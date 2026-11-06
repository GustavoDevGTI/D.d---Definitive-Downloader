import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:definitive_downloader/core/network/bounded_http.dart';
import 'package:definitive_downloader/core/platform/android_files.dart';
import 'package:definitive_downloader/core/platform/android_documents.dart';
import 'package:definitive_downloader/core/storage/database.dart';
import 'package:definitive_downloader/features/downloads/download_service.dart';
import 'package:definitive_downloader/features/importing/collection_duplicates.dart';
import 'package:definitive_downloader/features/importing/csv_importer.dart';
import 'package:definitive_downloader/features/importing/music_link.dart';
import 'package:definitive_downloader/features/importing/music_link_catalog.dart';
import 'package:definitive_downloader/features/importing/spotify_importer.dart';
import 'package:definitive_downloader/features/library/application/library_controller.dart';
import 'package:definitive_downloader/features/library/data/library_repository.dart';
import 'package:definitive_downloader/features/library/domain/models.dart';
import 'package:definitive_downloader/features/matching/deezer_catalog.dart';
import 'package:definitive_downloader/features/player/data/android_audio_engine.dart';
import 'package:definitive_downloader/features/player/data/player_library.dart';

class _Catalog extends MusicLinkCatalog {
  _Catalog(this.port);
  final int port;
  @override
  Future<ResolvedMusicLink> resolve(MusicLink link) async => ResolvedMusicLink(
      link: link,
      ready: true,
      pinned: true,
      draft: TrackDraft(
          title: 'Destino público',
          artist: 'Fixture D.d',
          durationMs: 4000,
          sourceUrl: link.url,
          mediaUrl: 'http://127.0.0.1:$port/audio.mp3',
          sourceKind: SourceKind.directMp3,
          coverUrl: 'asset:assets/demo/cover.png'));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
      'destino SAF: retry sem rede, player público, recuperação manual e substituição',
      (tester) async {
    final support = (await getApplicationSupportDirectory()).path;
    final temp =
        await (await getTemporaryDirectory()).createTemp('dd-managed-');
    final files = AndroidFiles();
    final bytes = await rootBundle.load('assets/demo/tone.mp3');
    final audio =
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var requests = 0;
    server.listen((request) async {
      requests++;
      request.response.headers.contentType = ContentType('audio', 'mpeg');
      request.response.contentLength = audio.length;
      request.response.add(audio);
      await request.response.close();
    });
    final repo = LibraryRepository(AppDatabase('${temp.path}/db'));
    final library = LibraryController(
        repository: repo,
        files: files,
        spotify: const SpotifyImporter(BoundedHttp()),
        csv: const CsvImporter(),
        catalog: const DeezerCatalog(BoundedHttp()),
        downloader: DownloadService(const BoundedHttp(), rootBundle),
        linkCatalog: _Catalog(server.port));
    String? destination;
    AndroidAudioEngine? engine;
    Future<void> marker(String name) async {
      final file = File('$support/$name');
      final clock = Stopwatch()..start();
      while (!await file.exists()) {
        if (clock.elapsed > const Duration(seconds: 90)) {
          throw TimeoutException(name);
        }
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
      await file.delete();
    }

    try {
      await library.initialize();
      await tester.pumpWidget(const MaterialApp(
          home: Scaffold(body: Text('Destino público — fixture isolada'))));
      debugPrint('ANDROID_MANAGED_CHOOSE');
      await library.chooseOutput();
      destination = library.outputDirectory;
      expect(files.displayPath(destination), contains('DdManaged-'));
      final owner = await library.createPlaylist('Destino Android');
      await library.openCollection((await repo.collectionById(owner))!);
      const link = 'https://fixture.invalid/source.mp3';
      expect(await library.addLinks(owner, link), isTrue);
      final first = library.page.items.single;
      debugPrint('ANDROID_MANAGED_HIDE_DESTINATION');
      await marker('managed-hidden');
      await library.downloadSelected(queueIds: [first.id]);
      expect((await repo.trackById(first.id))!.status, TrackStatus.failed);
      expect(requests, 1, reason: (await repo.trackById(first.id))!.error);
      expect((await repo.trackById(first.id))!.localPath, isEmpty);
      debugPrint('ANDROID_MANAGED_RESTORE_DESTINATION');
      await marker('managed-restored');
      await library.downloadSelected(queueIds: [first.id]);
      var saved = (await repo.trackById(first.id))!;
      expect(saved.status, TrackStatus.completed, reason: library.message);
      expect(requests, 1,
          reason: 'Repetir a publicação não pode obter o áudio novamente.');
      expect(await File(saved.localPath).exists(), isFalse,
          reason:
              'O cache completo deve ser liberado após confirmar o documento público.');
      expect(await files.fileExists(saved.localPath), isTrue);
      expect(await files.fileSize(saved.localPath), greaterThan(audio.length));
      final playerLibrary = PlayerLibrary(repo.database, files: files);
      final item = (await playerLibrary.localFor(saved))!;
      final tags = await playerLibrary.tags(item);
      expect(tags.title, saved.outputTitle);
      expect(tags.cover, isNotEmpty);
      engine = AndroidAudioEngine();
      await engine.open(item.uri);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(engine.measurements['playing'], isTrue);
      expect(engine.measurements['durationMs'], greaterThan(3000));
      await engine.stop();
      final uri = await AndroidDocuments().playback(item.uri);
      expect(Uri.parse(uri).scheme, 'content');
      await File('$support/managed-plan.json')
          .writeAsString(jsonEncode({'uri': uri}), flush: true);
      debugPrint('ANDROID_MANAGED_DELETE_MEDIA');
      await marker('managed-deleted');
      expect(await files.fileExists(saved.localPath), isFalse);
      expect((await repo.trackById(first.id))!.status, TrackStatus.completed);
      await library.downloadSelected(queueIds: [first.id]);
      expect((await repo.trackById(first.id))!.redownloadState, 'review');
      expect(requests, 1);
      await library.setManualSource(link, ManualSourceMode.originalAudio);
      expect((await repo.trackById(first.id))!.redownloadState, 'approved');
      expect(requests, 1);
      await library.downloadSelected(queueIds: [first.id]);
      saved = (await repo.trackById(first.id))!;
      expect(saved.status, TrackStatus.completed, reason: library.message);
      expect(saved.position, 1);
      expect(requests, 2);
      final original = File('${temp.path}/original.mp3');
      await original.writeAsBytes(audio, flush: true);
      expect(await library.addLocalFiles(owner, [original.path]), isTrue,
          reason: library.message);
      final local = library.page.items.last;
      expect(local.sourceKind, SourceKind.localFile);
      expect(local.position, 2);
      expect(await files.fileExists(local.localPath), isTrue);
      expect(await File(local.localPath).exists(), isFalse);
      expect(await original.readAsBytes(), audio);
      await files.revokeDestination(destination);
      await expectLater(
          files.fileExists(local.localPath), throwsA(isA<PlatformException>()));
      await library.downloadSelected(queueIds: [first.id]);
      expect((await repo.trackById(first.id))!.redownloadState, isEmpty,
          reason:
              'Revogar permissão não pode ser interpretado como exclusão da mídia.');
      expect(requests, 2);
      debugPrint('ANDROID_MANAGED_REAUTHORIZE');
      await library.chooseOutput();
      expect(library.outputDirectory, destination);
      expect(await files.fileExists(local.localPath), isTrue);
      expect(
          await library.addLinks(owner, link,
              chooseDuplicate: (_) async =>
                  const DuplicateDecision(DuplicateChoice.incoming)),
          isTrue,
          reason: library.message);
      expect(await files.fileExists(saved.localPath), isFalse,
          reason:
              'A versão antiga escolhida para substituição deve sair também da pasta pública.');
      expect(library.page.items.first.id, local.id);
      expect(library.page.items.first.position, 2);
      expect(library.page.items.last.position, 3);
      expect(await files.fileExists(local.localPath), isTrue);
      expect(await original.readAsBytes(), audio);
      expect(requests, 2);
      expect(
          await repo.database.run((db) => db
              .select('SELECT COUNT(*) AS n FROM music_replacement_files')
              .single['n']),
          0);
      debugPrint('ANDROID_MANAGED_VERIFIED');
      await marker('managed-inspected');
    } finally {
      if (engine != null) await engine.dispose();
      library.dispose();
      await server.close(force: true);
      if (destination != null &&
          destination.contains('/Definitive Downloader/Documentos/')) {
        // Remove only native registry rows for this isolated test's exact root.
        final db = sqlite3.open(
            '${Directory(support).parent.path}/databases/managed-documents.sqlite3');
        try {
          db.execute('BEGIN IMMEDIATE');
          db.execute(
              'DELETE FROM removals WHERE job IN (SELECT id FROM jobs WHERE instr(directory,?)=1)',
              ['$destination/']);
          db.execute(
              'DELETE FROM media WHERE job IN (SELECT id FROM jobs WHERE instr(directory,?)=1)',
              ['$destination/']);
          db.execute(
              'DELETE FROM jobs WHERE instr(directory,?)=1', ['$destination/']);
          db.execute('DELETE FROM folders WHERE root=?', [destination]);
          db.execute('DELETE FROM targets WHERE root=?', [destination]);
          db.execute('COMMIT');
        } finally {
          db.dispose();
        }
        if (await Directory(destination).exists()) {
          await Directory(destination).delete(recursive: true);
        }
      }
      await temp.delete(recursive: true);
      await tester.pumpWidget(const SizedBox());
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}

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
import 'package:definitive_downloader/core/platform/android_documents.dart';
import 'package:definitive_downloader/core/platform/android_files.dart';
import 'package:definitive_downloader/core/storage/database.dart';
import 'package:definitive_downloader/features/downloads/download_service.dart';
import 'package:definitive_downloader/features/importing/csv_importer.dart';
import 'package:definitive_downloader/features/importing/music_link.dart';
import 'package:definitive_downloader/features/importing/music_link_catalog.dart';
import 'package:definitive_downloader/features/importing/spotify_importer.dart';
import 'package:definitive_downloader/features/library/application/library_controller.dart';
import 'package:definitive_downloader/features/library/data/library_repository.dart';
import 'package:definitive_downloader/features/library/domain/models.dart';
import 'package:definitive_downloader/features/matching/deezer_catalog.dart';
import 'support/android_publication_guards.dart';

class _Catalog extends MusicLinkCatalog {
  _Catalog(this.port, this.token);
  final int port;
  final String token;
  @override
  Future<ResolvedMusicLink> resolve(MusicLink link) async {
    final name = Uri.parse(link.url).pathSegments.last;
    return ResolvedMusicLink(
        link: link,
        ready: true,
        pinned: true,
        draft: TrackDraft(
            title: name.replaceFirst('.mp3', ''),
            artist: 'Fixture D.d $token',
            durationMs: 4000,
            sourceUrl: link.url,
            mediaUrl: 'http://127.0.0.1:$port/$name',
            sourceKind: SourceKind.directMp3,
            coverUrl: 'asset:assets/demo/cover.png'));
  }
}

class _PublicationGate extends AndroidFiles {
  _PublicationGate({this.renamed = false});
  final bool renamed;
  @override
  Future<String> publishMedia(
      String path, String directory, int trackId, int collectionId, String key,
      {DownloadCancellation? cancellation, String? fileName}) async {
    final result = await super.publishMedia(
        path, directory, trackId, collectionId, key,
        cancellation: cancellation, fileName: fileName);
    if (renamed) {
      // Journal fixture only: emulate the durable gap after a real provider
      // rename but before the returned URI/cache binding was recorded.
      final support = (await getApplicationSupportDirectory()).path;
      final db = sqlite3.open(
          '${Directory(support).parent.path}/databases/managed-documents.sqlite3');
      try {
        final row = db.select(
            'SELECT j.* FROM media m JOIN jobs j ON j.id=m.job WHERE m.path=?',
            [result]).single;
        final uri = Uri.parse(row['uri'] as String);
        expect(uri.authority, 'com.android.externalstorage.documents');
        final segments = uri.pathSegments.toList();
        final document = segments.last;
        segments[segments.length - 1] =
            '${document.substring(0, document.lastIndexOf('/'))}/.dd-${row['id']}.mp3';
        final original =
            File('${row['stage']}/${File(result).uri.pathSegments.last}');
        await File(result).rename(original.path);
        db.execute('BEGIN IMMEDIATE');
        db.execute('DELETE FROM media WHERE path=?', [result]);
        db.execute("UPDATE jobs SET state='renaming',uri=?,path=? WHERE id=?", [
          uri.replace(pathSegments: segments).toString(),
          original.path,
          row['id']
        ]);
        db.execute('COMMIT');
      } finally {
        db.dispose();
      }
    }
    debugPrint('DD_INTERRUPT_PUBLISHED');
    // The companion force-stops the real Android process here, after native
    // publication but before the shared queue can commit completion to SQLite.
    await Completer<void>().future;
    return result;
  }
}

Future<void> _waitFile(File file) async {
  final clock = Stopwatch()..start();
  while (!await file.exists()) {
    if (clock.elapsed > const Duration(seconds: 90)) {
      throw TimeoutException('A automação de interrupção não respondeu.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('retomada Android em quatro processos isolados', (tester) async {
    final support = (await getApplicationSupportDirectory()).path;
    final configFile = File('$support/dd-interruption-config.json');
    debugPrint('DD_INTERRUPT_CONFIG');
    await _waitFile(configFile);
    final config =
        jsonDecode(await configFile.readAsString()) as Map<String, dynamic>;
    await configFile.delete();
    final token = config['token'] as String;
    final phase = config['phase'] as int;
    expect(RegExp(r'^[a-f0-9]{12}$').hasMatch(token), isTrue);
    final work = Directory('$support/dd-interruption-$token');
    final planFile = File('${work.path}/plan.json');
    if (phase == 1) {
      expect(await work.exists(), isFalse);
      await work.create();
    } else {
      expect(await planFile.exists(), isTrue);
    }
    final renamed = config['renamed'] == true;
    final files =
        phase == 1 ? _PublicationGate(renamed: renamed) : AndroidFiles();
    final repo = LibraryRepository(AppDatabase('${work.path}/library.sqlite3'));
    final library = LibraryController(
        repository: repo,
        files: files,
        spotify: const SpotifyImporter(BoundedHttp()),
        csv: const CsvImporter(),
        catalog: const DeezerCatalog(BoundedHttp()),
        downloader: DownloadService(const BoundedHttp(), rootBundle),
        linkCatalog: _Catalog(config['port'] as int, token));
    await library.initialize();
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Text('D.d · retomada isolada'))));
    if (phase == 1) {
      debugPrint('DD_INTERRUPT_CHOOSE');
      await library.chooseOutput();
      expect(files.displayPath(library.outputDirectory),
          contains('DdInterrupt-$token'));
      final owner = await library.createPlaylist('Retomada $token');
      if (renamed) {
        await checkPrivatePublicationGuards(
            library.outputDirectory, owner, work);
      }
      await library.openCollection((await repo.collectionById(owner))!);
      expect(
          await library.addLinks(owner,
              'https://fixture.invalid/publicado.mp3\nhttps://fixture.invalid/interrompido.mp3'),
          isTrue);
      final tracks = library.page.items;
      await planFile.writeAsString(
          jsonEncode({
            'owner': owner,
            'first': tracks[0].id,
            'second': tracks[1].id,
            'destination': library.outputDirectory
          }),
          flush: true);
      await library.downloadSelected(queueIds: [tracks[0].id]);
      fail('A fase publicada deveria ter sido encerrada pelo processo real.');
    }
    final plan =
        jsonDecode(await planFile.readAsString()) as Map<String, dynamic>;
    final firstId = plan['first'] as int;
    final secondId = plan['second'] as int;
    final first = (await repo.trackById(firstId))!;
    final second = (await repo.trackById(secondId))!;
    expect(first.position, 1);
    expect(second.position, 2);
    expect(library.downloading, isFalse);
    if (phase == 2) {
      expect(first.status, TrackStatus.completed, reason: library.message);
      expect(await files.fileExists(first.localPath), isTrue);
      expect(await File(first.localPath).exists(), isFalse);
      expect(second.status, TrackStatus.ready);
      final history = await repo.database.run((db) => db.select(
          'SELECT created_at FROM download_history WHERE track_id=?',
          [firstId]).single['created_at']);
      plan['firstDate'] = history;
      await planFile.writeAsString(jsonEncode(plan), flush: true);
      if (renamed) {
        expect((await files.pendingMedia()).where((p) => p.trackId == firstId),
            isEmpty);
        debugPrint('DD_INTERRUPT_RENAMED_VERIFIED');
        final inspected = File('$support/dd-interruption-inspected');
        await _waitFile(inspected);
        await inspected.delete();
        library.dispose();
        await _cleanup(support, work, plan['destination'] as String);
        await tester.pumpWidget(const SizedBox());
        return;
      }
      final running = library.downloadSelected(queueIds: [secondId]);
      final clock = Stopwatch()..start();
      while ((library.transfer?.received ?? 0) < 4096) {
        if (clock.elapsed > const Duration(seconds: 30)) {
          throw TimeoutException('Recebimento de fixture não iniciou.');
        }
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      expect((await repo.trackById(secondId))!.status, TrackStatus.downloading);
      debugPrint('DD_INTERRUPT_NETWORK');
      await running;
      fail(
          'A fase de recebimento deveria ter sido encerrada pelo processo real.');
    }
    if (phase == 3) {
      expect(first.status, TrackStatus.completed);
      expect(second.status, TrackStatus.ready);
      expect(second.localPath, isEmpty);
      expect(second.error, contains('interrompida'));
      expect(
          await repo.database.run((db) => db
              .select('SELECT COUNT(*) AS n FROM download_run_additions')
              .single['n']),
          0);
      expect(
          await repo.database.run((db) => db.select(
              'SELECT created_at FROM download_history WHERE track_id=?',
              [firstId]).single['created_at']),
          plan['firstDate']);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      debugPrint('DD_INTERRUPT_RETRY');
      final retryChecked = File('$support/dd-interruption-retry-checked');
      await _waitFile(retryChecked);
      await retryChecked.delete();
      await library.downloadSelected(queueIds: [secondId]);
      final completed = (await repo.trackById(secondId))!;
      expect(completed.status, TrackStatus.completed, reason: library.message);
      expect(await files.fileExists(completed.localPath), isTrue);
      expect(await File(completed.localPath).exists(), isFalse);
      final uri = await AndroidDocuments()
          .playback(Uri.file(first.localPath).toString());
      await File('$support/dd-interruption-delete.json')
          .writeAsString(jsonEncode({'uri': uri}), flush: true);
      debugPrint('DD_INTERRUPT_DELETE');
      final deleted = File('$support/dd-interruption-deleted');
      await _waitFile(deleted);
      await deleted.delete();
      expect(await files.fileExists(first.localPath), isFalse);
      await library.downloadSelected(queueIds: [firstId]);
      expect((await repo.trackById(firstId))!.redownloadState, 'review');
      expect((await repo.trackById(firstId))!.localPath, first.localPath);
      debugPrint('DD_INTERRUPT_REVIEW');
      await Completer<void>().future;
    }
    expect(phase, 4);
    expect(first.redownloadState, 'review');
    expect(first.status, TrackStatus.pending);
    expect(await repo.hasMediaHistory(first.localPath), isTrue);
    expect(second.status, TrackStatus.completed);
    expect(await files.fileExists(first.localPath), isFalse);
    expect(await files.fileExists(second.localPath), isTrue);
    await library.downloadSelected(queueIds: [firstId]);
    expect((await repo.trackById(firstId))!.redownloadState, 'review');
    await library.setManualSource('https://fixture.invalid/publicado.mp3',
        ManualSourceMode.originalAudio);
    expect((await repo.trackById(firstId))!.redownloadState, 'approved');
    debugPrint('DD_INTERRUPT_APPROVED');
    final approved = File('$support/dd-interruption-approve-checked');
    await _waitFile(approved);
    await approved.delete();
    await library.downloadSelected(queueIds: [firstId]);
    final saved = (await repo.trackById(firstId))!;
    expect(saved.redownloadState, isEmpty);
    expect(saved.position, 1);
    expect(saved.localPath, first.localPath);
    expect(await files.fileExists(saved.localPath), isTrue);
    expect(await files.fileExists(second.localPath), isTrue);
    expect(
        await repo.database.run((db) => db
            .select('SELECT COUNT(*) AS n FROM download_history')
            .single['n']),
        2);
    final destination = plan['destination'] as String;
    final native = sqlite3.open(
        '${Directory(support).parent.path}/databases/managed-documents.sqlite3');
    try {
      expect(
          native.select(
              "SELECT COUNT(*) AS n FROM jobs WHERE directory LIKE ? AND state='allocated'",
              ['$destination/%']).single['n'],
          0);
      expect(
          native.select(
              "SELECT COUNT(*) AS n FROM jobs WHERE directory LIKE ? AND state='published'",
              ['$destination/%']).single['n'],
          0);
      expect(
          native.select('SELECT COUNT(*) AS n FROM removals').single['n'], 0);
    } finally {
      native.dispose();
    }
    debugPrint('DD_INTERRUPT_VERIFIED');
    final inspected = File('$support/dd-interruption-inspected');
    await _waitFile(inspected);
    await inspected.delete();
    library.dispose();
    await _cleanup(support, work, destination);
    await tester.pumpWidget(const SizedBox());
  }, timeout: const Timeout(Duration(minutes: 3)));
}

Future<void> _cleanup(
    String support, Directory work, String destination) async {
  final roots = Directory('$support/Definitive Downloader/Documentos');
  final target = Directory(destination);
  expect(await target.parent.resolveSymbolicLinks(),
      await roots.resolveSymbolicLinks());
  expect(target.uri.pathSegments.where((s) => s.isNotEmpty).last,
      matches(RegExp(r'^[a-f0-9-]{36}$')));
  expect(work.parent.path, support);
  expect(work.uri.pathSegments.where((s) => s.isNotEmpty).last,
      matches(RegExp(r'^dd-interruption-[a-f0-9]{12}$')));
  final clean = sqlite3.open(
      '${Directory(support).parent.path}/databases/managed-documents.sqlite3');
  try {
    clean.execute('BEGIN IMMEDIATE');
    clean.execute(
        'DELETE FROM media WHERE job IN (SELECT id FROM jobs WHERE instr(directory,?)=1)',
        ['$destination/']);
    clean.execute(
        'DELETE FROM jobs WHERE instr(directory,?)=1', ['$destination/']);
    clean.execute('DELETE FROM folders WHERE root=?', [destination]);
    clean.execute('DELETE FROM targets WHERE root=?', [destination]);
    clean.execute('COMMIT');
  } finally {
    clean.dispose();
  }
  if (await target.exists()) {
    await target.delete(recursive: true);
  }
  await work.delete(recursive: true);
}

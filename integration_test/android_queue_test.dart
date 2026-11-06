import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:definitive_downloader/app/theme.dart';
import 'package:definitive_downloader/core/network/bounded_http.dart';
import 'package:definitive_downloader/core/platform/android_files.dart';
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
import 'package:definitive_downloader/features/library/presentation/duplicate_music_dialog.dart';
import 'package:definitive_downloader/features/library/presentation/edit_track_dialog.dart';
import 'package:definitive_downloader/features/matching/deezer_catalog.dart';
import 'package:definitive_downloader/features/player/data/android_audio_engine.dart';

Future<void> until(bool Function() ready) async {
  final clock = Stopwatch()..start();
  while (!ready()) {
    if (clock.elapsed > const Duration(seconds: 15)) {
      throw TimeoutException('O estado esperado da fila não foi alcançado.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

/// Synthetic metadata routes to a real loopback HTTP server, not a provider.
/// DownloadService, SQLite, tags, queue and Android IO remain unmocked.
class _FixtureCatalog extends MusicLinkCatalog {
  _FixtureCatalog(this.port);
  final int port;
  @override
  Future<ResolvedMusicLink> resolve(MusicLink link) async {
    final name = Uri.parse(link.url).pathSegments.last;
    return ResolvedMusicLink(
        link: link,
        ready: true,
        pinned: true,
        draft: TrackDraft(
            title: name.replaceFirst('.mp3', ''),
            artist: 'Fixture D.d',
            durationMs: 4000,
            sourceUrl: link.url,
            mediaUrl: 'http://127.0.0.1:$port/$name',
            sourceKind: SourceKind.directMp3,
            coverUrl: 'asset:assets/demo/cover.png'));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  late HttpServer server;
  late LibraryRepository repo;
  late LibraryController controller;
  late Completer<void> gate;
  late List<String> received;
  late Uint8List audio;
  Future<void>? queueRun;
  var holdFirst = false;
  const base = 'https://fixture.invalid';
  setUp(() async {
    temp = await (await getTemporaryDirectory()).createTemp('dd-queue-native-');
    final source = await rootBundle.load('assets/demo/tone.mp3');
    audio =
        source.buffer.asUint8List(source.offsetInBytes, source.lengthInBytes);
    gate = Completer<void>();
    received = [];
    holdFirst = false;
    queueRun = null;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      try {
        received.add(request.uri.path);
        request.response.contentLength = audio.length;
        request.response.headers.contentType = ContentType('audio', 'mpeg');
        final held = holdFirst && received.length == 1;
        final prefix = held ? 16384 : 2048;
        for (var start = 0; start < prefix; start += 1024) {
          request.response.add(audio.sublist(start, start + 1024));
          await request.response.flush();
          if (held) {
            await Future<void>.delayed(const Duration(milliseconds: 100));
          }
        }
        if (held) await gate.future;
        request.response.add(audio.sublist(prefix));
        await request.response.close();
      } on IOException {
        // Cancellation/fixture teardown may close only this loopback response.
      }
    });
    repo = LibraryRepository(AppDatabase('${temp.path}/library.db'));
    controller = LibraryController(
        repository: repo,
        files: AndroidFiles(),
        spotify: const SpotifyImporter(BoundedHttp()),
        csv: const CsvImporter(),
        catalog: const DeezerCatalog(BoundedHttp()),
        downloader: DownloadService(const BoundedHttp(), rootBundle),
        linkCatalog: _FixtureCatalog(server.port));
    await controller.initialize();
    controller.outputDirectory = '${temp.path}/media';
    final owner = await controller.createPlaylist('Fila Android isolada');
    await controller.openCollection((await repo.collectionById(owner))!);
  });
  tearDown(() async {
    controller.cancel();
    if (!gate.isCompleted) gate.complete();
    await server.close(force: true);
    if (queueRun != null) {
      await queueRun!.timeout(const Duration(seconds: 25));
    }
    controller.dispose();
    await temp.delete(recursive: true);
  });
  testWidgets(
      'fila Android: HTTP, pausa, ordem pendente e extras na mesma execução',
      (tester) async {
    final owner = controller.current!.id;
    expect(
        await controller.addLinks(
            owner, '$base/primeira.mp3\n$base/segunda.mp3\n$base/terceira.mp3'),
        isTrue,
        reason: controller.message);
    final tracks = controller.page.items;
    holdFirst = true;
    final running = queueRun =
        controller.downloadSelected(queueIds: tracks.map((t) => t.id).toList());
    await until(() => (controller.transfer?.received ?? 0) > 0);
    expect(controller.activeTrackId, tracks.first.id);
    expect(
        await controller.moveTracks(tracks[2].id,
            collectionId: owner,
            targetId: tracks[1].id,
            after: false,
            selectedGroup: false),
        isNull);
    expect(await controller.addLinks(owner, '$base/extra.mp3'), isTrue,
        reason: controller.message);
    final measured = controller.transfer!;
    expect(measured.total, audio.length);
    controller.togglePause();
    gate.complete();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(received, ['/primeira.mp3']);
    expect(controller.pauseMode, isTrue);
    expect(controller.activeTrackId, tracks.first.id);
    final remaining = (await repo.page(owner)).items;
    expect(remaining.map((t) => t.title),
        ['primeira', 'terceira', 'segunda', 'extra']);
    controller.togglePause();
    await running;
    expect(received,
        ['/primeira.mp3', '/terceira.mp3', '/segunda.mp3', '/extra.mp3']);
    expect((await repo.collectionById(owner))!.completedCount, 4);
    expect(controller.message, isEmpty);
    final first = (await repo.trackById(tracks.first.id))!;
    expect(first.position, 1);
    final playlist = (await temp
            .list(recursive: true)
            .where((f) => f.path.endsWith('.m3u8'))
            .toList())
        .single;
    final lines = await File(playlist.path).readAsLines();
    expect(lines.where((line) => line.startsWith('#EXTINF:')).length, 4);
    final metadata = await AndroidAudioEngine.channel
        .invokeMapMethod<String, dynamic>('inspect', {'path': first.localPath});
    expect(metadata!['durationMs'] as int, greaterThan(3500));
    debugPrint('ANDROID_QUEUE_RESULT ${jsonEncode({
          'completed': 4,
          'measuredTotal': measured.total,
          'pauseBlockedNext': true,
          'pendingOrder': true,
          'extraIncluded': true
        })}');
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets(
      'Android: editor por toque mantém numeração com lacunas antes do download',
      (tester) async {
    final owner = controller.current!.id;
    expect(
        await controller.addLinks(
            owner, '$base/primeira.mp3\n$base/segunda.mp3\n$base/terceira.mp3'),
        isTrue);
    expect(
        await controller.addLinks(owner, '$base/primeira.mp3',
            chooseDuplicate: (_) async =>
                const DuplicateDecision(DuplicateChoice.incoming)),
        isTrue);
    final track = controller.page.items.last;
    expect(track.position, 4);
    expect(controller.current!.trackCount, 3);
    await tester.pumpWidget(MaterialApp(
        theme: appTheme(),
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => showEditTrack(context, controller, track),
                    child: const Text('Editar teste'))))));
    await tester.tap(find.text('Editar teste'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('edit-track-name')), 'Nome personalizado');
    await tester.ensureVisible(find.text('Salvar alterações'));
    await tester.tap(find.text('Salvar alterações'));
    for (var i = 0;
        i < 80 && find.byType(EditTrackDialog).evaluate().isNotEmpty;
        i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(EditTrackDialog), findsNothing);
    final renamed = (await repo.trackById(track.id))!;
    expect(renamed.position, 4);
    expect(renamed.displayTitle, 'Nome personalizado');
    expect(received, isEmpty, reason: 'Editar não inicia download.');
    await tester.pumpWidget(const SizedBox());
    debugPrint('ANDROID_GAPPED_EDITOR ${jsonEncode({
          'position': renamed.position,
          'trackCount': 3,
          'renamed': true,
          'downloads': received.length
        })}');
  }, timeout: const Timeout(Duration(minutes: 2)));
  testWidgets(
      'Android: recuperação manual e popup de duplicatas preservam arquivos e posições',
      (tester) async {
    final owner = controller.current!.id;
    expect(
        await controller.addLinks(
            owner, '$base/primeira.mp3\n$base/segunda.mp3'),
        isTrue);
    await controller.downloadSelected(
        queueIds: controller.page.items.map((t) => t.id).toList());
    final old = controller.page.items.first;
    final fixed = controller.page.items[1];
    final fixedBytes = await File(fixed.localPath).readAsBytes();
    await File(old.localPath).delete();
    final calls = received.length;
    await controller.downloadSelected(queueIds: [old.id]);
    expect(controller.focused!.redownloadReview, isTrue);
    expect(received.length, calls);
    await controller.confirmSource();
    expect(received.length, calls);
    expect(controller.downloading, isFalse);
    await controller.downloadSelected(queueIds: [old.id]);
    expect(received.length, calls + 1);
    final recovered = (await repo.trackById(old.id))!;
    expect(recovered.localPath, old.localPath);
    expect(recovered.position, old.position);
    Future<bool>? addition;
    await tester.pumpWidget(MaterialApp(
        theme: appTheme(),
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () {
                      addition = controller.addLinks(owner,
                          '$base/primeira.mp3\n$base/primeira.mp3\n$base/terceira.mp3',
                          chooseDuplicate: (conflict) =>
                              chooseDuplicateMusic(context, conflict));
                    },
                    child: const Text('Adicionar lote de teste'))))));
    await tester.tap(find.text('Adicionar lote de teste'));
    for (var i = 0;
        i < 80 &&
            find
                .byKey(const ValueKey('duplicates-incoming'))
                .evaluate()
                .isEmpty;
        i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const ValueKey('duplicates-incoming')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('duplicates-incoming')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('duplicates-all')));
    await tester.tap(find.byKey(const ValueKey('duplicates-all')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('duplicates-confirm')));
    await tester.pumpAndSettle();
    expect(await addition!, isTrue, reason: controller.message);
    expect(await File(recovered.localPath).exists(), isFalse);
    expect(await File(fixed.localPath).readAsBytes(), fixedBytes);
    var rows = (await repo.page(owner)).items;
    expect(rows.map((t) => t.position), [2, 3, 4]);
    expect(rows.first.id, fixed.id);
    expect(rows.map((t) => t.title), ['segunda', 'primeira', 'terceira']);
    expect(
        await controller.moveTracks(rows.last.id,
            collectionId: owner,
            targetId: rows[1].id,
            after: false,
            selectedGroup: false),
        isNull);
    rows = (await repo.page(owner)).items;
    expect(rows.map((t) => t.position), [2, 3, 4]);
    expect(rows.map((t) => t.title), ['segunda', 'terceira', 'primeira']);
    expect(await File(fixed.localPath).readAsBytes(), fixedBytes);
    final journal = await repo.database
        .run((db) => db.select('SELECT * FROM music_replacement_files').length);
    expect(journal, 0);
    await tester.pumpWidget(const SizedBox());
    debugPrint('ANDROID_RECOVERY_DUPLICATES ${jsonEncode({
          'manualRecovery': true,
          'replacementDeletedOnlyOld': true,
          'fixedPosition': 2,
          'gappedReorder': true,
          'journalRemaining': journal
        })}');
  }, timeout: const Timeout(Duration(minutes: 3)));
}

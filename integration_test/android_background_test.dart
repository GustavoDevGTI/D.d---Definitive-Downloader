import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:definitive_downloader/core/platform/android_background.dart';
import 'package:definitive_downloader/core/platform/android_files.dart';
import 'package:definitive_downloader/core/network/bounded_http.dart';
import 'package:definitive_downloader/core/storage/database.dart';
import 'package:definitive_downloader/features/downloads/download_service.dart';
import 'package:definitive_downloader/features/importing/csv_importer.dart';
import 'package:definitive_downloader/features/importing/spotify_importer.dart';
import 'package:definitive_downloader/features/library/application/library_controller.dart';
import 'package:definitive_downloader/features/library/data/library_repository.dart';
import 'package:definitive_downloader/features/library/domain/models.dart';
import 'package:definitive_downloader/features/matching/deezer_catalog.dart';
import 'package:definitive_downloader/features/player/application/music_player_controller.dart';
import 'package:definitive_downloader/features/player/data/android_audio_engine.dart';
import 'package:definitive_downloader/features/player/data/player_library.dart';

Future<Map<String, dynamic>> status() async =>
    await AndroidBackground.channel
        .invokeMapMethod<String, dynamic>('status') ??
    {};
Future<void> until(FutureOr<bool> Function() check) async {
  final clock = Stopwatch()..start();
  while (!await check()) {
    if (clock.elapsed > const Duration(seconds: 25)) {
      throw TimeoutException('Estado de segundo plano não alcançado.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
      'Android: fechar/reabrir Activity conserva áudio, sessão, fila e download',
      (tester) async {
    final temp =
        await (await getTemporaryDirectory()).createTemp('dd-bg-native-');
    final data = await rootBundle.load('assets/demo/tone.mp3');
    final bytes =
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    final original =
        await File('${temp.path}/Original.mp3').writeAsBytes(bytes);
    final repo = LibraryRepository(AppDatabase('${temp.path}/library.db'));
    final files = AndroidFiles();
    final controller = LibraryController(
        repository: repo,
        files: files,
        spotify: const SpotifyImporter(BoundedHttp()),
        csv: const CsvImporter(),
        catalog: const DeezerCatalog(BoundedHttp()),
        downloader: DownloadService(const BoundedHttp(), rootBundle));
    await controller.initialize();
    controller.outputDirectory = '${temp.path}/media';
    final id = await controller.createPlaylist('Segundo plano — fixture');
    expect(await controller.addLocalFiles(id, [original.path, original.path]),
        isTrue,
        reason: controller.message);
    final audio = AndroidAudioEngine();
    final player =
        MusicPlayerController(PlayerLibrary(repo.database), audio, files);
    final bridge = AndroidBackground(controller, player);
    addTearDown(() async {
      bridge.dispose();
      controller.dispose();
      await audio.stop();
      player.dispose();
      await audio.dispose();
      await temp.delete(recursive: true);
    });
    await player.initialize();
    player.cycleRepeat();
    await player.playCollection(id);
    await until(
        () async => (await status())['active'] == true && player.playing);
    final first = player.current!.id;
    await SystemNavigator.pop();
    await until(() async => (await status())['uiAttached'] == false);
    await until(
        () => player.current!.id != first && player.playing && !player.loading);
    expect(player.playing, isTrue);
    expect((await status())['session'], isTrue);
    await AndroidBackground.channel
        .invokeMethod<void>('command', {'action': 'pause'});
    await until(() => !player.playing);
    await AndroidBackground.channel
        .invokeMethod<void>('command', {'action': 'play'});
    await until(() => player.playing);
    debugPrint('ANDROID_BG_REOPEN_AUDIO');
    await until(() async => (await status())['uiAttached'] == true);
    expect((await status())['playing'], isTrue);
    await player.setModuleActive(false);
    await until(() async => (await status())['active'] == false);
    await AndroidBackground.channel
        .invokeMethod<void>('command', {'action': 'play'});
    expect(player.playing, isFalse,
        reason: 'Outra categoria não reativa música pela notificação.');
    await audio.stop();

    final gate = Completer<void>();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var requests = 0;
    server.listen((request) async {
      requests++;
      request.response.contentLength = bytes.length;
      request.response.add(bytes.sublist(0, 1024));
      await request.response.flush();
      await gate.future;
      request.response.add(bytes.sublist(1024));
      await request.response.close();
    });
    final collection = await repo.importCollection(ImportedCollection(
        name: 'HTTP em segundo plano',
        source: 'Fixture loopback',
        sourceUrl: '',
        tracks: Stream.fromIterable(List.generate(
            2,
            (i) => TrackDraft(
                title: 'Fixture $i',
                artist: 'D.d',
                durationMs: 4000,
                sourceKind: SourceKind.directMp3,
                mediaUrl: 'http://127.0.0.1:${server.port}/$i.mp3')))));
    await controller.openCollection((await repo.collectionById(collection))!);
    final running = controller.downloadSelected(
        queueIds: controller.page.items.map((t) => t.id).toList());
    try {
      await until(() async =>
          requests > 0 &&
          (await status())['downloading'] == true &&
          (await status())['active'] == true);
      await player.setModuleActive(true);
      await player.playCollection(id);
      await until(() async => (await status())['notifications'] == 2);
      await AndroidBackground.channel
          .invokeMethod<void>('command', {'action': 'pauseQueue'});
      await until(() async =>
          controller.pauseMode && (await status())['paused'] == true);
      await AndroidBackground.channel
          .invokeMethod<void>('command', {'action': 'pauseQueue'});
      await until(() => !controller.pauseMode);
      await SystemNavigator.pop();
      await until(() async => (await status())['uiAttached'] == false);
      gate.complete();
      await running;
      expect((await repo.collectionById(collection))!.completedCount, 2,
          reason: controller.message);
      expect(requests, 2);
      await AndroidBackground.channel
          .invokeMethod<void>('command', {'action': 'stopAudio'});
      await until(() => player.current == null);
      await until(() async => (await status())['active'] == false);
      debugPrint('ANDROID_BG_REOPEN_DOWNLOAD');
      await until(() async => (await status())['uiAttached'] == true);
      debugPrint(
          'ANDROID_BACKGROUND_RESULT: Activity encerrada/reaberta duas vezes; áudio/fila e 2 HTTP completos; sessão/controles/finalização aprovados.');
    } finally {
      controller.cancel();
      if (!gate.isCompleted) gate.complete();
      await server.close(force: true);
      await running;
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}

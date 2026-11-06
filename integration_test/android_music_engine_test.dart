import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:definitive_downloader/features/matching/android_music_engine.dart';
import 'package:definitive_downloader/core/storage/database.dart';
import 'package:definitive_downloader/features/importing/soundcloud_catalog.dart';
import 'package:definitive_downloader/features/library/data/library_repository.dart';
import 'package:definitive_downloader/features/library/domain/models.dart';
import 'package:definitive_downloader/features/connections/application/deezer_connection_controller.dart';
import 'package:definitive_downloader/features/downloads/music_download_service.dart';
import 'package:definitive_downloader/features/downloads/download_cancellation.dart';
import 'package:definitive_downloader/features/downloads/playlist_exporter.dart';
import 'package:definitive_downloader/features/player/data/android_audio_engine.dart';
import 'package:definitive_downloader/features/player/data/audio_tags.dart';

class _NoSession implements DeezerSessionStore {
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String value) async {}
  @override
  Future<void> clear() async {}
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('runtime Android executa Python, codec MP3 e vetor portátil',
      (tester) async {
    expect(Platform.isAndroid, isTrue);
    final engine = await AndroidMusicEngine.installed();
    expect(engine.available, isTrue, reason: engine.initializationError);
    final health = await engine.call({'operation': 'health'});
    expect(health['platform'], 'android');
    expect(health['codecValidated'], isTrue);
    expect(health['blockVectorValidated'], isTrue);
    expect(health['protocol'], 1);
    debugPrint('ANDROID_RUNTIME_HEALTH ${jsonEncode(health)}');
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets(
      'SoundCloud real Android: cópia, MP3 completo, tags, M3U8, pausa e cancelamento',
      (tester) async {
    final engine = await AndroidMusicEngine.installed();
    expect(engine.available, isTrue, reason: engine.initializationError);
    final directory =
        await (await getTemporaryDirectory()).createTemp('dd-android-source-');
    final connection = DeezerConnectionController(_NoSession(), engine);
    addTearDown(() async {
      connection.dispose();
      await directory.delete(recursive: true);
    });
    final draft = await SoundCloudCatalog()
        .track('https://soundcloud.com/the-concept-band/the-concept-d-d-dance');
    expect(draft.sourceId, '30510138');
    final repository =
        LibraryRepository(AppDatabase('${directory.path}/library.db'));
    await repository.database.initialize();
    final id = await repository.importCollection(ImportedCollection(
        name: 'SoundCloud Android isolado',
        source: 'SoundCloud',
        sourceUrl: draft.sourceUrl,
        tracks: Stream.fromIterable([draft, draft])));
    final tracks = (await repository.page(id)).items;
    final service = MusicDownloadService(engine, connection);
    final paths = <String>[];
    var progress = 0;
    var pausedBytesObserved = false;
    for (final track in tracks) {
      final token = DownloadCancellation()..pauseMode = paths.isEmpty;
      Timer? resume;
      try {
        final path = await service.save(track, directory.path, token, (_) {},
            onTransfer: (measurement) {
          progress++;
          if (token.pauseMode &&
              measurement.received > 0 &&
              !measurement.processing &&
              resume == null) {
            pausedBytesObserved = true;
            resume = Timer(
                const Duration(seconds: 2), () => token.pauseMode = false);
          }
        });
        await repository.setStatus(track.id, TrackStatus.completed,
            localPath: path);
        final tags = await readAudioTags(path);
        expect(tags.title, isNotEmpty);
        expect(tags.cover, isNotNull);
        expect(await File(path).length(), greaterThan(100000));
        final metadata = await AndroidAudioEngine.channel
            .invokeMapMethod<String, dynamic>('inspect', {'path': path});
        expect(((metadata!['durationMs'] as int) - draft.durationMs!).abs(),
            lessThanOrEqualTo(2000));
        paths.add(path);
      } finally {
        resume?.cancel();
      }
    }
    expect(paths.toSet().length, 2);
    expect(progress, greaterThan(0));
    expect(pausedBytesObserved, isTrue);
    final playlist =
        await PlaylistExporter(repository).export(id, directory.path);
    expect(playlist, isNotNull);
    final text = await File(playlist).readAsString();
    expect(text.split('\n').where((line) => line.startsWith('#EXTINF:')).length,
        2);
    expect(text, contains('[SoundCloud]'));
    final cancel = DownloadCancellation();
    var processingObserved = false;
    await expectLater(
        service.save(tracks.first, directory.path, cancel, (stage) {
          if (stage == 'Conferindo áudio completo e metadados') {
            processingObserved = true;
            cancel.cancelled = true;
          }
        }),
        throwsA(isA<DownloadCancelled>()));
    expect(processingObserved, isTrue);
    Map<String, dynamic> status = {};
    for (var i = 0; i < 30; i++) {
      status = await AndroidMusicEngine.channel
              .invokeMapMethod<String, dynamic>('status') ??
          {};
      if (status['active'] == 0 && status['cancelledGroupsAlive'] == 0) break;
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    expect(status, {'active': 0, 'cancelledGroupsAlive': 0});
    for (final path in paths) {
      expect(await File(path).exists(), isTrue);
    }
    expect(
        (await directory.list().where((f) => f.path.endsWith('.mp3')).toList())
            .length,
        2);
    debugPrint('ANDROID_SOUNDCLOUD_RESULT ${jsonEncode({
          'files': paths.length,
          'progressEvents': progress,
          'pauseDuringReceive': pausedBytesObserved,
          'cancelDuringProcessing': processingObserved,
          'ownedGroupsRemaining': status['cancelledGroupsAlive'],
          'accountUsed': false
        })}');
  },
      skip: !const bool.fromEnvironment('DD_ANDROID_LIVE_SOURCES'),
      timeout: const Timeout(Duration(minutes: 5)));
}

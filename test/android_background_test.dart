import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:definitive_downloader/core/platform/android_background.dart';
import 'package:definitive_downloader/core/storage/database.dart';
import 'package:definitive_downloader/core/network/bounded_http.dart';
import 'package:definitive_downloader/features/downloads/download_service.dart';
import 'package:definitive_downloader/features/importing/csv_importer.dart';
import 'package:definitive_downloader/features/importing/spotify_importer.dart';
import 'package:definitive_downloader/features/library/application/library_controller.dart';
import 'package:definitive_downloader/features/library/data/library_repository.dart';
import 'package:definitive_downloader/features/matching/deezer_catalog.dart';
import 'package:definitive_downloader/features/player/application/music_player_controller.dart';
import 'package:definitive_downloader/features/player/domain/playback.dart';
import 'player_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('segundo plano compartilha política e não transmite cada tick do player',
      () async {
    final messages = <Map>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(AndroidBackground.channel, (call) async {
      messages.add(Map.from(call.arguments as Map));
      return null;
    });
    final audio = FakeAudioEngine();
    final files = PlayerFiles();
    final player = MusicPlayerController(MemoryPlayerLibrary(), audio, files);
    final library = LibraryController(
        repository: LibraryRepository(const AppDatabase('unused')),
        files: files,
        spotify: const SpotifyImporter(BoundedHttp()),
        csv: const CsvImporter(),
        catalog: const DeezerCatalog(BoundedHttp()),
        downloader: DownloadService(const BoundedHttp(), rootBundle));
    final bridge = AndroidBackground(library, player);
    try {
      await player.playCollection(1);
      await Future<void>.delayed(Duration.zero);
      final count = messages.length;
      for (var i = 1; i <= 200; i++) {
        audio.emit(AudioEvent(position: Duration(milliseconds: i * 10)));
      }
      await Future<void>.delayed(Duration.zero);
      expect(messages.length, count);
      await player.setModuleActive(false);
      await Future<void>.delayed(Duration.zero);
      expect(messages.last['audioEnabled'], isFalse);
      expect(player.playing, isFalse);
      await player.setModuleActive(true);
      await Future<void>.delayed(Duration.zero);
      expect(messages.last['audioEnabled'], isTrue);
      await messenger.handlePlatformMessage(
          AndroidBackground.channel.name,
          const StandardMethodCodec()
              .encodeMethodCall(const MethodCall('command', 'next')),
          (_) {});
      await playerUntil(() => player.current?.id == 'track-2');
      await messenger.handlePlatformMessage(
          AndroidBackground.channel.name,
          const StandardMethodCodec()
              .encodeMethodCall(const MethodCall('command', 'stopAudio')),
          (_) {});
      await playerUntil(() => player.current == null);
      expect(player.queue, isEmpty);
      expect(player.playing, isFalse);
    } finally {
      bridge.dispose();
      library.dispose();
      player.dispose();
      messenger.setMockMethodCallHandler(AndroidBackground.channel, null);
    }
  });
}

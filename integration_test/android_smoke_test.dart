import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:definitive_downloader/app/definitive_downloader_app.dart';
import 'package:definitive_downloader/core/network/bounded_http.dart';
import 'package:definitive_downloader/core/platform/android_files.dart';
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
import 'package:definitive_downloader/features/player/domain/playback.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android: SQLite, MP3 real local, player e navegação',
      (tester) async {
    expect(Platform.isAndroid, isTrue);
    final temp = await Directory((await getTemporaryDirectory()).path)
        .createTemp('dd-android-smoke-');
    final files = AndroidFiles();
    final destination = await files.defaultOutputDirectory();
    expect(destination.startsWith('/'), isTrue);
    final data = await rootBundle.load('assets/demo/tone.mp3');
    final original = await File('${temp.path}/Original.mp3')
        .writeAsBytes(data.buffer.asUint8List());
    final database = AppDatabase('${temp.path}/smoke.sqlite3');
    final repository = LibraryRepository(database);
    final controller = LibraryController(
        repository: repository,
        files: files,
        spotify: const SpotifyImporter(BoundedHttp()),
        csv: const CsvImporter(),
        catalog: const DeezerCatalog(BoundedHttp()),
        downloader: DownloadService(const BoundedHttp(), rootBundle));
    await controller.initialize();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      // Only the test-created tree is removed, including after a failed check.
      await temp.delete(recursive: true);
    });
    controller.outputDirectory = '${temp.path}/media';
    final id = await controller.createPlaylist('Teste Android isolado');
    expect(await controller.addLocalFiles(id, [original.path, original.path]),
        isTrue,
        reason: controller.message);
    final collection = (await repository.collectionById(id))!;
    expect(collection.completedCount, 2);
    final stored = (await repository.page(id)).items.first;
    expect(stored.sourceKind, SourceKind.localFile);
    expect(stored.localPath, isNot(original.path));
    expect(await File(stored.localPath).readAsBytes(),
        await original.readAsBytes());
    // A fresh repository/isolate reads the same native SQLite database.
    expect(
        (await LibraryRepository(AppDatabase(database.path))
                .collectionById(id))!
            .trackCount,
        2);
    const secure = FlutterSecureStorage();
    await secure.write(
        key: 'dd_android_smoke', value: 'fixture-not-a-credential');
    expect(
        await secure.read(key: 'dd_android_smoke'), 'fixture-not-a-credential');
    await secure.delete(key: 'dd_android_smoke');

    final engine = AndroidAudioEngine();
    final player =
        MusicPlayerController(PlayerLibrary(database), engine, files);
    await player.initialize();
    await player.playCollection(id);
    for (var i = 0;
        i < 40 && (engine.measurements['positionMs'] as int? ?? 0) == 0;
        i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    expect(engine.measurements['durationMs'] as int, greaterThan(0));
    expect(engine.measurements['positionMs'] as int, greaterThan(0));
    final first = player.current!.id;
    await player.next();
    expect(player.current!.id, isNot(first));
    await player.previous();
    expect(player.current!.id, first);
    player.toggleShuffle();
    expect(player.shuffled, isTrue);
    player.cycleRepeat();
    expect(player.repeat, AudioRepeat.playlist);
    player.cycleRepeat();
    expect(player.repeat, AudioRepeat.track);
    await player.pause();
    expect(engine.measurements['playing'], isFalse);
    player.setVolume(.35);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(engine.measurements['volume'] as num, closeTo(35, 1));

    await tester.pumpWidget(
        DefinitiveDownloaderApp(controller: controller, player: player));
    await tester.pumpAndSettle();
    if (find.byKey(const ValueKey('app-notice')).evaluate().isNotEmpty) {
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Músicas').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('music-player-bar')), findsOneWidget);
    await tester.ensureVisible(find.text('Teste Android isolado'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Teste Android isolado'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('track-search')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Voltar às coleções'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('music-player-bar')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

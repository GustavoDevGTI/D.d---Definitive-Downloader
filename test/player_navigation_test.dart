import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:definitive_downloader/app/definitive_downloader_app.dart';
import 'package:definitive_downloader/core/network/bounded_http.dart';
import 'package:definitive_downloader/core/platform/desktop_files.dart';
import 'package:definitive_downloader/core/storage/database.dart';
import 'package:definitive_downloader/features/downloads/download_service.dart';
import 'package:definitive_downloader/features/importing/csv_importer.dart';
import 'package:definitive_downloader/features/importing/spotify_importer.dart';
import 'package:definitive_downloader/features/library/application/library_controller.dart';
import 'package:definitive_downloader/features/library/data/library_repository.dart';
import 'package:definitive_downloader/features/library/domain/models.dart';
import 'package:definitive_downloader/features/library/presentation/sidebar.dart';
import 'package:definitive_downloader/features/library/presentation/track_inspector.dart';
import 'package:definitive_downloader/features/library/presentation/track_table.dart';
import 'package:definitive_downloader/features/matching/deezer_catalog.dart';
import 'package:definitive_downloader/features/player/application/music_player_controller.dart';
import 'player_fixtures.dart';
import 'widget_io.dart';

void main() {
  for (final width in [1360.0, 900.0, 390.0]) {
    testWidgets('player pertence a Músicas e pausa ao sair a $width px',
        (tester) async {
      tester.view.physicalSize = Size(width, 820);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late Directory temp;
      late LibraryController library;
      late Track track;
      await tester.runAsync(() async {
        temp = await Directory.systemTemp.createTemp('dd-player-nav-');
        final repo = LibraryRepository(AppDatabase('${temp.path}/test.db'));
        await repo.database.initialize();
        final id = await repo.importCollection(ImportedCollection(
            name: 'Coleção de áudio',
            source: 'Fixture',
            sourceUrl: '',
            tracks: Stream.fromIterable(List.generate(
                5,
                (i) => TrackDraft(
                    title: 'Faixa ${i + 1}',
                    artist: 'Laboratório D.d',
                    mediaUrl: 'https://www.deezer.com/track/123',
                    sourceKind: SourceKind.deezerFull)))));
        track = (await repo.page(id)).items.first;
        await repo.setStatus(track.id, TrackStatus.completed,
            localPath: '/fixture/1.mp3');
        library = LibraryController(
            repository: repo,
            files: DesktopFiles(),
            spotify: const SpotifyImporter(BoundedHttp()),
            csv: const CsvImporter(),
            catalog: const DeezerCatalog(BoundedHttp()),
            downloader: DownloadService(const BoundedHttp(), rootBundle));
        await library.refresh();
      });
      final engine = FakeAudioEngine();
      final player =
          MusicPlayerController(MemoryPlayerLibrary(), engine, PlayerFiles());
      await player.playCollection(1);
      await tester.pumpWidget(
          DefinitiveDownloaderApp(controller: library, player: player));
      await tester.pumpAndSettle();
      expect(player.playing, isFalse);
      expect(find.byKey(const ValueKey('player-play-pause')), findsNothing);
      final nav = width < 780
          ? find.byType(MobileNavigation)
          : find.byType(LibrarySidebar);
      final versionBounds = width >= 780
          ? tester.getRect(find.byKey(const ValueKey('sidebar-version')))
          : null;
      await tester
          .tap(find.descendant(of: nav, matching: find.text('Músicas')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('player-play-pause')), findsOneWidget);
      final playerBounds =
          tester.getRect(find.byKey(const ValueKey('music-player-bar')));
      if (width >= 780) {
        final sidebarBounds = tester.getRect(nav);
        expect(playerBounds.left, sidebarBounds.right);
        expect(playerBounds.right, width);
        expect(sidebarBounds.bottom, 820);
        expect(tester.getRect(find.byKey(const ValueKey('sidebar-version'))),
            versionBounds);
        expect(versionBounds!.bottom, sidebarBounds.bottom);
      } else {
        expect(playerBounds.left, 0);
        expect(playerBounds.right, width);
        expect(playerBounds.bottom, lessThanOrEqualTo(tester.getRect(nav).top));
      }
      await player.toggle();
      await tester.pumpAndSettle();
      final open =
          find.byKey(ValueKey('collection-open-${track.collectionId}'));
      await ioUntil(tester, () => open.evaluate().isNotEmpty);
      await tester.ensureVisible(open);
      await tester.pumpAndSettle();
      await tester.tap(open);
      await ioUntil(
          tester,
          () => find
              .byKey(ValueKey('track-row-${track.id}'))
              .evaluate()
              .isNotEmpty);
      if (width >= 1360) {
        final viewport = tester.getRect(find.descendant(
            of: find.byType(TrackTable), matching: find.byType(ListView)));
        final fourth =
            tester.getRect(find.byKey(ValueKey('track-row-${track.id + 3}')));
        expect(fourth.top, greaterThanOrEqualTo(viewport.top));
        expect(fourth.bottom, lessThanOrEqualTo(viewport.bottom));
        expect(
            tester.getCenter(find.byTooltip('Ouvir playlist')).dy,
            closeTo(
                tester.getCenter(find.byKey(const ValueKey('track-search'))).dy,
                4));
      }
      await tester.ensureVisible(find.byKey(ValueKey('track-row-${track.id}')));
      await tester.tap(find.byKey(ValueKey('track-row-${track.id}')));
      await ioUntil(tester, () => library.focused?.id == track.id);
      await tester.pumpAndSettle();
      final inspector = find.byType(TrackInspector);
      expect(inspector, findsOneWidget);
      expect(find.descendant(of: inspector, matching: find.text('Ouvir')),
          findsOneWidget);
      expect(player.playing, isTrue);
      expect(engine.opens.length, 1);
      if (Navigator.of(tester.element(inspector)).canPop()) {
        Navigator.of(tester.element(inspector)).pop();
        await tester.pumpAndSettle();
      }
      await tester
          .tap(find.descendant(of: nav, matching: find.text('Arquivos')));
      await tester.pumpAndSettle();
      expect(player.playing, isFalse);
      expect(find.byKey(const ValueKey('player-play-pause')), findsNothing);
      expect(player.queue.length, 4);
      await tester
          .tap(find.descendant(of: nav, matching: find.text('Músicas')));
      await tester.pumpAndSettle();
      expect(player.playing, isFalse);
      expect(find.byKey(const ValueKey('player-play-pause')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() => temp.delete(recursive: true));
    });
  }
}

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
import 'package:definitive_downloader/features/library/presentation/track_table.dart';
import 'package:definitive_downloader/features/library/presentation/collection_workspace.dart';
import 'package:definitive_downloader/features/matching/deezer_catalog.dart';
import 'package:definitive_downloader/features/player/application/music_player_controller.dart';
import 'package:definitive_downloader/features/workspace/presentation/download_action_button.dart';
import 'player_fixtures.dart';
import 'widget_io.dart';

class _PhoneFiles extends DesktopFiles {
  _PhoneFiles(this.path);
  final String path;
  @override
  Future<String> defaultOutputDirectory() async => path;
}

void main() {
  for (final size in [
    const Size(360, 640),
    const Size(844, 390),
    const Size(914, 411)
  ]) {
    testWidgets('coleção com player e teclado em $size', (tester) async {
      final report = FlutterError.onError;
      FlutterError.onError = (details) {
        debugPrint(details.toString());
        report?.call(details);
      };
      addTearDown(() => FlutterError.onError = report);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      late Directory temp;
      late LibraryController controller;
      await tester.runAsync(() async {
        temp = await Directory.systemTemp.createTemp('dd-phone-layout-');
        final repo = LibraryRepository(AppDatabase('${temp.path}/test.db'));
        controller = LibraryController(
            repository: repo,
            files: _PhoneFiles(temp.path),
            spotify: const SpotifyImporter(BoundedHttp()),
            csv: const CsvImporter(),
            catalog: const DeezerCatalog(BoundedHttp()),
            downloader: DownloadService(const BoundedHttp(), rootBundle));
        await controller.initialize();
        await repo.importCollection(ImportedCollection(
            name: 'Lista móvel',
            source: 'Fixture',
            sourceUrl: '',
            tracks: Stream.fromIterable(List.generate(30,
                (i) => TrackDraft(title: 'Música $i', artist: 'Artista')))));
        await controller.refresh();
      });
      final player = MusicPlayerController(
          MemoryPlayerLibrary(), FakeAudioEngine(), PlayerFiles());
      await tester.pumpWidget(
          DefinitiveDownloaderApp(controller: controller, player: player));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('mobile-destination-music')));
      await tester.pumpAndSettle();
      final collectionsScroll = find
          .descendant(
              of: find.byType(CollectionWorkspace),
              matching: find.byType(Scrollable))
          .first;
      if (find.text('Lista móvel').evaluate().isEmpty) {
        await tester.drag(collectionsScroll, const Offset(0, -180));
        await tester.pumpAndSettle();
      }
      await ioUntil(
          tester, () => find.text('Lista móvel').evaluate().isNotEmpty);
      await tester.ensureVisible(find.text('Lista móvel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lista móvel'));
      await ioUntil(
          tester, () => find.byType(TrackTable).evaluate().isNotEmpty);
      expect(
          find.ancestor(
              of: find.byType(TrackTable), matching: find.byType(ListView)),
          findsNothing);
      expect(tester.takeException(), isNull);
      tester.view.viewInsets = const FakeViewPadding(bottom: 220);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('music-player-bar')), findsNothing);
      expect(find.byKey(const ValueKey('track-search')), findsOneWidget);
      expect(tester.takeException(), isNull);
      tester.view.viewInsets = const FakeViewPadding();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Downloads'));
      await tester.pumpAndSettle();
      final toolbar = find.byKey(const ValueKey('download-mobile-actions'));
      final filters = find.byKey(const ValueKey('download-mobile-filters'));
      final search = find.byKey(const ValueKey('download-search-music'));
      final actions = find.descendant(
          of: toolbar, matching: find.byType(DownloadActionButton));
      expect(actions, findsNWidgets(8));
      final buttons = [
        for (var i = 0; i < 8; i++) tester.getRect(actions.at(i)),
      ];
      expect(
          buttons.every((button) => button.top == buttons.first.top), isTrue);
      expect(buttons.first.left, greaterThanOrEqualTo(0));
      expect(buttons.last.right, lessThanOrEqualTo(size.width));
      expect(buttons.first.top,
          greaterThanOrEqualTo(tester.getRect(search).bottom));
      expect(tester.widget<SingleChildScrollView>(filters).scrollDirection,
          Axis.horizontal);
      expect(tester.getRect(filters).top,
          greaterThanOrEqualTo(buttons.first.bottom));
      final header = tester
          .getRect(find.byKey(const ValueKey('download-horizontal-header')));
      final body =
          tester.getRect(find.byKey(const ValueKey('download-scroll-body')));
      expect(header.right, body.right);
      expect(header.bottom, body.top);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('download-search-music')));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 220);
      await tester.pumpAndSettle();
      expect(
          find.byKey(const ValueKey('download-search-music')), findsOneWidget);
      expect(
          tester
              .widget<EditableText>(find.descendant(
                  of: find.byKey(const ValueKey('download-search-music')),
                  matching: find.byType(EditableText)))
              .focusNode
              .hasFocus,
          isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      await tester.runAsync(() => temp.delete(recursive: true));
    });
  }
}

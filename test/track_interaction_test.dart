import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:definitive_downloader/app/theme.dart';
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
import 'package:definitive_downloader/features/matching/deezer_catalog.dart';
import 'widget_io.dart';
import 'package:definitive_downloader/features/workspace/data/workspace_repository.dart';

void main() {
  for (final width in [900.0, 390.0]) {
    testWidgets(
        'clique direito, Ctrl e arraste em grupo/entre páginas a ${width.toInt()}px',
        (tester) async {
      tester.view.physicalSize = Size(width, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late Directory temp;
      late LibraryController c;
      await tester.runAsync(() async {
        temp = await Directory.systemTemp.createTemp('dd-track-gesture-');
        final repo = LibraryRepository(AppDatabase('${temp.path}/library.db'));
        await repo.database.initialize();
        final id = await repo.importCollection(ImportedCollection(
            name: 'Gestos',
            source: 'Fixture',
            sourceUrl: '',
            tracks: Stream.fromIterable(List.generate(
                85,
                (i) => TrackDraft(
                    title: 'Faixa ${i + 1}',
                    artist: 'Pessoa',
                    mediaUrl: 'https://example.org/a.mp3',
                    sourceKind: SourceKind.directMp3)))));
        c = LibraryController(
            repository: repo,
            files: DesktopFiles(),
            spotify: const SpotifyImporter(BoundedHttp()),
            csv: const CsvImporter(),
            catalog: const DeezerCatalog(BoundedHttp()),
            downloader: DownloadService(const BoundedHttp(), rootBundle));
        await c.openCollection((await repo.collectionById(id))!);
      });
      await tester.pumpWidget(MaterialApp(
          theme: appTheme().copyWith(
              platform: width > 500
                  ? TargetPlatform.windows
                  : TargetPlatform.android),
          home: Scaffold(
              body: ListenableBuilder(
                  listenable: c,
                  builder: (_, __) =>
                      TrackTable(controller: c, onFocus: c.focus)))));
      await tester.pumpAndSettle();
      final original = c.page.items.map((t) => t.id).toList();
      Finder row(int id) => find.byKey(ValueKey('track-row-$id'));
      expect(find.byIcon(Icons.more_vert), findsNothing);
      await tester.tap(row(original[0]), buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar faixa'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('edit-track-position')), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      await tester.tap(row(original[0]));
      await ioUntil(tester, () => c.page.selectedCount == 1);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.tap(row(original[1]));
      await ioUntil(tester, () => c.page.selectedCount == 2);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      expect(c.page.items.take(2).every((t) => t.selected), isTrue);
      final gesture = await tester.startGesture(
          tester.getCenter(row(original[0])),
          kind:
              width > 500 ? PointerDeviceKind.mouse : PointerDeviceKind.touch);
      await tester.pump(const Duration(milliseconds: 350));
      await gesture.moveBy(const Offset(0, 12));
      await tester.pump();
      final target = find.byKey(ValueKey('drop-after-${original[3]}'));
      expect(target, findsOneWidget);
      await gesture.moveTo(tester.getCenter(target));
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.up();
      await ioUntil(
          tester, () => !c.editing && c.page.items.first.id == original[2]);
      expect(c.page.items.take(4).map((t) => t.id),
          [original[2], original[3], original[0], original[1]]);
      expect(
          c.page.items.map((t) => t.position), List.generate(40, (i) => i + 1));
      expect(c.page.selectedCount, 2);
      final unchanged = c.page.items.map((t) => t.id).toList();
      final cancel = await tester.startGesture(
          tester.getCenter(row(original[2])),
          kind: PointerDeviceKind.mouse);
      await tester.pump(const Duration(milliseconds: 350));
      await cancel.moveTo(Offset(width + 100, 20));
      await tester.pump();
      await cancel.up();
      await tester.pumpAndSettle();
      expect(c.page.items.map((t) => t.id), unchanged);
      final across = await tester.startGesture(
          tester.getCenter(row(original[2])),
          kind: PointerDeviceKind.mouse);
      await tester.pump(const Duration(milliseconds: 350));
      await across
          .moveTo(tester.getCenter(find.byKey(const ValueKey('track-page-1'))));
      await tester.pump(const Duration(milliseconds: 750));
      await ioUntil(
          tester, () => c.offset == 40 && c.page.items.first.position == 41);
      final destination = c.page.items.first;
      await across.moveTo(tester
          .getCenter(find.byKey(ValueKey('drop-before-${destination.id}'))));
      await tester.pump(const Duration(milliseconds: 100));
      await across.up();
      await ioUntil(
          tester,
          () =>
              !c.editing &&
              c.offset == 0 &&
              c.page.items.last.id == original[2]);
      expect(c.page.items.last.position, 40);
      expect(c.page.selectedCount, 2);
      expect(tester.takeException(), isNull);
      final future = c.page.items.take(3).toList();
      await tester.runAsync(() async {
        await WorkspaceRepository(c.repository.database)
            .claimNext(run: 'gesture-active', ids: [future[0].id]);
        c.downloading = true;
        await c.refresh();
      });
      await tester.pump();
      expect(find.byKey(ValueKey('drag-track-${future[0].id}')), findsNothing);
      expect(
          find.byKey(ValueKey('drag-track-${future[2].id}')), findsOneWidget);
      final pending = await tester.startGesture(
          tester.getCenter(row(future[2].id)),
          kind:
              width > 500 ? PointerDeviceKind.mouse : PointerDeviceKind.touch);
      await tester.pump(const Duration(milliseconds: 350));
      await pending.moveBy(const Offset(0, 12));
      await tester.pump();
      await pending.moveTo(tester
          .getCenter(find.byKey(ValueKey('drop-before-${future[1].id}'))));
      await tester.pump();
      await pending.up();
      await ioUntil(
          tester, () => !c.editing && c.page.items[1].id == future[2].id);
      expect(c.page.items.first.id, future[0].id);
      expect(c.page.items.first.position, 1);
      expect(c.downloading, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      await tester.runAsync(() => temp.delete(recursive: true));
    });
  }
}

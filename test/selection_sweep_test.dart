import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:definitive_downloader/app/theme.dart';
import 'package:definitive_downloader/core/storage/database.dart';
import 'package:definitive_downloader/core/platform/desktop_files.dart';
import 'package:definitive_downloader/core/network/bounded_http.dart';
import 'package:definitive_downloader/features/library/data/library_repository.dart';
import 'package:definitive_downloader/features/library/application/library_controller.dart';
import 'package:definitive_downloader/features/library/domain/models.dart';
import 'package:definitive_downloader/features/library/presentation/track_table.dart';
import 'package:definitive_downloader/features/importing/spotify_importer.dart';
import 'package:definitive_downloader/features/importing/csv_importer.dart';
import 'package:definitive_downloader/features/downloads/download_service.dart';
import 'package:definitive_downloader/features/matching/deezer_catalog.dart';
import 'package:definitive_downloader/features/workspace/domain/workspace_models.dart';
import 'package:definitive_downloader/features/workspace/domain/download_columns.dart';
import 'package:definitive_downloader/features/workspace/presentation/download_table.dart';
import 'widget_io.dart';

void main() {
  for (final width in [900.0, 390.0]) {
    testWidgets(
        'Ctrl arraste seleciona sem reordenar nas duas tabelas a ${width.toInt()}px',
        (tester) async {
      tester.view.physicalSize = Size(width, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late Directory temp;
      late LibraryController c;
      await tester.runAsync(() async {
        temp = await Directory.systemTemp.createTemp('dd-sweep-');
        final repo = LibraryRepository(AppDatabase('${temp.path}/library.db'));
        await repo.database.initialize();
        final id = await repo.importCollection(ImportedCollection(
            name: 'Gestos',
            source: 'Teste',
            sourceUrl: '',
            tracks: Stream.fromIterable(List.generate(
                80,
                (i) =>
                    TrackDraft(title: 'Faixa ${i + 1}', artist: 'Pessoa')))));
        c = LibraryController(
            repository: repo,
            files: DesktopFiles(),
            spotify: const SpotifyImporter(BoundedHttp()),
            csv: const CsvImporter(),
            catalog: const DeezerCatalog(BoundedHttp()),
            downloader: DownloadService(const BoundedHttp(), rootBundle));
        await c.openCollection((await repo.collectionById(id))!);
      });
      addTearDown(() async {
        c.dispose();
        await temp.delete(recursive: true);
      });
      await tester.pumpWidget(MaterialApp(
          theme: appTheme().copyWith(platform: TargetPlatform.windows),
          home: Scaffold(
              body: ListenableBuilder(
                  listenable: c,
                  builder: (_, __) =>
                      TrackTable(controller: c, onFocus: c.focus)))));
      await tester.pumpAndSettle();
      final ids = c.page.items.map((t) => t.id).toList();
      Finder row(int i) => find.byKey(ValueKey('track-row-${ids[i]}'));
      await tester.tap(row(0));
      await ioUntil(tester, () => c.focused?.id == ids[0]);
      expect(c.page.selectedCount, 0);
      await tester
          .tap(find.descendant(of: row(0), matching: find.byType(Checkbox)));
      await ioUntil(tester, () => c.page.selectedCount == 1);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      final drag = await tester.startGesture(tester.getCenter(row(0)),
          kind: PointerDeviceKind.mouse);
      await drag.moveTo(tester.getCenter(row(3)));
      await tester.pump(const Duration(milliseconds: 50));
      await drag.up();
      await ioUntil(tester, () => c.page.selectedCount == 4);
      expect(c.page.items.take(4).every((t) => t.selected), isTrue);
      expect(c.page.items.map((t) => t.id), ids);
      // Sweep upward adds all crossed rows as well.
      final up = await tester.startGesture(tester.getCenter(row(4)),
          kind: PointerDeviceKind.mouse);
      await up.moveTo(tester.getCenter(row(1)));
      await tester.pump();
      await up.up();
      await ioUntil(tester, () => c.page.selectedCount == 5);
      final edge = await tester.startGesture(tester.getCenter(row(3)),
          kind: PointerDeviceKind.mouse);
      final viewport = tester.getRect(find.byType(ListView));
      await edge.moveTo(Offset(viewport.center.dx, viewport.bottom - 8));
      await tester.pump(const Duration(milliseconds: 650));
      await edge.up();
      await ioUntil(tester, () => c.page.selectedCount > 8);
      expect(c.page.items.map((t) => t.id), ids);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      final selected = <int>{ids.last};
      final entries = [
        for (final t in c.page.items) DownloadEntry(t, 'Gestos')
      ];
      await tester.pumpWidget(MaterialApp(
          theme: appTheme(),
          home: Scaffold(
              body: StatefulBuilder(
                  builder: (context, setState) => DownloadTable(
                      entries: entries,
                      widths: downloadColumns.map((d) => d.width).toList(),
                      onResize: (_) {},
                      onResizeEnd: () {},
                      selection: selected,
                      onSelect: (id, v) => setState(
                          () => v ? selected.add(id) : selected.remove(id)),
                      onSelectMany: (ids) =>
                          setState(() => selected.addAll(ids)),
                      onSelectPage: (_) {},
                      output: '')))));
      await tester.pumpAndSettle();
      Finder download(int i) => find.byKey(ValueKey('download-row-${ids[i]}'));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      final downloadDrag = await tester.startGesture(
          Offset(150, tester.getCenter(download(0)).dy),
          kind: PointerDeviceKind.mouse);
      await downloadDrag.moveTo(Offset(150, tester.getCenter(download(4)).dy));
      await tester.pump();
      await downloadDrag.up();
      await tester.pump();
      expect(selected, containsAll([ids.last, ...ids.take(5)]));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}

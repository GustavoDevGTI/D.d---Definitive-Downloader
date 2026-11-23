import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:definitive_downloader/app/theme.dart';
import 'package:definitive_downloader/features/library/presentation/library_screen.dart';
import 'package:definitive_downloader/features/library/presentation/sidebar.dart';
import 'package:definitive_downloader/features/workspace/presentation/download_table.dart';
import 'package:definitive_downloader/features/workspace/presentation/download_workspace.dart';
import 'audio_capture_test.dart'
    show captureFixtureLibrary, CaptureFixtureEngine;
import 'widget_io.dart';

void main() {
  for (final size in [const Size(1366, 768), const Size(1024, 600)]) {
    testWidgets('Downloads compacto ocupa a janela ${size.width.toInt()}',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final directory = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('dd-density-')))!;
      final library = (await tester.runAsync(() async {
        final library = await captureFixtureLibrary(directory, CaptureFixtureEngine());
        await library.loadExample();
        await library.repository.database
            .run((db) => db.execute('UPDATE tracks SET queue_added=1'));
        return library;
      }))!;
      library.clearMessage();
      final boundaryKey = GlobalKey();
      final output = Platform.environment['DD_LAYOUT_OUTPUT'];
      if (output != null) {
        await (FontLoader('Manrope')
              ..addFont(rootBundle.load('assets/fonts/Manrope.ttf')))
            .load();
        await (FontLoader('MaterialIcons')
              ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
            .load();
      }
      await tester.pumpWidget(RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: appTheme().copyWith(platform: TargetPlatform.windows),
              home: LibraryScreen(controller: library))));
      await tester.tap(find.descendant(of: find.byType(LibrarySidebar), matching: find.text('Músicas')));
      await tester.pumpAndSettle();
      await tester.runAsync(() => tester.tap(find.text('Downloads')));
      await tester.pumpAndSettle();
      final workspace =
          tester.widget<DownloadWorkspace>(find.byType(DownloadWorkspace));
      await tester.runAsync(workspace.controller.refresh);
      await ioUntil(
          tester,
          () => find
              .byKey(const ValueKey('download-row-1'))
              .evaluate()
              .isNotEmpty);
      final table = tester.getRect(find.byType(DownloadTable));
      // The page now reserves 20 more pixels above its content.
      expect(table.height, greaterThan(size.height - 225));
      expect(table.left, lessThan(250));
      expect(size.width - table.right, lessThanOrEqualTo(15));
      final search =
          tester.getRect(find.byKey(const ValueKey('download-search-music')));
      final toolbar = tester.getRect(find.byType(DownloadToolbar));
      expect(search.height, lessThanOrEqualTo(40));
      expect(toolbar.height, lessThanOrEqualTo(44));
      expect(search.center.dy, closeTo(toolbar.center.dy, .1));
      expect(
          tester
              .getSize(find.byKey(const ValueKey('download-table-header')))
              .height,
          32);
      expect(
          tester.getSize(find.byKey(const ValueKey('download-row-1'))).height,
          40);
      expect(tester.takeException(), isNull);
      if (output != null) {
        await tester.runAsync(() async {
          final boundary = boundaryKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory(output).create(recursive: true);
          await File('$output/download-density-${size.width.toInt()}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox.shrink());
      library.dispose();
      await tester.runAsync(() => directory.delete(recursive: true));
    });
  }
}

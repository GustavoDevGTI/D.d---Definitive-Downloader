import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:definitive_downloader/app/theme.dart';
import 'package:definitive_downloader/features/library/domain/models.dart';
import 'package:definitive_downloader/features/workspace/domain/download_columns.dart';
import 'package:definitive_downloader/features/workspace/domain/workspace_models.dart';
import 'package:definitive_downloader/features/workspace/presentation/download_table.dart';

DownloadEntry entry(int i) => DownloadEntry(
    Track(
        id: i,
        collectionId: 1,
        position: i,
        title: 'Faixa de nome longo número $i',
        artist: 'Pessoa',
        album: '',
        durationMs: 180000,
        isrc: '',
        coverUrl: '',
        sourceUrl: '',
        mediaUrl: 'https://example.org/$i.mp3',
        sourceKind: SourceKind.directMp3,
        status: TrackStatus.ready,
        selected: false,
        localPath: '',
        error: '',
        resolvedTitle: '',
        resolvedArtist: ''),
    'Fixture');

Future<void> expectHandleBackground(
    WidgetTester tester, GlobalKey key, Finder handle) async {
  final point = tester.getCenter(handle) -
      tester.getTopLeft(find.byKey(key)) -
      const Offset(8, 0);
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final img = await boundary.toImage();
    try {
      final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      final offset = (point.dy.floor() * img.width + point.dx.floor()) * 4;
      final bytes = data!.buffer.asUint8List();
      final color = Color.fromARGB(bytes[offset + 3], bytes[offset],
          bytes[offset + 1], bytes[offset + 2]);
      expect(color, AppColors.navigation,
          reason:
              'Foco da divisória não pode cobrir o cabeçalho com um bloco claro.');
    } finally {
      img.dispose();
    }
  });
}

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  final output = Platform.environment['DD_LAYOUT_OUTPUT'];
  if (output == null) return;
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final img = await boundary.toImage();
    try {
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      await Directory(output).create(recursive: true);
      await File('$output/$name.png').writeAsBytes(data!.buffer.asUint8List());
    } finally {
      img.dispose();
    }
  });
}

void main() {
  for (final width in [1100.0, 390.0]) {
    testWidgets(
        'cabeçalho permanece fixo e tabela ocupa largura disponível a $width px',
        (tester) async {
      tester.view.physicalSize = Size(width, 500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final captureKey = GlobalKey();
      if (Platform.environment['DD_LAYOUT_OUTPUT'] != null) {
        await (FontLoader('Manrope')
              ..addFont(rootBundle.load('assets/fonts/Manrope.ttf')))
            .load();
        await (FontLoader('MaterialIcons')
              ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
            .load();
      }
      final widths = downloadColumns.map((c) => c.minimum).toList();
      await tester.pumpWidget(RepaintBoundary(
          key: captureKey,
          child: MaterialApp(
              theme: appTheme(),
              home: Scaffold(
                  body: DownloadTable(
                      entries: List.generate(40, (i) => entry(i + 1)),
                      widths: widths,
                      onResize: (_) {},
                      onResizeEnd: () {},
                      selection: const {},
                      onSelect: (_, value) {},
                      onSelectPage: (_) {},
                      output: 'C:/Fixture')))));
      await tester.pumpAndSettle();
      final header = find.byKey(const ValueKey('download-table-header'));
      final before = tester.getRect(header);
      await capture(tester, captureKey, 'table-top-${width.toInt()}');
      if (width > 600) expect(before.width, closeTo(width - 12, .01));
      expect(find.byKey(const ValueKey('download-row-1')), findsOneWidget);
      await tester.drag(
          find.byKey(const ValueKey('download-rows')), const Offset(0, -900));
      await tester.pumpAndSettle();
      expect(tester.getRect(header), before);
      await capture(tester, captureKey, 'table-scrolled-${width.toInt()}');
      expect(find.byKey(const ValueKey('download-row-1')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  for (final width in [1100.0, 390.0]) {
    testWidgets(
        'divisória acompanha ida e volta e respeita vizinha a $width px',
        (tester) async {
      tester.view.physicalSize = Size(width, 500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var widths = downloadColumns.map((c) => c.minimum).toList();
      widths[1] = 200;
      widths[2] = 140;
      var saves = 0;
      final captureKey = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
          key: captureKey,
          child: MaterialApp(
              theme: appTheme(),
              home: Scaffold(
                  body: StatefulBuilder(
                      builder: (context, setState) => DownloadTable(
                          entries: [entry(1)],
                          widths: widths,
                          onResize: (values) => setState(() => widths = values),
                          onResizeEnd: () => saves++,
                          selection: const {},
                          onSelect: (_, value) {},
                          onSelectPage: (_) {},
                          output: 'C:/Fixture'))))));
      await tester.pumpAndSettle();
      final handle = find.byKey(const ValueKey('resize-download-name'));
      var gesture = await tester.startGesture(tester.getCenter(handle));
      await gesture.moveBy(const Offset(30, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(10, 0));
      await tester.pump();
      await expectHandleBackground(tester, captureKey, handle);
      await capture(tester, captureKey, 'table-resize-drag-${width.toInt()}');
      final start = widths[1], right = widths[2];
      final position = tester.getCenter(handle).dx;
      final total = widths.fold<double>(0, (a, b) => a + b);
      await gesture.moveBy(const Offset(30, 0));
      await tester.pump();
      expect(widths[1], closeTo(start + 30, .01));
      expect(widths[2], closeTo(right - 30, .01));
      expect(tester.getCenter(handle).dx, closeTo(position + 30, .01));
      await gesture.moveBy(const Offset(-60, 0));
      await tester.pump();
      expect(widths[1], closeTo(start - 30, .01));
      expect(widths[2], closeTo(right + 30, .01));
      expect(tester.getCenter(handle).dx, closeTo(position - 30, .01));
      expect(widths.fold<double>(0, (a, b) => a + b), closeTo(total, .01));
      await gesture.up();
      await tester.pumpAndSettle();
      await expectHandleBackground(tester, captureKey, handle);
      await capture(tester, captureKey, 'table-resize-focus-${width.toInt()}');
      gesture = await tester.startGesture(tester.getCenter(handle));
      await gesture.moveBy(const Offset(30, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(1500, 0));
      await tester.pump();
      expect(widths[2], downloadColumns[2].minimum);
      expect(widths[1], 1200,
          reason: 'Vizinha no mínimo não deve impedir ampliar a tabela.');
      expect(widths.fold<double>(0, (a, b) => a + b), greaterThan(total));
      final limit = widths[1];
      await gesture.moveBy(const Offset(-25, 0));
      await tester.pump();
      expect(widths[1], closeTo(limit - 25, .01));
      expect(widths[2], downloadColumns[2].minimum + 25);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(saves, 2);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'filtro vazio mantém cabeçalho sem mensagem ou seleção disponível',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: appTheme(),
        home: Scaffold(
            body: DownloadTable(
                entries: const [],
                widths: downloadColumns.map((c) => c.width).toList(),
                onResize: (_) {},
                onResizeEnd: () {},
                selection: const {},
                onSelect: (_, value) {},
                onSelectPage: (_) {},
                output: ''))));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('download-table-header')), findsOneWidget);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).onChanged, isNull);
    expect(find.text('Nenhum download neste filtro'), findsNothing);
    expect(find.text('Nome'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

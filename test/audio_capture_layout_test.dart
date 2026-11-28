import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:definitive_downloader/app/theme.dart';
import 'package:definitive_downloader/features/audio_capture/presentation/audio_capture_panel.dart';
import 'package:definitive_downloader/features/library/application/library_controller.dart';
import 'audio_capture_test.dart'
    show CaptureFixtureEngine, captureFixture, captureFixtureLibrary;
import 'widget_io.dart';

void main() {
  for (final width in [320.0, 1360.0]) {
    testWidgets(
        'captura analisa, seleciona e envia à fila em ${width.toInt()}px',
        (tester) async {
      tester.view.physicalSize = Size(width, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late Directory directory;
      late LibraryController library;
      final output = Platform.environment['DD_LAYOUT_OUTPUT'];
      await tester.runAsync(() async {
        directory = await Directory.systemTemp.createTemp('dd-capture-ui-');
        library =
            await captureFixtureLibrary(directory, CaptureFixtureEngine());
      });
      if (output != null) {
        await (FontLoader('Manrope')
              ..addFont(rootBundle.load('assets/fonts/Manrope.ttf')))
            .load();
        await (FontLoader('MaterialIcons')
              ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
            .load();
      }
      final key = GlobalKey();
      var openedDownloads = false;
      try {
        await tester.pumpWidget(RepaintBoundary(
            key: key,
            child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: appTheme(),
                home: Scaffold(
                    body: Padding(
                        padding: const EdgeInsets.all(16),
                        child: AudioCapturePanel(
                            library: library,
                            onDownloads: () => openedDownloads = true))))));
        await tester.enterText(find.byKey(const ValueKey('capture-url-music')),
            'https://example.org/page');
        await tester.runAsync(() =>
            tester.tap(find.byKey(const ValueKey('capture-analyze-music'))));
        final first = find
            .byKey(ValueKey('captured-audio-${captureFixture(1)['sourceId']}'));
        await ioUntil(tester, () => first.evaluate().isNotEmpty);
        expect(library.collections, isEmpty);
        // The row does not toggle; only its checkbox does.
        await tester.ensureVisible(first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Áudio 1'));
        await tester.pumpAndSettle();
        expect(find.text('2 de 2 selecionados'), findsOneWidget);
        await tester
            .tap(find.descendant(of: first, matching: find.byType(Checkbox)));
        await tester.pumpAndSettle();
        expect(find.text('1 de 2 selecionados'), findsOneWidget);
        expect(find.byKey(const ValueKey('destination-path')), findsOneWidget);
        expect(find.byKey(const ValueKey('capture-save-playlist')),
            findsOneWidget);
        expect(
            find.byKey(const ValueKey('capture-add-playlist')), findsOneWidget);
        if (output != null) {
          await tester.runAsync(() async {
            final boundary =
                key.currentContext!.findRenderObject() as RenderRepaintBoundary;
            final image = await boundary.toImage();
            final bytes =
                await image.toByteData(format: ui.ImageByteFormat.png);
            await Directory(output).create(recursive: true);
            await File('$output/audio-capture-${width.toInt()}.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.ensureVisible(
            find.byKey(const ValueKey('capture-download-selected')));
        await tester.pumpAndSettle();
        await tester.runAsync(() => tester
            .tap(find.byKey(const ValueKey('capture-download-selected'))));
        await ioUntil(tester, () => openedDownloads && !library.downloading);
        await tester.runAsync(() async {
          final tracks =
              (await library.repository.page(library.current!.id)).items;
          expect(tracks, hasLength(1));
          expect(tracks.single.title, 'Áudio 2');
          expect(await File(tracks.single.localPath).exists(), isTrue);
          expect(File(tracks.single.localPath).parent.path,
              endsWith('${Platform.pathSeparator}Áudio 2'));
        });
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        library.dispose();
        await tester.runAsync(() => directory.delete(recursive: true));
      }
    });
  }
}

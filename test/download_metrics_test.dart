import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:definitive_downloader/app/theme.dart';
import 'package:definitive_downloader/features/downloads/transfer_progress.dart';
import 'package:definitive_downloader/features/workspace/domain/download_columns.dart';
import 'package:definitive_downloader/features/workspace/domain/workspace_models.dart';
import 'package:definitive_downloader/features/workspace/presentation/download_table.dart';
import 'download_table_layout_test.dart' show entry, capture;

void main() {
  for (final width in [1360.0, 390.0]) {
    testWidgets('medições reais, pausa e processamento a $width px',
        (tester) async {
      tester.view.physicalSize = Size(width, 500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      if (Platform.environment['DD_LAYOUT_OUTPUT'] != null) {
        await (FontLoader('Manrope')
              ..addFont(rootBundle.load('assets/fonts/Manrope.ttf')))
            .load();
      }
      var transfer = const TransferProgress(
          received: 1024, total: 8192, bytesPerSecond: 1024);
      var paused = false;
      late StateSetter update;
      final key = GlobalKey();
      final completed =
          entry(2, downloadedAt: DateTime.utc(2026, 11, 4, 15, 5, 18));
      await tester.pumpWidget(RepaintBoundary(
          key: key,
          child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: appTheme(),
              home:
                  Scaffold(body: StatefulBuilder(builder: (context, setState) {
                update = setState;
                return DownloadTable(
                    entries: [
                      entry(1),
                      DownloadEntry(completed.track, completed.collectionName,
                          downloadedAt: completed.downloadedAt, fileBytes: 4096)
                    ],
                    widths: downloadColumns.map((c) => c.width).toList(),
                    onResize: (_) {},
                    onResizeEnd: () {},
                    selection: const {},
                    onSelect: (id, selected) {},
                    onSelectPage: (_) {},
                    activeId: 1,
                    transfer: transfer,
                    progress: transfer.fraction,
                    paused: paused,
                    output: 'C:/Fixture');
              })))));
      await tester.pump();
      expect(find.text('8.0 KiB'), findsOneWidget);
      expect(find.text('1.0 KiB/s'), findsOneWidget);
      expect(find.text('1.0 KiB'), findsOneWidget);
      expect(find.text('4.0 KiB'), findsNWidgets(2));
      expect(find.text('7s'), findsOneWidget);
      expect(find.text('Faixa de nome longo número 1'), findsOneWidget);
      expect(find.text('Pessoa'), findsNWidgets(2));
      await capture(tester, key, 'download-metrics-${width.toInt()}');
      update(() => paused = true);
      await tester.pump();
      expect(find.text('7s'), findsNothing);
      expect(find.text('1.0 KiB/s'), findsNothing);
      update(() {
        paused = false;
        transfer = transfer.asProcessing();
      });
      await tester.pump();
      expect(find.text('Processando'), findsOneWidget);
      expect(find.text('7s'), findsNothing);
      expect(find.text('1.0 KiB'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:definitive_downloader/app/theme.dart';
import 'package:definitive_downloader/features/library/domain/models.dart';
import 'package:definitive_downloader/features/workspace/domain/download_columns.dart';
import 'package:definitive_downloader/features/workspace/domain/workspace_models.dart';
import 'package:definitive_downloader/features/workspace/presentation/download_table.dart';

void main() {
  for (final width in [1100.0, 390.0]) {
    testWidgets(
        'barra vertical chega ao fim e última linha fica inteira a ${width.toInt()}px',
        (tester) async {
      tester.view.physicalSize = Size(width, 500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final entries = List.generate(
          40,
          (i) => DownloadEntry(
              Track(
                  id: i + 1,
                  collectionId: 1,
                  position: i + 1,
                  title: 'Faixa ${i + 1}',
                  artist: 'Pessoa',
                  album: '',
                  durationMs: 1000,
                  isrc: '',
                  coverUrl: '',
                  sourceUrl: '',
                  mediaUrl: '',
                  sourceKind: SourceKind.none,
                  status: TrackStatus.pending,
                  selected: false,
                  localPath: '',
                  error: '',
                  resolvedTitle: '',
                  resolvedArtist: ''),
              'Fixture'));
      await tester.pumpWidget(MaterialApp(
          theme: appTheme().copyWith(platform: TargetPlatform.windows),
          home: Scaffold(
              body: DownloadTable(
                  entries: entries,
                  widths: downloadColumns.map((c) => c.width).toList(),
                  onResize: (_) {},
                  onResizeEnd: () {},
                  selection: const {},
                  onSelect: (_, __) {},
                  onSelectPage: (_) {},
                  output: 'C:/Music'))));
      await tester.pumpAndSettle();
      final rows = find.byKey(const ValueKey('download-rows'));
      final controller = tester.widget<ListView>(rows).controller!;
      final bar = find.byWidgetPredicate(
          (w) => w is RawScrollbar && w.controller == controller);
      final state = tester.state<RawScrollbarState>(bar);
      final barRect = tester.getRect(bar);
      final bodyRect = tester.getRect(rows);
      // The inset belongs to the body. It must not subtract the header again
      // or prevent dragging through the full row viewport.
      final bottom =
          Offset(barRect.width - 5, bodyRect.bottom - barRect.top - 11);
      // Inspect painter geometry only in this regression test.
      expect(
          // ignore: invalid_use_of_protected_member
          state.scrollbarPainter
              .hitTestInteractive(bottom, PointerDeviceKind.mouse),
          isTrue);
      var thumb = Offset.zero;
      for (var y = 0.0; y < barRect.height; y += 1) {
        final point = Offset(barRect.width - 5, y);
        // ignore: invalid_use_of_protected_member
        if (state.scrollbarPainter
            .hitTestOnlyThumbInteractive(point, PointerDeviceKind.mouse)) {
          thumb = point;
          break;
        }
      }
      final gesture = await tester.startGesture(
          barRect.topLeft + thumb + const Offset(0, 5),
          kind: PointerDeviceKind.mouse);
      await gesture.moveTo(Offset(barRect.right - 5, bodyRect.bottom - 2));
      await tester.pumpAndSettle();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(
          controller.offset, closeTo(controller.position.maxScrollExtent, 1));
      final last =
          tester.getRect(find.byKey(const ValueKey('download-row-40')));
      expect(last.bottom, lessThanOrEqualTo(bodyRect.bottom + .1));
      expect(last.top, greaterThanOrEqualTo(bodyRect.top));
      final header = find.byKey(const ValueKey('download-column-name'));
      final headerBefore = tester.getRect(header);
      final horizontal = tester
          .widget<SingleChildScrollView>(
              find.byKey(const ValueKey('download-horizontal-rows')))
          .controller!;
      horizontal.jumpTo(horizontal.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(tester.getRect(header).left,
          closeTo(headerBefore.left - horizontal.offset, .1));
      expect(tester.getRect(header).top, headerBefore.top);
      expect(tester.getRect(bar), barRect);
      expect(
          controller.offset, closeTo(controller.position.maxScrollExtent, 1));
      expect(tester.takeException(), isNull);
    });
  }
}

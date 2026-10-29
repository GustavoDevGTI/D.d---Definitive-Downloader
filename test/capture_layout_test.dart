import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:definitive_downloader/app/theme.dart';
import 'package:definitive_downloader/features/workspace/domain/workspace_models.dart';
import 'package:definitive_downloader/features/workspace/presentation/capture_workspace.dart';

void main() {
  for (final size in [
    const Size(320, 400),
    const Size(900, 360),
    const Size(1360, 600)
  ]) {
    testWidgets(
        'captura mantém espaçamento e rolagem em ${size.width.toInt()}x${size.height.toInt()}',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
          theme: appTheme(),
          home: const Scaffold(
              body: Padding(
                  padding: EdgeInsets.all(16),
                  child: CaptureWorkspace(category: ContentCategory.media)))));
      await tester.pumpAndSettle();
      final input =
          tester.getRect(find.byKey(const ValueKey('capture-url-media')));
      final button =
          tester.getRect(find.byKey(const ValueKey('capture-analyze-media')));
      expect(input.overlaps(button), isFalse);
      expect(button.top, greaterThan(input.bottom + 6));
      expect(
          tester
              .widget<OutlinedButton>(
                  find.widgetWithText(OutlinedButton, 'Analisar link'))
              .onPressed,
          isNull);
      await tester.scrollUntilVisible(
          find.textContaining('A captura de páginas, escolha'), 120,
          scrollable: find
              .descendant(
                  of: find.byType(ListView), matching: find.byType(Scrollable))
              .first);
      expect(
          find.textContaining('ainda não estão disponíveis'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

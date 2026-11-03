import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:definitive_downloader/app/theme.dart';
import 'package:definitive_downloader/features/workspace/presentation/download_action_button.dart';

void main() {
  testWidgets('hover e pressão animam sem consumir o clique', (tester) async {
    var clicks = 0;
    await tester.pumpWidget(MaterialApp(
        theme: appTheme(),
        home: Scaffold(
            body: Center(
                child: DownloadActionButton(
                    icon: Icons.add_link,
                    label: 'Adicionar',
                    onPressed: () => clicks++)))));
    final button = find.byType(IconButton);
    final initial = tester.getRect(button).width;
    final mouse = await tester.createGesture(kind: ui.PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(button));
    await tester.pumpAndSettle();
    expect(tester.getRect(button).width, greaterThan(initial));
    await mouse.down(tester.getCenter(button));
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump(const Duration(milliseconds: 180));
    expect(tester.getRect(button).width, lessThan(initial));
    await mouse.up();
    await tester.pumpAndSettle();
    expect(clicks, 1);
    await mouse.removePointer();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(tester.getRect(button).width, closeTo(initial, .01));
    expect(tester.takeException(), isNull);
  });
  testWidgets('movimento reduzido e botão desabilitado mantêm a geometria',
      (tester) async {
    for (final reduced in [false, true]) {
      await tester.pumpWidget(MaterialApp(
          theme: appTheme(),
          home: MediaQuery(
              data: MediaQueryData(disableAnimations: reduced),
              child: Scaffold(
                  body: Center(
                      child: DownloadActionButton(
                          icon: Icons.add_link,
                          label: 'Adicionar',
                          onPressed: reduced ? () {} : null))))));
      await tester.pumpAndSettle();
      final button = find.byType(IconButton);
      final initial = tester.getRect(button).width;
      final mouse =
          await tester.createGesture(kind: ui.PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(button));
      await tester.pumpAndSettle();
      expect(tester.getRect(button).width, closeTo(initial, .01));
      await mouse.removePointer();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}

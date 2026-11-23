import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:definitive_downloader/app/theme.dart';
import 'package:definitive_downloader/features/workspace/presentation/download_action_button.dart';

void main() {
  testWidgets(
    'hover conserva espaço e pressão responde sem consumir o clique',
    (tester) async {
      var clicks = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(),
          home: Scaffold(
            body: Center(
              child: DownloadActionButton(
                icon: Icons.add_link,
                label: 'Adicionar',
                onPressed: () => clicks++,
              ),
            ),
          ),
        ),
      );
      final button = find.byType(IconButton);
      final initial = tester.getRect(button).width;
      final mouse = await tester.createGesture(
        kind: ui.PointerDeviceKind.mouse,
      );
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(button));
      await tester.pumpAndSettle();
      expect(tester.getRect(button).width, closeTo(initial, .01));
      expect(
        tester.widget<IconButton>(button).statesController!.value,
        contains(WidgetState.hovered),
      );
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
    },
  );
  testWidgets('foco e ativação por teclado não movimentam o botão', (
    tester,
  ) async {
    var clicks = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        home: Scaffold(
          body: DownloadActionButton(
            icon: Icons.add_link,
            label: 'Adicionar',
            onPressed: () => clicks++,
          ),
        ),
      ),
    );
    final button = find.byType(IconButton);
    final initial = tester.getRect(button);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(
      tester.widget<IconButton>(button).statesController!.value,
      contains(WidgetState.focused),
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    await tester.pump(const Duration(milliseconds: 180));
    expect(tester.getRect(button), initial);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(clicks, 1);
    expect(tester.getRect(button), initial);
  });
  testWidgets('movimento reduzido e botão desabilitado mantêm a geometria', (
    tester,
  ) async {
    for (final reduced in [false, true]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(),
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: Scaffold(
              body: Center(
                child: DownloadActionButton(
                  icon: Icons.add_link,
                  label: 'Adicionar',
                  onPressed: reduced ? () {} : null,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final button = find.byType(IconButton);
      final initial = tester.getRect(button).width;
      final mouse = await tester.createGesture(
        kind: ui.PointerDeviceKind.mouse,
      );
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(button));
      await tester.pumpAndSettle();
      await mouse.down(tester.getCenter(button));
      await tester.pump(const Duration(milliseconds: 180));
      expect(tester.getRect(button).width, closeTo(initial, .01));
      await mouse.up();
      await mouse.removePointer();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}

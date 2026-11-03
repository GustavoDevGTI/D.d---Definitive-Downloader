import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:definitive_downloader/features/workspace/presentation/column_resize_handle.dart';

void main() {
  testWidgets(
      'redimensionamento acumula arraste, aceita teclado e restaura com duplo clique',
      (tester) async {
    var width = 300.0, saves = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: StatefulBuilder(
                builder: (context, setState) => Align(
                    alignment: Alignment.topLeft,
                    child: ColumnResizeHandle(
                        label: 'Nome',
                        width: width,
                        defaultWidth: 300,
                        minimumWidth: 140,
                        onResize: (value) =>
                            setState(() => width = value.clamp(140, 1200)),
                        onEnd: () => saves++))))));
    final handle = find.byType(ColumnResizeHandle);
    await tester.drag(handle, const Offset(160, 0));
    await tester.pump();
    expect(width, greaterThan(420));
    expect(saves, 1);
    final gesture =
        find.descendant(of: handle, matching: find.byType(GestureDetector));
    Focus.of(tester.element(gesture)).requestFocus();
    await tester.pump();
    final before = width;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(width, before + 20);
    await tester.tap(handle);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(handle);
    await tester.pumpAndSettle();
    expect(width, 300);
    expect(tester.takeException(), isNull);
  });
}

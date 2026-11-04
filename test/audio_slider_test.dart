import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:definitive_downloader/features/player/presentation/audio_slider.dart';

void main() {
  testWidgets(
      'volume contínuo por gesto, teclado e leitor de tela, inclusive após modal',
      (tester) async {
    final semantics = tester.ensureSemantics();
    var value = .5;
    final commits = <double>[];
    late StateSetter update;
    const key = ValueKey('continuous-audio');
    await tester.pumpWidget(
        MaterialApp(home: StatefulBuilder(builder: (context, setState) {
      update = setState;
      return Scaffold(
          body: Column(children: [
        SizedBox(
            width: 300,
            child: AudioSlider(
                key: key,
                value: value,
                label: 'Volume',
                describe: (v) => '${(v * 100).round()}%',
                activeColor: Colors.pink,
                onChanged: (v) => setState(() => value = v),
                onChangeEnd: commits.add)),
        TextButton(
            onPressed: () => showModalBottomSheet<void>(
                context: context,
                builder: (context) => TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Fechar'))),
            child: const Text('Fila'))
      ]));
    })));
    final box = tester.getRect(find.byKey(key));
    await tester
        .tapAt(Offset(box.left + 8 + (box.width - 16) * .713, box.center.dy));
    await tester.pump();
    expect(value, closeTo(.713, .001));
    expect(commits.last, closeTo(.713, .001));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(value, closeTo(.763, .001));
    final node = tester.getSemantics(find.byKey(key));
    expect(node.getSemanticsData().label, 'Volume');
    expect(node.getSemanticsData().value, '76%');
    node.owner!.performAction(node.id, ui.SemanticsAction.decrease);
    await tester.pump();
    expect(value, closeTo(.713, .001));
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Fila'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fechar'));
      await tester.pumpAndSettle();
      expect(tester.getSemantics(find.byKey(key)).getSemanticsData().label,
          'Volume');
    }
    update(() => value = .99);
    await tester.pump();
    await tester.tapAt(box.center);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump();
    expect(value, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(value, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pump();
    expect(value, 0);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}

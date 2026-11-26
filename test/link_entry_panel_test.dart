import 'package:definitive_downloader/features/workspace/presentation/link_entry_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _panel({required bool busy, String? label}) => MaterialApp(
    home: Scaffold(
        body: LinkEntryPanel(
            title: 'Importar playlist',
            fieldLabel: 'Link da playlist ou faixa',
            hintText: '',
            controller: TextEditingController(),
            inputKey: const ValueKey('url'),
            actionLabel: busy ? 'Importando…' : 'Importar por link',
            actionIcon: Icons.playlist_add_rounded,
            onAction: busy ? null : () {},
            busy: busy,
            busyLabel: label)));

void main() {
  testWidgets('importação em andamento mostra barra e progresso',
      (tester) async {
    await tester.pumpWidget(_panel(busy: true, label: 'Lendo faixas: 12/40'));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Lendo faixas: 12/40'), findsOneWidget);
    expect(find.text('Importando…'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sem importação não há indicador nem texto vazio',
      (tester) async {
    await tester.pumpWidget(_panel(busy: false));
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await tester.pumpWidget(_panel(busy: true, label: '  '));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('  '), findsNothing);
  });
}

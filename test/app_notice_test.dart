import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:definitive_downloader/app/app_notice.dart';
import 'package:definitive_downloader/app/theme.dart';

void main() {
  for (final width in [1360.0, 390.0]) {
    testWidgets(
        'aviso central sem duplicação, repetível e sem popup de progresso a $width px',
        (tester) async {
      tester.view.physicalSize = Size(width, 820);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final signal = ValueNotifier(0);
      var message = '', busy = false;
      void update(String value) {
        message = value;
        signal.value++;
      }

      await tester.pumpWidget(MaterialApp(
          theme: appTheme(),
          home: AppNoticeHost(
              listenable: signal,
              readMessage: () => busy ? '' : message,
              acknowledge: (_) {
                message = '';
                signal.value++;
              },
              child: const Scaffold(body: Text('App')))));
      busy = true;
      update('Lendo a coleção…');
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      busy = false;
      update('Confira o link.');
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Confira o link.'), findsOneWidget);
      expect(tester.getRect(find.text('Confira o link.')).center.dy,
          inInclusiveRange(250, 570));
      signal.value++;
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      update('Segundo aviso.');
      await tester.pumpAndSettle();
      expect(find.text('Segundo aviso.'), findsNothing);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('Segundo aviso.'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      update('Confira o link.');
      await tester.pumpAndSettle();
      expect(find.text('Confira o link.'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      signal.dispose();
    });
  }
}

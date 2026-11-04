import 'package:flutter_test/flutter_test.dart';

Future<void> ioUntil(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 600; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump(const Duration(milliseconds: 30));
    if (ready()) {
      await tester.pumpAndSettle();
      return;
    }
  }
  expect(ready(), isTrue,
      reason: 'A operação local não terminou no limite do teste.');
}

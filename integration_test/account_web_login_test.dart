import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:definitive_downloader/features/connections/data/deezer_web_login.dart';

// Native WebView/cookie contract only. A synthetic HttpOnly cookie is created
// inside the fresh test login profile; this does not authenticate any account.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('sessão do próprio login é capturada e removida sem campo ARL', (tester) async {
    final login = DeezerWebLogin();
    final created = Completer<InAppWebViewController>();
    await login.initialize();
    try {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: InAppWebView(
          webViewEnvironment: login.environment,
          initialData: InAppWebViewInitialData(data: '<!doctype html><title>D.d fixture</title><p>Login fixture</p>'),
          initialSettings: InAppWebViewSettings(incognito: true),
          onWebViewCreated: (view) { if (!created.isCompleted) created.complete(view); }))));
      final view = await created.future.timeout(const Duration(seconds: 30));
      await login.begin(view: view);
      final cookies = CookieManager.instance(webViewEnvironment: login.environment);
      expect(await login.observe(Uri.parse('https://www.deezer.com/')), isNull);
      final synthetic = 'ddFixture' * 24;
      await cookies.setCookie(url: DeezerWebLogin.cookieUrl, name: 'arl', value: synthetic,
          domain: '.deezer.com', isSecure: true, isHttpOnly: true, webViewController: view);
      expect(await login.observe(Uri.parse('https://deezer.com.evil.test/')), isNull);
      expect(await login.observe(Uri.parse('https://www.deezer.com/')), synthetic);
      await login.begin();
      expect(await login.observe(Uri.parse('https://www.deezer.com/')), isNull);
      expect(find.byType(TextField), findsNothing);
      debugPrint('DD_LOGIN_COOKIE_FIXTURE verified; no real account used');
    } finally {
      await tester.pumpWidget(const SizedBox());
      await login.close();
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}

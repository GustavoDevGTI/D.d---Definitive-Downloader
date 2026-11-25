import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../features/connections/data/deezer_web_login.dart';
import '../../features/connections/presentation/deezer_login_controls.dart';

/// Windows-only native contract probe. No library, vault or real account.
Future<int> diagnoseWebLogin() async {
  final login = DeezerWebLogin(), done = Completer<int>();
  try {
    await login.initialize();
    runApp(MaterialApp(
        home: Scaffold(
            body: InAppWebView(
                webViewEnvironment: login.environment,
                initialSettings: InAppWebViewSettings(incognito: true),
                initialData: InAppWebViewInitialData(
                    data: '''<!doctype html><title>D.d</title>
                        <button id="email" onclick="window.emailClicks=(window.emailClicks||0)+1">Entrar</button>
                        <button id="google" onclick="window.socialClicks=1"><span>Google</span></button>
                        <a id="facebook" href="https://www.facebook.com/">Facebook</a>'''),
                onLoadStop: (view, _) async {
                  try {
                    // Windows NavigateToString uses about:blank. Exercise the
                    // same installer body on this isolated document, without
                    // weakening the production HTTPS/origin guard.
                    await view.evaluateJavascript(
                        source: '($deezerLoginControlInstaller)()');
                    await view.evaluateJavascript(source: r'''
                      document.body.insertAdjacentHTML('beforeend',
                        '<button id="apple"><span>Apple</span></button>');
                    ''');
                    await Future<void>.delayed(
                        const Duration(milliseconds: 50));
                    final controls = await view.evaluateJavascript(source: r'''
                      (() => {
                        const google=document.getElementById('google');
                        const facebook=document.getElementById('facebook');
                        const apple=document.getElementById('apple');
                        google.querySelector('span').dispatchEvent(
                          new MouseEvent('click',{bubbles:true,cancelable:true}));
                        document.getElementById('email').click();
                        return google.disabled && apple.disabled &&
                          facebook.getAttribute('aria-disabled')==='true' &&
                          facebook.tabIndex===-1 && !window.socialClicks &&
                          window.emailClicks===1;
                      })()
                    ''');
                    await login.begin(view: view);
                    final cookies = CookieManager.instance(
                        webViewEnvironment: login.environment);
                    final fixture = 'ddFixture' * 24;
                    await cookies.setCookie(
                        url: DeezerWebLogin.cookieUrl,
                        name: 'arl',
                        value: fixture,
                        domain: '.deezer.com',
                        isSecure: true,
                        isHttpOnly: true,
                        webViewController: view);
                    final received = await login
                        .observe(Uri.parse('https://www.deezer.com/'));
                    final foreign = await login
                        .observe(Uri.parse('https://deezer.com.evil.test/'));
                    await login.begin();
                    final cleared = await login
                        .observe(Uri.parse('https://www.deezer.com/'));
                    if (!done.isCompleted) {
                      done.complete(controls == true &&
                              received == fixture &&
                              foreign == null &&
                              cleared == null
                          ? 0
                          : 1);
                    }
                  } catch (_) {
                    if (!done.isCompleted) done.complete(1);
                  }
                }))));
    final result = await done.future
        .timeout(const Duration(seconds: 40), onTimeout: () => 1);
    debugPrint(result == 0
        ? 'DD_WEB_LOGIN_OK synthetic cookie and disabled social controls; no real account'
        : 'DD_WEB_LOGIN_FAILED');
    return result;
  } catch (_) {
    return 1;
  } finally {
    runApp(const SizedBox());
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await login.close();
  }
}

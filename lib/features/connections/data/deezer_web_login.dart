import 'dart:io';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';
import '../domain/deezer_login_policy.dart';

/// Uses only the profile created for this login, never a browser profile.
class DeezerWebLogin {
  WebViewEnvironment? environment;
  Directory? _profile;
  CookieManager? _cookies;
  InAppWebViewController? _view;
  bool _reading = false, _closed = false;
  static final loginUrl = WebUri('https://account.deezer.com/pt-br/login/');
  static final resetUrl =
      WebUri('https://account.deezer.com/pt-br/forgot-password/');
  static final cookieUrl = WebUri('https://www.deezer.com/');
  Future<void> initialize() async {
    if (Platform.isAndroid) {
      await InAppWebViewController.setWebContentsDebuggingEnabled(false);
    }
    if (Platform.isWindows) {
      if (await WebViewEnvironment.getAvailableVersion() == null) {
        throw const FormatException(
            'Instale o Microsoft Edge WebView2 Runtime para conectar a Deezer.');
      }
      final cache = await getApplicationCacheDirectory();
      final parent =
          await Directory('${cache.path}/deezer-login').create(recursive: true);
      _profile = await parent.createTemp('flow-');
      environment = await WebViewEnvironment.create(
          settings: WebViewEnvironmentSettings(userDataFolder: _profile!.path));
    }
    _cookies = CookieManager.instance(webViewEnvironment: environment);
    if (_closed) await close();
  }

  Future<void> begin({InAppWebViewController? view}) async {
    _view = view ?? _view;
    await _cookies!.deleteAllCookies();
    await _cookies!.deleteCookie(
        url: cookieUrl,
        name: 'arl',
        domain: '.deezer.com',
        webViewController: _view);
  }

  Future<String?> observe(Uri? current) async {
    if (_closed || _reading || !DeezerLoginPolicy.isDeezer(current)) {
      return null;
    }
    _reading = true;
    try {
      final cookie = await _cookies!
          .getCookie(url: cookieUrl, name: 'arl', webViewController: _view);
      return _closed ? null : DeezerLoginPolicy.session(current, cookie?.value);
    } finally {
      _reading = false;
    }
  }

  Future<void> close() async {
    _closed = true;
    try {
      await _cookies?.deleteAllCookies();
    } catch (_) {/* View already detached. */}
    try {
      await environment?.dispose();
    } catch (_) {/* Window already dismissed. */}
    final profile = _profile;
    if (profile == null) return;
    for (var retry = 0; retry < 5; retry++) {
      try {
        if (await profile.exists()) {
          if (await profile.resolveSymbolicLinks() != profile.absolute.path) {
            return;
          }
          await profile.delete(recursive: true);
        }
        return;
      } on FileSystemException {
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }
    }
  }
}

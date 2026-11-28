import 'dart:io';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';
import '../domain/capture_login.dart';

/// Reads cookies only from the profile created for this login window, never
/// from a browser profile. The profile is deleted when the window closes.
class CaptureWebLogin {
  CaptureWebLogin(this.platform);
  final CapturePlatform platform;
  WebViewEnvironment? environment;
  Directory? _profile;
  CookieManager? _cookies;
  InAppWebViewController? _view;
  bool _reading = false, _closed = false;

  WebUri get loginUrl => WebUri(platform.loginUrl);

  Future<void> initialize() async {
    if (Platform.isAndroid) {
      await InAppWebViewController.setWebContentsDebuggingEnabled(false);
    }
    if (Platform.isWindows) {
      if (await WebViewEnvironment.getAvailableVersion() == null) {
        throw FormatException(
            'Instale o Microsoft Edge WebView2 Runtime para entrar no ${platform.label}.');
      }
      final cache = await getApplicationCacheDirectory();
      final parent = await Directory('${cache.path}/${platform.name}-login')
          .create(recursive: true);
      _profile = await parent.createTemp('flow-');
      environment = await WebViewEnvironment.create(
          settings: WebViewEnvironmentSettings(userDataFolder: _profile!.path));
    }
    _cookies = CookieManager.instance(webViewEnvironment: environment);
    if (_closed) await close();
  }

  Future<void> begin(InAppWebViewController view) async {
    _view = view;
    await _cookies!.deleteAllCookies();
  }

  /// The platform's cookies once its session cookie exists on its own page.
  Future<List<SessionCookie>?> observe(Uri? page) async {
    if (_closed || _reading || !platform.allowsNavigation(page)) return null;
    _reading = true;
    try {
      final cookies = <Cookie>[];
      final seen = <String>{};
      for (final url in platform.cookieUrls) {
        for (final cookie in await _cookies!
            .getCookies(url: WebUri(url), webViewController: _view)) {
          if (seen.add('${cookie.domain}|${cookie.path}|${cookie.name}')) {
            cookies.add(cookie);
          }
        }
      }
      if (_closed) return null;
      return platformSession(
          platform,
          cookies.map((cookie) => SessionCookie(
              name: cookie.name,
              value: '${cookie.value}',
              domain: cookie.domain?.isNotEmpty == true
                  ? cookie.domain!
                  : '.${platform.domain}',
              path: cookie.path?.isNotEmpty == true ? cookie.path! : '/',
              expires: cookie.expiresDate == null
                  ? null
                  : cookie.expiresDate! ~/ 1000)));
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

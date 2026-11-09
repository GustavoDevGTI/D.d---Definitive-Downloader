import 'dart:io';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// The Windows login has an isolated profile and never queries its cookies.
class SpotifyWebProfile {
  Directory? _directory;
  WebViewEnvironment? _environment;

  Future<WebViewEnvironment> open() async {
    if (await WebViewEnvironment.getAvailableVersion() == null) {
      throw const FormatException(
          'O Microsoft Edge WebView2 Runtime não está disponível.');
    }
    final temp = Directory(await Directory.systemTemp.resolveSymbolicLinks());
    final directory = _directory = await temp.createTemp('dd-spotify-login-');
    return _environment = await WebViewEnvironment.create(
        settings: WebViewEnvironmentSettings(userDataFolder: directory.path));
  }

  Future<void> close() async {
    try {
      await _environment?.dispose();
    } catch (_) {/* The dialog can already have detached the WebView. */}
    final directory = _directory;
    if (directory == null) return;
    for (var attempt = 0; attempt < 5; attempt++) {
      try {
        if (await directory.exists() &&
            await directory.resolveSymbolicLinks() == directory.absolute.path) {
          await directory.delete(recursive: true);
        }
        return;
      } on FileSystemException {
        await Future<void>.delayed(const Duration(milliseconds: 350));
      }
    }
  }
}

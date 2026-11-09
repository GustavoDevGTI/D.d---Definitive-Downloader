import 'dart:async';
import 'dart:io';

import '../domain/spotify_auth.dart';

typedef SpotifyLoginPresenter = Future<Uri?> Function(
    SpotifyAuthorizationRequest request, Future<void> cancelled);

class WindowsSpotifyWebAuthorization implements SpotifyAuthorizationFlow {
  WindowsSpotifyWebAuthorization(this.present);

  final SpotifyLoginPresenter present;
  Completer<void>? _active;

  @override
  bool get supported => Platform.isWindows;

  @override
  Uri get redirectUri => SpotifyConfig.windowsRedirect;

  @override
  Future<String> authorize(SpotifyAuthorizationRequest request) async {
    if (!supported || request.redirectUri != redirectUri || _active != null) {
      throw const SpotifyException(
          'Não foi possível iniciar a conexão Spotify.');
    }
    final active = _active = Completer<void>();
    try {
      final callback = await present(request, active.future)
          .timeout(const Duration(minutes: 4), onTimeout: () {
        cancel();
        throw const SpotifyException('O tempo para conectar expirou.');
      });
      if (active.isCompleted || callback == null) {
        throw const SpotifyAuthCancelled();
      }
      return request.acceptCallback(callback);
    } finally {
      _active = null;
    }
  }

  @override
  void cancel() {
    final active = _active;
    if (active != null && !active.isCompleted) active.complete();
  }
}

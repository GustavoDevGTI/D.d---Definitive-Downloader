import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../domain/spotify_auth.dart';
import 'loopback_spotify_authorization.dart';

/// Uses the signed Spotify app first, then an Android Custom Tab when absent.
class AndroidSpotifyAuthorization extends LoopbackSpotifyAuthorization {
  AndroidSpotifyAuthorization(
      {required super.openBrowser,
      this.nativeLogin,
      this.cancelNative,
      this.closeTab,
      super.timeout = const Duration(minutes: 4)})
      : super(redirectUri: SpotifyConfig.androidRedirect);

  factory AndroidSpotifyAuthorization.installed() {
    const channel = MethodChannel('br.com.definitivedownloader/spotify');
    final tab = _SpotifyCustomTab();
    late final AndroidSpotifyAuthorization authorization;
    authorization = AndroidSpotifyAuthorization(
        nativeLogin: (request) async {
          final reply =
              await channel.invokeMapMethod<String, String>('connect', {
            'clientId': SpotifyConfig.clientId,
            'redirect': request.redirectUri.toString(),
            'state': request.state,
            'verifier': request.verifier,
            'challenge': pkceChallenge(request.verifier),
            'scopes': SpotifyConfig.scopes,
          });
          if (reply == null) return null;
          return request.redirectUri.replace(queryParameters: reply);
        },
        cancelNative: () => channel.invokeMethod<void>('cancel'),
        openBrowser: (uri) async {
          if (!await ChromeSafariBrowser.isAvailable()) {
            throw const SpotifyException(
                'O login Spotify precisa de um navegador com suporte a abas dentro do app.');
          }
          tab.onDismiss = authorization.cancel;
          await tab.open(
              url: WebUri.uri(uri),
              settings: ChromeSafariBrowserSettings(
                  shareState: CustomTabsShareState.SHARE_STATE_OFF));
        },
        closeTab: () async {
          tab.onDismiss = null;
          if (tab.isOpened()) await tab.close();
        });
    return authorization;
  }

  final Future<Uri?> Function(SpotifyAuthorizationRequest)? nativeLogin;
  final Future<void> Function()? cancelNative, closeTab;
  var _generation = 0;
  bool _busy = false, _usingNative = false;

  @override
  bool get supported => Platform.isAndroid;

  @override
  Future<String> authorize(SpotifyAuthorizationRequest request) async {
    if (!supported || request.redirectUri != redirectUri || _busy) {
      throw const SpotifyException(
          'Não foi possível iniciar a conexão Spotify.');
    }
    _busy = true;
    final generation = ++_generation;
    try {
      final native = nativeLogin;
      if (native != null) {
        _usingNative = true;
        final result = await native(request).timeout(timeout, onTimeout: () {
          cancel();
          throw const SpotifyException('O tempo para conectar expirou.');
        });
        _usingNative = false;
        if (generation != _generation) throw const SpotifyAuthCancelled();
        if (result != null) return request.acceptCallback(result);
      }
      return await super.authorize(request);
    } on PlatformException catch (error) {
      if (error.code == 'cancelled') throw const SpotifyAuthCancelled();
      throw const SpotifyException(
          'O Spotify não concluiu a conexão. Confira a autorização no app oficial.');
    } finally {
      _usingNative = false;
      try {
        await closeTab?.call();
      } on PlatformException {/* Android may already have closed the tab. */}
      _busy = false;
    }
  }

  @override
  void cancel() {
    _generation++;
    super.cancel();
    if (_usingNative && cancelNative != null) {
      unawaited(cancelNative!().catchError((Object _) {}));
    }
  }
}

class _SpotifyCustomTab extends ChromeSafariBrowser {
  void Function()? onDismiss;

  @override
  void onClosed() => onDismiss?.call();
}

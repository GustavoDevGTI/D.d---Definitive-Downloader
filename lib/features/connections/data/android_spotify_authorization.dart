import 'dart:io';
import '../domain/spotify_auth.dart';
import 'loopback_spotify_authorization.dart';

/// Android-owned callback, registered independently of Windows. The browser
/// stays outside the app; no WebView, browser cookies or client secret.
class AndroidSpotifyAuthorization extends LoopbackSpotifyAuthorization {
  AndroidSpotifyAuthorization(
      {required super.openBrowser, super.timeout = const Duration(minutes: 4)})
      : super(redirectUri: SpotifyConfig.androidRedirect);
  @override
  bool get supported => Platform.isAndroid;
}

import 'dart:io';
import '../domain/spotify_auth.dart';
import 'loopback_spotify_authorization.dart';

class WindowsSpotifyAuthorization extends LoopbackSpotifyAuthorization {
  WindowsSpotifyAuthorization(
      {required super.openBrowser,
      Uri? redirectUri,
      super.timeout = const Duration(minutes: 4)})
      : super(redirectUri: redirectUri ?? SpotifyConfig.windowsRedirect);
  @override
  bool get supported => Platform.isWindows;
}

class UnavailableSpotifyAuthorization implements SpotifyAuthorizationFlow {
  @override
  bool get supported => false;
  @override
  Uri get redirectUri => Uri();
  @override
  Future<String> authorize(SpotifyAuthorizationRequest request) async =>
      throw const SpotifyException(
          'O login Spotify ainda não foi configurado nesta plataforma.');
  @override
  void cancel() {}
}

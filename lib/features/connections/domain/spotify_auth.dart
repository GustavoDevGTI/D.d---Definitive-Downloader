import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

abstract final class SpotifyConfig {
  // Public application identifier supplied by the owner; this is not a secret.
  static const clientId = String.fromEnvironment('SPOTIFY_CLIENT_ID',
      defaultValue: 'bef27a897e96427996bc49e0cf2b4bf2');
  static final windowsRedirect = Uri.parse('http://127.0.0.1:43821/callback');
  static const scopes = [
    'playlist-read-private',
    'playlist-read-collaborative'
  ];
}

class SpotifyException implements Exception {
  const SpotifyException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class SpotifyAuthCancelled extends SpotifyException {
  const SpotifyAuthCancelled() : super('Conexão cancelada.');
}

String pkceChallenge(String verifier) => base64Url
    .encode(sha256.convert(ascii.encode(verifier)).bytes)
    .replaceAll('=', '');

class SpotifyAuthorizationRequest {
  SpotifyAuthorizationRequest.generate(this.redirectUri) {
    final random = Random.secure();
    String secret(int length) => base64Url
        .encode(List.generate(length, (_) => random.nextInt(256)))
        .replaceAll('=', '');
    verifier = secret(64);
    state = secret(32);
  }
  final Uri redirectUri;
  late final String verifier;
  late final String state;
  Uri get authorizationUri => Uri.https('accounts.spotify.com', '/authorize', {
        'client_id': SpotifyConfig.clientId,
        'response_type': 'code',
        'redirect_uri': redirectUri.toString(),
        'scope': SpotifyConfig.scopes.join(' '),
        'code_challenge_method': 'S256',
        'code_challenge': pkceChallenge(verifier),
        'state': state,
      });

  String acceptCallback(Uri callback) {
    final parameters = callback.queryParametersAll;
    if (callback.path != redirectUri.path ||
        parameters['state']?.length != 1 ||
        parameters['state']?.single != state) {
      throw const SpotifyException('Retorno de autenticação inválido.');
    }
    if (parameters.containsKey('error')) {
      if (parameters['error']?.singleOrNull == 'access_denied') {
        throw const SpotifyAuthCancelled();
      }
      throw const SpotifyException('O Spotify não autorizou a conexão.');
    }
    final codes = parameters['code'];
    if (codes?.length != 1 ||
        codes!.single.isEmpty ||
        codes.single.length > 4096) {
      throw const SpotifyException('O retorno não contém um código válido.');
    }
    return codes.single;
  }
}

abstract interface class SpotifyAuthorizationFlow {
  bool get supported;
  Uri get redirectUri;
  Future<String> authorize(SpotifyAuthorizationRequest request);
  void cancel();
}

class SpotifyTokens {
  const SpotifyTokens(
      {required this.accessToken,
      required this.refreshToken,
      required this.expiresAt,
      required this.scope});
  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final String scope;

  factory SpotifyTokens.fromResponse(Map<String, dynamic> json,
      {String previousRefreshToken = '', DateTime? now}) {
    final access = json['access_token'];
    final refresh = json['refresh_token'] ?? previousRefreshToken;
    final expires = json['expires_in'];
    if (access is! String ||
        access.isEmpty ||
        access.length > 4096 ||
        refresh is! String ||
        refresh.isEmpty ||
        refresh.length > 4096 ||
        expires is! int ||
        expires <= 0 ||
        expires > 86400 ||
        json['token_type']?.toString().toLowerCase() != 'bearer') {
      throw const SpotifyException('O Spotify retornou uma sessão inválida.');
    }
    return SpotifyTokens(
        accessToken: access,
        refreshToken: refresh,
        expiresAt: (now ?? DateTime.now()).add(Duration(seconds: expires)),
        scope: (json['scope'] ?? '').toString());
  }

  factory SpotifyTokens.fromStorage(Map<String, dynamic> json) {
    if (json['client_id'] != SpotifyConfig.clientId) {
      throw const SpotifyException('A sessão pertence a outro aplicativo.');
    }
    final expiry = DateTime.tryParse(json['expires_at']?.toString() ?? '');
    if (expiry == null) throw const SpotifyException('Sessão salva inválida.');
    final value = SpotifyTokens.fromResponse({...json, 'expires_in': 3600});
    return SpotifyTokens(
        accessToken: value.accessToken,
        refreshToken: value.refreshToken,
        expiresAt: expiry,
        scope: value.scope);
  }

  Map<String, dynamic> toStorage() => {
        'client_id': SpotifyConfig.clientId,
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'token_type': 'Bearer',
        'scope': scope,
        'expires_at': expiresAt.toUtc().toIso8601String(),
      };
}

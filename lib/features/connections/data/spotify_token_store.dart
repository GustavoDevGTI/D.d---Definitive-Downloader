import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../domain/spotify_auth.dart';

abstract interface class SpotifyTokenStore {
  Future<SpotifyTokens?> read();
  Future<void> write(SpotifyTokens tokens);
  Future<void> clear();
}

class SecureSpotifyTokenStore implements SpotifyTokenStore {
  const SecureSpotifyTokenStore(this.storage);
  final FlutterSecureStorage storage;
  String get _key => 'dd.spotify.${SpotifyConfig.clientId}.session';
  @override
  Future<SpotifyTokens?> read() async {
    final value = await storage.read(key: _key);
    if (value == null) return null;
    if (value.length > 16384) {
      throw const SpotifyException('Sessão salva inválida.');
    }
    final data = jsonDecode(value);
    if (data is! Map<String, dynamic>) {
      throw const SpotifyException('Sessão salva inválida.');
    }
    return SpotifyTokens.fromStorage(data);
  }

  @override
  Future<void> write(SpotifyTokens tokens) =>
      storage.write(key: _key, value: jsonEncode(tokens.toStorage()));
  @override
  Future<void> clear() => storage.delete(key: _key);
}

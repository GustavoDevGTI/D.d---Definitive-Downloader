import 'package:definitive_downloader/features/connections/data/spotify_token_store.dart';
import 'package:definitive_downloader/features/connections/data/spotify_transport.dart';
import 'package:definitive_downloader/features/connections/domain/spotify_auth.dart';

class MemorySpotifyStore implements SpotifyTokenStore {
  SpotifyTokens? value;
  int writes = 0;
  @override
  Future<SpotifyTokens?> read() async => value;
  @override
  Future<void> write(SpotifyTokens tokens) async {
    writes++;
    value = tokens;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

class FakeSpotifyFlow implements SpotifyAuthorizationFlow {
  @override
  bool get supported => true;
  @override
  Uri get redirectUri => SpotifyConfig.windowsRedirect;
  @override
  Future<String> authorize(SpotifyAuthorizationRequest request) async =>
      'fixture-code';
  @override
  void cancel() {}
}

typedef FixtureRequest = Future<Map<String, dynamic>> Function(Uri uri,
    String method, Map<String, String> headers, Map<String, String>? form);

class FixtureSpotifyTransport implements SpotifyTransport {
  FixtureSpotifyTransport(this.handle);
  final FixtureRequest handle;
  @override
  Future<Map<String, dynamic>> request(Uri uri,
          {String method = 'GET',
          Map<String, String> headers = const {},
          Map<String, String>? form}) =>
      handle(uri, method, headers, form);
}

Map<String, dynamic> fixtureToken(
        {String access = 'fixture-access', bool refresh = true}) =>
    {
      'access_token': access,
      if (refresh) 'refresh_token': 'fixture-refresh',
      'token_type': 'Bearer',
      'expires_in': 3600,
      'scope': SpotifyConfig.scopes.join(' '),
    };

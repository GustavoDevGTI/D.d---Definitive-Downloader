import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:definitive_downloader/features/connections/domain/spotify_auth.dart';
import 'package:definitive_downloader/features/connections/data/windows_spotify_authorization.dart';
import 'package:definitive_downloader/features/connections/data/spotify_transport.dart';

void main() {
  test('PKCE usa vetor S256 do RFC e entropia por tentativa', () {
    expect(pkceChallenge('dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk'),
        'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM');
    final first =
        SpotifyAuthorizationRequest.generate(SpotifyConfig.windowsRedirect);
    final next =
        SpotifyAuthorizationRequest.generate(SpotifyConfig.windowsRedirect);
    expect(first.state, isNot(next.state));
    expect(first.verifier.length, inInclusiveRange(43, 128));
    expect(first.authorizationUri.queryParameters,
        isNot(contains('code_verifier')));
    expect(first.authorizationUri.queryParameters['scope'],
        SpotifyConfig.scopes.join(' '));
  });
  test('callback exige state único, caminho correto e código', () {
    final request =
        SpotifyAuthorizationRequest.generate(SpotifyConfig.windowsRedirect);
    expect(
        () => request
            .acceptCallback(Uri.parse('/callback?state=wrong&code=test')),
        throwsA(isA<SpotifyException>()));
    expect(
        () => request.acceptCallback(Uri.parse(
            '/callback?state=${request.state}&state=${request.state}&code=test')),
        throwsA(isA<SpotifyException>()));
    expect(
        () => request.acceptCallback(
            Uri.parse('/other?state=${request.state}&code=test')),
        throwsA(isA<SpotifyException>()));
    expect(
        request.acceptCallback(
            Uri.parse('/callback?state=${request.state}&code=test')),
        'test');
  });
  test('credenciais de resposta inválida não viram sessão', () {
    expect(() => SpotifyTokens.fromResponse({'access_token': 'fixture'}),
        throwsA(isA<SpotifyException>()));
  });
  test('transporte recusa domínios estranhos e HTTP antes de transmitir',
      () async {
    const transport = SpotifyHttpTransport();
    for (final url in [
      'https://example.com/token',
      'http://accounts.spotify.com/token',
      'https://user:pass@api.spotify.com/v1/me',
      'https://api.spotify.com:1234/v1/me'
    ]) {
      await expectLater(
          transport.request(Uri.parse(url)), throwsA(isA<SpotifyException>()));
    }
  });

  group('retorno Windows em localhost', () {
    setUpAll(() {
      HttpOverrides.global = null;
    });
    Future<Uri> redirect() async {
      final reservation =
          await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = reservation.port;
      await reservation.close(force: true);
      return Uri.parse('http://127.0.0.1:$port/callback');
    }

    test(
        'estado falso não consome callback válido; resposta não reflete código',
        () async {
      final uri = await redirect();
      final flow = WindowsSpotifyAuthorization(
          redirectUri: uri,
          openBrowser: (url) async {
            final client = HttpClient();
            try {
              final invalid = await (await client.getUrl(uri.replace(
                      queryParameters: {
                    'state': 'wrong',
                    'code': 'fake-secret-code'
                  })))
                  .close();
              expect(invalid.statusCode, 400);
              await invalid.drain<void>();
              final valid = await (await client.getUrl(uri.replace(
                      queryParameters: {
                    'state': url.queryParameters['state']!,
                    'code': 'fake-secret-code'
                  })))
                  .close();
              expect(valid.statusCode, 200);
              final body = await valid
                  .map((chunk) => String.fromCharCodes(chunk))
                  .join();
              expect(body, isNot(contains('fake-secret-code')));
              expect(valid.headers.value(HttpHeaders.cacheControlHeader),
                  'no-store');
            } finally {
              client.close(force: true);
            }
          });
      expect(await flow.authorize(SpotifyAuthorizationRequest.generate(uri)),
          'fake-secret-code');
      final released =
          await HttpServer.bind(InternetAddress.loopbackIPv4, uri.port);
      await released.close(force: true);
    }, skip: !Platform.isWindows);
    test('cancelamento fecha o listener sem trocar código por token', () async {
      final uri = await redirect();
      late WindowsSpotifyAuthorization flow;
      flow = WindowsSpotifyAuthorization(
          redirectUri: uri, openBrowser: (_) async => flow.cancel());
      await expectLater(
          flow.authorize(SpotifyAuthorizationRequest.generate(uri)),
          throwsA(isA<SpotifyAuthCancelled>()));
      final released =
          await HttpServer.bind(InternetAddress.loopbackIPv4, uri.port);
      await released.close(force: true);
    }, skip: !Platform.isWindows);
    test('tempo esgotado libera a porta', () async {
      final uri = await redirect();
      final flow = WindowsSpotifyAuthorization(
          redirectUri: uri,
          timeout: const Duration(milliseconds: 50),
          openBrowser: (_) async {});
      await expectLater(
          flow.authorize(SpotifyAuthorizationRequest.generate(uri)),
          throwsA(isA<SpotifyException>()));
      final released =
          await HttpServer.bind(InternetAddress.loopbackIPv4, uri.port);
      await released.close(force: true);
    }, skip: !Platform.isWindows);
  });
}

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:definitive_downloader/features/connections/data/android_spotify_authorization.dart';
import 'package:definitive_downloader/features/connections/data/spotify_token_store.dart';
import 'package:definitive_downloader/features/connections/domain/spotify_auth.dart';
import 'package:definitive_downloader/features/connections/application/spotify_connection_controller.dart';
import '../test/spotify_fixtures.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
      'Android PKCE: retorno próprio, cofre, renovação e restauração automáticos',
      (tester) async {
    expect(Platform.isAndroid, isTrue);
    const store = SecureSpotifyTokenStore(FlutterSecureStorage());
    var tokenCalls = 0;
    var browserCalls = 0;
    final transport =
        FixtureSpotifyTransport((uri, method, headers, form) async {
      if (uri.path == '/api/token') {
        tokenCalls++;
        expect(form, isNot(contains('client_secret')));
        if (form!['grant_type'] == 'authorization_code') {
          expect(
              form['redirect_uri'], SpotifyConfig.androidRedirect.toString());
          expect(form['code_verifier']!.length, greaterThanOrEqualTo(43));
          return fixtureToken();
        }
        expect(form['refresh_token'], 'fixture-refresh');
        return fixtureToken(access: 'fixture-renewed');
      }
      return {'display_name': 'Fixture Android, sem conta real'};
    });
    final flow = AndroidSpotifyAuthorization(openBrowser: (url) async {
      browserCalls++;
      expect(url.host, 'accounts.spotify.com');
      expect(url.queryParameters['code_challenge_method'], 'S256');
      expect(url.queryParameters, isNot(contains('code_verifier')));
      final redirect = Uri.parse(url.queryParameters['redirect_uri']!);
      expect(redirect, SpotifyConfig.androidRedirect);
      final client = HttpClient();
      try {
        final invalid = await (await client.getUrl(redirect.replace(
                queryParameters: {'state': 'wrong', 'code': 'fixture'})))
            .close();
        expect(invalid.statusCode, 400);
        await invalid.drain<void>();
        final response = await (await client.getUrl(redirect.replace(
                queryParameters: {
              'state': url.queryParameters['state']!,
              'code': 'fixture-android-code'
            })))
            .close();
        expect(response.statusCode, 200);
        final html = await response.map(String.fromCharCodes).join();
        expect(html, isNot(contains('fixture-android-code')));
        expect(response.headers.value('cache-control'), 'no-store');
      } finally {
        client.close(force: true);
      }
    });
    final controller = SpotifyConnectionController(
        store: store, transport: transport, authorization: flow);
    addTearDown(() async {
      await controller.disconnect();
      controller.dispose();
    });
    await controller.connect();
    expect(controller.isConnected, isTrue, reason: controller.message);
    expect(browserCalls, 1);
    final fixture = (await store.read())!;
    expect(fixture.accessToken, 'fixture-access');
    await store.write(SpotifyTokens(
        accessToken: fixture.accessToken,
        refreshToken: fixture.refreshToken,
        expiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
        scope: fixture.scope));
    final restored = SpotifyConnectionController(
        store: store,
        transport: transport,
        authorization: AndroidSpotifyAuthorization(
            openBrowser: (_) async => fail('Restauração não abre login.')));
    try {
      await restored.restore();
      expect(restored.isConnected, isTrue, reason: restored.message);
      expect(tokenCalls, 2);
      expect((await store.read())!.accessToken, 'fixture-renewed');
    } finally {
      await restored.disconnect();
      restored.dispose();
    }
    final port = await HttpServer.bind(
        InternetAddress.loopbackIPv4, SpotifyConfig.androidRedirect.port);
    await port.close(force: true);
    debugPrint(
        'ANDROID_AUTH_FIXTURE: PKCE, origem, cofre, refresh e restauração passaram; nenhuma conta real.');
  });
  testWidgets('Android PKCE: cancelar e expirar liberam apenas seu listener',
      (tester) async {
    late AndroidSpotifyAuthorization flow;
    flow = AndroidSpotifyAuthorization(openBrowser: (_) async => flow.cancel());
    await expectLater(
        flow.authorize(SpotifyAuthorizationRequest.generate(flow.redirectUri)),
        throwsA(isA<SpotifyAuthCancelled>()));
    final timeout = AndroidSpotifyAuthorization(
        timeout: const Duration(milliseconds: 100), openBrowser: (_) async {});
    await expectLater(
        timeout.authorize(
            SpotifyAuthorizationRequest.generate(timeout.redirectUri)),
        throwsA(isA<SpotifyException>()));
    final port = await HttpServer.bind(
        InternetAddress.loopbackIPv4, flow.redirectUri.port);
    await port.close(force: true);
  });
}

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:definitive_downloader/features/connections/application/spotify_connection_controller.dart';
import 'package:definitive_downloader/features/connections/domain/spotify_auth.dart';

import 'spotify_fixtures.dart';

void main() {
  test('conecta com PKCE, persiste no cofre e remove a sessão local', () async {
    final store = MemorySpotifyStore();
    final controller = SpotifyConnectionController(
        store: store,
        authorization: FakeSpotifyFlow(),
        transport: FixtureSpotifyTransport((uri, method, headers, form) async {
          if (uri.path == '/api/token') {
            expect(method, 'POST');
            expect(form!['client_id'], SpotifyConfig.clientId);
            expect(form['code_verifier']!.length, greaterThanOrEqualTo(43));
            expect(form, isNot(contains('client_secret')));
            return fixtureToken();
          }
          expect(headers['Authorization'], 'Bearer fixture-access');
          return {'display_name': 'Pessoa de teste'};
        }));
    await controller.connect();
    expect(controller.isConnected, isTrue);
    expect(store.writes, 1);
    expect(controller.displayName, 'Pessoa de teste');
    await controller.disconnect();
    expect(controller.isConnected, isFalse);
    expect(store.value, isNull);
    controller.dispose();
  });

  test(
      'duas respostas 401 compartilham refresh e preservam refresh token omitido',
      () async {
    final store = MemorySpotifyStore()
      ..value = SpotifyTokens.fromResponse(fixtureToken());
    final gate = Completer<Map<String, dynamic>>();
    final started = Completer<void>();
    var refreshes = 0;
    final controller = SpotifyConnectionController(
        store: store,
        authorization: FakeSpotifyFlow(),
        transport: FixtureSpotifyTransport((uri, method, headers, form) async {
          if (uri.path == '/api/token') {
            refreshes++;
            if (!started.isCompleted) started.complete();
            return gate.future;
          }
          if (uri.path == '/v1/me') return {'display_name': 'Teste'};
          if (headers['Authorization'] == 'Bearer fixture-access') {
            throw const SpotifyException('Expired', statusCode: 401);
          }
          return {'ok': true};
        }));
    await controller.restore();
    final results =
        Future.wait([controller.getJson('/test'), controller.getJson('/test')]);
    await started.future;
    await Future<void>.delayed(Duration.zero);
    expect(refreshes, 1);
    gate.complete(fixtureToken(access: 'fixture-new', refresh: false));
    expect((await results).every((row) => row['ok'] == true), isTrue);
    expect(store.value!.refreshToken, 'fixture-refresh');
    controller.dispose();
  });

  test('cancelar durante troca de código impede salvar uma sessão tardia',
      () async {
    final store = MemorySpotifyStore();
    final gate = Completer<Map<String, dynamic>>();
    final started = Completer<void>();
    final controller = SpotifyConnectionController(
        store: store,
        authorization: FakeSpotifyFlow(),
        transport: FixtureSpotifyTransport((uri, method, headers, form) async {
          started.complete();
          return gate.future;
        }));
    final connecting = controller.connect();
    await started.future;
    controller.cancel();
    gate.complete(fixtureToken());
    await connecting;
    expect(controller.isConnected, isFalse);
    expect(store.writes, 0);
    controller.dispose();
  });

  test('desconectar durante refresh não recria a sessão removida', () async {
    final store = MemorySpotifyStore()
      ..value = SpotifyTokens.fromResponse(fixtureToken());
    final gate = Completer<Map<String, dynamic>>();
    final started = Completer<void>();
    final controller = SpotifyConnectionController(
        store: store,
        authorization: FakeSpotifyFlow(),
        transport: FixtureSpotifyTransport((uri, method, headers, form) async {
          if (uri.path == '/api/token') {
            started.complete();
            return gate.future;
          }
          if (uri.path == '/v1/me') return {'display_name': 'Teste'};
          throw const SpotifyException('Expired', statusCode: 401);
        }));
    await controller.restore();
    final outcome = expectLater(
        controller.getJson('/test'), throwsA(isA<SpotifyAuthCancelled>()));
    await started.future;
    await controller.disconnect();
    gate.complete(fixtureToken(access: 'fixture-late'));
    await outcome;
    expect(store.value, isNull);
    expect(controller.isConnected, isFalse);
    controller.dispose();
  });
}

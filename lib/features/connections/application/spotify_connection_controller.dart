import 'package:flutter/foundation.dart';
import '../data/spotify_token_store.dart';
import '../data/spotify_transport.dart';
import '../domain/spotify_auth.dart';

enum SpotifyConnectionStatus { disconnected, restoring, authorizing, connected }

class SpotifyConnectionController extends ChangeNotifier {
  SpotifyConnectionController(
      {required this.store,
      required this.transport,
      required this.authorization});
  final SpotifyTokenStore store;
  final SpotifyTransport transport;
  final SpotifyAuthorizationFlow authorization;
  SpotifyConnectionStatus status = SpotifyConnectionStatus.disconnected;
  String displayName = '';
  String message = '';
  SpotifyTokens? _tokens;
  Future<SpotifyTokens>? _refreshing;
  bool _disposed = false;
  int _generation = 0;
  Future<void> _vaultTail = Future.value();
  bool get isConnected => status == SpotifyConnectionStatus.connected;
  bool get busy =>
      status == SpotifyConnectionStatus.restoring ||
      status == SpotifyConnectionStatus.authorizing;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  String _error(Object error) => error is SpotifyException
      ? error.message
      : 'Não foi possível concluir a conexão. Confira a rede e o acesso ao cofre do sistema.';

  Future<void> restore() async {
    if (busy || isConnected) return;
    final generation = ++_generation;
    status = SpotifyConnectionStatus.restoring;
    _notify();
    try {
      final saved = await store.read();
      if (generation != _generation || _disposed) return;
      _tokens = saved;
      if (_tokens != null) {
        final profile = await getJson('/me');
        if (generation != _generation || _disposed) return;
        displayName = (profile['display_name'] ?? 'Conta Spotify').toString();
        status = SpotifyConnectionStatus.connected;
      } else {
        status = SpotifyConnectionStatus.disconnected;
      }
    } catch (error) {
      if (generation != _generation || _disposed) return;
      _tokens = null;
      status = SpotifyConnectionStatus.disconnected;
      message = _error(error);
    }
    _notify();
  }

  Future<void> connect() async {
    if (busy || isConnected || !authorization.supported) return;
    final generation = ++_generation;
    status = SpotifyConnectionStatus.authorizing;
    message =
        'Conclua a autorização no navegador. O D.d solicita leitura de playlists.';
    _notify();
    try {
      final request =
          SpotifyAuthorizationRequest.generate(authorization.redirectUri);
      final code = await authorization.authorize(request);
      _checkGeneration(generation);
      final response = await transport.request(
          Uri.https('accounts.spotify.com', '/api/token'),
          method: 'POST',
          form: {
            'grant_type': 'authorization_code',
            'client_id': SpotifyConfig.clientId,
            'redirect_uri': request.redirectUri.toString(),
            'code': code,
            'code_verifier': request.verifier,
          });
      _checkGeneration(generation);
      final tokens = SpotifyTokens.fromResponse(response);
      if (!tokens.scope.split(' ').toSet().containsAll(SpotifyConfig.scopes)) {
        throw const SpotifyException(
            'A autorização não incluiu as permissões de leitura necessárias.');
      }
      final profile = await transport.request(
          Uri.https('api.spotify.com', '/v1/me'),
          headers: {'Authorization': 'Bearer ${tokens.accessToken}'});
      await _persist(tokens, generation);
      _tokens = tokens;
      displayName = (profile['display_name'] ?? 'Conta Spotify').toString();
      status = SpotifyConnectionStatus.connected;
      message =
          'Spotify conectado. Importe uma playlist própria ou colaborativa pelo link.';
    } catch (error) {
      if (generation != _generation || _disposed) return;
      _tokens = null;
      status = SpotifyConnectionStatus.disconnected;
      message = _error(error);
    }
    _notify();
  }

  Future<SpotifyTokens> _access({bool forceRefresh = false}) async {
    final tokens = _tokens;
    if (tokens == null) {
      throw const SpotifyException('Conecte sua conta Spotify.');
    }
    if (!forceRefresh &&
        tokens.expiresAt
            .isAfter(DateTime.now().add(const Duration(seconds: 45)))) {
      return tokens;
    }
    final active = _refreshing;
    if (active != null) return active;
    final operation = _refresh(tokens);
    _refreshing = operation;
    try {
      return await operation;
    } finally {
      _refreshing = null;
    }
  }

  Future<SpotifyTokens> _refresh(SpotifyTokens current) async {
    final generation = _generation;
    try {
      final response = await transport.request(
          Uri.https('accounts.spotify.com', '/api/token'),
          method: 'POST',
          form: {
            'grant_type': 'refresh_token',
            'client_id': SpotifyConfig.clientId,
            'refresh_token': current.refreshToken,
          });
      final updated = SpotifyTokens.fromResponse(
          {...response, 'scope': response['scope'] ?? current.scope},
          previousRefreshToken: current.refreshToken);
      await _persist(updated, generation);
      _tokens = updated;
      return updated;
    } on SpotifyException catch (error) {
      if (error.statusCode == 400 || error.statusCode == 401) {
        if (generation == _generation) await _forget();
        throw const SpotifyException(
            'A sessão foi revogada. Conecte o Spotify novamente.',
            statusCode: 401);
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getJson(String path,
      {Map<String, String> query = const {}}) async {
    if (!path.startsWith('/') || path.contains('://') || path.contains('..')) {
      throw const SpotifyException('Recurso Spotify inválido.');
    }
    final uri = Uri.https('api.spotify.com', '/v1$path', query);
    for (var attempt = 0; attempt < 2; attempt++) {
      final tokens = await _access(forceRefresh: attempt == 1);
      try {
        return await transport.request(uri,
            headers: {'Authorization': 'Bearer ${tokens.accessToken}'});
      } on SpotifyException catch (error) {
        if (error.statusCode != 401) rethrow;
        if (attempt == 1) {
          await _forget();
          rethrow;
        }
      }
    }
    throw const SpotifyException('Não foi possível validar a sessão.');
  }

  Future<void> _forget() async {
    _generation++;
    _tokens = null;
    displayName = '';
    status = SpotifyConnectionStatus.disconnected;
    final clear = _vaultTail.then((_) => store.clear());
    _vaultTail = clear.catchError((Object _) {});
    await clear;
    _notify();
  }

  Future<void> disconnect() async {
    authorization.cancel();
    try {
      await _forget();
      message =
          'Sessão removida deste dispositivo. Para revogar a autorização, use os aplicativos conectados na conta Spotify.';
    } catch (_) {
      message =
          'Não foi possível apagar a sessão no cofre do sistema. Tente desconectar novamente.';
    }
    _notify();
  }

  void _checkGeneration(int generation) {
    if (_disposed || generation != _generation) {
      throw const SpotifyAuthCancelled();
    }
  }

  Future<void> _persist(SpotifyTokens tokens, int generation) async {
    final write = _vaultTail.then((_) async {
      _checkGeneration(generation);
      await store.write(tokens);
    });
    _vaultTail = write.catchError((Object _) {});
    await write;
    _checkGeneration(generation);
  }

  void cancel() {
    _generation++;
    authorization.cancel();
    status = SpotifyConnectionStatus.disconnected;
    message = 'Conexão cancelada.';
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    authorization.cancel();
    super.dispose();
  }
}

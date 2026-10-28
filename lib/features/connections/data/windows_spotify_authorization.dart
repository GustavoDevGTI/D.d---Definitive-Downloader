import 'dart:async';
import 'dart:io';
import '../domain/spotify_auth.dart';

class WindowsSpotifyAuthorization implements SpotifyAuthorizationFlow {
  WindowsSpotifyAuthorization(
      {required this.openBrowser,
      Uri? redirectUri,
      this.timeout = const Duration(minutes: 4)})
      : redirectUri = redirectUri ?? SpotifyConfig.windowsRedirect;
  final Future<void> Function(Uri) openBrowser;
  @override
  final Uri redirectUri;
  final Duration timeout;
  Completer<String>? _pending;
  @override
  bool get supported => Platform.isWindows;

  @override
  Future<String> authorize(SpotifyAuthorizationRequest request) async {
    if (!supported ||
        request.redirectUri != redirectUri ||
        redirectUri.scheme != 'http' ||
        redirectUri.host != '127.0.0.1') {
      throw const SpotifyException(
          'Retorno de login incompatível com esta plataforma.');
    }
    if (_pending != null) {
      throw const SpotifyException('Já há uma conexão em andamento.');
    }
    HttpServer server;
    try {
      server = await HttpServer.bind(
          InternetAddress.loopbackIPv4, redirectUri.port,
          shared: false);
    } on SocketException {
      throw const SpotifyException(
          'A porta de retorno está ocupada. Feche outra janela do D.d e tente novamente.');
    }
    final pending = Completer<String>();
    _pending = pending;
    // Install an error listener before browser launch/cancellation can complete it.
    final outcome = pending.future.timeout(timeout,
        onTimeout: () => throw const SpotifyException(
            'O tempo para conectar expirou. Tente novamente.'));
    server.idleTimeout = const Duration(seconds: 10);
    final subscription = server.listen((incoming) async {
      incoming.response.headers
        ..contentType = ContentType.html
        ..set(HttpHeaders.cacheControlHeader, 'no-store')
        ..set('Referrer-Policy', 'no-referrer')
        ..set('Content-Security-Policy',
            "default-src 'none'; frame-ancestors 'none'");
      try {
        if (incoming.method != 'GET' ||
            incoming.connectionInfo?.remoteAddress.isLoopback != true ||
            incoming.headers.value(HttpHeaders.hostHeader) !=
                redirectUri.authority ||
            incoming.uri.toString().length > 8192 ||
            pending.isCompleted) {
          incoming.response.statusCode = HttpStatus.badRequest;
          incoming.response
              .write('Retorno inválido. Volte ao Definitive Downloader.');
          return;
        }
        final code = request.acceptCallback(incoming.uri);
        incoming.response.write(
            '<!doctype html><html lang="pt-BR"><meta charset="utf-8">'
            '<title>Definitive Downloader</title><h1>Login recebido</h1>'
            '<p>Volte ao D.d para concluir a conexão. Você pode fechar esta aba.</p></html>');
        if (!pending.isCompleted) pending.complete(code);
      } on SpotifyAuthCancelled {
        incoming.response
            .write('Conexão cancelada. Volte ao Definitive Downloader.');
        if (!pending.isCompleted) {
          pending.completeError(const SpotifyAuthCancelled());
        }
      } on SpotifyException {
        incoming.response.statusCode = HttpStatus.badRequest;
        incoming.response
            .write('Retorno inválido. Use a janela de login aberta pelo D.d.');
        // An invalid state must not consume the legitimate callback.
      } finally {
        await incoming.response.close();
      }
    }, onError: (Object _) {
      if (!pending.isCompleted) {
        pending.completeError(
            const SpotifyException('O retorno do login foi interrompido.'));
      }
    });
    try {
      // Await both; no authorization result is logged or written outside the vault.
      await Future.wait<Object?>([
        outcome,
        Future<void>.sync(() => openBrowser(request.authorizationUri))
            .catchError((Object _) {
          if (!pending.isCompleted) {
            pending.completeError(
                const SpotifyException('Não foi possível abrir o navegador.'));
          }
        }),
      ]);
      return await outcome;
    } finally {
      await subscription.cancel();
      await server.close(force: true);
      _pending = null;
    }
  }

  @override
  void cancel() {
    final pending = _pending;
    if (pending != null && !pending.isCompleted) {
      pending.completeError(const SpotifyAuthCancelled());
    }
  }
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

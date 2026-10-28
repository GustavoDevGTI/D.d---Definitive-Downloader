import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../../../core/network/platform_trust.dart';
import '../domain/spotify_auth.dart';

abstract interface class SpotifyTransport {
  Future<Map<String, dynamic>> request(Uri uri,
      {String method = 'GET',
      Map<String, String> headers = const {},
      Map<String, String>? form});
}

class SpotifyHttpTransport implements SpotifyTransport {
  const SpotifyHttpTransport();
  @override
  Future<Map<String, dynamic>> request(Uri uri,
      {String method = 'GET',
      Map<String, String> headers = const {},
      Map<String, String>? form}) async {
    if (uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.port != 443 ||
        !{'accounts.spotify.com', 'api.spotify.com'}.contains(uri.host)) {
      throw const SpotifyException('Destino de autenticação não permitido.');
    }
    final client = HttpClient(context: await platformSecurityContext())
      ..connectionTimeout = const Duration(seconds: 12);
    try {
      final request = await client
          .openUrl(method, uri)
          .timeout(const Duration(seconds: 15));
      request.followRedirects = false;
      headers.forEach(request.headers.set);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (form != null) {
        request.headers.contentType =
            ContentType('application', 'x-www-form-urlencoded');
        request.write(Uri(queryParameters: form).query);
      }
      final response =
          await request.close().timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        // Never echo upstream bodies, codes, tokens or URLs in errors/logs.
        throw SpotifyException(
            switch (response.statusCode) {
              400 =>
                'O Spotify recusou a autorização. Confira o Client ID e o endereço de retorno cadastrado.',
              401 =>
                'A sessão Spotify expirou ou foi revogada. Conecte novamente.',
              403 =>
                'Acesso negado. Confira os usuários autorizados do aplicativo e use uma playlist própria ou colaborativa.',
              404 =>
                'A playlist não foi encontrada ou não está acessível para esta conta.',
              429 =>
                'O Spotify limitou as consultas. Aguarde antes de tentar novamente.',
              _ => 'O Spotify está indisponível. Tente novamente mais tarde.',
            },
            statusCode: response.statusCode);
      }
      if (response.contentLength > 1024 * 1024) {
        throw const SpotifyException('Resposta Spotify acima do limite.');
      }
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in response.timeout(const Duration(seconds: 20))) {
        if (bytes.length + chunk.length > 1024 * 1024) {
          throw const SpotifyException('Resposta Spotify acima do limite.');
        }
        bytes.add(chunk);
      }
      final data = jsonDecode(utf8.decode(bytes.takeBytes()));
      if (data is! Map<String, dynamic>) {
        throw const SpotifyException('Formato de resposta Spotify inesperado.');
      }
      return data;
    } on HandshakeException {
      throw const SpotifyException(
          'Não foi possível validar a conexão segura com o Spotify. Confira os certificados do sistema.');
    } on TimeoutException {
      throw const SpotifyException(
          'O Spotify demorou para responder. Tente novamente.');
    } on SocketException {
      throw const SpotifyException(
          'Não foi possível conectar ao Spotify. Confira a conexão.');
    } on FormatException {
      throw const SpotifyException(
          'A resposta do Spotify não pôde ser interpretada.');
    } finally {
      client.close(force: true);
    }
  }
}

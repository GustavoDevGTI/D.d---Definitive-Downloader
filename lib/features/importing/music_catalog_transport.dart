import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../../core/network/platform_trust.dart';

abstract interface class MusicCatalogTransport {
  Future<Map<String, dynamic>> read(Uri uri, {Map<String, Object?>? body});
}

class PublicMusicCatalogTransport implements MusicCatalogTransport {
  const PublicMusicCatalogTransport();
  @override
  Future<Map<String, dynamic>> read(Uri uri,
      {Map<String, Object?>? body}) async {
    if (uri.scheme != 'https' ||
        uri.port != 443 ||
        uri.userInfo.isNotEmpty ||
        !(uri.host == 'api.deezer.com' &&
                RegExp(r'^/track/[1-9][0-9]{0,18}$').hasMatch(uri.path) &&
                body == null ||
            uri.host == 'music.youtube.com' &&
                uri.path == '/youtubei/v1/player' &&
                body != null)) {
      throw const FormatException('Destino de catálogo não permitido.');
    }
    final client = HttpClient(context: await platformSecurityContext())
      ..connectionTimeout = const Duration(seconds: 12);
    final deadline =
        Timer(const Duration(seconds: 45), () => client.close(force: true));
    try {
      final request = await client
          .openUrl(body == null ? 'GET' : 'POST', uri)
          .timeout(const Duration(seconds: 15));
      request.followRedirects = false;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(
          HttpHeaders.userAgentHeader, 'Mozilla/5.0 DefinitiveDownloader/0.1');
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.headers.set('Origin', 'https://music.youtube.com');
        request.write(jsonEncode(body));
      }
      final response =
          await request.close().timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw const FormatException(
            'O catálogo recusou a consulta. Tente novamente mais tarde.');
      }
      const maximum = 2 * 1024 * 1024;
      if (response.contentLength > maximum) {
        throw const FormatException('Resposta de catálogo acima do limite.');
      }
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in response.timeout(const Duration(seconds: 15))) {
        if (bytes.length + chunk.length > maximum) {
          throw const FormatException('Resposta de catálogo acima do limite.');
        }
        bytes.add(chunk);
      }
      final value = jsonDecode(utf8.decode(bytes.takeBytes()));
      if (value is! Map<String, dynamic>) {
        throw const FormatException('Resposta de catálogo inválida.');
      }
      return value;
    } on SocketException {
      throw const FormatException('Não foi possível conectar ao catálogo.');
    } on TimeoutException {
      throw const FormatException('O catálogo demorou para responder.');
    } finally {
      deadline.cancel();
      client.close(force: true);
    }
  }
}

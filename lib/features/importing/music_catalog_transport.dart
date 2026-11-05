import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import '../../core/network/platform_trust.dart';

abstract interface class MusicCatalogTransport {
  Future<Map<String, dynamic>> read(Uri uri, {Map<String, Object?>? body});
}

class PublicMusicCatalogTransport implements MusicCatalogTransport {
  const PublicMusicCatalogTransport();
  static Future<dynamic> _decode(Uint8List payload) =>
      Isolate.run(() => jsonDecode(utf8.decode(payload)));
  static void validate(Uri uri, {bool post = false}) {
    final deezer = uri.host == 'api.deezer.com' &&
        !post &&
        (RegExp(r'^/track/[1-9][0-9]{0,18}$').hasMatch(uri.path) &&
                uri.query.isEmpty ||
            RegExp(r'^/playlist/[1-9][0-9]{0,18}$').hasMatch(uri.path) &&
                uri.query.isEmpty ||
            RegExp(r'^/playlist/[1-9][0-9]{0,18}/tracks$').hasMatch(uri.path) &&
                uri.queryParameters.length == 2 &&
                uri.queryParameters['limit'] == '100' &&
                RegExp(r'^[0-9]{1,5}$')
                    .hasMatch(uri.queryParameters['index'] ?? ''));
    final youtube = post &&
        (uri.host == 'music.youtube.com' &&
                ['/youtubei/v1/player', '/youtubei/v1/browse']
                    .contains(uri.path) ||
            uri.host == 'www.youtube.com' &&
                uri.path == '/youtubei/v1/browse') &&
        (uri.query.isEmpty || uri.query == 'prettyPrint=false');
    if (uri.scheme != 'https' ||
        uri.port != 443 ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        !(deezer || youtube)) {
      throw const FormatException('Destino de catálogo não permitido.');
    }
  }

  @override
  Future<Map<String, dynamic>> read(Uri uri,
      {Map<String, Object?>? body}) async {
    validate(uri, post: body != null);
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
        request.headers.set('Origin', 'https://${uri.host}');
        request.write(jsonEncode(body));
      }
      final response =
          await request.close().timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw const FormatException(
            'O catálogo recusou a consulta. Tente novamente mais tarde.');
      }
      final maximum = (uri.path == '/youtubei/v1/browse' ? 8 : 2) * 1024 * 1024;
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
      final payload = bytes.takeBytes();
      final value = await _decode(payload);
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

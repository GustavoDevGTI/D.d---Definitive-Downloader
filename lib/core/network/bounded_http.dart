import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'platform_trust.dart';

class BoundedHttp {
  const BoundedHttp();
  Future<Uint8List> bytes(Uri uri, {int maximumBytes = 2 * 1024 * 1024}) async {
    validateHttpUrl(uri);
    final client = HttpClient(context: await platformSecurityContext())
      ..connectionTimeout = const Duration(seconds: 12);
    try {
      var current = uri;
      for (var redirect = 0; redirect < 5; redirect++) {
        final request =
            await client.getUrl(current).timeout(const Duration(seconds: 15));
        request.followRedirects = false;
        request.headers.set(HttpHeaders.userAgentHeader,
            'DefinitiveDownloader/0.1 (+playlist metadata)');
        final response =
            await request.close().timeout(const Duration(seconds: 15));
        if (response.isRedirect) {
          final location = response.headers.value(HttpHeaders.locationHeader);
          if (location == null) {
            throw const HttpException('Redirecionamento sem destino.');
          }
          final next = current.resolve(location);
          validateHttpUrl(next);
          if (next.host != uri.host) {
            throw const HttpException(
                'A origem redirecionou para outro domínio.');
          }
          current = next;
          continue;
        }
        if (response.statusCode != 200) {
          throw HttpException(
              'A origem respondeu HTTP ${response.statusCode}.');
        }
        if (response.contentLength > maximumBytes) {
          throw const FormatException('Resposta acima do limite de leitura.');
        }
        final output = BytesBuilder(copy: false);
        await for (final chunk
            in response.timeout(const Duration(seconds: 15))) {
          if (output.length + chunk.length > maximumBytes) {
            throw const FormatException('Resposta acima do limite de leitura.');
          }
          output.add(chunk);
        }
        return output.takeBytes();
      }
      throw const HttpException('Muitos redirecionamentos.');
    } finally {
      client.close(force: true);
    }
  }

  Future<String> text(Uri uri) async => utf8.decode(await bytes(uri));
}

void validateHttpUrl(Uri uri) {
  if (!['http', 'https'].contains(uri.scheme) ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    throw const FormatException(
        'Use um endereço HTTP ou HTTPS sem credenciais.');
  }
}

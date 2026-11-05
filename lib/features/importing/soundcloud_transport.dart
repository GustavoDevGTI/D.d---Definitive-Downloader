import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../../core/network/platform_trust.dart';

class SoundCloudResponse {
  const SoundCloudResponse(this.url, this.text);
  final Uri url;
  final String text;
}

abstract interface class SoundCloudTransport {
  Future<SoundCloudResponse> get(Uri url, {required int maximumBytes});
}

/// Public metadata only. No cookie jar, browser profiles or account credentials.
class PublicSoundCloudTransport implements SoundCloudTransport {
  const PublicSoundCloudTransport();
  static void validate(Uri url) {
    final host = url.host.toLowerCase();
    final page = const {
      'soundcloud.com',
      'www.soundcloud.com',
      'm.soundcloud.com',
      'on.soundcloud.com'
    }.contains(host);
    final asset = host == 'a-v2.sndcdn.com' &&
        url.path.startsWith('/assets/') &&
        url.path.endsWith('.js') &&
        !url.hasQuery;
    final api = host == 'api-v2.soundcloud.com' && url.path == '/tracks';
    if (url.scheme != 'https' ||
        url.port != 443 ||
        url.userInfo.isNotEmpty ||
        url.hasFragment ||
        !(page || asset || api)) {
      throw const FormatException('Destino SoundCloud não permitido.');
    }
  }

  @override
  Future<SoundCloudResponse> get(Uri url, {required int maximumBytes}) async {
    validate(url);
    final client = HttpClient(context: await platformSecurityContext())
      ..connectionTimeout = const Duration(seconds: 12);
    final deadline =
        Timer(const Duration(seconds: 40), () => client.close(force: true));
    try {
      var current = url;
      for (var redirects = 0; redirects < 5; redirects++) {
        validate(current);
        final request =
            await client.getUrl(current).timeout(const Duration(seconds: 15));
        request.followRedirects = false;
        request.headers.set(HttpHeaders.userAgentHeader,
            'Mozilla/5.0 DefinitiveDownloader/0.1');
        final response =
            await request.close().timeout(const Duration(seconds: 15));
        if (response.isRedirect) {
          final next = response.headers.value(HttpHeaders.locationHeader);
          if (next == null || !current.host.endsWith('soundcloud.com')) {
            throw const FormatException(
                'Redirecionamento SoundCloud inválido.');
          }
          final target = current.resolve(next);
          if (!const {
            'soundcloud.com',
            'www.soundcloud.com',
            'm.soundcloud.com',
            'on.soundcloud.com'
          }.contains(target.host)) {
            throw const FormatException(
                'O link SoundCloud redirecionou para fora da plataforma.');
          }
          current = target;
          continue;
        }
        if (response.statusCode != 200) {
          throw FormatException(response.statusCode == 429
              ? 'O SoundCloud limitou as consultas. Tente novamente mais tarde.'
              : 'O SoundCloud respondeu HTTP ${response.statusCode}. Use um link público disponível.');
        }
        if (response.contentLength > maximumBytes) {
          throw const FormatException('Resposta SoundCloud acima do limite.');
        }
        final bytes = BytesBuilder(copy: false);
        await for (final chunk
            in response.timeout(const Duration(seconds: 15))) {
          if (bytes.length + chunk.length > maximumBytes) {
            throw const FormatException('Resposta SoundCloud acima do limite.');
          }
          bytes.add(chunk);
        }
        return SoundCloudResponse(current, utf8.decode(bytes.takeBytes()));
      }
      throw const FormatException(
          'Muitos redirecionamentos no link SoundCloud.');
    } on SocketException {
      throw const FormatException('Não foi possível conectar ao SoundCloud.');
    } on TimeoutException {
      throw const FormatException('O SoundCloud demorou para responder.');
    } finally {
      deadline.cancel();
      client.close(force: true);
    }
  }
}

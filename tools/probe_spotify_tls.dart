import 'dart:io';
import 'package:definitive_downloader/core/network/platform_trust.dart';

/// No tokens, credentials or private resources; checks TLS connectivity only.
Future<void> main() async {
  for (final endpoint in [
    'https://accounts.spotify.com/.well-known/openid-configuration',
    'https://api.spotify.com/v1/me',
  ]) {
    final client = HttpClient(context: await platformSecurityContext())
      ..connectionTimeout = const Duration(seconds: 8);
    final uri = Uri.parse(endpoint);
    try {
      final request =
          await client.getUrl(uri).timeout(const Duration(seconds: 10));
      request.followRedirects = false;
      final response =
          await request.close().timeout(const Duration(seconds: 10));
      stdout.writeln(
          '${uri.host}: TLS verified, HTTP ${response.statusCode}; credentials_sent=false');
    } catch (error) {
      stdout
          .writeln('${uri.host}: ${error.runtimeType}; credentials_sent=false');
    } finally {
      client.close(force: true);
    }
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../core/network/platform_trust.dart';
import '../downloads/download_cancellation.dart';
import '../library/domain/models.dart';
import 'spotify_importer.dart';
import 'trackhop_client.dart';

class ManagedSpotifyPlaylists {
  ManagedSpotifyPlaylists(String address) : _origin = Uri.parse(address) {
    if (_origin.scheme != 'https' ||
        _origin.host.isEmpty ||
        _origin.userInfo.isNotEmpty ||
        _origin.hasQuery ||
        _origin.hasFragment ||
        (_origin.path.isNotEmpty && _origin.path != '/')) {
      throw const FormatException(
          'O serviço de playlists exige um endereço HTTPS.');
    }
  }

  static const source = 'Spotify · importação por link';
  final Uri _origin;

  Future<ImportedCollection> open(String input,
      {bool Function()? cancelled, void Function(int, int)? onProgress}) async {
    final id = SpotifyImporter.idFromLink(input);
    if (cancelled?.call() == true) throw const DownloadCancelled();
    final uri =
        _origin.replace(pathSegments: ['v1', 'spotify', 'playlists', id]);
    final client = HttpClient(context: await platformSecurityContext())
      ..connectionTimeout = const Duration(seconds: 10);
    final timeout =
        Timer(const Duration(seconds: 90), () => client.close(force: true));
    final cancelTimer = cancelled == null
        ? null
        : Timer.periodic(const Duration(milliseconds: 200), (_) {
            if (cancelled()) client.close(force: true);
          });
    try {
      final request = await client.getUrl(uri);
      request.followRedirects = false;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close();
      switch (response.statusCode) {
        case 200:
          break;
        case 404:
          throw const PublicSpotifyPlaylistRequired();
        case 422:
          throw FormatException(switch (await _errorCode(response)) {
            'playlist_too_large' =>
              'A playlist ultrapassa o limite de faixas do serviço. Importe um CSV.',
            _ =>
              'A playlist não contém faixas de música que possam ser importadas.',
          });
        case 429:
          throw FormatException(switch (await _errorCode(response)) {
            'monthly_limit' =>
              'A cota de importação por link está esgotada. Você ainda pode importar um CSV.',
            _ =>
              'O serviço de playlists está ocupado. Tente novamente em instantes.',
          });
        case 502:
          throw const FormatException(
              'A playlist chegou incompleta. Tente novamente ou importe o CSV.');
        default:
          throw const FormatException(
              'O serviço de playlists está temporariamente indisponível. Tente novamente ou importe o CSV.');
      }
      const limit = 12 * 1024 * 1024;
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in response) {
        if (bytes.length + chunk.length > limit) {
          throw const FormatException(
              'A playlist excedeu o limite de leitura.');
        }
        bytes.add(chunk);
      }
      if (cancelled?.call() == true) throw const DownloadCancelled();
      final payload = jsonDecode(utf8.decode(bytes.takeBytes()));
      if (payload is! Map ||
          payload['id'] != id ||
          payload['name'] is! String ||
          payload['tracks'] is! List) {
        throw const FormatException(
            'O serviço retornou uma playlist inválida.');
      }
      final rows = payload['tracks'] as List;
      final skipped = payload['skipped'] ?? 0;
      if (rows.isEmpty ||
          skipped is! int ||
          skipped < 0 ||
          rows.length + skipped > 10000 ||
          payload['total'] != rows.length) {
        throw const FormatException(
            'O serviço retornou uma playlist incompleta.');
      }
      final tracks =
          rows.map(TrackhopClient.parseTrack).toList(growable: false);
      onProgress?.call(tracks.length, tracks.length);
      return ImportedCollection(
          name: payload['name'] as String,
          source: source,
          sourceUrl: 'https://open.spotify.com/playlist/$id',
          skippedCount: skipped,
          tracks: Stream.fromIterable(tracks));
    } on IOException {
      if (cancelled?.call() == true) throw const DownloadCancelled();
      rethrow;
    } finally {
      cancelTimer?.cancel();
      timeout.cancel();
      client.close(force: true);
    }
  }

  static Future<String?> _errorCode(HttpClientResponse response) async {
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response) {
      if (bytes.length + chunk.length > 4096) return null;
      bytes.add(chunk);
    }
    try {
      final body = jsonDecode(utf8.decode(bytes.takeBytes()));
      return body is Map && body['error'] is String
          ? body['error'] as String
          : null;
    } on FormatException {
      return null;
    }
  }
}

class PublicSpotifyPlaylistRequired extends FormatException {
  const PublicSpotifyPlaylistRequired()
      : super(
            'A leitura por link precisa de uma playlist pública. Para uma playlist privada, use Conexões ou importe o CSV.');
}

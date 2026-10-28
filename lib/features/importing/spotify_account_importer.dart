import '../connections/domain/spotify_auth.dart';
import '../library/domain/models.dart';
import 'spotify_importer.dart';
import '../../core/network/bounded_http.dart';

typedef SpotifyJsonReader = Future<Map<String, dynamic>> Function(String path,
    {Map<String, String> query});

class SpotifyAccountImporter {
  const SpotifyAccountImporter(this.read, this.connected);
  final SpotifyJsonReader read;
  final bool Function() connected;
  bool get isConnected => connected();

  Future<ImportedCollection> open(String input) async {
    final id = const SpotifyImporter(BoundedHttp()).playlistId(input);
    final initial = await read('/playlists/$id');
    final items = initial['items'] ?? initial['tracks'];
    final total = items is Map ? items['total'] : null;
    if (total is! int) {
      throw const SpotifyException(
          'A conta não recebeu acesso ao conteúdo desta playlist. Use uma lista própria ou colaborativa.');
    }
    if (total <= 0 || total > 10000) {
      throw const SpotifyException('Use uma playlist com 1 a 10.000 entradas.');
    }
    final snapshot = initial['snapshot_id'];
    return ImportedCollection(
        name: (initial['name'] ?? 'Playlist Spotify').toString(),
        source: 'Spotify · conta conectada',
        sourceUrl: 'https://open.spotify.com/playlist/$id',
        tracks: _tracks(id, total, snapshot));
  }

  Stream<TrackDraft> _tracks(String id, int total, Object? snapshot) async* {
    var offset = 0;
    while (offset < total) {
      final page = await read('/playlists/$id/items',
          query: {'limit': '50', 'offset': '$offset'});
      final entries = page['items'];
      if (entries is! List ||
          entries.isEmpty ||
          page['total'] != total ||
          (page['offset'] != null && page['offset'] != offset)) {
        throw const SpotifyException(
            'A leitura da playlist ficou incompleta ou a lista mudou. Tente importar novamente.');
      }
      if (offset + entries.length > total) {
        throw const SpotifyException(
            'O total de entradas da playlist mudou durante a leitura.');
      }
      for (final entry in entries) {
        offset++;
        final item = entry is Map ? entry['item'] ?? entry['track'] : null;
        if (item is! Map ||
            item['type'] == 'episode' ||
            item['is_local'] == true ||
            item['name'] is! String ||
            item['artists'] is! List) {
          yield TrackDraft(
              title: 'Entrada indisponível ou não musical ($offset)',
              artist: 'Spotify · conferir na origem');
          continue;
        }
        final artists = (item['artists'] as List)
            .whereType<Map>()
            .map((artist) => artist['name'])
            .whereType<String>()
            .join(', ');
        final album = item['album'];
        final images = album is Map ? album['images'] : null;
        final trackId = item['id']?.toString() ?? '';
        yield TrackDraft(
            title: item['name'] as String,
            explicit:
                item['explicit'] is bool ? item['explicit'] as bool : null,
            artist: artists.isEmpty ? 'Artista indisponível' : artists,
            album: album is Map ? (album['name'] ?? '').toString() : '',
            durationMs: (item['duration_ms'] as num?)?.toInt(),
            coverUrl: images is List && images.isNotEmpty && images.first is Map
                ? (images.first['url'] ?? '').toString()
                : '',
            isrc: item['external_ids'] is Map
                ? (item['external_ids']['isrc'] ?? '').toString()
                : '',
            sourceUrl: RegExp(r'^[A-Za-z0-9]{22}$').hasMatch(trackId)
                ? 'https://open.spotify.com/track/$trackId'
                : '');
      }
    }
    if (snapshot != null) {
      final latest =
          await read('/playlists/$id', query: {'fields': 'snapshot_id'});
      if (latest['snapshot_id'] != snapshot) {
        throw const SpotifyException(
            'A playlist mudou durante a importação. Nenhuma cópia incompleta foi mantida; tente novamente.');
      }
    }
  }
}

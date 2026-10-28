import 'dart:convert';
import 'package:html/parser.dart' as html;
import '../../core/network/bounded_http.dart';
import '../library/domain/models.dart';

class SpotifyImporter {
  const SpotifyImporter(this.http);
  final BoundedHttp http;

  String playlistId(String input) {
    final text = input.trim();
    final uri = Uri.tryParse(text);
    String? id;
    if (text.startsWith('spotify:playlist:')) {
      id = text.split(':').last;
    } else if (uri != null &&
        uri.scheme == 'https' &&
        uri.host == 'open.spotify.com') {
      final segments = uri.pathSegments;
      final index = segments.indexOf('playlist');
      if (index >= 0 && segments.length > index + 1) id = segments[index + 1];
    }
    if (id == null || !RegExp(r'^[A-Za-z0-9]{22}$').hasMatch(id)) {
      throw const FormatException(
          'Cole um link de playlist de open.spotify.com.');
    }
    return id;
  }

  Future<ImportedCollection> open(String input) async {
    final id = playlistId(input);
    final body =
        await http.text(Uri.https('open.spotify.com', '/embed/playlist/$id'));
    final element = html.parse(body).getElementById('__NEXT_DATA__');
    if (element == null) {
      throw const FormatException(
          'O Spotify não disponibilizou a lista pública. Importe um CSV ou aguarde a integração de conta.');
    }
    final payload = jsonDecode(element.text) as Map<String, dynamic>;
    final entity = payload['props']?['pageProps']?['state']?['data']?['entity'];
    if (entity is! Map<String, dynamic>) {
      throw const FormatException(
          'A resposta pública do Spotify mudou. Importe um CSV.');
    }
    final list = entity['trackList'];
    if (list is! List || list.isEmpty) {
      throw const FormatException(
          'Nenhuma faixa foi disponibilizada nessa playlist.');
    }
    final tracks = <TrackDraft>[];
    for (final item in list.take(300)) {
      if (item is! Map<String, dynamic>) continue;
      final title = (item['title'] ?? item['name'] ?? '').toString();
      final artists = item['artists'];
      final artist = artists is List
          ? artists.whereType<Map>().map((a) => a['name']).join(', ')
          : (item['subtitle'] ?? '').toString();
      if (title.isEmpty || artist.isEmpty) continue;
      final rawDuration = item['duration'] ?? item['duration_ms'];
      final duration = rawDuration is num ? rawDuration.toInt() : null;
      final uri = (item['uri'] ?? item['id'] ?? '').toString();
      tracks.add(TrackDraft(
          title: title,
          artist: artist,
          durationMs: duration,
          sourceUrl: uri.startsWith('spotify:track:')
              ? 'https://open.spotify.com/track/${uri.split(':').last}'
              : '',
          isrc: (item['isrc'] ?? '').toString()));
    }
    if (tracks.isEmpty) {
      throw const FormatException(
          'A lista pública não trouxe faixas identificáveis.');
    }
    return ImportedCollection(
        name: (entity['title'] ?? entity['name'] ?? 'Playlist Spotify')
            .toString(),
        source: 'Spotify · leitura pública',
        sourceUrl: 'https://open.spotify.com/playlist/$id',
        tracks: Stream.fromIterable(tracks),
        isPartial: true);
  }
}

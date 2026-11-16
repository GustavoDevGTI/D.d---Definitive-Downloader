import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import '../library/domain/models.dart';

/// Reads the playlist JSON from Spotify's account data download.
/// This importer never sends requests or opens a Spotify session.
class SpotifyPlaylistExport {
  const SpotifyPlaylistExport._(this.name, this.tracks, this.skipped);

  static const source = 'Spotify · arquivo';
  static const _limit = 5 * 1024 * 1024;
  static final _trackUri = RegExp(r'^spotify:track:([a-zA-Z0-9]{22})$');
  final String name;
  final List<TrackDraft> tracks;
  final int skipped;

  static Future<List<SpotifyPlaylistExport>> read(String path) =>
      Isolate.run(() => _read(path));

  static Future<List<SpotifyPlaylistExport>> _read(String path) async {
    final file = File(path);
    if (await file.length() > _limit) {
      throw const FormatException('O arquivo de playlists ultrapassa 5 MB.');
    }
    // Read at most one byte past the limit, even if the file changes.
    final data = await file.open();
    final List<int> bytes;
    try {
      bytes = await data.read(_limit + 1);
    } finally {
      await data.close();
    }
    if (bytes.length > _limit) {
      throw const FormatException('O arquivo de playlists ultrapassa 5 MB.');
    }
    final Object? root;
    try {
      root = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      throw const FormatException(
          'O arquivo de playlists não é um JSON válido.');
    }
    if (root is! Map || root['playlists'] is! List) {
      throw const FormatException(
          'Selecione Playlist1.json (ou outro Playlist*.json) dos dados do Spotify.');
    }
    final playlists = <SpotifyPlaylistExport>[];
    for (final entry in root['playlists'] as List) {
      if (entry is! Map || entry['items'] is! List) continue;
      final name = _field(entry, 'name');
      if (name.isEmpty) continue;
      final items = entry['items'] as List;
      final tracks = <TrackDraft>[];
      for (final item in items) {
        final track = item is Map ? item['track'] : null;
        if (track is! Map) continue; // Podcast or local file.
        final title = _field(track, 'trackName');
        final artist = _field(track, 'artistName');
        if (title.isEmpty || artist.isEmpty) continue;
        final id = _trackUri.firstMatch(_field(track, 'trackUri'))?.group(1);
        tracks.add(TrackDraft(
            title: title,
            artist: artist,
            album: _field(track, 'albumName'),
            sourceUrl: id == null ? '' : 'https://open.spotify.com/track/$id'));
      }
      if (tracks.isNotEmpty) {
        playlists.add(SpotifyPlaylistExport._(
            name, tracks, items.length - tracks.length));
      }
    }
    if (playlists.isEmpty) {
      throw const FormatException(
          'Nenhuma playlist com músicas neste arquivo.');
    }
    return playlists;
  }

  static String _field(Map row, String key) =>
      row[key] is String ? (row[key] as String).trim() : '';

  ImportedCollection open() => ImportedCollection(
      name: name,
      source: source,
      sourceUrl: '',
      tracks: Stream.fromIterable(tracks));
}

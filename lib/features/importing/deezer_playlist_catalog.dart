import '../downloads/download_cancellation.dart';
import '../library/domain/models.dart';
import 'music_catalog_transport.dart';
import 'public_playlist_link.dart';

class DeezerPlaylistCatalog {
  const DeezerPlaylistCatalog(
      {this.transport = const PublicMusicCatalogTransport()});
  final MusicCatalogTransport transport;

  Future<ImportedCollection> open(PublicPlaylistLink link,
      {bool downloadAvailable = false,
      bool Function()? cancelled,
      void Function(int, int)? onProgress}) async {
    void check() {
      if (cancelled?.call() == true) throw const DownloadCancelled();
    }

    check();
    final initial = await transport
        .read(Uri.https('api.deezer.com', '/playlist/${link.id}'));
    check();
    final total = initial['nb_tracks'];
    if ('${initial['id']}' != link.id ||
        initial['error'] != null ||
        initial['public'] == false ||
        total is! int ||
        total < 1 ||
        total > 10000) {
      throw const FormatException(
          'Playlist Deezer indisponível, vazia ou acima de 10.000 faixas.');
    }
    final drafts = <TrackDraft>[];
    while (drafts.length < total) {
      check();
      final offset = drafts.length;
      final page = await transport.read(Uri.https('api.deezer.com',
          '/playlist/${link.id}/tracks', {'limit': '100', 'index': '$offset'}));
      check();
      final rows = page['data'];
      if (page['error'] != null ||
          rows is! List ||
          rows.isEmpty ||
          rows.length > 100 ||
          page['total'] != total ||
          drafts.length + rows.length > total) {
        throw const FormatException(
            'A playlist Deezer mudou ou chegou incompleta. Importe novamente.');
      }
      for (final row in rows) {
        if (row is! Map) {
          throw const FormatException('Entrada Deezer inválida.');
        }
        drafts.add(_draft(row, link.url, downloadAvailable));
      }
      // Follow only the expected index on our own endpoint, never a remote URL.
      if (drafts.length < total) {
        final next = Uri.tryParse('${page['next'] ?? ''}');
        if (next == null ||
            next.host != 'api.deezer.com' ||
            !['http', 'https'].contains(next.scheme) ||
            next.userInfo.isNotEmpty ||
            next.path != '/playlist/${link.id}/tracks' ||
            next.queryParameters['index'] != '${drafts.length}') {
          throw const FormatException(
              'Paginação Deezer incompleta ou inválida.');
        }
      }
      onProgress?.call(drafts.length, total);
    }
    check();
    final end = await transport
        .read(Uri.https('api.deezer.com', '/playlist/${link.id}'));
    check();
    if ('${end['id']}' != link.id ||
        end['nb_tracks'] != total ||
        (initial['checksum'] != null &&
            end['checksum'] != initial['checksum'])) {
      throw const FormatException(
          'A playlist Deezer mudou durante a importação. Tente novamente.');
    }
    return ImportedCollection(
        name: _text(initial['title'], 'Playlist Deezer'),
        source: 'Deezer · público',
        sourceUrl: link.url,
        tracks: Stream.fromIterable(drafts));
  }

  static TrackDraft _draft(Map row, String playlist, bool available) {
    final id = '${row['id']}';
    final validId = RegExp(r'^[1-9][0-9]{0,18}$').hasMatch(id);
    final url = validId ? 'https://www.deezer.com/track/$id' : playlist;
    final artist = row['artist'] is Map ? _text(row['artist']['name'], '') : '';
    final album = row['album'] is Map ? row['album'] as Map : const {};
    final duration = row['duration'];
    final ms = duration is num && duration >= 1 && duration <= 3600
        ? (duration * 1000).round()
        : null;
    final title = _text(row['title'], 'Faixa indisponível');
    final complete = validId &&
        row['readable'] != false &&
        artist.isNotEmpty &&
        ms != null &&
        row['title'] is String &&
        (row['title'] as String).trim().isNotEmpty;
    final cover = Uri.tryParse('${album['cover_medium'] ?? ''}');
    return TrackDraft(
        title: title,
        artist: artist,
        album: _text(album['title'], ''),
        durationMs: ms,
        sourceUrl: url,
        manualUrl: url,
        mediaUrl: complete ? url : '',
        sourceKind: complete ? SourceKind.deezerFull : SourceKind.none,
        recordingType: complete ? 'DEEZER_TRACK' : '',
        sourceReady: available,
        isrc: _text(row['isrc'], ''),
        explicit:
            row['explicit_lyrics'] is bool ? row['explicit_lyrics'] : null,
        coverUrl: cover?.scheme == 'https' && cover!.userInfo.isEmpty
            ? cover.toString()
            : '',
        pendingReason: !complete
            ? 'Faixa Deezer indisponível. Escolha uma fonte na conferência.'
            : available
                ? ''
                : 'Conecte a Deezer em uma plataforma com motor musical para baixar.');
  }

  static String _text(Object? value, String fallback) {
    if (value == null || value == '') return fallback;
    if (value is! String ||
        value.length > 400 ||
        value.contains(RegExp(r'[\x00-\x1f]'))) {
      throw const FormatException('Metadados Deezer inválidos.');
    }
    return value.trim().isEmpty ? fallback : value.trim();
  }
}

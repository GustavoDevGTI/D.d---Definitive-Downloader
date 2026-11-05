import 'dart:isolate';
import '../downloads/download_cancellation.dart';
import '../library/domain/models.dart';
import 'music_catalog_transport.dart';
import 'public_playlist_link.dart';
import 'youtube_playlist_page.dart';

class YouTubePlaylistCatalog {
  const YouTubePlaylistCatalog(
      {this.transport = const PublicMusicCatalogTransport()});
  final MusicCatalogTransport transport;
  static Future<YouTubePlaylistPage> _parse(Map<String, dynamic> response,
          PublicPlaylistLink link, bool initial, bool available) =>
      Isolate.run(() => YouTubePlaylistPage.parse(response, link,
          initial: initial, available: available));

  Future<ImportedCollection> open(PublicPlaylistLink link,
      {bool downloadAvailable = false,
      bool Function()? cancelled,
      void Function(int, int)? onProgress}) async {
    void check() {
      if (cancelled?.call() == true) throw const DownloadCancelled();
    }

    final music = link.kind == PublicPlaylistKind.youtubeMusic;
    final now = DateTime.now().toUtc();
    final date =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final context = {
      'client': {
        'clientName': music ? 'WEB_REMIX' : 'WEB',
        'clientVersion': '${music ? 1 : 2}.$date.01.00',
        'hl': 'en',
        'gl': 'US'
      }
    };
    final endpoint = Uri.https(music ? 'music.youtube.com' : 'www.youtube.com',
        '/youtubei/v1/browse', {'prettyPrint': 'false'});
    final seen = <String>{};
    final tracks = <TrackDraft>[];
    var continuation = '', title = '';
    int? total;
    var initial = true;
    for (var pageNumber = 0; pageNumber < 300; pageNumber++) {
      check();
      final response = await transport.read(endpoint, body: {
        'context': context,
        if (initial && !music) 'params': 'wgYCCAA=',
        if (initial)
          'browseId': 'VL${link.id}'
        else
          'continuation': continuation,
      });
      check();
      final page = await _parse(response, link, initial, downloadAvailable);
      check();
      if (initial) {
        title = page.title;
        total = page.total;
      }
      if ((total != null && (total < 1 || total > 10000)) ||
          tracks.length + page.tracks.length > 10000) {
        throw const FormatException(
            'Use uma playlist com 1 a 10.000 entradas.');
      }
      if (page.tracks.isEmpty && page.continuation.isNotEmpty) {
        throw const FormatException(
            'O YouTube retornou uma página incompleta.');
      }
      tracks.addAll(page.tracks);
      onProgress?.call(tracks.length, total ?? tracks.length);
      continuation = page.continuation;
      if (continuation.isEmpty) {
        if (tracks.isEmpty || (total != null && tracks.length != total)) {
          throw const FormatException(
              'A playlist YouTube está vazia ou incompleta. Verifique se há vídeos ocultos.');
        }
        return ImportedCollection(
            name: title,
            source: '${music ? 'YouTube Music' : 'YouTube'} · público',
            sourceUrl: link.url,
            tracks: Stream.fromIterable(tracks));
      }
      if (!seen.add(continuation)) {
        throw const FormatException(
            'O YouTube repetiu uma página. Importação interrompida.');
      }
      initial = false;
    }
    throw const FormatException('A playlist ultrapassou o limite de páginas.');
  }
}

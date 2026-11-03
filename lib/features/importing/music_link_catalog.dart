import '../library/domain/models.dart';
import 'music_link.dart';
import 'music_catalog_transport.dart';
import 'spotify_account_importer.dart';

class MusicLinkCatalog {
  const MusicLinkCatalog(
      {this.transport = const PublicMusicCatalogTransport(), this.spotify});
  final MusicCatalogTransport transport;
  final SpotifyAccountImporter? spotify;

  Future<ResolvedMusicLink> resolve(MusicLink link) async {
    if (link.kind == MusicLinkKind.mp3) {
      final name = Uri.parse(link.url)
          .pathSegments
          .last
          .replaceFirst(RegExp(r'\.mp3$', caseSensitive: false), '');
      return ResolvedMusicLink(
          link: link,
          pinned: true,
          ready: true,
          draft: TrackDraft(
              title: _text(name.isEmpty ? 'Áudio' : name),
              artist: '',
              sourceUrl: link.url,
              mediaUrl: link.url,
              sourceKind: SourceKind.directMp3));
    }
    if (link.kind == MusicLinkKind.spotify) {
      if (spotify?.isConnected != true) {
        throw const FormatException(
            'Conecte o Spotify para conferir esta faixa.');
      }
      final row = await spotify!.read('/tracks/${link.id}');
      if (row['id'] != link.id ||
          row['type'] != 'track' ||
          row['is_local'] == true) {
        throw const FormatException(
            'A resposta não corresponde à faixa Spotify.');
      }
      final artists = row['artists'];
      final album = row['album'];
      if (artists is! List || artists.isEmpty || album is! Map) {
        throw const FormatException('Metadados Spotify incompletos.');
      }
      final artist = artists
          .take(8)
          .whereType<Map>()
          .map((r) => _text(r['name']))
          .join(', ');
      final images = album['images'];
      return ResolvedMusicLink(
          link: link,
          draft: TrackDraft(
              title: _text(row['name']),
              artist: artist,
              album: _text(album['name'], optional: true),
              durationMs: _duration(row['duration_ms']),
              sourceUrl: link.url,
              isrc: row['external_ids'] is Map
                  ? _text(row['external_ids']['isrc'], optional: true)
                  : '',
              coverUrl:
                  images is List && images.isNotEmpty && images.first is Map
                      ? _image(images.first['url'])
                      : '',
              explicit:
                  row['explicit'] is bool ? row['explicit'] as bool : null));
    }
    Candidate source;
    if (link.kind == MusicLinkKind.deezer) {
      final row = await transport
          .read(Uri.https('api.deezer.com', '/track/${link.id}'));
      if ('${row['id']}' != link.id ||
          row['type'] != 'track' ||
          row['error'] != null ||
          row['readable'] == false ||
          row['artist'] is! Map ||
          row['album'] is! Map) {
        throw const FormatException(
            'A faixa Deezer não está disponível no catálogo.');
      }
      source = Candidate(
          title: _text(row['title']),
          artist: _text(row['artist']['name']),
          album: _text(row['album']['title'], optional: true),
          durationMs: _duration(row['duration'], seconds: true),
          pageUrl: link.url,
          previewUrl: '',
          coverUrl: _image(row['album']['cover_medium']),
          isrc: _text(row['isrc'], optional: true),
          kind: SourceKind.deezerFull,
          recordingType: 'DEEZER_TRACK',
          explicit: row['explicit_lyrics'] is bool
              ? row['explicit_lyrics'] as bool
              : null);
    } else {
      final now = DateTime.now().toUtc();
      final date =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final row = await transport.read(
          Uri.https('music.youtube.com', '/youtubei/v1/player',
              {'prettyPrint': 'false'}),
          body: {
            'video_id': link.id,
            'context': {
              'client': {
                'clientName': 'WEB_REMIX',
                'clientVersion': '1.$date.01.00'
              },
              'user': <String, Object?>{}
            },
            'playbackContext': {
              'contentPlaybackContext': {
                'signatureTimestamp': now.millisecondsSinceEpoch ~/ 86400000 - 1
              }
            },
          });
      final details = row['videoDetails'];
      if (details is! Map ||
          details['videoId'] != link.id ||
          details['isLiveContent'] == true ||
          details['isLive'] == true ||
          details['isTvfilmVideo'] == true ||
          row['playabilityStatus'] is! Map ||
          row['playabilityStatus']['status'] != 'OK') {
        throw const FormatException(
            'Este link do YouTube está indisponível ou é uma transmissão ao vivo.');
      }
      final thumbnails = details['thumbnail'] is Map
          ? details['thumbnail']['thumbnails']
          : null;
      source = Candidate(
          title: _text(details['title']),
          artist:
              _text(details['author']).replaceFirst(RegExp(r' - Topic$'), ''),
          album: '',
          durationMs: _duration(int.tryParse('${details['lengthSeconds']}'),
              seconds: true),
          pageUrl: link.kind == MusicLinkKind.youtubeMusic &&
                  details['musicVideoType'] == 'MUSIC_VIDEO_TYPE_ATV'
              ? link.url
              : 'https://www.youtube.com/watch?v=${link.id}',
          previewUrl: '',
          coverUrl: thumbnails is List &&
                  thumbnails.isNotEmpty &&
                  thumbnails.last is Map
              ? _image(thumbnails.last['url'])
              : '',
          kind: link.kind == MusicLinkKind.youtubeMusic &&
                  details['musicVideoType'] == 'MUSIC_VIDEO_TYPE_ATV'
              ? SourceKind.youtubeMusic
              : SourceKind.youtube,
          recordingType: details['musicVideoType'] is String
              ? details['musicVideoType'] as String
              : '');
    }
    if (!source.isFullRecording && source.kind != SourceKind.youtube) {
      throw const FormatException('Tipo de gravação não confirmado.');
    }
    return ResolvedMusicLink(
        link: link,
        source: source,
        alternatives: [source],
        pinned: true,
        draft: TrackDraft(
            title: source.title,
            artist: source.artist,
            album: source.album,
            durationMs: source.durationMs,
            isrc: source.isrc,
            coverUrl: source.coverUrl,
            sourceUrl: link.url,
            explicit: source.explicit));
  }

  static String _text(Object? value, {bool optional = false}) {
    if (value == null && optional) return '';
    if (value is! String ||
        value.length > 400 ||
        value.contains(RegExp(r'[\x00-\x1f]')) ||
        (!optional && value.trim().isEmpty)) {
      throw const FormatException('Metadados musicais inválidos.');
    }
    return value.trim();
  }

  static int _duration(Object? value, {bool seconds = false}) {
    if (value is! num) {
      throw const FormatException('Duração não informada pelo catálogo.');
    }
    final duration = (value * (seconds ? 1000 : 1)).round();
    if (duration < 1000 || duration > 3600000) {
      throw const FormatException('Duração musical inválida.');
    }
    return duration;
  }

  static String _image(Object? value) {
    if (value == null || value == '') return '';
    if (value is! String || value.length > 2048) {
      throw const FormatException('Capa inválida.');
    }
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'https' || uri.userInfo.isNotEmpty) {
      return '';
    }
    return value;
  }
}

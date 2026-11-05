import '../library/domain/models.dart';
import 'public_playlist_link.dart';

class YouTubePlaylistPage {
  const YouTubePlaylistPage(
      this.tracks, this.continuation, this.title, this.total);
  final List<TrackDraft> tracks;
  final String continuation, title;
  final int? total;

  static YouTubePlaylistPage parse(
      Map<String, dynamic> response, PublicPlaylistLink link,
      {required bool initial, required bool available}) {
    final music = link.kind == PublicPlaylistKind.youtubeMusic;
    final shelf = _find(response['contents'],
        music ? 'musicPlaylistShelfRenderer' : 'playlistVideoListRenderer');
    if (music && initial && shelf?['playlistId'] != link.id) {
      throw const FormatException(
          'A resposta não corresponde à playlist YouTube Music.');
    }
    List? contents = shelf?['contents'] as List?;
    if (contents == null && !initial) {
      final continuation = _find(
          response['continuationContents'],
          music
              ? 'musicPlaylistShelfContinuation'
              : 'playlistVideoListContinuation');
      contents = continuation?['contents'] as List?;
      if (contents == null) {
        final actions = response['onResponseReceivedActions'] ??
            response['onResponseReceivedEndpoints'];
        contents = _find(
                actions, 'appendContinuationItemsAction')?['continuationItems']
            as List?;
      }
    }
    if (contents == null && initial && !music) {
      contents = _videoSection(response['contents']);
    }
    if (contents == null ||
        contents.length > 1000 ||
        response['error'] != null) {
      throw const FormatException(
          'O leitor de playlist do YouTube mudou ou a lista não está disponível.');
    }
    final drafts = <TrackDraft>[];
    String token = '';
    for (final entry in contents) {
      if (entry is! Map) {
        throw const FormatException('Entrada YouTube inválida.');
      }
      final row = entry['musicResponsiveListItemRenderer'] ??
          entry['playlistVideoRenderer'] ??
          entry['lockupViewModel'];
      if (row is Map) {
        drafts.add(_draft(row, link, available));
      } else if (entry.containsKey('continuationItemRenderer') ||
          entry.containsKey('continuationItemViewModel')) {
        final found = _token(entry);
        if (found.isEmpty || (token.isNotEmpty && token != found)) {
          throw const FormatException('Continuação YouTube inválida.');
        }
        token = found;
      } else if (!entry.containsKey('messageRenderer')) {
        // Never silently drop a changed row shape or replace it with recommendations.
        throw const FormatException(
            'Uma entrada da playlist não pôde ser lida.');
      }
    }
    final continuations = shelf?['continuations'] ??
        _find(response['continuationContents'],
            'musicPlaylistShelfContinuation')?['continuations'];
    if (token.isEmpty && continuations is List && continuations.isNotEmpty) {
      token =
          _text(_find(continuations, 'nextContinuationData')?['continuation']);
    }
    if (token.length > 20000) {
      throw const FormatException('Continuação YouTube acima do limite.');
    }
    final metadata = _find(response['metadata'], 'playlistMetadataRenderer');
    if (initial && !music) {
      final canonical = Uri.tryParse(_text(_find(response['microformat'],
          'microformatDataRenderer')?['urlCanonical']));
      final indexed = Uri.tryParse(_text(metadata?['androidAppindexingLink']));
      if (canonical?.queryParameters['list'] != link.id &&
          indexed?.queryParameters['list'] != link.id) {
        throw const FormatException(
            'A resposta não corresponde à playlist YouTube.');
      }
    }
    final header = _find(response, 'musicResponsiveHeaderRenderer') ??
        _find(response, 'musicDetailHeaderRenderer');
    final name =
        _bounded(_text(music ? (header?['title']) : (metadata?['title'])));
    if (initial && name.isEmpty) {
      throw const FormatException('Nome da playlist não confirmado.');
    }
    final sidebar =
        _find(response['sidebar'], 'playlistSidebarPrimaryInfoRenderer');
    final summary =
        music ? _text(header?['secondSubtitle']) : _text(sidebar?['stats']);
    final count =
        RegExp(r'([0-9][0-9,]*) (?:tracks|songs|videos)\b').firstMatch(summary);
    return YouTubePlaylistPage(drafts, token, name,
        count == null ? null : int.tryParse(count[1]!.replaceAll(',', '')));
  }

  static TrackDraft _draft(Map row, PublicPlaylistLink link, bool available) {
    final music = link.kind == PublicPlaylistKind.youtubeMusic;
    final modern = row['contentId'] != null;
    final columns = row['flexColumns'];
    final flex = columns is List ? columns : const [];
    String column(int index) => index >= flex.length
        ? ''
        : _text(_find(
            flex[index], 'musicResponsiveListItemFlexColumnRenderer')?['text']);
    final id = _text(music
        ? (row['playlistItemData'] is Map
            ? row['playlistItemData']['videoId']
            : null)
        : modern
            ? row['contentId']
            : row['videoId']);
    final validId = RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id);
    final metadata =
        modern ? _find(row['metadata'], 'lockupMetadataViewModel') : null;
    final title =
        music ? column(0) : _text(modern ? (metadata?['title']) : row['title']);
    final artist = music
        ? column(1)
        : modern
            ? _text(_find(metadata?['metadata'], 'contentMetadataViewModel')?[
                    'metadataRows'] is List
                ? (_find(metadata?['metadata'], 'contentMetadataViewModel')![
                        'metadataRows'] as List)
                    .firstOrNull
                : null)
            : _text(row['shortBylineText']);
    final label = music
        ? _text(row['fixedColumns'])
        : modern
            ? _text(
                _find(row['contentImage'], 'thumbnailBadgeViewModel')?['text'])
            : _text(row['lengthText']);
    final ms = _duration(label);
    final endpoint = _find(row, 'watchEndpoint');
    final type =
        _text(_find(endpoint, 'watchEndpointMusicConfig')?['musicVideoType']);
    final atv = music && type == 'MUSIC_VIDEO_TYPE_ATV';
    final source = validId
        ? Uri.https(music ? 'music.youtube.com' : 'www.youtube.com', '/watch',
            {'v': id}).toString()
        : link.url;
    final media = validId
        ? Uri.https(atv ? 'music.youtube.com' : 'www.youtube.com', '/watch',
            {'v': id}).toString()
        : '';
    final playable = row['isPlayable'] != false &&
        row['musicItemRendererDisplayPolicy'] !=
            'MUSIC_ITEM_RENDERER_DISPLAY_POLICY_GREY_OUT';
    final complete = validId && title.isNotEmpty && ms != null && playable;
    final thumbnails =
        _find(row['thumbnail'], 'musicThumbnailRenderer')?['thumbnail'];
    final images = thumbnails is Map ? thumbnails['thumbnails'] : null;
    final image = images is List && images.isNotEmpty && images.last is Map
        ? '${images.last['url'] ?? ''}'
        : '';
    final cover = Uri.tryParse(image);
    return TrackDraft(
        title: title.isEmpty ? 'Vídeo indisponível' : _bounded(title),
        artist: _bounded(artist).replaceFirst(RegExp(r' - Topic$'), ''),
        album: music ? _bounded(column(2)) : '',
        durationMs: ms,
        sourceUrl: source,
        manualUrl: source,
        mediaUrl: complete ? media : '',
        sourceKind: !complete
            ? SourceKind.none
            : atv
                ? SourceKind.youtubeMusic
                : SourceKind.youtube,
        recordingType: complete ? type : '',
        sourceReady: available,
        coverUrl: cover?.scheme == 'https' &&
                cover!.userInfo.isEmpty &&
                image.length <= 2048
            ? image
            : validId
                ? 'https://i.ytimg.com/vi/$id/hqdefault.jpg'
                : '',
        pendingReason: !complete
            ? 'Vídeo indisponível ou duração musical não confirmada. Confira a fonte.'
            : available
                ? ''
                : 'Download musical não está disponível nesta plataforma.');
  }

  static int? _duration(String value) {
    final match =
        RegExp(r'^\s*(?:(\d{1,2}):)?(\d{1,2}):(\d{2})\s*$').firstMatch(value);
    if (match == null) return null;
    final seconds = int.parse(match[3]!);
    final minutes = int.parse(match[2]!);
    final hours = int.parse(match[1] ?? '0');
    final total = hours * 3600 + minutes * 60 + seconds;
    return seconds < 60 &&
            (hours == 0 || minutes < 60) &&
            total >= 1 &&
            total <= 3600
        ? total * 1000
        : null;
  }

  static String _bounded(String value) {
    if (value.length > 400 || value.contains(RegExp(r'[\x00-\x1f]'))) {
      throw const FormatException('Metadados YouTube inválidos.');
    }
    return value.trim();
  }

  static String _text(Object? value) {
    if (value is String) return value;
    if (value is List) {
      return value.map(_text).where((s) => s.isNotEmpty).join('');
    }
    if (value is Map) {
      for (final key in [
        'simpleText',
        'content',
        'runs',
        'text',
        'musicResponsiveListItemFixedColumnRenderer',
        'metadataParts'
      ]) {
        if (value[key] != null) return _text(value[key]);
      }
    }
    return '';
  }

  static Map? _find(Object? value, String key) {
    if (value is Map) {
      if (value[key] is Map) return value[key] as Map;
      for (final child in value.values) {
        final found = _find(child, key);
        if (found != null) return found;
      }
    } else if (value is List) {
      for (final child in value) {
        final found = _find(child, key);
        if (found != null) return found;
      }
    }
    return null;
  }

  static String _token(Map entry) {
    final command = _find(entry, 'continuationCommand');
    return _text(
        command?['token'] ?? _find(command, 'continuationCommand')?['token']);
  }

  static List? _videoSection(Object? value) {
    if (value is Map) {
      final section = value['itemSectionRenderer'];
      if (section is Map && section['contents'] is List) {
        final items = section['contents'] as List;
        if (items.any((e) =>
            e is Map &&
            (e.containsKey('lockupViewModel') ||
                e.containsKey('playlistVideoRenderer')))) {
          return items;
        }
      }
      for (final child in value.values) {
        final found = _videoSection(child);
        if (found != null) return found;
      }
    } else if (value is List) {
      for (final child in value) {
        final found = _videoSection(child);
        if (found != null) return found;
      }
    }
    return null;
  }
}

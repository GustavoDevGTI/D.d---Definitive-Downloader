import '../library/domain/models.dart';

enum MusicLinkKind { spotify, deezer, youtubeMusic, mp3 }

class MusicLink {
  const MusicLink(this.kind, this.url, this.id);
  final MusicLinkKind kind;
  final String url, id;

  static MusicLink parse(String input) {
    final value = input.trim();
    if (value.length > 4096) throw const FormatException('Link muito longo.');
    if (RegExp(r'^spotify:track:[A-Za-z0-9]{22}$').hasMatch(value)) {
      return MusicLink(
          MusicLinkKind.spotify,
          'https://open.spotify.com/track/${value.split(':').last}',
          value.split(':').last);
    }
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        (uri.scheme == 'https' ? uri.port != 443 : uri.port != 80)) {
      throw const FormatException(
          'Use um link HTTP/HTTPS público, sem credenciais.');
    }
    if (uri.host == 'open.spotify.com' && uri.scheme == 'https') {
      final match = RegExp(r'^/(?:intl-[a-z-]+/)?track/([A-Za-z0-9]{22})/?$')
          .firstMatch(uri.path);
      if (match == null) {
        throw const FormatException('Use um link de faixa do Spotify.');
      }
      return MusicLink(MusicLinkKind.spotify,
          'https://open.spotify.com/track/${match[1]}', match[1]!);
    }
    if (['www.deezer.com', 'deezer.com'].contains(uri.host) &&
        uri.scheme == 'https') {
      final match =
          RegExp(r'^/(?:[a-z]{2}(?:-[a-z]{2})?/)?track/([1-9][0-9]{0,18})/?$')
              .firstMatch(uri.path);
      if (match == null) {
        throw const FormatException('Use um link completo de faixa da Deezer.');
      }
      return MusicLink(MusicLinkKind.deezer,
          'https://www.deezer.com/track/${match[1]}', match[1]!);
    }
    if (uri.host == 'music.youtube.com' &&
        uri.scheme == 'https' &&
        uri.path == '/watch') {
      final id = uri.queryParameters['v'] ?? '';
      if (!RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id)) {
        throw const FormatException('Faixa YouTube Music inválida.');
      }
      return MusicLink(MusicLinkKind.youtubeMusic,
          'https://music.youtube.com/watch?v=$id', id);
    }
    if (uri.path.toLowerCase().endsWith('.mp3') &&
        !uri.hasQuery &&
        !['youtube.com', 'www.youtube.com', 'youtu.be', 'music.youtube.com']
            .contains(uri.host)) {
      return MusicLink(MusicLinkKind.mp3, uri.toString(), '');
    }
    throw const FormatException(
        'Use uma faixa do Spotify, Deezer, YouTube Music ou MP3 direto sem parâmetros.');
  }

  static List<MusicLink> batch(String input) {
    if (input.length > 32768) {
      throw const FormatException('O lote excede o limite de leitura.');
    }
    final lines = input
        .split(RegExp(r'[\r\n]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (lines.isEmpty || lines.length > 20) {
      throw const FormatException('Adicione de 1 a 20 links por vez.');
    }
    final result = <MusicLink>[];
    for (var i = 0; i < lines.length; i++) {
      try {
        result.add(parse(lines[i]));
      } on FormatException catch (error) {
        throw FormatException('Link ${i + 1}: ${error.message}');
      }
    }
    // Each line is an occurrence, including intentional repetitions.
    return result;
  }
}

class ResolvedMusicLink {
  const ResolvedMusicLink(
      {required this.link,
      required this.draft,
      this.source,
      this.alternatives = const [],
      this.pinned = false,
      this.ready = false});
  final MusicLink link;
  final TrackDraft draft;
  final Candidate? source;
  final List<Candidate> alternatives;
  final bool pinned, ready;

  ResolvedMusicLink prepared(
          {Candidate? source,
          List<Candidate> alternatives = const [],
          required bool ready}) =>
      ResolvedMusicLink(
          link: link,
          draft: draft,
          source: source ?? this.source,
          alternatives: alternatives,
          pinned: pinned,
          ready: ready);

  Track get matchingTrack => Track(
      id: 0,
      collectionId: 0,
      position: 0,
      title: draft.title,
      artist: draft.artist,
      album: draft.album,
      durationMs: draft.durationMs,
      isrc: draft.isrc,
      coverUrl: draft.coverUrl,
      sourceUrl: draft.sourceUrl,
      mediaUrl: '',
      sourceKind: SourceKind.none,
      status: TrackStatus.pending,
      selected: false,
      localPath: '',
      error: '',
      resolvedTitle: '',
      resolvedArtist: '',
      explicit: draft.explicit);
}

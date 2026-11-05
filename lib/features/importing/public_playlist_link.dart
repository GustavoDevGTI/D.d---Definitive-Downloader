enum PublicPlaylistKind { deezer, youtube, youtubeMusic }

class PublicPlaylistLink {
  const PublicPlaylistLink(this.kind, this.id, this.url);
  final PublicPlaylistKind kind;
  final String id, url;

  static PublicPlaylistLink? recognize(String input) {
    final uri = Uri.tryParse(input.trim());
    if (uri == null ||
        !const {
          'deezer.com',
          'www.deezer.com',
          'youtube.com',
          'www.youtube.com',
          'm.youtube.com',
          'music.youtube.com'
        }.contains(uri.host.toLowerCase())) {
      return null;
    }
    if (input.length > 4096 ||
        uri.scheme != 'https' ||
        uri.port != 443 ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment) {
      throw const FormatException('Use um link HTTPS público de playlist.');
    }
    final host = uri.host.toLowerCase();
    if (host.endsWith('deezer.com')) {
      final match = RegExp(
              r'^/(?:[a-z]{2}(?:-[a-z]{2})?/)?playlist/([1-9][0-9]{0,18})/?$')
          .firstMatch(uri.path);
      if (match == null) {
        throw const FormatException('Cole o link completo da playlist Deezer.');
      }
      final id = match[1]!;
      return PublicPlaylistLink(
          PublicPlaylistKind.deezer, id, 'https://www.deezer.com/playlist/$id');
    }
    final ids = uri.queryParametersAll['list'];
    if (!['/playlist', '/watch'].contains(uri.path) ||
        ids?.length != 1 ||
        !RegExp(r'^(PL|OLAK5uy_|UU)[A-Za-z0-9_-]{10,110}$')
            .hasMatch(ids!.single)) {
      throw const FormatException(
          'Use uma playlist pública do YouTube. Mixes automáticos e listas privadas não são aceitos.');
    }
    final music = host == 'music.youtube.com';
    return PublicPlaylistLink(
        music ? PublicPlaylistKind.youtubeMusic : PublicPlaylistKind.youtube,
        ids.single,
        Uri.https(music ? 'music.youtube.com' : 'www.youtube.com', '/playlist',
            {'list': ids.single}).toString());
  }
}

enum SoundCloudResource { track, playlist, shortLink }

class SoundCloudLink {
  const SoundCloudLink(this.url, this.resource);
  final String url;
  final SoundCloudResource resource;

  static bool recognizes(String input) => const {
        'soundcloud.com',
        'www.soundcloud.com',
        'm.soundcloud.com',
        'on.soundcloud.com'
      }.contains(Uri.tryParse(input.trim())?.host.toLowerCase());

  static SoundCloudLink parse(String input) {
    final uri = Uri.tryParse(input.trim());
    if (input.length > 4096 ||
        uri == null ||
        uri.scheme != 'https' ||
        uri.port != 443 ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        !recognizes(input) ||
        uri.queryParameters.keys.any((k) =>
            k.toLowerCase().contains('secret') ||
            k.toLowerCase().contains('token'))) {
      throw const FormatException('Use um link público HTTPS do SoundCloud.');
    }
    final parts = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (parts.any((s) => !RegExp(r'^[A-Za-z0-9_-]{1,200}$').hasMatch(s))) {
      throw const FormatException('Endereço SoundCloud inválido.');
    }
    if (uri.host.toLowerCase() == 'on.soundcloud.com' && parts.length == 1) {
      return SoundCloudLink(
          Uri.https('on.soundcloud.com', '/${parts.single}').toString(),
          SoundCloudResource.shortLink);
    }
    if (parts.length == 3 &&
        parts[1] == 'sets' &&
        !parts.last.startsWith('s-')) {
      return SoundCloudLink(
          Uri.https('soundcloud.com', '/${parts.join('/')}').toString(),
          SoundCloudResource.playlist);
    }
    if (parts.length != 2 ||
        const {
          'discover',
          'charts',
          'search',
          'you',
          'tracks',
          'settings',
          'stream'
        }.contains(parts.first) ||
        const {
          'sets',
          'tracks',
          'albums',
          'reposts',
          'likes',
          'popular-tracks',
          'spotlight'
        }.contains(parts.last)) {
      throw const FormatException(
          'Use o link de uma faixa ou playlist pública do SoundCloud.');
    }
    return SoundCloudLink(
        Uri.https('soundcloud.com', '/${parts.join('/')}').toString(),
        SoundCloudResource.track);
  }
}

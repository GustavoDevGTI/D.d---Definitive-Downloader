import '../library/domain/models.dart';
import 'deezer_playlist_catalog.dart';
import 'youtube_playlist_catalog.dart';
import 'public_playlist_link.dart';
import 'soundcloud_catalog.dart';
import 'soundcloud_link.dart';
import 'spotify_importer.dart';
import 'spotify_account_importer.dart';

/// Reads a collection without creating a second collection in the library.
class PlaylistCatalog {
  const PlaylistCatalog(
      {required this.spotify,
      required this.soundcloud,
      this.accountSpotify,
      this.deezer = const DeezerPlaylistCatalog(),
      this.youtube = const YouTubePlaylistCatalog(),
      this.available = false,
      this.deezerConnected = false});
  final SpotifyImporter spotify;
  final SpotifyAccountImporter? accountSpotify;
  final SoundCloudCatalog soundcloud;
  final DeezerPlaylistCatalog deezer;
  final YouTubePlaylistCatalog youtube;
  final bool available, deezerConnected;

  static bool isCollection(String value) {
    if (value.startsWith('spotify:playlist:')) return true;
    if (SoundCloudLink.recognizes(value)) {
      return SoundCloudLink.parse(value).resource != SoundCloudResource.track;
    }
    final uri = Uri.tryParse(value);
    if (uri == null) return false;
    return uri.pathSegments.contains('playlist') ||
        (const {
              'youtube.com',
              'www.youtube.com',
              'm.youtube.com',
              'music.youtube.com'
            }.contains(uri.host.toLowerCase()) &&
            uri.path == '/watch' &&
            uri.queryParameters.containsKey('list'));
  }

  Future<ImportedCollection> read(String url,
      {bool Function()? cancelled, void Function(int, int)? onProgress}) {
    if (SoundCloudLink.recognizes(url)) {
      return soundcloud.open(url,
          downloadAvailable: available,
          cancelled: cancelled,
          onProgress: onProgress);
    }
    final link = PublicPlaylistLink.recognize(url);
    if (link != null) {
      return link.kind == PublicPlaylistKind.deezer
          ? deezer.open(link,
              downloadAvailable: available && deezerConnected,
              cancelled: cancelled,
              onProgress: onProgress)
          : youtube.open(link,
              downloadAvailable: available,
              cancelled: cancelled,
              onProgress: onProgress);
    }
    return accountSpotify?.isConnected == true
        ? accountSpotify!.open(url)
        : spotify.open(url);
  }
}

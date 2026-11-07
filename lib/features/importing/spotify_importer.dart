import '../../core/network/bounded_http.dart';
import '../connections/domain/music_account.dart';
import '../library/domain/models.dart';

/// Spotify link validation. Playlist content requires the account importer.
class SpotifyImporter {
  const SpotifyImporter(this.http);
  final BoundedHttp http;
  String playlistId(String input) {
    final text = input.trim();
    final uri = Uri.tryParse(text);
    String? id;
    if (text.startsWith('spotify:playlist:')) {
      id = text.split(':').last;
    } else if (uri != null && uri.scheme == 'https' &&
        uri.host == 'open.spotify.com' && uri.port == 443 && uri.userInfo.isEmpty) {
      final segments = uri.pathSegments;
      final index = segments.indexOf('playlist');
      if (index >= 0 && segments.length == index + 2) id = segments[index + 1];
    }
    if (id == null || !RegExp(r'^[A-Za-z0-9]{22}$').hasMatch(id)) {
      throw const FormatException('Cole um link de playlist de open.spotify.com.');
    }
    return id;
  }

  Future<ImportedCollection> open(String input) async {
    playlistId(input);
    throw const MusicAccountRequired(MusicAccount.spotify);
  }
}

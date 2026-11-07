import '../domain/music_account.dart';
import '../../../core/network/bounded_http.dart';
import '../../importing/spotify_importer.dart';
import '../../importing/music_link.dart';

/// Account decisions precede metadata reads and playlist mutations.
class MusicAccountAccess {
  MusicAccountAccess(
      {required this.spotifyConnected, required this.deezerConnected});
  final bool Function() spotifyConnected, deezerConnected;
  Future<bool> Function(MusicAccount)? requestLogin;
  Future<bool>? _pending;
  bool connected(MusicAccount account) =>
      account == MusicAccount.spotify ? spotifyConnected() : deezerConnected();
  Future<bool> connect(MusicAccount account) async {
    if (connected(account)) return true;
    if (_pending != null) {
      await _pending;
      return connected(account);
    }
    final operation = _request(account);
    _pending = operation;
    try {
      return await operation;
    } finally {
      _pending = null;
    }
  }

  Future<bool> _request(MusicAccount account) async {
    final request = requestLogin;
    if (request == null) throw MusicAccountRequired(account);
    return await request(account) && connected(account);
  }

  Future<bool> ensure(String input) async {
    final refs = input.split(RegExp(r'[\r\n]+')).map((s) => s.trim());
    final spotify = refs.any((s) =>
        s.startsWith('spotify:') ||
        Uri.tryParse(s)?.host.toLowerCase() == 'open.spotify.com');
    for (final ref in refs) {
      if (ref.startsWith('spotify:') ||
          Uri.tryParse(ref)?.host.toLowerCase() == 'open.spotify.com') {
        if (ref.startsWith('spotify:playlist:') ||
            Uri.tryParse(ref)?.pathSegments.contains('playlist') == true) {
          const SpotifyImporter(BoundedHttp()).playlistId(ref);
        } else {
          MusicLink.parse(ref);
        }
      }
    }
    final deezer = refs.any((s) => const {'deezer.com', 'www.deezer.com'}
        .contains(Uri.tryParse(s)?.host.toLowerCase()));
    if (spotify && !await connect(MusicAccount.spotify)) return false;
    if ((spotify || deezer) && !await connect(MusicAccount.deezer)) {
      return false;
    }
    return true;
  }
}

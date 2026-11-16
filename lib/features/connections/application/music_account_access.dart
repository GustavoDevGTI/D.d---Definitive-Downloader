import '../domain/music_account.dart';
import '../../../core/network/bounded_http.dart';
import '../../importing/spotify_importer.dart';
import '../../importing/music_link.dart';

/// Coordinates account prompts and deferral between music operations.
class MusicAccountAccess {
  MusicAccountAccess(
      {required this.spotifyConnected, required this.deezerConnected});
  final bool Function() spotifyConnected, deezerConnected;
  Future<MusicAccountDecision> Function(MusicAccount,
      {required bool allowLater})? requestLogin;
  ({MusicAccount account, Future<MusicAccountDecision> decision})? _pending;
  bool _deezerDeferred = false;

  bool get deezerDeferred => _deezerDeferred && !deezerConnected();

  bool connected(MusicAccount account) =>
      account == MusicAccount.spotify ? spotifyConnected() : deezerConnected();

  Future<bool> connect(MusicAccount account) async =>
      await _decide(account, allowLater: false) ==
      MusicAccountDecision.connected;

  Future<MusicAccountDecision> offerDeezerForPlaylist() =>
      _decide(MusicAccount.deezer, allowLater: true, repeatOffer: true);

  Future<MusicAccountDecision> _decide(MusicAccount account,
      {required bool allowLater, bool repeatOffer = false}) async {
    if (connected(account)) return MusicAccountDecision.connected;
    final pending = _pending;
    if (pending != null) {
      final decision = await pending.decision;
      if (pending.account == account) return decision;
      return _decide(account, allowLater: allowLater, repeatOffer: repeatOffer);
    }
    if (allowLater && deezerDeferred && !repeatOffer) {
      return MusicAccountDecision.later;
    }
    final operation = _request(account, allowLater: allowLater);
    _pending = (account: account, decision: operation);
    try {
      return await operation;
    } finally {
      _pending = null;
    }
  }

  Future<MusicAccountDecision> _request(MusicAccount account,
      {required bool allowLater}) async {
    final request = requestLogin;
    if (request == null) throw MusicAccountRequired(account);
    final decision = await request(account, allowLater: allowLater);
    if (decision == MusicAccountDecision.connected && connected(account)) {
      if (account == MusicAccount.deezer) _deezerDeferred = false;
      return decision;
    }
    if (account == MusicAccount.deezer &&
        allowLater &&
        decision == MusicAccountDecision.later) {
      _deezerDeferred = true;
      return decision;
    }
    return MusicAccountDecision.cancelled;
  }

  Future<bool> ensure(String input, {bool allowDeezerLater = true}) async {
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
    if (deezer || (spotify && !allowDeezerLater)) {
      return connect(MusicAccount.deezer);
    }
    if (spotify) {
      return await _decide(MusicAccount.deezer, allowLater: true) !=
          MusicAccountDecision.cancelled;
    }
    return true;
  }
}

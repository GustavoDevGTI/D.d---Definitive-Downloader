import '../connections/application/deezer_connection_controller.dart';
import '../downloads/download_service.dart';
import '../library/domain/models.dart';
import '../library/domain/matching.dart';
import 'music_candidates.dart';
import 'music_engine.dart';

class MusicResolver {
  MusicResolver(this.engine, this.connection);
  final MusicEngine engine;
  final DeezerConnectionController connection;
  bool get available => engine.available;
  bool canUse(Candidate candidate) =>
      candidate.isFullRecording &&
      (candidate.kind == SourceKind.youtubeMusic || connection.connected);

  Future<List<Candidate>> search(Track track, String query,
      {DownloadCancellation? cancellation}) async {
    final candidates = <Candidate>[];
    Object? lastError;
    for (final kind in ['deezerFull', 'youtubeMusic']) {
      cancellation?.check();
      try {
        final response = await engine.call({
          'operation': 'search',
          'provider': kind,
          'query': query,
          'isrc': track.isrc
        }, cancellation: cancellation);
        final rows = response['candidates'];
        if (rows is! List || rows.length > 8) {
          throw const FormatException('Resposta de busca inválida.');
        }
        candidates.addAll(rows
            .map((row) =>
                parseMusicCandidate(Map<String, dynamic>.from(row as Map)))
            .where((c) => c.isFullRecording));
      } on DownloadCancelled {
        rethrow;
      } catch (error) {
        lastError = error;
      }
    }
    if (candidates.isEmpty && lastError != null) throw lastError;
    return candidates;
  }

  Candidate? automaticChoice(Track track, List<Candidate> candidates,
      {SourceKind? only}) {
    const matcher = TrackMatcher();
    for (final provider in [SourceKind.deezerFull, SourceKind.youtubeMusic]) {
      if (only != null && only != provider) continue;
      final eligible = candidates
          .where((c) =>
              c.kind == provider &&
              canUse(c) &&
              !matcher.assess(track, c).needsReview)
          .toList()
        ..sort((a, b) => matcher
            .assess(track, b)
            .score
            .compareTo(matcher.assess(track, a).score));
      if (eligible.isEmpty) continue;
      // An original-album recording is a stronger choice than an equally named
      // compilation/remaster. Multiple entries within that album still need review.
      final sameAlbum = eligible
          .where((c) =>
              track.album.trim().isNotEmpty &&
              c.album.trim().toLowerCase() == track.album.trim().toLowerCase())
          .toList();
      if (sameAlbum.length == 1) return sameAlbum.single;
      // Repeated catalog rows for the same source are harmless. Competing versions are not.
      if (eligible.length > 1 &&
          eligible[0].pageUrl != eligible[1].pageUrl &&
          (matcher.assess(track, eligible[0]).score -
                      matcher.assess(track, eligible[1]).score)
                  .abs() <
              .04) {
        continue;
      }
      return eligible.first;
    }
    return null;
  }
}

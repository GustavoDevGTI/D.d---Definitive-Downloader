import '../connections/application/deezer_connection_controller.dart';
import '../downloads/download_cancellation.dart';
import '../library/domain/models.dart';
import '../library/domain/matching.dart';
import '../library/domain/track_listing.dart';
import 'music_candidates.dart';
import 'music_engine.dart';

class MusicResolver {
  MusicResolver(this.engine, this.connection);
  final MusicEngine engine;
  final DeezerConnectionController connection;
  bool get available => engine.available;
  bool canUse(Candidate candidate) =>
      available &&
      (candidate.isVideoRecording ||
          (candidate.isFullRecording &&
              (candidate.kind == SourceKind.youtubeMusic ||
                  candidate.kind == SourceKind.soundcloud ||
                  connection.connected)));

  Future<List<Candidate>> search(Track track, String query,
      {DownloadCancellation? cancellation}) async {
    final candidates = <Candidate>[];
    Object? lastError;
    for (final kind in ['deezerFull', 'youtubeMusic', 'soundcloud']) {
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
    const matcher = TrackMatcher();
    if (!candidates.any((c) => sameSong(track, c))) {
      final exactQuery = '"${track.title}" "${track.artist}"';
      if (track.title.trim().isNotEmpty &&
          track.artist.trim().isNotEmpty &&
          exactQuery != query) {
        // Exhaust the exact requested song before presenting other titles or
        // recordings. Only providers already implemented by the motor are used.
        for (final kind in ['soundcloud', 'deezerFull', 'youtubeMusic']) {
          cancellation?.check();
          try {
            final response = await engine.call({
              'operation': 'search',
              'provider': kind,
              'query': exactQuery,
              'isrc': track.isrc
            }, cancellation: cancellation);
            final rows = response['candidates'];
            if (rows is! List || rows.length > 8) {
              throw const FormatException('Resposta de busca inválida.');
            }
            for (final row in rows) {
              final c =
                  parseMusicCandidate(Map<String, dynamic>.from(row as Map));
              if (c.isFullRecording &&
                  !candidates.any(
                      (old) => old.kind == c.kind && old.pageUrl == c.pageUrl)) {
                candidates.add(c);
              }
            }
          } on DownloadCancelled {
            rethrow;
          } catch (error) {
            lastError = error;
          }
        }
      }
    }
    final exact = candidates.where((c) => sameSong(track, c)).toList();
    if (exact.isNotEmpty) {
      candidates
        ..clear()
        ..addAll(exact);
    }
    if (!candidates
        .any((c) => canUse(c) && !matcher.assess(track, c).needsReview)) {
      try {
        candidates.addAll(
            await searchVideos(track, query, cancellation: cancellation));
      } on DownloadCancelled {
        rethrow;
      } catch (error) {
        lastError ??= error;
      }
    }
    if (candidates.isEmpty && lastError != null) throw lastError;
    return candidates.take(32).toList();
  }

  static bool sameSong(Track track, Candidate candidate) {
    String fold(String v) => foldTrackText(v)
        .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
        .trim();
    final title = fold(track.title),
        artist = fold(track.artist),
        actualArtist = fold(candidate.artist);
    if (title.isEmpty || artist.isEmpty || actualArtist.isEmpty) return false;
    final sameTitle = fold(candidate.title) == title;
    final artists = actualArtist.split(' ').toSet(),
        requested = artist.split(' ').toSet();
    return sameTitle &&
        (actualArtist == artist || requested.every(artists.contains));
  }

  Future<List<Candidate>> searchVideos(Track track, String query,
      {DownloadCancellation? cancellation}) async {
    cancellation?.check();
    final response = await engine.call({
      'operation': 'search',
      'provider': 'youtube',
      'query': query,
      'isrc': track.isrc
    }, cancellation: cancellation);
    final rows = response['candidates'];
    if (rows is! List || rows.length > 8) {
      throw const FormatException('Resposta de videoclipes inválida.');
    }
    return rows
        .map((r) => parseMusicCandidate(Map<String, dynamic>.from(r as Map)))
        .where((c) => c.isVideoRecording && c.durationMs >= 1000)
        .toList();
  }

  Candidate? automaticChoice(Track track, List<Candidate> candidates,
      {SourceKind? only}) {
    const matcher = TrackMatcher();
    for (final provider in [
      SourceKind.deezerFull,
      SourceKind.youtubeMusic,
      SourceKind.soundcloud
    ]) {
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

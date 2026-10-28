import 'models.dart';

class MatchAssessment {
  const MatchAssessment(this.score, this.needsReview, this.reason);
  final double score;
  final bool needsReview;
  final String reason;
}

class TrackMatcher {
  const TrackMatcher();
  MatchAssessment assess(Track track, Candidate candidate) {
    final full = candidate.kind == SourceKind.youtubeMusic ||
        candidate.kind == SourceKind.deezerFull;
    if (full && !candidate.isFullRecording) {
      return const MatchAssessment(
          0, true, 'Videoclipe ou tipo não confirmado: bloqueado');
    }
    if (full &&
        track.explicit != null &&
        candidate.explicit != track.explicit) {
      return const MatchAssessment(
          0, true, 'Versão explícita/limpa diferente ou não confirmada');
    }
    final artist = _similarity(track.artist, candidate.artist);
    final title = _similarity(track.title, candidate.title);
    final delta = track.durationMs == null
        ? null
        : (track.durationMs! - candidate.durationMs).abs();
    final duration = delta == null ? 0.5 : (1 - delta / 15000).clamp(0.0, 1.0);
    final versionMismatch =
        _versions(track.title) != _versions(candidate.title);
    final isrcMatch = track.isrc.isNotEmpty &&
        candidate.isrc.isNotEmpty &&
        track.isrc.toUpperCase() == candidate.isrc.toUpperCase();
    final score = ((title * .5 + artist * .35 + duration * .15) *
            (versionMismatch ? .55 : 1))
        .clamp(0.0, 1.0);
    final high = !versionMismatch &&
        artist >= .85 &&
        title >= .9 &&
        delta != null &&
        delta <= (full ? 2000 : 3000);
    if (full && (delta == null || delta > 2000)) {
      return MatchAssessment(score, true,
          'Duração diferente ou não confirmada; revise a gravação');
    }
    return MatchAssessment(
        isrcMatch && !versionMismatch ? 1 : score,
        !(high || (isrcMatch && !versionMismatch)),
        versionMismatch
            ? 'Versão diferente da solicitada'
            : artist < .5
                ? 'Artista diferente; confira a gravação'
                : delta != null && delta > 10000
                    ? 'Duração diferente; confira a gravação'
                    : high
                        ? 'Título, artista e duração compatíveis'
                        : 'Confira antes de escolher');
  }

  String _versions(String text) {
    final normalized = _normalize(text);
    return [
      'live',
      'remix',
      'karaoke',
      'instrumental',
      'cover',
      'acustico',
      'sped',
      'slowed',
      'remastered',
      'remaster',
      'edit',
      'radio',
      'reverb'
    ].where((word) => normalized.split(' ').contains(word)).join('|');
  }

  double _similarity(String a, String b) {
    final x = _normalize(a).split(' ').where((v) => v.isNotEmpty).toSet();
    final y = _normalize(b).split(' ').where((v) => v.isNotEmpty).toSet();
    if (x.isEmpty || y.isEmpty) return 0;
    return x.intersection(y).length / x.union(y).length;
  }

  String _normalize(String value) {
    const from = 'áàâãäéèêëíìîïóòôõöúùûüç';
    const to = 'aaaaaeeeeiiiiooooouuuuc';
    var result = value.toLowerCase();
    for (var i = 0; i < from.length; i++) {
      result = result.replaceAll(from[i], to[i]);
    }
    return result
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

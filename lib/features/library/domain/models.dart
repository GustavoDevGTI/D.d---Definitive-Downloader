enum TrackStatus { pending, ready, downloading, completed, failed }

enum SourceKind {
  none,
  localExample,
  directMp3,
  preview,
  deezerFull,
  youtubeMusic
}

extension MusicSourceName on SourceKind {
  String? get musicProviderName => switch (this) {
        SourceKind.deezerFull => 'Deezer',
        SourceKind.youtubeMusic => 'YouTube Music',
        _ => null,
      };
  String get musicProviderSuffix =>
      musicProviderName == null ? '' : ' [$musicProviderName]';
}

class Collection {
  const Collection(
      {required this.id,
      required this.name,
      required this.source,
      required this.sourceUrl,
      required this.trackCount,
      required this.completedCount,
      required this.isPartial});
  final int id;
  final String name;
  final String source;
  final String sourceUrl;
  final int trackCount;
  final int completedCount;
  final bool isPartial;
}

class TrackDraft {
  const TrackDraft(
      {required this.title,
      required this.artist,
      this.album = '',
      this.durationMs,
      this.coverUrl = '',
      this.sourceUrl = '',
      this.isrc = '',
      this.mediaUrl = '',
      this.sourceKind = SourceKind.none,
      this.explicit});
  final bool? explicit;
  final String title;
  final String artist;
  final String album;
  final int? durationMs;
  final String coverUrl;
  final String sourceUrl;
  final String isrc;
  final String mediaUrl;
  final SourceKind sourceKind;
}

class Track {
  const Track(
      {required this.id,
      required this.collectionId,
      required this.position,
      required this.title,
      required this.artist,
      required this.album,
      required this.durationMs,
      required this.isrc,
      required this.coverUrl,
      required this.sourceUrl,
      required this.mediaUrl,
      required this.sourceKind,
      required this.status,
      required this.selected,
      required this.localPath,
      required this.error,
      required this.resolvedTitle,
      required this.resolvedArtist,
      this.resolvedAlbum = '',
      this.resolvedDurationMs,
      this.explicit,
      this.resolvedCoverUrl = ''});
  final bool? explicit;
  final String resolvedCoverUrl;
  final int id;
  final int collectionId;
  final int position;
  final String title;
  final String artist;
  final String album;
  final int? durationMs;
  final String isrc;
  final String coverUrl;
  final String sourceUrl;
  final String mediaUrl;
  final SourceKind sourceKind;
  final TrackStatus status;
  final bool selected;
  final String localPath;
  final String error;
  final String resolvedTitle;
  final String resolvedArtist;
  final String resolvedAlbum;
  final int? resolvedDurationMs;
  bool get canDownload => sourceKind != SourceKind.none && mediaUrl.isNotEmpty;
  String get outputTitle => resolvedTitle.isEmpty ? title : resolvedTitle;
  String get outputArtist => resolvedArtist.isEmpty ? artist : resolvedArtist;
  String get outputAlbum => resolvedAlbum.isEmpty ? album : resolvedAlbum;
  int? get outputDurationMs => sourceKind == SourceKind.preview
      ? resolvedDurationMs
      : resolvedDurationMs ?? durationMs;
  String get sourceLabel => switch (sourceKind) {
        SourceKind.none => 'A conferir',
        SourceKind.localExample => 'Exemplo local',
        SourceKind.directMp3 => 'MP3 vinculado',
        SourceKind.preview => 'Prévia Deezer',
        SourceKind.deezerFull => 'Deezer · faixa',
        SourceKind.youtubeMusic => 'YouTube Music · faixa',
      };
}

class TrackPage {
  const TrackPage(this.items, this.total, this.selectedCount);
  final List<Track> items;
  final int total;
  final int selectedCount;
}

class Candidate {
  const Candidate(
      {required this.title,
      required this.artist,
      required this.album,
      required this.durationMs,
      required this.pageUrl,
      required this.previewUrl,
      required this.coverUrl,
      this.isrc = '',
      this.kind = SourceKind.preview,
      this.recordingType = '',
      this.explicit});
  final SourceKind kind;
  final String recordingType;
  final bool? explicit;
  bool get isFullRecording =>
      !RegExp(r'\b(official video|music video|videoclipe)\b',
              caseSensitive: false)
          .hasMatch(title) &&
      ((kind == SourceKind.deezerFull && recordingType == 'DEEZER_TRACK') ||
          (kind == SourceKind.youtubeMusic &&
              recordingType == 'MUSIC_VIDEO_TYPE_ATV'));
  final String title;
  final String artist;
  final String album;
  final int durationMs;
  final String pageUrl;
  final String previewUrl;
  final String coverUrl;
  final String isrc;
}

class ImportedCollection {
  const ImportedCollection(
      {required this.name,
      required this.source,
      required this.sourceUrl,
      required this.tracks,
      this.isPartial = false});
  final String name;
  final String source;
  final String sourceUrl;
  final Stream<TrackDraft> tracks;
  final bool isPartial;
}

String formatDuration(int? milliseconds) {
  if (milliseconds == null || milliseconds <= 0) return '—';
  final seconds = milliseconds ~/ 1000;
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

import '../library/domain/models.dart';

Map<String, Object?> candidateJson(Candidate candidate) => {
      'title': candidate.title,
      'artist': candidate.artist,
      'album': candidate.album,
      'durationMs': candidate.durationMs,
      'pageUrl': candidate.pageUrl,
      'coverUrl': candidate.coverUrl,
      'isrc': candidate.isrc,
      'kind': candidate.kind.name,
      'recordingType': candidate.recordingType,
      'explicit': candidate.explicit,
    };

Candidate parseMusicCandidate(Map<String, dynamic> row) {
  String text(String key) {
    final value = row[key];
    if (value == null) return '';
    if (value is! String ||
        value.length > 2048 ||
        value.contains('\n') ||
        value.contains('\r')) {
      throw const FormatException('Metadados musicais inválidos.');
    }
    return value;
  }

  final kind = switch (row['kind']) {
    'deezerFull' => SourceKind.deezerFull,
    'youtubeMusic' => SourceKind.youtubeMusic,
    _ => throw const FormatException('Fonte de gravação inválida.'),
  };
  final page = Uri.parse(text('pageUrl'));
  if (page.scheme != 'https' ||
      page.userInfo.isNotEmpty ||
      page.port != 443 ||
      (kind == SourceKind.youtubeMusic
          ? page.host != 'music.youtube.com'
          : page.host != 'www.deezer.com')) {
    throw const FormatException('Endereço de faixa não permitido.');
  }
  final duration = row['durationMs'];
  if (duration is! int || duration < 0 || duration > 3600000) {
    throw const FormatException('Duração inválida.');
  }
  return Candidate(
      title: text('title'),
      artist: text('artist'),
      album: text('album'),
      durationMs: duration,
      pageUrl: page.toString(),
      previewUrl: '',
      coverUrl: text('coverUrl'),
      isrc: text('isrc'),
      kind: kind,
      recordingType: text('recordingType'),
      explicit: row['explicit'] is bool ? row['explicit'] as bool : null);
}

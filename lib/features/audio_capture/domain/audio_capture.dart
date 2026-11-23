import '../../library/domain/models.dart';

Uri captureUrl(String input) {
  final value = input.trim();
  final uri = Uri.tryParse(value);
  if (value.length > 2048 ||
      RegExp(r'[\x00-\x20]').hasMatch(value) ||
      uri == null ||
      !['http', 'https'].contains(uri.scheme) ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    throw const FormatException(
        'Use um endereço HTTP ou HTTPS sem credenciais.');
  }
  return uri;
}

Candidate capturedAudio(Map<String, dynamic> row) {
  String text(String key, int maximum) {
    final value = row[key] ?? '';
    if (value is! String ||
        value.length > maximum ||
        RegExp(r'[\x00-\x1f]').hasMatch(value)) {
      throw const FormatException('Metadados de captura inválidos.');
    }
    return value;
  }

  final id = text('sourceId', 64);
  final title = text('title', 400);
  final duration = row['durationMs'];
  if (row['kind'] != 'webAudio' ||
      row['recordingType'] != 'WEB_AUDIO' ||
      !RegExp(r'^[a-f0-9]{64}$').hasMatch(id) ||
      title.trim().isEmpty ||
      duration is! int ||
      duration < 0 ||
      duration > const Duration(hours: 24).inMilliseconds) {
    throw const FormatException('A fonte não identificou um áudio válido.');
  }
  return Candidate(
      sourceId: id,
      kind: SourceKind.webAudio,
      recordingType: 'WEB_AUDIO',
      title: title,
      artist: text('artist', 400),
      album: text('album', 400),
      durationMs: duration,
      pageUrl: captureUrl(text('pageUrl', 2048)).toString(),
      previewUrl: '',
      coverUrl: '');
}

class AudioCaptureResult {
  const AudioCaptureResult(
      {required this.title,
      required this.url,
      required this.items,
      required this.truncated,
      this.unavailableCount = 0});
  final String title, url;
  final List<Candidate> items;
  final bool truncated;
  final int unavailableCount;

  ImportedCollection selection(Set<String> ids) {
    final chosen = items.where((item) => ids.contains(item.sourceId)).toList();
    if (chosen.isEmpty) {
      throw const FormatException('Selecione pelo menos um áudio.');
    }
    return ImportedCollection(
        name: title,
        source: 'Captura de áudio',
        sourceUrl: url,
        tracks: Stream.fromIterable(chosen.map((item) => TrackDraft(
            title: item.title,
            artist: item.artist,
            album: item.album,
            durationMs: item.durationMs == 0 ? null : item.durationMs,
            sourceUrl: item.pageUrl,
            mediaUrl: item.pageUrl,
            manualUrl: item.pageUrl,
            sourceKind: SourceKind.webAudio,
            sourceId: item.sourceId,
            recordingType: 'WEB_AUDIO'))));
  }
}

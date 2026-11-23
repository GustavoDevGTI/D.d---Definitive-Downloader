import '../../downloads/download_cancellation.dart';
import '../../matching/music_engine.dart';
import '../domain/audio_capture.dart';

class AudioCaptureService {
  const AudioCaptureService(this.engine);
  final MusicEngine engine;

  Future<AudioCaptureResult> analyze(String input,
      {required DownloadCancellation cancellation,
      void Function(String)? onStage}) async {
    final url = captureUrl(input).toString();
    final response = await engine.call(
        {'operation': 'captureAnalyze', 'url': url},
        cancellation: cancellation, onStage: onStage);
    cancellation.check();
    final rows = response['items'];
    final title = response['title'];
    if (rows is! List ||
        rows.isEmpty ||
        rows.length > 50 ||
        title is! String ||
        title.trim().isEmpty ||
        title.length > 160 ||
        captureUrl(response['pageUrl'] as String).toString() != url) {
      throw const FormatException(
          'A página não retornou uma lista de áudios válida.');
    }
    final items = rows
        .map((row) => capturedAudio(Map<String, dynamic>.from(row as Map)))
        .toList();
    if (items.map((item) => item.sourceId).toSet().length != items.length) {
      throw const FormatException(
          'A página retornou identificadores repetidos.');
    }
    return AudioCaptureResult(
        title: title,
        url: url,
        items: List.unmodifiable(items),
        truncated: response['truncated'] == true,
        unavailableCount: response['unavailableCount'] is int
            ? (response['unavailableCount'] as int).clamp(0, 51)
            : 0);
  }
}

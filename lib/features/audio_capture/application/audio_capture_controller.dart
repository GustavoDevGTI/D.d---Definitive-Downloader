import 'package:flutter/foundation.dart';
import '../../../core/application/operation_message.dart';
import '../../downloads/download_cancellation.dart';
import '../../library/application/library_controller.dart';
import '../data/audio_capture_service.dart';
import '../domain/audio_capture.dart';

class AudioCaptureController extends ChangeNotifier {
  AudioCaptureController(this.library, {AudioCaptureService? service})
      : service = service ??
            (library.music == null
                ? null
                : AudioCaptureService(library.music!.engine));
  final LibraryController library;
  final AudioCaptureService? service;
  AudioCaptureResult? result;
  final Set<String> selected = {};
  String message = '', stage = '';
  bool analyzing = false, submitting = false;
  bool _disposed = false;
  DownloadCancellation? _cancellation;
  bool get busy => analyzing || submitting;
  bool get available => service?.engine.available == true;

  void select(String id, bool value) {
    if (busy) return;
    value ? selected.add(id) : selected.remove(id);
    notifyListeners();
  }

  void selectAll(bool value) {
    if (busy) return;
    selected.clear();
    if (value) selected.addAll(result!.items.map((item) => item.sourceId));
    notifyListeners();
  }

  void clearResult() {
    if (busy || result == null) return;
    result = null;
    selected.clear();
    message = '';
    notifyListeners();
  }

  Future<void> analyze(String url) async {
    if (busy) return;
    if (!available) {
      message = 'O motor de áudio não está disponível neste dispositivo.';
      notifyListeners();
      return;
    }
    analyzing = true;
    result = null;
    selected.clear();
    message = '';
    stage = 'Analisando página…';
    final token = _cancellation = DownloadCancellation();
    notifyListeners();
    try {
      final found =
          await service!.analyze(url, cancellation: token, onStage: (value) {
        if (_disposed || token.cancelled) return;
        stage = value;
        notifyListeners();
      });
      token.check();
      if (_disposed) return;
      result = found;
      selected.addAll(found.items.map((item) => item.sourceId));
    } on DownloadCancelled {
      message = 'Análise cancelada.';
    } catch (error) {
      message = operationMessage(error);
    } finally {
      analyzing = false;
      stage = '';
      _cancellation = null;
      if (!_disposed) notifyListeners();
    }
  }

  void cancel() => _cancellation?.cancelled = true;

  Future<bool> download() async {
    if (busy || library.busy || result == null || selected.isEmpty) {
      return false;
    }
    submitting = true;
    message = '';
    notifyListeners();
    try {
      final saved =
          await library.importAudioCapture(result!.selection(selected));
      if (saved == null) {
        message = library.message;
        return false;
      }
      final tracks = await library.repository.page(saved.id, limit: 100);
      final started = await library.startDownloads(
          queueIds: tracks.items.map((track) => track.id).toList());
      selected.clear();
      message = started ? '' : library.message;
      return true;
    } catch (error) {
      message = operationMessage(error);
      return false;
    } finally {
      submitting = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    cancel();
    super.dispose();
  }
}

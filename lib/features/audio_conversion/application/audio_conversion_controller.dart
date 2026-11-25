import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../../../core/application/operation_message.dart';
import '../../../core/platform/desktop_files.dart';
import '../../downloads/download_cancellation.dart';
import '../../downloads/download_file_name.dart';
import '../../importing/local_audio_formats.dart';
import '../../library/domain/models.dart';
import 'local_audio_converter.dart';

class AudioConversionController extends ChangeNotifier {
  AudioConversionController(this.files,
      {this.converter = const LocalAudioConverter()});
  final DesktopFiles files;
  final LocalAudioConverter converter;
  int bitrate = 320;
  bool busy = false, cancelling = false, _disposed = false;
  String error = '', savedPath = '';
  DownloadCancellation? _token;

  static bool canOffer(Track track) =>
      defaultTargetPlatform == TargetPlatform.windows &&
      track.status == TrackStatus.completed &&
      track.localPath.isNotEmpty &&
      p.extension(track.localPath).toLowerCase() != '.mp3' &&
      localAudioExtensions.contains(p.extension(track.localPath).toLowerCase());

  Future<void> convert(Track track) async {
    if (busy || savedPath.isNotEmpty) return;
    final token = _token = DownloadCancellation();
    busy = true;
    error = '';
    notifyListeners();
    try {
      final destination = await files
          .chooseMp3Destination('${safeSegment(track.displayTitle)}.mp3');
      token.check();
      if (destination == null) return;
      savedPath = await converter.convert(track.localPath, destination,
          cancellation: token, bitrate: bitrate);
    } on DownloadCancelled {
      error = 'Conversão cancelada. O original foi preservado.';
    } catch (failure) {
      error = operationMessage(failure);
    } finally {
      busy = false;
      cancelling = false;
      _token = null;
      if (!_disposed) notifyListeners();
    }
  }

  void cancel() {
    cancelling = true;
    _token?.cancelled = true;
    notifyListeners();
  }

  Future<void> revealSaved() async {
    try {
      await files.revealFile(savedPath);
    } catch (failure) {
      error = operationMessage(failure);
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _token?.cancelled = true;
    super.dispose();
  }
}

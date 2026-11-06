import 'dart:io';
import '../../features/downloads/download_cancellation.dart';
import '../../features/downloads/transfer_progress.dart';
import '../../features/matching/music_engine.dart';
import 'android_files.dart';
import 'desktop_files.dart';

DesktopFiles createPlatformFiles() =>
    Platform.isAndroid ? AndroidFiles() : DesktopFiles();

Future<MusicEngine> createMusicEngine() async => Platform.isWindows
    ? await WindowsMusicEngine.installed()
    : const UnavailableMusicEngine();

/// A visible capability boundary, rather than attempting to execute a Windows
/// binary or silently accepting unsupported transfers on another platform.
class UnavailableMusicEngine implements MusicEngine {
  const UnavailableMusicEngine();
  @override
  bool get available => false;
  @override
  Future<Map<String, dynamic>> call(Map<String, dynamic> request,
      {DownloadCancellation? cancellation,
      void Function(String)? onStage,
      void Function(TransferProgress)? onProgress}) async {
    cancellation?.check();
    throw const FormatException(
        'O motor de fontes musicais ainda não está disponível nesta plataforma.');
  }
}

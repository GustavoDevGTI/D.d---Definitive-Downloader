import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../../downloads/download_cancellation.dart';
import '../../importing/local_mp3_inspector.dart';

/// Converts a local file into a separate MP3. Never replaces library records,
/// source audio or an existing destination. FFmpeg is the app's bundled binary.
class LocalAudioConverter {
  const LocalAudioConverter(
      {this.ffmpeg, this.inspector = const MediaKitLocalAudioInspector()});
  final String? ffmpeg;
  final LocalAudioInspector inspector;
  bool get supported => Platform.isWindows;
  static const bitrates = [128, 192, 256, 320];

  Future<String> convert(String source, String destination,
      {required DownloadCancellation cancellation, int bitrate = 320}) async {
    cancellation.check();
    if (!supported ||
        !bitrates.contains(bitrate) ||
        !p.isAbsolute(source) ||
        !p.isAbsolute(destination) ||
        p.extension(destination).toLowerCase() != '.mp3') {
      throw const FormatException(
          'Escolha um áudio local e um destino MP3 válido no Windows.');
    }
    final input = File(await File(source).resolveSymbolicLinks());
    final extension = p.extension(input.path).toLowerCase();
    final demuxer = localAudioDemuxers[extension];
    final before = await input.stat();
    if (demuxer == null ||
        before.type != FileSystemEntityType.file ||
        before.size < 64 ||
        before.size > maximumLocalAudioBytes) {
      throw const FormatException(
          'Áudio incompatível ou acima do limite de 2 GB.');
    }
    if (await FileSystemEntity.type(destination, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw const FormatException(
          'O destino já existe. Escolha outro nome para preservar o arquivo.');
    }
    final executable = ffmpeg ??
        p.join(p.dirname(Platform.resolvedExecutable), 'music_engine',
            '_internal', 'ffmpeg.exe');
    if (!await File(executable).exists()) {
      throw const FormatException(
          'Conversor indisponível. Reinstale o pacote completo do aplicativo.');
    }
    final original = await inspector.inspect(input.path);
    cancellation.check();
    final parent = await File(destination).parent.create(recursive: true);
    final parentPath = await parent.resolveSymbolicLinks();
    final output = File(p.join(parentPath, p.basename(destination)));
    if (p.equals(input.path, output.path)) {
      throw const FormatException(
          'O destino deve ser diferente do arquivo original.');
    }
    final work = await Directory(parentPath).createTemp('.dd-mp3-');
    final staged = File(p.join(work.path, 'converted.mp3'));
    Process? process;
    Timer? timer;
    var timedOut = false, reserved = false, published = false;
    final clock = Stopwatch()..start();
    try {
      process = await Process.start(
          executable,
          [
            '-nostdin',
            '-hide_banner',
            '-loglevel',
            'error',
            '-n',
            '-xerror',
            '-protocol_whitelist',
            'file,pipe',
            '-f',
            demuxer,
            '-i',
            input.path,
            '-map',
            '0:a:0',
            '-vn',
            '-sn',
            '-dn',
            '-map_metadata',
            '0',
            '-c:a',
            'libmp3lame',
            '-b:a',
            '${bitrate}k',
            '-ac',
            '2',
            '-ar',
            '48000',
            '-threads',
            '2',
            '-id3v2_version',
            '3',
            '-fs',
            '$maximumLocalAudioBytes',
            staged.path,
          ],
          runInShell: false);
      final running = process;
      final stdout = running.stdout.drain<void>();
      final stderr = running.stderr.drain<void>();
      timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (clock.elapsed > const Duration(hours: 2)) timedOut = true;
        if (cancellation.cancelled || timedOut) running.kill();
      });
      final exit = await running.exitCode;
      await Future.wait([stdout, stderr]);
      cancellation.check();
      if (timedOut) {
        throw const FormatException('A conversão excedeu o tempo limite.');
      }
      if (exit != 0) {
        throw const FormatException(
            'Não foi possível converter este áudio para MP3.');
      }
      final after = await input.stat();
      if (before.size != after.size || before.modified != after.modified) {
        throw const FormatException(
            'O original mudou durante a conversão. Tente novamente.');
      }
      final converted = await inspector.inspect(staged.path);
      final tolerance = (original.durationMs * .01).round().clamp(1000, 10000);
      if ((converted.durationMs - original.durationMs).abs() > tolerance) {
        throw const FormatException(
            'A duração do MP3 não corresponde ao áudio original.');
      }
      cancellation.check();
      // Reserve only at publication time, and never overwrite another file.
      await output.create(exclusive: true);
      reserved = true;
      await staged.rename(output.path);
      published = true;
      return output.path;
    } finally {
      timer?.cancel();
      process?.kill();
      if (reserved && !published) {
        try {
          if (await output.length() == 0) await output.delete();
        } on FileSystemException {/* Keep original error. */}
      }
      try {
        if (p.isWithin(parentPath, work.path) &&
            await work.resolveSymbolicLinks() == work.path) {
          await work.delete(recursive: true);
        }
      } on FileSystemException {/* A published MP3 remains usable. */}
    }
  }
}

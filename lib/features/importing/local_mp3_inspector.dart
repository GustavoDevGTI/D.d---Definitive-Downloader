import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:path/path.dart' as p;
import '../player/data/audio_tags.dart';
import '../player/domain/playback.dart';
import '../player/data/android_audio_engine.dart';

class LocalAudioMetadata {
  const LocalAudioMetadata(
      {required this.durationMs,
      this.title = '',
      this.artist = '',
      this.album = ''});
  final int durationMs;
  final String title, artist, album;
}

abstract interface class LocalAudioInspector {
  Future<LocalAudioMetadata> inspect(String path);
}

const localAudioExtensions = {
  '.mp3',
  '.wav',
  '.flac',
  '.m4a',
  '.aac',
  '.ogg',
  '.opus'
};

/// A silent decoder probe, with structural validation for MP3.
class MediaKitLocalAudioInspector implements LocalAudioInspector {
  const MediaKitLocalAudioInspector();

  static const _androidMimeTypes = {
    '.mp3': {'audio/mpeg', 'audio/mp3'},
    '.wav': {'audio/x-wav', 'audio/wav', 'audio/wave'},
    '.flac': {'audio/flac', 'audio/x-flac'},
    '.m4a': {'audio/mp4', 'audio/x-m4a'},
    '.aac': {'audio/aac', 'audio/aac-adts', 'audio/aacp'},
    '.ogg': {'application/ogg', 'audio/ogg'},
    '.opus': {'application/ogg', 'audio/ogg', 'audio/opus'},
  };

  @override
  Future<LocalAudioMetadata> inspect(String path) async {
    final extension = p.extension(path).toLowerCase();
    if (!localAudioExtensions.contains(extension)) {
      throw const FormatException('Formato de áudio indisponível.');
    }
    if (extension == '.mp3') {
      await validateMp3Frames(path, maximumBytes: 500 * 1024 * 1024);
    }
    final tags = await _tags(path);
    if (Platform.isAndroid) {
      final metadata = await AndroidAudioEngine.channel
          .invokeMapMethod<String, dynamic>('inspect', {'path': path});
      final duration = metadata?['durationMs'] as int? ?? 0;
      if (duration < 1 ||
          duration > const Duration(hours: 24).inMilliseconds ||
          metadata?['hasVideo'] == true ||
          !_androidMimeTypes[extension]!.contains(metadata?['mime'])) {
        throw FormatException(
          'O arquivo não contém áudio $extension utilizável.',
        );
      }
      return LocalAudioMetadata(
        durationMs: duration,
        title: tags.title.isEmpty
            ? (metadata?['title'] as String? ?? '')
            : tags.title,
        artist: tags.artist.isEmpty
            ? (metadata?['artist'] as String? ?? '')
            : tags.artist,
        album: tags.album.isEmpty
            ? (metadata?['album'] as String? ?? '')
            : tags.album,
      );
    }
    mk.MediaKit.ensureInitialized();
    final player = mk.Player(
        configuration: const mk.PlayerConfiguration(
            title: 'D.d · Importação local',
            bufferSize: 1024 * 1024,
            protocolWhitelist: ['file']));
    final duration = Completer<Duration>();
    final subscriptions = <StreamSubscription<dynamic>>[
      player.stream.duration.listen((v) {
        if (v > Duration.zero && !duration.isCompleted) duration.complete(v);
      }),
    ];
    try {
      await player.setVolume(0);
      await player
          .open(mk.Media(Uri.file(path).toString()), play: false)
          .timeout(const Duration(seconds: 20));
      final value = player.state.duration > Duration.zero
          ? player.state.duration
          : await duration.future.timeout(const Duration(seconds: 12));
      final tracks = player.state.tracks;
      final audio = tracks.audio.any((t) => switch (extension) {
            '.mp3' => t.codec == 'mp3' || t.codec == 'mp3float',
            '.wav' => t.codec?.startsWith('pcm_') == true ||
                t.codec?.startsWith('adpcm_') == true,
            '.flac' => t.codec == 'flac',
            '.m4a' => t.codec == 'aac' || t.codec == 'alac',
            '.aac' => t.codec == 'aac',
            '.ogg' => const {'vorbis', 'opus', 'flac'}.contains(t.codec),
            '.opus' => t.codec == 'opus',
            _ => false,
          });
      final video = tracks.video
          .any((t) => t.codec != null && t.image != true && t.albumart != true);
      if (value.inMilliseconds < 1 ||
          value > const Duration(hours: 24) ||
          !audio ||
          video) {
        throw FormatException(
            'O arquivo não contém áudio $extension utilizável.');
      }
      return LocalAudioMetadata(
          durationMs: value.inMilliseconds,
          title: tags.title,
          artist: tags.artist,
          album: tags.album);
    } on TimeoutException {
      throw const FormatException(
          'Não foi possível conferir o áudio no tempo limite.');
    } finally {
      for (final sub in subscriptions) {
        await sub.cancel();
      }
      await player.dispose();
    }
  }

  static Future<AudioTags> _tags(String path) =>
      Isolate.run(() => readAudioTags(path));
}

Future<void> validateMp3Frames(String path,
        {int maximumBytes = 200 * 1024 * 1024}) =>
    Isolate.run(() => _validate(path, maximumBytes));
void _validate(String path, int maximumBytes) {
  final file = File(path).openSync();
  try {
    var end = file.lengthSync();
    if (end < 64 || end > maximumBytes) {
      throw FormatException(
          'Use MP3 de até ${maximumBytes ~/ (1024 * 1024)} MB.');
    }
    var offset = 0;
    final first = file.readSync(10);
    if (first[0] == 73 && first[1] == 68 && first[2] == 51) {
      if (![2, 3, 4].contains(first[3]) ||
          first.sublist(6).any((b) => b > 127)) {
        throw const FormatException('Cabeçalho ID3 inválido.');
      }
      final size = first.sublist(6).fold(0, (a, b) => (a << 7) | b);
      if (size > 4 * 1024 * 1024) {
        throw const FormatException('Metadados MP3 acima do limite de 4 MB.');
      }
      offset = 10 + size + (first[3] == 4 && first[5] & 16 != 0 ? 10 : 0);
    }
    file.setPositionSync(end - 128 < 0 ? 0 : end - 128);
    final tail = file.readSync(3);
    if (tail.length == 3 && tail[0] == 84 && tail[1] == 65 && tail[2] == 71) {
      end -= 128;
    }
    var frames = 0;
    while (offset + 4 <= end) {
      file.setPositionSync(offset);
      final b = file.readSync(4);
      final version = (b[1] >> 3) & 3, rate = (b[2] >> 2) & 3, bit = b[2] >> 4;
      if (b[0] != 255 ||
          b[1] & 224 != 224 ||
          version == 1 ||
          (b[1] >> 1) & 3 != 1 ||
          rate == 3 ||
          bit == 0 ||
          bit == 15) {
        throw const FormatException(
            'O MP3 contém quadros inválidos ou dados incompletos.');
      }
      final bitrate = (version == 3
          ? const [
              0,
              32,
              40,
              48,
              56,
              64,
              80,
              96,
              112,
              128,
              160,
              192,
              224,
              256,
              320
            ]
          : const [
              0,
              8,
              16,
              24,
              32,
              40,
              48,
              56,
              64,
              80,
              96,
              112,
              128,
              144,
              160
            ])[bit];
      final sample = const [44100, 48000, 32000][rate] ~/
          (version == 3
              ? 1
              : version == 2
                  ? 2
                  : 4);
      final length = (version == 3 ? 144000 : 72000) * bitrate ~/ sample +
          ((b[2] >> 1) & 1);
      if (offset + length > end) {
        throw const FormatException('O último quadro do MP3 está incompleto.');
      }
      offset += length;
      frames++;
    }
    if (frames < 2 || offset != end) {
      throw const FormatException('Arquivo MP3 incompleto.');
    }
  } finally {
    file.closeSync();
  }
}

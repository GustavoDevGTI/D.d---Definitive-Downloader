import 'dart:async';
import 'package:media_kit/media_kit.dart' as mk;
import '../domain/playback.dart';

class MediaKitEngine implements AudioEngine {
  @override
  bool get available => true;
  MediaKitEngine() {
    mk.MediaKit.ensureInitialized();
    _player = mk.Player(
        configuration: const mk.PlayerConfiguration(
            title: 'Definitive Downloader',
            bufferSize: 4 * 1024 * 1024,
            protocolWhitelist: [
          'file',
          'http',
          'https',
          'tcp',
          'tls',
          'data'
        ]));
    _subscriptions.addAll([
      _player.stream.playing.listen((v) => _emit(AudioEvent(playing: v))),
      _player.stream.position.listen((v) => _emit(AudioEvent(position: v))),
      _player.stream.duration.listen((v) => _emit(AudioEvent(duration: v))),
      _player.stream.buffering.listen((v) => _emit(AudioEvent(buffering: v))),
      _player.stream.completed.listen((v) {
        if (v && !_opening) _emit(const AudioEvent(completed: true));
      }),
      _player.stream.error.listen((_) => _emit(const AudioEvent(failed: true))),
    ]);
  }
  late final mk.Player _player;
  Map<String, Object> get measurements => {
        'positionMs': _player.state.position.inMilliseconds,
        'durationMs': _player.state.duration.inMilliseconds,
        'playing': _player.state.playing,
        'volume': _player.state.volume
      };
  final _events = StreamController<AudioEvent>.broadcast();
  final _subscriptions = <StreamSubscription<dynamic>>[];
  bool _opening = false, _disposed = false;
  void _emit(AudioEvent event) {
    if (!_disposed) _events.add(event);
  }

  @override
  Stream<AudioEvent> get events => _events.stream;
  @override
  Future<void> open(String uri) async {
    _opening = true;
    try {
      await _player.open(mk.Media(uri), play: true);
    } finally {
      _opening = false;
    }
  }

  @override
  Future<void> play() => _player.play();
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> stop() => _player.stop();
  @override
  Future<void> seek(Duration value) => _player.seek(value);
  @override
  Future<void> volume(double value) =>
      _player.setVolume(value.clamp(0, 1) * 100);
  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _player.dispose();
    await _events.close();
  }
}

AudioEngine createAudioEngine() {
  try {
    return MediaKitEngine();
  } catch (_) {
    return UnavailableAudioEngine();
  }
}

class UnavailableAudioEngine implements AudioEngine {
  @override
  bool get available => false;
  @override
  Stream<AudioEvent> get events => const Stream.empty();
  @override
  Future<void> open(String uri) async {
    throw const FormatException('Player indisponível.');
  }

  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> seek(Duration value) async {}
  @override
  Future<void> volume(double value) async {}
  @override
  Future<void> dispose() async {}
}

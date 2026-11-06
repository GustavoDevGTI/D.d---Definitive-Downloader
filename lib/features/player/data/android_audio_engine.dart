import 'dart:async';
import 'package:flutter/services.dart';
import '../domain/playback.dart';

/// Android owns MediaPlayer and its lifecycle. No Dart FFI callback survives an
/// Activity/FlutterEngine teardown, including closing and reopening the app.
class AndroidAudioEngine implements AudioEngine {
  AndroidAudioEngine() {
    channel.setMethodCallHandler((call) async {
      if (_disposed || call.method != 'event') return;
      final value = Map<String, dynamic>.from(call.arguments as Map);
      _state.addAll(value);
      _events.add(AudioEvent(
          playing: value['playing'] as bool?,
          buffering: value['buffering'] as bool?,
          position: value['positionMs'] is int
              ? Duration(milliseconds: value['positionMs'] as int)
              : null,
          duration: value['durationMs'] is int
              ? Duration(milliseconds: value['durationMs'] as int)
              : null,
          completed: value['completed'] == true,
          failed: value['failed'] == true));
    });
  }
  static const channel = MethodChannel('br.com.definitivedownloader/audio');
  final _events = StreamController<AudioEvent>.broadcast();
  final _state = <String, dynamic>{};
  Map<String, dynamic> get measurements => Map.unmodifiable(_state);
  bool _disposed = false;
  @override
  bool get available => !_disposed;
  @override
  Stream<AudioEvent> get events => _events.stream;
  Future<void> _call(String method, [Map<String, Object>? args]) async {
    if (!_disposed) await channel.invokeMethod<void>(method, args);
  }

  @override
  Future<void> open(String uri) => _call('open', {'uri': uri});
  @override
  Future<void> play() => _call('play');
  @override
  Future<void> pause() => _call('pause');
  @override
  Future<void> stop() => _call('stop');
  @override
  Future<void> seek(Duration value) =>
      _call('seek', {'milliseconds': value.inMilliseconds});
  @override
  Future<void> volume(double value) async {
    await _call('volume', {'value': value.clamp(0, 1)});
    _state['volume'] = value.clamp(0, 1) * 100;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    try {
      await channel.invokeMethod<void>('dispose');
    } on PlatformException {
      /* Activity may already have released its player. */
    } on MissingPluginException {/* FlutterEngine has detached. */}
    _disposed = true;
    channel.setMethodCallHandler(null);
    await _events.close();
  }
}

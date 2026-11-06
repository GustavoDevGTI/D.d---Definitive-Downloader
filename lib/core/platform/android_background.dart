import 'dart:async';
import 'package:flutter/services.dart';
import '../../features/library/application/library_controller.dart';
import '../../features/player/application/music_player_controller.dart';

/// Keeps lifecycle/notification commands outside widgets and queue policy.
class AndroidBackground {
  AndroidBackground(this.library, this.player) {
    library.addListener(_changed);
    player.addListener(_changed);
    channel.setMethodCallHandler((call) async {
      if (_disposed || call.method != 'command') return;
      switch (call.arguments) {
        case 'pauseQueue':
          library.togglePause();
        case 'stopQueue':
          library.cancel();
        case 'next':
          await player.next();
        case 'previous':
          await player.previous();
        case 'stopAudio':
          await player.stop();
      }
    });
    _changed();
  }
  static const channel =
      MethodChannel('br.com.definitivedownloader/background');
  final LibraryController library;
  final MusicPlayerController player;
  bool _disposed = false, _sending = false, _again = false;
  Map<String, Object>? _last;
  void _changed() {
    if (_disposed) return;
    _again = true;
    if (!_sending) unawaited(_send());
  }

  Future<void> _send() async {
    _sending = true;
    try {
      while (_again && !_disposed) {
        _again = false;
        final state = <String, Object>{
          'downloading': library.downloading,
          'paused': library.pauseMode,
          'audioEnabled': player.moduleActive,
          'downloadTitle': library.activeTitle,
          'title': player.title,
          'artist': player.artist,
        };
        if (_last != null && state.keys.every((k) => state[k] == _last![k])) {
          continue;
        }
        await channel.invokeMethod<void>('state', state);
        _last = state;
      }
    } on PlatformException {
      library.cancel();
      await player.pause();
      library.message =
          'O Android não permitiu manter o trabalho em segundo plano. Abra o app e tente novamente.';
      library.notifyListeners();
    } finally {
      _sending = false;
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    library.removeListener(_changed);
    player.removeListener(_changed);
    channel.setMethodCallHandler(null);
  }
}

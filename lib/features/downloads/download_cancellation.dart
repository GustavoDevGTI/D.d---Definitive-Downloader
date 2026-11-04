class DownloadCancelled implements Exception {
  const DownloadCancelled();
}

class DownloadCancellation {
  bool cancelled = false;
  bool _pauseMode = false;
  bool get pauseMode => _pauseMode;
  set pauseMode(bool value) {
    if (_pauseMode == value) return;
    _pauseMode = value;
    _pacedBytes = 0;
    _paceClock.reset();
    if (value) _paceClock.start();
  }

  final Stopwatch _paceClock = Stopwatch();
  int _pacedBytes = 0;
  // Pause mode keeps the current connection alive at 10 KiB/s. The queue
  // controller prevents another transfer from starting until it is resumed.
  Future<void> throttle(int bytes) async {
    check();
    if (!pauseMode) return;
    _pacedBytes += bytes;
    final target = _pacedBytes * 1000 ~/ 10240;
    while (pauseMode && _paceClock.elapsedMilliseconds < target) {
      check();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    check();
  }

  Future<void> waitForQueue() async {
    while (pauseMode) {
      check();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    check();
  }

  void check() {
    if (cancelled) throw const DownloadCancelled();
  }
}

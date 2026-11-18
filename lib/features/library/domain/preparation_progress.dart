class PreparationProgress {
  const PreparationProgress({
    required this.total,
    required this.checked,
    required this.measured,
    required this.elapsed,
  });

  final int total, checked, measured;
  final Duration elapsed;

  double get fraction => total == 0 ? 0 : checked / total;

  Duration? get remaining {
    if (checked == total) return Duration.zero;
    if (measured == 0 || elapsed.inMicroseconds <= 0) return null;
    return Duration(
        microseconds:
            (elapsed.inMicroseconds * (total - checked) / measured).ceil());
  }
}

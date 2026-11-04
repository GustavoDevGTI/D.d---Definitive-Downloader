/// Measurements for one receive attempt. Network completion is not publication.
class TransferProgress {
  const TransferProgress(
      {required this.received,
      this.total,
      this.bytesPerSecond,
      this.estimatedTotal = false,
      this.processing = false});
  final int received;
  final int? total;
  final double? bytesPerSecond;
  final bool estimatedTotal, processing;
  double? get fraction => !processing && total != null && total! > 0
      ? (received / total!).clamp(0, 1)
      : null;
  Duration? get remaining => processing ||
          total == null ||
          total! <= received ||
          bytesPerSecond == null ||
          bytesPerSecond! <= 0
      ? null
      : Duration(seconds: ((total! - received) / bytesPerSecond!).ceil());
  TransferProgress asProcessing() => TransferProgress(
      received: received,
      total: total,
      estimatedTotal: estimatedTotal,
      processing: true);

  static TransferProgress fromEvent(Map<String, dynamic> event) {
    int? size(Object? value) =>
        value is int && value >= 0 && value <= 500 * 1024 * 1024 ? value : null;
    final received = size(event['received']);
    if (received == null) {
      throw const FormatException('Medição de transferência inválida.');
    }
    final total = size(event['total']);
    final rate = event['bytesPerSecond'];
    return TransferProgress(
        received: received,
        total: total != null && total >= received && total > 0 ? total : null,
        estimatedTotal: event['estimatedTotal'] == true,
        bytesPerSecond:
            rate is num && rate.isFinite && rate > 0 ? rate.toDouble() : null);
  }
}

/// A monotonic clock keeps rate/ETA independent of system clock changes.
class TransferMeter {
  final _clock = Stopwatch()..start();
  int _lastBytes = 0, _lastMs = 0;
  double? _rate;
  TransferProgress sample(int received, {int? total}) {
    final now = _clock.elapsedMilliseconds;
    if (now > _lastMs && received >= _lastBytes) {
      _rate = (received - _lastBytes) * 1000 / (now - _lastMs);
    }
    _lastBytes = received;
    _lastMs = now;
    return TransferProgress(
        received: received, total: total, bytesPerSecond: _rate);
  }
}

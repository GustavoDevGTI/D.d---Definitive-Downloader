/// A published file keeps its number; the active receiver is temporarily fixed.
bool trackOrderLocked({required String status, String localPath = ''}) =>
    localPath.isNotEmpty || const ['downloading', 'completed'].contains(status);

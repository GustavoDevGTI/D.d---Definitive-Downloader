import 'package:sqlite3/sqlite3.dart';

/// Caller owns the transaction. Slots of other collections stay put.
void reassignRunSlots(
    Database db, List<Map<String, Object?>> slots, List<int> ids) {
  final members = slots.map((s) => s['track_id'] as int).toSet();
  if (slots.length != ids.length ||
      ids.toSet().length != ids.length ||
      !members.containsAll(ids)) {
    throw StateError('Ordem da execução inconsistente.');
  }
  final stage = db.prepare(
      'UPDATE download_run_additions SET ordinal=-ordinal WHERE ordinal=?');
  final write = db.prepare(
      'UPDATE download_run_additions SET ordinal=? WHERE run=? AND track_id=?');
  try {
    for (final slot in slots) {
      stage.execute([slot['ordinal']]);
    }
    for (var i = 0; i < slots.length; i++) {
      write.execute([slots[i]['ordinal'], slots[i]['run'], ids[i]]);
    }
  } finally {
    stage.dispose();
    write.dispose();
  }
}

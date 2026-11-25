import 'package:sqlite3/sqlite3.dart';

/// SQLite can roll back the transaction itself after a storage error. Cleanup
/// must never replace the original exception raised by the failed operation.
void rollbackAfterFailure(Database db) {
  try {
    if (!db.autocommit) db.execute('ROLLBACK');
  } catch (_) {
    // The caller rethrows the original error; disposing closes the connection.
  }
}

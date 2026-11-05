import 'package:sqlite3/sqlite3.dart';

// Reconstruct the actual previous schema, rather than only lowering its number.
void removeOrganizationSchema(Database db) {
  removeContinuousSchema(db);
  db.execute('ALTER TABLE collections DROP COLUMN cover_path');
  db.execute('ALTER TABLE tracks DROP COLUMN redownload_state');
  db.execute('DROP INDEX collections_group_id');
  db.execute('ALTER TABLE collections DROP COLUMN group_id');
  db.execute('ALTER TABLE collections DROP COLUMN storage_name');
  db.execute('DROP TABLE collection_groups');
}

void removeContinuousSchema(Database db) {
  for (final event in ['insert', 'update', 'delete']) {
    db.execute('DROP TRIGGER tracks_list_$event');
    db.execute('DROP TRIGGER IF EXISTS history_list_$event');
  }
  db.execute('DROP TRIGGER collection_list_name');
  db.execute('DROP INDEX tracks_list_revision');
  db.execute('ALTER TABLE tracks DROP COLUMN list_revision');
  db.execute('DROP TABLE library_revision');
}

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
  removePlaylistThemeSchema(db);
  for (final event in ['insert', 'update', 'delete']) {
    db.execute('DROP TRIGGER tracks_list_$event');
    db.execute('DROP TRIGGER IF EXISTS history_list_$event');
  }
  db.execute('DROP TRIGGER collection_list_name');
  if (db
      .select('PRAGMA table_info(tracks)')
      .any((r) => r['name'] == 'source_id')) {
    db.execute('ALTER TABLE tracks DROP COLUMN source_id');
  }
  if (db
      .select('PRAGMA table_info(music_candidates)')
      .any((r) => r['name'] == 'source_id')) {
    db.execute('ALTER TABLE music_candidates DROP COLUMN source_id');
  }
  db.execute('DROP INDEX tracks_list_revision');
  db.execute('ALTER TABLE tracks DROP COLUMN list_revision');
  db.execute('DROP TABLE library_revision');
}

void removePlaylistThemeSchema(Database db) {
  db.execute('DROP TRIGGER collections_assign_color');
  db.execute('DROP TRIGGER collection_list_name');
  db.execute('DROP INDEX collections_theme_color');
  db.execute('ALTER TABLE collections DROP COLUMN theme_color');
  db.execute(
      '''CREATE TRIGGER collection_list_name AFTER UPDATE OF name ON collections
    WHEN NEW.name IS NOT OLD.name BEGIN
      UPDATE library_revision SET revision=revision+1 WHERE id=1;
      UPDATE tracks SET list_revision=(SELECT revision FROM library_revision WHERE id=1) WHERE collection_id=NEW.id;
    END''');
}

import 'package:sqlite3/sqlite3.dart';

// Reconstruct the actual previous schema, rather than only lowering its number.
void removeOrganizationSchema(Database db) {
  db.execute('DROP INDEX collections_group_id');
  db.execute('ALTER TABLE collections DROP COLUMN group_id');
  db.execute('ALTER TABLE collections DROP COLUMN storage_name');
  db.execute('DROP TABLE collection_groups');
}

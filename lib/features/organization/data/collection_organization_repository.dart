import 'package:sqlite3/sqlite3.dart';
import '../../../core/storage/database.dart';
import '../../library/data/library_repository.dart';
import '../domain/collection_organization.dart';

class CollectionOrganizationRepository {
  const CollectionOrganizationRepository(this.database);
  final AppDatabase database;

  // null = all groups; 0 = ungrouped. Filter before counts and pagination.
  Future<CollectionListing> list(
          {String query = '', int? groupId, int offset = 0}) =>
      database.run((db) {
        if (offset < 0 ||
            query.length > 160 ||
            (groupId != null && groupId < 0)) {
          throw ArgumentError('Filtro inválido.');
        }
        final where = <String>[];
        final args = <Object?>[];
        if (query.trim().isNotEmpty) {
          // Dart case folding works for accented names, independently of SQLite ICU.
          db.createFunction(
              functionName: 'dd_name_contains',
              argumentCount: const AllowedArgumentCount(2),
              function: (values) => (values[0] as String)
                      .toLowerCase()
                      .contains((values[1] as String).toLowerCase())
                  ? 1
                  : 0);
          where.add('dd_name_contains(c.name,?)=1');
          args.add(query.trim());
        }
        if (groupId == 0) {
          where.add('c.group_id IS NULL');
        } else if (groupId != null) {
          where.add('c.group_id=?');
          args.add(groupId);
        }
        final clause = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
        final total = db
            .select('SELECT COUNT(*) AS n FROM collections c $clause', args)
            .first['n'] as int;
        final rows = db.select('''SELECT c.*,
      (SELECT COUNT(*) FROM tracks t WHERE t.collection_id=c.id) AS total,
      (SELECT COUNT(*) FROM tracks t WHERE t.collection_id=c.id AND t.status='completed') AS completed
      FROM collections c $clause ORDER BY c.id DESC LIMIT 30 OFFSET ?''',
            [...args, offset]);
        return CollectionListing(
            rows.map(LibraryRepository.readCollection).toList(), total);
      });

  // Explicit product limit: at most 100 named groups, never an unbounded load.
  Future<List<CollectionGroup>> groups() => database.run((db) => db
      .select('''SELECT g.id,g.name,
    (SELECT COUNT(*) FROM collections c WHERE c.group_id=g.id) AS n
    FROM collection_groups g ORDER BY g.name_key,g.id LIMIT 100''')
      .map((r) =>
          CollectionGroup(r['id'] as int, r['name'] as String, r['n'] as int))
      .toList());

  Future<int> create(String name, {int? groupId}) async {
    final valid = organizationName(name);
    return database.run((db) {
      db.execute(
          'INSERT INTO collections(name,storage_name,source,source_url,group_id) VALUES(?,?,?,\'\',?)',
          [valid, valid, 'Local', groupId]);
      return db.lastInsertRowId;
    });
  }

  Future<void> rename(int id, String name) async {
    final valid = organizationName(name);
    await database.run((db) {
      db.execute(
          'UPDATE collections SET name=?,storage_name=CASE WHEN storage_name=\'\' THEN name ELSE storage_name END WHERE id=?',
          [valid, id]);
      if (db.updatedRows != 1) {
        throw const FormatException('Playlist não encontrada.');
      }
    });
  }

  Future<void> move(int id, int? groupId) => database.run((db) {
        db.execute(
            'UPDATE collections SET group_id=? WHERE id=?', [groupId, id]);
        if (db.updatedRows != 1) {
          throw const FormatException('Playlist não encontrada.');
        }
      });

  Future<void> saveGroup(String name, {int? id}) async {
    final valid = organizationName(name, maxLength: 80),
        key = organizationName(name, maxLength: 80).toLowerCase();
    await database.run((db) {
      db.execute('BEGIN IMMEDIATE');
      try {
        if (db.select(
            'SELECT id FROM collection_groups WHERE name_key=? AND id!=?',
            [key, id ?? 0]).isNotEmpty) {
          throw const FormatException('Já existe um grupo com esse nome.');
        }
        if (id == null) {
          if ((db
                  .select('SELECT COUNT(*) AS n FROM collection_groups')
                  .first['n'] as int) >=
              100) {
            throw const FormatException(
                'Limite de 100 grupos. Renomeie ou remova um grupo existente.');
          }
          db.execute('INSERT INTO collection_groups(name,name_key) VALUES(?,?)',
              [valid, key]);
        } else {
          db.execute(
              'UPDATE collection_groups SET name=?,name_key=? WHERE id=?',
              [valid, key, id]);
          if (db.updatedRows != 1) {
            throw const FormatException('Grupo não encontrado.');
          }
        }
        db.execute('COMMIT');
      } catch (_) {
        db.execute('ROLLBACK');
        rethrow;
      }
    });
  }

  Future<void> removeGroup(int id) => database.run((db) {
        // ON DELETE SET NULL preserves every playlist, occurrence and file reference.
        db.execute('DELETE FROM collection_groups WHERE id=?', [id]);
      });
}

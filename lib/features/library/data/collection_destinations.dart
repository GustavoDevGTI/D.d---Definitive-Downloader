import 'package:path/path.dart' as p;
import '../../../core/storage/database.dart';
import '../../downloads/download_file_name.dart';

/// Where a playlist's media goes. [root] is the chosen location and
/// [directory] the playlist folder inside it.
class CollectionDestination {
  const CollectionDestination(
      {required this.root,
      required this.directory,
      required this.customRoot,
      required this.reserved});
  final String root, directory;

  /// The playlist has its own location instead of the default one.
  final bool customRoot;

  /// The folder is already reserved; otherwise [directory] is a preview and a
  /// numbered name may be used if the folder is taken when the first file
  /// arrives.
  final bool reserved;
}

/// Resolves playlist folders. Playlists created before schema 18 keep their
/// `<name> [id]` folder under the old root until a location is chosen for
/// them. Newer playlists get a folder named after them, reserved once and
/// never reused by another playlist or merged into an existing folder.
class CollectionDestinations {
  CollectionDestinations(this.database,
      {required this.exists, required this.root, required this.legacyRoot});
  final AppDatabase database;

  /// Whether something already exists at this path outside the app's records.
  final Future<bool> Function(String path) exists;

  /// Default location for playlists without their own location.
  final String Function() root;

  /// Root of the playlists created before schema 18.
  final String Function() legacyRoot;

  Future<_Row> _row(int id) => database.run((db) {
        final rows = db.select(
            '''SELECT id,name,storage_name,output_root,output_folder,legacy_folder
            FROM collections WHERE id=?''', [id]);
        if (rows.isEmpty) {
          throw const FormatException('Playlist não encontrada.');
        }
        final r = rows.single;
        final storage = r['storage_name'] as String? ?? '';
        return _Row(
            id: id,
            folder: storage.isEmpty ? r['name'] as String : storage,
            root: r['output_root'] as String? ?? '',
            reserved: r['output_folder'] as String? ?? '',
            legacy: r['legacy_folder'] == 1);
      });

  String _rootOf(_Row row) => row.root.isNotEmpty ? row.root : root();

  String _legacy(_Row row) =>
      p.join(legacyRoot(), '${safeSegment(row.folder)} [${row.id}]');

  /// Folder the playlist uses now, without reserving anything.
  Future<CollectionDestination> describe(int id) async {
    final row = await _row(id);
    if (row.reserved.isNotEmpty) {
      return CollectionDestination(
          root: p.dirname(row.reserved),
          directory: row.reserved,
          customRoot: row.root.isNotEmpty,
          reserved: true);
    }
    if (row.legacy && row.root.isEmpty) {
      final directory = _legacy(row);
      return CollectionDestination(
          root: legacyRoot(),
          directory: directory,
          customRoot: false,
          reserved: true);
    }
    return CollectionDestination(
        root: _rootOf(row),
        directory: await _candidate(row),
        customRoot: row.root.isNotEmpty,
        reserved: false);
  }

  /// Folder for the next file, reserved on first use.
  Future<String> directory(int id) async {
    for (var attempt = 0; attempt < 5; attempt++) {
      final row = await _row(id);
      if (row.reserved.isNotEmpty) return row.reserved;
      if (row.legacy && row.root.isEmpty) return _legacy(row);
      final candidate = await _candidate(row);
      final claimed = await database.run((db) {
        db.execute('BEGIN IMMEDIATE');
        try {
          final taken = db.select(
              '''SELECT 1 FROM collections WHERE id!=? AND output_folder!=''
              AND lower(output_folder)=lower(?) LIMIT 1''',
              [id, candidate]).isNotEmpty;
          if (!taken) {
            db.execute(
                "UPDATE collections SET output_folder=? WHERE id=? AND output_folder=''",
                [candidate, id]);
          }
          db.execute('COMMIT');
          return !taken;
        } catch (_) {
          rollbackAfterFailure(db);
          rethrow;
        }
      });
      if (claimed) {
        final reserved = (await _row(id)).reserved;
        if (reserved.isNotEmpty) return reserved;
      }
    }
    throw const FormatException(
        'Não foi possível reservar a pasta da playlist. Tente novamente.');
  }

  Future<String> _candidate(_Row row) async {
    final parent = _rootOf(row);
    if (parent.isEmpty) {
      throw const FormatException('Escolha a pasta de downloads.');
    }
    final taken = await database.run((db) => db
        .select(
            "SELECT lower(output_folder) AS f FROM collections WHERE id!=? AND output_folder!=''",
            [row.id])
        .map((r) => p.normalize(r['f'] as String))
        .toSet());
    final base = safeSegment(row.folder);
    for (var n = 1; n <= 999; n++) {
      final candidate = p.join(parent, n == 1 ? base : '$base ($n)');
      if (taken.contains(p.normalize(candidate.toLowerCase()))) continue;
      // A folder that already exists belongs to somebody else: the app never
      // merges its files or its playlist.m3u8 into it.
      if (await exists(candidate)) continue;
      return candidate;
    }
    throw const FormatException(
        'Há pastas demais com o nome desta playlist no destino.');
  }

  /// Chooses where the playlist's next files go. An empty [root] returns the
  /// playlist to the default location. Files already saved stay where they
  /// are.
  Future<void> setRoot(int id, String root) async {
    if (root.isNotEmpty && !p.isAbsolute(root)) {
      throw const FormatException('Escolha uma pasta válida.');
    }
    await database.run((db) {
      db.execute(
          "UPDATE collections SET output_root=?,output_folder='',legacy_folder=0 WHERE id=?",
          [root, id]);
      if (db.updatedRows == 0) {
        throw const FormatException('Playlist não encontrada.');
      }
    });
  }

  /// Location chosen for a playlist created now (for example, a capture).
  Future<void> setInitialRoot(int id, String root) =>
      root.isEmpty ? Future<void>.value() : setRoot(id, root);
}

class _Row {
  const _Row(
      {required this.id,
      required this.folder,
      required this.root,
      required this.reserved,
      required this.legacy});
  final int id;
  final String folder, root, reserved;
  final bool legacy;
}

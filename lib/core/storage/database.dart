import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';

class AppDatabase {
  const AppDatabase(this.path);
  final String path;

  Future<T> run<T>(T Function(Database database) action) {
    final filePath = path;
    return Isolate.run(() {
      if (Platform.isWindows) {
        open.overrideFor(OperatingSystem.windows,
            () => DynamicLibrary.open('winsqlite3.dll'));
      }
      final db = sqlite3.open(filePath);
      try {
        db.execute('PRAGMA foreign_keys = ON');
        db.execute('PRAGMA busy_timeout = 5000');
        return action(db);
      } finally {
        db.dispose();
      }
    });
  }

  Future<void> initialize() async {
    await File(path).parent.create(recursive: true);
    await run((db) {
      final version =
          db.select('PRAGMA user_version').first.values.first as int;
      if (version > 7) {
        throw StateError('Este banco foi criado por uma versão mais recente.');
      }
      if (version == 0) {
        db.execute('BEGIN IMMEDIATE');
        try {
          db.execute('''CREATE TABLE collections (
            id INTEGER PRIMARY KEY, name TEXT NOT NULL, source TEXT NOT NULL,
            source_url TEXT NOT NULL, partial INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP)''');
          db.execute('''CREATE TABLE tracks (
            id INTEGER PRIMARY KEY, collection_id INTEGER NOT NULL REFERENCES collections(id) ON DELETE CASCADE,
            position INTEGER NOT NULL, title TEXT NOT NULL, artist TEXT NOT NULL,
            album TEXT NOT NULL DEFAULT '', duration_ms INTEGER, isrc TEXT NOT NULL DEFAULT '',
            cover_url TEXT NOT NULL DEFAULT '', source_url TEXT NOT NULL DEFAULT '',
            media_url TEXT NOT NULL DEFAULT '', source_kind TEXT NOT NULL DEFAULT 'none',
            status TEXT NOT NULL DEFAULT 'pending', selected INTEGER NOT NULL DEFAULT 0,
            local_path TEXT NOT NULL DEFAULT '', error TEXT NOT NULL DEFAULT '',
            resolved_title TEXT NOT NULL DEFAULT '', resolved_artist TEXT NOT NULL DEFAULT '',
            UNIQUE(collection_id, position))''');
          db.execute(
              'CREATE INDEX tracks_collection_position ON tracks(collection_id, position)');
          db.execute(
              'CREATE INDEX tracks_queue ON tracks(collection_id, selected, status, position)');
          db.execute(
              'CREATE TABLE preferences (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
          db.execute('PRAGMA user_version = 1');
          db.execute('COMMIT');
        } catch (_) {
          db.execute('ROLLBACK');
          rethrow;
        }
      }
      if (version <= 1) {
        db.execute('BEGIN IMMEDIATE');
        try {
          db.execute(
              "ALTER TABLE tracks ADD COLUMN resolved_album TEXT NOT NULL DEFAULT ''");
          db.execute(
              'ALTER TABLE tracks ADD COLUMN resolved_duration_ms INTEGER');
          db.execute('PRAGMA user_version = 2');
          db.execute('COMMIT');
        } catch (_) {
          db.execute('ROLLBACK');
          rethrow;
        }
      }
      if (version <= 2) {
        db.execute('BEGIN IMMEDIATE');
        try {
          // Only app-generated demo labels change; imported music stays intact.
          db.execute("""UPDATE tracks SET artist='Laboratório D.d'
            WHERE source_kind='localExample' AND artist='Laboratório Trama'
              AND media_url='asset:assets/demo/tone.mp3'""");
          db.execute('PRAGMA user_version = 3');
          db.execute('COMMIT');
        } catch (_) {
          db.execute('ROLLBACK');
          rethrow;
        }
      }
      if (version <= 3) {
        db.execute('BEGIN IMMEDIATE');
        try {
          db.execute('ALTER TABLE tracks ADD COLUMN explicit INTEGER');
          db.execute(
              "ALTER TABLE tracks ADD COLUMN resolved_cover_url TEXT NOT NULL DEFAULT ''");
          db.execute('''CREATE TABLE music_candidates (
            track_id INTEGER NOT NULL REFERENCES tracks(id) ON DELETE CASCADE,
            ordinal INTEGER NOT NULL, kind TEXT NOT NULL, title TEXT NOT NULL,
            artist TEXT NOT NULL, album TEXT NOT NULL, duration_ms INTEGER NOT NULL,
            page_url TEXT NOT NULL, cover_url TEXT NOT NULL, isrc TEXT NOT NULL,
            recording_type TEXT NOT NULL, explicit INTEGER,
            PRIMARY KEY(track_id,ordinal))''');
          db.execute('PRAGMA user_version = 4');
          db.execute('COMMIT');
        } catch (_) {
          db.execute('ROLLBACK');
          rethrow;
        }
      }
      if (version <= 4) {
        db.execute('BEGIN IMMEDIATE');
        try {
          // Last result per provider and occurrence; never store request/session data.
          db.execute('''CREATE TABLE music_source_attempts (
            track_id INTEGER NOT NULL REFERENCES tracks(id) ON DELETE CASCADE,
            provider TEXT NOT NULL, succeeded INTEGER NOT NULL,
            message TEXT NOT NULL, updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY(track_id,provider))''');
          db.execute('PRAGMA user_version = 5');
          db.execute('COMMIT');
        } catch (_) {
          db.execute('ROLLBACK');
          rethrow;
        }
      }
      if (version <= 5) {
        db.execute('BEGIN IMMEDIATE');
        try {
          db.execute(
              "ALTER TABLE tracks ADD COLUMN match_status TEXT NOT NULL DEFAULT 'pending'");
          db.execute(
              "ALTER TABLE tracks ADD COLUMN manual_url TEXT NOT NULL DEFAULT ''");
          db.execute(
              "ALTER TABLE tracks ADD COLUMN manual_mode TEXT NOT NULL DEFAULT 'originalAudio'");
          db.execute(
              'ALTER TABLE tracks ADD COLUMN queue_hidden INTEGER NOT NULL DEFAULT 0');
          db.execute(
              "UPDATE tracks SET match_status=CASE WHEN source_kind='none' THEN 'pending' WHEN source_kind='directMp3' THEN 'manual' ELSE 'confirmed' END");
          db.execute(
              "UPDATE tracks SET manual_url=media_url WHERE source_kind='directMp3'");
          db.execute('''CREATE TABLE download_history (
            id INTEGER PRIMARY KEY, track_id INTEGER REFERENCES tracks(id) ON DELETE SET NULL,
            category TEXT NOT NULL DEFAULT 'music', name TEXT NOT NULL,
            local_path TEXT NOT NULL UNIQUE, folder TEXT NOT NULL,
            source TEXT NOT NULL, duration_ms INTEGER,
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP, hidden INTEGER NOT NULL DEFAULT 0)''');
          // Keep completed-file references even when a track gets a new source later.
          var afterId = 0;
          while (true) {
            final completed = db.select(
                "SELECT * FROM tracks WHERE status='completed' AND local_path!='' AND id>? ORDER BY id LIMIT 100",
                [afterId]);
            if (completed.isEmpty) break;
            for (final row in completed) {
              afterId = row['id'] as int;
              final local = row['local_path'] as String;
              final separator = local.lastIndexOf(RegExp(r'[/\\]'));
              db.execute(
                  '''INSERT OR IGNORE INTO download_history
              (track_id,name,local_path,folder,source,duration_ms) VALUES(?,?,?,?,?,?)''',
                  [
                    row['id'],
                    separator < 0 ? local : local.substring(separator + 1),
                    local,
                    separator < 0 ? '' : local.substring(0, separator),
                    row['source_kind'],
                    row['resolved_duration_ms'] ?? row['duration_ms']
                  ]);
            }
          }
          db.execute(
              'CREATE INDEX history_folder_name ON download_history(hidden,folder,name)');
          db.execute(
              'CREATE INDEX tracks_transfer_status ON tracks(queue_hidden,status,id)');
          db.execute('PRAGMA user_version = 6');
          db.execute('COMMIT');
        } catch (_) {
          db.execute('ROLLBACK');
          rethrow;
        }
      }
      if (version <= 6) {
        db.execute('BEGIN IMMEDIATE');
        try {
          db.execute(
              'ALTER TABLE tracks ADD COLUMN queue_priority INTEGER NOT NULL DEFAULT 0');
          db.execute(
              "ALTER TABLE tracks ADD COLUMN queue_run TEXT NOT NULL DEFAULT ''");
          db.execute(
              'CREATE INDEX tracks_priority ON tracks(queue_hidden,status,queue_priority DESC,collection_id,position)');
          db.execute('PRAGMA user_version = 7');
          db.execute('COMMIT');
        } catch (_) {
          db.execute('ROLLBACK');
          rethrow;
        }
      }
      db.execute(
          "UPDATE tracks SET status='ready', error='Transferência interrompida; pronta para reiniciar.' WHERE status='downloading'");
    });
  }
}

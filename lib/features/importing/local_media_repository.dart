import '../../core/storage/database.dart';
import '../library/data/library_repository.dart';
import '../library/domain/models.dart';
import 'local_mp3_inspector.dart';
import 'package:path/path.dart' as p;

class LocalMediaCopy {
  const LocalMediaCopy(this.path, this.original, this.metadata);
  final String path, original;
  final LocalAudioMetadata metadata;
}

class LocalMediaRepository {
  const LocalMediaRepository(this.database);
  final AppDatabase database;
  Future<({Collection owner, int last})> target(int id, int count) =>
      database.run((db) {
        final rows = db.select(
            '''SELECT c.*,(SELECT COUNT(*) FROM tracks WHERE collection_id=c.id) AS total,
        (SELECT COUNT(*) FROM tracks WHERE collection_id=c.id AND status='completed') AS completed
        FROM collections c WHERE id=?''', [id]);
        if (rows.isEmpty) {
          throw const FormatException('Playlist não encontrada.');
        }
        final owner = LibraryRepository.readCollection(rows.single);
        if (owner.trackCount + count > 10000) {
          throw const FormatException('Limite de 10.000 faixas por coleção.');
        }
        final last = db.select(
            'SELECT COALESCE(MAX(position),0) AS n FROM tracks WHERE collection_id=?',
            [id]).single['n'] as int;
        return (owner: owner, last: last);
      });

  Future<void> commit(int id, int last, List<LocalMediaCopy> copies) =>
      database.run((db) {
        if (copies.isEmpty || copies.length > 100) {
          throw const FormatException('Lote local inválido.');
        }
        db.execute('BEGIN IMMEDIATE');
        try {
          final size = db.select(
              'SELECT COUNT(*) AS n,COALESCE(MAX(position),0) AS last FROM tracks WHERE collection_id=?',
              [id]).single;
          if (size['last'] != last ||
              (size['n'] as int) + copies.length > 10000) {
            throw const FormatException(
                'A playlist mudou durante a cópia. Adicione os arquivos novamente.');
          }
          for (var i = 0; i < copies.length; i++) {
            final copy = copies[i], m = copy.metadata;
            db.execute(
                '''INSERT INTO tracks(collection_id,position,title,artist,album,duration_ms,
            source_url,media_url,source_kind,status,local_path,match_status,queue_added)
            VALUES(?,?,?,?,?,?,?,?, 'localFile','completed',?,'confirmed',1)''',
                [
                  id,
                  last + i + 1,
                  m.title,
                  m.artist,
                  m.album,
                  m.durationMs,
                  Uri.file(copy.original).toString(),
                  Uri.file(copy.path).toString(),
                  copy.path
                ]);
            db.execute(
                '''INSERT INTO download_history(track_id,name,local_path,folder,source,duration_ms)
            VALUES(?,?,?,?, 'localFile',?)''',
                [
                  db.lastInsertRowId,
                  p.basename(copy.path),
                  copy.path,
                  p.dirname(copy.path),
                  m.durationMs
                ]);
          }
          db.execute(
              'UPDATE collections SET editing_locked=1 WHERE id=?', [id]);
          db.execute('COMMIT');
        } catch (_) {
          db.execute('ROLLBACK');
          rethrow;
        }
      });
}

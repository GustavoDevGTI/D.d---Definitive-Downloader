import '../../../core/storage/database.dart';
import '../domain/models.dart';
import 'library_repository.dart';

class RedownloadRepository {
  const RedownloadRepository(this.database);
  final AppDatabase database;

  Future<bool> hasWork(
          {int? collectionId, List<int>? ids, bool failedOnly = false}) =>
      database.run((db) {
        if (ids?.isEmpty == true) return false;
        if (ids != null && ids.length > 10000) {
          throw const FormatException('Seleção inválida.');
        }
        final scope = ids == null
            ? 'collection_id=? AND selected=1'
            : 'id IN (${List.filled(ids.length, '?').join(',')})';
        return db.select(
            '''SELECT 1 FROM tracks WHERE ($scope) AND queue_hidden=0
      AND source_kind!='none' AND match_status!='review' AND redownload_state!='review'
      AND (source_kind!='youtube' OR source_authorization IN ('manualLink','approvedVideo'))
      AND NOT(manual_url!='' AND manual_mode='extractAudio')
      AND status IN ('ready','failed') ${failedOnly ? "AND status='failed'" : ''} LIMIT 1''',
            [if (ids == null) collectionId else ...ids]).isNotEmpty;
      });

  Future<List<Track>> selected(
          {int? collectionId,
          List<int>? ids,
          int offset = 0,
          bool failedOnly = false}) =>
      database.run((db) {
        if (offset < 0 || (ids != null && ids.length > 10000)) {
          throw const FormatException('Seleção inválida.');
        }
        if (ids?.isEmpty == true) return <Track>[];
        final scope = ids == null
            ? 'collection_id=? AND selected=1'
            : 'id IN (${List.filled(ids.length, '?').join(',')})';
        return db
            .select('''SELECT * FROM tracks WHERE ($scope) AND
        (${failedOnly ? '0' : "status='completed'"} OR redownload_state!='')
        ORDER BY collection_id,position,id LIMIT 40 OFFSET ?''',
                [if (ids == null) collectionId else ...ids, offset])
            .map(LibraryRepository.readTrack)
            .toList();
      });

  Future<void> request(List<Track> missing) => database.run((db) {
        if (missing.length > 40) {
          throw const FormatException('Seleção deve ser paginada.');
        }
        db.execute('BEGIN IMMEDIATE');
        try {
          for (final track in missing) {
            db.execute(
                """UPDATE tracks SET status='pending',redownload_state='review',
            queue_hidden=0,error='' WHERE id=? AND status='completed' AND local_path=?""",
                [track.id, track.localPath]);
          }
          db.execute('COMMIT');
        } catch (_) {
          db.execute('ROLLBACK');
          rethrow;
        }
      });

  /// Explicit user choice of the previously linked version; never starts work.
  Future<void> approvePrevious(int id,
          {required String url, required SourceKind kind}) =>
      database.run((db) {
        db.execute('BEGIN IMMEDIATE');
        try {
          final rows = db.select('SELECT * FROM tracks WHERE id=?', [id]);
          if (rows.isEmpty) {
            throw const FormatException('Faixa não encontrada.');
          }
          final track = LibraryRepository.readTrack(rows.first);
          if (!track.redownloadReview ||
              !track.hasDownloadableSource ||
              track.mediaUrl != url ||
              track.sourceKind != kind ||
              ['downloading', 'completed'].contains(track.status.name)) {
            throw const FormatException(
                'A fonte mudou ou precisa de revisão. Escolha novamente.');
          }
          db.execute(
              "UPDATE tracks SET redownload_state='approved',status='ready',error='' WHERE id=?",
              [id]);
          db.execute('COMMIT');
        } catch (_) {
          db.execute('ROLLBACK');
          rethrow;
        }
      });
}

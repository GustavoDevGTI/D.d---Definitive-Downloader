import '../../../core/storage/database.dart';
import '../../library/data/library_repository.dart';
import '../../library/domain/models.dart';
import '../domain/workspace_models.dart';

class WorkspaceRepository {
  const WorkspaceRepository(this.database);
  final AppDatabase database;

  Future<DownloadPage> downloads(ContentCategory category,
          {DownloadFilter filter = DownloadFilter.all,
          int offset = 0,
          bool pauseMode = false}) =>
      database.run((db) {
        if (offset < 0) throw ArgumentError('Página inválida.');
        // No video/photo transfer engine is connected yet. Never relabel music jobs.
        if (category == ContentCategory.media ||
            (filter == DownloadFilter.paused && !pauseMode)) {
          return const DownloadPage([], 0);
        }
        final status = switch (filter) {
          DownloadFilter.downloading =>
            pauseMode ? ' AND 0' : " AND t.status='downloading'",
          DownloadFilter.queued => " AND t.status IN ('pending','ready')",
          DownloadFilter.completed => " AND t.status='completed'",
          DownloadFilter.failed => " AND t.status='failed'",
          DownloadFilter.paused => " AND t.status='downloading'",
          _ => '',
        };
        final where =
            "t.queue_hidden=0 AND (t.source_kind!='none' OR t.manual_url!='')$status";
        final count = db
            .select('SELECT COUNT(*) AS n FROM tracks t WHERE $where')
            .first['n'] as int;
        final rows = db.select(
            '''SELECT t.*, c.name AS collection_name FROM tracks t
      JOIN collections c ON c.id=t.collection_id WHERE $where
      ORDER BY t.queue_priority DESC,t.collection_id,t.position LIMIT 40 OFFSET ?''',
            [offset]);
        return DownloadPage(
            rows
                .map((r) => DownloadEntry(LibraryRepository.readTrack(r),
                    r['collection_name'] as String))
                .toList(),
            count);
      });

  Future<void> changePriority(List<int> ids, int delta) => database.run((db) {
        if (ids.length > 100 || ![-1, 1].contains(delta)) {
          throw ArgumentError('Seleção inválida.');
        }
        db.execute('BEGIN IMMEDIATE');
        try {
          for (final id in ids) {
            db.execute(
                "UPDATE tracks SET queue_priority=MIN(4,MAX(-4,queue_priority+?)) WHERE id=? AND queue_hidden=0 AND status IN ('ready','failed')",
                [delta, id]);
          }
          db.execute('COMMIT');
        } catch (_) {
          db.execute('ROLLBACK');
          rethrow;
        }
      });

  // Removing a queue entry never deletes media, collection occurrences or the
  // independent file history. Relinking its source makes the entry visible again.
  Future<void> removeDownloads(List<int> ids) => database.run((db) {
        if (ids.length > 100) throw ArgumentError('Seleção deve ser paginada.');
        db.execute('BEGIN IMMEDIATE');
        try {
          for (final id in ids) {
            db.execute(
                "UPDATE tracks SET queue_hidden=1,selected=0 WHERE id=? AND status!='downloading'",
                [id]);
          }
          db.execute('COMMIT');
        } catch (_) {
          db.execute('ROLLBACK');
          rethrow;
        }
      });

  Future<Track?> claimNext(
          {required String run,
          List<int>? ids,
          int? collectionId,
          bool failedOnly = false}) =>
      database.run((db) {
        if (run.isEmpty ||
            (ids == null && collectionId == null) ||
            (ids != null && (ids.isEmpty || ids.length > 100))) {
          return null;
        }
        final selection = ids == null
            ? 'collection_id=? AND selected=1'
            : 'id IN (${List.filled(ids.length, '?').join(',')})';
        db.execute('BEGIN IMMEDIATE');
        try {
          final rows = db.select(
              '''SELECT * FROM tracks WHERE queue_run!=? AND queue_hidden=0
        AND $selection AND source_kind!='none' AND match_status!='review'
        AND NOT(manual_url!='' AND manual_mode='extractAudio')
        AND ${failedOnly ? "status='failed'" : "status IN ('ready','failed')"}
        ORDER BY queue_priority DESC,collection_id,position LIMIT 1''',
              [run, if (ids == null) collectionId else ...ids]);
          Track? track;
          if (rows.isNotEmpty) {
            track = LibraryRepository.readTrack(rows.first);
            db.execute(
                "UPDATE tracks SET queue_run=?,status='downloading',error='' WHERE id=?",
                [run, track.id]);
          }
          db.execute('COMMIT');
          return track;
        } catch (_) {
          db.execute('ROLLBACK');
          rethrow;
        }
      });

  Future<ActivitySummary> summary() => database.run((db) {
        final counts = db.select('''SELECT
      COALESCE(SUM(source_kind!='none' OR manual_url!=''),0) AS records,
      COALESCE(SUM(status='downloading'),0) AS active,
      COALESCE(SUM(selected=1 AND status IN ('ready','failed') AND source_kind!='none'
        AND match_status!='review' AND NOT(manual_url!='' AND manual_mode='extractAudio')),0) AS queued
      FROM tracks WHERE queue_hidden=0''').first;
        final completed = db
            .select('SELECT COUNT(*) AS n FROM download_history WHERE hidden=0')
            .first['n'] as int;
        final recent = db.select(
            'SELECT * FROM download_history WHERE hidden=0 ORDER BY id DESC LIMIT 5');
        return ActivitySummary(
            records: counts['records'] as int,
            active: counts['active'] as int,
            queued: counts['queued'] as int,
            completed: completed,
            recent: recent.map(_history).toList());
      });

  Future<HistoryPage> history(
          {String folder = '', String query = '', int offset = 0}) =>
      database.run((db) {
        if (offset < 0) throw ArgumentError('Página inválida.');
        final search = query.trim();
        if (folder.isEmpty) {
          final where =
              "hidden=0 AND (?='' OR instr(lower(name),lower(?))>0 OR instr(lower(folder),lower(?))>0)";
          final args = [search, search, search];
          final count = db
              .select(
                  'SELECT COUNT(DISTINCT folder) AS n FROM download_history WHERE $where',
                  args)
              .first['n'] as int;
          final rows = db.select(
              '''SELECT folder,COUNT(*) AS n FROM download_history WHERE $where
        GROUP BY folder ORDER BY folder LIMIT 40 OFFSET ?''',
              [...args, offset]);
          return HistoryPage(
              rows
                  .map((r) =>
                      HistoryFolder(r['folder'] as String, r['n'] as int))
                  .toList(),
              [],
              count);
        }
        final base =
            folder.replaceAll('\\', '/').replaceFirst(RegExp(r'/+$'), '');
        // Only recorded downloads are browsed. No filesystem tree is scanned.
        const entries = '''WITH visible AS (
          SELECT *,replace(folder,char(92),'/') AS normalized FROM download_history
          WHERE hidden=0 AND (?2='' OR instr(lower(name),lower(?2))>0 OR instr(lower(folder),lower(?2))>0)
        ), descendants AS (
          SELECT substr(normalized,length(?1)+2) AS tail FROM visible WHERE instr(normalized,?1||'/')=1
        ), entries AS (
          SELECT 0 AS sort,0 AS id,?1||'/'||CASE WHEN instr(tail,'/')=0 THEN tail
            ELSE substr(tail,1,instr(tail,'/')-1) END AS name,'' AS local_path,
            '' AS folder,'' AS source,NULL AS duration_ms,COUNT(*) AS n
          FROM descendants GROUP BY name
          UNION ALL
          SELECT 1 AS sort,id,name,local_path,folder,source,duration_ms,0 AS n FROM visible WHERE normalized=?1
        )''';
        final count = db.select('$entries SELECT COUNT(*) AS n FROM entries',
            [base, search]).first['n'] as int;
        final rows = db.select(
            '$entries SELECT * FROM entries ORDER BY sort,name LIMIT 40 OFFSET ?3',
            [base, search, offset]);
        return HistoryPage(
            rows
                .where((r) => r['sort'] == 0)
                .map((r) => HistoryFolder(r['name'] as String, r['n'] as int))
                .toList(),
            rows.where((r) => r['sort'] == 1).map(_history).toList(),
            count);
      });

  Future<void> hideCompleted(List<int> trackIds) => database.run((db) {
        if (trackIds.length > 100) {
          throw ArgumentError('Seleção deve ser paginada.');
        }
        db.execute('BEGIN IMMEDIATE');
        try {
          for (final id in trackIds) {
            db.execute(
                "UPDATE tracks SET queue_hidden=1 WHERE id=? AND status='completed'",
                [id]);
            db.execute(
                "UPDATE download_history SET hidden=1 WHERE track_id=? AND EXISTS(SELECT 1 FROM tracks WHERE id=? AND status='completed')",
                [id, id]);
          }
          db.execute('COMMIT');
        } catch (_) {
          db.execute('ROLLBACK');
          rethrow;
        }
      });

  Future<Track?> nextQueueItem(List<int>? ids, int afterId) =>
      database.run((db) {
        if (ids != null && (ids.isEmpty || ids.length > 100)) return null;
        final selection = ids == null
            ? 'selected=1'
            : 'id IN (${List.filled(ids.length, '?').join(',')})';
        final rows = db.select(
            '''SELECT * FROM tracks WHERE id>? AND queue_hidden=0 AND $selection
      AND source_kind!='none' AND match_status!='review'
      AND NOT(manual_url!='' AND manual_mode='extractAudio') AND status IN ('ready','failed')
      ORDER BY id LIMIT 1''', [afterId, ...?ids]);
        return rows.isEmpty ? null : LibraryRepository.readTrack(rows.first);
      });

  static HistoryEntry _history(Map<String, Object?> r) => HistoryEntry(
      id: r['id'] as int,
      name: r['name'] as String,
      path: r['local_path'] as String,
      folder: r['folder'] as String,
      source: r['source'] as String,
      durationMs: r['duration_ms'] as int?);
}

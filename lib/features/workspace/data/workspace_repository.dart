import '../../../core/platform/platform_services.dart';
import '../../../core/storage/database.dart';
import '../../library/data/library_repository.dart';
import '../../library/domain/models.dart';
import '../../downloads/run_order.dart';
import '../domain/workspace_models.dart';
import '../domain/download_columns.dart';
import 'download_listing_query.dart';

class WorkspaceRepository {
  const WorkspaceRepository(this.database);
  final AppDatabase database;

  Future<DownloadPage> downloads(ContentCategory category,
          {DownloadFilter filter = DownloadFilter.all,
          int offset = 0,
          String query = '',
          bool pauseMode = false,
          DownloadSort? sort,
          bool descending = false,
          String outputDirectory = ''}) =>
      database.run((db) {
        if (offset < 0 || query.length > 200) {
          throw ArgumentError('Pesquisa ou página inválida.');
        }
        // No video/photo transfer engine is connected yet. Never relabel music jobs.
        if (category == ContentCategory.media ||
            (filter == DownloadFilter.paused && !pauseMode)) {
          return const DownloadPage([], 0);
        }
        final listing = DownloadListingQuery(db,
            filter: filter,
            query: query,
            pauseMode: pauseMode,
            sort: sort,
            descending: descending,
            outputDirectory: outputDirectory);
        final from = listing.from,
            where = listing.where,
            args = listing.args,
            order = listing.order;
        final count = db
            .select('SELECT COUNT(*) AS n $from WHERE $where', args)
            .single['n'] as int;
        final rows = db.select(
            'SELECT t.*,c.name AS collection_name,c.theme_color,h.created_at AS downloaded_at $from WHERE $where '
            'ORDER BY $order LIMIT 40 OFFSET ?',
            [...args, offset]);
        return DownloadPage(
            rows
                .map((r) => DownloadEntry(LibraryRepository.readTrack(r),
                    r['collection_name'] as String,
                    playlistColor: r['theme_color'] as int?,
                    downloadedAt:
                        _readCompletionDate(r['downloaded_at'] as String?)))
                .toList(),
            count);
      }).then((page) async {
        // Bounded to the current page; asynchronous disk checks never run in widgets.
        final entries = await Future.wait(page.items.map((entry) async {
          final track = entry.track;
          int? size;
          if (track.status == TrackStatus.completed &&
              track.localPath.isNotEmpty) {
            try {
              size = await createPlatformFiles().fileSize(track.localPath);
            } catch (_) {/* Unavailable public volume. */}
          }
          return DownloadEntry(track, entry.collectionName,
              playlistColor: entry.playlistColor,
              downloadedAt: entry.downloadedAt,
              fileBytes: size);
        }));
        return DownloadPage(entries, page.total);
      });

  static DateTime? _readCompletionDate(String? value) {
    if (value == null || value.isEmpty) return null;
    // SQLite CURRENT_TIMESTAMP is UTC, even though it omits the timezone.
    final normalized = value.replaceFirst(' ', 'T');
    return DateTime.tryParse(
        RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(normalized)
            ? normalized
            : '${normalized}Z');
  }

  Future<List<double>> columnWidths() => database.run((db) {
        final widths = downloadColumns.map((c) => c.width).toList();
        final keys = downloadColumns
            .skip(1)
            .map((c) => 'download_column_${c.key}')
            .toList();
        final rows = db.select(
            'SELECT key,value FROM preferences WHERE key IN (${List.filled(keys.length, '?').join(',')})',
            keys);
        for (final row in rows) {
          final index = keys.indexOf(row['key'] as String) + 1;
          final value = double.tryParse(row['value'] as String);
          if (index > 0 && value != null && value.isFinite) {
            widths[index] = boundedColumnWidth(index, value);
          }
        }
        return widths;
      });

  Future<void> saveColumnWidths(List<double> widths) => database.run((db) {
        if (widths.length != downloadColumns.length) {
          throw ArgumentError('Colunas inválidas.');
        }
        db.execute('BEGIN IMMEDIATE');
        try {
          for (var i = 1; i < widths.length; i++) {
            db.execute(
                'INSERT INTO preferences(key,value) VALUES(?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value',
                [
                  'download_column_${downloadColumns[i].key}',
                  '${boundedColumnWidth(i, widths[i])}'
                ]);
          }
          db.execute('COMMIT');
        } catch (_) {
          db.execute('ROLLBACK');
          rethrow;
        }
      });

  Future<void> changePriority(List<int> ids, int delta) => database.run((db) {
        if (ids.length > 10000 || ![-1, 1].contains(delta)) {
          throw ArgumentError('Seleção inválida.');
        }
        db.execute('BEGIN IMMEDIATE');
        try {
          for (final id in ids) {
            db.execute(
                "UPDATE tracks SET queue_priority=MIN(4,MAX(-4,queue_priority+?)) WHERE id=? AND queue_hidden=0 AND status IN ('ready','failed')",
                [delta, id]);
          }
          final runs = ids.isEmpty
              ? <Map<String, Object?>>[]
              : db.select(
                  'SELECT DISTINCT run FROM download_run_additions WHERE track_id IN (${List.filled(ids.length, '?').join(',')})',
                  ids);
          for (final run in runs) {
            final members = db.select(
                '''SELECT a.*,t.queue_priority,t.collection_id,t.position
                FROM download_run_additions a JOIN tracks t ON t.id=a.track_id
                WHERE a.run=? AND t.queue_run!=? AND t.status IN ('ready','failed')
                ORDER BY a.ordinal LIMIT 10001''', [run['run'], run['run']]);
            if (members.length > 10000) {
              throw const FormatException(
                  'Limite de 10.000 faixas por execução.');
            }
            final order = [...members]..sort((a, b) {
                final priority = (b['queue_priority'] as int)
                    .compareTo(a['queue_priority'] as int);
                if (priority != 0) return priority;
                final owner = (a['collection_id'] as int)
                    .compareTo(b['collection_id'] as int);
                return owner != 0
                    ? owner
                    : (a['position'] as int).compareTo(b['position'] as int);
              });
            reassignRunSlots(
                db, members, order.map((r) => r['track_id'] as int).toList());
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
        if (ids.length > 10000) {
          throw ArgumentError('Limite de 10.000 itens por ação.');
        }
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

  Future<void> beginRun(
          {required String run,
          List<int>? ids,
          int? collectionId,
          bool failedOnly = false}) =>
      database.run((db) {
        if (run.isEmpty ||
            (ids == null && collectionId == null) ||
            (ids != null && (ids.isEmpty || ids.length > 10000))) {
          throw const FormatException('Seleção de execução inválida.');
        }
        db.execute('BEGIN IMMEDIATE');
        try {
          if (db.select(
              'SELECT 1 FROM download_run_additions WHERE run=? LIMIT 1',
              [run]).isNotEmpty) {
            throw const FormatException('Esta execução já foi iniciada.');
          }
          final scope = ids == null
              ? 'collection_id=? AND selected=1'
              : 'id IN (${List.filled(ids.length, '?').join(',')})';
          final rows = db.select('''SELECT id FROM tracks WHERE ($scope)
        AND queue_hidden=0 AND source_kind!='none' AND match_status!='review' AND redownload_state!='review'
        AND (source_kind!='youtube' OR source_authorization IN ('manualLink','approvedVideo'))
        AND NOT(manual_url!='' AND manual_mode='extractAudio')
        AND status IN ('ready','failed') ${failedOnly ? "AND status='failed'" : ''}
        ORDER BY queue_priority DESC,collection_id,position,id LIMIT 10001''',
              [if (ids == null) collectionId else ...ids]);
          if (rows.length > 10000) {
            throw const FormatException(
                'Limite de 10.000 faixas por execução.');
          }
          final insert = db.prepare(
              'INSERT INTO download_run_additions(run,track_id) VALUES(?,?)');
          try {
            for (final row in rows) {
              insert.execute([run, row['id']]);
            }
          } finally {
            insert.dispose();
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
          bool failedOnly = false,
          bool snapshot = false}) =>
      database.run((db) {
        if (run.isEmpty ||
            (!snapshot && ids == null && collectionId == null) ||
            (ids != null && (ids.isEmpty || ids.length > 10000))) {
          return null;
        }
        final selection = ids == null
            ? 't.collection_id=? AND t.selected=1'
            : 't.id IN (${List.filled(ids.length, '?').join(',')})';
        final scope = snapshot
            ? 'a.track_id IS NOT NULL'
            : '(($selection) OR a.track_id IS NOT NULL)';
        db.execute('BEGIN IMMEDIATE');
        try {
          final rows = db.select('''SELECT t.* FROM tracks t
        LEFT JOIN download_run_additions a ON a.track_id=t.id AND a.run=?
        WHERE t.queue_run!=? AND t.queue_hidden=0
        AND $scope
        AND t.source_kind!='none' AND t.match_status!='review' AND t.redownload_state!='review'
        AND (t.source_kind!='youtube' OR t.source_authorization IN ('manualLink','approvedVideo'))
        AND NOT(t.manual_url!='' AND t.manual_mode='extractAudio')
        AND t.status IN ('ready','failed')
        ${failedOnly ? "AND (t.status='failed' OR a.track_id IS NOT NULL)" : ''}
        ORDER BY ${snapshot ? 'a.ordinal,' : ''} (a.track_id IS NOT NULL),
          CASE WHEN a.track_id IS NULL THEN t.queue_priority END DESC,
          a.ordinal,t.collection_id,t.position LIMIT 1''', [
            run,
            run,
            if (!snapshot) ...[if (ids == null) collectionId else ...ids]
          ]);
          Track? track;
          if (rows.isNotEmpty) {
            track = LibraryRepository.readTrack(rows.first);
            db.execute('UPDATE collections SET editing_locked=1 WHERE id=?',
                [track.collectionId]);
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

  Future<void> finishRun(String run) => database.run((db) {
        db.execute('DELETE FROM download_run_additions WHERE run=?', [run]);
      });

  Future<ActivitySummary> summary() => database.run((db) {
        final counts = db.select('''SELECT
      COALESCE(SUM(source_kind!='none' OR manual_url!='' OR queue_added=1),0) AS records,
      COALESCE(SUM(status='downloading'),0) AS active,
      COALESCE(SUM(selected=1 AND status IN ('ready','failed') AND source_kind!='none'
        AND match_status!='review' AND redownload_state!='review' AND NOT(manual_url!='' AND manual_mode='extractAudio')),0) AS queued
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
          throw ArgumentError('Limite de 10.000 itens por ação.');
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
        if (ids != null && (ids.isEmpty || ids.length > 10000)) return null;
        final selection = ids == null
            ? 'selected=1'
            : 'id IN (${List.filled(ids.length, '?').join(',')})';
        final rows = db.select(
            '''SELECT * FROM tracks WHERE id>? AND queue_hidden=0 AND $selection
      AND source_kind!='none' AND match_status!='review'
      AND (source_kind!='youtube' OR source_authorization IN ('manualLink','approvedVideo'))
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

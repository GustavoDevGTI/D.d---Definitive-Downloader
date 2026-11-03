import '../../core/storage/database.dart';
import 'package:sqlite3/sqlite3.dart';
import '../library/domain/models.dart';
import 'music_link.dart';

/// Appends occurrences and active-run membership in one short transaction.
class MusicLinkRepository {
  const MusicLinkRepository(this.database);
  final AppDatabase database;

  Future<List<int>> append(int collectionId, List<ResolvedMusicLink> links,
          {String? run}) =>
      database.run((db) {
        if (links.isEmpty || links.length > 20 || (run?.length ?? 0) > 100) {
          throw ArgumentError('Lote inválido.');
        }
        db.execute('BEGIN IMMEDIATE');
        try {
          if (db.select('SELECT id FROM collections WHERE id=?',
              [collectionId]).isEmpty) {
            throw const FormatException('A coleção não está disponível.');
          }
          final size = db.select(
              'SELECT COUNT(*) AS n,COALESCE(MAX(position),0) AS last FROM tracks WHERE collection_id=?',
              [collectionId]).first;
          if ((size['n'] as int) + links.length > 10000) {
            throw const FormatException('Limite de 10.000 faixas por coleção.');
          }
          var position = size['last'] as int;
          final ids = <int>[];
          for (final entry in links) {
            final draft = entry.draft, source = entry.source;
            if (entry.alternatives.length > 24 ||
                draft.title.trim().isEmpty ||
                draft.title.length > 400 ||
                (source != null &&
                    !source.isFullRecording &&
                    !(entry.pinned && source.kind == SourceKind.youtube))) {
              throw const FormatException('Metadados ou fonte inválidos.');
            }
            final kind = source?.kind ?? draft.sourceKind;
            final url = source?.pageUrl ?? draft.mediaUrl;
            if (entry.ready && (kind == SourceKind.none || url.isEmpty)) {
              throw const FormatException('A fonte ainda não está pronta.');
            }
            db.execute(
                '''INSERT INTO tracks(collection_id,position,title,artist,album,
              duration_ms,isrc,cover_url,source_url,media_url,source_kind,status,selected,
              explicit,match_status,manual_url,manual_mode,queue_added,
              resolved_title,resolved_artist,resolved_album,resolved_duration_ms,resolved_cover_url,error)
              VALUES(?,?,?,?,?,?,?,?,?,?,?,?,1,?,?,?,'originalAudio',1,?,?,?,?,?,?)''',
                [
                  collectionId,
                  ++position,
                  draft.title,
                  draft.artist,
                  draft.album,
                  draft.durationMs,
                  draft.isrc,
                  draft.coverUrl,
                  entry.link.url,
                  url,
                  kind.name,
                  entry.ready ? 'ready' : 'pending',
                  draft.explicit == null ? null : (draft.explicit! ? 1 : 0),
                  entry.pinned
                      ? 'manual'
                      : source != null
                          ? 'confirmed'
                          : entry.alternatives.isEmpty
                              ? 'pending'
                              : 'review',
                  entry.pinned ? entry.link.url : '',
                  source?.title ?? '',
                  source?.artist ?? '',
                  source?.album ?? '',
                  source?.durationMs,
                  source?.coverUrl ?? '',
                  !entry.ready && entry.pinned
                      ? 'Fonte aguardando conexão ou suporte de download nesta plataforma.'
                      : '',
                ]);
            final id = db.lastInsertRowId;
            ids.add(id);
            db.execute(
                'UPDATE tracks SET recording_type=?,source_authorization=? WHERE id=?',
                [
                  source?.recordingType ?? '',
                  entry.pinned && source?.kind == SourceKind.youtube
                      ? 'manualLink'
                      : 'catalog',
                  id
                ]);
            for (var i = 0; i < entry.alternatives.length; i++) {
              final c = entry.alternatives[i];
              db.execute(
                  'INSERT INTO music_candidates VALUES(?,?,?,?,?,?,?,?,?,?,?,?)',
                  [
                    id,
                    i,
                    c.kind.name,
                    c.title,
                    c.artist,
                    c.album,
                    c.durationMs,
                    c.pageUrl,
                    c.coverUrl,
                    c.isrc,
                    c.recordingType,
                    c.explicit == null ? null : (c.explicit! ? 1 : 0),
                  ]);
            }
            if (run != null) {
              db.execute(
                  'INSERT INTO download_run_additions(run,track_id) VALUES(?,?)',
                  [run, id]);
            }
          }
          db.execute('COMMIT');
          return ids;
        } catch (_) {
          db.execute('ROLLBACK');
          rethrow;
        }
      });
  // Called inside a short transaction. Manual source edits preserve requested metadata.
  static void replaceSource(Database db, int id, ResolvedMusicLink entry,
      {bool replaceRequested = false}) {
    final c = entry.source, d = entry.draft;
    if (entry.alternatives.length > 24 ||
        (c != null &&
            !c.isFullRecording &&
            !(entry.pinned && c.kind == SourceKind.youtube))) {
      throw const FormatException('Fonte não confirmada.');
    }
    if (replaceRequested) {
      db.execute(
          'UPDATE tracks SET title=?,artist=?,album=?,duration_ms=?,isrc=?,cover_url=?,source_url=?,explicit=? WHERE id=?',
          [
            d.title,
            d.artist,
            d.album,
            d.durationMs,
            d.isrc,
            d.coverUrl,
            entry.link.url,
            d.explicit == null
                ? null
                : d.explicit!
                    ? 1
                    : 0,
            id
          ]);
    }
    db.execute(
        "UPDATE tracks SET media_url=?,source_kind=?,status=?,match_status=?,manual_url=?,manual_mode='originalAudio',resolved_title=?,resolved_artist=?,resolved_album=?,resolved_duration_ms=?,resolved_cover_url=?,recording_type=?,source_authorization=?,queue_hidden=0,error='' WHERE id=?",
        [
          c?.pageUrl ?? d.mediaUrl,
          (c?.kind ?? d.sourceKind).name,
          entry.ready ? 'ready' : 'pending',
          entry.pinned
              ? 'manual'
              : c != null
                  ? 'confirmed'
                  : entry.alternatives.isNotEmpty
                      ? 'review'
                      : 'pending',
          entry.pinned ? entry.link.url : '',
          c?.title ?? '',
          c?.artist ?? '',
          c?.album ?? '',
          c?.durationMs,
          c?.coverUrl ?? '',
          c?.recordingType ?? '',
          entry.pinned && c?.kind == SourceKind.youtube
              ? 'manualLink'
              : 'catalog',
          id
        ]);
    db.execute('DELETE FROM music_candidates WHERE track_id=?', [id]);
    for (var i = 0; i < entry.alternatives.length; i++) {
      final a = entry.alternatives[i];
      db.execute(
          'INSERT INTO music_candidates VALUES(?,?,?,?,?,?,?,?,?,?,?,?)', [
        id,
        i,
        a.kind.name,
        a.title,
        a.artist,
        a.album,
        a.durationMs,
        a.pageUrl,
        a.coverUrl,
        a.isrc,
        a.recordingType,
        a.explicit == null
            ? null
            : a.explicit!
                ? 1
                : 0
      ]);
    }
  }

  Future<void> setSource(int id, ResolvedMusicLink entry) => database.run((db) {
        db.execute('BEGIN IMMEDIATE');
        try {
          final rows = db.select('SELECT status FROM tracks WHERE id=?', [id]);
          if (rows.isEmpty ||
              ['downloading', 'completed'].contains(rows.first['status'])) {
            throw const FormatException(
                'Não é possível trocar a fonte de uma faixa em transferência ou concluída.');
          }
          replaceSource(db, id, entry);
          db.execute('COMMIT');
        } catch (_) {
          db.execute('ROLLBACK');
          rethrow;
        }
      });
}

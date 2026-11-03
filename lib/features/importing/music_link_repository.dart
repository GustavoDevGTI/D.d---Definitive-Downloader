import '../../core/storage/database.dart';
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
            if (entry.alternatives.length > 16 ||
                draft.title.trim().isEmpty ||
                draft.title.length > 400 ||
                (source != null && !source.isFullRecording)) {
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
}

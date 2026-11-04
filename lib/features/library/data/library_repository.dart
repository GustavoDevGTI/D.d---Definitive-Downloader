import '../../../core/storage/database.dart';
import '../../../core/network/bounded_http.dart';
import 'package:path/path.dart' as p;
import '../domain/models.dart';
import '../domain/track_listing.dart';
import 'track_listing_query.dart';

class LibraryRepository {
  const LibraryRepository(this.database);
  final AppDatabase database;

  Future<List<Collection>> collections({int offset = 0}) =>
      database.run((db) => db
          .select('''
    SELECT c.*, COUNT(t.id) AS total,
      COALESCE(SUM(CASE WHEN t.status='completed' THEN 1 ELSE 0 END),0) AS completed
    FROM (SELECT * FROM collections ORDER BY id DESC LIMIT 30 OFFSET ?) c
      LEFT JOIN tracks t ON t.collection_id=c.id
    GROUP BY c.id ORDER BY c.id DESC''', [offset])
          .map(readCollection)
          .toList());

  static Collection readCollection(Map<String, Object?> r) => Collection(
      id: r['id'] as int,
      name: r['name'] as String,
      source: r['source'] as String,
      sourceUrl: r['source_url'] as String,
      trackCount: r['total'] as int,
      completedCount: r['completed'] as int,
      isPartial: r['partial'] == 1,
      editingLocked: r['editing_locked'] == 1,
      groupId: r['group_id'] as int?,
      storageName: r['storage_name'] as String? ?? '',
      coverPath: r['cover_path'] as String? ?? '');

  Future<int> importCollection(ImportedCollection collection) async {
    final id = await _createCollection(
        collection.name, collection.source, collection.sourceUrl);
    try {
      var position = 0;
      var batch = <TrackDraft>[];
      await for (final track in collection.tracks) {
        if (position + batch.length >= 10000) {
          throw const FormatException('Limite de 10.000 faixas por coleção.');
        }
        batch.add(track);
        if (batch.length == 100) {
          await _insertBatch(id, position, batch);
          position += batch.length;
          batch = [];
        }
      }
      if (batch.isNotEmpty) {
        await _insertBatch(id, position, batch);
        position += batch.length;
      }
      if (position == 0) {
        throw const FormatException('Nenhuma faixa encontrada.');
      }
      await _finishCollection(id, collection.isPartial);
      return id;
    } catch (_) {
      await _deleteCollection(id);
      rethrow;
    }
  }

  // Streams stay in the importer; the database isolate receives scalar metadata.
  Future<int> _createCollection(String name, String source, String sourceUrl) =>
      database.run((db) {
        db.execute(
            'INSERT INTO collections(name,source,source_url,partial,storage_name) VALUES(?,?,?,?,?)',
            [name, source, sourceUrl, 1, name]);
        return db.lastInsertRowId;
      });

  // Until the stream and its completeness checks finish, persisted batches
  // remain explicitly partial, including after a process interruption.
  Future<void> _finishCollection(int id, bool partial) => database.run((db) {
        db.execute('UPDATE collections SET partial=? WHERE id=?',
            [partial ? 1 : 0, id]);
      });

  Future<void> _deleteCollection(int id) => database.run((db) {
        db.execute('DELETE FROM collections WHERE id=?', [id]);
      });

  Future<void> _insertBatch(int id, int start, List<TrackDraft> batch) =>
      database.run((db) {
        db.execute('BEGIN IMMEDIATE');
        final statement = db.prepare(
            '''INSERT INTO tracks(collection_id,position,title,artist,album,
      duration_ms,isrc,cover_url,source_url,media_url,source_kind,status,explicit,match_status) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?)''');
        try {
          for (var i = 0; i < batch.length; i++) {
            final t = batch[i];
            statement.execute([
              id,
              start + i + 1,
              t.title,
              t.artist,
              t.album,
              t.durationMs,
              t.isrc,
              t.coverUrl,
              t.sourceUrl,
              t.mediaUrl,
              t.sourceKind.name,
              t.sourceKind == SourceKind.none ? 'pending' : 'ready',
              t.explicit == null ? null : (t.explicit! ? 1 : 0),
              t.sourceKind == SourceKind.none ? 'pending' : 'confirmed'
            ]);
          }
          db.execute('COMMIT');
        } catch (_) {
          db.execute('ROLLBACK');
          rethrow;
        } finally {
          statement.dispose();
        }
      });

  Future<bool> needsAutomaticMatching(int id) => database.run((db) => db.select(
      "SELECT 1 FROM tracks WHERE collection_id=? AND status='pending' AND match_status='pending' AND source_kind='none' AND manual_url='' AND redownload_state='' LIMIT 1",
      [id]).isNotEmpty);

  Future<TrackPage> page(int id,
          {int offset = 0,
          int limit = 40,
          String filter = '',
          String query = '',
          TrackSort sort = TrackSort.position,
          bool descending = false}) =>
      database.run((db) {
        if (limit < 1 || limit > 100 || offset < 0 || query.length > 400) {
          throw ArgumentError('Página inválida.');
        }
        final listing = TrackListingQuery(db, id, filter, query);
        final total = db
            .select('SELECT COUNT(*) AS n FROM tracks WHERE ${listing.where}',
                listing.args)
            .first['n'] as int;
        final selected = db.select(
            'SELECT COUNT(*) AS n FROM tracks WHERE collection_id=? AND selected=1',
            [id]).first['n'] as int;
        final rows = db.select(
            'SELECT * FROM tracks WHERE ${listing.where} ORDER BY ${TrackListingQuery.order(sort, descending)} LIMIT ? OFFSET ?',
            [...listing.args, limit, offset]);
        final filteredSelected = db
            .select(
                'SELECT COUNT(*) AS n FROM tracks WHERE ${listing.where} AND selected=1',
                listing.args)
            .first['n'] as int;
        return TrackPage(
            rows.map(readTrack).toList(), total, selected, filteredSelected);
      });

  Future<void> select(int id, bool value) => database.run((db) {
        db.execute(
            'UPDATE tracks SET selected=? WHERE id=?', [value ? 1 : 0, id]);
      });

  Future<void> selectFromClick(int collectionId, int id,
          {required bool extend}) =>
      database.run((db) {
        db.execute('BEGIN IMMEDIATE');
        try {
          if (db.select('SELECT id FROM tracks WHERE id=? AND collection_id=?',
              [id, collectionId]).isEmpty) {
            throw const FormatException('Faixa não encontrada nesta coleção.');
          }
          if (extend) {
            db.execute(
                'UPDATE tracks SET selected=1-selected WHERE id=? AND collection_id=?',
                [id, collectionId]);
          } else {
            db.execute(
                'UPDATE tracks SET selected=CASE WHEN id=? THEN 1 ELSE 0 END WHERE collection_id=? AND (selected=1 OR id=?)',
                [id, collectionId, id]);
          }
          db.execute('COMMIT');
        } catch (_) {
          db.execute('ROLLBACK');
          rethrow;
        }
      });
  Future<void> selectPage(List<int> ids, bool value) => database.run((db) {
        if (ids.isEmpty) return;
        if (ids.length > 100) throw ArgumentError('Seleção deve ser paginada.');
        db.execute(
            'UPDATE tracks SET selected=? WHERE id IN (${List.filled(ids.length, '?').join(',')})',
            [value ? 1 : 0, ...ids]);
      });
  Future<void> linkSource(Track track,
          {required String url,
          required SourceKind kind,
          String title = '',
          String artist = '',
          String album = '',
          int? durationMs,
          String coverUrl = ''}) =>
      database.run((db) {
        db.execute(
            '''UPDATE tracks SET media_url=?,source_kind=?,match_status='confirmed',queue_hidden=0,status=CASE WHEN status='completed' THEN status ELSE 'ready' END,error='',
        resolved_title=?,resolved_artist=?,resolved_album=?,resolved_duration_ms=?,resolved_cover_url=? WHERE id=? AND manual_url='' ''',
            [
              url,
              kind.name,
              title,
              artist,
              album,
              durationMs,
              coverUrl,
              track.id
            ]);
      });
  Future<Track?> nextSelected(int id, {int afterPosition = 0}) =>
      database.run((db) {
        final rows = db.select(
            "SELECT * FROM tracks WHERE collection_id=? AND position>? AND selected=1 AND source_kind!='none' AND match_status!='review' AND redownload_state!='review' AND (source_kind!='youtube' OR source_authorization IN ('manualLink','approvedVideo')) AND NOT(manual_url!='' AND manual_mode='extractAudio') AND status IN ('ready','failed') ORDER BY position LIMIT 1",
            [id, afterPosition]);
        return rows.isEmpty ? null : readTrack(rows.first);
      });
  Future<void> setStatus(int id, TrackStatus status,
          {String error = '', String localPath = ''}) =>
      database.run((db) {
        db.execute('BEGIN IMMEDIATE');
        try {
          db.execute(
              'UPDATE tracks SET status=?,error=?,local_path=CASE WHEN ?=\'\' THEN local_path ELSE ? END,redownload_state=CASE WHEN ?=\'completed\' AND ?!=\'\' THEN \'\' ELSE redownload_state END WHERE id=?',
              [
                status.name,
                error,
                localPath,
                localPath,
                status.name,
                localPath,
                id
              ]);
          if (status == TrackStatus.completed && localPath.isNotEmpty) {
            final row =
                db.select('SELECT * FROM tracks WHERE id=?', [id]).first;
            db.execute('''INSERT INTO download_history
            (track_id,name,local_path,folder,source,duration_ms) VALUES(?,?,?,?,?,?)
            ON CONFLICT(local_path) DO UPDATE SET name=excluded.name,folder=excluded.folder,
              source=excluded.source,duration_ms=excluded.duration_ms,created_at=CURRENT_TIMESTAMP,hidden=0
            WHERE download_history.track_id=excluded.track_id''', [
              id,
              p.basename(localPath),
              localPath,
              p.dirname(localPath),
              row['source_kind'],
              row['resolved_duration_ms'] ?? row['duration_ms']
            ]);
          }
          db.execute('COMMIT');
        } catch (_) {
          db.execute('ROLLBACK');
          rethrow;
        }
      });
  Future<String?> preference(String key) => database.run((db) {
        final rows =
            db.select('SELECT value FROM preferences WHERE key=?', [key]);
        return rows.isEmpty ? null : rows.first['value'] as String;
      });
  Future<void> setPreference(String key, String value) => database.run((db) {
        db.execute(
            'INSERT INTO preferences(key,value) VALUES(?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value',
            [key, value]);
      });
  Future<List<Track>> completedPage(int id, int afterPosition) =>
      database.run((db) => db
          .select(
              "SELECT * FROM tracks WHERE collection_id=? AND status='completed' AND position>? ORDER BY position LIMIT 100",
              [id, afterPosition])
          .map(readTrack)
          .toList());

  static Track readTrack(Map<String, Object?> r) => Track(
      redownloadState: r['redownload_state'] as String? ?? '',
      customTitle: r['custom_title'] as String? ?? '',
      recordingType: r['recording_type'] as String? ?? '',
      sourceAuthorization: SourceAuthorization.values
          .byName(r['source_authorization'] as String? ?? 'catalog'),
      queuePriority: r['queue_priority'] as int? ?? 0,
      id: r['id'] as int,
      collectionId: r['collection_id'] as int,
      position: r['position'] as int,
      title: r['title'] as String,
      artist: r['artist'] as String,
      album: r['album'] as String,
      durationMs: r['duration_ms'] as int?,
      isrc: r['isrc'] as String,
      coverUrl: r['cover_url'] as String,
      sourceUrl: r['source_url'] as String,
      mediaUrl: r['media_url'] as String,
      sourceKind: SourceKind.values.byName(r['source_kind'] as String),
      status: TrackStatus.values.byName(r['status'] as String),
      selected: r['selected'] == 1,
      localPath: r['local_path'] as String,
      error: r['error'] as String,
      resolvedTitle: r['resolved_title'] as String,
      resolvedArtist: r['resolved_artist'] as String,
      resolvedAlbum: r['resolved_album'] as String,
      resolvedDurationMs: r['resolved_duration_ms'] as int?,
      explicit: r['explicit'] == null ? null : r['explicit'] == 1,
      matchStatus: MatchStatus.values.byName(r['match_status'] as String),
      manualUrl: r['manual_url'] as String,
      manualMode: ManualSourceMode.values.byName(r['manual_mode'] as String),
      resolvedCoverUrl: (r['resolved_cover_url'] as String?) ?? '');

  Future<Track?> trackById(int id) => database.run((db) {
        final rows = db.select('SELECT * FROM tracks WHERE id=?', [id]);
        return rows.isEmpty ? null : readTrack(rows.first);
      });

  Future<void> saveCandidates(int id, List<Candidate> candidates) =>
      database.run((db) {
        if (candidates.length > 24) {
          throw ArgumentError('Limite de 24 candidatos por faixa.');
        }
        db.execute('BEGIN IMMEDIATE');
        try {
          db.execute('DELETE FROM music_candidates WHERE track_id=?', [id]);
          for (var i = 0; i < candidates.length; i++) {
            final c = candidates[i];
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
                  c.explicit == null ? null : (c.explicit! ? 1 : 0)
                ]);
          }
          db.execute('COMMIT');
        } catch (_) {
          db.execute('ROLLBACK');
          rethrow;
        }
      });

  Future<List<Candidate>> musicCandidates(int id) => database.run((db) => db
      .select(
          'SELECT * FROM music_candidates WHERE track_id=? ORDER BY ordinal LIMIT 24',
          [
            id
          ])
      .map((r) => Candidate(
          title: r['title'] as String,
          artist: r['artist'] as String,
          album: r['album'] as String,
          durationMs: r['duration_ms'] as int,
          pageUrl: r['page_url'] as String,
          previewUrl: '',
          coverUrl: r['cover_url'] as String,
          isrc: r['isrc'] as String,
          kind: SourceKind.values.byName(r['kind'] as String),
          recordingType: r['recording_type'] as String,
          explicit: r['explicit'] == null ? null : r['explicit'] == 1))
      .toList());

  Future<void> chooseMusicSource(Track track, Candidate candidate,
          {bool approveVideo = false,
          bool forFallback = false,
          bool userSelected = false}) =>
      database.run((db) {
        if (!candidate.isFullRecording &&
            !(approveVideo && candidate.isVideoRecording)) {
          throw const FormatException('Esta versão exige aprovação explícita.');
        }
        db.execute('BEGIN IMMEDIATE');
        try {
          final rows = db.select(
              'SELECT status,manual_url,source_kind,redownload_state FROM tracks WHERE id=?',
              [track.id]);
          final replacement =
              rows.isNotEmpty && rows.first['redownload_state'] != '';
          if (replacement && (!userSelected || forFallback)) {
            throw const FormatException(
                'Escolha a fonte na conferência para baixar novamente.');
          }
          if (rows.isNotEmpty &&
              rows.first['manual_url'] != '' &&
              !replacement) {
            db.execute('COMMIT');
            return;
          }
          if (rows.isEmpty ||
              (rows.first['status'] == 'completed' ||
                  (rows.first['status'] == 'downloading' &&
                      !(forFallback &&
                          candidate.kind == SourceKind.youtubeMusic &&
                          rows.first['source_kind'] == 'deezerFull')))) {
            throw const FormatException(
                'Esta ocorrência não permite alterar a fonte agora.');
          }
          if (candidate.isVideoRecording &&
              db.select(
                  'SELECT 1 FROM music_candidates WHERE track_id=? AND kind=? AND page_url=? AND recording_type=? AND duration_ms=? AND title=? AND artist=?',
                  [
                    track.id,
                    candidate.kind.name,
                    candidate.pageUrl,
                    candidate.recordingType,
                    candidate.durationMs,
                    candidate.title,
                    candidate.artist
                  ]).isEmpty) {
            throw const FormatException(
                'Pesquise novamente para aprovar esta versão.');
          }
          db.execute(
              "UPDATE tracks SET media_url=?,source_kind=?,match_status='confirmed',queue_hidden=0,status=CASE WHEN status='downloading' THEN status ELSE 'ready' END,error='',resolved_title=?,resolved_artist=?,resolved_album=?,resolved_duration_ms=?,resolved_cover_url=?,recording_type=?,source_authorization=? WHERE id=?",
              [
                candidate.pageUrl,
                candidate.kind.name,
                candidate.title,
                candidate.artist,
                candidate.album,
                candidate.durationMs,
                candidate.coverUrl,
                candidate.recordingType,
                candidate.isVideoRecording ? 'approvedVideo' : 'catalog',
                track.id
              ]);
          if (replacement) {
            db.execute(
                "UPDATE tracks SET redownload_state='approved',manual_url=?,manual_mode='originalAudio' WHERE id=?",
                [candidate.pageUrl, track.id]);
          }
          db.execute('COMMIT');
        } catch (_) {
          db.execute('ROLLBACK');
          rethrow;
        }
      });

  Future<void> setManualSource(
      int id, String value, ManualSourceMode mode) async {
    var uri = Uri.parse(value.trim());
    validateHttpUrl(uri);
    if (['www.youtube.com', 'youtube.com', 'music.youtube.com']
            .contains(uri.host) &&
        uri.path == '/watch' &&
        RegExp(r'^[a-zA-Z0-9_-]{11}$')
            .hasMatch(uri.queryParameters['v'] ?? '')) {
      uri = Uri.https(uri.host, '/watch', {'v': uri.queryParameters['v']!});
    } else if (uri.hasQuery || uri.hasFragment) {
      throw const FormatException(
          'Use um link público estável, sem tokens, parâmetros ou fragmentos.');
    }
    if (uri.toString().length > 4096) {
      throw const FormatException('Link muito longo.');
    }
    await database.run((db) {
      db.execute(
          '''UPDATE tracks SET manual_url=?,manual_mode=?,match_status='manual',queue_hidden=0,
        media_url=?,source_kind=?,resolved_title='',resolved_artist='',resolved_album='',resolved_duration_ms=NULL,
        resolved_cover_url='',error='',status=CASE WHEN status='completed' THEN status WHEN ?='originalAudio' THEN 'ready' ELSE 'pending' END
        WHERE id=? AND status NOT IN ('downloading','completed') ''',
          [
            uri.toString(),
            mode.name,
            mode == ManualSourceMode.originalAudio ? uri.toString() : '',
            mode == ManualSourceMode.originalAudio ? 'directMp3' : 'none',
            mode.name,
            id
          ]);
      db.execute(
          "UPDATE tracks SET redownload_state=? WHERE id=? AND redownload_state!='' AND status NOT IN ('downloading','completed')",
          [mode == ManualSourceMode.originalAudio ? 'approved' : 'review', id]);
    });
  }

  Future<void> removeManualSource(int id) => database.run((db) {
        db.execute(
            '''UPDATE tracks SET manual_url='',manual_mode='originalAudio',match_status='pending',
      redownload_state=CASE WHEN redownload_state!='' THEN 'review' ELSE '' END,
      media_url='',source_kind='none',resolved_title='',resolved_artist='',resolved_album='',resolved_duration_ms=NULL,
      resolved_cover_url='',error='',status=CASE WHEN status='completed' THEN status ELSE 'pending' END WHERE id=? AND status NOT IN ('downloading','completed') ''',
            [id]);
      });

  Future<void> markForReview(int id) => database.run((db) {
        db.execute(
            "UPDATE tracks SET match_status='review',redownload_state=CASE WHEN redownload_state!='' THEN 'review' ELSE '' END WHERE id=? AND status!='downloading'",
            [id]);
      });

  Future<void> confirmSource(int id) => database.run((db) {
        db.execute(
            "UPDATE tracks SET match_status='confirmed' WHERE id=? AND source_kind!='none' AND manual_url='' AND status!='downloading'",
            [id]);
      });

  Future<Collection?> collectionById(int id) => database.run((db) {
        final rows = db.select('''SELECT c.*, COUNT(t.id) AS total,
      COALESCE(SUM(t.status='completed'),0) AS completed FROM collections c
      LEFT JOIN tracks t ON t.collection_id=c.id WHERE c.id=? GROUP BY c.id''',
            [id]);
        if (rows.isEmpty) return null;
        return readCollection(rows.first);
      });

  Future<void> selectCollection(int id, bool value,
          {String query = '', String filter = ''}) =>
      database.run((db) {
        final listing = TrackListingQuery(db, id, filter, query);
        db.execute('UPDATE tracks SET selected=? WHERE ${listing.where}',
            [value ? 1 : 0, ...listing.args]);
      });

  Future<void> recordMusicAttempt(int id, SourceKind provider,
          {required bool succeeded, String message = ''}) =>
      database.run((db) {
        if (provider != SourceKind.deezerFull &&
            provider != SourceKind.youtubeMusic &&
            provider != SourceKind.youtube) {
          return;
        }
        if (message.length > 1000) message = message.substring(0, 1000);
        db.execute(
            '''INSERT INTO music_source_attempts(track_id,provider,succeeded,message)
          VALUES(?,?,?,?) ON CONFLICT(track_id,provider) DO UPDATE SET
          succeeded=excluded.succeeded,message=excluded.message,updated_at=CURRENT_TIMESTAMP''',
            [id, provider.name, succeeded ? 1 : 0, message]);
      });
}

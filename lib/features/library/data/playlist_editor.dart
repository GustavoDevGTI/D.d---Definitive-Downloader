import '../../../core/storage/database.dart';
import '../../importing/music_link.dart';
import '../../importing/music_link_repository.dart';
import '../domain/track_order.dart';

class PlaylistEditor {
  const PlaylistEditor(this.database);
  final AppDatabase database;

  /// Reorders occurrences, including a selection spanning several pages.
  /// IDs and metadata stay intact; only the contiguous playlist positions change.
  Future<int> move(int collectionId, int trackId,
          {required int targetId,
          required bool after,
          bool selectedGroup = false}) =>
      database.run((db) {
        db.execute('BEGIN IMMEDIATE');
        try {
          final owner = db.select(
              'SELECT editing_locked FROM collections WHERE id=?',
              [collectionId]);
          if (owner.isEmpty) {
            throw const FormatException('Coleção não encontrada.');
          }
          // Only order, selection and transfer guards of this bounded collection
          // are loaded, never the library or full track metadata.
          final rows = db.select(
              'SELECT id,position,selected,queue_run,status,local_path,error FROM tracks WHERE collection_id=? ORDER BY position LIMIT 10001',
              [collectionId]);
          if (rows.length > 10000) {
            throw const FormatException('Limite de 10.000 faixas por coleção.');
          }
          final dragged = rows.where((r) => r['id'] == trackId).firstOrNull;
          if (dragged == null || !rows.any((r) => r['id'] == targetId)) {
            throw const FormatException(
                'A faixa ou o destino não pertence mais a esta coleção.');
          }
          if (selectedGroup && dragged['selected'] != 1) {
            throw const FormatException('A seleção mudou. Arraste novamente.');
          }
          bool locked(Map<String, Object?> row) => trackOrderLocked(
              status: row['status'] as String,
              run: row['queue_run'] as String,
              localPath: row['local_path'] as String,
              error: row['error'] as String);
          if (locked(dragged) ||
              locked(rows.firstWhere((r) => r['id'] == targetId))) {
            throw const FormatException(
                'Só é possível reordenar faixas que ainda não iniciaram o download.');
          }
          final moving = rows
              .where((r) =>
                  selectedGroup ? r['selected'] == 1 : r['id'] == trackId)
              .map((r) => r['id'] as int)
              .toList();
          final movingSet = moving.toSet();
          if (rows.any((r) => movingSet.contains(r['id']) && locked(r))) {
            throw const FormatException(
                'A seleção inclui uma faixa que já iniciou o download.');
          }
          if (movingSet.contains(targetId)) {
            db.execute('COMMIT');
            return dragged['position'] as int;
          }
          final remaining = rows
              .map((r) => r['id'] as int)
              .where((id) => !movingSet.contains(id))
              .toList();
          final insertion = remaining.indexOf(targetId) + (after ? 1 : 0);
          final order = [
            ...remaining.take(insertion),
            ...moving,
            ...remaining.skip(insertion)
          ];
          final positions = {
            for (final r in rows) r['id'] as int: r['position'] as int
          };
          final newPositions = {
            for (var i = 0; i < order.length; i++) order[i]: i + 1
          };
          for (final row in rows.where(locked)) {
            if (newPositions[row['id']] != row['position']) {
              throw const FormatException(
                  'O movimento alteraria a posição de uma faixa já iniciada.');
            }
          }
          // Extras keep their global append slots; reorder only this collection's
          // occurrences within those slots. Other collections keep their places.
          final additions = db.select('''SELECT a.run,a.ordinal,a.track_id
            FROM download_run_additions a JOIN tracks t ON t.id=a.track_id
            WHERE t.collection_id=? ORDER BY a.ordinal LIMIT 10001''',
              [collectionId]);
          if (additions.length > 10000) {
            throw const FormatException('Há faixas demais nesta execução.');
          }
          final runs = <String, List<Map<String, Object?>>>{};
          for (final a in additions) {
            (runs[a['run'] as String] ??= []).add(a);
          }
          for (final entries in runs.values) {
            final addedIds = entries.map((a) => a['track_id'] as int).toSet();
            final firstExtra = addedIds
                .map((id) => newPositions[id]!)
                .reduce((a, b) => a < b ? a : b);
            if (rows.any((r) =>
                !addedIds.contains(r['id']) &&
                newPositions[r['id']]! > firstExtra)) {
              throw const FormatException(
                  'Durante a execução, as faixas extras permanecem após as originais.');
            }
            final reordered = [...addedIds]
              ..sort((a, b) => newPositions[a]!.compareTo(newPositions[b]!));
            for (final a in entries) {
              db.execute(
                  'UPDATE download_run_additions SET ordinal=-ordinal WHERE ordinal=?',
                  [a['ordinal']]);
            }
            for (var i = 0; i < entries.length; i++) {
              db.execute(
                  'UPDATE download_run_additions SET ordinal=? WHERE run=? AND track_id=?',
                  [entries[i]['ordinal'], entries[i]['run'], reordered[i]]);
            }
          }
          final changed = [
            for (var i = 0; i < order.length; i++)
              if (positions[order[i]] != i + 1) order[i]
          ];
          final stage = db.prepare(
              'UPDATE tracks SET position=-position WHERE id=? AND collection_id=?');
          try {
            for (final id in changed) {
              stage.execute([id, collectionId]);
            }
          } finally {
            stage.dispose();
          }
          final update = db.prepare(
              'UPDATE tracks SET position=? WHERE id=? AND collection_id=?');
          try {
            for (var i = 0; i < order.length; i++) {
              if (positions[order[i]] != i + 1) {
                update.execute([i + 1, order[i], collectionId]);
              }
            }
          } finally {
            update.dispose();
          }
          db.execute('COMMIT');
          return order.indexOf(trackId) + 1;
        } catch (_) {
          db.execute('ROLLBACK');
          rethrow;
        }
      });
  Future<void> edit(int trackId,
          {required String name,
          required int position,
          ResolvedMusicLink? replacement}) =>
      database.run((db) {
        final title = name.trim();
        if (title.isEmpty ||
            title.length > 400 ||
            title.contains(RegExp(r'[\x00-\x1f]'))) {
          throw const FormatException('Use um nome de 1 a 400 caracteres.');
        }
        db.execute('BEGIN IMMEDIATE');
        try {
          final rows = db.select(
              'SELECT t.*,c.editing_locked FROM tracks t JOIN collections c ON c.id=t.collection_id WHERE t.id=?',
              [trackId]);
          if (rows.isEmpty) {
            throw const FormatException('Faixa não encontrada.');
          }
          final row = rows.first;
          if (row['editing_locked'] == 1 ||
              ['downloading', 'completed'].contains(row['status'])) {
            throw const FormatException(
                'Nomes e ordem ficam bloqueados após o início dos downloads.');
          }
          final owner = row['collection_id'] as int,
              before = row['position'] as int;
          final count = db.select(
              'SELECT COUNT(*) AS n FROM tracks WHERE collection_id=?',
              [owner]).first['n'] as int;
          if (position < 1 || position > count) {
            throw FormatException('Use uma posição entre 1 e $count.');
          }
          if (before != position) {
            // Temporary negatives avoid UNIQUE collisions in either direction.
            db.execute('UPDATE tracks SET position=0 WHERE id=?', [trackId]);
            final lower = before < position ? before + 1 : position,
                upper = before < position ? position : before - 1;
            db.execute(
                'UPDATE tracks SET position=-position WHERE collection_id=? AND position BETWEEN ? AND ?',
                [owner, lower, upper]);
            db.execute(
                'UPDATE tracks SET position=-position+? WHERE collection_id=? AND position<0',
                [before < position ? -1 : 1, owner]);
            db.execute(
                'UPDATE tracks SET position=? WHERE id=?', [position, trackId]);
          }
          if (replacement != null) {
            MusicLinkRepository.replaceSource(db, trackId, replacement,
                replaceRequested: true);
          }
          final requested = replacement?.draft.title ?? row['title'] as String;
          db.execute('UPDATE tracks SET custom_title=? WHERE id=?',
              [title == requested ? '' : title, trackId]);
          db.execute('COMMIT');
        } catch (_) {
          db.execute('ROLLBACK');
          rethrow;
        }
      });
}

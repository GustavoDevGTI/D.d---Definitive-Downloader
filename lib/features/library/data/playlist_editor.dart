import '../../../core/storage/database.dart';
import '../../importing/music_link.dart';
import '../../importing/music_link_repository.dart';
import '../domain/track_order.dart';
import '../../downloads/run_order.dart';

class PlaylistEditor {
  const PlaylistEditor(this.database);
  final AppDatabase database;

  /// Reorders occurrences, including a selection spanning several pages.
  /// IDs and metadata stay intact; reorder within existing slots, including gaps
  /// left by explicit removal, without shifting already published media.
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
              'SELECT id,position,selected,status,local_path FROM tracks WHERE collection_id=? ORDER BY position LIMIT 10001',
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
              localPath: row['local_path'] as String);
          if (locked(dragged) ||
              locked(rows.firstWhere((r) => r['id'] == targetId))) {
            throw const FormatException(
                'Faixas concluídas ou em andamento mantêm sua posição.');
          }
          final moving = rows
              .where((r) =>
                  selectedGroup ? r['selected'] == 1 : r['id'] == trackId)
              .map((r) => r['id'] as int)
              .toList();
          final movingSet = moving.toSet();
          if (rows.any((r) => movingSet.contains(r['id']) && locked(r))) {
            throw const FormatException(
                'A seleção inclui uma faixa concluída ou em andamento.');
          }
          if (movingSet.contains(targetId)) {
            db.execute('COMMIT');
            return dragged['position'] as int;
          }
          final remaining = rows
              .where((r) => !locked(r))
              .map((r) => r['id'] as int)
              .where((id) => !movingSet.contains(id))
              .toList();
          final insertion = remaining.indexOf(targetId) + (after ? 1 : 0);
          final freeOrder = [
            ...remaining.take(insertion),
            ...moving,
            ...remaining.skip(insertion)
          ];
          var freeIndex = 0;
          final order = [
            for (final row in rows)
              if (locked(row)) row['id'] as int else freeOrder[freeIndex++]
          ];
          final positions = {
            for (final r in rows) r['id'] as int: r['position'] as int
          };
          final slots = [for (final row in rows) row['position'] as int];
          final newPositions = {
            for (var i = 0; i < order.length; i++) order[i]: slots[i]
          };
          for (final row in rows.where(locked)) {
            if (newPositions[row['id']] != row['position']) {
              throw const FormatException(
                  'O movimento alteraria a posição de uma faixa já iniciada.');
            }
          }
          // The execution snapshot includes originals and extras. Reorder only
          // this collection's slots, preserving every other collection's place.
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
            final reordered = [...addedIds]
              ..sort((a, b) => newPositions[a]!.compareTo(newPositions[b]!));
            reassignRunSlots(db, entries, reordered);
          }
          final changed = [
            for (var i = 0; i < order.length; i++)
              if (positions[order[i]] != slots[i]) order[i]
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
              if (positions[order[i]] != slots[i]) {
                update.execute([slots[i], order[i], collectionId]);
              }
            }
          } finally {
            update.dispose();
          }
          db.execute('COMMIT');
          return newPositions[trackId]!;
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
          final last = db.select(
              'SELECT MAX(position) AS last FROM tracks WHERE collection_id=?',
              [owner]).first['last'] as int;
          if (position < 1 || position > last) {
            throw FormatException('Use uma posição entre 1 e $last.');
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

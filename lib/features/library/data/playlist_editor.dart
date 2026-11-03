import '../../../core/storage/database.dart';
import '../../importing/music_link.dart';
import '../../importing/music_link_repository.dart';

class PlaylistEditor {
  const PlaylistEditor(this.database);
  final AppDatabase database;
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

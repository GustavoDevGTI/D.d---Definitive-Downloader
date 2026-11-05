import '../../../core/storage/database.dart';
import '../domain/models.dart';
import '../domain/track_listing.dart';
import 'library_repository.dart';
import 'track_listing_query.dart';

class ContinuousTrackSnapshot {
  const ContinuousTrackSnapshot(this.revision, this.ids, this.existingIds,
      this.changed, this.selected, this.filteredSelected);
  final int revision, selected, filteredSelected;
  final List<int> ids;
  final Set<int> existingIds;
  final List<Track> changed;
}

/// One bounded playlist, with metadata deltas and globally ordered/filterable IDs.
class ContinuousTrackRepository {
  const ContinuousTrackRepository(this.database);
  final AppDatabase database;
  Future<ContinuousTrackSnapshot> read(int collectionId,
          {required int since,
          String query = '',
          String filter = '',
          TrackSort sort = TrackSort.position,
          bool descending = false}) =>
      database.run((db) {
        if (query.length > 400 || since < -1) {
          throw ArgumentError('Consulta inválida.');
        }
        db.execute('BEGIN');
        try {
          final revision = db
              .select('SELECT revision FROM library_revision WHERE id=1')
              .single['revision'] as int;
          final listing = TrackListingQuery(db, collectionId, filter, query);
          final ids = db
              .select(
                  'SELECT id FROM tracks WHERE ${listing.where} ORDER BY ${TrackListingQuery.order(sort, descending)} LIMIT 10001',
                  listing.args)
              .map((r) => r['id'] as int)
              .toList();
          final existing = query.trim().isEmpty && filter.isEmpty
              ? ids.toSet()
              : db
                  .select(
                      'SELECT id FROM tracks WHERE collection_id=? LIMIT 10001',
                      [collectionId])
                  .map((r) => r['id'] as int)
                  .toSet();
          if (existing.length > 10000) {
            throw const FormatException('Limite de 10.000 faixas por coleção.');
          }
          final changed = db
              .select(
                  'SELECT * FROM tracks WHERE collection_id=? AND list_revision>? LIMIT 10001',
                  [collectionId, since])
              .map(LibraryRepository.readTrack)
              .toList();
          final selected = db.select(
              'SELECT COUNT(*) AS n FROM tracks WHERE collection_id=? AND selected=1',
              [collectionId]).single['n'] as int;
          final filtered = db
              .select(
                  'SELECT COUNT(*) AS n FROM tracks WHERE ${listing.where} AND selected=1',
                  listing.args)
              .single['n'] as int;
          db.execute('COMMIT');
          return ContinuousTrackSnapshot(
              revision, ids, existing, changed, selected, filtered);
        } catch (_) {
          db.execute('ROLLBACK');
          rethrow;
        }
      });
}

import '../../../core/platform/platform_services.dart';
import '../../../core/storage/database.dart';
import '../../library/data/library_repository.dart';
import '../../library/domain/models.dart';
import '../domain/workspace_models.dart';
import '../domain/download_columns.dart';
import 'download_listing_query.dart';

class DownloadListingSnapshot {
  const DownloadListingSnapshot(
      this.revision, this.ids, this.existing, this.changed, this.colors);
  final int revision;
  final List<int> ids;
  final Set<int> existing;
  final List<DownloadEntry> changed;
  final List<DownloadPlaylistColor> colors;
}

class ContinuousDownloadRepository {
  const ContinuousDownloadRepository(this.database);
  final AppDatabase database;
  Future<DownloadListingSnapshot> read(ContentCategory category,
          {required int since,
          DownloadFilter filter = DownloadFilter.all,
          String query = '',
          bool pauseMode = false,
          DownloadSort? sort,
          bool descending = false,
          int? playlistId,
          String outputDirectory = ''}) =>
      database.run((db) {
        if (query.length > 200 || since < -1) {
          throw ArgumentError('Consulta inválida.');
        }
        db.execute('BEGIN');
        try {
          final revision = db
              .select('SELECT revision FROM library_revision WHERE id=1')
              .single['revision'] as int;
          final listing = DownloadListingQuery(db,
              filter: filter,
              query: query,
              pauseMode: pauseMode,
              sort: sort,
              descending: descending,
              playlistId: playlistId,
              outputDirectory: outputDirectory);
          final ids = category == ContentCategory.media ||
                  (filter == DownloadFilter.paused && !pauseMode)
              ? <int>[]
              : db
                  .select(
                      'SELECT t.id ${listing.from} WHERE ${listing.where} ORDER BY ${listing.order} LIMIT 100001',
                      listing.args)
                  .map((r) => r['id'] as int)
                  .toList();
          const eligible = DownloadListingQuery.membership;
          final colors = category == ContentCategory.media
              ? <DownloadPlaylistColor>[]
              : db
                  .select('''
                SELECT c.id,c.name,c.theme_color FROM collections c
                WHERE c.theme_color IS NOT NULL AND EXISTS (
                  SELECT 1 FROM tracks t WHERE t.collection_id=c.id AND $eligible
                ) ORDER BY c.name COLLATE NOCASE,c.id
                ''')
                  .map((row) => (
                        collectionId: row['id'] as int,
                        name: row['name'] as String,
                        rgb: row['theme_color'] as int,
                      ))
                  .toList();
          final existing = category == ContentCategory.media
              ? <int>{}
              : db
                  .select(
                      'SELECT t.id FROM tracks t WHERE $eligible LIMIT 100001')
                  .map((r) => r['id'] as int)
                  .toSet();
          if (existing.length > 100000) {
            throw const FormatException(
                'Limite de 100.000 registros na lista de Downloads.');
          }
          final changed = category == ContentCategory.media
              ? <DownloadEntry>[]
              : db
                  .select(
                      'SELECT t.*,c.name AS collection_name,c.theme_color,h.created_at AS downloaded_at ${listing.from} WHERE $eligible AND t.list_revision>? LIMIT 100001',
                      [
                        since
                      ])
                  .map((r) => DownloadEntry(LibraryRepository.readTrack(r),
                      r['collection_name'] as String,
                      playlistColor: r['theme_color'] as int?,
                      downloadedAt:
                          readDownloadDate(r['downloaded_at'] as String?)))
                  .toList();
          db.execute('COMMIT');
          return DownloadListingSnapshot(
              revision, ids, existing, changed, colors);
        } catch (_) {
          rollbackAfterFailure(db);
          rethrow;
        }
      });

  /// Disk work is bounded to the visible rows and done outside the widget.
  Future<Map<int, int?>> sizes(List<DownloadEntry> visible) async {
    if (visible.length > 100) {
      throw ArgumentError('Janela de leitura inválida.');
    }
    final result = <int, int?>{};
    for (var start = 0; start < visible.length; start += 8) {
      await Future.wait(visible.skip(start).take(8).map((entry) async {
        final t = entry.track;
        if (t.status != TrackStatus.completed || t.localPath.isEmpty) return;
        try {
          result[t.id] = await createPlatformFiles().fileSize(t.localPath);
        } catch (_) {
          result[t.id] = null;
        }
      }));
    }
    return result;
  }
}

DateTime? readDownloadDate(String? value) {
  if (value == null || value.isEmpty) return null;
  final normalized = value.replaceFirst(' ', 'T');
  return DateTime.tryParse(RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(normalized)
      ? normalized
      : '${normalized}Z');
}

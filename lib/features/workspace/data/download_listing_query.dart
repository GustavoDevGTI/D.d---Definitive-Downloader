import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import '../domain/workspace_models.dart';
import '../domain/download_columns.dart';

class DownloadListingQuery {
  DownloadListingQuery(Database db,
      {required DownloadFilter filter,
      required String query,
      required bool pauseMode,
      required DownloadSort? sort,
      required bool descending,
      required String outputDirectory,
      int? playlistId}) {
    final status = switch (filter) {
      DownloadFilter.downloading =>
        pauseMode ? ' AND 0' : " AND t.status='downloading'",
      DownloadFilter.queued => " AND t.status IN ('pending','ready')",
      DownloadFilter.completed => " AND t.status='completed'",
      DownloadFilter.failed => " AND t.status='failed'",
      DownloadFilter.paused => " AND t.status='downloading'",
      _ => '',
    };
    final search = query.trim();
    where =
        "t.queue_hidden=0 AND (t.source_kind!='none' OR t.manual_url!='' OR t.queue_added=1)$status"
        " AND (?='' OR instr(lower(t.title),lower(?))>0 OR instr(lower(t.artist),lower(?))>0"
        " OR instr(lower(t.custom_title),lower(?))>0 OR instr(lower(t.resolved_title),lower(?))>0 OR instr(lower(t.local_path),lower(?))>0"
        " OR instr(lower(c.name),lower(?))>0 OR instr(lower(CASE t.source_kind WHEN 'youtubeMusic' THEN 'YouTube Music' WHEN 'deezerFull' THEN 'Deezer' WHEN 'directMp3' THEN 'MP3 vinculado' ELSE t.source_kind END),lower(?))>0)"
        "${playlistId == null ? '' : ' AND t.collection_id=?'}";
    args = [
      ...List<Object?>.filled(8, search),
      if (playlistId != null) playlistId
    ];
    from = "FROM tracks t JOIN collections c ON c.id=t.collection_id "
        "LEFT JOIN download_history h ON h.local_path=t.local_path AND h.track_id=t.id "
        "AND h.category='music' AND t.status='completed'";
    order = 't.queue_priority DESC,t.collection_id,t.position,t.id';
    if (sort != null) {
      db.createCollation(
          name: 'download_text',
          function: (a, b) =>
              (a ?? '').toLowerCase().compareTo((b ?? '').toLowerCase()));
      db.createFunction(
          functionName: 'download_folder',
          argumentCount: const AllowedArgumentCount(1),
          deterministic: true,
          function: (args) => (args.first as String).isEmpty
              ? outputDirectory
              : p.posix.dirname((args.first as String).replaceAll(r'\', '/')));
      final expression = switch (sort) {
        DownloadSort.name =>
          "(COALESCE(NULLIF(t.custom_title,''),t.title) || ' — ' || COALESCE(NULLIF(t.artist,''),t.resolved_artist)) COLLATE download_text",
        DownloadSort.provider =>
          "CASE t.source_kind WHEN 'none' THEN 'A conferir' WHEN 'localExample' THEN 'Exemplo local' WHEN 'directMp3' THEN 'MP3 vinculado' WHEN 'preview' THEN 'Prévia Deezer' WHEN 'deezerFull' THEN 'Deezer' WHEN 'youtubeMusic' THEN 'YouTube Music' WHEN 'youtube' THEN 'YouTube' ELSE t.source_kind END COLLATE download_text",
        DownloadSort.status =>
          "CASE t.status WHEN 'pending' THEN 0 WHEN 'ready' THEN 1 WHEN 'downloading' THEN 2 WHEN 'completed' THEN 3 WHEN 'failed' THEN 4 ELSE 5 END",
        DownloadSort.downloadedAt => 'julianday(h.created_at)',
        DownloadSort.destination =>
          'download_folder(t.local_path) COLLATE download_text',
        DownloadSort.playlistColor => 'c.theme_color',
      };
      final direction = descending ? 'DESC' : 'ASC';
      order = sort == DownloadSort.downloadedAt
          ? 'CASE WHEN julianday(h.created_at) IS NULL THEN 1 ELSE 0 END ASC,$expression $direction,h.id $direction,t.collection_id,t.position,t.id'
          : '$expression $direction,t.collection_id,t.position,t.id';
    }
  }
  late final String where, from;
  late String order;
  late final List<Object?> args;
}

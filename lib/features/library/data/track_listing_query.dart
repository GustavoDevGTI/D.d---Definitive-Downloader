import 'package:sqlite3/sqlite3.dart';
import '../domain/track_listing.dart';

class TrackListingQuery {
  TrackListingQuery(
      Database db, int collectionId, String filter, String query) {
    db.createFunction(
        functionName: 'track_contains',
        argumentCount: const AllowedArgumentCount(2),
        function: (args) => foldTrackText(args[0] as String)
                .contains(foldTrackText(args[1] as String))
            ? 1
            : 0);
    db.createCollation(
        name: 'track_text',
        function: (a, b) =>
            foldTrackText(a ?? '').compareTo(foldTrackText(b ?? '')));
    where = 'collection_id=?';
    args = [collectionId];
    where += switch (filter) {
      'downloads' => " AND status IN ('ready','downloading','failed')",
      'files' => " AND status='completed'",
      'review' =>
        " AND status!='completed' AND (redownload_state='review' OR match_status IN ('pending','review') OR source_kind='none')",
      'ready' =>
        " AND status IN ('ready','failed') AND redownload_state!='review' AND match_status IN ('confirmed','manual') AND source_kind!='none' AND media_url!='' AND (source_kind!='youtube' OR source_authorization IN ('manualLink','approvedVideo')) AND NOT(manual_url!='' AND manual_mode='extractAudio')",
      _ => '',
    };
    if (query.trim().isNotEmpty) {
      where += " AND track_contains(title||' '||artist||' '||custom_title,?)=1";
      args.add(query.trim());
    }
  }
  late String where;
  late final List<Object?> args;

  static String order(TrackSort sort, bool descending) {
    final direction = descending ? 'DESC' : 'ASC';
    final expression = switch (sort) {
      TrackSort.position => 'position',
      TrackSort.name =>
        "CASE WHEN custom_title='' THEN title ELSE custom_title END COLLATE track_text",
      TrackSort.duration => 'duration_ms',
      TrackSort.correspondence =>
        "CASE WHEN status!='completed' AND (redownload_state='review' OR match_status IN ('pending','review') OR source_kind='none') THEN 0 WHEN status='completed' THEN 3 WHEN match_status='manual' THEN 2 ELSE 1 END",
    };
    final missing = sort == TrackSort.duration
        ? 'CASE WHEN duration_ms IS NULL OR duration_ms<=0 THEN 1 ELSE 0 END,'
        : '';
    return '$missing$expression $direction,position,id';
  }
}

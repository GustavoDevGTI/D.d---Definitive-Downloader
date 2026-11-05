import '../data/continuous_download_repository.dart';
import '../domain/workspace_models.dart';
import '../domain/download_columns.dart';

class ContinuousDownloadListing {
  ContinuousDownloadListing(this.repository);
  final ContinuousDownloadRepository repository;
  final _entries = <int, DownloadEntry>{};
  final _checked = <int, DateTime>{};
  final _checking = <int>{};
  int _revision = -1, _request = 0;
  ContentCategory? _category;
  List<DownloadEntry> selected(Set<int> ids) =>
      ids.map((id) => _entries[id]).whereType<DownloadEntry>().toList();
  Future<DownloadPage?> load(ContentCategory category,
      {DownloadFilter filter = DownloadFilter.all,
      String query = '',
      bool pauseMode = false,
      DownloadSort? sort,
      bool descending = false,
      String outputDirectory = ''}) async {
    final request = ++_request;
    final snapshot = await repository.read(category,
        since: _category == category ? _revision : -1,
        filter: filter,
        query: query,
        pauseMode: pauseMode,
        sort: sort,
        descending: descending,
        outputDirectory: outputDirectory);
    if (request != _request) return null;
    if (_category != category) {
      _entries.clear();
      _checked.clear();
    }
    _entries.removeWhere((id, _) => !snapshot.existing.contains(id));
    _checked.removeWhere((id, _) => !snapshot.existing.contains(id));
    for (final entry in snapshot.changed) {
      final old = _entries[entry.track.id];
      final sameFile = old?.track.localPath == entry.track.localPath &&
          old?.track.status == entry.track.status &&
          old?.downloadedAt == entry.downloadedAt;
      _entries[entry.track.id] = DownloadEntry(
          entry.track, entry.collectionName,
          downloadedAt: entry.downloadedAt,
          fileBytes: sameFile ? old?.fileBytes : null);
      if (!sameFile) _checked.remove(entry.track.id);
    }
    _category = category;
    _revision = snapshot.revision;
    return DownloadPage(
        List.unmodifiable(snapshot.ids.map((id) => _entries[id]!)),
        snapshot.ids.length);
  }

  Future<bool> checkVisible(List<int> ids) async {
    final now = DateTime.now();
    final rows = ids
        .take(100)
        .where((id) =>
            !_checking.contains(id) &&
            (!_checked.containsKey(id) ||
                now.difference(_checked[id]!).inSeconds >= 30))
        .map((id) => _entries[id])
        .whereType<DownloadEntry>()
        .toList();
    if (rows.isEmpty) return false;
    _checking.addAll(rows.map((e) => e.track.id));
    try {
      final sizes = await repository.sizes(rows);
      var changed = false;
      for (final row in rows) {
        final current = _entries[row.track.id];
        if (current == null ||
            current.track.localPath != row.track.localPath ||
            current.track.status != row.track.status ||
            current.downloadedAt != row.downloadedAt) {
          continue;
        }
        _checked[row.track.id] = now;
        if (sizes.containsKey(row.track.id) &&
            current.fileBytes != sizes[row.track.id]) {
          _entries[row.track.id] = DownloadEntry(
              current.track, current.collectionName,
              downloadedAt: current.downloadedAt,
              fileBytes: sizes[row.track.id]);
          changed = true;
        }
      }
      return changed;
    } finally {
      _checking.removeAll(rows.map((e) => e.track.id));
    }
  }

  DownloadPage updated(DownloadPage page) => DownloadPage(
      List.unmodifiable(page.items.map((e) => _entries[e.track.id] ?? e)),
      page.total);
  void clear() {
    _request++;
    _entries.clear();
    _checked.clear();
    _category = null;
    _revision = -1;
  }
}

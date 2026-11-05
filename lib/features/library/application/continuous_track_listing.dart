import '../data/continuous_track_repository.dart';
import '../domain/models.dart';
import '../domain/track_listing.dart';

class ContinuousTrackListing {
  ContinuousTrackListing(this.repository);
  final ContinuousTrackRepository repository;
  final _tracks = <int, Track>{};
  int? _collectionId;
  int _revision = -1, _request = 0;
  Future<TrackPage?> load(int collectionId,
      {String query = '',
      String filter = '',
      TrackSort sort = TrackSort.position,
      bool descending = false}) async {
    final request = ++_request;
    final snapshot = await repository.read(collectionId,
        since: _collectionId == collectionId ? _revision : -1,
        query: query,
        filter: filter,
        sort: sort,
        descending: descending);
    if (request != _request) return null;
    if (_collectionId != collectionId) _tracks.clear();
    _tracks.removeWhere((id, _) => !snapshot.existingIds.contains(id));
    for (final track in snapshot.changed) {
      _tracks[track.id] = track;
    }
    _collectionId = collectionId;
    _revision = snapshot.revision;
    return TrackPage(List.unmodifiable(snapshot.ids.map((id) => _tracks[id]!)),
        snapshot.ids.length, snapshot.selected, snapshot.filteredSelected);
  }

  void clear() {
    _request++;
    _tracks.clear();
    _collectionId = null;
    _revision = -1;
  }
}

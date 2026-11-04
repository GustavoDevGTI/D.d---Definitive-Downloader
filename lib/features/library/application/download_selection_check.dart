import '../../../core/platform/desktop_files.dart';
import '../data/library_repository.dart';
import '../data/redownload_repository.dart';
import '../domain/models.dart';

class DownloadSelectionResult {
  const DownloadSelectionResult({this.reviewId, this.existingId, this.error});
  final int? reviewId, existingId;
  final String? error;
}

class DownloadSelectionCheck {
  const DownloadSelectionCheck(this.repository, this.files);
  final LibraryRepository repository;
  final DesktopFiles files;

  Future<DownloadSelectionResult> check(
      {int? collectionId, List<int>? ids, bool failedOnly = false}) async {
    final recovery = RedownloadRepository(repository.database);
    int? review, existing;
    for (var offset = 0; offset < 10000; offset += 40) {
      final rows = await recovery.selected(
          collectionId: collectionId,
          ids: ids,
          offset: offset,
          failedOnly: failedOnly);
      if (rows.isEmpty) break;
      final available = await Future.wait(rows.map((t) async =>
          t.localPath.isNotEmpty && await files.fileExists(t.localPath)));
      final missing = <Track>[];
      for (var i = 0; i < rows.length; i++) {
        final track = rows[i];
        if (track.redownloadReview) review ??= track.id;
        if (track.status == TrackStatus.completed) {
          if (available[i]) {
            existing ??= track.id;
          } else {
            missing.add(track);
            review ??= track.id;
          }
        } else if (track.redownloadState == 'approved' && available[i]) {
          return DownloadSelectionResult(
              existingId: track.id,
              error:
                  'O arquivo anterior está disponível novamente. Nenhum novo download foi iniciado.');
        }
      }
      if (missing.isNotEmpty) await recovery.request(missing);
      if (rows.length < 40) break;
    }
    return DownloadSelectionResult(reviewId: review, existingId: existing);
  }
}

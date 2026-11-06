import '../../../core/platform/desktop_files.dart';
import '../../../core/platform/media_publication.dart';
import '../data/library_repository.dart';
import '../domain/models.dart';
import '../../downloads/playlist_exporter.dart';
import 'package:path/path.dart' as p;

/// Reconcile only already published work. Never initiate IO to a music source,
/// publish an unfinished cache, approve a review or remove unrelated history.
class MediaPublicationRecovery {
  const MediaPublicationRecovery(this.repository, this.files);
  final LibraryRepository repository;
  final DesktopFiles files;
  Future<String?> recover() async {
    var failed = false;
    final exports = <(int, String)>{};
    try {
      for (final pending in await files.pendingMedia()) {
        try {
          if (pending.trackId < 0) {
            final track = await repository.trackAtPath(pending.path);
            if (track != null && track.sourceKind == SourceKind.localFile) {
              await files.bindImported(pending.path, track.id,
                  track.collectionId, mediaPublicationKey(track));
              exports.add((track.collectionId, p.dirname(pending.path)));
            } else if (await repository.hasMediaHistory(pending.path)) {
              await files.acknowledgeMedia(pending.path);
            } else {
              await files.rollbackImported(pending.path);
            }
            continue;
          }
          final track = await repository.trackById(pending.trackId);
          if (track == null ||
              track.redownloadReview ||
              track.needsReview ||
              mediaPublicationKey(track) != pending.key) {
            continue;
          }
          if (!await files.fileExists(pending.path)) continue;
          if (pending.position != null && pending.position != track.position) {
            failed = true;
            continue;
          }
          if (track.status != TrackStatus.completed ||
              track.localPath != pending.path) {
            await repository.setStatus(track.id, TrackStatus.completed,
                localPath: pending.path);
          }
          await files.acknowledgeMedia(pending.path);
          exports.add((track.collectionId, p.dirname(pending.path)));
        } catch (_) {
          failed = true;
        }
      }
      for (final pending in await files.pendingPublicRemovals()) {
        try {
          final journaled = await repository.database.run((db) => db.select(
              'SELECT track_id FROM music_replacement_files WHERE operation=? AND original=? LIMIT 1',
              [pending.operation, pending.path]).isNotEmpty);
          if (journaled) {
            continue; // The reversible core journal owns this case.
          }
          final track = await repository.trackAtPath(pending.path);
          final retained =
              track != null || await repository.hasMediaHistory(pending.path);
          await files.finishPublicRemoval(
              pending.operation, pending.path, retained);
        } catch (_) {
          failed = true;
        }
      }
      for (final item in exports) {
        try {
          await PlaylistExporter(repository, files: files)
              .export(item.$1, item.$2);
        } catch (_) {
          failed = true;
        }
      }
    } catch (_) {
      failed = true;
    }
    return failed
        ? 'Há publicações ou remoções pendentes na pasta pública. Confira o acesso ao destino; nenhuma fonte será baixada automaticamente.'
        : null;
  }
}

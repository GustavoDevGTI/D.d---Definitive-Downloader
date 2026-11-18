import 'dart:async';
import 'package:path/path.dart' as p;
import '../../../core/application/operation_message.dart';
import '../../downloads/download_service.dart';
import '../../downloads/playlist_exporter.dart';
import '../../matching/music_resolver.dart';
import '../../workspace/data/workspace_repository.dart';
import '../data/library_repository.dart';
import '../domain/models.dart';
import '../../../core/platform/desktop_files.dart';
import '../../../core/platform/media_publication.dart';
import '../../importing/local_mp3_inspector.dart';
import '../../downloads/cached_media_publication.dart';

sealed class DownloadRunEvent {
  const DownloadRunEvent();
}

class DownloadRunMembership extends DownloadRunEvent {
  const DownloadRunMembership(this.run);
  final String? run;
}

class DownloadRunTrack extends DownloadRunEvent {
  const DownloadRunTrack(this.track);
  final Track track;
}

class DownloadRunProgress extends DownloadRunEvent {
  const DownloadRunProgress(this.fraction, this.transfer);
  final double? fraction;
  final TransferProgress? transfer;
}

class DownloadRunNotice extends DownloadRunEvent {
  const DownloadRunNotice(this.message);
  final String message;
}

/// Owns queue membership, fallback, publication and export; never owns UI state.
class DownloadQueueRun {
  const DownloadQueueRun(this.repository, this.downloader, this.music,
      {this.files, this.inspector = const MediaKitLocalAudioInspector()});
  final LocalAudioInspector inspector;
  final DesktopFiles? files;
  final LibraryRepository repository;
  final DownloadService downloader;
  final MusicResolver? music;
  Future<String> execute(
      {required String outputDirectory,
      int? collectionId,
      List<int>? queueIds,
      bool failedOnly = false,
      required DownloadCancellation token,
      required void Function(DownloadRunEvent) onEvent,
      required Future<void> Function() recordsChanged,
      required Future<void>? Function() pendingAddition,
      Future<void>? Function()? pendingMutation}) async {
    final destinations = <int, String>{};
    var saved = 0, failed = 0, reviewVideos = 0;
    double? progress;
    TransferProgress? transfer;
    var message = '';
    final queue = WorkspaceRepository(repository.database);
    final run = '${DateTime.now().microsecondsSinceEpoch}';
    try {
      await queue.beginRun(
          run: run,
          ids: queueIds,
          collectionId: collectionId,
          failedOnly: failedOnly);
      onEvent(DownloadRunMembership(run));
      await recordsChanged();
      while (!token.cancelled) {
        final mutation = pendingMutation?.call();
        if (mutation != null) {
          while (!token.cancelled &&
              identical(pendingMutation?.call(), mutation)) {
            await Future.any<void>([
              mutation,
              Future<void>.delayed(const Duration(milliseconds: 100))
            ]);
          }
          if (token.cancelled) break;
        }
        try {
          await token.waitForQueue();
        } on DownloadCancelled {
          break;
        }
        final track = await queue.claimNext(
            run: run,
            snapshot: true,
            ids: queueIds,
            collectionId: collectionId,
            failedOnly: failedOnly);
        if (track == null) {
          final addition = pendingAddition();
          if (addition != null) {
            while (!token.cancelled && identical(pendingAddition(), addition)) {
              await Future.any<void>([
                addition,
                Future<void>.delayed(const Duration(milliseconds: 100))
              ]);
            }
            continue;
          }
          break;
        }
        final owner = await repository.collectionById(track.collectionId);
        if (owner == null) continue;
        final directory = p.join(outputDirectory,
            '${safeSegment(owner.outputFolderName)} [${owner.id}]');
        destinations[owner.id] = directory;
        onEvent(DownloadRunTrack(track));
        progress = null;
        transfer = null;
        await recordsChanged();
        try {
          Future<String> receive(Track item) async {
            transfer = null;
            try {
              final work = await files?.transferDirectory(directory, item.id,
                      item.collectionId, mediaPublicationKey(item)) ??
                  directory;
              final path = await downloader.save(item, work, token, (value) {
                progress = value;
                onEvent(DownloadRunProgress(progress, transfer));
              }, onTransfer: (value) {
                transfer = value;
                onEvent(DownloadRunProgress(progress, transfer));
              });
              if (work != directory) await inspector.inspect(path);
              await repository.recordMusicAttempt(item.id, item.sourceKind,
                  succeeded: true);
              return path;
            } on DownloadCancelled {
              rethrow;
            } catch (error) {
              token.check();
              if (error is MediaPublicationFailure) rethrow;
              await repository.recordMusicAttempt(item.id, item.sourceKind,
                  succeeded: false, message: operationMessage(error));
              rethrow;
            }
          }

          String path;
          var received = track;
          final reusable = await files?.reusableTransfer(
              directory, track.id, mediaPublicationKey(track));
          if (reusable != null) {
            path = await prepareCachedMedia(reusable, track, inspector);
          } else {
            try {
              path = await receive(track);
            } on DownloadCancelled {
              rethrow;
            } catch (error) {
              token.check();
              if (error is MediaPublicationFailure ||
                  track.redownloadState.isNotEmpty ||
                  track.hasManualSource ||
                  ![
                    SourceKind.deezerFull,
                    SourceKind.youtubeMusic,
                    SourceKind.soundcloud
                  ].contains(track.sourceKind) ||
                  music == null) {
                rethrow;
              }
              final alternatives = await repository.musicCandidates(track.id);
              final fallback = music!.automaticChoice(
                  track,
                  alternatives
                      .where((c) => c.kind != track.sourceKind)
                      .toList());
              if (fallback == null) {
                final videos = await music!.searchVideos(
                    track, '${track.artist} ${track.title}',
                    cancellation: token);
                if (videos.isEmpty) rethrow;
                await repository.saveCandidates(
                    track.id,
                    [
                      ...alternatives
                          .where((c) => c.kind != SourceKind.youtube),
                      ...videos
                    ].take(32).toList());
                await repository.markForReview(track.id);
                await repository.setStatus(track.id, TrackStatus.pending,
                    error:
                        'Áudio indisponível. Videoclipe encontrado: aprove a versão na coleção.');
                reviewVideos++;
                await recordsChanged();
                continue;
              }
              message =
                  '${track.sourceKind.musicProviderName} indisponível para esta faixa; tentando a correspondência de áudio em ${fallback.kind.musicProviderName}.';
              onEvent(DownloadRunNotice(message));
              await repository.chooseMusicSource(track, fallback,
                  forFallback: true);
              final updated = await repository.trackById(track.id);
              received = updated!;
              await repository.setStatus(track.id, TrackStatus.downloading);
              path = await receive(updated);
            }
          }
          // Publication failures occur outside the provider fallback block.
          // Validated bytes remain available for a write-only retry.
          token.check();
          path = await files?.publishMedia(path, directory, received.id,
                  received.collectionId, mediaPublicationKey(received),
                  cancellation: token,
                  fileName: p.basename(path).replaceFirst(RegExp(r'^\d+ - '),
                      '${received.position.toString().padLeft(3, '0')} - ')) ??
              path;
          await repository.setStatus(track.id, TrackStatus.completed,
              localPath: path);
          try {
            await files?.acknowledgeMedia(path);
          } catch (_) {
            onEvent(const DownloadRunNotice(
                'Mídia publicada. O registro de confirmação será reconciliado ao reabrir.'));
          }
          saved++;
        } on DownloadCancelled {
          await repository.setStatus(track.id, TrackStatus.ready,
              error: 'Interrompido. Uma nova tentativa reinicia este arquivo.');
          break;
        } catch (error) {
          failed++;
          await repository.setStatus(track.id, TrackStatus.failed,
              error: operationMessage(error));
        }
        await recordsChanged();
        // Finish the current transfer in pause mode without starting another.
        if (token.pauseMode) break;
      }
      onEvent(const DownloadRunMembership(null));
      if (saved > 0) {
        for (final entry in destinations.entries) {
          await PlaylistExporter(repository, files: files)
              .export(entry.key, entry.value);
        }
      }
      message = token.cancelled
          ? 'Transferência interrompida. Os arquivos concluídos foram preservados.'
          : saved == 0 && failed == 0
              ? 'Selecione faixas com uma fonte vinculada. Itens já salvos não são baixados novamente.'
              : failed > 0
                  ? '$failed download(s) com falha. Confira os itens marcados com erro.'
                  : '';
      if (reviewVideos > 0) {
        message +=
            ' $reviewVideos videoclipe(s) aguardando aprovação na coleção.';
      }
      return message;
    } finally {
      try {
        await queue.finishRun(run);
      } catch (_) {
        // Startup also clears membership; cleanup must not mask cancellation.
      }
    }
  }
}

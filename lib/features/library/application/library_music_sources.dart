import '../../../core/application/operation_message.dart';
import '../../downloads/download_cancellation.dart';
import '../../importing/music_link.dart';
import '../../importing/music_link_catalog.dart';
import '../../importing/music_link_service.dart';
import '../../importing/music_link_repository.dart';
import '../../matching/music_resolver.dart';
import '../data/library_repository.dart';
import '../data/redownload_repository.dart';
import '../domain/models.dart';

class LibraryMusicSources {
  const LibraryMusicSources(this.repository, this.catalog, this.music);
  final LibraryRepository repository;
  final MusicLinkCatalog catalog;
  final MusicResolver? music;
  Future<({int prepared, int review})> prepare(
      Collection collection, DownloadCancellation token,
      {required bool onlyPending,
      required void Function(Track) onTrack,
      required Future<void> Function() recordsChanged}) async {
    final resolver = music!;
    var after = 0;
    var prepared = 0;
    var review = 0;
    while (!token.cancelled) {
      final batch = await repository.page(collection.id, offset: after);
      if (batch.items.isEmpty) break;
      for (final track in batch.items) {
        token.check();
        if (track.redownloadState.isNotEmpty) continue;
        if (onlyPending && !track.needsAutomaticMatching) continue;
        if (track.hasManualSource &&
            track.status == TrackStatus.pending &&
            resolver.available &&
            (track.sourceKind == SourceKind.youtubeMusic ||
                track.sourceKind == SourceKind.youtube ||
                (track.sourceKind == SourceKind.deezerFull &&
                    resolver.connection.connected))) {
          await repository.setStatus(track.id, TrackStatus.ready);
          prepared++;
        }
        if (track.status == TrackStatus.completed ||
            track.hasManualSource ||
            track.sourceKind == SourceKind.localExample) {
          continue;
        }
        onTrack(track);
        if (Uri.tryParse(track.sourceUrl)?.host == 'api.soundcloud.com' &&
            track.durationMs == null) {
          await repository.markForReview(track.id);
          await repository.setStatus(track.id, TrackStatus.pending,
              error:
                  'Esta ocorrência não está disponível no SoundCloud. Informe uma versão na conferência.');
          review++;
          await recordsChanged();
          continue;
        }
        try {
          final found = await resolver.search(
              track, '${track.artist} ${track.title}',
              cancellation: token);
          await repository.saveCandidates(track.id, found);
          final choice = resolver.automaticChoice(track, found);
          if (choice != null) {
            await repository.chooseMusicSource(track, choice);
            prepared++;
          } else {
            await repository.markForReview(track.id);
            review++;
          }
        } on DownloadCancelled {
          rethrow;
        } catch (error) {
          review++;
          await repository.setStatus(track.id, TrackStatus.pending,
              error: operationMessage(error));
          await repository.markForReview(track.id);
        }
        await recordsChanged();
      }
      after += batch.items.length;
    }
    return (prepared: prepared, review: review);
  }

  Future<String> setManual(
      Track track, String value, ManualSourceMode mode) async {
    MusicLink? link;
    try {
      link = MusicLink.parse(value);
    } on FormatException {/* Generic pages may remain pending below. */}
    if (link != null) {
      final resolved =
          (await MusicLinkService(catalog, music).resolve(link.url)).single;
      await MusicLinkRepository(repository.database)
          .setSource(track.id, resolved);
      return resolved.ready
          ? 'Fonte manual salva.'
          : 'Fonte salva; aguardando conexão ou revisão.';
    }
    if (mode == ManualSourceMode.originalAudio) {
      throw const FormatException(
          'Use um link de faixa, YouTube ou MP3 direto.');
    }
    await repository.setManualSource(track.id, value, mode);
    return mode == ManualSourceMode.extractAudio
        ? 'Fonte manual salva. A extração de páginas e vídeos ainda não está disponível.'
        : 'Fonte manual salva. O endereço deve fornecer MP3; o arquivo será validado no download.';
  }

  Future<String> usePreview(Track track, Candidate candidate) async {
    if (track.redownloadReview && track.hasManualSource) {
      await repository.removeManualSource(track.id);
    }
    await repository.linkSource(track,
        url: candidate.previewUrl,
        kind: SourceKind.preview,
        title: candidate.title,
        artist: candidate.artist,
        album: candidate.album,
        coverUrl: candidate.coverUrl);
    if (track.redownloadReview) {
      await RedownloadRepository(repository.database).approvePrevious(track.id,
          url: candidate.previewUrl, kind: SourceKind.preview);
    }
    return 'Prévia vinculada. O arquivo será identificado como prévia, com a fonte real.';
  }
}

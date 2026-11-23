import 'dart:io';
import 'package:path/path.dart' as p;
import 'transfer_progress.dart';
import '../connections/application/deezer_connection_controller.dart';
import '../library/domain/models.dart';
import '../matching/music_candidates.dart';
import '../matching/music_engine.dart';
import 'download_cancellation.dart';
import 'download_file_name.dart';
import '../audio_capture/domain/audio_capture.dart';

class MusicDownloadService {
  MusicDownloadService(this.engine, this.connection);
  final MusicEngine engine;
  final DeezerConnectionController connection;

  Future<String> save(Track track, String directory, DownloadCancellation token,
      void Function(String) onStage,
      {void Function(TransferProgress)? onTransfer}) async {
    final candidate = Candidate(
        sourceId: track.sourceId,
        title: track.resolvedTitle.isEmpty ? track.title : track.resolvedTitle,
        artist: track.outputArtist,
        album: track.outputAlbum,
        durationMs: track.outputDurationMs ?? 0,
        pageUrl: track.mediaUrl,
        previewUrl: '',
        coverUrl: track.resolvedCoverUrl,
        kind: track.sourceKind,
        recordingType: track.recordingType.isNotEmpty
            ? track.recordingType
            : track.sourceKind == SourceKind.youtubeMusic
                ? 'MUSIC_VIDEO_TYPE_ATV'
                : track.sourceKind == SourceKind.deezerFull
                    ? 'DEEZER_TRACK'
                    : '');
    final allowedVideo = track.sourceKind == SourceKind.youtube &&
        (track.sourceAuthorization == SourceAuthorization.manualLink ||
            (track.sourceAuthorization == SourceAuthorization.approvedVideo &&
                candidate.isVideoRecording));
    final captured = track.sourceKind == SourceKind.webAudio &&
        track.sourceAuthorization == SourceAuthorization.manualLink &&
        track.recordingType == 'WEB_AUDIO';
    if (!captured && !candidate.isFullRecording && !allowedVideo) {
      throw const FormatException('Não é uma fonte musical confirmada.');
    }
    final folder = Directory(directory);
    await folder.create(recursive: true);
    final work = await folder.createTemp('.dd-music-');
    try {
      final request = <String, dynamic>{
        'operation': 'download',
        'candidate': candidateJson(candidate),
        'authorization': track.sourceAuthorization.name,
        'outputTitle': track.customTitle,
        'directory': work.absolute.path
      };
      if (track.sourceKind == SourceKind.deezerFull) {
        request['arl'] = await connection.sessionForDownload();
      }
      TransferProgress? latest;
      final result =
          await engine.call(request, cancellation: token, onProgress: (value) {
        latest = value;
        onTransfer?.call(value);
      }, onStage: (stage) {
        if (latest != null) onTransfer?.call(latest!.asProcessing());
        onStage(stage);
      });
      token.check();
      final actualRow = Map<String, dynamic>.from(result['actual'] as Map);
      final actual =
          captured ? capturedAudio(actualRow) : parseMusicCandidate(actualRow);
      final duration = result['durationMs'];
      if ((!captured &&
              !actual.isFullRecording &&
              !(allowedVideo && actual.kind == SourceKind.youtube)) ||
          actual.kind != candidate.kind ||
          actual.sourceId != candidate.sourceId ||
          (track.sourceAuthorization == SourceAuthorization.approvedVideo &&
              !actual.isVideoRecording) ||
          (track.customTitle.isNotEmpty &&
              result['displayTitle'] != track.customTitle) ||
          actual.pageUrl != candidate.pageUrl ||
          result['decoded'] != true ||
          (!captured && result['coverEmbedded'] != true) ||
          duration is! int ||
          duration < (captured ? 1 : 1000) ||
          duration > const Duration(hours: 24).inMilliseconds ||
          ((!captured || candidate.durationMs > 0) &&
              (duration - candidate.durationMs).abs() > 2000)) {
        throw const FormatException(
            'O áudio recebido não corresponde à faixa escolhida.');
      }
      final source = File(result['path'] as String);
      if (p.basename(source.path) != 'verified.mp3' ||
          !await source.exists() ||
          await source.length() < 1024) {
        throw const FormatException(
            'O motor não entregou um arquivo validado.');
      }
      // Windows can virtualize the logical AppData path across processes.
      // Compare actual filesystem targets, including junctions, before publication.
      final actualWork = await work.resolveSymbolicLinks();
      final actualSource = await source.resolveSymbolicLinks();
      if (!p.isWithin(p.normalize(actualWork), p.normalize(actualSource))) {
        throw const FormatException(
            'O motor retornou um arquivo fora da pasta temporária.');
      }
      final name =
          '${track.position.toString().padLeft(3, '0')} - ${safeSegment(track.customTitle.isEmpty ? actual.title : track.customTitle)}${actual.artist.trim().isEmpty ? '' : ' - ${safeSegment(actual.artist)}'}${actual.kind.musicProviderSuffix}';
      var output = File(p.join(folder.path, '$name.mp3'));
      if (await output.exists()) {
        output = File(p.join(folder.path, '$name [${track.id}].mp3'));
      }
      if (await output.exists()) {
        throw const FileSystemException(
            'O arquivo já existe. Escolha outra pasta.');
      }
      await source.rename(output.path);
      return output.path;
    } finally {
      // Only the unique, owned staging directory created above may be removed.
      if (p.isWithin(folder.absolute.path, work.absolute.path) &&
          await work.exists()) {
        try {
          await work.delete(recursive: true);
        } on FileSystemException {
          // Windows may still hold a descendant's file handle after stopping
          // the worker. Cleanup must not mask cancellation or a published file.
          // Keep only this owned staging directory for later inspection.
        }
      }
    }
  }
}

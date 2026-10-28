import 'dart:io';
import 'package:path/path.dart' as p;
import '../connections/application/deezer_connection_controller.dart';
import '../library/domain/models.dart';
import '../matching/music_candidates.dart';
import '../matching/music_engine.dart';
import 'download_service.dart';

class MusicDownloadService {
  MusicDownloadService(this.engine, this.connection);
  final MusicEngine engine;
  final DeezerConnectionController connection;

  Future<String> save(Track track, String directory, DownloadCancellation token,
      void Function(String) onStage) async {
    final candidate = Candidate(
        title: track.outputTitle,
        artist: track.outputArtist,
        album: track.outputAlbum,
        durationMs: track.outputDurationMs ?? 0,
        pageUrl: track.mediaUrl,
        previewUrl: '',
        coverUrl: track.resolvedCoverUrl,
        kind: track.sourceKind,
        recordingType: track.sourceKind == SourceKind.youtubeMusic
            ? 'MUSIC_VIDEO_TYPE_ATV'
            : 'DEEZER_TRACK');
    if (!candidate.isFullRecording) {
      throw const FormatException('Não é uma fonte musical confirmada.');
    }
    final folder = Directory(directory);
    await folder.create(recursive: true);
    final work = await folder.createTemp('.dd-music-');
    try {
      final request = <String, dynamic>{
        'operation': 'download',
        'candidate': candidateJson(candidate),
        'directory': work.absolute.path
      };
      if (track.sourceKind == SourceKind.deezerFull) {
        request['arl'] = await connection.sessionForDownload();
      }
      final result =
          await engine.call(request, cancellation: token, onStage: onStage);
      token.check();
      final actual = parseMusicCandidate(
          Map<String, dynamic>.from(result['actual'] as Map));
      final duration = result['durationMs'];
      if (!actual.isFullRecording ||
          actual.pageUrl != candidate.pageUrl ||
          result['decoded'] != true ||
          result['coverEmbedded'] != true ||
          duration is! int ||
          (duration - candidate.durationMs).abs() > 2000) {
        throw const FormatException(
            'O áudio recebido não corresponde à faixa escolhida.');
      }
      final source = File(result['path'] as String);
      if (!p.isWithin(p.normalize(work.absolute.path),
              p.normalize(source.absolute.path)) ||
          p.basename(source.path) != 'verified.mp3' ||
          !await source.exists() ||
          await source.length() < 1024) {
        throw const FormatException(
            'O motor não entregou um arquivo validado.');
      }
      final name =
          '${track.position.toString().padLeft(3, '0')} - ${safeSegment(actual.artist)} - ${safeSegment(actual.title)}${actual.kind.musicProviderSuffix}';
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
        await work.delete(recursive: true);
      }
    }
  }
}

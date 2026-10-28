import 'dart:io';
import 'package:path/path.dart' as p;
import '../library/data/library_repository.dart';
import '../library/domain/models.dart';

class PlaylistExporter {
  const PlaylistExporter(this.repository);
  final LibraryRepository repository;
  Future<String> export(int collectionId, String directory) async {
    final file = File(p.join(directory, 'playlist.m3u8'));
    final temporary = File('${file.path}.tmp');
    final sink = temporary.openWrite();
    try {
      sink.writeln('#EXTM3U');
      var after = 0;
      while (true) {
        final tracks = await repository.completedPage(collectionId, after);
        if (tracks.isEmpty) break;
        for (final track in tracks) {
          final title = '${track.outputArtist} - ${track.outputTitle}'
              .replaceAll(RegExp(r'[\r\n]'), ' ');
          sink.writeln(
              '#EXTINF:${(track.outputDurationMs ?? -1000) ~/ 1000},$title${track.sourceKind.musicProviderSuffix}');
          sink.writeln(p.basename(track.localPath));
        }
        after = tracks.last.position;
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
    // The app only replaces its own generated playlist; audio files are never overwritten.
    if (await file.exists()) await file.delete();
    await temporary.rename(file.path);
    return file.path;
  }
}

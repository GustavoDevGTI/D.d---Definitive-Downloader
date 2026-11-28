import 'dart:io';
import 'package:path/path.dart' as p;
import '../library/data/library_repository.dart';
import '../library/domain/models.dart';
import '../../core/platform/desktop_files.dart';
import '../../core/platform/platform_services.dart';

class PlaylistExporter {
  const PlaylistExporter(this.repository, {this.files});
  final LibraryRepository repository;
  final DesktopFiles? files;
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
          final title =
              '${track.outputTitle}${track.outputArtist.trim().isEmpty ? '' : ' - ${track.outputArtist}'}'
                  .replaceAll(RegExp(r'[\r\n]'), ' ');
          sink.writeln(
              '#EXTINF:${(track.outputDurationMs ?? -1000) ~/ 1000},$title${track.sourceKind.musicProviderSuffix}');
          // Files saved before the playlist changed location stay in the
          // old folder; the entry then points there instead of breaking.
          sink.writeln(_entry(track.localPath, directory));
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
    await (files ?? createPlatformFiles()).publishPlaylist(file.path);
    return file.path;
  }
}

String _entry(String path, String directory) {
  if (p.equals(p.dirname(path), directory)) return p.basename(path);
  try {
    return p.relative(path, from: directory);
  } on p.PathException {
    return path; // Another drive: only an absolute path reaches it.
  }
}

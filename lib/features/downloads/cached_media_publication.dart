import 'dart:io';
import 'package:path/path.dart' as p;
import '../importing/local_mp3_inspector.dart';
import '../library/domain/models.dart';
import '../player/data/audio_tags.dart';
import 'mp3_tags.dart';

/// Reorder only private staging metadata; never fetch or alter the recording.
Future<String> prepareCachedMedia(
    String path, Track track, LocalAudioInspector inspector) async {
  await inspector.inspect(path);
  final file = File(path);
  if (!p.basename(file.parent.path).startsWith('.dd-transfer-')) return path;
  final name = p.basename(path);
  final match = RegExp(r'^(\d+) - ').firstMatch(name);
  if (match == null || int.parse(match[1]!) == track.position) return path;
  final tags = await readAudioTags(path);
  final staged = File(p.join(file.parent.path, '.renumber.part'));
  await const Mp3TagWriter().write(
      source: file, destination: staged, track: track, cover: tags.cover);
  await staged.rename(file.path);
  return file.path;
}

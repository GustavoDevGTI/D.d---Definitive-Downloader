import 'dart:io';
import 'package:path/path.dart' as p;
import '../domain/status_saver.dart';

/// Reads the folder of status copies prepared by the Android adapter and the
/// staging used for the extracted MP3s. Only files inside [root] are touched.
class StatusFolder {
  const StatusFolder(this.root);
  final String root;

  Future<List<WhatsAppStatus>> statuses() async {
    final rows = <WhatsAppStatus>[];
    await for (final entry in Directory(root).list(followLinks: false)) {
      if (entry is! File) continue;
      final extension = p.extension(entry.path).toLowerCase();
      final video = statusVideoExtensions.contains(extension);
      if (!video && !statusAudioExtensions.contains(extension)) continue;
      final stat = await entry.stat();
      rows.add(WhatsAppStatus(
          path: entry.path,
          modified: stat.modified,
          bytes: stat.size,
          isVideo: video));
      if (rows.length > 200) break;
    }
    // The adapter numbers the copies newest first.
    rows.sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
    return rows;
  }

  /// An empty directory inside [root] for one extraction.
  Future<String> staging(int index) async =>
      (await Directory(p.join(root, '.extract-$index')).create()).path;

  /// The folder whose MP3s become the playlist, named after it.
  Future<String> playlistFolder(String name) async =>
      (await Directory(p.join(root, name)).create()).path;

  /// Moves an extracted MP3 into the playlist folder, keeping the order.
  Future<void> collect(
      String mp3, String folder, int order, String title) async {
    final source = File(mp3);
    if (!p.isWithin(root, source.path) || !p.isWithin(root, folder)) {
      throw const FormatException('Áudio extraído fora da pasta dos status.');
    }
    final safe = title.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '-');
    await source.rename(p.join(
        folder, '${(order + 1).toString().padLeft(3, '0')} - $safe.mp3'));
  }
}

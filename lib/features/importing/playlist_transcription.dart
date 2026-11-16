import '../downloads/download_cancellation.dart';
import '../library/domain/models.dart';

/// A complete playlist held for review before it is added to the library.
class PlaylistTranscription {
  PlaylistTranscription._(
      this.name, this.source, this.sourceUrl, this.tracks, this.skippedCount);

  final String name, source, sourceUrl;
  final List<TrackDraft> tracks;
  final int skippedCount;

  static Future<PlaylistTranscription> read(
      ImportedCollection collection, DownloadCancellation cancellation) async {
    if (collection.isPartial) {
      throw const FormatException('A origem não entregou a playlist completa.');
    }
    final tracks = <TrackDraft>[];
    await for (final track in collection.tracks) {
      cancellation.check();
      if (tracks.length >= 10000) {
        throw const FormatException('Limite de 10.000 faixas por playlist.');
      }
      tracks.add(track);
    }
    cancellation.check();
    if (tracks.isEmpty) {
      throw const FormatException('A playlist está vazia.');
    }
    return PlaylistTranscription._(
        collection.name,
        collection.source,
        collection.sourceUrl,
        List.unmodifiable(tracks),
        collection.skippedCount);
  }

  ImportedCollection open() => ImportedCollection(
      name: name,
      source: source,
      sourceUrl: sourceUrl,
      skippedCount: skippedCount,
      tracks: Stream.fromIterable(tracks));
}

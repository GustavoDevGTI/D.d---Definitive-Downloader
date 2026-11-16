import 'package:definitive_downloader/features/importing/trackhop_client.dart';
import 'package:definitive_downloader/features/library/domain/models.dart';

class FixtureTrackhop extends TrackhopClient {
  FixtureTrackhop(
      {this.titles = const ['Canção'],
      this.artist = 'Pessoa',
      this.durationMs = 180000,
      this.onRead,
      this.onCheck})
      : super(Uri.parse(TrackhopClient.desktopAddress), 'fixture-trackhop-key');

  final List<String> titles;
  final String artist;
  final int durationMs;
  final void Function()? onRead;
  final Future<void> Function()? onCheck;

  @override
  Future<void> check() async {
    await onCheck?.call();
  }

  @override
  Future<ImportedCollection> playlist(String url,
      {bool Function()? cancelled, void Function(int, int)? onProgress}) async {
    onRead?.call();
    return ImportedCollection(
        name: 'Playlist de teste',
        source: 'Spotify · Trackhop',
        sourceUrl: url,
        tracks: Stream.fromIterable(titles.map((title) =>
            TrackDraft(title: title, artist: artist, durationMs: durationMs))));
  }

  @override
  Future<TrackDraft> track(String id, String url) async => TrackDraft(
      title: 'Canção', artist: 'Pessoa', durationMs: 180000, sourceUrl: url);
}

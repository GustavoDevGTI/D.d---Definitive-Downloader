import '../matching/music_resolver.dart';
import '../library/domain/models.dart';
import 'music_link.dart';
import 'music_link_catalog.dart';
import '../downloads/download_cancellation.dart';

class MusicLinkService {
  const MusicLinkService(this.catalog, this.resolver);
  final MusicLinkCatalog catalog;
  final MusicResolver? resolver;

  Future<List<ResolvedMusicLink>> resolve(String input,
      {void Function(int done, int total)? onProgress,
      DownloadCancellation? cancellation}) async {
    final links = MusicLink.batch(input);
    final result = <ResolvedMusicLink>[];
    for (var i = 0; i < links.length; i++) {
      onProgress?.call(i, links.length);
      cancellation?.check();
      final item = await prepare(await catalog.resolve(links[i]),
          cancellation: cancellation);
      result.add(item);
    }
    onProgress?.call(links.length, links.length);
    return result;
  }

  Future<ResolvedMusicLink> prepare(ResolvedMusicLink entry,
      {DownloadCancellation? cancellation}) async {
    cancellation?.check();
    var item = entry;
    final music = resolver;
    if (item.pinned && item.source != null) {
      item = item.prepared(
          source: item.source,
          alternatives: item.alternatives,
          ready: music?.available == true &&
              (item.source!.kind == SourceKind.youtube ||
                  music!.canUse(item.source!)));
    } else if (!item.pinned && music?.available == true) {
      // Spotify/SoundCloud supply requested metadata, not a downloadable source.
      final track = item.matchingTrack;
      try {
        final found = await music!.search(
            track, '${track.artist} ${track.title}',
            cancellation: cancellation);
        final choice = music.automaticChoice(track, found);
        item = item.prepared(
            source: choice, alternatives: found, ready: choice != null);
      } on FormatException {
        // Keep the imported occurrence pending; a provider outage must not
        // discard the requested metadata or silently select another version.
      }
    }
    cancellation?.check();
    return item;
  }
}

import '../matching/music_resolver.dart';
import 'music_link.dart';
import 'music_link_catalog.dart';

class MusicLinkService {
  const MusicLinkService(this.catalog, this.resolver);
  final MusicLinkCatalog catalog;
  final MusicResolver? resolver;

  Future<List<ResolvedMusicLink>> resolve(String input,
      {void Function(int done, int total)? onProgress}) async {
    final links = MusicLink.batch(input);
    final result = <ResolvedMusicLink>[];
    for (var i = 0; i < links.length; i++) {
      onProgress?.call(i, links.length);
      var item = await catalog.resolve(links[i]);
      final music = resolver;
      if (item.pinned && item.source != null) {
        item = item.prepared(
            source: item.source,
            alternatives: item.alternatives,
            ready: music?.available == true && music!.canUse(item.source!));
      } else if (!item.pinned && music?.available == true) {
        // Spotify supplies requested metadata, never a downloadable audio URL.
        final track = item.matchingTrack;
        try {
          final found =
              await music!.search(track, '${track.artist} ${track.title}');
          final choice = music.automaticChoice(track, found);
          item = item.prepared(
              source: choice, alternatives: found, ready: choice != null);
        } on FormatException {
          // Keep the imported occurrence pending; a provider outage must not
          // discard the requested metadata or silently select another version.
        }
      }
      result.add(item);
    }
    onProgress?.call(links.length, links.length);
    return result;
  }
}

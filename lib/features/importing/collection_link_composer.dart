import '../downloads/download_cancellation.dart';
import '../library/domain/models.dart';
import 'playlist_catalog.dart';
import 'music_link.dart';
import 'music_link_service.dart';

class CollectionLinkComposer {
  const CollectionLinkComposer(this.playlists, this.links);
  final PlaylistCatalog playlists;
  final MusicLinkService links;

  Future<List<ResolvedMusicLink>> resolve(String input,
      {required int capacity,
      required DownloadCancellation cancellation,
      bool prepare = true,
      void Function(String)? onProgress}) async {
    if (input.length > 32768) {
      throw const FormatException('O lote excede o limite de leitura.');
    }
    final lines = input
        .split(RegExp(r'[\r\n]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (lines.isEmpty || lines.length > 20) {
      throw const FormatException('Adicione de 1 a 20 links por vez.');
    }
    final entries = <ResolvedMusicLink>[];
    // Fully expand first: no remote error can leave half a playlist appended.
    for (var i = 0; i < lines.length; i++) {
      cancellation.check();
      onProgress?.call('Lendo link ${i + 1}/${lines.length}');
      if (PlaylistCatalog.isCollection(lines[i])) {
        final imported = await playlists.read(lines[i],
            cancelled: () => cancellation.cancelled,
            onProgress: (done, total) =>
                onProgress?.call('Lendo playlist: $done/$total'));
        if (imported.isPartial) {
          throw const FormatException(
              'A playlist chegou parcial. Conecte a conta ou use uma lista completa.');
        }
        await for (final draft in imported.tracks) {
          cancellation.check();
          if (entries.length >= capacity) {
            throw const FormatException('Limite de 10.000 faixas por coleção.');
          }
          entries.add(fromDraft(draft, imported.sourceUrl));
        }
      } else {
        if (entries.length >= capacity) {
          throw const FormatException('Limite de 10.000 faixas por coleção.');
        }
        entries.add(await links.catalog.resolve(MusicLink.parse(lines[i])));
      }
    }
    if (entries.isEmpty) {
      throw const FormatException('Nenhuma faixa encontrada nos links.');
    }
    if (!prepare) return entries;
    final result = <ResolvedMusicLink>[];
    for (var i = 0; i < entries.length; i++) {
      cancellation.check();
      onProgress?.call('Conferindo faixas: ${i + 1}/${entries.length}');
      result.add(await links.prepare(entries[i], cancellation: cancellation));
    }
    return result;
  }

  static ResolvedMusicLink fromDraft(TrackDraft draft, String fallback) {
    final url = draft.sourceUrl.isEmpty ? fallback : draft.sourceUrl;
    final host = Uri.tryParse(url)?.host ?? '';
    final kind = host.contains('soundcloud.com')
        ? MusicLinkKind.soundcloud
        : host == 'music.youtube.com'
            ? MusicLinkKind.youtubeMusic
            : host.contains('youtube.com')
                ? MusicLinkKind.youtube
                : host.contains('deezer.com')
                    ? MusicLinkKind.deezer
                    : MusicLinkKind.spotify;
    final source = draft.sourceKind == SourceKind.none
        ? null
        : Candidate(
            title: draft.title,
            artist: draft.artist,
            album: draft.album,
            durationMs: draft.durationMs ?? 0,
            pageUrl: draft.mediaUrl,
            previewUrl: '',
            coverUrl: draft.coverUrl,
            kind: draft.sourceKind,
            recordingType: draft.recordingType,
            sourceId: draft.sourceId,
            isrc: draft.isrc,
            explicit: draft.explicit);
    return ResolvedMusicLink(
        link: MusicLink(kind, url, draft.sourceId),
        draft: draft,
        source: source,
        alternatives: source == null ? const [] : [source],
        pinned: draft.manualUrl.isNotEmpty || host == 'api.soundcloud.com',
        ready: draft.sourceReady && source != null,
        pendingReason: draft.pendingReason);
  }
}

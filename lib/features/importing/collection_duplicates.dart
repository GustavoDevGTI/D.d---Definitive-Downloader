import '../downloads/download_cancellation.dart';
import '../library/domain/models.dart';
import '../library/domain/track_listing.dart';
import 'music_link.dart';

enum DuplicateChoice { existing, incoming }

class DuplicateDecision {
  const DuplicateDecision(this.choice, {this.forAll = false});
  final DuplicateChoice choice;
  final bool forAll;
}

class DuplicateVersion {
  const DuplicateVersion(this.track,
      {this.incomingIndex, this.extraKeys = const {}});
  final Track track;
  final Set<String> extraKeys;
  final int? incomingIndex;
  bool get fromPlaylist => incomingIndex == null;
}

class DuplicateConflict {
  const DuplicateConflict(
      this.existing, this.incoming, this.inputPosition, this.total);
  final List<DuplicateVersion> existing;
  final ResolvedMusicLink incoming;
  final int inputPosition, total;
}

typedef ChooseDuplicate = Future<DuplicateDecision?> Function(
    DuplicateConflict);

class DuplicatePlan {
  const DuplicatePlan(this.add, this.remove, this.skipped);
  final List<ResolvedMusicLink> add;
  final List<Track> remove;
  final int skipped;
}

/// Selection only: no storage, network, or implicit removal of repetitions.
class CollectionDuplicates {
  const CollectionDuplicates();
  Future<DuplicatePlan> review(
      List<Track> existing, List<ResolvedMusicLink> input,
      {ChooseDuplicate? choose,
      required DownloadCancellation cancellation,
      void Function()? onConflict}) async {
    final index = <String, Set<DuplicateVersion>>{};
    final active = <DuplicateVersion>{};
    void add(DuplicateVersion v) {
      active.add(v);
      for (final key in {...keys(v.track), ...v.extraKeys}) {
        (index[key] ??= {}).add(v);
      }
    }

    void remove(DuplicateVersion v) {
      active.remove(v);
      for (final key in {...keys(v.track), ...v.extraKeys}) {
        index[key]?.remove(v);
      }
    }

    final original = [for (final t in existing) DuplicateVersion(t)];
    for (var i = 0; i < original.length; i++) {
      if (i % 64 == 0) {
        cancellation.check();
        await Future<void>.delayed(Duration.zero);
      }
      add(original[i]);
    }
    DuplicateChoice? all;
    for (var i = 0; i < input.length; i++) {
      if (i % 64 == 0) await Future<void>.delayed(Duration.zero);
      cancellation.check();
      final entry = input[i];
      final track = entry.matchingTrack;
      // Also index the effective source without replacing requested metadata.
      final found = <DuplicateVersion>{};
      final incomingKeys = {
        ...keys(track),
        ...referenceKeys(entry.link.url),
        ...nativeKeys(
            entry.draft.sourceKind, entry.draft.sourceId, entry.link.url),
        if (entry.source != null) ...referenceKeys(entry.source!.pageUrl),
        if (entry.source != null)
          ...nativeKeys(
              entry.source!.kind, entry.source!.sourceId, entry.source!.pageUrl)
      };
      for (final key in incomingKeys) {
        found.addAll(index[key] ?? {});
      }
      if (found.isNotEmpty) {
        onConflict?.call();
        final ordered = found.toList()
          ..sort((a, b) => a.fromPlaylist != b.fromPlaylist
              ? (a.fromPlaylist ? -1 : 1)
              : (a.fromPlaylist
                  ? a.track.position.compareTo(b.track.position)
                  : a.incomingIndex!.compareTo(b.incomingIndex!)));
        final answer = all == null
            ? await choose
                ?.call(DuplicateConflict(ordered, entry, i + 1, input.length))
            : DuplicateDecision(all);
        cancellation.check();
        if (answer == null) throw const DownloadCancelled();
        if (answer.forAll) all = answer.choice;
        if (answer.choice == DuplicateChoice.existing) continue;
        for (final v in found) {
          remove(v);
        }
      }
      add(DuplicateVersion(track, incomingIndex: i, extraKeys: incomingKeys));
    }
    final positions = active
        .where((v) => !v.fromPlaylist)
        .map((v) => v.incomingIndex!)
        .toSet();
    return DuplicatePlan([
      for (var i = 0; i < input.length; i++)
        if (positions.contains(i)) input[i]
    ], [
      for (final v in original)
        if (!active.contains(v)) v.track
    ], input.length - positions.length);
  }

  static Set<String> keys(Track t) {
    final isrc = t.isrc.toUpperCase().replaceAll('-', '');
    String text(String v) => foldTrackText(v)
        .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
        .trim();
    final title = text(t.title), artist = text(t.artist);
    return {
      if (RegExp(r'^[A-Z]{2}[A-Z0-9]{3}[0-9]{7}$').hasMatch(isrc)) 'isrc:$isrc',
      if (title.isNotEmpty && artist.isNotEmpty) 'name:$title\u0000$artist',
      ...referenceKeys(t.sourceUrl),
      ...referenceKeys(t.manualUrl),
      ...referenceKeys(t.mediaUrl),
      ...nativeKeys(t.sourceKind, t.sourceId, t.sourceUrl),
    };
  }

  static Set<String> nativeKeys(SourceKind kind, String id, String reference) {
    if (id.isEmpty) return {};
    final platform = switch (kind) {
      SourceKind.deezerFull => 'deezer',
      SourceKind.youtube || SourceKind.youtubeMusic => 'youtube',
      SourceKind.soundcloud => 'soundcloud',
      _ => '',
    };
    if (platform.isNotEmpty) return {'ref:$platform:$id'};
    if (kind == SourceKind.none) {
      try {
        final link = MusicLink.parse(reference);
        if (link.kind == MusicLinkKind.spotify) return {'ref:spotify:$id'};
      } on FormatException {/* Unknown platform cannot identify a recording. */}
    }
    return {};
  }

  static Set<String> referenceKeys(String raw) {
    if (raw.isEmpty) return {};
    try {
      final link = MusicLink.parse(raw);
      final platform = [MusicLinkKind.youtube, MusicLinkKind.youtubeMusic]
              .contains(link.kind)
          ? 'youtube'
          : link.kind.name;
      return {'ref:$platform:${link.id.isEmpty ? link.url : link.id}'};
    } on FormatException {
      return {};
    }
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../domain/models.dart';
import 'artwork_thumbnail.dart';
import 'playlist_palette.dart';
import 'track_source_cell.dart';
import '../../player/presentation/player_scope.dart';

class TrackRow extends StatelessWidget {
  const TrackRow(
      {super.key,
      required this.track,
      required this.focused,
      required this.compact,
      required this.selectionEnabled,
      required this.onTap,
      required this.onContextMenu,
      required this.onSelect,
      this.accent});
  final Track track;
  final bool focused, compact, selectionEnabled;
  final VoidCallback onTap;
  final ValueChanged<Offset> onContextMenu;
  final ValueChanged<bool> onSelect;
  final Color? accent;
  @override
  Widget build(BuildContext context) {
    final t = track;
    final ink = playlistInk(accent);
    return Material(
        key: ValueKey('track-row-${t.id}'),
        color: t.needsReview
            ? playlistReviewSurface(accent, selected: focused || t.selected)
            : accent != null
                ? Color.alphaBlend(
                    accent!.withAlpha(focused
                        ? 54
                        : t.selected
                            ? 35
                            : 12),
                    Colors.white)
                : focused
                    ? Color.lerp(AppColors.accentSoft, AppColors.accent, .12)
                    : t.selected
                        ? AppColors.accentSoft
                        : Colors.white,
        child: InkWell(
            onTap: onTap,
            onSecondaryTapUp: (details) =>
                onContextMenu(details.globalPosition),
            child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                    border: Border(
                        left: BorderSide(
                            width: 3,
                            color: t.needsReview ? ink : Colors.transparent),
                        bottom: const BorderSide(color: AppColors.line))),
                child: Row(children: [
                  SizedBox(
                      width: 36,
                      child: Checkbox(
                          semanticLabel: 'Selecionar ${t.displayTitle}',
                          value: t.selected,
                          activeColor: ink,
                          onChanged: !selectionEnabled
                              ? null
                              : (v) => onSelect(v ?? false))),
                  Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: ArtworkThumbnail(
                          reference: t.resolvedCoverUrl.isEmpty
                              ? t.coverUrl
                              : t.resolvedCoverUrl,
                          audioPath: t.localPath,
                          borderColor: accent,
                          placeholderColor: accent == null
                              ? AppColors.accentSoft
                              : playlistReviewSurface(accent),
                          size: AppDensity.of(context).desktop
                              ? AppDensity.of(context).artwork
                              : compact
                                  ? 36
                                  : 44)),
                  Expanded(
                      child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${t.position}. ${t.displayTitle}',
                                    maxLines:
                                        AppDensity.of(context).desktop ? 1 : 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: AppDensity.of(context).body,
                                        fontWeight: FontWeight.w600,
                                        color: t.needsReview
                                            ? ink
                                            : AppColors.ink)),
                                Text(t.artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: AppDensity.of(context).desktop
                                            ? 11
                                            : 12,
                                        color: AppColors.muted)),
                              ]))),
                  SizedBox(
                      width: compact ? 88 : 104,
                      child: TrackSourceCell(
                          track: t, compact: compact, accent: accent)),
                  if (!compact) ...[
                    SizedBox(
                        width: 56,
                        child: Text(formatDuration(t.durationMs),
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.muted))),
                    SizedBox(
                        width: 108,
                        child: Text(
                            t.needsReview ? 'Conferir' : t.matchStatus.label,
                            style: TextStyle(
                                fontSize: 11,
                                color: t.needsReview ? ink : AppColors.muted,
                                fontWeight: t.needsReview
                                    ? FontWeight.w700
                                    : FontWeight.w400))),
                  ],
                  if (PlayerScope.of(context) != null)
                    IconButton(
                        tooltip: PlayerScope.of(context)!.canListenTrack(t)
                            ? PlayerScope.of(context)!.trackListenLabel(t)
                            : 'Abrir referência',
                        onPressed: () => unawaited(
                            PlayerScope.of(context)!.canListenTrack(t)
                                ? PlayerScope.of(context)!.listenTrack(t)
                                : PlayerScope.of(context)!.openReference(
                                    PlayerScope.of(context)!
                                        .library
                                        .referenceFor(t))),
                        icon: Icon(
                            PlayerScope.of(context)!.canListenTrack(t)
                                ? Icons.play_arrow_rounded
                                : Icons.open_in_new_rounded,
                            color: ink,
                            size: AppDensity.of(context).icon)),
                ]))));
  }
}

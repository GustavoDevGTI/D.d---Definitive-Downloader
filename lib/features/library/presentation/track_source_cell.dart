import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../domain/models.dart';
import 'track_download_badge.dart';
import 'playlist_palette.dart';

class TrackSourceCell extends StatelessWidget {
  const TrackSourceCell(
      {super.key, required this.track, required this.compact, this.accent});
  final Track track;
  final bool compact;
  final Color? accent;
  @override
  Widget build(BuildContext context) {
    final source = track.sourceKind.musicProviderName ?? track.sourceLabel;
    final ink = playlistInk(accent);
    return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Tooltip(
              message: source,
              child: Row(children: [
                Flexible(
                    child: Text(source,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.muted))),
                if (track.hasManualSource)
                  Tooltip(
                      message: 'Fonte manual definida',
                      child: Icon(Icons.link, size: 13, color: ink)),
              ])),
          if (compact)
            Row(children: [
              Text(formatDuration(track.durationMs),
                  style: const TextStyle(fontSize: 11, color: AppColors.muted)),
              const SizedBox(width: 5),
              Tooltip(
                  message: track.needsReview
                      ? 'Conferir correspondência'
                      : track.matchStatus.label,
                  child: Icon(
                      track.needsReview
                          ? Icons.flag_outlined
                          : Icons.check_rounded,
                      size: 14,
                      color: track.needsReview ? ink : AppColors.muted)),
            ]),
          const SizedBox(height: 2),
          TrackDownloadBadge(track: track, accent: accent),
        ]);
  }
}

import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../domain/models.dart';
import 'artwork_thumbnail.dart';
import 'track_download_badge.dart';

class TrackIdentity extends StatelessWidget {
  const TrackIdentity({super.key, required this.track});
  final Track track;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final beside = box.maxWidth >= 340 &&
            MediaQuery.textScalerOf(context).scale(17) <= 22;
        final cover = ArtworkThumbnail(
            reference: track.resolvedCoverUrl.isEmpty
                ? track.coverUrl
                : track.resolvedCoverUrl,
            audioPath: track.localPath,
            size: 112);
        final identity = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                beside ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              Text(track.displayTitle,
                  textAlign: beside ? TextAlign.start : TextAlign.center,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w600)),
              const SizedBox(height: 5),
              Text(track.artist,
                  textAlign: beside ? TextAlign.start : TextAlign.center,
                  style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 8),
              TrackDownloadBadge(track: track),
            ]);
        return beside
            ? Row(children: [
                cover,
                const SizedBox(width: 16),
                Expanded(child: identity),
              ])
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Center(child: cover),
                const SizedBox(height: 12),
                identity,
              ]);
      });
}

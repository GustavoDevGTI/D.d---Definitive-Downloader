import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../core/platform/platform_services.dart';
import '../domain/models.dart';
import 'playlist_palette.dart';

class TrackDownloadBadge extends StatefulWidget {
  const TrackDownloadBadge({super.key, required this.track, this.accent});
  final Track track;
  final Color? accent;
  @override
  State<TrackDownloadBadge> createState() => _TrackDownloadBadgeState();
}

class _TrackDownloadBadgeState extends State<TrackDownloadBadge> {
  Future<bool>? _exists;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _exists = widget.track.localPath.isEmpty
        ? null
        : createPlatformFiles().fileExists(widget.track.localPath);
  }

  @override
  void didUpdateWidget(TrackDownloadBadge old) {
    super.didUpdateWidget(old);
    if (old.track.localPath != widget.track.localPath ||
        old.track.status != widget.track.status) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
      future: _exists,
      builder: (context, snapshot) {
        final t = widget.track;
        final saved =
            t.localPath.isNotEmpty || t.status == TrackStatus.completed;
        final missing = saved && (snapshot.data == false || snapshot.hasError);
        final text = missing
            ? 'Arquivo indisponível'
            : saved
                ? 'Baixada'
                : switch (t.status) {
                    TrackStatus.downloading => 'Baixando',
                    TrackStatus.failed => 'Falha no download',
                    _ => 'Não baixada'
                  };
        final color = missing || (!saved && t.status == TrackStatus.failed)
            ? playlistInk(widget.accent)
            : saved
                ? AppColors.success
                : AppColors.muted;
        return Tooltip(
            message: text,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                  missing
                      ? Icons.link_off
                      : saved
                          ? Icons.download_done_rounded
                          : Icons.download_outlined,
                  size: 13,
                  color: color),
              const SizedBox(width: 3),
              Flexible(
                  child: Text(text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, color: color))),
            ]));
      });
}

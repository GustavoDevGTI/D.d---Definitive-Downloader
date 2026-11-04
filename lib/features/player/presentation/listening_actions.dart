import 'dart:async';
import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../library/domain/models.dart';
import '../../library/application/library_controller.dart';
import '../../library/presentation/track_review_actions.dart';
import 'player_scope.dart';

class ListeningActions extends StatelessWidget {
  const ListeningActions(
      {super.key, required this.track, this.candidate, this.library});
  final Track track;
  final Candidate? candidate;
  final LibraryController? library;
  @override
  Widget build(BuildContext context) {
    final player = PlayerScope.of(context);
    if (player == null) return const SizedBox.shrink();
    final version = candidate;
    final reference = version == null
        ? player.library.referenceFor(track)
        : player.library.referenceForCandidate(version);
    final listen = version == null
        ? player.canListenTrack(track)
        : player.canListenCandidate(track, version);
    final canUse = version != null &&
        library != null &&
        !library!.busy &&
        track.status != TrackStatus.completed &&
        (!track.hasManualSource || track.redownloadReview) &&
        (library!.music == null
            ? version.previewUrl.isNotEmpty
            : library!.music!.canUse(version));
    Widget action(String label, IconData icon, VoidCallback? onPressed,
            {bool use = false}) =>
        IconButton(
            tooltip: label,
            onPressed: onPressed,
            style: IconButton.styleFrom(
                foregroundColor:
                    use ? AppColors.success : AppColors.accentActive,
                hoverColor: AppColors.accentSoft,
                minimumSize: const Size(36, 36),
                padding: const EdgeInsets.all(6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6))),
            icon: Icon(icon, size: 18));
    return Wrap(spacing: 3, children: [
      if (listen)
        TextButton.icon(
            style: TextButton.styleFrom(
                foregroundColor: AppColors.accentActive,
                minimumSize: const Size(36, 36),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                textStyle: const TextStyle(fontSize: 11)),
            icon: const Icon(Icons.play_arrow_rounded, size: 18),
            label: Text(version == null
                ? player.trackListenLabel(track)
                : player.candidateListenLabel(track, version)),
            onPressed: () => unawaited(version == null
                ? player.listenTrack(track)
                : player.listenCandidate(track, version))),
      if (reference.isNotEmpty) ...[
        action('Abrir referência', Icons.open_in_new_rounded,
            () => unawaited(player.openReference(reference))),
        action('Copiar link', Icons.copy_rounded,
            () => unawaited(player.copyReference(reference))),
      ],
      if (version != null)
        action(
            'Usar esta versão',
            Icons.check_rounded,
            canUse
                ? () => unawaited(
                    confirmCandidateVersion(context, library!, choice: version))
                : null,
            use: true),
    ]);
  }
}

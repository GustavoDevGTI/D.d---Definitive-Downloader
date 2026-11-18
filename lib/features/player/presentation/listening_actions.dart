import 'dart:async';
import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../library/domain/models.dart';
import 'player_scope.dart';

class ListeningActions extends StatelessWidget {
  const ListeningActions(
      {super.key, required this.track, this.candidate, this.accent});
  final Track track;
  final Candidate? candidate;
  final Color? accent;
  @override
  Widget build(BuildContext context) {
    final player = PlayerScope.of(context);
    if (player == null) return const SizedBox.shrink();
    final ink = accent ?? AppColors.accentActive;
    final version = candidate;
    final reference = version == null
        ? player.library.referenceFor(track)
        : player.library.referenceForCandidate(version);
    final listen = version == null
        ? player.canListenTrack(track)
        : player.canListenCandidate(track, version);
    Widget action(String label, IconData icon, VoidCallback onPressed) =>
        IconButton(
            tooltip: label,
            onPressed: onPressed,
            style: IconButton.styleFrom(
                foregroundColor: ink,
                hoverColor:
                    accent == null ? AppColors.accentSoft : ink.withAlpha(24),
                minimumSize: const Size(36, 36),
                fixedSize: const Size(36, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.all(6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6))),
            icon: Icon(icon, size: 18));
    return Wrap(
        spacing: 3,
        alignment: WrapAlignment.start,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (listen)
            TextButton.icon(
                style: TextButton.styleFrom(
                    foregroundColor: ink,
                    minimumSize: const Size(36, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    fixedSize: const Size.fromHeight(36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
        ]);
  }
}

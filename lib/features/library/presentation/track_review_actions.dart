import 'dart:async';
import 'package:flutter/material.dart';
import '../../../app/app_notice.dart';
import '../../../app/theme.dart';
import '../application/library_controller.dart';
import '../domain/models.dart';
import '../../workspace/presentation/download_action_button.dart';
import 'manual_source_input.dart';
import '../../connections/presentation/music_connection_actions.dart';

class TrackReviewActions extends StatelessWidget {
  const TrackReviewActions(
      {super.key,
      required this.controller,
      this.accent = AppColors.accentActive});
  final LibraryController controller;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final c = controller, track = c.focused, candidate = c.selectedCandidate;
    if (track == null) return const SizedBox.shrink();
    if (track.status == TrackStatus.completed) {
      return DownloadActionButton(
          label: 'Ver fonte vinculada',
          icon: Icons.link,
          color: accent,
          onPressed: () => unawaited(showAppNotice(context,
              title: 'Fonte da faixa concluída',
              message:
                  '${track.sourceKind.musicProviderName ?? track.sourceLabel}\n${track.hasManualSource ? track.manualUrl : track.mediaUrl}')));
    }
    return Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          MusicConnectionActions(
              onConnected: !track.hasManualSource || track.redownloadReview
                  ? () => c.search('${track.artist} ${track.title}')
                  : null),
          if (!track.hasManualSource || track.redownloadReview) ...[
            if (candidate != null)
              FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 48),
                      visualDensity: VisualDensity.standard,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10))),
                  icon: const Icon(Icons.check_rounded, size: 21),
                  label: Text(candidate.isVideoRecording
                      ? 'Aprovar videoclipe'
                      : 'Usar esta versão'),
                  onPressed: c.busy ||
                          !(c.music?.canUse(candidate) ??
                              candidate.previewUrl.isNotEmpty)
                      ? null
                      : () => unawaited(_confirm(context)))
            else
              DownloadActionButton(
                  label: track.redownloadReview
                      ? 'Usar fonte anterior'
                      : 'Confirmar correspondência',
                  icon: Icons.check_rounded,
                  color: AppColors.success,
                  onPressed: c.busy ||
                          (track.redownloadReview &&
                              !track.hasDownloadableSource) ||
                          track.sourceKind == SourceKind.none
                      ? null
                      : () => unawaited(_confirm(context))),
            DownloadActionButton(
                label: 'Marcar para revisão',
                icon: Icons.flag_outlined,
                color: accent,
                onPressed: c.busy || track.needsReview
                    ? null
                    : () => unawaited(c.reviewSource())),
          ],
          DownloadActionButton(
              label: track.hasManualSource
                  ? 'Editar link manual'
                  : 'Informar link manualmente',
              icon: track.hasManualSource
                  ? Icons.edit_outlined
                  : Icons.add_link_rounded,
              color: AppColors.navigation,
              onPressed: c.busy ? null : () => unawaited(_manual(context))),
          if (track.hasManualSource) ...[
            const SizedBox(width: 6),
            DownloadActionButton(
                label: 'Remover vínculo manual',
                icon: Icons.link_off,
                color: AppColors.accent,
                onPressed:
                    c.busy ? null : () => unawaited(c.removeManualSource())),
          ],
        ]);
  }

  Future<void> _manual(BuildContext context) async {
    final track = controller.focused;
    if (track == null) return;
    final choice = await showDialog<ManualSourceChoice>(
        context: context, builder: (_) => ManualSourceInput(track: track));
    if (choice != null &&
        context.mounted &&
        controller.focused?.id == track.id) {
      await controller.setManualSource(choice.url, choice.mode);
    }
  }

  Future<void> _confirm(BuildContext context) async {
    final c = controller, candidate = controller.selectedCandidate;
    if (candidate == null) {
      await c.confirmSource();
      return;
    }
    if (c.music == null) {
      await c.usePreview(candidate);
      return;
    }
    var approved = false;
    if (candidate.isVideoRecording) {
      final id = c.focused?.id;
      approved = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                      title: const Text('Usar áudio deste videoclipe?'),
                      content: SingleChildScrollView(
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(candidate.title),
                            const SizedBox(height: 8),
                            Text(candidate.artist),
                            const SizedBox(height: 8),
                            Text(
                                'Duração desta versão: ${formatDuration(candidate.durationMs)}'),
                            Text(
                                'Duração solicitada: ${formatDuration(c.focused?.durationMs)}'),
                            const SizedBox(height: 12),
                            SelectableText(candidate.pageUrl,
                                style: const TextStyle(fontSize: 12))
                          ])),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancelar')),
                        FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Aprovar esta versão'))
                      ])) ==
          true;
      if (!approved ||
          !context.mounted ||
          c.focused?.id != id ||
          c.selectedCandidate?.pageUrl != candidate.pageUrl) {
        return;
      }
    }
    await c.useMusicCandidate(candidate, approveVideo: approved);
  }
}

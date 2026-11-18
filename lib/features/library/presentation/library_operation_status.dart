import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../application/library_controller.dart';
import 'playlist_palette.dart';

class LibraryOperationStatus extends StatelessWidget {
  const LibraryOperationStatus({super.key, required this.controller});
  final LibraryController controller;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: Listenable.merge([controller, controller.transferUpdates]),
      builder: (context, _) => _content());
  Widget _content() {
    final c = controller;
    if (!c.downloading && !c.preparing && !c.importing) {
      return const SizedBox(height: 8);
    }
    final transfer = c.progress == null
        ? 'recebendo / processando'
        : '${(c.progress! * 100).round()}% recebidos';
    return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(4)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (c.downloading)
            _status(
                '${c.activeTitle} · $transfer', 'Parar downloads', c.cancel),
          if (c.importing) _status(c.message),
          if (c.preparing) _conference(),
        ]));
  }

  Widget _conference() {
    final c = controller;
    final progress = c.preparationProgress;
    final name = c.preparingCollection?.name;
    final rgb = c.preparingCollection?.themeColor;
    final ink = playlistInk(rgb == null ? null : Color(0xFF000000 | rgb));
    final status = c.preparationStatus.isEmpty
        ? 'Conferência na fila'
        : c.preparationStatus;
    final detail = [
      if (c.preparationStopping)
        'Parando…'
      else if (c.preparationPaused)
        'Pausada'
      else if (progress != null)
        _estimate(progress.remaining),
      if (c.waitingPreparations > 0) '${c.waitingPreparations} na fila',
    ].join(' · ');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(progress == null ? status : name ?? status,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          if (progress != null)
            Text('${progress.checked} de ${progress.total} faixas conferidas',
                style: TextStyle(
                    color: ink, fontSize: 13, fontWeight: FontWeight.w700)),
          if (detail.isNotEmpty)
            Text(detail,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: AppColors.muted)),
        ])),
        TextButton.icon(
            onPressed: c.preparationStopping ? null : c.togglePreparationPause,
            icon: Icon(
                c.preparationPaused
                    ? Icons.play_arrow_rounded
                    : Icons.pause_rounded,
                size: 18),
            label: Text(c.preparationPaused ? 'Retomar' : 'Pausar')),
        TextButton.icon(
            onPressed: c.preparationStopping ? null : c.cancelPreparation,
            icon: const Icon(Icons.stop_rounded, size: 18),
            label: const Text('Parar')),
      ]),
      if (progress != null) ...[
        const SizedBox(height: 5),
        LinearProgressIndicator(
            value: progress.fraction,
            minHeight: 4,
            backgroundColor: AppColors.line,
            color: ink,
            borderRadius: BorderRadius.circular(2),
            semanticsLabel: 'Progresso da conferência'),
      ]
    ]);
  }

  String _estimate(Duration? remaining) {
    if (remaining == null) return 'Calculando tempo restante…';
    if (remaining == Duration.zero) return 'Conferência concluída';
    if (remaining.inMinutes == 0) return 'Menos de 1 min restante';
    final minutes = (remaining.inSeconds / 60).ceil();
    if (minutes < 60) return '≈ $minutes min restantes';
    return '≈ ${minutes ~/ 60} h ${minutes % 60} min restantes';
  }

  Widget _status(String message, [String? label, VoidCallback? onStop]) =>
      Row(children: [
        Expanded(
            child: Text(message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: AppColors.muted))),
        if (onStop != null)
          IconButton(
              tooltip: label,
              onPressed: onStop,
              icon: const Icon(Icons.stop_circle_outlined, size: 20)),
      ]);
}

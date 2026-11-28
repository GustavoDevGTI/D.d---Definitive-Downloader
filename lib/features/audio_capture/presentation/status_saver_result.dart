import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../../../app/theme.dart';
import '../../workspace/presentation/download_action_button.dart';
import '../../workspace/presentation/workspace_components.dart';
import '../application/status_saver_controller.dart';
import '../domain/status_saver.dart';

/// Statuses chosen in Status Saver, in the layout of the capture result.
class StatusSaverResult extends StatelessWidget {
  const StatusSaverResult(
      {super.key, required this.controller, required this.onSave});
  final StatusSaverController controller;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final density = AppDensity.of(context);
    final count = c.statuses.length;
    final selected = c.selected.length;
    final videos = c.statuses.where((status) => status.isVideo).length;
    final summary = [
      count == 1 ? '1 status' : '$count status',
      if (videos > 0) videos == 1 ? '1 vídeo' : '$videos vídeos',
      if (count - videos > 0)
        count - videos == 1 ? '1 áudio' : '${count - videos} áudios',
    ].join(' · ');
    return WorkspacePanel(
        key: const ValueKey('status-saver-result'),
        padding: EdgeInsets.all(density.panelInset),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: AppColors.accentSoft,
                    borderRadius: BorderRadius.circular(density.radius)),
                child: const Icon(Icons.history_toggle_off_rounded,
                    color: AppColors.accent)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text('Status do WhatsApp',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(summary,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.muted)),
                ])),
            IconButton(
                key: const ValueKey('status-saver-discard'),
                tooltip: 'Descartar status',
                onPressed: c.busy ? null : c.discard,
                icon: const Icon(Icons.close, color: AppColors.secondary)),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.icon(
                key: const ValueKey('status-saver-save'),
                onPressed: c.busy || selected == 0 ? null : onSave,
                style: FilledButton.styleFrom(
                    backgroundColor: DownloadActionColors.start,
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.standard,
                    minimumSize: Size(0, density.control)),
                icon: const Icon(Icons.library_music_rounded, size: 20),
                label: Text(selected > 1
                    ? 'Salvar $selected áudios como playlist'
                    : 'Salvar áudio como playlist')),
          ]),
          if (c.saving) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(
                minHeight: 3,
                color: AppColors.accent,
                backgroundColor: AppColors.accentSoft),
            if (c.progress.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(c.progress,
                  style: const TextStyle(fontSize: 11, color: AppColors.muted)),
            ],
          ],
          const SizedBox(height: 12),
          const Divider(height: 1),
          Row(children: [
            Checkbox(
                semanticLabel: 'Selecionar todos os status',
                value: selected == count
                    ? true
                    : selected == 0
                        ? false
                        : null,
                tristate: true,
                onChanged:
                    c.busy ? null : (_) => c.selectAll(selected != count)),
            Flexible(
                child: Text('$selected de $count selecionados',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(fontSize: 12, color: AppColors.muted))),
          ]),
          for (var i = 0; i < count; i++)
            _StatusRow(
                index: i,
                status: c.statuses[i],
                title: c.titles[i],
                controller: c),
        ]));
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow(
      {required this.index,
      required this.status,
      required this.title,
      required this.controller});
  final int index;
  final WhatsAppStatus status;
  final String title;
  final StatusSaverController controller;

  @override
  Widget build(BuildContext context) {
    final checked = controller.selected.contains(status.path);
    return DecoratedBox(
        key: ValueKey('status-${p.basename(status.path)}'),
        decoration: BoxDecoration(
            color: checked ? AppColors.accentSoft.withValues(alpha: .55) : null,
            border: const Border(top: BorderSide(color: AppColors.line))),
        child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Checkbox(
                  semanticLabel: 'Selecionar $title',
                  value: checked,
                  onChanged: controller.busy
                      ? null
                      : (value) =>
                          controller.select(status.path, value ?? false)),
              Icon(
                  status.isVideo
                      ? Icons.movie_outlined
                      : Icons.graphic_eq_rounded,
                  size: 20,
                  color: AppColors.secondary),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                        '${status.isVideo ? 'Vídeo' : 'Áudio'} · ${formatStatusBytes(status.bytes)}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.muted)),
                  ])),
            ])));
  }
}

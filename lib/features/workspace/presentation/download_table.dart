import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../../../app/theme.dart';
import '../../library/domain/models.dart';
import '../domain/workspace_models.dart';
import '../domain/download_columns.dart';
import 'column_resize_handle.dart';
import 'horizontal_table_viewport.dart';

class DownloadTable extends StatelessWidget {
  const DownloadTable(
      {super.key,
      required this.entries,
      required this.widths,
      required this.onResize,
      required this.onResizeEnd,
      required this.selection,
      required this.onSelect,
      required this.onSelectPage,
      this.activeId,
      this.progress,
      this.paused = false,
      required this.output});
  final List<DownloadEntry> entries;
  final List<double> widths;
  final void Function(int, double) onResize;
  final VoidCallback onResizeEnd;
  final Set<int> selection;
  final void Function(int, bool) onSelect;
  final ValueChanged<bool> onSelectPage;
  final int? activeId;
  final double? progress;
  final bool paused;
  final String output;
  @override
  Widget build(BuildContext context) => HorizontalTableViewport(
      width: widths.fold(0, (sum, value) => sum + value),
      child: Column(children: [
        _row([
          Checkbox(
              shape: const CircleBorder(),
              semanticLabel: 'Selecionar downloads da página',
              value: entries.isNotEmpty &&
                  entries.every((e) => selection.contains(e.track.id)),
              onChanged: (v) => onSelectPage(v ?? false)),
          for (final label in [
            'Nome',
            'Tamanho',
            'Servidor',
            'Status',
            'Velocidade',
            'Tempo restante',
            'Baixado',
            'Progresso',
            'Salvar em'
          ])
            Tooltip(
                message: switch (label) {
                  'Velocidade' => 'Medição de velocidade indisponível.',
                  'Tempo restante' => 'Estimativa de tempo indisponível.',
                  _ => label,
                },
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w500))),
        ], header: true),
        Expanded(
            child: ListView.builder(
                primary: false,
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final e = entries[index], t = e.track;
                  return _row([
                    Checkbox(
                        shape: const CircleBorder(),
                        semanticLabel: 'Selecionar download ${t.title}',
                        value: selection.contains(t.id),
                        onChanged: (v) => onSelect(t.id, v ?? false)),
                    Tooltip(
                        message:
                            '${t.localPath.isEmpty ? t.displayTitle : p.basename(t.localPath)} · ${e.collectionName} · Prioridade ${t.queuePriority}',
                        child: Text(
                            t.localPath.isEmpty
                                ? t.displayTitle
                                : p.basename(t.localPath),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11))),
                    const Text('—'),
                    Tooltip(
                        message:
                            t.sourceKind.musicProviderName ?? t.sourceLabel,
                        child: Text(
                            t.sourceKind.musicProviderName ?? t.sourceLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11))),
                    Tooltip(
                        message: t.error.isEmpty ? e.statusLabel : t.error,
                        child: Text(
                            t.id == activeId && paused
                                ? 'Pausado · 10 KiB/s'
                                : e.statusLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11))),
                    const Text('—'),
                    const Text('—'),
                    const Text('—'),
                    t.status == TrackStatus.completed
                        ? const Text('Concluído',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11))
                        : t.id == activeId
                            ? LinearProgressIndicator(
                                value: progress, minHeight: 6)
                            : const Text('—'),
                    Tooltip(
                        message: t.localPath.isEmpty
                            ? output
                            : p.dirname(t.localPath),
                        child: Text(
                            t.localPath.isEmpty
                                ? output
                                : p.dirname(t.localPath),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11))),
                  ], selected: selection.contains(t.id));
                })),
      ]));
  Widget _row(List<Widget> cells,
      {bool header = false, bool selected = false}) {
    return Container(
        constraints: BoxConstraints(minHeight: header ? 40 : 48),
        decoration: BoxDecoration(
            color: selected ? AppColors.accentSoft : Colors.white,
            border: const Border(bottom: BorderSide(color: AppColors.line))),
        child: Row(children: [
          for (var i = 0; i < cells.length; i++)
            SizedBox(
                width: widths[i],
                child: Stack(children: [
                  Padding(
                      padding: EdgeInsets.fromLTRB(
                          8, 6, header && i > 0 ? 22 : 8, 6),
                      child: cells[i]),
                  if (header && i > 0)
                    Positioned(
                        right: 0,
                        top: 0,
                        bottom: 0,
                        child: ColumnResizeHandle(
                            key: ValueKey(
                                'resize-download-${downloadColumns[i].key}'),
                            label: downloadColumns[i].label,
                            width: widths[i],
                            defaultWidth: downloadColumns[i].width,
                            minimumWidth: downloadColumns[i].minimum,
                            onResize: (value) => onResize(i, value),
                            onEnd: onResizeEnd)),
                ]))
        ]));
  }
}

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../../../app/theme.dart';
import '../../library/domain/models.dart';
import '../domain/workspace_models.dart';
import '../domain/download_columns.dart';
import 'column_resize_handle.dart';
import 'horizontal_table_viewport.dart';

class DownloadTable extends StatefulWidget {
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
  final ValueChanged<List<double>> onResize;
  final VoidCallback onResizeEnd;
  final Set<int> selection;
  final void Function(int, bool) onSelect;
  final ValueChanged<bool> onSelectPage;
  final int? activeId;
  final double? progress;
  final bool paused;
  final String output;
  @override
  State<DownloadTable> createState() => _DownloadTableState();
}

class _DownloadTableState extends State<DownloadTable> {
  static const _headerHeight = 56.0;
  static const _rail = 12.0;
  final _vertical = ScrollController();
  int? _hovered;
  @override
  void didUpdateWidget(covariant DownloadTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entries.firstOrNull?.track.id !=
        widget.entries.firstOrNull?.track.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _vertical.hasClients) _vertical.jumpTo(0);
      });
    }
  }

  @override
  void dispose() {
    _vertical.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final entries = widget.entries, selection = widget.selection;
        final onSelect = widget.onSelect, onSelectPage = widget.onSelectPage;
        final activeId = widget.activeId,
            progress = widget.progress,
            paused = widget.paused,
            output = widget.output;
        final widths = [...widget.widths];
        final total = widths.fold<double>(0, (sum, value) => sum + value);
        final available =
            (constraints.maxWidth - _rail).clamp(0, double.infinity);
        if (total < available) widths[1] += available - total;
        return ScrollbarTheme(
            data: ScrollbarThemeData(
                thickness: const WidgetStatePropertyAll(10),
                radius: const Radius.circular(6),
                thumbColor: WidgetStateProperty.resolveWith((states) =>
                    states.contains(WidgetState.hovered) ||
                            states.contains(WidgetState.dragged)
                        ? AppColors.accentActive
                        : AppColors.accent.withAlpha(210)),
                trackColor: const WidgetStatePropertyAll(AppColors.surface),
                trackBorderColor: const WidgetStatePropertyAll(AppColors.line)),
            child: RawScrollbar(
                thumbColor: AppColors.accent.withAlpha(210),
                trackColor: AppColors.surface,
                trackBorderColor: AppColors.line,
                thickness: 10,
                radius: const Radius.circular(6),
                controller: _vertical,
                thumbVisibility: true,
                trackVisibility: true,
                interactive: true,
                padding: const EdgeInsets.only(
                    top: _headerHeight, bottom: _rail, right: 1),
                notificationPredicate: (n) => n.metrics.axis == Axis.vertical,
                child: Padding(
                    padding: const EdgeInsets.only(right: _rail),
                    child: HorizontalTableViewport(
                        width:
                            widths.fold<double>(0, (sum, value) => sum + value),
                        child: Column(children: [
                          _row([
                            Checkbox(
                                shape: const CircleBorder(),
                                checkColor: AppColors.accentActive,
                                fillColor: WidgetStateProperty.resolveWith(
                                    (states) =>
                                        states.contains(WidgetState.selected)
                                            ? Colors.white
                                            : Colors.transparent),
                                semanticLabel: 'Selecionar downloads da página',
                                value: entries.isNotEmpty &&
                                    entries.every(
                                        (e) => selection.contains(e.track.id)),
                                side: const BorderSide(
                                    color: Colors.white70, width: 1.2),
                                onChanged: entries.isEmpty
                                    ? null
                                    : (v) => onSelectPage(v ?? false)),
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
                                    'Velocidade' =>
                                      'Medição de velocidade indisponível.',
                                    'Tempo restante' =>
                                      'Estimativa de tempo indisponível.',
                                    _ => label,
                                  },
                                  child: Text(label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white))),
                          ], widths: widths, header: true),
                          Expanded(
                              child: ListView.builder(
                                  key: const ValueKey('download-rows'),
                                  controller: _vertical,
                                  primary: false,
                                  itemCount: entries.length,
                                  itemBuilder: (context, index) {
                                    final e = entries[index], t = e.track;
                                    return MouseRegion(
                                        key: ValueKey('download-row-${t.id}'),
                                        onEnter: (_) =>
                                            setState(() => _hovered = t.id),
                                        onExit: (_) {
                                          if (_hovered == t.id) {
                                            setState(() => _hovered = null);
                                          }
                                        },
                                        child: _row([
                                          Checkbox(
                                              shape: const CircleBorder(),
                                              semanticLabel:
                                                  'Selecionar download ${t.title}',
                                              value: selection.contains(t.id),
                                              onChanged: (v) =>
                                                  onSelect(t.id, v ?? false)),
                                          Tooltip(
                                              message:
                                                  '${t.localPath.isEmpty ? t.displayTitle : p.basename(t.localPath)} · ${e.collectionName} · Prioridade ${t.queuePriority}',
                                              child: Text(
                                                  t.localPath.isEmpty
                                                      ? t.displayTitle
                                                      : p.basename(t.localPath),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                      fontSize: 12))),
                                          const Text('—'),
                                          Tooltip(
                                              message: t.sourceKind
                                                      .musicProviderName ??
                                                  t.sourceLabel,
                                              child: Text(
                                                  t.sourceKind
                                                          .musicProviderName ??
                                                      t.sourceLabel,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                      fontSize: 12))),
                                          Tooltip(
                                              message: t.error.isEmpty
                                                  ? e.statusLabel
                                                  : t.error,
                                              child: Text(
                                                  t.id == activeId && paused
                                                      ? 'Pausado · 10 KiB/s'
                                                      : e.statusLabel,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                      fontSize: 12))),
                                          const Text('—'),
                                          const Text('—'),
                                          const Text('—'),
                                          t.status == TrackStatus.completed
                                              ? const Text('Concluído',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style:
                                                      TextStyle(fontSize: 12))
                                              : t.id == activeId
                                                  ? LinearProgressIndicator(
                                                      value: progress,
                                                      minHeight: 6)
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
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                      fontSize: 12))),
                                        ],
                                            widths: widths,
                                            index: index,
                                            hovered: _hovered == t.id,
                                            selected:
                                                selection.contains(t.id) ||
                                                    t.id == activeId));
                                  })),
                          const SizedBox(height: _rail),
                        ])))));
      });
  Widget _row(List<Widget> cells,
      {required List<double> widths,
      bool header = false,
      bool selected = false,
      bool hovered = false,
      int index = 0}) {
    return Container(
        key: header ? const ValueKey('download-table-header') : null,
        constraints: const BoxConstraints(minHeight: 56),
        decoration: BoxDecoration(
            color: header
                ? AppColors.accentActive
                : selected
                    ? AppColors.accentSoft
                    : hovered
                        ? AppColors.accentSoft.withAlpha(190)
                        : index.isOdd
                            ? Color.alphaBlend(
                                AppColors.accentSoft.withAlpha(100),
                                Colors.white)
                            : Colors.white,
            border: const Border(bottom: BorderSide(color: AppColors.line))),
        child: Row(children: [
          for (var i = 0; i < cells.length; i++)
            SizedBox(
                width: widths[i],
                child: Stack(children: [
                  Padding(
                      padding: EdgeInsets.fromLTRB(
                          8, 2, header && i > 0 ? 22 : 8, 2),
                      child: cells[i]),
                  if (header && i > 0 && i < cells.length - 1)
                    Positioned(
                        right: 0,
                        top: 0,
                        bottom: 0,
                        child: _resizeHandle(i, widths)),
                ]))
        ]));
  }

  Widget _resizeHandle(int index, List<double> widths) {
    final total = widths[index] + widths[index + 1];
    final minimum = math.max(downloadColumns[index].minimum, total - 1200);
    const maximum = 1200.0;
    return ColumnResizeHandle(
        key: ValueKey('resize-download-${downloadColumns[index].key}'),
        label:
            '${downloadColumns[index].label} e ${downloadColumns[index + 1].label}',
        width: widths[index],
        defaultWidth: downloadColumns[index].width,
        minimumWidth: minimum,
        maximumWidth: maximum,
        color: Colors.white70,
        onResize: (value) {
          // Materialize the displayed widths together so automatic Name growth
          // cannot counteract the pointer movement on compact layouts.
          final left = value.clamp(minimum, maximum);
          widget.onResize([...widths]
            ..[index] = left
            ..[index + 1] =
                math.max(downloadColumns[index + 1].minimum, total - left));
        },
        onEnd: widget.onResizeEnd);
  }
}

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../../../app/theme.dart';
import '../../library/domain/models.dart';
import '../domain/workspace_models.dart';
import '../domain/download_columns.dart';
import '../../downloads/transfer_progress.dart';
import 'column_resize_handle.dart';

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
      this.sort,
      this.descending = false,
      this.onSort,
      this.activeId,
      this.progress,
      this.transfer,
      this.paused = false,
      required this.output});
  final List<DownloadEntry> entries;
  final List<double> widths;
  final ValueChanged<List<double>> onResize;
  final VoidCallback onResizeEnd;
  final Set<int> selection;
  final void Function(int, bool) onSelect;
  final ValueChanged<bool> onSelectPage;
  final DownloadSort? sort;
  final bool descending;
  final ValueChanged<DownloadSort>? onSort;
  final int? activeId;
  final double? progress;
  final TransferProgress? transfer;
  final bool paused;
  final String output;
  @override
  State<DownloadTable> createState() => _DownloadTableState();
}

class _DownloadTableState extends State<DownloadTable> {
  static const _headerHeight = 56.0;
  static const _rail = 12.0;
  final _vertical = ScrollController();
  final _horizontal = ScrollController();
  final _headerHorizontal = ScrollController();
  bool _syncing = false;
  @override
  void initState() {
    super.initState();
    _horizontal
        .addListener(() => _syncHorizontal(_horizontal, _headerHorizontal));
    _headerHorizontal
        .addListener(() => _syncHorizontal(_headerHorizontal, _horizontal));
  }

  void _syncHorizontal(ScrollController from, ScrollController to) {
    if (_syncing ||
        !from.hasClients ||
        !to.hasClients ||
        !to.position.hasContentDimensions) {
      return;
    }
    final offset = from.offset
        .clamp(to.position.minScrollExtent, to.position.maxScrollExtent);
    if ((to.offset - offset).abs() < .01) return;
    _syncing = true;
    try {
      to.jumpTo(offset);
    } finally {
      _syncing = false;
    }
  }

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
    _horizontal.dispose();
    _headerHorizontal.dispose();
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
            child: ScrollConfiguration(
                behavior:
                    ScrollConfiguration.of(context).copyWith(scrollbars: false),
                child: Stack(fit: StackFit.expand, children: [
                  const Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: _headerHeight,
                      child: ColoredBox(color: AppColors.navigation)),
                  Scrollbar(
                      controller: _horizontal,
                      thumbVisibility: true,
                      notificationPredicate: (n) =>
                          n.metrics.axis == Axis.horizontal,
                      child: Column(children: [
                        Padding(
                            padding: const EdgeInsets.only(right: _rail),
                            child: SizedBox(
                                height: _headerHeight,
                                child: SingleChildScrollView(
                                    key: const ValueKey(
                                        'download-horizontal-header'),
                                    controller: _headerHorizontal,
                                    scrollDirection: Axis.horizontal,
                                    child: SizedBox(
                                        width: widths.fold<double>(
                                            0, (sum, w) => sum + w),
                                        child: _row([
                                          Checkbox(
                                              shape: const CircleBorder(),
                                              checkColor: AppColors.navigation,
                                              fillColor: WidgetStateProperty.resolveWith(
                                                  (states) => states.contains(
                                                          WidgetState.selected)
                                                      ? Colors.white
                                                      : Colors.transparent),
                                              semanticLabel:
                                                  'Selecionar downloads da página',
                                              value: entries.isNotEmpty &&
                                                  entries.every((e) => selection
                                                      .contains(e.track.id)),
                                              side: const BorderSide(
                                                  color: Colors.white70,
                                                  width: 1.2),
                                              onChanged: entries.isEmpty
                                                  ? null
                                                  : (v) =>
                                                      onSelectPage(v ?? false)),
                                          for (var i = 1;
                                              i < downloadColumns.length;
                                              i++)
                                            _headerCell(i),
                                        ], widths: widths, header: true))))),
                        Expanded(
                            child: RawScrollbar(
                                controller: _vertical,
                                thumbVisibility: true,
                                trackVisibility: true,
                                interactive: true,
                                thumbColor: AppColors.accent.withAlpha(210),
                                trackColor: AppColors.surface,
                                trackBorderColor: AppColors.line,
                                thickness: 10,
                                radius: const Radius.circular(6),
                                padding: const EdgeInsets.only(right: 1),
                                notificationPredicate: (n) =>
                                    n.metrics.axis == Axis.vertical,
                                child: Padding(
                                    padding:
                                        const EdgeInsets.only(right: _rail),
                                    child: SingleChildScrollView(
                                        key: const ValueKey(
                                            'download-horizontal-rows'),
                                        controller: _horizontal,
                                        scrollDirection: Axis.horizontal,
                                        child: SizedBox(
                                            width: widths.fold<double>(
                                                0, (sum, w) => sum + w),
                                            child: ListView.builder(
                                                key: const ValueKey(
                                                    'download-rows'),
                                                controller: _vertical,
                                                primary: false,
                                                itemCount: entries.length,
                                                itemBuilder: (context, index) {
                                                  final e = entries[index],
                                                      t = e.track;
                                                  final live = t.id == activeId
                                                      ? widget.transfer
                                                      : null;
                                                  return MouseRegion(
                                                      key: ValueKey(
                                                          'download-row-${t.id}'),
                                                      onEnter: (_) => setState(
                                                          () =>
                                                              _hovered = t.id),
                                                      onExit: (_) {
                                                        if (_hovered == t.id) {
                                                          setState(() =>
                                                              _hovered = null);
                                                        }
                                                      },
                                                      child: _row([
                                                        Checkbox(
                                                            shape:
                                                                const CircleBorder(),
                                                            semanticLabel:
                                                                'Selecionar download ${t.title}',
                                                            value: selection
                                                                .contains(t.id),
                                                            onChanged: (v) =>
                                                                onSelect(
                                                                    t.id,
                                                                    v ??
                                                                        false)),
                                                        Tooltip(
                                                            message:
                                                                '${t.downloadName} · ${e.collectionName}${t.localPath.isEmpty ? '' : '\n${t.localPath}'}',
                                                            child: Column(
                                                                mainAxisSize:
                                                                    MainAxisSize
                                                                        .min,
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .start,
                                                                children: [
                                                                  Text(t.displayTitle,
                                                                      maxLines:
                                                                          1,
                                                                      overflow:
                                                                          TextOverflow
                                                                              .ellipsis,
                                                                      style: const TextStyle(
                                                                          fontSize:
                                                                              12)),
                                                                  if (t
                                                                      .downloadArtist
                                                                      .isNotEmpty)
                                                                    Text(t.downloadArtist,
                                                                        maxLines:
                                                                            1,
                                                                        overflow:
                                                                            TextOverflow
                                                                                .ellipsis,
                                                                        style: const TextStyle(
                                                                            fontSize:
                                                                                11,
                                                                            color:
                                                                                AppColors.muted)),
                                                                ])),
                                                        _metric(
                                                            e.fileBytes != null
                                                                ? _bytes(e
                                                                    .fileBytes!)
                                                                : live?.total ==
                                                                        null
                                                                    ? '—'
                                                                    : '${live!.estimatedTotal ? '≈ ' : ''}${_bytes(live.total!)}',
                                                            e.fileBytes != null
                                                                ? 'Tamanho do arquivo salvo.'
                                                                : 'Tamanho da transferência; ≈ indica estimativa.'),
                                                        Tooltip(
                                                            message: t
                                                                    .sourceKind
                                                                    .musicProviderName ??
                                                                t.sourceLabel,
                                                            child: Text(
                                                                t.sourceKind
                                                                        .musicProviderName ??
                                                                    t
                                                                        .sourceLabel,
                                                                maxLines: 1,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                                style: const TextStyle(
                                                                    fontSize:
                                                                        12))),
                                                        Tooltip(
                                                            message: t.error
                                                                    .isEmpty
                                                                ? e.statusLabel
                                                                : t.error,
                                                            child: Text(
                                                                t.id == activeId &&
                                                                        paused
                                                                    ? 'Pausado · 10 KiB/s'
                                                                    : e
                                                                        .statusLabel,
                                                                maxLines: 1,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                                style: const TextStyle(
                                                                    fontSize:
                                                                        12))),
                                                        _metric(
                                                            live?.bytesPerSecond ==
                                                                        null ||
                                                                    paused ||
                                                                    live!
                                                                        .processing
                                                                ? '—'
                                                                : '${_bytes(live.bytesPerSecond!.round())}/s',
                                                            'Velocidade medida nesta transferência.'),
                                                        _metric(
                                                            live?.processing ==
                                                                    true
                                                                ? 'Processando'
                                                                : paused ||
                                                                        live?.remaining ==
                                                                            null
                                                                    ? '—'
                                                                    : _remaining(
                                                                        live!
                                                                            .remaining!),
                                                            'Estimativa para receber o áudio; validação e capa acontecem depois.'),
                                                        _metric(
                                                            live != null
                                                                ? _bytes(live
                                                                    .received)
                                                                : e.fileBytes !=
                                                                        null
                                                                    ? _bytes(e
                                                                        .fileBytes!)
                                                                    : '—',
                                                            live != null
                                                                ? 'Dados de áudio recebidos nesta tentativa.'
                                                                : 'Dados no arquivo final salvo; podem diferir da transferência original.'),
                                                        t.status ==
                                                                TrackStatus
                                                                    .completed
                                                            ? const Text(
                                                                'Concluído',
                                                                maxLines: 1,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                                style: TextStyle(
                                                                    fontSize:
                                                                        12))
                                                            : t.id == activeId
                                                                ? LinearProgressIndicator(
                                                                    value:
                                                                        progress,
                                                                    minHeight:
                                                                        6)
                                                                : const Text(
                                                                    '—'),
                                                        Tooltip(
                                                            message: e.downloadedAt ==
                                                                    null
                                                                ? 'Sem registro de conclusão.'
                                                                : 'Concluído em ${_completionLabel(e.downloadedAt!)} (horário local)',
                                                            child: Text(
                                                                e.downloadedAt ==
                                                                        null
                                                                    ? '—'
                                                                    : _completionLabel(e
                                                                        .downloadedAt!),
                                                                maxLines: 1,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                                style: const TextStyle(
                                                                    fontSize:
                                                                        12))),
                                                        Tooltip(
                                                            message: t.localPath
                                                                    .isEmpty
                                                                ? output
                                                                : p.dirname(t
                                                                    .localPath),
                                                            child: Text(
                                                                t.localPath
                                                                        .isEmpty
                                                                    ? output
                                                                    : p.dirname(t
                                                                        .localPath),
                                                                maxLines: 1,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                                style: const TextStyle(
                                                                    fontSize:
                                                                        12))),
                                                      ],
                                                          widths: widths,
                                                          index: index,
                                                          hovered:
                                                              _hovered == t.id,
                                                          selected: selection
                                                                  .contains(
                                                                      t.id) ||
                                                              t.id ==
                                                                  activeId));
                                                })))))),
                        const SizedBox(height: _rail),
                      ])),
                ])));
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
                ? AppColors.navigation
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
                key: header
                    ? ValueKey('download-column-${downloadColumns[i].key}')
                    : null,
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

  String _completionLabel(DateTime date) {
    final local = date.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
  }

  Widget _metric(String text, String description) => Tooltip(
      message: '$text · $description',
      child: Text(text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12)));

  String _bytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KiB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MiB';
  }

  String _remaining(Duration duration) {
    final seconds = duration.inSeconds;
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${seconds ~/ 60}min ${seconds % 60}s';
    return '${seconds ~/ 3600}h ${(seconds % 3600) ~/ 60}min';
  }

  Widget _headerCell(int index) {
    final label = downloadColumns[index].label;
    final sort = DownloadSort.forColumn(index);
    final selected = sort != null && widget.sort == sort;
    const style = TextStyle(
        fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white);
    final text =
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
    if (sort == null) {
      return Tooltip(
          message: switch (index) {
            2 =>
              'Tamanho recebido da origem ou tamanho final do arquivo salvo.',
            5 => 'Velocidade medida durante a transferência.',
            6 =>
              'Tempo estimado de recebimento; processamento não tem estimativa.',
            7 =>
              'Durante a transferência: bytes recebidos. Concluído: bytes do arquivo salvo.',
            8 => 'Progresso sem ordenação disponível.',
            _ => '$label: medição indisponível.',
          },
          child: text);
    }
    return Tooltip(
        message:
            '$label · ${selected ? (widget.descending ? 'Decrescente' : 'Crescente') : 'Ordenar'}',
        child: TextButton(
          key: ValueKey('sort-download-${sort.name}'),
          onPressed: widget.onSort == null ? null : () => widget.onSort!(sort),
          style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 40),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)))
              .copyWith(
                  overlayColor:
                      WidgetStatePropertyAll(Colors.white.withAlpha(25))),
          child: LayoutBuilder(
              builder: (context, constraints) => Row(children: [
                    if (!selected || constraints.maxWidth >= 32)
                      Expanded(child: text),
                    if (selected)
                      Icon(
                          widget.descending
                              ? Icons.arrow_downward
                              : Icons.arrow_upward,
                          size: math.min(14, constraints.maxWidth),
                          color: Colors.white,
                          semanticLabel:
                              widget.descending ? 'Decrescente' : 'Crescente'),
                  ])),
        ));
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
        activeColor: Colors.white,
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

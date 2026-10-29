import 'dart:async';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../../../app/theme.dart';
import '../../library/domain/models.dart';
import '../application/workspace_controller.dart';
import '../domain/workspace_models.dart';
import 'workspace_components.dart';
import 'horizontal_table_viewport.dart';

class DownloadWorkspace extends StatelessWidget {
  const DownloadWorkspace(
      {super.key,
      required this.controller,
      required this.category,
      this.onCapture});
  final WorkspaceController controller;
  final ContentCategory category;
  final VoidCallback? onCapture;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: Listenable.merge([controller, controller.library]),
      builder: (context, child) {
        final c = controller, library = c.library;
        final enabled = category == ContentCategory.music;
        final page = enabled && c.category == category
            ? c.downloads
            : const DownloadPage([], 0);
        final selected =
            page.items.where((e) => c.selection.contains(e.track.id)).toList();
        final canStart = enabled &&
            !library.busy &&
            selected.any((e) =>
                e.track.canDownload &&
                [TrackStatus.ready, TrackStatus.failed]
                    .contains(e.track.status));
        final canCancel = library.downloading && enabled;
        final canPrioritize = selected.any((e) =>
            [TrackStatus.ready, TrackStatus.failed].contains(e.track.status));
        final content =
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Expanded(
                child: Text('Gerenciador de downloads',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
            Text('${page.total} registros',
                style: const TextStyle(fontSize: 11, color: AppColors.muted))
          ]),
          const SizedBox(height: 14),
          DownloadToolbar(
              paused: library.pauseMode,
              onStart: canStart || (enabled && library.pauseMode)
                  ? () => unawaited(c.start())
                  : null,
              onPause: canCancel ? library.togglePause : null,
              onCancel: canCancel ? library.cancel : null,
              onUp: canPrioritize &&
                      selected.any((e) => e.track.queuePriority < 4)
                  ? () => unawaited(c.changePriority(1))
                  : null,
              onDown: canPrioritize &&
                      selected.any((e) => e.track.queuePriority > -4)
                  ? () => unawaited(c.changePriority(-1))
                  : null,
              onOpen: selected.length == 1 &&
                      selected.single.track.localPath.isNotEmpty
                  ? () => unawaited(c.reveal(selected.single.track.localPath))
                  : null,
              onRetry: canStart &&
                      selected.any((e) => e.track.status == TrackStatus.failed)
                  ? () => unawaited(c.start(failedOnly: true))
                  : null,
              onRemove: enabled &&
                      selected
                          .any((e) => e.track.status != TrackStatus.downloading)
                  ? () => unawaited(_remove(context))
                  : null),
          const SizedBox(height: 10),
          if (c.message.isNotEmpty)
            Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(c.message,
                    style: const TextStyle(color: AppColors.ink))),
          Wrap(spacing: 4, runSpacing: 4, children: [
            for (final filter in DownloadFilter.values)
              TextButton(
                  style: TextButton.styleFrom(
                      shape: const StadiumBorder(),
                      foregroundColor: AppColors.muted,
                      backgroundColor: c.filter == filter
                          ? AppColors.accentSoft
                          : Colors.transparent),
                  onPressed: () => unawaited(c.setFilter(filter)),
                  child: Text(switch (filter) {
                    DownloadFilter.all => 'Todos',
                    DownloadFilter.downloading => 'Baixando',
                    DownloadFilter.queued => 'Na fila',
                    DownloadFilter.paused => 'Pausado',
                    DownloadFilter.completed => 'Concluído',
                    DownloadFilter.failed => 'Erro',
                  }))
          ]),
          const SizedBox(height: 10),
          Expanded(
              child: WorkspacePanel(
                  child: page.items.isEmpty
                      ? WorkspaceNotice(
                          title: enabled
                              ? 'Nenhum download neste filtro'
                              : 'Fila de vídeos e fotos',
                          message: enabled
                              ? 'Vincule uma fonte em Músicas → Coleções. Os arquivos concluídos ficam no histórico de Arquivos.'
                              : 'A captura e o download de vídeos e fotos ainda não estão disponíveis.')
                      : DownloadTable(
                          entries: page.items,
                          selection: c.selection,
                          onSelect: c.select,
                          onSelectPage: c.selectPage,
                          activeId: library.activeTrackId,
                          progress: library.progress,
                          paused: library.pauseMode,
                          output: library.outputDirectory))),
          PageControls(
              offset: c.downloadOffset,
              count: page.items.length,
              total: page.total,
              onPage: (v) => unawaited(c.turnDownloads(v))),
          const SizedBox(height: 6),
          Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('${c.selection.length} selecionados',
                    style:
                        const TextStyle(fontSize: 11, color: AppColors.muted)),
                OutlinedButton.icon(
                    style:
                        OutlinedButton.styleFrom(shape: const StadiumBorder()),
                    onPressed: onCapture,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Capturar novo link')),
              ]),
          const SizedBox(height: 8),
          const Text(
              'Deezer tem preferência; YouTube Music é a alternativa de áudio. Velocidade e tempo restante ainda não são medidos.',
              style: TextStyle(fontSize: 10, color: AppColors.muted)),
        ]);
        return LayoutBuilder(builder: (context, constraints) {
          final minimumHeight = constraints.maxWidth < 600
              ? (MediaQuery.textScalerOf(context).scale(12) > 14
                  ? 820.0
                  : 700.0)
              : 540.0;
          return constraints.maxHeight < minimumHeight
              ? SingleChildScrollView(
                  child: SizedBox(height: minimumHeight, child: content))
              : content;
        });
      });
  Future<void> _remove(BuildContext context) async {
    final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Remover da fila?'),
                content: const Text(
                    'Os itens selecionados sairão de Downloads. A coleção, os arquivos baixados e o histórico em Arquivos serão preservados. A transferência ativa não será removida.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Remover da fila'))
                ]));
    if (accepted == true) await controller.removeDownloads();
  }
}

class DownloadToolbar extends StatelessWidget {
  const DownloadToolbar(
      {super.key,
      this.onStart,
      this.onPause,
      this.onCancel,
      this.onUp,
      this.onDown,
      this.onOpen,
      this.onRetry,
      this.onRemove,
      this.paused = false});
  final VoidCallback? onStart,
      onPause,
      onCancel,
      onUp,
      onDown,
      onOpen,
      onRetry,
      onRemove;
  final bool paused;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
      key: const ValueKey('download-toolbar-scroll'),
      scrollDirection: Axis.horizontal,
      primary: false,
      child: Row(children: [
        _button(
            Icons.play_arrow_rounded,
            paused ? 'Continuar fila' : 'Iniciar selecionados',
            'Arquivos incompletos reiniciam do começo.',
            onStart,
            primary: true),
        const SizedBox(width: 4),
        _button(
            paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
            paused ? 'Retomar' : 'Pausar fila',
            'Limitar a transferência atual a 10 KiB/s e não iniciar outras.',
            onPause,
            active: paused),
        _button(
            Icons.stop_rounded,
            'Parar fila',
            'Interromper a operação ativa e preservar os arquivos concluídos.',
            onCancel),
        _separator(),
        _button(Icons.arrow_upward_rounded, 'Aumentar prioridade',
            'Aumentar a prioridade sem alterar a ordem da playlist.', onUp),
        _button(Icons.arrow_downward_rounded, 'Diminuir prioridade',
            'Diminuir a prioridade dos selecionados.', onDown),
        _separator(),
        _button(Icons.folder_open_rounded, 'Abrir pasta',
            'Abrir a pasta do arquivo selecionado.', onOpen),
        _button(Icons.refresh_rounded, 'Tentar novamente',
            'Reiniciar somente os selecionados que falharam.', onRetry),
        _button(Icons.delete_outline_rounded, 'Remover da fila',
            'Preservar a coleção, os arquivos e o histórico.', onRemove),
      ]));

  Widget _separator() => const SizedBox(
      height: 22, width: 20, child: VerticalDivider(width: 20, thickness: 1));

  Widget _button(
          IconData icon, String label, String description, VoidCallback? action,
          {bool primary = false, bool active = false}) =>
      Semantics(
          hint: description,
          child: IconButton(
              tooltip: label,
              onPressed: action,
              isSelected: active,
              style: IconButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      foregroundColor: primary ? Colors.white : AppColors.ink,
                      backgroundColor: primary
                          ? AppColors.accent
                          : active
                              ? AppColors.accentSoft
                              : Colors.transparent,
                      disabledForegroundColor: AppColors.muted,
                      disabledBackgroundColor:
                          primary ? AppColors.background : Colors.transparent)
                  .copyWith(backgroundColor:
                      WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled)) {
                  return primary ? AppColors.background : Colors.transparent;
                }
                if (!primary) {
                  return active ? AppColors.accentSoft : Colors.transparent;
                }
                return states.any((state) => const {
                          WidgetState.hovered,
                          WidgetState.focused,
                          WidgetState.pressed
                        }.contains(state))
                    ? AppColors.accentActive
                    : AppColors.accent;
              })),
              icon: Icon(icon, size: 22)));
}

class DownloadTable extends StatelessWidget {
  const DownloadTable(
      {super.key,
      required this.entries,
      required this.selection,
      required this.onSelect,
      required this.onSelectPage,
      this.activeId,
      this.progress,
      this.paused = false,
      required this.output});
  final List<DownloadEntry> entries;
  final Set<int> selection;
  final void Function(int, bool) onSelect;
  final ValueChanged<bool> onSelectPage;
  final int? activeId;
  final double? progress;
  final bool paused;
  final String output;
  @override
  Widget build(BuildContext context) => HorizontalTableViewport(
      width: 1160,
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
            Text(label,
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
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
                            '${t.title} · ${e.collectionName} · Prioridade ${t.queuePriority}',
                        child: Text(
                            t.localPath.isEmpty
                                ? t.title
                                : p.basename(t.localPath),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11))),
                    const Text('—'),
                    Text(t.sourceKind.musicProviderName ?? t.sourceLabel,
                        style: const TextStyle(fontSize: 11)),
                    Tooltip(
                        message: t.error,
                        child: Text(
                            t.id == activeId && paused
                                ? 'Pausado · 10 KiB/s'
                                : e.statusLabel,
                            style: const TextStyle(fontSize: 11))),
                    const Text('—'),
                    const Text('—'),
                    const Text('—'),
                    t.status == TrackStatus.completed
                        ? const Text('Concluído',
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
    const widths = [
      38.0,
      170.0,
      80.0,
      120.0,
      130.0,
      90.0,
      110.0,
      90.0,
      120.0,
      212.0
    ];
    return Container(
        constraints: BoxConstraints(minHeight: header ? 40 : 48),
        decoration: BoxDecoration(
            color: selected ? AppColors.accentSoft : Colors.white,
            border: const Border(bottom: BorderSide(color: AppColors.line))),
        child: Row(children: [
          for (var i = 0; i < cells.length; i++)
            SizedBox(
                width: widths[i],
                child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: cells[i]))
        ]));
  }
}

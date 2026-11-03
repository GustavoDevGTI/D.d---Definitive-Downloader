import 'dart:async';
import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../library/domain/models.dart';
import '../application/workspace_controller.dart';
import '../domain/workspace_models.dart';
import 'workspace_components.dart';
import 'download_table.dart';
import '../../library/presentation/add_music_links_dialog.dart';

class DownloadWorkspace extends StatefulWidget {
  const DownloadWorkspace(
      {super.key,
      required this.controller,
      required this.category,
      this.onCapture});
  final WorkspaceController controller;
  final ContentCategory category;
  final VoidCallback? onCapture;
  @override
  State<DownloadWorkspace> createState() => _DownloadWorkspaceState();
}

class _DownloadWorkspaceState extends State<DownloadWorkspace> {
  late final _query =
      TextEditingController(text: widget.controller.downloadQuery);
  Timer? _searchTimer;
  WorkspaceController get controller => widget.controller;
  ContentCategory get category => widget.category;
  VoidCallback? get onCapture => widget.onCapture;
  @override
  void dispose() {
    _searchTimer?.cancel();
    _query.dispose();
    super.dispose();
  }

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
          Row(children: [
            Expanded(
                child: TextField(
              key: ValueKey('download-search-${category.name}'),
              controller: _query,
              enabled: enabled,
              maxLength: 200,
              decoration: InputDecoration(
                  counterText: '',
                  hintText: 'Buscar nos downloads…',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _query.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Limpar busca de downloads',
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            _searchTimer?.cancel();
                            _query.clear();
                            setState(() {});
                            unawaited(c.searchDownloads(''));
                          })),
              onChanged: (value) {
                setState(() {});
                _searchTimer?.cancel();
                _searchTimer = Timer(const Duration(milliseconds: 300),
                    () => unawaited(c.searchDownloads(value)));
              },
            )),
            const SizedBox(width: 8),
            IconButton(
                tooltip: 'Restaurar colunas',
                onPressed: () => unawaited(c.resetColumnWidths()),
                icon: const Icon(Icons.view_column_outlined,
                    color: AppColors.accent)),
          ]),
          const SizedBox(height: 12),
          DownloadToolbar(
              onAdd: enabled &&
                      !library.addingLinks &&
                      !library.importing &&
                      !library.preparing &&
                      library.current != null
                  ? () => unawaited(showAddMusicLinks(context, library))
                  : null,
              paused: library.pauseMode,
              onStart: canStart || (enabled && library.pauseMode)
                  ? () => unawaited(c.start())
                  : null,
              onPause: canCancel ? library.togglePause : null,
              onCancel: canCancel ? library.cancel : null,
              onUp:
                  canPrioritize && selected.any((e) => e.track.queuePriority < 4)
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
                              ? 'Adicione faixas em Músicas → Coleções.'
                              : 'A captura e o download de vídeos e fotos ainda não estão disponíveis.')
                      : DownloadTable(
                          entries: page.items,
                          widths: c.columnWidths,
                          onResize: c.resizeColumn,
                          onResizeEnd: () => unawaited(c.saveColumnWidths()),
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
                    onPressed: enabled && library.current != null
                        ? (library.addingLinks ||
                                library.importing ||
                                library.preparing
                            ? null
                            : () =>
                                unawaited(showAddMusicLinks(context, library)))
                        : onCapture,
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(
                        enabled ? 'Adicionar links' : 'Capturar novo link')),
              ]),
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
      this.onAdd,
      this.onStart,
      this.onPause,
      this.onCancel,
      this.onUp,
      this.onDown,
      this.onOpen,
      this.onRetry,
      this.onRemove,
      this.paused = false});
  final VoidCallback? onAdd,
      onStart,
      onPause,
      onCancel,
      onUp,
      onDown,
      onOpen,
      onRetry,
      onRemove;
  final bool paused;
  @override
  Widget build(BuildContext context) => Align(
      alignment: Alignment.centerLeft,
      child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(14)),
          child: SingleChildScrollView(
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
                const SizedBox(width: 6),
                _button(
                    paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    paused ? 'Retomar' : 'Pausar fila',
                    'Limitar a transferência atual a 10 KiB/s e não iniciar outras.',
                    onPause,
                    active: paused),
                const SizedBox(width: 6),
                _button(
                    Icons.stop_rounded,
                    'Parar fila',
                    'Interromper a operação ativa e preservar os arquivos concluídos.',
                    onCancel),
                _separator(),
                _button(
                    Icons.arrow_upward_rounded,
                    'Aumentar prioridade',
                    'Aumentar a prioridade sem alterar a ordem da playlist.',
                    onUp),
                const SizedBox(width: 6),
                _button(Icons.arrow_downward_rounded, 'Diminuir prioridade',
                    'Diminuir a prioridade dos selecionados.', onDown),
                _separator(),
                _button(Icons.folder_open_rounded, 'Abrir pasta',
                    'Abrir a pasta do arquivo selecionado.', onOpen),
                const SizedBox(width: 6),
                _button(Icons.refresh_rounded, 'Tentar novamente',
                    'Reiniciar somente os selecionados que falharam.', onRetry),
                const SizedBox(width: 6),
                _button(
                    Icons.delete_outline_rounded,
                    'Remover da fila',
                    'Preservar a coleção, os arquivos e o histórico.',
                    onRemove),
                _separator(),
                _button(Icons.add_link_rounded, 'Adicionar links',
                    'Acrescentar faixas ao final da coleção.', onAdd),
              ]))));

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
                      visualDensity: VisualDensity.standard,
                      side: BorderSide(
                          color: AppColors.accent
                              .withAlpha(action == null ? 65 : 125)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      foregroundColor: primary || active
                          ? Colors.white
                          : AppColors.accentActive,
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
                  return AppColors.accentSoft.withAlpha(115);
                }
                if (!primary) {
                  return active ? AppColors.accentActive : AppColors.accentSoft;
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

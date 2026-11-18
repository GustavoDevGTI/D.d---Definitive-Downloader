import 'dart:async';
import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../app/button_hover_motion.dart';
import '../../library/domain/models.dart';
import '../application/workspace_controller.dart';
import '../domain/workspace_models.dart';
import '../domain/download_columns.dart';
import 'workspace_components.dart';
import 'download_table.dart';
import 'download_action_button.dart';
import '../../library/presentation/add_music_links_dialog.dart';

class DownloadWorkspace extends StatefulWidget {
  const DownloadWorkspace(
      {super.key,
      required this.controller,
      required this.category,
      this.keyboardOpen = false,
      this.onCapture});
  final bool keyboardOpen;
  final WorkspaceController controller;
  final ContentCategory category;
  final VoidCallback? onCapture;
  @override
  State<DownloadWorkspace> createState() => _DownloadWorkspaceState();
}

class _DownloadWorkspaceState extends State<DownloadWorkspace> {
  final _searchKey = GlobalKey();
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
      listenable: Listenable.merge(
          [controller, controller.library, controller.library.transferUpdates]),
      builder: (context, child) =>
          LayoutBuilder(builder: (context, constraints) {
            final wide = constraints.maxWidth >= 800 ||
                (constraints.maxHeight < 300 && constraints.maxWidth >= 700);
            final platform = Theme.of(context).platform;
            final compact = constraints.maxWidth < 600 ||
                platform == TargetPlatform.android ||
                platform == TargetPlatform.iOS;
            final inlineFilters = !compact && constraints.maxWidth >= 1380;
            final c = controller, library = c.library;
            final enabled = category == ContentCategory.music;
            final page = enabled && c.category == category
                ? c.downloads
                : const DownloadPage([], 0);
            final selected = enabled && c.category == category
                ? c.selectedDownloads
                : const <DownloadEntry>[];
            final canStart = enabled &&
                !library.busy &&
                selected.any((e) =>
                    e.track.redownloadReview ||
                    (e.track.status == TrackStatus.completed &&
                        e.fileBytes == null) ||
                    (e.track.canDownload &&
                        [TrackStatus.ready, TrackStatus.failed]
                            .contains(e.track.status)));
            final canCancel = library.downloading && enabled;
            final search = Row(key: _searchKey, children: [
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
            ]);
            final toolbar = DownloadToolbar(
                compact: compact,
                onAdd: enabled &&
                        !library.addingLinks &&
                        !library.importing &&
                        !library.preparing &&
                        !library.editing &&
                        library.current != null
                    ? () => unawaited(
                        showAddMusicLinks(context, library, enqueue: true))
                    : null,
                paused: library.pauseMode,
                onStart: canStart || (enabled && library.pauseMode)
                    ? () => unawaited(c.start())
                    : null,
                onPause: canCancel ? library.togglePause : null,
                onCancel: canCancel ? library.cancel : null,
                onReset: enabled
                    ? () {
                        _searchTimer?.cancel();
                        _query.clear();
                        setState(() {});
                        unawaited(c.resetDownloadTable());
                      }
                    : null,
                onOpen: selected.length == 1 &&
                        selected.single.track.localPath.isNotEmpty
                    ? () => unawaited(c.reveal(selected.single.track.localPath))
                    : null,
                onRetry: canStart &&
                        selected
                            .any((e) => e.track.status == TrackStatus.failed)
                    ? () => unawaited(c.start(failedOnly: true))
                    : null,
                onRemove: enabled &&
                        selected.any(
                            (e) => e.track.status != TrackStatus.downloading)
                    ? () => unawaited(_remove(context))
                    : null);
            final filterButtons = <Widget>[
              for (final filter in DownloadFilter.values)
                TextButton(
                    style: TextButton.styleFrom(
                        shape: const StadiumBorder(),
                        padding: compact
                            ? const EdgeInsets.symmetric(horizontal: 8)
                            : null,
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
                    })),
              if (enabled) _playlistColorMenu(c),
            ];
            final filters = compact
                ? SingleChildScrollView(
                    key: const ValueKey('download-mobile-filters'),
                    scrollDirection: Axis.horizontal,
                    primary: false,
                    child: Row(children: filterButtons))
                : Wrap(spacing: 4, runSpacing: 4, children: filterButtons);
            final footer = Row(children: [
              Expanded(
                  child: Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                    Text('${c.selection.length} selecionados',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.muted)),
                    if (!enabled && compact)
                      SizedBox(
                          width: 44,
                          child: DownloadActionButton(
                              icon: Icons.add,
                              label: 'Capturar novo link',
                              color: DownloadActionColors.add,
                              compact: true,
                              onPressed: onCapture))
                    else if (!enabled)
                      ButtonHoverMotion(
                          builder: (states) => OutlinedButton.icon(
                              statesController: states,
                              style:
                                  downloadActionStyle(DownloadActionColors.add)
                                      .copyWith(
                                          shape: const WidgetStatePropertyAll(
                                              StadiumBorder())),
                              onPressed: onCapture,
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Capturar novo link'))),
                  ])),
              const SizedBox(width: 12),
              Text('${page.total} registros',
                  key: const ValueKey('download-record-count'),
                  style: const TextStyle(fontSize: 11, color: AppColors.muted)),
            ]);
            final content = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.keyboardOpen)
                    search
                  else if (compact) ...[
                    search,
                    const SizedBox(height: 6),
                    toolbar,
                  ] else if (wide)
                    Row(children: [
                      toolbar,
                      if (inlineFilters) ...[
                        const SizedBox(width: 12),
                        filters,
                      ],
                      const SizedBox(width: 12),
                      Expanded(child: search)
                    ])
                  else ...[
                    toolbar,
                    const SizedBox(height: 8),
                    search
                  ],
                  if (!widget.keyboardOpen && !inlineFilters) ...[
                    SizedBox(height: compact ? 2 : 8),
                    filters,
                  ],
                  const SizedBox(height: 8),
                  Expanded(
                      child: WorkspacePanel(
                          child: !enabled
                              ? WorkspaceNotice(
                                  title: 'Fila de vídeos e fotos',
                                  message:
                                      'A captura e o download de vídeos e fotos ainda não estão disponíveis.')
                              : DownloadTable(
                                  key: ValueKey(
                                      'download-table-${c.tableRevision}'),
                                  compact: compact,
                                  entries: page.items,
                                  sort: c.downloadSort,
                                  descending: c.downloadDescending,
                                  onSort: (value) =>
                                      unawaited(c.sortDownloads(value)),
                                  widths: c.columnWidths,
                                  onResize: c.resizeColumns,
                                  onSelectMany: c.selectMany,
                                  onResizeEnd: () =>
                                      unawaited(c.saveColumnWidths()),
                                  selection: c.selection,
                                  onSelect: c.select,
                                  onSelectPage: c.selectFiltered,
                                  onVisible: (ids) =>
                                      unawaited(c.checkVisibleDownloads(ids)),
                                  viewKey: (
                                    c.category,
                                    c.filter,
                                    c.downloadPlaylistId,
                                    c.downloadQuery,
                                    c.downloadSort,
                                    c.downloadDescending
                                  ),
                                  activeId: library.activeTrackId,
                                  progress: library.progress,
                                  transfer: library.transfer,
                                  paused: library.pauseMode,
                                  output: library.outputDirectory))),
                  const SizedBox(height: 8),
                  footer,
                ]);
            final minimumHeight = compact
                ? (widget.keyboardOpen ? 170.0 : 270.0) *
                    (MediaQuery.textScalerOf(context).scale(12) / 12)
                        .clamp(1, 2)
                : 540.0;
            return constraints.maxHeight < minimumHeight
                ? SingleChildScrollView(
                    child: SizedBox(height: minimumHeight, child: content))
                : content;
          }));
  Widget _playlistColorMenu(WorkspaceController c) {
    final selectedId = c.downloadPlaylistId;
    final active = selectedId != null;
    final selected = c.downloadColors
        .where((option) => option.collectionId == selectedId)
        .firstOrNull;
    final sorted = c.downloadSort == DownloadSort.playlistColor;
    return PopupMenuButton<({int? playlistId})>(
        key: const ValueKey('download-playlist-color-filter'),
        tooltip: selected == null
            ? 'Filtrar pela cor da playlist'
            : 'Cor da playlist: ${selected.name}',
        position: PopupMenuPosition.under,
        enabled: active || c.downloadColors.isNotEmpty,
        onSelected: (option) =>
            unawaited(c.filterDownloadsByPlaylist(option.playlistId)),
        itemBuilder: (_) => [
              CheckedPopupMenuItem(
                  value: (playlistId: null),
                  checked: !active,
                  child: const Text('Todas as cores')),
              for (final option in c.downloadColors)
                CheckedPopupMenuItem(
                    key: ValueKey('download-color-${option.collectionId}'),
                    value: (playlistId: option.collectionId),
                    checked: selectedId == option.collectionId,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      _colorDot(option.rgb),
                      const SizedBox(width: 8),
                      Flexible(
                          child: Text(option.name,
                              maxLines: 2, overflow: TextOverflow.ellipsis)),
                    ])),
              const PopupMenuDivider(),
              PopupMenuItem(
                  onTap: () =>
                      unawaited(c.sortDownloads(DownloadSort.playlistColor)),
                  child: Text(sorted
                      ? 'Ordenar por cor ${c.downloadDescending ? '↓' : '↑'}'
                      : 'Ordenar por cor')),
            ],
        child: DecoratedBox(
            decoration: BoxDecoration(
                color: active ? AppColors.accentSoft : Colors.transparent,
                borderRadius: BorderRadius.circular(12)),
            child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(
                    height: 36,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (selected == null)
                        const Icon(Icons.palette_outlined,
                            size: 16, color: AppColors.muted)
                      else
                        _colorDot(selected.rgb),
                      const SizedBox(width: 6),
                      Text('Cor',
                          style: TextStyle(
                              color: active
                                  ? AppColors.accentActive
                                  : AppColors.muted)),
                      const Icon(Icons.arrow_drop_down, size: 18),
                    ])))));
  }

  Widget _colorDot(int rgb) => Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFF000000 | rgb),
          border: Border.all(color: Colors.black26)));

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
      this.onReset,
      this.onOpen,
      this.onRetry,
      this.onRemove,
      this.compact = false,
      this.paused = false});
  final VoidCallback? onAdd,
      onStart,
      onPause,
      onCancel,
      onReset,
      onOpen,
      onRetry,
      onRemove;
  final bool paused, compact;
  @override
  Widget build(BuildContext context) {
    final buttons = _buttons();
    if (compact) {
      return Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Row(
            key: const ValueKey('download-mobile-actions'),
            spacing: 4,
            children: [for (final button in buttons) Expanded(child: button)],
          ),
        ),
      );
    }
    return Align(
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
                child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                    child: Row(children: buttons)))));
  }

  List<Widget> _buttons() => [
        _button(
            Icons.download_rounded,
            paused ? 'Continuar fila' : 'Iniciar selecionados',
            'Arquivos incompletos reiniciam do começo.',
            onStart,
            color: DownloadActionColors.start,
            primary: true),
        if (!compact) const SizedBox(width: 6),
        _button(
            paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
            paused ? 'Retomar' : 'Pausar fila',
            'Limitar a transferência atual a 10 KiB/s e não iniciar outras.',
            onPause,
            color: DownloadActionColors.pause,
            active: paused),
        if (!compact) const SizedBox(width: 6),
        _button(
            Icons.stop_rounded,
            'Parar fila',
            'Interromper a operação ativa e preservar os arquivos concluídos.',
            onCancel,
            color: DownloadActionColors.stop),
        if (!compact) _separator(),
        _button(Icons.folder_open_rounded, 'Abrir pasta',
            'Abrir a pasta do arquivo selecionado.', onOpen),
        if (!compact) const SizedBox(width: 6),
        _button(Icons.refresh_rounded, 'Tentar novamente',
            'Reiniciar somente os selecionados que falharam.', onRetry),
        if (!compact) const SizedBox(width: 6),
        _button(Icons.delete_outline_rounded, 'Remover da fila',
            'Preservar a coleção, os arquivos e o histórico.', onRemove,
            color: DownloadActionColors.stop),
        if (!compact) const SizedBox(width: 6),
        _button(Icons.settings_backup_restore_rounded, 'Resetar tabela',
            'Restaurar larguras, busca, filtros e ordenação.', onReset),
        if (!compact) _separator(),
        _button(Icons.add_link_rounded, 'Adicionar links',
            'Acrescentar faixas ao final da coleção.', onAdd,
            color: DownloadActionColors.add),
      ];

  Widget _separator() => const SizedBox(
      height: 22, width: 20, child: VerticalDivider(width: 20, thickness: 1));

  Widget _button(
          IconData icon, String label, String description, VoidCallback? action,
          {bool primary = false,
          bool active = false,
          Color color = DownloadActionColors.utility}) =>
      DownloadActionButton(
          icon: icon,
          label: label,
          description: description,
          onPressed: action,
          color: color,
          compact: compact,
          primary: primary,
          active: active);
}

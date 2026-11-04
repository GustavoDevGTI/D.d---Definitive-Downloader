import 'dart:async';
import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../app/app_notice.dart';
import '../application/library_controller.dart';
import '../domain/models.dart';
import '../../workspace/presentation/workspace_components.dart';
import '../../workspace/presentation/link_entry_panel.dart';
import '../../organization/presentation/collection_manager.dart';
import 'track_inspector.dart';
import '../domain/track_listing.dart';
import 'track_table.dart';
import 'add_music_links_dialog.dart';
import '../../workspace/presentation/download_action_button.dart';

class CollectionWorkspace extends StatefulWidget {
  const CollectionWorkspace(
      {super.key,
      required this.controller,
      required this.onConnections,
      required this.onDownloads,
      this.initialPlaylist = ''});
  final LibraryController controller;
  final VoidCallback? onConnections;
  final VoidCallback onDownloads;
  final String initialPlaylist;
  @override
  State<CollectionWorkspace> createState() => _CollectionWorkspaceState();
}

class _CollectionWorkspaceState extends State<CollectionWorkspace> {
  late final _url = TextEditingController(text: widget.initialPlaylist);
  final _query = TextEditingController();
  final _urlFocus = FocusNode();
  Timer? _timer;
  bool _detail = false;
  @override
  void dispose() {
    _timer?.cancel();
    _url.dispose();
    _query.dispose();
    _urlFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    if (_detail && c.current != null) {
      return LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 880;
        final panel =
            Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(flex: 8, child: WorkspacePanel(child: _tracks(c, wide))),
          if (wide) ...[
            const SizedBox(width: 12),
            Expanded(
                flex: 5,
                child: WorkspacePanel(child: TrackInspector(controller: c)))
          ],
        ]);
        if (constraints.maxHeight < 560 || constraints.maxWidth < 560) {
          return ListView(primary: false, padding: EdgeInsets.zero, children: [
            _back(),
            const SizedBox(height: 12),
            SizedBox(height: 660, child: panel)
          ]);
        }
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _back(),
              const SizedBox(height: 12),
              Expanded(child: panel)
            ]);
      });
    }
    return ListView(primary: false, padding: EdgeInsets.zero, children: [
      LinkEntryPanel(
          title: 'Importar playlist',
          fieldLabel: 'Link da playlist',
          hintText: 'Link de playlist do Spotify',
          controller: _url,
          focusNode: _urlFocus,
          inputKey: const ValueKey('playlist-url'),
          enabled: !c.busy,
          onSubmitted: c.busy ? null : (value) => unawaited(_import(value)),
          actionLabel: 'Importar por link',
          actionIcon: Icons.playlist_add_rounded,
          onAction: c.busy ? null : () => unawaited(_import(_url.text)),
          secondaryActions: [
            OutlinedButton(
                onPressed: widget.onConnections, child: const Text('Conexões')),
            IconButton(
                tooltip: 'Importar CSV · Ctrl+O',
                onPressed: c.busy ? null : () => unawaited(c.importCsv()),
                icon: const Icon(Icons.upload_file_outlined, size: 19)),
          ]),
      const SizedBox(height: 12),
      CollectionManager(
          library: c,
          onOpen: (collection) {
            _query.clear();
            setState(() => _detail = true);
            unawaited(c.openCollection(collection));
          }),
    ]);
  }

  Widget _back() => Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
          onPressed: () => setState(() => _detail = false),
          icon: const Icon(Icons.arrow_back, size: 18),
          label: const Text('Voltar às coleções')));
  Future<void> _import(String value) async {
    final before = widget.controller.current?.id;
    await widget.controller.importSpotify(value);
    if (mounted && widget.controller.current?.id != before) {
      setState(() => _detail = true);
    }
  }

  Widget _tracks(LibraryController c, bool wide) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 0),
            child: Row(children: [
              Expanded(
                  child: Text(c.current!.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600))),
              Text('${c.page.selectedCount} selecionadas',
                  style: const TextStyle(fontSize: 11, color: AppColors.muted)),
              if (c.current!.editingLocked)
                IconButton(
                    tooltip: 'Por que a edição está bloqueada?',
                    onPressed: () => unawaited(showAppNotice(context,
                        title: 'Edição bloqueada',
                        message:
                            'Nomes, ordem e IDs ficam bloqueados após o início dos downloads. Você ainda pode adicionar novos links à coleção.')),
                    icon: const Icon(Icons.lock_outline,
                        size: 18, color: AppColors.accentActive)),
            ])),
        SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(children: [
              DownloadActionButton(
                  label: 'Baixar selecionadas',
                  icon: Icons.download_rounded,
                  color: DownloadActionColors.start,
                  primary: true,
                  onPressed: c.busy || c.page.selectedCount == 0
                      ? null
                      : () {
                          unawaited(c.downloadSelected());
                          widget.onDownloads();
                        }),
              const SizedBox(width: 6),
              DownloadActionButton(
                  label: 'Adicionar links',
                  color: DownloadActionColors.add,
                  icon: Icons.add_link_rounded,
                  onPressed:
                      c.addingLinks || c.importing || c.preparing || c.editing
                          ? null
                          : () => unawaited(showAddMusicLinks(context, c))),
              const SizedBox(width: 6),
              DownloadActionButton(
                  label: 'Rever correspondências',
                  icon: Icons.fact_check_outlined,
                  color: AppColors.accentActive,
                  onPressed: c.busy || c.isExample || c.music?.available != true
                      ? null
                      : () => unawaited(c.prepareMusic())),
              if (c.preparing || c.downloading) ...[
                const SizedBox(width: 6),
                DownloadActionButton(
                    label: 'Interromper',
                    icon: Icons.stop,
                    color: DownloadActionColors.stop,
                    onPressed: c.cancel)
              ],
            ])),
        Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: LayoutBuilder(builder: (context, box) {
              final search = TextField(
                  key: const ValueKey('track-search'),
                  controller: _query,
                  maxLength: 400,
                  decoration: InputDecoration(
                      hintText: 'Pesquisar faixas…',
                      counterText: '',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      suffixIcon: _query.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Limpar pesquisa de faixas',
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () {
                                _timer?.cancel();
                                _query.clear();
                                unawaited(c.searchCollection(''));
                              })),
                  onChanged: (value) {
                    setState(() {});
                    _timer?.cancel();
                    _timer = Timer(const Duration(milliseconds: 300),
                        () => unawaited(c.searchCollection(value)));
                  });
              final filter = DropdownButtonFormField<String>(
                  key: ValueKey('track-filter-${c.view}'),
                  initialValue: c.view,
                  isExpanded: true,
                  menuMaxHeight: 280,
                  decoration: const InputDecoration(
                      labelText: 'Mostrar',
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                  items: const [
                    DropdownMenuItem(
                        value: 'collections',
                        child: Text('Todas', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(
                        value: 'review',
                        child:
                            Text('Conferir', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(
                        value: 'ready',
                        child:
                            Text('Prontas', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(
                        value: 'files',
                        child:
                            Text('Concluídas', overflow: TextOverflow.ellipsis))
                  ],
                  onChanged: (v) {
                    if (v != null) unawaited(c.setView(v));
                  });
              final sort = PopupMenuButton<TrackSort>(
                  tooltip: 'Ordenar faixas',
                  icon: const Icon(Icons.sort, color: AppColors.accentActive),
                  onSelected: (v) => unawaited(c.sortTracks(v)),
                  itemBuilder: (_) => [
                        for (final item in const [
                          (TrackSort.position, 'Ordem da playlist'),
                          (TrackSort.name, 'Nome'),
                          (TrackSort.duration, 'Duração'),
                          (TrackSort.correspondence, 'Correspondência')
                        ])
                          CheckedPopupMenuItem(
                              value: item.$1,
                              checked: c.trackSort == item.$1,
                              child: Text(
                                  '${item.$2}${c.trackSort == item.$1 ? c.trackDescending ? ' ↓' : ' ↑' : ''}'))
                      ]);
              if (box.maxWidth >= 520) {
                return Row(children: [
                  Expanded(child: search),
                  const SizedBox(width: 10),
                  SizedBox(width: 136, child: filter),
                  sort
                ]);
              }
              return Column(children: [
                search,
                const SizedBox(height: 10),
                Row(children: [Expanded(child: filter), sort])
              ]);
            })),
        if (c.importing || c.preparing)
          const LinearProgressIndicator(minHeight: 2),
        Expanded(
            child: TrackTable(
                controller: c, onFocus: (track) => _focus(track, wide))),
      ]);
  void _focus(Track track, bool wide) {
    widget.controller.focus(track);
    if (!wide) {
      unawaited(showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (context) => SizedBox(
              height: MediaQuery.sizeOf(context).height * .9,
              child: ListenableBuilder(
                  listenable: widget.controller,
                  builder: (context, child) =>
                      TrackInspector(controller: widget.controller)))));
    }
  }
}

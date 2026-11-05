import 'dart:async';
import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../application/library_controller.dart';
import '../domain/models.dart';
import '../../workspace/presentation/workspace_components.dart';
import '../../workspace/presentation/link_entry_panel.dart';
import '../../organization/presentation/collection_manager.dart';
import 'track_inspector.dart';
import 'track_table.dart';
import 'collection_track_toolbar.dart';
import 'collection_mp3_drop_target.dart';

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
  bool _wide = false;
  bool _inspectorOpen = false;
  int _inspectorRequest = 0;
  @override
  void initState() {
    super.initState();
    _inspectorRequest = widget.controller.inspectorRequest;
    widget.controller.addListener(_requestInspector);
  }

  void _requestInspector() {
    final c = widget.controller;
    if (!mounted || c.inspectorRequest == _inspectorRequest) return;
    _inspectorRequest = c.inspectorRequest;
    setState(() => _detail = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_wide && c.focused != null) _showInspector();
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_requestInspector);
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
        _wide = wide;
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
        final drop = CollectionMp3DropTarget(
            controller: c, collectionId: c.current!.id, child: panel);
        if (constraints.maxHeight < 560 || constraints.maxWidth < 560) {
          return ListView(
              primary: false,
              padding: EdgeInsets.zero,
              children: [SizedBox(height: 660, child: drop)]);
        }
        return drop;
      });
    }
    return ListView(primary: false, padding: EdgeInsets.zero, children: [
      LinkEntryPanel(
          title: 'Importar playlist',
          fieldLabel: 'Link da playlist ou faixa',
          hintText: 'Cole o link da playlist',
          controller: _url,
          focusNode: _urlFocus,
          inputKey: const ValueKey('playlist-url'),
          enabled: !c.busy,
          onSubmitted: c.busy ? null : (value) => unawaited(_import(value)),
          actionLabel: 'Importar por link',
          actionIcon: Icons.playlist_add_rounded,
          onAction: c.busy ? null : () => unawaited(_import(_url.text)),
          secondaryActions: [
            if (c.importing)
              IconButton(
                  tooltip: 'Cancelar importação',
                  onPressed: c.cancel,
                  icon: const Icon(Icons.close, color: AppColors.accentActive)),
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

  Widget _back() => IconButton(
      tooltip: 'Voltar às coleções',
      onPressed: () => setState(() => _detail = false),
      icon: const Icon(Icons.arrow_back, size: 18));
  Future<void> _import(String value) async {
    final before = widget.controller.current?.id;
    await widget.controller.importPlaylist(value);
    if (mounted && widget.controller.current?.id != before) {
      setState(() => _detail = true);
    }
  }

  Widget _tracks(LibraryController c, bool wide) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 0),
            child: Row(children: [
              _back(),
              Expanded(
                  child: Text(c.current!.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600))),
              if (c.page.selectedCount > 0) ...[
                const SizedBox(width: 8),
                Text(
                    '${c.page.selectedCount} ${c.page.selectedCount == 1 ? 'selecionada' : 'selecionadas'}',
                    style:
                        const TextStyle(fontSize: 11, color: AppColors.muted)),
              ],
            ])),
        CollectionTrackToolbar(
            controller: c,
            query: _query,
            onDownload: () => unawaited(_startDownloads()),
            onQueryChanged: (value) {
              setState(() {});
              _timer?.cancel();
              _timer = Timer(const Duration(milliseconds: 300),
                  () => unawaited(c.searchCollection(value)));
            },
            onClear: () {
              _timer?.cancel();
              setState(_query.clear);
              unawaited(c.searchCollection(''));
            }),
        if (c.importing || c.preparing || c.addingLinks)
          const LinearProgressIndicator(minHeight: 2),
        if (c.addingLinks && c.linkProgress.isNotEmpty)
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Row(children: [
                Expanded(
                    child: Text(c.linkProgress,
                        style: const TextStyle(fontSize: 11))),
                IconButton(
                    tooltip: 'Interromper adição',
                    onPressed: c.cancelAdditions,
                    icon: const Icon(Icons.close, size: 18))
              ])),
        Expanded(
            child: TrackTable(
                controller: c, onFocus: (track) => _focus(track, wide))),
      ]);
  void _focus(Track track, bool wide) {
    widget.controller.focus(track);
    if (!wide) _showInspector();
  }

  Future<void> _startDownloads() async {
    final started = await widget.controller.startDownloads();
    if (mounted && started) widget.onDownloads();
  }

  void _showInspector() {
    if (_inspectorOpen) return;
    _inspectorOpen = true;
    unawaited(showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (context) => SizedBox(
                height: MediaQuery.sizeOf(context).height * .9,
                child: ListenableBuilder(
                    listenable: widget.controller,
                    builder: (context, child) =>
                        TrackInspector(controller: widget.controller))))
        .whenComplete(() => _inspectorOpen = false));
  }
}

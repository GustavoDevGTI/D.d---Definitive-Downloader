import 'dart:async';
import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../application/library_controller.dart';
import '../domain/models.dart';
import '../../workspace/presentation/workspace_components.dart';
import 'track_inspector.dart';
import 'track_table.dart';

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
      const Text('Importar playlist',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
      TextField(
          key: const ValueKey('playlist-url'),
          controller: _url,
          focusNode: _urlFocus,
          enabled: !c.busy,
          keyboardType: TextInputType.url,
          decoration:
              const InputDecoration(hintText: 'Link de playlist do Spotify'),
          onSubmitted: (value) => unawaited(_import(value))),
      const SizedBox(height: 8),
      Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton(
                style: OutlinedButton.styleFrom(shape: const StadiumBorder()),
                onPressed: c.busy ? null : () => unawaited(_import(_url.text)),
                child: const Text('Importar por link')),
            OutlinedButton(
                style: OutlinedButton.styleFrom(shape: const StadiumBorder()),
                onPressed: widget.onConnections,
                child: const Text('Conexões')),
            IconButton(
                tooltip: 'Importar CSV · Ctrl+O',
                onPressed: c.busy ? null : () => unawaited(c.importCsv()),
                icon: const Icon(Icons.upload_file_outlined, size: 19)),
          ]),
      const SizedBox(height: 12),
      Row(children: [
        const Expanded(
            child: Text('Minhas coleções',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
        TextButton(
            onPressed: c.busy
                ? null
                : () {
                    _urlFocus.requestFocus();
                  },
            child: const Text('+ Nova'))
      ]),
      const SizedBox(height: 8),
      if (c.collections.isEmpty)
        const WorkspacePanel(
            padding: EdgeInsets.all(16),
            child: Text(
                'Nenhuma coleção importada. Use um link do Spotify ou um arquivo CSV.',
                style: TextStyle(
                    fontSize: 12, color: AppColors.muted, height: 1.6))),
      for (final collection in c.collections)
        Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: WorkspacePanel(
                child: ListTile(
                    title: Text(collection.name,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                        '${collection.trackCount} faixas · ${collection.source}${collection.isPartial ? ' · parcial' : ''}',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.muted)),
                    trailing: const Icon(Icons.chevron_right, size: 19),
                    onTap: () {
                      _query.clear();
                      setState(() => _detail = true);
                      unawaited(c.openCollection(collection));
                    }))),
      if (c.collectionOffset > 0 || c.collections.length == 30)
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          IconButton(
              tooltip: 'Coleções anteriores',
              onPressed: c.collectionOffset > 0
                  ? () => unawaited(c.turnCollections(-1))
                  : null,
              icon: const Icon(Icons.chevron_left)),
          IconButton(
              tooltip: 'Mais coleções',
              onPressed: c.collections.length == 30
                  ? () => unawaited(c.turnCollections(1))
                  : null,
              icon: const Icon(Icons.chevron_right)),
        ]),
      const SizedBox(height: 2),
      const WorkspacePanel(
          padding: EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Conferência',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            SizedBox(height: 10),
            Text(
                'Ao selecionar uma coleção, confira as faixas identificadas e suas correspondências antes de baixar.',
                style: TextStyle(
                    fontSize: 11, color: AppColors.muted, height: 1.6)),
          ])),
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
            padding: const EdgeInsets.fromLTRB(14, 8, 8, 0),
            child: Row(children: [
              Expanded(
                  child: Text(c.current!.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600))),
              IconButton(
                  tooltip: 'Buscar músicas',
                  onPressed: c.busy || c.isExample || c.music?.available != true
                      ? null
                      : () => unawaited(c.prepareMusic()),
                  icon: const Icon(Icons.manage_search, size: 20)),
            ])),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: TextField(
                controller: _query,
                decoration: const InputDecoration(
                    hintText: 'Pesquisar faixas…',
                    prefixIcon: Icon(Icons.search, size: 18)),
                onChanged: (value) {
                  _timer?.cancel();
                  _timer = Timer(const Duration(milliseconds: 300),
                      () => unawaited(c.searchCollection(value)));
                })),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('Seleção múltipla',
                      style: TextStyle(fontSize: 11, color: AppColors.muted)),
                  TextButton(
                      onPressed: c.busy || c.page.items.isEmpty
                          ? null
                          : () => unawaited(
                              c.selectCollection(!c.allFilteredSelected)),
                      child: Text(c.allFilteredSelected
                          ? 'Desmarcar todas'
                          : 'Selecionar todas')),
                ])),
        if (c.importing || c.preparing)
          const LinearProgressIndicator(minHeight: 2),
        Expanded(
            child: TrackTable(
                controller: c, onFocus: (track) => _focus(track, wide))),
        PageControls(
            offset: c.offset,
            count: c.page.items.length,
            total: c.page.total,
            onPage: (v) => unawaited(c.turnPage(v)),
            label: 'faixas'),
        Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('${c.page.selectedCount} selecionadas',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.muted)),
                  OutlinedButton(
                      onPressed: c.busy || c.page.selectedCount == 0
                          ? null
                          : () {
                              unawaited(c.downloadSelected());
                              widget.onDownloads();
                            },
                      child: const Text('Baixar selecionadas')),
                  IconButton(
                      tooltip: 'Abrir downloads musicais',
                      onPressed: widget.onDownloads,
                      icon: const Icon(Icons.downloading_outlined, size: 20)),
                  if (c.downloading || c.preparing)
                    IconButton(
                        tooltip: 'Interromper',
                        onPressed: c.cancel,
                        icon: const Icon(Icons.stop, size: 20)),
                ])),
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

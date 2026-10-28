import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../app/theme.dart';
import '../../connections/application/spotify_connection_controller.dart';
import '../../connections/presentation/connections_dialog.dart';
import '../application/library_controller.dart';
import '../domain/models.dart';
import 'sidebar.dart';
import 'track_inspector.dart';
import 'track_table.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen(
      {super.key,
      required this.controller,
      this.connections,
      this.initialPlaylist = '',
      this.showConnectionsOnStart = false});
  final LibraryController controller;
  final SpotifyConnectionController? connections;
  final String initialPlaylist;
  final bool showConnectionsOnStart;
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _url = TextEditingController();
  @override
  void initState() {
    super.initState();
    _url.text = widget.initialPlaylist;
    if (widget.showConnectionsOnStart && widget.connections != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showConnections();
      });
    }
  }

  void _showConnections() {
    final connections = widget.connections;
    if (connections == null) return;
    unawaited(showDialog<void>(
        context: context,
        builder: (_) => ConnectionsDialog(
            controller: connections,
            deezer: widget.controller.music?.connection,
            allowChanges: !widget.controller.busy)));
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.keyO, control: true): () =>
                unawaited(widget.controller.importCsv()),
          },
          child: ListenableBuilder(
              listenable: widget.controller,
              builder: (context, _) {
                final c = widget.controller;
                return Scaffold(
                    body: LayoutBuilder(builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 1180;
                  return Row(children: [
                    LibrarySidebar(
                        controller: c, compact: constraints.maxWidth < 1000),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          _header(c),
                          _importBar(c),
                          Expanded(
                              child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                Expanded(
                                    child: Container(
                                        color: Colors.white,
                                        child: Column(children: [
                                          _collectionHeader(c),
                                          if (c.importing ||
                                              c.downloading ||
                                              c.preparing)
                                            LinearProgressIndicator(
                                                value:
                                                    c.importing || c.preparing
                                                        ? null
                                                        : c.progress,
                                                minHeight: 2,
                                                backgroundColor:
                                                    AppColors.line),
                                          Expanded(
                                              child: TrackTable(
                                                  controller: c,
                                                  onFocus: (track) =>
                                                      _focusTrack(
                                                          track, wide))),
                                          _pagination(c),
                                        ]))),
                                if (wide)
                                  SizedBox(
                                      width: 300,
                                      child: TrackInspector(controller: c)),
                              ])),
                          _downloadBar(c),
                          _status(c),
                        ])),
                  ]);
                }));
              }));

  Widget _header(LibraryController c) => Padding(
      padding: const EdgeInsets.fromLTRB(30, 27, 30, 23),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
              switch (c.view) {
                'downloads' => 'Downloads',
                'files' => 'Arquivos',
                _ => 'Coleções'
              },
              style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -.8)),
          const SizedBox(height: 7),
          Text(
              switch (c.view) {
                'downloads' => 'Acompanhe os itens com uma fonte vinculada.',
                'files' =>
                  'Os arquivos concluídos permanecem na sua biblioteca.',
                _ => 'Importe, confira e mantenha a ordem da sua playlist.'
              },
              style: const TextStyle(fontSize: 11, color: AppColors.muted)),
        ])),
        if (widget.connections case final connections?)
          ListenableBuilder(
              listenable: connections,
              builder: (context, _) => TextButton.icon(
                    onPressed: _showConnections,
                    icon: Icon(
                        connections.isConnected
                            ? Icons.person
                            : Icons.person_outline,
                        size: 16),
                    label:
                        const Text('Conexões', style: TextStyle(fontSize: 11)),
                  ))
        else
          const Text('Sem conta conectada',
              style: TextStyle(fontSize: 10, color: AppColors.muted)),
      ]));

  Widget _importBar(LibraryController c) => Container(
      padding: const EdgeInsets.fromLTRB(30, 0, 30, 24),
      child: Row(children: [
        Expanded(
            child: TextField(
                controller: _url,
                enabled: !c.busy,
                style: const TextStyle(fontSize: 12),
                decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.link, size: 17),
                    hintText: 'Cole o link de uma playlist do Spotify',
                    prefixIconConstraints: BoxConstraints(minWidth: 42)),
                onSubmitted: (value) => unawaited(c.importSpotify(value)))),
        const SizedBox(width: 10),
        FilledButton(
            onPressed:
                c.busy ? null : () => unawaited(c.importSpotify(_url.text)),
            child: const Text('Importar link')),
        const SizedBox(width: 7),
        Tooltip(
            message: 'Importar CSV · Ctrl+O',
            child: IconButton(
                onPressed: c.busy ? null : () => unawaited(c.importCsv()),
                icon: const Icon(Icons.file_upload_outlined, size: 21),
                color: AppColors.muted)),
      ]));

  Widget _collectionHeader(LibraryController c) => Padding(
      padding: const EdgeInsets.fromLTRB(26, 25, 24, 23),
      child: Row(children: [
        if (c.isExample)
          Image.asset('assets/demo/cover.png', width: 54, height: 54)
        else
          Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(color: Color(0xFFF1F5F8)),
              child: const Icon(Icons.queue_music,
                  size: 23, color: AppColors.accent)),
        const SizedBox(width: 16),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(c.current?.name ?? 'Sua biblioteca começa aqui',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -.3)),
          const SizedBox(height: 7),
          Text(
              c.current == null
                  ? 'Playlist por link ou arquivo CSV'
                  : '${c.current!.trackCount} faixas · ${c.current!.source}${c.current!.isPartial ? ' · lista parcial' : ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: AppColors.muted)),
        ])),
        if (c.current != null && !c.isExample && c.music != null) ...[
          TextButton.icon(
              onPressed: c.busy || c.music?.available != true
                  ? null
                  : () => unawaited(c.prepareMusic()),
              icon: const Icon(Icons.manage_search, size: 18),
              label: const Text('Buscar músicas')),
          const SizedBox(width: 10),
        ],
        if (c.current != null)
          Text('${c.current!.completedCount} salvas',
              style: const TextStyle(fontSize: 10, color: AppColors.muted)),
      ]));

  Widget _pagination(LibraryController c) => Container(
      height: 45,
      padding: const EdgeInsets.symmetric(horizontal: 25),
      decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.line))),
      child: Row(children: [
        Expanded(
            child: Text(
                c.isExample
                    ? 'Exemplo local · áudio sintético, sem conta'
                    : c.current?.isPartial == true
                        ? 'Leitura pública limitada; confira o total.'
                        : 'A ordem e as repetições são preservadas.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 9, color: AppColors.muted))),
        const SizedBox(width: 10),
        Text(
            c.page.total == 0
                ? '0 faixas'
                : '${c.offset + 1}–${c.offset + c.page.items.length} de ${c.page.total}',
            style: const TextStyle(fontSize: 10, color: AppColors.muted)),
        const SizedBox(width: 6),
        IconButton(
            tooltip: 'Página anterior',
            onPressed: c.offset <= 0 ? null : () => unawaited(c.turnPage(-1)),
            icon: const Icon(Icons.chevron_left, size: 18)),
        IconButton(
            tooltip: 'Próxima página',
            onPressed: c.offset + c.page.items.length >= c.page.total
                ? null
                : () => unawaited(c.turnPage(1)),
            icon: const Icon(Icons.chevron_right, size: 18)),
      ]));

  Widget _downloadBar(LibraryController c) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 27, vertical: 16),
      decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.line))),
      child: Row(children: [
        SizedBox(
            width: 100,
            child: Text('${c.page.selectedCount} selecionadas',
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600))),
        Container(width: 1, height: 30, color: AppColors.line),
        const SizedBox(width: 18),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Salvar em',
              style: TextStyle(fontSize: 9, color: AppColors.muted)),
          const SizedBox(height: 5),
          Tooltip(
              message: c.outputDirectory,
              child: Text(c.outputDirectory,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10))),
        ])),
        const SizedBox(width: 8),
        IconButton(
            tooltip: 'Escolher pasta',
            onPressed: c.busy ? null : () => unawaited(c.chooseOutput()),
            icon: const Icon(Icons.folder_open_outlined, size: 19),
            color: AppColors.muted),
        const SizedBox(width: 12),
        if (c.downloading || c.preparing)
          OutlinedButton(onPressed: c.cancel, child: const Text('Interromper'))
        else
          FilledButton.icon(
              onPressed: c.busy || c.page.selectedCount == 0
                  ? null
                  : () => unawaited(c.downloadSelected()),
              icon: const Icon(Icons.south, size: 15),
              label: const Text('Baixar selecionadas')),
      ]));

  Widget _status(LibraryController c) => Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(children: [
        Expanded(
            child: Tooltip(
                message: c.message,
                child: Text(
                    c.downloading
                        ? '${c.activeTitle} · ${c.progress == null ? 'recebendo' : ('${(c.progress! * 100).round()}% recebidos')}'
                        : c.message.isEmpty
                            ? 'Pronto. Seus arquivos e preferências ficam neste dispositivo.'
                            : c.message,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(fontSize: 9, color: AppColors.muted)))),
        const SizedBox(width: 8),
        TextButton(
            onPressed: () => unawaited(c.openOutput()),
            child: const Text('Abrir pasta', style: TextStyle(fontSize: 10))),
      ]));

  void _focusTrack(Track track, bool wide) {
    widget.controller.focus(track);
    if (!wide) {
      unawaited(showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(),
          builder: (context) => SizedBox(
              height: MediaQuery.sizeOf(context).height * .85,
              child: ListenableBuilder(
                  listenable: widget.controller,
                  builder: (context, _) =>
                      TrackInspector(controller: widget.controller)))));
    }
  }
}

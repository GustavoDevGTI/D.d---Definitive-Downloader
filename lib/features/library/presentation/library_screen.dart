import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../app/theme.dart';
import '../../connections/application/spotify_connection_controller.dart';
import '../../connections/presentation/connections_dialog.dart';
import '../application/library_controller.dart';
import '../../workspace/application/workspace_controller.dart';
import '../../workspace/domain/workspace_models.dart';
import '../../workspace/presentation/capture_workspace.dart';
import '../../workspace/presentation/download_workspace.dart';
import '../../workspace/presentation/history_workspace.dart';
import '../../workspace/presentation/home_workspace.dart';
import '../../workspace/presentation/settings_workspace.dart';
import '../../workspace/presentation/workspace_components.dart';
import 'collection_workspace.dart';
import 'sidebar.dart';

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
  late final _workspace = WorkspaceController(widget.controller);
  late AppSection _section =
      widget.initialPlaylist.isEmpty ? AppSection.home : AppSection.music;
  int _musicTab = 0, _mediaTab = 0;
  @override
  void initState() {
    super.initState();
    unawaited(_workspace.refresh());
    if (widget.showConnectionsOnStart && widget.connections != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showConnections();
      });
    }
  }

  @override
  void dispose() {
    _workspace.dispose();
    super.dispose();
  }

  void _showConnections() {
    if (widget.connections == null) return;
    unawaited(showDialog<void>(
        context: context,
        builder: (_) => ConnectionsDialog(
            controller: widget.connections!,
            deezer: widget.controller.music?.connection,
            allowChanges: !widget.controller.busy)));
  }

  void _navigate(AppSection section, [int tab = 0]) {
    widget.controller.clearMessage();
    setState(() {
      _section = section;
      if (section == AppSection.music) _musicTab = tab;
      if (section == AppSection.media) _mediaTab = tab;
    });
    if (section == AppSection.music && tab == 2) {
      unawaited(_workspace.setCategory(ContentCategory.music));
    } else if (section == AppSection.media && tab == 1) {
      unawaited(_workspace.setCategory(ContentCategory.media));
    } else {
      unawaited(_workspace.refresh());
    }
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.keyO, control: true): () =>
                unawaited(widget.controller.importCsv()),
          },
          child: ListenableBuilder(
              listenable: widget.controller,
              builder: (context, child) =>
                  LayoutBuilder(builder: (context, constraints) {
                    final mobile = constraints.maxWidth < 780;
                    return Scaffold(
                        backgroundColor: Colors.white,
                        bottomNavigationBar: mobile
                            ? MobileNavigation(
                                selected: _section,
                                onSelect: (value) => _navigate(value))
                            : null,
                        body: SafeArea(
                            child: Row(
                                key: const ValueKey('app-edge-to-edge'),
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                              if (!mobile)
                                LibrarySidebar(
                                    selected: _section,
                                    onSelect: (value) => _navigate(value)),
                              Expanded(
                                  child: Padding(
                                      padding: EdgeInsets.fromLTRB(
                                          mobile ? 16 : 28,
                                          mobile ? 18 : 26,
                                          mobile ? 16 : 28,
                                          12),
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            Row(children: [
                                              Expanded(
                                                  child: Text(
                                                      appDestinations[
                                                              _section.index]
                                                          .$2,
                                                      style: const TextStyle(
                                                          fontSize: 22,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          letterSpacing: -.4))),
                                              if (_section ==
                                                      AppSection.music ||
                                                  _section == AppSection.media)
                                                Text(
                                                    _section == AppSection.music
                                                        ? 'Áudio'
                                                        : 'Vídeo / Imagem',
                                                    style: const TextStyle(
                                                        fontSize: 11,
                                                        color:
                                                            AppColors.muted)),
                                            ]),
                                            const SizedBox(height: 20),
                                            Expanded(child: _sections()),
                                            _status(),
                                          ]))),
                            ])));
                  })));

  Widget _sections() => IndexedStack(index: _section.index, children: [
        HomeWorkspace(
            controller: _workspace,
            onNavigate: (section, tab) => _navigate(section, tab)),
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          CategoryTabs(
              labels: const ['Coleções', 'Capturar áudio', 'Downloads'],
              selected: _musicTab,
              onSelect: (tab) => _navigate(AppSection.music, tab)),
          Expanded(
              child: IndexedStack(index: _musicTab, children: [
            CollectionWorkspace(
                controller: widget.controller,
                initialPlaylist: widget.initialPlaylist,
                onConnections:
                    widget.connections == null ? null : _showConnections,
                onDownloads: () => _navigate(AppSection.music, 2)),
            const CaptureWorkspace(category: ContentCategory.music),
            DownloadWorkspace(
                controller: _workspace,
                category: ContentCategory.music,
                onCapture: () => _navigate(AppSection.music, 1)),
          ])),
        ]),
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          CategoryTabs(
              labels: const ['Capturar mídias', 'Downloads'],
              selected: _mediaTab,
              onSelect: (tab) => _navigate(AppSection.media, tab)),
          Expanded(
              child: IndexedStack(index: _mediaTab, children: [
            const CaptureWorkspace(category: ContentCategory.media),
            DownloadWorkspace(
                controller: _workspace,
                category: ContentCategory.media,
                onCapture: () => _navigate(AppSection.media, 0)),
          ])),
        ]),
        HistoryWorkspace(controller: _workspace),
        SettingsWorkspace(
            controller: widget.controller,
            onConnections:
                widget.connections == null ? null : _showConnections),
      ]);

  Widget _status() {
    final c = widget.controller;
    if (c.message.isEmpty && !c.downloading && !c.preparing) {
      return const SizedBox(height: 8);
    }
    return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
            color: const Color(0xFFF2F4F6),
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(4)),
        child: Row(children: [
          Expanded(
              child: Text(
                  c.downloading
                      ? '${c.activeTitle} · ${c.progress == null ? 'recebendo / processando' : '${(c.progress! * 100).round()}% recebidos'}'
                      : c.message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontSize: 11, color: AppColors.muted))),
          if (c.downloading || c.preparing)
            IconButton(
                tooltip: 'Interromper operação atual',
                onPressed: c.cancel,
                icon: const Icon(Icons.stop_circle_outlined, size: 20)),
        ]));
  }
}

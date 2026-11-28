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
import 'playlist_cover_picker.dart';
import 'playlist_destination.dart';
import 'playlist_palette.dart';
import 'collection_track_toolbar.dart';
import 'collection_local_drop_target.dart';
import 'playlist_file_action.dart';
import 'playlist_transcription_page.dart';
import 'spotify_playlist_visibility_dialog.dart';
import '../../connections/presentation/music_connection_actions.dart';
import '../../importing/music_link.dart';
import '../../importing/playlist_catalog.dart';
import '../../importing/spotify_importer.dart';

class CollectionWorkspace extends StatefulWidget {
  const CollectionWorkspace(
      {super.key,
      required this.controller,
      required this.onConnections,
      required this.onDownloads,
      this.buildTabs,
      this.importRequest = 0,
      this.openRequest = 0,
      this.active = true,
      this.keyboardOpen = false,
      this.initialPlaylist = ''});
  final bool active, keyboardOpen;
  final LibraryController controller;
  final VoidCallback? onConnections;
  final VoidCallback onDownloads;
  final Widget Function(VoidCallback? onBack)? buildTabs;
  final String initialPlaylist;
  final int importRequest;

  /// Shows the controller's current playlist, opened from another tab.
  final int openRequest;
  @override
  State<CollectionWorkspace> createState() => _CollectionWorkspaceState();
}

class _CollectionWorkspaceState extends State<CollectionWorkspace> {
  late final _url = TextEditingController(text: widget.initialPlaylist);
  final _query = TextEditingController();
  final _urlFocus = FocusNode();
  final _collectionScroll = ScrollController();
  Timer? _timer;
  Timer? _loginTimer;
  String _lastLoginInput = '';
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
  void didUpdateWidget(covariant CollectionWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.openRequest != widget.openRequest &&
        widget.controller.current != null) {
      _detail = true;
    }
    if (oldWidget.importRequest == widget.importRequest) return;
    _detail = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.active) return;
      if (_collectionScroll.hasClients) _collectionScroll.jumpTo(0);
      if (!widget.controller.importBlocked) _urlFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_requestInspector);
    _timer?.cancel();
    _loginTimer?.cancel();
    _url.dispose();
    _query.dispose();
    _urlFocus.dispose();
    _collectionScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = _buildBody();
    final buildTabs = widget.buildTabs;
    if (buildTabs == null) return body;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      buildTabs(_detail && widget.controller.current != null
          ? () => setState(() => _detail = false)
          : null),
      Expanded(child: body),
    ]);
  }

  Widget _buildBody() {
    final c = widget.controller;
    final collection = c.current;
    if (_detail && collection != null) {
      final rgb = collection.themeColor;
      final accent = rgb == null ? null : Color(0xFF000000 | rgb);
      return PopScope(
          canPop: !widget.active,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop && widget.active) setState(() => _detail = false);
          },
          child: LayoutBuilder(builder: (context, constraints) {
            final wide =
                constraints.maxWidth >= 880 && constraints.maxHeight >= 360;
            _wide = wide;
            final panel =
                Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(
                  flex: 8,
                  child: WorkspacePanel(
                      color: accent == null
                          ? AppColors.surface
                          : Color.alphaBlend(
                              accent.withAlpha(24), Colors.white),
                      borderColor: accent ?? AppColors.line,
                      child: _tracks(c, wide, accent))),
              if (wide) ...[
                const SizedBox(width: 12),
                Expanded(
                    flex: 5,
                    child: WorkspacePanel(
                        borderColor: accent ?? AppColors.line,
                        child: TrackInspector(controller: c)))
              ],
            ]);
            final drop = CollectionLocalDropTarget(
                controller: c, collectionId: collection.id, child: panel);
            return drop;
          }));
    }
    return ListView(
        controller: _collectionScroll,
        padding: EdgeInsets.zero,
        children: [
          LinkEntryPanel(
              title: 'Importar playlist',
              fieldLabel: 'Link da playlist ou faixa',
              hintText: '',
              controller: _url,
              focusNode: _urlFocus,
              inputKey: const ValueKey('playlist-url'),
              enabled: !c.importBlocked,
              onChanged: _offerLogin,
              onSubmitted:
                  c.importBlocked ? null : (value) => unawaited(_import(value)),
              actionLabel: c.importing ? 'Importando…' : 'Importar por link',
              actionIcon: Icons.playlist_add_rounded,
              busy: c.importing,
              busyLabel: c.importing ? c.message : null,
              onAction:
                  c.importBlocked ? null : () => unawaited(_import(_url.text)),
              secondaryActions: [
                PopupMenuButton<String>(
                    key: const ValueKey('playlist-import-options'),
                    tooltip: 'Opções de importação',
                    onSelected: (action) {
                      switch (action) {
                        case 'file':
                          unawaited(importPlaylistFile(context, c));
                        case 'transcribe':
                          unawaited(_transcribe(_url.text.trim()));
                        case 'connections':
                          widget.onConnections?.call();
                      }
                    },
                    itemBuilder: (_) => [
                          PopupMenuItem(
                              value: 'file',
                              enabled: !c.importBlocked,
                              child: const ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(Icons.upload_file_outlined),
                                  title: Text('Importar arquivo'),
                                  subtitle: Text('CSV ou JSON · Ctrl+O'))),
                          PopupMenuItem(
                              value: 'transcribe',
                              enabled: !c.importBlocked,
                              child: const ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(Icons.playlist_add_check),
                                  title: Text('Transcrever playlist'))),
                          PopupMenuItem(
                              value: 'connections',
                              enabled: widget.onConnections != null,
                              child: const ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(Icons.settings_input_component),
                                  title: Text('Conexões'))),
                        ],
                    child: SizedBox(
                        height: AppDensity.of(context).control,
                        child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              Flexible(
                                  child: Text('Outras opções',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.secondary))),
                              SizedBox(width: 6),
                              Icon(Icons.keyboard_arrow_down,
                                  size: 18, color: AppColors.secondary),
                            ])))),
                const MusicConnectionActions(showLabel: true),
                if (c.importing)
                  IconButton(
                      tooltip: 'Cancelar importação',
                      onPressed: c.cancelImport,
                      icon: const Icon(Icons.close,
                          color: AppColors.accentActive)),
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

  Future<void> _import(String value) async {
    final library = widget.controller;
    final before = library.current?.id;
    _loginTimer?.cancel();
    _urlFocus.unfocus();
    Future<bool> importLink() async {
      var needsPublicAccess = false;
      await library.importPlaylist(value,
          onPublicSpotifyRequired: () => needsPublicAccess = true);
      return needsPublicAccess;
    }

    if (await importLink() && mounted && widget.active) {
      await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => SpotifyPlaylistVisibilityDialog(
              playlistId: SpotifyImporter.idFromLink(value),
              retryImport: importLink));
    }
    if (mounted && library.current?.id != before) {
      setState(() => _detail = true);
    }
  }

  Future<void> _transcribe(String input) async {
    final library = widget.controller;
    final before = library.current?.id;
    _loginTimer?.cancel();
    final result = await showPlaylistTranscription(context, library, input);
    if (!mounted || result == null) return;
    await library.saveTranscription(result);
    if (mounted && library.current?.id != before) {
      setState(() => _detail = true);
    }
  }

  bool _isPlaylist(String value) {
    try {
      return PlaylistCatalog.isCollection(value);
    } on FormatException {
      return false;
    }
  }

  void _offerLogin(String raw) {
    _loginTimer?.cancel();
    final value = raw.trim(), access = widget.controller.accounts;
    if (access == null || value == _lastLoginInput || !widget.active) return;
    final uri = Uri.tryParse(value);
    final spotify =
        value.startsWith('spotify:') || uri?.host == 'open.spotify.com';
    final deezer = const {'deezer.com', 'www.deezer.com'}.contains(uri?.host);
    if (!spotify && !deezer) return;
    if (_isPlaylist(value)) return;
    try {
      MusicLink.parse(value);
    } on FormatException {
      return;
    }
    _lastLoginInput = value;
    _loginTimer = Timer(const Duration(milliseconds: 600), () async {
      if (!mounted || widget.controller.importBlocked) return;
      try {
        await access.ensure(value);
      } on FormatException {
        /* Only valid, configured account flows are offered. */
      }
    });
  }

  Widget _tracks(LibraryController c, bool wide, Color? accent) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (!widget.keyboardOpen)
          Padding(
              padding: EdgeInsets.fromLTRB(
                  14, MediaQuery.sizeOf(context).height < 500 ? 0 : 10, 8, 0),
              child: LayoutBuilder(builder: (context, box) {
                final selected = c.page.selectedCount;
                final preparation = c.preparationLabelFor(c.current!.id);
                final selectionLabel = [
                  if (selected > 0)
                    '$selected ${selected == 1 ? 'selecionada' : 'selecionadas'}',
                  if (preparation != null) preparation,
                ].join(' · ');
                return Row(children: [
                  PlaylistCoverButton(
                      library: c, playlist: c.current!, size: 28),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(c.current!.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600))),
                  PlaylistDestinationButton(library: c, playlist: c.current!),
                  if (selectionLabel.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: box.maxWidth / 2),
                        child: Tooltip(
                            message: selectionLabel,
                            child: Text(selectionLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 11, color: AppColors.muted)))),
                  ],
                ]);
              })),
        CollectionTrackToolbar(
            controller: c,
            accent: accent,
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
        if (c.importing || c.preparingCurrent || c.addingLinks)
          LinearProgressIndicator(minHeight: 2, color: playlistInk(accent)),
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
                controller: c,
                accent: accent,
                onFocus: (track) => _focus(track, wide))),
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
            clipBehavior: Clip.antiAlias,
            builder: (context) => SizedBox(
                height: MediaQuery.sizeOf(context).height * .9,
                child: ListenableBuilder(
                    listenable: widget.controller,
                    builder: (context, child) =>
                        TrackInspector(controller: widget.controller))))
        .whenComplete(() => _inspectorOpen = false));
  }
}

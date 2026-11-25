import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme.dart';
import '../../../app/brand.dart';
import '../../../app/app_notice.dart';
import '../../connections/application/trackhop_connection.dart';
import '../../connections/presentation/connections_dialog.dart';
import '../../connections/domain/music_account.dart';
import '../../connections/presentation/account_request_dialog.dart';
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
import 'playlist_file_action.dart';
import 'sidebar.dart';
import 'library_operation_status.dart';
import '../../player/application/music_player_controller.dart';
import '../../player/presentation/player_scope.dart';
import '../../player/presentation/player_bar.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    super.key,
    required this.controller,
    this.player,
    this.connections,
    this.initialPlaylist = '',
    this.showConnectionsOnStart = false,
  });
  final LibraryController controller;
  final MusicPlayerController? player;
  final TrackhopConnection? connections;
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
  int _inspectorRequest = 0;
  int _playlistImportRequest = 0;
  VoidCallback? _returnFromPlaylist;
  @override
  void initState() {
    super.initState();
    widget.controller.accounts?.requestLogin = _requestAccount;
    unawaited(widget.player?.setModuleActive(_section == AppSection.music));
    _inspectorRequest = widget.controller.inspectorRequest;
    widget.controller.addListener(_requestInspector);
    unawaited(_workspace.refresh());
    if (widget.showConnectionsOnStart && widget.connections != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showConnections();
      });
    }
  }

  @override
  void dispose() {
    widget.controller.accounts?.requestLogin = null;
    widget.controller.removeListener(_requestInspector);
    _workspace.dispose();
    widget.player?.dispose();
    super.dispose();
  }

  void _requestInspector() {
    if (!mounted || _inspectorRequest == widget.controller.inspectorRequest) {
      return;
    }
    _inspectorRequest = widget.controller.inspectorRequest;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(widget.player?.setModuleActive(true));
        setState(() {
          _section = AppSection.music;
          _musicTab = 0;
        });
      }
    });
  }

  void _showConnections() {
    if (widget.connections == null) return;
    unawaited(
      showDialog<void>(
        context: context,
        builder: (_) => ConnectionsDialog(
          controller: widget.connections!,
          deezer: widget.controller.music?.connection,
          allowChanges: !widget.controller.busy,
        ),
      ),
    );
  }

  Future<MusicAccountDecision> _requestAccount(
    MusicAccount account, {
    required bool allowLater,
  }) async {
    final spotify = widget.connections,
        deezer = widget.controller.music?.connection;
    if (!mounted || spotify == null || deezer == null) {
      return MusicAccountDecision.cancelled;
    }
    return await showDialog<MusicAccountDecision>(
          context: context,
          barrierDismissible: false,
          builder: (_) => AccountRequestDialog(
            account: account,
            trackhop: spotify,
            deezer: deezer,
            allowLater: allowLater,
          ),
        ) ??
        MusicAccountDecision.cancelled;
  }

  void _navigate(AppSection section, [int tab = 0]) {
    unawaited(widget.player?.setModuleActive(section == AppSection.music));
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

  void _returnToCollections() {
    final back = _returnFromPlaylist;
    _returnFromPlaylist = null;
    back?.call();
    _navigate(AppSection.music);
  }

  @override
  Widget build(BuildContext context) => PlayerScope(
        player: widget.player,
        child: AppNoticeHost(
          listenable: Listenable.merge([widget.controller, _workspace]),
          readMessage: () {
            final c = widget.controller;
            if (!c.importBlocked && !c.searching && c.message.isNotEmpty) {
              return c.message;
            }
            return _workspace.message;
          },
          acknowledge: (message) {
            widget.controller.acknowledgeMessage(message);
            _workspace.acknowledgeMessage(message);
          },
          child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.keyO, control: true):
                  () =>
                      unawaited(importPlaylistFile(context, widget.controller)),
              if (widget.player != null && _section == AppSection.music) ...{
                const SingleActivator(LogicalKeyboardKey.mediaPlayPause): () =>
                    unawaited(widget.player!.toggle()),
                const SingleActivator(LogicalKeyboardKey.mediaTrackNext): () =>
                    unawaited(widget.player!.next()),
                const SingleActivator(LogicalKeyboardKey.mediaTrackPrevious):
                    () => unawaited(widget.player!.previous()),
              },
            },
            child: ListenableBuilder(
              listenable: widget.controller,
              builder: (context, child) => LayoutBuilder(
                builder: (context, constraints) {
                  final short = constraints.maxHeight < 500;
                  final mobile = constraints.maxWidth < 780 || short;
                  final landscape =
                      mobile && short && constraints.maxWidth >= 600;
                  final typing = MediaQuery.viewInsetsOf(context).bottom > 0;
                  return Scaffold(
                    backgroundColor: AppColors.background,
                    bottomNavigationBar: mobile && !typing && !landscape
                        ? MobileNavigation(
                            selected: _section,
                            onSelect: (value) => _navigate(value),
                          )
                        : null,
                    body: SafeArea(
                      child: Row(
                        key: const ValueKey('app-edge-to-edge'),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (landscape && !typing)
                            MobileLandscapeNavigation(
                              selected: _section,
                              onSelect: (value) => _navigate(value),
                            ),
                          if (!mobile)
                            LibrarySidebar(
                              selected: _section,
                              onSelect: (value) => _navigate(value),
                            ),
                          Expanded(
                            child: Column(
                              children: [
                                Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.fromLTRB(
                                      mobile ? 16 : 14,
                                      mobile
                                          ? (short || typing ? 8 : 18)
                                          : AppDensity.of(context).pageTop,
                                      mobile ? 16 : 14,
                                      mobile ? 12 : 6,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        if (!(mobile && (short || typing))) ...[
                                          _heading(mobile),
                                          SizedBox(
                                            height: mobile
                                                ? 12
                                                : _section == AppSection.home
                                                    ? 24
                                                    : 12,
                                          ),
                                        ],
                                        Expanded(child: _sections()),
                                        LibraryOperationStatus(
                                          controller: widget.controller,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (widget.player != null &&
                                    _section == AppSection.music &&
                                    !typing)
                                  PlayerBar(player: widget.player!),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );

  Widget _heading(bool mobile) {
    if (_section == AppSection.home) {
      return LayoutBuilder(
        builder: (context, constraints) => BrandLockup(
          stacked: constraints.maxWidth < 420,
          markSize: mobile ? 36 : 34,
          fontSize: mobile ? 16 : 20,
        ),
      );
    }
    return Row(
      children: [
        if (mobile) ...[const BrandMark(size: 28), const SizedBox(width: 10)],
        Expanded(
          child: Text(
            appDestinations[_section.index].$2,
            style: TextStyle(
              fontSize: mobile ? 22 : 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -.4,
            ),
          ),
        ),
        if (_section == AppSection.music || _section == AppSection.media)
          Text(
            _section == AppSection.music ? 'Áudio' : 'Vídeo / Imagem',
            style: const TextStyle(fontSize: 11, color: AppColors.muted),
          ),
      ],
    );
  }

  Widget _musicTabs({VoidCallback? onBack}) =>
      MediaQuery.viewInsetsOf(context).bottom > 0 &&
              MediaQuery.sizeOf(context).height < 500
          ? const SizedBox.shrink()
          : CategoryTabs(
              labels: const ['Coleções', 'Capturar áudio', 'Downloads'],
              selected: _musicTab,
              dense: _musicTab == 2 && MediaQuery.sizeOf(context).width >= 780,
              bottomSpacing: _musicTab == 2 ? 8 : 20,
              onBack: onBack,
              onSelect: (tab) => _navigate(AppSection.music, tab),
            );

  Widget _sections() => IndexedStack(
        index: _section.index,
        children: [
          HomeWorkspace(
            controller: _workspace,
            onNavigate: (section, tab) => _navigate(section, tab),
            onImportPlaylist: () {
              _playlistImportRequest++;
              _navigate(AppSection.music);
            },
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_musicTab != 0)
                _musicTabs(
                    onBack: _returnFromPlaylist == null
                        ? null
                        : _returnToCollections),
              Expanded(
                child: IndexedStack(
                  index: _musicTab,
                  children: [
                    CollectionWorkspace(
                      controller: widget.controller,
                      active: _section == AppSection.music && _musicTab == 0,
                      keyboardOpen: MediaQuery.viewInsetsOf(context).bottom > 0,
                      initialPlaylist: widget.initialPlaylist,
                      importRequest: _playlistImportRequest,
                      buildTabs: (onBack) {
                        _returnFromPlaylist = onBack;
                        return _musicTabs(onBack: onBack);
                      },
                      onConnections:
                          widget.connections == null ? null : _showConnections,
                      onDownloads: () => _navigate(AppSection.music, 2),
                    ),
                    CaptureWorkspace(
                      category: ContentCategory.music,
                      library: widget.controller,
                      onDownloads: () => _navigate(AppSection.music, 2),
                    ),
                    DownloadWorkspace(
                      controller: _workspace,
                      keyboardOpen: MediaQuery.viewInsetsOf(context).bottom > 0,
                      category: ContentCategory.music,
                      onCapture: () => _navigate(AppSection.music, 1),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (MediaQuery.viewInsetsOf(context).bottom == 0 ||
                  MediaQuery.sizeOf(context).height >= 500)
                CategoryTabs(
                  labels: const ['Capturar mídias', 'Downloads'],
                  selected: _mediaTab,
                  onSelect: (tab) => _navigate(AppSection.media, tab),
                ),
              Expanded(
                child: IndexedStack(
                  index: _mediaTab,
                  children: [
                    const CaptureWorkspace(category: ContentCategory.media),
                    DownloadWorkspace(
                      controller: _workspace,
                      keyboardOpen: MediaQuery.viewInsetsOf(context).bottom > 0,
                      category: ContentCategory.media,
                      onCapture: () => _navigate(AppSection.media, 0),
                    ),
                  ],
                ),
              ),
            ],
          ),
          HistoryWorkspace(controller: _workspace),
          SettingsWorkspace(
            controller: widget.controller,
            onConnections: widget.connections == null ? null : _showConnections,
          ),
        ],
      );
}

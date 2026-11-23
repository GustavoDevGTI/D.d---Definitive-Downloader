import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../app/app_notice.dart';
import '../../library/application/library_controller.dart';
import '../../library/domain/models.dart';
import '../../workspace/presentation/workspace_components.dart';
import '../application/collection_organization_controller.dart';
import '../data/collection_organization_repository.dart';
import '../domain/collection_organization.dart';
import 'organization_name_dialog.dart';
import 'collection_group_strip.dart';
import '../../library/presentation/playlist_cover_picker.dart';
import '../../library/presentation/collection_local_drop_target.dart';

class CollectionManager extends StatefulWidget {
  const CollectionManager(
      {super.key, required this.library, required this.onOpen});
  final LibraryController library;
  final ValueChanged<Collection> onOpen;
  @override
  State<CollectionManager> createState() => _CollectionManagerState();
}

class _CollectionManagerState extends State<CollectionManager> {
  late final _controller = CollectionOrganizationController(
      CollectionOrganizationRepository(widget.library.repository.database));
  final _search = TextEditingController();
  Timer? _timer;
  List<Collection> _lastCollections = const [];
  @override
  void initState() {
    super.initState();
    widget.library.addListener(_libraryChanged);
    _lastCollections = widget.library.collections;
    unawaited(_controller.refresh());
  }

  void _libraryChanged() {
    final library = widget.library;
    if (library.importBlocked ||
        identical(_lastCollections, library.collections)) {
      return;
    }
    if (library.preparing &&
        listEquals(_lastCollections.map((c) => c.id).toList(),
            library.collections.map((c) => c.id).toList())) {
      return;
    }
    _lastCollections = library.collections;
    unawaited(_controller.refresh());
  }

  @override
  void dispose() {
    widget.library.removeListener(_libraryChanged);
    _timer?.cancel();
    _search.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: Listenable.merge([_controller, widget.library]),
      builder: (context, _) {
        final c = _controller;
        final enabled = !widget.library.busy && !c.saving;
        final group = c.groups.where((g) => g.id == c.groupId).firstOrNull;
        return CollectionLocalDropTarget(
            key: const ValueKey('collection-folder-drop'),
            controller: widget.library,
            groupId: group?.id,
            onFolderImported: widget.onOpen,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    const Expanded(
                        child: Text('Playlists',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w700))),
                    if (defaultTargetPlatform == TargetPlatform.android)
                      IconButton(
                          key: const ValueKey('import-audio-folder'),
                          tooltip: 'Importar pasta de áudio',
                          onPressed: !widget.library.importBlocked && !c.saving
                              ? () async {
                                  final playlist = await widget.library
                                      .chooseLocalFolder(groupId: group?.id);
                                  if (mounted && playlist != null) {
                                    widget.onOpen(playlist);
                                  }
                                }
                              : null,
                          icon:
                              const Icon(Icons.folder_open_outlined, size: 22)),
                  ]),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                      builder: (context, box) => Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                SizedBox(
                                    width: box.maxWidth < 480
                                        ? box.maxWidth
                                        : box.maxWidth - 160,
                                    child: TextField(
                                        key: const ValueKey('search-playlists'),
                                        controller: _search,
                                        maxLength: 160,
                                        decoration: InputDecoration(
                                            hintText: 'Buscar playlists',
                                            counterText: '',
                                            prefixIcon: const Icon(Icons.search,
                                                size: 19),
                                            suffixIcon: _search.text.isEmpty
                                                ? null
                                                : IconButton(
                                                    tooltip: 'Limpar busca',
                                                    icon: const Icon(
                                                        Icons.close,
                                                        size: 18),
                                                    onPressed: () {
                                                      _timer?.cancel();
                                                      _search.clear();
                                                      unawaited(c.filter(
                                                          '', c.groupId));
                                                    })),
                                        onChanged: (value) {
                                          setState(() {});
                                          _timer?.cancel();
                                          _timer = Timer(
                                              const Duration(milliseconds: 300),
                                              () => unawaited(
                                                  c.filter(value, c.groupId)));
                                        })),
                                FilledButton.icon(
                                    key: const ValueKey('create-playlist'),
                                    onPressed: !widget.library.importBlocked &&
                                            !c.saving
                                        ? () => _editPlaylist()
                                        : null,
                                    style: FilledButton.styleFrom(
                                        minimumSize: Size(
                                            0, AppDensity.of(context).control),
                                        visualDensity: VisualDensity.standard,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10))),
                                    icon: const Icon(Icons.add, size: 18),
                                    label: const Text('Nova playlist')),
                              ])),
                  const SizedBox(height: 10),
                  if (c.groups.isNotEmpty)
                    CollectionGroupStrip(
                        groups: c.groups,
                        selected: c.groupId,
                        onSelect: (id) {
                          _timer?.cancel();
                          unawaited(c.filter(_search.text, id));
                        },
                        onRename: enabled && group != null
                            ? () => unawaited(_editGroup(group))
                            : null,
                        onRemove: enabled && group != null
                            ? () => unawaited(_removeGroup(group))
                            : null),
                  const SizedBox(height: 12),
                  if (c.loading && c.listing.items.isEmpty)
                    const Text('Carregando playlists…',
                        style: TextStyle(fontSize: 12, color: AppColors.muted)),
                  if (c.error.isNotEmpty)
                    Row(children: [
                      Expanded(child: Text(c.error)),
                      TextButton(
                          onPressed: c.refresh,
                          child: const Text('Tentar novamente'))
                    ])
                  else if (!c.loading && c.listing.total == 0)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                            c.query.isNotEmpty
                                ? 'Nenhuma playlist encontrada.'
                                : c.groupId == null
                                    ? 'Crie uma playlist ou importe por link.'
                                    : 'Nenhuma playlist nesta pasta.',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.muted))),
                  for (final item in c.listing.items)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: LayoutBuilder(builder: (context, box) {
                          final themeColor = item.themeColor;
                          final accent = themeColor == null
                              ? null
                              : Color(0xFF000000 | themeColor);
                          final progress =
                              widget.library.preparationProgressFor(item.id);
                          final tile = CollectionLocalDropTarget(
                              controller: widget.library,
                              collectionId: item.id,
                              child: Stack(children: [
                                WorkspaceNavigationButton(
                                    key: ValueKey('collection-open-${item.id}'),
                                    title: item.name,
                                    subtitle: [
                                      '${item.trackCount} faixas',
                                      '${item.completedCount} baixadas',
                                      if (_groupName(item) case final name?)
                                        name,
                                      if (widget.library
                                              .preparationLabelFor(item.id)
                                          case final status?)
                                        status,
                                      if (progress != null)
                                        '${progress.checked}/${progress.total} conferidas',
                                    ].join(' · '),
                                    leading: SizedBox.square(
                                        dimension:
                                            AppDensity.of(context).control),
                                    icon: Icons.library_music_outlined,
                                    accent: accent,
                                    onPressed: () => widget.onOpen(item)),
                                Positioned(
                                    left: 14,
                                    top: 0,
                                    bottom: 0,
                                    child: Center(
                                        child: PlaylistCoverButton(
                                            library: widget.library,
                                            playlist: item,
                                            size: AppDensity.of(context)
                                                .control))),
                              ]));
                          return Row(children: [
                            Expanded(child: tile),
                            const SizedBox(width: 8),
                            _playlistMenu(item, enabled, box.maxWidth >= 600),
                          ]);
                        })),
                  if (c.listing.total > 0)
                    PageControls(
                        offset: c.offset,
                        count: c.listing.items.length,
                        total: c.listing.total,
                        onPage: (v) => unawaited(c.turnPage(v)),
                        label: 'playlists',
                        showDivider: false),
                ]));
      });

  Widget _playlistMenu(Collection item, bool enabled, bool showLabel) =>
      PopupMenuButton<String>(
          key: ValueKey('collection-menu-${item.id}'),
          tooltip: 'Gerenciar playlist',
          enabled: enabled,
          onSelected: (action) {
            switch (action) {
              case 'rename':
                unawaited(_editPlaylist(item));
              case 'new-group':
                unawaited(_editGroup(null, item));
              case 'move':
                unawaited(_move(item));
              case 'delete':
                unawaited(_removePlaylist(item));
            }
          },
          itemBuilder: (_) => [
                for (final action in const [
                  ('rename', Icons.edit_outlined, 'Editar playlist'),
                  (
                    'new-group',
                    Icons.create_new_folder_outlined,
                    'Nova pasta com esta playlist'
                  ),
                  ('move', Icons.drive_file_move_outline, 'Mover para pasta'),
                  ('delete', Icons.delete_outline, 'Excluir playlist'),
                ])
                  PopupMenuItem(
                      key: ValueKey('collection-${action.$1}-${item.id}'),
                      value: action.$1,
                      child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(action.$2,
                              color: action.$1 == 'delete'
                                  ? AppColors.accentActive
                                  : AppColors.secondary),
                          title: Text(action.$3))),
              ],
          child: Padding(
              padding: EdgeInsets.all(AppDensity.of(context).desktop ? 10 : 14),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.tune_rounded,
                    size: 20, color: AppColors.secondary),
                if (showLabel) ...[
                  const SizedBox(width: 8),
                  const Text('Gerenciar',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.secondary)),
                ],
              ])));
  Future<void> _removePlaylist(Collection item) async {
    final approved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Excluir playlist?'),
                content: Text(
                    'Excluir “${item.name}” da biblioteca? Os arquivos baixados e o histórico em Arquivos serão preservados.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Excluir playlist'))
                ]));
    if (approved != true || !mounted) return;
    final error = await _controller.mutate(() async {
      if (widget.library.busy) {
        throw const FormatException('Aguarde a operação em andamento.');
      }
      await _controller.repository.remove(item.id);
      await widget.library.refresh();
    });
    if (error != null && mounted) await showAppNotice(context, message: error);
  }

  String? _groupName(Collection item) =>
      _controller.groups.where((g) => g.id == item.groupId).firstOrNull?.name;

  Future<void> _editPlaylist([Collection? item]) async {
    final usedColors = item == null
        ? const <int>{}
        : await _controller.repository.usedThemeColors(item.id);
    if (!mounted) return;
    int? createdId;
    final saved = await showDialog<bool>(
        context: context,
        builder: (_) => OrganizationNameDialog(
            title: item == null ? 'Nova playlist' : 'Editar playlist',
            name: item?.name ?? '',
            playlistColor: item?.themeColor,
            usedPlaylistColors: usedColors,
            groups: item == null ? _controller.groups : null,
            groupId: _controller.groupId == 0 ? null : _controller.groupId,
            onSaveWithLink: item != null
                ? null
                : (name, groupId, link) => _controller.mutate(() async {
                      createdId = await widget.library
                          .createPlaylist(name, groupId: groupId, link: link);
                    }),
            onCancel: widget.library.cancelImport,
            progress: ListenableBuilder(
                listenable: widget.library,
                builder: (context, _) =>
                    Column(mainAxisSize: MainAxisSize.min, children: [
                      const LinearProgressIndicator(minHeight: 2),
                      if (widget.library.linkProgress.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(widget.library.linkProgress,
                            style: const TextStyle(fontSize: 12)),
                      ]
                    ])),
            onSave: (name, groupId, color) => _controller.mutate(() async {
                  if (item == null
                      ? widget.library.importBlocked
                      : widget.library.busy) {
                    throw const FormatException(
                        'Aguarde a operação em andamento.');
                  }
                  if (item == null) {
                    createdId = await _controller.repository
                        .create(name, groupId: groupId);
                  } else {
                    await _controller.repository
                        .rename(item.id, name, themeColor: color);
                  }
                  await widget.library.refresh();
                })));
    if (saved == true && createdId != null && mounted) {
      final created =
          await widget.library.repository.collectionById(createdId!);
      if (created != null && mounted) widget.onOpen(created);
    }
  }

  Future<void> _editGroup([CollectionGroup? group, Collection? item]) async {
    await showDialog<bool>(
        context: context,
        builder: (_) => OrganizationNameDialog(
            title: group == null ? 'Nova pasta' : 'Renomear pasta',
            name: group?.name ?? '',
            maxLength: 80,
            onSave: (name, _, __) => _controller.mutate(() async {
                  if (widget.library.busy) {
                    throw const FormatException(
                        'Aguarde a operação em andamento.');
                  }
                  await _controller.repository
                      .saveGroup(name, id: group?.id, collectionId: item?.id);
                  await widget.library.refresh();
                })));
  }

  Future<void> _removeGroup(CollectionGroup group) async {
    final remove = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Remover pasta?'),
                content: Text(
                    'Remover a pasta “${group.name}” da organização das playlists?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Remover pasta'))
                ]));
    if (remove != true || !mounted) return;
    final error = await _controller.mutate(() async {
      if (widget.library.busy) {
        throw const FormatException('Aguarde a operação em andamento.');
      }
      await _controller.repository.removeGroup(group.id);
    });
    if (error != null && mounted) await showAppNotice(context, message: error);
  }

  Future<void> _move(Collection item) async {
    await showDialog<bool>(
        context: context,
        builder: (_) => OrganizationNameDialog(
            title: 'Mover para pasta',
            name: item.name,
            groups: _controller.groups,
            groupId: item.groupId,
            nameEditable: false,
            onSave: (_, groupId, __) => _controller.mutate(() async {
                  if (widget.library.busy) {
                    throw const FormatException(
                        'Aguarde a operação em andamento.');
                  }
                  await _controller.repository.move(item.id, groupId);
                  await widget.library.refresh();
                })));
  }
}

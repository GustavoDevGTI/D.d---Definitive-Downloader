import 'dart:async';
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
import '../../library/data/artwork_store.dart';
import '../../library/presentation/artwork_thumbnail.dart';
import '../../library/presentation/collection_mp3_drop_target.dart';

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
  Object? _lastCollections;
  @override
  void initState() {
    super.initState();
    widget.library.addListener(_libraryChanged);
    _lastCollections = widget.library.collections;
    unawaited(_controller.refresh());
  }

  void _libraryChanged() {
    if (!widget.library.busy &&
        !identical(_lastCollections, widget.library.collections)) {
      _lastCollections = widget.library.collections;
      unawaited(_controller.refresh());
    }
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
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                const Expanded(
                    child: Text('Minhas coleções',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600))),
                TextButton.icon(
                    key: const ValueKey('create-playlist'),
                    onPressed: enabled ? () => _editPlaylist() : null,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Nova playlist')),
              ]),
              const SizedBox(height: 8),
              TextField(
                  key: const ValueKey('search-playlists'),
                  controller: _search,
                  maxLength: 160,
                  decoration: InputDecoration(
                      hintText: 'Buscar playlists',
                      counterText: '',
                      prefixIcon: const Icon(Icons.search, size: 19),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Limpar busca',
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () {
                                _timer?.cancel();
                                _search.clear();
                                unawaited(c.filter('', c.groupId));
                              })),
                  onChanged: (value) {
                    setState(() {});
                    _timer?.cancel();
                    _timer = Timer(const Duration(milliseconds: 300),
                        () => unawaited(c.filter(value, c.groupId)));
                  }),
              const SizedBox(height: 10),
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
                                : 'Nenhuma playlist neste grupo.',
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
                      final tile = CollectionMp3DropTarget(
                          controller: widget.library,
                          collectionId: item.id,
                          child: WorkspaceNavigationButton(
                              key: ValueKey('collection-open-${item.id}'),
                              title: item.name,
                              subtitle:
                                  '${item.trackCount} faixas · ${item.completedCount} baixadas · ${item.source}${_groupLabel(item)}',
                              leading: ArtworkThumbnail(
                                  reference: item.coverPath,
                                  size: 44,
                                  placeholderColor: accent == null
                                      ? AppColors.surface
                                      : Color.alphaBlend(
                                          accent.withAlpha(42), Colors.white),
                                  icon: Icons.library_music_outlined),
                              icon: Icons.library_music_outlined,
                              accent: accent,
                              onPressed: () => widget.onOpen(item)));
                      final actions =
                          Row(mainAxisSize: MainAxisSize.min, children: [
                        _action(
                            'Novo grupo com esta playlist',
                            Icons.create_new_folder_outlined,
                            enabled
                                ? () => unawaited(_editGroup(null, item))
                                : null,
                            item.id,
                            'new-group'),
                        _action(
                            'Editar playlist',
                            Icons.edit_outlined,
                            enabled
                                ? () => unawaited(_editPlaylist(item))
                                : null,
                            item.id,
                            'rename'),
                        _action(
                            'Alterar capa',
                            Icons.add_photo_alternate_outlined,
                            enabled ? () => unawaited(_cover(item)) : null,
                            item.id,
                            'cover'),
                        _action(
                            'Mover para grupo',
                            Icons.drive_file_move_outline,
                            enabled ? () => unawaited(_move(item)) : null,
                            item.id,
                            'move'),
                        _action(
                            'Excluir playlist',
                            Icons.delete_outline,
                            enabled
                                ? () => unawaited(_removePlaylist(item))
                                : null,
                            item.id,
                            'delete'),
                      ]);
                      return box.maxWidth < 600
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                  tile,
                                  Align(
                                      alignment: Alignment.centerRight,
                                      child: actions)
                                ])
                          : Row(children: [
                              Expanded(child: tile),
                              const SizedBox(width: 8),
                              actions
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
            ]);
      });

  Widget _action(String label, IconData icon, VoidCallback? onPressed, int id,
          String action) =>
      IconButton(
          key: ValueKey('collection-$action-$id'),
          tooltip: label,
          onPressed: onPressed,
          color: AppColors.accentActive,
          icon: Icon(icon, size: 19));
  Future<void> _cover(Collection item) async {
    try {
      final path = await widget.library.files.chooseCover();
      if (path == null || !mounted) return;
      final error = await _controller.mutate(() async {
        if (widget.library.busy) {
          throw const FormatException('Aguarde a operação em andamento.');
        }
        final cover = await ArtworkStore.shared
            .importCover(path, await widget.library.files.dataDirectory());
        await _controller.repository.setCover(item.id, cover);
        await widget.library.refresh();
      });
      if (error != null && mounted) {
        await showAppNotice(context, message: error);
      }
    } catch (_) {
      if (mounted) {
        await showAppNotice(context,
            message:
                'Não foi possível usar a imagem. Escolha PNG, JPEG ou WebP de até 5 MB.');
      }
    }
  }

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

  String _groupLabel(Collection item) {
    final group =
        _controller.groups.where((g) => g.id == item.groupId).firstOrNull;
    return group == null ? '' : ' · ${group.name}';
  }

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
            onCancel: widget.library.cancel,
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
                  if (widget.library.busy) {
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
            title: group == null ? 'Novo grupo' : 'Renomear grupo',
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
                title: const Text('Remover grupo?'),
                content: Text(
                    'As playlists de “${group.name}” ficarão sem grupo. As faixas e os arquivos serão preservados.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Remover grupo'))
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
            title: 'Mover para grupo',
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

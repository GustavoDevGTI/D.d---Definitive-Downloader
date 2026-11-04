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
              Row(children: [
                Expanded(
                    child: DropdownButtonFormField<int>(
                        key: ValueKey('group-filter-${c.groupId}'),
                        initialValue: c.groupId ?? -1,
                        isExpanded: true,
                        menuMaxHeight: 320,
                        selectedItemBuilder: (_) => [
                              const Text('Todas'),
                              const Text('Sem grupo',
                                  overflow: TextOverflow.ellipsis),
                              for (final g in c.groups)
                                Text('${g.name} (${g.count})',
                                    overflow: TextOverflow.ellipsis),
                            ],
                        decoration: const InputDecoration(
                            labelText: 'Grupo',
                            prefixIcon: Icon(Icons.folder_outlined, size: 19)),
                        items: [
                          const DropdownMenuItem(
                              value: -1, child: Text('Todas as playlists')),
                          const DropdownMenuItem(
                              value: 0, child: Text('Sem grupo')),
                          for (final g in c.groups)
                            DropdownMenuItem(
                                value: g.id,
                                child: Text('${g.name} (${g.count})',
                                    overflow: TextOverflow.ellipsis))
                        ],
                        onChanged: (v) {
                          _timer?.cancel();
                          unawaited(c.filter(_search.text, v == -1 ? null : v));
                        })),
                const SizedBox(width: 6),
                PopupMenuButton<String>(
                    tooltip: 'Gerenciar grupos',
                    enabled: enabled,
                    icon: const Icon(Icons.create_new_folder_outlined,
                        color: AppColors.accentActive),
                    onSelected: (v) {
                      if (v == 'new') {
                        unawaited(_editGroup());
                      }
                      if (v == 'rename' && group != null) {
                        unawaited(_editGroup(group));
                      }
                      if (v == 'remove' && group != null) {
                        unawaited(_removeGroup(group));
                      }
                    },
                    itemBuilder: (_) => [
                          const PopupMenuItem(
                              value: 'new', child: Text('Novo grupo')),
                          if (group != null) ...[
                            const PopupMenuItem(
                                value: 'rename', child: Text('Renomear grupo')),
                            const PopupMenuItem(
                                value: 'remove', child: Text('Remover grupo'))
                          ]
                        ]),
              ]),
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
                    child: Row(children: [
                      Expanded(
                          child: WorkspaceNavigationButton(
                              key: ValueKey('collection-open-${item.id}'),
                              title: item.name,
                              subtitle:
                                  '${item.trackCount} faixas · ${item.source}${item.isPartial ? ' · parcial' : ''}${_groupLabel(item)}',
                              icon: Icons.library_music_outlined,
                              onPressed: () => widget.onOpen(item))),
                      PopupMenuButton<String>(
                          key: ValueKey('collection-actions-${item.id}'),
                          tooltip: 'Organizar ${item.name}',
                          enabled: enabled,
                          icon: const Icon(Icons.more_horiz,
                              color: AppColors.accentActive),
                          onSelected: (v) {
                            if (v == 'rename') {
                              unawaited(_editPlaylist(item));
                            } else {
                              unawaited(_move(item));
                            }
                          },
                          itemBuilder: (_) => const [
                                PopupMenuItem(
                                    value: 'rename',
                                    child: Text('Renomear playlist')),
                                PopupMenuItem(
                                    value: 'move',
                                    child: Text('Mover para grupo'))
                              ]),
                    ])),
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

  String _groupLabel(Collection item) {
    final group =
        _controller.groups.where((g) => g.id == item.groupId).firstOrNull;
    return group == null ? '' : ' · ${group.name}';
  }

  Future<void> _editPlaylist([Collection? item]) async {
    int? createdId;
    final saved = await showDialog<bool>(
        context: context,
        builder: (_) => _NameDialog(
            title: item == null ? 'Nova playlist' : 'Renomear playlist',
            name: item?.name ?? '',
            groups: item == null ? _controller.groups : null,
            groupId: _controller.groupId == 0 ? null : _controller.groupId,
            onSave: (name, groupId) => _controller.mutate(() async {
                  if (widget.library.busy) {
                    throw const FormatException(
                        'Aguarde a operação em andamento.');
                  }
                  if (item == null) {
                    createdId = await _controller.repository
                        .create(name, groupId: groupId);
                  } else {
                    await _controller.repository.rename(item.id, name);
                  }
                  await widget.library.refresh();
                })));
    if (saved == true && createdId != null && mounted) {
      final created =
          await widget.library.repository.collectionById(createdId!);
      if (created != null && mounted) widget.onOpen(created);
    }
  }

  Future<void> _editGroup([CollectionGroup? group]) async {
    await showDialog<bool>(
        context: context,
        builder: (_) => _NameDialog(
            title: group == null ? 'Novo grupo' : 'Renomear grupo',
            name: group?.name ?? '',
            maxLength: 80,
            onSave: (name, _) => _controller.mutate(() async {
                  if (widget.library.busy) {
                    throw const FormatException(
                        'Aguarde a operação em andamento.');
                  }
                  await _controller.repository.saveGroup(name, id: group?.id);
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
        builder: (_) => _NameDialog(
            title: 'Mover para grupo',
            name: item.name,
            groups: _controller.groups,
            groupId: item.groupId,
            nameEditable: false,
            onSave: (_, groupId) => _controller.mutate(() async {
                  if (widget.library.busy) {
                    throw const FormatException(
                        'Aguarde a operação em andamento.');
                  }
                  await _controller.repository.move(item.id, groupId);
                  await widget.library.refresh();
                })));
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog(
      {required this.title,
      required this.name,
      required this.onSave,
      this.groups,
      this.groupId,
      this.maxLength = 160,
      this.nameEditable = true});
  final String title, name;
  final int maxLength;
  final bool nameEditable;
  final List<CollectionGroup>? groups;
  final int? groupId;
  final Future<String?> Function(String, int?) onSave;
  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _name = TextEditingController(text: widget.name);
  late int? _groupId = widget.groupId;
  String? _error;
  bool _saving = false;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await widget.onSave(_name.text, _groupId);
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _saving = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_saving,
      child: AlertDialog(
          title: Text(widget.title),
          content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    if (widget.nameEditable)
                      TextField(
                          key: const ValueKey('organization-name'),
                          controller: _name,
                          autofocus: true,
                          enabled: !_saving,
                          maxLength: widget.maxLength,
                          decoration: const InputDecoration(labelText: 'Nome'),
                          onSubmitted: (_) => unawaited(_save()))
                    else
                      Text(widget.name,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (widget.groups != null) ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                          initialValue: _groupId ?? 0,
                          isExpanded: true,
                          menuMaxHeight: 300,
                          decoration: const InputDecoration(labelText: 'Grupo'),
                          items: [
                            const DropdownMenuItem(
                                value: 0, child: Text('Sem grupo')),
                            for (final g in widget.groups!)
                              DropdownMenuItem(
                                  value: g.id,
                                  child: Text(g.name,
                                      overflow: TextOverflow.ellipsis))
                          ],
                          onChanged: _saving
                              ? null
                              : (v) =>
                                  setState(() => _groupId = v == 0 ? null : v))
                    ],
                    if (_error != null)
                      Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(_error!,
                              style: const TextStyle(
                                  color: AppColors.accentActive))),
                  ]))),
          actions: [
            TextButton(
                onPressed: _saving ? null : () => Navigator.pop(context, false),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Salvando…' : 'Salvar'))
          ]));
}

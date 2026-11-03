import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../application/library_controller.dart';
import '../domain/models.dart';

Future<void> showAddMusicLinks(
        BuildContext context, LibraryController controller) =>
    showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AddMusicLinksDialog(controller: controller));

class AddMusicLinksDialog extends StatefulWidget {
  const AddMusicLinksDialog({super.key, required this.controller});
  final LibraryController controller;
  @override
  State<AddMusicLinksDialog> createState() => _AddMusicLinksDialogState();
}

class _AddMusicLinksDialogState extends State<AddMusicLinksDialog> {
  final _links = TextEditingController();
  late List<Collection> _collections;
  int? _collectionId;
  int _offset = 0;
  bool _saving = false, _loading = false;
  String _error = '';
  @override
  void initState() {
    super.initState();
    final c = widget.controller;
    _offset = c.collectionOffset;
    _collections = [...c.collections];
    if (c.current != null && !_collections.any((e) => e.id == c.current!.id)) {
      _collections.insert(0, c.current!);
    }
    _collectionId = c.current?.id ?? _collections.firstOrNull?.id;
  }

  @override
  void dispose() {
    _links.dispose();
    super.dispose();
  }

  Future<void> _page(int direction) async {
    setState(() => _loading = true);
    try {
      final next = (_offset + direction * 30).clamp(0, 1 << 30);
      final choices = await widget.controller.collectionChoices(next);
      if (!mounted) return;
      setState(() {
        if (choices.isNotEmpty) {
          _offset = next;
          _collections = choices;
          if (!choices.any((c) => c.id == _collectionId)) {
            _collectionId = choices.first.id;
          }
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Não foi possível carregar as coleções.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    if (_collectionId == null || _saving) return;
    setState(() {
      _saving = true;
      _error = '';
    });
    final saved = await widget.controller.addLinks(_collectionId!, _links.text);
    if (!mounted) return;
    if (saved) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _saving = false;
      _error = widget.controller.message;
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: const Text('Adicionar links'),
        content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  if (_collections.isEmpty)
                    const Text('Importe uma coleção primeiro.')
                  else
                    DropdownButtonFormField<int>(
                        key: ValueKey('links-collection-$_collectionId'),
                        initialValue: _collectionId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Coleção'),
                        items: [
                          for (final c in _collections)
                            DropdownMenuItem(
                                value: c.id,
                                child: Text(c.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis))
                        ],
                        onChanged: _saving || _loading
                            ? null
                            : (id) => setState(() => _collectionId = id)),
                  if (_offset > 0 || _collections.length >= 30)
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      IconButton(
                          tooltip: 'Coleções anteriores',
                          onPressed: !_saving && !_loading && _offset > 0
                              ? () => _page(-1)
                              : null,
                          icon: const Icon(Icons.chevron_left)),
                      IconButton(
                          tooltip: 'Mais coleções',
                          onPressed:
                              !_saving && !_loading && _collections.length >= 30
                                  ? () => _page(1)
                                  : null,
                          icon: const Icon(Icons.chevron_right)),
                    ]),
                  const SizedBox(height: 16),
                  TextField(
                      key: const ValueKey('extra-music-links'),
                      controller: _links,
                      enabled: !_saving,
                      minLines: 4,
                      maxLines: 8,
                      maxLength: 32768,
                      keyboardType: TextInputType.multiline,
                      decoration: const InputDecoration(
                          labelText: 'Links das faixas',
                          alignLabelWithHint: true,
                          hintText:
                              'Spotify, Deezer, YouTube ou MP3 direto\nUm link por linha · até 20',
                          counterText: '')),
                  if (_saving)
                    Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: ListenableBuilder(
                            listenable: widget.controller,
                            builder: (context, child) => Column(children: [
                                  const LinearProgressIndicator(minHeight: 2),
                                  const SizedBox(height: 8),
                                  Text(widget.controller.linkProgress,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.muted)),
                                ]))),
                  if (_error.isNotEmpty)
                    Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(_error,
                            style: const TextStyle(
                                color: AppColors.accentActive))),
                ]))),
        actions: [
          TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton.icon(
              onPressed:
                  _saving || _loading || _collectionId == null ? null : _add,
              icon: const Icon(Icons.add_link_rounded, size: 18),
              label: const Text('Adicionar')),
        ],
      ));
}

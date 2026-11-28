import 'dart:async';
import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../organization/domain/collection_organization.dart';
import '../domain/models.dart';

/// Picks an existing playlist by name.
Future<Collection?> pickPlaylist(BuildContext context,
        {required String title,
        required Future<CollectionListing> Function(String query) search}) =>
    showDialog<Collection>(
        context: context,
        builder: (_) => _PlaylistPickerDialog(title: title, search: search));

class _PlaylistPickerDialog extends StatefulWidget {
  const _PlaylistPickerDialog({required this.title, required this.search});
  final String title;
  final Future<CollectionListing> Function(String query) search;
  @override
  State<_PlaylistPickerDialog> createState() => _PlaylistPickerDialogState();
}

class _PlaylistPickerDialogState extends State<_PlaylistPickerDialog> {
  final _query = TextEditingController();
  Timer? _timer;
  CollectionListing? _listing;
  String? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load(''));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _query.dispose();
    super.dispose();
  }

  Future<void> _load(String query) async {
    final generation = ++_generation;
    try {
      final listing = await widget.search(query.trim());
      // An older search must not replace the result of a newer one.
      if (mounted && generation == _generation) {
        setState(() {
          _listing = listing;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _error = 'Não foi possível listar as playlists.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final listing = _listing;
    return AlertDialog(
        title: Text(widget.title),
        content: SizedBox(
            width: 420,
            height: MediaQuery.sizeOf(context).height * .5,
            child: Column(children: [
              TextField(
                  key: const ValueKey('playlist-picker-search'),
                  controller: _query,
                  autofocus: true,
                  decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search, size: 18),
                      hintText: 'Buscar playlist'),
                  onChanged: (value) {
                    _timer?.cancel();
                    _timer = Timer(const Duration(milliseconds: 250),
                        () => unawaited(_load(value)));
                  }),
              const SizedBox(height: 8),
              Expanded(
                  child: _error != null
                      ? Center(child: Text(_error!))
                      : listing == null
                          ? const Center(child: CircularProgressIndicator())
                          : listing.items.isEmpty
                              ? const Center(
                                  child: Text('Nenhuma playlist encontrada.',
                                      style: TextStyle(color: AppColors.muted)))
                              : ListView.builder(
                                  itemCount: listing.items.length,
                                  itemBuilder: (context, index) {
                                    final item = listing.items[index];
                                    return ListTile(
                                        key: ValueKey(
                                            'playlist-picker-${item.id}'),
                                        leading: const Icon(
                                            Icons.queue_music_rounded,
                                            color: AppColors.secondary),
                                        title: Text(item.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis),
                                        subtitle: Text(item.trackCount == 1
                                            ? '1 faixa'
                                            : '${item.trackCount} faixas'),
                                        onTap: () =>
                                            Navigator.pop(context, item));
                                  })),
              if (listing != null && listing.total > listing.items.length)
                Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                        'Mostrando ${listing.items.length} de ${listing.total}. Busque pelo nome para encontrar as demais.',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.muted))),
            ])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
        ]);
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import '../../../app/app_notice.dart';
import '../../../app/theme.dart';
import '../../organization/data/collection_organization_repository.dart';
import '../application/library_controller.dart';
import '../data/artwork_store.dart';
import '../domain/models.dart';
import 'artwork_thumbnail.dart';

class PlaylistCoverButton extends StatelessWidget {
  const PlaylistCoverButton(
      {super.key,
      required this.library,
      required this.playlist,
      this.size = 44});

  final LibraryController library;
  final Collection playlist;
  final double size;

  @override
  Widget build(BuildContext context) {
    final rgb = playlist.themeColor;
    return IconButton(
        key: ValueKey('collection-cover-${playlist.id}'),
        tooltip: 'Alterar capa da playlist',
        padding: EdgeInsets.zero,
        onPressed: library.busy ? null : () => unawaited(_change(context)),
        icon: ArtworkThumbnail(
            reference: playlist.coverPath,
            size: size,
            placeholderColor: rgb == null
                ? AppColors.surface
                : Color.alphaBlend(
                    Color(0xFF000000 | rgb).withAlpha(42), Colors.white),
            icon: Icons.library_music_outlined));
  }

  Future<void> _change(BuildContext context) async {
    final choice = await showDialog<({Track? track, bool file})>(
        context: context,
        builder: (_) =>
            _PlaylistCoverPicker(library: library, playlist: playlist));
    if (choice == null || !context.mounted) return;
    final store = ArtworkStore.shared;
    try {
      final directory = await library.files.dataDirectory();
      final String cover;
      if (choice.file) {
        final path = await library.files.chooseCover();
        if (path == null || !context.mounted) return;
        cover = await store.importCover(path, directory);
      } else {
        final track = choice.track!;
        final bytes =
            await store.load(_reference(track), audioPath: track.localPath);
        if (bytes == null) throw const FormatException('Capa indisponível.');
        cover = await store.saveCover(bytes, directory);
      }
      await CollectionOrganizationRepository(library.repository.database)
          .setCover(playlist.id, cover);
      await library.refresh();
    } catch (_) {
      if (context.mounted) {
        await showAppNotice(context,
            message: 'Não foi possível salvar a capa. Escolha outra imagem.');
      }
    }
  }
}

String _reference(Track track) =>
    track.resolvedCoverUrl.isEmpty ? track.coverUrl : track.resolvedCoverUrl;

class _PlaylistCoverPicker extends StatefulWidget {
  const _PlaylistCoverPicker({required this.library, required this.playlist});
  final LibraryController library;
  final Collection playlist;

  @override
  State<_PlaylistCoverPicker> createState() => _PlaylistCoverPickerState();
}

class _PlaylistCoverPickerState extends State<_PlaylistCoverPicker> {
  final _covers = <Track>[];
  int _offset = 0;
  bool _loading = false, _more = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final library = widget.library;
      final tracks =
          await library.repository.coverCandidates(widget.playlist.id, _offset);
      if (!mounted) return;
      final available = await Future.wait(tracks.map((track) async {
        try {
          if (!await library.files.fileExists(track.localPath)) return null;
          final bytes = await ArtworkStore.shared
              .load(_reference(track), audioPath: track.localPath);
          return bytes == null ? null : track;
        } catch (_) {
          return null;
        }
      }));
      if (!mounted) return;
      _covers.addAll(available.whereType<Track>());
      _offset += tracks.length;
      _more = tracks.length == 24;
    } catch (_) {
      _error = 'Não foi possível carregar as capas.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: const Text('Capa da playlist'),
          content: SizedBox(
              width: 440,
              height: (MediaQuery.sizeOf(context).height * .42)
                  .clamp(90, 370)
                  .toDouble(),
              child: ListView.builder(
                  itemCount: _covers.length + 1,
                  itemBuilder: (context, index) {
                    if (index < _covers.length) {
                      final track = _covers[index];
                      return ListTile(
                          key: ValueKey('playlist-cover-track-${track.id}'),
                          contentPadding: EdgeInsets.zero,
                          leading: ArtworkThumbnail(
                              reference: _reference(track),
                              audioPath: track.localPath),
                          title: Text(track.displayTitle,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(track.artist,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          onTap: () => Navigator.pop(
                              context, (track: track, file: false)));
                    }
                    if (_loading) return const LinearProgressIndicator();
                    if (_more) {
                      return Column(children: [
                        if (_error.isNotEmpty) Text(_error),
                        TextButton(
                            onPressed: _load,
                            child: Text(_error.isEmpty
                                ? 'Ver mais faixas'
                                : 'Tentar novamente')),
                      ]);
                    }
                    return _covers.isEmpty
                        ? const Text(
                            'Nenhuma capa de música baixada disponível.')
                        : const SizedBox.shrink();
                  })),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar')),
            FilledButton.icon(
                onPressed: () =>
                    Navigator.pop(context, (track: null, file: true)),
                icon: const Icon(Icons.image_outlined),
                label: const Text('Escolher imagem')),
          ]);
}

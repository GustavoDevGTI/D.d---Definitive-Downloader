import 'dart:async';
import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../application/library_controller.dart';
import '../domain/track_listing.dart';
import '../../player/presentation/player_scope.dart';
import '../../workspace/presentation/download_action_button.dart';
import 'add_music_links_dialog.dart';
import 'playlist_palette.dart';

class CollectionTrackToolbar extends StatelessWidget {
  const CollectionTrackToolbar(
      {super.key,
      required this.controller,
      required this.query,
      required this.onQueryChanged,
      required this.onClear,
      required this.onDownload,
      this.accent});
  final LibraryController controller;
  final TextEditingController query;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClear, onDownload;
  final Color? accent;

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: LayoutBuilder(builder: (context, box) {
        final c = controller;
        final search = TextField(
            key: const ValueKey('track-search'),
            controller: query,
            maxLength: 400,
            decoration: InputDecoration(
                hintText: 'Pesquisar faixas…',
                counterText: '',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: query.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpar pesquisa de faixas',
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: onClear)),
            onChanged: onQueryChanged);
        final filter = DropdownButtonFormField<String>(
            key: ValueKey('track-filter-${c.view}'),
            initialValue: c.view,
            isExpanded: true,
            style: const TextStyle(fontSize: 12, color: AppColors.ink),
            menuMaxHeight: 280,
            decoration: const InputDecoration(
                labelText: 'Mostrar',
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
            items: const [
              DropdownMenuItem(
                  value: 'collections',
                  child: Text('Todas', overflow: TextOverflow.ellipsis)),
              DropdownMenuItem(
                  value: 'review',
                  child: Text('Conferir', overflow: TextOverflow.ellipsis)),
              DropdownMenuItem(
                  value: 'ready',
                  child: Text('Prontas', overflow: TextOverflow.ellipsis)),
              DropdownMenuItem(
                  value: 'files',
                  child: Text('Concluídas', overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) {
              if (v != null) unawaited(c.setView(v));
            });
        final sort = PopupMenuButton<TrackSort>(
            tooltip: 'Ordenar faixas',
            icon: Icon(Icons.sort, color: playlistInk(accent)),
            onSelected: (v) => unawaited(c.sortTracks(v)),
            itemBuilder: (_) => [
                  for (final item in const [
                    (TrackSort.position, 'Ordem da playlist'),
                    (TrackSort.name, 'Nome'),
                    (TrackSort.duration, 'Duração'),
                    (TrackSort.correspondence, 'Correspondência')
                  ])
                    CheckedPopupMenuItem(
                        value: item.$1,
                        checked: c.trackSort == item.$1,
                        child: Text(
                            '${item.$2}${c.trackSort == item.$1 ? c.trackDescending ? ' ↓' : ' ↑' : ''}')),
                ]);
        final conference = OutlinedButton.icon(
            key: const ValueKey('start-playlist-conference'),
            icon: const Icon(Icons.manage_search_rounded, size: 20),
            label: const Text('Iniciar conferência'),
            style: OutlinedButton.styleFrom(
                foregroundColor: playlistInk(accent),
                backgroundColor: playlistReviewSurface(accent),
                side: BorderSide(color: playlistInk(accent).withAlpha(100)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
            onPressed: c.busy || c.isExample || c.music?.available != true
                ? null
                : () => unawaited(c.prepareMusic()));
        if (box.maxWidth >= 760) {
          return Row(children: [
            _commands(context),
            const SizedBox(width: 8),
            Expanded(child: search),
            const SizedBox(width: 8),
            SizedBox(width: 104, child: filter),
            sort,
            conference,
          ]);
        }
        return Column(children: [
          Row(children: [
            Expanded(child: search),
            const SizedBox(width: 8),
            SizedBox(width: 104, child: filter),
            sort
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _commands(context)),
            const SizedBox(width: 8),
            conference,
          ]),
        ]);
      }));

  Widget _commands(BuildContext context) {
    final c = controller, player = PlayerScope.of(context);
    final actions = <Widget>[
      if (player != null && c.current!.completedCount > 0)
        DownloadActionButton(
            label: 'Ouvir playlist',
            icon: Icons.play_arrow_rounded,
            color: playlistInk(accent),
            primary: true,
            onPressed: () => unawaited(player.playCollection(c.current!.id))),
      DownloadActionButton(
          label: 'Baixar selecionadas',
          icon: Icons.download_rounded,
          color: DownloadActionColors.start,
          primary: true,
          onPressed: c.busy || c.page.selectedCount == 0 ? null : onDownload),
      DownloadActionButton(
          label: 'Adicionar links',
          icon: Icons.add_link_rounded,
          color: DownloadActionColors.add,
          onPressed: c.addingLinks || c.importing || c.preparing || c.editing
              ? null
              : () => unawaited(showAddMusicLinks(context, c))),
      DownloadActionButton(
          label: 'Adicionar MP3',
          icon: Icons.audio_file_outlined,
          color: DownloadActionColors.add,
          onPressed:
              c.reorderingBusy ? null : () => unawaited(c.chooseLocalFiles())),
      if (c.downloading)
        DownloadActionButton(
            label: 'Interromper',
            icon: Icons.stop,
            color: DownloadActionColors.stop,
            onPressed: c.cancel),
    ];
    return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            actions[i],
          ],
        ]));
  }
}

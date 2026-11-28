import 'dart:async';
import 'package:flutter/material.dart';
import '../../../app/app_notice.dart';
import '../../../app/theme.dart';
import '../../../core/application/operation_message.dart';
import '../application/library_controller.dart';
import '../data/collection_destinations.dart';
import '../domain/models.dart';

/// "Salvar em" line shared by the capture page and the playlist dialog.
class DestinationRow extends StatelessWidget {
  const DestinationRow(
      {super.key,
      required this.path,
      required this.custom,
      required this.onChange,
      required this.onReset,
      this.enabled = true});
  final String path;
  final bool custom, enabled;
  final VoidCallback onChange, onReset;

  @override
  Widget build(BuildContext context) {
    final location = Row(children: [
      const Icon(Icons.folder_outlined, size: 20, color: AppColors.secondary),
      const SizedBox(width: 10),
      Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
            Text(custom ? 'Salvar em · pasta escolhida' : 'Salvar em',
                style: const TextStyle(fontSize: 11, color: AppColors.muted)),
            const SizedBox(height: 2),
            Tooltip(
                message: path,
                child: Text(path.isEmpty ? '—' : path,
                    key: const ValueKey('destination-path'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink))),
          ])),
    ]);
    final actions = Wrap(spacing: 4, runSpacing: 4, children: [
      TextButton.icon(
          key: const ValueKey('destination-change'),
          onPressed: enabled ? onChange : null,
          icon: const Icon(Icons.drive_folder_upload_outlined, size: 18),
          label: const Text('Alterar pasta')),
      if (custom)
        TextButton(
            key: const ValueKey('destination-default'),
            onPressed: enabled ? onReset : null,
            child: const Text('Usar padrão')),
    ]);
    return DecoratedBox(
        decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(AppDensity.of(context).radius)),
        child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            child: LayoutBuilder(
                builder: (context, box) => box.maxWidth < 480
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                            location,
                            Align(
                                alignment: Alignment.centerRight,
                                child: actions)
                          ])
                    : Row(children: [
                        Expanded(child: location),
                        const SizedBox(width: 8),
                        actions
                      ]))));
  }
}

/// Folder button next to the open playlist's name.
class PlaylistDestinationButton extends StatelessWidget {
  const PlaylistDestinationButton(
      {super.key, required this.library, required this.playlist});
  final LibraryController library;
  final Collection playlist;

  @override
  Widget build(BuildContext context) => IconButton(
      key: ValueKey('playlist-destination-${playlist.id}'),
      tooltip: 'Pasta de destino',
      visualDensity: VisualDensity.compact,
      onPressed: () =>
          unawaited(showPlaylistDestination(context, library, playlist)),
      icon: const Icon(Icons.folder_outlined,
          size: 20, color: AppColors.secondary));
}

Future<void> showPlaylistDestination(
        BuildContext context, LibraryController library, Collection playlist) =>
    showDialog<void>(
        context: context,
        builder: (_) =>
            PlaylistDestinationDialog(library: library, playlist: playlist));

class PlaylistDestinationDialog extends StatefulWidget {
  const PlaylistDestinationDialog(
      {super.key, required this.library, required this.playlist});
  final LibraryController library;
  final Collection playlist;
  @override
  State<PlaylistDestinationDialog> createState() =>
      _PlaylistDestinationDialogState();
}

class _PlaylistDestinationDialogState extends State<PlaylistDestinationDialog> {
  CollectionDestination? _destination;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final destination =
          await widget.library.destinationOf(widget.playlist.id);
      if (mounted) setState(() => _destination = destination);
    } catch (error) {
      if (mounted) setState(() => _error = operationMessage(error));
    }
  }

  Future<void> _apply(Future<String?> Function() root) async {
    setState(() => _saving = true);
    try {
      final chosen = await root();
      if (chosen != null) {
        await widget.library.setCollectionRoot(widget.playlist.id, chosen);
        await _load();
      }
    } on FormatException catch (error) {
      if (mounted) await showAppNotice(context, message: error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final destination = _destination;
    final blocked = _saving || widget.library.importBlocked;
    return AlertDialog(
        title: const Text('Pasta de destino'),
        content: SizedBox(
            width: 480,
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(widget.playlist.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  if (_error != null)
                    Text(_error!,
                        style: const TextStyle(color: AppColors.accentActive))
                  else if (destination == null)
                    const LinearProgressIndicator(minHeight: 2)
                  else
                    DestinationRow(
                        path: widget.library.displayPath(destination.directory),
                        custom: destination.customRoot,
                        enabled: !blocked,
                        onChange: () => unawaited(
                            _apply(widget.library.pickDestinationRoot)),
                        onReset: () => unawaited(_apply(() async => ''))),
                  if (widget.playlist.completedCount > 0) ...[
                    const SizedBox(height: 10),
                    const Text(
                        'Ao mudar a pasta, os arquivos já baixados continuam onde estão.',
                        style: TextStyle(fontSize: 11, color: AppColors.muted)),
                  ],
                  if (widget.library.importBlocked) ...[
                    const SizedBox(height: 10),
                    const Text(
                        'Aguarde os downloads e importações em andamento para mudar a pasta.',
                        style: TextStyle(fontSize: 11, color: AppColors.muted)),
                  ],
                ])),
        actions: [
          TextButton.icon(
              key: const ValueKey('destination-open'),
              onPressed: destination == null || _saving
                  ? null
                  : () => unawaited(
                      widget.library.openCollectionFolder(widget.playlist.id)),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Abrir pasta')),
          FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar')),
        ]);
  }
}

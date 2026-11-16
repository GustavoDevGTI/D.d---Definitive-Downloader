import 'package:flutter/material.dart';

import '../../importing/spotify_playlist_export.dart';
import '../application/library_controller.dart';

Future<void> importPlaylistFile(
        BuildContext context, LibraryController controller) =>
    controller.importPlaylistFile((playlists) async {
      if (!context.mounted) return null;
      return showDialog<SpotifyPlaylistExport>(
          context: context,
          builder: (dialogContext) => AlertDialog(
                title: const Text('Escolher playlist'),
                content: SizedBox(
                  width: 360,
                  height: MediaQuery.sizeOf(dialogContext).height * .42,
                  child: ListView.builder(
                    itemCount: playlists.length,
                    itemBuilder: (_, index) {
                      final playlist = playlists[index];
                      return ListTile(
                        title: Text(playlist.name),
                        subtitle: Text(playlist.skipped == 0
                            ? '${playlist.tracks.length} músicas'
                            : '${playlist.tracks.length} músicas · ${playlist.skipped} itens fora da importação'),
                        onTap: () => Navigator.pop(dialogContext, playlist),
                      );
                    },
                  ),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Cancelar')),
                ],
              ));
    });

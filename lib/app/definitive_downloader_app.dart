import 'package:flutter/material.dart';
import '../core/app_identity.dart';
import '../features/connections/application/spotify_connection_controller.dart';
import '../features/library/application/library_controller.dart';
import '../features/library/presentation/library_screen.dart';
import 'theme.dart';
import '../features/player/application/music_player_controller.dart';
import '../features/player/presentation/player_scope.dart';

class DefinitiveDownloaderApp extends StatelessWidget {
  const DefinitiveDownloaderApp(
      {super.key,
      required this.controller,
      this.player,
      this.connections,
      this.initialPlaylist = '',
      this.showConnectionsOnStart = false});
  final LibraryController controller;
  final MusicPlayerController? player;
  final SpotifyConnectionController? connections;
  final String initialPlaylist;
  final bool showConnectionsOnStart;
  @override
  Widget build(BuildContext context) => MaterialApp(
      title: AppIdentity.name,
      debugShowCheckedModeBanner: false,
      theme: appTheme(),
      builder: (context, child) =>
          PlayerScope(player: player, child: child ?? const SizedBox.shrink()),
      home: LibraryScreen(
          controller: controller,
          player: player,
          connections: connections,
          initialPlaylist: initialPlaylist,
          showConnectionsOnStart: showConnectionsOnStart));
}

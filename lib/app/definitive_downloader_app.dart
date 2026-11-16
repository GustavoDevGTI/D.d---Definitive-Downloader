import 'package:flutter/material.dart';
import '../core/app_identity.dart';
import '../features/connections/application/trackhop_connection.dart';
import '../features/connections/presentation/music_connection_actions.dart';
import '../features/library/application/library_controller.dart';
import '../features/library/presentation/library_screen.dart';
import 'theme.dart';
import '../features/player/application/music_player_controller.dart';
import '../features/player/presentation/player_scope.dart';
import '../core/platform/android_incoming.dart';
import '../features/library/presentation/incoming_music_host.dart';

class DefinitiveDownloaderApp extends StatelessWidget {
  const DefinitiveDownloaderApp(
      {super.key,
      required this.controller,
      this.navigatorKey,
      this.player,
      this.connections,
      this.incoming,
      this.initialPlaylist = '',
      this.showConnectionsOnStart = false});
  final LibraryController controller;
  final GlobalKey<NavigatorState>? navigatorKey;
  final MusicPlayerController? player;
  final TrackhopConnection? connections;
  final AndroidIncoming? incoming;
  final String initialPlaylist;
  final bool showConnectionsOnStart;
  @override
  Widget build(BuildContext context) => MaterialApp(
      navigatorKey: navigatorKey,
      title: AppIdentity.name,
      debugShowCheckedModeBanner: false,
      theme: appTheme(),
      builder: (context, child) => ListenableBuilder(
          listenable:
              Listenable.merge([connections, controller.music?.connection]),
          builder: (context, _) => MusicConnectionsScope(
              access: controller.accounts,
              child: PlayerScope(
                  player: player, child: child ?? const SizedBox.shrink()))),
      home: incoming == null
          ? _screen()
          : IncomingMusicHost(
              incoming: incoming!, library: controller, child: _screen()));
  Widget _screen() => LibraryScreen(
      controller: controller,
      player: player,
      connections: connections,
      initialPlaylist: initialPlaylist,
      showConnectionsOnStart: showConnectionsOnStart);
}

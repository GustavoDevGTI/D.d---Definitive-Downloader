import 'package:flutter/material.dart';
import '../core/app_identity.dart';
import '../features/connections/application/spotify_connection_controller.dart';
import '../features/library/application/library_controller.dart';
import '../features/library/presentation/library_screen.dart';
import 'theme.dart';

class DefinitiveDownloaderApp extends StatelessWidget {
  const DefinitiveDownloaderApp(
      {super.key,
      required this.controller,
      this.connections,
      this.initialPlaylist = '',
      this.showConnectionsOnStart = false});
  final LibraryController controller;
  final SpotifyConnectionController? connections;
  final String initialPlaylist;
  final bool showConnectionsOnStart;
  @override
  Widget build(BuildContext context) => MaterialApp(
      title: AppIdentity.name,
      debugShowCheckedModeBanner: false,
      theme: appTheme(),
      home: LibraryScreen(
          controller: controller,
          connections: connections,
          initialPlaylist: initialPlaylist,
          showConnectionsOnStart: showConnectionsOnStart));
}

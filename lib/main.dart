import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'app/definitive_downloader_app.dart';
import 'core/network/bounded_http.dart';
import 'core/platform/desktop_files.dart';
import 'core/platform/music_engine_diagnostic.dart';
import 'core/storage/database.dart';
import 'features/downloads/download_service.dart';
import 'features/importing/csv_importer.dart';
import 'features/importing/spotify_importer.dart';
import 'features/library/application/library_controller.dart';
import 'features/library/data/library_repository.dart';
import 'features/matching/deezer_catalog.dart';
import 'features/importing/spotify_account_importer.dart';
import 'features/connections/application/spotify_connection_controller.dart';
import 'features/connections/data/spotify_token_store.dart';
import 'features/connections/data/spotify_transport.dart';
import 'features/connections/data/windows_spotify_authorization.dart';
import 'features/connections/application/deezer_connection_controller.dart';
import 'features/downloads/music_download_service.dart';
import 'features/matching/music_engine.dart';
import 'features/matching/music_resolver.dart';

Future<void> main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (arguments.contains('--check-music-engine')) {
    exit(await diagnoseMusicEngine(WindowsMusicEngine.installed()));
  }
  final files = DesktopFiles();
  final database = AppDatabase(await files.databasePath());
  const http = BoundedHttp();
  final engine = WindowsMusicEngine.installed();
  final deezer = DeezerConnectionController(
      const SecureDeezerSessionStore(FlutterSecureStorage()), engine);
  final connections = SpotifyConnectionController(
      store: const SecureSpotifyTokenStore(FlutterSecureStorage()),
      transport: const SpotifyHttpTransport(),
      authorization: Platform.isWindows
          ? WindowsSpotifyAuthorization(openBrowser: files.openUrl)
          : UnavailableSpotifyAuthorization());
  final controller = LibraryController(
      repository: LibraryRepository(database),
      files: files,
      spotify: const SpotifyImporter(http),
      accountSpotify: SpotifyAccountImporter(
          connections.getJson, () => connections.isConnected),
      csv: const CsvImporter(),
      catalog: const DeezerCatalog(http),
      music: MusicResolver(engine, deezer),
      downloader: DownloadService(http, rootBundle,
          music: MusicDownloadService(engine, deezer)));
  await controller.initialize(example: arguments.contains('--example'));
  final playlistArgument =
      arguments.where((value) => value.startsWith('--playlist=')).firstOrNull;
  var initialPlaylist = '';
  if (playlistArgument != null) {
    final id = const SpotifyImporter(http)
        .playlistId(playlistArgument.substring('--playlist='.length));
    initialPlaylist = 'https://open.spotify.com/playlist/$id';
  }
  runApp(DefinitiveDownloaderApp(
      controller: controller,
      connections: connections,
      initialPlaylist: initialPlaylist,
      showConnectionsOnStart: arguments.contains('--connections')));
  unawaited(connections.restore());
  unawaited(deezer.restore());
}

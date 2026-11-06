import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'app/definitive_downloader_app.dart';
import 'core/network/bounded_http.dart';
import 'core/platform/platform_services.dart';
import 'core/platform/android_background.dart';
import 'core/platform/music_engine_diagnostic.dart';
import 'core/platform/player_diagnostic.dart';
import 'features/player/application/music_player_controller.dart';
import 'features/player/data/media_kit_engine.dart';
import 'features/player/data/player_library.dart';
import 'core/storage/database.dart';
import 'features/downloads/download_service.dart';
import 'features/importing/csv_importer.dart';
import 'features/importing/spotify_importer.dart';
import 'features/importing/soundcloud_link.dart';
import 'features/library/application/library_controller.dart';
import 'features/library/data/library_repository.dart';
import 'features/matching/deezer_catalog.dart';
import 'features/importing/spotify_account_importer.dart';
import 'features/connections/application/spotify_connection_controller.dart';
import 'features/connections/data/spotify_token_store.dart';
import 'features/connections/data/spotify_transport.dart';
import 'features/connections/data/windows_spotify_authorization.dart';
import 'features/connections/data/android_spotify_authorization.dart';
import 'features/connections/application/deezer_connection_controller.dart';
import 'features/downloads/music_download_service.dart';
import 'features/matching/music_engine.dart';
import 'features/matching/music_resolver.dart';

Future<void> main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isAndroid) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark));
  }
  if (arguments.contains('--check-player')) {
    exit(await diagnosePlayer(arguments));
  }
  if (arguments.contains('--check-music-engine')) {
    exit(await diagnoseMusicEngine(await WindowsMusicEngine.installed()));
  }
  final files = createPlatformFiles();
  final database = AppDatabase(await files.databasePath());
  const http = BoundedHttp();
  final engine = await createMusicEngine();
  final deezer = DeezerConnectionController(
      const SecureDeezerSessionStore(FlutterSecureStorage()), engine);
  final connections = SpotifyConnectionController(
      store: const SecureSpotifyTokenStore(FlutterSecureStorage()),
      transport: const SpotifyHttpTransport(),
      authorization: Platform.isWindows
          ? WindowsSpotifyAuthorization(openBrowser: files.openUrl)
          : Platform.isAndroid
              ? AndroidSpotifyAuthorization(openBrowser: files.openUrl)
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
  final player = MusicPlayerController(
      PlayerLibrary(database), createAudioEngine(), files);
  await player.initialize();
  if (Platform.isAndroid) AndroidBackground(controller, player);
  final playlistArgument =
      arguments.where((value) => value.startsWith('--playlist=')).firstOrNull;
  var initialPlaylist = '';
  if (playlistArgument != null) {
    final input = playlistArgument.substring('--playlist='.length);
    initialPlaylist = SoundCloudLink.recognizes(input)
        ? SoundCloudLink.parse(input).url
        : 'https://open.spotify.com/playlist/${const SpotifyImporter(http).playlistId(input)}';
  }
  runApp(DefinitiveDownloaderApp(
      controller: controller,
      player: player,
      connections: connections,
      initialPlaylist: initialPlaylist,
      showConnectionsOnStart: arguments.contains('--connections')));
  unawaited(connections.restore());
  unawaited(deezer.restore());
}

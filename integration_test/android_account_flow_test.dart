import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:definitive_downloader/app/definitive_downloader_app.dart';
import 'package:definitive_downloader/core/network/bounded_http.dart';
import 'package:definitive_downloader/core/platform/android_files.dart';
import 'package:definitive_downloader/core/storage/database.dart';
import 'package:definitive_downloader/features/connections/application/deezer_connection_controller.dart';
import 'package:definitive_downloader/features/connections/application/music_account_access.dart';
import 'package:definitive_downloader/features/connections/application/spotify_connection_controller.dart';
import 'package:definitive_downloader/features/connections/data/android_spotify_authorization.dart';
import 'package:definitive_downloader/features/connections/data/spotify_token_store.dart';
import 'package:definitive_downloader/features/downloads/download_service.dart';
import 'package:definitive_downloader/features/downloads/music_download_service.dart';
import 'package:definitive_downloader/features/importing/csv_importer.dart';
import 'package:definitive_downloader/features/importing/spotify_account_importer.dart';
import 'package:definitive_downloader/features/importing/spotify_importer.dart';
import 'package:definitive_downloader/features/library/application/library_controller.dart';
import 'package:definitive_downloader/features/library/data/library_repository.dart';
import 'package:definitive_downloader/features/library/domain/models.dart';
import 'package:definitive_downloader/features/matching/deezer_catalog.dart';
import 'package:definitive_downloader/features/matching/music_engine.dart';
import 'package:definitive_downloader/features/matching/music_resolver.dart';
import 'package:definitive_downloader/features/player/data/android_audio_engine.dart';
import 'package:definitive_downloader/features/player/data/player_library.dart';

import '../test/spotify_fixtures.dart';

const _playlistId = '1234567890123456789012';
const _artist = 'Artista de teste';
const _titles = ['Faixa rosa', 'Faixa azul'];
final _deezerSession = 'ddTestSession' * 12;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android: importar, adiar Deezer, conferir, baixar e tocar',
      (tester) async {
    expect(Platform.isAndroid, isTrue);
    final temp = await (await getTemporaryDirectory()).createTemp('dd-flow-');
    const storage = FlutterSecureStorage();
    const spotifyStore = SecureSpotifyTokenStore(storage);
    const deezerStore = SecureDeezerSessionStore(storage);
    final worker = _FixtureWorker();
    final deezer = DeezerConnectionController(deezerStore, worker);
    var playlistReads = 0;
    final spotify = SpotifyConnectionController(
        store: spotifyStore,
        authorization: AndroidSpotifyAuthorization(openBrowser: (uri) async {
          expect(uri.host, 'accounts.spotify.com');
          expect(uri.queryParameters['code_challenge_method'], 'S256');
          final callback = Uri.parse(uri.queryParameters['redirect_uri']!);
          expect(callback.port, 43822);
          final client = HttpClient();
          try {
            final response =
                await (await client.getUrl(callback.replace(queryParameters: {
              'code': 'fixture-code',
              'state': uri.queryParameters['state']!,
            })))
                    .close();
            expect(response.statusCode, 200);
            await response.drain<void>();
          } finally {
            client.close(force: true);
          }
        }),
        transport: FixtureSpotifyTransport((uri, method, headers, form) async {
          if (uri.path == '/api/token') {
            expect(form?['code'], 'fixture-code');
            return fixtureToken();
          }
          expect(headers['Authorization'], 'Bearer fixture-access');
          if (uri.path == '/v1/me') return {'display_name': 'Fixture Android'};
          playlistReads++;
          if (uri.path == '/v1/playlists/$_playlistId') {
            return {
              'name': 'Coleção de teste Android',
              'items': {'total': 2}
            };
          }
          expect(uri.path, '/v1/playlists/$_playlistId/items');
          return {
            'total': 2,
            'offset': 0,
            'items': [
              for (final title in _titles)
                {
                  'item': {
                    'name': title,
                    'duration_ms': 4000,
                    'artists': [
                      {'name': _artist}
                    ]
                  }
                }
            ],
          };
        }));
    final repository = LibraryRepository(AppDatabase('${temp.path}/flow.db'));
    final files = AndroidFiles();
    const http = BoundedHttp();
    final controller = LibraryController(
        repository: repository,
        files: files,
        spotify: const SpotifyImporter(http),
        accountSpotify:
            SpotifyAccountImporter(spotify.getJson, () => spotify.isConnected),
        accounts: MusicAccountAccess(
            spotifyConnected: () => spotify.isConnected,
            deezerConnected: () => deezer.connected),
        csv: const CsvImporter(),
        catalog: const DeezerCatalog(http),
        music: MusicResolver(worker, deezer),
        downloader: DownloadService(http, rootBundle,
            music: MusicDownloadService(worker, deezer)));

    Future<void> tap(Finder target) async {
      await _until(tester, () => target.evaluate().isNotEmpty, '$target');
      await tester.ensureVisible(target);
      await tester.tap(target);
      await tester.pump();
    }

    Future<void> acknowledgeNotice() async {
      await tester.pumpAndSettle();
      final notice = find.byKey(const ValueKey('app-notice'));
      if (notice.evaluate().isNotEmpty) {
        await tap(find.descendant(of: notice, matching: find.text('OK')));
        await tester.pumpAndSettle();
      }
    }

    final audio = AndroidAudioEngine();
    try {
      await controller.initialize();
      controller.outputDirectory = '${temp.path}/media';
      await tester.pumpWidget(DefinitiveDownloaderApp(
          controller: controller,
          connections: spotify,
          initialPlaylist: 'https://open.spotify.com/playlist/$_playlistId'));
      await tap(find.text('Importar por link'));
      await tap(find.text('Entrar no Spotify'));
      await tap(find.text('Fazer login depois'));
      await _until(tester, () => controller.current != null && !controller.busy,
          'importação com Deezer adiado');
      await controller.preparationDone;
      final owner = controller.current!.id;
      final imported = (await repository.page(owner)).items;
      expect(imported.map((t) => t.title), _titles);
      expect(imported.map((t) => t.position), [1, 2]);
      expect(imported.every((t) => t.status == TrackStatus.pending), isTrue);
      expect(playlistReads, 2);
      expect((await spotifyStore.read())?.accessToken, 'fixture-access');
      expect(await deezerStore.read(), isNull);
      expect(find.text('Conectar Deezer'), findsNothing);
      expect(worker.searches, 0);
      expect(worker.downloaded, isEmpty);
      debugPrint('DD_FLOW: Spotify fixture importado com Deezer adiado');

      await acknowledgeNotice();
      await tap(find.byTooltip('Rever correspondências'));
      await _until(
          tester,
          () => find.text('Conectar Deezer').evaluate().isNotEmpty,
          'pedido de conexão na conferência');
      expect(find.text('Fazer login depois'), findsNothing);
      await deezer.login(() async => _deezerSession);
      await _until(
          tester,
          () =>
              controller.page.items.length == 2 &&
              controller.page.items
                  .every((t) => t.status == TrackStatus.ready) &&
              !controller.busy,
          'correspondências prontas');
      expect(await deezerStore.read() != null, isTrue);
      expect(controller.page.items.map((t) => t.sourceKind),
          [SourceKind.deezerFull, SourceKind.youtubeMusic]);
      expect(worker.downloaded, isEmpty);
      debugPrint('DD_FLOW: conferência após conexão e seleção da fonte');

      await acknowledgeNotice();
      await tap(find.byKey(const ValueKey('select-all-collection')));
      await _until(tester, () => controller.page.selectedCount == 2,
          'seleção das duas faixas');
      await tap(find.byTooltip('Baixar selecionadas'));
      await _until(
          tester,
          () => controller.current?.completedCount == 2 && !controller.busy,
          'publicação das duas faixas');
      final downloaded = (await repository.page(owner)).items;
      expect(worker.downloaded, ['deezerFull', 'youtubeMusic']);
      expect(
          downloaded.every((t) => t.status == TrackStatus.completed), isTrue);
      for (final track in downloaded) {
        expect(await files.fileSize(track.localPath), greaterThan(1024));
        final metadata = await AndroidAudioEngine.channel
            .invokeMapMethod<String, dynamic>(
                'inspect', {'path': track.localPath});
        expect(metadata?['durationMs'], greaterThan(3500));
      }
      final m3u = await temp
          .list(recursive: true)
          .where((entry) => entry.path.endsWith('.m3u8'))
          .single;
      final playlist = await File(m3u.path).readAsString();
      expect(playlist.indexOf('001 - Faixa rosa'), greaterThanOrEqualTo(0));
      expect(playlist.indexOf('002 - Faixa azul'),
          greaterThan(playlist.indexOf('001 - Faixa rosa')));
      final playerLibrary = PlayerLibrary(repository.database, files: files);
      final item = await playerLibrary.localFor(downloaded.first);
      expect(item, isNotNull);
      await audio.open(item!.uri);
      await _until(tester, () => audio.measurements['playing'] == true,
          'reprodução nativa do MP3');
      expect(tester.takeException(), isNull);
      debugPrint('DD_FLOW: 2 MP3 sintéticos, M3U8 ordenada e MediaPlayer');
    } finally {
      await audio.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      await spotify.disconnect();
      await deezer.disconnect();
      spotify.dispose();
      deezer.dispose();
      await temp.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}

Future<void> _until(
    WidgetTester tester, bool Function() predicate, String description) async {
  final timer = Stopwatch()..start();
  while (!predicate()) {
    if (timer.elapsed > const Duration(seconds: 25)) {
      fail('Tempo limite: $description');
    }
    await tester.pump(const Duration(milliseconds: 60));
  }
}

/// Only provider responses and audio payloads are synthetic. The app still
/// runs its normal controller, download publication, SQLite and native player.
class _FixtureWorker implements MusicEngine {
  @override
  bool get available => true;
  var searches = 0;
  final downloaded = <String>[];

  @override
  Future<Map<String, dynamic>> call(Map<String, dynamic> request,
      {DownloadCancellation? cancellation,
      void Function(String)? onStage,
      void Function(TransferProgress)? onProgress}) async {
    cancellation?.check();
    switch (request['operation']) {
      case 'deezerConnect':
        return {'connected': request['arl'] == _deezerSession};
      case 'search':
        searches++;
        final provider = request['provider'];
        final query = request['query'] as String;
        if (provider == 'deezerFull' && query.contains(_titles.first)) {
          return {
            'candidates': [
              {
                'kind': 'deezerFull',
                'recordingType': 'DEEZER_TRACK',
                'sourceId': '1001',
                'title': _titles.first,
                'artist': _artist,
                'durationMs': 4000,
                'pageUrl': 'https://www.deezer.com/track/1001',
              },
            ]
          };
        }
        if (provider == 'youtubeMusic' && query.contains(_titles.last)) {
          return {
            'candidates': [
              {
                'kind': 'youtubeMusic',
                'recordingType': 'MUSIC_VIDEO_TYPE_ATV',
                'sourceId': 'fixture0001',
                'title': _titles.last,
                'artist': _artist,
                'durationMs': 4000,
                'pageUrl': 'https://music.youtube.com/watch?v=fixture0001',
              },
            ]
          };
        }
        return {'candidates': []};
      case 'download':
        final candidate = request['candidate'] as Map;
        final kind = candidate['kind'] as String;
        expect(request['arl'] == _deezerSession, kind == 'deezerFull');
        downloaded.add(kind);
        final data = await rootBundle.load('assets/demo/tone.mp3');
        final output = File('${request['directory']}/verified.mp3');
        await output.writeAsBytes(
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
        return {
          'path': output.path,
          'actual': candidate,
          'decoded': true,
          'coverEmbedded': true,
          'durationMs': 4000,
        };
      default:
        throw StateError('Operação inesperada na fixture.');
    }
  }
}

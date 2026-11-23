import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:definitive_downloader/core/network/bounded_http.dart';
import 'package:definitive_downloader/core/platform/android_files.dart';
import 'package:definitive_downloader/core/storage/database.dart';
import 'package:definitive_downloader/features/audio_capture/application/audio_capture_controller.dart';
import 'package:definitive_downloader/features/connections/application/deezer_connection_controller.dart';
import 'package:definitive_downloader/features/downloads/download_service.dart';
import 'package:definitive_downloader/features/downloads/music_download_service.dart';
import 'package:definitive_downloader/features/importing/csv_importer.dart';
import 'package:definitive_downloader/features/importing/spotify_importer.dart';
import 'package:definitive_downloader/features/library/application/library_controller.dart';
import 'package:definitive_downloader/features/library/data/library_repository.dart';
import 'package:definitive_downloader/features/library/domain/models.dart';
import 'package:definitive_downloader/features/matching/android_music_engine.dart';
import 'package:definitive_downloader/features/matching/deezer_catalog.dart';
import 'package:definitive_downloader/features/matching/music_resolver.dart';
import 'package:definitive_downloader/features/player/data/android_audio_engine.dart';

class _Files extends AndroidFiles {
  _Files(this.output);
  final String output;
  @override
  Future<String> defaultOutputDirectory() async => output;
}

class _Sessions implements DeezerSessionStore {
  @override
  Future<String?> read() async => throw StateError('Conta não faz parte deste ensaio.');
  @override
  Future<void> write(String value) async => throw StateError('Conta não faz parte deste ensaio.');
  @override
  Future<void> clear() async {}
}

Uint8List _wav() {
  const dataSize = 16000 * 2 * 2;
  final bytes = Uint8List(44 + dataSize);
  final data = ByteData.sublistView(bytes);
  void text(int offset, String value) => bytes.setRange(
      offset, offset + value.length, value.codeUnits);
  text(0, 'RIFF');
  data.setUint32(4, bytes.length - 8, Endian.little);
  text(8, 'WAVEfmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, 16000, Endian.little);
  data.setUint32(28, 32000, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  text(36, 'data');
  data.setUint32(40, dataSize, Endian.little);
  return bytes;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android captura página, baixa seleção e valida MP3 nativo',
      (tester) async {
    final temp = await (await getTemporaryDirectory())
        .createTemp('dd-native-capture-');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final audio = _wav();
    server.listen((request) async {
      if (request.uri.path == '/page') {
        request.response.headers.contentType = ContentType.html;
        request.response.write('<html><head><title>Captura nativa</title></head>'
            '<body><audio controls src="/one.wav"></audio>'
            '<audio controls src="/two.wav"></audio></body></html>');
      } else if (['/one.wav', '/two.wav'].contains(request.uri.path)) {
        request.response.headers.contentType = ContentType('audio', 'wav');
        request.response.contentLength = audio.length;
        request.response.add(audio);
      } else {
        request.response.statusCode = 404;
      }
      await request.response.close();
    });
    final engine = await AndroidMusicEngine.installed();
    expect(engine.available, isTrue, reason: engine.initializationError);
    final connection = DeezerConnectionController(_Sessions(), engine);
    final library = LibraryController(
        repository: LibraryRepository(AppDatabase('${temp.path}/library.db')),
        files: _Files('${temp.path}/output'),
        spotify: const SpotifyImporter(BoundedHttp()),
        csv: const CsvImporter(),
        catalog: const DeezerCatalog(BoundedHttp()),
        music: MusicResolver(engine, connection),
        downloader: DownloadService(const BoundedHttp(), rootBundle,
            music: MusicDownloadService(engine, connection)));
    final capture = AudioCaptureController(library);
    try {
      await library.initialize();
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await capture.analyze('http://127.0.0.1:${server.port}/page');
      expect(capture.result?.items.length, 2, reason: capture.message);
      expect(library.collections, isEmpty);
      capture.select(capture.result!.items.first.sourceId, false);
      expect(await capture.download(), isTrue, reason: capture.message);
      for (var i = 0; i < 600 && library.downloading; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      expect(library.downloading, isFalse);
      final track =
          (await library.repository.page(library.current!.id)).items.single;
      expect(track.status, TrackStatus.completed, reason: track.error);
      expect(track.sourceKind, SourceKind.webAudio);
      expect(track.manualUrl, isNotEmpty);
      final metadata = await AndroidAudioEngine.channel
          .invokeMapMethod<String, dynamic>('inspect', {'path': track.localPath});
      expect(metadata!['durationMs'] as int, greaterThan(1000));
      expect(metadata['mime'], anyOf('audio/mpeg', 'audio/mp3'));
      debugPrint('DD_ANDROID_AUDIO_CAPTURE_OK');
    } finally {
      capture.dispose();
      library.dispose();
      await server.close(force: true);
      await temp.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 4)));
}

import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:definitive_downloader/core/network/bounded_http.dart';
import 'package:definitive_downloader/core/platform/desktop_files.dart';
import 'package:definitive_downloader/core/storage/database.dart';
import 'package:definitive_downloader/features/audio_capture/application/audio_capture_controller.dart';
import 'package:definitive_downloader/features/audio_capture/data/audio_capture_service.dart';
import 'package:definitive_downloader/features/audio_capture/domain/audio_capture.dart';
import 'package:definitive_downloader/features/connections/application/deezer_connection_controller.dart';
import 'package:definitive_downloader/features/downloads/download_service.dart';
import 'package:definitive_downloader/features/downloads/music_download_service.dart';
import 'package:definitive_downloader/features/importing/csv_importer.dart';
import 'package:definitive_downloader/features/importing/spotify_importer.dart';
import 'package:definitive_downloader/features/library/application/library_controller.dart';
import 'package:definitive_downloader/features/library/data/library_repository.dart';
import 'package:definitive_downloader/features/library/domain/models.dart';
import 'package:definitive_downloader/features/matching/deezer_catalog.dart';
import 'package:definitive_downloader/features/matching/music_engine.dart';
import 'package:definitive_downloader/features/matching/music_resolver.dart';
import 'package:definitive_downloader/features/player/data/player_library.dart';
import 'music_resolver_test.dart' show EmptySession;

Map<String, dynamic> captureFixture(int number) => {
      'sourceId': List.filled(64, number == 1 ? 'a' : 'b').join(),
      'kind': 'webAudio',
      'recordingType': 'WEB_AUDIO',
      'title': 'Áudio $number',
      'artist': 'Ensaio local',
      'album': '',
      'durationMs': 4000,
      'pageUrl': 'https://example.org/audio-$number',
    };

class CaptureFixtureEngine implements MusicEngine {
  final calls = <Map<String, dynamic>>[];
  Completer<Map<String, dynamic>>? pending;
  @override
  bool get available => true;
  @override
  Future<Map<String, dynamic>> call(Map<String, dynamic> request,
      {DownloadCancellation? cancellation,
      void Function(String)? onStage,
      void Function(TransferProgress)? onProgress}) async {
    calls.add(request);
    if (request['operation'] == 'captureAnalyze') {
      if (pending != null) return pending!.future;
      return {
        'title': 'Página de ensaio',
        'pageUrl': request['url'],
        'items': [captureFixture(1), captureFixture(2)],
      };
    }
    if (request['operation'] != 'download') {
      throw StateError('Operação inesperada no ensaio de captura.');
    }
    cancellation?.check();
    final bytes = await rootBundle.load('assets/demo/tone.mp3');
    final path = '${request['directory']}/verified.mp3';
    await File(path).writeAsBytes(bytes.buffer.asUint8List());
    return {
      'path': path,
      'actual': request['candidate'],
      'durationMs': 4000,
      'decoded': true,
      'coverEmbedded': false,
    };
  }
}

class _CaptureFiles extends DesktopFiles {
  _CaptureFiles(this.root);
  final String root;
  @override
  Future<String> defaultOutputDirectory() async => '$root/output';
}

Future<LibraryController> captureFixtureLibrary(
    Directory directory, CaptureFixtureEngine engine) async {
  final connection = DeezerConnectionController(EmptySession(), engine);
  final library = LibraryController(
      repository: LibraryRepository(AppDatabase('${directory.path}/test.db')),
      files: _CaptureFiles(directory.path),
      spotify: const SpotifyImporter(BoundedHttp()),
      csv: const CsvImporter(),
      catalog: const DeezerCatalog(BoundedHttp()),
      music: MusicResolver(engine, connection),
      downloader: DownloadService(const BoundedHttp(), rootBundle,
          music: MusicDownloadService(engine, connection)));
  await library.initialize();
  return library;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('captura recusa protocolos, credenciais e fontes inválidas', () {
    for (final url in [
      'file:///audio.mp3',
      'https://user:secret@example.org/a',
      'https://example.org/line\nother',
    ]) {
      expect(() => captureUrl(url), throwsFormatException);
    }
    expect(captureUrl('https://example.org/page').host, 'example.org');
    expect(() => capturedAudio({...captureFixture(1), 'sourceId': 'wrong'}),
        throwsFormatException);
    expect(() => capturedAudio({...captureFixture(1), 'kind': 'deezerFull'}),
        throwsFormatException);
  });

  test('analisar não importa; baixar preserva somente os áudios escolhidos',
      () async {
    final directory = await Directory.systemTemp.createTemp('dd-capture-');
    final engine = CaptureFixtureEngine();
    final library = await captureFixtureLibrary(directory, engine);
    final controller = AudioCaptureController(library);
    try {
      final originalId = await library.repository.importCollection(
          ImportedCollection(
              name: 'Fila anterior',
              source: 'Ensaio',
              sourceUrl: '',
              tracks: Stream.value(const TrackDraft(
                  title: 'Anterior',
                  artist: '',
                  sourceKind: SourceKind.directMp3,
                  mediaUrl: 'https://example.org/original.mp3'))));
      await library.refresh();
      await controller.analyze('https://example.org/page');
      expect(controller.result!.items.length, 2);
      expect(library.collections, hasLength(1));
      expect(library.downloading, isFalse);
      expect(engine.calls.map((call) => call['operation']), ['captureAnalyze']);

      controller.select(captureFixture(1)['sourceId'] as String, false);
      expect(await controller.download(), isTrue);
      for (var i = 0; i < 200 && library.downloading; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(library.downloading, isFalse);
      final owner = library.current!;
      final tracks = (await library.repository.page(owner.id)).items;
      expect(tracks, hasLength(1));
      final track = tracks.single;
      expect(track.title, 'Áudio 2');
      expect(track.position, 1);
      expect(track.sourceKind, SourceKind.webAudio);
      expect(track.hasManualSource, isTrue);
      expect(track.status, TrackStatus.completed, reason: track.error);
      expect(await File(track.localPath).exists(), isTrue);
      expect(PlayerLibrary(library.repository.database).referenceFor(track),
          'https://example.org/audio-2');
      expect(engine.calls.map((call) => call['operation']),
          ['captureAnalyze', 'download']);
      expect(engine.calls.last['authorization'], 'manualLink');
      expect((await library.repository.page(originalId)).items.single.status,
          TrackStatus.ready);

      final reopened =
          LibraryRepository(AppDatabase('${directory.path}/test.db'));
      final restored = (await reopened.page(owner.id)).items.single;
      expect(restored.sourceKind, SourceKind.webAudio);
      expect(restored.sourceId, captureFixture(2)['sourceId']);
    } finally {
      controller.dispose();
      library.dispose();
      await directory.delete(recursive: true);
    }
  });

  test('cancelar análise descarta resposta atrasada e permite tentar novamente',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('dd-capture-cancel-');
    final engine = CaptureFixtureEngine()
      ..pending = Completer<Map<String, dynamic>>();
    final library = await captureFixtureLibrary(directory, engine);
    final controller = AudioCaptureController(library);
    try {
      final analyzing = controller.analyze('https://example.org/page');
      controller.cancel();
      engine.pending!.complete({
        'title': 'Resposta tardia',
        'pageUrl': 'https://example.org/page',
        'items': [captureFixture(1)],
      });
      await analyzing;
      expect(controller.result, isNull);
      expect(library.collections, isEmpty);
      engine.pending = null;
      await controller.analyze('https://example.org/page');
      expect(controller.result, isNotNull);
      controller.clearResult();
      expect(controller.selected, isEmpty);
      expect(await controller.download(), isFalse);
      expect(library.collections, isEmpty);
    } finally {
      controller.dispose();
      library.dispose();
      await directory.delete(recursive: true);
    }
  });

  test('resposta com IDs repetidos é recusada antes de criar a playlist',
      () async {
    final engine = CaptureFixtureEngine()
      ..pending = Completer<Map<String, dynamic>>();
    final analysis = AudioCaptureService(engine).analyze(
        'https://example.org/page',
        cancellation: DownloadCancellation());
    engine.pending!.complete({
      'title': 'Página',
      'pageUrl': 'https://example.org/page',
      'items': [captureFixture(1), captureFixture(1)],
    });
    await expectLater(analysis, throwsFormatException);
  });
}

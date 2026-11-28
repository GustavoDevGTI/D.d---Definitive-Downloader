import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_test/flutter_test.dart';
import 'package:definitive_downloader/core/network/bounded_http.dart';
import 'package:definitive_downloader/core/platform/desktop_files.dart';
import 'package:definitive_downloader/core/storage/database.dart';
import 'package:definitive_downloader/features/audio_capture/application/audio_capture_controller.dart';
import 'package:definitive_downloader/features/audio_capture/data/audio_capture_service.dart';
import 'package:definitive_downloader/features/audio_capture/domain/audio_capture.dart';
import 'package:definitive_downloader/features/audio_capture/data/capture_sessions.dart';
import 'package:definitive_downloader/features/audio_capture/domain/capture_login.dart';
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
      final url = request['url'] as String;
      if (url.contains('instagram.com')) {
        final session = request['session'] as List?;
        final valid = session?.any((c) =>
                (c as Map)['name'] == 'sessionid' && c['value'] == 'ok') ==
            true;
        if (!valid) {
          return {
            'loginRequired': 'instagram',
            'sessionRejected': session != null,
            'pageUrl': url
          };
        }
        return {
          'title': 'Reel',
          'pageUrl': url,
          'items': [
            {...captureFixture(1), 'pageUrl': url}
          ],
        };
      }
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
    Directory directory, CaptureFixtureEngine engine,
    {CaptureSessionStore? sessions}) async {
  final connection = DeezerConnectionController(EmptySession(), engine);
  final library = LibraryController(
      repository: LibraryRepository(AppDatabase('${directory.path}/test.db')),
      files: _CaptureFiles(directory.path),
      spotify: const SpotifyImporter(BoundedHttp()),
      csv: const CsvImporter(),
      catalog: const DeezerCatalog(BoundedHttp()),
      music: MusicResolver(engine, connection),
      captureSessions: sessions,
      downloader: DownloadService(const BoundedHttp(), rootBundle,
          music: MusicDownloadService(engine, connection,
              captureSessions: sessions)));
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
      // A single audio gets a folder named after itself in Downloads.
      expect(owner.name, 'Áudio 2');
      expect(p.dirname(track.localPath), p.join(directory.path, 'Áudio 2'));
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

  test('descartar remove da análise sem salvar nada', () async {
    final directory = await Directory.systemTemp.createTemp('dd-capture-');
    final library =
        await captureFixtureLibrary(directory, CaptureFixtureEngine());
    final controller = AudioCaptureController(library);
    try {
      await controller.analyze('https://example.org/page');
      controller.discard(captureFixture(1)['sourceId'] as String);
      expect(controller.result!.items.map((item) => item.title), ['Áudio 2']);
      expect(controller.selected, {captureFixture(2)['sourceId']});
      controller.discardSelected();
      expect(controller.result, isNull);
      expect(controller.selected, isEmpty);
      expect(library.collections, isEmpty);
    } finally {
      controller.dispose();
      library.dispose();
      await directory.delete(recursive: true);
    }
  });

  test(
      'salvar como playlist usa a pasta escolhida e não baixa; '
      'adicionar a playlist acrescenta no fim', () async {
    final directory = await Directory.systemTemp.createTemp('dd-capture-');
    final engine = CaptureFixtureEngine();
    final library = await captureFixtureLibrary(directory, engine);
    final controller = AudioCaptureController(library);
    try {
      final existing = await library.repository.importCollection(
          ImportedCollection(
              name: 'Minha lista',
              source: 'Ensaio',
              sourceUrl: '',
              tracks: Stream.value(const TrackDraft(
                  title: 'Primeira',
                  artist: '',
                  sourceKind: SourceKind.directMp3,
                  mediaUrl: 'https://example.org/original.mp3'))));
      await library.refresh();
      await controller.analyze('https://example.org/page');
      final chosen = p.join(directory.path, 'Escolhida');
      controller.destinationRoot = chosen;
      expect(controller.destinationPreview, p.join(chosen, 'Página de ensaio'));

      final saved = await controller.saveAsPlaylist();
      expect(saved, isNotNull, reason: controller.message);
      expect(saved!.name, 'Página de ensaio');
      expect(library.downloading, isFalse);
      expect(engine.calls.map((call) => call['operation']), ['captureAnalyze']);
      final destination = await library.destinationOf(saved.id);
      expect(destination.customRoot, isTrue);
      expect(destination.directory, p.join(chosen, 'Página de ensaio'));
      expect(await Directory(destination.directory).exists(), isFalse);

      controller.selectAll(true);
      final target = (await library.repository.collectionById(existing))!;
      expect(await controller.addToPlaylist(target), isTrue,
          reason: controller.message);
      final tracks = (await library.repository.page(existing)).items;
      expect(tracks.map((t) => (t.position, t.title)),
          [(1, 'Primeira'), (2, 'Áudio 1'), (3, 'Áudio 2')]);
      expect(tracks.last.sourceKind, SourceKind.webAudio);
      expect(tracks.last.hasManualSource, isTrue);
      expect(tracks.last.status, TrackStatus.ready);
      expect(engine.calls.map((call) => call['operation']), ['captureAnalyze']);
    } finally {
      controller.dispose();
      library.dispose();
      await directory.delete(recursive: true);
    }
  });

  group('login de plataforma na captura', () {
    const reel = 'https://www.instagram.com/reel/AbC123/';
    SessionCookie cookie(String value) => SessionCookie(
        name: 'sessionid', value: value, domain: '.instagram.com');

    test('pede login, repete a análise, guarda e reaproveita a sessão',
        () async {
      final directory = await Directory.systemTemp.createTemp('dd-capture-');
      final engine = CaptureFixtureEngine();
      final sessions = MemoryCaptureSessionStore();
      final library =
          await captureFixtureLibrary(directory, engine, sessions: sessions);
      final controller = AudioCaptureController(library);
      var asked = 0;
      controller.requestLogin = (platform, verify) async {
        asked++;
        expect(platform, CapturePlatform.instagram);
        // A wrong session keeps the window open; the right one closes it.
        expect(await verify([cookie('wrong')]), isFalse);
        final session = [cookie('ok')];
        expect(await verify(session), isTrue);
        return session;
      };
      try {
        await controller.analyze(reel);
        expect(controller.result?.items.single.pageUrl, reel,
            reason: controller.message);
        expect(asked, 1);
        expect(controller.signedIn, {CapturePlatform.instagram});
        expect((await sessions.read(CapturePlatform.instagram))!.single.value,
            'ok');

        await controller.analyze(reel);
        expect(asked, 1, reason: 'A sessão salva é usada sem novo login.');
        expect(controller.result, isNotNull);
        // Other sites never receive the Instagram session.
        await controller.analyze('https://example.org/page');
        expect(engine.calls.last.containsKey('session'), isFalse);
      } finally {
        controller.dispose();
        library.dispose();
        await _deleteTemp(directory);
      }
    });

    test('download de áudio do Instagram leva a sessão salva', () async {
      final directory = await Directory.systemTemp.createTemp('dd-capture-');
      final engine = CaptureFixtureEngine();
      final sessions = MemoryCaptureSessionStore();
      await sessions.write(CapturePlatform.instagram, [cookie('ok')]);
      final library =
          await captureFixtureLibrary(directory, engine, sessions: sessions);
      final controller = AudioCaptureController(library);
      try {
        await controller.analyze(reel);
        expect(await controller.download(), isTrue, reason: controller.message);
        for (var i = 0;
            i < 750 &&
                (library.downloading ||
                    !engine.calls
                        .any((call) => call['operation'] == 'download'));
            i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        final download =
            engine.calls.lastWhere((call) => call['operation'] == 'download');
        expect((download['session'] as List).single['value'], 'ok');
      } finally {
        controller.dispose();
        library.dispose();
        await _deleteTemp(directory);
      }
    });

    test('sessão recusada é apagada; login cancelado não captura nada',
        () async {
      final directory = await Directory.systemTemp.createTemp('dd-capture-');
      final sessions = MemoryCaptureSessionStore();
      await sessions.write(CapturePlatform.instagram, [cookie('expired')]);
      final library = await captureFixtureLibrary(
          directory, CaptureFixtureEngine(),
          sessions: sessions);
      final controller = AudioCaptureController(library)
        ..requestLogin = (_, __) async => null;
      try {
        await controller.loadSessions();
        expect(controller.signedIn, {CapturePlatform.instagram});
        await controller.analyze(reel);
        expect(controller.result, isNull);
        expect(controller.message, contains('Login no Instagram cancelado'));
        expect(await sessions.read(CapturePlatform.instagram), isNull);
        expect(controller.signedIn, isEmpty);
        expect(library.collections, isEmpty);
      } finally {
        controller.dispose();
        library.dispose();
        await _deleteTemp(directory);
      }
    });

    test('sessão só aceita cookies da própria plataforma', () {
      expect(CapturePlatform.forUrl(reel), CapturePlatform.instagram);
      expect(CapturePlatform.forUrl('https://notinstagram.com/p/x'), isNull);
      expect(
          platformSession(CapturePlatform.instagram, [
            const SessionCookie(
                name: 'sessionid', value: 'x', domain: '.example.org')
          ]),
          isNull);
      expect(
          platformSession(CapturePlatform.instagram, [
            const SessionCookie(
                name: 'csrftoken', value: 'x', domain: '.instagram.com')
          ]),
          isNull,
          reason: 'Sem sessionid não há login.');
      expect(
          platformSession(CapturePlatform.instagram, [cookie('a;b')]), isNull);
      expect(
          CapturePlatform.instagram
              .allowsNavigation(Uri.parse('https://www.facebook.com/login')),
          isFalse);
      expect(
          CapturePlatform.instagram.allowsNavigation(
              Uri.parse('https://www.instagram.com/accounts/login/')),
          isTrue);
    });
  });
}

// Windows can hold a just-written file for a moment after the run finishes.
Future<void> _deleteTemp(Directory directory) async {
  for (var attempt = 0;; attempt++) {
    try {
      await directory.delete(recursive: true);
      return;
    } on FileSystemException {
      if (attempt >= 20) rethrow;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  }
}

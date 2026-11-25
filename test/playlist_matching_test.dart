import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:definitive_downloader/core/network/bounded_http.dart';
import 'package:definitive_downloader/core/platform/desktop_files.dart';
import 'package:definitive_downloader/core/storage/database.dart';
import 'package:definitive_downloader/features/connections/application/deezer_connection_controller.dart';
import 'package:definitive_downloader/features/downloads/download_service.dart';
import 'package:definitive_downloader/features/importing/csv_importer.dart';
import 'package:definitive_downloader/features/importing/trackhop_client.dart';
import 'package:definitive_downloader/features/importing/spotify_importer.dart';
import 'package:definitive_downloader/features/library/application/library_controller.dart';
import 'package:definitive_downloader/features/library/data/library_repository.dart';
import 'package:definitive_downloader/features/library/domain/models.dart';
import 'package:definitive_downloader/features/library/domain/preparation_progress.dart';
import 'package:definitive_downloader/features/library/domain/track_listing.dart';
import 'package:definitive_downloader/features/library/presentation/library_operation_status.dart';
import 'package:definitive_downloader/features/matching/deezer_catalog.dart';
import 'package:definitive_downloader/features/matching/music_resolver.dart';
import 'music_resolver_test.dart' show EmptyEngine, EmptySession;
import 'package:definitive_downloader/app/theme.dart';
import 'package:definitive_downloader/features/library/presentation/collection_track_toolbar.dart';
import 'package:definitive_downloader/features/library/presentation/track_inspector.dart';
import 'package:definitive_downloader/features/library/presentation/track_table.dart';
import 'package:definitive_downloader/features/organization/presentation/collection_manager.dart';
import 'widget_io.dart';

const fixturePlaylistUrl =
    'https://open.spotify.com/playlist/0123456789012345678901';

class FixturePlaylist extends SpotifyImporter {
  FixturePlaylist(this.tracks) : super(const BoundedHttp());
  final List<TrackDraft> tracks;

  @override
  Future<ImportedCollection> open(String input) async => ImportedCollection(
      name: 'Playlist de teste',
      source: 'Spotify',
      sourceUrl: '',
      tracks: Stream.fromIterable(tracks));
}

class _ConnectedPlaylistFixture extends TrackhopClient {
  _ConnectedPlaylistFixture(this.tracks)
      : super(Uri.parse(TrackhopClient.desktopAddress), 'fixture-trackhop-key');
  final List<TrackDraft> tracks;
  final opened = Completer<void>();
  Completer<void>? paused, release;

  @override
  Future<ImportedCollection> playlist(String input,
      {bool Function()? cancelled, void Function(int, int)? onProgress}) async {
    if (!opened.isCompleted) opened.complete();
    if (release != null) {
      paused?.complete();
      await release!.future;
    }
    return ImportedCollection(
        name: 'Playlist de teste',
        source: 'Spotify · conta conectada',
        sourceUrl: input,
        tracks: Stream.fromIterable(tracks));
  }
}

class FixtureMatching extends MusicResolver {
  FixtureMatching(super.engine, super.connection);
  Completer<void>? gate;
  final started = Completer<void>();
  final calls = <int>[];
  Completer<void>? secondStarted, secondGate;
  @override
  Future<List<Candidate>> search(Track track, String query,
      {DownloadCancellation? cancellation}) async {
    calls.add(track.id);
    if (!started.isCompleted) started.complete();
    await gate?.future;
    if (calls.length == 2 && secondGate != null) {
      secondStarted?.complete();
      await secondGate!.future;
    }
    cancellation?.check();
    if (track.title == 'Erro') {
      throw const FormatException('Busca indisponível.');
    }
    if (track.title == 'Vazia') return [];
    final video = track.title == 'Vídeo';
    return [
      Candidate(
          title: track.title,
          artist: track.artist,
          album: track.album,
          durationMs: track.durationMs ?? 180000,
          pageUrl:
              'https://${video ? 'www' : 'music'}.youtube.com/watch?v=abcdefghijk',
          previewUrl: '',
          coverUrl: '',
          kind: video ? SourceKind.youtube : SourceKind.youtubeMusic,
          recordingType:
              video ? 'MUSIC_VIDEO_TYPE_OMV' : 'MUSIC_VIDEO_TYPE_ATV')
    ];
  }
}

Future<void> finishMatching(LibraryController c) async {
  await c.preparationDone.timeout(const Duration(seconds: 45));
  expect(c.preparing, isFalse);
}

void main() {
  late Directory temp;
  late LibraryRepository repository;
  late DeezerConnectionController connection;
  late FixtureMatching resolver;
  late _ConnectedPlaylistFixture importer;
  LibraryController controller(List<TrackDraft> tracks) {
    importer = _ConnectedPlaylistFixture(tracks);
    final c = LibraryController(
        repository: repository,
        files: DesktopFiles(),
        spotify: const SpotifyImporter(BoundedHttp()),
        trackhopClient: () => importer,
        csv: const CsvImporter(),
        catalog: const DeezerCatalog(BoundedHttp()),
        music: resolver,
        downloader: DownloadService(const BoundedHttp(), rootBundle));
    addTearDown(() async {
      c.cancel();
      if (resolver.gate?.isCompleted == false) resolver.gate!.complete();
      await c.preparationDone;
      c.dispose();
    });
    return c;
  }

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('dd-auto-match-');
    repository = LibraryRepository(AppDatabase('${temp.path}/test.db'));
    await repository.database.initialize();
    final engine = EmptyEngine();
    connection = DeezerConnectionController(EmptySession(), engine);
    resolver = FixtureMatching(engine, connection);
  });
  tearDown(() async {
    connection.dispose();
    await temp.delete(recursive: true);
  });

  test('playlist salva continua selecionável durante retomada da conferência',
      () async {
    final id = await repository.importCollection(ImportedCollection(
        name: 'Playlist salva',
        source: 'Spotify',
        sourceUrl: fixturePlaylistUrl,
        tracks: Stream.fromIterable(const [
          TrackDraft(title: 'Primeira', artist: 'Pessoa', durationMs: 180000),
          TrackDraft(title: 'Segunda', artist: 'Pessoa', durationMs: 180000),
        ])));
    final saved = (await repository.page(id)).items;
    await repository.select(saved.first.id, true);
    await repository.database.initialize(); // Reopen the persisted library.
    resolver.gate = Completer<void>();
    final c = controller(const []);
    await c.openCollection((await repository.collectionById(id))!);
    await resolver.started.future.timeout(const Duration(seconds: 5));
    expect(c.preparingCurrent, isTrue);
    expect(c.page.items.first.selected, isTrue);
    expect(await c.clickTrack(c.page.items.last, extend: false), isTrue,
        reason:
            'Busca em segundo plano não pode prender a seleção restaurada.');
    expect(c.page.items.first.selected, isFalse);
    expect(c.page.items.last.selected, isTrue);
    await c.select(c.page.items.last, false);
    expect(c.page.selectedCount, 0);
    await c.selectCollection(true);
    expect(c.page.selectedCount, 2);
    c.togglePreparationPause();
    await c.selectCollection(false);
    expect(c.page.selectedCount, 0);
    await c.selectSweep([saved.first.id]);
    expect(c.page.selectedCount, 1);
    expect(c.page.items.first.selected, isTrue);
    expect(c.preparingCurrent, isTrue);
  });

  testWidgets(
      'excluir playlist interrompe sua conferência e preserva mídia e histórico',
      (tester) async {
    tester.view.physicalSize = const Size(1360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late LibraryController c;
    late int id;
    late File media;
    await tester.runAsync(() async {
      id = await repository.importCollection(ImportedCollection(
          name: 'Excluir salva',
          source: 'Spotify',
          sourceUrl: fixturePlaylistUrl,
          tracks: Stream.fromIterable(const [
            TrackDraft(title: 'Salva', artist: 'Pessoa'),
            TrackDraft(title: 'Pendente', artist: 'Pessoa'),
          ])));
      media = await File('${temp.path}/preservar.mp3').writeAsBytes([1, 2, 3]);
      await repository.setStatus(
          (await repository.page(id)).items.first.id, TrackStatus.completed,
          localPath: media.path);
      resolver.gate = Completer<void>();
      c = controller(const []);
      await c.openCollection((await repository.collectionById(id))!);
      await resolver.started.future;
    });
    await tester.pumpWidget(MaterialApp(
        theme: appTheme(platform: TargetPlatform.windows),
        home: Scaffold(body: CollectionManager(library: c, onOpen: (_) {}))));
    final menu = find.byKey(ValueKey('collection-menu-$id'));
    await ioUntil(tester, () => menu.evaluate().isNotEmpty);
    expect(tester.widget<PopupMenuButton<String>>(menu).enabled, isTrue,
        reason: 'A conferência não deve impedir excluir a própria playlist.');
    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('collection-delete-$id')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Excluir playlist'));
    await ioUntil(tester, () => c.preparationStopping);
    resolver.gate!.complete();
    await ioUntil(tester, () => c.collections.every((item) => item.id != id));
    await tester.runAsync(() async {
      await c.preparationDone;
      expect(await repository.collectionById(id), isNull);
      expect(await media.readAsBytes(), [1, 2, 3]);
      expect(
          await repository.database.run((db) => db
              .select('SELECT track_id FROM download_history')
              .single['track_id']),
          isNull);
    });
    expect(c.current, isNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  test('excluir playlist na fila de conferência não cancela a busca de outra',
      () async {
    Future<int> saved(String name) =>
        repository.importCollection(ImportedCollection(
            name: name,
            source: 'Spotify',
            sourceUrl: fixturePlaylistUrl,
            tracks: Stream.value(const TrackDraft(
                title: 'Faixa', artist: 'Pessoa', durationMs: 180000))));
    final first = await saved('Primeira');
    final second = await saved('Segunda');
    resolver.gate = Completer<void>();
    final c = controller(const []);
    await c.openCollection((await repository.collectionById(first))!);
    await resolver.started.future;
    await c.openCollection((await repository.collectionById(second))!);
    expect(c.waitingPreparations, 1);
    await c.removeCollection(second);
    expect(await repository.collectionById(second), isNull);
    expect(c.waitingPreparations, 0);
    expect(c.preparingCollection!.id, first);
    expect(c.preparationStopping, isFalse);
    resolver.gate!.complete();
    await finishMatching(c);
    expect(resolver.calls, hasLength(1));
    expect(
        (await repository.page(first)).items.single.status, TrackStatus.ready);
  });

  testWidgets(
      'playlist salva aceita cliques e checkboxes durante conferência pendente',
      (tester) async {
    tester.view.physicalSize = const Size(1360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late LibraryController c;
    await tester.runAsync(() async {
      final id = await repository.importCollection(ImportedCollection(
          name: 'Playlist salva',
          source: 'Spotify',
          sourceUrl: fixturePlaylistUrl,
          tracks: Stream.fromIterable(const [
            TrackDraft(title: 'Primeira', artist: 'Pessoa'),
            TrackDraft(title: 'Segunda', artist: 'Pessoa'),
          ])));
      await repository.select((await repository.page(id)).items.first.id, true);
      await repository.database.initialize();
      resolver.gate = Completer<void>();
      c = controller(const []);
      await c.openCollection((await repository.collectionById(id))!);
      await resolver.started.future;
    });
    await tester.pumpWidget(MaterialApp(
        theme: appTheme(platform: TargetPlatform.windows),
        home: Scaffold(
            body: ListenableBuilder(
                listenable: c,
                builder: (_, __) =>
                    TrackTable(controller: c, onFocus: c.focus)))));
    await tester.pumpAndSettle();
    final second = c.page.items.last.id;
    final row = find.byKey(ValueKey('track-row-$second'));
    final check = find.descendant(of: row, matching: find.byType(Checkbox));
    expect(tester.widget<Checkbox>(check).onChanged, isNotNull,
        reason:
            'A conferência automática não pode desabilitar as caixas de seleção.');
    await tester.tap(row);
    await ioUntil(tester,
        () => c.page.items.last.selected && !c.page.items.first.selected);
    await tester.tap(check);
    await ioUntil(tester, () => c.page.selectedCount == 0);
    await tester.tap(find.byKey(const ValueKey('select-all-collection')));
    await ioUntil(tester, () => c.page.selectedCount == 2);
    c.togglePreparationPause();
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('select-all-collection')));
    await ioUntil(tester, () => c.page.selectedCount == 0);
    expect(c.preparingCurrent, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  test(
      'faixa pronta da playlist salva pode baixar enquanto outra aguarda conferência',
      () async {
    final previousHttp = HttpOverrides.current;
    HttpOverrides.global =
        null; // Requests are restricted to this loopback fixture.
    addTearDown(() => HttpOverrides.global = previousHttp);
    final bytes =
        (await rootBundle.load('assets/demo/tone.mp3')).buffer.asUint8List();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.headers.contentType = ContentType('audio', 'mpeg');
      request.response.add(bytes);
      await request.response.close();
    });
    addTearDown(() => server.close(force: true));
    final id = await repository.importCollection(ImportedCollection(
        name: 'Playlist salva',
        source: 'Spotify',
        sourceUrl: fixturePlaylistUrl,
        tracks: Stream.fromIterable([
          TrackDraft(
              title: 'Pronta',
              artist: 'Pessoa',
              sourceKind: SourceKind.directMp3,
              mediaUrl: 'http://127.0.0.1:${server.port}/tone.mp3'),
          const TrackDraft(
              title: 'Pendente', artist: 'Pessoa', durationMs: 180000),
        ])));
    final before = (await repository.page(id)).items;
    await repository.select(before.first.id, true);
    resolver.gate = Completer<void>();
    final c = controller(const [])..outputDirectory = '${temp.path}/output';
    await c.openCollection((await repository.collectionById(id))!);
    await resolver.started.future;
    await c.downloadSelected();
    final after = (await repository.page(id)).items;
    expect(after.first.status, TrackStatus.completed,
        reason:
            'Uma busca pendente não deve bloquear o download de uma fonte já pronta.');
    expect(await File(after.first.localPath).exists(), isTrue);
    expect(after.last.status, TrackStatus.pending);
    expect(after.last.localPath, isEmpty);
    expect(c.preparingCurrent, isTrue);
    resolver.gate!.complete();
    await finishMatching(c);
    final finished = (await repository.page(id)).items;
    expect(finished.first.status, TrackStatus.completed);
    expect(finished.first.localPath, after.first.localPath);
    expect(finished.last.status, TrackStatus.ready);
    expect(finished.last.localPath, isEmpty);
  });

  test(
      'reconferência completa conserva bloqueio de download sem prender seleção',
      () async {
    final id = await repository.importCollection(ImportedCollection(
        name: 'Salva pronta',
        source: 'Spotify',
        sourceUrl: fixturePlaylistUrl,
        tracks: Stream.value(const TrackDraft(
            title: 'Pronta',
            artist: 'Pessoa',
            mediaUrl: 'https://example.org/fixture.mp3',
            sourceKind: SourceKind.directMp3))));
    await repository.select((await repository.page(id)).items.first.id, true);
    resolver.gate = Completer<void>();
    final c = controller(const []);
    await c.openCollection((await repository.collectionById(id))!);
    unawaited(c.prepareMusic(onlyPending: false));
    await resolver.started.future;
    expect(c.downloadBlocked, isTrue);
    expect(c.selectionBlocked, isFalse);
    expect(c.busy, isTrue); // Source/name editing remains protected.
    await c.selectCollection(false);
    expect(c.page.selectedCount, 0);
    expect((await repository.page(id)).items.single.status, TrackStatus.ready);
  });

  test('estimativa usa amostras da busca e descarta faixas já conferidas', () {
    const progress = PreparationProgress(
        total: 10, checked: 6, measured: 2, elapsed: Duration(seconds: 30));
    expect(progress.fraction, .6);
    expect(progress.remaining, const Duration(minutes: 1));
    const resuming = PreparationProgress(
        total: 10, checked: 6, measured: 0, elapsed: Duration.zero);
    expect(resuming.remaining, isNull);
  });

  test(
      'refazer conferência da única selecionada pesquisa sem alterar o arquivo baixado',
      () async {
    final c = controller(const [
      TrackDraft(title: 'Baixada', artist: 'Pessoa', durationMs: 180000),
      TrackDraft(title: 'Outra', artist: 'Pessoa', durationMs: 180000),
    ]);
    await c.importSpotify(fixturePlaylistUrl);
    await finishMatching(c);
    final first = (await repository.page(c.current!.id)).items.first;
    final file = File('${temp.path}/original.mp3');
    await file.writeAsString('arquivo preservado');
    await repository.setStatus(first.id, TrackStatus.completed,
        localPath: file.path);
    await repository.select(first.id, true);
    await c.refresh();
    final downloaded = c.page.items.first;
    c.focus(downloaded);
    final before = resolver.calls.length;
    await c.prepareMusic();
    expect(resolver.calls.length, before + 1);
    expect(resolver.calls.last, downloaded.id);
    expect(c.candidates, isNotEmpty);
    expect(c.message, isNot(contains('0 faixa(s) preparada')));
    final after = (await repository.page(c.current!.id)).items.first;
    expect(after.status, TrackStatus.completed);
    expect(after.localPath, downloaded.localPath);
    expect(after.mediaUrl, downloaded.mediaUrl);
    expect(after.redownloadState, isEmpty);
    expect(await file.readAsString(), 'arquivo preservado');
  });

  for (final width in [900.0, 390.0]) {
    testWidgets(
        'rever baixada abre comparação sem controles de substituição a $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 820);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = controller(const [
        TrackDraft(title: 'Baixada', artist: 'Pessoa', durationMs: 180000),
      ]);
      await tester.runAsync(() async {
        await c.importSpotify(fixturePlaylistUrl);
        await finishMatching(c);
        final track = c.page.items.single;
        await repository.setStatus(track.id, TrackStatus.completed,
            localPath: '${temp.path}/original.mp3');
        await repository.select(track.id, true);
        await c.refresh();
        c.focus(c.page.items.single);
      });
      final query = TextEditingController();
      await tester.pumpWidget(MaterialApp(
          theme: appTheme(platform: TargetPlatform.windows),
          home: Scaffold(
              body: ListenableBuilder(
                  listenable: c,
                  builder: (context, _) => Column(children: [
                        CollectionTrackToolbar(
                            controller: c,
                            query: query,
                            onQueryChanged: (_) {},
                            onClear: () {},
                            onDownload: () {}),
                        Expanded(child: TrackInspector(controller: c)),
                      ])))));
      await tester.pumpAndSettle();
      expect(find.text('Buscar outras versões'), findsNothing);
      expect(find.text('Rever correspondência'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('start-playlist-conference')));
      await ioUntil(tester, () => resolver.calls.length == 2 && !c.searching);
      expect(find.text('Buscar outras versões'), findsOneWidget);
      expect(c.candidates, isNotEmpty);
      expect(find.byType(RadioListTile<Candidate>), findsNothing);
      expect(find.text('Usar esta versão'), findsNothing);
      expect(c.message, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      query.dispose();
    });
  }

  testWidgets('painel da conferência exibe contagem, barra e previsão',
      (tester) async {
    final c = controller([
      const TrackDraft(title: 'Primeira', artist: 'Pessoa', durationMs: 180000),
      const TrackDraft(title: 'Segunda', artist: 'Pessoa', durationMs: 180000),
    ]);
    addTearDown(() {
      if (resolver.secondGate?.isCompleted == false) {
        resolver.secondGate!.complete();
      }
    });
    await tester.runAsync(() async {
      resolver.gate = Completer<void>();
      resolver.secondGate = Completer<void>();
      resolver.secondStarted = Completer<void>();
      await c.importPlaylist(fixturePlaylistUrl);
      await resolver.started.future.timeout(const Duration(seconds: 10));
    });
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: LibraryOperationStatus(controller: c))));
    expect(find.text('0 de 2 faixas conferidas'), findsOneWidget);
    expect(find.text('Calculando tempo restante…'), findsOneWidget);
    await tester.runAsync(() async {
      resolver.gate!.complete();
      await resolver.secondStarted!.future.timeout(const Duration(seconds: 10));
    });
    await tester.pump();
    expect(find.text('1 de 2 faixas conferidas'), findsOneWidget);
    expect(find.textContaining('1 min restante'), findsOneWidget);
    expect(
        tester
            .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator))
            .value,
        .5);
    await tester.tap(find.text('Pausar'));
    await tester.pump();
    expect(find.text('Pausada'), findsOneWidget);
    expect(find.text('Retomar'), findsOneWidget);
    await tester.runAsync(() async {
      resolver.secondGate!.complete();
      await c.preparationDone.timeout(const Duration(seconds: 10));
    });
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test(
      'cancelar importação preserva a biblioteca anterior e não começa conferência',
      () async {
    final c = controller([
      const TrackDraft(title: 'Nova', artist: 'Pessoa', durationMs: 180000)
    ]);
    final pending = c.importPlaylist(fixturePlaylistUrl);
    await importer.opened.future;
    expect(c.importing, isTrue);
    c.cancel();
    await pending;
    expect(c.message, 'Importação cancelada.');
    expect(await repository.collections(), isEmpty);
    expect(resolver.calls, isEmpty);
  });

  test('retomar após parar consulta somente as faixas ainda não conferidas',
      () async {
    resolver.secondStarted = Completer<void>();
    resolver.secondGate = Completer<void>();
    final c = controller([
      for (final title in ['Vazia', 'Pendente', 'Última'])
        TrackDraft(title: title, artist: 'Pessoa', durationMs: 180000)
    ]);
    await c.importPlaylist(fixturePlaylistUrl);
    await resolver.secondStarted!.future;
    final rows = (await repository.page(c.current!.id)).items;
    expect(rows.first.matchStatus, MatchStatus.review);
    c.cancelPreparation();
    resolver.secondGate!.complete();
    await finishMatching(c);
    expect(resolver.calls, rows.take(2).map((t) => t.id));
    resolver.gate = Completer<void>();
    final resumed = c.prepareMusic();
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (c.preparationProgress == null && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(c.preparationProgress?.checked, 1);
    expect(c.preparationProgress?.total, 3);
    expect(c.preparationProgress?.remaining, isNull);
    resolver.gate!.complete();
    await resumed;
    expect(resolver.calls, [rows[0].id, rows[1].id, rows[1].id, rows[2].id]);
    expect(
        (await repository.trackById(rows.last.id))!.status, TrackStatus.ready);
  });

  test('pausar termina a faixa atual e espera antes da próxima', () async {
    resolver.gate = Completer<void>();
    final c = controller([
      const TrackDraft(title: 'Primeira', artist: 'Pessoa', durationMs: 180000),
      const TrackDraft(title: 'Segunda', artist: 'Pessoa', durationMs: 180000),
    ]);
    await c.importPlaylist(fixturePlaylistUrl);
    await resolver.started.future;
    final rows = (await repository.page(c.current!.id)).items;
    c.togglePreparationPause();
    expect(c.preparationPaused, isTrue);
    resolver.gate!.complete();
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    Track? first;
    do {
      await Future<void>.delayed(const Duration(milliseconds: 25));
      first = await repository.trackById(rows.first.id);
    } while ((first?.status != TrackStatus.ready ||
            c.preparationProgress?.checked != 1) &&
        DateTime.now().isBefore(deadline));
    expect(first?.status, TrackStatus.ready);
    expect(resolver.calls, [rows.first.id]);
    expect(c.preparing, isTrue);
    expect(c.preparationProgress?.checked, 1);
    expect(c.preparationProgress?.total, 2);
    expect(c.preparationProgress?.remaining, isNotNull);
    c.togglePreparationPause();
    await finishMatching(c);
    expect(resolver.calls, rows.map((t) => t.id));
  });

  test('importa a segunda playlist enquanto a primeira está em conferência',
      () async {
    resolver.gate = Completer<void>();
    final c = controller([
      const TrackDraft(title: 'Faixa', artist: 'Pessoa', durationMs: 180000)
    ]);
    await c.importPlaylist(fixturePlaylistUrl);
    await resolver.started.future;
    final first = c.current!;
    final firstTrack = (await repository.page(first.id)).items.single.id;

    await c.importPlaylist(
        'https://open.spotify.com/playlist/1123456789012345678901');

    expect(c.preparing, isTrue);
    expect(c.importing, isFalse);
    expect(await repository.collections(), hasLength(2));
    final second = c.current!;
    expect(second.id, isNot(first.id));
    expect(c.preparationLabelFor(first.id), 'Em conferência');
    expect(c.preparationLabelFor(second.id), 'Na fila de conferência');
    expect(c.waitingPreparations, 1);
    expect(resolver.calls, [firstTrack]);
    await c.openCollection(first);
    await c.openCollection(second);
    resolver.gate!.complete();
    await finishMatching(c);
    final secondTrack = (await repository.page(second.id)).items.single;
    expect(resolver.calls, [firstTrack, secondTrack.id]);
    expect(c.current?.id, second.id);
    expect(c.preparationLabelFor(second.id), isNull);
    expect(secondTrack.status, TrackStatus.ready);
    expect((await repository.trackById(firstTrack))?.status, TrackStatus.ready);
  });

  test('cancelar a segunda importação mantém a primeira conferência ativa',
      () async {
    resolver.gate = Completer<void>();
    final c = controller([
      const TrackDraft(title: 'Faixa', artist: 'Pessoa', durationMs: 180000)
    ]);
    await c.importPlaylist(fixturePlaylistUrl);
    await resolver.started.future;
    final first = c.current!;
    importer.paused = Completer<void>();
    importer.release = Completer<void>();
    final second = c.importPlaylist(
        'https://open.spotify.com/playlist/1123456789012345678901');
    await importer.paused!.future;
    expect(c.preparing && c.importing, isTrue);

    c.cancelImport();
    importer.release!.complete();
    await second;

    expect(c.preparing, isTrue);
    expect(c.message, 'Importação cancelada.');
    expect(await repository.collections(), hasLength(1));
    resolver.gate!.complete();
    await finishMatching(c);
    expect((await repository.page(first.id)).items.single.status,
        TrackStatus.ready);
  });

  test(
      'importação inicia conferência sem download; vazias, erros e vídeos ficam em revisão',
      () async {
    resolver.gate = Completer<void>();
    final c = controller([
      for (final name in ['Certa', 'Vazia', 'Erro', 'Vídeo'])
        TrackDraft(title: name, artist: 'Pessoa', durationMs: 180000)
    ]);
    await c.importSpotify(fixturePlaylistUrl);
    await resolver.started.future;
    expect(c.preparing, isTrue);
    expect(c.importing, isFalse);
    expect(c.downloading, isFalse);
    await c.searchCollection('Vazia');
    resolver.gate!.complete();
    await finishMatching(c);
    final rows = (await repository.page(c.current!.id)).items;
    expect(resolver.calls.length, 4);
    expect(rows.first.status, TrackStatus.ready);
    expect(
        rows
            .skip(1)
            .every((t) => t.matchStatus == MatchStatus.review && t.needsReview),
        isTrue);
    expect(rows.last.sourceAuthorization, SourceAuthorization.catalog);
    expect(rows.every((t) => !t.selected && t.localPath.isEmpty), isTrue);
    expect(c.page.total, 1);
    expect(c.page.items.single.title, 'Vazia');
    await c.openCollection(c.current!);
    expect(resolver.calls.length, 4);
  });

  test('conferência percorre outras páginas e preserva fontes já definidas',
      () async {
    final c = controller([
      for (var i = 0; i < 45; i++)
        TrackDraft(title: 'Faixa $i', artist: 'Pessoa', durationMs: 180000),
      const TrackDraft(
          title: 'Manual pronta',
          artist: 'Pessoa',
          mediaUrl: 'https://example.org/a.mp3',
          sourceKind: SourceKind.directMp3)
    ]);
    await c.importSpotify(fixturePlaylistUrl);
    await finishMatching(c);
    expect(resolver.calls.length, 45);
    expect((await repository.page(c.current!.id, offset: 40)).items.length, 6);
    final last = (await repository.page(c.current!.id, offset: 40)).items.last;
    expect(last.mediaUrl, 'https://example.org/a.mp3');
    expect(last.sourceKind, SourceKind.directMp3);
    expect(last.position, 46);
    expect((await repository.page(c.current!.id)).items.first.position, 1);
  });

  test(
      'abrir importação pendente inicia conferência e cancelamento não confirma as demais',
      () async {
    final id = await repository.importCollection(ImportedCollection(
        name: 'Pendente',
        source: 'Fixture',
        sourceUrl: '',
        tracks: Stream.fromIterable(List.generate(
            3, (_) => const TrackDraft(title: 'Repetida', artist: 'Pessoa')))));
    resolver.gate = Completer<void>();
    final c = controller([]);
    await c.openCollection((await repository.collectionById(id))!);
    await resolver.started.future;
    expect(c.preparing, isTrue);
    c.cancel();
    resolver.gate!.complete();
    await finishMatching(c);
    expect(
        (await repository.page(id))
            .items
            .every((t) => t.matchStatus == MatchStatus.pending),
        isTrue);
    expect(c.downloading, isFalse);
  });

  test(
      'busca, ordenação e seleção aplicam o mesmo filtro antes de paginar sem reordenar a playlist',
      () async {
    final id = await repository.importCollection(ImportedCollection(
        name: 'Lista',
        source: 'Fixture',
        sourceUrl: '',
        tracks: Stream.fromIterable(List.generate(
            85,
            (i) => TrackDraft(
                title: i.isEven ? 'MÚSICA $i' : 'Outra $i',
                artist: 'Pessoa',
                durationMs: (85 - i) * 1000)))));
    final rows = (await repository.page(id, limit: 100)).items;
    for (var i = 0; i < 85; i += 2) {
      await repository.markForReview(rows[i].id);
    }
    await repository.linkSource(rows[1],
        url: 'https://example.org/x.mp3', kind: SourceKind.directMp3);
    await repository.selectCollection(id, true,
        query: 'musica', filter: 'review');
    var result = await repository.page(id,
        query: 'musica', filter: 'review', offset: 40);
    expect(result.total, 43);
    expect(result.filteredSelectedCount, 43);
    expect(result.items.length, 3);
    result = await repository.page(id, sort: TrackSort.duration);
    expect(result.items.first.position, 85);
    result =
        await repository.page(id, sort: TrackSort.duration, descending: true);
    expect(result.items.first.position, 1);
    expect((await repository.page(id, filter: 'ready')).items.single.id,
        rows[1].id);
    expect(
        (await repository.page(id, sort: TrackSort.correspondence))
            .items
            .first
            .needsReview,
        isTrue);
    expect((await repository.page(id)).items.map((t) => t.position),
        List.generate(40, (i) => i + 1));
    await repository.selectCollection(id, false, filter: 'ready');
    expect((await repository.page(id)).selectedCount, 43);
    expect((await repository.page(id, query: "' OR 1=1 --")).total, 0);
  });
}

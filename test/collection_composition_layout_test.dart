import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:definitive_downloader/app/theme.dart';
import 'package:definitive_downloader/core/network/bounded_http.dart';
import 'package:definitive_downloader/core/platform/desktop_files.dart';
import 'package:definitive_downloader/core/storage/database.dart';
import 'package:definitive_downloader/features/downloads/download_service.dart';
import 'package:definitive_downloader/features/importing/csv_importer.dart';
import 'package:definitive_downloader/features/library/application/library_controller.dart';
import 'package:definitive_downloader/features/library/data/library_repository.dart';
import 'package:definitive_downloader/features/library/presentation/collection_workspace.dart';
import 'package:definitive_downloader/features/matching/deezer_catalog.dart';
import 'package:definitive_downloader/features/player/data/player_library.dart';
import 'package:definitive_downloader/features/organization/presentation/collection_manager.dart';
import 'collection_composition_test.dart'
    show YouTubeFixture, LocalInspectorFixture;
import 'playlist_matching_test.dart' show FixturePlaylist;
import 'widget_io.dart';

class LocalPickerFixture extends DesktopFiles {
  LocalPickerFixture(this.output, this.file);
  final String output, file;
  String? folder;
  final releasedFolders = <String>[];

  @override
  Future<String?> chooseAudioFolder() async => folder;

  @override
  Future<void> releaseAudioFolder(String path) async {
    releasedFolders.add(path);
  }

  @override
  Future<String> defaultOutputDirectory() async => output;
  @override
  Future<List<String>> chooseMp3Files() async => [file];
}

void main() {
  testWidgets('solta uma pasta sobre Minhas coleções e abre a playlist criada',
      (tester) async {
    late Directory temp;
    late LibraryController library;
    late File input;
    await tester.runAsync(() async {
      temp = await Directory.systemTemp.createTemp('dd-folder-layout-');
      final folder = await Directory('${temp.path}/Pasta de ensaio').create();
      input = await File('assets/demo/tone.mp3').copy('${folder.path}/tom.mp3');
      final repo = LibraryRepository(AppDatabase('${temp.path}/library.db'));
      library = LibraryController(
          repository: repo,
          files: LocalPickerFixture('${temp.path}/output', input.path),
          spotify: FixturePlaylist([]),
          csv: const CsvImporter(),
          catalog: const DeezerCatalog(BoundedHttp()),
          downloader: DownloadService(const BoundedHttp(), rootBundle),
          localInspector: LocalInspectorFixture());
      await library.initialize();
    });
    addTearDown(() async {
      library.dispose();
      await temp.delete(recursive: true);
    });
    int? opened;
    await tester.pumpWidget(MaterialApp(
        theme: appTheme(),
        home: Scaffold(
            body: CollectionManager(
                library: library,
                onOpen: (collection) => opened = collection.id))));
    await tester.pumpAndSettle();
    Future<void> drop(String method, Object args) =>
        tester.binding.defaultBinaryMessenger.handlePlatformMessage(
            'desktop_drop',
            const StandardMethodCodec()
                .encodeMethodCall(MethodCall(method, args)),
            (_) {});
    final point = tester.getCenter(find.text('Minhas coleções'));
    await drop('entered', [point.dx, point.dy]);
    await tester.runAsync(() => drop('performOperation', [input.parent.path]));
    await ioUntil(tester, () => opened != null);
    await tester.runAsync(() async {
      final playlist = (await library.repository.collectionById(opened!))!;
      expect(playlist.name, 'Pasta de ensaio');
      expect(playlist.trackCount, 1);
      final track = (await library.repository.page(playlist.id)).items.single;
      expect(await File(track.localPath).exists(), isTrue);
      expect(await input.exists(), isTrue);
      expect(track.localPath, isNot(input.path));
    });
    expect(tester.takeException(), isNull);
  }, variant: const TargetPlatformVariant({TargetPlatform.windows}));

  testWidgets('Importar pasta seleciona áudios aninhados e abre a playlist', (
    tester,
  ) async {
    late Directory temp, folder;
    late LocalPickerFixture files;
    late LibraryController library;
    await tester.runAsync(() async {
      temp = await Directory.systemTemp.createTemp('dd-android-folder-layout-');
      folder = await Directory('${temp.path}/Áudio de viagem').create();
      final inner = await Directory('${folder.path}/B').create();
      final fixture = File('assets/demo/tone.mp3');
      await fixture.copy('${folder.path}/A.mp3');
      await fixture.copy('${inner.path}/B.mp3');
      await File('${inner.path}/ignorar.txt').writeAsString('texto');
      files = LocalPickerFixture('${temp.path}/output', '');
      library = LibraryController(
        repository: LibraryRepository(AppDatabase('${temp.path}/library.db')),
        files: files,
        spotify: FixturePlaylist([]),
        csv: const CsvImporter(),
        catalog: const DeezerCatalog(BoundedHttp()),
        downloader: DownloadService(const BoundedHttp(), rootBundle),
        localInspector: LocalInspectorFixture(),
      );
      await library.initialize();
    });
    addTearDown(() async {
      library.dispose();
      await temp.delete(recursive: true);
    });
    int? opened;
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        home: Scaffold(
          body: CollectionManager(
            library: library,
            onOpen: (collection) => opened = collection.id,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final import = find.byKey(const ValueKey('import-audio-folder'));
    await tester.runAsync(() => tester.tap(import));
    await ioUntil(tester, () => !library.importing);
    expect(opened, isNull);
    expect(library.collections, isEmpty);

    files.folder = folder.path;
    await tester.runAsync(() => tester.tap(import));
    await ioUntil(tester, () => opened != null);
    await tester.runAsync(() async {
      final playlist = (await library.repository.collectionById(opened!))!;
      expect(playlist.name, 'Áudio de viagem');
      final tracks = (await library.repository.page(playlist.id)).items;
      expect(tracks.map((track) => track.position), [1, 2]);
      expect(
        tracks.map((track) => Uri.parse(track.sourceUrl).pathSegments.last),
        ['A.mp3', 'B.mp3'],
      );
      expect(await File(tracks.last.localPath).exists(), isTrue);
      expect(await File('${folder.path}/B/B.mp3').exists(), isTrue);
      expect(files.releasedFolders, [folder.path]);
    });
    expect(tester.takeException(), isNull);
  }, variant: const TargetPlatformVariant({TargetPlatform.android}));

  for (final width in [1360.0, 390.0]) {
    testWidgets(
        'criação por link, MP3 pelo canal de arraste e seletor a ${width.toInt()}px',
        (tester) async {
      tester.view.physicalSize = Size(width, 820);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late Directory temp;
      late LibraryController library;
      late String input;
      await tester.runAsync(() async {
        temp = await Directory.systemTemp.createTemp('dd-compose-layout-');
        input = (await File('assets/demo/tone.mp3')
                .copy('${temp.path}/original.mp3'))
            .path;
        final repo = LibraryRepository(AppDatabase('${temp.path}/library.db'));
        library = LibraryController(
            repository: repo,
            files: LocalPickerFixture('${temp.path}/output', input),
            spotify: FixturePlaylist([]),
            youtubePlaylists: YouTubeFixture(),
            csv: const CsvImporter(),
            catalog: const DeezerCatalog(BoundedHttp()),
            downloader: DownloadService(const BoundedHttp(), rootBundle),
            localInspector: LocalInspectorFixture());
        await library.initialize();
      });
      addTearDown(() async {
        library.dispose();
        await temp.delete(recursive: true);
      });
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
          key: key,
          child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: appTheme(),
              home: Scaffold(
                  body: ListenableBuilder(
                      listenable: library,
                      builder: (context, _) => CollectionWorkspace(
                          controller: library,
                          onConnections: null,
                          onDownloads: () {}))))));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('create-playlist')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('new-playlist-link')), findsOneWidget);
      await tester.enterText(
          find.byKey(const ValueKey('organization-name')), 'Mix pessoal');
      await tester.enterText(find.byKey(const ValueKey('new-playlist-link')),
          'https://www.youtube.com/playlist?list=PL1234567890123456');
      final out = Platform.environment['DD_LAYOUT_OUTPUT'];
      if (out != null) {
        final boundary =
            key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory(out).create(recursive: true);
          await File('$out/create-composed-${width.toInt()}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.tap(find.text('Salvar'));
      await ioUntil(
          tester,
          () =>
              library.current?.trackCount == 2 &&
              find.byType(AlertDialog).evaluate().isEmpty);
      await ioUntil(
          tester,
          () =>
              find.byKey(const ValueKey('track-search')).evaluate().isNotEmpty);
      expect(find.byTooltip('Por que a edição está bloqueada?'), findsNothing);
      Future<void> platform(String method, Object args) async {
        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
            'desktop_drop',
            const StandardMethodCodec()
                .encodeMethodCall(MethodCall(method, args)),
            (_) {});
      }

      final point =
          tester.getCenter(find.byKey(const ValueKey('track-search')));
      await platform('entered', [point.dx, point.dy]);
      await tester.pumpAndSettle();
      expect(find.text('Adicionar MP3 à playlist'), findsOneWidget);
      await tester.runAsync(() => platform('performOperation', [input, input]));
      await ioUntil(tester,
          () => !library.addingLinks && library.current?.trackCount == 4);
      await tester.runAsync(() async {
        final tracks =
            (await library.repository.page(library.current!.id)).items;
        expect(tracks.map((t) => t.position), [1, 2, 3, 4]);
        expect(await File(tracks.last.localPath).exists(), isTrue);
        expect(await File(input).exists(), isTrue);
        expect(
            (await PlayerLibrary(library.repository.database)
                    .collection(library.current!.id))
                .length,
            2);
      });
      final button = find.byTooltip('Adicionar MP3');
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await ioUntil(tester,
          () => !library.addingLinks && library.current?.trackCount == 5);
      expect(tester.takeException(), isNull);
    });
  }
}

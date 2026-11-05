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
import 'collection_composition_test.dart'
    show YouTubeFixture, LocalInspectorFixture;
import 'playlist_matching_test.dart' show FixturePlaylist;
import 'widget_io.dart';

class LocalPickerFixture extends DesktopFiles {
  LocalPickerFixture(this.output, this.file);
  final String output, file;
  @override
  Future<String> defaultOutputDirectory() async => output;
  @override
  Future<List<String>> chooseMp3Files() async => [file];
}

void main() {
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
      await platform('performOperation', [input, input]);
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

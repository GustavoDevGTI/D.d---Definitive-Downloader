import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:definitive_downloader/app/definitive_downloader_app.dart';
import 'package:definitive_downloader/core/network/bounded_http.dart';
import 'package:definitive_downloader/core/platform/desktop_files.dart';
import 'package:definitive_downloader/core/storage/database.dart';
import 'package:definitive_downloader/features/downloads/download_service.dart';
import 'package:definitive_downloader/features/importing/csv_importer.dart';
import 'package:definitive_downloader/features/importing/spotify_importer.dart';
import 'package:definitive_downloader/features/library/application/library_controller.dart';
import 'package:definitive_downloader/features/library/data/library_repository.dart';
import 'package:definitive_downloader/features/matching/deezer_catalog.dart';
import 'package:definitive_downloader/features/connections/application/spotify_connection_controller.dart';
import 'spotify_fixtures.dart';
import 'music_resolver_test.dart' show EmptyEngine, EmptySession;
import 'package:definitive_downloader/features/connections/application/deezer_connection_controller.dart';
import 'package:definitive_downloader/features/matching/music_resolver.dart';
import 'package:definitive_downloader/features/library/domain/models.dart';

void main() {
  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
    final output = Platform.environment['DD_LAYOUT_OUTPUT'];
    if (output == null) return;
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage();
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory(output).create(recursive: true);
        await File('$output/$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
      } finally {
        image.dispose();
      }
    });
  }

  for (final width in [1360.0, 900.0]) {
    testWidgets('lista e ações acessíveis a ${width.toInt()}px',
        (tester) async {
      tester.view.physicalSize = Size(width, 820);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late Directory directory;
      late LibraryController controller;
      final engine = EmptyEngine();
      final deezer = DeezerConnectionController(EmptySession(), engine);
      final captureKey = GlobalKey();
      if (Platform.environment['DD_LAYOUT_OUTPUT'] != null) {
        final fonts = FontLoader('Manrope')
          ..addFont(rootBundle.load('assets/fonts/Manrope.ttf'));
        await fonts.load();
        final icons = FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
        await icons.load();
      }
      await tester.runAsync(() async {
        directory = await Directory.systemTemp.createTemp('dd-layout-');
        final repository =
            LibraryRepository(AppDatabase('${directory.path}/test.db'));
        await repository.database.initialize();
        controller = LibraryController(
            repository: repository,
            files: DesktopFiles(),
            spotify: const SpotifyImporter(BoundedHttp()),
            csv: const CsvImporter(),
            catalog: const DeezerCatalog(BoundedHttp()),
            music: MusicResolver(engine, deezer),
            downloader: DownloadService(const BoundedHttp(), rootBundle));
        controller.outputDirectory = directory.path;
        await controller.loadExample();
        // Visual metadata fixtures only; no provider is contacted or downloaded.
        final rows = (await repository.page(controller.current!.id)).items;
        await repository.linkSource(rows[0],
            url: 'https://www.deezer.com/track/123',
            kind: SourceKind.deezerFull);
        await repository.linkSource(rows[1],
            url: 'https://music.youtube.com/watch?v=abcdefghijk',
            kind: SourceKind.youtubeMusic);
        await controller.refresh();
      });
      final connections = SpotifyConnectionController(
          store: MemorySpotifyStore(),
          authorization: FakeSpotifyFlow(),
          transport: FixtureSpotifyTransport(
              (uri, method, headers, form) async => {}));
      await tester.pumpWidget(RepaintBoundary(
          key: captureKey,
          child: DefinitiveDownloaderApp(
              controller: controller, connections: connections)));
      await tester.pumpAndSettle();
      expect(find.text('Baixar selecionadas'), findsOneWidget);
      expect(find.text('Origem do áudio'), findsOneWidget);
      expect(find.text('Deezer'), findsOneWidget);
      expect(find.text('YouTube Music'), findsOneWidget);
      expect(find.textContaining('Exemplo local'), findsWidgets);
      expect(tester.takeException(), isNull);
      await capture(tester, captureKey, 'music-library-${width.toInt()}');
      await tester.tap(find.text('Conexões'));
      await tester.pumpAndSettle();
      expect(find.text('Conectar Spotify'), findsOneWidget);
      expect(find.text('Sessão Deezer (ARL)'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capture(tester, captureKey, 'music-connections-${width.toInt()}');
      await tester.tap(find.text('Fechar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abertura'));
      await tester.pumpAndSettle();
      expect(find.text('Conferência'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      connections.dispose();
      deezer.dispose();
      await tester.runAsync(() => directory.delete(recursive: true));
    });
  }
}

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
import 'package:definitive_downloader/features/library/presentation/sidebar.dart';
import 'package:definitive_downloader/features/workspace/presentation/download_workspace.dart';
import 'package:definitive_downloader/features/workspace/presentation/capture_workspace.dart';
import 'package:definitive_downloader/features/workspace/presentation/home_workspace.dart';

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

  for (final size in [
    const Size(1920, 1080),
    const Size(1360, 820),
    const Size(900, 820),
    const Size(900, 600),
    const Size(390, 820),
    const Size(320, 820)
  ]) {
    final width = size.width;
    testWidgets(
        'lista e ações acessíveis a ${width.toInt()}x${size.height.toInt()}px',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      if (width == 320) {
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      }
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
        controller.clearMessage();
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
      final home = tester.widget<HomeWorkspace>(find.byType(HomeWorkspace));
      await tester.runAsync(home.controller.refresh);
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('Visão geral'), findsOneWidget);
      expect(find.text('Meus arquivos'), findsOneWidget);
      final surface =
          tester.getRect(find.byKey(const ValueKey('app-edge-to-edge')));
      expect(surface.left, 0);
      expect(surface.right, width);
      expect(tester.takeException(), isNull);
      await capture(tester, captureKey, 'home-${width.toInt()}');
      final nav = width < 780
          ? find.byType(MobileNavigation)
          : find.byType(LibrarySidebar);
      await tester
          .tap(find.descendant(of: nav, matching: find.text('Músicas')));
      await tester.pumpAndSettle();
      expect(find.text('Minhas coleções'), findsOneWidget);
      await capture(tester, captureKey, 'collections-${width.toInt()}');
      await tester.tap(find.widgetWithText(OutlinedButton, 'Conexões'));
      await tester.pumpAndSettle();
      expect(find.text('Conectar Spotify'), findsOneWidget);
      expect(find.text('Sessão Deezer (ARL)'), findsOneWidget);
      await capture(tester, captureKey, 'music-connections-${width.toInt()}');
      await tester.tap(find.text('Fechar'));
      await tester.pumpAndSettle();
      await tester.runAsync(
          () => tester.tap(find.textContaining('Exemplo local').first));
      await tester.runAsync(() => controller.refresh());
      await tester.pumpAndSettle();
      expect(find.text('Baixar selecionadas'), findsOneWidget);
      expect(find.text('Faixa / artista'), findsOneWidget);
      if (width >= 1360) {
        expect(find.text('Deezer'), findsOneWidget);
        expect(find.text('YouTube Music'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await capture(tester, captureKey, 'music-library-${width.toInt()}');
      await tester.ensureVisible(find.text('Abertura'));
      await tester.tap(find.text('Abertura'));
      await tester.pumpAndSettle();
      expect(find.text('Conferência'), findsOneWidget);
      expect(controller.page.selectedCount, 0);
      await capture(tester, captureKey, 'verification-${width.toInt()}');
      await tester.ensureVisible(find.text('Informar link manualmente'));
      await tester
          .runAsync(() => tester.tap(find.text('Informar link manualmente')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byType(TextFormField), 'https://example.org/manual.mp3');
      await tester.runAsync(() => tester.tap(find.text('Aplicar link')));
      await tester.runAsync(() async {
        final deadline = DateTime.now().add(const Duration(seconds: 5));
        while (controller.focused?.hasManualSource != true &&
            DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pumpAndSettle();
      expect(controller.focused!.hasManualSource, isTrue,
          reason: controller.message);
      expect(controller.page.selectedCount, 0);
      if (width < 1360) {
        await tester.tap(find.byTooltip('Fechar conferência'));
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(find.byTooltip('Abrir downloads musicais'));
      await tester.pumpAndSettle();
      await tester.runAsync(
          () => tester.tap(find.byTooltip('Abrir downloads musicais')));
      await tester.pump();
      final downloadsWidget =
          tester.widget<DownloadWorkspace>(find.byType(DownloadWorkspace));
      await tester.runAsync(() => downloadsWidget.controller.refresh());
      await tester.pump();
      await tester.pumpAndSettle();
      // SQLite isolates are outside the fake frame clock used by pumpAndSettle.
      // Wait for the rendered list to consume the already persisted source.
      for (var frame = 0;
          frame < 10 && find.textContaining('MP3 vinculado').evaluate().isEmpty;
          frame++) {
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await capture(tester, captureKey, 'music-downloads-${width.toInt()}');
      expect(find.textContaining('MP3 vinculado'), findsOneWidget,
          reason:
              '${downloadsWidget.controller.category}: ${downloadsWidget.controller.downloads.items.map((e) => e.track.sourceLabel).join(', ')}');
      expect(find.byTooltip('Pausar fila'), findsOneWidget);
      final tools = find.descendant(
          of: find.byType(DownloadToolbar), matching: find.byType(IconButton));
      expect(tools, findsNWidgets(8));
      final toolY = tester.getRect(tools.first).center.dy;
      for (var index = 1; index < 8; index++) {
        expect(tester.getRect(tools.at(index)).center.dy, toolY);
      }
      await tester.ensureVisible(find.byTooltip('Remover da fila'));
      await tester.pumpAndSettle();
      await capture(tester, captureKey, 'music-tools-end-${width.toInt()}');
      await tester.ensureVisible(find.byTooltip('Iniciar selecionados'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await capture(tester, captureKey, 'music-downloads-${width.toInt()}');
      await tester.ensureVisible(find.text('Capturar novo link'));
      await tester.tap(find.text('Capturar novo link'));
      await tester.pumpAndSettle();
      expect(find.text('Capturador de áudio'), findsOneWidget);
      await capture(tester, captureKey, 'audio-capture-${width.toInt()}');
      await tester.tap(find.descendant(
          of: nav,
          matching: find.text(width < 780 ? 'Mídias' : 'Vídeos e Fotos')));
      await tester.pumpAndSettle();
      expect(find.text('Capturar mídias'), findsOneWidget);
      await capture(tester, captureKey, 'media-capture-${width.toInt()}');
      final input =
          tester.getRect(find.byKey(const ValueKey('capture-url-media')));
      final analyze =
          tester.getRect(find.byKey(const ValueKey('capture-analyze-media')));
      expect(input.overlaps(analyze), isFalse);
      expect(analyze.top, greaterThan(input.bottom + 6));
      await tester.scrollUntilVisible(
          find.textContaining('A captura de páginas, escolha'), 100,
          scrollable: find
              .descendant(
                  of: find.byType(CaptureWorkspace),
                  matching: find.byType(Scrollable))
              .first);
      expect(
          find.textContaining('A captura de páginas, escolha'), findsOneWidget);
      await tester.tap(find.text('Downloads'));
      await tester.pumpAndSettle();
      expect(find.text('Fila de vídeos e fotos'), findsOneWidget);
      await capture(tester, captureKey, 'media-downloads-${width.toInt()}');
      await tester
          .tap(find.descendant(of: nav, matching: find.text('Arquivos')));
      // History-only fixtures. These references do not represent provider downloads.
      await tester.runAsync(() async {
        final rows =
            (await controller.repository.page(controller.current!.id)).items;
        await controller.repository.setStatus(rows[4].id, TrackStatus.completed,
            localPath: '${directory.path}/Playlist Teste/faixa.mp3');
        await controller.repository.setStatus(rows[5].id, TrackStatus.completed,
            localPath: '${directory.path}/Arquivos locais/outra.mp3');
        await downloadsWidget.controller.refresh();
      });
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('Histórico dos downloads organizado por pastas'),
          findsOneWidget);
      await capture(tester, captureKey, 'history-${width.toInt()}');
      await tester.tap(find.descendant(
          of: nav,
          matching: find.text(width < 780 ? 'Ajustes' : 'Configurações')));
      await tester.pumpAndSettle();
      expect(find.text('Qualidade preferencial'), findsOneWidget);
      await capture(tester, captureKey, 'settings-${width.toInt()}');
      await tester.ensureVisible(find.text('Formatos e conversão'));
      await tester.tap(find.text('Formatos e conversão'));
      await tester.pumpAndSettle();
      expect(find.textContaining('O fluxo musical atual salva MP3'),
          findsOneWidget);
      await tester.tap(find.text('Fechar'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      connections.dispose();
      deezer.dispose();
      await tester.runAsync(() => directory.delete(recursive: true));
    });
  }
}

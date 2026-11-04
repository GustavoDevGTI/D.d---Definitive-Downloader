import 'widget_io.dart';
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
import 'package:definitive_downloader/features/importing/spotify_importer.dart';
import 'package:definitive_downloader/features/library/application/library_controller.dart';
import 'package:definitive_downloader/features/library/data/library_repository.dart';
import 'package:definitive_downloader/features/library/domain/models.dart';
import 'package:definitive_downloader/features/matching/deezer_catalog.dart';
import 'package:definitive_downloader/features/organization/data/collection_organization_repository.dart';
import 'package:definitive_downloader/features/organization/presentation/collection_manager.dart';

void main() {
  for (final width in [1360.0, 390.0, 320.0]) {
    testWidgets(
        'gestão local cria, renomeia, busca e agrupa a ${width.toInt()}px',
        (tester) async {
      tester.view.physicalSize = Size(width, 820);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      if (width == 320) {
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      }
      final output = Platform.environment['DD_LAYOUT_OUTPUT'];
      if (output != null) {
        await (FontLoader('Manrope')
              ..addFont(rootBundle.load('assets/fonts/Manrope.ttf')))
            .load();
        await (FontLoader('MaterialIcons')
              ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
            .load();
      }
      late Directory temp;
      late LibraryController library;
      late CollectionOrganizationRepository repository;
      late int originalId;
      await tester.runAsync(() async {
        temp = await Directory.systemTemp.createTemp('dd-manager-ui-');
        final db = AppDatabase('${temp.path}/test.db');
        await db.initialize();
        repository = CollectionOrganizationRepository(db);
        originalId = await repository.create('Para ouvir no caminho');
        library = LibraryController(
            repository: LibraryRepository(db),
            files: DesktopFiles(),
            spotify: const SpotifyImporter(BoundedHttp()),
            csv: const CsvImporter(),
            catalog: const DeezerCatalog(BoundedHttp()),
            downloader: DownloadService(const BoundedHttp(), rootBundle));
        await library.repository.setPreference('output_directory', temp.path);
        await library.initialize();
      });
      Collection? opened;
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
          key: key,
          child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: appTheme(),
              home: Scaffold(
                  body: SafeArea(
                      child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: CollectionManager(
                              library: library,
                              onOpen: (c) => opened = c)))))));
      await ioUntil(
          tester,
          () => find
              .byKey(ValueKey('collection-open-$originalId'))
              .evaluate()
              .isNotEmpty);
      await tester.tap(find.byTooltip('Gerenciar grupos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Novo grupo'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('organization-name')), 'Viagens');
      await tester.tap(find.text('Salvar'));
      await ioUntil(tester, () => find.byType(AlertDialog).evaluate().isEmpty);
      await tester.tap(find.byKey(ValueKey('collection-actions-$originalId')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mover para grupo'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(DropdownButtonFormField<int>)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Viagens').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar'));
      await ioUntil(tester, () => find.byType(AlertDialog).evaluate().isEmpty);
      await tester.tap(find.byKey(ValueKey('collection-actions-$originalId')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Renomear playlist'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('organization-name')),
          'Estrada e companhia');
      await tester.tap(find.text('Salvar'));
      await ioUntil(
          tester,
          () =>
              find.text('Estrada e companhia').evaluate().isNotEmpty &&
              find.byType(AlertDialog).evaluate().isEmpty);
      await tester.enterText(
          find.byKey(const ValueKey('search-playlists')), 'Não existe');
      await tester.pump(const Duration(milliseconds: 350));
      await ioUntil(
          tester,
          () =>
              find.text('Nenhuma playlist encontrada.').evaluate().isNotEmpty);
      await tester.tap(find.byTooltip('Limpar busca'));
      await ioUntil(
          tester, () => find.text('Estrada e companhia').evaluate().isNotEmpty);
      await tester.tap(find.byKey(const ValueKey('create-playlist')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Use um nome'), findsOneWidget);
      await tester.enterText(
          find.byKey(const ValueKey('organization-name')), 'Uma seleção nova');
      await tester.tap(find.text('Salvar'));
      await ioUntil(tester, () => opened != null);
      expect(opened!.trackCount, 0);
      expect(opened!.source, 'Local');
      expect(tester.takeException(), isNull);
      if (output != null) {
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject() as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory(output).create(recursive: true);
          await File('$output/organization-${width.toInt()}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.runAsync(() async {
        final owner = (await library.repository.collectionById(originalId))!;
        expect(owner.name, 'Estrada e companhia');
        expect(owner.outputFolderName, 'Para ouvir no caminho');
        expect(owner.groupId, (await repository.groups()).single.id);
      });
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Viagens (1)').last);
      await tester.pumpAndSettle();
      await ioUntil(
          tester, () => find.text('Uma seleção nova').evaluate().isEmpty);
      await tester.tap(find.byTooltip('Gerenciar grupos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Renomear grupo'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('organization-name')), 'Viagens favoritas');
      await tester.tap(find.text('Salvar'));
      await ioUntil(
          tester,
          () =>
              find.byType(AlertDialog).evaluate().isEmpty &&
              find.text('Viagens favoritas (1)').evaluate().isNotEmpty);
      await tester.tap(find.byTooltip('Gerenciar grupos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remover grupo'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Remover grupo'));
      await ioUntil(
          tester, () => find.text('Uma seleção nova').evaluate().isNotEmpty);
      await tester.runAsync(() async {
        expect(await repository.groups(), isEmpty);
        expect((await repository.list(groupId: 0)).total, 2);
      });
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      library.dispose();
      await tester.runAsync(() => temp.delete(recursive: true));
    });
  }
}

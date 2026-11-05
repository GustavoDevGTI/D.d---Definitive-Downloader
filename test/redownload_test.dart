import 'dart:io';
import 'package:flutter/material.dart';
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
import 'package:definitive_downloader/features/library/presentation/library_screen.dart';
import 'package:definitive_downloader/features/library/presentation/track_inspector.dart';
import 'package:definitive_downloader/features/matching/deezer_catalog.dart';
import 'package:definitive_downloader/features/workspace/data/workspace_repository.dart';
import 'package:definitive_downloader/features/workspace/presentation/workspace_components.dart';
import 'download_table_layout_test.dart' show capture;
import 'widget_io.dart';
import 'schema_fixtures.dart';

class CountedDownload extends DownloadService {
  CountedDownload() : super(const BoundedHttp(), rootBundle);
  int calls = 0;
  @override
  Future<String> save(Track track, String directory, DownloadCancellation token,
      void Function(double?) progress,
      {void Function(TransferProgress)? onTransfer}) {
    calls++;
    return super
        .save(track, directory, token, progress, onTransfer: onTransfer);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  late LibraryRepository repo;
  late LibraryController c;
  late CountedDownload downloads;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('dd-redownload-');
    repo = LibraryRepository(AppDatabase('${temp.path}/library.db'));
    await repo.database.initialize();
    downloads = CountedDownload();
    c = LibraryController(
        repository: repo,
        files: DesktopFiles(),
        spotify: const SpotifyImporter(BoundedHttp()),
        csv: const CsvImporter(),
        catalog: const DeezerCatalog(BoundedHttp()),
        downloader: downloads);
    c.outputDirectory = temp.path;
    await c.loadExample();
  });
  tearDown(() async {
    c.dispose();
    await temp.delete(recursive: true);
  });
  Future<Track> completeFirst() async {
    final id = c.page.items.first.id;
    await c.downloadSelected(queueIds: [id]);
    return (await repo.trackById(id))!;
  }

  test('arquivo apagado exige escolha persistente e outro clique para baixar',
      () async {
    final saved = await completeFirst();
    final original = await File(saved.localPath).readAsBytes();
    await repo.database.run((db) => db.execute(
        "UPDATE download_history SET created_at='2000-01-01 00:00:00'"));
    await File(saved.localPath).delete();
    await c.downloadSelected(queueIds: [saved.id]);
    expect(downloads.calls, 1);
    expect(c.focused!.redownloadReview, isTrue);
    expect(c.focused!.canDownload, isFalse);
    expect(c.focused!.orderLocked, isTrue);
    expect(c.inspectorRequest, 1);
    await c.downloadSelected(queueIds: [saved.id]);
    expect(downloads.calls, 1);
    await repo.database.initialize();
    final restored = (await repo.trackById(saved.id))!;
    expect(restored.redownloadReview, isTrue);
    final queue = WorkspaceRepository(repo.database);
    await queue.beginRun(run: 'no-auto', ids: [saved.id]);
    expect(await queue.claimNext(run: 'no-auto', snapshot: true), isNull);
    c.focus(restored);
    await c.confirmSource();
    expect(c.focused!.redownloadState, 'approved');
    expect(downloads.calls, 1);
    expect(c.downloading, isFalse);
    await c.downloadSelected(queueIds: [saved.id]);
    expect(downloads.calls, 2);
    final again = (await repo.trackById(saved.id))!;
    expect(again.status, TrackStatus.completed);
    expect(again.redownloadState, '');
    expect(again.position, saved.position);
    expect(await File(again.localPath).readAsBytes(), original);
    final history = await repo.database.run((db) => db
        .select('SELECT created_at FROM download_history')
        .map((r) => r['created_at'])
        .toList());
    expect(history.length, 1);
    expect(history.single, isNot('2000-01-01 00:00:00'));
  });
  test('arquivo presente não é baixado outra vez nem muda de fonte', () async {
    final saved = await completeFirst();
    await c.downloadSelected(queueIds: [saved.id]);
    expect(downloads.calls, 1);
    expect(c.focused!.status, TrackStatus.completed);
    expect(c.focused!.redownloadState, '');
  });
  test(
      'seleção mista não começa outros itens enquanto a reposição exige revisão',
      () async {
    final saved = await completeFirst();
    final next = c.page.items[1];
    await File(saved.localPath).delete();
    await c.downloadSelected(queueIds: [saved.id, next.id]);
    expect(downloads.calls, 1);
    expect((await repo.trackById(next.id))!.status, TrackStatus.ready);
  });
  test(
      'busca automática não autoriza reposição; escolha explícita fixa a nova fonte',
      () async {
    final saved = await completeFirst();
    await File(saved.localPath).delete();
    await c.downloadSelected(queueIds: [saved.id]);
    final source = Candidate(
        title: saved.title,
        artist: saved.artist,
        album: saved.album,
        durationMs: 4000,
        pageUrl: 'https://www.deezer.com/track/123',
        previewUrl: '',
        coverUrl: '',
        kind: SourceKind.deezerFull,
        recordingType: 'DEEZER_TRACK');
    await expectLater(
        repo.chooseMusicSource(c.focused!, source), throwsFormatException);
    expect((await repo.trackById(saved.id))!.redownloadReview, isTrue);
    await repo.chooseMusicSource(c.focused!, source, userSelected: true);
    final chosen = (await repo.trackById(saved.id))!;
    expect(chosen.redownloadState, 'approved');
    expect(chosen.manualUrl, source.pageUrl);
    await expectLater(repo.chooseMusicSource(chosen, source, forFallback: true),
        throwsFormatException);
    expect(downloads.calls, 1);
  });
  test('migração v10 mantém concluída e arquivo, sem criar pedido automático',
      () async {
    final saved = await completeFirst();
    final bytes = await File(saved.localPath).readAsBytes();
    await repo.database.run((db) {
      removeContinuousSchema(db);
      db.execute('ALTER TABLE tracks DROP COLUMN redownload_state');
      db.execute('ALTER TABLE collections DROP COLUMN cover_path');
      db.execute('PRAGMA user_version=10');
    });
    await repo.database.initialize();
    final restored = (await repo.trackById(saved.id))!;
    expect(restored.status, TrackStatus.completed);
    expect(restored.redownloadState, '');
    expect(await File(restored.localPath).readAsBytes(), bytes);
    expect(
        await repo.database
            .run((db) => db.select('PRAGMA user_version').first.values.first),
        16);
  });
  test('link manual aprova a reposição sem iniciar e persiste após reinício',
      () async {
    final saved = await completeFirst();
    await File(saved.localPath).delete();
    await c.downloadSelected(queueIds: [saved.id]);
    await repo.setManualSource(saved.id, 'https://example.org/escolhida.mp3',
        ManualSourceMode.originalAudio);
    await repo.database.initialize();
    final chosen = (await repo.trackById(saved.id))!;
    expect(chosen.redownloadState, 'approved');
    expect(chosen.manualUrl, 'https://example.org/escolhida.mp3');
    expect(chosen.canDownload, isTrue);
    expect(chosen.orderLocked, isTrue);
    expect(downloads.calls, 1);
  });
  test('arquivo que reaparece bloqueia nova transferência e permanece intacto',
      () async {
    final saved = await completeFirst();
    final bytes = await File(saved.localPath).readAsBytes();
    await File(saved.localPath).delete();
    await c.downloadSelected(queueIds: [saved.id]);
    await c.confirmSource();
    await File(saved.localPath).writeAsBytes(bytes);
    await c.downloadSelected(queueIds: [saved.id]);
    expect(downloads.calls, 1);
    expect(c.message, contains('disponível novamente'));
    expect(await File(saved.localPath).readAsBytes(), bytes);
  });

  for (final width in [1360.0, 390.0]) {
    testWidgets(
        'concluída abre Informações; reposição abre escolha sem download a $width px',
        (tester) async {
      tester.view.physicalSize = Size(width, 820);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      if (Platform.environment['DD_LAYOUT_OUTPUT'] != null) {
        await (FontLoader('Manrope')
              ..addFont(rootBundle.load('assets/fonts/Manrope.ttf')))
            .load();
        await (FontLoader('MaterialIcons')
              ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
            .load();
      }
      late Track saved;
      await tester.runAsync(() async {
        saved = await completeFirst();
        c.focus(saved);
      });
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
          key: key,
          child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: appTheme(),
              home: Scaffold(body: TrackInspector(controller: c)))));
      await tester.pumpAndSettle();
      expect(
          tester.widget<CategoryTabs>(find.byType(CategoryTabs)).selected, 1);
      expect(find.text('Álbum original'), findsOneWidget);
      await capture(tester, key, 'completed-info-${width.toInt()}');
      await tester.pumpWidget(RepaintBoundary(
          key: key,
          child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: appTheme(),
              home: LibraryScreen(controller: c))));
      await tester.runAsync(() async {
        await File(saved.localPath).delete();
        await c.downloadSelected(queueIds: [saved.id]);
      });
      await ioUntil(tester,
          () => find.byTooltip('Usar fonte anterior').evaluate().isNotEmpty);
      await tester.pumpAndSettle();
      final tabs = find.descendant(
          of: find.byType(TrackInspector), matching: find.byType(CategoryTabs));
      expect(tester.widget<CategoryTabs>(tabs).selected, 0);
      expect(downloads.calls, 1);
      await capture(tester, key, 'redownload-review-${width.toInt()}');
      await tester.ensureVisible(find.byTooltip('Usar fonte anterior'));
      await tester.tap(find.byTooltip('Usar fonte anterior'));
      await ioUntil(tester, () => c.focused?.redownloadState == 'approved');
      expect(downloads.calls, 1);
      expect(c.downloading, isFalse);
      await tester.pumpWidget(const SizedBox());
    });
  }
}

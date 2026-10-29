import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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
import 'package:definitive_downloader/features/workspace/data/workspace_repository.dart';
import 'package:definitive_downloader/features/workspace/application/workspace_controller.dart';

class HeldDownload extends DownloadService {
  HeldDownload({this.cleanupFails = false})
      : super(const BoundedHttp(), rootBundle);
  final bool cleanupFails;
  final started = Completer<void>();
  final release = Completer<void>();
  @override
  Future<String> save(Track track, String directory, DownloadCancellation token,
      void Function(double?) progress) async {
    started.complete();
    await release.future;
    if (cleanupFails) throw const FileSystemException('Deletion failed');
    token.check();
    throw StateError('Teste deveria cancelar.');
  }
}

class GatedDownload extends DownloadService {
  GatedDownload() : super(const BoundedHttp(), rootBundle);
  final started = Completer<void>();
  final release = Completer<void>();
  final ids = <int>[];
  @override
  Future<String> save(Track track, String directory, DownloadCancellation token,
      void Function(double?) progress) async {
    ids.add(track.id);
    if (ids.length == 1) {
      started.complete();
      await release.future;
    }
    return super.save(track, directory, token, progress);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late LibraryRepository repository;
  late LibraryController controller;
  LibraryController create(DownloadService downloader) => LibraryController(
      repository: repository,
      files: DesktopFiles(),
      spotify: const SpotifyImporter(BoundedHttp()),
      csv: const CsvImporter(),
      catalog: const DeezerCatalog(BoundedHttp()),
      downloader: downloader);
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('dd-queue-controller-');
    repository = LibraryRepository(AppDatabase('${directory.path}/test.db'));
    await repository.database.initialize();
    controller = create(DownloadService(const BoundedHttp(), rootBundle));
    controller.outputDirectory = directory.path;
  });
  tearDown(() async {
    controller.dispose();
    await directory.delete(recursive: true);
  });
  test(
      'fila inicia seleção de coleções diferentes com arquivos locais e M3U8 em ordem',
      () async {
    await controller.loadExample();
    final first = controller.page.items;
    await controller.loadExample();
    final second = controller.page.items;
    final currentId = controller.current!.id;
    await controller
        .downloadSelected(queueIds: [second[1].id, first[2].id, first[0].id]);
    expect(controller.current!.id, currentId);
    expect(controller.downloading, isFalse);
    expect(controller.activeTrackId, isNull);
    expect((await WorkspaceRepository(repository.database).summary()).completed,
        3);
    for (final id in [first[0].id, first[2].id, second[1].id]) {
      final saved = (await repository.trackById(id))!;
      expect(saved.status, TrackStatus.completed);
      expect(await File(saved.localPath).exists(), isTrue);
      expect(saved.selected, isFalse);
      final bytes = await File(saved.localPath).readAsBytes();
      expect(String.fromCharCodes(bytes.take(3)), 'ID3');
    }
    expect(
        (await repository.trackById(first[1].id))!.status, TrackStatus.ready);
    final playlists = await directory
        .list(recursive: true)
        .where((e) => e.path.endsWith('.m3u8'))
        .toList();
    expect(playlists.length, 2);
    final list = await File(playlists.first.path).readAsString();
    expect(list, contains('#EXTM3U'));
  });
  test(
      'cancelamento da fila preserva registros e deixa item pronto para nova tentativa',
      () async {
    controller.dispose();
    final downloader = HeldDownload();
    controller = create(downloader);
    controller.outputDirectory = directory.path;
    await controller.loadExample();
    final track = controller.page.items.first;
    final running = controller.downloadSelected(queueIds: [track.id]);
    await downloader.started.future;
    expect(controller.activeTrackId, track.id);
    controller.cancel();
    downloader.release.complete();
    await running;
    expect((await repository.trackById(track.id))!.status, TrackStatus.ready);
    expect((await repository.page(track.collectionId)).total, 6);
    expect((await WorkspaceRepository(repository.database).summary()).completed,
        0);
  });
  test('erro de limpeza após parar não vira falha do provedor', () async {
    controller.dispose();
    final downloader = HeldDownload(cleanupFails: true);
    controller = create(downloader);
    controller.outputDirectory = directory.path;
    await controller.loadExample();
    final track = controller.page.items.first;
    await repository.linkSource(track,
        url: 'https://www.deezer.com/track/123', kind: SourceKind.deezerFull);
    final running = controller.downloadSelected(queueIds: [track.id]);
    await downloader.started.future;
    controller.cancel();
    downloader.release.complete();
    await running;
    final restored = (await repository.trackById(track.id))!;
    expect(restored.status, TrackStatus.ready);
    expect(restored.sourceKind, SourceKind.deezerFull);
    expect(
        await repository.database.run((db) => db
            .select('SELECT COUNT(*) AS n FROM music_source_attempts')
            .first['n']),
        0);
  });

  test(
      'remover última página retorna à página disponível e erros de pasta aparecem',
      () async {
    final id = await repository.importCollection(ImportedCollection(
        name: 'Fila paginada',
        source: 'Fixture',
        sourceUrl: '',
        tracks: Stream.fromIterable(List.generate(
            45,
            (_) => const TrackDraft(
                title: 'Repetida',
                artist: 'Pessoa',
                sourceKind: SourceKind.localExample,
                mediaUrl: 'asset:assets/demo/tone.mp3')))));
    final workspace = WorkspaceController(controller);
    try {
      await workspace.refresh();
      await workspace.turnDownloads(1);
      expect(workspace.downloads.items.length, 5);
      workspace.selectPage(true);
      await workspace.removeDownloads();
      expect(workspace.downloadOffset, 0);
      expect(workspace.downloads.items.length, 40);
      expect((await repository.page(id)).total, 45);
      await workspace.reveal('${directory.path}/missing/file.mp3');
      expect(workspace.message, contains('não está disponível'));
    } finally {
      workspace.dispose();
    }
  });

  test('arquivo excluído externamente fica indisponível sem perder histórico',
      () async {
    await controller.loadExample();
    final t = controller.page.items.first;
    final file = await File('${directory.path}/history-fixture.mp3')
        .writeAsString('fixture de histórico');
    await repository.setStatus(t.id, TrackStatus.completed,
        localPath: file.path);
    final workspace = WorkspaceController(controller);
    try {
      await workspace.openFolder(directory.path);
      expect(workspace.availability[file.path], isTrue);
      await file.delete();
      await workspace.refresh();
      expect(workspace.availability[file.path], isFalse);
      expect(workspace.history.total, 1);
      expect(workspace.summary.completed, 1);
      expect((await repository.trackById(t.id))!.localPath, file.path);
    } finally {
      workspace.dispose();
    }
  });

  test('pausa conclui somente o item ativo e mantém o restante para iniciar',
      () async {
    controller.dispose();
    final downloader = GatedDownload();
    controller = create(downloader);
    controller.outputDirectory = directory.path;
    await controller.loadExample();
    final rows = controller.page.items;
    final running =
        controller.downloadSelected(queueIds: [rows[0].id, rows[1].id]);
    await downloader.started.future;
    controller.togglePause();
    expect(controller.pauseMode, isTrue);
    downloader.release.complete();
    await running;
    expect(downloader.ids, [rows[0].id]);
    expect((await repository.trackById(rows[0].id))!.status,
        TrackStatus.completed);
    expect((await repository.trackById(rows[1].id))!.status, TrackStatus.ready);
    expect(controller.pauseMode, isFalse);
  });

  test('prioridade alterada em execução muda próxima faixa sem mudar M3U8',
      () async {
    controller.dispose();
    final downloader = GatedDownload();
    controller = create(downloader);
    controller.outputDirectory = directory.path;
    await controller.loadExample();
    final rows = controller.page.items.take(3).toList();
    final running =
        controller.downloadSelected(queueIds: rows.map((t) => t.id).toList());
    await downloader.started.future;
    await WorkspaceRepository(repository.database)
        .changePriority([rows[2].id], 1);
    downloader.release.complete();
    await running;
    expect(downloader.ids, [rows[0].id, rows[2].id, rows[1].id]);
    final playlist = await directory
        .list(recursive: true)
        .where((f) => f.path.endsWith('.m3u8'))
        .single;
    final entries = (await File(playlist.path).readAsLines())
        .where((s) => s.isNotEmpty && !s.startsWith('#'))
        .toList();
    expect(entries.map((s) => s.substring(0, 3)), ['001', '002', '003']);
  });
}

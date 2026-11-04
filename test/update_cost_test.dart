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
import 'package:definitive_downloader/features/matching/music_engine.dart';
import 'package:definitive_downloader/features/player/application/music_player_controller.dart';
import 'package:definitive_downloader/features/player/domain/playback.dart';
import 'package:definitive_downloader/features/workspace/application/workspace_controller.dart';
import 'package:definitive_downloader/features/workspace/data/workspace_repository.dart';
import 'package:definitive_downloader/features/workspace/domain/download_columns.dart';
import 'package:definitive_downloader/features/workspace/domain/workspace_models.dart';
import 'player_fixtures.dart';

class ProbeFiles extends DesktopFiles {
  int probes = 0;
  @override
  Future<bool> fileExists(String path) async {
    probes++;
    return true;
  }
}

class PulseLibrary extends LibraryController {
  PulseLibrary(ProbeFiles files)
      : super(
            repository: const LibraryRepository(AppDatabase('unused')),
            files: files,
            spotify: const SpotifyImporter(BoundedHttp()),
            csv: const CsvImporter(),
            catalog: const DeezerCatalog(BoundedHttp()),
            downloader: DownloadService(const BoundedHttp(), rootBundle));
  void pulse({bool data = false}) {
    if (data) dataRevision++;
    notifyListeners();
  }
}

class ProbeWorkspace extends WorkspaceRepository {
  ProbeWorkspace() : super(const AppDatabase('unused'));
  int reads = 0;
  @override
  Future<ActivitySummary> summary() async {
    reads++;
    return const ActivitySummary();
  }

  @override
  Future<DownloadPage> downloads(ContentCategory category,
      {DownloadFilter filter = DownloadFilter.all,
      int offset = 0,
      String query = '',
      bool pauseMode = false,
      DownloadSort? sort,
      bool descending = false,
      String outputDirectory = ''}) async {
    reads++;
    return const DownloadPage([], 0);
  }

  @override
  Future<HistoryPage> history(
      {String folder = '', String query = '', int offset = 0}) async {
    reads++;
    return const HistoryPage([], [
      HistoryEntry(
          id: 1,
          name: 'Fixture',
          path: '/fixture.mp3',
          folder: '/',
          source: 'Fixture')
    ], 1);
  }

  @override
  Future<List<double>> columnWidths() async {
    reads++;
    return downloadColumns.map((c) => c.width).toList();
  }
}

class BurstDownload extends DownloadService {
  BurstDownload() : super(const BoundedHttp(), rootBundle);
  @override
  Future<String> save(Track track, String directory, DownloadCancellation token,
      void Function(double?) progress,
      {void Function(TransferProgress)? onTransfer}) async {
    for (var i = 0; i < 100; i++) {
      progress(i / 100);
      onTransfer?.call(TransferProgress(received: i, total: 100));
    }
    return super
        .save(track, directory, token, progress, onTransfer: onTransfer);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'capacidade do worker é lida no carregamento e arquivo ausente é revalidado antes do processo',
      () async {
    final temp = await Directory.systemTemp.createTemp('dd-engine-presence-');
    addTearDown(() => temp.delete(recursive: true));
    final file = File('${temp.path}/fixture-worker.exe');
    await file.writeAsBytes([0]);
    final engine = await WindowsMusicEngine.load(file.path);
    expect(engine.available, Platform.isWindows);
    await file.delete();
    expect(engine.available, Platform.isWindows);
    await expectLater(
        engine.call({'operation': 'diagnostic'}), throwsFormatException);
    expect((await WindowsMusicEngine.load(file.path)).available, isFalse);
  });
  test(
      '100 sinais transitórios não consultam SQL/disco; mudanças de dados coalescem',
      () async {
    final files = ProbeFiles();
    final c = PulseLibrary(files), repo = ProbeWorkspace();
    final workspace = WorkspaceController(c, repository: repo);
    addTearDown(workspace.dispose);
    addTearDown(c.dispose);
    await workspace.refresh();
    final reads = repo.reads, probes = files.probes;
    for (var i = 0; i < 100; i++) {
      c.progress = i / 100;
      c.pulse();
    }
    await Future<void>.delayed(const Duration(milliseconds: 480));
    expect(repo.reads, reads);
    expect(files.probes, probes);
    for (var i = 0; i < 100; i++) {
      c.pulse(data: true);
    }
    await Future<void>.delayed(const Duration(milliseconds: 480));
    expect(repo.reads, reads + 3);
    expect(files.probes, probes + 1);
  });
  test(
      'transferência real da fixture publica métricas sem reconstruir a biblioteca por chunk',
      () async {
    final temp = await Directory.systemTemp.createTemp('dd-progress-cost-');
    final repo = LibraryRepository(AppDatabase('${temp.path}/test.db'));
    await repo.database.initialize();
    final id = await repo.importCollection(ImportedCollection(
        name: 'Fixture',
        source: 'Exemplo local',
        sourceUrl: '',
        tracks: Stream.value(const TrackDraft(
            title: 'Sintética',
            artist: 'Laboratório',
            durationMs: 4000,
            coverUrl: 'asset:assets/demo/cover.png',
            mediaUrl: 'asset:assets/demo/tone.mp3',
            sourceKind: SourceKind.localExample))));
    final c = LibraryController(
        repository: repo,
        files: DesktopFiles(),
        spotify: const SpotifyImporter(BoundedHttp()),
        csv: const CsvImporter(),
        catalog: const DeezerCatalog(BoundedHttp()),
        downloader: BurstDownload());
    c.outputDirectory = temp.path;
    await c.openCollection((await repo.collectionById(id))!);
    await c.selectPage(true);
    var libraryUpdates = 0, metrics = 0;
    c.addListener(() => libraryUpdates++);
    c.transferUpdates.addListener(() => metrics++);
    try {
      await c.downloadSelected();
      expect(metrics, greaterThanOrEqualTo(200));
      expect(libraryUpdates, lessThan(20));
      expect(c.page.items.single.status, TrackStatus.completed);
      expect(await File(c.page.items.single.localPath).exists(), isTrue);
    } finally {
      c.dispose();
      await temp.delete(recursive: true);
    }
  });
  test('100 eventos de posição atualizam só o relógio, pausa continua imediata',
      () async {
    final engine = FakeAudioEngine();
    final player =
        MusicPlayerController(MemoryPlayerLibrary(), engine, PlayerFiles());
    addTearDown(player.dispose);
    await player.playCollection(1);
    await Future<void>.delayed(Duration.zero);
    var clock = 0, controls = 0;
    player.timeline.addListener(() => clock++);
    player.addListener(() => controls++);
    for (var i = 1; i <= 100; i++) {
      engine.emit(AudioEvent(position: Duration(milliseconds: i)));
    }
    expect(clock, 100);
    expect(controls, 0);
    expect(player.position.inMilliseconds, 100);
    engine.emit(const AudioEvent(playing: false));
    expect(player.playing, isFalse);
    expect(controls, 1);
    engine.emit(const AudioEvent(position: Duration(milliseconds: 100)));
    expect(clock, 100);
    player.setVolume(.437);
    expect(controls, 2);
    engine.emit(const AudioEvent(position: Duration(seconds: 1)));
    expect(clock, 101);
    expect(controls, 2);
  });
  test('página de coleções conserva contagens e ordem nas duas bordas',
      () async {
    final temp = await Directory.systemTemp.createTemp('dd-collection-page-');
    addTearDown(() => temp.delete(recursive: true));
    final repo = LibraryRepository(AppDatabase('${temp.path}/test.db'));
    await repo.database.initialize();
    await repo.database.run((db) {
      db.execute('BEGIN');
      try {
        for (var i = 1; i <= 61; i++) {
          db.execute(
              "INSERT INTO collections(id,name,source,source_url) VALUES(?,?,'Fixture','')",
              [i, 'Coleção $i']);
          for (var j = 1; j <= 2; j++) {
            db.execute(
                "INSERT INTO tracks(collection_id,position,title,artist,status) VALUES(?,?,'Repetida','Pessoa',?)",
                [i, j, j == 1 ? 'completed' : 'pending']);
          }
        }
        db.execute('COMMIT');
      } catch (_) {
        db.execute('ROLLBACK');
        rethrow;
      }
    });
    final first = await repo.collections(),
        second = await repo.collections(offset: 30),
        last = await repo.collections(offset: 60);
    expect(first.length, 30);
    expect(second.length, 30);
    expect(last.single.id, 1);
    expect([...first, ...second, ...last].map((c) => c.id).toList(),
        List.generate(61, (i) => 61 - i));
    expect(
        [...first, ...second, ...last]
            .every((c) => c.trackCount == 2 && c.completedCount == 1),
        isTrue);
    expect(await repo.collections(offset: 90), isEmpty);
  });
}

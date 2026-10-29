import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:definitive_downloader/core/storage/database.dart';
import 'package:definitive_downloader/core/network/bounded_http.dart';
import 'package:definitive_downloader/features/downloads/download_service.dart';
import 'package:definitive_downloader/features/library/data/library_repository.dart';
import 'package:definitive_downloader/features/library/domain/models.dart';
import 'package:definitive_downloader/features/workspace/data/workspace_repository.dart';
import 'package:definitive_downloader/features/workspace/domain/workspace_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late LibraryRepository library;
  late WorkspaceRepository workspace;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('dd-workspace-');
    library = LibraryRepository(AppDatabase('${directory.path}/library.db'));
    await library.database.initialize();
    workspace = WorkspaceRepository(library.database);
  });
  tearDown(() => directory.delete(recursive: true));
  Future<List<Track>> seed(int count) async {
    final id = await library.importCollection(ImportedCollection(
        name: 'Repetições',
        source: 'CSV',
        sourceUrl: '',
        tracks: Stream.fromIterable(List.generate(
            count,
            (_) => const TrackDraft(
                title: 'Repetida',
                artist: 'Pessoa',
                album: 'Original',
                durationMs: 180000)))));
    return (await library.page(id, limit: 100)).items;
  }

  test('prioridade e remoção persistem sem perder ocorrências ou histórico',
      () async {
    final rows = await seed(3);
    for (final t in rows) {
      await library.linkSource(t,
          url: 'https://example.org/${t.id}.mp3', kind: SourceKind.directMp3);
    }
    await library.setStatus(rows[0].id, TrackStatus.completed,
        localPath: '${directory.path}/saved.mp3');
    await library.setStatus(rows[1].id, TrackStatus.downloading);
    for (var i = 0; i < 6; i++) {
      await workspace.changePriority([rows[2].id], 1);
    }
    expect((await library.trackById(rows[2].id))!.queuePriority, 4);
    await workspace.removeDownloads(rows.map((t) => t.id).toList());
    expect(
        (await workspace.downloads(ContentCategory.music))
            .items
            .single
            .track
            .id,
        rows[1].id);
    expect((await workspace.history()).folders.single.count, 1);
    await library.database.initialize();
    expect(
        (await library.page(rows[0].collectionId)).items.map((t) => t.position),
        [1, 2, 3]);
    expect((await library.trackById(rows[2].id))!.queuePriority, 4);
    expect(await workspace.claimNext(run: 'after-restart', ids: [rows[2].id]),
        isNull);
    await library.setManualSource(rows[2].id, 'https://example.org/new.mp3',
        ManualSourceMode.originalAudio);
    expect((await workspace.downloads(ContentCategory.music)).total, 2);
  });

  test('uma execução não repete falha nem aceita item sem revisão', () async {
    final rows = await seed(3);
    for (final t in rows) {
      await library.linkSource(t,
          url: 'https://example.org/${t.id}.mp3', kind: SourceKind.directMp3);
    }
    await library.markForReview(rows[1].id);
    final first = (await workspace.claimNext(
        run: 'one', ids: rows.map((t) => t.id).toList()))!;
    await library.setStatus(first.id, TrackStatus.failed);
    final second = (await workspace.claimNext(
        run: 'one', ids: rows.map((t) => t.id).toList()))!;
    expect(second.id, rows[2].id);
    await library.setStatus(second.id, TrackStatus.completed,
        localPath: '${directory.path}/fixture.mp3');
    expect(
        await workspace.claimNext(
            run: 'one', ids: rows.map((t) => t.id).toList()),
        isNull);
    expect(
        (await workspace.claimNext(
                run: 'two', ids: [first.id], failedOnly: true))!
            .id,
        first.id);
  });

  test('migração v6 acrescenta fila preservando biblioteca e histórico',
      () async {
    final rows = await seed(2);
    await library.setManualSource(rows[1].id, 'https://example.org/a.mp3',
        ManualSourceMode.originalAudio);
    await library.setStatus(rows[0].id, TrackStatus.completed,
        localPath: '${directory.path}/original.mp3');
    await library.database.run((db) {
      db.execute('DROP INDEX tracks_priority');
      db.execute('ALTER TABLE tracks DROP COLUMN queue_priority');
      db.execute('ALTER TABLE tracks DROP COLUMN queue_run');
      db.execute('PRAGMA user_version=6');
    });
    await library.database.initialize();
    await library.database.initialize();
    expect((await library.trackById(rows[1].id))!.manualUrl,
        'https://example.org/a.mp3');
    expect((await library.trackById(rows[1].id))!.queuePriority, 0);
    expect((await workspace.history()).folders.single.count, 1);
    expect(
        await library.database
            .run((db) => db.select('PRAGMA user_version').first.values.first),
        7);
  });

  test('fonte manual persiste por ocorrência e protege contra busca automática',
      () async {
    final rows = await seed(2);
    await library.setManualSource(
        rows.first.id,
        'https://www.youtube.com/watch?v=abcdefghijk&si=not-persisted',
        ManualSourceMode.extractAudio);
    final restored = LibraryRepository(AppDatabase(library.database.path));
    await restored.database.initialize();
    final t = (await restored.trackById(rows.first.id))!;
    expect(t.manualUrl, 'https://www.youtube.com/watch?v=abcdefghijk');
    expect(t.matchStatus, MatchStatus.manual);
    expect(t.canDownload, isFalse);
    expect(t.durationMs, 180000);
    expect(t.album, 'Original');
    expect(t.position, 1);
    expect((await restored.trackById(rows.last.id))!.hasManualSource, isFalse);
    await restored.chooseMusicSource(
        t,
        const Candidate(
            title: 'Alternativa',
            artist: 'Pessoa',
            album: 'Outro',
            durationMs: 180000,
            pageUrl: 'https://music.youtube.com/watch?v=01234567890',
            previewUrl: '',
            coverUrl: '',
            kind: SourceKind.youtubeMusic,
            recordingType: 'MUSIC_VIDEO_TYPE_ATV'));
    expect((await restored.trackById(t.id))!.manualUrl, t.manualUrl);
    expect(await workspace.nextQueueItem([t.id], 0), isNull);
    await expectLater(
        DownloadService(const BoundedHttp(), rootBundle)
            .save(t, directory.path, DownloadCancellation(), (_) {}),
        throwsFormatException);
    await restored.removeManualSource(t.id);
    final removed = (await restored.trackById(t.id))!;
    expect(removed.hasManualSource, isFalse);
    expect(removed.matchStatus, MatchStatus.pending);
  });
  test('correspondência, seleção e conclusão são estados independentes',
      () async {
    final t = (await seed(1)).single;
    await library.setManualSource(
        t.id, 'https://example.org/song.mp3', ManualSourceMode.originalAudio);
    final linked = (await library.trackById(t.id))!;
    expect(linked.canDownload, isTrue);
    expect(linked.matchStatus, MatchStatus.manual);
    expect(linked.status, TrackStatus.ready);
    expect(linked.selected, isFalse);
    await library.select(t.id, true);
    await library.markForReview(t.id);
    expect(await library.nextSelected(t.collectionId), isNull);
    await expectLater(
        library.setManualSource(
            t.id,
            'https://example.org/song.mp3?token=secret',
            ManualSourceMode.originalAudio),
        throwsFormatException);
    await expectLater(
        library.setManualSource(
            t.id,
            'https://user:password@example.org/song.mp3',
            ManualSourceMode.originalAudio),
        throwsFormatException);
  });
  test('histórico conserva caminho e fonte ao trocar vínculo; navega subpastas',
      () async {
    final rows = await seed(3);
    final base = '${directory.path}/Coleção';
    await library.setStatus(rows[0].id, TrackStatus.completed,
        localPath: '$base/primeira.mp3');
    await library.setStatus(rows[1].id, TrackStatus.completed,
        localPath: '$base/Subpasta/segunda.mp3');
    await library.setStatus(rows[2].id, TrackStatus.completed,
        localPath: '$base/Subpasta/Outra/terceira.mp3');
    await library.setManualSource(rows[0].id, 'https://example.org/new.mp3',
        ManualSourceMode.originalAudio);
    await library.removeManualSource(rows[0].id);
    final page = await workspace.history(folder: base);
    expect(page.files.single.path, '$base/primeira.mp3');
    expect(page.folders.single.path.replaceAll('\\', '/'),
        '$base/Subpasta'.replaceAll('\\', '/'));
    final child = await workspace.history(folder: page.folders.single.path);
    expect(child.files.single.name, 'segunda.mp3');
    expect(child.folders.single.count, 1);
    expect((await workspace.summary()).completed, 3);
    expect((await workspace.history(query: 'segunda')).folders.single.count, 1);
    expect(
        (await library.trackById(rows[0].id))!.localPath, '$base/primeira.mp3');
  });
  test('filas paginadas por categoria e remoção de registro preserva arquivo',
      () async {
    final rows = await seed(45);
    for (final t in rows) {
      await library.linkSource(t,
          url: 'https://example.org/${t.id}.mp3', kind: SourceKind.directMp3);
    }
    final second = (await seed(1)).single;
    await library.linkSource(second,
        url: 'https://example.org/other.mp3', kind: SourceKind.directMp3);
    expect((await workspace.downloads(ContentCategory.music)).items.length, 40);
    expect(
        (await workspace.downloads(ContentCategory.music, offset: 40))
            .items
            .length,
        6);
    expect((await workspace.downloads(ContentCategory.media)).total, 0);
    expect(
        (await workspace.downloads(ContentCategory.music,
                filter: DownloadFilter.paused))
            .total,
        0);
    final file =
        await File('${directory.path}/saved.mp3').writeAsString('fixture');
    await library.setStatus(rows.first.id, TrackStatus.completed,
        localPath: file.path);
    await workspace.hideCompleted([rows.first.id, rows.last.id]);
    expect(await file.exists(), isTrue);
    expect((await library.page(rows.first.collectionId)).total, 45);
    expect((await workspace.summary()).completed, 0);
    expect((await workspace.summary()).records, 45);
    expect((await workspace.downloads(ContentCategory.music)).total, 45);
  });
  test(
      'migração v5 preserva repetição, arquivo, sessão/preferência e tentativas',
      () async {
    final rows = await seed(2);
    await library.linkSource(rows[0],
        url: 'https://www.deezer.com/track/123', kind: SourceKind.deezerFull);
    await library.setStatus(rows[0].id, TrackStatus.completed,
        localPath: 'C:\\Music\\original.mp3');
    await library.select(rows[1].id, true);
    await library.setPreference('output_directory', 'C:/Music');
    await library.recordMusicAttempt(rows[0].id, SourceKind.deezerFull,
        succeeded: true);
    await library.database.run((db) {
      db.execute('DROP TABLE download_history');
      db.execute('DROP INDEX tracks_transfer_status');
      db.execute('DROP INDEX tracks_priority');
      db.execute('ALTER TABLE tracks DROP COLUMN queue_priority');
      db.execute('ALTER TABLE tracks DROP COLUMN queue_run');
      for (final column in [
        'match_status',
        'manual_url',
        'manual_mode',
        'queue_hidden'
      ]) {
        db.execute('ALTER TABLE tracks DROP COLUMN $column');
      }
      db.execute('PRAGMA user_version=5');
    });
    await library.database.initialize();
    final restored = (await library.page(rows.first.collectionId)).items;
    expect(restored.map((t) => t.position), [1, 2]);
    expect(restored[1].selected, isTrue);
    expect(restored[0].status, TrackStatus.completed);
    expect(restored[0].matchStatus, MatchStatus.confirmed);
    expect(restored[1].matchStatus, MatchStatus.pending);
    expect((await workspace.history()).folders.single.path, 'C:\\Music');
    expect(await library.preference('output_directory'), 'C:/Music');
    expect(
        await library.database.run((db) => db
            .select('SELECT COUNT(*) AS n FROM music_source_attempts')
            .first['n']),
        1);
    await library.database.initialize();
    expect((await workspace.summary()).completed, 1);
  });
}

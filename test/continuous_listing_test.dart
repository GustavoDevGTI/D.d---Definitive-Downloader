import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:definitive_downloader/core/storage/database.dart';
import 'package:definitive_downloader/features/library/data/library_repository.dart';
import 'package:definitive_downloader/features/library/data/continuous_track_repository.dart';
import 'package:definitive_downloader/features/library/application/continuous_track_listing.dart';
import 'package:definitive_downloader/features/library/domain/models.dart';
import 'package:definitive_downloader/features/library/domain/track_listing.dart';
import 'package:definitive_downloader/features/workspace/data/continuous_download_repository.dart';
import 'package:definitive_downloader/features/workspace/application/continuous_download_listing.dart';
import 'package:definitive_downloader/features/workspace/data/workspace_repository.dart';
import 'package:definitive_downloader/features/workspace/domain/workspace_models.dart';
import 'package:definitive_downloader/features/workspace/domain/download_columns.dart';
import 'package:definitive_downloader/features/organization/data/collection_organization_repository.dart';
import 'schema_fixtures.dart';
import 'package:definitive_downloader/features/library/data/redownload_repository.dart';

void main() {
  late Directory temp;
  late LibraryRepository repo;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('dd-continuous-');
    repo = LibraryRepository(AppDatabase('${temp.path}/library.db'));
    await repo.database.initialize();
  });
  tearDown(() => temp.delete(recursive: true));
  Future<int> import(int count) => repo.importCollection(ImportedCollection(
      name: 'Grande',
      source: 'Fixture',
      sourceUrl: '',
      tracks: Stream.fromIterable(List.generate(
          count,
          (i) => TrackDraft(
              title: i.isEven ? 'Repetida' : 'Outra ${i + 1}',
              artist: 'Pessoa',
              sourceKind: SourceKind.directMp3,
              mediaUrl: 'https://example.org/a.mp3')))));

  test(
      '10 mil ocorrências ficam prontas numa lista, deltas não relêem as demais',
      () async {
    final id = await import(10000);
    final data = ContinuousTrackRepository(repo.database);
    final first = await data.read(id, since: -1);
    expect(first.ids.length, 10000);
    expect(first.ids.toSet().length, 10000);
    expect(await RedownloadRepository(repo.database).hasWork(ids: first.ids),
        isTrue);
    expect(first.changed.where((t) => t.title == 'Repetida').length, 5000);
    final same = await data.read(id, since: first.revision);
    expect(same.changed, isEmpty);
    final last = first.changed.last;
    await repo.select(last.id, true);
    final delta = await data.read(id, since: first.revision);
    expect(delta.changed.map((t) => t.id), [last.id]);
    expect(delta.selected, 1);
    final listing = ContinuousTrackListing(data);
    final all = (await listing.load(id))!;
    final filtered = (await listing.load(id, query: 'outra 9999'))!;
    expect(filtered.items, isEmpty);
    final restored = (await listing.load(id))!;
    expect(restored.items.length, 10000);
    expect(identical(all.items.first, restored.items.first), isTrue);
    final found =
        (await listing.load(id, query: 'outra 10000', sort: TrackSort.name))!;
    expect(found.items.single.id, last.id);
  });

  test(
      'Downloads mantém 235 registros, filtros globais e deltas de conclusão/coleção',
      () async {
    final id = await import(235);
    final data = ContinuousDownloadRepository(repo.database);
    final listing = ContinuousDownloadListing(data);
    final all = (await listing.load(ContentCategory.music))!;
    expect(all.items.length, 235);
    final last = all.items.last.track;
    final selectedIds = all.items.map((e) => e.track.id).toList();
    expect(await RedownloadRepository(repo.database).hasWork(ids: selectedIds),
        isTrue);
    await WorkspaceRepository(repo.database)
        .beginRun(run: 'large-selection', ids: selectedIds);
    final members = await repo.database.run((db) => db
        .select('SELECT COUNT(*) AS n FROM download_run_additions')
        .single['n']);
    expect(members, 235);
    final file = await File('${temp.path}/last.mp3').writeAsBytes([1, 2, 3, 4]);
    await repo.setStatus(last.id, TrackStatus.completed, localPath: file.path);
    var next = (await listing.load(ContentCategory.music))!;
    expect(next.items.last.track.status, TrackStatus.completed);
    expect(next.items.last.downloadedAt, isNotNull);
    expect(await listing.checkVisible([last.id]), isTrue);
    next = listing.updated(next);
    expect(next.items.last.fileBytes, 4);
    expect(identical(all.items.first, next.items.first), isTrue);
    final completed = (await listing.load(ContentCategory.music,
        filter: DownloadFilter.completed))!;
    expect(completed.items.single.track.id, last.id);
    final before = await data.read(ContentCategory.music, since: -1);
    await repo.database.run((db) => db.execute(
        'UPDATE download_history SET created_at=? WHERE track_id=?',
        ['2026-11-04 10:20:00', last.id]));
    final delta =
        await data.read(ContentCategory.music, since: before.revision);
    expect(delta.changed.map((e) => e.track.id), [last.id]);
    expect(
        delta.changed.single.downloadedAt, DateTime.utc(2026, 11, 4, 10, 20));
    await repo.database.run((db) => db.execute(
        'UPDATE collections SET name=? WHERE id=?', ['Renomeada', id]));
    final renamed = (await listing.load(ContentCategory.music))!;
    expect(renamed.items.every((e) => e.collectionName == 'Renomeada'), isTrue);
    await WorkspaceRepository(repo.database).removeDownloads(
        renamed.items.take(180).map((e) => e.track.id).toList());
    expect((await listing.load(ContentCategory.music))!.items.length, 55);
    expect((await repo.collectionById(id))!.trackCount, 235);
    await expectLater(
        data.sizes(List.filled(101, renamed.items.first)), throwsArgumentError);
  });

  test('cores de playlists migram e agrupam Downloads sem mudar a fila',
      () async {
    final firstId = await import(2), secondId = await import(2);
    final before = (await repo.page(firstId)).items.map((t) => t.id).toList();
    await repo.select(before.first, true);
    await repo.database.run((db) {
      removePlaylistThemeSchema(db);
      db.execute('PRAGMA user_version=16');
    });
    await repo.database.initialize();
    final first = (await repo.collectionById(firstId))!;
    final second = (await repo.collectionById(secondId))!;
    expect(first.themeColor, isNotNull);
    expect(second.themeColor, isNot(first.themeColor));
    expect((await repo.page(firstId)).items.map((t) => t.id), before);
    expect((await repo.page(firstId)).items.first.selected, isTrue);

    final organization = CollectionOrganizationRepository(repo.database);
    final thirdId = await organization.create('Nova');
    expect((await repo.collectionById(thirdId))!.themeColor,
        isNot(anyOf(isNull, first.themeColor, second.themeColor)));
    await expectLater(
        organization.rename(firstId, 'Alteração recusada',
            themeColor: second.themeColor),
        throwsFormatException);
    expect((await repo.collectionById(firstId))!.name, first.name);

    await organization.rename(secondId, 'Segunda', themeColor: 0x125500);
    final data = ContinuousDownloadRepository(repo.database);
    final listing = ContinuousDownloadListing(data);
    final baseline = (await listing.load(ContentCategory.music))!;
    final revision =
        (await data.read(ContentCategory.music, since: -1)).revision;
    await organization.rename(firstId, 'Primeira', themeColor: 0xBB6600);
    final delta = await data.read(ContentCategory.music, since: revision);
    expect(delta.changed.map((e) => e.track.id), unorderedEquals(before));
    expect(delta.changed.every((e) => e.playlistColor == 0xBB6600), isTrue);
    final byColor = (await listing.load(ContentCategory.music,
        sort: DownloadSort.playlistColor))!;
    expect(byColor.items.map((e) => e.collectionName),
        ['Segunda', 'Segunda', 'Primeira', 'Primeira']);
    final reversed = (await listing.load(ContentCategory.music,
        sort: DownloadSort.playlistColor, descending: true))!;
    expect(reversed.items.map((e) => e.track.id).take(2), before);
    final restored = (await listing.load(ContentCategory.music))!;
    expect(restored.items.map((e) => e.track.id),
        baseline.items.map((e) => e.track.id));
    await repo.database.initialize();
    expect((await repo.collectionById(firstId))!.themeColor, 0xBB6600);
  });

  test('migração v12 conserva campos e cria revisão sem trabalho nem download',
      () async {
    final id = await import(3);
    final before = (await repo.page(id))
        .items
        .map((t) => (t.id, t.title, t.position, t.sourceKind))
        .toList();
    await repo.database.run((db) {
      removeContinuousSchema(db);
      db.execute('PRAGMA user_version=12');
    });
    await repo.database.initialize();
    await repo.database.initialize();
    expect(
        (await repo.page(id))
            .items
            .map((t) => (t.id, t.title, t.position, t.sourceKind))
            .toList(),
        before);
    final check = await repo.database.run((db) => [
          db.select('PRAGMA user_version').single.values.single,
          db.select('PRAGMA quick_check').single.values.single,
          db.select('PRAGMA foreign_key_check').length
        ]);
    expect(check, [17, 'ok', 0]);
    final data = ContinuousTrackRepository(repo.database);
    final snapshot = await data.read(id, since: -1);
    await repo.database.run((db) {
      db.execute('PRAGMA recursive_triggers=ON');
      db.execute('UPDATE tracks SET selected=1 WHERE id=?', [before.first.$1]);
    });
    expect((await data.read(id, since: snapshot.revision)).changed.length, 1);
  });
}

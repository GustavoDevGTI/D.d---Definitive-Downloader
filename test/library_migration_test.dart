import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:definitive_downloader/core/storage/database.dart';
import 'package:definitive_downloader/core/storage/legacy_library_migration.dart';
import 'package:definitive_downloader/features/library/data/library_repository.dart';
import 'package:definitive_downloader/features/library/domain/models.dart';

void main() {
  late Directory directory;
  late LibraryRepository source;
  late String destination;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('dd-migration-');
    source = LibraryRepository(AppDatabase('${directory.path}/old.sqlite3'));
    destination = '${directory.path}/new/library.sqlite3';
    await source.database.initialize();
  });
  tearDown(() => directory.delete(recursive: true));

  test(
      'migra snapshot preservando ocorrências, seleção, arquivo e preferências',
      () async {
    final id = await source.importCollection(ImportedCollection(
        name: 'Minha coleção',
        source: 'CSV',
        sourceUrl: '',
        tracks: Stream.fromIterable(List.generate(
            2, (_) => const TrackDraft(title: 'Repetida', artist: 'Pessoa')))));
    final original = (await source.page(id)).items;
    await source.select(original[0].id, true);
    await source.setStatus(original[1].id, TrackStatus.completed,
        localPath: 'C:/Music/original.mp3');
    await source.setPreference('output_directory', 'C:/Minha pasta');
    expect(
        await migrateLegacyLibrary(
            sourcePath: source.database.path, destinationPath: destination),
        isTrue);
    final restored = LibraryRepository(AppDatabase(destination));
    await restored.database.initialize();
    final rows = (await restored.page(id)).items;
    expect(rows.map((row) => row.position), [1, 2]);
    expect(rows.map((row) => row.title), ['Repetida', 'Repetida']);
    expect(rows[0].selected, isTrue);
    expect(rows[1].localPath, 'C:/Music/original.mp3');
    expect(rows[1].status, TrackStatus.completed);
    expect(await restored.preference('output_directory'), 'C:/Minha pasta');
    expect(await File(source.database.path).exists(), isTrue);
    expect((await source.page(id)).total, 2);
    expect(
        await migrateLegacyLibrary(
            sourcePath: source.database.path, destinationPath: destination),
        isFalse);
  });

  test('não sobrescreve biblioteca existente com a anterior', () async {
    final current = AppDatabase(destination);
    await current.initialize();
    await current.run((db) => db.execute(
        "INSERT INTO preferences(key,value) VALUES('identity','current')"));
    expect(
        await migrateLegacyLibrary(
            sourcePath: source.database.path, destinationPath: destination),
        isFalse);
    expect(await LibraryRepository(current).preference('identity'), 'current');
  });

  test('atualiza somente o rótulo do exemplo na migração da versão anterior',
      () async {
    final id = await source.importCollection(ImportedCollection(
        name: 'Exemplo e importado',
        source: 'Teste',
        sourceUrl: '',
        tracks: Stream.fromIterable(const [
          TrackDraft(
              title: 'Exemplo',
              artist: 'Laboratório Trama',
              sourceKind: SourceKind.localExample,
              mediaUrl: 'asset:assets/demo/tone.mp3'),
          TrackDraft(title: 'Importado', artist: 'Laboratório Trama'),
        ])));
    await source.database.run((db) {
      // Simulate the actual v2 schema, not a current schema with a false version.
      db.execute('DROP TABLE music_candidates');
      db.execute('DROP TABLE music_source_attempts');
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
      db.execute('ALTER TABLE tracks DROP COLUMN explicit');
      db.execute('ALTER TABLE tracks DROP COLUMN resolved_cover_url');
      db.execute('PRAGMA user_version = 2');
    });
    await migrateLegacyLibrary(
        sourcePath: source.database.path, destinationPath: destination);
    final restored = LibraryRepository(AppDatabase(destination));
    await restored.database.initialize();
    final rows = (await restored.page(id)).items;
    expect(rows[0].artist, 'Laboratório D.d');
    expect(rows[1].artist, 'Laboratório Trama');
    expect(
        await source.database.run((db) => db.select(
            'SELECT artist FROM tracks WHERE collection_id=? ORDER BY position LIMIT 1',
            [id]).first['artist']),
        'Laboratório Trama');
  });
}

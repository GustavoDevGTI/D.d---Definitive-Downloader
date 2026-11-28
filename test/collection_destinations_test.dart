import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:definitive_downloader/core/storage/database.dart';
import 'package:definitive_downloader/features/downloads/playlist_exporter.dart';
import 'package:definitive_downloader/features/library/data/collection_destinations.dart';
import 'package:definitive_downloader/features/library/data/library_repository.dart';
import 'package:definitive_downloader/features/library/domain/models.dart';
import 'schema_fixtures.dart';

void main() {
  late Directory temp;
  late LibraryRepository repository;
  late CollectionDestinations destinations;
  late String root, legacyRoot;

  Future<int> create(String name) =>
      repository.importCollection(ImportedCollection(
          name: name,
          source: 'Ensaio',
          sourceUrl: '',
          tracks: Stream.value(const TrackDraft(title: 'Faixa', artist: ''))));

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('dd-destinations-');
    root = p.join(temp.path, 'Downloads');
    legacyRoot = p.join(root, 'Definitive Downloader');
    repository = LibraryRepository(AppDatabase(p.join(temp.path, 'db.sqlite')));
    await repository.database.initialize();
    destinations = CollectionDestinations(repository.database,
        exists: (path) async =>
            await FileSystemEntity.type(path) != FileSystemEntityType.notFound,
        root: () => root,
        legacyRoot: () => legacyRoot);
  });

  tearDown(() => temp.delete(recursive: true));

  test('playlists anteriores ao schema 18 mantêm a pasta "nome [id]"',
      () async {
    final id = await create('Antiga');
    await repository.database.run((db) {
      removePlaylistDestinationSchema(db);
      db.execute('PRAGMA user_version=17');
    });
    await repository.database.initialize();
    final expected = p.join(legacyRoot, 'Antiga [$id]');
    expect((await destinations.describe(id)).directory, expected);
    expect(await destinations.directory(id), expected);
    // Still following the root, as before: nothing was reserved.
    legacyRoot = p.join(temp.path, 'Outra');
    expect(
        await destinations.directory(id), p.join(legacyRoot, 'Antiga [$id]'));
  });

  test('nova playlist ganha pasta com o nome dela, sem juntar a pasta alheia',
      () async {
    final first = await create('Treino');
    expect(
        (await destinations.describe(first)).directory, p.join(root, 'Treino'));
    await Directory(p.join(root, 'Treino')).create(recursive: true);
    final reserved = await destinations.directory(first);
    expect(reserved, p.join(root, 'Treino (2)'));
    // Reserved once: creating the folder later keeps the same name.
    await Directory(reserved).create();
    expect(await destinations.directory(first), reserved);

    final second = await create('Treino');
    expect(await destinations.directory(second), p.join(root, 'Treino (3)'));

    await repository.database.run((db) => db.execute(
        "UPDATE collections SET name='Renomeada' WHERE id=?", [first]));
    expect(await destinations.directory(first), reserved);
  });

  test('pasta escolhida vale para os próximos arquivos; padrão volta ao início',
      () async {
    final id = await create('Viagem');
    expect(await destinations.directory(id), p.join(root, 'Viagem'));
    final chosen = p.join(temp.path, 'Externo');
    await destinations.setRoot(id, chosen);
    final custom = await destinations.describe(id);
    expect(custom.customRoot, isTrue);
    expect(custom.reserved, isFalse);
    expect(await destinations.directory(id), p.join(chosen, 'Viagem'));
    await destinations.setRoot(id, '');
    expect((await destinations.describe(id)).customRoot, isFalse);
    expect(await destinations.directory(id), p.join(root, 'Viagem'));
    expect(() => destinations.setRoot(id, 'relativa'), throwsFormatException);
  });

  test('playlist antiga passa ao novo formato ao escolher uma pasta', () async {
    final id = await create('Antiga');
    await repository.database
        .run((db) => db.execute('UPDATE collections SET legacy_folder=1'));
    await destinations.setRoot(id, root);
    expect(await destinations.directory(id), p.join(root, 'Antiga'));
  });

  test('M3U8 aponta para arquivos salvos antes da troca de pasta', () async {
    final id = await create('Mista');
    final old = p.join(legacyRoot, 'Mista [$id]', '01 - Faixa.mp3');
    final now = p.join(root, 'Mista');
    await Directory(now).create(recursive: true);
    await repository.database.run((db) => db.execute(
        "UPDATE tracks SET status='completed',local_path=? WHERE collection_id=?",
        [old, id]));
    final playlist = await PlaylistExporter(repository).export(id, now);
    final lines = await File(playlist).readAsLines();
    expect(lines.last,
        p.join('..', 'Definitive Downloader', 'Mista [$id]', '01 - Faixa.mp3'));
  });
}

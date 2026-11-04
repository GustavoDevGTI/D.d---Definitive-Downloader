import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:definitive_downloader/core/storage/database.dart';
import 'package:definitive_downloader/features/library/data/library_repository.dart';
import 'package:definitive_downloader/features/library/domain/models.dart';
import 'package:definitive_downloader/features/organization/data/collection_organization_repository.dart';
import 'package:definitive_downloader/features/organization/application/collection_organization_controller.dart';
import 'schema_fixtures.dart';

void main() {
  late Directory temp;
  late LibraryRepository library;
  late CollectionOrganizationRepository repository;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('dd-organization-');
    library = LibraryRepository(AppDatabase('${temp.path}/test.db'));
    await library.database.initialize();
    repository = CollectionOrganizationRepository(library.database);
  });
  tearDown(() => temp.delete(recursive: true));

  test('cria playlist vazia local e pagina busca e grupo antes do limite',
      () async {
    await repository.saveGroup('Viagens');
    final group = (await repository.groups()).single.id;
    for (var i = 0; i < 65; i++) {
      await repository.create(i.isEven ? 'ÁUDIO $i' : 'Outra $i',
          groupId: i < 50 ? group : null);
    }
    final first = await repository.list(query: 'áudio', groupId: group);
    expect(first.total, 25);
    expect(first.items.length, 25);
    expect(first.items.every((c) => c.trackCount == 0 && c.source == 'Local'),
        isTrue);
    final all = await repository.list(groupId: group);
    final second = await repository.list(groupId: group, offset: 30);
    expect(all.total, 50);
    expect(all.items.length, 30);
    expect(second.items.length, 20);
    expect(
        {...all.items.map((c) => c.id), ...second.items.map((c) => c.id)}
            .length,
        50);
    expect((await repository.list(groupId: 0)).total, 15);
    expect((await repository.list(query: "' OR 1=1 --")).total, 0);
    await expectLater(repository.list(offset: -1), throwsArgumentError);
  });

  test(
      'renomeia e agrupa preservando ocorrências, fonte, bloqueio, pasta e histórico',
      () async {
    final id = await library.importCollection(ImportedCollection(
        name: 'Original',
        source: 'Teste',
        sourceUrl: 'https://example.org/list',
        tracks: Stream.fromIterable(List.generate(
            2, (_) => const TrackDraft(title: 'Repetida', artist: 'Pessoa')))));
    final rows = (await library.page(id)).items;
    await library.setStatus(rows[0].id, TrackStatus.completed,
        localPath: '${temp.path}/original.mp3');
    await library.database.run((db) =>
        db.execute('UPDATE collections SET editing_locked=1 WHERE id=?', [id]));
    await repository.saveGroup('Estúdio');
    final group = (await repository.groups()).single;
    await repository.rename(id, 'Novo nome');
    await repository.move(id, group.id);
    await repository.saveGroup('Favoritas', id: group.id);
    final owner = (await library.collectionById(id))!;
    expect(owner.name, 'Novo nome');
    expect(owner.outputFolderName, 'Original');
    expect(owner.editingLocked, isTrue);
    expect(owner.sourceUrl, 'https://example.org/list');
    expect(owner.groupId, group.id);
    expect(
        (await library.page(id)).items.map((t) => t.id), rows.map((t) => t.id));
    expect((await library.page(id)).items.map((t) => t.position), [1, 2]);
    final restored =
        CollectionOrganizationRepository(AppDatabase(library.database.path));
    expect((await restored.groups()).single.name, 'Favoritas');
    await restored.removeGroup(group.id);
    expect((await restored.list(groupId: 0)).total, 1);
    expect((await library.page(id)).items.first.localPath,
        '${temp.path}/original.mp3');
    expect(
        await library.database.run((db) =>
            db.select('SELECT COUNT(*) AS n FROM download_history').first['n']),
        1);
    expect((await library.collectionById(id))!.outputFolderName, 'Original');
  });

  test('valida nomes, grupos únicos e limite explícito sem alterações parciais',
      () async {
    for (final name in ['', '  ', 'a\nb', 'a' * 161]) {
      await expectLater(repository.create(name), throwsFormatException);
    }
    await repository.saveGroup('MÚSICAS');
    await expectLater(repository.saveGroup(' músicas '), throwsFormatException);
    final id = await repository.create('Nome repetido');
    await repository.create('Nome repetido');
    await expectLater(repository.move(id, 999), throwsA(anything));
    expect((await library.collectionById(id))!.groupId, isNull);
    for (var i = 1; i < 100; i++) {
      await repository.saveGroup('Grupo $i');
    }
    await expectLater(repository.saveGroup('Excedente'), throwsFormatException);
    expect((await repository.groups()).length, 100);
  });

  test('migra v9 duas vezes preservando pasta e dados, sem grupos fictícios',
      () async {
    final id = await repository.create('Antes');
    await library.database.run((db) {
      removeOrganizationSchema(db);
      db.execute('PRAGMA user_version=9');
    });
    await library.database.initialize();
    await library.database.initialize();
    expect((await library.collectionById(id))!.outputFolderName, 'Antes');
    expect(await repository.groups(), isEmpty);
    expect(
        await library.database
            .run((db) => db.select('PRAGMA user_version').first.values.first),
        10);
    expect(
        await library.database
            .run((db) => db.select('PRAGMA foreign_key_check').length),
        0);
    expect(
        await library.database
            .run((db) => db.select('PRAGMA quick_check').first.values.first),
        'ok');
  });

  test(
      'controlador elimina filtros antigos e retorna a página existente após mover',
      () async {
    for (var i = 0; i < 31; i++) {
      await repository.create('Playlist $i');
    }
    final c = CollectionOrganizationController(repository);
    await c.refresh();
    await c.turnPage(1);
    expect(c.offset, 30);
    await c.filter('Playlist 30', null);
    expect(c.offset, 0);
    expect(c.listing.total, 1);
    final old = c.filter('Playlist 1', null);
    final latest = c.filter('Inexistente', 0);
    await Future.wait([old, latest]);
    expect(c.listing.total, 0);
    expect(c.query, 'Inexistente');
    await c.filter('', null);
    await c.turnPage(1);
    final id = c.listing.items.single.id;
    await repository.saveGroup('Mover');
    final group = (await repository.groups()).single.id;
    await c.filter('', 0);
    await c.turnPage(1);
    expect(await c.mutate(() => repository.move(id, group)), isNull);
    expect(c.offset, 0);
    expect(c.listing.total, 30);
    c.dispose();
  });
}

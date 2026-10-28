import 'dart:io';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:definitive_downloader/core/storage/database.dart';
import 'package:definitive_downloader/features/library/data/library_repository.dart';
import 'package:definitive_downloader/features/library/domain/models.dart';
import 'package:definitive_downloader/features/downloads/playlist_exporter.dart';

void main() {
  late Directory directory;
  late LibraryRepository repository;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('dd-db-');
    repository = LibraryRepository(AppDatabase('${directory.path}/library.db'));
    await repository.database.initialize();
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });
  Future<int> seed(int count) => repository.importCollection(ImportedCollection(
      name: 'Minha lista',
      source: 'Teste',
      sourceUrl: '',
      tracks: Stream.fromIterable(List.generate(count,
          (i) => const TrackDraft(title: 'Repetida', artist: 'Pessoa')))));

  test('pagina sem remover ocorrências repetidas e persiste seleção', () async {
    final id = await seed(85);
    final first = await repository.page(id);
    final last = await repository.page(id, offset: 80);
    expect(first.items.length, 40);
    expect(last.items.length, 5);
    expect(first.total, 85);
    expect(last.items.first.position, 81);
    expect(last.items.last.position, 85);
    await repository.select(first.items[2].id, true);
    final restored = LibraryRepository(AppDatabase(repository.database.path));
    expect((await restored.page(id)).selectedCount, 1);
    await expectLater(repository.page(id, limit: 10000), throwsArgumentError);
  });

  test('lotes gravados permanecem parciais até concluir o stream', () async {
    final persisted = Completer<void>();
    final finish = Completer<void>();
    Stream<TrackDraft> entries() async* {
      for (var index = 0; index < 100; index++) {
        yield const TrackDraft(title: 'Repetida', artist: 'Pessoa');
      }
      persisted.complete();
      await finish.future;
      yield const TrackDraft(title: 'Última', artist: 'Pessoa');
    }

    final importing = repository.importCollection(ImportedCollection(
        name: 'Em leitura', source: 'Teste', sourceUrl: '', tracks: entries()));
    await persisted.future;
    expect((await repository.collections()).single.isPartial, isTrue);
    finish.complete();
    await importing;
    expect((await repository.collections()).single.isPartial, isFalse);
    expect((await repository.collections()).single.trackCount, 101);
  });
  test(
      'falha no stream remove a importação incompleta, inclusive lotes gravados',
      () async {
    Stream<TrackDraft> broken() async* {
      for (var i = 0; i < 105; i++) {
        yield const TrackDraft(title: 'Faixa', artist: 'Pessoa');
      }
      throw const FormatException('Arquivo interrompido');
    }

    await expectLater(
        repository.importCollection(ImportedCollection(
            name: 'Quebrada', source: 'CSV', sourceUrl: '', tracks: broken())),
        throwsFormatException);
    expect(await repository.collections(), isEmpty);
  });
  test('recupera transferências interrompidas sem alterar itens concluídos',
      () async {
    final id = await seed(2);
    final rows = (await repository.page(id)).items;
    await repository.setStatus(rows[0].id, TrackStatus.downloading);
    await repository.setStatus(rows[1].id, TrackStatus.completed,
        localPath: 'arquivo.mp3');
    await repository.database.initialize();
    final restored = (await repository.page(id)).items;
    expect(restored[0].status, TrackStatus.ready);
    expect(restored[1].status, TrackStatus.completed);
  });
  test('M3U8 mantém a posição original mesmo concluindo fora de ordem',
      () async {
    final id = await seed(3);
    final rows = (await repository.page(id)).items;
    await repository.database.run((db) {
      db.execute("UPDATE tracks SET source_kind='deezerFull' WHERE id=?",
          [rows[0].id]);
      db.execute("UPDATE tracks SET source_kind='youtubeMusic' WHERE id=?",
          [rows[2].id]);
    });
    await repository.setStatus(rows[2].id, TrackStatus.completed,
        localPath: '${directory.path}/003.mp3');
    await repository.setStatus(rows[0].id, TrackStatus.completed,
        localPath: '${directory.path}/001.mp3');
    final path = await PlaylistExporter(repository).export(id, directory.path);
    final content = await File(path).readAsLines();
    expect(content[2], '001.mp3');
    expect(content[4], '003.mp3');
    expect(content[1], endsWith('[Deezer]'));
    expect(content[3], endsWith('[YouTube Music]'));
  });
}

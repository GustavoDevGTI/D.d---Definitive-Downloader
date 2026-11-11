import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'schema_fixtures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'package:definitive_downloader/app/theme.dart';
import 'package:definitive_downloader/core/storage/database.dart';
import 'package:definitive_downloader/features/downloads/download_cancellation.dart';
import 'package:definitive_downloader/features/importing/collection_duplicates.dart';
import 'package:definitive_downloader/features/importing/collection_link_addition.dart';
import 'package:definitive_downloader/features/importing/music_link.dart';
import 'package:definitive_downloader/features/importing/music_link_catalog.dart';
import 'package:definitive_downloader/features/importing/csv_importer.dart';
import 'package:definitive_downloader/core/network/bounded_http.dart';
import 'package:definitive_downloader/core/platform/desktop_files.dart';
import 'package:definitive_downloader/features/library/application/library_controller.dart';
import 'package:definitive_downloader/features/matching/deezer_catalog.dart';
import 'package:definitive_downloader/features/importing/music_link_repository.dart';
import 'package:definitive_downloader/features/importing/replacement_media_files.dart';
import 'package:definitive_downloader/features/library/data/library_repository.dart';
import 'package:definitive_downloader/features/library/domain/models.dart';
import 'package:definitive_downloader/features/library/presentation/duplicate_music_dialog.dart';
import 'package:definitive_downloader/features/organization/data/collection_organization_repository.dart';
import 'package:definitive_downloader/features/player/application/music_player_controller.dart';
import 'player_fixtures.dart';
import 'playlist_matching_test.dart' show FixturePlaylist;
import 'workspace_download_controller_test.dart' show GatedDownload;

ResolvedMusicLink synthetic(String id, String title) => ResolvedMusicLink(
    link: MusicLink.parse('https://media.example/$id.mp3'),
    ready: true,
    draft: TrackDraft(
        title: title,
        artist: 'Pessoa',
        durationMs: 4000,
        sourceKind: SourceKind.localExample,
        mediaUrl: 'asset:assets/demo/tone.mp3'));

class DuplicateCatalogFixture extends MusicLinkCatalog {
  @override
  Future<ResolvedMusicLink> resolve(MusicLink link) async =>
      synthetic('new', 'Canção');
}

ResolvedMusicLink entry(String id,
    {String title = 'Canção', String artist = 'Pessoa', String isrc = ''}) {
  final url = 'https://media.example/$id.mp3';
  return ResolvedMusicLink(
      link: MusicLink.parse(url),
      ready: true,
      draft: TrackDraft(
          title: title,
          artist: artist,
          isrc: isrc,
          durationMs: 180000,
          sourceUrl: url,
          mediaUrl: url,
          sourceKind: SourceKind.directMp3));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  late LibraryRepository repo;
  late Collection owner;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('dd-duplicates-');
    repo = LibraryRepository(AppDatabase('${temp.path}/library.db'));
    await repo.database.initialize();
    final id = await CollectionOrganizationRepository(repo.database)
        .create('Minha playlist');
    owner = (await repo.collectionById(id))!;
  });
  tearDown(() => temp.delete(recursive: true));
  Future<List<Track>> seed(List<ResolvedMusicLink> entries) async {
    await MusicLinkRepository(repo.database).append(owner.id, entries);
    return (await repo.page(owner.id)).items;
  }

  Future<File> completed(Track track) async {
    final dir = await Directory('${temp.path}/${owner.name} [${owner.id}]')
        .create(recursive: true);
    final file = await File('assets/demo/tone.mp3')
        .copy('${dir.path}/${track.position}.mp3');
    await repo.setStatus(track.id, TrackStatus.completed, localPath: file.path);
    return file;
  }

  Future<String> apply(
          List<ResolvedMusicLink> entries, ChooseDuplicate choose) =>
      CollectionLinkAddition(repo).add(owner, entries,
          choose: choose,
          cancellation: DownloadCancellation(),
          holdQueue: () {},
          run: () => null,
          progress: (_) {});

  test(
      'manter existentes reorganiza só as recebidas; Fazer para todos vale no lote',
      () async {
    final old = await seed([entry('a'), entry('b', title: 'Outra')]);
    var questions = 0;
    await apply([
      entry('new-a'),
      entry('c', title: 'Inédita'),
      entry('new-b', title: 'Outra')
    ], (c) async {
      questions++;
      return const DuplicateDecision(DuplicateChoice.existing, forAll: true);
    });
    final rows = (await repo.page(owner.id)).items;
    expect(questions, 1);
    expect(rows.map((t) => t.position), [1, 2, 3]);
    expect(rows.map((t) => t.title), ['Canção', 'Outra', 'Inédita']);
    expect(rows.take(2).map((t) => t.id), old.map((t) => t.id));
  });
  test(
      'nova versão exclui arquivo/entrada antigos e entra no fim; demais baixadas ficam fixas',
      () async {
    final original = File('assets/demo/tone.mp3');
    final hash = sha256.convert(await original.readAsBytes());
    final old = await seed([entry('a'), entry('b', title: 'Outra')]);
    final fileA = await completed(old[0]), fileB = await completed(old[1]);
    await apply([entry('new-a'), entry('c', title: 'Inédita')],
        (_) async => const DuplicateDecision(DuplicateChoice.incoming));
    expect(await fileA.exists(), isFalse);
    expect(await fileB.exists(), isTrue);
    expect(sha256.convert(await original.readAsBytes()), hash);
    final rows = (await repo.page(owner.id)).items;
    expect(rows.map((t) => t.position), [2, 3, 4]);
    expect(rows.first.id, old[1].id);
    expect(rows[1].id, greaterThan(old.last.id));
    expect(rows[1].localPath, isEmpty);
    expect(await repo.trackById(old[0].id), isNull);
    final check = await repo.database.run((db) => [
          db.select('SELECT * FROM music_replacement_files').length,
          db.select('SELECT * FROM download_history WHERE local_path=?',
              [fileA.path]).length,
          db.select('PRAGMA foreign_key_check').length
        ]);
    expect(check, [0, 0, 0]);
    expect(await File('${fileB.parent.path}/playlist.m3u8').readAsString(),
        contains('2.mp3'));
  });
  test('cancelar depois de uma decisão não altera faixas ou arquivo', () async {
    final old = await seed([entry('a'), entry('b', title: 'Outra')]);
    final file = await completed(old[0]);
    var asked = 0;
    await expectLater(
        apply(
            [entry('new-a'), entry('new-b', title: 'Outra')],
            (_) async => ++asked == 1
                ? const DuplicateDecision(DuplicateChoice.incoming)
                : null),
        throwsA(isA<DownloadCancelled>()));
    expect((await repo.page(owner.id)).items.map((t) => t.id),
        old.map((t) => t.id));
    expect(await file.exists(), isTrue);
  });
  test('falha na transação restaura mídia e ocorrência anteriores', () async {
    final old = (await seed([entry('a', isrc: 'USAAA1200001')])).single;
    final file = await completed(old);
    await expectLater(
        apply([entry('bad', title: '', isrc: 'USAAA1200001')],
            (_) async => const DuplicateDecision(DuplicateChoice.incoming)),
        throwsFormatException);
    expect(await file.exists(), isTrue);
    expect(await repo.trackById(old.id), isNotNull);
    expect(
        await repo.database.run(
            (db) => db.select('SELECT * FROM music_replacement_files').length),
        0);
  });
  test('remover a última antiga não cria buraco antes das novas', () async {
    final old = await seed([entry('a', title: 'Fixa'), entry('b')]);
    await apply([entry('new'), entry('other', title: 'Depois')],
        (_) async => const DuplicateDecision(DuplicateChoice.incoming));
    final rows = (await repo.page(owner.id)).items;
    expect(rows.map((t) => t.position), [1, 2, 3]);
    expect(rows.first.id, old.first.id);
    expect(rows[1].id, greaterThan(old.last.id));
  });
  test('somente as versões escolhidas passam pela preparação de fonte',
      () async {
    await seed([entry('a')]);
    final prepared = <String>[];
    await CollectionLinkAddition(repo).add(
        owner, [entry('new-a'), entry('b', title: 'Nova')],
        choose: (_) async => const DuplicateDecision(DuplicateChoice.existing),
        prepare: (e) async {
          prepared.add(e.draft.title);
          return e;
        },
        cancellation: DownloadCancellation(),
        holdQueue: () {},
        run: () => null,
        progress: (_) {});
    expect(prepared, ['Nova']);
  });
  test(
      'fila aguarda revisão sem começar a próxima faixa; substituta entra ao final',
      () async {
    final old = await seed([synthetic('a', 'Canção'), synthetic('b', 'Outra')]);
    final downloader = GatedDownload();
    final controller = LibraryController(
        repository: repo,
        files: DesktopFiles(),
        spotify: FixturePlaylist([]),
        csv: const CsvImporter(),
        catalog: const DeezerCatalog(BoundedHttp()),
        downloader: downloader,
        linkCatalog: DuplicateCatalogFixture());
    controller.outputDirectory = '${temp.path}/output';
    addTearDown(controller.dispose);
    await controller.openCollection(owner);
    final downloading = controller.downloadSelected();
    await downloader.started.future;
    final reviewing = Completer<void>(),
        decision = Completer<DuplicateDecision?>();
    final adding = controller.addLinks(
        owner.id, 'https://media.example/new.mp3', chooseDuplicate: (_) {
      reviewing.complete();
      return decision.future;
    });
    await reviewing.future;
    downloader.release.complete();
    for (var i = 0; i < 300; i++) {
      if ((await repo.trackById(old[0].id))?.status == TrackStatus.completed) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect((await repo.trackById(old[0].id))!.status, TrackStatus.completed);
    expect(downloader.ids, [old[0].id]);
    decision.complete(const DuplicateDecision(DuplicateChoice.incoming));
    expect(await adding, isTrue, reason: controller.message);
    await downloading;
    expect(await repo.trackById(old[0].id), isNull);
    final rows = (await repo.page(owner.id)).items;
    expect(rows.map((t) => t.position), [2, 3]);
    expect(rows.every((t) => t.status == TrackStatus.completed), isTrue);
    expect(downloader.ids, [old[0].id, old[1].id, rows.last.id]);
  });
  test(
      'ISRC e ID YouTube reconhecem a mesma gravação; título sem artista não basta',
      () async {
    final old = await seed([entry('a', isrc: 'USAAA1200001')]);
    var asked = 0;
    final plan = await const CollectionDuplicates().review(
        old, [entry('b', title: 'Outra grafia', isrc: 'USAAA1200001')],
        cancellation: DownloadCancellation(), choose: (_) async {
      asked++;
      return const DuplicateDecision(DuplicateChoice.existing);
    });
    expect(asked, 1);
    expect(plan.add, isEmpty);
    expect(
        CollectionDuplicates.referenceKeys(
            'https://music.youtube.com/watch?v=abcdefghijk'),
        CollectionDuplicates.referenceKeys(
            'https://www.youtube.com/watch?v=abcdefghijk'));
    final separate = await const CollectionDuplicates().review(
        [], [entry('1', artist: ''), entry('2', artist: '')],
        cancellation: DownloadCancellation(), choose: (_) async {
      fail('Não deve adivinhar artista');
    });
    expect(separate.add.length, 2);
    expect(
        (await const CollectionDuplicates().review(
                old, [entry('x', title: 'Canção (Live)')],
                cancellation: DownloadCancellation()))
            .add
            .length,
        1);
  });
  test(
      'repetições no lote pedem escolha e a última escolhida mantém sua ordem de chegada',
      () async {
    final plan = await const CollectionDuplicates().review(
        [], [entry('a'), entry('b', title: 'Outra'), entry('c')],
        cancellation: DownloadCancellation(),
        choose: (_) async => const DuplicateDecision(DuplicateChoice.incoming));
    expect(plan.add.map((e) => e.link.url),
        [entry('b').link.url, entry('c').link.url]);
    expect(plan.skipped, 1);
  });
  test('diário restaura antes do commit e termina remoção depois do commit',
      () async {
    final old = (await seed([entry('a')])).single;
    final file = await completed(old);
    final track = (await repo.trackById(old.id))!;
    final files = ReplacementMediaFiles(repo);
    await files.stage(owner, [track], DownloadCancellation());
    expect(await file.exists(), isFalse);
    await repo.database.initialize();
    expect(await files.recover(), isNull);
    expect(await file.exists(), isTrue);
    await files.stage(owner, [track], DownloadCancellation());
    await MusicLinkRepository(repo.database)
        .append(owner.id, [entry('new')], replaced: [track]);
    expect(await files.recover(), isNull);
    expect(await file.exists(), isFalse);
    expect(await File('${file.parent.path}/playlist.m3u8').readAsString(),
        isNot(contains('1.mp3')));
    expect(
        await repo.database.run(
            (db) => db.select('SELECT * FROM music_replacement_files').length),
        0);
  });
  test(
      'arquivo compartilhado e caminho fora da pasta são recusados sem alterações',
      () async {
    final old = await seed([entry('a'), entry('b', title: 'Outra')]);
    final file = await completed(old[0]);
    await repo.database.run((db) => db.execute(
        'UPDATE tracks SET local_path=? WHERE id=?', [file.path, old[1].id]));
    await expectLater(
        apply([entry('new')],
            (_) async => const DuplicateDecision(DuplicateChoice.incoming)),
        throwsFormatException);
    expect(await file.exists(), isTrue);
    await repo.database.run((db) => db
        .execute('UPDATE tracks SET local_path=? WHERE id=?', ['', old[1].id]));
    final external =
        await File('assets/demo/tone.mp3').copy('${temp.path}/original.mp3');
    await repo.setStatus(old[0].id, TrackStatus.completed,
        localPath: external.path);
    await expectLater(
        apply([entry('new')],
            (_) async => const DuplicateDecision(DuplicateChoice.incoming)),
        throwsFormatException);
    expect(await external.exists(), isTrue);
  });
  test(
      'substituição espera a faixa ativa e não inicia as novas automaticamente',
      () async {
    final old = (await seed([entry('a')])).single;
    await repo.setStatus(old.id, TrackStatus.downloading);
    final waiting = Completer<void>();
    var held = false;
    final addition = CollectionLinkAddition(repo).add(owner, [entry('new')],
        choose: (_) async => const DuplicateDecision(DuplicateChoice.incoming),
        cancellation: DownloadCancellation(),
        holdQueue: () => held = true,
        run: () => null,
        progress: (value) {
          if (value.startsWith('Aguardando') && !waiting.isCompleted) {
            waiting.complete();
          }
        });
    await waiting.future;
    expect(held, isTrue);
    expect(await repo.trackById(old.id), isNotNull);
    await completed(old);
    await addition;
    expect(await repo.trackById(old.id), isNull);
    expect((await repo.page(owner.id)).items.single.status, TrackStatus.ready);
  });
  test('migração 15 para 16 cria diário vazio sem alterar faixas', () async {
    final old = await seed([entry('a')]);
    await repo.database.run((db) {
      removePlaylistThemeSchema(db);
      db.execute('DROP TABLE music_replacement_files');
      db.execute('PRAGMA user_version=15');
    });
    await repo.database.initialize();
    expect((await repo.page(owner.id)).items.single.id, old.single.id);
    expect(
        await repo.database.run(
            (db) => db.select('SELECT * FROM music_replacement_files').length),
        0);
  });
  test('player libera arquivo substituído e mantém o restante da fila',
      () async {
    final memory = MemoryPlayerLibrary(), engine = FakeAudioEngine();
    final player = MusicPlayerController(memory, engine, PlayerFiles());
    addTearDown(player.dispose);
    await player.playCollection(1);
    final track = (await seed([entry('a')])).single;
    await player.discardTracks([track]);
    expect(player.current, isNull);
    expect(player.playing, isFalse);
    expect(player.queue.map((i) => i.id), ['track-2', 'track-3', 'track-4']);
  });
  test(
      'falha de exportação não anuncia diário de arquivo que já foi finalizado',
      () async {
    final old = (await seed([entry('a')])).single;
    final file = await completed(old);
    final track = (await repo.trackById(old.id))!;
    final files = ReplacementMediaFiles(repo);
    await files.stage(owner, [track], DownloadCancellation());
    await MusicLinkRepository(repo.database)
        .append(owner.id, [entry('new')], replaced: [track]);
    await Directory('${file.parent.path}/playlist.m3u8').create();
    final warning = await files.recover();
    expect(warning, contains('M3U8'));
    expect(warning, isNot(contains('diário')));
    expect(await file.exists(), isFalse);
    expect(
        await repo.database.run(
            (db) => db.select('SELECT * FROM music_replacement_files').length),
        0);
  });
  for (final width in [1360.0, 390.0]) {
    testWidgets('decisão explícita e Fazer para todos a ${width.toInt()}px',
        (tester) async {
      tester.view.physicalSize = Size(width, 820);
      tester.view.devicePixelRatio = 1;
      final output = Platform.environment['DD_LAYOUT_OUTPUT'];
      if (output != null) {
        await (FontLoader('Manrope')
              ..addFont(rootBundle.load('assets/fonts/Manrope.ttf')))
            .load();
        await (FontLoader('MaterialIcons')
              ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
            .load();
      }
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final old = await tester.runAsync(() => seed([entry('a')]));
      DuplicateDecision? result;
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
              theme: appTheme(),
              home: Builder(
                  builder: (context) => Scaffold(
                      body: TextButton(
                          onPressed: () async {
                            result = await chooseDuplicateMusic(
                                context,
                                DuplicateConflict(
                                    [DuplicateVersion(old!.single)],
                                    entry('new'),
                                    1,
                                    3));
                          },
                          child: const Text('Abrir')))))));
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<FilledButton>(
                  find.byKey(const ValueKey('duplicates-confirm')))
              .onPressed,
          isNull);
      await tester.tap(find.byKey(const ValueKey('duplicates-incoming')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('duplicates-all')));
      await tester.tap(find.byKey(const ValueKey('duplicates-all')));
      await tester.pumpAndSettle();
      if (output != null) {
        final boundary = boundaryKey.currentContext!.findRenderObject()
            as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory(output).create(recursive: true);
          await File('$output/duplicates-${width.toInt()}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.tap(find.byKey(const ValueKey('duplicates-confirm')));
      await tester.pumpAndSettle();
      expect(result!.choice, DuplicateChoice.incoming);
      expect(result!.forAll, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}

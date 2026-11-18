import 'dart:io';
import 'dart:convert';
import 'dart:typed_data' show Endian;
import 'package:media_kit/media_kit.dart' as mk;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'package:definitive_downloader/core/network/bounded_http.dart';
import 'package:definitive_downloader/core/platform/desktop_files.dart';
import 'package:definitive_downloader/core/storage/database.dart';
import 'package:definitive_downloader/features/downloads/download_service.dart';
import 'package:definitive_downloader/features/importing/csv_importer.dart';
import 'package:definitive_downloader/features/importing/collection_link_composer.dart';
import 'package:definitive_downloader/features/importing/music_link_catalog.dart';
import 'package:definitive_downloader/features/importing/music_link_service.dart';
import 'package:definitive_downloader/features/importing/music_link_repository.dart';
import 'package:definitive_downloader/features/importing/playlist_catalog.dart';
import 'package:definitive_downloader/features/importing/soundcloud_catalog.dart';
import 'package:definitive_downloader/features/importing/youtube_playlist_catalog.dart';
import 'package:definitive_downloader/features/importing/public_playlist_link.dart';
import 'package:definitive_downloader/features/importing/local_media_importer.dart';
import 'package:definitive_downloader/features/importing/local_mp3_inspector.dart';
import 'package:definitive_downloader/features/library/data/library_repository.dart';
import 'package:definitive_downloader/features/library/domain/models.dart';
import 'package:definitive_downloader/features/library/application/library_controller.dart';
import 'package:definitive_downloader/features/matching/deezer_catalog.dart';
import 'package:definitive_downloader/features/player/data/player_library.dart';
import 'package:definitive_downloader/features/player/data/audio_tags.dart';
import 'package:definitive_downloader/features/organization/data/collection_organization_repository.dart';
import 'package:definitive_downloader/features/workspace/data/workspace_repository.dart';
import 'playlist_matching_test.dart' show FixturePlaylist;

TrackDraft manual(int n) => TrackDraft(
    title: 'Canção $n',
    artist: 'Pessoa',
    durationMs: 180000,
    sourceKind: SourceKind.youtube,
    sourceUrl: 'https://www.youtube.com/watch?v=abcdefghijk',
    mediaUrl: 'https://www.youtube.com/watch?v=abcdefghijk',
    manualUrl: 'https://www.youtube.com/watch?v=abcdefghijk');

class PlaylistsFixture extends PlaylistCatalog {
  PlaylistsFixture(this.rows)
      : super(spotify: FixturePlaylist([]), soundcloud: SoundCloudCatalog());
  final List<TrackDraft> rows;
  @override
  Future<ImportedCollection> read(String url,
          {bool Function()? cancelled,
          void Function(int, int)? onProgress}) async =>
      ImportedCollection(
          name: 'Origem',
          source: 'YouTube',
          sourceUrl: url,
          tracks: Stream.fromIterable(rows));
}

class YouTubeFixture extends YouTubePlaylistCatalog {
  YouTubeFixture({this.fail = false});
  final bool fail;
  @override
  Future<ImportedCollection> open(PublicPlaylistLink link,
      {bool downloadAvailable = false,
      bool Function()? cancelled,
      void Function(int, int)? onProgress}) async {
    if (fail) throw const FormatException('Lista indisponível');
    return ImportedCollection(
        name: 'Nome de origem',
        source: 'YouTube',
        sourceUrl: link.url,
        tracks: Stream.fromIterable([manual(1), manual(1)]));
  }
}

class LocalInspectorFixture implements LocalAudioInspector {
  LocalInspectorFixture({this.failAt});
  final int? failAt;
  int calls = 0;
  @override
  Future<LocalAudioMetadata> inspect(String path) async {
    if (++calls == failAt) throw const FormatException('MP3 inválido');
    return const LocalAudioMetadata(
        title: 'Canção local',
        artist: 'Pessoa',
        album: 'Pasta',
        durationMs: 4000);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  late LibraryRepository repo;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('dd-composition-');
    repo = LibraryRepository(AppDatabase('${temp.path}/library.db'));
    await repo.database.initialize();
  });
  tearDown(() => temp.delete(recursive: true));
  LibraryController controller(
      {bool fail = false, LocalAudioInspector? localInspector}) {
    final c = LibraryController(
        repository: repo,
        files: DesktopFiles(),
        spotify: FixturePlaylist([]),
        youtubePlaylists: YouTubeFixture(fail: fail),
        csv: const CsvImporter(),
        catalog: const DeezerCatalog(BoundedHttp()),
        downloader: DownloadService(const BoundedHttp(), rootBundle),
        localInspector: localInspector ?? LocalInspectorFixture());
    c.outputDirectory = '${temp.path}/output';
    addTearDown(c.dispose);
    return c;
  }

  test(
      'cria vazia ou composta com nome escolhido; falha não deixa playlist extra',
      () async {
    expect(
        PlaylistCatalog.isCollection(
            'https://www.youtube.com/watch?v=abcdefghijk'),
        isFalse);
    expect(
        PlaylistCatalog.isCollection(
            'https://www.youtube.com/watch?v=abcdefghijk&list=PL1234567890123456'),
        isTrue);
    final c = controller();
    final empty = await c.createPlaylist('Minha lista');
    expect((await repo.collectionById(empty))!.trackCount, 0);
    final filled = await c.createPlaylist('Super lista',
        link:
            'https://www.youtube.com/watch?v=abcdefghijk&list=PL1234567890123456');
    expect((await repo.collectionById(filled))!.name, 'Super lista');
    expect((await repo.page(filled)).items.map((t) => t.title),
        ['Canção 1', 'Canção 1']);
    await expectLater(
        controller(fail: true).createPlaylist('Falha',
            link: 'https://www.youtube.com/playlist?list=PL1234567890123456'),
        throwsFormatException);
    expect((await repo.collections()).length, 2);
  });

  test('grupo criado pela playlist inclui só aquela coleção e é atômico',
      () async {
    final organization = CollectionOrganizationRepository(repo.database);
    final a = await organization.create('A'),
        b = await organization.create('B');
    await organization.saveGroup('Grupo', collectionId: a);
    expect((await repo.collectionById(a))!.groupId,
        (await organization.groups()).single.id);
    expect((await repo.collectionById(b))!.groupId, isNull);
    await expectLater(organization.saveGroup('Inválido', collectionId: 999),
        throwsFormatException);
    expect((await organization.groups()).length, 1);
  });

  test('lote misto expande listas na ordem e conserva duplicatas e MP3 direto',
      () async {
    final composer = CollectionLinkComposer(
        PlaylistsFixture([manual(1), manual(2), manual(1)]),
        const MusicLinkService(MusicLinkCatalog(), null));
    final links = await composer.resolve(
        'https://www.deezer.com/playlist/1\nhttps://example.org/audio.mp3\nhttps://www.youtube.com/playlist?list=PL1234567890123456',
        capacity: 10000,
        cancellation: DownloadCancellation());
    expect(links.map((e) => e.draft.title), [
      'Canção 1',
      'Canção 2',
      'Canção 1',
      'audio',
      'Canção 1',
      'Canção 2',
      'Canção 1'
    ]);
    expect(links.first.pinned, isTrue);
    expect(links.first.ready, isFalse);
    expect(links[3].ready, isTrue);
    await expectLater(
        composer.resolve('https://www.deezer.com/playlist/1',
            capacity: 2, cancellation: DownloadCancellation()),
        throwsFormatException);
  });

  test('cancelamento da expansão não grava parte do lote', () async {
    final token = DownloadCancellation();
    final composer = CollectionLinkComposer(PlaylistsFixture([manual(1)]),
        const MusicLinkService(MusicLinkCatalog(), null));
    await expectLater(
        composer.resolve('https://www.deezer.com/playlist/1',
            capacity: 10000,
            cancellation: token,
            onProgress: (_) => token.cancelled = true),
        throwsA(isA<DownloadCancelled>()));
    expect(await repo.collections(), isEmpty);
  });

  test('playlist expandida com mais de vinte faixas entra ao final da execução',
      () async {
    final owner =
        await CollectionOrganizationRepository(repo.database).create('Fila');
    final composer = CollectionLinkComposer(
        PlaylistsFixture(List.generate(25, manual)),
        const MusicLinkService(MusicLinkCatalog(), null));
    final links = await composer.resolve(
        'https://www.youtube.com/playlist?list=PL1234567890123456',
        capacity: 10000,
        cancellation: DownloadCancellation());
    final ready =
        links.map((e) => e.prepared(source: e.source, ready: true)).toList();
    final queue = WorkspaceRepository(repo.database);
    await queue.beginRun(run: 'active', collectionId: owner);
    await MusicLinkRepository(repo.database)
        .append(owner, ready, run: 'active');
    final first = await queue.claimNext(
        run: 'active', snapshot: true, collectionId: owner);
    expect(first!.position, 1);
    expect(first.sourceAuthorization, SourceAuthorization.manualLink);
    expect((await repo.page(owner)).total, 25);
  });

  Future<File> original() async =>
      File('assets/demo/tone.mp3').copy('${temp.path}/original.mp3');
  test(
      'MP3s são cópias numeradas ao final, com player e histórico; original permanece idêntico',
      () async {
    final owner = await repo.importCollection(ImportedCollection(
        name: 'Minha lista',
        source: 'Local',
        sourceUrl: '',
        tracks: Stream.fromIterable(
            [const TrackDraft(title: 'Pendente', artist: 'Pessoa')])));
    final input = await original();
    final before = sha256.convert(await input.readAsBytes()).toString();
    await validateMp3Frames(input.path);
    await LocalMediaImporter(repo, inspector: LocalInspectorFixture()).add(
        owner, [input.path, input.path], '${temp.path}/output',
        cancellation: DownloadCancellation());
    final tracks = (await repo.page(owner)).items;
    expect(tracks.map((t) => t.position), [1, 2, 3]);
    expect(tracks[1].status, TrackStatus.completed);
    expect((await repo.collectionById(owner))!.editingLocked, isTrue);
    expect(tracks[1].sourceKind, SourceKind.localFile);
    expect(tracks[1].localPath, contains('002 - Canção local - Pessoa.mp3'));
    expect(tracks[2].localPath, contains('003 - Canção local - Pessoa.mp3'));
    expect(
        sha256
            .convert(await File(tracks[1].localPath).readAsBytes())
            .toString(),
        before);
    expect(sha256.convert(await input.readAsBytes()).toString(), before);
    expect((await PlayerLibrary(repo.database).collection(owner)).length, 2);
    expect(
        await repo.database.run((db) => db
            .select('SELECT COUNT(*) AS n FROM download_history')
            .single['n']),
        2);
    final playlist =
        await File('${File(tracks[1].localPath).parent.path}/playlist.m3u8')
            .readAsString();
    expect(playlist.indexOf('002 -'), lessThan(playlist.indexOf('003 -')));
  });

  test(
      'colisão não sobrescreve mídia existente; erro de inspeção desfaz somente o lote novo',
      () async {
    final owner =
        await CollectionOrganizationRepository(repo.database).create('Lista');
    final input = await original();
    final folder = await Directory('${temp.path}/output/Lista [$owner]')
        .create(recursive: true);
    final existing =
        await File('${folder.path}/001 - Canção local - Pessoa.mp3')
            .writeAsString('não alterar');
    await expectLater(
        LocalMediaImporter(repo, inspector: LocalInspectorFixture(failAt: 2))
            .add(owner, [input.path, input.path], '${temp.path}/output',
                cancellation: DownloadCancellation()),
        throwsFormatException);
    expect((await repo.page(owner)).total, 0);
    expect(await existing.readAsString(), 'não alterar');
    await LocalMediaImporter(repo, inspector: LocalInspectorFixture()).add(
        owner, [input.path], '${temp.path}/output',
        cancellation: DownloadCancellation());
    final track = (await repo.page(owner)).items.single;
    expect(track.localPath, isNot(existing.path));
    expect(await existing.readAsString(), 'não alterar');
    expect((await folder.list().toList()).whereType<Directory>(), isEmpty);
  });

  test('MP3 truncado e arquivo disfarçado são recusados', () async {
    final input = await original();
    final bytes = await input.readAsBytes();
    final broken = await File('${temp.path}/broken.mp3')
        .writeAsBytes(bytes.take(bytes.length - 15).toList());
    await expectLater(validateMp3Frames(broken.path), throwsFormatException);
    final fake = await File('${temp.path}/fake.mp3').writeAsString('x' * 500);
    await expectLater(validateMp3Frames(fake.path), throwsFormatException);
  });

  test(
      'cancelar cópia preserva original e não deixa registros nem arquivos parciais',
      () async {
    final owner = await CollectionOrganizationRepository(repo.database)
        .create('Cancelada');
    final input = await original();
    final token = DownloadCancellation();
    await expectLater(
        LocalMediaImporter(repo, inspector: LocalInspectorFixture()).add(
            owner, [input.path], '${temp.path}/output',
            cancellation: token, onProgress: (_) => token.cancelled = true),
        throwsA(isA<DownloadCancelled>()));
    expect((await repo.page(owner)).total, 0);
    expect(await input.exists(), isTrue);
    final files =
        await Directory('${temp.path}/output').list(recursive: true).toList();
    expect(files.whereType<File>(), isEmpty);
    expect(
        files.whereType<Directory>().any((d) => d.path.contains('.dd-local-')),
        isFalse);
  });

  test(
      'MP3 local pode entrar durante a execução sem alterar a faixa em andamento',
      () async {
    final c = controller();
    final owner = await CollectionOrganizationRepository(repo.database)
        .create('Em execução');
    final composer = CollectionLinkComposer(PlaylistsFixture([manual(1)]),
        const MusicLinkService(MusicLinkCatalog(), null));
    final ready = (await composer.resolve(
            'https://www.youtube.com/playlist?list=PL1234567890123456',
            capacity: 10000,
            cancellation: DownloadCancellation()))
        .map((e) => e.prepared(source: e.source, ready: true))
        .toList();
    await MusicLinkRepository(repo.database).append(owner, ready);
    final queue = WorkspaceRepository(repo.database);
    await queue.beginRun(run: 'copy-during-run', collectionId: owner);
    final active = await queue.claimNext(
        run: 'copy-during-run', snapshot: true, collectionId: owner);
    c.downloading = true;
    final input = await original();
    expect(await c.addLocalFiles(owner, [input.path]), isTrue);
    final tracks = (await repo.page(owner)).items;
    expect(tracks.map((t) => t.position), [1, 2]);
    expect(tracks.first.id, active!.id);
    expect(tracks.first.status, TrackStatus.downloading);
    expect(tracks.last.status, TrackStatus.completed);
    expect(
        await queue.claimNext(
            run: 'copy-during-run', snapshot: true, collectionId: owner),
        isNull);
  });

  test(
      'cópia e sondagem reais com decoder nativo, sem tocar na biblioteca do usuário',
      () async {
    mk.MediaKit.ensureInitialized(
        libmpv: Platform.environment['DD_LOCAL_REAL_DLL']);
    final output =
        await Directory(Platform.environment['DD_LOCAL_REAL_OUTPUT']!)
            .create(recursive: true);
    final directory = await output.createTemp('native-');
    final privateRepo =
        LibraryRepository(AppDatabase('${directory.path}/library.db'));
    await privateRepo.database.initialize();
    final owner = await CollectionOrganizationRepository(privateRepo.database)
        .create('MP3 locais');
    final supplied = Platform.environment['DD_LOCAL_REAL_INPUT'];
    final input = supplied == null
        ? await original()
        : await File(supplied).copy('${temp.path}/tagged.mp3');
    final digest = sha256.convert(await input.readAsBytes()).toString();
    final result = await LocalMediaImporter(privateRepo).add(
        owner, [input.path, input.path], directory.path,
        cancellation: DownloadCancellation());
    final copies = (await privateRepo.page(owner)).items;
    expect(copies.length, 2);
    for (final copy in copies) {
      expect(copy.durationMs, greaterThan(3500));
      expect(
          sha256.convert(await File(copy.localPath).readAsBytes()).toString(),
          digest);
    }
    expect(sha256.convert(await input.readAsBytes()).toString(), digest);
    if (supplied != null) {
      expect(copies.first.artist, isNotEmpty);
      expect((await readAudioTags(copies.first.localPath)).cover, isNotNull);
    }
    final folder = await Directory('${temp.path}/Áudios mistos').create();
    await input.copy('${folder.path}/01 - MP3.mp3');
    final wav = ByteData(44 + 16000)
      ..setUint32(0, 0x52494646)
      ..setUint32(4, 16036, Endian.little)
      ..setUint32(8, 0x57415645)
      ..setUint32(12, 0x666D7420)
      ..setUint32(16, 16, Endian.little)
      ..setUint16(20, 1, Endian.little)
      ..setUint16(22, 1, Endian.little)
      ..setUint32(24, 8000, Endian.little)
      ..setUint32(28, 16000, Endian.little)
      ..setUint16(32, 2, Endian.little)
      ..setUint16(34, 16, Endian.little)
      ..setUint32(36, 0x64617461)
      ..setUint32(40, 16000, Endian.little);
    final nested = await Directory('${folder.path}/Subpasta').create();
    await File('${nested.path}/02 - Piano.wav')
        .writeAsBytes(wav.buffer.asUint8List());
    await File('${folder.path}/Notas.txt').writeAsString('material de ensaio');
    final mixed = await LocalMediaImporter(privateRepo).importFolder(
        folder.path, directory.path,
        cancellation: DownloadCancellation());
    final imported = (await privateRepo.collectionById(mixed.id))!;
    expect(imported.name, 'Áudios mistos');
    expect(imported.isPartial, isFalse);
    final tracks = (await privateRepo.page(mixed.id)).items;
    expect(tracks.map((t) => t.localPath.split('.').last), ['mp3', 'wav']);
    expect(tracks.last.title, 'Piano');
    expect(tracks.last.durationMs, closeTo(1000, 100));
    expect(await File(tracks.last.localPath).readAsBytes(),
        wav.buffer.asUint8List());
    expect(
        (await PlayerLibrary(privateRepo.database).collection(mixed.id)).length,
        2);
    await File('${directory.path}/result.json').writeAsString(jsonEncode({
      'result': result,
      'count': copies.length,
      'durationMs': copies.first.durationMs,
      'sourceSha256': digest,
      'paths': copies.map((t) => t.localPath).toList(),
      'title': copies.first.title,
      'artist': copies.first.artist,
      'originalUnchanged': true,
      'playableItems':
          (await PlayerLibrary(privateRepo.database).collection(owner)).length
    }));
  },
      skip: Platform.environment['DD_LOCAL_REAL_DLL'] == null,
      timeout: const Timeout(Duration(minutes: 1)));
}

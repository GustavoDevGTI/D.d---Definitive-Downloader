import 'dart:io';
import 'package:definitive_downloader/features/downloads/download_service.dart';
import 'package:definitive_downloader/features/matching/music_engine.dart';
import 'package:definitive_downloader/features/matching/music_resolver.dart';
import 'package:definitive_downloader/features/connections/application/deezer_connection_controller.dart';
import 'music_resolver_test.dart' show EmptySession, EmptyEngine;
import 'package:flutter_test/flutter_test.dart';
import 'package:definitive_downloader/core/storage/database.dart';
import 'package:definitive_downloader/features/importing/music_link.dart';
import 'package:definitive_downloader/features/importing/music_link_catalog.dart';
import 'package:definitive_downloader/features/importing/music_catalog_transport.dart';
import 'package:definitive_downloader/features/importing/music_link_repository.dart';
import 'package:definitive_downloader/features/importing/music_link_service.dart';
import 'package:definitive_downloader/features/importing/spotify_account_importer.dart';
import 'package:definitive_downloader/features/library/data/library_repository.dart';
import 'package:definitive_downloader/features/library/domain/models.dart';
import 'package:definitive_downloader/features/workspace/data/workspace_repository.dart';
import 'package:definitive_downloader/features/workspace/domain/workspace_models.dart';
import 'package:definitive_downloader/features/workspace/domain/download_columns.dart';

class FixtureCatalogTransport implements MusicCatalogTransport {
  FixtureCatalogTransport(this.response);
  final Map<String, dynamic> response;
  @override
  Future<Map<String, dynamic>> read(Uri uri,
          {Map<String, Object?>? body}) async =>
      response;
}

class LinkSearchEngine implements MusicEngine {
  final providers = <String>[];
  @override
  bool get available => true;
  @override
  Future<Map<String, dynamic>> call(Map<String, dynamic> request,
      {DownloadCancellation? cancellation,
      void Function(String)? onStage}) async {
    providers.add(request['provider'] as String);
    return {
      'candidates': request['provider'] != 'youtubeMusic'
          ? []
          : [
              for (final title in ['Outra canção', 'Canção'])
                {
                  'kind': 'youtubeMusic',
                  'title': title,
                  'artist': 'Pessoa',
                  'album': 'Álbum',
                  'durationMs': 180000,
                  'pageUrl':
                      'https://music.youtube.com/watch?v=${title == 'Canção' ? 'abcdefghijk' : '01234567890'}',
                  'recordingType': 'MUSIC_VIDEO_TYPE_ATV',
                  'coverUrl': '',
                  'isrc': '',
                }
            ]
    };
  }
}

void main() {
  test('links canônicos descartam rastreamento e preservam repetições', () {
    final links = MusicLink.batch(
        'https://open.spotify.com/intl-pt/track/0123456789012345678901?si=tracking\nspotify:track:0123456789012345678901\nhttps://www.deezer.com/br/track/123?utm=x\nhttps://music.youtube.com/watch?v=abcdefghijk&list=not-persisted\nhttps://example.org/audio.mp3');
    expect(links.length, 5);
    expect(links[0].url, links[1].url);
    expect(links[2].url, 'https://www.deezer.com/track/123');
    expect(links[3].url, 'https://music.youtube.com/watch?v=abcdefghijk');
    for (final value in [
      'file:///C:/music.mp3',
      'https://user:secret@example.org/a.mp3',
      'https://example.org/a.mp3?token=private',
      'https://music.youtube.com.evil.org/watch?v=abcdefghijk',
      'https://open.spotify.com/playlist/0123456789012345678901',
      'https://www.youtube.com/watch?v=bad'
    ]) {
      expect(() => MusicLink.parse(value), throwsFormatException);
    }
    expect(
        () => MusicLink.batch(
            List.filled(21, 'https://example.org/a.mp3').join('\n')),
        throwsFormatException);
  });

  test('catalogação musical exige identidade, disponibilidade e tipo ATV',
      () async {
    final row = <String, dynamic>{
      'videoDetails': <String, dynamic>{
        'videoId': 'abcdefghijk',
        'musicVideoType': 'MUSIC_VIDEO_TYPE_ATV',
        'title': 'Canção',
        'author': 'Pessoa - Topic',
        'lengthSeconds': '180'
      },
      'playabilityStatus': {'status': 'OK'}
    };
    final catalog = MusicLinkCatalog(transport: FixtureCatalogTransport(row));
    final link =
        MusicLink.parse('https://music.youtube.com/watch?v=abcdefghijk');
    final result = await catalog.resolve(link);
    expect(result.source!.isFullRecording, isTrue);
    expect(result.pinned, isTrue);
    expect(result.draft.artist, 'Pessoa');
    row['videoDetails']['musicVideoType'] = 'MUSIC_VIDEO_TYPE_OMV';
    expect((await catalog.resolve(link)).source!.kind, SourceKind.youtube);
    row['videoDetails']['musicVideoType'] = 'MUSIC_VIDEO_TYPE_ATV';
    row['videoDetails']['isLive'] = true;
    await expectLater(catalog.resolve(link), throwsFormatException);
    row['videoDetails']['isLive'] = false;
    row['videoDetails']['videoId'] = '01234567890';
    await expectLater(catalog.resolve(link), throwsFormatException);
  });

  test(
      'Deezer manual aguarda conexão/motor; Spotify mantém metadados sem URL de áudio',
      () async {
    final deezer = MusicLinkCatalog(
        transport: FixtureCatalogTransport({
      'id': 123,
      'type': 'track',
      'title': 'Canção',
      'duration': 180,
      'artist': {'name': 'Pessoa'},
      'album': {'title': 'Álbum'},
      'readable': true,
    }));
    final manual = (await MusicLinkService(deezer, null)
            .resolve('https://deezer.com/track/123'))
        .single;
    expect(manual.source!.kind, SourceKind.deezerFull);
    expect(manual.ready, isFalse);
    expect(manual.pinned, isTrue);
    final spotify = SpotifyAccountImporter(
        (path, {query = const {}}) async => {
              'id': '0123456789012345678901',
              'type': 'track',
              'name': 'Canção',
              'duration_ms': 180000,
              'artists': [
                {'name': 'Pessoa'}
              ],
              'album': {'name': 'Álbum'},
            },
        () => true);
    final requested =
        (await MusicLinkService(MusicLinkCatalog(spotify: spotify), null)
                .resolve('spotify:track:0123456789012345678901'))
            .single;
    expect(requested.ready, isFalse);
    expect(requested.pinned, isFalse);
    expect(requested.draft.title, 'Canção');
    expect(requested.draft.mediaUrl, isEmpty);
    expect(requested.source, isNull);
  });

  test(
      'Spotify consulta alternativas e escolhe pela correspondência, não pelo primeiro resultado',
      () async {
    final engine = LinkSearchEngine();
    final connection = DeezerConnectionController(EmptySession(), engine);
    try {
      final spotify = SpotifyAccountImporter(
          (path, {query = const {}}) async => {
                'id': '0123456789012345678901',
                'type': 'track',
                'name': 'Canção',
                'duration_ms': 180000,
                'artists': [
                  {'name': 'Pessoa'}
                ],
                'album': {'name': 'Álbum'},
              },
          () => true);
      final entries = await MusicLinkService(MusicLinkCatalog(spotify: spotify),
              MusicResolver(engine, connection))
          .resolve('spotify:track:0123456789012345678901');
      expect(engine.providers, ['deezerFull', 'youtubeMusic']);
      expect(entries.single.source!.title, 'Canção');
      expect(entries.single.source!.kind, SourceKind.youtubeMusic);
      expect(entries.single.ready, isTrue);
      expect(entries.single.pinned, isFalse);
      expect(entries.single.alternatives.length, 2);
    } finally {
      connection.dispose();
    }
  });

  test(
      'YouTube normal, link curto e tipo ausente usam escolha manual sem matching ou aprovação',
      () async {
    final engine = EmptyEngine();
    final connection = DeezerConnectionController(EmptySession(), engine);
    final transport = FixtureCatalogTransport({
      'videoDetails': {
        'videoId': 'abcdefghijk',
        'title': 'Meu áudio',
        'author': 'Pessoa',
        'lengthSeconds': '180'
      },
      'playabilityStatus': {'status': 'OK'}
    });
    try {
      final service = MusicLinkService(MusicLinkCatalog(transport: transport),
          MusicResolver(engine, connection));
      for (final url in [
        'https://youtu.be/abcdefghijk?si=tracking',
        'https://www.youtube.com/watch?v=abcdefghijk',
        'https://music.youtube.com/watch?v=abcdefghijk'
      ]) {
        final entry = (await service.resolve(url)).single;
        expect(entry.source!.kind, SourceKind.youtube);
        expect(entry.source!.pageUrl,
            'https://www.youtube.com/watch?v=abcdefghijk');
        expect(entry.pinned, isTrue);
        expect(entry.ready, isTrue);
      }
      expect(MusicLink.fromIdentifier(MusicLinkKind.youtube, 'abcdefghijk').url,
          'https://www.youtube.com/watch?v=abcdefghijk');
      expect(
          MusicLink.fromIdentifier(
                  MusicLinkKind.spotify, '0123456789012345678901')
              .kind,
          MusicLinkKind.spotify);
    } finally {
      connection.dispose();
    }
  });

  group('persistência de extras, pesquisa e colunas', () {
    late Directory temp;
    late LibraryRepository library;
    late WorkspaceRepository queue;
    late int collectionId;
    setUp(() async {
      temp = await Directory.systemTemp.createTemp('dd-extras-');
      library = LibraryRepository(AppDatabase('${temp.path}/library.db'));
      await library.database.initialize();
      queue = WorkspaceRepository(library.database);
      collectionId = await library.importCollection(ImportedCollection(
          name: 'Coleção longa',
          source: 'Fixture',
          sourceUrl: '',
          tracks: Stream.fromIterable(List.generate(
              42,
              (i) => TrackDraft(
                  title: 'Faixa $i',
                  artist: 'Pessoa',
                  sourceKind: SourceKind.directMp3,
                  mediaUrl: 'https://example.org/$i.mp3')))));
    });
    tearDown(() => temp.delete(recursive: true));
    test(
        'migração v7 preserva ocorrências e acrescenta apenas controle de extras',
        () async {
      await library.database.run((db) {
        db.execute('ALTER TABLE collections DROP COLUMN editing_locked');
        for (final column in [
          'custom_title',
          'recording_type',
          'source_authorization'
        ]) {
          db.execute('ALTER TABLE tracks DROP COLUMN $column');
        }
        db.execute('DROP TABLE download_run_additions');
        db.execute('ALTER TABLE tracks DROP COLUMN queue_added');
        db.execute('PRAGMA user_version=7');
      });
      await library.database.initialize();
      expect((await library.page(collectionId)).total, 42);
      expect(
          await library.database
              .run((db) => db.select('PRAGMA user_version').first.values.first),
          9);
      expect(
          await library.database
              .run((db) => db.select('PRAGMA quick_check').first.values.first),
          'ok');
    });
    test(
        'busca consulta todas as páginas e limites de colunas sobrevivem ao reinício',
        () async {
      expect((await queue.downloads(ContentCategory.music)).items.length, 40);
      final page =
          await queue.downloads(ContentCategory.music, query: 'Faixa 41');
      expect(page.total, 1);
      expect(page.items.single.track.position, 42);
      expect(
          (await queue.downloads(ContentCategory.music, query: 'Coleção longa'))
              .total,
          42);
      expect(
          (await queue.downloads(ContentCategory.music, query: 'MP3 vinculado'))
              .total,
          42);
      expect(
          (await queue.downloads(ContentCategory.music, query: "' OR 1=1 --"))
              .total,
          0);
      final widths = downloadColumns.map((c) => c.width).toList()
        ..[1] = 950
        ..[2] = 0
        ..[3] = 99999;
      await queue.saveColumnWidths(widths);
      final saved =
          await WorkspaceRepository(AppDatabase(library.database.path))
              .columnWidths();
      expect(saved[1], 950);
      expect(saved[2], downloadColumns[2].minimum);
      expect(saved[3], 1200);
    });
    test(
        'lote atômico preserva duplicatas e pendentes visíveis sem habilitar download',
        () async {
      final catalog = const MusicLinkCatalog();
      final entry = await catalog
          .resolve(MusicLink.parse('https://example.org/extra.mp3'));
      final pending = ResolvedMusicLink(
          link: MusicLink.parse('spotify:track:0123456789012345678901'),
          draft: const TrackDraft(title: 'Pendente', artist: 'Pessoa'));
      final ids = await MusicLinkRepository(library.database)
          .append(collectionId, [entry, entry, pending]);
      expect(ids.toSet().length, 3);
      final page = await library.page(collectionId, offset: 40);
      expect(page.items.map((t) => t.position), [41, 42, 43, 44, 45]);
      expect(page.items[2].manualUrl, 'https://example.org/extra.mp3');
      expect(page.items.last.canDownload, isFalse);
      expect(
          (await queue.downloads(ContentCategory.music, query: 'Pendente'))
              .total,
          1);
      final invalid = ResolvedMusicLink(
          link: entry.link, draft: const TrackDraft(title: '', artist: ''));
      await expectLater(
          MusicLinkRepository(library.database)
              .append(collectionId, [entry, invalid]),
          throwsFormatException);
      expect((await library.page(collectionId)).total, 45);
      await library.database.initialize();
      expect((await library.trackById(ids.first))!.hasManualSource, isTrue);
    });
    test(
        'extras entram após seleção inicial mesmo com prioridade maior; pendentes não são reivindicados',
        () async {
      final rows = (await library.page(collectionId)).items;
      final entry = await const MusicLinkCatalog()
          .resolve(MusicLink.parse('https://example.org/extra.mp3'));
      final ids = await MusicLinkRepository(library.database)
          .append(collectionId, [entry, entry], run: 'active');
      await queue.changePriority([ids[0]], 1);
      final initial = await queue.claimNext(run: 'active', ids: [rows[1].id]);
      expect(initial!.id, rows[1].id);
      expect((await queue.claimNext(run: 'active', ids: [rows[1].id]))!.id,
          ids[0]);
      expect((await queue.claimNext(run: 'active', ids: [rows[1].id]))!.id,
          ids[1]);
      expect(await queue.claimNext(run: 'active', ids: [rows[1].id]), isNull);
      await queue.finishRun('active');
      expect(
          await library.database.run((db) => db
              .select('SELECT COUNT(*) AS n FROM download_run_additions')
              .first['n']),
          0);
    });
  });
}

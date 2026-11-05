import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:definitive_downloader/core/storage/database.dart';
import 'package:definitive_downloader/features/importing/soundcloud_catalog.dart';
import 'package:definitive_downloader/features/importing/soundcloud_link.dart';
import 'package:definitive_downloader/features/importing/soundcloud_transport.dart';
import 'package:definitive_downloader/features/importing/music_link.dart';
import 'package:definitive_downloader/features/importing/music_link_catalog.dart';
import 'package:definitive_downloader/features/importing/music_link_service.dart';
import 'package:definitive_downloader/features/importing/music_link_repository.dart';
import 'package:definitive_downloader/features/library/data/library_repository.dart';
import 'package:definitive_downloader/features/library/domain/models.dart';
import 'package:definitive_downloader/features/library/domain/matching.dart';
import 'package:definitive_downloader/features/matching/music_resolver.dart';
import 'package:definitive_downloader/features/connections/application/deezer_connection_controller.dart';
import 'package:definitive_downloader/features/player/data/player_library.dart';
import 'music_link_test.dart' show LinkSearchEngine;
import 'music_resolver_test.dart' show EmptySession;

Map<String, dynamic> sound(int id, {bool artist = true}) => {
      'id': id,
      'title': 'Canção',
      'kind': 'track',
      'public': true,
      'permalink_url': 'https://soundcloud.com/pessoa/cancao-$id',
      'full_duration': 180000,
      'duration': 180000,
      'policy': 'ALLOW',
      'streamable': true,
      'media': {
        'transcodings': [
          {
            'url': 'https://api-v2.soundcloud.com/media/test',
            'format': {'protocol': 'hls'}
          }
        ]
      },
      'artwork_url': 'https://i1.sndcdn.com/cover.jpg',
      'user': {'username': 'Uploader diferente'},
      'publisher_metadata': artist ? {'artist': 'Pessoa'} : null,
    };

class FixtureSoundCloud implements SoundCloudTransport {
  FixtureSoundCloud(this.row, {this.omit = const {}});
  final Map<String, dynamic> row;
  final Set<int> omit;
  final calls = <Uri>[];
  String? body;
  @override
  Future<SoundCloudResponse> get(Uri url, {required int maximumBytes}) async {
    calls.add(url);
    if (url.host == 'a-v2.sndcdn.com') {
      return SoundCloudResponse(url, 'client_id:"${'x' * 32}"');
    }
    if (url.host == 'api-v2.soundcloud.com') {
      final ids = url.queryParameters['ids']!
          .split(',')
          .map(int.parse)
          .toList()
          .reversed;
      return SoundCloudResponse(
          url,
          jsonEncode([
            for (final id in ids)
              if (!omit.contains(id)) sound(id)
          ]));
    }
    final canonical = Uri.parse(row['permalink_url'] as String);
    return SoundCloudResponse(
        canonical,
        body ??
            '<script src="https://a-v2.sndcdn.com/assets/app.js"></script><script>window.__sc_hydration = ${jsonEncode([
                  {
                    'hydratable':
                        row['kind'] == 'playlist' ? 'playlist' : 'sound',
                    'data': row
                  }
                ])};</script>');
  }
}

void main() {
  test(
      'links públicos distinguem faixa, playlist e curto; rejeitam segredos e destinos falsos',
      () {
    expect(
        MusicLink.parse('https://m.soundcloud.com/pessoa/cancao-1?si=tracking')
            .url,
        'https://soundcloud.com/pessoa/cancao-1');
    expect(
        SoundCloudLink.parse('https://soundcloud.com/pessoa/sets/mix').resource,
        SoundCloudResource.playlist);
    expect(MusicLink.parse('https://on.soundcloud.com/Abc').kind,
        MusicLinkKind.soundcloud);
    for (final bad in [
      'https://soundcloud.com.evil.org/pessoa/cancao',
      'http://soundcloud.com/pessoa/cancao',
      'https://user:pass@soundcloud.com/pessoa/cancao',
      'https://soundcloud.com/pessoa/cancao/s-private',
      'https://soundcloud.com/pessoa/cancao?secret_token=private',
      'https://soundcloud.com/pessoa/likes',
      'https://soundcloud.com/pessoa/cancao.mp3'
    ]) {
      expect(() => SoundCloudLink.parse(bad), throwsFormatException,
          reason: bad);
    }
    expect(() => MusicLink.parse('https://soundcloud.com/pessoa/sets/mix'),
        throwsFormatException);
    expect(publicReference('https://soundcloud.com/pessoa/cancao-1?si=x'),
        'https://soundcloud.com/pessoa/cancao-1');
    expect(
        publicReference('https://soundcloud.com/pessoa/cancao/s-private'), '');
    for (final bad in [
      'https://localhost/tracks',
      'https://api-v2.soundcloud.com/me',
      'https://a-v2.sndcdn.com/anything.js',
      'https://soundcloud.com:444/pessoa/cancao'
    ]) {
      expect(() => PublicSoundCloudTransport.validate(Uri.parse(bad)),
          throwsFormatException);
    }
  });
  test('metadados não confundem uploader, prévia e áudio baixável', () async {
    final catalog = SoundCloudCatalog(
        transport: FixtureSoundCloud(sound(1, artist: false)));
    final draft = await catalog.track('https://soundcloud.com/pessoa/cancao-1');
    expect(draft.artist, '');
    expect(draft.durationMs, 180000);
    expect(draft.sourceKind, SourceKind.soundcloud);
    expect(draft.mediaUrl, draft.sourceUrl);
    final linked =
        ResolvedMusicLink(link: MusicLink.parse(draft.sourceUrl), draft: draft);
    final assessment = const TrackMatcher().assess(
        linked.matchingTrack,
        const Candidate(
            title: 'Canção',
            artist: 'Uploader diferente',
            album: '',
            durationMs: 180000,
            pageUrl: 'https://music.youtube.com/watch?v=abcdefghijk',
            previewUrl: '',
            coverUrl: '',
            kind: SourceKind.youtubeMusic,
            recordingType: 'MUSIC_VIDEO_TYPE_ATV'));
    expect(assessment.needsReview, isTrue);
  });
  test(
      'playlist completa ordem e repetições em lotes, mantendo indisponível e sem cortar nas primeiras 25',
      () async {
    final ids = [1, 2, 1, ...List.generate(53, (i) => i + 3)];
    final fixture = FixtureSoundCloud({
      'id': 100,
      'kind': 'playlist',
      'title': 'Mix',
      'public': true,
      'permalink_url': 'https://soundcloud.com/pessoa/sets/mix',
      'track_count': ids.length,
      'tracks': [
        sound(1),
        {'id': 2},
        sound(1),
        ...ids.skip(3).map((id) => {'id': id})
      ]
    }, omit: {
      9
    });
    final catalog = SoundCloudCatalog(transport: fixture);
    final imported =
        await catalog.open('https://soundcloud.com/pessoa/sets/mix');
    final tracks = await imported.tracks.toList();
    expect(tracks.length, ids.length);
    expect(tracks[0].sourceUrl, tracks[2].sourceUrl);
    expect(tracks.last.sourceUrl, 'https://soundcloud.com/pessoa/cancao-55');
    expect(tracks[ids.indexOf(9)].title, contains('indisponível'));
    expect(tracks[ids.indexOf(9)].sourceKind, SourceKind.none);
    expect(fixture.calls.where((u) => u.host == 'api-v2.soundcloud.com').length,
        3);
    expect(fixture.calls.where((u) => u.host == 'a-v2.sndcdn.com').length, 1);
    expect(imported.isPartial, isFalse);
  });
  test(
      'lista parcial, privada, alterada ou código em lugar de JSON não vira importação completa',
      () async {
    for (final row in [
      {
        'id': 1,
        'kind': 'playlist',
        'title': 'Mix',
        'public': true,
        'permalink_url': 'https://soundcloud.com/pessoa/sets/mix',
        'track_count': 2,
        'tracks': [sound(1)]
      },
      {...sound(1), 'public': false},
    ]) {
      final catalog = SoundCloudCatalog(transport: FixtureSoundCloud(row));
      await expectLater(
          catalog.open(row['permalink_url'] as String), throwsFormatException);
    }
    final fixture = FixtureSoundCloud(sound(1))
      ..body = '<script>window.__sc_hydration = runCode();</script>';
    await expectLater(
        SoundCloudCatalog(transport: fixture)
            .track('https://soundcloud.com/pessoa/cancao-1'),
        throwsFormatException);
  });
  test(
      'link fixa versão SoundCloud, persiste ID e entra no fim da execução sem buscar outra versão',
      () async {
    final directory = await Directory.systemTemp.createTemp('dd-soundcloud-');
    final db = AppDatabase('${directory.path}/test.db');
    await db.initialize();
    addTearDown(() => directory.delete(recursive: true));
    final repo = LibraryRepository(db);
    final imported =
        await SoundCloudCatalog(transport: FixtureSoundCloud(sound(1)))
            .open('https://soundcloud.com/pessoa/cancao-1');
    final collection = await repo.importCollection(imported);
    final connection =
        DeezerConnectionController(EmptySession(), LinkSearchEngine());
    final engine = LinkSearchEngine();
    final service = MusicLinkService(
        MusicLinkCatalog(
            soundcloud:
                SoundCloudCatalog(transport: FixtureSoundCloud(sound(2)))),
        MusicResolver(engine, connection));
    final links = await service.resolve(
        'https://soundcloud.com/pessoa/cancao-2\nhttps://soundcloud.com/pessoa/cancao-2');
    expect(links.every((e) => e.ready && e.pinned), isTrue);
    final added = await MusicLinkRepository(db)
        .append(collection, links, run: 'soundcloud-fixture');
    final page = await repo.page(collection);
    expect(page.items.length, 3);
    expect(page.items.last.position, 3);
    expect(page.items.last.sourceUrl, 'https://soundcloud.com/pessoa/cancao-2');
    expect(page.items.last.sourceKind, SourceKind.soundcloud);
    expect(page.items.last.sourceId, '2');
    expect(page.items.last.hasManualSource, isTrue);
    expect(page.items.last.localPath, '');
    expect(engine.providers, isEmpty);
    final membership = await db.run((db) => db
        .select(
            'SELECT track_id FROM download_run_additions WHERE run=? ORDER BY track_id',
            ['soundcloud-fixture'])
        .map((r) => r['track_id'])
        .toList());
    expect(membership, added);
    final unknown = await MusicLinkService(
            MusicLinkCatalog(
                soundcloud: SoundCloudCatalog(
                    transport: FixtureSoundCloud(sound(2, artist: false)))),
            MusicResolver(engine, connection))
        .resolve('https://soundcloud.com/pessoa/cancao-2');
    expect(unknown.single.ready, isTrue);
    expect(unknown.single.draft.artist, isEmpty);
  });
}

import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:definitive_downloader/core/network/bounded_http.dart';
import 'package:definitive_downloader/core/platform/desktop_files.dart';
import 'package:definitive_downloader/features/library/application/library_controller.dart';
import 'package:definitive_downloader/features/importing/csv_importer.dart';
import 'package:definitive_downloader/features/importing/spotify_importer.dart';
import 'package:definitive_downloader/features/importing/music_link_catalog.dart';
import 'package:definitive_downloader/features/matching/deezer_catalog.dart';
import 'package:definitive_downloader/features/matching/music_resolver.dart';
import 'package:definitive_downloader/features/downloads/download_service.dart';
import 'package:definitive_downloader/features/library/application/library_music_sources.dart';
import 'package:definitive_downloader/features/connections/application/deezer_connection_controller.dart';
import 'music_resolver_test.dart' show EmptyEngine, EmptySession;
import 'package:definitive_downloader/features/importing/deezer_playlist_catalog.dart';
import 'package:definitive_downloader/features/importing/youtube_playlist_catalog.dart';
import 'package:definitive_downloader/features/importing/music_catalog_transport.dart';
import 'package:definitive_downloader/features/importing/public_playlist_link.dart';
import 'package:definitive_downloader/features/library/domain/models.dart';
import 'package:definitive_downloader/features/library/data/library_repository.dart';
import 'package:definitive_downloader/core/storage/database.dart';

const playlistId = 'PL1234567890123456';
PublicPlaylistLink youtube({bool music = false}) => PublicPlaylistLink.recognize(
    'https://${music ? 'music' : 'www'}.youtube.com/playlist?list=$playlistId')!;
PublicPlaylistLink deezer() =>
    PublicPlaylistLink.recognize('https://www.deezer.com/br/playlist/123')!;

class PlaylistTransport implements MusicCatalogTransport {
  PlaylistTransport(this.reader);
  final Map<String, dynamic> Function(Uri, Map<String, Object?>?) reader;
  final calls = <Uri>[];
  @override
  Future<Map<String, dynamic>> read(Uri uri,
      {Map<String, Object?>? body}) async {
    PublicMusicCatalogTransport.validate(uri, post: body != null);
    calls.add(uri);
    return reader(uri, body);
  }
}

Map<String, dynamic> deezerRow(int id, {bool readable = true}) => {
      'id': id,
      'title': 'Canção $id',
      'duration': 180,
      'readable': readable,
      'artist': {'name': 'Pessoa'},
      'album': {
        'title': 'Álbum',
        'cover_medium': 'https://e-cdns-images.dzcdn.net/cover.jpg'
      }
    };
Map<String, dynamic> video(String id, {bool playable = true}) => {
      'playlistVideoRenderer': {
        'videoId': id,
        'title': {'simpleText': 'Canção'},
        'shortBylineText': {'simpleText': 'Pessoa'},
        'lengthText': {'simpleText': '3:00'},
        'isPlayable': playable
      }
    };
Map<String, dynamic> continuation(String token) => {
      'continuationItemRenderer': {
        'continuationEndpoint': {
          'continuationCommand': {'token': token}
        }
      }
    };
Map<String, dynamic> musicRow(String id,
        {String type = 'MUSIC_VIDEO_TYPE_ATV'}) =>
    {
      'musicResponsiveListItemRenderer': {
        'playlistItemData': {'videoId': id},
        'flexColumns': [
          for (final name in ['Canção', 'Pessoa', 'Álbum'])
            {
              'musicResponsiveListItemFlexColumnRenderer': {
                'text': {
                  'runs': [
                    {'text': name}
                  ]
                }
              }
            }
        ],
        'fixedColumns': [
          {
            'musicResponsiveListItemFixedColumnRenderer': {
              'text': {'simpleText': '3:00'}
            }
          }
        ],
        'navigationEndpoint': {
          'watchEndpoint': {
            'videoId': id,
            'watchEndpointMusicSupportedConfigs': {
              'watchEndpointMusicConfig': {'musicVideoType': type}
            }
          }
        }
      }
    };
Map<String, dynamic> firstPage(List<Map<String, dynamic>> rows,
        {bool music = false, int total = 3, String id = playlistId}) =>
    {
      'contents': music
          ? {
              'musicPlaylistShelfRenderer': {'playlistId': id, 'contents': rows}
            }
          : {
              'playlistVideoListRenderer': {'contents': rows}
            },
      'metadata': {
        'playlistMetadataRenderer': {
          'title': 'Lista',
          'androidAppindexingLink':
              'android-app://com.google.android.youtube/http/www.youtube.com/playlist?list=$id'
        }
      },
      'sidebar': {
        'playlistSidebarPrimaryInfoRenderer': {
          'stats': [
            {'simpleText': '$total videos'}
          ]
        }
      },
      if (music)
        'header': {
          'musicResponsiveHeaderRenderer': {
            'title': {'simpleText': 'Lista'},
            'secondSubtitle': {'simpleText': '$total tracks'}
          }
        }
    };
Map<String, dynamic> nextPage(List<Map<String, dynamic>> rows) => {
      'onResponseReceivedActions': [
        {
          'appendContinuationItemsAction': {'continuationItems': rows}
        }
      ]
    };

void main() {
  test(
      'despacha links canônicos sem rastreamento; recusa mix e destinos alheios',
      () {
    expect(deezer().url, 'https://www.deezer.com/playlist/123');
    expect(
        PublicPlaylistLink.recognize(
                'https://music.youtube.com/watch?v=abcdefghijk&list=$playlistId&si=x')!
            .url,
        'https://music.youtube.com/playlist?list=$playlistId');
    expect(
        PublicPlaylistLink.recognize(
            'https://youtube.com.evil.org/playlist?list=$playlistId'),
        isNull);
    for (final url in [
      'https://www.youtube.com/playlist?list=RD1234567890123',
      'https://www.youtube.com/playlist?list=$playlistId&list=$playlistId',
      'https://u:p@www.deezer.com/playlist/123',
      'https://www.deezer.com:444/playlist/123'
    ]) {
      expect(() => PublicPlaylistLink.recognize(url), throwsFormatException);
    }
    for (final url in [
      'https://api.deezer.com/me',
      'https://www.youtube.com/youtubei/v1/player',
      'https://music.youtube.com/youtubei/v1/browse?key=secret',
      'https://api.deezer.com/playlist/123/tracks?limit=100&index=-1'
    ]) {
      expect(
          () => PublicMusicCatalogTransport.validate(Uri.parse(url),
              post: url.contains('youtube')),
          throwsFormatException);
    }
  });

  test(
      'Deezer lê todas as páginas, preserva repetidas e indisponíveis sem fonte falsa',
      () async {
    final transport = PlaylistTransport((uri, _) {
      if (!uri.path.endsWith('/tracks')) {
        return {
          'id': 123,
          'title': 'Lista',
          'nb_tracks': 3,
          'checksum': 'a',
          'public': true
        };
      }
      final offset = int.parse(uri.queryParameters['index']!);
      return {
        'data': offset == 0
            ? [deezerRow(1), deezerRow(2, readable: false)]
            : [deezerRow(1)],
        'total': 3,
        if (offset == 0)
          'next': 'http://api.deezer.com/playlist/123/tracks?index=2&limit=100'
      };
    });
    final imported = await DeezerPlaylistCatalog(transport: transport)
        .open(deezer(), downloadAvailable: true);
    final tracks = await imported.tracks.toList();
    expect(tracks.map((t) => t.title), ['Canção 1', 'Canção 2', 'Canção 1']);
    expect(tracks[0].manualUrl, tracks[2].manualUrl);
    expect(tracks[1].sourceKind, SourceKind.none);
    expect(tracks[1].pendingReason, isNotEmpty);
    expect(transport.calls.length, 4);
  });

  test('Deezer recusa redirecionamento de paginação e mudança de snapshot',
      () async {
    for (final changed in [false, true]) {
      var reads = 0;
      final transport = PlaylistTransport((uri, _) {
        if (!uri.path.endsWith('/tracks')) {
          return {
            'id': 123,
            'title': 'Lista',
            'nb_tracks': changed ? 1 : 2,
            'checksum': reads++ == 0 ? 'a' : 'b'
          };
        }
        return {
          'data': [deezerRow(1)],
          'total': changed ? 1 : 2,
          'next': 'https://evil.org/playlist/123/tracks?index=1'
        };
      });
      await expectLater(
          DeezerPlaylistCatalog(transport: transport).open(deezer()),
          throwsFormatException);
    }
  });

  for (final music in [false, true]) {
    test(
        'YouTube music=$music lê continuação e mantém autorização manual e ordem',
        () async {
      final row = music ? musicRow : video;
      final transport = PlaylistTransport((_, body) => body!['continuation'] ==
              null
          ? firstPage(
              [row('abcdefghijk'), row('01234567890'), continuation('next')],
              music: music)
          : nextPage([row('abcdefghijk')]));
      final imported = await YouTubePlaylistCatalog(transport: transport)
          .open(youtube(music: music), downloadAvailable: true);
      final tracks = await imported.tracks.toList();
      expect(tracks.length, 3);
      expect(tracks.first.sourceUrl, tracks.last.sourceUrl);
      expect(tracks.first.manualUrl, tracks.first.sourceUrl);
      expect(tracks.first.durationMs, 180000);
      expect(tracks.first.sourceKind,
          music ? SourceKind.youtubeMusic : SourceKind.youtube);
      expect(tracks.first.artist, 'Pessoa');
      expect(transport.calls.length, 2);
    });
  }

  test('YouTube recusa página repetida, truncamento e identidade errada',
      () async {
    for (final mode in ['repeat', 'truncated', 'identity']) {
      final transport = PlaylistTransport((_, body) =>
          body!['continuation'] == null
              ? firstPage([
                  musicRow('abcdefghijk'),
                  if (mode == 'repeat') continuation('same')
                ],
                  music: true,
                  id: mode == 'identity' ? 'PL0000000000000000' : playlistId)
              : nextPage([musicRow('abcdefghijk'), continuation('same')]));
      await expectLater(
          YouTubePlaylistCatalog(transport: transport)
              .open(youtube(music: true)),
          throwsFormatException);
    }
  });

  test(
      'YouTube vídeo da playlist é escolha manual; indisponível continua pendente',
      () async {
    final transport = PlaylistTransport((_, __) => firstPage([
          musicRow('abcdefghijk', type: 'MUSIC_VIDEO_TYPE_OMV'),
          video('01234567890', playable: false)
        ], music: true, total: 2));
    final tracks = await (await YouTubePlaylistCatalog(transport: transport)
            .open(youtube(music: true)))
        .tracks
        .toList();
    expect(tracks.first.sourceKind, SourceKind.youtube);
    expect(
        tracks.first.mediaUrl, 'https://www.youtube.com/watch?v=abcdefghijk');
    expect(tracks.first.sourceReady, isFalse);
    expect(tracks.last.sourceKind, SourceKind.none);
  });

  test('cancelamento entre páginas aborta antes de importar a coleção',
      () async {
    var cancelled = false;
    final transport = PlaylistTransport(
        (_, __) => firstPage([video('abcdefghijk'), continuation('next')]));
    await expectLater(
        YouTubePlaylistCatalog(transport: transport).open(youtube(),
            cancelled: () => cancelled,
            onProgress: (_, __) => cancelled = true),
        throwsA(isA<DownloadCancelled>()));
    expect(transport.calls.length, 1);
  });

  test(
      'formato moderno do YouTube preserva indisponível e recusa resposta de outra lista',
      () async {
    final modern = {
      'lockupViewModel': {
        'contentId': 'abcdefghijk',
        'contentType': 'LOCKUP_CONTENT_TYPE_VIDEO',
        'metadata': {
          'lockupMetadataViewModel': {
            'title': {'content': 'Canção'},
            'metadata': {
              'contentMetadataViewModel': {
                'metadataRows': [
                  {
                    'metadataParts': [
                      {
                        'text': {'content': 'Pessoa'}
                      }
                    ]
                  }
                ]
              }
            }
          }
        },
        'contentImage': {
          'thumbnailBadgeViewModel': {'text': '3:00'}
        }
      }
    };
    Map<String, dynamic> page({bool wrong = false}) => {
          ...firstPage([],
              total: 2, id: wrong ? 'PL0000000000000000' : playlistId),
          'contents': {
            'itemSectionRenderer': {
              'contents': [modern, video('01234567890', playable: false)]
            }
          }
        };
    final tracks = await (await YouTubePlaylistCatalog(
                transport: PlaylistTransport((_, __) => page()))
            .open(youtube(), downloadAvailable: true))
        .tracks
        .toList();
    expect(tracks.first.artist, 'Pessoa');
    expect(tracks.first.durationMs, 180000);
    expect(tracks.last.sourceKind, SourceKind.none);
    await expectLater(
        YouTubePlaylistCatalog(
                transport: PlaylistTransport((_, __) => page(wrong: true)))
            .open(youtube()),
        throwsFormatException);
  });

  test(
      'preparar após conectar promove só fontes manuais utilizáveis, sem buscar ou trocar versões',
      () async {
    final temp = await Directory.systemTemp.createTemp('dd-playlist-ready-');
    final repository =
        LibraryRepository(AppDatabase('${temp.path}/library.db'));
    await repository.database.initialize();
    final connection =
        DeezerConnectionController(EmptySession(), EmptyEngine());
    final resolver = MusicResolver(EmptyEngine(), connection);
    try {
      final transport =
          PlaylistTransport((uri, _) => uri.path.endsWith('/tracks')
              ? {
                  'data': [deezerRow(1), deezerRow(2, readable: false)],
                  'total': 2
                }
              : {'id': 123, 'title': 'Lista', 'nb_tracks': 2, 'checksum': 'a'});
      final owner = await repository.importCollection(
          await DeezerPlaylistCatalog(transport: transport).open(deezer()));
      final collection = (await repository.collectionById(owner))!;
      expect(await repository.needsSourcePreparation(owner), isFalse);
      expect(
          await repository.needsSourcePreparation(owner, deezerConnected: true),
          isTrue);
      final sources =
          LibraryMusicSources(repository, const MusicLinkCatalog(), resolver);
      final before = await sources.prepare(collection, DownloadCancellation(),
          onlyPending: true,
          onChecked: (_) async => fail('A sessão está desconectada.'));
      expect(before.prepared, 0);
      connection.connected = true;
      var checked = 0;
      final result = await sources.prepare(collection, DownloadCancellation(),
          onlyPending: true, onChecked: (_) async {
        checked++;
      });
      expect(result.prepared, 1);
      expect(checked, 1);
      expect(result.review, 0);
      final tracks = (await repository.page(owner)).items;
      expect(tracks.first.canDownload, isTrue);
      expect(tracks.first.manualUrl, 'https://www.deezer.com/track/1');
      expect(tracks.last.canDownload, isFalse);
      expect(
          await repository.needsSourcePreparation(owner, deezerConnected: true),
          isFalse);
    } finally {
      connection.dispose();
      await temp.delete(recursive: true);
    }
  });

  test(
      'fontes da playlist persistem por ocorrência, sem habilitar motor ausente',
      () async {
    final temp = await Directory.systemTemp.createTemp('dd-playlist-contract-');
    final db = AppDatabase('${temp.path}/library.sqlite3');
    await db.initialize();
    try {
      final repository = LibraryRepository(db);
      final transport = PlaylistTransport((_, __) =>
          firstPage([video('abcdefghijk'), video('abcdefghijk')], total: 2));
      final id = await repository.importCollection(
          await YouTubePlaylistCatalog(transport: transport).open(youtube()));
      final tracks = (await repository.page(id)).items;
      expect(tracks.map((t) => t.position), [1, 2]);
      expect(tracks.first.hasManualSource, isTrue);
      expect(tracks.first.sourceAuthorization, SourceAuthorization.manualLink);
      expect(tracks.first.status, TrackStatus.pending);
      expect(tracks.first.canDownload, isFalse);
    } finally {
      await temp.delete(recursive: true);
    }
  });

  test('consulta pública real dos três importadores sem alterar biblioteca',
      () async {
    final path = Platform.environment['DD_PLAYLIST_REAL_OUTPUT']!;
    final output = Directory(path);
    await output.create(recursive: true);
    final libraries = await Directory('$path/library').create(recursive: true);
    final private = await libraries.createTemp('run-');
    final repository =
        LibraryRepository(AppDatabase('${private.path}/library.db'));
    await repository.database.initialize();
    final controller = LibraryController(
        repository: repository,
        files: DesktopFiles(),
        spotify: const SpotifyImporter(BoundedHttp()),
        csv: const CsvImporter(),
        catalog: const DeezerCatalog(BoundedHttp()),
        downloader: DownloadService(const BoundedHttp(), rootBundle));
    addTearDown(controller.dispose);
    final results = <Map<String, Object?>>[];
    for (final link in [
      PublicPlaylistLink.recognize(
          'https://www.deezer.com/playlist/908622995')!,
      PublicPlaylistLink.recognize(
          'https://www.youtube.com/playlist?list=PLMC9KNkIncKtPzgY-5rmhvj7fax8fdxoj')!,
      PublicPlaylistLink.recognize(
          'https://music.youtube.com/playlist?list=PLMC9KNkIncKtPzgY-5rmhvj7fax8fdxoj')!
    ]) {
      final watch = Stopwatch()..start();
      final imported = link.kind == PublicPlaylistKind.deezer
          ? await const DeezerPlaylistCatalog().open(link)
          : await const YouTubePlaylistCatalog().open(link);
      final tracks = await imported.tracks.toList();
      expect(tracks.length, greaterThan(0));
      await controller.importPlaylist(link.url);
      expect(controller.current?.sourceUrl, link.url,
          reason: controller.message);
      expect(controller.current!.trackCount, tracks.length);
      final persisted = (await repository.page(controller.current!.id)).items;
      expect(persisted.first.sourceUrl, tracks.first.sourceUrl);
      expect(persisted.first.hasManualSource, isTrue);
      expect(controller.downloading, isFalse);
      results.add({
        'source': imported.source,
        'name': imported.name,
        'count': tracks.length,
        'pending': tracks.where((t) => t.sourceKind == SourceKind.none).length,
        'ms': watch.elapsedMilliseconds,
        'first': {
          'title': tracks.first.title,
          'artist': tracks.first.artist,
          'reference': tracks.first.sourceUrl
        },
        'references': tracks.map((t) => t.sourceUrl).toList()
      });
    }
    await File('$path/results.json').writeAsString(jsonEncode(results));
  },
      skip: Platform.environment['DD_PLAYLIST_REAL_OUTPUT'] == null,
      timeout: const Timeout(Duration(minutes: 5)));
}

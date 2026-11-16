import 'package:flutter_test/flutter_test.dart';
import 'package:definitive_downloader/features/connections/application/deezer_connection_controller.dart';
import 'package:definitive_downloader/features/downloads/download_service.dart';
import 'package:definitive_downloader/features/library/domain/models.dart';
import 'package:definitive_downloader/features/matching/music_engine.dart';
import 'package:definitive_downloader/features/matching/music_resolver.dart';
import 'support.dart';
import 'package:definitive_downloader/features/matching/music_candidates.dart';

class EmptyEngine implements MusicEngine {
  @override
  bool get available => true;
  @override
  Future<Map<String, dynamic>> call(Map<String, dynamic> request,
          {DownloadCancellation? cancellation,
          void Function(String)? onStage,
          void Function(TransferProgress)? onProgress}) async =>
      {};
}

class EmptySession implements DeezerSessionStore {
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String value) async {}
  @override
  Future<void> clear() async {}
}

Candidate recording(String id, String album,
        {String type = 'MUSIC_VIDEO_TYPE_ATV'}) =>
    Candidate(
        title: 'Entre linhas',
        artist: 'Laboratório D.d',
        album: album,
        durationMs: 180000,
        pageUrl: 'https://music.youtube.com/watch?v=$id',
        previewUrl: '',
        coverUrl: '',
        kind: SourceKind.youtubeMusic,
        recordingType: type);

class SearchPolicyEngine extends EmptyEngine {
  SearchPolicyEngine(this.audio);
  final bool audio;
  final providers = <String>[];
  @override
  Future<Map<String, dynamic>> call(Map<String, dynamic> request,
      {DownloadCancellation? cancellation,
      void Function(String)? onStage,
      void Function(TransferProgress)? onProgress}) async {
    final provider = request['provider'] as String;
    providers.add(provider);
    return {
      'candidates': provider == 'youtubeMusic' && audio
          ? [candidateJson(recording('abcdefghijk', 'Ensaios'))]
          : provider == 'youtube'
              ? [
                  candidateJson(const Candidate(
                      title: 'Entre linhas (Official Video)',
                      artist: 'Laboratório D.d',
                      album: '',
                      durationMs: 190000,
                      pageUrl: 'https://www.youtube.com/watch?v=abcdefghijk',
                      previewUrl: '',
                      coverUrl: '',
                      kind: SourceKind.youtube,
                      recordingType: 'MUSIC_VIDEO_TYPE_OMV'))
                ]
              : []
    };
  }
}

class ExactSoundCloudEngine extends EmptyEngine {
  final queries = <Map<String, dynamic>>[];
  @override
  Future<Map<String, dynamic>> call(Map<String, dynamic> request,
      {DownloadCancellation? cancellation,
      void Function(String)? onStage,
      void Function(TransferProgress)? onProgress}) async {
    queries.add(request);
    if (request['provider'] == 'soundcloud' &&
        (request['query'] as String).startsWith('"')) {
      return {
        'candidates': [
          candidateJson(const Candidate(
              title: 'Entre linhas',
              artist: 'Laboratório D.d',
              album: 'Ensaios',
              durationMs: 180000,
              pageUrl: 'https://soundcloud.com/artist/entre-linhas',
              previewUrl: '',
              coverUrl: '',
              sourceId: '123',
              kind: SourceKind.soundcloud,
              recordingType: 'SOUNDCLOUD_TRACK',
              explicit: false))
        ]
      };
    }
    if (request['provider'] == 'youtubeMusic') {
      return {
        'candidates': [
          candidateJson(const Candidate(
              title: 'Outra música',
              artist: 'Outra pessoa',
              album: '',
              durationMs: 180000,
              pageUrl: 'https://music.youtube.com/watch?v=abcdefghijk',
              previewUrl: '',
              coverUrl: '',
              kind: SourceKind.youtubeMusic,
              recordingType: 'MUSIC_VIDEO_TYPE_ATV'))
        ]
      };
    }
    return {'candidates': []};
  }
}

void main() {
  late MusicResolver resolver;
  late DeezerConnectionController connection;
  setUp(() {
    final engine = EmptyEngine();
    connection = DeezerConnectionController(EmptySession(), engine);
    resolver = MusicResolver(engine, connection);
  });
  tearDown(() => connection.dispose());
  test('prioriza o álbum pedido mesmo quando uma compilação aparece primeiro',
      () {
    final original = recording('abcdefghijk', 'Ensaios');
    expect(
        resolver.automaticChoice(
            testTrack(), [recording('01234567890', 'Compilação'), original]),
        same(original));
  });
  test('duas gravações igualmente plausíveis do mesmo álbum ficam para revisão',
      () {
    expect(
        resolver.automaticChoice(testTrack(), [
          recording('abcdefghijk', 'Ensaios'),
          recording('01234567890', 'Ensaios')
        ]),
        isNull);
  });
  test('um videoclipe não vira alternativa por ter título e álbum idênticos',
      () {
    expect(
        resolver.automaticChoice(testTrack(), [
          recording('abcdefghijk', 'Ensaios', type: 'MUSIC_VIDEO_TYPE_OMV')
        ]),
        isNull);
  });
  test('áudio exato sem duração fica para revisão antes de videoclipes',
      () async {
    final engine = SearchPolicyEngine(true);
    final own = MusicResolver(engine, connection);
    final track = testTrack(duration: null);
    final found = await own.search(track, '${track.artist} ${track.title}');
    expect(engine.providers, ['deezerFull', 'youtubeMusic', 'soundcloud']);
    expect(found.single.kind, SourceKind.youtubeMusic);
    expect(own.automaticChoice(track, found), isNull);
  });
  test(
      'videoclipes só são buscados quando não há correspondência de áudio e nunca são escolhidos automaticamente',
      () async {
    for (final audio in [true, false]) {
      final engine = SearchPolicyEngine(audio);
      final ownConnection = DeezerConnectionController(EmptySession(), engine);
      try {
        final own = MusicResolver(engine, ownConnection);
        final result = await own.search(testTrack(), 'Entre linhas');
        expect(
            engine.providers,
            audio
                ? ['deezerFull', 'youtubeMusic', 'soundcloud']
                : [
                    'deezerFull',
                    'youtubeMusic',
                    'soundcloud',
                    'soundcloud',
                    'deezerFull',
                    'youtubeMusic',
                    'youtube'
                  ]);
        expect(own.automaticChoice(testTrack(), result)?.kind,
            audio ? SourceKind.youtubeMusic : null);
        if (!audio) expect(result.single.isVideoRecording, isTrue);
      } finally {
        ownConnection.dispose();
      }
    }
  });
  test(
      'busca a faixa exata no SoundCloud antes de recomendar outro título ou videoclipe',
      () async {
    final engine = ExactSoundCloudEngine();
    final own = MusicResolver(engine, connection);
    final found = await own.search(testTrack(), 'Entre linhas');
    expect(engine.queries.map((r) => r['provider']), [
      'deezerFull',
      'youtubeMusic',
      'soundcloud',
      'soundcloud',
      'deezerFull',
      'youtubeMusic'
    ]);
    expect(engine.queries[3]['query'], '"Entre linhas" "Laboratório D.d"');
    expect(found.single.kind, SourceKind.soundcloud);
    expect(found.single.title, 'Entre linhas');
    expect(
        own.automaticChoice(testTrack(), found)?.kind, SourceKind.soundcloud);
  });
}

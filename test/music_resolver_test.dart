import 'package:flutter_test/flutter_test.dart';
import 'package:definitive_downloader/features/connections/application/deezer_connection_controller.dart';
import 'package:definitive_downloader/features/downloads/download_service.dart';
import 'package:definitive_downloader/features/library/domain/models.dart';
import 'package:definitive_downloader/features/matching/music_engine.dart';
import 'package:definitive_downloader/features/matching/music_resolver.dart';
import 'support.dart';

class EmptyEngine implements MusicEngine {
  @override
  bool get available => true;
  @override
  Future<Map<String, dynamic>> call(Map<String, dynamic> request,
          {DownloadCancellation? cancellation,
          void Function(String)? onStage}) async =>
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
}

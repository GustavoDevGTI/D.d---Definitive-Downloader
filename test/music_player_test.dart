import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:definitive_downloader/core/network/bounded_http.dart';
import 'package:definitive_downloader/core/storage/database.dart';
import 'package:definitive_downloader/features/downloads/mp3_tags.dart';
import 'package:definitive_downloader/features/library/data/library_repository.dart';
import 'package:definitive_downloader/features/library/domain/models.dart';
import 'package:definitive_downloader/features/player/application/music_player_controller.dart';
import 'package:definitive_downloader/features/player/data/player_library.dart';
import 'package:definitive_downloader/features/player/data/audio_tags.dart';
import 'package:definitive_downloader/features/player/domain/playback.dart';
import 'player_fixtures.dart';

class PreviewHttp extends BoundedHttp {
  final calls = <Uri>[];
  int responseId = 123;
  @override
  Future<String> text(Uri uri) async {
    calls.add(uri);
    return jsonEncode(
        {'id': responseId, 'preview': 'https://cdn.test.dzcdn.net/exact.mp3'});
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MemoryPlayerLibrary library;
  late FakeAudioEngine engine;
  late PlayerFiles files;
  late MusicPlayerController player;
  setUp(() {
    library = MemoryPlayerLibrary();
    engine = FakeAudioEngine();
    files = PlayerFiles();
    player = MusicPlayerController(library, engine, files, random: Random(7));
  });
  tearDown(() => player.dispose());
  test('playlist, pausa, retorno e fim sem alterar ordem ou repetições',
      () async {
    final ids = library.items.map((i) => i.id).toList();
    await player.playCollection(1);
    expect(player.current!.id, ids.first);
    await player.toggle();
    expect(player.playing, isFalse);
    await player.toggle();
    expect(player.playing, isTrue);
    engine.emit(const AudioEvent(completed: true));
    await playerUntil(() => player.index == 1 && !player.loading);
    await player.previous();
    expect(player.index, 0);
    await player.jump(3);
    engine.emit(const AudioEvent(completed: true));
    await playerUntil(() => player.ended);
    expect(player.playing, isFalse);
    expect(player.queue.map((i) => i.id), ids);
  });
  test('aleatório visita cada ocorrência e voltar segue o que foi ouvido',
      () async {
    library.items = [
      for (var i = 0; i < 5; i++)
        AudioItem(
            id: '$i',
            title: 'Repetida',
            artist: 'Pessoa',
            uri: 'file:///same.mp3')
    ];
    await player.playCollection(1);
    player.toggleShuffle();
    final heard = <int>[player.index];
    for (var i = 0; i < 4; i++) {
      await player.next();
      heard.add(player.index);
    }
    expect(heard.toSet().length, 5);
    await player.previous();
    expect(player.index, heard[3]);
    expect(player.queue.length, 5);
    expect(library.items.map((i) => i.id), ['0', '1', '2', '3', '4']);
  });
  test('loop playlist e loop música são separados do avanço manual', () async {
    await player.playCollection(1);
    player.cycleRepeat();
    expect(player.repeat, AudioRepeat.playlist);
    await player.jump(3);
    engine.emit(const AudioEvent(completed: true));
    await playerUntil(() => player.index == 0 && !player.loading);
    player.cycleRepeat();
    expect(player.repeat, AudioRepeat.track);
    engine.emit(const AudioEvent(completed: true));
    await playerUntil(() => engine.seeks.isNotEmpty);
    expect(player.index, 0);
    expect(engine.seeks.last, Duration.zero);
    await player.next();
    expect(player.index, 1);
  });
  test('arquivo ausente é pulado e fila totalmente ausente não entra em loop',
      () async {
    library.missing.add('track-1');
    await player.playCollection(1);
    expect(player.index, 1);
    library.missing.addAll(library.items.map((i) => i.id));
    await player.playCollection(1);
    expect(player.playing, isFalse);
    expect(player.loading, isFalse);
    expect(player.message, isNotEmpty);
  });
  test('volume contínuo, mute, seek e preferências sem autoplay', () async {
    library.saved['player_volume'] = '0.137';
    await player.initialize();
    expect(player.volume, .137);
    expect(engine.opens, isEmpty);
    await player.playCollection(1);
    player.setVolume(.713);
    await Future<void>.delayed(const Duration(milliseconds: 70));
    expect(engine.volumes.last, .713);
    await player.saveVolume();
    expect(library.saved['player_volume'], '0.713');
    player.mute();
    expect(player.volume, 0);
    player.mute();
    expect(player.volume, .713);
    await player.seek(const Duration(seconds: 20));
    expect(engine.seeks.last, const Duration(seconds: 20));
    await player.seek(const Duration(days: 1));
    expect(engine.seeks.last, engine.length);
  });
  test(
      'resposta de prévia antiga não substitui uma música local escolhida depois',
      () async {
    library.deferred = Completer<AudioItem?>();
    final old = player.listenCandidate(audioTrack(path: ''), audioCandidate());
    await player.listenTrack(audioTrack());
    library.deferred!.complete(library.preview);
    await old;
    expect(player.current!.kind, PlaybackKind.local);
    expect(engine.opens.every((uri) => uri.startsWith('file:')), isTrue);
  });
  test('referência é canônica e copiar/abrir não toca nem modifica a fila',
      () async {
    String? copied;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await player.copyReference(
        'https://music.youtube.com/watch?v=abcdefghijk&list=ignored');
    await player.openReference('https://www.deezer.com/br/track/123');
    expect(copied, 'https://music.youtube.com/watch?v=abcdefghijk');
    expect(files.opened.single.toString(), 'https://www.deezer.com/track/123');
    expect(engine.opens, isEmpty);
    expect(
        publicReference('https://www.youtube.com.evil.org/watch?v=abcdefghijk'),
        '');
    expect(
        publicReference('https://user:password@www.deezer.com/track/123'), '');
  });
  test('prévia usa ID exato e não adota duração da faixa completa', () async {
    final http = PreviewHttp();
    final repository = PlayerLibrary(const AppDatabase('unused'), http: http);
    final preview = await repository.online(audioCandidate());
    expect(preview!.isPreview, isTrue);
    expect(preview.duration, Duration.zero);
    expect(http.calls.single.toString(), 'https://api.deezer.com/track/123');
    http.responseId = 456;
    await expectLater(
        repository.online(audioCandidate()), throwsFormatException);
    expect(
        await repository.online(const Candidate(
            title: 'Vídeo',
            artist: 'Pessoa',
            album: '',
            durationMs: 100000,
            pageUrl: 'https://music.youtube.com/watch?v=abcdefghijk',
            previewUrl: '',
            coverUrl: '',
            kind: SourceKind.youtubeMusic)),
        isNull);
  });
  test(
      'arquivo local tem prioridade sobre prévia e ouvir não altera dados de matching/download',
      () async {
    final temp = await Directory.systemTemp.createTemp('dd-player-data-');
    final repo = LibraryRepository(AppDatabase('${temp.path}/library.db'));
    await repo.database.initialize();
    final id = await repo.importCollection(ImportedCollection(
        name: 'Sintética',
        source: 'Fixture',
        sourceUrl: '',
        tracks: Stream.value(const TrackDraft(
            title: 'Entre linhas',
            artist: 'Laboratório D.d',
            durationMs: 4000,
            mediaUrl: 'https://www.deezer.com/track/123',
            sourceKind: SourceKind.deezerFull))));
    var track = (await repo.page(id)).items.single;
    final target = File('${temp.path}/track.mp3');
    await const Mp3TagWriter().write(
        source: File('assets/demo/tone.mp3'),
        destination: target,
        track: track,
        cover: await File('assets/demo/cover.png').readAsBytes());
    await repo.setStatus(track.id, TrackStatus.completed,
        localPath: target.path);
    track = (await repo.trackById(track.id))!;
    Future<String> snapshot() => repo.database.run((db) => jsonEncode([
          db
              .select('SELECT * FROM tracks')
              .map((r) => r.values.toList())
              .toList(),
          db
              .select('SELECT * FROM download_history')
              .map((r) => r.values.toList())
              .toList()
        ]));
    final before = await snapshot();
    final http = PreviewHttp();
    final actual = MusicPlayerController(
        PlayerLibrary(repo.database, http: http), FakeAudioEngine(), files);
    await actual.listenCandidate(track, audioCandidate());
    await playerUntil(() => actual.cover != null);
    expect(actual.current!.kind, PlaybackKind.local);
    expect(http.calls, isEmpty);
    expect(actual.artist, 'Laboratório D.d');
    expect(await snapshot(), before);
    actual.dispose();
    final tags = await readAudioTags(target.path);
    expect(tags.cover, isNotNull);
    await temp.delete(recursive: true);
  });
}

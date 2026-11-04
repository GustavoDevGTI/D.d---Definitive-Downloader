import 'dart:async';
import 'package:definitive_downloader/core/platform/desktop_files.dart';
import 'package:definitive_downloader/core/storage/database.dart';
import 'package:definitive_downloader/features/library/domain/models.dart';
import 'package:definitive_downloader/features/player/data/player_library.dart';
import 'package:definitive_downloader/features/player/domain/playback.dart';

class FakeAudioEngine implements AudioEngine {
  @override
  bool get available => true;
  final controller = StreamController<AudioEvent>.broadcast(sync: true);
  final opens = <String>[];
  final volumes = <double>[];
  final seeks = <Duration>[];
  bool disposed = false;
  Duration length = const Duration(seconds: 240);
  @override
  Stream<AudioEvent> get events => controller.stream;
  void emit(AudioEvent event) {
    if (!disposed) controller.add(event);
  }

  @override
  Future<void> open(String uri) async {
    opens.add(uri);
    emit(AudioEvent(playing: true, position: Duration.zero, duration: length));
  }

  @override
  Future<void> play() async => emit(const AudioEvent(playing: true));
  @override
  Future<void> pause() async => emit(const AudioEvent(playing: false));
  @override
  Future<void> stop() async => emit(const AudioEvent(playing: false));
  @override
  Future<void> seek(Duration value) async {
    seeks.add(value);
    emit(AudioEvent(position: value));
  }

  @override
  Future<void> volume(double value) async => volumes.add(value);
  @override
  Future<void> dispose() async {
    if (disposed) return;
    disposed = true;
    await controller.close();
  }
}

class MemoryPlayerLibrary extends PlayerLibrary {
  MemoryPlayerLibrary() : super(const AppDatabase('not-used'));
  List<AudioItem> items = List.generate(
      4,
      (i) => AudioItem(
          id: 'track-${i + 1}',
          title: i == 2 ? 'Entre linhas' : 'Faixa ${i + 1}',
          artist: 'Laboratório D.d',
          uri: 'file:///fixture/${i + 1}.mp3',
          reference: 'https://www.deezer.com/track/${i + 1}',
          collectionId: 1));
  final missing = <String>{};
  final saved = <String, String>{};
  AudioItem? preview = const AudioItem(
      id: 'preview-123',
      title: 'Versão alternativa',
      artist: 'Pessoa',
      uri: 'https://cdn.test.dzcdn.net/p.mp3',
      reference: 'https://www.deezer.com/track/123',
      isPreview: true,
      kind: PlaybackKind.preview);
  Completer<AudioItem?>? deferred;
  int onlineCalls = 0;
  @override
  Future<List<AudioItem>> collection(int id) async => items;
  @override
  Future<bool> available(AudioItem item) async => !missing.contains(item.id);
  @override
  Future<AudioTags> tags(AudioItem item) async => const AudioTags();
  @override
  Future<Map<String, String>> preferences() async => Map.of(saved);
  @override
  Future<void> savePreference(String key, String value) async {
    saved[key] = value;
  }

  @override
  Future<AudioItem?> localFor(Track t) async => items
      .where((i) => i.id == 'track-${t.id}' && !missing.contains(i.id))
      .firstOrNull;
  @override
  Future<AudioItem?> track(Track t) async {
    onlineCalls++;
    return preview;
  }

  @override
  Future<AudioItem?> candidate(Track track, Candidate candidate) async {
    onlineCalls++;
    return deferred == null ? preview : await deferred!.future;
  }
}

class PlayerFiles extends DesktopFiles {
  final opened = <Uri>[];
  @override
  Future<void> openUrl(Uri uri) async {
    opened.add(uri);
  }
}

Track audioTrack(
        {int id = 1,
        String path = '/fixture/1.mp3',
        SourceKind kind = SourceKind.deezerFull,
        TrackStatus status = TrackStatus.completed}) =>
    Track(
        id: id,
        collectionId: 1,
        position: id,
        title: 'Entre linhas',
        artist: 'Laboratório D.d',
        album: 'Ensaios',
        durationMs: 240000,
        isrc: '',
        coverUrl: '',
        sourceUrl: '',
        mediaUrl: 'https://www.deezer.com/track/123',
        sourceKind: kind,
        status: status,
        selected: false,
        localPath: path,
        error: '',
        resolvedTitle: '',
        resolvedArtist: '');
Candidate audioCandidate() => const Candidate(
    title: 'Versão alternativa',
    artist: 'Pessoa',
    album: '',
    durationMs: 240000,
    pageUrl: 'https://www.deezer.com/track/123',
    previewUrl: '',
    coverUrl: '',
    kind: SourceKind.deezerFull,
    recordingType: 'DEEZER_TRACK');

Future<void> playerUntil(bool Function() check) async {
  for (var i = 0; i < 200 && !check(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  if (!check()) throw StateError('Player did not settle');
}

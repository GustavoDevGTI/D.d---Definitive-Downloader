import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter_test/flutter_test.dart';
import 'package:definitive_downloader/core/storage/database.dart';
import 'package:definitive_downloader/features/importing/soundcloud_catalog.dart';
import 'package:definitive_downloader/features/importing/music_link_catalog.dart';
import 'package:definitive_downloader/features/importing/music_link_service.dart';
import 'package:definitive_downloader/features/importing/music_link_repository.dart';
import 'package:definitive_downloader/features/library/data/library_repository.dart';
import 'package:definitive_downloader/features/library/domain/models.dart';
import 'package:definitive_downloader/features/library/domain/matching.dart';
import 'support.dart' show testTrack;
import 'package:definitive_downloader/features/downloads/music_download_service.dart';
import 'package:definitive_downloader/features/downloads/transfer_progress.dart';
import 'package:definitive_downloader/features/downloads/download_cancellation.dart';
import 'package:definitive_downloader/features/downloads/playlist_exporter.dart';
import 'package:definitive_downloader/features/matching/music_engine.dart';
import 'package:definitive_downloader/features/matching/music_resolver.dart';
import 'package:definitive_downloader/features/matching/music_candidates.dart';
import 'package:definitive_downloader/features/connections/application/deezer_connection_controller.dart';
import 'music_resolver_test.dart' show EmptySession, EmptyEngine;
import 'soundcloud_import_test.dart' show sound, FixtureSoundCloud;

class FakeSoundCloudEngine extends EmptyEngine {
  bool changedId = false;
  bool outside = false;
  @override
  Future<Map<String, dynamic>> call(Map<String, dynamic> request,
      {DownloadCancellation? cancellation,
      void Function(String)? onStage,
      void Function(TransferProgress)? onProgress}) async {
    final file = File(outside
        ? '${Directory(request['directory'] as String).parent.path}/outside/verified.mp3'
        : '${request['directory']}/verified.mp3');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(List.filled(4096, 0));
    return {
      'path': file.path,
      'actual': {
        ...request['candidate'] as Map,
        if (changedId) 'sourceId': '999'
      },
      'durationMs': 180000,
      'decoded': true,
      'coverEmbedded': true
    };
  }
}

class ObservedSoundCloudEngine implements MusicEngine {
  ObservedSoundCloudEngine(this.inner, this.output);
  final MusicEngine inner;
  final String output;
  int count = 0;
  @override
  bool get available => inner.available;
  @override
  Future<Map<String, dynamic>> call(Map<String, dynamic> request,
      {DownloadCancellation? cancellation,
      void Function(String)? onStage,
      void Function(TransferProgress)? onProgress}) async {
    final result = await inner.call(request,
        cancellation: cancellation, onStage: onStage, onProgress: onProgress);
    final source = File(result['path'] as String);
    await File('$output/worker-path-${++count}.json').writeAsString(jsonEncode({
      'directory': request['directory'],
      'path': source.path,
      'exists': await source.exists(),
      'basename': p.basename(source.path),
      'within': p.isWithin(p.normalize(request['directory'] as String),
          p.normalize(source.absolute.path)),
      'bytes': await source.exists() ? await source.length() : null
    }));
    return result;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  test(
      'fonte exata persiste ID e nome, rejeita ID trocado e preserva arquivo já publicado',
      () async {
    final temp = await Directory.systemTemp.createTemp('dd-sc-source-');
    addTearDown(() => temp.delete(recursive: true));
    final repo = LibraryRepository(AppDatabase('${temp.path}/library.db'));
    await repo.database.initialize();
    final imported =
        await SoundCloudCatalog(transport: FixtureSoundCloud(sound(123)))
            .open('https://soundcloud.com/pessoa/cancao-123');
    final owner = await repo.importCollection(imported);
    final track = (await repo.page(owner)).items.single;
    expect(track.sourceId, '123');
    expect(track.hasManualSource, isTrue);
    expect(track.recordingType, 'SOUNDCLOUD_TRACK');
    expect(track.canDownload, isTrue);
    final engine = FakeSoundCloudEngine();
    final connection = DeezerConnectionController(EmptySession(), engine);
    addTearDown(connection.dispose);
    final service = MusicDownloadService(engine, connection);
    final path =
        await service.save(track, temp.path, DownloadCancellation(), (_) {});
    expect(path, contains('[SoundCloud].mp3'));
    engine.changedId = true;
    await expectLater(
        service.save(track, temp.path, DownloadCancellation(), (_) {}),
        throwsFormatException);
    expect(await File(path).length(), 4096);
    engine.changedId = false;
    engine.outside = true;
    await expectLater(
        service.save(track, temp.path, DownloadCancellation(), (_) {}),
        throwsFormatException);
    expect(await File(path).length(), 4096);
    expect(
        temp
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.mp3'))
            .length,
        1);
    await repo.saveCandidates(track.id, [
      Candidate(
          title: track.title,
          artist: track.artist,
          album: '',
          durationMs: 180000,
          pageUrl: track.mediaUrl,
          previewUrl: '',
          coverUrl: '',
          kind: SourceKind.soundcloud,
          sourceId: '123',
          recordingType: 'SOUNDCLOUD_TRACK')
    ]);
    await repo.database.initialize();
    expect((await repo.musicCandidates(track.id)).single.sourceId, '123');
    expect((await repo.trackById(track.id))!.sourceId, '123');
    final resolver = MusicResolver(engine, connection);
    final saved = (await repo.musicCandidates(track.id)).single;
    expect(resolver.canUse(saved), isTrue);
    expect(resolver.automaticChoice(track, [saved])?.sourceId, '123');
  });
  test(
      'prévia permanece pendente e usuário pode escolher outra fonte sem fallback automático',
      () async {
    final temp = await Directory.systemTemp.createTemp('dd-sc-preview-');
    addTearDown(() => temp.delete(recursive: true));
    final repo = LibraryRepository(AppDatabase('${temp.path}/library.db'));
    await repo.database.initialize();
    final catalog = MusicLinkCatalog(
        soundcloud: SoundCloudCatalog(
            transport: FixtureSoundCloud(
                {...sound(1), 'policy': 'SNIP', 'duration': 30000})));
    final resolved = (await MusicLinkService(catalog, null)
            .resolve('https://soundcloud.com/pessoa/cancao-1'))
        .single;
    expect(resolved.ready, isFalse);
    expect(resolved.pinned, isTrue);
    final owner = await repo.importCollection(ImportedCollection(
        name: 'Pendentes',
        source: 'Test',
        sourceUrl: '',
        tracks:
            Stream.value(const TrackDraft(title: 'Outra', artist: 'Pessoa'))));
    await MusicLinkRepository(repo.database).append(owner, [resolved]);
    final track = (await repo.page(owner)).items.last;
    expect(track.canDownload, isFalse);
    expect(track.hasManualSource, isTrue);
    expect(track.error, contains('prévia'));
    const alternative = Candidate(
        title: 'Canção',
        artist: 'Pessoa',
        album: '',
        durationMs: 180000,
        pageUrl: 'https://music.youtube.com/watch?v=abcdefghijk',
        previewUrl: '',
        coverUrl: '',
        kind: SourceKind.youtubeMusic,
        recordingType: 'MUSIC_VIDEO_TYPE_ATV');
    await repo.chooseMusicSource(track, alternative, forFallback: true);
    expect((await repo.trackById(track.id))!.sourceKind, SourceKind.none);
    await repo.chooseMusicSource(track, alternative, userSelected: true);
    final changed = (await repo.trackById(track.id))!;
    expect(changed.sourceKind, SourceKind.youtubeMusic);
    expect(changed.manualUrl, alternative.pageUrl);
    expect(changed.sourceId, '');
    final unavailable =
        await SoundCloudCatalog(transport: FixtureSoundCloud(sound(2))).open(
            'https://soundcloud.com/pessoa/cancao-2',
            downloadAvailable: false);
    final unavailableOwner = await repo.importCollection(unavailable);
    final pending = (await repo.page(unavailableOwner)).items.single;
    expect(pending.sourceKind, SourceKind.soundcloud);
    expect(pending.status, TrackStatus.pending);
    expect(pending.canDownload, isFalse);
  });
  test(
      'parser exige ID SoundCloud imutável e não confunde prévia com gravação completa',
      () {
    final row = {
      'title': 'Canção',
      'artist': 'Pessoa',
      'album': '',
      'durationMs': 180000,
      'kind': 'soundcloud',
      'sourceId': '123',
      'recordingType': 'SOUNDCLOUD_TRACK',
      'pageUrl': 'https://soundcloud.com/pessoa/cancao',
      'coverUrl': ''
    };
    final source = parseMusicCandidate(row);
    expect(source.isFullRecording, isTrue);
    final namedVideo =
        parseMusicCandidate({...row, 'title': 'Canção (Official Video)'});
    expect(namedVideo.isFullRecording, isTrue);
    expect(const TrackMatcher().assess(testTrack(), namedVideo).reason,
        contains('Vídeo indicado'));
    for (final changed in [
      {'sourceId': ''},
      {'sourceId': 'invalid'},
      {'pageUrl': 'https://soundcloud.com.evil.org/a/b'},
      {'pageUrl': 'https://soundcloud.com/a/b?token=private'}
    ]) {
      expect(() => parseMusicCandidate({...row, ...changed}),
          throwsFormatException);
    }
    expect(
        parseMusicCandidate({...row, 'recordingType': 'SOUNDCLOUD_PREVIEW'})
            .isFullRecording,
        isFalse);
  });

  test(
      'integração real SoundCloud: Flutter, worker, repetição, pausa e cancelamento isolados',
      () async {
    final base = Platform.environment['DD_SOUNDCLOUD_REAL_OUTPUT']!;
    final root = Directory(base);
    expect(await root.exists(), isFalse);
    await root.create(recursive: true);
    final engine = ObservedSoundCloudEngine(
        await WindowsMusicEngine.load(
            Platform.environment['DD_SOUNDCLOUD_REAL_WORKER']!),
        base);
    expect(engine.available, isTrue);
    final connection = DeezerConnectionController(EmptySession(), engine);
    addTearDown(connection.dispose);
    final draft = await SoundCloudCatalog()
        .track('https://soundcloud.com/the-concept-band/the-concept-d-d-dance');
    expect(draft.sourceKind, SourceKind.soundcloud);
    expect(draft.sourceId, '30510138');
    final repo = LibraryRepository(AppDatabase('$base/library.sqlite3'));
    await repo.database.initialize();
    final owner = await repo.importCollection(ImportedCollection(
        name: 'SoundCloud real isolado',
        source: 'SoundCloud',
        sourceUrl: draft.sourceUrl,
        tracks: Stream.fromIterable([draft, draft])));
    final rows = (await repo.page(owner)).items;
    final service = MusicDownloadService(engine, connection);
    final files = <String>[];
    var progressEvents = 0;
    for (final track in rows) {
      final token = DownloadCancellation()..pauseMode = track.position == 1;
      final resume =
          Timer(const Duration(seconds: 4), () => token.pauseMode = false);
      try {
        final file = await service.save(track, base, token, (_) {},
            onTransfer: (_) => progressEvents++);
        await repo.setStatus(track.id, TrackStatus.completed, localPath: file);
        files.add(file);
      } finally {
        resume.cancel();
      }
    }
    final playlist = await PlaylistExporter(repo).export(owner, base);
    final content = await File(playlist).readAsString();
    expect(
        content.split('\n').where((line) => line.startsWith('#EXTINF:')).length,
        2);
    expect(content, contains('[SoundCloud]'));
    final cancel = DownloadCancellation()..pauseMode = true;
    final timer =
        Timer(const Duration(seconds: 4), () => cancel.cancelled = true);
    try {
      await expectLater(service.save(rows.first, base, cancel, (_) {}),
          throwsA(isA<DownloadCancelled>()));
    } finally {
      timer.cancel();
    }
    expect(
        root
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.mp3'))
            .length,
        2);
    expect(progressEvents, greaterThan(0));
    await File('$base/result.json').writeAsString(jsonEncode({
      'files': files,
      'playlist': playlist,
      'progressEvents': progressEvents,
      'pauseRequested': true,
      'cancellationVerified': true,
      'historyRows': await repo.database.run((db) =>
          db.select('SELECT COUNT(*) AS n FROM download_history').single['n']),
      'accountUsed': false,
      'sourceId': draft.sourceId
    }));
  },
      skip: Platform.environment['DD_SOUNDCLOUD_REAL_WORKER'] == null,
      timeout: const Timeout(Duration(minutes: 4)));
}

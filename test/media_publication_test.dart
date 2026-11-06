import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:definitive_downloader/core/network/bounded_http.dart';
import 'package:definitive_downloader/core/platform/desktop_files.dart';
import 'package:definitive_downloader/core/platform/media_publication.dart';
import 'package:definitive_downloader/core/storage/database.dart';
import 'package:definitive_downloader/features/downloads/download_service.dart';
import 'package:definitive_downloader/features/importing/csv_importer.dart';
import 'package:definitive_downloader/features/importing/local_mp3_inspector.dart';
import 'package:definitive_downloader/features/library/application/library_controller.dart';
import 'package:definitive_downloader/features/library/application/media_publication_recovery.dart';
import 'package:definitive_downloader/features/library/data/library_repository.dart';
import 'package:definitive_downloader/features/library/domain/models.dart';
import 'package:definitive_downloader/features/matching/deezer_catalog.dart';
import 'playlist_matching_test.dart' show FixturePlaylist;

class _Inspector implements LocalAudioInspector {
  @override
  Future<LocalAudioMetadata> inspect(String path) async =>
      const LocalAudioMetadata(durationMs: 4000);
}

class _Downloader extends DownloadService {
  _Downloader() : super(const BoundedHttp(), rootBundle);
  int calls = 0;
  @override
  Future<String> save(Track track, String directory, DownloadCancellation token,
      void Function(double?) progress,
      {void Function(TransferProgress)? onTransfer}) async {
    calls++;
    await Directory(directory).create(recursive: true);
    return (await File('assets/demo/tone.mp3').copy(
            '$directory/${track.position.toString().padLeft(3, '0')} - ${track.title}.mp3'))
        .path;
  }
}

class _Documents extends DesktopFiles {
  _Documents(this.output);
  final String output;
  bool fail = true;
  String? received;
  final keys = <String>[];
  List<PendingMediaPublication> publications = [];
  @override
  Future<List<PendingMediaPublication>> pendingMedia() async => publications;
  @override
  Future<String> defaultOutputDirectory() async => output;
  @override
  Future<String> transferDirectory(
          String directory, int trackId, int collectionId, String key) async =>
      '$directory/.dd-transfer-fixture';
  @override
  Future<String?> reusableTransfer(
          String directory, int trackId, String key) async =>
      received;
  @override
  Future<String> publishMedia(
      String path, String directory, int trackId, int collectionId, String key,
      {DownloadCancellation? cancellation, String? fileName}) async {
    received = path;
    keys.add(key);
    if (fail) {
      throw const MediaPublicationFailure(
          'Destino indisponível. Áudio preservado.');
    }
    return (await File(path)
            .copy('$directory/${fileName ?? File(path).uri.pathSegments.last}'))
        .path;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'reconciliação conclui somente publicação da fonte atual sem aprovar revisão',
      () async {
    final temp =
        await Directory.systemTemp.createTemp('dd-publication-recovery-');
    final repo = LibraryRepository(AppDatabase('${temp.path}/db'));
    final files = _Documents(temp.path);
    try {
      await repo.database.initialize();
      final owner = await repo.importCollection(ImportedCollection(
          name: 'Reconciliação',
          source: 'Fixture',
          sourceUrl: '',
          tracks: Stream.fromIterable([
            for (final title in ['Publicado', 'Revisar'])
              TrackDraft(
                  title: title,
                  artist: 'Fixture',
                  durationMs: 4000,
                  sourceUrl: 'https://fixture.invalid/$title.mp3',
                  mediaUrl: 'https://fixture.invalid/$title.mp3',
                  sourceKind: SourceKind.directMp3)
          ])));
      final tracks = (await repo.page(owner)).items;
      for (final track in tracks) {
        final path = (await File('assets/demo/tone.mp3')
                .copy('${temp.path}/${track.id}.mp3'))
            .path;
        files.publications.add(PendingMediaPublication(
            track.id, path, mediaPublicationKey(track)));
      }
      await repo.markForReview(tracks.last.id);
      final original = files.publications.first;
      files.publications[0] = PendingMediaPublication(
          original.trackId, original.path, original.key,
          position: 2);
      expect(await MediaPublicationRecovery(repo, files).recover(), isNotNull);
      expect((await repo.trackById(tracks.first.id))!.status,
          isNot(TrackStatus.completed));
      files.publications[0] = original;
      expect(await MediaPublicationRecovery(repo, files).recover(), isNull);
      expect((await repo.trackById(tracks.first.id))!.status,
          TrackStatus.completed);
      expect((await repo.trackById(tracks.last.id))!.needsReview, isTrue);
      expect((await repo.trackById(tracks.last.id))!.localPath, isEmpty);
      await repo.database.run((db) => db.execute(
          "UPDATE download_history SET created_at='2026-01-01 12:34:00' WHERE track_id=?",
          [tracks.first.id]));
      expect(await MediaPublicationRecovery(repo, files).recover(), isNull);
      expect(
          await repo.database.run((db) => db.select(
              'SELECT created_at FROM download_history WHERE track_id=?',
              [tracks.first.id]).single['created_at']),
          '2026-01-01 12:34:00');
      expect(await File('${temp.path}/playlist.m3u8').readAsString(),
          contains('${tracks.first.id}.mp3'));
    } finally {
      await temp.delete(recursive: true);
    }
  });
  test(
      'falha de publicação e reordenação pendente reutilizam áudio sem nova obtenção',
      () async {
    final temp = await Directory.systemTemp.createTemp('dd-publication-');
    final files = _Documents('${temp.path}/media');
    final downloader = _Downloader();
    final repo = LibraryRepository(AppDatabase('${temp.path}/db'));
    await repo.database.initialize();
    final owner = await repo.importCollection(ImportedCollection(
        name: 'Publicação',
        source: 'Fixture',
        sourceUrl: '',
        tracks: Stream.fromIterable([
          for (final title in ['Primeira', 'Segunda'])
            TrackDraft(
                title: title,
                artist: 'Fixture',
                durationMs: 4000,
                sourceUrl: 'https://fixture.invalid/$title.mp3',
                mediaUrl: 'https://fixture.invalid/$title.mp3',
                sourceKind: SourceKind.directMp3)
        ])));
    final controller = LibraryController(
        repository: repo,
        files: files,
        downloader: downloader,
        spotify: FixturePlaylist([]),
        csv: const CsvImporter(),
        localInspector: _Inspector(),
        catalog: const DeezerCatalog(BoundedHttp()));
    try {
      await controller.initialize();
      final first = controller.page.items.first;
      final second = controller.page.items.last;
      final key = mediaPublicationKey(first);
      await controller.downloadSelected(queueIds: [first.id]);
      expect((await repo.trackById(first.id))!.status, TrackStatus.failed);
      expect((await repo.trackById(first.id))!.localPath, isEmpty);
      expect(downloader.calls, 1);
      expect(await File(files.received!).exists(), isTrue);
      expect(
          await controller.moveTracks(first.id,
              collectionId: owner,
              targetId: second.id,
              after: true,
              selectedGroup: false),
          isNull);
      expect((await repo.trackById(first.id))!.position, 2);
      expect(mediaPublicationKey((await repo.trackById(first.id))!), key);
      files.fail = false;
      await controller.downloadSelected(queueIds: [first.id]);
      final saved = (await repo.trackById(first.id))!;
      expect(saved.status, TrackStatus.completed);
      expect(File(saved.localPath).uri.pathSegments.last, startsWith('002 - '));
      expect(downloader.calls, 1);
      expect(files.keys.toSet(), {key});
    } finally {
      controller.dispose();
      await temp.delete(recursive: true);
    }
  });
}

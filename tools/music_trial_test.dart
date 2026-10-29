// Explicit live trial, outside the default test suite. No saved sessions are read.
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:definitive_downloader/core/network/bounded_http.dart';
import 'package:definitive_downloader/core/platform/desktop_files.dart';
import 'package:definitive_downloader/core/storage/database.dart';
import 'package:definitive_downloader/features/connections/application/deezer_connection_controller.dart';
import 'package:definitive_downloader/features/downloads/download_service.dart';
import 'package:definitive_downloader/features/downloads/music_download_service.dart';
import 'package:definitive_downloader/features/importing/csv_importer.dart';
import 'package:definitive_downloader/features/importing/spotify_importer.dart';
import 'package:definitive_downloader/features/library/application/library_controller.dart';
import 'package:definitive_downloader/features/library/data/library_repository.dart';
import 'package:definitive_downloader/features/library/domain/models.dart';
import 'package:definitive_downloader/features/matching/deezer_catalog.dart';
import 'package:definitive_downloader/features/matching/music_engine.dart';
import 'package:definitive_downloader/features/matching/music_resolver.dart';

class NoSession implements DeezerSessionStore {
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String value) async =>
      throw StateError('No credentials in trial');
  @override
  Future<void> clear() async {}
}

void main() {
  final worker = Platform.environment['DD_LIVE_WORKER'];
  test('playlist Spotify importada -> apenas faixas musicais -> MP3 validado',
      () async {
    final source = AppDatabase(Platform.environment['DD_LIVE_DATABASE']!);
    final rows = await source.run((db) => db
        .select('''SELECT * FROM tracks WHERE collection_id=(
      SELECT id FROM collections WHERE source_url=? AND partial=0 ORDER BY id DESC LIMIT 1)
      ORDER BY position LIMIT 40''',
            ['https://open.spotify.com/playlist/4PYxm8yonIPl6XxizOPYb1'])
        .map((r) => Map<String, Object?>.from(r))
        .toList());
    expect(rows.length, 10);
    final resume = Platform.environment['DD_LIVE_RESUME_DIR'];
    final folder = resume == null
        ? await Directory(Platform.environment['DD_LIVE_OUTPUT']!)
            .createTemp('dd-music-trial-')
        : Directory(resume);
    final repository =
        LibraryRepository(AppDatabase('${folder.path}/trial.sqlite3'));
    await repository.database.initialize();
    if (resume == null) {
      await repository.importCollection(ImportedCollection(
          name: 'Teste - faixas de áudio',
          source: 'Cópia do Spotify importado',
          sourceUrl: '',
          tracks: Stream.fromIterable(rows.map((r) => TrackDraft(
              title: r['title'] as String,
              artist: r['artist'] as String,
              album: r['album'] as String,
              durationMs: r['duration_ms'] as int?,
              coverUrl: r['cover_url'] as String,
              isrc: r['isrc'] as String,
              sourceUrl: r['source_url'] as String,
              explicit: r['explicit'] == null ? null : r['explicit'] == 1)))));
    }
    final engine = WindowsMusicEngine(worker!);
    final connection = DeezerConnectionController(NoSession(), engine);
    final controller = LibraryController(
        repository: repository,
        files: DesktopFiles(),
        spotify: const SpotifyImporter(BoundedHttp()),
        csv: const CsvImporter(),
        catalog: const DeezerCatalog(BoundedHttp()),
        music: MusicResolver(engine, connection),
        downloader: DownloadService(const BoundedHttp(), rootBundle,
            music: MusicDownloadService(engine, connection)));
    controller.current = (await repository.collections()).first;
    controller.outputDirectory = folder.path;
    await controller.refresh();
    await controller.prepareMusic();
    final prepared = await repository.page(controller.current!.id);
    stdout.writeln(
        'LIVE_PREPARED ${prepared.items.where((t) => t.canDownload).length}/10');
    await controller.downloadSelected();
    final output = await repository.page(controller.current!.id);
    final report = {
      'desktop_ui_used': false,
      'saved_sessions_read': false,
      'deezer_connected': false,
      'input': 'previous authenticated Spotify import, playlist Teste',
      'expected': 10,
      'directory': folder.path,
      'message': controller.message,
      'tracks': output.items
          .map((t) => {
                'position': t.position,
                'title': t.title,
                'artist': t.artist,
                'source': t.sourceKind.name,
                'sourceUrl': t.mediaUrl,
                'status': t.status.name,
                'error': t.error,
                'file': t.localPath,
                'durationMs': t.outputDurationMs
              })
          .toList()
    };
    await File('${folder.path}/trial-report.json')
        .writeAsString(const JsonEncoder.withIndent('  ').convert(report));
    stdout.writeln('LIVE_REPORT ${folder.path}/trial-report.json');
    expect(output.items.any((t) => t.status == TrackStatus.completed), true);
    expect(
        output.items
            .where((t) => t.status == TrackStatus.completed)
            .every((t) => t.sourceKind == SourceKind.youtubeMusic),
        true);
    controller.dispose();
    connection.dispose();
  }, skip: worker == null, timeout: const Timeout(Duration(minutes: 15)));
}

import 'dart:io';

import 'package:definitive_downloader/core/network/bounded_http.dart';
import 'package:definitive_downloader/core/platform/android_files.dart';
import 'package:definitive_downloader/core/storage/database.dart';
import 'package:definitive_downloader/features/audio_capture/application/status_saver_controller.dart';
import 'package:definitive_downloader/features/connections/application/deezer_connection_controller.dart';
import 'package:definitive_downloader/features/downloads/download_service.dart';
import 'package:definitive_downloader/features/importing/csv_importer.dart';
import 'package:definitive_downloader/features/importing/spotify_importer.dart';
import 'package:definitive_downloader/features/library/application/library_controller.dart';
import 'package:definitive_downloader/features/library/data/library_repository.dart';
import 'package:definitive_downloader/features/library/domain/models.dart';
import 'package:definitive_downloader/features/matching/android_music_engine.dart';
import 'package:definitive_downloader/features/matching/deezer_catalog.dart';
import 'package:definitive_downloader/features/matching/music_resolver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class _Files extends AndroidFiles {
  _Files(this.output);
  final String output;
  final released = <String>[];
  @override
  Future<String> defaultOutputDirectory() async => output;
  @override
  Future<void> releaseWhatsAppStatuses(String path) async {
    await super.releaseWhatsAppStatuses(path);
    released.add(path);
  }
}

class _Sessions implements DeezerSessionStore {
  @override
  Future<void> clear() async {}
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String value) async {}
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Status Saver lê .Statuses pelo seletor e salva o áudio',
      (tester) async {
    final temp =
        await (await getTemporaryDirectory()).createTemp('dd-status-saver-');
    final files = _Files(p.join(temp.path, 'media'));
    final engine = await AndroidMusicEngine.installed();
    expect(engine.available, isTrue, reason: engine.initializationError);
    final library = LibraryController(
        repository: LibraryRepository(AppDatabase(p.join(temp.path, 'db'))),
        files: files,
        spotify: const SpotifyImporter(BoundedHttp()),
        csv: const CsvImporter(),
        catalog: const DeezerCatalog(BoundedHttp()),
        music: MusicResolver(
            engine, DeezerConnectionController(_Sessions(), engine)),
        downloader: DownloadService(const BoundedHttp(), rootBundle));
    final statuses = StatusSaverController(library);
    try {
      await library.initialize();
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      expect(statuses.available, isTrue);
      // The host fixture holds a video with sound, a silent video and a photo
      // in WhatsApp's .Statuses folder; it confirms the real system picker.
      debugPrint('DD_ANDROID_STATUS_PICK');
      await statuses.pick();
      expect(statuses.statuses.length, 2, reason: statuses.message);
      final copies = p.dirname(statuses.statuses.first.path);
      final playlist = await statuses.save();
      expect(playlist, isNotNull, reason: statuses.message);
      expect(playlist!.name, startsWith('Status do WhatsApp '));
      expect(statuses.message, contains('1 status sem áudio'));
      final tracks = (await library.repository.page(playlist.id)).items;
      expect(tracks, hasLength(1));
      final track = tracks.single;
      expect(track.title, startsWith('Status '));
      expect(track.sourceKind, SourceKind.localFile);
      expect(track.status, TrackStatus.completed);
      expect(p.extension(track.localPath), '.mp3');
      expect(await File(track.localPath).length(), greaterThan(1024));
      expect(files.released, [copies]);
      expect(await Directory(copies).exists(), isFalse);
      debugPrint('DD_ANDROID_STATUS_OK');
    } finally {
      statuses.dispose();
      library.dispose();
      await temp.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 4)));
}

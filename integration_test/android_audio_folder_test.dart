import 'dart:io';

import 'package:definitive_downloader/core/network/bounded_http.dart';
import 'package:definitive_downloader/core/platform/android_files.dart';
import 'package:definitive_downloader/core/storage/database.dart';
import 'package:definitive_downloader/features/downloads/download_service.dart';
import 'package:definitive_downloader/features/importing/csv_importer.dart';
import 'package:definitive_downloader/features/importing/spotify_importer.dart';
import 'package:definitive_downloader/features/library/application/library_controller.dart';
import 'package:definitive_downloader/features/library/data/library_repository.dart';
import 'package:definitive_downloader/features/library/domain/models.dart';
import 'package:definitive_downloader/features/matching/deezer_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class _FolderFiles extends AndroidFiles {
  _FolderFiles(this.output);

  final String output;
  String? released;

  @override
  Future<String> defaultOutputDirectory() async => output;

  @override
  Future<void> releaseAudioFolder(String path) async {
    await super.releaseAudioFolder(path);
    released = path;
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('seletor SAF importa pasta e subpasta com mídia local',
      (tester) async {
    final temp =
        await (await getTemporaryDirectory()).createTemp('dd-saf-audio-');
    final files = _FolderFiles(p.join(temp.path, 'media'));
    final repository =
        LibraryRepository(AppDatabase(p.join(temp.path, 'test.db')));
    final library = LibraryController(
        repository: repository,
        files: files,
        spotify: const SpotifyImporter(BoundedHttp()),
        csv: const CsvImporter(),
        catalog: const DeezerCatalog(BoundedHttp()),
        downloader: DownloadService(const BoundedHttp(), rootBundle));
    try {
      await library.initialize();
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      // The host fixture selects a tree containing an audio file, a subfolder
      // with another audio file, and a text file through the real system picker.
      debugPrint('DD_ANDROID_AUDIO_FOLDER_PICK');
      final playlist = await library.chooseLocalFolder();
      expect(playlist, isNotNull, reason: library.message);
      expect(playlist!.name, startsWith('00-DD-Pasta-'));
      final tracks = (await repository.page(playlist.id)).items;
      expect(tracks.map((track) => track.title), ['Abertura', 'Final']);
      expect(tracks.map((track) => track.position), [1, 2]);
      expect(tracks.map((track) => track.status),
          [TrackStatus.completed, TrackStatus.completed]);
      for (final track in tracks) {
        expect(track.sourceKind, SourceKind.localFile);
        expect(p.extension(track.localPath), '.wav');
        expect(await File(track.localPath).length(), greaterThan(64));
      }
      expect(files.released, isNotNull);
      expect(await Directory(files.released!).exists(), isFalse);
      debugPrint('DD_ANDROID_AUDIO_FOLDER_OK');
    } finally {
      library.dispose();
      await temp.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}

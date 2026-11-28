import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:definitive_downloader/core/network/bounded_http.dart';
import 'package:definitive_downloader/core/platform/desktop_files.dart';
import 'package:definitive_downloader/core/storage/database.dart';
import 'package:definitive_downloader/features/audio_capture/application/status_saver_controller.dart';
import 'package:definitive_downloader/features/audio_capture/domain/status_saver.dart';
import 'package:definitive_downloader/features/connections/application/deezer_connection_controller.dart';
import 'package:definitive_downloader/features/downloads/download_service.dart';
import 'package:definitive_downloader/features/importing/csv_importer.dart';
import 'package:definitive_downloader/features/importing/local_mp3_inspector.dart';
import 'package:definitive_downloader/features/importing/spotify_importer.dart';
import 'package:definitive_downloader/features/library/application/library_controller.dart';
import 'package:definitive_downloader/features/library/data/library_repository.dart';
import 'package:definitive_downloader/features/library/domain/models.dart';
import 'package:definitive_downloader/features/matching/deezer_catalog.dart';
import 'package:definitive_downloader/features/matching/music_engine.dart';
import 'package:definitive_downloader/features/matching/music_resolver.dart';
import 'music_resolver_test.dart' show EmptySession;

class _StatusFiles extends DesktopFiles {
  _StatusFiles(this.root, this.statuses);
  final String root;
  final String? statuses;
  final released = <String>[];
  @override
  bool get supportsStatusSaver => true;
  @override
  Future<String> defaultOutputDirectory() async => '$root/output';
  @override
  Future<String?> chooseWhatsAppStatuses() async => statuses;
  @override
  Future<void> releaseWhatsAppStatuses(String path) async {
    released.add(path);
    await Directory(path).delete(recursive: true);
  }
}

class _ExtractEngine implements MusicEngine {
  final calls = <Map<String, dynamic>>[];
  @override
  bool get available => true;
  @override
  Future<Map<String, dynamic>> call(Map<String, dynamic> request,
      {DownloadCancellation? cancellation,
      void Function(String)? onStage,
      void Function(TransferProgress)? onProgress}) async {
    calls.add(request);
    if (request['operation'] != 'extractAudio') {
      throw StateError('Operação inesperada.');
    }
    if ((request['path'] as String).contains('mudo')) {
      throw const FormatException(
          'Este status não tem áudio que possa ser extraído.');
    }
    final bytes = await rootBundle.load('assets/demo/tone.mp3');
    final path = p.join(request['directory'] as String, 'verified.mp3');
    await File(path).writeAsBytes(bytes.buffer.asUint8List());
    return {'path': path, 'durationMs': 4000, 'decoded': true};
  }
}

class _Inspector implements LocalAudioInspector {
  const _Inspector();
  @override
  Future<LocalAudioMetadata> inspect(String path) async =>
      const LocalAudioMetadata(durationMs: 4000);
}

Future<(LibraryController, _StatusFiles, _ExtractEngine)> _library(
    Directory temp, String? statuses) async {
  final engine = _ExtractEngine();
  final files = _StatusFiles(temp.path, statuses);
  final connection = DeezerConnectionController(EmptySession(), engine);
  final library = LibraryController(
      repository: LibraryRepository(AppDatabase(p.join(temp.path, 'db'))),
      files: files,
      spotify: const SpotifyImporter(BoundedHttp()),
      csv: const CsvImporter(),
      catalog: const DeezerCatalog(BoundedHttp()),
      music: MusicResolver(engine, connection),
      localInspector: const _Inspector(),
      downloader: DownloadService(const BoundedHttp(), rootBundle));
  await library.initialize();
  return (library, files, engine);
}

Future<Directory> _statusCopies(Directory temp) async {
  final folder = await Directory(p.join(temp.path, 'statuses')).create();
  Future<void> status(String name, DateTime modified) async {
    final file = File(p.join(folder.path, name));
    await file.writeAsBytes(List.filled(4096, 7));
    await file.setLastModified(modified);
  }

  await status('000-novo.mp4', DateTime(2026, 11, 27, 14, 30));
  await status('001-mudo.mp4', DateTime(2026, 11, 27, 13, 5));
  await status('002-voz.opus', DateTime(2026, 11, 27, 9, 0));
  await File(p.join(folder.path, '003-foto.jpg')).writeAsBytes([1, 2, 3]);
  return folder;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('títulos e nome da playlist dos status', () {
    final at = DateTime(2026, 11, 27, 14, 30);
    final statuses = [
      for (final _ in [1, 2])
        WhatsAppStatus(path: 'x', modified: at, bytes: 1, isVideo: true),
    ];
    expect(statusTitles(statuses),
        ['Status 27/11 14:30', 'Status 27/11 14:30 (2)']);
    expect(statusPlaylistName(at), 'Status do WhatsApp 27-11-2026 14h30');
    expect(formatStatusBytes(2 * 1024 * 1024 + 300000), '2,3 MB');
  });

  test('Status Saver extrai os escolhidos, ignora mudo e cria a playlist',
      () async {
    final temp = await Directory.systemTemp.createTemp('dd-status-');
    final copies = await _statusCopies(temp);
    final (library, files, engine) = await _library(temp, copies.path);
    final controller = StatusSaverController(library);
    try {
      expect(controller.available, isTrue);
      await controller.pick();
      expect(controller.statuses.map((s) => p.basename(s.path)),
          ['000-novo.mp4', '001-mudo.mp4', '002-voz.opus'],
          reason: 'A foto fica de fora.');
      expect(controller.statuses.map((s) => s.isVideo), [true, true, false]);
      expect(controller.titles.first, 'Status 27/11 14:30');
      expect(controller.selected, hasLength(3));

      final playlist = await controller.save();
      expect(playlist, isNotNull, reason: controller.message);
      expect(playlist!.name, startsWith('Status do WhatsApp '));
      expect(controller.message, contains('Áudio de 2 status'));
      expect(controller.message, contains('1 status sem áudio'));
      final tracks = (await library.repository.page(playlist.id)).items;
      expect(tracks.map((t) => t.title),
          ['Status 27-11 14-30', 'Status 27-11 09-00']);
      expect(tracks.map((t) => t.position), [1, 2]);
      for (final track in tracks) {
        expect(track.sourceKind, SourceKind.localFile);
        expect(track.status, TrackStatus.completed);
        expect(await File(track.localPath).exists(), isTrue);
      }
      expect(engine.calls.map((c) => c['title']),
          ['Status 27/11 14:30', 'Status 27/11 13:05', 'Status 27/11 09:00']);
      expect(files.released, [copies.path]);
      expect(await copies.exists(), isFalse);
      expect(controller.hasStatuses, isFalse);
    } finally {
      controller.dispose();
      library.dispose();
      await temp.delete(recursive: true);
    }
  });

  test('seleção parcial, descarte e seletor cancelado', () async {
    final temp = await Directory.systemTemp.createTemp('dd-status-');
    final copies = await _statusCopies(temp);
    final (library, files, engine) = await _library(temp, copies.path);
    final controller = StatusSaverController(library);
    try {
      await controller.pick();
      controller.selectAll(false);
      expect(await controller.save(), isNull);
      expect(engine.calls, isEmpty);
      await controller.discard();
      expect(controller.hasStatuses, isFalse);
      expect(files.released, [copies.path]);
      expect(library.collections, isEmpty);
    } finally {
      controller.dispose();
      library.dispose();
      await temp.delete(recursive: true);
    }
    final empty = await Directory.systemTemp.createTemp('dd-status-');
    final (other, _, _) = await _library(empty, null);
    final cancelled = StatusSaverController(other);
    try {
      await cancelled.pick();
      expect(cancelled.hasStatuses, isFalse);
      expect(cancelled.message, isEmpty);
    } finally {
      cancelled.dispose();
      other.dispose();
      await empty.delete(recursive: true);
    }
  });

  test('sem pasta de status no Windows o botão não aparece', () {
    expect(DesktopFiles().supportsStatusSaver, isFalse);
  });
}

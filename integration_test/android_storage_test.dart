import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:definitive_downloader/core/network/bounded_http.dart';
import 'package:definitive_downloader/core/platform/android_files.dart';
import 'package:definitive_downloader/core/platform/android_incoming.dart';
import 'package:definitive_downloader/core/storage/database.dart';
import 'package:definitive_downloader/features/downloads/download_service.dart';
import 'package:definitive_downloader/features/importing/csv_importer.dart';
import 'package:definitive_downloader/features/importing/spotify_importer.dart';
import 'package:definitive_downloader/features/library/application/library_controller.dart';
import 'package:definitive_downloader/features/library/data/library_repository.dart';
import 'package:definitive_downloader/features/library/presentation/incoming_music_host.dart';
import 'package:definitive_downloader/features/matching/deezer_catalog.dart';

class _Files extends AndroidFiles {
  _Files(this.output);
  final String output;
  @override
  Future<String> defaultOutputDirectory() async => output;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('compartilhar texto e MP3, revisar e exportar cópia SAF',
      (tester) async {
    final temp =
        await (await getTemporaryDirectory()).createTemp('dd-storage-');
    final media = await Directory(
            '${await AndroidFiles().defaultOutputDirectory()}/fixture-${DateTime.now().microsecondsSinceEpoch}')
        .create();
    final files = _Files(media.path);
    final library = LibraryController(
        repository: LibraryRepository(AppDatabase('${temp.path}/db')),
        files: files,
        spotify: const SpotifyImporter(BoundedHttp()),
        csv: const CsvImporter(),
        catalog: const DeezerCatalog(BoundedHttp()),
        downloader: DownloadService(const BoundedHttp(), rootBundle));
    await library.initialize();
    final id = await library.createPlaylist('Fixture export');
    final inbox = AndroidIncoming();
    // Clean only prior receipts in this isolated test package.
    while (true) {
      final old = await inbox.peek();
      if (old == null) break;
      await inbox.finish(old.id);
    }
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: IncomingMusicHost(
                incoming: inbox,
                library: library,
                child: const Text('Biblioteca de fixture')))));
    Future<void> until(bool Function() ready) async {
      final clock = Stopwatch()..start();
      while (!ready()) {
        if (clock.elapsed > const Duration(seconds: 90)) {
          throw TimeoutException('Automação de armazenamento não respondeu.');
        }
        await tester.pump(const Duration(milliseconds: 100));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      await tester.pump(const Duration(milliseconds: 350));
    }

    try {
      debugPrint('ANDROID_STORAGE_SHARE_TEXT');
      await until(
          () => find.text('Recebido de outro app').evaluate().isNotEmpty);
      expect(library.collections.single.trackCount, 0);
      expect(library.downloading, isFalse);
      await tester.tap(find.text('Cancelar'));
      await until(() => find.text('Recebido de outro app').evaluate().isEmpty);
      debugPrint('ANDROID_STORAGE_SHARE_MP3');
      await until(
          () => find.text('Recebido de outro app').evaluate().isNotEmpty);
      expect(find.textContaining('1 arquivo(s) MP3'), findsOneWidget);
      await tester.tap(find.text('Adicionar'));
      await until(() =>
          library.collections.single.completedCount == 1 &&
          !library.addingLinks);
      await until(() => find.text('Recebido de outro app').evaluate().isEmpty);
      final tracks = await library.repository.completedPage(id, 0);
      expect(tracks.single.position, 1);
      final audio = await rootBundle.load('assets/demo/tone.mp3');
      expect(await File(tracks.single.localPath).readAsBytes(),
          audio.buffer.asUint8List(audio.offsetInBytes, audio.lengthInBytes));
      final folder = File(tracks.single.localPath).parent.path;
      final support = (await getApplicationSupportDirectory()).path;
      final plan = File('$support/storage-export-plan.json');
      final planClock = Stopwatch()..start();
      debugPrint('ANDROID_STORAGE_PREPARE_JOURNAL');
      while (!await plan.exists()) {
        if (planClock.elapsed > const Duration(seconds: 40)) {
          throw TimeoutException('Diário de fixture não foi preparado.');
        }
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      final journalPlan =
          jsonDecode(await plan.readAsString()) as Map<String, dynamic>;
      await plan.delete();
      final journal = sqlite3.open(
          '${Directory(support).parent.path}/databases/public-exports.sqlite3');
      try {
        journal.execute(
            'CREATE TABLE IF NOT EXISTS exports(id TEXT PRIMARY KEY,uri TEXT NOT NULL)');
        journal.execute(
            'CREATE TABLE IF NOT EXISTS documents(operation TEXT NOT NULL,uri TEXT PRIMARY KEY,parent TEXT NOT NULL,directory INTEGER NOT NULL)');
        journal.execute(
            'CREATE INDEX IF NOT EXISTS documents_operation ON documents(operation)');
        journal.execute('PRAGMA user_version=2');
        journal.execute('INSERT INTO exports(id,uri) VALUES(?,?)',
            [journalPlan['id'], journalPlan['root']]);
        journal.execute(
            'INSERT INTO documents(operation,uri,parent,directory) VALUES(?,?,?,0)',
            [journalPlan['id'], journalPlan['file'], journalPlan['root']]);
      } finally {
        journal.dispose();
      }
      await files.openFolder(folder);
      debugPrint('ANDROID_STORAGE_EXPORT_BLOCKED');
      final retry = File('$support/storage-export-retry');
      final retryClock = Stopwatch()..start();
      while (!await retry.exists()) {
        if (retryClock.elapsed > const Duration(seconds: 90)) {
          throw TimeoutException(
              'Proteção do conteúdo público não foi verificada.');
        }
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      await retry.delete();
      await files.openFolder(folder);
      debugPrint('ANDROID_STORAGE_EXPORT');
      final marker = File(
          '${(await getApplicationSupportDirectory()).path}/storage-export-verified');
      final clock = Stopwatch()..start();
      while (!await marker.exists()) {
        if (clock.elapsed > const Duration(seconds: 120)) {
          throw TimeoutException('Exportação SAF não foi verificada.');
        }
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
      await marker.delete();
      expect(await File(tracks.single.localPath).readAsBytes(),
          audio.buffer.asUint8List(audio.offsetInBytes, audio.lengthInBytes));
      expect(library.downloading, isFalse);
      expect(await inbox.peek(), isNull);
      await tester.pumpWidget(const SizedBox());
      debugPrint('ANDROID_STORAGE_OVERFLOW');
      final sent = File('$support/storage-overflow-sent');
      final burstClock = Stopwatch()..start();
      while (!await sent.exists()) {
        if (burstClock.elapsed > const Duration(seconds: 60)) {
          throw TimeoutException('Lote de compartilhamentos não foi enviado.');
        }
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      await sent.delete();
      IncomingMusic? overflow;
      for (var attempt = 0; attempt < 100; attempt++) {
        overflow = await inbox.peek();
        if (overflow?.id == 'overflow') break;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      expect(overflow?.id, 'overflow');
      await inbox.finish('overflow');
      var count = 0;
      while (true) {
        final batch = await inbox.peek();
        if (batch == null) break;
        count++;
        expect(batch.error, isEmpty);
        await inbox.finish(batch.id);
      }
      expect(count, 8);
      expect(library.collections.single.completedCount, 1);
      final cleanJournal = sqlite3.open(
          '${Directory(support).parent.path}/databases/public-exports.sqlite3');
      try {
        expect(
            cleanJournal
                .select('SELECT COUNT(*) AS n FROM exports')
                .single['n'],
            0);
        expect(
            cleanJournal
                .select('SELECT COUNT(*) AS n FROM documents')
                .single['n'],
            0);
      } finally {
        cleanJournal.dispose();
      }
      expect(tester.takeException(), isNull);
      debugPrint('ANDROID_STORAGE_VERIFIED');
    } finally {
      await tester.pumpWidget(const SizedBox());
      inbox.dispose();
      library.dispose();
      await media.delete(recursive: true);
      await temp.delete(recursive: true);
    }
  });
}

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:definitive_downloader/core/storage/database.dart';
import 'package:definitive_downloader/features/library/data/library_repository.dart';
import 'package:definitive_downloader/features/library/domain/models.dart';
import 'package:definitive_downloader/features/organization/data/collection_organization_repository.dart';
import 'package:definitive_downloader/core/platform/desktop_files.dart';
import 'package:definitive_downloader/core/storage/legacy_library_migration.dart';
import 'package:definitive_downloader/core/storage/publish_library_snapshot.dart';

class _LibraryPaths extends DesktopFiles {
  _LibraryPaths(this.old, this.local);
  final String old, local;
  @override
  Future<String> dataDirectory() async => old;
  @override
  Future<String> localLibraryDirectory() async => local;
}

void main() {
  test(
      'snapshot inclui WAL confirmado e nunca substitui biblioteca local existente',
      () async {
    final root = await Directory.systemTemp.createTemp('dd-wal-copy-');
    final sourcePath = '${root.path}/Perfil João 🎵/old.sqlite3';
    final destination = '${root.path}/Local/library.sqlite3';
    Database? writer;
    try {
      await AppDatabase(sourcePath).initialize();
      writer = sqlite3.open(sourcePath);
      writer.execute('PRAGMA journal_mode=WAL');
      writer.execute('PRAGMA wal_autocheckpoint=0');
      writer
          .execute("INSERT INTO preferences VALUES('fixture','committed-wal')");
      expect(await File('$sourcePath-wal').exists(), isTrue);
      expect(
          await migrateLegacyLibrary(
              sourcePath: sourcePath, destinationPath: destination),
          isTrue);
      final local = LibraryRepository(AppDatabase(destination));
      expect(await local.preference('fixture'), 'committed-wal');
      await local.setPreference('fixture', 'local-newer');
      expect(
          await migrateLegacyLibrary(
              sourcePath: sourcePath, destinationPath: destination),
          isFalse);
      expect(await local.preference('fixture'), 'local-newer');
    } finally {
      writer?.dispose();
      await root.delete(recursive: true);
    }
  });

  test('aberturas simultâneas publicam uma única cópia sem sobrescrever',
      () async {
    final root = await Directory.systemTemp.createTemp('dd-migration-lock-');
    try {
      final source = '${root.path}/old.sqlite3';
      final destination = '${root.path}/Local/library.sqlite3';
      await AppDatabase(source).initialize();
      await LibraryRepository(AppDatabase(source))
          .setPreference('fixture', 'original');
      final results = await Future.wait(List.generate(
          3,
          (_) => migrateLegacyLibrary(
              sourcePath: source, destinationPath: destination)));
      expect(results.where((copied) => copied).length, 1);
      expect(
          await LibraryRepository(AppDatabase(destination))
              .preference('fixture'),
          'original');
      final staging =
          await File('${root.path}/other.sqlite3').writeAsBytes([9, 8, 7]);
      expect(await publishLibrarySnapshot(staging.path, destination), isFalse);
      expect(await staging.readAsBytes(), [9, 8, 7]);
      expect(
          await LibraryRepository(AppDatabase(destination))
              .preference('fixture'),
          'original');
    } finally {
      await root.delete(recursive: true);
    }
  }, skip: !Platform.isWindows);

  test('biblioteca legível com journal indisponível volta a importar e excluir',
      () async {
    final root = await Directory.systemTemp.createTemp('dd-journal-access-');
    final oldPath = '${root.path}/roaming/definitive_downloader.sqlite3';
    try {
      final old = LibraryRepository(AppDatabase(oldPath));
      await old.database.initialize();
      final id = await old.importCollection(ImportedCollection(
          name: 'Antiga',
          source: 'Spotify',
          sourceUrl: '',
          tracks: Stream.value(
              const TrackDraft(title: 'Preservada', artist: 'Pessoa'))));
      final track = (await old.page(id)).items.single;
      await old.select(track.id, true);
      final original = await File(oldPath).readAsBytes();
      await Directory('$oldPath-journal').create();
      expect((await old.collections()).single.id, id); // Reading still works.
      final path =
          await _LibraryPaths('${root.path}/roaming', '${root.path}/local')
              .databasePath();
      final library = LibraryRepository(AppDatabase(path));
      await library.database.initialize();
      final added = await library.importCollection(ImportedCollection(
          name: 'Nova',
          source: 'Spotify',
          sourceUrl: '',
          tracks: Stream.value(
              const TrackDraft(title: 'Nova faixa', artist: 'Pessoa'))));
      expect((await library.page(id)).items.single.id, track.id);
      expect((await library.page(id)).items.single.selected, isTrue);
      await CollectionOrganizationRepository(library.database).remove(id);
      expect((await library.collections()).map((c) => c.id), [added]);
      expect(await File(oldPath).readAsBytes(), original);
    } finally {
      await root.delete(recursive: true);
    }
  }, skip: !Platform.isWindows);

  test('importar e excluir com diretório temporário SQLite indisponível',
      () async {
    final root = await Directory.systemTemp.createTemp('dd-db-access-');
    final previous = sqlite3.tempDirectory;
    final database = AppDatabase('${root.path}/biblioteca.sqlite3');
    try {
      await database.initialize();
      final library = LibraryRepository(database);
      final old = await library.importCollection(ImportedCollection(
          name: 'Salva',
          source: 'Spotify',
          sourceUrl: '',
          tracks: Stream.value(
              const TrackDraft(title: 'Música', artist: 'Pessoa'))));
      sqlite3.tempDirectory = '${root.path}/temporary-path-does-not-exist';
      expect((await library.collections()).single.id, old);
      final added = await library.importCollection(ImportedCollection(
          name: 'Outra',
          source: 'Spotify',
          sourceUrl: '',
          tracks: Stream.value(
              const TrackDraft(title: 'Faixa', artist: 'Pessoa'))));
      await CollectionOrganizationRepository(database).remove(old);
      expect((await library.collections()).map((c) => c.id), [added]);
    } finally {
      sqlite3.tempDirectory = previous;
      await root.delete(recursive: true);
    }
  });
}

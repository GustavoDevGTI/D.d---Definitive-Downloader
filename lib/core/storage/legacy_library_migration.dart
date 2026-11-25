import 'dart:io';
import 'dart:isolate';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'publish_library_snapshot.dart';

/// Copies a consistent SQLite snapshot once; never replaces an existing library.
Future<bool> migrateLegacyLibrary({
  required String sourcePath,
  required String destinationPath,
}) async {
  if (p.equals(p.absolute(sourcePath), p.absolute(destinationPath)) ||
      !await File(sourcePath).exists()) {
    return false;
  }
  final parent = await File(destinationPath).parent.create(recursive: true);
  final canonicalParent = await parent.resolveSymbolicLinks();
  final lock = await File(p.join(canonicalParent, '.dd-library-migration.lock'))
      .open(mode: FileMode.append);
  Directory? work;
  try {
    await lock.lock(FileLock.blockingExclusive);
    if (await FileSystemEntity.type(destinationPath, followLinks: false) !=
        FileSystemEntityType.notFound) {
      return false;
    }
    work = await Directory(canonicalParent).createTemp('.dd-library-copy-');
    final temporary = p.join(work.path, 'library.sqlite3');
    await Isolate.run(() async {
      // A readable old database may be unable to create its rollback journal.
      // Backup reads the source without changing it and includes committed WAL.
      final source = sqlite3.open(sourcePath, mode: OpenMode.readOnly);
      Database? target;
      try {
        source.execute('PRAGMA busy_timeout=5000');
        target = sqlite3.open(temporary);
        await source
            .backup(target, nPage: 64)
            .timeout(const Duration(seconds: 60))
            .drain<void>();
        if (target.select('PRAGMA quick_check').single.values.single != 'ok') {
          throw const FormatException(
              'A cópia da biblioteca não passou na verificação.');
        }
      } finally {
        target?.dispose();
        source.dispose();
      }
    });
    return await publishLibrarySnapshot(temporary, destinationPath);
  } finally {
    try {
      if (work != null &&
          p.isWithin(canonicalParent, work.path) &&
          await work.resolveSymbolicLinks() == work.path) {
        await work.delete(recursive: true);
      }
    } on FileSystemException {
      /* Preserve the original result and old library. */
    }
    await lock.close();
  }
}

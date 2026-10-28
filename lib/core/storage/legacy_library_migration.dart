import 'dart:io';
import 'package:path/path.dart' as p;
import 'database.dart';

/// Copies a consistent SQLite snapshot once; never replaces an existing library.
Future<bool> migrateLegacyLibrary({
  required String sourcePath,
  required String destinationPath,
}) async {
  if (p.equals(p.absolute(sourcePath), p.absolute(destinationPath)) ||
      await File(destinationPath).exists() ||
      !await File(sourcePath).exists()) {
    return false;
  }
  await File(destinationPath).parent.create(recursive: true);
  final temporary = File('$destinationPath.migrating');
  if (await temporary.exists()) {
    throw const FileSystemException(
        'Há uma migração incompleta da biblioteca. Preserve os arquivos para recuperação.');
  }
  try {
    await AppDatabase(sourcePath)
        .run((db) => db.execute('VACUUM INTO ?', [temporary.path]));
    final valid = await AppDatabase(temporary.path).run(
        (db) => db.select('PRAGMA quick_check').single.values.single == 'ok');
    if (!valid) {
      throw const FormatException(
          'A cópia da biblioteca não passou na verificação.');
    }
    // Windows rename fails if the destination appeared; preserve that library.
    await temporary.rename(destinationPath);
    return true;
  } catch (_) {
    if (await temporary.exists()) await temporary.delete();
    rethrow;
  }
}

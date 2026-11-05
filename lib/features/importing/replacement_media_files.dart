import 'dart:io';
import 'package:path/path.dart' as p;
import '../downloads/download_cancellation.dart';
import '../downloads/download_file_name.dart';
import '../downloads/playlist_exporter.dart';
import '../library/data/library_repository.dart';
import '../library/domain/models.dart';

/// Reversible removal with a relational crash journal; never touches originals
/// imported from outside the collection or files shared by another occurrence.
class ReplacementMediaFiles {
  const ReplacementMediaFiles(this.repository);
  final LibraryRepository repository;

  Future<String> stage(
      Collection owner, List<Track> tracks, DownloadCancellation token) async {
    final operation = '${DateTime.now().microsecondsSinceEpoch}';
    try {
      for (final t in tracks) {
        token.check();
        if (t.localPath.isEmpty) continue;
        final file = File(t.localPath);
        final expected = '${safeSegment(owner.outputFolderName)} [${owner.id}]';
        if (!p.isAbsolute(file.path) ||
            p.basename(file.parent.path) != expected ||
            p.extension(file.path).toLowerCase() != '.mp3') {
          throw const FormatException(
              'O arquivo antigo está fora da pasta da playlist. Nada foi excluído.');
        }
        final allowed = await repository.database.run((db) =>
            db.select(
                'SELECT id FROM download_history WHERE track_id=? AND local_path=? AND category=\'music\'',
                [
                  t.id,
                  t.localPath
                ]).isNotEmpty &&
            !db.select('SELECT id FROM tracks WHERE local_path=? AND id!=?', [
              t.localPath,
              t.id
            ]).any((r) => !tracks.any((x) => x.id == r['id'])));
        if (!allowed) {
          throw const FormatException(
              'O arquivo antigo não é exclusivo desta playlist. Nada foi excluído.');
        }
        final type = await FileSystemEntity.type(file.path, followLinks: false);
        if (type == FileSystemEntityType.notFound) continue;
        if (type != FileSystemEntityType.file ||
            await file.resolveSymbolicLinks() !=
                p.join(await file.parent.resolveSymbolicLinks(),
                    p.basename(file.path))) {
          throw const FormatException(
              'O arquivo antigo não é uma mídia local regular.');
        }
        final folder = await file.parent.createTemp('.dd-replace-');
        final staged = p.join(folder.path, 'media.mp3');
        final canonicalFolder = await file.parent.resolveSymbolicLinks();
        await repository.database.run((db) => db.execute(
            'INSERT INTO music_replacement_files VALUES(?,?,?,?,?,?)',
            [operation, t.id, file.path, staged, canonicalFolder, owner.id]));
        await file.rename(staged);
      }
      return operation;
    } catch (_) {
      final warning = await recover(operation: operation);
      if (warning != null) throw FormatException(warning);
      rethrow;
    }
  }

  /// Existing occurrence => restore; deleted occurrence => finish its explicit
  /// removal. A journal entry is cleared only after the file action succeeds.
  Future<String?> recover(
      {String? operation, bool updatePlaylist = true}) async {
    final entries = await repository.database.run((db) => db
        .select(
            'SELECT * FROM music_replacement_files ${operation == null ? '' : 'WHERE operation=?'} LIMIT 10001',
            operation == null ? [] : [operation])
        .map((r) => Map<String, Object?>.from(r))
        .toList());
    if (entries.length > 10000) {
      return 'Há substituições locais pendentes acima do limite de recuperação.';
    }
    var failed = false;
    var exportFailed = false;
    final exports = <(int, String)>{};
    for (final r in entries) {
      try {
        final original = File(r['original'] as String),
            staged = File(r['staging'] as String);
        final parent = staged.parent;
        final expectedFolder = r['folder'] as String;
        if (!p.isAbsolute(original.path) ||
            !p.isWithin(original.parent.path, parent.path) ||
            p.dirname(parent.path) != original.parent.path ||
            !p.basename(parent.path).startsWith('.dd-replace-') ||
            p.basename(staged.path) != 'media.mp3') {
          throw const FormatException('Diário local inválido.');
        }
        if (await original.parent.exists() &&
            await original.parent.resolveSymbolicLinks() != expectedFolder) {
          throw const FormatException('Pasta da mídia redirecionada.');
        }
        if (await parent.exists() &&
            await parent.resolveSymbolicLinks() !=
                p.join(expectedFolder, p.basename(parent.path))) {
          throw const FormatException('Pasta de recuperação redirecionada.');
        }
        final retained = await repository.database.run((db) => db.select(
            'SELECT id FROM tracks WHERE id=? AND local_path=?',
            [r['track_id'], original.path]).isNotEmpty);
        if (await staged.exists()) {
          if (retained) {
            if (await original.exists()) {
              throw const FormatException(
                  'O destino da restauração já existe.');
            }
            await staged.rename(original.path);
          } else {
            await staged.delete();
          }
        }
        if (await parent.exists()) {
          await parent.delete(); // only an empty owned directory
        }
        await repository.database.run((db) => db.execute(
            'DELETE FROM music_replacement_files WHERE operation=? AND track_id=?',
            [r['operation'], r['track_id']]));
        if (!retained) {
          exports.add((r['collection_id'] as int, original.parent.path));
        }
      } catch (_) {
        failed = true;
      }
    }
    if (updatePlaylist) {
      for (final item in exports) {
        try {
          if (await repository.collectionById(item.$1) != null &&
              await Directory(item.$2).exists()) {
            await PlaylistExporter(repository).export(item.$1, item.$2);
          }
        } catch (_) {
          exportFailed = true;
        }
      }
    }
    return failed
        ? 'Não foi possível finalizar a remoção/restauração de um arquivo. O diário foi preservado para recuperação.'
        : exportFailed
            ? 'Arquivos substituídos, mas não foi possível atualizar a M3U8 da playlist.'
            : null;
  }
}

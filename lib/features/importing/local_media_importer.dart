import 'dart:io';
import 'package:path/path.dart' as p;
import '../downloads/download_cancellation.dart';
import '../downloads/download_file_name.dart';
import '../downloads/playlist_exporter.dart';
import '../library/data/library_repository.dart';
import '../library/domain/models.dart';
import '../organization/data/collection_organization_repository.dart';
import 'local_media_repository.dart';
import 'local_mp3_inspector.dart';
import '../../core/platform/desktop_files.dart';
import '../../core/platform/platform_services.dart';
import '../../core/platform/media_publication.dart';

class LocalMediaImporter {
  const LocalMediaImporter(this.repository,
      {this.inspector = const MediaKitLocalAudioInspector(), this.files});
  final LibraryRepository repository;
  final LocalAudioInspector inspector;
  final DesktopFiles? files;

  Future<String> add(
          int collectionId, List<String> paths, String outputDirectory,
          {required DownloadCancellation cancellation,
          Future<String> Function(Collection owner)? directoryFor,
          void Function(String)? onProgress}) =>
      _add(collectionId, paths, outputDirectory,
          directoryFor: directoryFor,
          cancellation: cancellation,
          onProgress: onProgress);

  Future<({int id, String message})> importFolder(
      String path, String outputDirectory,
      {int? groupId,
      required DownloadCancellation cancellation,
      Future<String> Function(Collection owner)? directoryFor,
      void Function(String)? onProgress}) async {
    final name = p.basename(p.normalize(path));
    if (!p.isAbsolute(path) || name.isEmpty) {
      throw const FormatException('Selecione uma pasta de áudio.');
    }
    final source = Directory(await Directory(path).resolveSymbolicLinks());
    final paths = <String>[];
    await for (final item in source.list(recursive: true, followLinks: false)) {
      cancellation.check();
      if (item is File &&
          localAudioExtensions.contains(p.extension(item.path).toLowerCase())) {
        paths.add(item.path);
        if (paths.length > 10000) {
          throw const FormatException('Limite de 10.000 faixas por playlist.');
        }
      }
    }
    if (paths.isEmpty) {
      throw const FormatException('Nenhum áudio compatível nesta pasta.');
    }
    paths.sort((a, b) {
      final order = a.toLowerCase().compareTo(b.toLowerCase());
      return order == 0 ? a.compareTo(b) : order;
    });
    cancellation.check();
    final organization = CollectionOrganizationRepository(repository.database);
    final id = await organization.create(name, groupId: groupId, partial: true);
    try {
      final message = await _add(id, paths, outputDirectory,
          sourceRoot: source.path,
          directoryFor: directoryFor,
          cancellation: cancellation,
          onProgress: onProgress);
      return (id: id, message: message);
    } catch (_) {
      await organization.remove(id);
      rethrow;
    }
  }

  Future<String> _add(
      int collectionId, List<String> paths, String outputDirectory,
      {String? sourceRoot,
      Future<String> Function(Collection owner)? directoryFor,
      required DownloadCancellation cancellation,
      void Function(String)? onProgress}) async {
    final folderImport = sourceRoot != null;
    if (paths.isEmpty || paths.length > (folderImport ? 10000 : 100)) {
      throw const FormatException(
          'Adicione de 1 a 100 arquivos de áudio por vez.');
    }
    final extensions =
        paths.map((path) => p.extension(path).toLowerCase()).toList();
    var total = 0;
    for (final path in paths) {
      cancellation.check();
      if (!p.isAbsolute(path) ||
          !localAudioExtensions.contains(p.extension(path).toLowerCase()) ||
          path.contains('\x00')) {
        throw const FormatException('Selecione arquivos de áudio compatíveis.');
      }
      final stat = await File(path).stat();
      if (stat.type != FileSystemEntityType.file ||
          stat.size < 64 ||
          stat.size > maximumLocalAudioBytes) {
        throw const FormatException(
            'Arquivo indisponível ou fora do limite de 2 GB por áudio.');
      }
      total += stat.size;
      if (total > maximumLocalAudioBatchBytes) {
        throw const FormatException('O lote de áudio ultrapassa 10 GB.');
      }
    }
    final storage = LocalMediaRepository(repository.database);
    final initial = await storage.target(collectionId, paths.length);
    final directory = await directoryFor?.call(initial.owner) ??
        p.join(outputDirectory,
            '${safeSegment(initial.owner.outputFolderName)} [${initial.owner.id}]');
    final root = await Directory(p.dirname(directory)).create(recursive: true);
    final rootPath = await root.resolveSymbolicLinks();
    final folder = await Directory(directory).create(recursive: true);
    final folderPath = await folder.resolveSymbolicLinks();
    if (!p.isWithin(rootPath, folderPath)) {
      throw const FormatException(
          'Pasta da playlist fora do destino escolhido.');
    }
    final work = await Directory(folderPath).createTemp('.dd-local-');
    final published = <File>[];
    final destinationFiles = files ?? createPlatformFiles();
    var committed = false;
    try {
      final metadata = <LocalAudioMetadata>[];
      final originals = <String>[];
      for (var i = 0; i < paths.length; i++) {
        cancellation.check();
        onProgress?.call('Copiando áudio: ${i + 1}/${paths.length}');
        final original = File(await File(paths[i]).resolveSymbolicLinks());
        if (sourceRoot != null && !p.isWithin(sourceRoot, original.path)) {
          throw const FormatException(
              'Um áudio aponta para fora da pasta selecionada.');
        }
        final before = await original.stat();
        final staged = File(p.join(work.path, '$i${extensions[i]}'));
        final sink = await staged.open(mode: FileMode.writeOnly);
        var bytes = 0;
        try {
          await for (final chunk in original.openRead()) {
            cancellation.check();
            bytes += chunk.length;
            if (bytes > before.size || bytes > maximumLocalAudioBytes) {
              throw const FormatException('O arquivo mudou durante a cópia.');
            }
            await sink.writeFrom(chunk);
          }
          await sink.flush();
        } finally {
          await sink.close();
        }
        final after = await original.stat();
        if (bytes != before.size ||
            before.size != after.size ||
            before.modified != after.modified) {
          throw const FormatException(
              'O arquivo mudou durante a cópia. Tente novamente.');
        }
        onProgress?.call('Conferindo áudio: ${i + 1}/${paths.length}');
        final found = await inspector.inspect(staged.path);
        cancellation.check();
        final fallback = p
            .basenameWithoutExtension(original.path)
            .replaceFirst(RegExp(r'^\d{1,5}\s*[-_.]\s*'), '');
        final title = _text(found.title.isEmpty ? fallback : found.title);
        metadata.add(LocalAudioMetadata(
            durationMs: found.durationMs,
            title: title.isEmpty ? 'Áudio local' : title,
            artist: _text(found.artist),
            album: _text(found.album)));
        originals.add(original.path);
      }
      final target = await storage.target(collectionId, paths.length);
      final copies = <LocalMediaCopy>[];
      for (var i = 0; i < paths.length; i++) {
        cancellation.check();
        final m = metadata[i];
        final name =
            '${(target.last + i + 1).toString().padLeft(3, '0')} - ${safeSegment(m.title)}${m.artist.isEmpty ? '' : ' - ${safeSegment(m.artist)}'}';
        final extension = extensions[i];
        var destination = File(p.join(folderPath, '$name$extension'));
        if (await destination.exists()) {
          destination = File(p.join(
              folderPath, '$name [${p.basename(work.path)}-$i]$extension'));
        }
        // Exclusive reservation: never replace an existing file, even with a race.
        await destination.create(exclusive: true);
        published.add(destination);
        await File(p.join(work.path, '$i$extension')).rename(destination.path);
        destination = File(await destinationFiles.publishImported(
            destination.path, folderPath, collectionId));
        published[published.length - 1] = destination;
        copies.add(LocalMediaCopy(destination.path, originals[i], m));
      }
      cancellation.check();
      await storage.commit(collectionId, target.last, copies,
          completeImport: folderImport);
      committed = true;
      for (final copy in copies) {
        if (!await destinationFiles.isManagedMedia(copy.path)) continue;
        final track = await repository.trackAtPath(copy.path);
        if (track != null) {
          await destinationFiles.bindImported(
              copy.path, track.id, collectionId, mediaPublicationKey(track));
        }
      }
      final imported = folderImport
          ? 'Playlist criada com ${copies.length} faixa(s).'
          : '${copies.length} áudio(s) adicionado(s) à playlist.';
      try {
        await PlaylistExporter(repository, files: destinationFiles)
            .export(collectionId, folderPath);
      } catch (_) {
        return '$imported Não foi possível atualizar a M3U8.';
      }
      return imported;
    } finally {
      if (!committed) {
        for (final file in published) {
          try {
            await destinationFiles.rollbackImported(file.path);
            if (await file.exists()) await file.delete();
          } catch (_) {
            /* Preserve the original error/cancellation. */
          }
        }
      }
      if (p.isWithin(folderPath, work.path) &&
          p.basename(work.path).startsWith('.dd-local-')) {
        try {
          if (await work.exists()) await work.delete(recursive: true);
        } on FileSystemException {/* Copies already published remain usable. */}
      }
    }
  }

  static String _text(String value) {
    final clean = value.replaceAll(RegExp(r'[\x00-\x1f\x7f]'), ' ').trim();
    return clean.length > 400 ? clean.substring(0, 400) : clean;
  }
}

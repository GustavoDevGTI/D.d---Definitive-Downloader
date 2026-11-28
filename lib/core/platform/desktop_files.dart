import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_identity.dart';
import '../storage/legacy_library_migration.dart';
import 'media_publication.dart';
import '../../features/downloads/download_cancellation.dart';
import '../../features/importing/local_audio_formats.dart';

class DesktopFiles {
  Future<bool> isDirectory(String path) async =>
      await FileSystemEntity.type(path, followLinks: false) ==
      FileSystemEntityType.directory;

  Future<void> initializeMedia() async {}
  String displayPath(String path) => path;
  bool publicDestination(String path) => false;
  Future<void> revokeDestination(String path) async {}
  Future<String> transferDirectory(
          String directory, int trackId, int collectionId, String key) async =>
      directory;
  Future<String?> reusableTransfer(
          String directory, int trackId, String key) async =>
      null;
  Future<String> publishMedia(String path, String directory, int trackId,
          int collectionId, String key,
          {DownloadCancellation? cancellation, String? fileName}) async =>
      path;
  Future<bool> isManagedMedia(String path) async => false;
  Future<void> acknowledgeMedia(String path) async {}
  Future<String> publishImported(
          String path, String directory, int collectionId) async =>
      path;
  Future<void> bindImported(
      String path, int trackId, int collectionId, String key) async {}
  Future<void> rollbackImported(String path) async {}
  Future<void> publishPlaylist(String path) async {}
  Future<List<PendingMediaPublication>> pendingMedia() async => const [];
  Future<void> stagePublicRemoval(
      String operation, int trackId, String path) async {}
  Future<void> finishPublicRemoval(
      String operation, String path, bool retained) async {}
  Future<void> cancelPublicRemovals(String operation) async {}
  Future<List<PendingPublicRemoval>> pendingPublicRemovals() async => const [];
  Future<int?> fileSize(String path) async {
    final stat = await FileStat.stat(path);
    return stat.type == FileSystemEntityType.file ? stat.size : null;
  }

  Future<String> dataDirectory() async =>
      (await getApplicationSupportDirectory()).path;
  Future<String> localLibraryDirectory() async {
    final local = Platform.environment['LOCALAPPDATA'];
    if (local == null || !p.isAbsolute(local)) {
      throw const FileSystemException(
          'A pasta local de dados do Windows não está disponível.');
    }
    return p.join(local, AppIdentity.name, 'Library');
  }

  Future<String> databasePath() async {
    final previous =
        p.join(await dataDirectory(), 'definitive_downloader.sqlite3');
    if (!Platform.isWindows) return previous;
    final destination =
        p.join(await localLibraryDirectory(), 'definitive_downloader.sqlite3');
    await migrateLegacyLibrary(
        sourcePath: previous, destinationPath: destination);
    final roaming = Platform.environment['APPDATA'];
    if (Platform.isWindows && roaming != null) {
      await migrateLegacyLibrary(
          sourcePath: p.join(roaming, 'br.com.trama', 'trama', 'trama.sqlite3'),
          destinationPath: destination);
    }
    return destination;
  }

  Future<String> defaultOutputDirectory() async {
    final directory = await getDownloadsDirectory() ??
        await getApplicationDocumentsDirectory();
    return p.join(directory.path, AppIdentity.name);
  }

  /// Default location of new playlists: a folder named after each playlist
  /// is created inside it. On Windows that is the Downloads folder itself,
  /// the parent of the former app folder.
  Future<String> defaultDownloadsRoot() async =>
      p.dirname(await defaultOutputDirectory());

  Future<bool> pathExists(String path) async =>
      await FileSystemEntity.type(path, followLinks: false) !=
      FileSystemEntityType.notFound;

  Future<String?> choosePlaylistFile() async =>
      (await openFile(acceptedTypeGroups: [
        const XTypeGroup(
            label: 'Playlist (CSV ou JSON)', extensions: ['csv', 'json'])
      ]))
          ?.path;
  Future<void> releasePlaylistFile(String path) async {}
  Future<String?> chooseAudioFolder() =>
      getDirectoryPath(confirmButtonText: 'Importar pasta');
  Future<void> cancelAudioFolder() async {}

  /// Status Saver needs WhatsApp's status folder, which exists only on Android.
  bool get supportsStatusSaver => false;
  Future<String?> chooseWhatsAppStatuses() async => null;
  Future<void> releaseWhatsAppStatuses(String path) async {}
  Future<void> releaseAudioFolder(String path) async {}
  Future<List<String>> chooseMp3Files() async =>
      (await openFiles(acceptedTypeGroups: [
        XTypeGroup(
            label: 'Arquivos de áudio',
            extensions: localAudioExtensions
                .map((extension) => extension.substring(1))
                .toList())
      ]))
          .map((file) => file.path)
          .toList();
  Future<String?> chooseMp3Destination(String suggestedName) async =>
      (await getSaveLocation(
              suggestedName: suggestedName,
              acceptedTypeGroups: const [
            XTypeGroup(label: 'MP3', extensions: ['mp3'])
          ]))
          ?.path;
  Future<String?> chooseCover() async => (await openFile(acceptedTypeGroups: [
        const XTypeGroup(
            label: 'Capa da playlist',
            extensions: ['png', 'jpg', 'jpeg', 'webp'])
      ]))
          ?.path;
  Future<String?> chooseOutput() =>
      getDirectoryPath(confirmButtonText: 'Usar esta pasta');
  Future<void> openFolder(String path) async {
    if (!await Directory(path).exists()) {
      await Directory(path).create(recursive: true);
    }
    if (!await launchUrl(Uri.directory(path),
        mode: LaunchMode.externalApplication)) {
      throw const FileSystemException('Não foi possível abrir a pasta.');
    }
  }

  Future<bool> fileExists(String path) => File(path).exists();

  Future<void> openSavedFile(String path) async {
    if (!await fileExists(path)) {
      throw const FileSystemException('Arquivo indisponível.');
    }
    if (!await launchUrl(Uri.file(path),
        mode: LaunchMode.externalApplication)) {
      throw const FileSystemException('Não foi possível abrir o arquivo.');
    }
  }

  Future<void> revealFile(String path) async {
    final directory = p.dirname(path);
    if (!await Directory(directory).exists()) {
      throw const FileSystemException('Pasta indisponível.');
    }
    if (!await launchUrl(Uri.directory(directory),
        mode: LaunchMode.externalApplication)) {
      throw const FileSystemException('Não foi possível abrir a localização.');
    }
  }

  Future<void> openUrl(Uri uri) async {
    if (uri.scheme != 'https') {
      throw const FormatException('Endereço externo inválido.');
    }
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw const FormatException('Não foi possível abrir o navegador.');
    }
  }
}

import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_identity.dart';
import '../storage/legacy_library_migration.dart';

class DesktopFiles {
  Future<String> dataDirectory() async =>
      (await getApplicationSupportDirectory()).path;
  Future<String> databasePath() async {
    final destination =
        p.join(await dataDirectory(), 'definitive_downloader.sqlite3');
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

  Future<String?> chooseCsv() async => (await openFile(acceptedTypeGroups: [
        const XTypeGroup(label: 'Lista de faixas CSV', extensions: ['csv'])
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

  Future<void> openUrl(Uri uri) async {
    if (uri.scheme != 'https') {
      throw const FormatException('Endereço externo inválido.');
    }
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw const FormatException('Não foi possível abrir o navegador.');
    }
  }
}

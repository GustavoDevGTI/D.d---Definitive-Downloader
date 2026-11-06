import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'desktop_files.dart';

/// Android document URIs are copied by the native adapter to bounded cache files.
/// The library then owns its separate, numbered copy; source documents stay intact.
class AndroidFiles extends DesktopFiles {
  static const channel = MethodChannel('br.com.definitivedownloader/files');

  @override
  Future<String> defaultOutputDirectory() async =>
      (await channel.invokeMethod<String>('defaultOutput'))!;

  Future<List<String>> _pick(String kind) async =>
      await channel.invokeListMethod<String>('pickFiles', {'kind': kind}) ?? [];

  @override
  Future<String?> chooseCsv() async => (await _pick('csv')).firstOrNull;
  @override
  Future<String?> chooseCover() async => (await _pick('cover')).firstOrNull;
  @override
  Future<List<String>> chooseMp3Files() => _pick('mp3');
  @override
  Future<String?> chooseOutput() =>
      channel.invokeMethod<String>('chooseOutput');

  @override
  Future<void> openSavedFile(String path) async {
    if (!await fileExists(path)) {
      throw const FileSystemException('Arquivo indisponível.');
    }
    await channel.invokeMethod<void>('openFile', {'path': path});
  }

  @override
  Future<void> openFolder(String path) async {
    throw const FileSystemException(
        'A navegação e exportação de pastas no Android ainda está em adaptação. '
        'Os arquivos continuam disponíveis na biblioteca do app.');
  }

  @override
  Future<void> revealFile(String path) => openFolder(p.dirname(path));
}

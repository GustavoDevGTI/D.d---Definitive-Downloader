import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'desktop_files.dart';
import 'android_documents.dart';
import 'media_publication.dart';
import '../../features/downloads/download_cancellation.dart';

/// Android document URIs are copied by the native adapter to bounded cache files.
/// The library then owns its separate, numbered copy; source documents stay intact.
class AndroidFiles extends DesktopFiles {
  static const channel = MethodChannel('br.com.definitivedownloader/files');
  final documents = AndroidDocuments();
  @override
  Future<void> initializeMedia() => documents.initialize();
  @override
  String displayPath(String path) => documents.display(path);
  @override
  bool publicDestination(String path) => documents.isPublic(path);
  @override
  Future<void> revokeDestination(String path) => documents.revoke(path);
  @override
  Future<bool> fileExists(String path) async =>
      await documents.available(path) ?? await super.fileExists(path);
  @override
  Future<int?> fileSize(String path) => documents.size(path);
  @override
  Future<String> transferDirectory(
          String directory, int trackId, int collectionId, String key) =>
      documents.transferDirectory(directory, trackId, collectionId, key);
  @override
  Future<String?> reusableTransfer(String directory, int trackId, String key) =>
      documents.reusable(directory, trackId, key);
  @override
  Future<String> publishMedia(String path, String directory, int trackId,
          int collectionId, String key,
          {DownloadCancellation? cancellation, String? fileName}) =>
      documents.publish(path, directory, trackId, collectionId, key,
          cancellation: cancellation, fileName: fileName);
  @override
  Future<bool> isManagedMedia(String path) => documents.owned(path);
  @override
  Future<void> acknowledgeMedia(String path) => documents.acknowledge(path);
  @override
  Future<String> publishImported(
          String path, String directory, int collectionId) =>
      documents.publishImported(path, directory, collectionId);
  @override
  Future<void> bindImported(
          String path, int trackId, int collectionId, String key) =>
      documents.bindImported(path, trackId, collectionId, key);
  @override
  Future<void> rollbackImported(String path) =>
      documents.rollbackImported(path);
  @override
  Future<void> publishPlaylist(String path) => documents.playlist(path);
  @override
  Future<List<PendingMediaPublication>> pendingMedia() => documents.pending();
  @override
  Future<void> stagePublicRemoval(String operation, int trackId, String path) =>
      documents.stageRemoval(operation, trackId, path);
  @override
  Future<void> finishPublicRemoval(
          String operation, String path, bool retained) =>
      documents.finishRemoval(operation, path, retained);
  @override
  Future<void> cancelPublicRemovals(String operation) =>
      documents.cancelRemovals(operation);
  @override
  Future<List<PendingPublicRemoval>> pendingPublicRemovals() =>
      documents.pendingRemovals();

  @override
  Future<String> defaultOutputDirectory() async =>
      (await channel.invokeMethod<String>('defaultOutput'))!;

  Future<List<String>> _pick(String kind) async =>
      await channel.invokeListMethod<String>('pickFiles', {'kind': kind}) ?? [];

  @override
  Future<String?> choosePlaylistFile() async =>
      (await _pick('playlist')).firstOrNull;
  @override
  Future<void> releasePlaylistFile(String path) async {
    try {
      await channel.invokeMethod<void>('releasePlaylistFile', {'path': path});
    } on MissingPluginException {
      // The Activity may have closed; its channel also cleans up on disposal.
    }
  }

  @override
  Future<String?> chooseCover() async => (await _pick('cover')).firstOrNull;
  @override
  Future<List<String>> chooseMp3Files() => _pick('mp3');
  @override
  Future<String?> chooseOutput() async {
    final result = await channel.invokeMethod<String>('chooseOutput');
    await documents.initialize();
    return result;
  }

  @override
  Future<void> openSavedFile(String path) async {
    if (!await fileExists(path)) {
      throw const FileSystemException('Arquivo indisponível.');
    }
    await channel.invokeMethod<void>('openFile', {'path': path});
  }

  @override
  Future<void> openFolder(String path) =>
      channel.invokeMethod<void>('openFolder', {'path': path});

  @override
  Future<void> revealFile(String path) => openFolder(p.dirname(path));
}

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'media_publication.dart';
import 'dart:async';
import '../../features/downloads/download_cancellation.dart';

/// Regular private paths identify cached bytes; native records identify the
/// authoritative public document. A cache never proves public availability.
class AndroidDocuments {
  static const channel = MethodChannel('br.com.definitivedownloader/documents');
  static final _labels = <String, String>{};
  Future<T> _storage<T>(Future<T> operation) async {
    try {
      return await operation;
    } on PlatformException catch (error) {
      throw MediaPublicationFailure(
          error.message ?? 'Pasta pública indisponível.');
    }
  }

  Future<void> initialize() async {
    final rows = await channel.invokeListMethod<Map>('destinations') ?? [];
    _labels
      ..clear()
      ..addEntries(
          rows.map((r) => MapEntry(r['root'] as String, r['label'] as String)));
  }

  String display(String path) {
    for (final root in _labels.keys) {
      if (path == root) return _labels[root]!;
      if (p.isWithin(root, path)) {
        return '${_labels[root]} / ${p.relative(path, from: root)}';
      }
    }
    return path;
  }

  bool isPublic(String path) =>
      _labels.keys.any((root) => path == root || p.isWithin(root, path));
  Future<void> revoke(String path) =>
      channel.invokeMethod('revoke', {'path': path});

  Future<String> transferDirectory(
          String directory, int trackId, int collectionId, String key) async =>
      (await _storage<String?>(channel.invokeMethod<String>('prepare', {
        'directory': directory,
        'trackId': trackId,
        'collectionId': collectionId,
        'key': key
      })))!;
  Future<String?> reusable(String directory, int trackId, String key) =>
      _storage(channel.invokeMethod('reusable',
          {'directory': directory, 'trackId': trackId, 'key': key}));
  Future<String> publish(
      String path, String directory, int trackId, int collectionId, String key,
      {DownloadCancellation? cancellation, String? fileName}) async {
    final timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (cancellation?.cancelled == true) {
        unawaited(channel.invokeMethod<void>('cancel', {'trackId': trackId}));
      }
    });
    var published = false;
    try {
      final result = (await channel.invokeMethod<String>('publish', {
        'path': path,
        'directory': directory,
        'trackId': trackId,
        'collectionId': collectionId,
        'key': key,
        'fileName': fileName
      }))!;
      published = true;
      return result;
    } finally {
      timer.cancel();
      if (!published) cancellation?.check();
    }
  }

  Future<bool> owned(String path) async =>
      await channel.invokeMethod<bool>('owned', {'path': path}) ?? false;
  Future<Map<String, dynamic>?> tags(String path) =>
      channel.invokeMapMethod<String, dynamic>('tags', {'path': path});
  Future<void> acknowledge(String path) =>
      channel.invokeMethod('acknowledge', {'path': path});
  Future<String> publishImported(
          String path, String directory, int collectionId) async =>
      (await channel.invokeMethod<String>('import', {
        'path': path,
        'directory': directory,
        'collectionId': collectionId
      }))!;
  Future<void> bindImported(
          String path, int trackId, int collectionId, String key) =>
      channel.invokeMethod('bindImport', {
        'path': path,
        'trackId': trackId,
        'collectionId': collectionId,
        'key': key
      });
  Future<void> rollbackImported(String path) =>
      channel.invokeMethod('rollbackImport', {'path': path});
  Future<void> playlist(String path) =>
      channel.invokeMethod('playlist', {'path': path});
  Future<bool?> available(String path) =>
      channel.invokeMethod('available', {'path': path});
  Future<int?> size(String path) =>
      channel.invokeMethod('size', {'path': path});
  Future<String> playback(String uri) async =>
      (await channel.invokeMethod<String>('playback', {'uri': uri}))!;
  Future<List<PendingMediaPublication>> pending() async =>
      (await channel.invokeListMethod<Map>('pending') ?? [])
          .map((r) => PendingMediaPublication(
              r['trackId'] as int, r['path'] as String, r['key'] as String,
              position: r['position'] as int?))
          .toList();
  Future<void> stageRemoval(String operation, int trackId, String path) =>
      channel.invokeMethod('stageRemoval',
          {'operation': operation, 'trackId': trackId, 'path': path});
  Future<void> finishRemoval(String operation, String path, bool retained) =>
      channel.invokeMethod('finishRemoval',
          {'operation': operation, 'path': path, 'retained': retained});
  Future<void> cancelRemovals(String operation) =>
      channel.invokeMethod('cancelRemovals', {'operation': operation});
  Future<List<PendingPublicRemoval>> pendingRemovals() async =>
      (await channel.invokeListMethod<Map>('pendingRemovals') ?? [])
          .map((r) => PendingPublicRemoval(r['operation'] as String,
              r['trackId'] as int, r['path'] as String))
          .toList();
}

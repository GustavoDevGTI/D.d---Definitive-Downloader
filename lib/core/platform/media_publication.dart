import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../features/library/domain/models.dart';

class MediaPublicationFailure implements Exception {
  const MediaPublicationFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// A retry may reuse validated bytes only for the same requested source/version.
String mediaPublicationKey(Track track) => sha256
    .convert(utf8.encode(jsonEncode([
      track.id,
      track.collectionId,
      track.sourceKind.name,
      track.mediaUrl,
      track.sourceId,
      track.outputTitle,
      track.outputArtist,
      track.outputAlbum,
      track.outputDurationMs,
      track.sourceAuthorization.name,
    ])))
    .toString();

class PendingMediaPublication {
  const PendingMediaPublication(this.trackId, this.path, this.key,
      {this.position});
  final int trackId;
  final int? position;
  final String path, key;
}

class PendingPublicRemoval {
  const PendingPublicRemoval(this.operation, this.trackId, this.path);
  final String operation, path;
  final int trackId;
}

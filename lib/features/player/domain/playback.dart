import 'dart:typed_data';

enum AudioRepeat { off, playlist, track }

enum PlaybackKind { local, preview, remote }

class AudioItem {
  const AudioItem(
      {required this.id,
      required this.title,
      required this.artist,
      required this.uri,
      this.reference = '',
      this.kind = PlaybackKind.local,
      this.isPreview = false,
      this.duration = Duration.zero,
      this.collectionId});
  final String id, title, artist, uri, reference;
  final PlaybackKind kind;
  final bool isPreview;
  final Duration duration;
  final int? collectionId;
}

class AudioTags {
  const AudioTags({this.title = '', this.artist = '', this.cover});
  final String title, artist;
  final Uint8List? cover;
}

class AudioEvent {
  const AudioEvent(
      {this.playing,
      this.position,
      this.duration,
      this.buffering,
      this.completed = false,
      this.failed = false});
  final bool? playing, buffering;
  final Duration? position, duration;
  final bool completed, failed;
}

abstract interface class AudioEngine {
  bool get available;
  Stream<AudioEvent> get events;
  Future<void> open(String uri);
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration value);
  Future<void> volume(double value);
  Future<void> dispose();
}

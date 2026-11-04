import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import '../../../core/network/bounded_http.dart';
import '../../../core/storage/database.dart';
import '../../library/data/library_repository.dart';
import '../../library/domain/models.dart';
import '../../workspace/domain/workspace_models.dart';
import '../domain/playback.dart';
import 'audio_tags.dart';

String publicReference(String raw) {
  final uri = Uri.tryParse(raw);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.userInfo.isNotEmpty ||
      uri.port != 443) {
    return '';
  }
  final host = uri.host.toLowerCase();
  if (['www.deezer.com', 'deezer.com'].contains(host)) {
    final id =
        RegExp(r'^/(?:[a-z]{2}/)?track/(\d+)$').firstMatch(uri.path)?.group(1);
    return id == null ? '' : 'https://www.deezer.com/track/$id';
  }
  if (['music.youtube.com', 'www.youtube.com', 'youtube.com'].contains(host)) {
    final id = uri.queryParameters['v'];
    return uri.path == '/watch' &&
            id != null &&
            RegExp(r'^[\w-]{11}$').hasMatch(id)
        ? Uri.https(host == 'youtube.com' ? 'www.youtube.com' : host, '/watch',
            {'v': id}).toString()
        : '';
  }
  if (host == 'open.spotify.com' &&
      RegExp(r'^/track/[a-zA-Z0-9]{22}$').hasMatch(uri.path)) {
    return Uri.https(host, uri.path).toString();
  }
  return uri.path.toLowerCase().endsWith('.mp3') &&
          !uri.hasQuery &&
          !uri.hasFragment
      ? uri.toString()
      : '';
}

class PlayerLibrary {
  const PlayerLibrary(this.database, {this.http = const BoundedHttp()});
  final AppDatabase database;
  final BoundedHttp http;
  String referenceFor(Track t) => t.sourceKind == SourceKind.preview
      ? '' // Legacy excerpts did not retain the catalog version's page URL.
      : publicReference(t.mediaUrl).isNotEmpty
          ? publicReference(t.mediaUrl)
          : t.sourceKind == SourceKind.none
              ? publicReference(t.sourceUrl)
              : '';
  String referenceForCandidate(Candidate c) => publicReference(c.pageUrl);
  AudioItem local(Track t) => AudioItem(
      id: 'track-${t.id}',
      title: t.displayTitle,
      artist: t.artist,
      uri: Uri.file(t.localPath).toString(),
      reference: t.redownloadState.isEmpty && t.sourceKind != SourceKind.preview
          ? publicReference(t.mediaUrl)
          : '',
      collectionId: t.collectionId,
      isPreview: t.sourceKind == SourceKind.preview,
      duration: Duration(milliseconds: t.outputDurationMs ?? 0));
  Future<List<AudioItem>> collection(int id) => database.run((db) {
        final rows = db.select(
            "SELECT * FROM tracks WHERE collection_id=? AND local_path!='' ORDER BY position LIMIT 10001",
            [id]);
        if (rows.length > 10000) {
          throw const FormatException(
              'Limite de 10.000 faixas para reprodução.');
        }
        return rows.map((r) => local(LibraryRepository.readTrack(r))).toList();
      });
  Future<bool> available(AudioItem item) async =>
      item.kind != PlaybackKind.local ||
      await File.fromUri(Uri.parse(item.uri)).exists();
  Future<AudioTags> tags(AudioItem item) async {
    if (item.kind != PlaybackKind.local) return const AudioTags();
    final path = File.fromUri(Uri.parse(item.uri)).path;
    return Isolate.run(() => readAudioTags(path));
  }

  Future<AudioItem?> localFor(Track t) async {
    if (t.localPath.isEmpty) return null;
    final item = local(t);
    return await available(item) ? item : null;
  }

  Future<AudioItem?> candidate(Track track, Candidate candidate) async {
    if (track.redownloadState.isEmpty &&
        track.sourceKind == candidate.kind &&
        publicReference(candidate.pageUrl).isNotEmpty &&
        publicReference(track.mediaUrl) == publicReference(candidate.pageUrl)) {
      final own = await localFor(track);
      if (own != null) return own;
    }
    final matches = await database.run((db) => db
        .select(
            "SELECT * FROM tracks WHERE media_url=? AND source_kind=? AND status='completed' AND local_path!='' ORDER BY id LIMIT 20",
            [candidate.pageUrl, candidate.kind.name])
        .map(LibraryRepository.readTrack)
        .toList());
    for (final match in matches) {
      final file = await localFor(match);
      if (file != null) return file;
    }
    return online(candidate);
  }

  Future<AudioItem?> track(Track t) => online(Candidate(
      title: t.outputTitle,
      artist: t.outputArtist,
      album: t.outputAlbum,
      durationMs: t.outputDurationMs ?? 0,
      pageUrl: t.mediaUrl,
      previewUrl: t.sourceKind == SourceKind.preview ? t.mediaUrl : '',
      coverUrl: '',
      kind: t.sourceKind,
      recordingType: t.recordingType));
  Future<AudioItem?> online(Candidate c) async {
    if (c.kind == SourceKind.directMp3) {
      final ref = publicReference(c.pageUrl);
      if (ref.isEmpty) return null;
      return AudioItem(
          id: ref,
          title: c.title,
          artist: c.artist,
          uri: ref,
          reference: ref,
          kind: PlaybackKind.remote);
    }
    if (c.kind != SourceKind.deezerFull && c.kind != SourceKind.preview) {
      return null;
    }
    var preview = c.previewUrl;
    final reference = publicReference(c.pageUrl);
    if (preview.isEmpty &&
        reference.startsWith('https://www.deezer.com/track/')) {
      final id = Uri.parse(reference).pathSegments.last;
      final row =
          jsonDecode(await http.text(Uri.https('api.deezer.com', '/track/$id')))
              as Map<String, dynamic>;
      if ('${row['id']}' != id) {
        throw const FormatException(
            'A prévia não corresponde à versão pedida.');
      }
      preview = row['preview'] is String ? row['preview'] as String : '';
    }
    final url = Uri.tryParse(preview);
    if (url == null ||
        url.scheme != 'https' ||
        url.userInfo.isNotEmpty ||
        url.port != 443 ||
        !(url.host == 'dzcdn.net' || url.host.endsWith('.dzcdn.net'))) {
      return null;
    }
    return AudioItem(
        id: 'preview-$reference',
        title: c.title,
        artist: c.artist,
        uri: url.toString(),
        reference: reference,
        isPreview: true,
        kind: PlaybackKind.preview);
  }

  AudioItem history(HistoryEntry file) => AudioItem(
      id: 'history-${file.id}',
      title: file.name,
      artist: '',
      uri: Uri.file(file.path).toString(),
      isPreview: file.source == 'preview',
      duration: Duration(milliseconds: file.durationMs ?? 0));
  Future<Map<String, String>> preferences() => database.run((db) => {
        for (final row in db.select(
            "SELECT key,value FROM preferences WHERE key IN ('player_volume','player_shuffle','player_repeat')"))
          row['key'] as String: row['value'] as String
      });
  Future<void> savePreference(String key, String value) => database.run((db) {
        if (!['player_volume', 'player_shuffle', 'player_repeat']
            .contains(key)) {
          throw ArgumentError('Preferência inválida.');
        }
        db.execute(
            'INSERT INTO preferences(key,value) VALUES(?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value',
            [key, value]);
      });
}

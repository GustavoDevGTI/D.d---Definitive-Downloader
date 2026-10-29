import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import '../../core/network/bounded_http.dart';
import '../library/domain/models.dart';
import 'mp3_tags.dart';
import 'music_download_service.dart';

class DownloadCancelled implements Exception {
  const DownloadCancelled();
}

class DownloadCancellation {
  bool cancelled = false;
  bool _pauseMode = false;
  bool get pauseMode => _pauseMode;
  set pauseMode(bool value) {
    if (_pauseMode == value) return;
    _pauseMode = value;
    _pacedBytes = 0;
    _paceClock.reset();
    if (value) _paceClock.start();
  }

  final Stopwatch _paceClock = Stopwatch();
  int _pacedBytes = 0;
  // Pause mode keeps the current connection alive at 10 KiB/s. The queue
  // controller prevents another transfer from starting until it is resumed.
  Future<void> throttle(int bytes) async {
    check();
    if (!pauseMode) return;
    _pacedBytes += bytes;
    final target = _pacedBytes * 1000 ~/ 10240;
    while (pauseMode && _paceClock.elapsedMilliseconds < target) {
      check();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    check();
  }

  Future<void> waitForQueue() async {
    while (pauseMode) {
      check();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    check();
  }

  void check() {
    if (cancelled) throw const DownloadCancelled();
  }
}

class DownloadService {
  const DownloadService(this.http, this.bundle, {this.music});
  final BoundedHttp http;
  final AssetBundle bundle;
  final MusicDownloadService? music;

  Future<String> save(Track track, String directory, DownloadCancellation token,
      void Function(double? fraction) progress) async {
    if (!track.canDownload) {
      throw const FormatException(
          'A fonte precisa de revisão ou ainda não tem suporte para download.');
    }
    if (track.sourceKind == SourceKind.deezerFull ||
        track.sourceKind == SourceKind.youtubeMusic) {
      if (music == null) {
        throw const FormatException('O motor musical não está disponível.');
      }
      return music!.save(track, directory, token, (_) => progress(null));
    }
    final folder = Directory(directory);
    await folder.create(recursive: true);
    final suffix = track.sourceKind == SourceKind.preview ? ' (prévia)' : '';
    final name =
        '${track.position.toString().padLeft(3, '0')} - ${safeSegment(track.outputArtist)} - ${safeSegment(track.outputTitle)}$suffix.mp3';
    var destination = File(p.join(folder.path, name));
    if (await destination.exists()) {
      destination = File(p.join(folder.path,
          '${p.basenameWithoutExtension(name)} [${track.id}].mp3'));
    }
    if (await destination.exists()) {
      throw const FileSystemException(
          'O arquivo de destino já existe. Escolha outra pasta.');
    }
    final partial = File('${destination.path}.part');
    final tagged = File('${destination.path}.tagging');
    token.check();
    if (track.mediaUrl.startsWith('asset:')) {
      if (track.sourceKind != SourceKind.localExample ||
          track.mediaUrl != 'asset:assets/demo/tone.mp3') {
        throw const FormatException('Recurso local inválido.');
      }
      final data = await bundle.load(track.mediaUrl.substring(6));
      await partial.writeAsBytes(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
      progress(1);
    } else {
      await _receive(Uri.parse(track.mediaUrl), partial, token, progress);
    }
    token.check();
    Uint8List? cover;
    final coverUrl = track.resolvedCoverUrl.isEmpty
        ? track.coverUrl
        : track.resolvedCoverUrl;
    if (coverUrl == 'asset:assets/demo/cover.png') {
      final bytes = await bundle.load('assets/demo/cover.png');
      cover =
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
    } else if (coverUrl.isNotEmpty) {
      cover = await http.bytes(Uri.parse(coverUrl));
    }
    try {
      await const Mp3TagWriter().write(
          source: partial, destination: tagged, track: track, cover: cover);
      token.check();
      await tagged.rename(destination.path);
      await partial.delete();
      return destination.path;
    } finally {
      if (await tagged.exists()) await tagged.delete();
    }
  }

  Future<void> _receive(Uri uri, File destination, DownloadCancellation token,
      void Function(double?) progress) async {
    validateHttpUrl(uri);
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    IOSink? output;
    try {
      var current = uri;
      for (var i = 0; i < 5; i++) {
        final request =
            await client.getUrl(current).timeout(const Duration(seconds: 15));
        request.followRedirects = false;
        final response =
            await request.close().timeout(const Duration(seconds: 20));
        if (response.isRedirect) {
          final location = response.headers.value(HttpHeaders.locationHeader);
          if (location == null) {
            throw const HttpException('A origem não informou o destino.');
          }
          current = current.resolve(location);
          validateHttpUrl(current);
          continue;
        }
        if (response.statusCode != 200) {
          throw HttpException(
              'A origem respondeu HTTP ${response.statusCode}.');
        }
        if (response.contentLength > 500 * 1024 * 1024) {
          throw const FormatException('O arquivo ultrapassa 500 MB.');
        }
        output = destination.openWrite();
        var received = 0;
        var lastUpdate = DateTime.now();
        await for (final chunk
            in response.timeout(const Duration(seconds: 20))) {
          token.check();
          await token.throttle(chunk.length);
          received += chunk.length;
          if (received > 500 * 1024 * 1024) {
            throw const FormatException('O arquivo ultrapassa 500 MB.');
          }
          output.add(chunk);
          if (DateTime.now().difference(lastUpdate).inMilliseconds > 200) {
            progress(response.contentLength > 0
                ? received / response.contentLength
                : null);
            lastUpdate = DateTime.now();
          }
          // Flush applies backpressure rather than accumulating a large file in memory.
          if (received % (1024 * 1024) < chunk.length) await output.flush();
        }
        await output.flush();
        if (response.contentLength > 0 && received != response.contentLength) {
          throw const HttpException('O arquivo recebido está incompleto.');
        }
        progress(1);
        return;
      }
      throw const HttpException('Muitos redirecionamentos.');
    } finally {
      await output?.close();
      client.close(force: true);
    }
  }
}

String safeSegment(String value) {
  var text = value
      .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  text = text.replaceAll(RegExp(r'[. ]+$'), '');
  if (text.isEmpty) text = 'Sem nome';
  if (RegExp(r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$', caseSensitive: false)
      .hasMatch(text)) {
    text = '_$text';
  }
  return text.length > 65 ? text.substring(0, 65).trim() : text;
}

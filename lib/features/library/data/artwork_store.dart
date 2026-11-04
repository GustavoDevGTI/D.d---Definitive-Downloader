import 'dart:collection';
import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import '../../../core/network/bounded_http.dart';
import '../../player/data/audio_tags.dart';

/// Bounded image reads/cache shared by thumbnails and inspectors. No widget IO.
class ArtworkStore {
  ArtworkStore({this.http = const BoundedHttp()});
  static final shared = ArtworkStore();
  final BoundedHttp http;
  final _cache = <String, Uint8List?>{};
  final _pending = <String, Future<Uint8List?>>{};
  int _bytes = 0;
  int _running = 0;
  final _waiting = Queue<Completer<void>>();
  Future<Uint8List?> load(String reference, {String audioPath = ''}) {
    final key = '$reference\n$audioPath';
    if (_cache.containsKey(key)) {
      final data = _cache.remove(key);
      _cache[key] = data;
      return Future.value(data);
    }
    return _pending.putIfAbsent(
        key,
        () => _load(reference, audioPath).then((data) {
              _cache[key] = data;
              _bytes += data?.length ?? 0;
              while (_cache.length > 100 || _bytes > 12 * 1024 * 1024) {
                _bytes -= _cache.remove(_cache.keys.first)?.length ?? 0;
              }
              return data;
            }).whenComplete(() {
              _pending.remove(key);
            }));
  }

  Future<Uint8List?> _load(String reference, String audioPath) async {
    if (_running >= 4) {
      final slot = Completer<void>();
      _waiting.add(slot);
      await slot.future;
    } else {
      _running++;
    }
    try {
      Uint8List? data;
      if (audioPath.isNotEmpty) {
        data = await Isolate.run(
            () async => (await readAudioTags(audioPath)).cover);
      }
      if (data != null) return await normalize(data);
      if (reference.startsWith('asset:')) {
        if (reference != 'asset:assets/demo/cover.png') return null;
        data = (await rootBundle.load(reference.substring(6)))
            .buffer
            .asUint8List();
      } else if (reference.startsWith('https://')) {
        data = await http.bytes(Uri.parse(reference),
            maximumBytes: 5 * 1024 * 1024);
      } else if (p.isAbsolute(reference)) {
        final file = File(reference);
        if (await file.length() > 5 * 1024 * 1024) return null;
        data = await file.readAsBytes();
      }
      return data == null ? null : await normalize(data);
    } catch (_) {
      return null;
    } finally {
      if (_waiting.isNotEmpty) {
        _waiting.removeFirst().complete();
      } else {
        _running--;
      }
    }
  }

  Future<String> importCover(String source, String supportDirectory) async {
    final file = File(source);
    if (await file.length() > 5 * 1024 * 1024) {
      throw const FormatException('A capa deve ter até 5 MB.');
    }
    final data = await normalize(await file.readAsBytes());
    final folder = Directory(p.join(supportDirectory, 'playlist-covers'));
    await folder.create(recursive: true);
    final target = File(p.join(folder.path, '${sha256.convert(data)}.png'));
    if (!await target.exists()) await target.writeAsBytes(data, flush: true);
    return target.path;
  }

  static Future<Uint8List> normalize(Uint8List bytes) async {
    if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
      throw const FormatException('Imagem inválida ou acima de 5 MB.');
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Image? image;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      if (descriptor.width > 8192 ||
          descriptor.height > 8192 ||
          descriptor.width * descriptor.height > 24000000) {
        throw const FormatException('Dimensões da capa acima do limite.');
      }
      final ratio = descriptor.width / descriptor.height;
      codec = await descriptor.instantiateCodec(
          targetWidth: ratio >= 1 ? 512 : (512 * ratio).round().clamp(1, 512),
          targetHeight: ratio >= 1 ? (512 / ratio).round().clamp(1, 512) : 512);
      image = (await codec.getNextFrame()).image;
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) {
        throw const FormatException('Não foi possível ler a capa.');
      }
      return png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes);
    } finally {
      image?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer.dispose();
    }
  }
}

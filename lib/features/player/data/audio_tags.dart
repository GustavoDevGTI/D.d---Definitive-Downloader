import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../domain/playback.dart';

/// Bounded ID3v2.3/v2.4 reader. Never rewrites the user's audio.
Future<AudioTags> readAudioTags(String path) async {
  RandomAccessFile? file;
  try {
    file = await File(path).open();
    final header = await file.read(10);
    if (header.length != 10 ||
        ascii.decode(header.take(3).toList(), allowInvalid: true) != 'ID3' ||
        ![3, 4].contains(header[3]) ||
        header[5] != 0) {
      return const AudioTags();
    }
    int sync(List<int> b) => b.fold(0, (v, n) => (v << 7) | (n & 127));
    final size = sync(header.sublist(6, 10));
    if (size > 4 * 1024 * 1024) return const AudioTags();
    final data = await file.read(size);
    String text(Uint8List value) {
      if (value.isEmpty) return '';
      final bytes = value.sublist(1, value.length > 2049 ? 2049 : value.length);
      if (value[0] == 0) {
        return latin1.decode(bytes).replaceAll('\u0000', '').trim();
      }
      if (value[0] == 3) {
        return utf8
            .decode(bytes, allowMalformed: true)
            .replaceAll('\u0000', '')
            .trim();
      }
      var start = 0, little = false;
      if (bytes.length >= 2 && bytes[0] == 255 && bytes[1] == 254) {
        little = true;
        start = 2;
      } else if (bytes.length >= 2 && bytes[0] == 254 && bytes[1] == 255) {
        start = 2;
      }
      final units = <int>[];
      for (var i = start; i + 1 < bytes.length; i += 2) {
        units.add(little
            ? bytes[i] | (bytes[i + 1] << 8)
            : (bytes[i] << 8) | bytes[i + 1]);
      }
      return String.fromCharCodes(units).replaceAll('\u0000', '').trim();
    }

    String title = '', artist = '';
    Uint8List? cover;
    for (var offset = 0; offset + 10 <= data.length;) {
      final id =
          ascii.decode(data.sublist(offset, offset + 4), allowInvalid: true);
      final length = header[3] == 4
          ? sync(data.sublist(offset + 4, offset + 8))
          : ByteData.sublistView(data, offset + 4, offset + 8).getUint32(0);
      if (length <= 0 || offset + 10 + length > data.length) break;
      final body =
          Uint8List.sublistView(data, offset + 10, offset + 10 + length);
      if (id == 'TIT2') title = text(body);
      if (id == 'TPE1') artist = text(body);
      if (id == 'APIC' && body.length > 5) {
        var end = body.indexOf(0, 1);
        if (end > 0 && end + 2 < body.length) {
          var start = end + 2;
          if (body[0] == 1 || body[0] == 2) {
            while (start + 1 < body.length &&
                !(body[start] == 0 && body[start + 1] == 0)) {
              start += 2;
            }
            start += 2;
          } else {
            while (start < body.length && body[start] != 0) {
              start++;
            }
            start++;
          }
          if (start < body.length) {
            final image = Uint8List.sublistView(body, start);
            if ((image.length > 3 && image[0] == 255 && image[1] == 216) ||
                (image.length > 8 &&
                    image[0] == 137 &&
                    image[1] == 80 &&
                    image[2] == 78 &&
                    image[3] == 71)) {
              cover = Uint8List.fromList(image);
            }
          }
        }
      }
      offset += 10 + length;
    }
    return AudioTags(title: title, artist: artist, cover: cover);
  } on FileSystemException {
    return const AudioTags();
  } finally {
    await file?.close();
  }
}

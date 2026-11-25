import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../domain/playback.dart';

/// Bounded FLAC Vorbis comments and embedded artwork; never decodes the audio.
Future<AudioTags> readFlacTags(RandomAccessFile file) async {
  var title = '', artist = '', album = '';
  Uint8List? cover;
  var total = 0;
  for (var block = 0; block < 128; block++) {
    final header = await file.read(4);
    if (header.length != 4) break;
    final type = header[0] & 127;
    final size = (header[1] << 16) | (header[2] << 8) | header[3];
    total += 4 + size;
    if (total > 8 * 1024 * 1024) break;
    if ((type == 4 || type == 6) && size <= 4 * 1024 * 1024) {
      final data = await file.read(size);
      if (data.length != size) break;
      final bytes = ByteData.sublistView(data);
      if (type == 4 && size >= 8) {
        var offset = 0;
        int? word() {
          if (offset + 4 > size) return null;
          final value = bytes.getUint32(offset, Endian.little);
          offset += 4;
          return value;
        }

        final vendor = word();
        if (vendor == null || vendor > size - offset) break;
        offset += vendor;
        final count = word();
        if (count == null || count > 10000) break;
        for (var i = 0; i < count; i++) {
          final length = word();
          if (length == null || length > size - offset) break;
          if (length <= 4096) {
            final entry = utf8.decode(data.sublist(offset, offset + length),
                allowMalformed: true);
            final split = entry.indexOf('=');
            if (split > 0) {
              final key = entry.substring(0, split).toUpperCase();
              final value = entry.substring(split + 1).trim();
              if (key == 'TITLE' && title.isEmpty) title = value;
              if (key == 'ARTIST' && artist.isEmpty) artist = value;
              if (key == 'ALBUM' && album.isEmpty) album = value;
            }
          }
          offset += length;
        }
      } else if (type == 6 && size >= 32 && cover == null) {
        var offset = 4; // Picture type.
        int? word() {
          if (offset + 4 > size) return null;
          final value = bytes.getUint32(offset);
          offset += 4;
          return value;
        }

        final mime = word();
        if (mime == null || mime > size - offset) break;
        offset += mime;
        final description = word();
        if (description == null || description > size - offset) break;
        offset += description + 16; // Width, height, depth, indexed colors.
        final length = word();
        if (length != null && length > 8 && length <= size - offset) {
          final image = Uint8List.sublistView(data, offset, offset + length);
          if ((image[0] == 255 && image[1] == 216) ||
              (image[0] == 137 &&
                  image[1] == 80 &&
                  image[2] == 78 &&
                  image[3] == 71)) {
            cover = Uint8List.fromList(image);
          }
        }
      }
    } else {
      await file.setPosition(await file.position() + size);
    }
    if ((header[0] & 128) != 0) break;
  }
  return AudioTags(title: title, artist: artist, album: album, cover: cover);
}

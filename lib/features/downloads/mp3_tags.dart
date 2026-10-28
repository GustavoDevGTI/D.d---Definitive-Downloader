import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../library/domain/models.dart';

class Mp3TagWriter {
  const Mp3TagWriter();
  Future<void> write(
      {required File source,
      required File destination,
      required Track track,
      Uint8List? cover}) async {
    final length = await source.length();
    if (length < 10) {
      throw const FormatException('O arquivo recebido não é um MP3 válido.');
    }
    final handle = await source.open();
    int start = 0;
    try {
      final header = await handle.read(10);
      if (ascii.decode(header.take(3).toList(), allowInvalid: true) == 'ID3') {
        start = 10 +
            ((header[6] & 127) << 21) +
            ((header[7] & 127) << 14) +
            ((header[8] & 127) << 7) +
            (header[9] & 127);
        if ((header[5] & 16) != 0) start += 10;
      }
      if (start > length - 2) {
        throw const FormatException('Cabeçalho MP3 inválido.');
      }
      await handle.setPosition(start);
      final audio = await handle.read(2);
      if (audio.length < 2 || audio[0] != 255 || (audio[1] & 224) != 224) {
        throw const FormatException('A origem não forneceu áudio MP3.');
      }
    } finally {
      await handle.close();
    }
    final frames = BytesBuilder();
    void text(String id, String value) {
      if (value.isEmpty) return;
      final utf16 = BytesBuilder()..add([1, 255, 254]);
      for (final unit in value
          .substring(0, value.length > 512 ? 512 : value.length)
          .codeUnits) {
        utf16.add([unit & 255, unit >> 8]);
      }
      frames.add(_frame(id, utf16.takeBytes()));
    }

    text(
        'TIT2',
        track.outputTitle +
            (track.sourceKind == SourceKind.preview ? ' (prévia)' : ''));
    text('TPE1', track.outputArtist);
    text('TALB', track.outputAlbum);
    text('TRCK', track.position.toString());
    if (cover != null && cover.isNotEmpty) {
      if (cover.length > 2 * 1024 * 1024) {
        throw const FormatException('Capa acima de 2 MB.');
      }
      final png = cover.length > 4 &&
          cover[0] == 137 &&
          cover[1] == 80 &&
          cover[2] == 78 &&
          cover[3] == 71;
      final jpeg = cover.length > 2 && cover[0] == 255 && cover[1] == 216;
      if (!png && !jpeg) {
        throw const FormatException('A capa precisa ser PNG ou JPEG.');
      }
      frames.add(_frame(
          'APIC',
          Uint8List.fromList([
            0,
            ...ascii.encode(png ? 'image/png' : 'image/jpeg'),
            0,
            3,
            0,
            ...cover
          ])));
    }
    final body = frames.takeBytes();
    final output = destination.openWrite();
    try {
      output.add([
        73,
        68,
        51,
        3,
        0,
        0,
        (body.length >> 21) & 127,
        (body.length >> 14) & 127,
        (body.length >> 7) & 127,
        body.length & 127
      ]);
      output.add(body);
      await output.addStream(source.openRead(start));
      await output.flush();
    } finally {
      await output.close();
    }
  }

  Uint8List _frame(String id, Uint8List data) {
    final size = ByteData(4)..setUint32(0, data.length);
    return Uint8List.fromList(
        [...ascii.encode(id), ...size.buffer.asUint8List(), 0, 0, ...data]);
  }
}

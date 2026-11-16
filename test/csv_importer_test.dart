import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:definitive_downloader/features/importing/csv_importer.dart';

void main() {
  const importer = CsvImporter();
  test('lê aspas escapadas e delimitador dentro do título', () {
    expect(importer.parseRow('"Uma, faixa","Nome ""artístico"""', ','),
        ['Uma, faixa', 'Nome "artístico"']);
  });
  test('rejeita uma linha com aspas abertas', () {
    expect(() => importer.parseRow('"incompleta,artista', ','),
        throwsFormatException);
  });
  test('importa linha a linha, preserva repetições e duração', () async {
    final dir = await Directory.systemTemp.createTemp('dd-csv-');
    try {
      final file = File('${dir.path}/lista.csv');
      await file.writeAsString(
          'titulo;artista;duracao\nFaixa;Pessoa;180\nFaixa;Pessoa;180\n');
      final rows = await importer.read(file).toList();
      expect(rows.length, 2);
      expect(rows[0].title, rows[1].title);
      expect(rows[0].durationMs, 180000);
    } finally {
      await dir.delete(recursive: true);
    }
  });
  test('rejeita CSV sem coluna de artista', () async {
    final dir = await Directory.systemTemp.createTemp('dd-csv-');
    try {
      final file = File('${dir.path}/lista.csv');
      await file.writeAsString('titulo\nFaixa');
      await expectLater(importer.read(file).toList(), throwsFormatException);
    } finally {
      await dir.delete(recursive: true);
    }
  });
  test('lê o CSV do Trackhop com duração em milissegundos', () async {
    final dir = await Directory.systemTemp.createTemp('dd-trackhop-csv-');
    try {
      final file = File('${dir.path}/Playlist.csv');
      await file.writeAsString('title,artist,album,duration_ms,isrc\n'
          '"Faixa, parte 1","A, B",Álbum,123456,BRABC2612345\n'
          'Segunda,C,,4000,\n'
          '"Faixa, parte 1","A, B",Álbum,123456,BRABC2612345\n');
      final rows =
          await importer.open(file.path, spotifyExport: true).tracks.toList();
      expect(rows.map((row) => row.title),
          ['Faixa, parte 1', 'Segunda', 'Faixa, parte 1']);
      expect(rows.first.artist, 'A, B');
      expect(rows.first.album, 'Álbum');
      expect(rows.first.durationMs, 123456);
      expect(rows.first.isrc, 'BRABC2612345');
    } finally {
      await dir.delete(recursive: true);
    }
  });
}

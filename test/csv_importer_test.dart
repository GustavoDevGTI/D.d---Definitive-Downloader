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
}

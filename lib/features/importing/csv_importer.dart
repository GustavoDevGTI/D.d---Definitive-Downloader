import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../library/domain/models.dart';

class CsvImporter {
  const CsvImporter();
  static const spotifyExportSource = 'Spotify · exportação CSV';
  ImportedCollection open(String path, {bool spotifyExport = false}) =>
      ImportedCollection(
          name: p.basenameWithoutExtension(path),
          source: spotifyExport ? spotifyExportSource : 'Arquivo CSV',
          sourceUrl: '',
          tracks: read(File(path), spotifyExport: spotifyExport));

  Stream<TrackDraft> read(File file, {bool spotifyExport = false}) async* {
    if (await file.length() > 20 * 1024 * 1024) {
      throw const FormatException('O CSV ultrapassa 20 MB.');
    }
    List<String>? headers;
    String? playlistName;
    var separator = ',';
    var lineNumber = 0;
    await for (var line in file
        .openRead()
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      lineNumber++;
      if (line.trim().isEmpty) continue;
      if (line.length > 16384) {
        throw FormatException('Linha $lineNumber muito longa.');
      }
      if (headers == null) {
        line = line.replaceFirst('\ufeff', '');
        separator = line.contains(';') ? ';' : ',';
        headers = parseRow(line, separator)
            .map((v) => v.trim().toLowerCase())
            .toList();
        if (!headers.any((h) => [
                  'titulo',
                  'título',
                  'title',
                  'track name',
                  'name'
                ].contains(h)) ||
            !headers.any((h) => [
                  'artista',
                  'artist',
                  'artist name',
                  'artist name(s)'
                ].contains(h))) {
          throw const FormatException(
              'O CSV precisa das colunas titulo e artista.');
        }
        continue;
      }
      final values = parseRow(line, separator);
      String field(List<String> names) {
        final index = headers!.indexWhere(names.contains);
        return index < 0 || index >= values.length ? '' : values[index].trim();
      }

      final title = field(['titulo', 'título', 'title', 'track name', 'name']);
      final artist =
          field(['artista', 'artist', 'artist name', 'artist name(s)']);
      if (title.isEmpty || artist.isEmpty) {
        throw FormatException(
            'Título ou artista ausente na linha $lineNumber.');
      }
      final duration = field(['duration_ms', 'track duration (ms)']);
      final seconds = field(['duracao', 'duração', 'duration']);
      if (spotifyExport) {
        final listedName = field(['playlist name']);
        if (listedName.isNotEmpty) {
          playlistName ??= listedName;
          if (playlistName != listedName) {
            throw const FormatException('Use um CSV com apenas uma playlist.');
          }
        }
      }
      final spotifyId = field(['spotify - id', 'spotify – id', 'spotify id']);
      final source = field(['spotify_url', 'track uri', 'url']);
      final spotifyTrack = RegExp(r'^[A-Za-z0-9]{22}$').hasMatch(spotifyId)
          ? 'https://open.spotify.com/track/$spotifyId'
          : '';
      yield TrackDraft(
          title: title,
          artist: artist,
          album: field(['album', 'álbum', 'album name']),
          durationMs: int.tryParse(duration) ??
              (double.tryParse(seconds) != null
                  ? (double.parse(seconds) * 1000).round()
                  : null),
          coverUrl: field(['capa', 'cover_url']),
          isrc: field(['isrc']),
          sourceUrl: source.isEmpty ? spotifyTrack : source);
    }
  }

  List<String> parseRow(String line, String separator) {
    final cells = <String>[];
    var current = StringBuffer();
    var quoted = false;
    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (quoted && i + 1 < line.length && line[i + 1] == '"') {
          current.write('"');
          i++;
        } else {
          quoted = !quoted;
        }
      } else if (char == separator && !quoted) {
        cells.add(current.toString());
        current = StringBuffer();
      } else {
        current.write(char);
      }
    }
    if (quoted) {
      throw const FormatException(
          'Aspas abertas no CSV. Use uma faixa por linha.');
    }
    cells.add(current.toString());
    return cells;
  }
}

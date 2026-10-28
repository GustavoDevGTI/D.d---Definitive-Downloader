import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:definitive_downloader/core/storage/database.dart';
import 'package:definitive_downloader/features/connections/domain/spotify_auth.dart';
import 'package:definitive_downloader/features/importing/spotify_account_importer.dart';
import 'package:definitive_downloader/features/library/data/library_repository.dart';

const fixturePlaylist =
    'https://open.spotify.com/playlist/1234567890123456789012';
Map<String, dynamic> fixtureEntry(int position) => {
      'item': {
        'id': '1234567890123456789012',
        'name': 'Repetida',
        'type': 'track',
        'artists': [
          {'name': 'Pessoa'}
        ],
        'duration_ms': 180000,
        'album': {'name': 'Álbum', 'images': []},
        'external_ids': {'isrc': 'BRTEST000001'},
      }
    };
void main() {
  test('pagina preservando 53 ocorrências, sem confundir prévia com arquivo',
      () async {
    final offsets = <int>[];
    final importer = SpotifyAccountImporter((path, {query = const {}}) async {
      if (path.endsWith('/items')) {
        final offset = int.parse(query['offset']!);
        offsets.add(offset);
        return {
          'total': 53,
          'offset': offset,
          'items': List.generate(offset == 0 ? 50 : 3, fixtureEntry)
        };
      }
      return {
        'name': 'Teste',
        'snapshot_id': 'same',
        'items': {'total': 53}
      };
    }, () => true);
    final collection = await importer.open(fixturePlaylist);
    final tracks = await collection.tracks.toList();
    expect(offsets, [0, 50]);
    expect(tracks.length, 53);
    expect(
        tracks.every(
            (track) => track.title == 'Repetida' && track.mediaUrl.isEmpty),
        isTrue);
    expect(collection.isPartial, isFalse);
  });
  test('entrada indisponível preserva posição em vez de sumir', () async {
    final importer = SpotifyAccountImporter(
        (path, {query = const {}}) async => path.endsWith('/items')
            ? {
                'total': 3,
                'offset': 0,
                'items': [
                  fixtureEntry(0),
                  {'item': null},
                  fixtureEntry(2)
                ]
              }
            : {
                'name': 'Teste',
                'items': {'total': 3}
              },
        () => true);
    final tracks = await (await importer.open(fixturePlaylist)).tracks.toList();
    expect(tracks.length, 3);
    expect(tracks[1].title, contains('(2)'));
    expect(tracks[2].title, 'Repetida');
  });
  test('origem sem conteúdo autorizado não é importada como vazia', () async {
    final importer = SpotifyAccountImporter(
        (path, {query = const {}}) async => {'name': 'Somente metadados'},
        () => true);
    await expectLater(
        importer.open(fixturePlaylist), throwsA(isA<SpotifyException>()));
  });
  test('mudança de snapshot desfaz também lotes já persistidos', () async {
    final directory =
        await Directory.systemTemp.createTemp('dd-account-import-');
    try {
      final repository =
          LibraryRepository(AppDatabase('${directory.path}/library.db'));
      await repository.database.initialize();
      var metadataReads = 0;
      final importer = SpotifyAccountImporter((path, {query = const {}}) async {
        if (!path.endsWith('/items')) {
          metadataReads++;
          return {
            'name': 'Teste',
            'snapshot_id': metadataReads == 1 ? 'first' : 'changed',
            'items': {'total': 105}
          };
        }
        final offset = int.parse(query['offset']!);
        return {
          'total': 105,
          'offset': offset,
          'items': List.generate(offset < 100 ? 50 : 5, fixtureEntry)
        };
      }, () => true);
      await expectLater(
          repository.importCollection(await importer.open(fixturePlaylist)),
          throwsA(isA<SpotifyException>()));
      expect(await repository.collections(), isEmpty);
    } finally {
      await directory.delete(recursive: true);
    }
  });
}

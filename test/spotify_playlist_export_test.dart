import 'dart:convert';
import 'dart:io';

import 'package:definitive_downloader/features/importing/spotify_playlist_export.dart';
import 'package:flutter_test/flutter_test.dart';

const exportTrack = {
  'trackName': 'Música A',
  'artistName': 'Artista A',
  'albumName': 'Álbum A',
  'trackUri': 'spotify:track:1234567890123456789012',
};

String playlistExport() => jsonEncode({
      'playlists': [
        {
          'name': 'Primeira',
          'items': [
            {'track': exportTrack}
          ],
        },
        {
          'name': 'Segunda',
          'items': [
            {'track': exportTrack},
            {
              'track': null,
              'episode': {'episodeName': 'Um podcast'}
            },
            {
              'track': null,
              'localTrack': {'trackName': 'MP3 não incluído'}
            },
            {
              'track': {
                ...exportTrack,
                'trackName': 'Faixa B',
                'trackUri': null
              }
            },
            {'track': exportTrack},
          ]
        },
      ]
    });

void main() {
  late Directory directory;
  late File file;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('dd-playlist-export-');
    file = File('${directory.path}/Playlist1.json');
  });
  tearDown(() => directory.delete(recursive: true));

  test('lê playlists na ordem e mantém repetições e referências exatas',
      () async {
    await file.writeAsString(playlistExport());
    final playlists = await SpotifyPlaylistExport.read(file.path);
    expect(playlists.map((playlist) => playlist.name), ['Primeira', 'Segunda']);
    expect(playlists.last.skipped, 2);
    final tracks = await playlists.last.open().tracks.toList();
    expect(tracks.map((track) => track.title),
        ['Música A', 'Faixa B', 'Música A']);
    expect(tracks.first.artist, 'Artista A');
    expect(tracks.first.album, 'Álbum A');
    expect(tracks.first.durationMs, isNull);
    expect(tracks.first.sourceUrl,
        'https://open.spotify.com/track/1234567890123456789012');
    expect(tracks[1].sourceUrl, isEmpty);
  });

  test('rejeita outros dados da conta sem expor o conteúdo no erro', () async {
    await file.writeAsString('{"email":"privado@example.test"}');
    await expectLater(
        SpotifyPlaylistExport.read(file.path),
        throwsA(isA<FormatException>().having((e) => e.message, 'mensagem',
            allOf(contains('Playlist1.json'), isNot(contains('@'))))));
  });
}

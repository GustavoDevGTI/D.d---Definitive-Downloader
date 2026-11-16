import 'dart:convert';
import 'dart:io';

import 'package:definitive_downloader/features/importing/trackhop_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const playlist = '1234567890123456789012';
  const track = '0123456789012345678901';
  const other = '0123456789012345678902';
  const key = 'test-trackhop-credential';
  const playlistUrl = 'https://open.spotify.com/playlist/$playlist';

  test('lê pelo Trackhop a lista completa em ordem, inclusive repetições',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final calls = <String>[];
    final headers = <String?>[];
    var expected = 151;
    server.listen((request) async {
      calls.add(request.uri.path);
      headers.add(request.headers.value(HttpHeaders.authorizationHeader));
      final response = request.response;
      response.headers.contentType = ContentType.json;
      if (request.uri.path == '/api/v1/services') {
        response.write(jsonEncode([
          {'id': 'spotify', 'serviceId': 'spotify', 'connected': true},
          {
            'id': 'spotify_bridge@2',
            'serviceId': 'spotify_bridge',
            'connected': true
          }
        ]));
      } else if (request.uri.path.endsWith('/playlists')) {
        response.write(jsonEncode([
          {'id': playlist, 'name': 'Lista grande', 'tracks': expected}
        ]));
      } else {
        response.write(jsonEncode([
          for (var i = 0; i < 151; i++)
            {
              'id': i == 150 ? track : other,
              'title': i == 150 ? 'Final' : 'Repetida',
              'artists': ['A', 'B'],
              'durationMs': 123456
            }
        ]));
      }
      await response.close();
    });
    try {
      final client =
          TrackhopClient(Uri.parse('http://127.0.0.1:${server.port}'), key);
      final result = await client.playlist(playlistUrl);
      final tracks = await result.tracks.toList();
      expect(result.name, 'Lista grande');
      expect(result.sourceUrl, playlistUrl);
      expect(tracks, hasLength(151));
      expect(tracks.first.artist, 'A, B');
      expect(tracks[149].sourceUrl, 'https://open.spotify.com/track/$other');
      expect(tracks.last.sourceUrl, 'https://open.spotify.com/track/$track');
      expect(tracks.last.durationMs, 123456);
      expect(calls, [
        '/api/v1/services',
        '/api/v1/services/spotify_bridge@2/playlists',
        '/api/v1/services/spotify_bridge@2/playlists/$playlist/tracks'
      ]);
      expect(headers, everyElement('Bearer $key'));
      expected = 152;
      await expectLater(client.playlist(playlistUrl), throwsFormatException);
    } finally {
      await server.close(force: true);
    }
  });

  test('recusa HTTP remoto, credenciais no endereço e caminho inesperado', () {
    for (final address in [
      'http://192.168.1.3:8642',
      'https://user@example.test',
      'https://example.test/app'
    ]) {
      expect(
          () => TrackhopClient.validateAddress(address), throwsFormatException);
    }
    expect(
        TrackhopClient.validateAddress('https://trackhop.example.test/').host,
        'trackhop.example.test');
  });
}

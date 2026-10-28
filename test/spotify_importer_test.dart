import 'package:flutter_test/flutter_test.dart';
import 'package:definitive_downloader/core/network/bounded_http.dart';
import 'package:definitive_downloader/features/importing/spotify_importer.dart';

void main() {
  const importer = SpotifyImporter(BoundedHttp());
  const id = '37i9dQZF1DXcBWIGoYBM5M';
  test('normaliza playlist normal, internacional e URI', () {
    for (final value in [
      'https://open.spotify.com/playlist/$id?si=demo',
      'https://open.spotify.com/intl-pt/playlist/$id',
      'spotify:playlist:$id'
    ]) {
      expect(importer.playlistId(value), id);
    }
  });
  test('rejeita domínio impostor e links de faixa', () {
    expect(
        () => importer
            .playlistId('https://open.spotify.com.evil.test/playlist/$id'),
        throwsFormatException);
    expect(() => importer.playlistId('https://open.spotify.com/track/$id'),
        throwsFormatException);
  });
}

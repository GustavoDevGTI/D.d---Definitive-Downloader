import 'dart:io';

import 'package:definitive_downloader/core/network/bounded_http.dart';
import 'package:definitive_downloader/features/importing/spotify_importer.dart';
import 'package:definitive_downloader/features/matching/deezer_catalog.dart';

/// Manual network probe; no credentials, no audio downloads and no persistence.
Future<void> main() async {
  const http = BoundedHttp();
  try {
    final collection = await const SpotifyImporter(http).open(
      'https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M',
    );
    final count = await collection.tracks.length;
    stdout.writeln(
        'Spotify public import: $count tracks; partial=${collection.isPartial}');
  } catch (error) {
    stdout.writeln('Spotify public import unavailable: $error');
  }
  try {
    final candidates =
        await const DeezerCatalog(http).search('Kevin MacLeod Carefree');
    stdout.writeln(
        'Deezer public catalog: ${candidates.length} candidates; previews=${candidates.where((c) => c.previewUrl.isNotEmpty).length}; full_audio_not_requested');
  } catch (error) {
    stdout.writeln('Deezer public catalog unavailable: $error');
  }
}

import 'dart:io';

import 'package:definitive_downloader/core/network/bounded_http.dart';
import 'package:definitive_downloader/core/platform/desktop_files.dart';
import 'package:definitive_downloader/core/storage/database.dart';
import 'package:definitive_downloader/features/connections/application/music_account_access.dart';
import 'package:definitive_downloader/features/connections/domain/music_account.dart';
import 'package:definitive_downloader/features/downloads/download_service.dart';
import 'package:definitive_downloader/features/importing/csv_importer.dart';
import 'package:definitive_downloader/features/importing/managed_spotify_playlists.dart';
import 'package:definitive_downloader/features/importing/spotify_importer.dart';
import 'package:definitive_downloader/features/library/application/library_controller.dart';
import 'package:definitive_downloader/features/library/data/library_repository.dart';
import 'package:definitive_downloader/features/library/domain/models.dart';
import 'package:definitive_downloader/features/matching/deezer_catalog.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const id = '1234567890123456789012';
const link = 'https://open.spotify.com/playlist/$id';

class _ManagedPlaylist extends ManagedSpotifyPlaylists {
  _ManagedPlaylist() : super('https://playlists.example.test');

  var isPublic = true;
  var reads = 0;

  @override
  Future<ImportedCollection> open(String input,
      {bool Function()? cancelled, void Function(int, int)? onProgress}) async {
    expect(SpotifyImporter.idFromLink(input), id);
    reads++;
    if (!isPublic) throw const PublicSpotifyPlaylistRequired();
    return ImportedCollection(
        name: 'Pública',
        source: ManagedSpotifyPlaylists.source,
        sourceUrl: link,
        skippedCount: 1,
        tracks: Stream.fromIterable([
          for (final title in ['Uma', 'Duas', 'Uma'])
            TrackDraft(title: title, artist: 'Artista')
        ]));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Importar por link abre Conferência sem solicitar contas', () async {
    final directory = await Directory.systemTemp.createTemp('dd-gateway-');
    addTearDown(() => directory.delete(recursive: true));
    final repository =
        LibraryRepository(AppDatabase('${directory.path}/library.db'));
    await repository.database.initialize();
    final managed = _ManagedPlaylist();
    final accounts = MusicAccountAccess(
        spotifyConnected: () => false, deezerConnected: () => false);
    final loginRequests = <MusicAccount>[];
    accounts.requestLogin = (account, {required allowLater}) async {
      loginRequests.add(account);
      return MusicAccountDecision.cancelled;
    };
    final library = LibraryController(
        repository: repository,
        files: DesktopFiles(),
        spotify: const SpotifyImporter(BoundedHttp()),
        managedSpotify: managed,
        accounts: accounts,
        csv: const CsvImporter(),
        catalog: const DeezerCatalog(BoundedHttp()),
        downloader: DownloadService(const BoundedHttp(), rootBundle));
    addTearDown(library.dispose);

    await library.importPlaylist('$link?si=sharing-code');
    final collection = library.current!;
    final tracks = (await repository.page(collection.id)).items;
    expect(collection.source, ManagedSpotifyPlaylists.source);
    expect(tracks.map((track) => track.title), ['Uma', 'Duas', 'Uma']);
    expect(collection.completedCount, 0);
    expect(library.focused?.id, tracks.first.id);
    expect(library.inspectorRequest, 1);
    expect(library.message, contains('ficaram de fora'));
    expect(loginRequests, isEmpty);

    managed.isPublic = false;
    await library.importPlaylist(link);
    expect(await repository.collections(), hasLength(1));
    expect(library.inspectorRequest, 1);
    expect(library.message, contains('playlist pública'));
    expect(managed.reads, 2);
    expect(loginRequests, isEmpty);

    var visibilityPrompts = 0;
    final originalInput = '$link?si=sharing-code';
    await library.importPlaylist(originalInput,
        onPublicSpotifyRequired: () => visibilityPrompts++);
    expect(visibilityPrompts, 1);
    expect(library.message, isEmpty);
    expect(await repository.collections(), hasLength(1));

    managed.isPublic = true;
    await library.importPlaylist(originalInput,
        onPublicSpotifyRequired: () => visibilityPrompts++);
    expect(visibilityPrompts, 1);
    expect(await repository.collections(), hasLength(2));
    expect(library.inspectorRequest, 2);
    expect(loginRequests, isEmpty);
  });
}

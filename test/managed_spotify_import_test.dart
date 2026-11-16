import 'dart:io';

import 'package:definitive_downloader/core/network/bounded_http.dart';
import 'package:definitive_downloader/core/platform/desktop_files.dart';
import 'package:definitive_downloader/core/storage/database.dart';
import 'package:definitive_downloader/features/connections/application/music_account_access.dart';
import 'package:definitive_downloader/features/connections/domain/music_account.dart';
import 'package:definitive_downloader/features/downloads/download_service.dart';
import 'package:definitive_downloader/features/importing/csv_importer.dart';
import 'package:definitive_downloader/features/importing/deezer_playlist_catalog.dart';
import 'package:definitive_downloader/features/importing/managed_spotify_playlists.dart';
import 'package:definitive_downloader/features/importing/public_playlist_link.dart';
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

class _DeezerPlaylist extends DeezerPlaylistCatalog {
  var reads = 0;

  @override
  Future<ImportedCollection> open(PublicPlaylistLink link,
      {bool downloadAvailable = false,
      bool Function()? cancelled,
      void Function(int, int)? onProgress}) async {
    reads++;
    expect(downloadAvailable, isFalse);
    return ImportedCollection(
        name: 'Playlist Deezer',
        source: 'Deezer · público',
        sourceUrl: link.url,
        tracks: Stream.value(TrackDraft(title: 'Faixa', artist: 'Artista')));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Spotify lê a playlist antes de oferecer Deezer em cada importação',
      () async {
    final directory = await Directory.systemTemp.createTemp('dd-gateway-');
    addTearDown(() => directory.delete(recursive: true));
    final repository =
        LibraryRepository(AppDatabase('${directory.path}/library.db'));
    await repository.database.initialize();
    final managed = _ManagedPlaylist();
    var deezerConnected = false;
    final accounts = MusicAccountAccess(
        spotifyConnected: () => false, deezerConnected: () => deezerConnected);
    final offersAfterRead = <int>[];
    accounts.requestLogin = (account, {required allowLater}) async {
      expect(account, MusicAccount.deezer);
      expect(allowLater, isTrue);
      offersAfterRead.add(managed.reads);
      return MusicAccountDecision.later;
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
    expect(offersAfterRead, [1]);

    managed.isPublic = false;
    await library.importPlaylist(link);
    expect(await repository.collections(), hasLength(1));
    expect(library.inspectorRequest, 1);
    expect(library.message, contains('playlist pública'));
    expect(managed.reads, 2);
    expect(offersAfterRead, [1]);

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
    expect(offersAfterRead, [1, 4]);

    deezerConnected = true;
    await library.importPlaylist(link);
    expect(await repository.collections(), hasLength(3));
    expect(offersAfterRead, [1, 4]);
  });

  test('Deezer oferece adiar a cada link e cancela sem criar coleção',
      () async {
    final directory = await Directory.systemTemp.createTemp('dd-deezer-link-');
    addTearDown(() => directory.delete(recursive: true));
    final repository =
        LibraryRepository(AppDatabase('${directory.path}/library.db'));
    final deezer = _DeezerPlaylist();
    final access = MusicAccountAccess(
        spotifyConnected: () => false, deezerConnected: () => false);
    final readsBeforeOffer = <int>[];
    access.requestLogin = (account, {required allowLater}) async {
      expect(account, MusicAccount.deezer);
      expect(allowLater, isTrue);
      readsBeforeOffer.add(deezer.reads);
      return readsBeforeOffer.length == 3
          ? MusicAccountDecision.cancelled
          : MusicAccountDecision.later;
    };
    final library = LibraryController(
        repository: repository,
        files: DesktopFiles(),
        spotify: const SpotifyImporter(BoundedHttp()),
        deezerPlaylists: deezer,
        accounts: access,
        csv: const CsvImporter(),
        catalog: const DeezerCatalog(BoundedHttp()),
        downloader: DownloadService(const BoundedHttp(), rootBundle));
    addTearDown(library.dispose);
    await repository.database.initialize();

    const deezerLink = 'https://www.deezer.com/br/playlist/123';
    await library.importPlaylist(deezerLink);
    await library.importPlaylist(deezerLink);
    await library.importPlaylist(deezerLink);

    expect(readsBeforeOffer, [0, 1, 2]);
    expect(deezer.reads, 2);
    expect(await repository.collections(), hasLength(2));
    expect(library.message, 'Importação cancelada.');
  });
}

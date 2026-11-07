import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/platform/desktop_files.dart';
import '../../downloads/download_service.dart';
import '../../importing/csv_importer.dart';
import '../../importing/music_link_catalog.dart';
import '../../importing/music_link_service.dart';
import '../../importing/music_link_repository.dart';
import '../../importing/demo_collection.dart';
import '../../importing/spotify_importer.dart';
import '../../importing/soundcloud_catalog.dart';
import '../../importing/playlist_catalog.dart';
import '../../importing/collection_link_composer.dart';
import '../../importing/deezer_playlist_catalog.dart';
import '../../importing/youtube_playlist_catalog.dart';
import '../../importing/spotify_account_importer.dart';
import '../../matching/deezer_catalog.dart';
import '../../matching/music_resolver.dart';
import '../data/library_repository.dart';
import '../data/playlist_editor.dart';
import '../data/redownload_repository.dart';
import 'download_selection_check.dart';
import 'download_queue_run.dart';
import 'library_music_sources.dart';
import 'media_publication_recovery.dart';
import 'continuous_track_listing.dart';
import '../data/continuous_track_repository.dart';
import '../../../core/application/operation_message.dart';
import '../../importing/music_link.dart';
import '../domain/models.dart';
import '../domain/track_listing.dart';
import '../domain/matching.dart';
import '../../organization/data/collection_organization_repository.dart';
import '../../organization/domain/collection_organization.dart';
import '../../importing/local_media_importer.dart';
import '../../importing/local_mp3_inspector.dart';
import '../../importing/collection_duplicates.dart';
import '../../importing/collection_link_addition.dart';
import '../../importing/replacement_media_files.dart';
import '../../connections/application/music_account_access.dart';
import '../../connections/domain/music_account.dart';

class LibraryController extends ChangeNotifier {
  LibraryController(
      {required this.repository,
      required this.files,
      required this.spotify,
      required this.csv,
      required this.catalog,
      required this.downloader,
      this.accountSpotify,
      this.accounts,
      SoundCloudCatalog? soundcloud,
      this.deezerPlaylists = const DeezerPlaylistCatalog(),
      this.youtubePlaylists = const YouTubePlaylistCatalog(),
      this.linkCatalog,
      this.localInspector = const MediaKitLocalAudioInspector(),
      this.music})
      : soundcloud = soundcloud ?? SoundCloudCatalog();
  final SoundCloudCatalog soundcloud;
  final MusicAccountAccess? accounts;

  Future<bool> _authorize(String input) async {
    try {
      final allowed = await accounts?.ensure(input) ?? true;
      if (!allowed) {
        message = 'Conexão cancelada. A playlist não foi alterada.';
        notifyListeners();
      }
      return allowed && !_disposed;
    } catch (error) {
      message = operationMessage(error);
      notifyListeners();
      return false;
    }
  }

  final DeezerPlaylistCatalog deezerPlaylists;
  Future<bool> _authorizePrimary() async {
    if (accounts == null) return true;
    try {
      return await accounts!.connect(MusicAccount.deezer) && !_disposed;
    } catch (error) {
      message = operationMessage(error);
      notifyListeners();
      return false;
    }
  }

  final YouTubePlaylistCatalog youtubePlaylists;
  DownloadCancellation? _importCancellation;
  final MusicResolver? music;
  final MusicLinkCatalog? linkCatalog;
  final LocalAudioInspector localInspector;
  bool addingLinks = false;
  String linkProgress = '';
  String? _activeRun;
  bool _startingRun = false;
  bool _checkingDownloads = false;
  int inspectorRequest = 0, inspectorRevision = 0;
  Completer<void>? _additionDone;
  DownloadCancellation? _additionCancellation;
  bool _holdQueueForReview = false;
  void cancelAdditions() => _additionCancellation?.cancelled = true;
  final _transferUpdates = ChangeNotifier();
  Listenable get transferUpdates => _transferUpdates;
  int dataRevision = 0;
  bool _disposed = false;

  Future<List<Collection>> collectionChoices(int offset) =>
      repository.collections(offset: offset);
  Future<Collection?> collectionChoice(int id) => repository.collectionById(id);

  Future<bool> addLinks(int collectionId, String input,
      {ChooseDuplicate? chooseDuplicate,
      Future<void> Function(List<Track>)? beforeRemoval}) async {
    if (!await _authorize(input)) return false;
    return _addition((token) async {
      final owner = await repository.collectionById(collectionId);
      if (owner == null) {
        throw const FormatException('Playlist não encontrada.');
      }
      final entries = await _composer.resolve(input,
          capacity: 10000,
          prepare: false,
          cancellation: token,
          onProgress: _additionProgress);
      token.check();
      return CollectionLinkAddition(repository).add(owner, entries,
          choose: chooseDuplicate,
          prepare: (entry) =>
              _composer.links.prepare(entry, cancellation: token),
          cancellation: token,
          holdQueue: () => _holdQueueForReview = true,
          run: () => _cancellation?.cancelled == true ? null : _activeRun,
          progress: _additionProgress,
          beforeRemoval: beforeRemoval);
    });
  }

  Future<bool> addLocalFiles(int collectionId, List<String> paths) =>
      _addition((token) => LocalMediaImporter(repository,
              inspector: localInspector, files: files)
          .add(collectionId, paths, outputDirectory,
              cancellation: token, onProgress: _additionProgress));
  Future<void> chooseLocalFiles() async {
    final id = current?.id;
    if (id == null || reorderingBusy) return;
    try {
      final paths = await files.chooseMp3Files();
      if (paths.isNotEmpty && !_disposed) await addLocalFiles(id, paths);
    } catch (error) {
      message = operationMessage(error);
      notifyListeners();
    }
  }

  void _additionProgress(String value) {
    linkProgress = value;
    notifyListeners();
  }

  Future<bool> _addition(
      Future<String> Function(DownloadCancellation) action) async {
    if (addingLinks ||
        importing ||
        preparing ||
        editing ||
        _startingRun ||
        _checkingDownloads) {
      return false;
    }
    addingLinks = true;
    final token = _additionCancellation = DownloadCancellation();
    _additionDone = Completer<void>();
    notifyListeners();
    try {
      message = await action(token);
      await refresh();
      return true;
    } on DownloadCancelled {
      message = 'Adição cancelada. Nenhuma faixa foi acrescentada.';
      return false;
    } catch (error) {
      message = operationMessage(error);
      return false;
    } finally {
      addingLinks = false;
      _holdQueueForReview = false;
      _additionCancellation = null;
      linkProgress = '';
      _additionDone?.complete();
      _additionDone = null;
      notifyListeners();
    }
  }

  bool editing = false;
  Future<void> _selectionWrites = Future<void>.value();
  Future<void> selectSweep(List<int> ids) {
    final owner = current?.id;
    if (owner == null || busy || ids.isEmpty) return Future<void>.value();
    final request = _selectionWrites.then((_) async {
      await repository.selectSweep(owner, ids);
      await refresh();
    });
    _selectionWrites = request.catchError((Object error) {
      message = operationMessage(error);
      notifyListeners();
    });
    return _selectionWrites;
  }

  Future<bool> clickTrack(Track track, {required bool extend}) async {
    if (busy || current?.id != track.collectionId) return false;
    await repository.selectFromClick(track.collectionId, track.id,
        extend: extend);
    await refresh();
    return true;
  }

  Future<String?> moveTracks(int trackId,
      {required int collectionId,
      required int targetId,
      required bool after,
      required bool selectedGroup}) async {
    if (reorderingBusy || current?.id != collectionId) {
      return 'A lista mudou ou está sendo atualizada. Tente arrastar novamente.';
    }
    editing = true;
    notifyListeners();
    try {
      await PlaylistEditor(repository.database).move(collectionId, trackId,
          targetId: targetId, after: after, selectedGroup: selectedGroup);
      trackSort = TrackSort.position;
      trackDescending = false;
      await refresh();
      return null;
    } catch (error) {
      return operationMessage(error);
    } finally {
      editing = false;
      notifyListeners();
    }
  }

  Future<bool> editTrack(Track track,
      {required String name,
      required int position,
      String? sourceInput,
      MusicLinkKind? platform}) async {
    if (busy) return false;
    editing = true;
    notifyListeners();
    try {
      ResolvedMusicLink? replacement;
      if (sourceInput != null && platform != null) {
        final link = MusicLink.fromIdentifier(platform, sourceInput);
        replacement = (await MusicLinkService(
                    linkCatalog ??
                        MusicLinkCatalog(
                            spotify: accountSpotify, soundcloud: soundcloud),
                    music)
                .resolve(link.url))
            .single;
      }
      final requestedName = replacement != null &&
              name.trim() == track.displayTitle &&
              track.customTitle.isEmpty
          ? replacement.draft.title
          : name;
      await PlaylistEditor(repository.database).edit(track.id,
          name: requestedName, position: position, replacement: replacement);
      message = 'Faixa atualizada.';
      await refresh();
      return true;
    } catch (error) {
      message = operationMessage(error);
      return false;
    } finally {
      editing = false;
      notifyListeners();
    }
  }

  final LibraryRepository repository;
  final DesktopFiles files;
  final SpotifyImporter spotify;
  final SpotifyAccountImporter? accountSpotify;
  final CsvImporter csv;
  final DeezerCatalog catalog;
  final DownloadService downloader;
  List<Collection> collections = [];
  Collection? current;
  late final _trackListing =
      ContinuousTrackListing(ContinuousTrackRepository(repository.database));
  TrackPage page = const TrackPage([], 0, 0);
  Track? focused;
  List<Candidate> candidates = [];
  Candidate? selectedCandidate;
  TrackSort trackSort = TrackSort.position;
  bool trackDescending = false;
  String outputDirectory = '';
  String message = '';
  String view = 'collections';
  String collectionQuery = '';
  int collectionOffset = 0;
  int? activeTrackId;
  bool importing = false;
  bool searching = false;
  bool downloading = false;
  bool preparing = false;
  double? progress;
  TransferProgress? transfer;
  String activeTitle = '';
  DownloadCancellation? _cancellation;
  bool get pauseMode => downloading && _cancellation?.pauseMode == true;

  void togglePause() {
    final token = _cancellation;
    if (!downloading || token == null || token.cancelled) return;
    token.pauseMode = !token.pauseMode;
    message = token.pauseMode
        ? 'Fila pausada. A transferência atual continua a até 10 KiB/s; nenhuma outra será iniciada.'
        : 'Fila retomada.';
    notifyListeners();
  }

  int _searchGeneration = 0;
  int _refreshGeneration = 0;
  bool get busy =>
      importing ||
      downloading ||
      preparing ||
      addingLinks ||
      editing ||
      _startingRun ||
      _checkingDownloads;
  bool get reorderingBusy =>
      importing ||
      preparing ||
      addingLinks ||
      editing ||
      _startingRun ||
      _checkingDownloads;
  bool get isExample => current?.source == 'Exemplo local';
  bool get allFilteredSelected =>
      page.total > 0 && page.filteredSelectedCount == page.total;

  void clearMessage() {
    if (message.isEmpty || busy) return;
    message = '';
    notifyListeners();
  }

  void acknowledgeMessage(String value) {
    if (message != value) return;
    message = '';
    notifyListeners();
  }

  Future<void> initialize({bool example = false}) async {
    await repository.database.initialize();
    await files.initializeMedia();
    final recovery =
        await ReplacementMediaFiles(repository, files: files).recover();
    if (recovery != null) message = recovery;
    final publications =
        await MediaPublicationRecovery(repository, files).recover();
    if (publications != null) message = publications;
    outputDirectory = await repository.preference('output_directory') ??
        await files.defaultOutputDirectory();
    collections = await repository.collections(offset: collectionOffset);
    if (collections.isNotEmpty) {
      current = collections.first;
      await refresh();
    } else if (example) {
      await loadExample();
    }
    notifyListeners();
  }

  Future<void> refresh() async {
    final generation = ++_refreshGeneration;
    final id = current?.id,
        query = collectionQuery,
        filter = view == 'collections' ? '' : view,
        sort = trackSort,
        descending = trackDescending;
    final nextCollections =
        await repository.collections(offset: collectionOffset);
    final owner = id == null ? null : await repository.collectionById(id);
    if (generation != _refreshGeneration || current?.id != id) return;
    final nextPage = owner == null
        ? const TrackPage([], 0, 0)
        : await _trackListing.load(owner.id,
            filter: filter, query: query, sort: sort, descending: descending);
    if (generation != _refreshGeneration ||
        current?.id != id ||
        nextPage == null) {
      return;
    }
    if (owner == null) _trackListing.clear();
    collections = nextCollections;
    current = owner;
    page = nextPage;
    focused = page.items.where((t) => t.id == focused?.id).firstOrNull;
    dataRevision++;
    notifyListeners();
  }

  Future<void> openCollection(Collection collection) async {
    _searchGeneration++;
    current = collection;
    focused = null;
    candidates = [];
    selectedCandidate = null;
    collectionQuery = '';
    view = 'collections';
    trackSort = TrackSort.position;
    trackDescending = false;
    message = '';
    await refresh();
    if (!busy &&
        music?.available == true &&
        !isExample &&
        await repository.needsSourcePreparation(collection.id,
            deezerConnected: music!.connection.connected) &&
        current?.id == collection.id) {
      unawaited(prepareMusic(onlyPending: true));
    }
  }

  void selectCandidate(Candidate? candidate) {
    selectedCandidate = candidate;
    notifyListeners();
  }

  Future<void> sortTracks(TrackSort sort) async {
    trackDescending = sort == trackSort ? !trackDescending : false;
    trackSort = sort;
    await refresh();
  }

  Future<void> setView(String value) async {
    _searchGeneration++;
    view = value;
    focused = null;
    candidates = [];
    selectedCandidate = null;
    await refresh();
  }

  void focus(Track track) {
    inspectorRevision++;
    focused = track;
    candidates = [];
    selectedCandidate = null;
    _searchGeneration++;
    notifyListeners();
    if (music != null && !isExample) unawaited(_loadMusicCandidates(track));
  }

  Future<void> searchCollection(String value) async {
    collectionQuery = value;
    _searchGeneration++;
    focused = null;
    candidates = [];
    selectedCandidate = null;
    await refresh();
  }

  Future<void> turnCollections(int direction) async {
    collectionOffset = (collectionOffset + 30 * direction).clamp(0, 1 << 30);
    collections = await repository.collections(offset: collectionOffset);
    if (collections.isEmpty && collectionOffset > 0) {
      collectionOffset = (collectionOffset - 30).clamp(0, 1 << 30);
      collections = await repository.collections(offset: collectionOffset);
    }
    notifyListeners();
  }

  Future<void> selectCollection(bool value) async {
    if (current == null || busy) return;
    await repository.selectCollection(current!.id, value,
        query: collectionQuery, filter: view == 'collections' ? '' : view);
    await refresh();
  }

  LibraryMusicSources get _sources => LibraryMusicSources(
      repository,
      linkCatalog ??
          MusicLinkCatalog(spotify: accountSpotify, soundcloud: soundcloud),
      music);
  Future<void> setManualSource(String value, ManualSourceMode mode) async {
    final track = focused;
    if (track == null || busy) return;
    if (!await _authorize(value) || focused?.id != track.id || busy) return;
    _searchGeneration++;
    try {
      message = await _sources.setManual(track, value, mode);
      await refresh();
    } catch (error) {
      message = operationMessage(error);
      notifyListeners();
    }
  }

  Future<void> removeManualSource() async {
    if (focused == null || busy) return;
    _searchGeneration++;
    await repository.removeManualSource(focused!.id);
    message = 'Vínculo manual removido. A busca automática está disponível.';
    await refresh();
  }

  Future<void> reviewSource() async {
    if (focused == null || busy) return;
    await repository.markForReview(focused!.id);
    await refresh();
  }

  Future<void> confirmSource() async {
    if (focused == null || busy) return;
    try {
      if (focused!.redownloadReview) {
        await RedownloadRepository(repository.database).approvePrevious(
            focused!.id,
            url: focused!.mediaUrl,
            kind: focused!.sourceKind);
      } else {
        await repository.confirmSource(focused!.id);
      }
      await refresh();
    } catch (error) {
      message = operationMessage(error);
      notifyListeners();
    }
  }

  Future<void> _loadMusicCandidates(Track track) async {
    final generation = _searchGeneration;
    final found = await repository.musicCandidates(track.id);
    if (generation == _searchGeneration && focused?.id == track.id) {
      candidates = found;
      notifyListeners();
    }
  }

  Future<void>? _preparation;
  Future<void> get preparationDone => _preparation ?? Future<void>.value();

  Future<void> prepareMusic({bool onlyPending = false}) {
    if (busy || current == null || music?.available != true || isExample) {
      return preparationDone;
    }
    return _preparation = _prepareMusic(onlyPending: onlyPending);
  }

  Future<void> _prepareMusic({required bool onlyPending}) async {
    final collection = current;
    if (collection == null || busy || music?.available != true || isExample) {
      return;
    }
    if (!await _authorize(collection.sourceUrl) ||
        current?.id != collection.id ||
        busy) {
      return;
    }
    if (accounts != null &&
        !accounts!.connected(MusicAccount.deezer) &&
        await repository.needsSourcePreparation(collection.id) &&
        !await _authorizePrimary()) {
      return;
    }
    if (current?.id != collection.id || busy) return;
    preparing = true;
    message = 'Conferindo correspondências…';
    final token = DownloadCancellation();
    _cancellation = token;
    notifyListeners();
    try {
      final result = await _sources.prepare(collection, token,
          onlyPending: onlyPending, recordsChanged: refresh, onTrack: (track) {
        activeTitle = track.displayTitle;
        message =
            'Procurando faixas de áudio: ${track.position}/${collection.trackCount}';
        notifyListeners();
      });
      message =
          '${result.prepared} faixa(s) preparada(s). ${result.review} para revisão; videoclipes exigem aprovação.';
      if (collection.isPartial) {
        message += '\nLeitura parcial: confira o total de faixas importadas.';
      }
    } on DownloadCancelled {
      message =
          'Busca interrompida. As correspondências já conferidas foram mantidas.';
    } catch (error) {
      message = operationMessage(error);
    } finally {
      preparing = false;
      activeTitle = '';
      _cancellation = null;
      await refresh();
      if (focused != null) await _loadMusicCandidates(focused!);
    }
  }

  Future<void> useMusicCandidate(Candidate candidate,
      {bool approveVideo = false}) async {
    if (focused == null ||
        (focused!.hasManualSource && !focused!.redownloadReview) ||
        busy ||
        music?.canUse(candidate) != true) {
      return;
    }
    try {
      await repository.chooseMusicSource(focused!, candidate,
          approveVideo: approveVideo, userSelected: true);
      message =
          'Fonte vinculada: ${candidate.kind.musicProviderName ?? 'Fonte'}.';
      await refresh();
    } catch (error) {
      message = operationMessage(error);
      notifyListeners();
    }
  }

  Future<void> select(Track track, bool value) async {
    await repository.select(track.id, value);
    await refresh();
  }

  Future<void> loadExample() => _import(() async => demoCollection());
  Future<void> importSpotify(String url) => importPlaylist(url);
  PlaylistCatalog get _playlists => PlaylistCatalog(
      spotify: spotify,
      accountSpotify: accountSpotify,
      soundcloud: soundcloud,
      deezer: deezerPlaylists,
      youtube: youtubePlaylists,
      available: music?.available == true,
      deezerConnected: music?.connection.connected == true);
  CollectionLinkComposer get _composer => CollectionLinkComposer(
      _playlists,
      MusicLinkService(
          linkCatalog ??
              MusicLinkCatalog(spotify: accountSpotify, soundcloud: soundcloud),
          music));
  Future<void> importPlaylist(String url) async {
    if (busy || !await _authorize(url)) return;
    await _import(() => _playlists.read(url,
        cancelled: () => _disposed || _importCancellation?.cancelled == true,
        onProgress: (done, total) {
          message = 'Lendo faixas: $done/$total';
          notifyListeners();
        }));
  }

  Future<int> createPlaylist(String name,
      {int? groupId, String link = ''}) async {
    if (busy) throw const FormatException('Aguarde a operação em andamento.');
    final valid = organizationName(name);
    if (link.trim().isNotEmpty && !await _authorize(link)) {
      throw const FormatException('Conexão cancelada. Playlist não criada.');
    }
    if (busy) throw const FormatException('Aguarde a operação em andamento.');
    importing = true;
    final token = _importCancellation = DownloadCancellation();
    notifyListeners();
    final organization = CollectionOrganizationRepository(repository.database);
    int? created;
    try {
      final entries = link.trim().isEmpty
          ? <ResolvedMusicLink>[]
          : await _composer.resolve(link.trim(),
              capacity: 10000, cancellation: token, onProgress: (value) {
              linkProgress = value;
              notifyListeners();
            });
      token.check();
      created = await organization.create(valid, groupId: groupId);
      if (entries.isNotEmpty) {
        await MusicLinkRepository(repository.database).append(created, entries);
      }
      token.check();
      await refresh();
      return created;
    } catch (_) {
      if (created != null) await organization.remove(created);
      rethrow;
    } finally {
      importing = false;
      _importCancellation = null;
      linkProgress = '';
      notifyListeners();
    }
  }

  Future<void> importCsv() async {
    if (busy) return;
    final path = await files.chooseCsv();
    if (path != null) await _import(() async => csv.open(path));
  }

  Future<void> _import(Future<ImportedCollection> Function() source) async {
    if (busy) return;
    _searchGeneration++;
    importing = true;
    final token = _importCancellation = DownloadCancellation();
    message = 'Lendo a coleção…';
    var importedSuccessfully = false;
    notifyListeners();
    try {
      final imported = await source();
      token.check();
      final id = await repository.importCollection(ImportedCollection(
          name: imported.name,
          source: imported.source,
          sourceUrl: imported.sourceUrl,
          isPartial: imported.isPartial,
          tracks: imported.tracks.map((track) {
            token.check();
            return track;
          })));
      collections = await repository.collections();
      current = collections.firstWhere((c) => c.id == id);
      collectionOffset = 0;
      collectionQuery = '';
      focused = null;
      candidates = [];
      selectedCandidate = null;
      view = 'collections';
      trackSort = TrackSort.position;
      trackDescending = false;
      message = imported.isPartial
          ? 'Leitura pública parcial. O Spotify pode limitar a lista; confira o total ou importe um CSV completo.'
          : imported.source == 'Exemplo local'
              ? 'Exemplo local: trechos sintéticos de 4 segundos. Nenhuma música comercial foi baixada.'
              : 'Coleção importada. A ordem e as repetições foram preservadas.';
      await refresh();
      importedSuccessfully = true;
    } on DownloadCancelled {
      message = 'Importação cancelada.';
    } catch (error) {
      message = operationMessage(error);
    } finally {
      importing = false;
      _importCancellation = null;
      if (importedSuccessfully && !isExample && music?.available == true) {
        unawaited(prepareMusic(onlyPending: true));
      }
      notifyListeners();
    }
  }

  Future<void> search(String query) async {
    if (searching || focused == null) return;
    final requestedTrack = focused!.id;
    if (!await _authorizePrimary() ||
        _disposed ||
        searching ||
        focused?.id != requestedTrack) {
      return;
    }
    final generation = ++_searchGeneration;
    searching = true;
    notifyListeners();
    try {
      final found = music == null
          ? await catalog.search(query)
          : await music!.search(focused!, query);
      if (generation == _searchGeneration) {
        candidates = found;
        selectedCandidate = null;
        message = found.isEmpty
            ? 'Nenhum resultado. Tente ajustar título ou artista.'
            : music == null
                ? 'A Deezer oferece prévias nesta integração; os resultados não habilitam download de faixa completa.'
                : 'Fontes em Deezer, YouTube Music e SoundCloud; videoclipes só como última alternativa e com aprovação.';
        if (music != null && focused != null) {
          await repository.saveCandidates(focused!.id, found);
        }
      }
    } catch (error) {
      message = operationMessage(error);
    } finally {
      searching = false;
      notifyListeners();
    }
  }

  MatchAssessment assess(Candidate candidate) =>
      const TrackMatcher().assess(focused!, candidate);
  Future<void> usePreview(Candidate candidate) async {
    final track = focused;
    if (track == null ||
        (track.hasManualSource && !track.redownloadReview) ||
        candidate.previewUrl.isEmpty ||
        busy) {
      return;
    }
    message = await _sources.usePreview(track, candidate);
    await refresh();
  }

  Future<void> linkMp3(String url) async {
    await setManualSource(url, ManualSourceMode.originalAudio);
  }

  Future<void> chooseOutput() async {
    if (busy) return;
    try {
      final path = await files.chooseOutput();
      if (path != null) {
        await repository.setPreference('output_directory', path);
        outputDirectory = path;
      }
    } catch (error) {
      message = operationMessage(error);
    }
    notifyListeners();
  }

  Future<void> openOutput() async {
    try {
      await files.openFolder(outputDirectory);
    } catch (error) {
      message = operationMessage(error);
      notifyListeners();
    }
  }

  Future<void> searchYoutube() async {
    if (focused == null) return;
    await files.openUrl(Uri.https('music.youtube.com', '/search',
        {'q': '${focused!.artist} ${focused!.title}'}));
  }

  Future<bool> startDownloads(
      {List<int>? queueIds, bool failedOnly = false}) async {
    if (!await _checkDownloadSelection(
        queueIds: queueIds, failedOnly: failedOnly)) {
      return false;
    }
    unawaited(_downloadSelected(queueIds: queueIds, failedOnly: failedOnly));
    return true;
  }

  Future<void> downloadSelected(
      {List<int>? queueIds, bool failedOnly = false}) async {
    if (await _checkDownloadSelection(
        queueIds: queueIds, failedOnly: failedOnly)) {
      await _downloadSelected(queueIds: queueIds, failedOnly: failedOnly);
    }
  }

  Future<bool> _checkDownloadSelection(
      {List<int>? queueIds, bool failedOnly = false}) async {
    if (busy || (current == null && queueIds == null)) return false;
    _checkingDownloads = true;
    notifyListeners();
    try {
      final result = await DownloadSelectionCheck(repository, files).check(
          collectionId: current?.id, ids: queueIds, failedOnly: failedOnly);
      if (result.error != null) {
        message = result.error!;
        return false;
      }
      if (result.reviewId != null) {
        await _openDownloadReview(result.reviewId!);
        return false;
      }
      if (result.existingId != null &&
          !await RedownloadRepository(repository.database).hasWork(
              collectionId: current?.id,
              ids: queueIds,
              failedOnly: failedOnly)) {
        await _openDownloadReview(result.existingId!);
        return false;
      }
      if (accounts != null &&
          !accounts!.connected(MusicAccount.deezer) &&
          await RedownloadRepository(repository.database).hasWork(
              collectionId: current?.id,
              ids: queueIds,
              failedOnly: failedOnly,
              deezerOnly: true) &&
          !await _authorizePrimary()) {
        return false;
      }
      return true;
    } catch (error) {
      message = operationMessage(error);
      return false;
    } finally {
      _checkingDownloads = false;
      notifyListeners();
    }
  }

  Future<void> _openDownloadReview(int id) async {
    final track = await repository.trackById(id);
    if (track == null) return;
    final owner = await repository.collectionById(track.collectionId);
    if (owner == null) return;
    await repository.selectFromClick(owner.id, id, extend: false);
    await openCollection(owner);
    focus((await repository.trackById(id))!);
    inspectorRequest++;
    notifyListeners();
  }

  Future<void> _downloadSelected(
      {List<int>? queueIds, bool failedOnly = false}) async {
    final collection = current;
    if ((collection == null && queueIds == null) || busy) return;
    downloading = true;
    progress = null;
    _startingRun = true;
    final token = DownloadCancellation();
    _cancellation = token;
    notifyListeners();
    try {
      message = await DownloadQueueRun(repository, downloader, music,
              files: files, inspector: localInspector)
          .execute(
              outputDirectory: outputDirectory,
              collectionId: collection?.id,
              queueIds: queueIds,
              failedOnly: failedOnly,
              token: token,
              recordsChanged: refresh,
              pendingAddition: () => _additionDone?.future,
              pendingMutation: () =>
                  _holdQueueForReview ? _additionDone?.future : null,
              onEvent: _downloadEvent);
    } catch (error) {
      message = operationMessage(error);
    } finally {
      _activeRun = null;
      _startingRun = false;
      downloading = false;
      activeTitle = '';
      activeTrackId = null;
      progress = null;
      transfer = null;
      _cancellation = null;
      await refresh();
    }
  }

  void _downloadEvent(DownloadRunEvent event) {
    switch (event) {
      case DownloadRunMembership():
        _activeRun = event.run;
        _startingRun = false;
      case DownloadRunTrack():
        activeTrackId = event.track.id;
        activeTitle = event.track.downloadName;
        progress = null;
        transfer = null;
      case DownloadRunProgress():
        progress = event.fraction;
        transfer = event.transfer;
        if (!_disposed) _transferUpdates.notifyListeners();
        return;
      case DownloadRunNotice():
        message = event.message;
    }
    notifyListeners();
  }

  void cancel() {
    _importCancellation?.cancelled = true;
    _cancellation?.cancelled = true;
    message = 'Interrompendo após liberar a operação atual…';
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _refreshGeneration++;
    _searchGeneration++;
    _cancellation?.cancelled = true;
    _trackListing.clear();
    _importCancellation?.cancelled = true;
    _transferUpdates.dispose();
    _additionCancellation?.cancelled = true;
    super.dispose();
  }
}

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../../../core/platform/desktop_files.dart';
import '../../../core/network/bounded_http.dart';
import '../../downloads/download_service.dart';
import '../../downloads/playlist_exporter.dart';
import '../../importing/csv_importer.dart';
import '../../importing/demo_collection.dart';
import '../../importing/spotify_importer.dart';
import '../../importing/spotify_account_importer.dart';
import '../../matching/deezer_catalog.dart';
import '../../matching/music_resolver.dart';
import '../data/library_repository.dart';
import '../domain/models.dart';
import '../domain/matching.dart';

class LibraryController extends ChangeNotifier {
  LibraryController(
      {required this.repository,
      required this.files,
      required this.spotify,
      required this.csv,
      required this.catalog,
      required this.downloader,
      this.accountSpotify,
      this.music});
  final MusicResolver? music;
  final LibraryRepository repository;
  final DesktopFiles files;
  final SpotifyImporter spotify;
  final SpotifyAccountImporter? accountSpotify;
  final CsvImporter csv;
  final DeezerCatalog catalog;
  final DownloadService downloader;
  List<Collection> collections = [];
  Collection? current;
  TrackPage page = const TrackPage([], 0, 0);
  Track? focused;
  List<Candidate> candidates = [];
  String outputDirectory = '';
  String message = '';
  String view = 'collections';
  int offset = 0;
  bool importing = false;
  bool searching = false;
  bool downloading = false;
  bool preparing = false;
  double? progress;
  String activeTitle = '';
  DownloadCancellation? _cancellation;
  int _searchGeneration = 0;
  bool get busy => importing || downloading || preparing;
  bool get isExample => current?.source == 'Exemplo local';

  Future<void> initialize({bool example = false}) async {
    await repository.database.initialize();
    outputDirectory = await repository.preference('output_directory') ??
        await files.defaultOutputDirectory();
    collections = await repository.collections();
    if (collections.isNotEmpty) {
      current = collections.first;
      await refresh();
    } else if (example) {
      await loadExample();
    }
    notifyListeners();
  }

  Future<void> refresh() async {
    collections = await repository.collections();
    if (current != null) {
      current = collections.where((c) => c.id == current!.id).firstOrNull;
      if (current != null) {
        page = await repository.page(current!.id,
            offset: offset, filter: view == 'collections' ? '' : view);
        if (offset > 0 && page.items.isEmpty) {
          offset = 0;
          page = await repository.page(current!.id,
              filter: view == 'collections' ? '' : view);
        }
        focused = page.items.where((t) => t.id == focused?.id).firstOrNull;
      }
    }
    notifyListeners();
  }

  Future<void> openCollection(Collection collection) async {
    if (busy) return;
    current = collection;
    offset = 0;
    focused = null;
    candidates = [];
    message = '';
    await refresh();
  }

  Future<void> setView(String value) async {
    view = value;
    offset = 0;
    focused = null;
    candidates = [];
    await refresh();
  }

  Future<void> turnPage(int direction) async {
    offset =
        (offset + direction * 40).clamp(0, page.total > 0 ? page.total - 1 : 0);
    focused = null;
    candidates = [];
    await refresh();
  }

  void focus(Track track) {
    focused = track;
    candidates = [];
    _searchGeneration++;
    notifyListeners();
    if (music != null && !isExample) unawaited(_loadMusicCandidates(track));
  }

  Future<void> _loadMusicCandidates(Track track) async {
    final generation = _searchGeneration;
    final found = await repository.musicCandidates(track.id);
    if (generation == _searchGeneration && focused?.id == track.id) {
      candidates = found;
      notifyListeners();
    }
  }

  Future<void> prepareMusic() async {
    final collection = current;
    final resolver = music;
    if (collection == null || busy || resolver == null) return;
    preparing = true;
    final cancellation = DownloadCancellation();
    _cancellation = cancellation;
    var after = 0;
    var prepared = 0;
    var review = 0;
    notifyListeners();
    try {
      while (!cancellation.cancelled) {
        final batch = await repository.page(collection.id, offset: after);
        if (batch.items.isEmpty) break;
        for (final track in batch.items) {
          cancellation.check();
          if (track.status == TrackStatus.completed ||
              track.sourceKind == SourceKind.localExample) {
            continue;
          }
          activeTitle = track.title;
          message =
              'Procurando faixas de áudio: ${track.position}/${collection.trackCount}';
          notifyListeners();
          try {
            final found = await resolver.search(
                track, '${track.artist} ${track.title}',
                cancellation: cancellation);
            await repository.saveCandidates(track.id, found);
            final choice = resolver.automaticChoice(track, found);
            if (choice != null) {
              await repository.chooseMusicSource(track, choice);
              prepared++;
            } else {
              review++;
            }
          } on DownloadCancelled {
            rethrow;
          } catch (error) {
            review++;
            await repository.setStatus(track.id, TrackStatus.pending,
                error: _message(error));
          }
          await refresh();
        }
        after += batch.items.length;
      }
      message =
          '$prepared faixa(s) preparada(s). $review para revisão. Videoclipes excluídos.';
    } on DownloadCancelled {
      message =
          'Busca interrompida. As correspondências já conferidas foram mantidas.';
    } finally {
      preparing = false;
      activeTitle = '';
      _cancellation = null;
      await refresh();
      if (focused != null) await _loadMusicCandidates(focused!);
    }
  }

  Future<void> useMusicCandidate(Candidate candidate) async {
    if (focused == null || busy || music?.canUse(candidate) != true) return;
    await repository.chooseMusicSource(focused!, candidate);
    message =
        'Faixa vinculada: ${candidate.kind == SourceKind.deezerFull ? 'Deezer' : 'YouTube Music'}. A versão escolhida será reconferida no download.';
    await refresh();
  }

  Future<void> select(Track track, bool value) async {
    await repository.select(track.id, value);
    await refresh();
  }

  Future<void> selectPage(bool value) async {
    await repository.selectPage(page.items.map((t) => t.id).toList(), value);
    await refresh();
  }

  Future<void> loadExample() => _import(() async => demoCollection());
  Future<void> importSpotify(String url) =>
      _import(() => accountSpotify?.isConnected == true
          ? accountSpotify!.open(url)
          : spotify.open(url));
  Future<void> importCsv() async {
    if (busy) return;
    final path = await files.chooseCsv();
    if (path != null) await _import(() async => csv.open(path));
  }

  Future<void> _import(Future<ImportedCollection> Function() source) async {
    if (busy) return;
    importing = true;
    message = 'Lendo a coleção…';
    notifyListeners();
    try {
      final imported = await source();
      final id = await repository.importCollection(imported);
      collections = await repository.collections();
      current = collections.firstWhere((c) => c.id == id);
      offset = 0;
      focused = null;
      candidates = [];
      view = 'collections';
      message = imported.isPartial
          ? 'Leitura pública parcial. O Spotify pode limitar a lista; confira o total ou importe um CSV completo.'
          : imported.source == 'Exemplo local'
              ? 'Exemplo local: trechos sintéticos de 4 segundos. Nenhuma música comercial foi baixada.'
              : 'Coleção importada. A ordem e as repetições foram preservadas.';
      await refresh();
    } catch (error) {
      message = _message(error);
    } finally {
      importing = false;
      notifyListeners();
    }
  }

  Future<void> search(String query) async {
    if (searching || focused == null) return;
    final generation = ++_searchGeneration;
    searching = true;
    notifyListeners();
    try {
      final found = music == null
          ? await catalog.search(query)
          : await music!.search(focused!, query);
      if (generation == _searchGeneration) {
        candidates = found;
        message = found.isEmpty
            ? 'Nenhum resultado. Tente ajustar título ou artista.'
            : music == null
                ? 'A Deezer oferece prévias nesta integração; os resultados não habilitam download de faixa completa.'
                : 'Faixas de áudio em Deezer e YouTube Music. Videoclipes foram excluídos.';
        if (music != null && focused != null) {
          await repository.saveCandidates(focused!.id, found);
        }
      }
    } catch (error) {
      message = _message(error);
    } finally {
      searching = false;
      notifyListeners();
    }
  }

  MatchAssessment assess(Candidate candidate) =>
      const TrackMatcher().assess(focused!, candidate);
  Future<void> usePreview(Candidate candidate) async {
    final track = focused;
    if (track == null || candidate.previewUrl.isEmpty || busy) return;
    await repository.linkSource(track,
        url: candidate.previewUrl,
        kind: SourceKind.preview,
        title: candidate.title,
        artist: candidate.artist,
        album: candidate.album,
        coverUrl: candidate.coverUrl);
    message =
        'Prévia vinculada. O arquivo será identificado como prévia, com a fonte real.';
    await refresh();
  }

  Future<void> linkMp3(String url) async {
    if (focused == null || busy) return;
    try {
      final uri = Uri.parse(url.trim());
      validateHttpUrl(uri);
      await repository.linkSource(focused!,
          url: uri.toString(), kind: SourceKind.directMp3);
      message =
          'MP3 vinculado. O conteúdo será validado durante a transferência.';
      await refresh();
    } catch (error) {
      message = _message(error);
      notifyListeners();
    }
  }

  Future<void> chooseOutput() async {
    if (busy) return;
    final path = await files.chooseOutput();
    if (path != null) {
      outputDirectory = path;
      await repository.setPreference('output_directory', path);
      notifyListeners();
    }
  }

  Future<void> openOutput() async {
    try {
      await files.openFolder(outputDirectory);
    } catch (error) {
      message = _message(error);
      notifyListeners();
    }
  }

  Future<void> searchYoutube() async {
    if (focused == null) return;
    await files.openUrl(Uri.https('music.youtube.com', '/search',
        {'q': '${focused!.artist} ${focused!.title}'}));
  }

  Future<void> downloadSelected() async {
    final collection = current;
    if (collection == null || busy) return;
    downloading = true;
    progress = null;
    final token = DownloadCancellation();
    _cancellation = token;
    final directory = p.join(
        outputDirectory, '${safeSegment(collection.name)} [${collection.id}]');
    var saved = 0;
    var failed = 0;
    var position = 0;
    notifyListeners();
    try {
      while (!token.cancelled) {
        final track = await repository.nextSelected(collection.id,
            afterPosition: position);
        if (track == null) break;
        position = track.position;
        activeTitle = track.title;
        await repository.setStatus(track.id, TrackStatus.downloading);
        await refresh();
        try {
          Future<String> receive(Track item) async {
            try {
              final path =
                  await downloader.save(item, directory, token, (value) {
                progress = value;
                notifyListeners();
              });
              await repository.recordMusicAttempt(item.id, item.sourceKind,
                  succeeded: true);
              return path;
            } on DownloadCancelled {
              rethrow;
            } catch (error) {
              await repository.recordMusicAttempt(item.id, item.sourceKind,
                  succeeded: false, message: _message(error));
              rethrow;
            }
          }

          String path;
          try {
            path = await receive(track);
          } on DownloadCancelled {
            rethrow;
          } catch (error) {
            if (track.sourceKind != SourceKind.deezerFull || music == null) {
              rethrow;
            }
            final alternatives = await repository.musicCandidates(track.id);
            final fallback = music!.automaticChoice(track, alternatives,
                only: SourceKind.youtubeMusic);
            if (fallback == null) rethrow;
            message =
                'Deezer indisponível para esta faixa; tentando a correspondência de áudio no YouTube Music.';
            notifyListeners();
            await repository.chooseMusicSource(track, fallback);
            final updated = await repository.trackById(track.id);
            await repository.setStatus(track.id, TrackStatus.downloading);
            path = await receive(updated!);
          }
          await repository.setStatus(track.id, TrackStatus.completed,
              localPath: path);
          saved++;
        } on DownloadCancelled {
          await repository.setStatus(track.id, TrackStatus.ready,
              error: 'Interrompido. Uma nova tentativa reinicia este arquivo.');
          break;
        } catch (error) {
          failed++;
          await repository.setStatus(track.id, TrackStatus.failed,
              error: _message(error));
        }
        await refresh();
      }
      if (saved > 0) {
        await PlaylistExporter(repository).export(collection.id, directory);
      }
      message = token.cancelled
          ? 'Transferência interrompida. Os arquivos concluídos foram preservados.'
          : saved == 0 && failed == 0
              ? 'Selecione faixas com uma fonte vinculada. Itens já salvos não são baixados novamente.'
              : '$saved arquivo(s) salvo(s) com metadados. $failed falha(s). Playlist M3U8 na pasta da coleção.';
    } catch (error) {
      message = _message(error);
    } finally {
      downloading = false;
      activeTitle = '';
      progress = null;
      _cancellation = null;
      await refresh();
    }
  }

  void cancel() {
    _cancellation?.cancelled = true;
    message = 'Interrompendo após liberar a operação atual…';
    notifyListeners();
  }

  String _message(Object error) {
    if (error is HandshakeException) {
      return 'Não foi possível validar o certificado da conexão. Verifique a rede e os certificados do sistema; você também pode importar um CSV.';
    }
    if (error is TimeoutException) {
      return 'O serviço demorou para responder. Tente novamente mais tarde.';
    }
    if (error is SocketException) {
      return 'Não foi possível conectar ao serviço. Verifique sua conexão e tente novamente.';
    }
    if (error is FormatException) return error.message;
    if (error is HttpException) return error.message;
    if (error is FileSystemException) return error.message;
    return 'Não foi possível concluir a operação. ${error.toString().replaceFirst('Exception: ', '')}';
  }
}

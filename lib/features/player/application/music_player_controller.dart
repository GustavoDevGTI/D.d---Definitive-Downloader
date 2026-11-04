import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../../core/platform/desktop_files.dart';
import '../../library/domain/models.dart';
import '../../workspace/domain/workspace_models.dart';
import '../data/player_library.dart';
import '../domain/playback.dart';

class MusicPlayerController extends ChangeNotifier {
  MusicPlayerController(this.library, this.engine, this.files, {Random? random})
      : random = random ?? Random() {
    _subscription = engine.events.listen(_event);
  }
  final PlayerLibrary library;
  final AudioEngine engine;
  final DesktopFiles files;
  final Random random;
  late final StreamSubscription<AudioEvent> _subscription;
  List<AudioItem> _queue = const [];
  List<int> _order = [];
  final List<int> _history = [];
  final Set<int> _failed = {};
  List<AudioItem> get queue => _queue;
  AudioItem? get current =>
      index >= 0 && index < _queue.length ? _queue[index] : null;
  int index = -1, _request = 0;
  bool playing = false,
      loading = false,
      buffering = false,
      shuffled = false,
      ended = false,
      _disposed = false;
  bool _moduleActive = true;
  Future<void> setModuleActive(bool value) async {
    _moduleActive = value;
    if (!value) await pause();
  }

  AudioRepeat repeat = AudioRepeat.off;
  double volume = .65, _lastVolume = .65;
  Duration position = Duration.zero, duration = Duration.zero;
  final _timeline = ChangeNotifier();
  Listenable get timeline => _timeline;
  Uint8List? cover;
  String title = '', artist = '', message = '';
  Future<void> _operations = Future<void>.value();
  Timer? _volumeTimer;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() async {
    if (!engine.available) {
      message = 'Player indisponível neste ambiente. Confira a instalação.';
      _notify();
      return;
    }
    Map<String, String> preferences = {};
    try {
      preferences = await library.preferences();
    } catch (_) {/* Defaults remain usable. */}
    final storedVolume = double.tryParse(preferences['player_volume'] ?? '');
    volume = (storedVolume?.isFinite == true ? storedVolume! : .65).clamp(0, 1);
    if (volume > 0) _lastVolume = volume;
    shuffled = preferences['player_shuffle'] == 'true';
    repeat = AudioRepeat.values
            .where((v) => v.name == preferences['player_repeat'])
            .firstOrNull ??
        AudioRepeat.off;
    await _safe(() => engine.volume(volume));
    _notify();
  }

  bool canListenTrack(Track t) =>
      _youtube(t.sourceKind) ||
      engine.available &&
          (t.localPath.isNotEmpty ||
              [SourceKind.deezerFull, SourceKind.preview, SourceKind.directMp3]
                  .contains(t.sourceKind));
  bool canListenCandidate(Track t, Candidate c) =>
      _youtube(c.kind) ||
      engine.available &&
          ([SourceKind.deezerFull, SourceKind.preview, SourceKind.directMp3]
                  .contains(c.kind) ||
              (t.localPath.isNotEmpty &&
                  t.mediaUrl == c.pageUrl &&
                  t.redownloadState.isEmpty));
  String trackListenLabel(Track t) => t.localPath.isNotEmpty
      ? 'Ouvir'
      : [SourceKind.deezerFull, SourceKind.preview].contains(t.sourceKind)
          ? 'Ouvir prévia'
          : _youtube(t.sourceKind)
              ? 'Ouvir no ${t.sourceKind.musicProviderName}'
              : 'Ouvir';
  bool _youtube(SourceKind kind) =>
      kind == SourceKind.youtubeMusic || kind == SourceKind.youtube;
  String candidateListenLabel(Track t, Candidate c) => t.localPath.isNotEmpty &&
          t.mediaUrl == c.pageUrl &&
          t.redownloadState.isEmpty
      ? 'Ouvir'
      : [SourceKind.deezerFull, SourceKind.preview].contains(c.kind)
          ? 'Ouvir prévia'
          : _youtube(c.kind)
              ? 'Ouvir no ${c.kind.musicProviderName}'
              : 'Ouvir';

  Future<void> playCollection(int id, {int? startTrackId}) async {
    final request = ++_request;
    loading = true;
    message = '';
    _notify();
    try {
      final items = await library.collection(id);
      if (request != _request || _disposed) return;
      if (items.isEmpty) {
        throw const FormatException(
            'Esta playlist ainda não tem arquivos locais para ouvir.');
      }
      final start = startTrackId == null
          ? 0
          : items.indexWhere((i) => i.id == 'track-$startTrackId');
      await _setQueue(items, start < 0 ? 0 : start, request);
    } catch (_) {
      if (request == _request) {
        loading = false;
        message =
            'Nenhum arquivo disponível nesta playlist. Confira os arquivos em Informações.';
        _notify();
      }
    }
  }

  Future<void> listenTrack(Track track) async {
    final request = ++_request;
    loading = true;
    message = '';
    _notify();
    try {
      final local = await library.localFor(track);
      if (request != _request || _disposed) return;
      if (local != null) {
        final items = await library.collection(track.collectionId);
        if (request != _request || _disposed) return;
        final start = items.indexWhere((i) => i.id == local.id);
        await _setQueue(
            start < 0 ? [local] : items, start < 0 ? 0 : start, request);
      } else {
        final item = await library.track(track);
        if (request != _request || _disposed) return;
        if (item == null) {
          if (_youtube(track.sourceKind)) {
            await pause();
            await openReference(library.referenceFor(track));
            loading = false;
            _notify();
            return;
          }
          throw const FormatException(
              'Sem áudio disponível. Abra a referência desta versão.');
        }
        await _setQueue([item], 0, request);
      }
    } catch (_) {
      if (request == _request) {
        loading = false;
        message =
            'Não foi possível ouvir esta fonte. Abra a referência para conferir a versão.';
        _notify();
      }
    }
  }

  Future<void> listenCandidate(Track track, Candidate candidate) async {
    final request = ++_request;
    loading = true;
    message = '';
    _notify();
    try {
      final item = await library.candidate(track, candidate);
      if (request != _request || _disposed) return;
      if (item == null) {
        if (_youtube(candidate.kind)) {
          await pause();
          await openReference(library.referenceForCandidate(candidate));
          loading = false;
          _notify();
          return;
        }
        throw const FormatException('Sem prévia disponível.');
      }
      await _setQueue([item], 0, request);
    } catch (_) {
      if (request == _request) {
        loading = false;
        message = 'Prévia indisponível. Abra a referência desta versão.';
        _notify();
      }
    }
  }

  Future<void> playHistory(HistoryEntry entry) async {
    final request = ++_request;
    await _setQueue([library.history(entry)], 0, request);
  }

  Future<void> _setQueue(List<AudioItem> items, int start, int request) async {
    if (request != _request || _disposed) return;
    _queue = List.unmodifiable(items);
    _history.clear();
    _failed.clear();
    _order = List.generate(items.length, (i) => i);
    if (shuffled) {
      _order.remove(start);
      _order.shuffle(random);
      _order.insert(0, start);
    }
    await _open(start, request);
  }

  Future<void> _serial(Future<void> Function() work) {
    final next = _operations.then((_) => work());
    _operations = next.catchError((Object _) {});
    return next;
  }

  Future<void> _open(int target, int request) => _serial(() async {
        if (_disposed ||
            request != _request ||
            target < 0 ||
            target >= _queue.length) {
          return;
        }
        loading = true;
        ended = false;
        position = Duration.zero;
        cover = null;
        message = '';
        _notify();
        var chosen = target;
        for (var attempts = 0; attempts < _queue.length; attempts++) {
          final item = _queue[chosen];
          if (!_failed.contains(chosen) && await library.available(item)) {
            if (_disposed || request != _request) return;
            index = chosen;
            title = item.title;
            artist = item.artist;
            duration =
                item.duration > Duration.zero ? item.duration : Duration.zero;
            _notify();
            try {
              await engine.volume(volume);
              await engine.open(item.uri).timeout(const Duration(seconds: 20));
              if (_disposed || request != _request) return;
              if (!_moduleActive) await engine.pause();
              loading = false;
              playing = _moduleActive;
              _notify();
              unawaited(_loadTags(item, request));
              return;
            } catch (_) {
              if (_disposed || request != _request) return;
              _failed.add(chosen);
            }
          } else {
            _failed.add(chosen);
          }
          final slot = _order.indexOf(chosen);
          chosen = _order[(slot + 1) % _order.length];
        }
        loading = false;
        playing = false;
        message =
            'Arquivos indisponíveis ou áudio inválido. Confira os arquivos da fila.';
        if (!_disposed) await _safe(engine.stop);
        _notify();
      });
  Future<void> _loadTags(AudioItem item, int request) async {
    try {
      final tags = await library.tags(item);
      if (_disposed || request != _request || current?.id != item.id) return;
      cover = tags.cover;
      if (tags.title.isNotEmpty) title = tags.title;
      if (tags.artist.isNotEmpty) artist = tags.artist;
      _notify();
    } catch (_) {/* Artwork failure does not stop valid audio. */}
  }

  void _event(AudioEvent event) {
    if (_disposed) return;
    final stateChanged = (event.playing != null && playing != event.playing) ||
        (event.buffering != null && buffering != event.buffering);
    final clockChanged =
        (event.position != null && position != event.position) ||
            (event.duration != null &&
                event.duration! > Duration.zero &&
                duration != event.duration);
    if (event.playing != null) playing = event.playing!;
    if (event.position != null) position = event.position!;
    if (event.duration != null && event.duration! > Duration.zero) {
      duration = event.duration!;
    }
    if (event.buffering != null) buffering = event.buffering!;
    if (event.failed && !loading) {
      playing = false;
      message =
          'Não foi possível reproduzir o áudio. Abra a referência ou confira o arquivo.';
    }
    if (event.completed && !loading && !ended) {
      ended = true;
      playing = false;
      if (_moduleActive) unawaited(_complete());
    }
    if (clockChanged) _timeline.notifyListeners();
    if (stateChanged || event.failed || event.completed) _notify();
  }

  Future<void> _complete() async {
    if (!_moduleActive) return;
    if (repeat == AudioRepeat.track) {
      await seek(Duration.zero);
      if (!_moduleActive) return;
      await _safe(engine.play);
      ended = false;
    } else {
      await next(automatic: true);
    }
  }

  Future<void> pause() async {
    if (playing) await _safe(engine.pause);
  }

  Future<void> toggle() async {
    if (current == null || loading) return;
    if (playing) {
      await _safe(engine.pause);
    } else {
      if (ended) {
        await seek(Duration.zero);
        ended = false;
      }
      await _safe(engine.play);
    }
  }

  Future<void> next({bool automatic = false}) async {
    if (current == null || loading) return;
    final slot = _order.indexOf(index);
    if (slot + 1 >= _order.length && repeat == AudioRepeat.off) {
      if (!automatic) await _safe(engine.pause);
      playing = false;
      ended = true;
      _notify();
      return;
    }
    _remember();
    final target = _order[(slot + 1) % _order.length];
    await _open(target, ++_request);
  }

  Future<void> previous() async {
    if (current == null || loading) return;
    if (position >= const Duration(seconds: 3)) {
      await seek(Duration.zero);
      return;
    }
    final slot = _order.indexOf(index);
    final target = _history.isNotEmpty
        ? _history.removeLast()
        : slot > 0
            ? _order[slot - 1]
            : index;
    await _open(target, ++_request);
  }

  Future<void> jump(int target) async {
    if (target < 0 || target >= _queue.length) return;
    _failed.remove(target);
    if (index >= 0) _remember();
    await _open(target, ++_request);
  }

  Future<void> seek(Duration target) async {
    if (current == null) return;
    final bounded = Duration(
        milliseconds: target.inMilliseconds.clamp(0, duration.inMilliseconds));
    await _safe(() => engine.seek(bounded));
    position = bounded;
    _notify();
  }

  void _remember() {
    if (_history.length >= 10000) _history.removeAt(0);
    _history.add(index);
  }

  Future<void> _safe(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      message = 'O player não concluiu a ação. Tente reproduzir novamente.';
      _notify();
    }
  }

  void setVolume(double value) {
    if (!value.isFinite || _disposed) return;
    volume = value.clamp(0, 1);
    if (volume > 0) _lastVolume = volume;
    _volumeTimer?.cancel();
    _volumeTimer = Timer(const Duration(milliseconds: 40),
        () => unawaited(_safe(() => engine.volume(volume))));
    _notify();
  }

  Future<void> _persist(String key, String value) async {
    try {
      await library.savePreference(key, value);
    } catch (_) {
      message = 'Não foi possível salvar a preferência do player.';
      _notify();
    }
  }

  Future<void> saveVolume() => _persist('player_volume', volume.toString());
  void mute() {
    setVolume(volume == 0 ? _lastVolume : 0);
    unawaited(saveVolume());
  }

  void toggleShuffle() {
    shuffled = !shuffled;
    _order = List.generate(_queue.length, (i) => i);
    if (shuffled && index >= 0) {
      _order.remove(index);
      _order.shuffle(random);
      _order.insert(0, index);
    }
    unawaited(_persist('player_shuffle', shuffled.toString()));
    _notify();
  }

  void cycleRepeat() {
    repeat = AudioRepeat.values[(repeat.index + 1) % AudioRepeat.values.length];
    unawaited(_persist('player_repeat', repeat.name));
    _notify();
  }

  Future<void> openReference(String value) async {
    final url = publicReference(value);
    if (url.isEmpty) return;
    await _safe(() => files.openUrl(Uri.parse(url)));
  }

  Future<void> copyReference(String value) async {
    final url = publicReference(value);
    if (url.isNotEmpty) await Clipboard.setData(ClipboardData(text: url));
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _request++;
    _volumeTimer?.cancel();
    _timeline.dispose();
    unawaited(_subscription.cancel());
    unawaited(engine.dispose());
    super.dispose();
  }
}

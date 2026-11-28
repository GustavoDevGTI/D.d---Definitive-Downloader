import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../../../core/application/operation_message.dart';
import '../../downloads/download_cancellation.dart';
import '../../downloads/download_file_name.dart';
import '../../library/domain/models.dart';
import '../../library/application/library_controller.dart';
import '../data/audio_capture_service.dart';
import '../data/capture_sessions.dart';
import '../domain/capture_login.dart';
import '../domain/audio_capture.dart';

/// Opens the platform's login window. [verify] retries the analysis with the
/// captured session; the window closes only when it succeeds.
typedef CaptureLoginRequest = Future<List<SessionCookie>?> Function(
    CapturePlatform platform,
    Future<bool> Function(List<SessionCookie> session) verify);

class AudioCaptureController extends ChangeNotifier {
  AudioCaptureController(this.library,
      {AudioCaptureService? service, CaptureSessionStore? sessions})
      : service = service ??
            (library.music == null
                ? null
                : AudioCaptureService(library.music!.engine)),
        sessions = sessions ?? library.captureSessions;
  final LibraryController library;
  final AudioCaptureService? service;
  final CaptureSessionStore sessions;
  CaptureLoginRequest? requestLogin;

  /// Platforms with a session saved in the vault.
  final Set<CapturePlatform> signedIn = {};

  Future<void> loadSessions() async {
    final saved = <CapturePlatform>{};
    for (final platform in CapturePlatform.values) {
      try {
        if (await sessions.read(platform) != null) saved.add(platform);
      } catch (_) {/* An unreadable vault entry is treated as signed out. */}
    }
    if (_disposed) return;
    signedIn
      ..clear()
      ..addAll(saved);
    notifyListeners();
  }

  Future<void> signOut(CapturePlatform platform) async {
    if (busy) return;
    await sessions.clear(platform);
    signedIn.remove(platform);
    message = 'Sessão do ${platform.label} removida deste aparelho.';
    notifyListeners();
  }

  AudioCaptureResult? result;
  final Set<String> selected = {};
  String message = '', stage = '';

  /// Location chosen for this capture; empty uses the default location.
  String destinationRoot = '';
  bool analyzing = false, submitting = false;
  bool _disposed = false;
  DownloadCancellation? _cancellation;
  bool get busy => analyzing || submitting;
  bool get available => service?.engine.available == true;

  void select(String id, bool value) {
    if (busy) return;
    value ? selected.add(id) : selected.remove(id);
    notifyListeners();
  }

  void selectAll(bool value) {
    if (busy) return;
    selected.clear();
    if (value) selected.addAll(result!.items.map((item) => item.sourceId));
    notifyListeners();
  }

  /// Folder the selected audios would go to: the chosen location plus a
  /// folder named after the audio (one) or the page (several).
  String get destinationPreview {
    final found = result;
    final root =
        destinationRoot.isEmpty ? library.outputDirectory : destinationRoot;
    if (found == null || selected.isEmpty || root.isEmpty) return root;
    return p.join(root, safeSegment(found.nameFor(selected)));
  }

  Future<void> pickDestination() async {
    if (busy) return;
    try {
      final chosen = await library.pickDestinationRoot();
      if (chosen != null && !_disposed) destinationRoot = chosen;
    } catch (error) {
      message = operationMessage(error);
    }
    if (!_disposed) notifyListeners();
  }

  void useDefaultDestination() {
    if (busy || destinationRoot.isEmpty) return;
    destinationRoot = '';
    notifyListeners();
  }

  /// Removes the selected audios from this analysis. Nothing was saved yet.
  void discardSelected() => _discard({...selected});

  void discard(String id) => _discard({id});

  void _discard(Set<String> ids) {
    final found = result;
    if (busy || found == null || ids.isEmpty) return;
    final remaining = found.without(ids);
    selected.removeAll(ids);
    result = remaining.items.isEmpty ? null : remaining;
    message = '';
    notifyListeners();
  }

  void clearResult() {
    if (busy || result == null) return;
    result = null;
    selected.clear();
    message = '';
    notifyListeners();
  }

  Future<void> analyze(String url) async {
    if (busy) return;
    if (!available) {
      message = 'O motor de áudio não está disponível neste dispositivo.';
      notifyListeners();
      return;
    }
    analyzing = true;
    result = null;
    selected.clear();
    message = '';
    stage = 'Analisando página…';
    final token = _cancellation = DownloadCancellation();
    notifyListeners();
    void onStage(String value) {
      if (_disposed || token.cancelled) return;
      stage = value;
      notifyListeners();
    }

    try {
      // Connections may have changed the saved sessions meanwhile.
      await loadSessions();
      final platform = CapturePlatform.forUrl(url);
      final saved = platform == null ? null : await sessions.read(platform);
      AudioCaptureResult found;
      try {
        found = await service!.analyze(url,
            cancellation: token, onStage: onStage, session: saved);
      } on CaptureLoginRequired catch (login) {
        if (login.rejected) {
          await sessions.clear(login.platform);
          signedIn.remove(login.platform);
        }
        found = await _login(url, login.platform, token, onStage);
      }
      token.check();
      if (_disposed) return;
      result = found;
      selected.addAll(found.items.map((item) => item.sourceId));
    } on DownloadCancelled {
      message = 'Análise cancelada.';
    } catch (error) {
      message = operationMessage(error);
    } finally {
      analyzing = false;
      stage = '';
      _cancellation = null;
      if (!_disposed) notifyListeners();
    }
  }

  Future<AudioCaptureResult> _login(String url, CapturePlatform platform,
      DownloadCancellation token, void Function(String) onStage) async {
    final ask = requestLogin;
    if (ask == null) {
      throw FormatException(
          'O ${platform.label} pediu login para liberar este conteúdo.');
    }
    stage = 'Entre no ${platform.label} para continuar';
    notifyListeners();
    AudioCaptureResult? verified;
    final session = await ask(platform, (cookies) async {
      token.check();
      try {
        verified = await service!.analyze(url,
            cancellation: token, onStage: onStage, session: cookies);
        return true;
      } on CaptureLoginRequired {
        return false;
      }
    });
    token.check();
    final result = verified;
    if (session == null || result == null) {
      throw FormatException(
          'Login no ${platform.label} cancelado. Nada foi capturado.');
    }
    await sessions.write(platform, session);
    signedIn.add(platform);
    return result;
  }

  void cancel() => _cancellation?.cancelled = true;

  Future<Collection?> _save() async {
    final saved = await library.importAudioCapture(result!.selection(selected));
    if (saved == null) {
      message = library.message;
      return null;
    }
    if (destinationRoot.isNotEmpty) {
      await library.setCollectionRoot(saved.id, destinationRoot);
    }
    return saved;
  }

  Future<T?> _submit<T>(Future<T?> Function() action) async {
    if (busy || library.busy || result == null || selected.isEmpty) {
      return null;
    }
    submitting = true;
    message = '';
    notifyListeners();
    try {
      return await action();
    } catch (error) {
      message = operationMessage(error);
      return null;
    } finally {
      submitting = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// Creates a playlist with the selected audios and starts downloading it.
  Future<bool> download() async =>
      await _submit(() async {
        final saved = await _save();
        if (saved == null) return false;
        final tracks = await library.repository.page(saved.id, limit: 100);
        final started = await library.startDownloads(
            queueIds: tracks.items.map((track) => track.id).toList());
        selected.clear();
        message = started ? '' : library.message;
        return true;
      }) ??
      false;

  /// Creates a playlist with the selected audios without downloading them.
  Future<Collection?> saveAsPlaylist() => _submit(() async {
        final saved = await _save();
        if (saved != null) {
          selected.clear();
          message = 'Playlist “${saved.name}” criada. Baixe quando quiser.';
        }
        return saved;
      });

  /// Adds the selected audios to the end of an existing playlist.
  Future<bool> addToPlaylist(Collection playlist) async =>
      await _submit(() async {
        final added = await library.appendCapturedAudio(
            playlist.id, result!.drafts(selected));
        message =
            added ? '${library.message} (${playlist.name})' : library.message;
        if (added) selected.clear();
        return added;
      }) ??
      false;

  @override
  void dispose() {
    _disposed = true;
    cancel();
    super.dispose();
  }
}

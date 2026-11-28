import 'package:flutter/foundation.dart';
import '../../../core/application/operation_message.dart';
import '../../library/application/library_controller.dart';
import '../../library/domain/models.dart';
import '../data/status_folder.dart';
import '../domain/status_saver.dart';

/// Status Saver (Android): lists the WhatsApp statuses the user granted,
/// extracts the audio of the chosen ones to MP3 and saves them as a playlist.
/// WhatsApp's files are never changed; only the app's copies are used.
class StatusSaverController extends ChangeNotifier {
  StatusSaverController(this.library);
  final LibraryController library;
  StatusFolder? _folder;
  List<WhatsAppStatus> statuses = const [];
  List<String> titles = const [];
  final Set<String> selected = {};
  bool picking = false, saving = false;
  String message = '', progress = '';
  bool _disposed = false;

  bool get available =>
      library.files.supportsStatusSaver &&
      library.music?.engine.available == true;
  bool get busy => picking || saving;
  bool get hasStatuses => statuses.isNotEmpty;

  Future<void> pick() async {
    if (busy || library.busy) return;
    await _release();
    picking = true;
    message = '';
    notifyListeners();
    try {
      final path = await library.files.chooseWhatsAppStatuses();
      if (path == null || _disposed) return;
      final folder = _folder = StatusFolder(path);
      statuses = await folder.statuses();
      titles = statusTitles(statuses);
      selected
        ..clear()
        ..addAll(statuses.map((status) => status.path));
      if (statuses.isEmpty) {
        message = 'Nenhum status de vídeo ou áudio nesta pasta.';
        await _release();
      }
    } catch (error) {
      message = operationMessage(error);
      await _release();
    } finally {
      picking = false;
      if (!_disposed) notifyListeners();
    }
  }

  void select(String path, bool value) {
    if (busy) return;
    value ? selected.add(path) : selected.remove(path);
    notifyListeners();
  }

  void selectAll(bool value) {
    if (busy) return;
    selected.clear();
    if (value) selected.addAll(statuses.map((status) => status.path));
    notifyListeners();
  }

  Future<void> discard() async {
    if (busy) return;
    await _release();
    message = '';
    notifyListeners();
  }

  /// Extracts the selected statuses and creates one playlist with them, in
  /// the order shown (newest first). Statuses without sound are skipped.
  Future<Collection?> save() async {
    final folder = _folder;
    final engine = library.music?.engine;
    if (busy || library.busy || folder == null || engine == null) return null;
    final chosen = [
      for (var i = 0; i < statuses.length; i++)
        if (selected.contains(statuses[i].path)) (statuses[i], titles[i])
    ];
    if (chosen.isEmpty) return null;
    saving = true;
    message = '';
    notifyListeners();
    try {
      final target =
          await folder.playlistFolder(statusPlaylistName(DateTime.now()));
      var saved = 0, silent = 0;
      String? firstError;
      for (var i = 0; i < chosen.length; i++) {
        progress = 'Extraindo áudio ${i + 1} de ${chosen.length}…';
        if (!_disposed) notifyListeners();
        final (status, title) = chosen[i];
        try {
          final result = await engine.call({
            'operation': 'extractAudio',
            'path': status.path,
            'directory': await folder.staging(i),
            'title': title,
          });
          await folder.collect(result['path'] as String, target, saved, title);
          saved++;
        } on FormatException catch (error) {
          silent++;
          firstError ??= error.message;
        }
      }
      if (saved == 0) {
        message = firstError ??
            'Nenhum dos status escolhidos tem áudio para extrair.';
        return null;
      }
      progress = 'Salvando a playlist…';
      if (!_disposed) notifyListeners();
      final playlist = await library.importLocalFolders([target]);
      if (playlist == null) {
        message = library.message;
        return null;
      }
      message = [
        saved == 1
            ? 'Áudio de 1 status salvo na playlist.'
            : 'Áudio de $saved status salvo na playlist.',
        if (silent > 0)
          silent == 1
              ? '1 status sem áudio foi ignorado.'
              : '$silent status sem áudio foram ignorados.',
      ].join(' ');
      await _release();
      return playlist;
    } catch (error) {
      message = operationMessage(error);
      return null;
    } finally {
      saving = false;
      progress = '';
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> _release() async {
    final folder = _folder;
    _folder = null;
    statuses = const [];
    titles = const [];
    selected.clear();
    if (folder != null) {
      await library.files.releaseWhatsAppStatuses(folder.root);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    final folder = _folder;
    if (folder != null) {
      library.files.releaseWhatsAppStatuses(folder.root).ignore();
    }
    super.dispose();
  }
}

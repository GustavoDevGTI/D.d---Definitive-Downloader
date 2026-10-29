import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../library/application/library_controller.dart';
import '../data/workspace_repository.dart';
import '../domain/workspace_models.dart';

class WorkspaceController extends ChangeNotifier {
  WorkspaceController(this.library)
      : repository = WorkspaceRepository(library.repository.database) {
    library.addListener(_changed);
  }
  final LibraryController library;
  final WorkspaceRepository repository;
  ActivitySummary summary = const ActivitySummary();
  DownloadPage downloads = const DownloadPage([], 0);
  HistoryPage history = const HistoryPage([], [], 0);
  ContentCategory category = ContentCategory.music;
  DownloadFilter filter = DownloadFilter.all;
  int downloadOffset = 0;
  int historyOffset = 0;
  String folder = '';
  String historyQuery = '';
  String message = '';
  final Set<int> selection = {};
  final Map<String, bool> availability = {};
  Timer? _refreshTimer;
  bool _disposed = false;
  bool loaded = false;
  int _generation = 0;

  void _changed() {
    _refreshTimer ??= Timer(const Duration(milliseconds: 400), () {
      _refreshTimer = null;
      unawaited(refresh());
    });
  }

  Future<void> refresh() async {
    final generation = ++_generation;
    final results = await Future.wait<Object>([
      repository.summary(),
      repository.downloads(category,
          filter: filter, offset: downloadOffset, pauseMode: library.pauseMode),
      repository.history(
          folder: folder, query: historyQuery, offset: historyOffset),
    ]);
    if (_disposed || generation != _generation) return;
    summary = results[0] as ActivitySummary;
    loaded = true;
    var downloadPage = results[1] as DownloadPage;
    if (downloadOffset > 0 && downloadPage.items.isEmpty) {
      downloadOffset =
          downloadPage.total == 0 ? 0 : ((downloadPage.total - 1) ~/ 40) * 40;
      downloadPage = await repository.downloads(category,
          filter: filter, offset: downloadOffset, pauseMode: library.pauseMode);
      if (_disposed || generation != _generation) return;
    }
    downloads = downloadPage;
    history = results[2] as HistoryPage;
    selection
        .removeWhere((id) => !downloads.items.any((e) => e.track.id == id));
    notifyListeners();
    final entries = history.files;
    final states = await Future.wait(entries.map((entry) async =>
        MapEntry(entry.path, await library.files.fileExists(entry.path))));
    if (_disposed || generation != _generation) return;
    availability.clear();
    availability.addEntries(states);
    notifyListeners();
  }

  Future<void> setCategory(ContentCategory value) async {
    category = value;
    downloadOffset = 0;
    selection.clear();
    await refresh();
  }

  Future<void> setFilter(DownloadFilter value) async {
    filter = value;
    downloadOffset = 0;
    selection.clear();
    await refresh();
  }

  void select(int id, bool value) {
    value ? selection.add(id) : selection.remove(id);
    notifyListeners();
  }

  void selectPage(bool value) {
    for (final item in downloads.items) {
      value ? selection.add(item.track.id) : selection.remove(item.track.id);
    }
    notifyListeners();
  }

  Future<void> turnDownloads(int direction) async {
    downloadOffset = (downloadOffset + 40 * direction)
        .clamp(0, downloads.total > 0 ? downloads.total - 1 : 0);
    selection.clear();
    await refresh();
  }

  Future<void> openFolder(String value) async {
    folder = value;
    historyOffset = 0;
    await refresh();
  }

  Future<void> searchHistory(String value) async {
    historyQuery = value;
    historyOffset = 0;
    await refresh();
  }

  Future<void> turnHistory(int direction) async {
    historyOffset = (historyOffset + 40 * direction)
        .clamp(0, history.total > 0 ? history.total - 1 : 0);
    await refresh();
  }

  Future<void> removeHistory() async {
    if (library.busy) return;
    await repository.hideCompleted(selection.toList());
    selection.clear();
    await refresh();
  }

  Future<void> changePriority(int delta) async {
    await repository.changePriority(selection.toList(), delta);
    await refresh();
  }

  Future<void> removeDownloads() async {
    await repository.removeDownloads(selection.toList());
    selection.clear();
    await refresh();
  }

  Future<void> start({bool failedOnly = false}) async {
    if (library.pauseMode) {
      library.togglePause();
      return;
    }
    await library.downloadSelected(
        queueIds: selection.toList(), failedOnly: failedOnly);
  }

  Future<void> openFile(HistoryEntry entry) async {
    try {
      await library.files.openSavedFile(entry.path);
    } catch (_) {
      message =
          'Arquivo indisponível ou sem aplicativo associado. O registro foi preservado.';
    }
    await refresh();
  }

  Future<void> reveal(String path) async {
    message = '';
    try {
      await library.files.revealFile(path);
    } catch (_) {
      message = 'A localização não está disponível. O registro foi preservado.';
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _refreshTimer?.cancel();
    library.removeListener(_changed);
    super.dispose();
  }
}

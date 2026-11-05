import 'dart:async';
import '../../../core/application/operation_message.dart';
import 'package:flutter/foundation.dart';
import '../../library/application/library_controller.dart';
import '../data/workspace_repository.dart';
import '../domain/workspace_models.dart';
import '../domain/download_columns.dart';
import '../data/continuous_download_repository.dart';
import 'continuous_download_listing.dart';

class WorkspaceController extends ChangeNotifier {
  WorkspaceController(this.library,
      {WorkspaceRepository? repository,
      ContinuousDownloadRepository? downloadRepository})
      : repository =
            repository ?? WorkspaceRepository(library.repository.database),
        _downloadListing = ContinuousDownloadListing(downloadRepository ??
            ContinuousDownloadRepository(
                (repository ?? WorkspaceRepository(library.repository.database))
                    .database)) {
    _lastLibraryData = _libraryData;
    library.addListener(_changed);
  }
  final LibraryController library;
  final WorkspaceRepository repository;
  ActivitySummary summary = const ActivitySummary();
  DownloadPage downloads = const DownloadPage([], 0);
  HistoryPage history = const HistoryPage([], [], 0);
  ContentCategory category = ContentCategory.music;
  DownloadFilter filter = DownloadFilter.all;
  DownloadSort? downloadSort;
  bool downloadDescending = false;
  int tableRevision = 0;
  final ContinuousDownloadListing _downloadListing;
  int historyOffset = 0;
  String downloadQuery = '';
  List<double> columnWidths = downloadColumns.map((c) => c.width).toList();
  bool _layoutLoaded = false;
  String folder = '';
  String historyQuery = '';
  String message = '';
  final Set<int> selection = {};
  List<DownloadEntry> get selectedDownloads =>
      _downloadListing.selected(selection);
  final Map<String, bool> availability = {};
  Timer? _refreshTimer;
  bool _disposed = false;
  bool loaded = false;
  bool _loadError = false;
  int _generation = 0;
  late (int, bool, String) _lastLibraryData;
  (int, bool, String) get _libraryData =>
      (library.dataRevision, library.pauseMode, library.outputDirectory);

  void _changed() {
    final revision = _libraryData;
    if (revision == _lastLibraryData) return;
    _lastLibraryData = revision;
    _refreshTimer ??= Timer(const Duration(milliseconds: 400), () {
      _refreshTimer = null;
      unawaited(refresh());
    });
  }

  Future<void> refresh() async {
    final generation = ++_generation;
    try {
      final results = await Future.wait<Object?>([
        repository.summary(),
        _downloadListing.load(category,
            filter: filter,
            query: downloadQuery,
            pauseMode: library.pauseMode,
            sort: downloadSort,
            descending: downloadDescending,
            outputDirectory: library.outputDirectory),
        repository.history(
            folder: folder, query: historyQuery, offset: historyOffset),
        if (!_layoutLoaded) repository.columnWidths(),
      ]);
      if (_disposed || generation != _generation) return;
      if (!_layoutLoaded && results.length > 3) {
        columnWidths = results[3] as List<double>;
        _layoutLoaded = true;
      }
      summary = results[0] as ActivitySummary;
      loaded = true;
      final downloadPage = results[1] as DownloadPage?;
      if (downloadPage == null) return;
      downloads = downloadPage;
      if (_loadError) {
        message = '';
        _loadError = false;
      }
      history = results[2] as HistoryPage;
      final visibleIds = downloads.items.map((e) => e.track.id).toSet();
      selection.removeWhere((id) => !visibleIds.contains(id));
      notifyListeners();
      final entries = history.files;
      final states = await Future.wait(entries.map((entry) async =>
          MapEntry(entry.path, await library.files.fileExists(entry.path))));
      if (_disposed || generation != _generation) return;
      availability.clear();
      availability.addEntries(states);
      notifyListeners();
    } catch (error) {
      if (_disposed || generation != _generation) return;
      message = operationMessage(error);
      _loadError = true;
      loaded = true;
      notifyListeners();
    }
  }

  Future<void> sortDownloads(DownloadSort value) async {
    downloadDescending = downloadSort == value
        ? !downloadDescending
        : value == DownloadSort.downloadedAt;
    downloadSort = value;
    selection.clear();
    await refresh();
  }

  void acknowledgeMessage(String value) {
    if (message != value) return;
    message = '';
    notifyListeners();
  }

  void resizeColumn(int index, double width) {
    columnWidths = [...columnWidths]..[index] =
        boundedColumnWidth(index, width);
    notifyListeners();
  }

  void resizeColumns(List<double> widths) {
    if (widths.length != downloadColumns.length) {
      throw ArgumentError('Quantidade de colunas inválida.');
    }
    columnWidths = [
      downloadColumns.first.width,
      for (var i = 1; i < widths.length; i++) boundedColumnWidth(i, widths[i])
    ];
    notifyListeners();
  }

  Future<void> saveColumnWidths() async {
    try {
      await repository.saveColumnWidths([...columnWidths]);
    } catch (_) {
      message = 'Não foi possível salvar a largura das colunas.';
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> resetColumnWidths() async {
    columnWidths = downloadColumns.map((c) => c.width).toList();
    notifyListeners();
    await saveColumnWidths();
  }

  Future<void> resetDownloadTable() async {
    message = '';
    downloadSort = null;
    downloadDescending = false;
    downloadQuery = '';
    filter = DownloadFilter.all;
    selection.clear();
    tableRevision++;
    columnWidths = downloadColumns.map((c) => c.width).toList();
    notifyListeners();
    await saveColumnWidths();
    await refresh();
  }

  Future<void> searchDownloads(String value) async {
    if (value.length > 200) return;
    downloadQuery = value.trim();
    selection.clear();
    await refresh();
  }

  Future<void> setCategory(ContentCategory value) async {
    category = value;
    selection.clear();
    await refresh();
  }

  Future<void> setFilter(DownloadFilter value) async {
    filter = value;
    selection.clear();
    await refresh();
  }

  void select(int id, bool value) {
    value ? selection.add(id) : selection.remove(id);
    notifyListeners();
  }

  void selectMany(List<int> ids) {
    selection.addAll(ids);
    notifyListeners();
  }

  void selectFiltered(bool value) {
    for (final item in downloads.items) {
      value ? selection.add(item.track.id) : selection.remove(item.track.id);
    }
    notifyListeners();
  }

  Future<void> checkVisibleDownloads(List<int> ids) async {
    final changed = await _downloadListing.checkVisible(ids);
    if (_disposed || !changed) return;
    downloads = _downloadListing.updated(downloads);
    notifyListeners();
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
    final ids = selection.toList();
    for (var start = 0; start < ids.length; start += 1000) {
      await repository.removeDownloads(ids.skip(start).take(1000).toList());
    }
    selection.clear();
    await refresh();
  }

  Future<void> start({bool failedOnly = false}) async {
    if (selection.length > 10000) {
      message = 'Selecione até 10.000 faixas por execução.';
      notifyListeners();
      return;
    }
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
    _downloadListing.clear();
    library.removeListener(_changed);
    super.dispose();
  }
}

import '../../library/domain/models.dart';

enum AppSection { home, music, media, files, settings }

enum ContentCategory { music, media }

enum DownloadFilter { all, downloading, queued, paused, completed, failed }

class DownloadEntry {
  const DownloadEntry(this.track, this.collectionName);
  final Track track;
  final String collectionName;
  String get statusLabel => switch (track.status) {
        TrackStatus.pending => 'Aguardando fonte',
        TrackStatus.ready => track.canDownload ? 'Na fila' : 'Conferir fonte',
        TrackStatus.downloading => 'Baixando / processando',
        TrackStatus.completed => 'Concluído',
        TrackStatus.failed => 'Erro',
      };
}

class DownloadPage {
  const DownloadPage(this.items, this.total);
  final List<DownloadEntry> items;
  final int total;
}

class HistoryEntry {
  const HistoryEntry(
      {required this.id,
      required this.name,
      required this.path,
      required this.folder,
      required this.source,
      this.durationMs});
  final int id;
  final String name;
  final String path;
  final String folder;
  final String source;
  final int? durationMs;
}

class HistoryFolder {
  const HistoryFolder(this.path, this.count);
  final String path;
  final int count;
}

class HistoryPage {
  const HistoryPage(this.folders, this.files, this.total);
  final List<HistoryFolder> folders;
  final List<HistoryEntry> files;
  final int total;
}

class ActivitySummary {
  const ActivitySummary(
      {this.active = 0,
      this.records = 0,
      this.completed = 0,
      this.queued = 0,
      this.recent = const []});
  final int active;
  final int records;
  final int completed;
  final int queued;
  final List<HistoryEntry> recent;
}

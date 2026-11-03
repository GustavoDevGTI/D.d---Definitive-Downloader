class DownloadColumn {
  const DownloadColumn(this.key, this.label, this.width, this.minimum);
  final String key, label;
  final double width, minimum;
}

const downloadColumns = [
  DownloadColumn('selection', '', 40, 40),
  DownloadColumn('name', 'Nome', 200, 64),
  DownloadColumn('size', 'Tamanho', 74, 40),
  DownloadColumn('provider', 'Servidor', 88, 48),
  DownloadColumn('status', 'Status', 96, 48),
  DownloadColumn('speed', 'Velocidade', 88, 40),
  DownloadColumn('remaining', 'Tempo restante', 100, 48),
  DownloadColumn('received', 'Recebido', 80, 40),
  DownloadColumn('progress', 'Progresso', 92, 48),
  DownloadColumn('downloadedAt', 'Baixado em', 150, 64),
  DownloadColumn('destination', 'Salvar em', 230, 64),
];

double boundedColumnWidth(int index, double value) {
  if (index < 1 || index >= downloadColumns.length || !value.isFinite) {
    throw ArgumentError('Largura de coluna inválida.');
  }
  return value.clamp(downloadColumns[index].minimum, 1200).toDouble();
}

// Sorting changes only the paginated view, never occurrence or queue priority.
enum DownloadSort {
  name(1),
  provider(3),
  status(4),
  downloadedAt(9),
  destination(10);

  const DownloadSort(this.column);
  final int column;
  static DownloadSort? forColumn(int column) {
    for (final sort in values) {
      if (sort.column == column) return sort;
    }
    return null;
  }
}

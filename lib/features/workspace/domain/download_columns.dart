class DownloadColumn {
  const DownloadColumn(this.key, this.label, this.width, this.minimum);
  final String key, label;
  final double width, minimum;
}

const downloadColumns = [
  DownloadColumn('selection', '', 40, 40),
  DownloadColumn('name', 'Nome', 300, 64),
  DownloadColumn('size', 'Tamanho', 80, 40),
  DownloadColumn('provider', 'Servidor', 120, 48),
  DownloadColumn('status', 'Status', 150, 48),
  DownloadColumn('speed', 'Velocidade', 90, 40),
  DownloadColumn('remaining', 'Tempo restante', 110, 48),
  DownloadColumn('received', 'Baixado', 90, 40),
  DownloadColumn('progress', 'Progresso', 120, 48),
  DownloadColumn('destination', 'Salvar em', 230, 64),
];

double boundedColumnWidth(int index, double value) {
  if (index < 1 || index >= downloadColumns.length || !value.isFinite) {
    throw ArgumentError('Largura de coluna inválida.');
  }
  return value.clamp(downloadColumns[index].minimum, 1200).toDouble();
}

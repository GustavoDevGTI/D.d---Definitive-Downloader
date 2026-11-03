class DownloadColumn {
  const DownloadColumn(this.key, this.label, this.width, this.minimum);
  final String key, label;
  final double width, minimum;
}

const downloadColumns = [
  DownloadColumn('selection', '', 40, 40),
  DownloadColumn('name', 'Nome', 300, 140),
  DownloadColumn('size', 'Tamanho', 80, 70),
  DownloadColumn('provider', 'Servidor', 120, 90),
  DownloadColumn('status', 'Status', 150, 100),
  DownloadColumn('speed', 'Velocidade', 90, 80),
  DownloadColumn('remaining', 'Tempo restante', 110, 100),
  DownloadColumn('received', 'Baixado', 90, 75),
  DownloadColumn('progress', 'Progresso', 120, 90),
  DownloadColumn('destination', 'Salvar em', 230, 140),
];

double boundedColumnWidth(int index, double value) {
  if (index < 1 || index >= downloadColumns.length || !value.isFinite) {
    throw ArgumentError('Largura de coluna inválida.');
  }
  return value.clamp(downloadColumns[index].minimum, 1200).toDouble();
}

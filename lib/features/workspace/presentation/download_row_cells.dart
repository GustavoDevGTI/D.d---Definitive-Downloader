import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../../../app/theme.dart';
import '../../library/domain/models.dart';
import '../../downloads/transfer_progress.dart';
import '../domain/workspace_models.dart';
import '../../../core/platform/platform_services.dart';

List<Widget> downloadRowCells(
    {required DownloadEntry entry,
    required bool selected,
    required void Function(int, bool) onSelect,
    required bool paused,
    required int? activeId,
    required double? progress,
    required TransferProgress? live,
    required String output}) {
  final e = entry, t = entry.track;
  return [
    Checkbox(
        shape: const CircleBorder(),
        semanticLabel: 'Selecionar download ${t.title}',
        value: selected,
        onChanged: (v) => onSelect(t.id, v ?? false)),
    Tooltip(
        message:
            '${t.downloadName} · ${e.collectionName}${t.localPath.isEmpty ? '' : '\n${createPlatformFiles().displayPath(t.localPath)}'}',
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12)),
              if (t.downloadArtist.isNotEmpty)
                Text(t.downloadArtist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(fontSize: 11, color: AppColors.muted)),
            ])),
    _metric(
        e.fileBytes != null
            ? _bytes(e.fileBytes!)
            : live?.total == null
                ? '—'
                : '${live!.estimatedTotal ? '≈ ' : ''}${_bytes(live.total!)}',
        e.fileBytes != null
            ? 'Tamanho do arquivo salvo.'
            : 'Tamanho da transferência; ≈ indica estimativa.'),
    Tooltip(
        message: t.sourceKind.musicProviderName ?? t.sourceLabel,
        child: Text(t.sourceKind.musicProviderName ?? t.sourceLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12))),
    Tooltip(
        message: t.error.isEmpty ? e.statusLabel : t.error,
        child: Text(
            t.id == activeId && paused ? 'Pausado · 10 KiB/s' : e.statusLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12))),
    _metric(
        live?.bytesPerSecond == null || paused || live!.processing
            ? '—'
            : '${_bytes(live.bytesPerSecond!.round())}/s',
        'Velocidade medida nesta transferência.'),
    _metric(
        live?.processing == true
            ? 'Processando'
            : paused || live?.remaining == null
                ? '—'
                : _remaining(live!.remaining!),
        'Estimativa para receber o áudio; validação e capa acontecem depois.'),
    _metric(
        live != null
            ? _bytes(live.received)
            : e.fileBytes != null
                ? _bytes(e.fileBytes!)
                : '—',
        live != null
            ? 'Dados de áudio recebidos nesta tentativa.'
            : 'Dados no arquivo final salvo; podem diferir da transferência original.'),
    t.status == TrackStatus.completed
        ? const Text('Concluído',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12))
        : t.id == activeId
            ? LinearProgressIndicator(value: progress, minHeight: 6)
            : const Text('—'),
    Tooltip(
        message: e.downloadedAt == null
            ? 'Sem registro de conclusão.'
            : 'Concluído em ${_completionLabel(e.downloadedAt!)} (horário local)',
        child: Text(
            e.downloadedAt == null ? '—' : _completionLabel(e.downloadedAt!),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12))),
    Tooltip(
        message: createPlatformFiles()
            .displayPath(t.localPath.isEmpty ? output : p.dirname(t.localPath)),
        child: Text(
            createPlatformFiles().displayPath(
                t.localPath.isEmpty ? output : p.dirname(t.localPath)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12))),
  ];
}

String _completionLabel(DateTime date) {
  final local = date.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
}

Widget _metric(String text, String description) => Tooltip(
    message: '$text · $description',
    child: Text(text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12)));

String _bytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KiB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MiB';
}

String _remaining(Duration duration) {
  final seconds = duration.inSeconds;
  if (seconds < 60) return '${seconds}s';
  if (seconds < 3600) return '${seconds ~/ 60}min ${seconds % 60}s';
  return '${seconds ~/ 3600}h ${(seconds % 3600) ~/ 60}min';
}

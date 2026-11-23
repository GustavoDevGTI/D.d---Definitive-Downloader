import 'package:flutter/material.dart';
import '../../../app/app_notice.dart';
import '../../../app/theme.dart';
import '../../library/application/library_controller.dart';
import '../../library/domain/models.dart';
import '../../workspace/presentation/download_action_button.dart';
import '../../workspace/presentation/link_entry_panel.dart';
import '../application/audio_capture_controller.dart';

class AudioCapturePanel extends StatefulWidget {
  const AudioCapturePanel({super.key, required this.library, this.onDownloads});
  final LibraryController library;
  final VoidCallback? onDownloads;
  @override
  State<AudioCapturePanel> createState() => _AudioCapturePanelState();
}

class _AudioCapturePanelState extends State<AudioCapturePanel> {
  final _url = TextEditingController();
  late final _controller = AudioCaptureController(widget.library);

  @override
  void dispose() {
    _controller.dispose();
    _url.dispose();
    super.dispose();
  }

  Future<void> _analyze() async {
    await _controller.analyze(_url.text);
    if (mounted &&
        _controller.message.isNotEmpty &&
        _controller.message != 'Análise cancelada.') {
      await showAppNotice(context, message: _controller.message);
    }
  }

  Future<void> _download() async {
    final added = await _controller.download();
    if (!mounted) return;
    if (added) {
      widget.onDownloads?.call();
    } else if (_controller.message.isNotEmpty) {
      await showAppNotice(context, message: _controller.message);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: Listenable.merge([_controller, widget.library]),
      builder: (context, _) {
        final c = _controller;
        final result = c.result;
        return ListView(primary: false, padding: EdgeInsets.zero, children: [
          LinkEntryPanel(
              title: 'Capturar áudio',
              fieldLabel: 'Endereço da página ou mídia',
              hintText: 'Cole o link',
              controller: _url,
              inputKey: const ValueKey('capture-url-music'),
              actionKey: const ValueKey('capture-analyze-music'),
              enabled: !c.busy,
              onChanged: (_) => c.clearResult(),
              onSubmitted: c.busy ? null : (_) => _analyze(),
              actionLabel: c.analyzing ? 'Analisando…' : 'Analisar link',
              actionIcon: Icons.search,
              onAction: c.available && !c.busy ? _analyze : null,
              secondaryActions: [
                if (c.analyzing)
                  TextButton(
                      onPressed: c.cancel,
                      child: const Text('Cancelar análise')),
              ],
              status: c.available
                  ? null
                  : 'O motor de áudio não está disponível neste dispositivo.'),
          if (c.analyzing) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            Text(c.stage, style: const TextStyle(color: AppColors.muted)),
          ],
          if (result != null) ...[
            const SizedBox(height: 20),
            Text(result.title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Checkbox(
                        semanticLabel: 'Selecionar todos os áudios',
                        value: c.selected.length == result.items.length
                            ? true
                            : c.selected.isEmpty
                                ? false
                                : null,
                        tristate: true,
                        onChanged: c.busy
                            ? null
                            : (_) => c.selectAll(
                                c.selected.length != result.items.length)),
                    Flexible(
                        child: Text(
                            '${c.selected.length} de ${result.items.length} selecionados')),
                  ]),
                  FilledButton.icon(
                      key: const ValueKey('capture-download-selected'),
                      onPressed:
                          c.busy || widget.library.busy || c.selected.isEmpty
                              ? null
                              : _download,
                      style: FilledButton.styleFrom(
                          backgroundColor: DownloadActionColors.start,
                          foregroundColor: Colors.white,
                          visualDensity: VisualDensity.standard,
                          minimumSize: Size(0, AppDensity.of(context).control)),
                      icon: const Icon(Icons.download_rounded, size: 20),
                      label: const Text('Baixar MP3')),
                ]),
            if (result.truncated)
              const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                      'A página tem mais itens. Use um link específico para capturar os demais.',
                      style: TextStyle(color: AppColors.muted))),
            if (result.unavailableCount > 0)
              Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                      '${result.unavailableCount} conteúdos não puderam ser capturados.',
                      style: const TextStyle(color: AppColors.muted))),
            const SizedBox(height: 12),
            for (final item in result.items) ...[
              const Divider(height: 1),
              ListTile(
                  key: ValueKey('captured-audio-${item.sourceId}'),
                  contentPadding: EdgeInsets.zero,
                  leading: Checkbox(
                      semanticLabel: 'Selecionar ${item.title}',
                      value: c.selected.contains(item.sourceId),
                      onChanged: c.busy
                          ? null
                          : (value) => c.select(item.sourceId, value ?? false)),
                  title: Text(item.title,
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Tooltip(
                      message: item.pageUrl,
                      child: Text([
                        if (item.artist.isNotEmpty) item.artist,
                        Uri.parse(item.pageUrl).host,
                        if (item.durationMs > 0)
                          formatDuration(item.durationMs),
                      ].join(' · '))),
                  onTap: c.busy
                      ? null
                      : () => c.select(
                          item.sourceId, !c.selected.contains(item.sourceId))),
            ],
          ],
        ]);
      });
}

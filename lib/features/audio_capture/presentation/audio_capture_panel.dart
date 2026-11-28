import 'dart:async';
import 'package:flutter/material.dart';
import '../../../app/app_notice.dart';
import '../../../app/theme.dart';
import '../../library/application/library_controller.dart';
import '../../library/domain/models.dart';
import '../../library/presentation/playlist_destination.dart';
import '../../library/presentation/playlist_picker_dialog.dart';
import '../../workspace/presentation/download_action_button.dart';
import '../../workspace/presentation/link_entry_panel.dart';
import '../../workspace/presentation/workspace_components.dart';
import '../application/audio_capture_controller.dart';
import '../domain/audio_capture.dart';
import '../application/status_saver_controller.dart';
import 'capture_login_dialog.dart';
import 'status_saver_result.dart';

class AudioCapturePanel extends StatefulWidget {
  const AudioCapturePanel(
      {super.key, required this.library, this.onDownloads, this.onOpen});
  final LibraryController library;
  final VoidCallback? onDownloads;

  /// Opens a playlist created or changed from this page.
  final ValueChanged<Collection>? onOpen;
  @override
  State<AudioCapturePanel> createState() => _AudioCapturePanelState();
}

class _AudioCapturePanelState extends State<AudioCapturePanel> {
  final _url = TextEditingController();
  late final _controller = AudioCaptureController(widget.library)
    ..requestLogin = (platform, verify) async =>
        mounted ? showCaptureLogin(context, platform, verify) : null;

  late final _statuses = StatusSaverController(widget.library);

  @override
  void initState() {
    super.initState();
    unawaited(_controller.loadSessions());
  }

  @override
  void dispose() {
    _statuses.dispose();
    _controller.dispose();
    _url.dispose();
    super.dispose();
  }

  Future<void> _notice() async {
    if (mounted && _controller.message.isNotEmpty) {
      await showAppNotice(context, message: _controller.message);
    }
  }

  Future<void> _analyze() async {
    await _controller.analyze(_url.text);
    if (_controller.message != 'Análise cancelada.') await _notice();
  }

  Future<void> _download() async {
    final added = await _controller.download();
    if (!mounted) return;
    if (added) {
      widget.onDownloads?.call();
    } else {
      await _notice();
    }
  }

  Future<void> _saveAsPlaylist() async {
    final saved = await _controller.saveAsPlaylist();
    await _notice();
    if (saved != null && mounted) widget.onOpen?.call(saved);
  }

  Future<void> _addToPlaylist() async {
    final playlist = await pickPlaylist(context,
        title: 'Adicionar a playlist', search: widget.library.searchPlaylists);
    if (playlist == null || !mounted) return;
    await _controller.addToPlaylist(playlist);
    await _notice();
  }

  Future<void> _pickStatuses() async {
    await _statuses.pick();
    if (mounted && _statuses.message.isNotEmpty) {
      await showAppNotice(context, message: _statuses.message);
    }
  }

  Future<void> _saveStatuses() async {
    final saved = await _statuses.save();
    if (!mounted) return;
    if (_statuses.message.isNotEmpty) {
      await showAppNotice(context, message: _statuses.message);
    }
    if (saved != null && mounted) widget.onOpen?.call(saved);
  }

  void _discard() {
    _controller.clearResult();
    _url.clear();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: Listenable.merge([_controller, _statuses, widget.library]),
      builder: (context, _) {
        final c = _controller;
        final result = c.result;
        return ListView(primary: false, padding: EdgeInsets.zero, children: [
          LinkEntryPanel(
              title: 'Capturar áudio',
              fieldLabel: 'Endereço da página ou mídia',
              hintText: '',
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
                // Status Saver: WhatsApp keeps statuses only on Android.
                if (_statuses.available)
                  OutlinedButton.icon(
                      key: const ValueKey('status-saver-pick'),
                      onPressed: c.busy || _statuses.busy || widget.library.busy
                          ? null
                          : () => unawaited(_pickStatuses()),
                      icon: const Icon(Icons.history_toggle_off_rounded,
                          size: 18),
                      label: Text(_statuses.picking
                          ? 'Lendo status…'
                          : 'Status do WhatsApp')),
                if (!c.busy)
                  for (final platform in c.signedIn)
                    TextButton.icon(
                        key: ValueKey('capture-sign-out-${platform.name}'),
                        onPressed: () async {
                          await c.signOut(platform);
                          await _notice();
                        },
                        icon: const Icon(Icons.logout_rounded, size: 18),
                        label: Text('Sair do ${platform.label}')),
              ],
              busy: c.analyzing,
              busyLabel: c.analyzing ? c.stage : null,
              status: c.available
                  ? null
                  : 'O motor de áudio não está disponível neste dispositivo.'),
          if (_statuses.hasStatuses) ...[
            const SizedBox(height: 20),
            StatusSaverResult(
                controller: _statuses,
                onSave: () => unawaited(_saveStatuses())),
          ],
          if (result != null) ...[
            const SizedBox(height: 20),
            _CaptureResult(
                controller: c,
                library: widget.library,
                result: result,
                onDownload: () => unawaited(_download()),
                onSave: () => unawaited(_saveAsPlaylist()),
                onAdd: () => unawaited(_addToPlaylist()),
                onDiscard: _discard),
          ],
        ]);
      });
}

class _CaptureResult extends StatelessWidget {
  const _CaptureResult(
      {required this.controller,
      required this.library,
      required this.result,
      required this.onDownload,
      required this.onSave,
      required this.onAdd,
      required this.onDiscard});
  final AudioCaptureController controller;
  final LibraryController library;
  final AudioCaptureResult result;
  final VoidCallback onDownload, onSave, onAdd, onDiscard;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final density = AppDensity.of(context);
    final count = result.items.length;
    final selected = c.selected.length;
    final idle = !c.busy && !library.busy;
    final canAct = idle && selected > 0;
    final hosts = result.items
        .map((item) => Uri.tryParse(item.pageUrl)?.host ?? '')
        .where((host) => host.isNotEmpty)
        .toSet();
    final summary = [
      count == 1 ? '1 áudio' : '$count áudios',
      if (hosts.length == 1) hosts.single,
      if (result.durationMs > 0) formatDuration(result.durationMs),
    ].join(' · ');
    final buttonSize = Size(0, density.control);
    return WorkspacePanel(
        key: const ValueKey('capture-result'),
        padding: EdgeInsets.all(density.panelInset),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: AppColors.accentSoft,
                    borderRadius: BorderRadius.circular(density.radius)),
                child: const Icon(Icons.graphic_eq_rounded,
                    color: AppColors.accent)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(result.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(summary,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.muted)),
                ])),
            IconButton(
                key: const ValueKey('capture-discard'),
                tooltip: 'Descartar análise',
                onPressed: c.busy ? null : onDiscard,
                icon: const Icon(Icons.close, color: AppColors.secondary)),
          ]),
          const SizedBox(height: 14),
          DestinationRow(
              path: library.displayPath(c.destinationPreview),
              custom: c.destinationRoot.isNotEmpty,
              enabled: !c.busy,
              onChange: () => unawaited(c.pickDestination()),
              onReset: c.useDefaultDestination),
          const SizedBox(height: 12),
          Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.icon(
                    key: const ValueKey('capture-download-selected'),
                    onPressed: canAct ? onDownload : null,
                    style: FilledButton.styleFrom(
                        backgroundColor: DownloadActionColors.start,
                        foregroundColor: Colors.white,
                        visualDensity: VisualDensity.standard,
                        minimumSize: buttonSize),
                    icon: const Icon(Icons.download_rounded, size: 20),
                    label: Text(selected > 1
                        ? 'Baixar $selected em MP3'
                        : 'Baixar MP3')),
                OutlinedButton.icon(
                    key: const ValueKey('capture-save-playlist'),
                    onPressed: canAct ? onSave : null,
                    style: OutlinedButton.styleFrom(minimumSize: buttonSize),
                    icon: const Icon(Icons.playlist_add_rounded, size: 20),
                    label: const Text('Salvar como playlist')),
                OutlinedButton.icon(
                    key: const ValueKey('capture-add-playlist'),
                    onPressed: canAct ? onAdd : null,
                    style: OutlinedButton.styleFrom(minimumSize: buttonSize),
                    icon: const Icon(Icons.queue_music_rounded, size: 20),
                    label: const Text('Adicionar a playlist')),
                TextButton.icon(
                    key: const ValueKey('capture-discard-selected'),
                    onPressed: canAct ? c.discardSelected : null,
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.accentActive,
                        minimumSize: buttonSize),
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    label: const Text('Descartar selecionados')),
              ]),
          if (c.submitting) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(
                minHeight: 3,
                color: AppColors.accent,
                backgroundColor: AppColors.accentSoft),
          ],
          if (result.truncated || result.unavailableCount > 0) ...[
            const SizedBox(height: 10),
            Text(
                [
                  if (result.truncated)
                    'A página tem mais itens. Use um link específico para capturar os demais.',
                  if (result.unavailableCount > 0)
                    '${result.unavailableCount} conteúdos não puderam ser capturados.',
                ].join(' '),
                style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ],
          const SizedBox(height: 12),
          const Divider(height: 1),
          Row(children: [
            Checkbox(
                semanticLabel: 'Selecionar todos os áudios',
                value: selected == count
                    ? true
                    : selected == 0
                        ? false
                        : null,
                tristate: true,
                onChanged:
                    c.busy ? null : (_) => c.selectAll(selected != count)),
            Flexible(
                child: Text('$selected de $count selecionados',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(fontSize: 12, color: AppColors.muted))),
          ]),
          for (var i = 0; i < count; i++)
            _CaptureRow(
                index: i,
                item: result.items[i],
                controller: c,
                library: library),
        ]));
  }
}

class _CaptureRow extends StatelessWidget {
  const _CaptureRow(
      {required this.index,
      required this.item,
      required this.controller,
      required this.library});
  final int index;
  final Candidate item;
  final AudioCaptureController controller;
  final LibraryController library;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final checked = c.selected.contains(item.sourceId);
    final details = [
      if (item.artist.isNotEmpty) item.artist,
      Uri.parse(item.pageUrl).host,
      if (item.durationMs > 0) formatDuration(item.durationMs),
    ].join(' · ');
    // As in the playlists, only the checkbox changes the selection.
    return DecoratedBox(
        key: ValueKey('captured-audio-${item.sourceId}'),
        decoration: BoxDecoration(
            color: checked ? AppColors.accentSoft.withValues(alpha: .55) : null,
            border: const Border(top: BorderSide(color: AppColors.line))),
        child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Checkbox(
                  semanticLabel: 'Selecionar ${item.title}',
                  value: checked,
                  onChanged: c.busy
                      ? null
                      : (value) => c.select(item.sourceId, value ?? false)),
              SizedBox(
                  width: 28,
                  child: Text('${index + 1}'.padLeft(2, '0'),
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                          fontFeatures: [FontFeature.tabularFigures()]))),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Tooltip(
                        message: item.pageUrl,
                        child: Text(details,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.muted))),
                  ])),
              if (Uri.parse(item.pageUrl).scheme == 'https')
                IconButton(
                    tooltip: 'Abrir página',
                    onPressed: () =>
                        unawaited(library.openPage(Uri.parse(item.pageUrl))),
                    icon: const Icon(Icons.open_in_new_rounded,
                        size: 18, color: AppColors.secondary)),
              IconButton(
                  key: ValueKey('captured-discard-${item.sourceId}'),
                  tooltip: 'Descartar',
                  onPressed: c.busy ? null : () => c.discard(item.sourceId),
                  icon: const Icon(Icons.close_rounded,
                      size: 18, color: AppColors.secondary)),
            ])));
  }
}

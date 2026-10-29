import 'dart:async';
import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../application/library_controller.dart';
import '../domain/models.dart';
import '../../workspace/presentation/workspace_components.dart';
import 'manual_source_input.dart';

class TrackInspector extends StatefulWidget {
  const TrackInspector({super.key, required this.controller});
  final LibraryController controller;
  @override
  State<TrackInspector> createState() => _TrackInspectorState();
}

class _TrackInspectorState extends State<TrackInspector> {
  final _query = TextEditingController();
  int? _trackId;
  Candidate? _candidate;
  int _tab = 0;
  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller, t = c.focused;
    if (_trackId != t?.id) {
      _trackId = t?.id;
      _candidate = null;
      _tab = 0;
      _query.text = t == null ? '' : '${t.artist} ${t.title}';
    }
    return Material(
        color: Colors.white,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              child: Row(children: [
                const Expanded(
                    child: Text('Conferência',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600))),
                if (Navigator.of(context).canPop())
                  IconButton(
                      tooltip: 'Fechar conferência',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, size: 20)),
              ])),
          if (t == null)
            const Expanded(
                child: WorkspaceNotice(
                    title: 'Escolha uma faixa',
                    message:
                        'Clique na linha para comparar versões. O checkbox seleciona a faixa para download.'))
          else ...[
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: CategoryTabs(
                    labels: const ['Correspondência', 'Informações'],
                    selected: _tab,
                    onSelect: (v) => setState(() => _tab = v))),
            Expanded(
                child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.title,
                              style: const TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 5),
                          Text(t.artist,
                              style: const TextStyle(color: AppColors.muted)),
                          const SizedBox(height: 16),
                          _line(
                              'Duração esperada', formatDuration(t.durationMs)),
                          _line('Correspondência', t.matchStatus.label),
                          _line(
                              'Fonte identificada',
                              t.hasManualSource
                                  ? 'Escolha manual'
                                  : t.sourceLabel),
                          _line(
                              'Versão encontrada',
                              t.resolvedTitle.isEmpty
                                  ? 'Não informada'
                                  : t.resolvedTitle),
                          _line('Duração encontrada',
                              formatDuration(t.resolvedDurationMs)),
                          if (t.error.isNotEmpty)
                            Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Text(t.error,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF9C4141)))),
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 12),
                          if (_tab == 1) ...[
                            _line('Álbum original',
                                t.album.isEmpty ? 'Não informado' : t.album),
                            _line('ISRC',
                                t.isrc.isEmpty ? 'Não informado' : t.isrc),
                            _line('Coleção', c.current?.name ?? '—'),
                            _line('Plataforma original',
                                c.current?.source ?? '—'),
                            _line('Posição', t.position.toString()),
                            _line(
                                'Artista da fonte',
                                t.resolvedArtist.isEmpty
                                    ? 'Não informado'
                                    : t.resolvedArtist),
                            _line(
                                'Álbum da fonte',
                                t.resolvedAlbum.isEmpty
                                    ? 'Não informado'
                                    : t.resolvedAlbum),
                            _line(
                                'Download',
                                switch (t.status) {
                                  TrackStatus.pending => 'Pendente',
                                  TrackStatus.ready => 'Na fila',
                                  TrackStatus.downloading => 'Em andamento',
                                  TrackStatus.completed => 'Concluído',
                                  TrackStatus.failed => 'Erro',
                                }),
                            if (t.localPath.isNotEmpty)
                              _line('Último arquivo', t.localPath),
                            if (t.hasManualSource)
                              _line('Link manual', t.manualUrl),
                          ] else ...[
                            if (t.hasManualSource) ...[
                              const Text('Fonte manual prioritária',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              SelectableText(t.manualUrl,
                                  style: const TextStyle(fontSize: 12)),
                              const SizedBox(height: 8),
                              Text(
                                  t.manualMode == ManualSourceMode.extractAudio
                                      ? 'Vínculo salvo. A extração desta página ainda não está disponível.'
                                      : 'MP3 direto. O conteúdo será validado durante a transferência.',
                                  style: const TextStyle(
                                      fontSize: 12, height: 1.6)),
                              TextButton.icon(
                                  onPressed: c.busy ? null : _manual,
                                  icon:
                                      const Icon(Icons.edit_outlined, size: 16),
                                  label: const Text('Editar link manual')),
                              TextButton(
                                  onPressed: c.busy
                                      ? null
                                      : () => unawaited(c.removeManualSource()),
                                  child: const Text('Remover vínculo manual')),
                            ] else ...[
                              TextField(
                                  controller: _query,
                                  decoration: const InputDecoration(
                                      labelText: 'Buscar outras versões'),
                                  onSubmitted: c.searching || c.busy
                                      ? null
                                      : (v) => unawaited(c.search(v))),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                  onPressed: c.searching ||
                                          c.busy ||
                                          c.isExample ||
                                          (c.music != null &&
                                              !c.music!.available)
                                      ? null
                                      : () => unawaited(c.search(_query.text)),
                                  icon: const Icon(Icons.search, size: 16),
                                  label: Text(c.searching
                                      ? 'Pesquisando…'
                                      : 'Pesquisar faixas')),
                              const SizedBox(height: 8),
                              const Text(
                                  'A busca automática exclui videoclipes.',
                                  style: TextStyle(
                                      fontSize: 11, color: AppColors.muted)),
                              RadioGroup<Candidate>(
                                  groupValue: _candidate,
                                  onChanged: (value) =>
                                      setState(() => _candidate = value),
                                  child: Column(children: [
                                    for (final candidate in c.candidates)
                                      _option(candidate)
                                  ])),
                              const SizedBox(height: 12),
                              OutlinedButton(
                                  onPressed: c.busy ||
                                          (_candidate == null &&
                                              t.sourceKind ==
                                                  SourceKind.none) ||
                                          (_candidate != null &&
                                              c.music != null &&
                                              !c.music!.canUse(_candidate!))
                                      ? null
                                      : () => unawaited(_confirm()),
                                  child:
                                      const Text('Confirmar correspondência')),
                              TextButton(
                                  onPressed:
                                      c.busy || t.sourceKind == SourceKind.none
                                          ? null
                                          : () => unawaited(c.reviewSource()),
                                  child: const Text('Marcar para revisão')),
                              TextButton.icon(
                                  onPressed: c.busy ? null : _manual,
                                  icon: const Icon(Icons.link, size: 16),
                                  label:
                                      const Text('Informar link manualmente')),
                            ],
                            const SizedBox(height: 8),
                            Tooltip(
                                message:
                                    'A reprodução de prévias ainda não está integrada.',
                                child: TextButton.icon(
                                    onPressed: null,
                                    icon: Icon(Icons.play_arrow, size: 17),
                                    label: Text('Ouvir prévia'))),
                            if (c.isExample)
                              const Text('Exemplo local com áudio sintético.',
                                  style: TextStyle(
                                      fontSize: 11, color: AppColors.muted)),
                          ],
                        ]))),
          ],
        ]));
  }

  Widget _line(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          flex: 5,
          child: Text(label,
              style: const TextStyle(fontSize: 11, color: AppColors.muted)),
        ),
        const SizedBox(width: 10),
        Expanded(
            flex: 6, child: Text(value, style: const TextStyle(fontSize: 12))),
      ]));
  Widget _option(Candidate candidate) {
    final assessment = widget.controller.assess(candidate);
    return RadioListTile<Candidate>(
        dense: true,
        contentPadding: EdgeInsets.zero,
        value: candidate,
        title: Text(candidate.title, style: const TextStyle(fontSize: 12)),
        subtitle: Text(
            '${candidate.artist}\n${candidate.kind.musicProviderName ?? 'Prévia Deezer'} · ${formatDuration(candidate.durationMs)}\n${assessment.needsReview ? assessment.reason : 'Correspondência provável'}',
            style: const TextStyle(fontSize: 11)));
  }

  Future<void> _confirm() async {
    if (_candidate case final candidate?) {
      if (widget.controller.music == null) {
        await widget.controller.usePreview(candidate);
      } else {
        await widget.controller.useMusicCandidate(candidate);
      }
    } else {
      await widget.controller.confirmSource();
    }
  }

  Future<void> _manual() async {
    final track = widget.controller.focused;
    if (track == null) return;
    final choice = await showDialog<ManualSourceChoice>(
        context: context, builder: (_) => ManualSourceInput(track: track));
    if (choice != null &&
        mounted &&
        widget.controller.focused?.id == track.id) {
      await widget.controller.setManualSource(choice.url, choice.mode);
    }
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../application/library_controller.dart';
import '../domain/models.dart';
import '../../workspace/presentation/workspace_components.dart';
import 'track_review_actions.dart';
import 'edit_track_dialog.dart';
import 'track_identity.dart';
import 'playlist_palette.dart';
import '../../player/presentation/listening_actions.dart';
import '../../audio_conversion/application/audio_conversion_controller.dart';
import '../../audio_conversion/presentation/audio_conversion_dialog.dart';

class TrackInspector extends StatefulWidget {
  const TrackInspector({super.key, required this.controller});
  final LibraryController controller;
  @override
  State<TrackInspector> createState() => _TrackInspectorState();
}

class _TrackInspectorState extends State<TrackInspector> {
  final _query = TextEditingController();
  int? _trackId;
  int _revision = -1;
  TrackStatus? _status;
  int _tab = 0;
  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller, t = c.focused;
    final rgb = c.current?.themeColor;
    final accent = rgb == null ? null : Color(0xFF000000 | rgb);
    final ink = playlistInk(accent);
    if (_trackId != t?.id ||
        _revision != c.inspectorRevision ||
        (_status != t?.status && t?.status == TrackStatus.completed)) {
      final openReview =
          _revision != c.inspectorRevision && c.inspectorReviewRequested;
      _trackId = t?.id;
      _revision = c.inspectorRevision;
      _tab = t?.status == TrackStatus.completed && !openReview ? 1 : 0;
      _query.text = t == null ? '' : '${t.artist} ${t.title}';
    }
    _status = t?.status;
    return Material(
        color: Colors.white,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _header(accent, hasTrack: t != null),
          if (t == null)
            const Expanded(child: Center(child: Text('Selecione uma faixa')))
          else ...[
            Expanded(
                child: SingleChildScrollView(
                    padding: EdgeInsets.all(AppDensity.of(context).panelInset),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TrackIdentity(track: t, accent: accent),
                          const SizedBox(height: 16),
                          _line(
                              'Duração esperada', formatDuration(t.durationMs)),
                          _line(
                              'Correspondência',
                              t.redownloadReview
                                  ? 'Escolher fonte novamente'
                                  : t.matchStatus.label,
                              emphasis: t.needsReview ? ink : null),
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
                            Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(top: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                    color: playlistReviewSurface(accent),
                                    borderRadius: BorderRadius.circular(8)),
                                child: Text(t.error,
                                    style:
                                        TextStyle(fontSize: 12, color: ink))),
                          const Divider(height: 24),
                          if (_tab == 1) ...[
                            Align(
                                alignment: Alignment.centerLeft,
                                child: ListeningActions(track: t, accent: ink)),
                            _line('Álbum original',
                                t.album.isEmpty ? 'Não informado' : t.album),
                            if (t.customTitle.isNotEmpty)
                              _line('Título de origem', t.title),
                            _line('ISRC',
                                t.isrc.isEmpty ? 'Não informado' : t.isrc),
                            _line('Coleção', c.current?.name ?? '—'),
                            _line('Plataforma original',
                                c.current?.source ?? '—'),
                            _line('Posição', t.position.toString()),
                            if (MediaQuery.sizeOf(context).width < 780)
                              TextButton.icon(
                                  style: TextButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(6))),
                                  onPressed:
                                      c.busy || c.current?.editingLocked == true
                                          ? null
                                          : () => unawaited(
                                              showEditTrack(context, c, t)),
                                  icon:
                                      const Icon(Icons.edit_outlined, size: 18),
                                  label: const Text('Editar faixa')),
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
                              _line('Último arquivo',
                                  c.files.displayPath(t.localPath)),
                            if (AudioConversionController.canOffer(t))
                              TextButton.icon(
                                  onPressed: c.busy
                                      ? null
                                      : () => unawaited(showAudioConversion(
                                          context, t, c.files)),
                                  icon: const Icon(Icons.transform, size: 18),
                                  label: const Text('Converter para MP3')),
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
                            ],
                            if (c.inspectorReviewRequested ||
                                ((!t.hasManualSource || t.redownloadReview) &&
                                    t.status != TrackStatus.completed)) ...[
                              TextField(
                                  controller: _query,
                                  decoration: InputDecoration(
                                      labelText: 'Buscar outras versões',
                                      suffixIcon: IconButton(
                                          tooltip: c.searching
                                              ? 'Pesquisando…'
                                              : 'Pesquisar faixas',
                                          onPressed: c.searching ||
                                                  c.busy ||
                                                  c.isExample ||
                                                  (c.music != null &&
                                                      !c.music!.available)
                                              ? null
                                              : () => unawaited(
                                                  c.search(_query.text)),
                                          icon:
                                              Icon(Icons.search, color: ink))),
                                  onSubmitted: c.searching || c.busy
                                      ? null
                                      : (v) => unawaited(c.search(v))),
                            ],
                            const SizedBox(height: 8),
                            Padding(
                                key: const ValueKey('conference-actions'),
                                padding: const EdgeInsets.all(4),
                                child: TrackReviewActions(
                                    controller: c, accent: ink)),
                            if (c.inspectorReviewRequested &&
                                (t.status == TrackStatus.completed ||
                                    (t.hasManualSource && !t.redownloadReview)))
                              for (final candidate in c.candidates)
                                _option(candidate, ink, readOnly: true)
                            else if ((!t.hasManualSource ||
                                    t.redownloadReview) &&
                                t.status != TrackStatus.completed)
                              RadioGroup<Candidate>(
                                  groupValue: c.selectedCandidate,
                                  onChanged: c.selectCandidate,
                                  child: Column(children: [
                                    for (final candidate in c.candidates)
                                      _option(candidate, ink)
                                  ])),
                            if (c.isExample)
                              const Text('Exemplo local com áudio sintético.',
                                  style: TextStyle(
                                      fontSize: 11, color: AppColors.muted)),
                          ],
                        ]))),
          ],
        ]));
  }

  Widget _header(Color? accent, {required bool hasTrack}) => DecoratedBox(
      key: const ValueKey('conference-header'),
      decoration: BoxDecoration(
          color: accent == null
              ? AppColors.surface
              : Color.alphaBlend(accent.withAlpha(24), Colors.white),
          border: const Border(bottom: BorderSide(color: AppColors.line))),
      child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: AppDensity.of(context).desktop ? 8 : 12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const Expanded(
                  child: Text('Conferência',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600))),
              if (Navigator.of(context).canPop())
                IconButton(
                    tooltip: 'Fechar conferência',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 20)),
            ]),
            if (hasTrack) ...[
              const SizedBox(height: 8),
              CategoryTabs(
                  labels: const ['Correspondência', 'Informações'],
                  selected: _tab,
                  accent: accent,
                  showDivider: false,
                  bottomSpacing: 0,
                  onSelect: (v) => setState(() => _tab = v)),
            ],
          ])));

  Widget _line(String label, String value, {Color? emphasis}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: LayoutBuilder(builder: (context, box) {
        final caption = Text(label,
            style: const TextStyle(fontSize: 11, color: AppColors.muted));
        final detail = Text(value,
            style: TextStyle(
                fontSize: 12,
                color: emphasis,
                fontWeight: emphasis == null ? null : FontWeight.w600));
        if (box.maxWidth < 340 &&
            MediaQuery.textScalerOf(context).scale(11) > 14) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                caption,
                const SizedBox(height: 3),
                detail,
              ]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: (box.maxWidth * .4).clamp(0, 140),
            child: caption,
          ),
          const SizedBox(width: 10),
          Expanded(child: detail),
        ]);
      }));
  Widget _option(Candidate candidate, Color ink, {bool readOnly = false}) {
    final assessment = widget.controller.assess(candidate);
    final title = Text(candidate.title, style: const TextStyle(fontSize: 12));
    final subtitle =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
          '${candidate.artist}\n${candidate.isVideoRecording ? 'Videoclipe · ' : ''}${candidate.kind.musicProviderName ?? 'Prévia Deezer'} · ${formatDuration(candidate.durationMs)}',
          style: const TextStyle(fontSize: 11)),
      Text(
          assessment.needsReview
              ? assessment.reason
              : 'Correspondência provável',
          style: TextStyle(
              fontSize: 11, color: assessment.needsReview ? ink : null)),
      ListeningActions(
          track: widget.controller.focused!, candidate: candidate, accent: ink),
    ]);
    if (readOnly) {
      return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: title,
          subtitle: subtitle);
    }
    return RadioListTile<Candidate>(
        dense: true,
        contentPadding: EdgeInsets.zero,
        value: candidate,
        activeColor: ink,
        selected: widget.controller.selectedCandidate == candidate,
        selectedTileColor: Color.alphaBlend(ink.withAlpha(16), Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: title,
        subtitle: subtitle);
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../application/library_controller.dart';
import '../domain/models.dart';

class TrackInspector extends StatefulWidget {
  const TrackInspector({super.key, required this.controller});
  final LibraryController controller;
  @override
  State<TrackInspector> createState() => _TrackInspectorState();
}

class _TrackInspectorState extends State<TrackInspector> {
  final _query = TextEditingController();
  int? _trackId;
  int? _candidateIndex;
  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final track = controller.focused;
    if (_trackId != track?.id) {
      _trackId = track?.id;
      _query.text = track == null ? '' : '${track.artist} ${track.title}';
      _candidateIndex = null;
    }
    return Container(
        decoration: const BoxDecoration(
            color: Color(0xFFFAFBFC),
            border: Border(left: BorderSide(color: AppColors.line))),
        child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 25, 24, 24),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.tune_outlined, size: 17, color: AppColors.accent),
                SizedBox(width: 9),
                Text('Conferência',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600))
              ]),
              const SizedBox(height: 26),
              if (track == null) ...[
                const Text('A faixa certa importa.',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        height: 1.5)),
                const SizedBox(height: 13),
                const Text(
                    'Escolha uma faixa da lista para comparar o título, o artista e a versão encontrada.',
                    style: TextStyle(
                        fontSize: 12, height: 1.9, color: AppColors.muted)),
                const SizedBox(height: 28),
                const Divider(),
                const SizedBox(height: 17),
                const Text(
                    'Cada fonte fica identificada.\nA ordem da sua lista é preservada.',
                    style: TextStyle(
                        fontSize: 11, height: 1.9, color: AppColors.muted)),
              ] else ...[
                if (controller.isExample)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 19),
                      child: Image.asset('assets/demo/cover.png',
                          width: 72,
                          height: 72,
                          filterQuality: FilterQuality.medium)),
                Text(track.title,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        height: 1.5)),
                const SizedBox(height: 7),
                Text(track.artist,
                    style:
                        const TextStyle(fontSize: 12, color: AppColors.muted)),
                const SizedBox(height: 17),
                _line('Posição', track.position.toString().padLeft(2, '0')),
                _line(
                    track.status == TrackStatus.completed
                        ? 'Baixado de'
                        : 'Fonte selecionada',
                    track.sourceKind.musicProviderName ?? track.sourceLabel),
                if (track.sourceKind.name == 'localExample')
                  const Padding(
                      padding: EdgeInsets.only(top: 7),
                      child: Text(
                          'Trecho sintético de 4 segundos, criado para testar o aplicativo.',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.muted,
                              height: 1.8))),
                if (track.error.isNotEmpty)
                  Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(track.error,
                          style: const TextStyle(
                              color: Color(0xFF9C4141),
                              fontSize: 11,
                              height: 1.6))),
                const SizedBox(height: 22),
                const Divider(),
                const SizedBox(height: 21),
                const Text('Procurar uma correspondência',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 11),
                TextField(
                    controller: _query,
                    style: const TextStyle(fontSize: 11),
                    decoration:
                        const InputDecoration(hintText: 'Artista e título'),
                    onSubmitted: (v) => unawaited(controller.search(v))),
                const SizedBox(height: 9),
                Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                        onPressed: controller.searching
                            ? null
                            : () => unawaited(controller.search(_query.text)),
                        icon: const Icon(Icons.search, size: 15),
                        label: Text(controller.searching
                            ? 'Pesquisando…'
                            : controller.music == null
                                ? 'Pesquisar na Deezer'
                                : 'Pesquisar faixas'))),
                const SizedBox(height: 10),
                Text(
                    controller.music == null
                        ? 'Catálogo e prévias. Não fornece a faixa completa.'
                        : 'Deezer e YouTube Music. Apenas faixas de áudio; videoclipes são bloqueados.',
                    style: const TextStyle(
                        fontSize: 10, height: 1.7, color: AppColors.muted)),
                if (controller.candidates.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  for (var i = 0; i < controller.candidates.length; i++)
                    _candidate(i),
                  const SizedBox(height: 12),
                  if (controller.music != null)
                    OutlinedButton(
                        onPressed: _candidateIndex == null ||
                                _candidateIndex! >=
                                    controller.candidates.length ||
                                controller.busy ||
                                !controller.music!.canUse(
                                    controller.candidates[_candidateIndex!])
                            ? null
                            : () => unawaited(controller.useMusicCandidate(
                                controller.candidates[_candidateIndex!])),
                        child: const Text('Vincular faixa escolhida'))
                  else
                    OutlinedButton(
                        onPressed: _candidateIndex == null ||
                                _candidateIndex! >=
                                    controller.candidates.length ||
                                controller.busy
                            ? null
                            : () => unawaited(controller.usePreview(
                                controller.candidates[_candidateIndex!])),
                        child: const Text('Vincular prévia selecionada')),
                ],
                const SizedBox(height: 18),
                if (controller.music == null)
                  TextButton.icon(
                      onPressed: () => unawaited(controller.searchYoutube()),
                      icon: const Icon(Icons.open_in_new, size: 14),
                      label: const Text('Pesquisar no YouTube Music')),
                const SizedBox(height: 2),
                TextButton.icon(
                    onPressed: controller.busy ? null : _linkMp3,
                    icon: const Icon(Icons.link, size: 15),
                    label: const Text('Vincular endereço de MP3')),
                const SizedBox(height: 7),
                const Text(
                    'Use um arquivo disponibilizado para download pela fonte.',
                    style: TextStyle(
                        fontSize: 10, color: AppColors.muted, height: 1.7)),
              ],
            ])));
  }

  Widget _line(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        SizedBox(
            width: 63,
            child: Text(label,
                style: const TextStyle(fontSize: 10, color: AppColors.muted))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 11))),
      ]));
  Widget _candidate(int index) {
    final c = widget.controller.candidates[index];
    final assessment = widget.controller.assess(c);
    final selected = _candidateIndex == index;
    return InkWell(
        onTap: () => setState(() => _candidateIndex = index),
        child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 7),
            decoration: BoxDecoration(
                color: selected ? const Color(0xFFEAF0F4) : Colors.transparent,
                border:
                    const Border(bottom: BorderSide(color: AppColors.line))),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.title,
                  maxLines: 2,
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600)),
              const SizedBox(height: 5),
              Text(c.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: AppColors.muted)),
              const SizedBox(height: 7),
              Text(
                  '${(assessment.score * 100).round()}% · ${c.kind.name == 'youtubeMusic' ? 'YouTube Music / áudio' : c.kind.name == 'deezerFull' ? 'Deezer / faixa' : 'prévia'}',
                  style: const TextStyle(fontSize: 9, color: AppColors.accent)),
              if (assessment.needsReview)
                Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(assessment.reason,
                        style: const TextStyle(
                            fontSize: 9, color: AppColors.muted))),
              if (c.kind.name == 'deezerFull' &&
                  widget.controller.music?.connection.connected != true)
                const Text(
                    'Conecte a Deezer em Conexões para baixar esta fonte.',
                    style: TextStyle(fontSize: 10)),
            ])));
  }

  Future<void> _linkMp3() async {
    final input = TextEditingController();
    final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
                title:
                    const Text('Vincular MP3', style: TextStyle(fontSize: 18)),
                content: SizedBox(
                    width: 470,
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                              'Cole o endereço direto do arquivo. Páginas de streaming não são links de MP3.',
                              style: TextStyle(fontSize: 12, height: 1.7)),
                          const SizedBox(height: 18),
                          TextField(
                              controller: input,
                              autofocus: true,
                              decoration: const InputDecoration(
                                  hintText: 'https://fonte.exemplo/faixa.mp3'),
                              onSubmitted: (v) => Navigator.pop(context, v)),
                        ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, input.text),
                      child: const Text('Vincular'))
                ]));
    // A dialog exit transition may still reference its text controller.
    if (result != null && result.trim().isNotEmpty) {
      await widget.controller.linkMp3(result);
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
    input.dispose();
  }
}

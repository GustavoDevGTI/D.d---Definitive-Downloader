import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../importing/collection_duplicates.dart';
import '../domain/models.dart';

Future<DuplicateDecision?> chooseDuplicateMusic(
        BuildContext context, DuplicateConflict conflict) =>
    showDialog<DuplicateDecision>(
        context: context,
        barrierDismissible: false,
        builder: (_) => DuplicateMusicDialog(conflict: conflict));

class DuplicateMusicDialog extends StatefulWidget {
  const DuplicateMusicDialog({super.key, required this.conflict});
  final DuplicateConflict conflict;
  @override
  State<DuplicateMusicDialog> createState() => _DuplicateMusicDialogState();
}

class _DuplicateMusicDialogState extends State<DuplicateMusicDialog> {
  DuplicateChoice? _choice;
  bool _all = false;
  @override
  Widget build(BuildContext context) {
    final c = widget.conflict;
    return AlertDialog(
      title: const Text('Música já presente'),
      content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                Text(
                    'Escolha qual versão permanece. Faixa ${c.inputPosition} de ${c.total}.',
                    style:
                        const TextStyle(fontSize: 12, color: AppColors.muted)),
                const SizedBox(height: 12),
                _option(
                    DuplicateChoice.existing,
                    c.existing.length == 1
                        ? 'Manter a existente'
                        : 'Manter as ${c.existing.length} existentes',
                    [
                      for (final v in c.existing.take(10))
                        _version(
                            v.track,
                            v.fromPlaylist
                                ? '${v.track.position}. Na playlist${v.track.status == TrackStatus.completed ? ' · Baixada' : ''}'
                                : 'Deste lote de links'),
                      if (c.existing.length > 10)
                        Text(
                            'E mais ${c.existing.length - 10} ocorrências existentes.',
                            style: const TextStyle(fontSize: 12)),
                    ]),
                const Divider(height: 24),
                _option(DuplicateChoice.incoming, 'Usar a nova versão', [
                  _version(
                      c.incoming.matchingTrack,
                      c.incoming.link.kind.name == 'mp3'
                          ? 'MP3 direto'
                          : 'Link recebido'),
                  if (c.incoming.source != null &&
                      c.incoming.source!.pageUrl != c.incoming.link.url)
                    Text(
                        'Fonte: ${c.incoming.source!.kind.musicProviderName ?? 'MP3 direto'}\n${c.incoming.source!.pageUrl}',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.muted)),
                ]),
                if (_choice == DuplicateChoice.incoming)
                  Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                          'As versões anteriores e seus arquivos, se baixados, serão excluídos. A nova entra no final.',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.accentActive))),
                const SizedBox(height: 8),
                CheckboxListTile(
                    key: const ValueKey('duplicates-all'),
                    value: _all,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text('Fazer para todos'),
                    onChanged: (v) => setState(() => _all = v ?? false)),
              ]))),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar adição')),
        FilledButton(
            key: const ValueKey('duplicates-confirm'),
            onPressed: _choice == null
                ? null
                : () => Navigator.pop(
                    context, DuplicateDecision(_choice!, forAll: _all)),
            child: const Text('Continuar')),
      ],
    );
  }

  Widget _option(DuplicateChoice choice, String title, List<Widget> details) =>
      Semantics(
          checked: _choice == choice,
          inMutuallyExclusiveGroup: true,
          label: title,
          child: InkWell(
              key: ValueKey('duplicates-${choice.name}'),
              onTap: () => setState(() => _choice = choice),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                            padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
                            child: Icon(
                                _choice == choice
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off,
                                color: _choice == choice
                                    ? AppColors.accentActive
                                    : AppColors.muted,
                                size: 21)),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                              Text(title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              ...details
                            ])),
                      ]))));
  Widget _version(Track t, String origin) {
    final uri = Uri.tryParse(t.sourceUrl);
    final source = t.sourceKind.musicProviderName ?? uri?.host ?? '';
    final duration = t.durationMs == null
        ? 'Duração não informada'
        : '${t.durationMs! ~/ 60000}:${((t.durationMs! ~/ 1000) % 60).toString().padLeft(2, '0')}';
    return Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t.displayTitle),
          if (t.artist.isNotEmpty)
            Text(t.artist, style: const TextStyle(fontSize: 12)),
          Text('$origin · $source · $duration',
              style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          if (t.album.isNotEmpty)
            Text(t.album,
                style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          if (t.explicit != null)
            Text(t.explicit! ? 'Explícita' : 'Limpa',
                style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          if (t.sourceUrl.isNotEmpty)
            Text(t.sourceUrl,
                style: const TextStyle(fontSize: 11, color: AppColors.muted)),
        ]));
  }
}

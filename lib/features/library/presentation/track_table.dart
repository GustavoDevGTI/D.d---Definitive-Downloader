import 'dart:async';
import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../application/library_controller.dart';
import '../domain/models.dart';

class TrackTable extends StatelessWidget {
  const TrackTable(
      {super.key, required this.controller, required this.onFocus});
  final LibraryController controller;
  final void Function(Track) onFocus;
  @override
  Widget build(BuildContext context) => Column(children: [
        Container(
            height: 43,
            decoration: const BoxDecoration(
                color: Color(0xFFF9FAFB),
                border: Border(
                    top: BorderSide(color: AppColors.line),
                    bottom: BorderSide(color: AppColors.line))),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              SizedBox(
                  width: 32,
                  child: Checkbox(
                      value: controller.page.items.isNotEmpty &&
                          controller.page.items.every((t) => t.selected),
                      onChanged:
                          controller.busy || controller.page.items.isEmpty
                              ? null
                              : (value) => unawaited(
                                  controller.selectPage(value ?? false)))),
              const SizedBox(width: 30, child: Text('#', style: _header)),
              const Expanded(
                  flex: 5, child: Text('Faixa / artista', style: _header)),
              const Expanded(
                  flex: 2, child: Text('Origem do áudio', style: _header)),
              const SizedBox(width: 54, child: Text('Tempo', style: _header)),
              const SizedBox(
                  width: 110, child: Text('Situação', style: _header)),
            ])),
        Expanded(
            child: controller.page.items.isEmpty
                ? _empty(context)
                : ListView.separated(
                    key: ValueKey(
                        '${controller.current?.id}-${controller.view}-${controller.offset}'),
                    itemCount: controller.page.items.length,
                    separatorBuilder: (context, index) => const Divider(
                        height: 1, thickness: 1, color: Color(0xFFEDF0F3)),
                    itemBuilder: (context, index) {
                      final track = controller.page.items[index];
                      final focused = controller.focused?.id == track.id;
                      return Material(
                          color:
                              focused ? const Color(0xFFF0F5F8) : Colors.white,
                          child: InkWell(
                              onTap: () => onFocus(track),
                              child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: SizedBox(
                                      height: 65,
                                      child: Row(children: [
                                        SizedBox(
                                            width: 32,
                                            child: Checkbox(
                                                value: track.selected,
                                                onChanged: controller.busy
                                                    ? null
                                                    : (value) => unawaited(
                                                        controller.select(track,
                                                            value ?? false)))),
                                        SizedBox(
                                            width: 30,
                                            child: Text(
                                                track.position
                                                    .toString()
                                                    .padLeft(2, '0'),
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    color: AppColors.muted))),
                                        Expanded(
                                            flex: 5,
                                            child: Padding(
                                                padding: const EdgeInsets.only(
                                                    right: 12),
                                                child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(track.title,
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: const TextStyle(
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600)),
                                                      const SizedBox(height: 5),
                                                      Text(track.artist,
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: const TextStyle(
                                                              fontSize: 11,
                                                              color: AppColors
                                                                  .muted)),
                                                    ]))),
                                        Expanded(
                                            flex: 2,
                                            child: Tooltip(
                                              message:
                                                  '${track.status == TrackStatus.completed ? 'Baixado de' : 'Fonte selecionada'}: ${track.sourceLabel}',
                                              child: Text(
                                                  track.sourceKind
                                                          .musicProviderName ??
                                                      track.sourceLabel,
                                                  maxLines: 2,
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: track
                                                                  .sourceKind
                                                                  .musicProviderName ==
                                                              null
                                                          ? FontWeight.w400
                                                          : FontWeight.w600,
                                                      color: track.sourceKind
                                                                  .musicProviderName ==
                                                              null
                                                          ? AppColors.muted
                                                          : AppColors.accent)),
                                            )),
                                        SizedBox(
                                            width: 54,
                                            child: Text(
                                                formatDuration(
                                                    track.durationMs),
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    color: AppColors.muted))),
                                        SizedBox(
                                            width: 110,
                                            child: Tooltip(
                                                message: track.error.isNotEmpty
                                                    ? track.error
                                                    : track.localPath,
                                                child: _Status(track: track))),
                                      ])))));
                    })),
      ]);

  Widget _empty(BuildContext context) => Center(
      child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(
                controller.current == null
                    ? Icons.playlist_add_outlined
                    : Icons.filter_list_outlined,
                size: 39,
                color: const Color(0xFF9AAAB8)),
            const SizedBox(height: 18),
            Text(
                controller.current == null
                    ? 'Uma coleção, do seu jeito.'
                    : 'Nenhuma faixa nesta visualização.',
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
            const SizedBox(height: 9),
            Text(
                controller.current == null
                    ? 'Importe uma lista para conferir cada faixa\ne manter tudo na ordem original.'
                    : 'Volte para Coleções para conferir a lista completa.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.muted, height: 1.8)),
            if (controller.current == null)
              Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: TextButton(
                      onPressed: controller.busy
                          ? null
                          : () => unawaited(controller.loadExample()),
                      child: const Text('Explorar um exemplo local'))),
          ])));
}

const _header = TextStyle(
    fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.muted);

class _Status extends StatelessWidget {
  const _Status({required this.track});
  final Track track;
  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = switch (track.status) {
      TrackStatus.pending => (
          'Conferir',
          Icons.circle_outlined,
          AppColors.muted
        ),
      TrackStatus.ready => ('Pronta', Icons.check_outlined, AppColors.accent),
      TrackStatus.downloading => (
          'Baixando',
          Icons.south_outlined,
          AppColors.accent
        ),
      TrackStatus.completed => (
          'Salva',
          Icons.check_circle_outline,
          AppColors.success
        ),
      TrackStatus.failed => (
          'Falhou',
          Icons.error_outline,
          const Color(0xFF9C4141)
        ),
    };
    return Row(children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 6),
      Flexible(child: Text(label, style: TextStyle(fontSize: 10, color: color)))
    ]);
  }
}

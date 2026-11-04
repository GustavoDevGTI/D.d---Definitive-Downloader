import 'dart:async';
import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../application/library_controller.dart';
import '../domain/models.dart';
import '../domain/track_listing.dart';
import 'edit_track_dialog.dart';

class TrackTable extends StatelessWidget {
  const TrackTable(
      {super.key, required this.controller, required this.onFocus});
  final LibraryController controller;
  final ValueChanged<Track> onFocus;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final compact = box.maxWidth < 500;
        final scale = MediaQuery.textScalerOf(context).scale(13) / 13;
        return Column(children: [
          Container(
              color: AppColors.surface,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(children: [
                SizedBox(
                    width: 36,
                    child: Checkbox(
                        key: const ValueKey('select-all-collection'),
                        semanticLabel: 'Selecionar todas as faixas do filtro',
                        tristate: true,
                        value: controller.allFilteredSelected
                            ? true
                            : controller.page.filteredSelectedCount > 0
                                ? null
                                : false,
                        onChanged: controller.busy || controller.page.total == 0
                            ? null
                            : (_) => unawaited(controller.selectCollection(
                                !controller.allFilteredSelected)))),
                Expanded(child: _header('Faixa / artista', TrackSort.name)),
                if (!compact) ...[
                  SizedBox(
                      width: 84, child: _header('Duração', TrackSort.duration)),
                  SizedBox(
                      width: 142,
                      child:
                          _header('Correspondência', TrackSort.correspondence))
                ],
              ])),
          Expanded(
              child: controller.page.items.isEmpty
                  ? const Center(
                      child: Text('Nenhuma faixa neste filtro.',
                          style:
                              TextStyle(fontSize: 12, color: AppColors.muted)))
                  : ListView.builder(
                      primary: false,
                      itemExtent: (compact ? 102.0 : 80.0) * scale.clamp(1, 2),
                      itemCount: controller.page.items.length,
                      itemBuilder: (context, index) {
                        final t = controller.page.items[index];
                        final focused = controller.focused?.id == t.id;
                        return Material(
                            key: ValueKey('track-row-${t.id}'),
                            color: focused
                                ? Color.lerp(
                                    AppColors.accentSoft, AppColors.accent, .12)
                                : t.needsReview
                                    ? AppColors.accentSoft
                                    : Colors.white,
                            child: InkWell(
                                onTap: () => onFocus(t),
                                child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6),
                                    decoration: BoxDecoration(
                                        border: Border(
                                            left: BorderSide(
                                                width: 3,
                                                color: t.needsReview
                                                    ? AppColors.accentActive
                                                    : Colors.transparent),
                                            bottom: const BorderSide(
                                                color: AppColors.line))),
                                    child: Row(children: [
                                      SizedBox(
                                          width: 36,
                                          child: Checkbox(
                                              semanticLabel:
                                                  'Selecionar ${t.displayTitle}',
                                              value: t.selected,
                                              onChanged: controller.busy
                                                  ? null
                                                  : (v) => unawaited(controller
                                                      .select(t, v ?? false)))),
                                      Expanded(
                                          child: Padding(
                                              padding: const EdgeInsets.only(
                                                  right: 8),
                                              child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(children: [
                                                      if (t.needsReview)
                                                        const Tooltip(
                                                            message:
                                                                'Conferir correspondência',
                                                            child: Icon(
                                                                Icons
                                                                    .priority_high,
                                                                size: 16,
                                                                color: AppColors
                                                                    .accentActive)),
                                                      if (t.hasManualSource)
                                                        const Padding(
                                                            padding:
                                                                EdgeInsets.only(
                                                                    right: 4),
                                                            child: Tooltip(
                                                                message:
                                                                    'Fonte manual definida',
                                                                child: Icon(
                                                                    Icons.link,
                                                                    size: 14,
                                                                    color: AppColors
                                                                        .accent))),
                                                      Expanded(
                                                          child: Text(
                                                              '${t.position}. ${t.displayTitle}',
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              style: TextStyle(
                                                                  fontSize: 13,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  color: t.needsReview
                                                                      ? AppColors
                                                                          .accentActive
                                                                      : AppColors
                                                                          .ink))),
                                                    ]),
                                                    Text(t.artist,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: const TextStyle(
                                                            fontSize: 12,
                                                            color: AppColors
                                                                .muted)),
                                                    Text(
                                                        t.sourceKind
                                                                .musicProviderName ??
                                                            t.sourceLabel,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: const TextStyle(
                                                            fontSize: 10,
                                                            color: AppColors
                                                                .muted)),
                                                    if (compact)
                                                      Text(
                                                          '${formatDuration(t.durationMs)} · ${t.needsReview ? 'Conferir' : t.matchStatus.label}',
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: const TextStyle(
                                                              fontSize: 11,
                                                              color: AppColors
                                                                  .accentActive)),
                                                  ]))),
                                      _edit(context, t),
                                      if (!compact) ...[
                                        SizedBox(
                                            width: 84,
                                            child: Text(
                                                formatDuration(t.durationMs),
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    color: AppColors.muted))),
                                        SizedBox(
                                            width: 142,
                                            child: Text(
                                                t.needsReview
                                                    ? 'Conferir'
                                                    : t.matchStatus.label,
                                                style: TextStyle(
                                                    fontSize: 11,
                                                    color: t.needsReview
                                                        ? AppColors.accentActive
                                                        : AppColors.muted,
                                                    fontWeight: t.needsReview
                                                        ? FontWeight.w700
                                                        : FontWeight.w400))),
                                      ],
                                    ]))));
                      })),
        ]);
      });

  Widget _header(String label, TrackSort sort) => Tooltip(
      message: 'Ordenar por $label',
      child: InkWell(
          key: ValueKey('track-sort-${sort.name}'),
          onTap: () => unawaited(controller.sortTracks(sort)),
          child: SizedBox(
              height: 44,
              child: Row(children: [
                Flexible(
                    child: Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w600))),
                if (controller.trackSort == sort)
                  Icon(
                      controller.trackDescending
                          ? Icons.arrow_downward
                          : Icons.arrow_upward,
                      size: 14,
                      color: AppColors.accentActive),
              ]))));

  Widget _edit(BuildContext context, Track t) => PopupMenuButton<String>(
      tooltip: controller.current?.editingLocked == true
          ? 'Nomes e ordem bloqueados após o início'
          : 'Editar faixa',
      enabled: !controller.busy && controller.current?.editingLocked != true,
      icon: const Icon(Icons.more_vert, size: 19, color: AppColors.accent),
      onSelected: (action) {
        if (action == 'edit') {
          unawaited(showEditTrack(context, controller, t));
        } else {
          unawaited(controller.editTrack(t,
              name: t.displayTitle,
              position: t.position + (action == 'up' ? -1 : 1)));
        }
      },
      itemBuilder: (_) => [
            const PopupMenuItem(
                value: 'edit', child: Text('Editar nome, link / ID e posição')),
            PopupMenuItem(
                value: 'up',
                enabled: t.position > 1,
                child: const Text('Mover para cima')),
            PopupMenuItem(
                value: 'down',
                enabled: t.position < (controller.current?.trackCount ?? 0),
                child: const Text('Mover para baixo'))
          ]);
}

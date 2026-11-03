import 'dart:async';
import 'edit_track_dialog.dart';
import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../application/library_controller.dart';
import '../domain/models.dart';
import '../../workspace/presentation/workspace_components.dart';

class TrackTable extends StatelessWidget {
  const TrackTable(
      {super.key, required this.controller, required this.onFocus});
  final LibraryController controller;
  final ValueChanged<Track> onFocus;
  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final compact = constraints.maxWidth < 500;
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
                const Expanded(child: Text('Faixa / artista', style: _header)),
                if (!compact) ...[
                  const SizedBox(
                      width: 58, child: Text('Duração', style: _header)),
                  const SizedBox(
                      width: 116,
                      child: Text('Correspondência', style: _header)),
                ],
              ])),
          Expanded(
              child: controller.page.items.isEmpty
                  ? const WorkspaceNotice(
                      title: 'Nenhuma faixa nesta visualização.',
                      message: 'Ajuste a pesquisa para conferir outras faixas.')
                  : ListView.builder(
                      primary: false,
                      itemExtent: (compact ? 102.0 : 80.0) * scale.clamp(1, 2),
                      itemCount: controller.page.items.length,
                      itemBuilder: (context, index) {
                        final t = controller.page.items[index];
                        return Material(
                            color: controller.focused?.id == t.id
                                ? AppColors.accentSoft
                                : Colors.white,
                            child: InkWell(
                                onTap: () => onFocus(t),
                                child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6),
                                    decoration: const BoxDecoration(
                                        border: Border(
                                            bottom: BorderSide(
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
                                                  right: 10),
                                              child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(children: [
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
                                                              style: const TextStyle(
                                                                  fontSize: 13,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600))),
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
                                                          '${formatDuration(t.durationMs)} · ${t.matchStatus.label}',
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: const TextStyle(
                                                              fontSize: 11,
                                                              color: AppColors
                                                                  .accent)),
                                                  ]))),
                                      PopupMenuButton<String>(
                                          tooltip: controller
                                                      .current?.editingLocked ==
                                                  true
                                              ? 'Nomes e ordem bloqueados após o início'
                                              : 'Editar faixa',
                                          enabled: !controller.busy &&
                                              controller
                                                      .current?.editingLocked !=
                                                  true,
                                          icon: const Icon(Icons.more_vert,
                                              size: 19,
                                              color: AppColors.accent),
                                          onSelected: (action) {
                                            if (action == 'edit') {
                                              unawaited(showEditTrack(
                                                  context, controller, t));
                                            } else {
                                              unawaited(controller.editTrack(t,
                                                  name: t.displayTitle,
                                                  position: t.position +
                                                      (action == 'up'
                                                          ? -1
                                                          : 1)));
                                            }
                                          },
                                          itemBuilder: (_) => [
                                                const PopupMenuItem(
                                                    value: 'edit',
                                                    child: Text(
                                                        'Editar nome, link / ID e posição')),
                                                PopupMenuItem(
                                                    value: 'up',
                                                    enabled: t.position > 1,
                                                    child: const Text(
                                                        'Mover para cima')),
                                                PopupMenuItem(
                                                    value: 'down',
                                                    enabled: t.position <
                                                        (controller.current
                                                                ?.trackCount ??
                                                            0),
                                                    child: const Text(
                                                        'Mover para baixo')),
                                              ]),
                                      if (!compact) ...[
                                        SizedBox(
                                            width: 58,
                                            child: Text(
                                                formatDuration(t.durationMs),
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    color: AppColors.muted))),
                                        SizedBox(
                                            width: 116,
                                            child: Text(t.matchStatus.label,
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    color: AppColors.accent))),
                                      ],
                                    ]))));
                      })),
        ]);
      });
}

const _header = TextStyle(
    fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.muted);

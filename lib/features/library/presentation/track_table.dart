import 'dart:async';
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
              color: const Color(0xFFF7F8FA),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(children: [
                SizedBox(
                    width: 36,
                    child: Checkbox(
                        semanticLabel: 'Selecionar faixas da página',
                        value: controller.page.items.isNotEmpty &&
                            controller.page.items.every((t) => t.selected),
                        onChanged: controller.busy ||
                                controller.page.items.isEmpty
                            ? null
                            : (v) =>
                                unawaited(controller.selectPage(v ?? false)))),
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
                                ? const Color(0xFFEDF1F4)
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
                                                  'Selecionar ${t.title}',
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
                                                          child: Text(t.title,
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

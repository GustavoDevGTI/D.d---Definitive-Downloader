import 'dart:async';
import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../core/app_identity.dart';
import '../application/library_controller.dart';

class LibrarySidebar extends StatelessWidget {
  const LibrarySidebar(
      {super.key, required this.controller, required this.compact});
  final LibraryController controller;
  final bool compact;
  @override
  Widget build(BuildContext context) => Container(
      width: compact ? 168 : 202,
      decoration: const BoxDecoration(
          color: Color(0xFFF7F9FA),
          border: Border(right: BorderSide(color: AppColors.line))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 16, 34),
            child: Row(children: [
              const Icon(Icons.file_download_outlined,
                  size: 25, color: AppColors.accent),
              const SizedBox(width: 10),
              Expanded(
                  child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(AppIdentity.abbreviation,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -1)))),
            ])),
        _navigation(Icons.queue_music_outlined, 'Coleções', 'collections'),
        _navigation(Icons.downloading_outlined, 'Downloads', 'downloads'),
        _navigation(Icons.folder_open_outlined, 'Arquivos', 'files'),
        const SizedBox(height: 36),
        const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text('Suas coleções',
                style: TextStyle(
                    fontSize: 11,
                    color: AppColors.muted,
                    fontWeight: FontWeight.w600))),
        const SizedBox(height: 10),
        Expanded(
            child: controller.collections.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Text('As listas importadas\naparecem aqui.',
                        style: TextStyle(
                            fontSize: 11, height: 1.8, color: AppColors.muted)))
                : ListView.builder(
                    itemCount: controller.collections.length,
                    itemBuilder: (context, index) {
                      final item = controller.collections[index];
                      return InkWell(
                          onTap: controller.busy
                              ? null
                              : () =>
                                  unawaited(controller.openCollection(item)),
                          child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(24, 10, 16, 10),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight:
                                                controller.current?.id ==
                                                        item.id
                                                    ? FontWeight.w600
                                                    : FontWeight.w400,
                                            color: AppColors.ink)),
                                    const SizedBox(height: 4),
                                    Text('${item.trackCount} faixas',
                                        style: const TextStyle(
                                            fontSize: 10,
                                            color: AppColors.muted)),
                                  ])));
                    })),
        Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 16, 22),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Feito para organizar.',
                  style: TextStyle(fontSize: 11, color: AppColors.muted)),
              const SizedBox(height: 5),
              Text('Versão 0.1 · desktop',
                  style: TextStyle(
                      fontSize: 10,
                      color: AppColors.muted.withValues(alpha: .8))),
            ])),
      ]));

  Widget _navigation(IconData icon, String label, String value) {
    final selected = controller.view == value;
    return Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
            color: selected ? const Color(0xFFEAF0F4) : Colors.transparent,
            border: Border(
                left: BorderSide(
                    color: selected ? AppColors.accent : Colors.transparent,
                    width: 3))),
        child: InkWell(
            onTap: () => unawaited(controller.setView(value)),
            child: Padding(
                padding: const EdgeInsets.fromLTRB(21, 12, 14, 12),
                child: Row(children: [
                  Icon(icon,
                      size: 18,
                      color: selected ? AppColors.accent : AppColors.muted),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text(label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight:
                                  selected ? FontWeight.w600 : FontWeight.w400,
                              color: selected
                                  ? AppColors.accent
                                  : AppColors.ink))),
                ]))));
  }
}

import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../application/library_controller.dart';

class LibraryOperationStatus extends StatelessWidget {
  const LibraryOperationStatus({super.key, required this.controller});
  final LibraryController controller;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: Listenable.merge([controller, controller.transferUpdates]),
      builder: (context, _) => _content());
  Widget _content() {
    final c = controller;
    if (!c.downloading && !c.preparing && !c.importing) {
      return const SizedBox(height: 8);
    }
    return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(4)),
        child: Row(children: [
          Expanded(
              child: Text(
                  c.downloading
                      ? '${c.activeTitle} · ${c.progress == null ? 'recebendo / processando' : '${(c.progress! * 100).round()}% recebidos'}'
                      : c.message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontSize: 11, color: AppColors.muted))),
          if (c.downloading || c.preparing)
            IconButton(
                tooltip: 'Interromper operação atual',
                onPressed: c.cancel,
                icon: const Icon(Icons.stop_circle_outlined, size: 20)),
        ]));
  }
}

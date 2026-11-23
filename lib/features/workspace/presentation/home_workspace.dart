import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../application/workspace_controller.dart';
import '../domain/workspace_models.dart';

class HomeWorkspace extends StatelessWidget {
  const HomeWorkspace(
      {super.key,
      required this.controller,
      required this.onNavigate,
      required this.onImportPlaylist});
  final WorkspaceController controller;
  final void Function(AppSection, int) onNavigate;
  final VoidCallback onImportPlaylist;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        final summary = controller.summary;
        return ListView(primary: false, padding: EdgeInsets.zero, children: [
          LayoutBuilder(builder: (context, constraints) {
            final width = constraints.maxWidth < 720
                ? constraints.maxWidth
                : (constraints.maxWidth - 28) / 3;
            return Wrap(spacing: 14, runSpacing: 12, children: [
              _shortcut(
                  width,
                  'Importar playlist',
                  AppColors.accentActive,
                  AppColors.accentSoft,
                  onImportPlaylist),
              _shortcut(
                  width,
                  'Minhas coleções',
                  AppColors.music,
                  AppColors.musicSoft,
                  () => onNavigate(AppSection.music, 0)),
              _shortcut(
                  width,
                  'Meus arquivos',
                  AppColors.ink,
                  AppColors.musicSoft,
                  () => onNavigate(AppSection.files, 0)),
            ]);
          }),
          const SizedBox(height: 32),
          const Text('Visão geral',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, constraints) {
            final compact = constraints.maxWidth < 520;
            final width = (constraints.maxWidth - 24) / 3;
            return Wrap(spacing: 12, runSpacing: 16, children: [
              _stat(
                  width,
                  'Registros',
                  controller.loaded ? '${summary.records}' : '—',
                  Icons.library_music_outlined,
                  AppColors.ink,
                  compact: compact),
              _stat(
                  width,
                  'Baixando',
                  controller.loaded ? '${summary.active}' : '—',
                  Icons.south_rounded,
                  AppColors.music,
                  compact: compact),
              _stat(
                  width,
                  'Concluídos',
                  controller.loaded ? '${summary.completed}' : '—',
                  Icons.done_rounded,
                  AppColors.success,
                  compact: compact),
            ]);
          }),
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Divider(height: 1)),
          const Text('Seus downloads',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _queue(
              'Músicas',
              Icons.queue_music_rounded,
              '${summary.active} em andamento',
              () => onNavigate(AppSection.music, 2)),
          _queue('Vídeos e fotos', Icons.perm_media_outlined,
              null, () => onNavigate(AppSection.media, 1)),
          const SizedBox(height: 24),
          Row(children: [
            const Expanded(
                child: Text('Últimos arquivos',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
            TextButton(
                onPressed: () => onNavigate(AppSection.files, 0),
                child: const Text('Ver todos')),
          ]),
          if (summary.recent.isEmpty)
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Os arquivos concluídos vão aparecer aqui.',
                    style: TextStyle(color: AppColors.muted, height: 1.6)))
          else
            for (final file in summary.recent)
              ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.audio_file_outlined,
                      color: AppColors.music, size: 22),
                  title: Text(file.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w500)),
                  subtitle: Text(file.folder,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.muted)),
                  onTap: () => onNavigate(AppSection.files, 0)),
        ]);
      });
  Widget _shortcut(double width, String title, Color color, Color background,
          VoidCallback action) =>
      SizedBox(
          width: width,
          child: Semantics(
              button: true,
              child: Material(
                  color: background,
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                      onTap: action,
                      child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(title,
                              style: TextStyle(
                                  color: color,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600)))))));
  Widget _stat(
          double width, String label, String value, IconData icon, Color color,
          {bool compact = false}) =>
      SizedBox(
          width: width,
          child: compact
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(value,
                      style: const TextStyle(
                          fontSize: 25,
                          height: 1.1,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 5),
                  Text(label,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.muted)),
                ])
              : Row(children: [
                  Icon(icon, color: color, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(value,
                            style: const TextStyle(
                                fontSize: 26,
                                height: 1.1,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(label,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.muted)),
                      ])),
                ]));
  Widget _queue(
          String title, IconData icon, String? subtitle, VoidCallback action) =>
      ListTile(
          contentPadding: EdgeInsets.zero,
          minVerticalPadding: 10,
          leading: Icon(icon, size: 23, color: AppColors.muted),
          title: Text(title,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: subtitle == null ? null : Text(subtitle,
              style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          onTap: action);
}

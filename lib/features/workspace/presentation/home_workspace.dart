import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../application/workspace_controller.dart';
import '../domain/workspace_models.dart';

class HomeWorkspace extends StatelessWidget {
  const HomeWorkspace(
      {super.key, required this.controller, required this.onNavigate});
  final WorkspaceController controller;
  final void Function(AppSection, int) onNavigate;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        final summary = controller.summary;
        return ListView(primary: false, padding: EdgeInsets.zero, children: [
          LayoutBuilder(builder: (context, constraints) {
            final compact = constraints.maxWidth < 650;
            final introduction =
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('O que vem\npra coleção?',
                  style: TextStyle(
                      fontSize: compact ? 28 : 34,
                      height: 1.12,
                      letterSpacing: -1.2,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              const Text('Importe uma playlist ou acompanhe seus downloads.',
                  style: TextStyle(color: AppColors.muted, height: 1.6)),
            ]);
            final import = FilledButton.icon(
                onPressed: () => onNavigate(AppSection.music, 0),
                icon: const Icon(Icons.playlist_add_rounded, size: 21),
                label: const Text('Importar playlist'));
            return Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 28),
                child: compact
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            introduction,
                            const SizedBox(height: 18),
                            import
                          ])
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                            Expanded(child: introduction),
                            const SizedBox(width: 24),
                            import
                          ]));
          }),
          LayoutBuilder(builder: (context, constraints) {
            final width = constraints.maxWidth < 530
                ? constraints.maxWidth
                : (constraints.maxWidth - 14) / 2;
            return Wrap(spacing: 14, runSpacing: 12, children: [
              _shortcut(
                  width,
                  Icons.headphones_rounded,
                  'Minhas coleções',
                  'Playlists, faixas e fontes.',
                  AppColors.accent,
                  AppColors.accentSoft,
                  () => onNavigate(AppSection.music, 0)),
              _shortcut(
                  width,
                  Icons.folder_open_rounded,
                  'Meus arquivos',
                  'O que já foi baixado.',
                  AppColors.ink,
                  AppColors.musicSoft,
                  () => onNavigate(AppSection.files, 0)),
            ]);
          }),
          const SizedBox(height: 30),
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
              'Ver fila de mídias', () => onNavigate(AppSection.media, 1)),
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
                  trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                  onTap: () => onNavigate(AppSection.files, 0)),
        ]);
      });
  Widget _shortcut(double width, IconData icon, String title, String subtitle,
          Color color, Color background, VoidCallback action) =>
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
                          padding: const EdgeInsets.all(20),
                          child: Row(children: [
                            Icon(icon, size: 30, color: color),
                            const SizedBox(width: 18),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(title,
                                      style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 5),
                                  Text(subtitle,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.muted,
                                          height: 1.4)),
                                ])),
                            const SizedBox(width: 8),
                            Icon(Icons.north_east_rounded,
                                size: 19, color: color),
                          ]))))));
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
          String title, IconData icon, String subtitle, VoidCallback action) =>
      ListTile(
          contentPadding: EdgeInsets.zero,
          minVerticalPadding: 10,
          leading: Icon(icon, size: 23, color: AppColors.muted),
          title: Text(title,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: Text(subtitle,
              style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          trailing: const Icon(Icons.chevron_right_rounded, size: 21),
          onTap: action);
}

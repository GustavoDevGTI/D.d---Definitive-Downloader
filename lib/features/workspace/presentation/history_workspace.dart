import 'dart:async';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../../../app/theme.dart';
import '../application/workspace_controller.dart';
import 'workspace_components.dart';

class HistoryWorkspace extends StatefulWidget {
  const HistoryWorkspace({super.key, required this.controller});
  final WorkspaceController controller;
  @override
  State<HistoryWorkspace> createState() => _HistoryWorkspaceState();
}

class _HistoryWorkspaceState extends State<HistoryWorkspace> {
  final _query = TextEditingController();
  Timer? _timer;
  @override
  void dispose() {
    _timer?.cancel();
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: widget.controller,
      builder: (context, child) {
        final c = widget.controller;
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Histórico dos downloads organizado por pastas',
                  style: TextStyle(fontSize: 12, color: AppColors.muted)),
              const SizedBox(height: 10),
              FolderBreadcrumb(
                  folder: c.folder, onOpen: (v) => unawaited(c.openFolder(v))),
              const SizedBox(height: 10),
              TextField(
                  controller: _query,
                  decoration: const InputDecoration(
                      hintText: 'Buscar arquivos ou pastas…'),
                  onChanged: (value) {
                    _timer?.cancel();
                    _timer = Timer(const Duration(milliseconds: 300),
                        () => unawaited(c.searchHistory(value)));
                  }),
              const SizedBox(height: 14),
              if (c.message.isNotEmpty)
                Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child:
                        Text(c.message, style: const TextStyle(fontSize: 12))),
              Expanded(
                  child: c.history.total == 0
                      ? const WorkspacePanel(
                          child: WorkspaceNotice(
                              title: 'Nenhum registro nesta pasta',
                              message:
                                  'Os downloads concluídos aparecerão aqui, organizados pelo local onde foram salvos.'))
                      : ListView.separated(
                          primary: false,
                          itemCount:
                              c.history.folders.length + c.history.files.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            if (index < c.history.folders.length) {
                              final folder = c.history.folders[index];
                              return WorkspacePanel(
                                  child: Tooltip(
                                      message: folder.path,
                                      child: ListTile(
                                          dense: true,
                                          leading: const Icon(
                                              Icons.folder_outlined,
                                              size: 20),
                                          title: Text(p.basename(folder.path),
                                              style: const TextStyle(
                                                  fontSize: 12)),
                                          subtitle: Text(
                                              '${folder.count} arquivo(s)',
                                              style: const TextStyle(
                                                  fontSize: 10,
                                                  color: AppColors.muted)),
                                          trailing: const Icon(
                                              Icons.chevron_right,
                                              size: 18),
                                          onTap: () => unawaited(
                                              c.openFolder(folder.path)))));
                            }
                            final file = c.history
                                    .files[index - c.history.folders.length],
                                available = c.availability[c
                                    .history
                                    .files[index - c.history.folders.length]
                                    .path];
                            return WorkspacePanel(
                                child: ListTile(
                                    dense: true,
                                    leading: Icon(
                                        available == false
                                            ? Icons.file_present_outlined
                                            : Icons.insert_drive_file_outlined,
                                        size: 20),
                                    title: Text(file.name,
                                        style: const TextStyle(fontSize: 12)),
                                    subtitle: Text(
                                        available == false
                                            ? 'Indisponível: arquivo movido ou excluído. Registro preservado.'
                                            : available == true
                                                ? 'Arquivo disponível'
                                                : 'Verificando disponibilidade…',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: available == false
                                                ? const Color(0xFF9C4141)
                                                : AppColors.muted)),
                                    onTap: available == true
                                        ? () => unawaited(c.openFile(file))
                                        : null,
                                    trailing: PopupMenuButton<String>(
                                        tooltip: 'Ações do arquivo',
                                        onSelected: (v) => unawaited(v == 'open'
                                            ? c.openFile(file)
                                            : c.reveal(file.path)),
                                        itemBuilder: (context) => [
                                              PopupMenuItem(
                                                  value: 'open',
                                                  enabled: available == true,
                                                  child: const Text(
                                                      'Abrir arquivo')),
                                              const PopupMenuItem(
                                                  value: 'folder',
                                                  child:
                                                      Text('Abrir localização'))
                                            ])));
                          })),
              PageControls(
                  offset: c.historyOffset,
                  count: c.history.folders.length + c.history.files.length,
                  total: c.history.total,
                  onPage: (v) => unawaited(c.turnHistory(v))),
              OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(shape: const StadiumBorder()),
                  onPressed: () => unawaited(c.library.openOutput()),
                  icon: const Icon(Icons.folder_open_outlined, size: 18),
                  label: const Text('Pasta principal')),
              const SizedBox(height: 8),
              const Text(
                  'Pastas e caminhos reais dos downloads registrados pelo aplicativo.',
                  style: TextStyle(fontSize: 10, color: AppColors.muted)),
            ]);
      });
}

class FolderBreadcrumb extends StatelessWidget {
  const FolderBreadcrumb(
      {super.key, required this.folder, required this.onOpen});
  final String folder;
  final ValueChanged<String> onOpen;
  @override
  Widget build(BuildContext context) =>
      Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
        TextButton(
            style: TextButton.styleFrom(
                padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
            onPressed: folder.isEmpty ? null : () => onOpen(''),
            child: const Text('Downloads',
                style: TextStyle(
                    fontSize: 12, decoration: TextDecoration.underline))),
        if (folder.isNotEmpty) ...[
          const Icon(Icons.chevron_right, size: 16),
          for (var index = 0; index < p.split(folder).length; index++)
            TextButton(
                onPressed: () =>
                    onOpen(p.joinAll(p.split(folder).take(index + 1))),
                child: Text(p.split(folder)[index],
                    style: const TextStyle(fontSize: 11)))
        ],
      ]);
}

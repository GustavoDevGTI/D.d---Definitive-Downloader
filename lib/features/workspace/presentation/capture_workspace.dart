import 'package:flutter/material.dart';
import '../domain/workspace_models.dart';
import 'link_entry_panel.dart';

class CaptureWorkspace extends StatefulWidget {
  const CaptureWorkspace({super.key, required this.category});
  final ContentCategory category;
  @override
  State<CaptureWorkspace> createState() => _CaptureWorkspaceState();
}

class _CaptureWorkspaceState extends State<CaptureWorkspace> {
  final _url = TextEditingController();
  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final audio = widget.category == ContentCategory.music;
    return ListView(primary: false, padding: EdgeInsets.zero, children: [
      LinkEntryPanel(
          title:
              audio ? 'Capturador de áudio' : 'Capturador de vídeos e imagens',
          fieldLabel: 'Endereço da página',
          hintText: 'https://exemplo.com/conteudo',
          controller: _url,
          inputKey: ValueKey('capture-url-${widget.category.name}'),
          actionKey: ValueKey('capture-analyze-${widget.category.name}'),
          actionLabel: 'Analisar link',
          actionIcon: Icons.search,
          onAction: null,
          status: 'Captura de links indisponível nesta versão.'),
    ]);
  }
}

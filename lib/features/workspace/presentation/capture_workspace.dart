import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../domain/workspace_models.dart';
import 'workspace_components.dart';

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
      Text(audio ? 'Capturador de áudio' : 'Capturador de vídeos e imagens',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
      WorkspacePanel(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Endereço da página',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted)),
            const SizedBox(height: 12),
            TextField(
                key: ValueKey('capture-url-${widget.category.name}'),
                controller: _url,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                    hintText: 'https://exemplo.com/conteudo',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: AppColors.line)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: AppColors.line)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(
                            color: AppColors.accent, width: 1.4)))),
            const SizedBox(height: 10),
            Align(
                alignment: Alignment.centerRight,
                child: Tooltip(
                    message:
                        'A análise de links individuais ainda não está integrada.',
                    child: OutlinedButton.icon(
                        key:
                            ValueKey('capture-analyze-${widget.category.name}'),
                        style: OutlinedButton.styleFrom(
                            shape: const StadiumBorder(),
                            backgroundColor: AppColors.surface),
                        onPressed: null,
                        icon: const Icon(Icons.search, size: 18),
                        label: const Text('Analisar link')))),
          ])),
      const SizedBox(height: 14),
      const Text('Captura de links indisponível nesta versão.',
          style: TextStyle(fontSize: 11, color: AppColors.muted, height: 1.6)),
    ]);
  }
}

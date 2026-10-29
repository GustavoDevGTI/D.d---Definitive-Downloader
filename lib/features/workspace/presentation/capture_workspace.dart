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
      Text(
          audio
              ? 'Analise links de áudio, faixas e páginas compatíveis.'
              : 'Analise páginas e repositórios para encontrar vídeos e fotos.',
          style: const TextStyle(
              fontSize: 12, color: AppColors.muted, height: 1.6)),
      const SizedBox(height: 14),
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
            Wrap(
                key: ValueKey('capture-filter-${widget.category.name}'),
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 10,
                children: [
                  Text(
                      audio
                          ? 'Filtro: arquivos de áudio'
                          : 'Filtro: vídeos e imagens',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.muted)),
                  Tooltip(
                      message:
                          'A análise de links individuais ainda não está integrada.',
                      child: OutlinedButton.icon(
                          key: ValueKey(
                              'capture-analyze-${widget.category.name}'),
                          style: OutlinedButton.styleFrom(
                              shape: const StadiumBorder(),
                              backgroundColor: const Color(0xFFF3F4F5)),
                          onPressed: null,
                          icon: const Icon(Icons.search, size: 18),
                          label: const Text('Analisar link'))),
                ]),
          ])),
      const SizedBox(height: 14),
      const WorkspacePanel(
          padding: EdgeInsets.all(24),
          child: Column(children: [
            Icon(Icons.search, size: 27, color: AppColors.muted),
            SizedBox(height: 14),
            Text(
                'Os arquivos encontrados aparecerão aqui após a análise do link.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12, color: AppColors.muted, height: 1.6)),
          ])),
      const SizedBox(height: 14),
      Text(
          audio
              ? 'A captura de URLs ainda não está disponível. MP3 direto pode ser vinculado na conferência de uma faixa.'
              : 'A captura de páginas, escolha de resolução e download de vídeos e fotos ainda não estão disponíveis.',
          style: const TextStyle(
              fontSize: 11, color: AppColors.muted, height: 1.6)),
    ]);
  }
}

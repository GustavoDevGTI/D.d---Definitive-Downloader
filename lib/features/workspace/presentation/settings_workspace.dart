import 'dart:async';
import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../library/application/library_controller.dart';
import 'workspace_components.dart';

class SettingsWorkspace extends StatelessWidget {
  const SettingsWorkspace(
      {super.key, required this.controller, required this.onConnections});
  final LibraryController controller;
  final VoidCallback? onConnections;
  @override
  Widget build(BuildContext context) =>
      ListView(primary: false, padding: EdgeInsets.zero, children: [
        const Text('Preferências e comportamento do aplicativo',
            style: TextStyle(fontSize: 12, color: AppColors.muted)),
        const SizedBox(height: 16),
        WorkspacePanel(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Qualidade preferencial',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.muted)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                      initialValue: 'source',
                      isExpanded: true,
                      decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide:
                                  const BorderSide(color: AppColors.line)),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide:
                                  const BorderSide(color: AppColors.line)),
                          disabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide:
                                  const BorderSide(color: AppColors.line))),
                      items: const [
                        DropdownMenuItem(
                            value: 'source',
                            child: Text('Melhor disponível',
                                style: TextStyle(fontSize: 13)))
                      ],
                      onChanged: null),
                  const SizedBox(height: 8),
                  const Text(
                      'Conforme a fonte. Alterar qualidade e conversão ainda não está disponível.',
                      style: TextStyle(fontSize: 11, color: AppColors.muted)),
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 14),
                  _row('Pasta padrão de downloads', () => _folder(context)),
                  _row(
                      'Formatos e conversão',
                      () => _info(context, 'Formatos e conversão',
                          'O fluxo musical atual salva MP3 com capa e playlist M3U8. A qualidade depende da fonte. Outros formatos de saída e controles de conversão ainda não estão disponíveis. DLC, CCF, RSDF, Metalink, Meta4, NZB e SFDL seguem planejados.')),
                  _row(
                      'Limite de downloads simultâneos',
                      () => _info(context, 'Downloads simultâneos',
                          'Uma transferência por vez. Alterar concorrência ou limitar velocidade ainda não está disponível.')),
                  _row('Contas conectadas', onConnections),
                  _row(
                      'Notificações',
                      () => _info(context, 'Notificações',
                          'O progresso aparece no aplicativo. Notificações do sistema ainda não estão disponíveis.')),
                  _row(
                      'Preferências de captura',
                      () => _info(context, 'Preferências de captura',
                          'A análise de páginas, extração de áudio e captura de vídeos e imagens ainda não estão integradas.')),
                  _row(
                      'Dados locais e histórico',
                      () => _info(context, 'Dados locais e histórico',
                          'Coleções, fontes e histórico ficam neste dispositivo. Atualizar a interface preserva os dados e os arquivos existentes.')),
                ])),
      ]);
  Widget _row(String label, VoidCallback? onTap) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: WorkspacePanel(
          child: ListTile(
              dense: true,
              title: Text(label, style: const TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: onTap)));
  void _info(BuildContext context, String title, String message) =>
      unawaited(showDialog<void>(
          context: context,
          builder: (context) =>
              AlertDialog(
                  title: Text(title),
                  content: SingleChildScrollView(
                      child:
                          Text(message, style: const TextStyle(height: 1.6))),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Fechar'))
                  ])));
  void _folder(BuildContext context) => unawaited(showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
              title: const Text('Pasta padrão de downloads'),
              content: SizedBox(
                  width: 450,
                  child: SingleChildScrollView(
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        SelectableText(controller.outputDirectory),
                        const SizedBox(height: 14),
                        const Text(
                            'Novos downloads usarão esta pasta. Arquivos existentes permanecem no local atual.',
                            style: TextStyle(fontSize: 12, height: 1.6))
                      ]))),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Fechar')),
                OutlinedButton(
                    onPressed: controller.busy
                        ? null
                        : () {
                            Navigator.pop(context);
                            unawaited(controller.chooseOutput());
                          },
                    child: const Text('Escolher pasta'))
              ])));
}

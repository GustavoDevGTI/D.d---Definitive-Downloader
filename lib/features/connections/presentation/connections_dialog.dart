import 'dart:async';
import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../application/spotify_connection_controller.dart';
import '../application/deezer_connection_controller.dart';
import 'deezer_connection_pane.dart';

class ConnectionsDialog extends StatelessWidget {
  const ConnectionsDialog(
      {super.key,
      required this.controller,
      this.allowChanges = true,
      this.deezer});
  final DeezerConnectionController? deezer;
  final SpotifyConnectionController controller;
  final bool allowChanges;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: controller,
      builder: (context, _) => AlertDialog(
            title: const Text('Conexões'),
            content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                    child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Spotify',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    Text(controller.isConnected
                        ? 'Conectado: ${controller.displayName}'
                        : 'Conecte sua conta para importar playlists próprias ou colaborativas.'),
                    const SizedBox(height: 10),
                    const Text(
                        'Acesso solicitado: leitura de playlists. O login abre no navegador oficial.',
                        style: TextStyle(fontSize: 12, color: AppColors.muted)),
                    const SizedBox(height: 18),
                    if (controller.busy) ...[
                      const LinearProgressIndicator(minHeight: 2),
                      const SizedBox(height: 12),
                      if (controller.status ==
                          SpotifyConnectionStatus.authorizing)
                        TextButton(
                            onPressed: controller.cancel,
                            child: const Text('Cancelar conexão')),
                    ] else if (controller.isConnected)
                      OutlinedButton(
                          onPressed: allowChanges
                              ? () => unawaited(controller.disconnect())
                              : null,
                          child: const Text('Desconectar deste dispositivo'))
                    else
                      FilledButton(
                          onPressed:
                              allowChanges && controller.authorization.supported
                                  ? () => unawaited(controller.connect())
                                  : null,
                          child: const Text('Conectar Spotify')),
                    if (!controller.authorization.supported) ...[
                      const SizedBox(height: 10),
                      const Text(
                          'O login ainda não foi configurado nesta plataforma.'),
                    ],
                    if (controller.message.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      SelectableText(controller.message,
                          style: const TextStyle(fontSize: 12)),
                    ],
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 12),
                    if (deezer != null) ...[
                      DeezerConnectionPane(
                          controller: deezer!, allowChanges: allowChanges),
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 12),
                    ],
                    const Text('YouTube Music',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    const Text(
                        'Busca de faixas musicais sem conta. Videoclipes não são aceitos. Vincular Google para transferir playlists será uma função separada.',
                        style: TextStyle(fontSize: 12, color: AppColors.muted)),
                  ],
                ))),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Fechar'))
            ],
          ));
}

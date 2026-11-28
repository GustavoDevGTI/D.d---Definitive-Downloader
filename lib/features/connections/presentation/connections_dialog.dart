import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../application/trackhop_connection.dart';
import '../application/deezer_connection_controller.dart';
import '../../audio_capture/data/capture_sessions.dart';
import '../../audio_capture/presentation/capture_connections_pane.dart';
import 'deezer_connection_pane.dart';
import 'trackhop_connection_pane.dart';

class ConnectionsDialog extends StatelessWidget {
  const ConnectionsDialog(
      {super.key,
      required this.controller,
      this.allowChanges = true,
      this.deezer,
      this.captureSessions});
  final DeezerConnectionController? deezer;
  final CaptureSessionStore? captureSessions;
  final TrackhopConnection controller;
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
                    TrackhopConnectionPane(
                        connection: controller, allowChanges: allowChanges),
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
                        'Alternativa à Deezer quando houver áudio disponível. Login Google ainda não está configurado.',
                        style: TextStyle(fontSize: 12, color: AppColors.muted)),
                    if (captureSessions != null) ...[
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 12),
                      CaptureConnectionsPane(
                          sessions: captureSessions!,
                          allowChanges: allowChanges),
                    ],
                  ],
                ))),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Fechar'))
            ],
          ));
}

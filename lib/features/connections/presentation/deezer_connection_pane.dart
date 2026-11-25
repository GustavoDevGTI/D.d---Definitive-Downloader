import 'package:flutter/material.dart';
import '../application/deezer_connection_controller.dart';
import 'deezer_login_dialog.dart';

class DeezerConnectionPane extends StatelessWidget {
  const DeezerConnectionPane(
      {super.key, required this.controller, required this.allowChanges});
  final DeezerConnectionController controller;
  final bool allowChanges;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: controller,
      builder: (context, _) =>
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Deezer',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Text(controller.connected
                ? 'Conta conectada neste dispositivo'
                : 'Fonte principal de download'),
            const SizedBox(height: 12),
            DeezerConnectionButton(
                controller: controller, allowChanges: allowChanges),
            if (controller.message.isNotEmpty)
              Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(controller.message,
                      style: const TextStyle(fontSize: 12))),
          ]));
}

class DeezerConnectionButton extends StatelessWidget {
  const DeezerConnectionButton(
      {super.key, required this.controller, this.allowChanges = true});
  final DeezerConnectionController controller;
  final bool allowChanges;

  @override
  Widget build(BuildContext context) {
    if (controller.connected) {
      return OutlinedButton(
          onPressed:
              !controller.busy && allowChanges ? controller.disconnect : null,
          child: const Text('Desconectar Deezer'));
    }
    return FilledButton(
        onPressed:
            !controller.busy && allowChanges && controller.engine.available
                ? () => controller.login(() => showDeezerLogin(context,
                    verifySession: controller.verifyLoginSession))
                : null,
        child: Text(controller.busy ? 'Conectando…' : 'Entrar na Deezer'));
  }
}

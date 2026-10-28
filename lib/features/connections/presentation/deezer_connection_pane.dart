import 'package:flutter/material.dart';
import '../application/deezer_connection_controller.dart';

class DeezerConnectionPane extends StatefulWidget {
  const DeezerConnectionPane(
      {super.key, required this.controller, required this.allowChanges});
  final DeezerConnectionController controller;
  final bool allowChanges;
  @override
  State<DeezerConnectionPane> createState() => _DeezerConnectionPaneState();
}

class _DeezerConnectionPaneState extends State<DeezerConnectionPane> {
  final _session = TextEditingController();
  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final c = widget.controller;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Deezer',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Text(c.connected
              ? 'Conta conectada neste dispositivo'
              : 'Conecte uma sessão da sua conta para tentar faixas completas.'),
          const SizedBox(height: 10),
          if (!c.connected) ...[
            const Text(
                'Informe o ARL somente aqui. A sessão é guardada no cofre do sistema; não envie esse valor pelo chat.',
                style: TextStyle(fontSize: 12)),
            const SizedBox(height: 12),
            TextField(
                controller: _session,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                enabled: !c.busy && widget.allowChanges,
                decoration:
                    const InputDecoration(labelText: 'Sessão Deezer (ARL)')),
            const SizedBox(height: 12),
            FilledButton(
                onPressed: !c.busy && widget.allowChanges && c.engine.available
                    ? () async {
                        await c.connect(_session.text);
                        if (mounted && c.connected) _session.clear();
                      }
                    : null,
                child: Text(c.busy ? 'Conferindo…' : 'Conectar Deezer')),
          ] else
            OutlinedButton(
                onPressed: !c.busy && widget.allowChanges ? c.disconnect : null,
                child: const Text('Desconectar Deezer deste dispositivo')),
          if (c.message.isNotEmpty)
            Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(c.message, style: const TextStyle(fontSize: 12))),
          if (!c.engine.available)
            const Text('Motor musical ainda não disponível nesta instalação.'),
        ]);
      });
}

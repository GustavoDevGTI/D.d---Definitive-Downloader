import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../application/trackhop_connection.dart';

class TrackhopConnectionPane extends StatefulWidget {
  const TrackhopConnectionPane(
      {super.key, required this.connection, this.allowChanges = true});
  final TrackhopConnection connection;
  final bool allowChanges;

  @override
  State<TrackhopConnectionPane> createState() => _TrackhopConnectionPaneState();
}

class _TrackhopConnectionPaneState extends State<TrackhopConnectionPane> {
  late final _address = TextEditingController(text: widget.connection.address);
  final _token = TextEditingController();

  @override
  void dispose() {
    _address.dispose();
    _token.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: widget.connection,
      builder: (context, _) {
        final connection = widget.connection;
        final enabled = widget.allowChanges && !connection.busy;
        return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  connection.isConnected
                      ? 'Spotify conectado pelo Trackhop'
                      : 'Spotify pelo Trackhop',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (!connection.isConnected) ...[
                Text(connection.localDesktop
                    ? 'No Trackhop Desktop, conecte Spotify (web) e gere um token em Ferramentas → API.'
                    : 'Use seu servidor Trackhop com Spotify (web) conectado. Você também pode exportar um CSV no Trackhop Android e abrir o arquivo no D.d.'),
                TextButton(
                    onPressed: () => launchUrl(
                        Uri.https(
                            'trackhop.org',
                            connection.localDesktop
                                ? '/guide/desktop'
                                : '/guide/export-playlist-csv'),
                        mode: LaunchMode.externalApplication),
                    child: const Text('Guia do Trackhop')),
                TextField(
                    controller: _address,
                    enabled: enabled,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    decoration: const InputDecoration(
                        labelText: 'Endereço do Trackhop')),
                const SizedBox(height: 10),
                TextField(
                    controller: _token,
                    enabled: enabled,
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration:
                        const InputDecoration(labelText: 'Token do Trackhop')),
                const SizedBox(height: 12),
                FilledButton(
                    onPressed: enabled
                        ? () async {
                            await connection.connect(
                                _address.text, _token.text);
                            if (mounted && connection.isConnected) {
                              _token.clear();
                            }
                          }
                        : null,
                    child: const Text('Conectar Trackhop')),
              ] else
                OutlinedButton(
                    onPressed: enabled ? connection.disconnect : null,
                    child: const Text('Desconectar Trackhop')),
              if (connection.busy) const LinearProgressIndicator(minHeight: 2),
              if (connection.message.isNotEmpty)
                Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(connection.message)),
            ]);
      });
}

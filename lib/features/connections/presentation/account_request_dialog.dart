import 'package:flutter/material.dart';
import '../application/trackhop_connection.dart';
import '../application/deezer_connection_controller.dart';
import '../domain/music_account.dart';
import 'deezer_connection_pane.dart';
import 'trackhop_connection_pane.dart';

class AccountRequestDialog extends StatefulWidget {
  const AccountRequestDialog(
      {super.key,
      required this.account,
      required this.trackhop,
      required this.deezer,
      this.allowLater = false});
  final MusicAccount account;
  final TrackhopConnection trackhop;
  final DeezerConnectionController deezer;
  final bool allowLater;
  @override
  State<AccountRequestDialog> createState() => _AccountRequestDialogState();
}

class _AccountRequestDialogState extends State<AccountRequestDialog> {
  late final _changes = Listenable.merge([widget.trackhop, widget.deezer]);
  bool _closing = false;
  @override
  void initState() {
    super.initState();
    _changes.addListener(_changed);
  }

  @override
  void dispose() {
    _changes.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (!mounted || _closing) return;
    final connected = widget.account == MusicAccount.spotify
        ? widget.trackhop.isConnected
        : widget.deezer.connected;
    if (connected) {
      _closing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ModalRoute.of(context)?.isCurrent == true) {
          Navigator.pop(context, MusicAccountDecision.connected);
        }
      });
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: Text(widget.account == MusicAccount.spotify
              ? 'Conectar Trackhop'
              : 'Conectar ${widget.account.label}'),
          content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                  child: widget.account == MusicAccount.deezer
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                              DeezerConnectionPane(
                                  controller: widget.deezer,
                                  allowChanges: true),
                              if (widget.allowLater)
                                const Padding(
                                    padding: EdgeInsets.only(top: 12),
                                    child: Text(
                                        'Você pode importar pelo Spotify e conectar o Deezer depois.')),
                            ])
                      : TrackhopConnectionPane(connection: widget.trackhop))),
          actions: [
            TextButton(
                onPressed: () =>
                    Navigator.pop(context, MusicAccountDecision.cancelled),
                child: const Text('Cancelar')),
            if (widget.account == MusicAccount.deezer && widget.allowLater)
              TextButton(
                  onPressed: widget.deezer.busy || _closing
                      ? null
                      : () =>
                          Navigator.pop(context, MusicAccountDecision.later),
                  child: const Text('Fazer login depois')),
          ]);
}

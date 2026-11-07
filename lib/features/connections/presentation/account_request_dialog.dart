import 'dart:async';
import 'package:flutter/material.dart';
import '../application/spotify_connection_controller.dart';
import '../application/deezer_connection_controller.dart';
import '../domain/music_account.dart';
import 'deezer_connection_pane.dart';

class AccountRequestDialog extends StatefulWidget {
  const AccountRequestDialog(
      {super.key,
      required this.account,
      required this.spotify,
      required this.deezer});
  final MusicAccount account;
  final SpotifyConnectionController spotify;
  final DeezerConnectionController deezer;
  @override
  State<AccountRequestDialog> createState() => _AccountRequestDialogState();
}

class _AccountRequestDialogState extends State<AccountRequestDialog> {
  late final _changes = Listenable.merge([widget.spotify, widget.deezer]);
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
        ? widget.spotify.isConnected
        : widget.deezer.connected;
    if (connected) {
      _closing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context, true);
      });
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: Text('Conectar ${widget.account.label}'),
          content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                  child: widget.account == MusicAccount.deezer
                      ? DeezerConnectionPane(
                          controller: widget.deezer, allowChanges: true)
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                              const Text('Entre para importar sua playlist.'),
                              const SizedBox(height: 16),
                              FilledButton(
                                  onPressed: widget.spotify.busy
                                      ? null
                                      : () =>
                                          unawaited(widget.spotify.connect()),
                                  child: Text(widget.spotify.busy
                                      ? 'Aguardando Spotify…'
                                      : 'Entrar no Spotify')),
                              if (widget.spotify.message.isNotEmpty)
                                Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: Text(widget.spotify.message)),
                            ]))),
          actions: [
            TextButton(
                onPressed: () {
                  if (widget.account == MusicAccount.spotify && widget.spotify.busy) {
                    widget.spotify.cancel();
                  }
                  Navigator.pop(context, false);
                },
                child: const Text('Cancelar'))
          ]);
}

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
  Widget build(BuildContext context) {
    final isDeezer = widget.account == MusicAccount.deezer;
    final canDefer = isDeezer && widget.allowLater;
    return AlertDialog(
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        actionsOverflowButtonSpacing: 8,
        buttonPadding: const EdgeInsets.symmetric(horizontal: 4),
        title: Text(widget.account == MusicAccount.spotify
            ? 'Conectar Trackhop'
            : 'Conectar ${widget.account.label}'),
        content: SizedBox(
            width: isDeezer ? 360 : 420,
            child: SingleChildScrollView(
                child: isDeezer
                    ? Semantics(
                        liveRegion: true,
                        child: Text(
                            widget.deezer.message.isEmpty
                                ? 'Use sua conta para buscar e baixar músicas.'
                                : widget.deezer.message,
                            style: TextStyle(
                                color: widget.deezer.message.isNotEmpty &&
                                        !widget.deezer.busy &&
                                        !widget.deezer.connected
                                    ? Theme.of(context).colorScheme.error
                                    : Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant)))
                    : TrackhopConnectionPane(connection: widget.trackhop))),
        actions: [
          TextButton(
              onPressed: canDefer && (widget.deezer.busy || _closing)
                  ? null
                  : () => Navigator.pop(
                      context,
                      canDefer
                          ? MusicAccountDecision.later
                          : MusicAccountDecision.cancelled),
              child: Text(canDefer ? 'Deixar para mais tarde' : 'Cancelar')),
          if (isDeezer)
            DeezerConnectionButton(
                controller: widget.deezer, allowChanges: !_closing),
        ]);
  }
}

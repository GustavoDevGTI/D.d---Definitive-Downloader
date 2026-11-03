import 'dart:async';
import 'package:flutter/material.dart';

Future<void> showAppNotice(BuildContext context,
        {String title = 'Aviso', required String message}) =>
    showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
              key: const ValueKey('app-notice'),
              title: Text(title),
              content: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: SingleChildScrollView(child: Text(message))),
              actions: [
                FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'))
              ],
            ));

// Present settled results once, after the current frame. Progress is excluded
// by readMessage; local form dialogs acknowledge the errors they already show.
class AppNoticeHost extends StatefulWidget {
  const AppNoticeHost(
      {super.key,
      required this.listenable,
      required this.readMessage,
      required this.acknowledge,
      required this.child});
  final Listenable listenable;
  final String Function() readMessage;
  final ValueChanged<String> acknowledge;
  final Widget child;
  @override
  State<AppNoticeHost> createState() => _AppNoticeHostState();
}

class _AppNoticeHostState extends State<AppNoticeHost> {
  bool _scheduled = false, _visible = false;
  @override
  void initState() {
    super.initState();
    widget.listenable.addListener(_schedule);
    _schedule();
  }

  @override
  void didUpdateWidget(covariant AppNoticeHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.listenable != widget.listenable) {
      oldWidget.listenable.removeListener(_schedule);
      widget.listenable.addListener(_schedule);
    }
    _schedule();
  }

  void _schedule() {
    if (_scheduled || _visible) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted || _visible) return;
      final message = widget.readMessage();
      if (message.isEmpty) return;
      _visible = true;
      widget.acknowledge(message);
      unawaited(_present(message));
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _present(String message) async {
    try {
      await showAppNotice(context, message: message);
    } finally {
      if (mounted) {
        _visible = false;
        _schedule();
      }
    }
  }

  @override
  void dispose() {
    widget.listenable.removeListener(_schedule);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

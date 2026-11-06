import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/platform/android_incoming.dart';
import '../../../app/app_notice.dart';
import '../application/library_controller.dart';
import '../application/shared_music_links.dart';
import 'add_music_links_dialog.dart';

/// A single review route; external intents never confirm a source or start work.
class IncomingMusicHost extends StatefulWidget {
  const IncomingMusicHost(
      {super.key,
      required this.incoming,
      required this.library,
      required this.child});
  final AndroidIncoming incoming;
  final LibraryController library;
  final Widget child;
  @override
  State<IncomingMusicHost> createState() => _IncomingMusicHostState();
}

class _IncomingMusicHostState extends State<IncomingMusicHost> {
  bool _checking = false;
  Timer? _retry;
  @override
  void initState() {
    super.initState();
    widget.incoming.addListener(_schedule);
    WidgetsBinding.instance.addPostFrameCallback((_) => _schedule());
  }

  void _schedule() {
    if (!mounted || _checking) return;
    _retry?.cancel();
    _retry = Timer(const Duration(milliseconds: 300), _review);
  }

  Future<void> _review() async {
    if (!mounted || _checking) return;
    if (widget.library.reorderingBusy ||
        ModalRoute.of(context)?.isCurrent != true) {
      _retry = Timer(const Duration(seconds: 2), _review);
      return;
    }
    _checking = true;
    try {
      final item = await widget.incoming.peek();
      if (!mounted || item == null) return;
      if (item.error.isNotEmpty) {
        await showAppNotice(context, message: item.error);
      } else {
        await showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (_) => AddMusicLinksDialog(
                controller: widget.library,
                initialText: sharedMusicLinks(item.text),
                localFiles: item.files,
                received: true));
      }
      await widget.incoming.finish(item.id);
      if (mounted) _retry = Timer(const Duration(milliseconds: 300), _review);
    } catch (_) {
      if (mounted) {
        await showAppNotice(context,
            message:
                'Não foi possível revisar o compartilhamento. Ele permanece na caixa de entrada.');
      }
    } finally {
      _checking = false;
    }
  }

  @override
  void dispose() {
    _retry?.cancel();
    widget.incoming.removeListener(_schedule);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

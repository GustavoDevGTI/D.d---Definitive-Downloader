import 'dart:async';
import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../data/capture_sessions.dart';
import '../domain/capture_login.dart';
import 'capture_login_dialog.dart';

/// Accounts of the platforms whose posts may ask for login in Capturar áudio.
class CaptureConnectionsPane extends StatefulWidget {
  const CaptureConnectionsPane(
      {super.key, required this.sessions, this.allowChanges = true});
  final CaptureSessionStore sessions;
  final bool allowChanges;
  @override
  State<CaptureConnectionsPane> createState() => _CaptureConnectionsPaneState();
}

class _CaptureConnectionsPaneState extends State<CaptureConnectionsPane> {
  final _signedIn = <CapturePlatform>{};
  CapturePlatform? _busy;
  String _message = '';

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    for (final platform in CapturePlatform.values) {
      try {
        if (await widget.sessions.read(platform) != null) {
          _signedIn.add(platform);
        }
      } catch (_) {/* An unreadable vault entry is treated as signed out. */}
    }
    if (mounted) setState(() {});
  }

  Future<void> _signIn(CapturePlatform platform) async {
    setState(() {
      _busy = platform;
      _message = '';
    });
    try {
      // Without a post to check, the session cookie on the platform's own page
      // is the confirmation; the capture checks the content later.
      final session =
          await showCaptureLogin(context, platform, (_) async => true);
      if (session != null) {
        await widget.sessions.write(platform, session);
        _signedIn.add(platform);
        _message = 'Conta do ${platform.label} conectada neste dispositivo.';
      }
    } catch (_) {
      _message = 'Não foi possível concluir o login no ${platform.label}.';
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _signOut(CapturePlatform platform) async {
    setState(() => _busy = platform);
    try {
      await widget.sessions.clear(platform);
      _signedIn.remove(platform);
      _message = 'Sessão do ${platform.label} removida deste dispositivo.';
    } catch (_) {
      _message = 'Não foi possível remover a sessão do ${platform.label}.';
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Captura de áudio',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        const Text(
            'Posts públicos não pedem conta. O login abre sozinho quando um post exigir.',
            style: TextStyle(fontSize: 12, color: AppColors.muted)),
        const SizedBox(height: 8),
        for (final platform in CapturePlatform.values)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: LayoutBuilder(builder: (context, constraints) {
                final status = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(platform.label,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                          _signedIn.contains(platform)
                              ? 'Conectado neste dispositivo'
                              : 'Não conectado',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.muted)),
                    ]);
                final action = _action(platform);
                // Narrow phones put the button under the platform name.
                if (constraints.maxWidth < 360) {
                  return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [status, const SizedBox(height: 6), action]);
                }
                return Row(children: [
                  Expanded(child: status),
                  const SizedBox(width: 12),
                  action,
                ]);
              })),
        if (_message.isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_message, style: const TextStyle(fontSize: 12))),
      ]);

  Widget _action(CapturePlatform platform) => _signedIn.contains(platform)
      ? OutlinedButton(
          key: ValueKey('capture-connection-out-${platform.name}'),
          onPressed: _busy == null && widget.allowChanges
              ? () => unawaited(_signOut(platform))
              : null,
          child: Text('Sair do ${platform.label}'))
      : FilledButton(
          key: ValueKey('capture-connection-in-${platform.name}'),
          onPressed: _busy == null && widget.allowChanges
              ? () => unawaited(_signIn(platform))
              : null,
          child: Text(_busy == platform
              ? 'Conectando…'
              : 'Entrar no ${platform.label}'));
}

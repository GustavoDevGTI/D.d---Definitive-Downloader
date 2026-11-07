import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../application/music_account_access.dart';
import '../domain/music_account.dart';

class MusicConnectionsScope extends InheritedWidget {
  const MusicConnectionsScope(
      {super.key, required this.access, required super.child});
  final MusicAccountAccess? access;
  static MusicAccountAccess? of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<MusicConnectionsScope>()
      ?.access;
  @override
  bool updateShouldNotify(MusicConnectionsScope oldWidget) => true;
}

/// Only disconnected, implemented connections appear; no placeholder logins.
class MusicConnectionActions extends StatelessWidget {
  const MusicConnectionActions({super.key, this.onConnected});
  final Future<void> Function()? onConnected;
  @override
  Widget build(BuildContext context) {
    final access = MusicConnectionsScope.of(context);
    if (access == null) return const SizedBox.shrink();
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (final account in MusicAccount.values)
        if (!access.connected(account))
          Padding(
              padding: const EdgeInsets.only(left: 6),
              child: IconButton.outlined(
                  tooltip: 'Entrar no ${account.label} · ampliar busca',
                  onPressed: () async {
                    if (await access.connect(account)) {
                      await onConnected?.call();
                    }
                  },
                  style: IconButton.styleFrom(
                      foregroundColor: AppColors.accentActive,
                      side: const BorderSide(color: AppColors.line)),
                  icon: _ProviderMark(account: account))),
    ]);
  }
}

class _ProviderMark extends StatelessWidget {
  const _ProviderMark({required this.account});
  final MusicAccount account;
  @override
  Widget build(BuildContext context) => Semantics(
      label: account.label,
      child: SizedBox(
          width: 22,
          height: 22,
          child: CustomPaint(
              painter: _MarkPainter(account,
                  IconTheme.of(context).color ?? AppColors.accentActive))));
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter(this.account, this.color);
  final MusicAccount account;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1.7
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    if (account == MusicAccount.spotify) {
      canvas.drawCircle(const Offset(11, 11), 9, p);
      for (var i = 0; i < 3; i++) {
        canvas.drawPath(
            Path()
              ..moveTo(5.5 + i * .7, 7 + i * 4)
              ..quadraticBezierTo(11, 5.5 + i * 4, 17 - i * .7, 9 + i * 3),
            p);
      }
    } else {
      p.style = PaintingStyle.fill;
      for (var col = 0; col < 5; col++) {
        for (var row = 0; row < [2, 3, 4, 3, 5][col]; row++) {
          canvas.drawRect(Rect.fromLTWH(2 + col * 4, 19 - row * 3, 3, 2), p);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_MarkPainter old) =>
      old.account != account || old.color != color;
}

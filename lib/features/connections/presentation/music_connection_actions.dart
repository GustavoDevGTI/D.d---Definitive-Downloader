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

/// Offers the Deezer connection while it can expand the music search.
class MusicConnectionActions extends StatelessWidget {
  const MusicConnectionActions({super.key, this.onConnected});
  final Future<void> Function()? onConnected;
  @override
  Widget build(BuildContext context) {
    final access = MusicConnectionsScope.of(context);
    if (access == null || access.connected(MusicAccount.deezer)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: IconButton.outlined(
        tooltip: 'Entrar no Deezer · ampliar busca',
        onPressed: () async {
          if (await access.connect(MusicAccount.deezer)) {
            await onConnected?.call();
          }
        },
        style: IconButton.styleFrom(
            foregroundColor: AppColors.accentActive,
            side: const BorderSide(color: AppColors.line)),
        icon: const _DeezerMark(),
      ),
    );
  }
}

class _DeezerMark extends StatelessWidget {
  const _DeezerMark();
  @override
  Widget build(BuildContext context) => Semantics(
      label: MusicAccount.deezer.label,
      child: SizedBox(
          width: 22,
          height: 22,
          child: CustomPaint(
              painter: _DeezerMarkPainter(
                  IconTheme.of(context).color ?? AppColors.accentActive))));
}

class _DeezerMarkPainter extends CustomPainter {
  const _DeezerMarkPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const barHeights = [2, 3, 4, 3, 5];
    for (var col = 0; col < barHeights.length; col++) {
      for (var row = 0; row < barHeights[col]; row++) {
        canvas.drawRect(Rect.fromLTWH(2 + col * 4, 19 - row * 3, 3, 2), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DeezerMarkPainter old) => old.color != color;
}

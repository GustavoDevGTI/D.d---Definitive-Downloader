import 'package:flutter/material.dart';
import '../core/app_identity.dart';
import 'brand_paths.dart';
import 'theme.dart';

enum BrandTone { primary, monochrome, soft, outline }

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 40, this.tone = BrandTone.primary});
  final double size;
  final BrandTone tone;

  @override
  Widget build(BuildContext context) => Semantics(
      image: true,
      label: AppIdentity.name,
      child: CustomPaint(
          size: Size.square(size), painter: BrandMarkPainter(tone)));
}

class BrandMarkPainter extends CustomPainter {
  const BrandMarkPainter(this.tone);
  final BrandTone tone;

  @override
  void paint(Canvas canvas, Size size) {
    final background = switch (tone) {
      BrandTone.primary => AppColors.accent,
      BrandTone.monochrome => AppColors.navigation,
      BrandTone.soft => AppColors.accentSoft,
      BrandTone.outline => Colors.white,
    };
    final foreground = switch (tone) {
      BrandTone.primary || BrandTone.monochrome => Colors.white,
      BrandTone.soft || BrandTone.outline => AppColors.accent,
    };
    canvas.save();
    canvas.scale(size.width, size.height);
    final shape = RRect.fromRectAndRadius(
        const Rect.fromLTWH(1 / 236, 1 / 236, 234 / 236, 234 / 236),
        const Radius.circular(49 / 236));
    canvas.drawRRect(shape, Paint()..color = background);
    if (tone == BrandTone.outline) {
      canvas.drawRRect(
          shape,
          Paint()
            ..color = AppColors.line
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2 / 236);
    }
    canvas.drawPath(BrandPaths.glyph, Paint()..color = foreground);
    canvas.restore();
  }

  @override
  bool shouldRepaint(BrandMarkPainter oldDelegate) => tone != oldDelegate.tone;
}

class BrandLockup extends StatelessWidget {
  const BrandLockup(
      {super.key,
      this.stacked = false,
      this.markSize = 40,
      this.fontSize = 18,
      this.monochrome = false,
      this.inverse = false});
  final bool stacked;
  final bool monochrome;
  final bool inverse;
  final double markSize, fontSize;

  @override
  Widget build(BuildContext context) => Semantics(
      image: true,
      label: AppIdentity.name,
      child: ExcludeSemantics(
          child: Row(mainAxisSize: MainAxisSize.min, children: [
        BrandMark(
            size: markSize,
            tone: monochrome ? BrandTone.monochrome : BrandTone.primary),
        const SizedBox(width: 10),
        Flexible(
            child: Text.rich(
                TextSpan(children: [
                  const TextSpan(text: 'Definitive'),
                  TextSpan(
                      text: stacked ? '\nDownloader' : ' Downloader',
                      style: TextStyle(
                          color: inverse
                              ? Colors.white
                              : monochrome
                                  ? AppColors.navigation
                                  : AppColors.accent)),
                ]),
                style: TextStyle(
                    color: inverse ? Colors.white : AppColors.navigation,
                    fontSize: fontSize,
                    fontWeight: FontWeight.w700,
                    height: 1.12,
                    letterSpacing: -.4))),
      ])));
}

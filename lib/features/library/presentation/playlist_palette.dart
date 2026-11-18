import 'package:flutter/material.dart';
import '../../../app/theme.dart';

Color playlistInk(Color? accent) {
  if (accent == null) return AppColors.accentActive;
  // Keep text legible even with very bright custom colors or selected rows.
  final surface = Color.alphaBlend(accent.withAlpha(82), Colors.white);
  final luminance = surface.computeLuminance();
  var ink = accent;
  while ((luminance + .05) / (ink.computeLuminance() + .05) < 4.5) {
    ink = Color.lerp(ink, Colors.black, .18)!;
  }
  return ink;
}

Color playlistReviewSurface(Color? accent, {bool selected = false}) =>
    accent == null
        ? selected
            ? Color.lerp(AppColors.accentSoft, AppColors.accent, .12)!
            : AppColors.accentSoft
        : Color.alphaBlend(accent.withAlpha(selected ? 82 : 60), Colors.white);

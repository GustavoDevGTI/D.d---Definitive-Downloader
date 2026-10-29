import 'package:flutter/material.dart';

abstract final class AppColors {
  // Exact brand palette supplied by the user, 29/10/2026.
  static const background = Color(0xFFFAFAFC);
  static const surface = Color(0xFFF3F4F6);
  static const ink = Color(0xFF1E293B);
  static const muted = Color(0xFF6B7280);
  static const line = Color(0xFFE5E7EB);
  static const accent = Color(0xFFC9345B);
  static const accentActive = Color(0xFFA01F45);
  static const accentSoft = Color(0xFFFDE7ED);
  static const navigation = Color(0xFF23273F);
  static const secondary = Color(0xFF5B6B85);
  static const music = secondary;
  static const musicSoft = surface;
  static const success = Color(0xFF326B5D);
}

ThemeData appTheme() {
  final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.light,
      primary: AppColors.accent,
      onPrimary: Colors.white,
      primaryContainer: AppColors.accentSoft,
      onPrimaryContainer: AppColors.accentActive,
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.surface,
      onSecondaryContainer: AppColors.navigation,
      tertiary: AppColors.navigation,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.muted,
      outline: AppColors.secondary,
      outlineVariant: AppColors.line,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: AppColors.background,
      surfaceContainer: AppColors.surface,
      surfaceContainerHigh: AppColors.surface,
      surfaceContainerHighest: AppColors.line,
      surfaceTint: Colors.transparent);
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Manrope',
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    textTheme: const TextTheme(
        bodyMedium: TextStyle(fontSize: 13, color: AppColors.ink),
        bodySmall: TextStyle(fontSize: 11, color: AppColors.muted)),
    dividerColor: AppColors.line,
    dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1),
    visualDensity: VisualDensity.compact,
    checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
        side: const BorderSide(color: AppColors.secondary, width: 1.2)),
    filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(
                    fontFamily: 'Manrope',
                    fontWeight: FontWeight.w600,
                    fontSize: 12))
            .copyWith(
                backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return null;
      return states.any((state) => const {
                WidgetState.hovered,
                WidgetState.focused,
                WidgetState.pressed,
                WidgetState.selected
              }.contains(state))
          ? AppColors.accentActive
          : AppColors.accent;
    }))),
    outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.line),
            foregroundColor: AppColors.ink,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)))),
    textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
            textStyle: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 12,
                fontWeight: FontWeight.w600),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4)))),
    inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        hintStyle: const TextStyle(fontSize: 12, color: AppColors.muted),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.line)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.line)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.accent, width: 1.4))),
    tooltipTheme:
        const TooltipThemeData(waitDuration: Duration(milliseconds: 500)),
  );
}

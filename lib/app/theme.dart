import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'density.dart';
export 'density.dart';

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

ThemeData appTheme({TargetPlatform? platform}) {
  final density = AppDensity(platform ?? defaultTargetPlatform);
  final desktop = density.desktop;
  final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(density.radius));
  const controlText = TextStyle(
      fontFamily: 'Manrope', fontSize: 12, height: 1.2, fontWeight: FontWeight.w600);
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
    platform: platform,
    fontFamily: 'Manrope',
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    textTheme: TextTheme(
        bodyLarge: TextStyle(fontSize: density.body, height: 1.3, color: AppColors.ink),
        labelLarge: controlText,
        bodyMedium: TextStyle(fontSize: density.body, color: AppColors.ink),
        bodySmall: const TextStyle(fontSize: 11, color: AppColors.muted),
        titleLarge:
            TextStyle(fontSize: desktop ? 18 : 22, fontWeight: FontWeight.w600),
        titleMedium:
            const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
    iconTheme: IconThemeData(size: density.icon),
    iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
            minimumSize: Size.square(density.control),
            iconSize: density.icon,
            padding: const EdgeInsets.all(8),
            visualDensity: VisualDensity.standard,
            tapTargetSize: desktop
                ? MaterialTapTargetSize.shrinkWrap
                : MaterialTapTargetSize.padded,
            shape: buttonShape)),
    popupMenuTheme: PopupMenuThemeData(
        iconSize: density.icon,
        textStyle: const TextStyle(
            fontFamily: 'Manrope', fontSize: 12, color: AppColors.ink),
        shape: buttonShape),
    listTileTheme: ListTileThemeData(
        dense: true,
        minTileHeight: desktop ? 44 : 48,
        horizontalTitleGap: desktop ? 8 : 12,
        titleTextStyle: TextStyle(
            fontFamily: 'Manrope',
            fontSize: density.body,
            color: AppColors.ink),
        subtitleTextStyle: const TextStyle(
            fontFamily: 'Manrope', fontSize: 11, color: AppColors.muted)),
    dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(desktop ? 12 : 20)),
        titleTextStyle: TextStyle(
            fontFamily: 'Manrope',
            fontSize: desktop ? 18 : 22,
            fontWeight: FontWeight.w600,
            color: AppColors.ink),
        contentTextStyle: TextStyle(
            fontFamily: 'Manrope',
            fontSize: density.body,
            height: 1.4,
            color: AppColors.ink)),
    dividerColor: AppColors.line,
    dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1),
    visualDensity: VisualDensity.compact,
    checkboxTheme: CheckboxThemeData(
        materialTapTargetSize: desktop ? MaterialTapTargetSize.shrinkWrap : MaterialTapTargetSize.padded,
        visualDensity: desktop ? VisualDensity.compact : VisualDensity.standard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
        side: const BorderSide(color: AppColors.secondary, width: 1.2)),
    filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
                elevation: 0,
                minimumSize: Size(0, density.control),
                visualDensity: VisualDensity.standard,
                tapTargetSize: desktop
                    ? MaterialTapTargetSize.shrinkWrap
                    : MaterialTapTargetSize.padded,
                padding: EdgeInsets.symmetric(
                    horizontal: desktop ? 12 : 18, vertical: desktop ? 8 : 16),
                shape: buttonShape,
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
            minimumSize: Size(0, density.control),
            visualDensity: VisualDensity.standard,
            tapTargetSize: desktop
                ? MaterialTapTargetSize.shrinkWrap
                : MaterialTapTargetSize.padded,
            textStyle: controlText,
            padding: EdgeInsets.symmetric(
                horizontal: 12, vertical: desktop ? 8 : 14),
            shape: buttonShape)),
    textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
            minimumSize: Size(0, density.control),
            visualDensity: VisualDensity.standard,
            tapTargetSize: desktop
                ? MaterialTapTargetSize.shrinkWrap
                : MaterialTapTargetSize.padded,
            textStyle: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 12,
                fontWeight: FontWeight.w600),
            shape: buttonShape)),
    inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        constraints: BoxConstraints(minHeight: density.control),
        prefixIconConstraints: BoxConstraints(
            minWidth: density.control, minHeight: density.control),
        suffixIconConstraints: BoxConstraints(
            minWidth: density.control, minHeight: density.control),
        hintStyle: const TextStyle(fontSize: 12, color: AppColors.muted),
        contentPadding:
            EdgeInsets.symmetric(horizontal: 12, vertical: desktop ? 10 : 15),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(density.radius),
            borderSide: const BorderSide(color: AppColors.line)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(density.radius),
            borderSide: const BorderSide(color: AppColors.line)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(density.radius),
            borderSide: const BorderSide(color: AppColors.accent, width: 1.4))),
    tooltipTheme:
        const TooltipThemeData(waitDuration: Duration(milliseconds: 500)),
  );
}

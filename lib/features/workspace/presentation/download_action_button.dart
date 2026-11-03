import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../app/button_hover_motion.dart';

abstract final class DownloadActionColors {
  static const start = AppColors.success;
  static const pause = Color(0xFF91611A);
  static const stop = AppColors.accent;
  static const add = AppColors.navigation;
  static const utility = AppColors.secondary;
}

ButtonStyle downloadActionStyle(Color color,
    {bool primary = false, bool active = false}) {
  bool highlighted(Set<WidgetState> states) => states.any((s) => const {
        WidgetState.hovered,
        WidgetState.focused,
        WidgetState.pressed
      }.contains(s));
  return ButtonStyle(
    animationDuration: const Duration(milliseconds: 140),
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return color.withAlpha(165);
      return primary || active || highlighted(states) ? Colors.white : color;
    }),
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return color.withAlpha(8);
      if (highlighted(states)) return Color.lerp(color, Colors.black, .12);
      return primary || active ? color : color.withAlpha(15);
    }),
    side: WidgetStateProperty.resolveWith((states) => BorderSide(
        color: states.contains(WidgetState.disabled)
            ? color.withAlpha(74)
            : highlighted(states)
                ? color
                : color.withAlpha(125),
        width: !states.contains(WidgetState.disabled) && highlighted(states)
            ? 1.5
            : 1)),
    overlayColor: WidgetStatePropertyAll(Colors.white.withAlpha(20)),
    mouseCursor: WidgetStateProperty.resolveWith((states) =>
        states.contains(WidgetState.disabled)
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click),
  );
}

class DownloadActionButton extends StatelessWidget {
  const DownloadActionButton(
      {super.key,
      required this.icon,
      required this.label,
      required this.onPressed,
      this.description = '',
      this.color = DownloadActionColors.utility,
      this.primary = false,
      this.active = false});
  final IconData icon;
  final String label, description;
  final VoidCallback? onPressed;
  final Color color;
  final bool primary, active;
  @override
  Widget build(BuildContext context) => ButtonHoverMotion(
      builder: (states) => Semantics(
          hint: description,
          child: IconButton(
              statesController: states,
              tooltip: label,
              onPressed: onPressed,
              isSelected: active,
              style: downloadActionStyle(color,
                      primary: primary, active: active)
                  .copyWith(
                      minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
                      visualDensity: VisualDensity.standard,
                      shape: WidgetStatePropertyAll(RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)))),
              icon: Icon(icon, size: 22))));
}

import 'package:flutter/animation.dart';

/// Short, interruptible feedback for pointer-operated controls.
abstract final class AppMotion {
  static const hoverDuration = Duration(milliseconds: 150);
  static const pressDuration = Duration(milliseconds: 160);
  static const easeOut = Cubic(.23, 1, .32, 1);
  static const pressedScale = .97;
}

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Paint-only motion keeps the button's layout space and action unchanged.
class ButtonHoverMotion extends StatefulWidget {
  const ButtonHoverMotion({super.key, required this.builder});
  final Widget Function(WidgetStatesController states) builder;
  @override
  State<ButtonHoverMotion> createState() => _ButtonHoverMotionState();
}

class _ButtonHoverMotionState extends State<ButtonHoverMotion> {
  final _states = WidgetStatesController();
  bool _framePending = false;
  @override
  void initState() {
    super.initState();
    _states.addListener(_changed);
  }

  void _changed() {
    // Buttons also update disabled/selected states while building their child.
    // Defer only those notifications; pointer changes start on the next frame.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      if (_framePending) {
        return;
      }
      _framePending = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _framePending = false;
        if (mounted) setState(() {});
      });
    } else if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _states.removeListener(_changed);
    _states.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final states = _states.value;
    final disabled = states.contains(WidgetState.disabled);
    final pressed = states.contains(WidgetState.pressed);
    final highlighted = states.contains(WidgetState.hovered) ||
        states.contains(WidgetState.focused);
    return AnimatedScale(
        scale: reducedMotion || disabled
            ? 1
            : pressed
                ? .94
                : highlighted
                    ? 1.08
                    : 1,
        duration:
            reducedMotion ? Duration.zero : const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        child: widget.builder(_states));
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'motion.dart';

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
  bool _pointerPressed = false;
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
    final pressed = _pointerPressed && states.contains(WidgetState.pressed);
    // Hover and keyboard focus use the button's color feedback. Scaling dense
    // toolbars on hover crowds their neighbours and adds motion to navigation.
    return Listener(
      onPointerDown: (_) => setState(() => _pointerPressed = true),
      onPointerUp: (_) => setState(() => _pointerPressed = false),
      onPointerCancel: (_) => setState(() => _pointerPressed = false),
      child: AnimatedScale(
        scale:
            reducedMotion || disabled || !pressed ? 1 : AppMotion.pressedScale,
        duration: reducedMotion ? Duration.zero : AppMotion.pressDuration,
        curve: AppMotion.easeOut,
        child: widget.builder(_states),
      ),
    );
  }
}

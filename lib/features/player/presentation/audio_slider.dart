import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Continuous audio control without Slider's OverlayPortal. Flutter 3.47's
/// portal can serialize orphan AX nodes when routes change (#190357/#175041).
/// Keep one explicit, keyboard-accessible slider semantics node instead.
class AudioSlider extends StatefulWidget {
  const AudioSlider(
      {super.key,
      required this.value,
      required this.onChanged,
      this.onChangeEnd,
      this.max = 1,
      required this.label,
      required this.describe,
      required this.activeColor,
      this.step = .05});
  final double value, max, step;
  final String label;
  final String Function(double) describe;
  final Color activeColor;
  final ValueChanged<double>? onChanged, onChangeEnd;
  @override
  State<AudioSlider> createState() => _AudioSliderState();
}

class _AudioSliderState extends State<AudioSlider> {
  final _focus = FocusNode();
  bool _focused = false, _hovered = false;
  double? _pending;
  bool get _enabled => widget.onChanged != null && widget.max > 0;
  double bound(double v) => v.clamp(0, widget.max > 0 ? widget.max : 1);
  void _change(double v, {bool commit = false}) {
    if (!_enabled) return;
    _pending = bound(v);
    widget.onChanged!(_pending!);
    if (commit) widget.onChangeEnd?.call(_pending!);
  }

  void _pointer(Offset point, double width) {
    _focus.requestFocus();
    final fraction =
        ((point.dx - 8) / (width > 16 ? width - 16 : 1)).clamp(0.0, 1.0);
    _change(widget.max *
        (Directionality.of(context) == TextDirection.rtl
            ? 1 - fraction
            : fraction));
  }

  void _commit() {
    if (_enabled) widget.onChangeEnd?.call(_pending ?? bound(widget.value));
    _pending = null;
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (!_enabled || event is KeyUpEvent) return KeyEventResult.ignored;
    final next = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowRight ||
      LogicalKeyboardKey.arrowUp =>
        widget.value + widget.step,
      LogicalKeyboardKey.arrowLeft ||
      LogicalKeyboardKey.arrowDown =>
        widget.value - widget.step,
      LogicalKeyboardKey.home => 0.0,
      LogicalKeyboardKey.end => widget.max,
      _ => null
    };
    if (next == null) return KeyEventResult.ignored;
    _change(next, commit: true);
    return KeyEventResult.handled;
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
      container: true,
      slider: true,
      enabled: _enabled,
      focusable: _enabled,
      focused: _focused,
      label: widget.label,
      value: widget.describe(bound(widget.value)),
      increasedValue:
          _enabled ? widget.describe(bound(widget.value + widget.step)) : null,
      decreasedValue:
          _enabled ? widget.describe(bound(widget.value - widget.step)) : null,
      onIncrease: _enabled
          ? () => _change(widget.value + widget.step, commit: true)
          : null,
      onDecrease: _enabled
          ? () => _change(widget.value - widget.step, commit: true)
          : null,
      child: ExcludeSemantics(
          child: Focus(
              focusNode: _focus,
              includeSemantics: false,
              canRequestFocus: _enabled,
              onFocusChange: (v) => setState(() => _focused = v),
              onKeyEvent: _key,
              child: MouseRegion(
                  cursor: _enabled
                      ? SystemMouseCursors.click
                      : SystemMouseCursors.basic,
                  onEnter: (_) => setState(() => _hovered = true),
                  onExit: (_) => setState(() => _hovered = false),
                  child: LayoutBuilder(
                      builder: (context, box) => GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: _enabled
                              ? (d) => _pointer(d.localPosition, box.maxWidth)
                              : null,
                          onTapUp: _enabled ? (_) => _commit() : null,
                          onHorizontalDragStart: _enabled
                              ? (d) => _pointer(d.localPosition, box.maxWidth)
                              : null,
                          onHorizontalDragUpdate: _enabled
                              ? (d) => _pointer(d.localPosition, box.maxWidth)
                              : null,
                          onHorizontalDragEnd:
                              _enabled ? (_) => _commit() : null,
                          child: CustomPaint(
                              painter: _AudioTrack(
                                  fraction: widget.max > 0
                                      ? bound(widget.value) / widget.max
                                      : 0,
                                  color: widget.activeColor,
                                  enabled: _enabled,
                                  highlighted: _focused || _hovered,
                                  rtl: Directionality.of(context) ==
                                      TextDirection.rtl),
                              child:
                                  const SizedBox(height: 40, width: double.infinity))))))));
}

class _AudioTrack extends CustomPainter {
  const _AudioTrack(
      {required this.fraction,
      required this.color,
      required this.enabled,
      required this.highlighted,
      required this.rtl});
  final double fraction;
  final Color color;
  final bool enabled, highlighted, rtl;
  @override
  void paint(Canvas canvas, Size size) {
    final start = 8.0,
        end = size.width > 16 ? size.width - 8 : 8.0,
        y = size.height / 2;
    final x = start + (end - start) * (rtl ? 1 - fraction : fraction);
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = highlighted ? 4 : 3;
    canvas.drawLine(
        Offset(start, y), Offset(end, y), paint..color = Colors.white24);
    if (enabled) {
      canvas.drawLine(
          Offset(rtl ? end : start, y), Offset(x, y), paint..color = color);
      canvas.drawCircle(
          Offset(x, y), highlighted ? 5 : 4, Paint()..color = Colors.white);
    }
    if (highlighted && enabled) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(2, 2, size.width - 4, size.height - 4),
              const Radius.circular(4)),
          Paint()
            ..color = Colors.white38
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1);
    }
  }

  @override
  bool shouldRepaint(_AudioTrack old) =>
      fraction != old.fraction ||
      color != old.color ||
      enabled != old.enabled ||
      highlighted != old.highlighted ||
      rtl != old.rtl;
}

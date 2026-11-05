import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class _CtrlPan extends PanGestureRecognizer {
  @override
  bool isPointerAllowed(PointerEvent event) =>
      event.kind == PointerDeviceKind.mouse &&
      HardwareKeyboard.instance.isControlPressed &&
      super.isPointerAllowed(event);
}

/// Additive sweep selection in displayed order. The header stays outside this
/// viewport; row positions include the current scroll offset, including edges.
class CtrlDragSelection extends StatefulWidget {
  const CtrlDragSelection(
      {super.key,
      required this.scroll,
      required this.extent,
      required this.count,
      required this.onSelect,
      required this.builder,
      this.enabled = true,
      this.viewKey});
  final ScrollController scroll;
  final double extent;
  final int count;
  final ValueChanged<List<int>> onSelect;
  final Widget Function(bool controlPressed) builder;
  final bool enabled;
  final Object? viewKey;
  @override
  State<CtrlDragSelection> createState() => _CtrlDragSelectionState();
}

class _CtrlDragSelectionState extends State<CtrlDragSelection> {
  bool _control = false;
  final _key = GlobalKey();
  final _seen = <int>{};
  int? _anchor;
  Offset? _point;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _control = HardwareKeyboard.instance.isControlPressed;
    HardwareKeyboard.instance.addHandler(_keyboard);
  }

  bool _keyboard(KeyEvent event) {
    final value = HardwareKeyboard.instance.isControlPressed;
    if (value != _control && mounted) setState(() => _control = value);
    if (!value) _end();
    return false;
  }

  @override
  void didUpdateWidget(CtrlDragSelection old) {
    super.didUpdateWidget(old);
    if (old.viewKey != widget.viewKey ||
        !widget.enabled ||
        old.count != widget.count) {
      _end();
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_keyboard);
    _timer?.cancel();
    super.dispose();
  }

  int? _index(Offset point) {
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || widget.count == 0 || !widget.scroll.hasClients) {
      return null;
    }
    final y = box.globalToLocal(point).dy.clamp(0, box.size.height - .01);
    return ((y + widget.scroll.offset) / widget.extent)
        .floor()
        .clamp(0, widget.count - 1);
  }

  void _select(Offset point) {
    final end = _index(point), start = _anchor;
    if (end == null || start == null) return;
    final changed = <int>[];
    for (var i = start < end ? start : end;
        i <= (start > end ? start : end);
        i++) {
      if (_seen.add(i)) changed.add(i);
    }
    if (changed.isNotEmpty) widget.onSelect(changed);
  }

  void _end() {
    _timer?.cancel();
    _timer = null;
    _anchor = null;
    _point = null;
    _seen.clear();
  }

  void _start(DragStartDetails d) {
    _end();
    _point = d.globalPosition;
    _anchor = _index(d.globalPosition);
    _select(d.globalPosition);
    _timer = Timer.periodic(const Duration(milliseconds: 30), (_) {
      if (!mounted ||
          !widget.enabled ||
          !_control ||
          _point == null ||
          !widget.scroll.hasClients) {
        _end();
        return;
      }
      final box = _key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null) return;
      final y = box.globalToLocal(_point!).dy;
      final direction = y < 32
          ? -1
          : y > box.size.height - 32
              ? 1
              : 0;
      if (direction != 0) {
        widget.scroll.jumpTo((widget.scroll.offset + direction * 12)
            .clamp(0, widget.scroll.position.maxScrollExtent));
        _select(_point!);
      }
    });
  }

  @override
  Widget build(BuildContext context) => RawGestureDetector(
      key: _key,
      gestures: widget.enabled
          ? {
              _CtrlPan: GestureRecognizerFactoryWithHandlers<_CtrlPan>(
                  () => _CtrlPan(), (r) {
                r
                  ..dragStartBehavior = DragStartBehavior.down
                  ..onStart = _start
                  ..onUpdate = (d) {
                    _point = d.globalPosition;
                    _select(d.globalPosition);
                  }
                  ..onEnd = ((_) => _end())
                  ..onCancel = _end;
              })
            }
          : const {},
      child: widget.builder(_control));
}

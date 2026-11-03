import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../app/theme.dart';

class ColumnResizeHandle extends StatefulWidget {
  const ColumnResizeHandle(
      {super.key,
      required this.label,
      required this.width,
      required this.defaultWidth,
      required this.minimumWidth,
      this.maximumWidth = 1200,
      this.color = AppColors.line,
      required this.onResize,
      required this.onEnd});
  final String label;
  final Color color;
  final double width, defaultWidth, minimumWidth, maximumWidth;
  final ValueChanged<double> onResize;
  final VoidCallback onEnd;
  @override
  State<ColumnResizeHandle> createState() => _ColumnResizeHandleState();
}

class _ColumnResizeHandleState extends State<ColumnResizeHandle> {
  final _focus = FocusNode();
  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  bool _focused = false;
  double? _dragWidth;
  void _step(double delta) {
    widget.onResize(
        (widget.width + delta).clamp(widget.minimumWidth, widget.maximumWidth));
    widget.onEnd();
  }

  @override
  Widget build(BuildContext context) => Semantics(
      label: 'Largura de ${widget.label}',
      value: '${widget.width.round()} pixels',
      increasedValue:
          '${(widget.width + 20).clamp(widget.minimumWidth, widget.maximumWidth).round()} pixels',
      decreasedValue:
          '${(widget.width - 20).clamp(widget.minimumWidth, widget.maximumWidth).round()} pixels',
      onIncrease: () => _step(20),
      onDecrease: () => _step(-20),
      child: Tooltip(
        message: 'Redimensionar ${widget.label}',
        child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
                  _step(-20),
              const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
                  _step(20),
            },
            child: Focus(
              focusNode: _focus,
              onFocusChange: (value) => setState(() => _focused = value),
              child: MouseRegion(
                  cursor: SystemMouseCursors.resizeColumn,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _focus.requestFocus,
                    onHorizontalDragStart: (_) {
                      _focus.requestFocus();
                      _dragWidth = widget.width;
                    },
                    onHorizontalDragUpdate: (event) {
                      _dragWidth =
                          ((_dragWidth ?? widget.width) + event.delta.dx)
                              .clamp(widget.minimumWidth, widget.maximumWidth);
                      widget.onResize(_dragWidth!);
                    },
                    onHorizontalDragEnd: (_) => widget.onEnd(),
                    onHorizontalDragCancel: widget.onEnd,
                    onDoubleTap: () {
                      widget.onResize(widget.defaultWidth
                          .clamp(widget.minimumWidth, widget.maximumWidth));
                      widget.onEnd();
                    },
                    child: Container(
                        width: 22,
                        height: 40,
                        alignment: Alignment.center,
                        color: _focused
                            ? AppColors.accentSoft
                            : Colors.transparent,
                        child: Container(
                            width: 2,
                            height: 18,
                            color: _focused ? AppColors.accent : widget.color)),
                  )),
            )),
      ));
}

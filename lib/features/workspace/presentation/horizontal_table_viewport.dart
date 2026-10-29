import 'package:flutter/material.dart';

class HorizontalTableViewport extends StatefulWidget {
  const HorizontalTableViewport(
      {super.key, required this.width, required this.child});
  final double width;
  final Widget child;
  @override
  State<HorizontalTableViewport> createState() =>
      _HorizontalTableViewportState();
}

class _HorizontalTableViewportState extends State<HorizontalTableViewport> {
  final _scroll = ScrollController();
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scrollbar(
      controller: _scroll,
      thumbVisibility: true,
      notificationPredicate: (notification) =>
          notification.metrics.axis == Axis.horizontal,
      child: SingleChildScrollView(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          child: SizedBox(width: widget.width, child: widget.child)));
}

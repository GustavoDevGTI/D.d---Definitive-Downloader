import 'dart:async';
import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import '../../../app/theme.dart';
import '../application/library_controller.dart';

class CollectionMp3DropTarget extends StatefulWidget {
  const CollectionMp3DropTarget(
      {super.key,
      required this.controller,
      required this.collectionId,
      required this.child});
  final LibraryController controller;
  final int collectionId;
  final Widget child;
  @override
  State<CollectionMp3DropTarget> createState() =>
      _CollectionMp3DropTargetState();
}

class _CollectionMp3DropTargetState extends State<CollectionMp3DropTarget> {
  bool _over = false;
  @override
  Widget build(BuildContext context) => DropTarget(
      enable: !widget.controller.reorderingBusy &&
          (ModalRoute.of(context)?.isCurrent ?? true),
      onDragEntered: (_) => setState(() => _over = true),
      onDragExited: (_) => setState(() => _over = false),
      onDragDone: (details) {
        setState(() => _over = false);
        unawaited(widget.controller.addLocalFiles(
            widget.collectionId, details.files.map((f) => f.path).toList()));
      },
      child: Stack(children: [
        widget.child,
        if (_over)
          Positioned.fill(
              child: IgnorePointer(
                  child: DecoratedBox(
                      decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: .08),
                          border: Border.all(
                              color: AppColors.accentActive, width: 2),
                          borderRadius: BorderRadius.circular(12)),
                      child: const Center(
                          child: Material(
                              color: AppColors.accentSoft,
                              child: Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Text('Adicionar MP3 à playlist',
                                      style: TextStyle(
                                          color: AppColors.accentActive,
                                          fontWeight: FontWeight.w600)))))))),
      ]));
}

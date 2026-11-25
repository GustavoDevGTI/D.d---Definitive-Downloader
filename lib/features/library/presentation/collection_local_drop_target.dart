import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:desktop_drop/desktop_drop.dart';
import '../../../app/theme.dart';
import '../application/library_controller.dart';
import '../domain/models.dart';

class CollectionLocalDropTarget extends StatefulWidget {
  const CollectionLocalDropTarget(
      {super.key,
      required this.controller,
      this.collectionId,
      this.groupId,
      this.onFolderImported,
      required this.child});
  final LibraryController controller;
  final int? collectionId, groupId;
  final ValueChanged<Collection>? onFolderImported;
  final Widget child;
  @override
  State<CollectionLocalDropTarget> createState() =>
      _CollectionLocalDropTargetState();
}

class _CollectionLocalDropTargetState extends State<CollectionLocalDropTarget> {
  bool _over = false;
  bool get _folder => widget.collectionId == null;

  Future<void> _import(List<String> paths) async {
    final id = widget.collectionId;
    if (id != null) {
      await widget.controller.addDroppedMp3(id, paths);
    } else {
      final collection = await widget.controller
          .importLocalFolders(paths, groupId: widget.groupId);
      if (mounted && collection != null) {
        widget.onFolderImported?.call(collection);
      }
    }
  }

  @override
  Widget build(BuildContext context) => DropTarget(
      enable: (_folder
              ? defaultTargetPlatform == TargetPlatform.windows &&
                  !widget.controller.importBlocked
              : !widget.controller.reorderingBusy) &&
          (ModalRoute.of(context)?.isCurrent ?? true),
      onDragEntered: (_) => setState(() => _over = true),
      onDragExited: (_) => setState(() => _over = false),
      onDragDone: (details) {
        setState(() => _over = false);
        unawaited(_import(details.files.map((f) => f.path).toList()));
      },
      child: Stack(children: [
        widget.child,
        if (_over)
          Positioned.fill(
              child: IgnorePointer(
                  child: DecoratedBox(
                      decoration: BoxDecoration(
                          color: _folder
                              ? Colors.transparent
                              : AppColors.accent.withValues(alpha: .08),
                          border: Border.all(
                              color: AppColors.accentActive, width: 2),
                          borderRadius: BorderRadius.circular(12)),
                      child: _folder
                          ? null
                          : const Center(
                              child: Material(
                                  color: AppColors.accentSoft,
                                  child: Padding(
                                      padding: EdgeInsets.all(12),
                                      child: Text('Adicionar áudios à playlist',
                                          style: TextStyle(
                                              color: AppColors.accentActive,
                                              fontWeight:
                                                  FontWeight.w600)))))))),
      ]));
}

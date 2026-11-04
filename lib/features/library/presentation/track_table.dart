import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../app/app_notice.dart';
import '../application/library_controller.dart';
import '../domain/models.dart';
import '../domain/track_listing.dart';
import 'edit_track_dialog.dart';
import 'track_row.dart';
import '../../player/presentation/player_scope.dart';

class TrackTable extends StatefulWidget {
  const TrackTable(
      {super.key, required this.controller, required this.onFocus});
  final LibraryController controller;
  final ValueChanged<Track> onFocus;
  @override
  State<TrackTable> createState() => _TrackTableState();
}

class _TrackDrag {
  const _TrackDrag(this.collectionId, this.trackId, this.group, this.count);
  final int collectionId, trackId, count;
  final bool group;
}

class _TrackTableState extends State<TrackTable> {
  LibraryController get controller => widget.controller;
  final _scroll = ScrollController();
  final _viewportKey = GlobalKey();
  Timer? _autoScroll, _pageTimer;
  int _scrollDirection = 0;
  int? _hoverPage;
  _TrackDrag? _drag;
  bool get _editable =>
      !controller.busy && controller.current?.editingLocked != true;
  bool get _reorderable => !controller.reorderingBusy;

  @override
  void dispose() {
    _autoScroll?.cancel();
    _pageTimer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.f2): _editFocused,
          },
          child: LayoutBuilder(builder: (context, box) {
            final compact = box.maxWidth < 500;
            final scale = MediaQuery.textScalerOf(context).scale(13) / 13;
            return Column(children: [
              Container(
                  color: AppColors.surface,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Row(children: [
                    SizedBox(
                        width: 36,
                        child: Checkbox(
                            key: const ValueKey('select-all-collection'),
                            semanticLabel:
                                'Selecionar todas as faixas do filtro',
                            tristate: true,
                            value: controller.allFilteredSelected
                                ? true
                                : controller.page.filteredSelectedCount > 0
                                    ? null
                                    : false,
                            onChanged: controller.busy ||
                                    controller.page.total == 0
                                ? null
                                : (_) => unawaited(controller.selectCollection(
                                    !controller.allFilteredSelected)))),
                    const SizedBox(width: 54),
                    Expanded(child: _header('Faixa / artista', TrackSort.name)),
                    if (!compact) ...[
                      SizedBox(
                          width: 84,
                          child: _header('Duração', TrackSort.duration)),
                      SizedBox(
                          width: 142,
                          child: _header(
                              'Correspondência', TrackSort.correspondence))
                    ],
                    if (PlayerScope.of(context) != null)
                      const SizedBox(width: 48),
                  ])),
              Expanded(
                  child: controller.page.items.isEmpty
                      ? const Center(
                          child: Text('Nenhuma faixa neste filtro.',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.muted)))
                      : ListView.builder(
                          key: _viewportKey,
                          controller: _scroll,
                          primary: false,
                          itemExtent:
                              (compact ? 120.0 : 96.0) * scale.clamp(1, 2),
                          itemCount: controller.page.items.length,
                          itemBuilder: (context, index) {
                            final t = controller.page.items[index];
                            final focused = controller.focused?.id == t.id;
                            return _interactive(context, t,
                                rowHeight: (compact ? 120.0 : 96.0) *
                                    scale.clamp(1, 2),
                                width: box.maxWidth,
                                child: TrackRow(
                                    track: t,
                                    focused: focused,
                                    compact: compact,
                                    selectionEnabled: !controller.busy,
                                    onTap: () => unawaited(_click(t)),
                                    onContextMenu: (point) =>
                                        unawaited(_contextMenu(t, point)),
                                    onSelect: (v) =>
                                        unawaited(controller.select(t, v))));
                          })),
              _pageControls(),
            ]);
          }));

  Widget _header(String label, TrackSort sort) => Tooltip(
      message: 'Ordenar por $label',
      child: InkWell(
          key: ValueKey('track-sort-${sort.name}'),
          onTap: () => unawaited(controller.sortTracks(sort)),
          child: SizedBox(
              height: 44,
              child: Row(children: [
                Flexible(
                    child: Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w600))),
                if (controller.trackSort == sort)
                  Icon(
                      controller.trackDescending
                          ? Icons.arrow_downward
                          : Icons.arrow_upward,
                      size: 14,
                      color: AppColors.accentActive),
              ]))));

  Future<void> _click(Track track) async {
    final extend = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    if (await controller.clickTrack(track, extend: extend) && mounted) {
      final focused =
          controller.page.items.where((t) => t.id == track.id).firstOrNull ??
              track;
      if (extend) {
        controller.focus(focused);
      } else {
        widget.onFocus(focused);
      }
    }
  }

  Future<void> _contextMenu(Track track, Offset point) async {
    controller.focus(track);
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final result = await showMenu<String>(
        context: context,
        position: RelativeRect.fromRect(
            Rect.fromPoints(point, point), Offset.zero & overlay.size),
        items: [
          PopupMenuItem(
              value: 'edit',
              enabled: _editable,
              child: Text(controller.current?.editingLocked == true
                  ? 'Edição bloqueada após o início'
                  : 'Editar faixa'))
        ]);
    if (result == 'edit' && mounted && _editable) {
      await showEditTrack(context, controller, track);
    }
  }

  void _editFocused() {
    final track = controller.focused;
    if (track != null && _editable) {
      unawaited(showEditTrack(context, controller, track));
    }
  }

  void _finishDrag() {
    _autoScroll?.cancel();
    _pageTimer?.cancel();
    _hoverPage = null;
    _scrollDirection = 0;
    if (mounted && _drag != null) setState(() => _drag = null);
  }

  void _updateScroll(Offset point) {
    final box = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !_scroll.hasClients) return;
    final local = box.globalToLocal(point);
    final inside = local.dx >= 0 &&
        local.dx <= box.size.width &&
        local.dy >= 0 &&
        local.dy <= box.size.height;
    final direction = !inside
        ? 0
        : local.dy < 44
            ? -1
            : local.dy > box.size.height - 44
                ? 1
                : 0;
    if (direction == _scrollDirection) return;
    _scrollDirection = direction;
    _autoScroll?.cancel();
    if (direction == 0) return;
    _autoScroll = Timer.periodic(const Duration(milliseconds: 20), (_) {
      if (!mounted || _drag == null || !_scroll.hasClients) {
        _autoScroll?.cancel();
        return;
      }
      final next = (_scroll.offset + direction * 12).clamp(
          _scroll.position.minScrollExtent, _scroll.position.maxScrollExtent);
      if (next == _scroll.offset) {
        _autoScroll?.cancel();
        _scrollDirection = 0;
        return;
      }
      _scroll.jumpTo(next);
    });
  }

  Widget _interactive(BuildContext context, Track track,
      {required double rowHeight,
      required double width,
      required Widget child}) {
    final payload = _TrackDrag(
        track.collectionId,
        track.id,
        !controller.downloading &&
            track.selected &&
            controller.page.selectedCount > 1,
        !controller.downloading && track.selected
            ? controller.page.selectedCount
            : 1);
    final row = Semantics(
        selected: track.selected,
        customSemanticsActions: _editable
            ? {
                const CustomSemanticsAction(label: 'Editar faixa'): () =>
                    unawaited(showEditTrack(context, controller, track))
              }
            : const {},
        child: Stack(fit: StackFit.expand, children: [
          child,
          if (_drag != null && _reorderable && !track.orderLocked)
            Positioned.fill(
                child: Column(children: [
              Expanded(child: _dropZone(track, false)),
              Expanded(child: _dropZone(track, true)),
            ])),
        ]));
    if (!_reorderable || track.orderLocked) return row;
    final feedback = Material(
        color: AppColors.accentSoft,
        shape: const RoundedRectangleBorder(
            side: BorderSide(color: AppColors.accentActive)),
        child: SizedBox(
            width: math.min(width, 420),
            height: math.min(rowHeight, 80),
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                        payload.group
                            ? '${payload.count} faixas selecionadas'
                            : track.displayTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.accentActive,
                            fontWeight: FontWeight.w600))))));
    void start() {
      setState(() => _drag = payload);
      controller.focus(track);
    }

    void update(DragUpdateDetails details) =>
        _updateScroll(details.globalPosition);
    void end(DraggableDetails details) => _finishDrag();
    final desktop = {
      TargetPlatform.windows,
      TargetPlatform.linux,
      TargetPlatform.macOS
    }.contains(Theme.of(context).platform);
    if (desktop) {
      return Draggable<_TrackDrag>(
          key: ValueKey('drag-track-${track.id}'),
          data: payload,
          maxSimultaneousDrags: 1,
          onDragStarted: start,
          onDragUpdate: update,
          onDragEnd: end,
          feedback: feedback,
          childWhenDragging: Opacity(opacity: .35, child: row),
          child: row);
    }
    return LongPressDraggable<_TrackDrag>(
        key: ValueKey('drag-track-${track.id}'),
        data: payload,
        delay: const Duration(milliseconds: 280),
        maxSimultaneousDrags: 1,
        onDragStarted: start,
        onDragUpdate: update,
        onDragEnd: end,
        feedback: feedback,
        childWhenDragging: Opacity(opacity: .35, child: row),
        child: row);
  }

  Widget _dropZone(Track track, bool after) => DragTarget<_TrackDrag>(
      key: ValueKey('drop-${after ? 'after' : 'before'}-${track.id}'),
      onWillAcceptWithDetails: (d) =>
          _reorderable &&
          !track.orderLocked &&
          d.data.collectionId == track.collectionId &&
          d.data.trackId != track.id &&
          !(d.data.group && track.selected),
      onAcceptWithDetails: (d) {
        unawaited(_reportMove(controller.moveTracks(d.data.trackId,
            collectionId: d.data.collectionId,
            targetId: track.id,
            after: after,
            selectedGroup: d.data.group)));
        _finishDrag();
      },
      builder: (context, candidates, rejected) => Container(
          color: Colors.transparent,
          alignment: after ? Alignment.bottomCenter : Alignment.topCenter,
          child: candidates.isEmpty
              ? null
              : const SizedBox(
                  height: 3,
                  width: double.infinity,
                  child: ColoredBox(color: AppColors.accentActive))));

  Future<void> _reportMove(Future<String?> movement) async {
    final error = await movement;
    if (error != null && mounted) {
      await showAppNotice(context, message: error);
    }
  }

  Widget _pageControls() => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.line))),
      child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        Flexible(
            child: Text(
                controller.page.total == 0
                    ? '0 faixas'
                    : '${controller.offset + 1}–${controller.offset + controller.page.items.length} de ${controller.page.total}',
                style: const TextStyle(fontSize: 11, color: AppColors.muted))),
        _pageTarget(-1),
        _pageTarget(1),
      ]));

  Widget _pageTarget(int direction) {
    final enabled = direction < 0
        ? controller.offset > 0
        : controller.offset + controller.page.items.length <
            controller.page.total;
    return DragTarget<_TrackDrag>(
      key: ValueKey('track-page-$direction'),
      onWillAcceptWithDetails: (d) =>
          enabled &&
          _reorderable &&
          d.data.collectionId == controller.current?.id,
      onMove: (_) {
        if (_hoverPage == direction) return;
        _pageTimer?.cancel();
        _hoverPage = direction;
        _pageTimer = Timer(const Duration(milliseconds: 650), () async {
          if (!mounted ||
              _drag == null ||
              !enabled ||
              controller.reorderingBusy) {
            return;
          }
          await controller.turnPage(direction);
          if (mounted && _scroll.hasClients) {
            _scroll
                .jumpTo(direction > 0 ? 0 : _scroll.position.maxScrollExtent);
          }
        });
      },
      onLeave: (_) {
        _pageTimer?.cancel();
        _hoverPage = null;
      },
      builder: (context, candidates, rejected) => ColoredBox(
          color: candidates.isEmpty ? Colors.transparent : AppColors.accentSoft,
          child: IconButton(
              tooltip: direction < 0 ? 'Página anterior' : 'Próxima página',
              onPressed: enabled
                  ? () => unawaited(controller.turnPage(direction))
                  : null,
              icon: Icon(
                  direction < 0 ? Icons.chevron_left : Icons.chevron_right))),
    );
  }
}

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../app/app_notice.dart';
import '../../../core/presentation/ctrl_drag_selection.dart';
import '../application/library_controller.dart';
import '../domain/models.dart';
import '../domain/track_listing.dart';
import 'edit_track_dialog.dart';
import 'track_row.dart';
import 'playlist_palette.dart';
import '../../player/presentation/player_scope.dart';
import '../../audio_conversion/application/audio_conversion_controller.dart';
import '../../audio_conversion/presentation/audio_conversion_dialog.dart';

class TrackTable extends StatefulWidget {
  const TrackTable(
      {super.key,
      required this.controller,
      required this.onFocus,
      this.accent});
  final LibraryController controller;
  final ValueChanged<Track> onFocus;
  final Color? accent;
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
  Timer? _autoScroll;
  int _scrollDirection = 0;
  Object? _listingKey;
  int _inspectorRequest = 0;
  int? _focusedId, _focusedPosition;
  _TrackDrag? _drag;
  bool get _editable =>
      !controller.busy && controller.current?.editingLocked != true;
  bool get _reorderable => !controller.reorderingBusy;

  @override
  void dispose() {
    _autoScroll?.cancel();
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
            final accent = widget.accent;
            final scale = MediaQuery.textScalerOf(context).scale(13) / 13;
            final extent = (AppDensity.of(context).desktop
                    ? AppDensity.of(context).trackExtent
                    : MediaQuery.sizeOf(context).height < 500
                        ? 64.0
                        : compact
                            ? 84.0
                            : 76.0) *
                scale.clamp(1, 2);
            final listingKey = (
              controller.current?.id,
              controller.collectionQuery,
              controller.view,
              controller.trackSort,
              controller.trackDescending
            );
            final changed = _listingKey != listingKey;
            _listingKey = listingKey;
            final focused = controller.focused;
            final reveal = _inspectorRequest != controller.inspectorRequest ||
                (focused != null &&
                    focused.id == _focusedId &&
                    focused.position != _focusedPosition);
            _inspectorRequest = controller.inspectorRequest;
            _focusedId = focused?.id;
            _focusedPosition = focused?.position;
            if (changed || reveal) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted || !_scroll.hasClients) return;
                final index = reveal
                    ? controller.page.items
                        .indexWhere((t) => t.id == focused?.id)
                    : 0;
                if (index >= 0) {
                  _scroll.jumpTo((index * extent)
                      .clamp(0, _scroll.position.maxScrollExtent));
                }
              });
            }
            return Column(children: [
              Container(
                  key: const ValueKey('track-table-header'),
                  decoration: BoxDecoration(
                      color: accent == null
                          ? AppColors.surface
                          : Color.alphaBlend(
                              accent.withAlpha(15), Colors.white),
                      border: Border(
                          top: BorderSide(color: accent ?? AppColors.line),
                          bottom: const BorderSide(color: AppColors.line))),
                  padding: const EdgeInsets.fromLTRB(9, 0, 18, 0),
                  child: Row(children: [
                    SizedBox(
                        width: 36,
                        child: Checkbox(
                            key: const ValueKey('select-all-collection'),
                            semanticLabel:
                                'Selecionar todas as faixas do filtro',
                            tristate: true,
                            activeColor: playlistInk(accent),
                            value: controller.allFilteredSelected
                                ? true
                                : controller.page.filteredSelectedCount > 0
                                    ? null
                                    : false,
                            onChanged: controller.selectionBlocked ||
                                    controller.page.total == 0
                                ? null
                                : (_) => unawaited(controller.selectCollection(
                                    !controller.allFilteredSelected)))),
                    SizedBox(
                        width: AppDensity.of(context).desktop
                            ? 42
                            : compact
                                ? 46
                                : 54),
                    Expanded(child: _header('Faixa / artista', TrackSort.name)),
                    SizedBox(
                        width: compact ? 88 : 104,
                        child: const Text('Fonte / arquivo',
                            style: TextStyle(fontSize: 10))),
                    if (!compact) ...[
                      SizedBox(
                          width: 56,
                          child: _header('Duração', TrackSort.duration)),
                      SizedBox(
                          width: 108,
                          child: _header(
                              'Correspondência', TrackSort.correspondence))
                    ],
                    if (PlayerScope.of(context) != null)
                      SizedBox(width: AppDensity.of(context).control),
                  ])),
              Expanded(
                  child: controller.page.items.isEmpty
                      ? const Center(
                          child: Text('Nenhuma faixa neste filtro.',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.muted)))
                      : CtrlDragSelection(
                          scroll: _scroll,
                          extent: extent,
                          count: controller.page.items.length,
                          enabled: !controller.selectionBlocked,
                          viewKey: listingKey,
                          onSelect: (indices) => unawaited(controller
                                  .selectSweep([
                                for (final i in indices)
                                  controller.page.items[i].id
                              ])),
                          builder: (control) => ClipRect(
                              child: ScrollConfiguration(
                                  behavior: ScrollConfiguration.of(context)
                                      .copyWith(scrollbars: false),
                                  child: RawScrollbar(
                                      controller: _scroll,
                                      thumbVisibility: true,
                                      trackVisibility: true,
                                      interactive: true,
                                      thickness: AppDensity.of(context).desktop
                                          ? 6
                                          : 8,
                                      radius: const Radius.circular(4),
                                      thumbColor: accent == null
                                          ? AppColors.accent
                                          : playlistInk(accent),
                                      trackColor: AppColors.surface,
                                      padding:
                                          const EdgeInsets.fromLTRB(0, 6, 1, 6),
                                      child: Padding(
                                          padding:
                                              const EdgeInsets.only(right: 12),
                                          child: ListView.builder(
                                              key: _viewportKey,
                                              controller: _scroll,
                                              primary: false,
                                              physics: control
                                                  ? const NeverScrollableScrollPhysics()
                                                  : null,
                                              itemExtent: extent,
                                              itemCount:
                                                  controller.page.items.length,
                                              findChildIndexCallback: (key) {
                                                if (key is! ValueKey<int>) {
                                                  return null;
                                                }
                                                final index = controller
                                                    .page.items
                                                    .indexWhere((t) =>
                                                        t.id == key.value);
                                                return index < 0 ? null : index;
                                              },
                                              itemBuilder: (context, index) {
                                                final t = controller
                                                    .page.items[index];
                                                final focused =
                                                    controller.focused?.id ==
                                                        t.id;
                                                return KeyedSubtree(
                                                    key: ValueKey(t.id),
                                                    child: _interactive(
                                                        context, t,
                                                        control: control,
                                                        rowHeight: extent,
                                                        width: box.maxWidth,
                                                        child: TrackRow(
                                                            track: t,
                                                            accent: accent,
                                                            focused: focused,
                                                            compact: compact,
                                                            selectionEnabled:
                                                                !controller
                                                                    .selectionBlocked,
                                                            onTap: () =>
                                                                unawaited(
                                                                    _click(t)),
                                                            onContextMenu: (point) =>
                                                                unawaited(
                                                                    _contextMenu(
                                                                        t,
                                                                        point)),
                                                            onSelect: (v) =>
                                                                unawaited(controller
                                                                    .select(t,
                                                                        v)))));
                                              }))))))),
            ]);
          }));

  Widget _header(String label, TrackSort sort) => Tooltip(
      message: 'Ordenar por $label',
      child: InkWell(
          key: ValueKey('track-sort-${sort.name}'),
          onTap: () => unawaited(controller.sortTracks(sort)),
          child: SizedBox(
              height: AppDensity.of(context).desktop ? 32 : 44,
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
                      color: playlistInk(widget.accent)),
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
                  : 'Editar faixa')),
          if (AudioConversionController.canOffer(track))
            PopupMenuItem(
                value: 'convert',
                enabled: !controller.busy,
                child: const Text('Converter para MP3')),
        ]);
    if (result == 'edit' && mounted && _editable) {
      await showEditTrack(context, controller, track);
    }
    if (result == 'convert' && mounted && !controller.busy) {
      await showAudioConversion(context, track, controller.files);
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
      required bool control,
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
        color: playlistReviewSurface(widget.accent),
        shape: RoundedRectangleBorder(
            side: BorderSide(color: playlistInk(widget.accent))),
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
                        style: TextStyle(
                            color: playlistInk(widget.accent),
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
          maxSimultaneousDrags: control ? 0 : 1,
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
              : SizedBox(
                  height: 3,
                  width: double.infinity,
                  child: ColoredBox(color: playlistInk(widget.accent)))));

  Future<void> _reportMove(Future<String?> movement) async {
    final error = await movement;
    if (error != null && mounted) {
      await showAppNotice(context, message: error);
    }
  }
}

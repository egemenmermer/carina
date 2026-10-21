/// The TV Guide grid, shared by the TV Guide tab and the live
/// player's Full TV Guide: a painted, two-axis virtualized programme grid
/// with a channel column, keyboard focus, mouse wheel / Shift+wheel /
/// middle-button drag scrolling, and cell routing through callbacks.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../../app/time_format.dart';
import '../../../core/core.dart';
import '../../../data/repositories/repository_models.dart';
import 'guide_cache.dart';
import 'guide_canvas.dart';
import 'guide_cells.dart';
import 'guide_controller.dart';
import 'guide_style.dart';

/// Label of a local day for the corner cell ("Today", "Tomorrow"…).
typedef GuideDayLabel = String Function(DateTime localDay);

/// The guide grid. Rows are [channels]; programmes come from [cache].
///
/// Arrow keys move the focused cell (focus follows, the grid scrolls to
/// keep it visible), PageUp/PageDown move a page of rows, Home jumps to
/// now, Enter/Space call [onActivate], the Menu key / Shift+F10 /
/// right-click / long-press call [onChannelActions]. A click on a cell
/// focuses and activates it; a click on a channel name calls
/// [onChannelActions].
class GuideGrid extends StatefulWidget {
  const GuideGrid({
    super.key,
    required this.channels,
    required this.cache,
    required this.controller,
    required this.nowMs,
    required this.rangeStartMs,
    required this.rangeEndMs,
    required this.zoomMinutes,
    required this.timeFormat,
    required this.dayLabel,
    required this.noEpgLabel,
    this.reminderKeys = const <String>{},
    this.initialChannelId,
    this.onActivate,
    this.onChannelActions,
    this.onDayTap,
    this.autofocus = true,
    this.focusNode,
    this.metrics = GuideMetrics.regular,
    this.leaveUpFromFirstRow = false,
  });

  final List<ChannelView> channels;
  final GuideProgrammeCache cache;
  final GuideGridController controller;

  /// The current time (UTC ms, minute clock).
  final int nowMs;

  /// Scrollable time range (UTC ms).
  final int rangeStartMs;
  final int rangeEndMs;

  /// Minutes visible across the programme area (30/60/90/120).
  final int zoomMinutes;
  final CarinaTimeFormat timeFormat;
  final GuideDayLabel dayLabel;
  final String noEpgLabel;

  /// `'<channel provider id>@<start ms>'` of programmes with a reminder.
  final Set<String> reminderKeys;

  /// Row focused first (default: the first row).
  final String? initialChannelId;

  /// A cell was clicked or Enter was pressed on it.
  final ValueChanged<GuideFocus>? onActivate;

  /// Channel name clicked, or a context menu asked on a row (global
  /// position).
  final void Function(ChannelView channel, Offset globalPosition)?
  onChannelActions;

  /// The day label in the corner was clicked (global rectangle).
  final ValueChanged<Rect>? onDayTap;
  final bool autofocus;
  final FocusNode? focusNode;
  final GuideMetrics metrics;

  /// Up on the first row is left unhandled so directional focus can move to
  /// the controls above the grid (TV remote).
  final bool leaveUpFromFirstRow;

  @override
  State<GuideGrid> createState() => _GuideGridState();
}

class _GuideGridState extends State<GuideGrid> implements GuideGridCommands {
  final GuideSelection _selection = GuideSelection();
  final ValueNotifier<int?> _focusRow = ValueNotifier<int?>(null);
  final ValueNotifier<int> _visibleDay = ValueNotifier<int>(0);
  final ValueNotifier<bool> _overCell = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _grabbing = ValueNotifier<bool>(false);
  final Map<String, Widget> _tiles = {};

  FocusNode? _ownFocusNode;
  ScrollController? _v;
  ScrollController? _h;
  double _pxPerMinute = 10;
  double _viewportWidth = 1;
  double _viewportHeight = 1;

  GuideFocus? _focus;
  late int _anchorMs;
  Object? _lastEnsure;
  Offset? _hoverPosition;

  int? _dragPointer;
  Offset _dragStart = Offset.zero;
  double _dragStartH = 0;
  double _dragStartV = 0;

  FocusNode get _focusNode =>
      widget.focusNode ?? (_ownFocusNode ??= FocusNode(debugLabel: 'guide'));

  GuideMetrics get _m => widget.metrics;
  int get _originMs => floorToSlot(widget.rangeStartMs);
  double get _pxPerMs => _pxPerMinute / kMinuteMs;
  double _xOf(int ms) => (ms - _originMs) * _pxPerMs;
  int _timeAt(double x) => _originMs + (x / _pxPerMs).round();

  bool get _ready =>
      _h != null && _v != null && _h!.hasClients && _v!.hasClients;

  @override
  int? get visibleStartMs => _ready ? _timeAt(_h!.offset) : null;

  // ------------------------------------------------------------- lifecycle

  @override
  void initState() {
    super.initState();
    _anchorMs = widget.nowMs;
    widget.controller.attach(this);
    widget.cache.addListener(_onCacheChanged);
    final row = _initialRow();
    if (row != null) _setFocus(row, _anchorMs);
    if (widget.autofocus) {
      // The shell's shortcut node autofocuses too; take keyboard focus
      // explicitly once mounted.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(GuideGrid old) {
    super.didUpdateWidget(old);
    if (!identical(old.controller, widget.controller)) {
      old.controller.detach(this);
      widget.controller.attach(this);
    }
    if (!identical(old.cache, widget.cache)) {
      old.cache.removeListener(_onCacheChanged);
      widget.cache.addListener(_onCacheChanged);
      _lastEnsure = null;
    }
    if (!identical(old.channels, widget.channels) || old.metrics != _m) {
      _tiles.clear();
      _lastEnsure = null;
      _onChannelsChanged(old.channels);
      WidgetsBinding.instance.addPostFrameCallback((_) => _ensureData());
    }
    if (old.zoomMinutes != widget.zoomMinutes ||
        old.rangeStartMs != widget.rangeStartMs) {
      _lastEnsure = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => _ensureData());
    }
  }

  @override
  void dispose() {
    widget.controller.detach(this);
    widget.cache.removeListener(_onCacheChanged);
    _v?.dispose();
    _h?.dispose();
    _ownFocusNode?.dispose();
    _selection.dispose();
    _focusRow.dispose();
    _visibleDay.dispose();
    _overCell.dispose();
    _grabbing.dispose();
    super.dispose();
  }

  int? _initialRow() {
    final channels = widget.channels;
    if (channels.isEmpty) return null;
    final id = widget.initialChannelId;
    if (id != null) {
      final i = channels.indexWhere((c) => c.providerId == id);
      if (i >= 0) return i;
    }
    return 0;
  }

  void _onChannelsChanged(List<ChannelView> previous) {
    final channels = widget.channels;
    if (channels.isEmpty) {
      _focus = null;
      _selection.setFocus(null, null);
      _focusRow.value = null;
      widget.controller.setFocus(null);
      return;
    }
    final f = _focus;
    var row = 0;
    if (f != null) {
      final same = channels.indexWhere(
        (c) => c.providerId == f.channel.providerId,
      );
      row = same >= 0 ? same : math.min(f.row, channels.length - 1);
    }
    _setFocus(row, _anchorMs);
    final v = _v;
    if (v != null && v.hasClients && f != null) {
      final sameChannel =
          row < channels.length &&
          channels[row].providerId == f.channel.providerId;
      if (!sameChannel) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _v!.hasClients) _v!.jumpTo(0);
        });
      }
    }
  }

  void _ensureControllers() {
    if (_h != null) return;
    final now = widget.nowMs;
    final h = _xOf(floorToSlot(now)).clamp(0.0, double.infinity);
    final row = _focus?.row ?? 0;
    final n = widget.channels.length;
    final maxV = math.max(
      0.0,
      n * _m.rowPitch - _m.rowGap + _m.bottomPadding - _viewportHeight,
    );
    final centred = row * _m.rowPitch - (_viewportHeight - _m.rowHeight) / 2;
    final v = widget.initialChannelId == null ? 0.0 : centred.clamp(0.0, maxV);
    _h = ScrollController(initialScrollOffset: h)..addListener(_onScroll);
    _v = ScrollController(initialScrollOffset: v)..addListener(_onScroll);
    _visibleDay.value = _dayIndex(_timeAt(h));
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureData());
  }

  // ------------------------------------------------------------------ data

  void _onScroll() {
    if (!_ready) return;
    _visibleDay.value = _dayIndex(_timeAt(_h!.offset));
    _ensureData();
    final p = _hoverPosition;
    if (p != null) _updateHover(p);
  }

  static int _dayIndex(int ms) {
    final d = localDay(DateTime.fromMillisecondsSinceEpoch(ms));
    return d.year * 10000 + d.month * 100 + d.day;
  }

  /// Loads the visible rows (± 8) for the visible time (± 2 hours).
  void _ensureData() {
    if (!mounted || !_ready) return;
    final channels = widget.channels;
    final n = channels.length;
    if (n == 0) return;
    final pitch = _m.rowPitch;
    final v = _v!.offset;
    final h = _h!.offset;
    final r0 = ((v / pitch).floor() - 8).clamp(0, n - 1);
    final r1 = (((v + _viewportHeight) / pitch).ceil() + 8).clamp(0, n - 1);
    final cache = widget.cache;
    final fromMs = math.max(widget.rangeStartMs, _timeAt(h) - 2 * kHourMs);
    final toMs = math.min(
      widget.rangeEndMs,
      _timeAt(h + _viewportWidth) + 2 * kHourMs,
    );
    if (toMs <= fromMs) return;
    final signature = (
      r0,
      r1,
      cache.chunkStartMs(fromMs),
      cache.chunkStartMs(toMs),
      cache.generation,
    );
    if (signature == _lastEnsure) return;
    _lastEnsure = signature;
    cache.ensure(
      [
        for (var r = r0; r <= r1; r++)
          if (channels[r].epgKey != null) channels[r].epgKey!,
      ],
      DateTime.fromMillisecondsSinceEpoch(fromMs, isUtc: true),
      DateTime.fromMillisecondsSinceEpoch(toMs, isUtc: true),
    );
  }

  void _onCacheChanged() {
    if (!mounted) return;
    if (widget.cache.isEmpty) _lastEnsure = null;
    final f = _focus;
    if (f == null) return;
    final at = f.cell.contains(_anchorMs) ? _anchorMs : f.cell.startMs;
    _setFocus(f.row, at);
    _ensureData();
  }

  // ----------------------------------------------------------------- focus

  void _setFocus(int row, int ms, {bool reveal = false, bool animate = true}) {
    final channels = widget.channels;
    if (channels.isEmpty) return;
    final r = row.clamp(0, channels.length - 1);
    final channel = channels[r];
    final cell = cellAt(widget.cache, channel.epgKey, ms);
    final focus = GuideFocus(row: r, channel: channel, cell: cell);
    _focus = focus;
    _selection.setFocus(r, cell.startMs);
    _focusRow.value = r;
    widget.controller.setFocus(focus);
    if (reveal) _reveal(focus, animate: animate);
  }

  void _reveal(GuideFocus f, {required bool animate}) {
    if (!_ready) return;
    final m = _m;
    final top = f.row * m.rowPitch;
    final bottom = top + m.rowHeight;
    final v = _v!;
    double? vTarget;
    if (top < v.offset) {
      vTarget = top;
    } else if (bottom > v.offset + _viewportHeight) {
      vTarget = bottom - _viewportHeight;
    }
    final h = _h!;
    final x0 = _xOf(f.cell.startMs);
    final x1 = _xOf(f.cell.stopMs);
    final left = h.offset;
    final right = left + _viewportWidth;
    const margin = 80.0;
    final startVisible = x0 >= left && x0 <= right - margin;
    final stillVisible = x0 < left && x1 > left + margin;
    double? hTarget;
    if (!startVisible && !stillVisible) {
      hTarget = _xOf(
        floorToSlot(math.max(f.cell.startMs, widget.rangeStartMs)),
      );
    }
    if (vTarget != null) _scrollTo(v, vTarget, animate);
    if (hTarget != null) _scrollTo(h, hTarget, animate);
  }

  void _scrollTo(ScrollController c, double target, bool animate) {
    final p = c.position;
    final t = target.clamp(p.minScrollExtent, p.maxScrollExtent);
    if ((t - p.pixels).abs() < 0.5) return;
    if (!animate || KMotion.reduced(context)) {
      c.jumpTo(t);
    } else {
      c.animateTo(t, duration: KDurations.scroll, curve: KMotion.enter);
    }
  }

  void _moveRow(int delta, {bool repeat = false}) {
    final f = _focus;
    final n = widget.channels.length;
    if (n == 0) return;
    if (f == null) {
      _setFocus(0, _anchorMs, reveal: true);
      return;
    }
    final row = (f.row + delta).clamp(0, n - 1);
    if (row == f.row) return;
    _setFocus(row, _anchorMs, reveal: true, animate: !repeat);
  }

  void _moveCell(int direction, {bool repeat = false}) {
    final f = _focus;
    if (f == null) return;
    final key = f.channel.epgKey;
    final next = direction > 0
        ? nextCell(widget.cache, key, f.cell)
        : previousCell(widget.cache, key, f.cell);
    if (next.stopMs <= widget.rangeStartMs ||
        next.startMs >= widget.rangeEndMs) {
      return;
    }
    var anchor = next.startMs;
    final visible = visibleStartMs;
    if (visible != null && anchor < visible && next.stopMs > visible) {
      anchor = math.min(visible, next.stopMs - 1);
    }
    _anchorMs = math.max(anchor, widget.rangeStartMs);
    _setFocus(f.row, _anchorMs, reveal: true, animate: !repeat);
  }

  @override
  void jumpToNow() {
    final now = widget.nowMs;
    _anchorMs = now;
    _setFocus(_focus?.row ?? 0, now);
    if (_ready) _scrollTo(_h!, _xOf(floorToSlot(now)), true);
  }

  @override
  void jumpToDay(DateTime localDay) {
    final now = DateTime.fromMillisecondsSinceEpoch(floorToSlot(widget.nowMs));
    final target = DateTime(
      localDay.year,
      localDay.month,
      localDay.day,
      now.hour,
      now.minute,
    ).toUtc().millisecondsSinceEpoch;
    final ms = target.clamp(widget.rangeStartMs, widget.rangeEndMs - 1);
    _anchorMs = ms;
    _setFocus(_focus?.row ?? 0, ms);
    if (_ready) _scrollTo(_h!, _xOf(floorToSlot(ms)), true);
  }

  @override
  void focusChannel(String providerId, {DateTime? at}) {
    final row = widget.channels.indexWhere((c) => c.providerId == providerId);
    if (row < 0) return;
    _anchorMs = (at ?? DateTime.fromMillisecondsSinceEpoch(widget.nowMs))
        .millisecondsSinceEpoch;
    _setFocus(row, _anchorMs, reveal: true, animate: false);
  }

  void _activate() {
    final f = _focus;
    if (f != null) widget.onActivate?.call(f);
  }

  void _channelActionsForFocus() {
    final f = _focus;
    if (f == null || !_ready) return;
    final box = context.findRenderObject();
    if (box is! RenderBox) return;
    final m = _m;
    final x =
        m.channelColumnWidth +
        (math.max(_xOf(f.cell.startMs), _h!.offset) - _h!.offset) +
        24;
    final y = m.headerHeight + f.row * m.rowPitch - _v!.offset + m.rowHeight;
    widget.onChannelActions?.call(f.channel, box.localToGlobal(Offset(x, y)));
  }

  // -------------------------------------------------------------- keyboard

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final repeat = event is KeyRepeatEvent;
    final key = event.logicalKey;
    final rowsPerPage = math.max(1, (_viewportHeight / _m.rowPitch).floor());
    if (key == LogicalKeyboardKey.arrowUp) {
      if (widget.leaveUpFromFirstRow && (_focus?.row ?? 0) == 0) {
        return KeyEventResult.ignored;
      }
      _moveRow(-1, repeat: repeat);
    } else if (key == LogicalKeyboardKey.arrowDown) {
      _moveRow(1, repeat: repeat);
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      _moveCell(-1, repeat: repeat);
    } else if (key == LogicalKeyboardKey.arrowRight) {
      _moveCell(1, repeat: repeat);
    } else if (key == LogicalKeyboardKey.pageUp) {
      _moveRow(-rowsPerPage, repeat: repeat);
    } else if (key == LogicalKeyboardKey.pageDown) {
      _moveRow(rowsPerPage, repeat: repeat);
    } else if (key == LogicalKeyboardKey.home) {
      if (!repeat) jumpToNow();
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.select) {
      if (!repeat) _activate();
    } else if (key == LogicalKeyboardKey.contextMenu ||
        (key == LogicalKeyboardKey.f10 &&
            HardwareKeyboard.instance.isShiftPressed)) {
      if (!repeat) _channelActionsForFocus();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  // ----------------------------------------------------------------- mouse

  ({int row, int ms, GuideCell cell})? _hit(Offset p) {
    if (!_ready) return null;
    final m = _m;
    if (p.dx < m.channelColumnWidth || p.dy < m.headerHeight) return null;
    final y = p.dy - m.headerHeight + _v!.offset;
    final row = (y / m.rowPitch).floor();
    final channels = widget.channels;
    if (row < 0 || row >= channels.length) return null;
    if (y - row * m.rowPitch > m.rowHeight) return null;
    final x = p.dx - m.channelColumnWidth + _h!.offset;
    final ms = _timeAt(x);
    final cell = cellAt(widget.cache, channels[row].epgKey, ms);
    if (x > _xOf(cell.stopMs) - m.cellGap) return null;
    return (row: row, ms: ms, cell: cell);
  }

  void _updateHover(Offset p) {
    final hit = _hit(p);
    _selection.setHover(hit?.row, hit?.cell.startMs);
    _overCell.value = hit != null;
  }

  void _onHover(PointerHoverEvent e) {
    _hoverPosition = e.localPosition;
    _updateHover(e.localPosition);
  }

  void _onExit(PointerExitEvent e) {
    _hoverPosition = null;
    _selection.setHover(null, null);
    _overCell.value = false;
  }

  void _onTapDown(TapDownDetails d) {
    final hit = _hit(d.localPosition);
    if (hit == null) return;
    _selection
      ..setHover(hit.row, hit.cell.startMs)
      ..setPressed(true);
  }

  void _onTapUp(TapUpDetails d) {
    _selection.setPressed(false);
    final hit = _hit(d.localPosition);
    if (hit == null) return;
    _focusNode.requestFocus();
    _anchorMs = hit.ms;
    _setFocus(hit.row, hit.ms);
    _activate();
  }

  void _onSecondary(Offset local, Offset global) {
    final hit = _hit(local);
    if (hit == null) return;
    _focusNode.requestFocus();
    _anchorMs = hit.ms;
    _setFocus(hit.row, hit.ms);
    widget.onChannelActions?.call(widget.channels[hit.row], global);
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !_ready) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (e) {
      final s = e as PointerScrollEvent;
      var dx = s.scrollDelta.dx;
      var dy = s.scrollDelta.dy;
      // Windows/Linux deliver Shift+wheel as vertical deltas; macOS already
      // turns it into a horizontal one.
      if (HardwareKeyboard.instance.isShiftPressed && dx == 0) {
        dx = dy;
        dy = 0;
      }
      if (dx != 0) _h!.position.pointerScroll(dx);
      if (dy != 0) _v!.position.pointerScroll(dy);
    });
  }

  void _onPointerDown(PointerDownEvent e) {
    if (e.kind != PointerDeviceKind.mouse ||
        (e.buttons & kMiddleMouseButton) == 0 ||
        !_ready) {
      return;
    }
    _dragPointer = e.pointer;
    _dragStart = e.position;
    _dragStartH = _h!.offset;
    _dragStartV = _v!.offset;
    _grabbing.value = true;
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (e.pointer != _dragPointer || !_ready) return;
    final d = e.position - _dragStart;
    _jump(_h!, _dragStartH - d.dx);
    _jump(_v!, _dragStartV - d.dy);
  }

  void _onPointerEnd(PointerEvent e) {
    if (e.pointer != _dragPointer) return;
    _dragPointer = null;
    _grabbing.value = false;
  }

  static void _jump(ScrollController c, double target) {
    final p = c.position;
    final t = target.clamp(p.minScrollExtent, p.maxScrollExtent);
    if (t != p.pixels) c.jumpTo(t);
  }

  // ----------------------------------------------------------------- build

  Widget _tileFor(int row) {
    final channel = widget.channels[row];
    return _tiles.putIfAbsent(
      channel.providerId,
      () => _ChannelTile(
        key: ValueKey('guide-channel-${channel.providerId}'),
        channel: channel,
        metrics: _m,
        onTap: (position) => widget.onChannelActions?.call(channel, position),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final m = _m;
        _viewportWidth = math.max(
          1.0,
          constraints.maxWidth - m.channelColumnWidth,
        );
        _viewportHeight = math.max(1.0, constraints.maxHeight - m.headerHeight);
        _pxPerMinute = _viewportWidth / widget.zoomMinutes.clamp(15, 24 * 60);
        _ensureControllers();
        return Focus(
          focusNode: _focusNode,
          autofocus: widget.autofocus,
          onKeyEvent: _onKey,
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context)
                .copyWith(scrollbars: false, overscroll: false),
            child: Scrollable(
              controller: _v,
              axisDirection: AxisDirection.down,
              physics: const ClampingScrollPhysics(),
              viewportBuilder: (context, vertical) => Scrollable(
                controller: _h,
                axisDirection: AxisDirection.right,
                physics: const ClampingScrollPhysics(),
                viewportBuilder: (context, horizontal) =>
                    _body(context, vertical, horizontal),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _body(
    BuildContext context,
    ViewportOffset vertical,
    ViewportOffset horizontal,
  ) {
    final m = _m;
    final canvas = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: () => _selection.setPressed(false),
      onSecondaryTapUp: (d) => _onSecondary(d.localPosition, d.globalPosition),
      onLongPressStart: (d) => _onSecondary(d.localPosition, d.globalPosition),
      child: GuideCanvas(
        verticalOffset: vertical,
        horizontalOffset: horizontal,
        channels: widget.channels,
        cache: widget.cache,
        selection: _selection,
        metrics: m,
        originMs: _originMs,
        endMs: widget.rangeEndMs,
        pxPerMinute: _pxPerMinute,
        nowMs: widget.nowMs,
        reminderKeys: widget.reminderKeys,
        timeFormat: widget.timeFormat,
        noEpgLabel: widget.noEpgLabel,
        textScaler: MediaQuery.textScalerOf(context),
      ),
    );
    return Listener(
      onPointerSignal: _onPointerSignal,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerEnd,
      onPointerCancel: _onPointerEnd,
      child: Stack(
        children: [
          Positioned.fill(
            child: ValueListenableBuilder<bool>(
              valueListenable: _grabbing,
              child: canvas,
              builder: (context, grabbing, child) =>
                  ValueListenableBuilder<bool>(
                    valueListenable: _overCell,
                    child: child,
                    builder: (context, over, child) => MouseRegion(
                      cursor: grabbing
                          ? SystemMouseCursors.grabbing
                          : over
                          ? SystemMouseCursors.click
                          : MouseCursor.defer,
                      onHover: _onHover,
                      onExit: _onExit,
                      child: child,
                    ),
                  ),
            ),
          ),
          Positioned(
            left: 0,
            top: m.headerHeight,
            width: m.channelColumnWidth,
            bottom: 0,
            // Scrolling repaints only the column and the canvas, never
            // the rest of the page.
            child: RepaintBoundary(
              child: _ChannelColumn(
                offset: vertical,
                focusRow: _focusRow,
                count: widget.channels.length,
                metrics: m,
                tileFor: _tileFor,
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            width: m.channelColumnWidth,
            height: m.headerHeight,
            child: RepaintBoundary(
              child: ValueListenableBuilder<int>(
                valueListenable: _visibleDay,
                builder: (context, day, _) => _CornerCell(
                  label: widget.dayLabel(
                    DateTime(day ~/ 10000, day ~/ 100 % 100, day % 100),
                  ),
                  onTap: widget.onDayTap,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The channel rows and the red bar that marks the focused row at the far
/// left. Tiles are built for a window of rows that shifts only every few
/// rows; in between, scrolling just repaints the window at the new offset
/// ([_VerticalShift]), so a scroll frame does not rebuild or relayout tiles.
class _ChannelColumn extends StatefulWidget {
  const _ChannelColumn({
    required this.offset,
    required this.focusRow,
    required this.count,
    required this.metrics,
    required this.tileFor,
  });

  final ViewportOffset offset;
  final ValueListenable<int?> focusRow;
  final int count;
  final GuideMetrics metrics;
  final Widget Function(int row) tileFor;

  @override
  State<_ChannelColumn> createState() => _ChannelColumnState();
}

class _ChannelColumnState extends State<_ChannelColumn> {
  /// Extra rows built above and below the visible ones.
  static const int _margin = 3;
  int _first = 0;
  double _height = 0;

  @override
  void initState() {
    super.initState();
    widget.offset.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(_ChannelColumn old) {
    super.didUpdateWidget(old);
    if (!identical(old.offset, widget.offset)) {
      old.offset.removeListener(_onScroll);
      widget.offset.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    widget.offset.removeListener(_onScroll);
    super.dispose();
  }

  int get _visible => (_height / widget.metrics.rowPitch).ceil() + 1;

  double get _pixels => widget.offset.hasPixels ? widget.offset.pixels : 0.0;

  int _windowStartFor(double pixels) {
    final row = (pixels / widget.metrics.rowPitch).floor();
    return math.max(0, row - _margin);
  }

  void _onScroll() {
    final px = widget.offset.hasPixels ? widget.offset.pixels : 0.0;
    final row = (px / widget.metrics.rowPitch).floor();
    // Shift the window only when the visible rows leave its margins.
    if (row < _first || row + _visible > _first + _visible + 2 * _margin) {
      final next = _windowStartFor(px);
      if (next == _first) return;
      final phase = SchedulerBinding.instance.schedulerPhase;
      if (phase == SchedulerPhase.persistentCallbacks) {
        // Scroll corrections during layout: rebuild after this frame.
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _first = _windowStartFor(_pixels));
        });
      } else {
        setState(() => _first = next);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.metrics;
    return LayoutBuilder(
      builder: (context, constraints) {
        _height = constraints.maxHeight;
        final px = widget.offset.hasPixels ? widget.offset.pixels : 0.0;
        final row = (px / m.rowPitch).floor();
        if (row < _first || row + _visible > _first + _visible + 2 * _margin) {
          _first = _windowStartFor(px);
        }
        final first = _first;
        final last = math.min(widget.count - 1, first + _visible + 2 * _margin);
        return _VerticalShift(
          offset: widget.offset,
          top: first * m.rowPitch,
          child: RepaintBoundary(
            child: ValueListenableBuilder<int?>(
              valueListenable: widget.focusRow,
              builder: (context, focused, _) => SizedBox(
                height: math.max(0, last - first + 1) * m.rowPitch,
                child: Stack(
                  children: [
                    for (var r = first; r <= last; r++)
                      Positioned(
                        key: ValueKey(r),
                        top: (r - first) * m.rowPitch,
                        left: 0,
                        right: 0,
                        height: m.rowHeight,
                        child: widget.tileFor(r),
                      ),
                    if (focused != null && focused >= first && focused <= last)
                      Positioned(
                        left: 0,
                        top: (focused - first) * m.rowPitch,
                        width: 4,
                        height: m.rowHeight,
                        child: const ColoredBox(color: KColors.accent),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Paints (and hit-tests) its child [top] − scroll pixels below its own
/// top, clipped to its bounds. Scrolling only repaints.
class _VerticalShift extends SingleChildRenderObjectWidget {
  const _VerticalShift({
    required this.offset,
    required this.top,
    required super.child,
  });

  final ViewportOffset offset;
  final double top;

  @override
  _RenderVerticalShift createRenderObject(BuildContext context) =>
      _RenderVerticalShift(offset, top);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderVerticalShift renderObject,
  ) {
    renderObject
      ..offset = offset
      ..top = top;
  }
}

class _RenderVerticalShift extends RenderProxyBox {
  _RenderVerticalShift(this._offset, this._top);

  ViewportOffset _offset;
  set offset(ViewportOffset value) {
    if (identical(value, _offset)) return;
    if (attached) _offset.removeListener(markNeedsPaint);
    _offset = value;
    if (attached) _offset.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  double _top;
  set top(double value) {
    if (value == _top) return;
    _top = value;
    markNeedsPaint();
  }

  double get _dy => _top - (_offset.hasPixels ? _offset.pixels : 0.0);

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _offset.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _offset.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void performLayout() {
    final c = child;
    if (c != null) {
      c.layout(
        BoxConstraints.tightFor(width: constraints.maxWidth),
        parentUsesSize: false,
      );
    }
    size = constraints.biggest;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final c = child;
    if (c == null) return;
    context.pushClipRect(
      needsCompositing,
      offset,
      Offset.zero & size,
      (context, offset) => context.paintChild(c, offset + Offset(0, _dy)),
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final c = child;
    if (c == null || !size.contains(position)) return false;
    return result.addWithPaintOffset(
      offset: Offset(0, _dy),
      position: position,
      hitTest: (result, transformed) =>
          c.hitTest(result, position: transformed),
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.translateByDouble(0, _dy, 0, 1);
  }
}

/// One channel row of the left column: logo tile (with a clock badge for
/// archive channels) and the name on up to two lines. Clicking it opens the
/// channel actions.
class _ChannelTile extends StatefulWidget {
  const _ChannelTile({
    super.key,
    required this.channel,
    required this.metrics,
    required this.onTap,
  });

  final ChannelView channel;
  final GuideMetrics metrics;
  final ValueChanged<Offset> onTap;

  @override
  State<_ChannelTile> createState() => _ChannelTileState();
}

class _ChannelTileState extends State<_ChannelTile> {
  Offset? _down;

  Offset _position() {
    final down = _down;
    if (down != null) return down;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return Offset.zero;
    return box.localToGlobal(box.size.centerRight(const Offset(-24, 0)));
  }

  @override
  Widget build(BuildContext context) {
    final channel = widget.channel;
    final m = widget.metrics;
    return Listener(
      onPointerDown: (e) => _down = e.position,
      child: KInteractive(
        focusable: false,
        semanticLabel: channel.displayName,
        onTap: () => widget.onTap(_position()),
        onContextMenu: widget.onTap,
        builder: (context, state, child) => AnimatedContainer(
          duration: KMotion.of(context, KDurations.hover),
          curve: KMotion.hover,
          decoration: BoxDecoration(
            color: state.pressed
                ? KColors.rowHover.withValues(alpha: 0.04)
                : state.hovered
                ? KColors.rowHover
                : KColors.bg,
            borderRadius: BorderRadius.circular(m.cellRadius),
          ),
          child: child,
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            _LogoWithBadge(channel: channel, size: m.logoSize),
            const SizedBox(width: 16),
            Expanded(
              child: _ChannelName(channel.displayName, badges: channel.badges),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

class _LogoWithBadge extends StatelessWidget {
  const _LogoWithBadge({required this.channel, required this.size});

  final ChannelView channel;
  final double size;

  @override
  Widget build(BuildContext context) {
    final logo = KLogoTile(
      name: channel.displayName,
      url: channel.logo,
      size: size,
      radius: 5,
    );
    if (!channel.hasArchive) return logo;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          logo,
          Positioned(
            right: -5,
            bottom: -5,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: KColors.surface2,
                shape: BoxShape.circle,
                border: Border.all(color: KColors.bg, width: 2),
              ),
              alignment: Alignment.center,
              child: const Icon(
                PhosphorIconsBold.clockCounterClockwise,
                size: 11,
                color: KColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Two-line channel name with its quality badges ("Show TV  FHD") that
/// shrinks before it is truncated.
class _ChannelName extends StatelessWidget {
  const _ChannelName(this.name, {this.badges = const []});

  final String name;
  final List<String> badges;

  TextSpan _span(TextStyle style) => TextSpan(
    style: style,
    children: [
      TextSpan(text: name),
      if (badges.isNotEmpty)
        TextSpan(
          text: '  ${badges.join(' ')}',
          style: style.copyWith(
            fontSize: (style.fontSize ?? 17) * 0.7,
            fontWeight: FontWeight.w600,
            color: KColors.textSecondary,
            letterSpacing: 0.3,
          ),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: _span(GuideText.channel),
          maxLines: 2,
          textDirection: TextDirection.ltr,
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final tooLong = painter.didExceedMaxLines;
        painter.dispose();
        return Text.rich(
          _span(tooLong ? GuideText.channelSmall : GuideText.channel),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}

/// The crimson top-left header cell with the day shown at the left edge of
/// the grid ("Today"); a click opens the day picker.
class _CornerCell extends StatelessWidget {
  const _CornerCell({required this.label, required this.onTap});

  final String label;
  final ValueChanged<Rect>? onTap;

  @override
  Widget build(BuildContext context) {
    final tap = onTap;
    return KInteractive(
      focusable: false,
      semanticLabel: label,
      onTap: tap == null
          ? null
          : () {
              final box = context.findRenderObject() as RenderBox?;
              if (box == null || !box.hasSize) return;
              tap(box.localToGlobal(Offset.zero) & box.size);
            },
      builder: (context, state, _) => ColoredBox(
        color: state.pressed
            ? GuideColors.pressed(GuideColors.focused)
            : state.hovered
            ? GuideColors.hovered(GuideColors.focused)
            : GuideColors.focused,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GuideText.header.copyWith(fontWeight: FontWeight.w500),
                ),
              ),
              if (tap != null) ...[
                const SizedBox(width: 6),
                const Icon(
                  PhosphorIconsBold.caretDown,
                  size: 13,
                  color: KColors.textPrimary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

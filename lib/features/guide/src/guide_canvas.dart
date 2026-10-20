/// The painted part of the guide grid: the time header and the programme
/// cells of the visible window only (both axes are virtualized), the red
/// now-line, and the scroll extents of both axes.
library;

import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../../app/time_format.dart';
import '../../../core/core.dart';
import '../../../data/repositories/repository_models.dart';
import 'guide_cache.dart';
import 'guide_cells.dart';
import 'guide_controller.dart';
import 'guide_style.dart';

/// Milliseconds per day.
const int _dayMs = 86400000;

/// Paints the header row and the programme cells; applies the content
/// dimensions of [verticalOffset] (rows) and [horizontalOffset] (time).
///
/// The left [GuideMetrics.channelColumnWidth] is left empty for the channel
/// column widgets drawn on top.
class GuideCanvas extends LeafRenderObjectWidget {
  const GuideCanvas({
    super.key,
    required this.verticalOffset,
    required this.horizontalOffset,
    required this.channels,
    required this.cache,
    required this.selection,
    required this.metrics,
    required this.originMs,
    required this.endMs,
    required this.pxPerMinute,
    required this.nowMs,
    required this.reminderKeys,
    required this.timeFormat,
    required this.noEpgLabel,
    required this.textScaler,
  });

  final ViewportOffset verticalOffset;
  final ViewportOffset horizontalOffset;
  final List<ChannelView> channels;
  final GuideProgrammeCache cache;
  final GuideSelection selection;
  final GuideMetrics metrics;

  /// Time at horizontal offset 0 (UTC ms, slot aligned).
  final int originMs;

  /// End of the scrollable time range (UTC ms).
  final int endMs;
  final double pxPerMinute;
  final int nowMs;

  /// `'<channel provider id>@<programme start ms>'` of programmes with a
  /// reminder.
  final Set<String> reminderKeys;
  final CarinaTimeFormat timeFormat;
  final String noEpgLabel;
  final TextScaler textScaler;

  @override
  RenderGuideCanvas createRenderObject(BuildContext context) =>
      RenderGuideCanvas(
        verticalOffset: verticalOffset,
        horizontalOffset: horizontalOffset,
        channels: channels,
        cache: cache,
        selection: selection,
        metrics: metrics,
        originMs: originMs,
        endMs: endMs,
        pxPerMinute: pxPerMinute,
        nowMs: nowMs,
        reminderKeys: reminderKeys,
        timeFormat: timeFormat,
        noEpgLabel: noEpgLabel,
        textScaler: textScaler,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderGuideCanvas renderObject,
  ) {
    renderObject
      ..verticalOffset = verticalOffset
      ..horizontalOffset = horizontalOffset
      ..channels = channels
      ..cache = cache
      ..selection = selection
      ..metrics = metrics
      ..setTimeline(originMs: originMs, endMs: endMs, pxPerMinute: pxPerMinute)
      ..nowMs = nowMs
      ..reminderKeys = reminderKeys
      ..timeFormat = timeFormat
      ..noEpgLabel = noEpgLabel
      ..textScaler = textScaler;
  }
}

class RenderGuideCanvas extends RenderBox {
  RenderGuideCanvas({
    required ViewportOffset verticalOffset,
    required ViewportOffset horizontalOffset,
    required this._channels,
    required this._cache,
    required this._selection,
    required this._metrics,
    required this._originMs,
    required this._endMs,
    required this._pxPerMinute,
    required this._nowMs,
    required this._reminderKeys,
    required this._timeFormat,
    required this._noEpgLabel,
    required this._textScaler,
  }) : _vertical = verticalOffset,
       _horizontal = horizontalOffset;

  ViewportOffset _vertical;
  set verticalOffset(ViewportOffset value) {
    if (identical(value, _vertical)) return;
    if (attached) _vertical.removeListener(markNeedsPaint);
    _vertical = value;
    if (attached) _vertical.addListener(markNeedsPaint);
    markNeedsLayout();
  }

  ViewportOffset _horizontal;
  set horizontalOffset(ViewportOffset value) {
    if (identical(value, _horizontal)) return;
    if (attached) _horizontal.removeListener(markNeedsPaint);
    _horizontal = value;
    if (attached) _horizontal.addListener(markNeedsPaint);
    markNeedsLayout();
  }

  List<ChannelView> _channels;
  set channels(List<ChannelView> value) {
    if (identical(value, _channels)) return;
    _channels = value;
    markNeedsLayout();
  }

  GuideProgrammeCache _cache;
  set cache(GuideProgrammeCache value) {
    if (identical(value, _cache)) return;
    if (attached) _cache.removeListener(markNeedsPaint);
    _cache = value;
    if (attached) _cache.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  GuideSelection _selection;
  set selection(GuideSelection value) {
    if (identical(value, _selection)) return;
    if (attached) _selection.removeListener(markNeedsPaint);
    _selection = value;
    if (attached) _selection.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  GuideMetrics _metrics;
  set metrics(GuideMetrics value) {
    if (value == _metrics) return;
    _metrics = value;
    markNeedsLayout();
  }

  int _originMs;
  int _endMs;
  double _pxPerMinute;

  /// Time kept at the left edge when the timeline changes (zoom, window
  /// size, range): applied in the next layout.
  int? _anchorMs;

  void setTimeline({
    required int originMs,
    required int endMs,
    required double pxPerMinute,
  }) {
    if (originMs == _originMs &&
        endMs == _endMs &&
        pxPerMinute == _pxPerMinute) {
      return;
    }
    if (originMs != _originMs || pxPerMinute != _pxPerMinute) {
      _anchorMs ??= _timeAtPixels(
        _horizontal.hasPixels ? _horizontal.pixels : 0,
      );
    }
    _originMs = originMs;
    _endMs = endMs;
    _pxPerMinute = pxPerMinute;
    markNeedsLayout();
  }

  int _nowMs;
  set nowMs(int value) {
    if (value == _nowMs) return;
    _nowMs = value;
    markNeedsPaint();
  }

  Set<String> _reminderKeys;
  set reminderKeys(Set<String> value) {
    if (identical(value, _reminderKeys)) return;
    _reminderKeys = value;
    markNeedsPaint();
  }

  CarinaTimeFormat _timeFormat;
  set timeFormat(CarinaTimeFormat value) {
    if (identical(value, _timeFormat)) return;
    _timeFormat = value;
    _slotLabels.clear();
    markNeedsPaint();
  }

  String _noEpgLabel;
  set noEpgLabel(String value) {
    if (value == _noEpgLabel) return;
    _noEpgLabel = value;
    markNeedsPaint();
  }

  TextScaler _textScaler;
  set textScaler(TextScaler value) {
    if (value == _textScaler) return;
    _textScaler = value;
    _text.clear();
    markNeedsPaint();
  }

  final _TextCache _text = _TextCache();

  /// Labels of the cells being painted, drawn after the now-line so the
  /// line never covers a title.
  final List<(TextPainter, Offset)> _labels = [];
  final Map<int, String> _slotLabels = {};
  final Paint _fill = Paint();

  double get _pxPerMs => _pxPerMinute / kMinuteMs;

  int _timeAtPixels(double pixels) => _originMs + (pixels / _pxPerMs).round();

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _vertical.addListener(markNeedsPaint);
    _horizontal.addListener(markNeedsPaint);
    _cache.addListener(markNeedsPaint);
    _selection.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _vertical.removeListener(markNeedsPaint);
    _horizontal.removeListener(markNeedsPaint);
    _cache.removeListener(markNeedsPaint);
    _selection.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void dispose() {
    _text.clear();
    super.dispose();
  }

  @override
  bool get isRepaintBoundary => true;

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  void performLayout() {
    final m = _metrics;
    final viewportWidth = math.max(0.0, size.width - m.channelColumnWidth);
    final viewportHeight = math.max(0.0, size.height - m.headerHeight);

    _horizontal.applyViewportDimension(viewportWidth);
    final anchor = _anchorMs;
    if (anchor != null && _horizontal.hasPixels) {
      final target = (anchor - _originMs) * _pxPerMs;
      _horizontal.correctBy(target - _horizontal.pixels);
      _anchorMs = null;
    }
    final contentWidth = (_endMs - _originMs) * _pxPerMs;
    _horizontal.applyContentDimensions(
      0,
      math.max(0.0, contentWidth - viewportWidth),
    );

    _vertical.applyViewportDimension(viewportHeight);
    final contentHeight = _channels.isEmpty
        ? 0.0
        : _channels.length * m.rowPitch - m.rowGap + m.bottomPadding;
    _vertical.applyContentDimensions(
      0,
      math.max(0.0, contentHeight - viewportHeight),
    );
  }

  @override
  bool hitTestSelf(Offset position) => true;

  // ---------------------------------------------------------------- painting

  @override
  void paint(PaintingContext context, Offset offset) {
    final m = _metrics;
    final viewportWidth = size.width - m.channelColumnWidth;
    if (viewportWidth <= 0 || size.height <= m.headerHeight) return;
    final canvas = context.canvas;
    final hx = _horizontal.hasPixels ? _horizontal.pixels : 0.0;
    final vy = _vertical.hasPixels ? _vertical.pixels : 0.0;
    final pxPerMs = _pxPerMs;
    final left = offset.dx + m.channelColumnWidth;
    final leftMs = _originMs + (hx / pxPerMs).floor();
    final rightMs = _originMs + ((hx + viewportWidth) / pxPerMs).ceil();
    double xOf(int ms) => left + (ms - _originMs) * pxPerMs - hx;

    // Time header.
    canvas
      ..save()
      ..clipRect(Rect.fromLTWH(left, offset.dy, viewportWidth, m.headerHeight));
    for (var slot = floorToSlot(leftMs); slot < rightMs; slot += kSlotMs) {
      final x0 = xOf(slot);
      final x1 = xOf(slot + kSlotMs) - m.cellGap;
      if (x1 <= x0) continue;
      final current = slot <= _nowMs && _nowMs < slot + kSlotMs;
      _fill.color = current ? GuideColors.focused : GuideColors.header;
      canvas.drawRect(
        Rect.fromLTRB(x0, offset.dy, x1, offset.dy + m.headerHeight),
        _fill,
      );
      final label = _slotLabels.putIfAbsent(
        slot,
        () => _timeFormat.time(
          DateTime.fromMillisecondsSinceEpoch(slot, isUtc: true),
        ),
      );
      final tp = _text.get(
        label,
        _TextStyleId.header,
        x1 - x0 - 8,
        _textScaler,
      );
      tp.paint(
        canvas,
        Offset(
          x0 + (x1 - x0 - tp.width) / 2,
          offset.dy + (m.headerHeight - tp.height) / 2,
        ),
      );
    }
    canvas.restore();

    // Cells.
    final top = offset.dy + m.headerHeight;
    final viewportHeight = size.height - m.headerHeight;
    canvas
      ..save()
      ..clipRect(Rect.fromLTWH(left, top, viewportWidth, viewportHeight));
    final n = _channels.length;
    if (n > 0) {
      final pitch = m.rowPitch;
      final firstRow = math.max(0, (vy / pitch).floor());
      final lastRow = math.min(n - 1, ((vy + viewportHeight) / pitch).floor());
      for (var r = firstRow; r <= lastRow; r++) {
        final y = top + r * pitch - vy;
        final channel = _channels[r];
        forEachRowCell(
          _cache,
          channel.epgKey,
          leftMs,
          rightMs,
          (s, e, kind, p) => _paintCell(
            canvas,
            row: r,
            channel: channel,
            startMs: s,
            stopMs: e,
            kind: kind,
            programme: p,
            x0: xOf(s),
            x1: xOf(e) - m.cellGap,
            clipLeft: left,
            y: y,
          ),
        );
      }
    }

    // Now-line: under the labels and broken around them, with a small
    // marker at the bottom of the time header.
    if (_nowMs >= leftMs && _nowMs <= rightMs) {
      final x = xOf(_nowMs);
      _fill.color = KColors.accent;
      final skips = <(double, double)>[
        for (final (painter, at) in _labels)
          if (x >= at.dx - 4 && x <= at.dx + painter.width + 4)
            (at.dy - 3, at.dy + painter.height + 3),
      ]..sort((a, b) => a.$1.compareTo(b.$1));
      var y = top;
      final bottom = top + viewportHeight;
      for (final (from, to) in skips) {
        if (from > y) {
          canvas.drawRect(Rect.fromLTRB(x - 1, y, x + 1, from), _fill);
        }
        if (to > y) y = to;
      }
      if (y < bottom) {
        canvas.drawRect(Rect.fromLTRB(x - 1, y, x + 1, bottom), _fill);
      }
      canvas.drawPath(
        Path()
          ..moveTo(x - 6, top)
          ..lineTo(x + 6, top)
          ..lineTo(x, top + 7)
          ..close(),
        _fill,
      );
    }
    for (final (painter, at) in _labels) {
      painter.paint(canvas, at);
    }
    _labels.clear();
    canvas.restore();
  }

  void _paintCell(
    Canvas canvas, {
    required int row,
    required ChannelView channel,
    required int startMs,
    required int stopMs,
    required GuideCellKind kind,
    required ProgrammeView? programme,
    required double x0,
    required double x1,
    required double clipLeft,
    required double y,
  }) {
    final m = _metrics;
    // Cells that began before the window stick to its left edge.
    final l = math.max(x0, clipLeft);
    if (x1 - l < 1) return;
    final focused = _selection.isFocused(row, startMs);
    final hovered = _selection.isHovered(row, startMs);
    final onAir = startMs <= _nowMs && _nowMs < stopMs;
    final ended = stopMs <= _nowMs;
    final replayable =
        ended &&
        channel.archiveDays > 0 &&
        startMs > _nowMs - channel.archiveDays * _dayMs;
    final dim = kind == GuideCellKind.programme && ended && !replayable;

    Color fill;
    if (kind == GuideCellKind.loading) {
      fill = GuideColors.loading;
    } else if (focused) {
      fill = GuideColors.focused;
    } else if (onAir) {
      fill = GuideColors.onAir;
    } else if (dim) {
      fill = GuideColors.past;
    } else {
      fill = GuideColors.future;
    }
    if (hovered) {
      fill = _selection.pressed
          ? GuideColors.pressed(fill)
          : GuideColors.hovered(fill);
    }
    _fill.color = fill;
    final rect = Rect.fromLTRB(l, y, x1, y + m.rowHeight);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(m.cellRadius)),
      _fill,
    );
    if (kind == GuideCellKind.loading) return;

    final style = focused || onAir
        ? _TextStyleId.cellBright
        : dim
        ? _TextStyleId.cellDim
        : _TextStyleId.cell;
    final width = x1 - l;
    final available = width - m.cellPadding * 2;
    final hasBell =
        programme != null &&
        _reminderKeys.contains('${channel.providerId}@$startMs');
    const bellSize = 16.0;
    final showBell = hasBell && available >= 60;
    if (available < 24) {
      if (width < 12) return;
      final tp = _text.get('…', style, width, _textScaler);
      _labels.add((
        tp,
        Offset(l + (width - tp.width) / 2, y + (m.rowHeight - tp.height) / 2),
      ));
      return;
    }
    final title = programme == null
        ? _noEpgLabel
        : (programme.title.trim().isEmpty ? '…' : programme.title);
    final textWidth = available - (showBell ? bellSize + 8 : 0);
    final tp = _text.get(title, style, textWidth, _textScaler);
    _labels.add((
      tp,
      Offset(l + m.cellPadding, y + (m.rowHeight - tp.height) / 2),
    ));
    if (showBell) {
      final icon = _text.icon(
        PhosphorIconsFill.bell,
        bellSize,
        focused || onAir ? KColors.textPrimary : KColors.textSecondary,
      );
      _labels.add((
        icon,
        Offset(
          x1 - m.cellPadding - icon.width,
          y + (m.rowHeight - icon.height) / 2,
        ),
      ));
    }
  }
}

enum _TextStyleId { header, cell, cellBright, cellDim }

TextStyle _styleFor(_TextStyleId id) => switch (id) {
  _TextStyleId.header => GuideText.header,
  _TextStyleId.cell => GuideText.cell,
  _TextStyleId.cellBright => GuideText.cell.copyWith(
    color: KColors.textPrimary,
  ),
  _TextStyleId.cellDim => GuideText.cell.copyWith(color: KColors.textTertiary),
};

/// LRU cache of laid-out single-line labels. A label is laid out once at
/// its natural width and reused whenever it fits; only labels that must be
/// truncated get an ellipsized layout, at widths bucketed to 24 px, so cells
/// clipped by the scrolling window edge rarely re-layout.
class _TextCache {
  static const int _capacity = 1200;
  static const int _bucket = 24;
  final LinkedHashMap<_TextKey, TextPainter> _map = LinkedHashMap();

  TextPainter get(
    String text,
    _TextStyleId style,
    double maxWidth,
    TextScaler scaler,
  ) {
    final natural = _layout(_TextKey(text, style.index, -1), scaler, null);
    if (natural.width <= maxWidth) return natural;
    final bucket = (math.max(0.0, maxWidth) / _bucket).floor() * _bucket;
    return _layout(_TextKey(text, style.index, bucket), scaler, bucket);
  }

  TextPainter _layout(_TextKey key, TextScaler scaler, int? width) {
    final hit = _map.remove(key);
    if (hit != null) {
      _map[key] = hit;
      return hit;
    }
    final tp = TextPainter(
      text: TextSpan(
        text: key.text,
        style: _styleFor(_TextStyleId.values[key.style]),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: width == null ? null : '…',
      textScaler: scaler,
    )..layout(maxWidth: width == null ? double.infinity : width.toDouble());
    _put(key, tp);
    return tp;
  }

  TextPainter icon(IconData icon, double size, Color color) {
    final key = _TextKey(
      'icon:${icon.codePoint}:${color.toARGB32()}',
      -1,
      size.round(),
    );
    final hit = _map.remove(key);
    if (hit != null) {
      _map[key] = hit;
      return hit;
    }
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: size,
          height: 1,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    _put(key, tp);
    return tp;
  }

  void _put(_TextKey key, TextPainter tp) {
    _map[key] = tp;
    while (_map.length > _capacity) {
      final oldest = _map.keys.first;
      _map.remove(oldest)!.dispose();
    }
  }

  void clear() {
    for (final tp in _map.values) {
      tp.dispose();
    }
    _map.clear();
  }
}

@immutable
class _TextKey {
  const _TextKey(this.text, this.style, this.width);

  final String text;
  final int style;
  final int width;

  @override
  bool operator ==(Object other) =>
      other is _TextKey &&
      other.text == text &&
      other.style == style &&
      other.width == width;

  @override
  int get hashCode => Object.hash(text, style, width);
}

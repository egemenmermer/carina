/// Multi-channel layouts and their tile geometry.
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// The three layouts of the top-bar picker.
enum MultiviewLayout {
  /// Two tiles side by side ("1 + 1").
  sideBySide(2),

  /// Four equal tiles ("2 × 2").
  grid2x2(4),

  /// One big tile and three small ones in a column at its right ("1 + 3").
  onePlusThree(4);

  const MultiviewLayout(this.slots);

  /// How many tiles the layout shows.
  final int slots;

  /// [preferred], or a 4-slot layout when [tiles] do not fit in it.
  static MultiviewLayout fitting(int tiles, MultiviewLayout preferred) {
    if (tiles <= preferred.slots) return preferred;
    return MultiviewLayout.grid2x2;
  }
}

const double _ratio = 16 / 9;

/// Tile rectangles of [layout] inside [area] (16:9 tiles, centered, [gap]
/// between them). Index 0 is the main tile.
List<Rect> multiviewRects(MultiviewLayout layout, Size area, {double gap = 8}) {
  final w = area.width;
  final h = area.height;
  if (w <= 0 || h <= 0) return List.filled(layout.slots, Rect.zero);
  switch (layout) {
    case MultiviewLayout.sideBySide:
      var tw = (w - gap) / 2;
      var th = tw / _ratio;
      if (th > h) {
        th = h;
        tw = th * _ratio;
      }
      final x = (w - (tw * 2 + gap)) / 2;
      final y = (h - th) / 2;
      return [
        Rect.fromLTWH(x, y, tw, th),
        Rect.fromLTWH(x + tw + gap, y, tw, th),
      ];
    case MultiviewLayout.grid2x2:
      var tw = (w - gap) / 2;
      var th = tw / _ratio;
      if (th * 2 + gap > h) {
        th = (h - gap) / 2;
        tw = th * _ratio;
      }
      final x = (w - (tw * 2 + gap)) / 2;
      final y = (h - (th * 2 + gap)) / 2;
      return [
        Rect.fromLTWH(x, y, tw, th),
        Rect.fromLTWH(x + tw + gap, y, tw, th),
        Rect.fromLTWH(x, y + th + gap, tw, th),
        Rect.fromLTWH(x + tw + gap, y + th + gap, tw, th),
      ];
    case MultiviewLayout.onePlusThree:
      // Three small tiles stacked with two gaps are as tall as the big one:
      // 3·hs + 2·gap = hb, so wb = 3·ws + 2·gap·r and
      // wb + gap + ws = w  →  ws = (w − gap − 2·gap·r) / 4.
      var ws = (w - gap - 2 * gap * _ratio) / 4;
      var hs = ws / _ratio;
      var hb = 3 * hs + 2 * gap;
      var wb = hb * _ratio;
      if (hb > h) {
        hb = h;
        wb = hb * _ratio;
        hs = (hb - 2 * gap) / 3;
        ws = hs * _ratio;
      }
      final x = (w - (wb + gap + ws)) / 2;
      final y = (h - hb) / 2;
      return [
        Rect.fromLTWH(x, y, wb, hb),
        for (var i = 0; i < 3; i++)
          Rect.fromLTWH(x + wb + gap, y + i * (hs + gap), ws, hs),
      ];
  }
}

/// The tile in [direction] from [from] among [rects] (closest center in
/// that half-plane), or [from] when there is none.
int neighborTile(List<Rect> rects, int from, TraversalDirection direction) {
  if (from < 0 || from >= rects.length) return 0;
  final vertical =
      direction == TraversalDirection.up ||
      direction == TraversalDirection.down;
  final origin = rects[from].center;
  var best = from;
  var bestScore = double.infinity;
  for (var i = 0; i < rects.length; i++) {
    if (i == from) continue;
    final d = rects[i].center - origin;
    final inDirection = switch (direction) {
      TraversalDirection.left => d.dx < -1,
      TraversalDirection.right => d.dx > 1,
      TraversalDirection.up => d.dy < -1,
      TraversalDirection.down => d.dy > 1,
    };
    if (!inDirection) continue;
    final along = vertical ? d.dy.abs() : d.dx.abs();
    final across = vertical ? d.dx.abs() : d.dy.abs();
    final score = along + across * 2;
    if (score < bestScore) {
      bestScore = score;
      best = i;
    }
  }
  return best;
}

/// Keeps [value] inside 0…[length] − 1.
int clampIndex(int value, int length) =>
    length <= 0 ? 0 : math.min(math.max(value, 0), length - 1);

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/core.dart';

/// The full-width progress bar of the VOD / catch-up player: red played
/// part over the buffered and the track, a white knob and a time tooltip
/// on hover, click or drag to seek. The elapsed label follows the playhead
///; [endLabel] sits at the right edge.
class PlayerSeekBar extends StatefulWidget {
  const PlayerSeekBar({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeek,
    required this.playheadLabel,
    required this.endLabel,
    this.buffered = Duration.zero,
    this.startLabel,
    this.hoverLabel,
    this.onInteraction,
  });

  final Duration position;
  final Duration duration;
  final Duration buffered;
  final ValueChanged<Duration> onSeek;

  /// Text under the playhead for a position (`0:13`, or `20:12` for
  /// catch-up).
  final String Function(Duration position) playheadLabel;

  /// Right label (`-2:46`, or the programme end).
  final String endLabel;

  /// Fixed left label (catch-up: the programme start); the playhead label
  /// then only shows when it does not collide with either end.
  final String? startLabel;

  /// Tooltip text at the hovered position (defaults to [playheadLabel]).
  final String Function(Duration position)? hoverLabel;

  /// Called on hover / drag so the parent keeps the controls visible.
  final VoidCallback? onInteraction;

  @override
  State<PlayerSeekBar> createState() => _PlayerSeekBarState();
}

class _PlayerSeekBarState extends State<PlayerSeekBar> {
  double? _hoverX;
  double? _dragFraction;

  static const double _barTop = 10;
  static const double _labelTop = 26;
  static const double height = 46;

  static final TextStyle _labelStyle = KText.time.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: KColors.textPrimary,
  );

  double get _fraction {
    final d = widget.duration.inMilliseconds;
    if (_dragFraction != null) return _dragFraction!;
    if (d <= 0) return 0;
    return (widget.position.inMilliseconds / d).clamp(0.0, 1.0);
  }

  double get _bufferedFraction {
    final d = widget.duration.inMilliseconds;
    if (d <= 0) return 0;
    return (widget.buffered.inMilliseconds / d).clamp(0.0, 1.0);
  }

  Duration _at(double fraction) => Duration(
    milliseconds: (widget.duration.inMilliseconds * fraction.clamp(0.0, 1.0))
        .round(),
  );

  double _fractionOf(double x, double width) =>
      width <= 0 ? 0 : (x / width).clamp(0.0, 1.0);

  static double _textWidth(String text, TextStyle style, TextScaler scaler) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final w = painter.width;
    painter.dispose();
    return w;
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.duration > Duration.zero;
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final scaler = MediaQuery.textScalerOf(context);
          final fraction = _fraction;
          final playX = width * fraction;
          final active = _hoverX != null || _dragFraction != null;
          final playhead = widget.playheadLabel(_at(fraction));
          final playheadW = _textWidth(playhead, _labelStyle, scaler);
          final endW = _textWidth(widget.endLabel, _labelStyle, scaler);
          final startW = widget.startLabel == null
              ? 0.0
              : _textWidth(widget.startLabel!, _labelStyle, scaler);
          final labelLeft = (playX - playheadW / 2)
              .clamp(0.0, math.max(0.0, width - endW - 12 - playheadW))
              .toDouble();
          var showPlayhead = true;
          if (widget.startLabel != null) {
            showPlayhead =
                labelLeft > startW + 12 &&
                labelLeft + playheadW < width - endW - 12;
          }
          final hoverX = _hoverX;
          String? tooltip;
          if (hoverX != null && enabled) {
            final at = _at(_fractionOf(hoverX, width));
            tooltip = (widget.hoverLabel ?? widget.playheadLabel)(at);
          } else if (_dragFraction != null) {
            tooltip = widget.playheadLabel(_at(_dragFraction!));
          }
          final tooltipX = hoverX ?? playX;
          return MouseRegion(
            cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
            onHover: (e) {
              setState(() => _hoverX = e.localPosition.dx.clamp(0.0, width));
              widget.onInteraction?.call();
            },
            onExit: (_) => setState(() => _hoverX = null),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: enabled
                  ? (d) => widget.onSeek(
                      _at(_fractionOf(d.localPosition.dx, width)),
                    )
                  : null,
              onHorizontalDragStart: enabled
                  ? (d) => setState(
                      () => _dragFraction = _fractionOf(
                        d.localPosition.dx,
                        width,
                      ),
                    )
                  : null,
              onHorizontalDragUpdate: enabled
                  ? (d) {
                      setState(
                        () => _dragFraction = _fractionOf(
                          d.localPosition.dx,
                          width,
                        ),
                      );
                      widget.onInteraction?.call();
                    }
                  : null,
              onHorizontalDragEnd: enabled
                  ? (_) {
                      final f = _dragFraction;
                      setState(() => _dragFraction = null);
                      if (f != null) widget.onSeek(_at(f));
                    }
                  : null,
              onHorizontalDragCancel: () =>
                  setState(() => _dragFraction = null),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: _barTop - (active ? 1 : 0),
                    height: active ? 6 : 4,
                    child: CustomPaint(
                      painter: _BarPainter(
                        played: fraction,
                        buffered: _bufferedFraction,
                      ),
                    ),
                  ),
                  if (active && enabled)
                    Positioned(
                      left: playX - 8,
                      top: _barTop - 6,
                      child: const IgnorePointer(child: _Knob()),
                    ),
                  if (widget.startLabel != null)
                    Positioned(
                      left: 0,
                      top: _labelTop,
                      child: Text(widget.startLabel!, style: _labelStyle),
                    ),
                  if (showPlayhead)
                    Positioned(
                      left: labelLeft,
                      top: _labelTop,
                      child: Text(
                        playhead,
                        key: const ValueKey('player-elapsed'),
                        style: _labelStyle,
                      ),
                    ),
                  Positioned(
                    right: 0,
                    top: _labelTop,
                    child: Text(
                      widget.endLabel,
                      key: const ValueKey('player-remaining'),
                      style: _labelStyle,
                    ),
                  ),
                  if (tooltip != null)
                    Positioned(
                      left: (tooltipX - 34)
                          .clamp(0.0, math.max(0.0, width - 68))
                          .toDouble(),
                      top: -34,
                      child: IgnorePointer(child: _Tooltip(text: tooltip)),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter({required this.played, required this.buffered});

  final double played;
  final double buffered;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Radius.circular(size.height / 2);
    final track = RRect.fromRectAndRadius(Offset.zero & size, r);
    canvas.drawRRect(track, Paint()..color = const Color(0x40FFFFFF));
    if (buffered > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width * buffered, size.height),
          r,
        ),
        Paint()..color = const Color(0x40FFFFFF),
      );
    }
    if (played > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width * played, size.height),
          r,
        ),
        Paint()..color = KColors.accent,
      );
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.played != played || old.buffered != buffered;
}

class _Knob extends StatelessWidget {
  const _Knob();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Color(0x66000000), blurRadius: 6)],
      ),
    );
  }
}

class _Tooltip extends StatelessWidget {
  const _Tooltip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 68),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xE6202022),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: KColors.materialStroke),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: KText.chip.copyWith(fontSize: 13),
      ),
    );
  }
}

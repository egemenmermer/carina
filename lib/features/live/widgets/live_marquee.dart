import 'package:flutter/widgets.dart';

import '../../../core/core.dart';

/// One line of text that slowly scrolls when it does not fit and [active]
/// is true (the selected channel card's programme, as in the
/// reference). Otherwise — and with reduced motion — it ends with an
/// ellipsis.
class LiveMarquee extends StatelessWidget {
  const LiveMarquee({
    super.key,
    required this.text,
    required this.style,
    this.active = true,
  });

  final String text;
  final TextStyle style;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final plain = Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
      style: style,
    );
    if (!active || KMotion.reduced(context)) return plain;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedWidth) return plain;
        final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 1,
        )..layout();
        final size = painter.size;
        painter.dispose();
        final overflow = size.width - constraints.maxWidth;
        if (overflow <= 1) return plain;
        return _MarqueeScroller(
          text: text,
          style: style,
          textSize: size,
          viewport: constraints.maxWidth,
          overflow: overflow,
        );
      },
    );
  }
}

class _MarqueeScroller extends StatefulWidget {
  const _MarqueeScroller({
    required this.text,
    required this.style,
    required this.textSize,
    required this.viewport,
    required this.overflow,
  });

  final String text;
  final TextStyle style;
  final Size textSize;
  final double viewport;
  final double overflow;

  @override
  State<_MarqueeScroller> createState() => _MarqueeScrollerState();
}

class _MarqueeScrollerState extends State<_MarqueeScroller>
    with SingleTickerProviderStateMixin {
  static const double _speed = 32; // logical px per second
  static const Duration _pause = Duration(milliseconds: 1600);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _cycle(widget.overflow),
  )..repeat();

  /// Pause, scroll to the end, pause, jump back.
  static Duration _cycle(double overflow) {
    final scroll = (overflow / _speed * 1000).round().clamp(600, 20000);
    return _pause * 2 + Duration(milliseconds: scroll);
  }

  @override
  void didUpdateWidget(_MarqueeScroller oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.overflow != widget.overflow ||
        oldWidget.text != widget.text) {
      _controller
        ..duration = _cycle(widget.overflow)
        ..repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _offset(double t) {
    final total = _controller.duration!.inMilliseconds;
    final pause = _pause.inMilliseconds / total;
    if (t <= pause) return 0;
    if (t >= 1 - pause) return widget.overflow;
    return Curves.easeInOut.transform((t - pause) / (1 - 2 * pause)) *
        widget.overflow;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.viewport,
      height: widget.textSize.height,
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => Transform.translate(
            offset: Offset(-_offset(_controller.value), 0),
            child: child,
          ),
          child: OverflowBox(
            alignment: Alignment.centerLeft,
            minWidth: widget.textSize.width,
            maxWidth: widget.textSize.width,
            child: Text(
              widget.text,
              maxLines: 1,
              softWrap: false,
              style: widget.style,
            ),
          ),
        ),
      ),
    );
  }
}

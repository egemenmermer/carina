import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:carina/core/icons/phosphor_icons.dart';

import 'package:carina/core/strings.dart';
import 'package:carina/core/tokens.dart';
import 'package:carina/core/widgets/k_interactive.dart';

/// Horizontal, lazily built row of equally sized cards (Continue watching,
/// Recently added, provider categories).
///
/// * The mouse wheel scrolls the row horizontally while the pointer is over
///   it; at either end the wheel falls through to the page.
/// * Round arrow buttons fade in at the edges on hover and page by ~80% of
///   the width, snapping to card boundaries.
/// * Left / Right move keyboard focus between cards (also into cards that
///   are not built yet); the focused card is kept fully visible.
/// * [focusPadding] leaves vertical room for the 1.04 focus scale; the row
///   does not clip by default so the focus shadow can spill out (use
///   [clipBehavior] for rows inside panels).
///
/// The row is `itemHeight + 2 × focusPadding` tall.
class KHorizontalRow extends StatefulWidget {
  const KHorizontalRow({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.itemWidth,
    required this.itemHeight,
    this.spacing = KSpacing.rowGap,
    this.padding = const EdgeInsets.symmetric(horizontal: KSpacing.gutter),
    this.focusPadding = 14,
    this.controller,
    this.showArrows = true,
    this.wheelScrollsHorizontally = true,
    this.onFocusedIndexChanged,
    this.clipBehavior = Clip.none,
  });

  final int itemCount;

  /// Builds card [index]; typically a [FocusableCard].
  final IndexedWidgetBuilder itemBuilder;

  /// Width of every card.
  final double itemWidth;

  /// Height of every card.
  final double itemHeight;

  /// Gap between cards.
  final double spacing;

  /// Horizontal padding inside the scroll view (page gutter).
  final EdgeInsetsGeometry padding;

  /// Vertical room above and below the cards for the focus treatment.
  final double focusPadding;

  final ScrollController? controller;

  /// Show the edge arrow buttons on hover.
  final bool showArrows;

  /// Map vertical wheel movement to horizontal scrolling while hovered.
  final bool wheelScrollsHorizontally;

  /// Called when keyboard focus moves to card [index] (hero updates).
  final ValueChanged<int>? onFocusedIndexChanged;

  final Clip clipBehavior;

  @override
  State<KHorizontalRow> createState() => KHorizontalRowState();
}

/// State of [KHorizontalRow]; exposes [focusIndex] and [scrollToIndex].
class KHorizontalRowState extends State<KHorizontalRow> {
  ScrollController? _ownController;
  final Map<int, _RowItemState> _items = {};
  bool _hovered = false;
  bool _canLeft = false;
  bool _canRight = false;
  int? _focusedIndex;
  double? _wheelTarget;

  ScrollController get _controller =>
      widget.controller ?? (_ownController ??= ScrollController());

  double get _extent => widget.itemWidth + widget.spacing;

  EdgeInsets get _padding => widget.padding.resolve(Directionality.of(context));

  /// Index of the card that currently has keyboard focus.
  int? get focusedIndex => _focusedIndex;

  @override
  void dispose() {
    _ownController?.dispose();
    super.dispose();
  }

  void _updateEdges(ScrollMetrics m) {
    final left = m.pixels > m.minScrollExtent + 0.5;
    final right = m.pixels < m.maxScrollExtent - 0.5;
    if (left != _canLeft || right != _canRight) {
      setState(() {
        _canLeft = left;
        _canRight = right;
      });
    }
  }

  Future<void> _animateTo(double target, {Duration? duration}) {
    final position = _controller.position;
    final clamped = target.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    final d = KMotion.of(context, duration ?? KDurations.scroll);
    if (d == Duration.zero) {
      _controller.jumpTo(clamped);
      return Future.value();
    }
    return _controller.animateTo(clamped, duration: d, curve: KMotion.enter);
  }

  /// Scrolls so card [index] is fully visible.
  Future<void> scrollToIndex(int index, {bool animate = true}) async {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    final pad = _padding;
    final left = pad.left + index * _extent;
    final right = left + widget.itemWidth;
    double? target;
    if (left - pad.left < position.pixels) {
      target = left - pad.left;
    } else if (right + pad.right >
        position.pixels + position.viewportDimension) {
      target = right + pad.right - position.viewportDimension;
    }
    if (target == null) return;
    if (animate) {
      await _animateTo(target);
    } else {
      _controller.jumpTo(
        target.clamp(position.minScrollExtent, position.maxScrollExtent),
      );
    }
  }

  /// Moves keyboard focus to card [index], scrolling it into view first when
  /// it is not built yet.
  void focusIndex(int index) {
    if (index < 0 || index >= widget.itemCount) return;
    final item = _items[index];
    if (item != null && item.requestFocus()) return;
    scrollToIndex(index, animate: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _items[index]?.requestFocus();
    });
  }

  void _page(int direction) {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    final raw = position.pixels + direction * position.viewportDimension * 0.8;
    final snapped = (raw / _extent).round() * _extent;
    _animateTo(snapped);
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (!widget.wheelScrollsHorizontally || event is! PointerScrollEvent) {
      return;
    }
    if (!_controller.hasClients) return;
    final dx = event.scrollDelta.dx;
    final dy = event.scrollDelta.dy;
    final delta = dy.abs() >= dx.abs() ? dy : dx;
    if (delta == 0) return;
    final position = _controller.position;
    final base = _wheelTarget ?? position.pixels;
    final target = (base + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    // At an end: let the page scroll instead.
    if ((target - position.pixels).abs() < 0.5 && _wheelTarget == null) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (_) {
      _wheelTarget = target;
      _animateTo(
        target,
        duration: const Duration(milliseconds: 160),
      ).whenComplete(() {
        if (_wheelTarget == target) _wheelTarget = null;
      });
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final current = _focusedIndex;
    if (current == null) return KeyEventResult.ignored;
    final int direction;
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      direction = 1;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      direction = -1;
    } else {
      return KeyEventResult.ignored;
    }
    final next = current + direction;
    if (next < 0 || next >= widget.itemCount) return KeyEventResult.ignored;
    focusIndex(next);
    return KeyEventResult.handled;
  }

  void _onItemFocusChanged(int index, bool hasFocus) {
    if (hasFocus) {
      _focusedIndex = index;
      widget.onFocusedIndexChanged?.call(index);
      scrollToIndex(index);
    } else if (_focusedIndex == index) {
      _focusedIndex = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = _padding;
    final strings = KStrings.of(context);
    final list = ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: NotificationListener<ScrollMetricsNotification>(
        onNotification: (n) {
          _updateEdges(n.metrics);
          return false;
        },
        child: NotificationListener<ScrollUpdateNotification>(
          onNotification: (n) {
            _updateEdges(n.metrics);
            return false;
          },
          child: ListView.builder(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            clipBehavior: widget.clipBehavior,
            padding: EdgeInsets.fromLTRB(
              pad.left,
              widget.focusPadding,
              (pad.right - widget.spacing).clamp(0, double.infinity),
              widget.focusPadding,
            ),
            itemExtent: _extent,
            itemCount: widget.itemCount,
            itemBuilder: (context, index) => Padding(
              padding: EdgeInsets.only(right: widget.spacing),
              child: _RowItem(
                index: index,
                row: this,
                child: widget.itemBuilder(context, index),
              ),
            ),
          ),
        ),
      ),
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: SizedBox(
        height: widget.itemHeight + widget.focusPadding * 2,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Listener(
                onPointerSignal: _onPointerSignal,
                child: Focus(
                  canRequestFocus: false,
                  skipTraversal: true,
                  onKeyEvent: _onKey,
                  child: list,
                ),
              ),
            ),
            if (widget.showArrows) ...[
              _EdgeArrow(
                left: true,
                visible: _hovered && _canLeft,
                tooltip: strings.scrollLeft,
                inset: (pad.left - 44) / 2,
                onTap: () => _page(-1),
              ),
              _EdgeArrow(
                left: false,
                visible: _hovered && _canRight,
                tooltip: strings.scrollRight,
                inset: (pad.right - 44) / 2,
                onTap: () => _page(1),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RowItem extends StatefulWidget {
  const _RowItem({required this.index, required this.row, required this.child});

  final int index;
  final KHorizontalRowState row;
  final Widget child;

  @override
  State<_RowItem> createState() => _RowItemState();
}

class _RowItemState extends State<_RowItem> {
  late final FocusNode _node = FocusNode(
    canRequestFocus: false,
    skipTraversal: true,
    debugLabel: 'KHorizontalRow item',
  );

  @override
  void initState() {
    super.initState();
    widget.row._items[widget.index] = this;
  }

  @override
  void didUpdateWidget(_RowItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      if (identical(oldWidget.row._items[oldWidget.index], this)) {
        oldWidget.row._items.remove(oldWidget.index);
      }
      widget.row._items[widget.index] = this;
    }
  }

  @override
  void dispose() {
    if (identical(widget.row._items[widget.index], this)) {
      widget.row._items.remove(widget.index);
    }
    _node.dispose();
    super.dispose();
  }

  /// Focuses the first focusable descendant; false when there is none.
  bool requestFocus() {
    final targets = _node.traversalDescendants;
    if (targets.isEmpty) return false;
    targets.first.requestFocus();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _node,
      onFocusChange: (has) => widget.row._onItemFocusChanged(widget.index, has),
      child: widget.child,
    );
  }
}

class _EdgeArrow extends StatelessWidget {
  const _EdgeArrow({
    required this.left,
    required this.visible,
    required this.tooltip,
    required this.inset,
    required this.onTap,
  });

  final bool left;
  final bool visible;
  final String tooltip;
  final double inset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final button = KInteractive(
      onTap: onTap,
      focusable: false,
      semanticLabel: tooltip,
      builder: (context, state, _) => AnimatedContainer(
        duration: KMotion.of(context, KDurations.hover),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: state.highlighted
              ? const Color(0xF2262626)
              : const Color(0xD9141414),
          border: Border.all(color: const Color(0x33FFFFFF)),
          boxShadow: KShadows.floating,
        ),
        child: Icon(
          left ? PhosphorIconsBold.caretLeft : PhosphorIconsBold.caretRight,
          size: 20,
          color: Colors.white,
        ),
      ),
    );
    return Positioned(
      left: left ? inset.clamp(4, double.infinity) : null,
      right: left ? null : inset.clamp(4, double.infinity),
      top: 0,
      bottom: 0,
      child: Center(
        child: IgnorePointer(
          ignoring: !visible,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: KMotion.of(context, const Duration(milliseconds: 180)),
            child: button,
          ),
        ),
      ),
    );
  }
}

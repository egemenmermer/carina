import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../widgets/channel_cards.dart';

/// Space above the first card (room for the floating category pill).
const double kLiveListTopPadding = 32;

/// Space below the last card.
const double kLiveListBottomPadding = 24;

/// Height of one list row (card + gap).
const double kLiveListItemExtent = kLiveListCardHeight + kLiveListGap;

/// Horizontal padding inside the list (room for the focus scale).
const double kLiveListSidePadding = 6;

/// Horizontal layout: a channel list
/// column (~28 %) with the floating category pill, and on the right the
/// preview over the NOW ON AIR and UPCOMING panels.
class LiveHorizontalLayout extends StatelessWidget {
  const LiveHorizontalLayout({
    super.key,
    required this.list,
    required this.pill,
    required this.preview,
    required this.nowOnAir,
    required this.upcoming,
  });

  final Widget list;
  final Widget pill;
  final Widget preview;
  final Widget nowOnAir;
  final Widget upcoming;

  /// Width of the channel column for a content [width].
  static double listWidth(double width) =>
      (width * 0.28).clamp(340.0, 540.0).toDouble();

  /// Logo tile size of the list cards for a list of [listWidth].
  static double logoSize(double listWidth) =>
      ((listWidth - 12) * 0.21).clamp(64.0, 88.0).roundToDouble();

  /// Height of the NOW ON AIR / UPCOMING row in a right column of
  /// [height]: 44 % as in the reference (the preview gets the rest), never
  /// less than the panels need.
  static double panelsHeight(double height) =>
      math.max(290, (height - 12) * 0.44).toDouble();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = listWidth(constraints.maxWidth);
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 24, 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: width,
                child: Stack(
                  children: [
                    Positioned.fill(child: list),
                    Positioned(
                      top: 6,
                      left: 0,
                      right: 0,
                      child: Center(child: pill),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: kLiveListTopPadding),
                  child: LayoutBuilder(
                    builder: (context, right) {
                      final panels = panelsHeight(right.maxHeight);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: preview),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: panels,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(child: nowOnAir),
                                const SizedBox(width: 12),
                                Expanded(child: upcoming),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Geometry of the vertical grid for a content width: 3–4 columns.
@immutable
class LiveGridMetrics {
  const LiveGridMetrics({
    required this.columns,
    required this.cardWidth,
    required this.cardHeight,
  });

  factory LiveGridMetrics.of(double width) {
    final inner = width - sidePadding * 2;
    final columns = ((inner + gap) / (minCardWidth + gap)).floor().clamp(3, 4);
    final cardWidth = (inner - gap * (columns - 1)) / columns;
    final cardHeight = (cardWidth * 0.53).clamp(168.0, 200.0).toDouble();
    return LiveGridMetrics(
      columns: columns,
      cardWidth: cardWidth,
      cardHeight: cardHeight,
    );
  }

  static const double sidePadding = 24;
  static const double topPadding = 34;
  static const double bottomPadding = 28;
  static const double gap = 18;
  static const double minCardWidth = 300;

  final int columns;
  final double cardWidth;
  final double cardHeight;

  double get rowExtent => cardHeight + gap;

  /// The live preview tile that replaces the previewed card: 16:9, a bit larger
  /// than the card.
  Size get tileSize {
    final w = cardWidth * 1.14;
    return Size(w, w * 9 / 16);
  }
}

/// Vertical layout: the channel grid, the floating category pill at the
/// top-center, and the preview tile that follows the previewed card.
class LiveVerticalLayout extends StatelessWidget {
  const LiveVerticalLayout({
    super.key,
    required this.grid,
    required this.pill,
    this.tile,
  });

  final Widget grid;
  final Widget pill;

  /// A positioned follower (see `CompositedTransformFollower`), or null.
  final Widget? tile;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: grid),
        ?tile,
        Positioned(top: 6, left: 0, right: 0, child: Center(child: pill)),
      ],
    );
  }
}

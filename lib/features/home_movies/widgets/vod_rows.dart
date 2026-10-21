import 'package:flutter/material.dart';

import '../../../core/core.dart';

/// A home row: 22/700 section title with a red See All, then a horizontal
/// row of equally sized cards (mouse wheel scrolls it sideways, arrows
/// appear at the edges on hover, Left / Right move focus).
class VodRowSection extends StatelessWidget {
  const VodRowSection({
    super.key,
    required this.title,
    required this.itemCount,
    required this.itemBuilder,
    required this.itemWidth,
    required this.itemHeight,
    this.onSeeAll,
    this.spacing = KSpacing.rowGap,
    this.bottomGap = 18,
  });

  final String title;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double itemWidth;
  final double itemHeight;
  final VoidCallback? onSeeAll;
  final double spacing;
  final double bottomGap;

  @override
  Widget build(BuildContext context) {
    // No FocusTraversalGroup per row: every group keeps its own Up/Down
    // history, so an Up right after a Down in the same row would return to
    // the card it is already on (the D-pad stalls on every second press).
    return Padding(
      padding: EdgeInsets.only(bottom: bottomGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          KSectionHeader(title: title, onSeeAll: onSeeAll),
          KHorizontalRow(
            itemCount: itemCount,
            itemWidth: itemWidth,
            itemHeight: itemHeight,
            spacing: spacing,
            focusPadding: 12,
            itemBuilder: itemBuilder,
          ),
        ],
      ),
    );
  }
}

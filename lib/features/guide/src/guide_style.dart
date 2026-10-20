library;

import 'package:flutter/widgets.dart';

import '../../../core/core.dart';

/// Geometry of the guide grid.
@immutable
class GuideMetrics {
  const GuideMetrics({
    this.channelColumnWidth = 260,
    this.headerHeight = 34,
    this.rowHeight = 68,
    this.rowGap = 2,
    this.cellGap = 2,
    this.cellRadius = 4,
    this.cellPadding = 12,
    this.logoSize = 50,
    this.bottomPadding = 24,
  });

  /// The full guide (TV Guide tab, Full TV Guide overlay).
  static const regular = GuideMetrics();

  /// Left channel column with logo and name.
  final double channelColumnWidth;

  /// Time header row.
  final double headerHeight;

  /// Height of a programme cell.
  final double rowHeight;

  /// Vertical gap between rows.
  final double rowGap;

  /// Horizontal gap after each programme cell.
  final double cellGap;
  final double cellRadius;

  /// Text inset inside a cell.
  final double cellPadding;
  final double logoSize;

  /// Space after the last row.
  final double bottomPadding;

  /// Distance from one row to the next.
  double get rowPitch => rowHeight + rowGap;
}

/// Type styles of the guide (Inter, derived from [KText]).
abstract final class GuideText {
  /// Time headers ("3:15 PM") and the "Today" corner: 18/400 white.
  static const header = TextStyle(
    fontFamily: KText.family,
    fontSize: 18,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.26,
    color: KColors.textPrimary,
    fontFeatures: KText.tabular,
  );

  /// Programme titles in cells: 18/400 (color per state).
  static const cell = TextStyle(
    fontFamily: KText.family,
    fontSize: 18,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.26,
    color: KColors.textSecondary,
  );

  /// Channel names in the left column: 20/400, two lines.
  static const channel = TextStyle(
    fontFamily: KText.family,
    fontSize: 20,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.3,
    height: 1.12,
    color: KColors.textPrimary,
  );

  /// Long channel names shrink to this before they are truncated.
  static const channelSmall = TextStyle(
    fontFamily: KText.family,
    fontSize: 17,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.22,
    height: 1.12,
    color: KColors.textPrimary,
  );

  /// Focused programme title above the grid: 24/500.
  static const title = TextStyle(
    fontFamily: KText.family,
    fontSize: 24,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.47,
    height: 1.2,
    color: KColors.textPrimary,
  );

  /// "2:50 PM – 3:45 PM  (55 min)": 18/400 tabular.
  static const time = TextStyle(
    fontFamily: KText.family,
    fontSize: 18,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.26,
    color: KColors.textPrimary,
    fontFeatures: KText.tabular,
  );

  /// Programme description above the grid: 17/400 white.
  static const description = TextStyle(
    fontFamily: KText.family,
    fontSize: 17,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.22,
    height: 1.3,
    leadingDistribution: TextLeadingDistribution.even,
    color: KColors.textPrimary,
  );

  /// "1920x1080" / "25 fps" chips: 16/500 tabular.
  static const chip = TextStyle(
    fontFamily: KText.family,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.18,
    color: KColors.textPrimary,
    fontFeatures: KText.tabular,
  );
}

/// Fill colors of guide cells.
abstract final class GuideColors {
  /// Time header cells.
  static const header = KColors.segmentTrack;

  /// Upcoming programmes and "No EPG data" blocks.
  static const future = KColors.surface3;

  /// Programmes that ended and cannot be replayed.
  static const past = KColors.surface2;

  /// Blocks whose guide is still loading.
  static const loading = KColors.surface1;

  /// On air (dark maroon) and focused (crimson).
  static const onAir = KColors.epgNow;
  static const focused = KColors.accentCrimson;

  /// Hover lightens a fill by this much white.
  static const double hoverLighten = 0.08;

  /// Press darkens a fill by this much black.
  static const double pressDarken = 0.16;

  static Color hovered(Color c) =>
      Color.lerp(c, KColors.textPrimary, hoverLighten)!;

  static Color pressed(Color c) => Color.lerp(c, KColors.bg, pressDarken)!;
}

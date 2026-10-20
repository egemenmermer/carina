/// Carina design tokens: colors, radii, durations, spacing, type and motion.
///
/// Feature code must use these instead of raw hex colors or ad-hoc text
/// styles (see docs/ARCHITECTURE.md §5). All colors are sRGB.
library;

import 'package:flutter/widgets.dart';

/// Color palette (dark only).
abstract final class KColors {
  // ---------------------------------------------------------------- surfaces

  /// App background, pure black.
  static const bg = Color(0xFF000000);

  /// Channel cards and panels.
  static const surface1 = Color(0xFF0D0D0D);

  /// Raised panels, sidebar and banner backgrounds.
  static const surface2 = Color(0xFF1C1C1E);

  /// Future EPG cells, input fields, chips.
  static const surface3 = Color(0xFF262626);

  /// Tiles inside panels (info tiles, upcoming rows).
  static const tile = Color(0xFF131313);

  /// Base of the frosted menu material, painted at [materialOpacity] over a 30
  /// px backdrop blur.
  static const material = Color(0xFF282828);

  /// Opacity of [material] in context menus and popovers.
  static const double materialOpacity = 0.85;

  /// 1 px rim of frosted menus.
  static const materialStroke = Color(0x1FFFFFFF);

  /// 1 px card and panel borders.
  static const stroke = Color(0xFF232323);

  /// Thin row separators inside menus and grouped lists.
  static const separator = Color(0x29FFFFFF);

  /// Stronger outline (pill borders, empty PIN dots).
  static const strokeStrong = Color(0xFF3A3A3C);

  // -------------------------------------------------------------------- text

  /// Primary text and icons.
  static const textPrimary = Color(0xFFFFFFFF);

  /// Metadata, times, badge outlines.
  static const textSecondary = Color(0xFFA9A9A9);

  /// Disabled items, hints, inactive status icons.
  static const textTertiary = Color(0xFF6D6D6D);

  /// Inactive iPad/Mac nav tab.
  static const navInactive = Color(0xFF858585);

  /// Date/time next to the logo.
  static const navDate = Color(0xFF808080);

  /// Hero metadata line.
  static const heroMeta = Color(0xFFBFBFBF);

  // ------------------------------------------------------------------ accent

  /// Accent red: active tab underline, See All, NEW badges, LIVE pill, progress
  /// bars, FAB.
  static const accent = Color(0xFFFF2500);

  /// Accent under the pointer.
  static const accentHover = Color(0xFFFF4524);

  /// Accent while pressed.
  static const accentPressed = Color(0xFFD81F00);

  /// Focused EPG cell and the guide "Today" header.
  static const accentCrimson = Color(0xFFB32642);

  /// Currently airing EPG cells (dark maroon).
  static const epgNow = Color(0xFF4D101C);

  /// Brand red of the Carina mark and app icon (ARCHITECTURE.md §5).
  static const brand = Color(0xFFFF5E57);

  // ------------------------------------------------------------------ status

  /// Success: green checks, active parental icon.
  static const success = Color(0xFF1FA344);

  /// Rating star.
  static const star = Color(0xFFFFD60A);

  /// Keyboard/hover focus border (tvOS style).
  static const focusRing = Color(0xFFF5F5F5);

  /// Dimmed backdrop behind sheets and dialogs (55% black).
  static const scrim = Color(0x8C000000);

  /// Track behind red progress bars.
  static const progressTrack = Color(0xFF2A2E33);

  /// Dark chip on black ("1920x1080", "25 fps").
  static const chip = Color(0xFF363636);

  /// Chips and buttons drawn over video or artwork (60% black).
  static const overlay = Color(0x99000000);

  /// Translucent fill of secondary buttons and round icon buttons.
  static const glass = Color(0x29FFFFFF);

  /// Translucent fill under the pointer.
  static const glassHover = Color(0x40FFFFFF);

  /// Subtle hover fill for rows (settings rows, menu rows).
  static const rowHover = Color(0x14FFFFFF);

  /// Toast gradient top.
  static const toastTop = Color(0xFF0F670F);

  /// Toast gradient bottom.
  static const toastBottom = Color(0xFF187518);

  /// Toast rim.
  static const toastStroke = Color(0xFF3A853A);

  /// Toast check-circle.
  static const toastIcon = Color(0xFF2EE53F);

  /// Track of the Apple TV style segmented control.
  static const segmentTrack = Color(0xFF191919);

  /// Selected segment of the segmented control.
  static const segmentActive = Color(0xFF303030);

  /// Neutral light background behind channel logos.
  static const logoBackground = Color(0xFFECECEE);

  /// Windows caption close button under the pointer (Windows 11 red).
  static const windowsCloseHover = Color(0xFFC42B1C);
}

/// Corner radii.
abstract final class KRadii {
  /// Cards (channel cards, continue-watching cards).
  static const double card = 10;

  /// Posters.
  static const double poster = 8;

  /// Panels (NOW ON AIR, UPCOMING, settings groups).
  static const double panel = 14;

  /// Popover menus (player menus, choosers).
  static const double popover = 14;

  /// Context menus.
  static const double contextMenu = 18;

  /// Modal sheets.
  static const double sheet = 20;

  /// Fully rounded pills.
  static const double pill = 999;

  /// Outlined quality badges.
  static const double badge = 4;

  /// Dark chips.
  static const double chip = 5;

  /// Buttons.
  static const double button = 8;

  /// Text fields.
  static const double field = 8;

  /// Info tiles and upcoming rows.
  static const double tile = 8;

  /// Channel logo tiles.
  static const double logo = 8;

  /// Live preview video.
  static const double video = 12;

  static const BorderRadius cardBorder = BorderRadius.all(
    Radius.circular(card),
  );
  static const BorderRadius posterBorder = BorderRadius.all(
    Radius.circular(poster),
  );
  static const BorderRadius panelBorder = BorderRadius.all(
    Radius.circular(panel),
  );
  static const BorderRadius pillBorder = BorderRadius.all(
    Radius.circular(pill),
  );
}

/// Durations.
abstract final class KDurations {
  /// Hover/focus scale and border.
  static const hover = Duration(milliseconds: 120);

  /// Context menu / popover open (scale 0.96 → 1 + fade).
  static const menu = Duration(milliseconds: 140);

  /// Context menu / popover close.
  static const menuExit = Duration(milliseconds: 100);

  /// Toast auto-hide delay.
  static const toast = Duration(milliseconds: 2500);

  /// Toast slide/fade animation.
  static const toastAnimation = Duration(milliseconds: 260);

  /// Hero backdrop crossfade.
  static const heroCrossfade = Duration(milliseconds: 400);

  /// Network image fade-in.
  static const imageFade = Duration(milliseconds: 200);

  /// Modal sheet open.
  static const sheet = Duration(milliseconds: 220);

  /// Programmatic scrolling (row arrows, keep-focused-visible).
  static const scroll = Duration(milliseconds: 280);

  /// Wrong-PIN shake.
  static const shake = Duration(milliseconds: 420);
}

/// Spacing scale (4 pt grid) and a few layout constants.
abstract final class KSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Horizontal page gutter on desktop (rows, hero text, section headers).
  static const double gutter = 48;

  /// Gap between cards in a row.
  static const double rowGap = 16;

  /// Height of the top navigation bar.
  static const double navHeight = 72;
}

/// Shadows.
abstract final class KShadows {
  /// Soft shadow under a hovered/focused card.
  static const focus = <BoxShadow>[
    BoxShadow(color: Color(0x99000000), blurRadius: 24, offset: Offset(0, 10)),
  ];

  /// Shadow of frosted menus and popovers.
  static const menu = <BoxShadow>[
    BoxShadow(color: Color(0x80000000), blurRadius: 40, offset: Offset(0, 16)),
  ];

  /// Shadow of floating controls (FAB, toasts).
  static const floating = <BoxShadow>[
    BoxShadow(color: Color(0x73000000), blurRadius: 18, offset: Offset(0, 6)),
  ];
}

/// Motion helpers. Everything animated in core respects the OS "reduce
/// animations" setting through these.
abstract final class KMotion {
  /// Whether the user asked the OS to reduce or disable animations
  /// (`MediaQuery.disableAnimations`).
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// [duration], or zero when animations are reduced.
  static Duration of(BuildContext context, Duration duration) =>
      reduced(context) ? Duration.zero : duration;

  /// Curve of hover/focus transitions ("120 ms ease-out").
  static const Curve hover = Curves.easeOut;

  /// Curve of entrances (menus, toasts, sheets).
  static const Curve enter = Curves.easeOutCubic;

  /// Curve of exits.
  static const Curve exit = Curves.easeInCubic;
}

/// Text styles.
///
/// Letter spacing follows Inter's dynamic-metrics formula
/// (tracking = −0.0223 + 0.185·e^(−0.1745·size) em), which approximates the
/// optical tracking of SF Pro. Times use tabular figures.
/// Colors are defaults; override with `copyWith(color: …)`.
abstract final class KText {
  /// Bundled font family (pubspec `fonts:`).
  static const String family = 'Inter';

  /// Font features for times and counters.
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  /// Emoji fallbacks for flag prefixes and avatar glyphs (macOS, Windows,
  /// Linux system emoji fonts).
  static const List<String> emojiFallback = [
    'Apple Color Emoji',
    'Segoe UI Emoji',
    'Noto Color Emoji',
  ];

  static const _even = TextLeadingDistribution.even;

  /// Nav item: 17/500, inactive grey (active white set by the nav).
  static const nav = TextStyle(
    fontFamily: family,
    fontSize: 17,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.22,
    color: KColors.navInactive,
  );

  /// Date/time next to the logo: 15/500 grey, tabular.
  static const navDate = TextStyle(
    fontFamily: family,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.13,
    color: KColors.navDate,
    fontFeatures: tabular,
  );

  /// Hero title when there is no logo art: 56/800, tight tracking.
  static const heroTitle = TextStyle(
    fontFamily: family,
    fontSize: 56,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.4,
    height: 1.05,
    leadingDistribution: _even,
    color: KColors.textPrimary,
  );

  /// Hero metadata line: 17/500 (genres are uppercased by the caller).
  static const heroMeta = TextStyle(
    fontFamily: family,
    fontSize: 17,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    color: KColors.heroMeta,
  );

  /// Section title ("Continue watching"): 22/700.
  static const sectionTitle = TextStyle(
    fontFamily: family,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.40,
    color: KColors.textPrimary,
  );

  /// "See All": 15/600 accent.
  static const seeAll = TextStyle(
    fontFamily: family,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.13,
    color: KColors.accent,
  );

  /// Card title: 15/600.
  static const cardTitle = TextStyle(
    fontFamily: family,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.13,
    color: KColors.textPrimary,
  );

  /// Card subtitle ("S1 E2 · Episode 2"): 13/500 secondary.
  static const cardSubtitle = TextStyle(
    fontFamily: family,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.04,
    color: KColors.textSecondary,
  );

  /// Channel name: 17/600.
  static const channelName = TextStyle(
    fontFamily: family,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.22,
    color: KColors.textPrimary,
  );

  /// Programme title on a channel card: 14/400.
  static const programme = TextStyle(
    fontFamily: family,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.09,
    color: Color(0xFFD9D9D9),
  );

  /// Time range ("3:15 PM – 4:15 PM"): 13/500 secondary, tabular.
  static const time = TextStyle(
    fontFamily: family,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.04,
    color: KColors.textSecondary,
    fontFeatures: tabular,
  );

  /// Large time (UPCOMING rows, "4:15 PM"): 22/600 tabular.
  static const timeLarge = TextStyle(
    fontFamily: family,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.40,
    color: KColors.textPrimary,
    fontFeatures: tabular,
  );

  /// Quality badges (SD / HD / FHD / 4K / H265): 11/600.
  static const badge = TextStyle(
    fontFamily: family,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
    height: 1.25,
    leadingDistribution: _even,
    color: KColors.textSecondary,
  );

  /// Panel header ("NOW ON AIR"): 15/700, uppercased by [PanelHeader].
  static const panelHeader = TextStyle(
    fontFamily: family,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.4,
    color: KColors.textPrimary,
  );

  /// Sheet and dialog titles: 20/700.
  static const title = TextStyle(
    fontFamily: family,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.33,
    color: KColors.textPrimary,
  );

  /// Large title (NOW ON AIR programme): 28/700.
  static const largeTitle = TextStyle(
    fontFamily: family,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.58,
    height: 1.15,
    leadingDistribution: _even,
    color: KColors.textPrimary,
  );

  /// Body text: 15/400.
  static const body = TextStyle(
    fontFamily: family,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.13,
    height: 1.35,
    leadingDistribution: _even,
    color: KColors.textPrimary,
  );

  /// Secondary body text: 15/400 secondary.
  static const bodySecondary = TextStyle(
    fontFamily: family,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.13,
    height: 1.35,
    leadingDistribution: _even,
    color: KColors.textSecondary,
  );

  /// Captions and hints: 13/400 secondary.
  static const caption = TextStyle(
    fontFamily: family,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.04,
    height: 1.3,
    leadingDistribution: _even,
    color: KColors.textSecondary,
  );

  /// Field labels and small strong labels: 13/600 secondary.
  static const label = TextStyle(
    fontFamily: family,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.04,
    color: KColors.textSecondary,
  );

  /// Button label (medium): 15/600.
  static const button = TextStyle(
    fontFamily: family,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.13,
    color: KColors.textPrimary,
  );

  /// Button label (large, e.g. hero "Play"): 17/600.
  static const buttonLarge = TextStyle(
    fontFamily: family,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.22,
    color: KColors.textPrimary,
  );

  /// Button label (small): 13/600.
  static const buttonSmall = TextStyle(
    fontFamily: family,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.04,
    color: KColors.textPrimary,
  );

  /// Context menu / popover row: 16/400 (iPad menus use 17 pt regular).
  static const menu = TextStyle(
    fontFamily: family,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.17,
    color: KColors.textPrimary,
  );

  /// Uppercase menu section header ("AUDIO", "SWITCH PLAYER"): 12/700.
  static const menuHeader = TextStyle(
    fontFamily: family,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.7,
    color: KColors.textSecondary,
  );

  /// Toast message: 17/600 white.
  static const toast = TextStyle(
    fontFamily: family,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.22,
    color: KColors.textPrimary,
  );

  /// Dark chips ("1920x1080", "25 fps"): 13/600 tabular.
  static const chip = TextStyle(
    fontFamily: family,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.04,
    color: KColors.textPrimary,
    fontFeatures: tabular,
  );

  /// Settings row title: 16/500.
  static const settingsTitle = TextStyle(
    fontFamily: family,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.17,
    color: KColors.textPrimary,
  );

  /// Settings row value: 15/400 secondary.
  static const settingsValue = TextStyle(
    fontFamily: family,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.13,
    color: KColors.textSecondary,
  );

  /// Settings section header: 13/600 uppercase tertiary.
  static const sectionLabel = TextStyle(
    fontFamily: family,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    color: KColors.textTertiary,
  );

  /// Text field input: 16/400.
  static const input = TextStyle(
    fontFamily: family,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.17,
    color: KColors.textPrimary,
  );
}

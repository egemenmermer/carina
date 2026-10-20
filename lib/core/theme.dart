import 'package:flutter/material.dart';

import 'package:carina/core/tokens.dart';

/// Builds the Carina [ThemeData]: dark only, pure black scaffold, Inter,
/// accent red, subtle hover/focus fills and no Material ink ripples.
///
/// Core widgets draw their own states and do not depend on most of these
/// values; the theme exists so that any stock Material widget a feature uses
/// (TextButton, Switch, Slider, TabBar, Tooltip, Scrollbar, TextField…) still
/// looks like the rest of the app.
ThemeData buildCarinaTheme() {
  const scheme = ColorScheme.dark(
    primary: KColors.accent,
    onPrimary: KColors.textPrimary,
    primaryContainer: KColors.epgNow,
    onPrimaryContainer: KColors.textPrimary,
    secondary: KColors.accent,
    onSecondary: KColors.textPrimary,
    secondaryContainer: KColors.surface3,
    onSecondaryContainer: KColors.textPrimary,
    tertiary: KColors.success,
    onTertiary: KColors.textPrimary,
    error: KColors.accent,
    onError: KColors.textPrimary,
    surface: KColors.bg,
    onSurface: KColors.textPrimary,
    onSurfaceVariant: KColors.textSecondary,
    surfaceDim: KColors.bg,
    surfaceBright: KColors.surface3,
    surfaceContainerLowest: KColors.bg,
    surfaceContainerLow: KColors.surface1,
    surfaceContainer: KColors.surface2,
    surfaceContainerHigh: KColors.surface3,
    surfaceContainerHighest: KColors.chip,
    outline: KColors.strokeStrong,
    outlineVariant: KColors.stroke,
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: KColors.textPrimary,
    onInverseSurface: KColors.bg,
    inversePrimary: KColors.accentPressed,
    surfaceTint: Colors.transparent,
  );

  const textTheme = TextTheme(
    displayLarge: KText.heroTitle,
    displayMedium: TextStyle(
      fontFamily: KText.family,
      fontSize: 44,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.98,
      color: KColors.textPrimary,
    ),
    displaySmall: TextStyle(
      fontFamily: KText.family,
      fontSize: 36,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.78,
      color: KColors.textPrimary,
    ),
    headlineLarge: TextStyle(
      fontFamily: KText.family,
      fontSize: 32,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.69,
      color: KColors.textPrimary,
    ),
    headlineMedium: KText.largeTitle,
    headlineSmall: TextStyle(
      fontFamily: KText.family,
      fontSize: 24,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.47,
      color: KColors.textPrimary,
    ),
    titleLarge: KText.sectionTitle,
    titleMedium: KText.channelName,
    titleSmall: KText.cardTitle,
    bodyLarge: TextStyle(
      fontFamily: KText.family,
      fontSize: 17,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.22,
      height: 1.35,
      color: KColors.textPrimary,
    ),
    bodyMedium: KText.body,
    bodySmall: KText.caption,
    labelLarge: KText.button,
    labelMedium: KText.cardSubtitle,
    labelSmall: KText.badge,
  );

  const subtleHover = Color(0x0FFFFFFF);
  const subtleFocus = Color(0x1AFFFFFF);
  const subtleHighlight = Color(0x0AFFFFFF);
  const fieldRadius = BorderRadius.all(Radius.circular(KRadii.field));
  const buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(KRadii.button)),
  );

  WidgetStateProperty<Color?> overlay(Color base) =>
      WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return base.withValues(alpha: 0.10);
        }
        if (states.contains(WidgetState.focused)) {
          return base.withValues(alpha: 0.12);
        }
        if (states.contains(WidgetState.hovered)) {
          return base.withValues(alpha: 0.08);
        }
        return null;
      });

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    fontFamily: KText.family,
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    scaffoldBackgroundColor: KColors.bg,
    canvasColor: KColors.bg,
    cardColor: KColors.surface1,
    dividerColor: KColors.stroke,
    disabledColor: KColors.textTertiary,
    hintColor: KColors.textTertiary,
    shadowColor: Colors.black,
    // Apple-like interaction feedback: no ink splash, faint fills only.
    splashFactory: NoSplash.splashFactory,
    splashColor: Colors.transparent,
    highlightColor: subtleHighlight,
    hoverColor: subtleHover,
    focusColor: subtleFocus,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    iconTheme: const IconThemeData(color: KColors.textPrimary, size: 22),
    primaryIconTheme: const IconThemeData(color: KColors.textPrimary, size: 22),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: KFadePageTransitionsBuilder(),
        TargetPlatform.fuchsia: KFadePageTransitionsBuilder(),
        TargetPlatform.iOS: KFadePageTransitionsBuilder(),
        TargetPlatform.linux: KFadePageTransitionsBuilder(),
        TargetPlatform.macOS: KFadePageTransitionsBuilder(),
        TargetPlatform.windows: KFadePageTransitionsBuilder(),
      },
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.dragged)) {
          return const Color(0x8CFFFFFF);
        }
        if (states.contains(WidgetState.hovered)) {
          return const Color(0x66FFFFFF);
        }
        return const Color(0x38FFFFFF);
      }),
      trackColor: const WidgetStatePropertyAll(Colors.transparent),
      trackBorderColor: const WidgetStatePropertyAll(Colors.transparent),
      thickness: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.hovered) ? 8 : 6,
      ),
      radius: const Radius.circular(4),
      crossAxisMargin: 3,
      mainAxisMargin: 4,
      minThumbLength: 40,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: KColors.accent,
      selectionColor: KColors.accent.withValues(alpha: 0.40),
      selectionHandleColor: KColors.accent,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: const Color(0xF22C2C2E),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: KColors.materialStroke),
        boxShadow: KShadows.floating,
      ),
      textStyle: KText.caption.copyWith(color: KColors.textPrimary),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      waitDuration: const Duration(milliseconds: 500),
      verticalOffset: 20,
    ),
    dividerTheme: const DividerThemeData(
      color: KColors.stroke,
      thickness: 1,
      space: 1,
    ),
    appBarTheme: const AppBarThemeData(
      backgroundColor: KColors.bg,
      foregroundColor: KColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: KText.title,
    ),
    cardTheme: const CardThemeData(
      color: KColors.surface1,
      elevation: 0,
      margin: EdgeInsets.zero,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: KRadii.cardBorder,
        side: BorderSide(color: KColors.stroke),
      ),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: KColors.surface2,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      barrierColor: KColors.scrim,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(KRadii.sheet)),
      ),
      titleTextStyle: KText.title,
      contentTextStyle: KText.bodySecondary,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: KColors.surface2,
      surfaceTintColor: Colors.transparent,
      modalBarrierColor: KColors.scrim,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(KRadii.sheet)),
      ),
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: KColors.surface1,
      surfaceTintColor: Colors.transparent,
      scrimColor: KColors.scrim,
      elevation: 0,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: KColors.material,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      textStyle: KText.menu,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KRadii.popover),
        side: const BorderSide(color: KColors.materialStroke),
      ),
    ),
    menuTheme: const MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(KColors.material),
        surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
        elevation: WidgetStatePropertyAll(0),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(KRadii.popover)),
            side: BorderSide(color: KColors.materialStroke),
          ),
        ),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: KColors.surface2,
      contentTextStyle: KText.body,
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: KColors.accent,
      linearTrackColor: KColors.progressTrack,
      circularTrackColor: KColors.glass,
      linearMinHeight: 4,
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: KColors.textPrimary,
      textColor: KColors.textPrimary,
      selectedColor: KColors.textPrimary,
      selectedTileColor: KColors.rowHover,
      tileColor: Colors.transparent,
      titleTextStyle: KText.settingsTitle,
      subtitleTextStyle: KText.caption,
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      indicator: const UnderlineTabIndicator(
        borderSide: BorderSide(color: KColors.accent, width: 3),
        borderRadius: BorderRadius.all(Radius.circular(1.5)),
      ),
      indicatorSize: TabBarIndicatorSize.label,
      labelColor: KColors.textPrimary,
      unselectedLabelColor: KColors.navInactive,
      labelStyle: KText.button,
      unselectedLabelStyle: KText.button,
      dividerColor: Colors.transparent,
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      splashFactory: NoSplash.splashFactory,
      tabAlignment: TabAlignment.start,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(KColors.textPrimary),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? KColors.accent
            : KColors.surface3,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      splashRadius: 0,
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? KColors.accent
            : Colors.transparent,
      ),
      checkColor: const WidgetStatePropertyAll(KColors.textPrimary),
      side: const BorderSide(color: KColors.textTertiary, width: 1.5),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      splashRadius: 0,
    ),
    radioTheme: const RadioThemeData(
      fillColor: WidgetStatePropertyAll(KColors.accent),
      overlayColor: WidgetStatePropertyAll(Colors.transparent),
      splashRadius: 0,
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: KColors.accent,
      inactiveTrackColor: KColors.progressTrack,
      thumbColor: KColors.textPrimary,
      overlayColor: Colors.transparent,
      trackHeight: 4,
    ),
    inputDecorationTheme: const InputDecorationThemeData(
      filled: true,
      fillColor: KColors.surface3,
      isDense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      hintStyle: TextStyle(
        fontFamily: KText.family,
        fontSize: 16,
        color: KColors.textTertiary,
      ),
      labelStyle: KText.label,
      floatingLabelBehavior: FloatingLabelBehavior.never,
      border: OutlineInputBorder(
        borderRadius: fieldRadius,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: fieldRadius,
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: fieldRadius,
        borderSide: BorderSide(color: KColors.accent, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: fieldRadius,
        borderSide: BorderSide(color: KColors.accent, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: fieldRadius,
        borderSide: BorderSide(color: KColors.accent, width: 2),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        foregroundColor: const WidgetStatePropertyAll(KColors.textPrimary),
        overlayColor: overlay(Colors.white),
        textStyle: const WidgetStatePropertyAll(KText.button),
        shape: const WidgetStatePropertyAll(buttonShape),
        splashFactory: NoSplash.splashFactory,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return KColors.surface3;
          if (states.contains(WidgetState.pressed)) {
            return KColors.accentPressed;
          }
          if (states.contains(WidgetState.hovered)) return KColors.accentHover;
          return KColors.accent;
        }),
        foregroundColor: const WidgetStatePropertyAll(KColors.textPrimary),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        textStyle: const WidgetStatePropertyAll(KText.button),
        shape: const WidgetStatePropertyAll(buttonShape),
        splashFactory: NoSplash.splashFactory,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: const WidgetStatePropertyAll(KColors.glass),
        foregroundColor: const WidgetStatePropertyAll(KColors.textPrimary),
        overlayColor: overlay(Colors.white),
        elevation: const WidgetStatePropertyAll(0),
        textStyle: const WidgetStatePropertyAll(KText.button),
        shape: const WidgetStatePropertyAll(buttonShape),
        splashFactory: NoSplash.splashFactory,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        foregroundColor: const WidgetStatePropertyAll(KColors.textPrimary),
        overlayColor: overlay(Colors.white),
        side: const WidgetStatePropertyAll(
          BorderSide(color: KColors.strokeStrong),
        ),
        textStyle: const WidgetStatePropertyAll(KText.button),
        shape: const WidgetStatePropertyAll(buttonShape),
        splashFactory: NoSplash.splashFactory,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        foregroundColor: const WidgetStatePropertyAll(KColors.textPrimary),
        overlayColor: overlay(Colors.white),
        splashFactory: NoSplash.splashFactory,
      ),
    ),
  );
}

/// Page transition used by every platform: a short fade (Apple TV style),
/// instant when the OS asks to reduce animations.
class KFadePageTransitionsBuilder extends PageTransitionsBuilder {
  const KFadePageTransitionsBuilder();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 220);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (KMotion.reduced(context)) return child;
    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: child,
    );
  }
}

import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'package:carina/core/tokens.dart';

/// Frosted dark material of menus and popovers: 30 px backdrop blur,
/// [KColors.material] at 85%, 1 px light rim and a soft shadow.
class KFrostedPanel extends StatelessWidget {
  const KFrostedPanel({
    super.key,
    required this.child,
    this.borderRadius = KRadii.contextMenu,
    this.width,
    this.color = KColors.material,
    this.opacity = KColors.materialOpacity,
    this.blur = 30,
    this.shadow = true,
  });

  final Widget child;
  final double borderRadius;
  final double? width;
  final Color color;
  final double opacity;

  /// Backdrop blur sigma.
  final double blur;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: shadow ? KShadows.menu : null,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color.withValues(alpha: opacity),
              borderRadius: radius,
              border: Border.all(color: KColors.materialStroke),
            ),
            child: SizedBox(width: width, child: child),
          ),
        ),
      ),
    );
  }
}

/// Where [showKPopup] places its content.
enum KPopupPlacement {
  /// Top-left corner at the point, flipped left/up to stay in the window
  /// (context menus).
  atPoint,

  /// Centered horizontally above the anchor rectangle (player popovers).
  above,

  /// Centered horizontally below the anchor rectangle.
  below,

  /// Right edge aligned with the anchor, below it (avatar menu).
  belowEnd,

  /// Centered in the window (choosers).
  center,
}

/// Shows [builder]'s widget in a transparent popup route on the root
/// navigator: fades in and scales 0.96 → 1 over 140 ms around the anchor,
/// stays inside the window, closes on an outside click or Esc.
///
/// Most code should use [showKContextMenu], [showKPopoverMenu] or
/// [showChooser], which are built on this.
Future<T?> showKPopup<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  Offset? position,
  Rect? anchorRect,
  KPopupPlacement placement = KPopupPlacement.atPoint,
  Color barrierColor = Colors.transparent,
  bool barrierDismissible = true,
  String? barrierLabel,
  double margin = 8,
  double gap = 8,
}) {
  final navigator = Navigator.of(context, rootNavigator: true);
  final overlayBox =
      navigator.overlay?.context.findRenderObject() as RenderBox?;
  Offset toLocal(Offset global) =>
      overlayBox == null ? global : overlayBox.globalToLocal(global);
  Rect? localRect;
  if (anchorRect != null) {
    localRect = Rect.fromPoints(
      toLocal(anchorRect.topLeft),
      toLocal(anchorRect.bottomRight),
    );
  }
  final localPoint = position != null
      ? toLocal(position)
      : localRect?.center ?? Offset.zero;
  return navigator.push<T>(
    KPopupRoute<T>(
      builder: builder,
      point: localPoint,
      anchorRect: localRect,
      placement: placement,
      barrierColorValue: barrierColor,
      dismissible: barrierDismissible,
      barrierLabel:
          barrierLabel ??
          MaterialLocalizations.of(context).modalBarrierDismissLabel,
      margin: margin,
      gap: gap,
      reduceMotion: MediaQuery.maybeDisableAnimationsOf(context) ?? false,
    ),
  );
}

/// Route behind [showKPopup]. Public so features can push it with their
/// own navigator when needed.
class KPopupRoute<T> extends PopupRoute<T> {
  KPopupRoute({
    required this.builder,
    required this.point,
    required this.placement,
    this.anchorRect,
    this.barrierColorValue = Colors.transparent,
    this.dismissible = true,
    this.barrierLabel,
    this.margin = 8,
    this.gap = 8,
    this.reduceMotion = false,
  });

  final WidgetBuilder builder;
  final Offset point;
  final Rect? anchorRect;
  final KPopupPlacement placement;
  final Color barrierColorValue;
  final bool dismissible;
  final double margin;
  final double gap;
  final bool reduceMotion;

  @override
  final String? barrierLabel;

  @override
  Color? get barrierColor => barrierColorValue;

  @override
  bool get barrierDismissible => dismissible;

  @override
  Duration get transitionDuration =>
      reduceMotion ? Duration.zero : KDurations.menu;

  @override
  Duration get reverseTransitionDuration =>
      reduceMotion ? Duration.zero : KDurations.menuExit;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final content = Builder(builder: builder);
    if (placement == KPopupPlacement.center) {
      return SafeArea(
        child: Center(
          child: Padding(padding: EdgeInsets.all(margin), child: content),
        ),
      );
    }
    return CustomSingleChildLayout(
      delegate: _KPopupLayout(
        point: point,
        anchorRect: anchorRect,
        placement: placement,
        margin: margin,
        gap: gap,
      ),
      child: content,
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (reduceMotion) return child;
    final size = MediaQuery.sizeOf(context);
    final origin = switch (placement) {
      KPopupPlacement.center => size.center(Offset.zero),
      KPopupPlacement.above => anchorRect?.topCenter ?? point,
      KPopupPlacement.below => anchorRect?.bottomCenter ?? point,
      KPopupPlacement.belowEnd => anchorRect?.bottomRight ?? point,
      KPopupPlacement.atPoint => point,
    };
    final alignment = size.isEmpty
        ? Alignment.center
        : Alignment(
            (origin.dx / size.width) * 2 - 1,
            (origin.dy / size.height) * 2 - 1,
          );
    final curved = CurvedAnimation(
      parent: animation,
      curve: KMotion.enter,
      reverseCurve: Curves.easeIn,
    );
    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
        alignment: alignment,
        child: child,
      ),
    );
  }
}

class _KPopupLayout extends SingleChildLayoutDelegate {
  _KPopupLayout({
    required this.point,
    required this.anchorRect,
    required this.placement,
    required this.margin,
    required this.gap,
  });

  final Offset point;
  final Rect? anchorRect;
  final KPopupPlacement placement;
  final double margin;
  final double gap;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints.loose(
      Size(
        math.max(0, constraints.maxWidth - margin * 2),
        math.max(0, constraints.maxHeight - margin * 2),
      ),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size child) {
    final anchor =
        anchorRect ?? Rect.fromCenter(center: point, width: 0, height: 0);
    double x;
    double y;
    switch (placement) {
      case KPopupPlacement.atPoint:
        // Open right/down from the pointer; flip left/up when there is no
        // room, and slide just enough to fit when neither side has room.
        x = point.dx;
        y = point.dy;
        if (x + child.width > size.width - margin) {
          final flipped = point.dx - child.width;
          x = flipped >= margin ? flipped : size.width - margin - child.width;
        }
        if (y + child.height > size.height - margin) {
          final flipped = point.dy - child.height;
          y = flipped >= margin ? flipped : size.height - margin - child.height;
        }
      case KPopupPlacement.above:
        x = anchor.center.dx - child.width / 2;
        y = anchor.top - gap - child.height;
        if (y < margin) y = anchor.bottom + gap;
      case KPopupPlacement.below:
        x = anchor.center.dx - child.width / 2;
        y = anchor.bottom + gap;
        if (y + child.height > size.height - margin) {
          y = anchor.top - gap - child.height;
        }
      case KPopupPlacement.belowEnd:
        x = anchor.right - child.width;
        y = anchor.bottom + gap;
        if (y + child.height > size.height - margin) {
          y = anchor.top - gap - child.height;
        }
      case KPopupPlacement.center:
        x = (size.width - child.width) / 2;
        y = (size.height - child.height) / 2;
    }
    x = x.clamp(margin, math.max(margin, size.width - margin - child.width));
    y = y.clamp(margin, math.max(margin, size.height - margin - child.height));
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_KPopupLayout oldDelegate) =>
      oldDelegate.point != point ||
      oldDelegate.anchorRect != anchorRect ||
      oldDelegate.placement != placement ||
      oldDelegate.margin != margin ||
      oldDelegate.gap != gap;
}

/// Global rectangle of the widget owning [context] (for anchoring popups).
Rect kGlobalRectOf(BuildContext context) {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize) return Rect.zero;
  return box.localToGlobal(Offset.zero) & box.size;
}

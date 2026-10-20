import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:carina/core/icons/phosphor_icons.dart';

import 'package:carina/core/strings.dart';
import 'package:carina/core/tokens.dart';
import 'package:carina/core/widgets/k_buttons.dart';

/// Opens a centered modal sheet (series/movie details, TV Archive, tag
/// picker): [width] wide (clamped to the window), radius 20, over a dimmed
/// and blurred backdrop, with a round × close button at the top-right.
/// Esc, the × and a click on the backdrop close it.
///
/// [child] is placed in a vertical scroll view unless [scrollable] is false
/// (pass false when the child scrolls itself, e.g. a ListView with
/// [expand] true).
///
/// ```dart
/// await showKSheet<void>(context, child: SeriesDetail(series));
/// ```
Future<T?> showKSheet<T>(
  BuildContext context, {
  required Widget child,
  double width = 880,
  double? maxHeight,
  bool scrollable = true,
  bool expand = false,
  bool showClose = true,
  bool barrierDismissible = true,
  Color background = KColors.bg,
  EdgeInsetsGeometry padding = EdgeInsets.zero,
}) {
  return Navigator.of(context, rootNavigator: true).push<T>(
    _KSheetRoute<T>(
      child: child,
      width: width,
      maxHeight: maxHeight,
      scrollable: scrollable,
      expand: expand,
      showClose: showClose,
      dismissible: barrierDismissible,
      background: background,
      padding: padding,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      reduceMotion: MediaQuery.maybeDisableAnimationsOf(context) ?? false,
    ),
  );
}

class _KSheetRoute<T> extends PopupRoute<T> {
  _KSheetRoute({
    required this.child,
    required this.width,
    required this.maxHeight,
    required this.scrollable,
    required this.expand,
    required this.showClose,
    required this.dismissible,
    required this.background,
    required this.padding,
    required this.barrierLabel,
    required this.reduceMotion,
  });

  final Widget child;
  final double width;
  final double? maxHeight;
  final bool scrollable;
  final bool expand;
  final bool showClose;
  final bool dismissible;
  final Color background;
  final EdgeInsetsGeometry padding;
  final bool reduceMotion;

  @override
  final String? barrierLabel;

  // The page paints its own dim + blur so the blur can fade with the route.
  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => dismissible;

  @override
  Duration get transitionDuration =>
      reduceMotion ? Duration.zero : KDurations.sheet;

  @override
  Duration get reverseTransitionDuration =>
      reduceMotion ? Duration.zero : const Duration(milliseconds: 160);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: KMotion.enter,
      reverseCurve: Curves.easeIn,
    );
    final size = MediaQuery.sizeOf(context);
    final sheetWidth = math.min(width, size.width - 48);
    final sheetMaxHeight = math.min(
      maxHeight ?? double.infinity,
      size.height - 56,
    );
    Widget content = child;
    if (scrollable) {
      content = SingleChildScrollView(padding: padding, child: content);
    } else {
      content = Padding(padding: padding, child: content);
    }
    Widget sheet = Container(
      width: sheetWidth,
      height: expand ? sheetMaxHeight : null,
      // Room for the × button even when the content is short.
      constraints: BoxConstraints(
        minHeight: showClose ? 68 : 0,
        maxHeight: sheetMaxHeight,
      ),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(KRadii.sheet),
        border: Border.all(color: KColors.stroke),
        boxShadow: const [
          BoxShadow(
            color: Color(0xB3000000),
            blurRadius: 60,
            offset: Offset(0, 24),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            content,
            if (showClose)
              const Positioned(top: 16, right: 16, child: KSheetCloseButton()),
          ],
        ),
      ),
    );
    sheet = FadeTransition(
      opacity: curved,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.97, end: 1).animate(curved),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.02),
            end: Offset.zero,
          ).animate(curved),
          child: sheet,
        ),
      ),
    );
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: dismissible ? () => Navigator.of(context).maybePop() : null,
            child: AnimatedBuilder(
              animation: curved,
              builder: (context, _) {
                final t = curved.value;
                return BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14 * t, sigmaY: 14 * t),
                  child: ColoredBox(
                    color: KColors.scrim.withValues(alpha: KColors.scrim.a * t),
                  ),
                );
              },
            ),
          ),
        ),
        Center(child: sheet),
      ],
    );
  }
}

/// Round dark × button used at the top-right of sheets (36 px, translucent
/// black over artwork). Pops the current route by default.
class KSheetCloseButton extends StatelessWidget {
  const KSheetCloseButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return KIconButton(
      icon: PhosphorIconsRegular.x,
      size: 36,
      iconSize: 18,
      background: const Color(0x99000000),
      tooltip: KStrings.of(context).close,
      onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
    );
  }
}

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'package:carina/core/core.dart';

/// Space the macOS traffic lights need at the top-left of the frameless
/// window (the routes outside the playlist shell have no top bar).
double macTitleBarInset() => !kIsWeb && Platform.isMacOS && !_isTest ? 34 : 0;

bool get _isTest => !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

/// Window chrome of the full-screen Playlists routes (Manager, wizard,
/// import, avatar picker): black background, a draggable strip along the
/// top (double-click maximizes) and, on Windows/Linux, the dark caption
/// buttons in the top-right corner. Content stays clickable: the strip only
/// receives the pointer where the content has nothing.
class PlaylistsWindowFrame extends StatelessWidget {
  const PlaylistsWindowFrame({
    super.key,
    required this.child,
    this.dragHeight = 44,
  });

  final Widget child;
  final double dragHeight;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: ColoredBox(color: KColors.bg)),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: dragHeight,
          child: const KNavDragArea(child: SizedBox.expand()),
        ),
        // The routes have no Material above them; without one, Text would
        // inherit MaterialApp's red "missing Material" fallback style.
        Positioned.fill(
          child: Material(type: MaterialType.transparency, child: child),
        ),
        if (KCaptionButtons.platformUsesCaptionButtons)
          const Positioned(top: 0, right: 0, child: KCaptionButtons()),
      ],
    );
  }
}

/// The wizard footer: a thin rule whose red part shows [progress]
/// above the small red CARINA wordmark at the
/// bottom-left.
class CarinaWordmarkFooter extends StatelessWidget {
  const CarinaWordmarkFooter({super.key, this.progress = 1});

  /// Red share of the rule, 0…1.
  final double progress;

  @override
  Widget build(BuildContext context) {
    final duration = KMotion.of(context, const Duration(milliseconds: 360));
    return ExcludeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 2,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final red = (width * progress.clamp(0.0, 1.0))
                    .clamp(56.0, width)
                    .toDouble();
                return Stack(
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0.5,
                      height: 1,
                      child: const ColoredBox(color: KColors.stroke),
                    ),
                    AnimatedPositioned(
                      duration: duration,
                      curve: KMotion.enter,
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: red,
                      child: const ColoredBox(color: KColors.accent),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          const Text('CARINA', style: carinaWordmarkStyle),
        ],
      ),
    );
  }
}

/// Style of the red CARINA wordmark.
const TextStyle carinaWordmarkStyle = TextStyle(
  fontFamily: KText.family,
  fontSize: 19,
  fontWeight: FontWeight.w800,
  letterSpacing: 1.6,
  height: 1,
  color: KColors.accent,
);

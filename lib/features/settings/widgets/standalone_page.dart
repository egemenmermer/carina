import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/clock.dart';
import '../../../app/time_format.dart';
import '../../../core/core.dart';
import '../../../data/settings/settings_store.dart';

/// Chrome of the pages that live outside a playlist (app-level Settings,
/// Downloads): the Carina top bar with the page name as the active tab, the
/// date/time when enabled, window dragging and caption buttons. Esc and
/// the logo call [onBack] (back to the Playlist Manager).
class LibraryStandalonePage extends ConsumerWidget {
  const LibraryStandalonePage({
    super.key,
    required this.title,
    required this.onBack,
    required this.child,
  });

  final String title;
  final VoidCallback onBack;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showClock = ref.watchSetting(AppSettings.showClock);
    final now =
        ref.watch(minuteClockProvider).value ?? ref.read(clockSourceProvider)();
    final fmt = ref.watch(timeFormatProvider);
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): onBack},
      child: FocusScope(
        autofocus: true,
        child: ColoredBox(
          color: KColors.bg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              KTopNav(
                leadingInset: _macTitleInset,
                tabs: [KNavTab(id: 'page', label: title)],
                activeTabId: 'page',
                onTabSelected: (_) {},
                dateTimeText: showClock ? fmt.navDateTime(now) : null,
                onLogoTap: onBack,
              ),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

/// Room for the macOS traffic lights (hidden title bar), as in the shell.
double get _macTitleInset {
  try {
    return Platform.isMacOS ? 72 : 0;
  } on Object {
    return 0;
  }
}

/// Small "‹ Label" back button used at the top-left of standalone pages.
class LibraryBackButton extends StatelessWidget {
  const LibraryBackButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return KInteractive(
      onTap: onPressed,
      semanticLabel: label,
      builder: (context, state, _) {
        final color = state.highlighted
            ? KColors.textPrimary
            : KColors.textSecondary;
        return KFocusRing(
          visible: state.focused,
          borderRadius: 18,
          gap: 1,
          child: AnimatedContainer(
            duration: KMotion.of(context, KDurations.hover),
            height: 36,
            padding: const EdgeInsets.fromLTRB(8, 0, 14, 0),
            decoration: BoxDecoration(
              color: state.highlighted ? KColors.rowHover : null,
              borderRadius: KRadii.pillBorder,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(PhosphorIconsBold.caretLeft, size: 16, color: color),
                const SizedBox(width: 6),
                Text(label, style: KText.button.copyWith(color: color)),
              ],
            ),
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/core.dart';
import '../features/reminders/reminders_api.dart';
import '../l10n/gen/app_localizations.dart';
import 'capture/capture_runner.dart';
import 'platform/form_factor.dart';
import 'router.dart';
import 'time_format.dart';
import 'window_setup.dart';

/// Root widget: theme, localization, router, toast host and app-wide
/// shortcuts (F11 fullscreen; on TV, Back that no screen handled).
class CarinaApp extends ConsumerWidget {
  const CarinaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final code = ref.watch(appLocaleCodeProvider);
    return MaterialApp.router(
      title: 'Carina',
      debugShowCheckedModeBanner: false,
      theme: buildCarinaTheme(),
      darkTheme: buildCarinaTheme(),
      themeMode: ThemeMode.dark,
      locale: Locale(code),
      supportedLocales: L10n.supportedLocales,
      localizationsDelegates: L10n.localizationsDelegates,
      routerConfig: router,
      builder: (context, child) => RepaintBoundary(
        key: captureBoundaryKey,
        child: _AppShortcuts(
          child: KToastHost(
            // Material gives every screen a DefaultTextStyle (no yellow
            // debug underlines) and ink for hover/press effects.
            child: Material(
              color: KColors.bg,
              child: ReminderListener(child: child ?? const SizedBox.shrink()),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppShortcuts extends ConsumerWidget {
  const _AppShortcuts({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tv = ref.watch(formFactorProvider).isTv;
    if (tv) {
      // Android starts in the "touch" highlight mode, which hides focus
      // rings until the first key press. A remote always needs them.
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
    }
    return KTvMode(enabled: tv, child: _bindings(ref, tv));
  }

  Widget _bindings(WidgetRef ref, bool tv) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.f11): () {
          WindowControls.toggleFullscreen();
        },
        // The remote's Back arrives as Escape (MainActivity.kt). Screens and
        // overlays handle it first, the playlist shell walks up to its home
        // tab; here it reaches only when none did, so it pops a route or
        // goes up (appBackLocation), and leaves the app from the Manager.
        // Not on key repeat: a held Back would climb to the exit.
        if (tv)
          const SingleActivator(
            LogicalKeyboardKey.escape,
            includeRepeats: false,
          ): () {
            // Overlays (sheets, menus, dialogs) close as Escape closes them
            // on desktop: only when they are dismissible.
            final focused = FocusManager.instance.primaryFocus?.context;
            final route = focused == null ? null : ModalRoute.of(focused);
            if (route != null && route is! PageRoute) {
              if (route.barrierDismissible) Navigator.of(focused!).maybePop();
              return;
            }
            final router = ref.read(routerProvider);
            if (router.canPop()) {
              router.pop();
              return;
            }
            final path = router.routerDelegate.currentConfiguration.uri.path;
            final target = appBackLocation(path);
            if (target == null) {
              SystemNavigator.pop();
            } else {
              router.go(target);
            }
          },
      },
      child: child,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/core.dart';
import '../features/reminders/reminders_api.dart';
import '../l10n/gen/app_localizations.dart';
import 'capture/capture_runner.dart';
import 'router.dart';
import 'time_format.dart';
import 'window_setup.dart';

/// Root widget: theme, localization, router, toast host and app-wide
/// shortcuts (F11 fullscreen).
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

class _AppShortcuts extends StatelessWidget {
  const _AppShortcuts({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.f11): () {
          WindowControls.toggleFullscreen();
        },
      },
      child: child,
    );
  }
}

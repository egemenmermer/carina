/// Shared test wrapper: the Kanal theme, localizations, a [ProviderScope]
/// and the [KToastHost] — the same shell the app uses.
///
/// ```dart
/// await tester.pumpWidget(carinaTestApp(const MyScreen()));
/// ```
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:carina/core/theme.dart';
import 'package:carina/core/tokens.dart';
import 'package:carina/core/widgets/k_toast.dart';
import 'package:carina/l10n/gen/app_localizations.dart';

/// Wraps [home] in ProviderScope → MaterialApp (Kanal theme, en/tr
/// localizations, [KToastHost]) → black [Material].
///
/// Set [wrapInMaterial] to false when [home] is already a full page
/// (Scaffold). [navigatorKey] gives tests access to the root navigator.
Widget carinaTestApp(
  Widget home, {
  List<Override> overrides = const [],
  Locale locale = const Locale('en'),
  bool wrapInMaterial = true,
  GlobalKey<NavigatorState>? navigatorKey,
  bool disableAnimations = false,
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: buildCarinaTheme(),
      locale: locale,
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      builder: (context, child) {
        Widget result = KToastHost(child: child!);
        if (disableAnimations) {
          result = MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: result,
          );
        }
        return result;
      },
      home: wrapInMaterial ? Material(color: KColors.bg, child: home) : home,
    ),
  );
}

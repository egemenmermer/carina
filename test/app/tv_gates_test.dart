import 'package:carina/app/platform/form_factor.dart';
import 'package:carina/app/router.dart';
import 'package:carina/data/app_paths.dart';
import 'package:carina/data/db/database.dart';
import 'package:carina/data/secrets/secret_store.dart';
import 'package:carina/data/settings/settings_store.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/playlists/support/playlists_harness.dart' show tempAppPaths;
import '../support/drift_widgets.dart';
import '../support/screenshot.dart';

/// The real router at [location] on an empty library.
Future<ProviderContainer> _pumpApp(
  WidgetTester tester, {
  required FormFactor formFactor,
  required String location,
}) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  final settings = SettingsStore(db);
  late AppPaths paths;
  await tester.runAsync(() async {
    await settings.load();
    paths = await tempAppPaths();
  });
  addTearDown(() => tester.runAsync(db.close));
  late ProviderContainer container;
  await pumpScreen(
    tester,
    Consumer(
      builder: (context, ref, _) {
        container = ProviderScope.containerOf(context);
        return Router.withConfig(config: ref.watch(routerProvider));
      },
    ),
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      appPathsProvider.overrideWithValue(paths),
      settingsStoreProvider.overrideWithValue(settings),
      secretStoreProvider.overrideWithValue(MemorySecretStore()),
      formFactorProvider.overrideWithValue(formFactor),
      initialLocationProvider.overrideWithValue(location),
    ],
  );
  await settleDrift(tester);
  return container;
}

String _location(ProviderContainer c) =>
    c.read(routerProvider).routeInformationProvider.value.uri.toString();

void main() {
  setUpAll(loadAppFonts);

  testWidgets('desktop: /downloads opens the Downloads page', (tester) async {
    final c = await _pumpApp(
      tester,
      formFactor: FormFactor.desktop,
      location: Routes.downloads,
    );
    expect(_location(c), Routes.downloads);
    expect(find.byKey(const ValueKey('downloads-empty')), findsOneWidget);
    await unmountAndFlush(tester);
  });

  testWidgets('desktop: the manager rail offers Downloads', (tester) async {
    await _pumpApp(
      tester,
      formFactor: FormFactor.desktop,
      location: Routes.manager,
    );
    expect(find.byKey(const ValueKey('rail-downloads')), findsOneWidget);
    await unmountAndFlush(tester);
  });

  testWidgets('tv: no Downloads in the rail, /downloads goes home', (
    tester,
  ) async {
    final c = await _pumpApp(
      tester,
      formFactor: FormFactor.tv,
      location: Routes.downloads,
    );
    expect(_location(c), Routes.manager);
    expect(find.byKey(const ValueKey('downloads-empty')), findsNothing);
    expect(find.byKey(const ValueKey('rail-settings')), findsOneWidget);
    expect(find.byKey(const ValueKey('rail-downloads')), findsNothing);
    await unmountAndFlush(tester);
  });
}

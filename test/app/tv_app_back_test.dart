import 'package:carina/app/app.dart';
import 'package:carina/app/platform/form_factor.dart';
import 'package:carina/app/router.dart';
import 'package:carina/core/core.dart';
import 'package:carina/data/app_paths.dart';
import 'package:carina/data/db/database.dart';
import 'package:carina/data/secrets/secret_store.dart';
import 'package:carina/data/settings/settings_store.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/playlists/support/playlists_harness.dart' show tempAppPaths;
import '../support/drift_widgets.dart';
import '../support/screenshot.dart';

/// The whole app (its Back fallback included) on an empty library, on TV.
Future<void> _pumpApp(WidgetTester tester, List<MethodCall> platform) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  final settings = SettingsStore(db);
  late AppPaths paths;
  await tester.runAsync(() async {
    await settings.load();
    paths = await tempAppPaths();
  });
  addTearDown(() => tester.runAsync(db.close));
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      platform.add(call);
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  await tester.runAsync(loadAppFonts);
  tester.view.physicalSize = const Size(960, 540);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  addTearDown(
    () => FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.automatic,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        appPathsProvider.overrideWithValue(paths),
        settingsStoreProvider.overrideWithValue(settings),
        secretStoreProvider.overrideWithValue(MemorySecretStore()),
        formFactorProvider.overrideWithValue(FormFactor.tv),
        initialLocationProvider.overrideWithValue(Routes.manager),
      ],
      child: const CarinaApp(),
    ),
  );
  await settleDrift(tester);
  await settle(tester);
}

bool _exited(List<MethodCall> calls) =>
    calls.any((c) => c.method == 'SystemNavigator.pop');

void main() {
  testWidgets('TV: the Manager starts focused with rings on; Back leaves', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    await _pumpApp(tester, calls);
    expect(
      FocusManager.instance.highlightStrategy,
      FocusHighlightStrategy.alwaysTraditional,
    );
    final add = find.byKey(const ValueKey('manager-add-playlist'));
    expect(add, findsOneWidget);
    final focused = FocusManager.instance.primaryFocus!;
    expect(tester.getRect(add).contains(focused.rect.center), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(_exited(calls), isTrue);
    await unmountAndFlush(tester);
  });

  testWidgets('TV: Back closes a dismissible overlay, not a blocking one', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    await _pumpApp(tester, calls);
    final context = tester.element(find.byType(KButton).first);

    showKPopup<void>(
      context,
      position: Offset.zero,
      barrierDismissible: false,
      builder: (_) => KButton.secondary(
        label: 'Blocking',
        onPressed: () {},
        autofocus: true,
      ),
    );
    await settle(tester);
    expect(find.text('Blocking'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(find.text('Blocking'), findsOneWidget);
    expect(_exited(calls), isFalse);

    Navigator.of(context).pop();
    showKPopup<void>(
      context,
      position: Offset.zero,
      builder: (_) => KButton.secondary(
        label: 'Dismissible',
        onPressed: () {},
        autofocus: true,
      ),
    );
    await settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(find.text('Dismissible'), findsNothing);
    expect(_exited(calls), isFalse);
    await unmountAndFlush(tester);
  });
}

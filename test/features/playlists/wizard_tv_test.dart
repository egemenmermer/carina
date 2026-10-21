import 'package:carina/app/platform/form_factor.dart';
import 'package:carina/data/app_paths.dart';
import 'package:carina/data/db/database.dart';
import 'package:carina/data/secrets/secret_store.dart';
import 'package:carina/data/settings/settings_store.dart';
import 'package:carina/features/playlists/playlist_wizard_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/drift_widgets.dart';
import '../../support/screenshot.dart';
import 'support/playlists_harness.dart' show tempAppPaths;

void main() {
  setUpAll(loadAppFonts);

  testWidgets('TV wizard: ↓/↑ walk every row without raising the keyboard', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final settings = SettingsStore(db);
    late AppPaths paths;
    await tester.runAsync(() async {
      await settings.load();
      paths = await tempAppPaths();
    });
    addTearDown(() => tester.runAsync(db.close));
    await pumpScreen(
      tester,
      const PlaylistWizardScreen(initialType: PlaylistType.m3u),
      size: const Size(960, 540),
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        appPathsProvider.overrideWithValue(paths),
        settingsStoreProvider.overrideWithValue(settings),
        secretStoreProvider.overrideWithValue(MemorySecretStore()),
        formFactorProvider.overrideWithValue(FormFactor.tv),
      ],
    );
    final first = FocusManager.instance.primaryFocus;
    expect(first?.debugLabel, 'wizard-name');
    expect(tester.testTextInput.isVisible, isFalse);

    final visited = <FocusNode>[first!];
    for (var i = 0; i < 12; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await settle(tester);
      final node = FocusManager.instance.primaryFocus!;
      if (node == visited.last) break;
      visited.add(node);
      expect(tester.testTextInput.isVisible, isFalse, reason: '$node');
    }
    expect(visited.last.debugLabel, 'wizard-save', reason: '$visited');
    expect(visited.length, greaterThan(4));

    for (var i = 0; i < visited.length - 1; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await settle(tester);
    }
    expect(FocusManager.instance.primaryFocus, first);

    // OK on a field starts typing.
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await settle(tester);
    expect(tester.testTextInput.isVisible, isTrue);
    await unmountAndFlush(tester);
  });
}

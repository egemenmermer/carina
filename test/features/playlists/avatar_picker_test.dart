import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:carina/core/core.dart';
import 'package:carina/data/app_paths.dart';
import 'package:carina/data/db/database.dart';
import 'package:carina/data/repositories/playlist_repository.dart';
import 'package:carina/data/secrets/secret_store.dart';
import 'package:carina/data/settings/settings_store.dart';

import '../../support/drift_widgets.dart';
import '../../support/screenshot.dart';
import 'support/playlists_harness.dart';

void main() {
  setUpAll(loadAppFonts);

  Future<(AppDatabase, List<Override>, int)> setUp(WidgetTester tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final settings = SettingsStore(db);
    late AppPaths paths;
    late int pid;
    await tester.runAsync(() async {
      await settings.load();
      paths = await tempAppPaths();
      pid = await db
          .into(db.playlists)
          .insert(
            PlaylistsCompanion.insert(
              name: 'Kanal Demo',
              type: PlaylistType.m3u,
              m3uUrl: const Value('http://iptv.example.com/list.m3u'),
              avatarId: const Value('animal-fox'),
              createdAt: DateTime(2026, 10, 17),
            ),
          );
    });
    return (
      db,
      <Override>[
        appDatabaseProvider.overrideWithValue(db),
        appPathsProvider.overrideWithValue(paths),
        settingsStoreProvider.overrideWithValue(settings),
        secretStoreProvider.overrideWithValue(MemorySecretStore()),
      ],
      pid,
    );
  }

  testWidgets('Choose Avatar: categories, current avatar, choose', (
    tester,
  ) async {
    final (db, overrides, pid) = await setUp(tester);
    final router = playlistsTestRouter(
      initialLocation: '/playlists/$pid/avatar',
    );
    await pumpScreen(tester, routerHost(router), overrides: overrides);
    await settleDrift(tester);
    expect(find.text('Choose Avatar'), findsOneWidget);
    for (final category in AvatarCategory.values) {
      expect(
        find.byKey(ValueKey('avatar-category-${category.name}')),
        findsOneWidget,
      );
    }
    // The current avatar's category is open and the avatar has the focus.
    expect(find.byKey(const ValueKey('avatar-animal-fox')), findsOneWidget);
    expect(find.byKey(const ValueKey('avatar-animal-panda')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('avatar-animal-fox')),
        matching: find.byIcon(PhosphorIconsBold.check),
      ),
      findsOneWidget,
      reason: 'the current avatar carries a check',
    );
    await saveScreen(tester, 'playlists_avatar_picker');

    // Another category, then an avatar from it.
    await tester.tap(find.byKey(const ValueKey('avatar-category-cars')));
    await settle(tester);
    expect(find.byKey(const ValueKey('avatar-car-race')), findsOneWidget);
    expect(find.byKey(const ValueKey('avatar-animal-fox')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('avatar-car-race')));
    await settleDrift(tester);
    expect(find.text('Avatar updated'), findsOneWidget);
    expect(router.state.uri.toString(), '/');
    final repository = PlaylistRepository(
      db,
      MemorySecretStore(),
      SettingsStore(db),
    );
    final row = await tester.runAsync(() => repository.get(pid));
    expect(row?.avatarId, 'car-race');
    await unmountAndFlush(tester);
  });

  testWidgets('Choose Avatar: keyboard and Esc', (tester) async {
    final (_, overrides, pid) = await setUp(tester);
    final router = playlistsTestRouter(
      initialLocation: '/playlists/$pid/avatar',
    );
    await pumpScreen(tester, routerHost(router), overrides: overrides);
    await settleDrift(tester);
    // Right moves to the next avatar; Enter would choose it.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await settle(tester);
    final panda = find.byKey(const ValueKey('avatar-animal-panda'));
    expect(
      Focus.of(
        tester.element(
          find.descendant(of: panda, matching: find.byType(KAvatar)),
        ),
      ).hasFocus,
      isTrue,
    );
    // Focusing a category shows it (tvOS behavior).
    final initials = find.byKey(const ValueKey('avatar-category-initials'));
    Focus.of(
      tester.element(
        find.descendant(of: initials, matching: find.byType(Text)).first,
      ),
    ).requestFocus();
    await settle(tester);
    expect(find.byKey(const ValueKey('avatar-init-ruby')), findsOneWidget);
    expect(find.text('KD'), findsWidgets, reason: 'initials of Kanal Demo');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settleDrift(tester);
    expect(router.state.uri.toString(), '/');
    await unmountAndFlush(tester);
  });
}

import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carina/data/app_paths.dart';
import 'package:carina/data/db/database.dart';
import 'package:carina/data/import/import.dart';
import 'package:carina/data/repositories/playlist_repository.dart';
import 'package:carina/data/secrets/secret_store.dart';
import 'package:carina/data/settings/settings_store.dart';

import '../../support/drift_widgets.dart';
import '../../support/mock_import.dart';
import '../../support/screenshot.dart';
import 'support/playlists_harness.dart';

/// Adds playlists next to the imported "Kanal Demo" so the Manager looks
/// like a real one. None of them reloads on open (frequency "Never").
Future<Map<String, int>> _seedPlaylists(MockImportFixture fx) async {
  final repo = PlaylistRepository(fx.db, fx.secrets, fx.settings);
  await repo.setAvatar(fx.playlistId, 'animal-fox');
  final base = fx.server.baseUrl;
  Future<int> add(String name, String? avatar, {bool m3u = false}) =>
      repo.create(
        PlaylistDraft(
          name: name,
          type: m3u ? PlaylistType.m3u : PlaylistType.xtream,
          server: m3u ? null : base,
          username: m3u ? null : MockFixtures.username,
          password: m3u ? null : MockFixtures.password,
          m3uUrl: m3u ? '$base/playlist.m3u' : null,
          reloadFrequencyHours: 0,
          avatarId: avatar,
        ),
      );
  final ids = {
    'demo': fx.playlistId,
    'sport': await add('Spor Paketi', 'obj-football'),
    'kids': await add('Çocuk Dünyası', 'char-robot', m3u: true),
    'family': await add('Ev TV', null, m3u: true),
    'cinema': await add('Sinema Kulübü', 'obj-popcorn'),
  };
  await repo.setAccessPin(ids['kids']!, '1234');
  return ids;
}

Finder _tile(int id) => find.byKey(ValueKey('playlist-$id'));

Future<void> _rightClick(WidgetTester tester, Finder finder) async {
  await tester.tap(finder, buttons: kSecondaryButton);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('Manager: avatars, menu, details, PIN gate, open', (
    tester,
  ) async {
    final fx = (await tester.runAsync(() => importMockPlaylist()))!;
    final ids = (await tester.runAsync(() => _seedPlaylists(fx)))!;
    final router = playlistsTestRouter();
    await pumpScreen(
      tester,
      routerHost(router),
      overrides: fx.providerOverrides,
    );
    await settleDrift(tester);
    for (final name in [
      'Kanal Demo',
      'Spor Paketi',
      'Çocuk Dünyası',
      'Ev TV',
      'Sinema Kulübü',
    ]) {
      expect(find.text(name), findsOneWidget, reason: name);
    }
    // The first playlist has the keyboard focus (ring + ••• button).
    expect(find.byTooltip('More actions'), findsWidgets);
    expect(find.byTooltip('Protected with a PIN'), findsOneWidget);
    await saveScreen(tester, 'playlists_manager');

    // Arrow keys move between avatars.
    final first = Focus.of(tester.element(find.text('Kanal Demo'))).hasFocus;
    expect(first, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(Focus.of(tester.element(find.text('Spor Paketi'))).hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(Focus.of(tester.element(find.text('Kanal Demo'))).hasFocus, isTrue);

    // The Menu key opens the menu titled with the playlist name beside the
    // focused avatar.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
    await settle(tester);
    expect(find.text('Choose Avatar'), findsOneWidget);
    expect(find.text('Spor Paketi'), findsNWidgets(2), reason: 'menu title');
    for (final label in [
      'Playlist details',
      'Force reload',
      'Set Playlist Access PIN',
      'Force reload EPG',
      'Edit',
      "Open playlist's settings",
      'Remove',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await settle(tester);
    await saveScreen(tester, 'playlists_manager_menu');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(find.text('Choose Avatar'), findsNothing);

    // Right-click opens the same menu; the protected playlist offers
    // "Remove PIN".
    await _rightClick(tester, _tile(ids['kids']!));
    expect(find.text('Remove PIN'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);

    // Playlist details of the imported playlist.
    await _rightClick(tester, _tile(ids['demo']!));
    await tester.tap(find.text('Playlist details'));
    await settleDrift(tester);
    expect(find.text('PLAYLIST DETAILS'), findsOneWidget);
    expect(find.text('Xtream (Recommended)'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('1 March 2027'), findsOneWidget);
    expect(find.text('300'), findsOneWidget, reason: 'live channels');
    // Credentials stay masked.
    expect(find.text('carina'), findsNothing);
    expect(find.text('ca•••••'), findsOneWidget);
    expect(find.textContaining(MockFixtures.password), findsNothing);
    await saveScreen(tester, 'playlists_details');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);

    // A protected playlist asks for its access PIN first.
    await tester.tap(_tile(ids['kids']!));
    await settleDrift(tester);
    expect(find.text('Enter PIN'), findsOneWidget);
    expect(find.text('Çocuk Dünyası is protected'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await settle(tester);
    await saveScreen(tester, 'playlists_pin_pad');
    await tester.sendKeyEvent(LogicalKeyboardKey.digit9);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit9);
    await settleDrift(tester);
    expect(find.text('Wrong PIN. Try again.'), findsOneWidget);
    for (final key in [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
    ]) {
      await tester.sendKeyEvent(key);
    }
    await pumpUntil(
      tester,
      () => find
          .text(routeStubText('/p/${ids['kids']}/live'))
          .evaluate()
          .isNotEmpty,
    );
    expect(fx.settings.get(AppSettings.lastPlaylistId), ids['kids']);
    await unmountAndFlush(tester);
    await tester.runAsync(fx.dispose);
  });

  testWidgets('Manager: set and remove the access PIN, remove a playlist', (
    tester,
  ) async {
    final fx = (await tester.runAsync(() => importMockPlaylist()))!;
    final ids = (await tester.runAsync(() => _seedPlaylists(fx)))!;
    final repo = PlaylistRepository(fx.db, fx.secrets, fx.settings);
    await pumpScreen(
      tester,
      routerHost(playlistsTestRouter()),
      overrides: fx.providerOverrides,
    );
    await settleDrift(tester);

    Future<void> typePin(String pin) async {
      for (final c in pin.split('')) {
        await tester.sendKeyEvent(
          LogicalKeyboardKey(LogicalKeyboardKey.digit0.keyId + int.parse(c)),
        );
      }
      await settleDrift(tester);
    }

    // Hovering an avatar shows its ••• button, which opens the menu.
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(_tile(ids['sport']!)));
    addTearDown(mouse.removePointer);
    await settle(tester);
    await tester.tap(
      find.descendant(
        of: _tile(ids['sport']!),
        matching: find.byTooltip('More actions'),
      ),
    );
    await settle(tester);
    expect(find.text('Set Playlist Access PIN'), findsOneWidget);

    // Set Playlist Access PIN: twice the same 4 digits.
    await tester.tap(find.text('Set Playlist Access PIN'));
    await settle(tester);
    expect(find.text('Set an access PIN'), findsOneWidget);
    await typePin('2468');
    expect(find.text('Enter the PIN again'), findsOneWidget);
    await typePin('2468');
    expect(find.text('Access PIN set'), findsOneWidget);
    final sport = await tester.runAsync(() => repo.get(ids['sport']!));
    expect(sport?.hasAccessPin, isTrue);
    expect(
      await tester.runAsync(() => repo.verifyAccessPin(ids['sport']!, '2468')),
      isTrue,
    );

    // Remove PIN asks for the current one.
    await _rightClick(tester, _tile(ids['sport']!));
    await tester.tap(find.text('Remove PIN'));
    await settleDrift(tester);
    expect(find.text('Enter the current PIN'), findsOneWidget);
    await typePin('2468');
    expect(find.text('Access PIN removed'), findsOneWidget);
    final unlocked = await tester.runAsync(() => repo.get(ids['sport']!));
    expect(unlocked?.hasAccessPin, isFalse);

    // Remove: confirmation (Cancel has the focus), then the row is gone.
    await _rightClick(tester, _tile(ids['cinema']!));
    await tester.tap(find.text('Remove'));
    await settleDrift(tester);
    expect(find.text('Remove “Sinema Kulübü”?'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter); // Cancel
    await settleDrift(tester);
    expect(find.text('Sinema Kulübü'), findsOneWidget);

    await _rightClick(tester, _tile(ids['cinema']!));
    await tester.tap(find.text('Remove'));
    await settleDrift(tester);
    await tester.tap(find.text('Remove'));
    await settleDrift(tester, rounds: 20);
    expect(find.text('Playlist removed'), findsOneWidget);
    expect(find.text('Sinema Kulübü'), findsNothing);
    expect((await tester.runAsync(() => repo.get(ids['cinema']!))), isNull);
    await unmountAndFlush(tester);
    await tester.runAsync(fx.dispose);
  });

  testWidgets('Manager: switch-playlist request and menu navigation', (
    tester,
  ) async {
    final fx = (await tester.runAsync(() => importMockPlaylist()))!;
    final ids = (await tester.runAsync(() => _seedPlaylists(fx)))!;
    final router = playlistsTestRouter(initialExtra: {'open': ids['sport']});
    // The import screen must not start real imports here.
    final imports = FakeImportService(
      db: fx.db,
      paths: fx.paths,
      secrets: fx.secrets,
      settings: fx.settings,
    );
    await pumpScreen(
      tester,
      routerHost(router),
      overrides: [
        appDatabaseProvider.overrideWithValue(fx.db),
        appPathsProvider.overrideWithValue(fx.paths),
        settingsStoreProvider.overrideWithValue(fx.settings),
        secretStoreProvider.overrideWithValue(fx.secrets),
        importServiceProvider.overrideWithValue(imports),
      ],
    );
    await pumpUntil(
      tester,
      () => find
          .text(routeStubText('/p/${ids['sport']}/live'))
          .evaluate()
          .isNotEmpty,
    );

    // Back on the Manager: Edit, Choose Avatar, Force reload EPG and the
    // playlist settings go to their routes.
    router.go('/');
    await settleDrift(tester);
    await _rightClick(tester, _tile(ids['demo']!));
    await tester.tap(find.text('Edit'));
    await settleDrift(tester);
    expect(router.state.uri.toString(), '/playlists/${ids['demo']}/edit');

    router.go('/');
    await settleDrift(tester);
    await _rightClick(tester, _tile(ids['demo']!));
    await tester.tap(find.text('Force reload EPG'));
    await settleDrift(tester);
    expect(
      router.state.uri.toString(),
      '/playlists/${ids['demo']}/import?scope=epg',
    );
    await pumpUntil(tester, () => imports.started.isNotEmpty);
    expect(imports.started.single, (ids['demo'], ImportScope.epg));

    router.go('/');
    await settleDrift(tester);
    await _rightClick(tester, _tile(ids['family']!));
    await tester.tap(find.text('Force reload EPG'));
    await settleDrift(tester);
    // The M3U without a header guide has nothing to reload.
    expect(find.text('No guide to reload'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);

    await _rightClick(tester, _tile(ids['demo']!));
    await tester.tap(find.text("Open playlist's settings"));
    await pumpUntil(
      tester,
      () => router.state.uri.toString() == '/p/${ids['demo']}/settings',
    );

    router.go('/');
    await settleDrift(tester);
    await _rightClick(tester, _tile(ids['demo']!));
    await tester.tap(find.text('Choose Avatar'));
    await settleDrift(tester);
    expect(router.state.uri.toString(), '/playlists/${ids['demo']}/avatar');
    await unmountAndFlush(tester);
    await tester.runAsync(fx.dispose);
  });

  testWidgets('Manager: empty state', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final settings = SettingsStore(db);
    late AppPaths paths;
    await tester.runAsync(() async {
      await settings.load();
      paths = await tempAppPaths();
    });
    final router = playlistsTestRouter();
    await pumpScreen(
      tester,
      routerHost(router),
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        appPathsProvider.overrideWithValue(paths),
        settingsStoreProvider.overrideWithValue(settings),
        secretStoreProvider.overrideWithValue(MemorySecretStore()),
      ],
    );
    await settleDrift(tester);
    expect(find.text('Add your first playlist'), findsOneWidget);
    await saveScreen(tester, 'playlists_manager_empty');

    // The red button has the keyboard focus.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester);
    expect(router.state.uri.toString(), '/playlists/new');
    expect(find.text('02 / Choose a source'), findsOneWidget);
    await unmountAndFlush(tester);
  });

  testWidgets('Manager rail: Downloads, Settings, About, Add', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final settings = SettingsStore(db);
    late AppPaths paths;
    await tester.runAsync(() async {
      await settings.load();
      paths = await tempAppPaths();
    });
    final router = playlistsTestRouter();
    await pumpScreen(
      tester,
      routerHost(router),
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        appPathsProvider.overrideWithValue(paths),
        settingsStoreProvider.overrideWithValue(settings),
        secretStoreProvider.overrideWithValue(MemorySecretStore()),
      ],
    );
    await settleDrift(tester);
    for (final (key, location) in [
      ('rail-downloads', '/downloads'),
      ('rail-settings', '/settings'),
      ('rail-about', '/settings/about'),
    ]) {
      await tester.tap(find.byKey(ValueKey(key)));
      await settle(tester);
      expect(router.state.uri.toString(), location);
      router.pop();
      await settle(tester);
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN); // plain N does nothing
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(tester);
    expect(router.state.uri.toString(), '/playlists/new');
    await unmountAndFlush(tester);
  });

  test('import scopes', () {
    expect(ImportScope.epg.includesContent, isFalse);
  });
}

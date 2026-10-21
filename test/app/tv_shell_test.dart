import 'package:carina/app/platform/form_factor.dart';
import 'package:carina/app/router.dart';
import 'package:carina/app/shell/shell_state.dart';
import 'package:carina/core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/library/library_harness.dart';
import '../support/screenshot.dart';

/// The real router at [location] for the imported mock playlist, on TV.
Future<ProviderContainer> _pumpTv(
  WidgetTester tester,
  MockImportFixture fx,
  String location, {
  Size size = const Size(960, 540),
}) async {
  late ProviderContainer container;
  await pumpScreen(
    tester,
    Consumer(
      builder: (context, ref, _) {
        container = ProviderScope.containerOf(context);
        return Router.withConfig(config: ref.watch(routerProvider));
      },
    ),
    size: size,
    overrides: libraryOverrides(
      fx,
      extra: [
        formFactorProvider.overrideWithValue(FormFactor.tv),
        initialLocationProvider.overrideWithValue(location),
      ],
    ),
  );
  await settleDrift(tester);
  await settle(tester);
  return container;
}

String _path(ProviderContainer c) =>
    c.read(routerProvider).routerDelegate.currentConfiguration.uri.path;

FocusNode? get _primary => FocusManager.instance.primaryFocus;

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await settleDrift(tester);
  await settle(tester);
}

void main() {
  setUpAll(loadAppFonts);

  group('Back locations', () {
    test('home tab: configured, else live, else the first visible', () {
      const all = MainTab.values;
      expect(shellHomeTab('guide', all), MainTab.guide);
      expect(shellHomeTab('last', all), MainTab.live);
      expect(shellHomeTab('guide', const [MainTab.movies]), MainTab.movies);
      expect(shellHomeTab('last', const []), isNull);
    });

    test('the shell walks up to its home tab, then the Manager', () {
      String back(String path) =>
          shellBackLocation(path, pid: 3, home: MainTab.live);
      expect(back('/p/3/movies/category/42'), '/p/3/movies');
      expect(back('/p/3/settings/player'), '/p/3/settings');
      expect(back('/p/3/movies'), '/p/3/live');
      expect(back('/p/3/search'), '/p/3/live');
      expect(back('/p/3/multiview'), '/p/3/live');
      expect(back('/p/3/live'), Routes.manager);
      expect(shellBackLocation('/p/3/guide', pid: 3), Routes.manager);
    });

    test(
      'outside the shell: settings sections, then the Manager, then out',
      () {
        expect(appBackLocation('/settings/about'), '/settings');
        expect(appBackLocation('/settings'), Routes.manager);
        expect(appBackLocation('/playlists/new'), Routes.manager);
        expect(appBackLocation('/'), isNull);
      },
    );
  });

  testWidgets('TV: a tab lands on a visible focus; Back goes home, then out', (
    tester,
  ) async {
    final fx = await importFixture(tester);
    final pid = fx.playlistId;
    // Live overflows at 960×540 (its own layout, outside this test).
    final c = await _pumpTv(
      tester,
      fx,
      Routes.tab(pid, MainTab.movies),
      size: const Size(1280, 720),
    );
    expect(kIsVisibleFocusTarget(_primary), isTrue, reason: '$_primary');

    await _key(tester, LogicalKeyboardKey.escape);
    expect(_path(c), Routes.tab(pid, MainTab.live));
    expect(kIsVisibleFocusTarget(_primary), isTrue, reason: '$_primary');

    await _key(tester, LogicalKeyboardKey.escape);
    expect(_path(c), Routes.manager);
    await disposeFixture(tester, fx);
  });

  testWidgets('TV: ↑ from a page reaches the top nav, ←/→ walk it, ↓ returns', (
    tester,
  ) async {
    final fx = await importFixture(tester);
    final pid = fx.playlistId;
    await _pumpTv(tester, fx, Routes.playlistSettings(pid));
    final start = _primary;
    expect(kIsVisibleFocusTarget(start), isTrue, reason: '$start');
    final navTop = tester.getBottomLeft(find.byType(KTopNav)).dy;
    expect(start!.rect.top, greaterThan(navTop), reason: 'starts in the page');

    // ↑ climbs the section list, then leaves the page for the nav.
    for (var i = 0; i < 12 && _primary!.rect.top > navTop; i++) {
      await _key(tester, LogicalKeyboardKey.arrowUp);
      expect(kIsVisibleFocusTarget(_primary), isTrue, reason: '$_primary');
    }
    expect(_primary!.rect.bottom, lessThanOrEqualTo(navTop), reason: 'nav');
    final tab = _primary;
    await _key(tester, LogicalKeyboardKey.arrowLeft);
    expect(_primary, isNot(tab));
    expect(_primary!.rect.bottom, lessThanOrEqualTo(navTop));
    await _key(tester, LogicalKeyboardKey.arrowRight);
    expect(_primary, tab);

    await _key(tester, LogicalKeyboardKey.arrowDown);
    expect(_primary!.rect.top, greaterThan(navTop), reason: 'back in page');
    await disposeFixture(tester, fx);
  });

  testWidgets('TV settings: the section has focus; Back goes content → '
      'section → out', (tester) async {
    final fx = await importFixture(tester);
    final pid = fx.playlistId;
    final c = await _pumpTv(
      tester,
      fx,
      Routes.playlistSettings(pid),
      size: const Size(1280, 720),
    );
    final tile = _primary;
    expect(
      tile!.context!.findAncestorWidgetOfExactType<SettingsSectionTile>(),
      isNotNull,
    );
    await _key(tester, LogicalKeyboardKey.arrowRight);
    expect(_primary, isNot(tile));
    expect(kIsVisibleFocusTarget(_primary), isTrue, reason: '$_primary');

    await _key(tester, LogicalKeyboardKey.escape);
    expect(_primary, tile);
    expect(_path(c), Routes.playlistSettings(pid));

    await _key(tester, LogicalKeyboardKey.escape);
    expect(_path(c), Routes.tab(pid, MainTab.live));
    await disposeFixture(tester, fx);
  });
}

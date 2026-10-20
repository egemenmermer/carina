import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show EditableText, Locale, Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:carina/data/repositories/parental_service.dart';
import 'package:carina/data/repositories/epg_repository.dart';
import 'package:carina/data/repositories/live_repository.dart';
import 'package:carina/data/repositories/playlist_repository.dart';
import 'package:carina/data/repositories/reminders_repository.dart';
import 'package:carina/data/repositories/category_repository.dart';
import 'package:carina/data/settings/settings_store.dart';
import 'package:carina/player/engine/fake_engine.dart';

import '../../support/drift_widgets.dart';
import '../../support/mock_import.dart';
import '../../support/screenshot.dart';
import 'live_test_support.dart';

void main() {
  setUpAll(loadAppFonts);

  /// Imports the mock playlist, applies [seed] and pumps TV Live in the
  /// shell. Returns the fixture and the engine factory.
  Future<(MockImportFixture, FakeEngineFactory)> open(
    WidgetTester tester, {
    Future<void> Function(MockImportFixture fx, DateTime now)? seed,
    Locale locale = const Locale('en'),
    Size size = const Size(1440, 900),
  }) async {
    final now = liveTestNow();
    final fx = (await tester.runAsync(importMockPlaylist))!;
    final engines = FakeEngineFactory(autoTick: false);
    if (seed != null) await tester.runAsync(() => seed(fx, now));
    await pumpScreen(
      tester,
      liveInShell(fx.playlistId),
      locale: locale,
      size: size,
      overrides: liveOverrides(
        fx,
        engines: engines,
        externals: RecordingExternals(),
        now: now,
      ),
    );
    await settleDrift(tester, rounds: 20);
    return (fx, engines);
  }

  Future<void> close(WidgetTester tester, MockImportFixture fx) async {
    await unmountAndFlush(tester);
    await tester.runAsync(fx.dispose);
  }

  /// A locked channel (second card) and a reminder on the third card.
  Future<void> referenceState(MockImportFixture fx, DateTime now) async {
    final live = LiveRepository(fx.db, fx.settings, clock: () => now);
    await live.setLocked(fx.playlistId, '1002', true);
    final channel = (await live.channel(fx.playlistId, '1011'))!;
    final epg = EpgRepository(
      fx.db,
      PlaylistRepository(fx.db, fx.secrets, fx.settings),
      clock: () => now,
    );
    final next = (await epg.nowNextForChannel(
      fx.playlistId,
      channel,
      at: now,
    )).next!;
    await RemindersRepository(
      fx.db,
      clock: () => now,
    ).add(fx.playlistId, channel.row, next);
    await live.dispose();
  }

  testWidgets('live_horizontal', (tester) async {
    final (fx, engines) = await open(tester, seed: referenceState);
    await tester.tap(find.text('Show TV').at(1));
    await settleDrift(tester);
    await saveScreen(tester, 'live_horizontal');
    expect(engines.created, hasLength(1));
    expect(engines.last.openedSources.last.url, endsWith('/1011.ts'));
    await close(tester, fx);
  });

  testWidgets('live_horizontal_menu', (tester) async {
    final (fx, _) = await open(tester, seed: referenceState);
    await tester.tap(find.text('Show TV').at(0), buttons: kSecondaryButton);
    await settleDrift(tester);
    await saveScreen(tester, 'live_horizontal_menu');
    expect(find.text('Assign Custom EPG'), findsOneWidget);
    await close(tester, fx);
  });

  testWidgets('live_vertical', (tester) async {
    final (fx, _) = await open(
      tester,
      seed: (fx, now) async {
        await referenceState(fx, now);
        await fx.settings.set(
          PlaylistSettings.liveLayout,
          'vertical',
          playlistId: fx.playlistId,
        );
        await fx.settings.set(
          PlaylistSettings.previewStartsOn,
          'select',
          playlistId: fx.playlistId,
        );
      },
    );
    await saveScreen(tester, 'live_vertical');
    await close(tester, fx);
  });

  testWidgets('live_vertical_preview', (tester) async {
    final (fx, engines) = await open(
      tester,
      seed: (fx, now) async {
        await referenceState(fx, now);
        await fx.settings.set(
          PlaylistSettings.liveLayout,
          'vertical',
          playlistId: fx.playlistId,
        );
      },
    );
    await tester.tap(find.text('Test'));
    await settleDrift(tester);
    await saveScreen(tester, 'live_vertical_preview');
    expect(engines.last.openedSources.last.url, endsWith('/1003.ts'));
    await close(tester, fx);
  });
  testWidgets('live_custom_epg_picker', (tester) async {
    final (fx, _) = await open(tester, seed: referenceState);
    await tester.tap(find.text('TRT 1').first, buttons: kSecondaryButton);
    await settleDrift(tester);
    await tester.tap(find.text('Assign Custom EPG'));
    await settleDrift(tester, rounds: 20);
    await tester.enterText(find.byType(EditableText), 'trt');
    await tester.pump(const Duration(milliseconds: 200));
    await settleDrift(tester, rounds: 20);
    await saveScreen(tester, 'live_custom_epg_picker');
    expect(find.text('TRT Haber'), findsWidgets);
    await close(tester, fx);
  });

  testWidgets('live_rename_category', (tester) async {
    final (fx, _) = await open(tester, seed: referenceState);
    await tester.tap(find.text('TRT 1').first, buttons: kSecondaryButton);
    await settleDrift(tester);
    await tester.tap(find.text("Change category's name"));
    await settleDrift(tester, rounds: 20);
    await tester.enterText(find.byType(EditableText), 'Ulusal Kanallar');
    await settle(tester);
    await saveScreen(tester, 'live_rename_category');
    await close(tester, fx);
  });

  testWidgets('live_number_osd', (tester) async {
    final (fx, _) = await open(tester, seed: referenceState);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
    await tester.pump(const Duration(milliseconds: 300));
    await saveScreen(tester, 'live_number_osd');
    expect(find.text('24'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await settleDrift(tester);
    await close(tester, fx);
  });

  testWidgets('live_locked_preview', (tester) async {
    final (fx, engines) = await open(
      tester,
      seed: (fx, now) async {
        await referenceState(fx, now);
        final live = LiveRepository(fx.db, fx.settings, clock: () => now);
        await live.setLocked(fx.playlistId, '1001', true);
        await live.dispose();
        await ParentalService(
          fx.db,
          fx.secrets,
          LiveRepository(fx.db, fx.settings),
          CategoryRepository(fx.db, fx.settings),
        ).setPin(fx.playlistId, '1234');
      },
    );
    await saveScreen(tester, 'live_locked_preview');
    expect(find.text('Locked channel'), findsOneWidget);
    // Locked previews never play sound.
    expect(engines.last.state.muted, isTrue);
    await close(tester, fx);
  });

  testWidgets('live_empty', (tester) async {
    final (fx, _) = await open(
      tester,
      seed: (fx, now) => fx.settings.set(
        const SettingKey<String?>(
          'selectedCategory.live',
          null,
          SettingScope.playlist,
        ),
        'fav',
        playlistId: fx.playlistId,
      ),
    );
    await saveScreen(tester, 'live_empty');
    expect(find.text('No favorite channels yet'), findsOneWidget);
    await close(tester, fx);
  });
  testWidgets('live_horizontal_tr (Turkish text fit)', (tester) async {
    final (fx, _) = await open(
      tester,
      locale: const Locale('tr'),
      seed: (fx, now) async {
        await referenceState(fx, now);
        await fx.settings.set(AppSettings.language, 'tr');
      },
    );
    await tester.tap(find.text('Show TV').at(1));
    await settleDrift(tester);
    await saveScreen(tester, 'live_horizontal_tr');
    expect(find.text('ŞU AN YAYINDA'), findsOneWidget);
    await tester.tap(find.text('Show TV').at(0), buttons: kSecondaryButton);
    await settleDrift(tester);
    await saveScreen(tester, 'live_horizontal_menu_tr');
    await close(tester, fx);
  });
  testWidgets('live_no_epg (channels without guide data)', (tester) async {
    final (fx, _) = await open(
      tester,
      seed: (fx, now) => fx.settings.set(
        const SettingKey<String?>(
          'selectedCategory.live',
          null,
          SettingScope.playlist,
        ),
        'p:10',
        playlistId: fx.playlistId,
      ),
    );
    await tester.tap(find.text('Kapalı Kanal 404'));
    await settleDrift(tester);
    await saveScreen(tester, 'live_no_epg');
    expect(find.text('EPG not available'), findsWidgets);
    expect(find.text('No programmes in the next 24 hours.'), findsOneWidget);
    await close(tester, fx);
  });
  for (final (name, size, vertical) in [
    ('live_size_min_horizontal', const Size(1100, 680), false),
    ('live_size_min_vertical', const Size(1100, 680), true),
    ('live_size_1080p_horizontal', const Size(1920, 1080), false),
  ]) {
    testWidgets('$name (no overflow)', (tester) async {
      final (fx, _) = await open(
        tester,
        size: size,
        seed: (fx, now) async {
          await referenceState(fx, now);
          if (vertical) {
            await fx.settings.set(
              PlaylistSettings.liveLayout,
              'vertical',
              playlistId: fx.playlistId,
            );
          }
        },
      );
      await saveScreen(tester, name);
      await close(tester, fx);
    });
  }
}

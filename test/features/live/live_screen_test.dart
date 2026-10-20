import 'package:drift/drift.dart' show BooleanExpressionOperators, OrderingTerm;
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carina/app/shell/category_selection.dart';
import 'package:carina/app/shell/shell_state.dart';
import 'package:carina/core/core.dart' show KContextMenu;
import 'package:carina/data/db/database.dart';
import 'package:carina/data/repositories/live_repository.dart';
import 'package:carina/data/repositories/repository_models.dart';
import 'package:carina/data/secrets/secret_store.dart';
import 'package:carina/data/settings/settings_store.dart';
import 'package:carina/features/live/live_screen.dart';
import 'package:carina/features/live/preview/live_preview_view.dart';
import 'package:carina/player/engine/fake_engine.dart';
import 'package:carina/player/player_api.dart';

import '../../support/drift_widgets.dart';
import '../../support/mock_import.dart';
import '../../support/screenshot.dart';
import 'live_test_support.dart';

/// Ulusal (`p:1`) starts with these channels (provider order).
const _first = '1001'; // TRT 1 HD
const _second = '1002'; // Show TV FHD
const _third = '1011'; // Show TV HD

class _Env {
  _Env(this.fx, this.engines, this.externals);

  final MockImportFixture fx;
  final FakeEngineFactory engines;
  final RecordingExternals externals;

  int get pid => fx.playlistId;

  FakeEngine get engine => engines.last;

  String? get lastUrl => engines.created.isEmpty || engine.openedSources.isEmpty
      ? null
      : engine.openedSources.last.url;
}

void main() {
  setUpAll(loadAppFonts);

  Future<_Env> open(
    WidgetTester tester, {
    Map<SettingKey<Object?>, Object?> settings = const {},
    Future<void> Function(MockImportFixture fx)? seed,
  }) async {
    final now = liveTestNow();
    final fx = (await tester.runAsync(importMockPlaylist))!;
    await tester.runAsync(() async {
      for (final e in settings.entries) {
        await fx.settings.set(e.key, e.value, playlistId: fx.playlistId);
      }
      await seed?.call(fx);
    });
    final env = _Env(
      fx,
      FakeEngineFactory(autoTick: false),
      RecordingExternals(),
    );
    await pumpScreen(
      tester,
      liveInShell(fx.playlistId),
      overrides: liveOverrides(
        fx,
        engines: env.engines,
        externals: env.externals,
        now: now,
      ),
    );
    await settleDrift(tester, rounds: 20);
    return env;
  }

  Future<void> close(WidgetTester tester, _Env env) async {
    await unmountAndFlush(tester);
    await tester.runAsync(env.fx.dispose);
  }

  Future<ChannelRow> channelRow(
    WidgetTester tester,
    _Env env,
    String id,
  ) async => (await tester.runAsync(
    () =>
        (env.fx.db.select(env.fx.db.channels)..where(
              (c) => c.playlistId.equals(env.pid) & c.providerId.equals(id),
            ))
            .getSingle(),
  ))!;

  ProviderContainer container(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(LiveScreen)));

  Future<void> openMenu(WidgetTester tester, Finder card) async {
    await tester.tap(card, buttons: kSecondaryButton);
    await settleDrift(tester);
  }

  /// Taps the menu row [label] (not a same-named text behind the menu).
  Future<void> choose(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(
        of: find.byWidgetPredicate((w) => w is KContextMenu),
        matching: find.text(label),
      ),
    );
    await settleDrift(tester, rounds: 15);
  }

  group('preview', () {
    testWidgets('the selected channel previews in one muted engine; clicks '
        'and focus switch the URL', (tester) async {
      final env = await open(tester);
      expect(env.engines.created, hasLength(1));
      expect(env.engine.preview, isTrue);
      expect(env.lastUrl, endsWith('/$_first.ts'));
      expect(env.engine.state.muted, isTrue);

      // Click another card: preview switches at once, same engine.
      await tester.tap(find.text('Show TV').first);
      await settleDrift(tester);
      expect(env.lastUrl, endsWith('/$_second.ts'));

      // Arrow down moves focus; the preview follows after the focus delay.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump(const Duration(milliseconds: 300));
      await settleDrift(tester, rounds: 2);
      expect(env.lastUrl, endsWith('/$_second.ts'));
      await tester.pump(const Duration(milliseconds: 600));
      await settleDrift(tester);
      expect(env.lastUrl, endsWith('/$_third.ts'));
      expect(env.engines.created, hasLength(1));

      await close(tester, env);
      expect(env.engine.isDisposed, isTrue, reason: 'disposed on leave');
    });

    testWidgets('Enter on the previewed channel stops the preview, opens the '
        'player, adds Last watched and resumes', (tester) async {
      final env = await open(tester);
      var stoppedWhilePlaying = false;
      env.externals.onPlayerOpen = () =>
          stoppedWhilePlaying = env.engine.state.source == null;
      final opens = env.engine.openedSources.length;

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settleDrift(tester);

      final request = env.externals.played.single as LivePlayRequest;
      expect(request.playlistId, env.pid);
      expect(request.channelId, _first);
      expect(request.categoryId, '1');
      expect(request.zapChannelIds, hasLength(37));
      expect(request.zapChannelIds!.take(3), [_first, _second, _third]);
      expect(stoppedWhilePlaying, isTrue);
      expect(env.engine.openedSources.length, opens + 1, reason: 'resumed');
      expect(env.lastUrl, endsWith('/$_first.ts'));
      final watched = await tester.runAsync(
        () => env.fx.db.select(env.fx.db.lastWatchedLive).get(),
      );
      expect(watched!.map((w) => w.channelId), [_first]);
      await close(tester, env);
    });

    testWidgets('a click on a card that is not previewed only previews it', (
      tester,
    ) async {
      final env = await open(tester);
      await tester.tap(find.text('Show TV').first);
      await settleDrift(tester);
      expect(env.externals.played, isEmpty);
      await tester.tap(find.text('Show TV').first);
      await settleDrift(tester);
      expect(
        (env.externals.played.single as LivePlayRequest).channelId,
        _second,
      );
      await close(tester, env);
    });

    testWidgets('"start on select" waits for a click', (tester) async {
      final env = await open(
        tester,
        settings: {PlaylistSettings.previewStartsOn: 'select'},
      );
      expect(env.engines.created, isEmpty);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump(const Duration(seconds: 2));
      await settleDrift(tester);
      expect(env.engines.created, isEmpty, reason: 'focus does not preview');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settleDrift(tester);
      expect(env.lastUrl, endsWith('/$_second.ts'));
      expect(env.externals.played, isEmpty);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settleDrift(tester);
      expect(env.externals.played, hasLength(1));
      await close(tester, env);
    });

    testWidgets('preview off: no engine; Enter on the selected card plays', (
      tester,
    ) async {
      final env = await open(
        tester,
        settings: {PlaylistSettings.livePreview: false},
      );
      expect(env.engines.created, isEmpty);
      expect(find.text('Press Enter or click to watch'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settleDrift(tester);
      expect(
        (env.externals.played.single as LivePlayRequest).channelId,
        _first,
      );
      expect(env.engines.created, isEmpty);
      await close(tester, env);
    });

    testWidgets('preview audio on unmutes the preview', (tester) async {
      final env = await open(
        tester,
        settings: {PlaylistSettings.previewAudio: true},
      );
      expect(env.engine.state.muted, isFalse);
      await close(tester, env);
    });

    testWidgets('a locked channel previews blurred and muted; playing it '
        'asks for the PIN first', (tester) async {
      final env = await open(
        tester,
        settings: {PlaylistSettings.previewAudio: true},
        seed: (fx) async {
          final live = LiveRepository(fx.db, fx.settings);
          await live.setLocked(fx.playlistId, _first, true);
          await live.dispose();
        },
      );
      expect(find.text('Locked channel'), findsOneWidget);
      expect(env.engine.state.muted, isTrue);
      env.externals.unlock = false;
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settleDrift(tester);
      expect(env.externals.calls, contains('ensureChannelUnlocked $_first'));
      expect(env.externals.played, isEmpty, reason: 'wrong PIN: no player');
      await close(tester, env);
    });
  });

  testWidgets('locking the previewed channel mutes and blurs it at once', (
    tester,
  ) async {
    final env = await open(
      tester,
      settings: {PlaylistSettings.previewAudio: true},
    );
    expect(env.engine.state.muted, isFalse);
    await tester.runAsync(() async {
      final live = LiveRepository(env.fx.db, env.fx.settings);
      await live.setLocked(env.pid, _first, true);
      await live.dispose();
    });
    await settleDrift(tester);
    expect(find.text('Locked channel'), findsOneWidget);
    expect(env.engine.state.muted, isTrue);
    await close(tester, env);
  });

  group('keyboard', () {
    testWidgets('Left opens the category sidebar; Up from the first card '
        'reaches the category pill', (tester) async {
      final env = await open(tester);
      final c = container(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settleDrift(tester);
      expect(c.read(categorySidebarOpenProvider), isTrue);
      c.read(categorySidebarOpenProvider.notifier).close();
      await settleDrift(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(c.read(categorySidebarOpenProvider), isTrue);
      await close(tester, env);
    });

    testWidgets('leaving an empty category loads the new list and focuses '
        'its first card', (tester) async {
      final env = await open(
        tester,
        settings: {
          const SettingKey<String?>(
            'selectedCategory.live',
            null,
            SettingScope.playlist,
          ): 'fav',
        },
      );
      expect(find.text('No favorite channels yet'), findsOneWidget);
      expect(env.engines.created, isEmpty);
      container(tester)
          .read(
            selectedCategoryProvider((
              playlistId: env.pid,
              kind: SectionKind.live,
            )).notifier,
          )
          .select(const ProviderCategory('1'));
      await settleDrift(tester, rounds: 15);
      expect(find.text('TRT 1'), findsWidgets);
      expect(env.lastUrl, endsWith('/$_first.ts'));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump(const Duration(milliseconds: 900));
      await settleDrift(tester);
      expect(env.lastUrl, endsWith('/$_second.ts'), reason: 'keyboard works');
      await close(tester, env);
    });

    testWidgets('hiding the focused channel moves focus and the preview to '
        'the next card', (tester) async {
      final env = await open(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump(const Duration(milliseconds: 900));
      await settleDrift(tester);
      expect(env.lastUrl, endsWith('/$_second.ts'));
      await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
      await settleDrift(tester);
      await choose(tester, 'Hide channel');
      await settleDrift(tester);
      expect(env.lastUrl, endsWith('/$_third.ts'));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump(const Duration(milliseconds: 900));
      await settleDrift(tester);
      expect(env.lastUrl, endsWith('/1012.ts'));
      await close(tester, env);
    });

    testWidgets('number zapping: OSD, then tune the channel number', (
      tester,
    ) async {
      final env = await open(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit6);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('6'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1400));
      await settleDrift(tester);
      expect(find.text('6'), findsNothing);
      final kanalD = await channelRow(tester, env, '1004');
      expect(kanalD.num, 6);
      expect(env.lastUrl, endsWith('/1004.ts'));
      await close(tester, env);
    });

    testWidgets('number zapping into another category switches it', (
      tester,
    ) async {
      final env = await open(tester);
      final spor = (await tester.runAsync(() async {
        final live = LiveRepository(env.fx.db, env.fx.settings);
        final list = await live.channels(env.pid, const ProviderCategory('2'));
        await live.dispose();
        return list.first;
      }))!;
      for (final ch in '${spor.number}'.split('')) {
        await tester.sendKeyEvent(
          LogicalKeyboardKey(LogicalKeyboardKey.digit0.keyId + int.parse(ch)),
        );
      }
      await tester.pump(const Duration(milliseconds: 1600));
      await settleDrift(tester, rounds: 20);
      expect(find.text('Spor'), findsOneWidget, reason: 'pill');
      expect(env.lastUrl, endsWith('/${spor.providerId}.ts'));
      await close(tester, env);
    });

    testWidgets('an unknown number shows "No channel"', (tester) async {
      final env = await open(tester);
      for (final key in [
        LogicalKeyboardKey.digit9,
        LogicalKeyboardKey.digit9,
        LogicalKeyboardKey.digit9,
        LogicalKeyboardKey.digit9,
      ]) {
        await tester.sendKeyEvent(key);
      }
      await tester.pump(const Duration(milliseconds: 1600));
      await settleDrift(tester);
      expect(find.text('No channel 9999'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('No channel 9999'), findsNothing);
      expect(env.lastUrl, endsWith('/$_first.ts'));
      await close(tester, env);
    });

    testWidgets('number zapping off ignores digits', (tester) async {
      final env = await open(
        tester,
        settings: {PlaylistSettings.numberZapping: false},
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.digit6);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('6'), findsNothing);
      await close(tester, env);
    });
  });

  group('vertical grid', () {
    testWidgets('the previewed card becomes the video tile; arrows move '
        'focus; Left in the first column opens the sidebar', (tester) async {
      final env = await open(
        tester,
        settings: {
          PlaylistSettings.liveLayout: 'vertical',
          PlaylistSettings.previewFocusDelayMs: 0,
        },
      );
      expect(find.byType(LivePreviewView), findsOneWidget);
      expect(env.lastUrl, endsWith('/$_first.ts'));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await settleDrift(tester);
      expect(env.lastUrl, endsWith('/$_second.ts'));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await settleDrift(tester);
      // Four columns at 1440 px: the card below the second one.
      final fifthRow = await tester.runAsync(() async {
        final live = LiveRepository(env.fx.db, env.fx.settings);
        final list = await live.channels(env.pid, const ProviderCategory('1'));
        await live.dispose();
        return list[5].providerId;
      });
      expect(env.lastUrl, endsWith('/$fifthRow.ts'));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(container(tester).read(categorySidebarOpenProvider), isTrue);
      await close(tester, env);
    });

    testWidgets('preview off: a click plays at once', (tester) async {
      final env = await open(
        tester,
        settings: {
          PlaylistSettings.liveLayout: 'vertical',
          PlaylistSettings.livePreview: false,
        },
      );
      expect(find.byType(LivePreviewView), findsNothing);
      await tester.tap(find.text('Show TV').first);
      await settleDrift(tester);
      expect(
        (env.externals.played.single as LivePlayRequest).channelId,
        _second,
      );
      await close(tester, env);
    });
  });

  group('channel menu', () {
    testWidgets('Add to favorites persists and toasts; the menu then offers '
        'Remove', (tester) async {
      final env = await open(tester);
      await openMenu(tester, find.text('TRT 1').first);
      await choose(tester, 'Add to favorites');
      final favorites = await tester.runAsync(
        () => env.fx.db.select(env.fx.db.favorites).get(),
      );
      expect(favorites!.map((f) => f.providerId), [_first]);
      expect(find.text('Added to favorites'), findsOneWidget);
      await openMenu(tester, find.text('TRT 1').first);
      await choose(tester, 'Remove from favorites');
      expect(find.text('Removed from favorites'), findsOneWidget);
      await close(tester, env);
    });

    testWidgets('Hide channel removes it from the list', (tester) async {
      final env = await open(tester);
      expect(find.text('FHD'), findsWidgets);
      await openMenu(tester, find.text('Show TV').first);
      await choose(tester, 'Hide channel');
      expect((await channelRow(tester, env, _second)).hidden, isTrue);
      expect(find.text('Channel hidden'), findsOneWidget);
      // The FHD Show TV card is gone; the preview stays on TRT 1.
      expect(find.text('Show TV'), findsNWidgets(2));
      expect(env.lastUrl, endsWith('/$_first.ts'));
      await close(tester, env);
    });

    testWidgets('Add to Parental Control creates a PIN first, then locks', (
      tester,
    ) async {
      final env = await open(tester);
      await openMenu(tester, find.text('TRT 1').first);
      await choose(tester, 'Add to Parental Control');
      expect(find.text('Create a parental PIN'), findsOneWidget);
      for (final k in [
        LogicalKeyboardKey.digit1,
        LogicalKeyboardKey.digit2,
        LogicalKeyboardKey.digit3,
        LogicalKeyboardKey.digit4,
      ]) {
        await tester.sendKeyEvent(k);
      }
      await settleDrift(tester);
      expect(find.text('Enter the new PIN again'), findsOneWidget);
      for (final k in [
        LogicalKeyboardKey.digit1,
        LogicalKeyboardKey.digit2,
        LogicalKeyboardKey.digit3,
        LogicalKeyboardKey.digit4,
      ]) {
        await tester.sendKeyEvent(k);
      }
      await settleDrift(tester, rounds: 15);
      expect((await channelRow(tester, env, _first)).locked, isTrue);
      expect(
        await tester.runAsync(
          () => env.fx.secrets.read(SecretStore.parentalPin(env.pid)),
        ),
        isNotNull,
      );
      expect(find.text('Parental control channels updated'), findsOneWidget);
      expect(find.text('Locked channel'), findsOneWidget, reason: 'blurred');
      await close(tester, env);
    });

    testWidgets('Remove from Parental Control asks for the PIN', (
      tester,
    ) async {
      final env = await open(
        tester,
        seed: (fx) async {
          final live = LiveRepository(fx.db, fx.settings);
          await live.setLocked(fx.playlistId, _second, true);
          await live.dispose();
        },
      );
      // A PIN exists: set it through the menu's create flow is covered
      // above; here store one directly.
      await tester.runAsync(
        () => env.fx.secrets.write(
          SecretStore.parentalPin(env.pid),
          PinHash.hash('4321'),
        ),
      );
      await openMenu(tester, find.text('Show TV').first);
      await choose(tester, 'Remove from Parental Control');
      expect(find.text('Enter the parental PIN'), findsOneWidget);
      for (final k in [
        LogicalKeyboardKey.digit4,
        LogicalKeyboardKey.digit3,
        LogicalKeyboardKey.digit2,
        LogicalKeyboardKey.digit1,
      ]) {
        await tester.sendKeyEvent(k);
      }
      await settleDrift(tester, rounds: 15);
      expect((await channelRow(tester, env, _second)).locked, isFalse);
      expect(find.text('Parental control channels updated'), findsOneWidget);
      await close(tester, env);
    });

    testWidgets("Change category's name renames locally", (tester) async {
      final env = await open(tester);
      await openMenu(tester, find.text('TRT 1').first);
      await choose(tester, "Change category's name");
      expect(find.text('Original name: TR | Ulusal'), findsOneWidget);
      await tester.enterText(find.byType(EditableText), 'Ulusal Kanallar');
      await tester.tap(find.text('Save'));
      await settleDrift(tester, rounds: 20);
      final category = await tester.runAsync(
        () =>
            (env.fx.db.select(env.fx.db.categories)..where(
                  (c) =>
                      c.playlistId.equals(env.pid) & c.providerId.equals('1'),
                ))
                .getSingle(),
      );
      expect(category!.localName, 'Ulusal Kanallar');
      expect(find.text('Category renamed'), findsOneWidget);
      expect(find.text('Ulusal Kanallar'), findsOneWidget, reason: 'pill');
      await close(tester, env);
    });

    testWidgets('Assign Custom EPG saves the mapping; Reset removes it', (
      tester,
    ) async {
      final env = await open(tester);
      await openMenu(tester, find.text('TRT 1').first);
      await choose(tester, 'Assign Custom EPG');
      expect(find.text('Automatic'), findsOneWidget);
      await tester.enterText(find.byType(EditableText), 'haber');
      await tester.pump(const Duration(milliseconds: 200));
      await settleDrift(tester, rounds: 15);
      await tester.tap(find.text('TRT Haber'));
      await settleDrift(tester, rounds: 15);
      expect(
        (await channelRow(tester, env, _first)).customEpgId,
        'trthaber.tr',
      );
      await tester.pump();
      expect(find.text('Custom EPG assigned'), findsOneWidget);

      await openMenu(tester, find.text('TRT 1').first);
      await choose(tester, 'Assign Custom EPG');
      expect(find.text('Assigned'), findsOneWidget);
      await tester.tap(find.text('Reset'));
      await settleDrift(tester, rounds: 15);
      expect((await channelRow(tester, env, _first)).customEpgId, isNull);
      await tester.pump();
      expect(find.text('Custom EPG removed'), findsOneWidget);
      await close(tester, env);
    });

    testWidgets('Hide category hides it and moves to another category', (
      tester,
    ) async {
      final env = await open(tester);
      await openMenu(tester, find.text('TRT 1').first);
      await choose(tester, 'Hide category');
      await settleDrift(tester, rounds: 10);
      final category = await tester.runAsync(
        () =>
            (env.fx.db.select(env.fx.db.categories)..where(
                  (c) =>
                      c.playlistId.equals(env.pid) & c.providerId.equals('1'),
                ))
                .getSingle(),
      );
      expect(category!.hidden, isTrue);
      expect(find.text('Category hidden'), findsOneWidget);
      expect(find.text('Spor'), findsOneWidget, reason: 'next category');
      await close(tester, env);
    });

    testWidgets('inside Last watched the menu removes the channel from it', (
      tester,
    ) async {
      final env = await open(
        tester,
        settings: {
          const SettingKey<String?>(
            'selectedCategory.live',
            null,
            SettingScope.playlist,
          ): 'last',
        },
        seed: (fx) async {
          final live = LiveRepository(fx.db, fx.settings);
          await live.addLastWatched(fx.playlistId, _second);
          await live.addLastWatched(fx.playlistId, _first);
          await live.dispose();
        },
      );
      expect(find.text('Last watched'), findsOneWidget, reason: 'pill');
      await openMenu(tester, find.text('TRT 1').first);
      await choose(tester, 'Remove from Last watched');
      final rows = await tester.runAsync(
        () => (env.fx.db.select(
          env.fx.db.lastWatchedLive,
        )..orderBy([(l) => OrderingTerm(expression: l.watchedAt)])).get(),
      );
      expect(rows!.map((r) => r.channelId), [_second]);
      expect(find.text('Removed from Last watched'), findsOneWidget);
      await close(tester, env);
    });

    testWidgets('Schedule Reminder, TV Archive, tags and Multi-channel call '
        'the owning features', (tester) async {
      final env = await open(tester);
      await openMenu(tester, find.text('TRT 1').first);
      await choose(tester, 'Schedule Reminder');
      await openMenu(tester, find.text('TRT 1').first);
      await choose(tester, 'TV Archive');
      await openMenu(tester, find.text('TRT 1').first);
      await choose(tester, 'Add to favorite with tags');
      await openMenu(tester, find.text('TRT 1').first);
      await choose(tester, 'Add to Multi-channel');
      expect(env.externals.calls, [
        startsWith('toggleReminder $_first '),
        'showArchiveSheet $_first',
        'showFavoriteTagsSheet $_first',
        'addToMultiview $_first',
      ]);
      await close(tester, env);
    });
  });
}

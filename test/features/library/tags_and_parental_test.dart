import 'dart:async';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carina/core/core.dart';
import 'package:carina/data/db/database.dart';
import 'package:carina/data/repositories/category_repository.dart';
import 'package:carina/data/repositories/favorites_repository.dart';
import 'package:carina/data/repositories/live_repository.dart';
import 'package:carina/data/repositories/parental_service.dart';
import 'package:carina/features/favorites/favorites_api.dart';
import 'package:carina/features/parental/parental_api.dart';

import '../../support/screenshot.dart';
import 'library_harness.dart';

const _host = Text('host');

Future<BuildContext> pumpHost(WidgetTester tester, MockImportFixture fx) async {
  await pumpScreen(tester, _host, overrides: libraryOverrides(fx));
  await settleDrift(tester);
  return tester.element(find.text('host'));
}

ParentalService parentalOf(MockImportFixture fx) => ParentalService(
  fx.db,
  fx.secrets,
  LiveRepository(fx.db, fx.settings),
  CategoryRepository(fx.db, fx.settings),
);

Future<void> typePin(WidgetTester tester, String pin) async {
  for (final c in pin.split('')) {
    await tester.sendKeyEvent(
      LogicalKeyboardKey(LogicalKeyboardKey.digit0.keyId + int.parse(c)),
    );
  }
  await settleDrift(tester, rounds: 4);
  await settle(tester);
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('tag sheet: creates and assigns tags, adds the favorite', (
    tester,
  ) async {
    final fx = await importFixture(tester);
    final pid = fx.playlistId;
    final repo = FavoritesRepository(db: fx.db, settings: fx.settings);
    const movie = '${MockFixtures.kisUykusu}';
    final existing = (await tester.runAsync(
      () => repo.createTag(pid, 'Hafta sonu'),
    ))!;
    final context = await pumpHost(tester, fx);
    unawaited(
      showFavoriteTagsSheet(
        context,
        playlistId: pid,
        type: ItemType.movie,
        providerId: movie,
        title: MockFixtures.kisUykusuName,
      ),
    );
    await settleDrift(tester);
    expect(find.text('Add to favorite with tags'), findsOneWidget);
    // Select the existing tag, create a new one (Enter) and save.
    await tester.tap(find.byKey(ValueKey('tag-$existing')));
    await settle(tester);
    await tester.enterText(find.byType(EditableText), 'Klasikler');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    expect(find.byKey(const ValueKey('pending-Klasikler')), findsOneWidget);
    await tester.tap(find.text('Save'));
    await settleDrift(tester);
    expect(find.text('Add to favorite with tags'), findsNothing);
    expect(find.text('Added to favorites'), findsOneWidget);

    final tags = (await tester.runAsync(
      () => repo.tagsFor(pid, ItemType.movie, movie),
    ))!;
    expect(tags.map((t) => t.name).toSet(), {'Hafta sonu', 'Klasikler'});
    expect(
      await tester.runAsync(() => repo.isFavorite(pid, ItemType.movie, movie)),
      isTrue,
    );

    // Reopen: the chips start selected; deselecting one and saving removes it.
    unawaited(
      showFavoriteTagsSheet(
        context,
        playlistId: pid,
        type: ItemType.movie,
        providerId: movie,
        title: MockFixtures.kisUykusuName,
      ),
    );
    await settleDrift(tester);
    await tester.tap(find.byKey(ValueKey('tag-$existing')));
    await settle(tester);
    await tester.tap(find.text('Save'));
    await settleDrift(tester);
    final after = (await tester.runAsync(
      () => repo.tagsFor(pid, ItemType.movie, movie),
    ))!;
    expect(after.map((t) => t.name), ['Klasikler']);
    expect(find.text('Favorite tags updated'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await disposeFixture(tester, fx);
  });

  testWidgets('tag sheet: Cancel changes nothing', (tester) async {
    final fx = await importFixture(tester);
    final pid = fx.playlistId;
    final repo = FavoritesRepository(db: fx.db, settings: fx.settings);
    final context = await pumpHost(tester, fx);
    unawaited(
      showFavoriteTagsSheet(
        context,
        playlistId: pid,
        type: ItemType.channel,
        providerId: '1001',
        title: 'TRT 1',
      ),
    );
    await settleDrift(tester);
    expect(find.text('No tags yet. Create one below.'), findsOneWidget);
    await tester.enterText(find.byType(EditableText), 'Haber');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    await tester.tap(find.text('Cancel'));
    await settleDrift(tester);
    expect(await tester.runAsync(() => repo.tags(pid)), isEmpty);
    expect(
      await tester.runAsync(
        () => repo.isFavorite(pid, ItemType.channel, '1001'),
      ),
      isFalse,
    );
    await disposeFixture(tester, fx);
  });

  testWidgets('parental gate: unlocked channels pass without a PIN pad', (
    tester,
  ) async {
    final fx = await importFixture(tester);
    final context = await pumpHost(tester, fx);
    bool? result;
    unawaited(
      ensureChannelUnlocked(
        context,
        playlistId: fx.playlistId,
        channelId: '1001',
      ).then((v) => result = v),
    );
    await settleDrift(tester);
    expect(result, isTrue);
    expect(find.byType(KPinPad), findsNothing);
    await disposeFixture(tester, fx);
  });

  testWidgets('parental gate: wrong PIN and Cancel deny, a correct PIN '
      'unlocks for the session', (tester) async {
    final fx = await importFixture(tester);
    final pid = fx.playlistId;
    const locked = '${MockFixtures.cocukKilitli}';
    await tester.runAsync(() async {
      final parental = parentalOf(fx);
      await parental.setPin(pid, '2468');
      await parental.lockChannel(pid, locked, true);
    });
    final context = await pumpHost(tester, fx);

    bool? result;
    unawaited(
      ensureChannelUnlocked(
        context,
        playlistId: pid,
        channelId: locked,
      ).then((v) => result = v),
    );
    await settleDrift(tester);
    expect(find.byType(KPinPad), findsOneWidget);
    expect(find.text('Çocuk Kilitli is locked'), findsOneWidget);
    await typePin(tester, '1111');
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(KPinPad), findsOneWidget, reason: 'wrong PIN');
    expect(result, isNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settleDrift(tester);
    expect(result, isFalse, reason: 'cancelled');

    result = null;
    unawaited(
      ensureChannelUnlocked(
        context,
        playlistId: pid,
        channelId: locked,
      ).then((v) => result = v),
    );
    await settleDrift(tester);
    await typePin(tester, '2468');
    await settleDrift(tester);
    expect(result, isTrue);
    expect(find.byType(KPinPad), findsNothing);

    // Unlocked for the session: no pad the second time.
    result = null;
    unawaited(
      ensureChannelUnlocked(
        context,
        playlistId: pid,
        channelId: locked,
      ).then((v) => result = v),
    );
    await settleDrift(tester);
    expect(result, isTrue);
    expect(find.byType(KPinPad), findsNothing);
    await disposeFixture(tester, fx);
  });

  testWidgets('parental gate: a locked category asks once for its channels', (
    tester,
  ) async {
    final fx = await importFixture(tester);
    final pid = fx.playlistId;
    final ids = (await tester.runAsync(() async {
      final parental = parentalOf(fx);
      await parental.setPin(pid, '1357');
      await parental.lockCategory(
        pid,
        SectionKind.live,
        MockFixtures.ulusalCategoryId,
        true,
      );
      final channels = await fx.db
          .customSelect(
            'SELECT provider_id FROM channels WHERE playlist_id = ? '
            'AND category_id = ? ORDER BY sort_index LIMIT 2',
            variables: [
              Variable.withInt(pid),
              Variable.withString(MockFixtures.ulusalCategoryId),
            ],
          )
          .get();
      return [for (final r in channels) r.read<String>('provider_id')];
    }))!;
    expect(ids, hasLength(2));
    final context = await pumpHost(tester, fx);
    bool? result;
    unawaited(
      ensureChannelUnlocked(
        context,
        playlistId: pid,
        channelId: ids.first,
      ).then((v) => result = v),
    );
    await settleDrift(tester);
    expect(find.byType(KPinPad), findsOneWidget);
    await typePin(tester, '1357');
    await settleDrift(tester);
    expect(result, isTrue);

    // The category is unlocked too: its other channel passes.
    result = null;
    unawaited(
      ensureChannelUnlocked(
        context,
        playlistId: pid,
        channelId: ids.last,
      ).then((v) => result = v),
    );
    await settleDrift(tester);
    expect(result, isTrue);
    expect(find.byType(KPinPad), findsNothing);
    await disposeFixture(tester, fx);
  });

  testWidgets('parental gate: without a PIN the lock asks to create one', (
    tester,
  ) async {
    final fx = await importFixture(tester);
    final pid = fx.playlistId;
    const locked = '${MockFixtures.cocukKilitli}';
    await tester.runAsync(() => parentalOf(fx).lockChannel(pid, locked, true));
    final context = await pumpHost(tester, fx);
    bool? result;
    unawaited(
      ensureChannelUnlocked(
        context,
        playlistId: pid,
        channelId: locked,
      ).then((v) => result = v),
    );
    await settleDrift(tester);
    expect(find.text('Create a PIN'), findsOneWidget);
    await typePin(tester, '4321');
    expect(find.text('Confirm PIN'), findsOneWidget);
    await typePin(tester, '4321');
    await settleDrift(tester);
    expect(result, isTrue);
    expect(find.text('Parental PIN set'), findsOneWidget);
    final parental = parentalOf(fx);
    expect(await tester.runAsync(() => parental.hasPin(pid)), isTrue);
    expect(
      await tester.runAsync(() => parental.verifyPin(pid, '4321')),
      isTrue,
    );
    await tester.pump(const Duration(seconds: 3));
    await disposeFixture(tester, fx);
  });
}

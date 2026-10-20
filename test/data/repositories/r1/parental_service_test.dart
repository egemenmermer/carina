import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carina/data/app_paths.dart';
import 'package:carina/data/db/database.dart';
import 'package:carina/data/repositories/category_repository.dart';
import 'package:carina/data/repositories/live_repository.dart';
import 'package:carina/data/repositories/parental_service.dart';
import 'package:carina/data/repositories/repository_models.dart';
import 'package:carina/data/secrets/secret_store.dart';
import 'package:carina/data/settings/settings_store.dart';

import 'fixtures.dart';

void main() {
  late R1Env env;
  late LiveRepository live;
  late CategoryRepository categories;
  late ParentalService service;
  late int pid;

  setUp(() async {
    env = await R1Env.create();
    live = LiveRepository(env.db, env.settings);
    categories = CategoryRepository(env.db, env.settings);
    service = ParentalService(env.db, env.secrets, live, categories);
    pid = await env.playlist();
    await env.category(pid, 'kids', 'Çocuk');
    await env.category(pid, 'adult', 'Yetişkin', locked: true);
    await env.channel(pid, '1', 'Minika', categoryId: 'kids');
    await env.channel(pid, '2', 'Kilitli', categoryId: 'kids', locked: true);
    await env.channel(pid, '3', 'Gece', categoryId: 'adult');
  });
  tearDown(() async {
    await live.dispose();
    await env.dispose();
  });

  group('PIN', () {
    test('salted hash, verify, change and clear', () async {
      expect(await service.hasPin(pid), isFalse);
      expect(
        await service.verifyPin(pid, '0000'),
        isTrue,
        reason: 'nothing to protect without a PIN',
      );
      await service.setPin(pid, '1234');
      expect(await service.hasPin(pid), isTrue);
      final stored = env.secrets.values[SecretStore.parentalPin(pid)]!;
      expect(stored, isNot(contains('1234')));
      expect(await service.verifyPin(pid, '1234'), isTrue);
      expect(await service.verifyPin(pid, '4321'), isFalse);
      expect(await service.changePin(pid, '0000', '5678'), isFalse);
      expect(await service.verifyPin(pid, '1234'), isTrue);
      expect(await service.changePin(pid, '1234', '5678'), isTrue);
      expect(await service.verifyPin(pid, '5678'), isTrue);
      expect(await service.verifyPin(pid, '1234'), isFalse);
      expect(() => service.setPin(pid, '12'), throwsArgumentError);
      expect(() => service.setPin(pid, 'abcd'), throwsArgumentError);
      await service.clearPin(pid);
      expect(await service.hasPin(pid), isFalse);
      // Another playlist's PIN is separate.
      await service.setPin(pid + 1, '9999');
      expect(await service.verifyPin(pid, '1111'), isTrue);
    });
  });

  group('lock checks and session unlocks', () {
    late ChannelView free;
    late ChannelView own;
    late ChannelView byCategory;

    setUp(() async {
      free = (await live.channel(pid, '1'))!;
      own = (await live.channel(pid, '2'))!;
      byCategory = (await live.channel(pid, '3'))!;
    });

    test('stored flags without a session', () {
      expect(service.isLocked(free), isFalse);
      expect(service.isLocked(own), isTrue);
      expect(service.isLocked(byCategory), isTrue);
    });

    test('session unlocks', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final session = container.read(parentalSessionProvider.notifier);
      ParentalSessionState state() => container.read(parentalSessionProvider);

      session.unlockChannel(pid, '2');
      expect(service.isLocked(own, state()), isFalse);
      expect(service.isLocked(byCategory, state()), isTrue);

      session.unlockFor(byCategory);
      expect(service.isLocked(byCategory, state()), isFalse);
      expect(
        state().isCategoryUnlocked(pid, SectionKind.live, 'adult'),
        isTrue,
        reason: 'the lock came from the category',
      );

      session.onPlaylistOpened(pid);
      expect(service.isLocked(own, state()), isFalse, reason: 'same playlist');
      session.onPlaylistOpened(pid + 1);
      expect(state(), ParentalSessionState.empty);
      expect(service.isLocked(own, state()), isTrue);

      session.unlockAll(pid);
      expect(service.isLocked(own, state()), isFalse);
      expect(service.isLocked(byCategory, state()), isFalse);
      expect(state().allUnlockedFor(pid), isTrue);
      expect(state().allUnlockedFor(pid + 1), isFalse);

      session.unlockChannel(pid + 1, 'x');
      expect(state().playlistId, pid + 1);
      expect(state().allUnlocked, isFalse, reason: 'another playlist');
      expect(service.isLocked(own, state()), isTrue);

      session.clear();
      expect(state(), ParentalSessionState.empty);
    });

    test('category lock checks', () async {
      final list = await categories.categories(pid, SectionKind.live);
      final adult = list.firstWhere((c) => c.providerId == 'adult');
      final kids = list.firstWhere((c) => c.providerId == 'kids');
      expect(service.isCategoryLocked(adult), isTrue);
      expect(service.isCategoryLocked(kids), isFalse);
      expect(service.isCategoryLocked(list.first), isFalse, reason: 'special');
      final unlocked = ParentalSessionState(
        playlistId: pid,
        categories: {
          ParentalSessionState.categoryKey(SectionKind.live, 'adult'),
        },
      );
      expect(service.isCategoryLocked(adult, unlocked), isFalse);
    });
  });

  test('lock mutations and the locked-items list', () async {
    final seen = <LockedItems>[];
    final sub = service.lockedItems(pid).listen(seen.add);
    await pumpUntil(() => seen.isNotEmpty);
    expect(seen.last.channels.map((c) => c.providerId), ['2']);
    expect(seen.last.categories.map((c) => c.providerId), ['adult']);
    await service.lockChannel(pid, '1', true);
    await service.lockCategory(pid, SectionKind.live, 'adult', false);
    await pumpUntil(
      () => seen.last.channels.length == 2 && seen.last.categories.isEmpty,
    );
    expect(seen.last.channels.map((c) => c.providerId), ['2', '1']);
    expect((await live.channel(pid, '1'))!.locked, isTrue);
    expect((await live.channel(pid, '3'))!.locked, isFalse);
    await sub.cancel();
  });

  test('providers: hide mode reveals locked content after unlockAll', () async {
    await env.settings.set(
      PlaylistSettings.parentalMode,
      'hide',
      playlistId: pid,
    );
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(env.db),
        settingsStoreProvider.overrideWithValue(env.settings),
        secretStoreProvider.overrideWithValue(env.secrets),
      ],
    );
    addTearDown(container.dispose);
    final channels = channelsProvider((
      playlistId: pid,
      category: const AllCategory(),
    ));
    final sidebar = categoriesProvider((
      playlistId: pid,
      kind: SectionKind.live,
    ));
    container.listen(channels, (_, _) {});
    container.listen(sidebar, (_, _) {});
    List<String> ids() => [
      for (final c in container.read(channels).value ?? const <ChannelView>[])
        c.providerId,
    ];
    List<String?> cats() => [
      for (final c in container.read(sidebar).value ?? const <CategoryView>[])
        c.providerId,
    ];
    await pumpUntil(() => ids().isNotEmpty && cats().isNotEmpty);
    expect(ids(), ['1']);
    expect(cats(), isNot(contains('adult')));
    container.read(parentalSessionProvider.notifier).unlockAll(pid);
    await pumpUntil(() => ids().length == 3);
    expect(ids(), ['1', '2', '3']);
    await pumpUntil(() => cats().contains('adult'));
    expect(
      (await container.read(parentalServiceProvider).lockedItemsOnce(pid))
          .channels
          .map((c) => c.providerId),
      ['2'],
    );
  });
}

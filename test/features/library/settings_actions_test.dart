import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carina/core/core.dart';
import 'package:carina/data/db/database.dart';
import 'package:carina/data/repositories/category_repository.dart';
import 'package:carina/data/repositories/live_repository.dart';
import 'package:carina/data/repositories/parental_service.dart';
import 'package:carina/data/secrets/secret_store.dart';
import 'package:carina/data/settings/settings_store.dart';
import 'package:carina/data/tmdb/tmdb_service.dart';
import 'package:carina/features/settings/settings_screen.dart';

import '../../support/screenshot.dart';
import 'library_harness.dart';

class FakeTmdbService extends TmdbService {
  FakeTmdbService(MockImportFixture fx)
    : super(db: fx.db, settings: fx.settings, secrets: fx.secrets);

  final List<String?> tested = [];
  int keyChanges = 0;

  @override
  Future<TmdbKeyStatus> testKey([String? credential]) async {
    tested.add(credential);
    return credential == 'bad' ? TmdbKeyStatus.invalid : TmdbKeyStatus.ok;
  }

  @override
  void keyChanged() => keyChanges++;
}

Future<void> pumpSection(
  WidgetTester tester,
  MockImportFixture fx,
  String section, {
  FakeTmdbService? tmdb,
  List<Uri>? launched,
}) async {
  await pumpScreen(
    tester,
    SettingsScreen(playlistId: fx.playlistId, section: section),
    overrides: libraryOverrides(
      fx,
      launched: launched,
      extra: [if (tmdb != null) tmdbServiceProvider.overrideWithValue(tmdb)],
    ),
  );
  await settleDrift(tester);
}

Future<void> tapKey(WidgetTester tester, String key) async {
  final f = find.byKey(ValueKey(key));
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await settleDrift(tester, rounds: 6);
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('TMDb: save stores the key securely, enables TMDb, tests it', (
    tester,
  ) async {
    final fx = await importFixture(tester);
    final tmdb = FakeTmdbService(fx);
    await pumpSection(tester, fx, 'tmdb', tmdb: tmdb);
    expect(find.text('No key saved. Carina works without TMDb too.'), findsOne);

    await tapKey(tester, 'tmdb-test');
    expect(find.text('Enter a key first'), findsOneWidget);

    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('tmdb-key-field')),
        matching: find.byType(EditableText),
      ),
      '  abc123  ',
    );
    await tapKey(tester, 'tmdb-save');
    expect(fx.secrets.values[SecretStore.tmdbKey], 'abc123');
    expect(fx.settings.get(AppSettings.tmdbEnabled), isTrue);
    expect(tmdb.keyChanges, 1);
    expect(tmdb.tested, ['abc123']);
    expect(find.text('The key works'), findsOneWidget);
    expect(find.text('TMDb key saved'), findsOneWidget);
    // The key is never shown back.
    expect(find.textContaining('abc123'), findsNothing);

    await tapKey(tester, 'action:tmdb-remove');
    expect(fx.secrets.values.containsKey(SecretStore.tmdbKey), isFalse);
    await tester.pump(const Duration(seconds: 3));
    await disposeFixture(tester, fx);
  });

  testWidgets('About shows the TMDb attribution only with a key', (
    tester,
  ) async {
    final fx = await importFixture(tester);
    await pumpSection(tester, fx, 'about');
    expect(find.text('Version 1.0.0 (1)'), findsOneWidget);
    expect(find.textContaining('This product uses the TMDB API'), findsNothing);
    await disposeFixture(tester, fx);
  });

  testWidgets('Parental Control asks for the PIN, then unlocks items', (
    tester,
  ) async {
    final fx = await importFixture(tester);
    final pid = fx.playlistId;
    const locked = '${MockFixtures.cocukKilitli}';
    final parental = ParentalService(
      fx.db,
      fx.secrets,
      LiveRepository(fx.db, fx.settings),
      CategoryRepository(fx.db, fx.settings),
    );
    await tester.runAsync(() async {
      await parental.setPin(pid, '9999');
      await parental.lockChannel(pid, locked, true);
    });
    await pumpSection(tester, fx, 'parental');
    expect(find.byKey(const ValueKey('parental-locked')), findsOneWidget);
    expect(find.byKey(ValueKey('locked-channel-$locked')), findsNothing);

    await tapKey(tester, 'parental-enter-pin');
    for (var i = 0; i < 4; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.digit9);
    }
    await settleDrift(tester);
    await settle(tester);
    expect(find.byKey(const ValueKey('parental-content')), findsOneWidget);
    final tile = find.byKey(ValueKey('locked-channel-$locked'));
    expect(tile, findsOneWidget);
    await tester.tap(find.descendant(of: tile, matching: find.text('Unlock')));
    await settleDrift(tester);
    expect(tile, findsNothing);
    final channel = await tester.runAsync(
      () => LiveRepository(fx.db, fx.settings).channel(pid, locked),
    );
    expect(channel!.channelLocked, isFalse);
    await tester.pump(const Duration(seconds: 3));
    await disposeFixture(tester, fx);
  });

  testWidgets('Hidden items: Unhide makes the channel visible again', (
    tester,
  ) async {
    final fx = await importFixture(tester);
    final pid = fx.playlistId;
    final live = LiveRepository(fx.db, fx.settings);
    await tester.runAsync(() => live.setHidden(pid, '1004', true));
    await pumpSection(tester, fx, 'management');
    await tapKey(tester, 'row:hidden');
    final tile = find.byKey(const ValueKey('hidden-channel-1004'));
    expect(tile, findsOneWidget);
    await tester.tap(find.descendant(of: tile, matching: find.text('Unhide')));
    await settleDrift(tester);
    expect(tile, findsNothing);
    expect(
      (await tester.runAsync(() => live.channel(pid, '1004')))!.row.hidden,
      isFalse,
    );
    await tester.pump(const Duration(seconds: 3));
    await disposeFixture(tester, fx);
  });

  testWidgets('Cache: Clear programmes empties the guide after confirming', (
    tester,
  ) async {
    final fx = await importFixture(tester);
    Future<int> count() async {
      final row = await fx.db
          .customSelect('SELECT COUNT(*) AS n FROM programmes')
          .getSingle();
      return row.read<int>('n');
    }

    expect(await tester.runAsync(count), greaterThan(0));
    await pumpSection(tester, fx, 'cache');
    await tapKey(tester, 'action:clear-programmes');
    expect(find.text('Clear every programme?'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(KFrostedPanel),
        matching: find.text('Clear'),
      ),
    );
    await settleDrift(tester);
    expect(await tester.runAsync(count), 0);
    expect(find.text('Programmes cleared'), findsOneWidget);
    expect(find.text('No programmes'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await disposeFixture(tester, fx);
  });

  testWidgets('Diagnostics: copy masks credentials; report opens a file', (
    tester,
  ) async {
    final fx = await importFixture(tester);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    final launched = <Uri>[];
    await pumpSection(tester, fx, 'diagnostics', launched: launched);
    await tapKey(tester, 'action:copy-diagnostics');
    await settleDrift(tester);
    expect(copied, isNotNull);
    expect(copied, contains('Carina diagnostics'));
    expect(copied, contains('"Kanal Demo"'));
    expect(copied, isNot(contains(MockFixtures.password)));
    final host = Uri.parse(fx.server.baseUrl).host;
    expect(copied, isNot(contains('://$host')));
    expect(copied, contains('user: ka***'));

    await tapKey(tester, 'action:report');
    await settleDrift(tester);
    expect(launched, hasLength(1));
    expect(launched.single.path, endsWith('.txt'));
    await tester.pump(const Duration(seconds: 3));
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
    await disposeFixture(tester, fx);
  });

  testWidgets('Reminders: listed for every playlist and deletable', (
    tester,
  ) async {
    final fx = await importFixture(tester);
    final start = DateTime.now().toUtc().add(const Duration(hours: 2));
    await tester.runAsync(
      () => fx.db
          .into(fx.db.reminders)
          .insert(
            RemindersCompanion.insert(
              playlistId: fx.playlistId,
              channelId: '1001',
              channelName: 'TRT 1',
              title: 'Akşam Haberleri',
              start: start.millisecondsSinceEpoch,
              stop: start.add(const Duration(hours: 1)).millisecondsSinceEpoch,
              createdAt: DateTime.now(),
            ),
          ),
    );
    await pumpSection(tester, fx, 'reminders');
    expect(find.text('Akşam Haberleri'), findsOneWidget);
    await tester.tap(find.byTooltip('Delete'));
    await settleDrift(tester);
    expect(find.text('Akşam Haberleri'), findsNothing);
    expect(find.text('Reminder deleted'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await disposeFixture(tester, fx);
  });
}

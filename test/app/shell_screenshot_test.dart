import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carina/app/clock.dart';
import 'package:carina/app/shell/playlist_shell.dart';
import 'package:carina/data/app_paths.dart';
import 'package:carina/data/db/database.dart';
import 'package:carina/data/settings/settings_store.dart';

import '../support/drift_widgets.dart';
import '../support/screenshot.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('shell top nav on TV Live', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final settings = SettingsStore(db);
    late int pid;
    await tester.runAsync(() async {
      await settings.load();
      pid = await db
          .into(db.playlists)
          .insert(
            PlaylistsCompanion.insert(
              name: 'Kanal Demo',
              type: PlaylistType.xtream,
              createdAt: DateTime(2026, 10, 17),
              avatarId: const Value('animal-fox'),
              lastReloadAt: Value(DateTime(2026, 10, 17)),
              liveCount: const Value(300),
              movieCount: const Value(2000),
              seriesCount: const Value(200),
            ),
          );
    });
    final fixed = DateTime(2026, 5, 20, 0, 26);
    await captureScreen(
      tester,
      PlaylistShell(
        playlistId: pid,
        location: '/p/$pid/live',
        child: const Center(
          child: Text('TV Live content', style: TextStyle(color: Colors.white)),
        ),
      ),
      'shell_live',
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        settingsStoreProvider.overrideWithValue(settings),
        minuteClockProvider.overrideWith((ref) => Stream.value(fixed)),
      ],
    );
    expect(find.text('TV Live'), findsWidgets);
    expect(find.text('Movies'), findsWidgets);
    await unmountAndFlush(tester);
  });
}

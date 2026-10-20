import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carina/app/clock.dart';
import 'package:carina/app/shell/playlist_shell.dart';
import 'package:carina/data/app_paths.dart';
import 'package:carina/data/secrets/secret_store.dart';
import 'package:carina/data/settings/settings_store.dart';

import '../data/repositories/r1/fixtures.dart';
import '../support/drift_widgets.dart';
import '../support/screenshot.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('category sidebar on TV Live', (tester) async {
    late R1Env env;
    late int pid;
    await tester.runAsync(() async {
      env = await R1Env.create();
      pid = await env.playlist(name: 'Kanal Demo');
      final groups = [
        ('1', 'TR | Ulusal', 24),
        ('2', 'TR | Spor', 12),
        ('3', 'TR | Haber', 9),
        ('4', 'TR | Belgesel', 7),
        ('5', 'TR | Çocuk', 6),
        ('6', 'IT | Top Italia', 18),
        ('7', 'UK | Entertainment', 15),
        ('8', 'DE | Filme', 5),
      ];
      var sort = 0;
      for (final (id, name, n) in groups) {
        await env.category(pid, id, name, sortIndex: sort++);
        for (var i = 0; i < n; i++) {
          await env.channel(pid, '$id-$i', '$name $i', categoryId: id);
        }
      }
    });
    await pumpScreen(
      tester,
      PlaylistShell(
        playlistId: pid,
        location: '/p/$pid/live',
        child: const SizedBox.expand(),
      ),
      overrides: [
        appDatabaseProvider.overrideWithValue(env.db),
        settingsStoreProvider.overrideWithValue(env.settings),
        secretStoreProvider.overrideWithValue(env.secrets),
        minuteClockProvider.overrideWith(
          (ref) => Stream.value(DateTime(2026, 5, 20, 0, 26)),
        ),
      ],
    );
    await tester.tap(find.byTooltip('Categories'));
    await settleDrift(tester, rounds: 20);
    await saveScreen(tester, 'shell_category_sidebar');
    expect(find.text('🇹🇷 Ulusal'), findsOneWidget);
    await unmountAndFlush(tester);
  });
}

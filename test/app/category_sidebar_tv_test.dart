import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carina/app/clock.dart';
import 'package:carina/app/platform/form_factor.dart';
import 'package:carina/app/shell/category_selection.dart';
import 'package:carina/app/shell/playlist_shell.dart';
import 'package:carina/app/shell/shell_state.dart';
import 'package:carina/data/app_paths.dart';
import 'package:carina/data/db/database.dart' show SectionKind;
import 'package:carina/data/repositories/repository_models.dart';
import 'package:carina/data/secrets/secret_store.dart';
import 'package:carina/data/settings/settings_store.dart';

import '../data/repositories/r1/fixtures.dart';
import '../support/drift_widgets.dart';
import '../support/screenshot.dart';

void main() {
  setUpAll(loadAppFonts);

  Future<(ProviderContainer, int)> pump(
    WidgetTester tester, {
    required bool tv,
    required int categories,
    int? selected,
  }) async {
    late R1Env env;
    late int pid;
    await tester.runAsync(() async {
      env = await R1Env.create();
      pid = await env.playlist(name: 'Kanal Demo');
      for (var i = 0; i < categories; i++) {
        await env.category(pid, '$i', 'Cat $i', sortIndex: i);
        await env.channel(pid, '$i-0', 'Channel $i', categoryId: '$i');
      }
    });
    await pumpScreen(
      tester,
      PlaylistShell(
        playlistId: pid,
        location: '/p/$pid/live',
        child: const SizedBox.expand(),
      ),
      size: const Size(960, 540),
      overrides: [
        appDatabaseProvider.overrideWithValue(env.db),
        settingsStoreProvider.overrideWithValue(env.settings),
        secretStoreProvider.overrideWithValue(env.secrets),
        minuteClockProvider.overrideWith(
          (ref) => Stream.value(DateTime(2026, 5, 20, 0, 26)),
        ),
        if (tv) formFactorProvider.overrideWithValue(FormFactor.tv),
      ],
    );
    await settleDrift(tester, rounds: 12);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlaylistShell)),
    );
    if (selected != null) {
      container
          .read(
            selectedCategoryProvider((playlistId: pid, kind: SectionKind.live))
                .notifier,
          )
          .select(ProviderCategory('$selected'));
    }
    container.read(categorySidebarOpenProvider.notifier).toggle();
    await settleDrift(tester, rounds: 20);
    return (container, pid);
  }

  /// The label of the row that has focus ('' when it is not a row).
  String focusedRow(WidgetTester tester) {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null) return '';
    final text = find.descendant(
      of: find.byElementPredicate((e) => e == context),
      matching: find.byType(Text),
    );
    return text.evaluate().isEmpty
        ? ''
        : tester.widget<Text>(text.first).data ?? '';
  }

  testWidgets('TV sidebar: the selected category, far down the list, takes '
      'focus and is on screen', (tester) async {
    await pump(tester, tv: true, categories: 60, selected: 55);
    expect(focusedRow(tester), 'Cat 55');
    final rect = FocusManager.instance.primaryFocus!.rect;
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.bottom, lessThanOrEqualTo(540));
    await unmountAndFlush(tester);
  });

  testWidgets('TV sidebar: a selection near the top keeps its focus', (
    tester,
  ) async {
    await pump(tester, tv: true, categories: 60, selected: 2);
    expect(focusedRow(tester), 'Cat 2');
    await unmountAndFlush(tester);
  });
}

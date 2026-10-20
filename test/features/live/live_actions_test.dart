import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carina/core/core.dart';
import 'package:carina/features/live/actions/channel_dump.dart';
import 'package:carina/features/live/widgets/upcoming_panel.dart';
import 'package:carina/player/engine/fake_engine.dart';

import '../../support/drift_widgets.dart';
import '../../support/mock_import.dart';
import '../../support/screenshot.dart';
import 'live_test_support.dart';

void main() {
  setUpAll(loadAppFonts);

  Future<(MockImportFixture, RecordingExternals)> open(
    WidgetTester tester, {
    Directory? dumps,
  }) async {
    final now = liveTestNow();
    final fx = (await tester.runAsync(importMockPlaylist))!;
    final externals = RecordingExternals();
    await pumpScreen(
      tester,
      liveInShell(fx.playlistId),
      overrides: [
        ...liveOverrides(
          fx,
          engines: FakeEngineFactory(autoTick: false),
          externals: externals,
          now: now,
        ),
        if (dumps != null)
          liveDumpDirectoryProvider.overrideWithValue(() async => dumps),
      ],
    );
    await settleDrift(tester, rounds: 20);
    return (fx, externals);
  }

  Future<void> close(WidgetTester tester, MockImportFixture fx) async {
    await unmountAndFlush(tester);
    await tester.runAsync(fx.dispose);
  }

  Finder menuRow(String label) => find.descendant(
    of: find.byWidgetPredicate((w) => w is KContextMenu),
    matching: find.text(label),
  );

  testWidgets('the ••• button on a hovered card opens the menu', (
    tester,
  ) async {
    final (fx, _) = await open(tester);
    final card = find.byKey(const ValueKey('live-card-1001'));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(card));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(
      find.descendant(of: card, matching: find.byTooltip('More actions')),
    );
    await settleDrift(tester);
    expect(menuRow('Assign Custom EPG'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settleDrift(tester);
    expect(menuRow('Assign Custom EPG'), findsNothing);
    await close(tester, fx);
  });

  testWidgets('long-press and the Menu key open the menu', (tester) async {
    final (fx, _) = await open(tester);
    await tester.longPress(find.text('TRT 1').first);
    await settleDrift(tester);
    expect(menuRow('Hide channel'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settleDrift(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
    await settleDrift(tester);
    expect(menuRow('Hide channel'), findsOneWidget);
    await close(tester, fx);
  });

  testWidgets('UPCOMING: a row opens the details, the bell toggles a '
      'reminder', (tester) async {
    final (fx, externals) = await open(tester);
    final row = find.byType(UpcomingRow).first;
    await tester.tap(row);
    await settleDrift(tester);
    expect(externals.calls.last, startsWith('showProgrammeDetails 1001 '));
    await tester.tap(
      find.descendant(of: row, matching: find.byIcon(PhosphorIconsLight.bell)),
    );
    await settleDrift(tester);
    expect(externals.calls.last, startsWith('toggleReminder 1001 '));
    // Keyboard: Left goes back to the list, Right reaches the first row,
    // Enter opens its details.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    final before = externals.calls.length;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settleDrift(tester);
    expect(externals.calls, hasLength(before + 1));
    expect(externals.calls.last, startsWith('showProgrammeDetails 1001 '));
    await close(tester, fx);
  });

  testWidgets('Dump Channel writes JSON with masked credentials', (
    tester,
  ) async {
    final dir = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('carina_dump_'),
    ))!;
    addTearDown(() => dir.deleteSync(recursive: true));
    final (fx, _) = await open(tester, dumps: dir);
    await tester.tap(find.text('TRT 1').first, buttons: kSecondaryButton);
    await settleDrift(tester);
    await tester.tap(menuRow('Dump Channel'));
    await settleDrift(tester, rounds: 20);
    final files = dir.listSync().whereType<File>().toList();
    expect(files, hasLength(1));
    final json = files.single.readAsStringSync();
    expect(json, contains('"providerId": "1001"'));
    expect(json, isNot(contains(MockFixtures.password)));
    expect(json, isNot(contains('/${MockFixtures.username}/')));
    expect(json, contains('***'));
    await tester.pump();
    expect(
      find.textContaining('Saved to Desktop: carina-channel-1001-'),
      findsOneWidget,
    );

    await tester.tap(find.text('TRT 1').first, buttons: kSecondaryButton);
    await settleDrift(tester);
    await tester.tap(menuRow('Dump Category'));
    await settleDrift(tester, rounds: 20);
    final category = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.contains('carina-category-1-'))
        .single
        .readAsStringSync();
    expect(category, contains('"name": "TR | Ulusal"'));
    expect(category, isNot(contains(MockFixtures.password)));
    await close(tester, fx);
  });

  testWidgets('Copy stream URL copies the masked URL', (tester) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final (fx, _) = await open(tester);
    await tester.tap(find.text('TRT 1').first, buttons: kSecondaryButton);
    await settleDrift(tester);
    await tester.tap(menuRow('Copy stream URL'));
    await settleDrift(tester);
    expect(copied, hasLength(1));
    expect(copied.single, endsWith('/1001.ts'));
    expect(copied.single, isNot(contains(MockFixtures.password)));
    expect(copied.single, contains('***'));
    await tester.pump();
    expect(find.text('Stream URL copied (credentials hidden)'), findsOneWidget);
    await close(tester, fx);
  });
}

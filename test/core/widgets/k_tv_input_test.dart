import 'package:carina/app/platform/form_factor.dart';
import 'package:carina/core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_app.dart';

void main() {
  final tv = [formFactorProvider.overrideWithValue(FormFactor.tv)];

  Future<(List<String>, FocusNode)> pumpTile(
    WidgetTester tester, {
    bool tvMode = true,
    bool withMenu = true,
  }) async {
    final log = <String>[];
    final node = FocusNode(debugLabel: 'tile');
    addTearDown(node.dispose);
    await tester.pumpWidget(
      carinaTestApp(
        Center(
          child: KInteractive(
            focusNode: node,
            autofocus: true,
            onTap: () => log.add('tap'),
            onContextMenu: withMenu ? (_) => log.add('menu') : null,
            builder: (context, state, _) =>
                const SizedBox(width: 120, height: 60),
          ),
        ),
        overrides: tvMode ? tv : const [],
      ),
    );
    await tester.pump();
    expect(node.hasPrimaryFocus, isTrue);
    return (log, node);
  }

  group('KInteractive on TV', () {
    testWidgets('a short OK press taps on release', (tester) async {
      final (log, _) = await pumpTile(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
      expect(log, isEmpty);
      await tester.pump(const Duration(milliseconds: 120));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
      expect(log, ['tap']);
    });

    testWidgets('holding OK opens the menu once and never taps', (
      tester,
    ) async {
      final (log, _) = await pumpTile(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
      await tester.pump(
        KInteractive.tvMenuHold + const Duration(milliseconds: 50),
      );
      expect(log, ['menu']);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.select);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.select);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
      expect(log, ['menu']);
    });

    testWidgets('the first key repeat opens the menu before the timer', (
      tester,
    ) async {
      final (log, _) = await pumpTile(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
      expect(log, ['menu']);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(seconds: 1));
      expect(log, ['menu']);
    });

    testWidgets('without a menu OK taps on press, once per press', (
      tester,
    ) async {
      final (log, _) = await pumpTile(tester, withMenu: false);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
      expect(log, ['tap']);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
      expect(log, ['tap']);
    });
  });

  testWidgets('desktop keeps Enter on press, repeats included', (tester) async {
    final (log, _) = await pumpTile(tester, tvMode: false);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    expect(log, ['tap']);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    expect(log, ['tap', 'tap']);
  });

  testWidgets('TV: the held OK that opened a menu does not choose a row', (
    tester,
  ) async {
    String? chosen;
    await tester.pumpWidget(
      carinaTestApp(
        Center(
          child: Builder(
            builder: (context) => KInteractive(
              autofocus: true,
              onTap: () {},
              onContextMenu: (position) async {
                chosen = await showKContextMenu<String>(
                  context,
                  position: position,
                  entries: const [
                    KMenuEntry(label: 'First', value: 'first'),
                    KMenuEntry(label: 'Second', value: 'second'),
                  ],
                );
              },
              builder: (context, state, _) =>
                  const SizedBox(width: 120, height: 60),
            ),
          ),
        ),
        overrides: tv,
      ),
    );
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.pump(
      KInteractive.tvMenuHold + const Duration(milliseconds: 50),
    );
    await tester.pumpAndSettle();
    expect(find.text('First'), findsOneWidget);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('First'), findsOneWidget, reason: 'menu stays open');
    // The first row starts highlighted on TV: a fresh OK chooses it.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(chosen, 'first');
  });
}

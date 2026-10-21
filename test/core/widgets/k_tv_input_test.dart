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

  group('KTextField on TV', () {
    Future<(TextEditingController, FocusNode)> pumpField(
      WidgetTester tester, {
      bool tvMode = true,
    }) async {
      final controller = TextEditingController(text: 'abc');
      final node = FocusNode(debugLabel: 'field');
      addTearDown(controller.dispose);
      addTearDown(node.dispose);
      await tester.pumpWidget(
        carinaTestApp(
          Center(
            child: SizedBox(
              width: 300,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  KTextField(controller: controller, focusNode: node),
                  const SizedBox(height: 20),
                  KButton.secondary(
                    key: const ValueKey('below'),
                    label: 'Below',
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
          overrides: tvMode ? tv : const [],
        ),
      );
      node.requestFocus();
      await tester.pumpAndSettle();
      return (controller, node);
    }

    testWidgets('D-pad focus keeps the keyboard down; OK opens it', (
      tester,
    ) async {
      final (controller, node) = await pumpField(tester);
      expect(node.hasPrimaryFocus, isTrue);
      expect(tester.testTextInput.isVisible, isFalse);

      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isTrue);
      tester.testTextInput.enterText('abcd');
      await tester.pump();
      expect(controller.text, 'abcd');

      // Hidden by the system (the remote's Back); OK raises it again.
      tester.testTextInput.hide();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isTrue);
    });

    testWidgets('↓ leaves the field; ← and → move the caret first', (
      tester,
    ) async {
      final (controller, node) = await pumpField(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      controller.selection = const TextSelection.collapsed(offset: 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(node.hasPrimaryFocus, isTrue, reason: 'caret moved inside');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(node.hasFocus, isFalse);
      expect(tester.testTextInput.isVisible, isFalse);
      final below = Focus.of(tester.element(find.text('Below')))
          .hasPrimaryFocus;
      expect(below, isTrue);
    });

    testWidgets('desktop: focusing the field opens the input at once', (
      tester,
    ) async {
      await pumpField(tester, tvMode: false);
      expect(tester.testTextInput.isVisible, isTrue);
    });
  });

  testWidgets('KTvFocusFirst: on TV a focused scope hands focus to its '
      'first item; desktop keeps the scope', (tester) async {
    for (final tvMode in [true, false]) {
      await tester.pumpWidget(
        carinaTestApp(
          FocusScope(
            autofocus: true,
            child: KTvFocusFirst(
              child: Column(
                children: [
                  KButton.secondary(label: 'One', onPressed: () {}),
                  KButton.secondary(label: 'Two', onPressed: () {}),
                ],
              ),
            ),
          ),
          overrides: tvMode ? tv : const [],
        ),
      );
      await tester.pumpAndSettle();
      final primary = FocusManager.instance.primaryFocus!;
      expect(primary is FocusScopeNode, !tvMode, reason: 'tv: $tvMode');
      if (tvMode) {
        expect(tester.getRect(find.text('One')).overlaps(primary.rect), isTrue);
      }
      await tester.pumpWidget(const SizedBox());
    }
  });
}

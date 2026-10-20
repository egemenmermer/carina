import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carina/core/core.dart';

import '../../support/test_app.dart';

Future<BuildContext> _pumpHost(WidgetTester tester) async {
  late BuildContext ctx;
  await tester.pumpWidget(
    carinaTestApp(
      Builder(
        builder: (context) {
          ctx = context;
          return const SizedBox.expand();
        },
      ),
    ),
  );
  return ctx;
}

void main() {
  testWidgets('keyboard digits enter the PIN and validate it', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ctx = await _pumpHost(tester);
    final checked = <String>[];
    final result = showPinPad(
      ctx,
      title: 'Enter PIN',
      validate: (pin) async {
        checked.add(pin);
        return pin == '1234';
      },
    );
    await tester.pumpAndSettle();
    expect(find.text('Enter PIN'), findsOneWidget);

    for (final key in [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.numpad2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
    ]) {
      await tester.sendKeyEvent(key);
    }
    await tester.pumpAndSettle();

    expect(checked, ['1234']);
    expect(await result, '1234');
    expect(find.text('Enter PIN'), findsNothing);
  });

  testWidgets('a wrong PIN shakes, shows the error and clears', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ctx = await _pumpHost(tester);
    final result = showPinPad(
      ctx,
      title: 'Enter PIN',
      validate: (pin) async => pin == '0000',
    );
    await tester.pumpAndSettle();

    for (final d in ['1', '1', '1', '1']) {
      await tester.tap(find.text(d).first);
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 100));
    final error = tester.widget<AnimatedOpacity>(
      find.ancestor(
        of: find.text('Wrong PIN. Try again.'),
        matching: find.byType(AnimatedOpacity),
      ),
    );
    expect(error.opacity, 1);
    await tester.pumpAndSettle();
    // Still open, digits cleared: Backspace does nothing harmful, then the
    // right PIN unlocks.
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    for (var i = 0; i < 4; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
    }
    await tester.pumpAndSettle();
    expect(await result, '0000');
  });

  testWidgets('Backspace deletes the last digit', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ctx = await _pumpHost(tester);
    final result = showPinPad(ctx, title: 'New PIN');
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.digit5);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit6);
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit7);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit8);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit9);
    await tester.pumpAndSettle();
    // Without a validator the first complete PIN is returned.
    expect(await result, '5789');
  });

  testWidgets('Esc and Cancel close with null', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ctx = await _pumpHost(tester);
    var result = showPinPad(ctx, title: 'Enter PIN');
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(await result, isNull);

    result = showPinPad(ctx, title: 'Enter PIN');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await result, isNull);
  });
}

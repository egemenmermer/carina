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
  const choices = [
    KChoice(value: 'system', label: 'System'),
    KChoice(value: 'en', label: 'English'),
    KChoice(value: 'tr', label: 'Türkçe'),
  ];

  testWidgets('chooser returns the tapped value', (tester) async {
    final ctx = await _pumpHost(tester);
    final result = showChooser<String>(
      ctx,
      title: 'Language',
      choices: choices,
      selected: 'en',
    );
    await tester.pumpAndSettle();
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    await tester.tap(find.text('Türkçe'));
    await tester.pumpAndSettle();
    expect(await result, 'tr');
    expect(find.text('Language'), findsNothing);
  });

  testWidgets('chooser Cancel and Esc return null', (tester) async {
    final ctx = await _pumpHost(tester);
    var result = showChooser<String>(ctx, title: 'Language', choices: choices);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await result, isNull);

    result = showChooser<String>(ctx, title: 'Language', choices: choices);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(await result, isNull);
  });

  testWidgets('chooser keyboard: the selected row has focus, Down + Enter', (
    tester,
  ) async {
    final ctx = await _pumpHost(tester);
    final result = showChooser<String>(
      ctx,
      title: 'Language',
      choices: choices,
      selected: 'system',
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(await result, 'en');
  });

  testWidgets('popover menu: check rows close, steppers update in place', (
    tester,
  ) async {
    final ctx = await _pumpHost(tester);
    var delay = 0.0;
    var track = 'en';
    List<KPopoverSection> sections(BuildContext _) => [
      KPopoverSection(
        header: 'Audio',
        items: [
          KPopoverItem.check(
            label: 'English',
            checked: track == 'en',
            onTap: () => track = 'en',
          ),
          KPopoverItem.check(
            label: 'Türkçe',
            checked: track == 'tr',
            onTap: () => track = 'tr',
          ),
          KPopoverItem.stepper(
            label: 'Audio delay',
            valueText: '${delay.toStringAsFixed(1)} s',
            onDecrement: () => delay -= 0.1,
            onIncrement: () => delay += 0.1,
          ),
        ],
      ),
    ];

    final done = showKPopoverMenu(
      ctx,
      anchorRect: const Rect.fromLTWH(380, 500, 40, 40),
      sections: sections,
    );
    await tester.pumpAndSettle();
    expect(find.text('AUDIO'), findsOneWidget);
    expect(find.text('0.0 s'), findsOneWidget);

    await tester.tap(find.byIcon(PhosphorIconsBold.plus));
    await tester.pumpAndSettle();
    expect(find.text('0.1 s'), findsOneWidget);

    // Keyboard: the checked row has focus; Down twice reaches the stepper,
    // where Left / Right step the value.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(find.text('-0.1 s'), findsOneWidget);

    // The popover sits above its anchor.
    final rect = tester.getRect(find.byType(KPopoverMenu));
    expect(rect.bottom, lessThanOrEqualTo(500));

    await tester.tap(find.text('Türkçe'));
    await tester.pumpAndSettle();
    await done;
    expect(track, 'tr');
    expect(find.text('AUDIO'), findsNothing);
  });
}

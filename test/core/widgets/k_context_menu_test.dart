import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carina/core/core.dart';

import '../../support/test_app.dart';

void main() {
  final entries = <KMenuEntry<String>>[
    const KMenuEntry(
      label: 'Add to favorites',
      icon: PhosphorIconsLight.star,
      value: 'fav',
    ),
    const KMenuEntry(
      label: 'Start recording now',
      value: 'rec',
      enabled: false,
    ),
    const KMenuEntry(label: 'Schedule Reminder', value: 'remind'),
    const KMenuEntry.separator(),
    const KMenuEntry(label: 'Remove', value: 'remove', destructive: true),
  ];

  Future<Future<String?>> open(
    WidgetTester tester, {
    Offset position = const Offset(100, 100),
    String? title,
  }) async {
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
    final result = showKContextMenu<String>(
      ctx,
      position: position,
      title: title,
      entries: entries,
    );
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('arrow keys skip disabled rows; Enter returns the value', (
    tester,
  ) async {
    final result = await open(tester);
    expect(find.text('Add to favorites'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown); // favorites
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown); // skips "rec"
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(await result, 'remind');
    expect(find.text('Add to favorites'), findsNothing);
  });

  testWidgets('Up from nothing selected wraps to the last row', (tester) async {
    final result = await open(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(await result, 'remove');
  });

  testWidgets('Esc closes with null', (tester) async {
    final result = await open(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(await result, isNull);
    expect(find.text('Remove'), findsNothing);
  });

  testWidgets('outside click closes with null', (tester) async {
    final result = await open(tester);
    await tester.tapAt(const Offset(700, 560));
    await tester.pumpAndSettle();
    expect(await result, isNull);
  });

  testWidgets('clicking a row returns its value and runs onSelected', (
    tester,
  ) async {
    var selected = 0;
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
    final result = showKContextMenu<int>(
      ctx,
      position: const Offset(50, 50),
      title: 'TRT 1',
      entries: [
        KMenuEntry(
          label: 'Hide channel',
          value: 7,
          onSelected: () => selected++,
        ),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.text('TRT 1'), findsOneWidget);
    await tester.tap(find.text('Hide channel'));
    await tester.pumpAndSettle();
    expect(await result, 7);
    expect(selected, 1);
  });

  testWidgets('disabled rows cannot be clicked', (tester) async {
    final result = await open(tester);
    await tester.tap(find.text('Start recording now'));
    await tester.pumpAndSettle();
    expect(find.text('Start recording now'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(await result, isNull);
  });

  testWidgets('menu stays inside the window near the bottom-right corner', (
    tester,
  ) async {
    await open(tester, position: const Offset(790, 590));
    final rect = tester.getRect(find.byType(KContextMenu<String>));
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(800));
    expect(rect.bottom, lessThanOrEqualTo(600));
    // Flipped to the left of / above the pointer.
    expect(rect.right, lessThanOrEqualTo(790));
  });

  testWidgets('right-click on a card opens the menu at the pointer', (
    tester,
  ) async {
    String? chosen;
    await tester.pumpWidget(
      carinaTestApp(
        Builder(
          builder: (context) => Center(
            child: SizedBox(
              width: 200,
              height: 100,
              child: FocusableCard(
                onTap: () {},
                onContextMenu: (pos) async {
                  chosen = await showKContextMenu<String>(
                    context,
                    position: pos,
                    entries: entries,
                  );
                },
                child: const Text('Card'),
              ),
            ),
          ),
        ),
      ),
    );
    final pointer = tester.getCenter(find.text('Card'));
    await tester.tapAt(pointer, buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    final rect = tester.getRect(find.byType(KContextMenu<String>));
    expect(rect.topLeft, pointer);
    await tester.tap(find.text('Add to favorites'));
    await tester.pumpAndSettle();
    expect(chosen, 'fav');
  });
}

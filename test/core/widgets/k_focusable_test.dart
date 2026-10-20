import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carina/core/core.dart';

import '../../support/test_app.dart';

double _scaleOf(WidgetTester tester, Key key) => tester
    .widget<AnimatedScale>(
      find.descendant(
        of: find.byKey(key),
        matching: find.byType(AnimatedScale),
      ),
    )
    .scale;

Color? _borderColorOf(WidgetTester tester, Key key) {
  final container = tester.widget<AnimatedContainer>(
    find
        .descendant(
          of: find.byKey(key),
          matching: find.byType(AnimatedContainer),
        )
        .first,
  );
  final decoration = container.foregroundDecoration as BoxDecoration?;
  return (decoration?.border as Border?)?.top.color;
}

void main() {
  const cardKey = Key('card');

  Widget card({
    VoidCallback? onTap,
    KContextMenuCallback? onContextMenu,
    bool enabled = true,
  }) => Center(
    child: SizedBox(
      width: 200,
      height: 120,
      child: FocusableCard(
        key: cardKey,
        onTap: onTap,
        onContextMenu: onContextMenu,
        enabled: enabled,
        child: const Center(child: Text('Card')),
      ),
    ),
  );

  testWidgets('hover scales to 1.04 and shows the white border', (
    tester,
  ) async {
    await tester.pumpWidget(carinaTestApp(card(onTap: () {})));
    expect(_scaleOf(tester, cardKey), 1.0);
    expect(_borderColorOf(tester, cardKey)!.a, 0);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(find.byKey(cardKey)));
    addTearDown(mouse.removePointer);
    await tester.pumpAndSettle();

    expect(_scaleOf(tester, cardKey), 1.04);
    expect(_borderColorOf(tester, cardKey), KColors.focusRing);

    await mouse.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    expect(_scaleOf(tester, cardKey), 1.0);
  });

  testWidgets('keyboard focus scales, Enter and Space activate', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(carinaTestApp(card(onTap: () => taps++)));

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(_scaleOf(tester, cardKey), 1.04);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(taps, 2);
  });

  testWidgets('right-click and long-press report the pointer position', (
    tester,
  ) async {
    final positions = <Offset>[];
    await tester.pumpWidget(
      carinaTestApp(card(onTap: () {}, onContextMenu: positions.add)),
    );
    final center = tester.getCenter(find.byKey(cardKey));

    await tester.tapAt(
      center + const Offset(20, 10),
      buttons: kSecondaryButton,
    );
    await tester.pump();
    expect(positions, [center + const Offset(20, 10)]);

    await tester.longPressAt(center - const Offset(30, 0));
    await tester.pump();
    expect(positions.last, center - const Offset(30, 0));
  });

  testWidgets('Menu key and Shift+F10 open the menu at the center', (
    tester,
  ) async {
    final positions = <Offset>[];
    await tester.pumpWidget(
      carinaTestApp(card(onTap: () {}, onContextMenu: positions.add)),
    );
    final center = tester.getCenter(find.byKey(cardKey));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.f10);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    expect(positions, hasLength(2));
    for (final p in positions) {
      expect((p - center).distance, lessThan(1));
    }
  });

  testWidgets('disabled cards ignore input and do not scale', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      carinaTestApp(card(onTap: () => taps++, enabled: false)),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(find.byKey(cardKey)));
    addTearDown(mouse.removePointer);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(cardKey), warnIfMissed: false);
    await tester.pump();

    expect(taps, 0);
    expect(_scaleOf(tester, cardKey), 1.0);
    expect(
      tester
          .widget<Opacity>(
            find.descendant(
              of: find.byKey(cardKey),
              matching: find.byType(Opacity),
            ),
          )
          .opacity,
      0.4,
    );
  });

  testWidgets('clicking focuses the card (tvOS behavior)', (tester) async {
    await tester.pumpWidget(carinaTestApp(card(onTap: () {})));
    await tester.tap(find.byKey(cardKey));
    await tester.pump();
    final focused = FocusManager.instance.primaryFocus;
    expect(focused, isNotNull);
    expect(
      find.descendant(
        of: find.byKey(cardKey),
        matching: find.byWidgetPredicate(
          (w) => w is Focus && w.focusNode == focused,
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('reduced motion makes hover changes instant', (tester) async {
    await tester.pumpWidget(
      carinaTestApp(card(onTap: () {}), disableAnimations: true),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(find.byKey(cardKey)));
    addTearDown(mouse.removePointer);
    await tester.pump();
    final scale = tester.widget<AnimatedScale>(
      find.descendant(
        of: find.byKey(cardKey),
        matching: find.byType(AnimatedScale),
      ),
    );
    expect(scale.duration, Duration.zero);
    expect(scale.scale, 1.04);
  });
}

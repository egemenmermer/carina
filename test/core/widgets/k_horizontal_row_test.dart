import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carina/core/core.dart';

import '../../support/test_app.dart';

void main() {
  late ScrollController controller;
  late List<int> focusedIndices;

  setUp(() {
    controller = ScrollController();
    focusedIndices = [];
  });

  tearDown(() => controller.dispose());

  Widget row({int count = 20}) => Align(
    alignment: Alignment.topLeft,
    child: KHorizontalRow(
      controller: controller,
      itemCount: count,
      itemWidth: 200,
      itemHeight: 110,
      onFocusedIndexChanged: focusedIndices.add,
      itemBuilder: (context, i) => FocusableCard(
        onTap: () {},
        child: Center(child: Text('Item $i')),
      ),
    ),
  );

  testWidgets('mouse wheel scrolls the row horizontally while hovered', (
    tester,
  ) async {
    await tester.pumpWidget(carinaTestApp(row()));
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    final location = tester.getCenter(find.text('Item 1'));
    await tester.sendEventToBinding(pointer.hover(location));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, 300)));
    await tester.pumpAndSettle();
    expect(controller.offset, closeTo(300, 0.5));

    // Scrolling back past the start stops at 0.
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, -1000)));
    await tester.pumpAndSettle();
    expect(controller.offset, 0);
  });

  testWidgets('at the start the wheel is left to the page', (tester) async {
    final page = ScrollController();
    addTearDown(page.dispose);
    await tester.pumpWidget(
      carinaTestApp(
        ListView(
          controller: page,
          children: [row(), const SizedBox(height: 2000)],
        ),
      ),
    );
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(
      pointer.hover(tester.getCenter(find.text('Item 1'))),
    );
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, -120)));
    await tester.pumpAndSettle();
    expect(controller.offset, 0);
    // Scrolling down moves the row, not the page.
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, 120)));
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThan(0));
    expect(page.offset, 0);
  });

  testWidgets('edge arrows appear on hover and page the row', (tester) async {
    await tester.pumpWidget(carinaTestApp(row()));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(find.text('Item 0')));
    addTearDown(mouse.removePointer);
    await tester.pumpAndSettle();

    final right = find.byIcon(PhosphorIconsBold.caretRight);
    final opacity = tester.widget<AnimatedOpacity>(
      find.ancestor(of: right, matching: find.byType(AnimatedOpacity)),
    );
    expect(opacity.opacity, 1);
    final left = find.byIcon(PhosphorIconsBold.caretLeft);
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.ancestor(of: left, matching: find.byType(AnimatedOpacity)),
          )
          .opacity,
      0,
    );

    await tester.tap(right);
    await tester.pumpAndSettle();
    // 80% of the 800 px viewport, snapped to the 216 px item extent.
    expect(controller.offset, closeTo(648, 0.5));
  });

  testWidgets('arrow keys move focus between cards and keep it visible', (
    tester,
  ) async {
    await tester.pumpWidget(carinaTestApp(row()));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab); // focus item 0
    await tester.pumpAndSettle();
    expect(focusedIndices.last, 0);

    for (var i = 0; i < 6; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
    }
    expect(focusedIndices.last, 6);
    // Item 6 spans 48 + 6 × 216 … + 200; it must be fully inside the
    // 800 px viewport (with the 48 px gutter).
    final itemRight = 48 + 6 * 216 + 200;
    expect(controller.offset, greaterThanOrEqualTo(itemRight + 48 - 800 - 1));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(focusedIndices.last, 5);
  });

  testWidgets('focus reaches cards that were not built yet', (tester) async {
    await tester.pumpWidget(carinaTestApp(row(count: 40)));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    final state = tester.state<KHorizontalRowState>(
      find.byType(KHorizontalRow),
    );
    state.focusIndex(30);
    await tester.pumpAndSettle();
    expect(state.focusedIndex, 30);
    expect(find.text('Item 30'), findsOneWidget);
  });
}

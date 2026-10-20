import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carina/features/live/widgets/live_marquee.dart';

void main() {
  const text = 'I misteri di Murdoch (Commando) – a very long programme title';
  const style = TextStyle(fontSize: 15);

  Widget host({required bool active, bool reduced = false}) => MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          width: 120,
          child: LiveMarquee(text: text, style: style, active: active),
        ),
      ),
    ),
  );

  Finder transform() => find.descendant(
    of: find.byType(LiveMarquee),
    matching: find.byType(Transform),
  );

  double offset(WidgetTester tester) =>
      tester.widget<Transform>(transform()).transform.getTranslation().x;

  testWidgets('an overflowing active line scrolls after a pause', (
    tester,
  ) async {
    await tester.pumpWidget(host(active: true));
    expect(offset(tester), 0);
    await tester.pump(const Duration(milliseconds: 1500));
    expect(offset(tester), 0, reason: 'still pausing');
    await tester.pump(const Duration(seconds: 3));
    expect(offset(tester), lessThan(-10));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('inactive or reduced motion: a plain ellipsized line', (
    tester,
  ) async {
    await tester.pumpWidget(host(active: false));
    expect(transform(), findsNothing);
    expect(
      tester.widget<Text>(find.text(text)).overflow,
      TextOverflow.ellipsis,
    );
    await tester.pumpWidget(host(active: true, reduced: true));
    expect(transform(), findsNothing);
  });

  testWidgets('a short line never scrolls', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 300,
            child: LiveMarquee(text: 'Short', style: style),
          ),
        ),
      ),
    );
    expect(transform(), findsNothing);
  });
}

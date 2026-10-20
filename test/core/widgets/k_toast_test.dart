import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carina/core/core.dart';

import '../../support/test_app.dart';

ToastController _controller(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(KToastHost)))
        .read(toastControllerProvider);

void main() {
  testWidgets('a toast shows, then hides after 2.5 s', (tester) async {
    await tester.pumpWidget(carinaTestApp(const SizedBox.expand()));
    _controller(tester).show('Removed from favorites');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Removed from favorites'), findsOneWidget);
    expect(find.byType(KToast), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2000));
    expect(find.text('Removed from favorites'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 300)); // timer fires
    await tester.pumpAndSettle(); // exit animation
    expect(find.text('Removed from favorites'), findsNothing);
    expect(_controller(tester).entries, isEmpty);
  });

  testWidgets('at most three toasts stack; the oldest leaves first', (
    tester,
  ) async {
    await tester.pumpWidget(carinaTestApp(const SizedBox.expand()));
    final c = _controller(tester);
    for (var i = 1; i <= 4; i++) {
      c.show('Toast $i');
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(c.entries.map((e) => e.message), ['Toast 2', 'Toast 3', 'Toast 4']);
    expect(find.text('Toast 1'), findsNothing);
    expect(find.byType(KToast), findsNWidgets(3));
    // Newest on top.
    expect(
      tester.getTopLeft(find.text('Toast 4')).dy,
      lessThan(tester.getTopLeft(find.text('Toast 2')).dy),
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.byType(KToast), findsNothing);
  });

  testWidgets('tapping a toast dismisses it', (tester) async {
    await tester.pumpWidget(carinaTestApp(const SizedBox.expand()));
    _controller(tester).show('Parental control channels updated');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Parental control channels updated'));
    await tester.pumpAndSettle();
    expect(find.byType(KToast), findsNothing);
  });

  testWidgets('banner actions run and dismiss the banner', (tester) async {
    await tester.pumpWidget(carinaTestApp(const SizedBox.expand()));
    var watched = 0;
    _controller(tester).showBanner(
      title: 'Evening Bulletin starts in 5 min',
      message: 'TRT 1 · 7:00 PM',
      actions: [
        KBannerAction(
          label: 'Watch now',
          primary: true,
          onPressed: () => watched++,
        ),
        const KBannerAction(label: 'Dismiss', onPressed: _noop),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.text('Evening Bulletin starts in 5 min'), findsOneWidget);
    // Banners do not auto-hide.
    await tester.pump(const Duration(seconds: 10));
    expect(find.byType(KBanner), findsOneWidget);

    await tester.tap(find.text('Watch now'));
    await tester.pumpAndSettle();
    expect(watched, 1);
    expect(find.byType(KBanner), findsNothing);
  });
}

void _noop() {}

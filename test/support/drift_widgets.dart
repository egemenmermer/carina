import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Helpers for widget tests whose providers watch drift streams.
///
/// Rules that keep these tests from hanging or failing:
/// 1. Create and seed the in-memory database inside `tester.runAsync`.
/// 2. Let DB-backed providers load with [settleDrift] (real async time),
///    not only `pump`.
/// 3. End the test with [unmountAndFlush]: unmounting cancels drift stream
///    queries, which schedules zero-duration timers that must run before the
///    test ends. Do not `close()` the database in tearDown (it would wait on
///    writes scheduled in the fake-async zone); the in-memory database dies
///    with the test process.

/// Pumps frames while giving drift real time to answer queries.
Future<void> settleDrift(WidgetTester tester, {int rounds = 10}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Unmounts the widget tree and flushes drift's stream-cancel timers.
Future<void> unmountAndFlush(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
  await tester.pump(const Duration(milliseconds: 1));
}

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Wall clock for UI that changes per minute (top-bar time, programme
/// progress bars, "ON AIR" markers). Ticks on every minute boundary.
///
/// Tests and capture mode can override [clockSourceProvider] with a fixed
/// time.
final clockSourceProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

final minuteClockProvider = StreamProvider<DateTime>((ref) {
  final now = ref.watch(clockSourceProvider);
  final controller = StreamController<DateTime>();
  Timer? timer;
  void schedule() {
    final t = now();
    controller.add(t);
    final next = DateTime(t.year, t.month, t.day, t.hour, t.minute + 1);
    timer = Timer(next.difference(t), schedule);
  }

  schedule();
  ref.onDispose(() {
    timer?.cancel();
    controller.close();
  });
  return controller.stream;
});

/// Synchronous read of the minute clock with a fallback to `now()`.
DateTime currentMinute(Ref ref) =>
    ref.watch(minuteClockProvider).value ?? ref.read(clockSourceProvider)();

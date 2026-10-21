import 'package:carina/features/reminders/reminders_api.dart';
import 'package:flutter/widgets.dart';

/// Records what the app asks of the OS notification scheduler (Android).
class FakeReminderOs implements ReminderOsScheduler, ReminderSystemNotifier {
  final List<String> calls = [];
  final Map<int, ReminderNotification> pending = {};
  final List<({String title, String body, int? id})> shown = [];
  int permissionRequests = 0;
  bool permission = true;

  @override
  bool get supported => true;

  @override
  Future<void> start() async {}

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return permission;
  }

  @override
  Future<void> schedule(ReminderNotification n) async {
    calls.add('schedule ${n.id}');
    pending[n.id] = n;
  }

  @override
  Future<void> cancel(int id) async {
    calls.add('cancel $id');
    pending.remove(id);
  }

  @override
  Future<void> show({
    required String title,
    required String body,
    int? id,
    VoidCallback? onClick,
  }) async {
    calls.add('show $id');
    shown.add((title: title, body: body, id: id));
  }

  @override
  Stream<int> get taps => const Stream<int>.empty();
}

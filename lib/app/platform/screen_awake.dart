import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Turns the OS "keep the screen on" flag on and off.
abstract interface class WakelockBackend {
  Future<void> enable();
  Future<void> disable();
}

/// [WakelockBackend] over `wakelock_plus` (Android only, see
/// [screenAwakeProvider]). Failures are logged and ignored: a TV that
/// dims during playback is a nuisance, not an error.
class PluginWakelock implements WakelockBackend {
  const PluginWakelock();

  @override
  Future<void> enable() => _guard(() => WakelockPlus.enable());

  @override
  Future<void> disable() => _guard(() => WakelockPlus.disable());

  Future<void> _guard(Future<void> Function() call) async {
    try {
      await call();
    } catch (e) {
      debugPrint('Wakelock failed: $e');
    }
  }
}

/// Keeps the screen awake while at least one owner (a player screen, the
/// multi-channel screen) holds it. Owners are tracked so that closing the
/// player on top of multi-channel does not release the lock under it.
class ScreenAwake {
  ScreenAwake(this._backend);

  final WakelockBackend _backend;
  final Set<Object> _owners = {};

  bool get isHeld => _owners.isNotEmpty;

  /// [owner] wants the screen awake (idempotent).
  void hold(Object owner) {
    if (!_owners.add(owner) || _owners.length > 1) return;
    unawaited(_backend.enable());
  }

  /// [owner] no longer needs it (idempotent).
  void release(Object owner) {
    if (!_owners.remove(owner) || _owners.isNotEmpty) return;
    unawaited(_backend.disable());
  }
}

class _NoWakelock implements WakelockBackend {
  const _NoWakelock();

  @override
  Future<void> enable() async {}

  @override
  Future<void> disable() async {}
}

/// Android only (a TV would go to its screensaver in the middle of a
/// film); desktop behaviour is unchanged. Tests override it with a fake.
final screenAwakeProvider = Provider<ScreenAwake>(
  (ref) => ScreenAwake(
    !kIsWeb && Platform.isAndroid
        ? const PluginWakelock()
        : const _NoWakelock(),
  ),
);

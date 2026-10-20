/// Full-screen control used by the player and multi-channel (injectable so
/// widget tests can check double-click / F / Esc without window_manager).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/window_setup.dart';

abstract class PlayerWindow {
  const PlayerWindow();

  Future<bool> isFullscreen();
  Future<void> toggleFullscreen();
  Future<void> exitFullscreen();
}

/// [WindowControls] (window_manager); no-ops before the window is set up
/// (tests, capture tools).
class AppPlayerWindow extends PlayerWindow {
  const AppPlayerWindow();

  @override
  Future<bool> isFullscreen() => WindowControls.isFullscreen();

  @override
  Future<void> toggleFullscreen() => WindowControls.toggleFullscreen();

  @override
  Future<void> exitFullscreen() => WindowControls.exitFullscreen();
}

final playerWindowProvider = Provider<PlayerWindow>(
  (ref) => const AppPlayerWindow(),
);

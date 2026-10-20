import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../data/settings/settings_store.dart';

const kMinWindowSize = Size(1100, 680);
const kDefaultWindowSize = Size(1440, 900);

/// Frameless dark window: hidden native title bar, our own caption
/// buttons on Windows, native traffic lights on macOS. Restores and persists
/// the window bounds.
class WindowSetup with WindowListener {
  WindowSetup(this._settings);

  final SettingsStore _settings;
  Timer? _saveTimer;
  static bool initialized = false;

  Future<void> init({bool fullscreen = false, Size? forceSize}) async {
    if (!(Platform.isWindows || Platform.isMacOS || Platform.isLinux)) return;
    await windowManager.ensureInitialized();
    initialized = true;
    final saved = forceSize == null
        ? _settings.get(AppSettings.windowBounds)
        : null;
    final w = (saved?['w'] as num?)?.toDouble();
    final h = (saved?['h'] as num?)?.toDouble();
    final size = forceSize ?? (w != null && h != null ? Size(w, h) : null);
    final options = WindowOptions(
      size: size ?? kDefaultWindowSize,
      minimumSize: kMinWindowSize,
      center: saved == null,
      backgroundColor: Colors.black,
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: Platform.isMacOS,
      title: 'Carina',
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      final x = (saved?['x'] as num?)?.toDouble();
      final y = (saved?['y'] as num?)?.toDouble();
      if (x != null && y != null && forceSize == null) {
        await windowManager.setPosition(Offset(x, y));
      }
      await windowManager.show();
      await windowManager.focus();
      if (saved?['maximized'] == true && forceSize == null) {
        await windowManager.maximize();
      }
      if (fullscreen) await windowManager.setFullScreen(true);
    });
    windowManager.addListener(this);
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), () async {
      if (await windowManager.isFullScreen()) return;
      final maximized = await windowManager.isMaximized();
      final bounds = await windowManager.getBounds();
      final previous = _settings.get(AppSettings.windowBounds);
      await _settings.set(AppSettings.windowBounds, <String, Object?>{
        // Keep the restored size while maximized.
        'x': maximized ? (previous?['x'] ?? bounds.left) : bounds.left,
        'y': maximized ? (previous?['y'] ?? bounds.top) : bounds.top,
        'w': maximized ? (previous?['w'] ?? bounds.width) : bounds.width,
        'h': maximized ? (previous?['h'] ?? bounds.height) : bounds.height,
        'maximized': maximized,
      });
    });
  }

  @override
  void onWindowResized() => _scheduleSave();

  @override
  void onWindowMoved() => _scheduleSave();

  @override
  void onWindowMaximize() => _scheduleSave();

  @override
  void onWindowUnmaximize() => _scheduleSave();
}

/// F11 / double-click helpers used by the shell and the player.
abstract final class WindowControls {
  static Future<void> toggleFullscreen() async {
    if (!WindowSetup.initialized) return;
    final full = await windowManager.isFullScreen();
    await windowManager.setFullScreen(!full);
  }

  static Future<bool> isFullscreen() async =>
      WindowSetup.initialized && await windowManager.isFullScreen();

  static Future<void> exitFullscreen() async {
    if (await isFullscreen()) await windowManager.setFullScreen(false);
  }

  static Future<void> toggleMaximize() async {
    if (!WindowSetup.initialized) return;
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }
}

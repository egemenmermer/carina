import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

/// Window actions used by the custom title bar ([KTopNav] drag area,
/// [KCaptionButtons]).
///
/// Injectable so widget tests and screenshot captures never touch the
/// window_manager plugin: [of] returns the controls from the nearest
/// [KWindowControlsScope], otherwise [platformDefault] — a
/// [WindowManagerControls] on desktop, and null under `flutter test`
/// (FLUTTER_TEST is set) or on other platforms. With null controls the
/// title bar simply does not drag.
abstract class KWindowControls {
  const KWindowControls();

  /// Starts a native window move (call from a pan-start).
  Future<void> startDragging();

  Future<void> minimize();

  /// Maximizes, or restores when already maximized.
  Future<void> toggleMaximize();

  Future<void> close();

  /// Whether the window is maximized (drives the restore glyph).
  ValueListenable<bool> get isMaximized;

  /// Controls in scope for [context] (see class docs).
  static KWindowControls? of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<KWindowControlsScope>();
    if (scope != null) return scope.controls;
    return platformDefault;
  }

  static KWindowControls? _default;

  /// window_manager-backed controls on a desktop app; null in tests.
  static KWindowControls? get platformDefault {
    if (kIsWeb) return null;
    if (Platform.environment.containsKey('FLUTTER_TEST')) return null;
    if (!(Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      return null;
    }
    return _default ??= WindowManagerControls();
  }
}

/// Provides (or, with null, disables) [KWindowControls] for a subtree.
class KWindowControlsScope extends InheritedWidget {
  const KWindowControlsScope({
    super.key,
    required this.controls,
    required super.child,
  });

  final KWindowControls? controls;

  @override
  bool updateShouldNotify(KWindowControlsScope oldWidget) =>
      oldWidget.controls != controls;
}

/// [KWindowControls] backed by window_manager. Every call is guarded, so a
/// missing plugin (e.g. before `windowManager.ensureInitialized()`) only
/// logs instead of throwing.
class WindowManagerControls extends KWindowControls with WindowListener {
  WindowManagerControls();

  final ValueNotifier<bool> _maximized = ValueNotifier<bool>(false);
  bool _listening = false;

  @override
  ValueListenable<bool> get isMaximized {
    _listen();
    return _maximized;
  }

  void _listen() {
    if (_listening) return;
    _listening = true;
    _guard(() async {
      windowManager.addListener(this);
      _maximized.value = await windowManager.isMaximized();
    });
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      debugPrint('KWindowControls: $error');
    }
  }

  @override
  Future<void> startDragging() => _guard(windowManager.startDragging);

  @override
  Future<void> minimize() => _guard(windowManager.minimize);

  @override
  Future<void> toggleMaximize() => _guard(() async {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  });

  @override
  Future<void> close() => _guard(windowManager.close);

  @override
  void onWindowMaximize() => _maximized.value = true;

  @override
  void onWindowUnmaximize() => _maximized.value = false;

  @override
  void onWindowRestore() => _guard(() async {
    _maximized.value = await windowManager.isMaximized();
  });
}

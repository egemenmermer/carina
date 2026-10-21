import 'package:flutter/widgets.dart';

/// Whether the subtree runs on a TV with a D-pad remote.
///
/// The app installs it from its form factor (`lib/app/app.dart`); core
/// widgets read it to switch to remote behavior: OK held opens the context
/// menu ([KInteractive]), text fields open the keyboard only on OK
/// ([KTextField]). Absent means desktop.
class KTvMode extends InheritedWidget {
  const KTvMode({super.key, required this.enabled, required super.child});

  /// TV behavior is on.
  final bool enabled;

  /// Whether the nearest [KTvMode] above [context] is on (false when none).
  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<KTvMode>()?.enabled ?? false;

  /// Like [of], without registering a dependency (event handlers).
  static bool read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<KTvMode>()?.enabled ?? false;

  @override
  bool updateShouldNotify(KTvMode oldWidget) => enabled != oldWidget.enabled;
}

/// Whether [node] is an element the user can see focused: a mounted,
/// traversable node, not a scope or a key-routing wrapper (those set
/// `skipTraversal` or `canRequestFocus: false`).
bool kIsVisibleFocusTarget(FocusNode? node) =>
    node != null &&
    node is! FocusScopeNode &&
    node.context != null &&
    node.canRequestFocus &&
    !node.skipTraversal;

/// The first visible focus target under [root] in reading order (top to
/// bottom, then left to right), or null.
FocusNode? kFirstFocusTarget(FocusNode root) {
  FocusNode? best;
  Rect? bestRect;
  for (final node in root.traversalDescendants) {
    if (!kIsVisibleFocusTarget(node)) continue;
    final rect = node.rect;
    if (rect.isEmpty) continue;
    if (best == null ||
        rect.top < bestRect!.top - 1 ||
        ((rect.top - bestRect.top).abs() <= 1 && rect.left < bestRect.left)) {
      best = node;
      bestRect = rect;
    }
  }
  return best;
}

/// Focuses [kFirstFocusTarget] of [root]; returns whether a target existed.
bool kFocusFirstIn(FocusNode root) {
  final target = kFirstFocusTarget(root);
  target?.requestFocus();
  return target != null;
}

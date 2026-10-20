import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Wraps a text field that lives inside the playlist shell so keys typed
/// into it reach the text input instead of the shell's single-key
/// shortcuts: the shell maps "/" to "open search", which would otherwise
/// swallow the character. Optionally reports ↓ (leave the field for the
/// content below).
class ShellSafeTextInput extends StatelessWidget {
  const ShellSafeTextInput({super.key, required this.child, this.onArrowDown});

  final Widget child;

  /// Called on ↓ while the field has focus (the key is consumed).
  final VoidCallback? onArrowDown;

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.slash ||
        key == LogicalKeyboardKey.numpadDivide) {
      // Not handled by the framework (the platform types the character),
      // but no ancestor shortcut sees it either.
      return KeyEventResult.skipRemainingHandlers;
    }
    final down = onArrowDown;
    if (down != null && key == LogicalKeyboardKey.arrowDown) {
      down();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: child,
    );
  }
}

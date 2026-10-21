import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:carina/core/tokens.dart';
import 'package:carina/core/widgets/k_tv.dart';

/// Called with the global pointer position where a context menu should open
/// (right-click, long-press, or the widget's center for Menu / Shift+F10).
typedef KContextMenuCallback = void Function(Offset globalPosition);

/// The visual state of an interactive element, passed to
/// [KInteractive.builder].
@immutable
class KInteractionState {
  const KInteractionState({
    this.hovered = false,
    this.focused = false,
    this.pressed = false,
    this.enabled = true,
    this.selected = false,
  });

  /// The mouse is over the element.
  final bool hovered;

  /// The element has keyboard focus and focus highlights are showing
  /// (keyboard or mouse input, not touch).
  final bool focused;

  /// A pointer is down on the element.
  final bool pressed;

  /// The element reacts to input.
  final bool enabled;

  /// The element is the selected one in its group (caller-defined).
  final bool selected;

  /// Hovered or focused — the tvOS "focus" treatment applies.
  bool get highlighted => enabled && (hovered || focused);
}

/// Builds an element for a given [KInteractionState].
typedef KInteractiveBuilder = Widget Function(
  BuildContext context,
  KInteractionState state,
  Widget? child,
);

/// Intent that opens an element's context menu from the keyboard
/// (Menu key or Shift+F10).
class KContextMenuIntent extends Intent {
  const KContextMenuIntent();
}

/// The single interaction primitive behind every core control.
///
/// Provides hover, keyboard focus and pressed states, the click mouse cursor,
/// Enter / Space activation, and context-menu entry points: secondary click
/// and long-press report the pointer position; the Menu key and Shift+F10
/// report the element's center. Clicking an element also focuses it (tvOS
/// behavior), so keyboard navigation continues from there.
///
/// Under [KTvMode] the remote's OK (Enter / Select) fires once per press,
/// never on key repeat. When the element has a context menu, OK fires on
/// release instead, and holding it for [tvMenuHold] (or until the remote
/// starts repeating) opens the menu without the tap.
///
/// Use it directly to build custom interactive pieces (EPG cells, rows):
///
/// ```dart
/// KInteractive(
///   onTap: play,
///   onContextMenu: (pos) => showKContextMenu(context, position: pos, entries: …),
///   builder: (context, state, _) => Container(
///     color: state.highlighted ? KColors.accentCrimson: KColors.surface3,
///  ),
/// )
/// ```
class KInteractive extends StatefulWidget {
  const KInteractive({
    super.key,
    required this.builder,
    this.child,
    this.onTap,
    this.onDoubleTap,
    this.onContextMenu,
    this.onHoverChange,
    this.onFocusChange,
    this.focusNode,
    this.autofocus = false,
    this.enabled = true,
    this.focusable = true,
    this.focusOnTap = true,
    this.selected = false,
    this.mouseCursor,
    this.semanticLabel,
    this.isButton = true,
  });

  /// Builds the element for the current state. [child] is passed through.
  final KInteractiveBuilder builder;

  /// Optional subtree that does not depend on the state.
  final Widget? child;

  /// Primary activation (click, Enter, Space).
  final VoidCallback? onTap;

  /// Double click. Only set it when needed: it delays single taps.
  final VoidCallback? onDoubleTap;

  /// Context menu request with a global position.
  final KContextMenuCallback? onContextMenu;

  /// Called when the hover highlight changes.
  final ValueChanged<bool>? onHoverChange;

  /// Called when keyboard focus enters or leaves the element.
  final ValueChanged<bool>? onFocusChange;

  /// Optional external focus node.
  final FocusNode? focusNode;

  /// Request focus when first built.
  final bool autofocus;

  /// When false the element ignores input and reports a disabled state.
  final bool enabled;

  /// When false the element never takes keyboard focus (it still hovers).
  final bool focusable;

  /// Whether a click moves keyboard focus to the element.
  final bool focusOnTap;

  /// Forwarded to [KInteractionState.selected] and semantics.
  final bool selected;

  /// Cursor over an interactive element; defaults to the click cursor.
  final MouseCursor? mouseCursor;

  /// Accessibility label.
  final String? semanticLabel;

  /// Whether to report the element as a button to accessibility services.
  final bool isButton;

  /// How long OK must be held on a TV remote to open the context menu.
  static const Duration tvMenuHold = Duration(milliseconds: 500);

  @override
  State<KInteractive> createState() => _KInteractiveState();
}

class _KInteractiveState extends State<KInteractive> {
  static const _shortcuts = <ShortcutActivator, Intent>{
    SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
    SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
    SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
    SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
    SingleActivator(LogicalKeyboardKey.contextMenu): KContextMenuIntent(),
    SingleActivator(LogicalKeyboardKey.f10, shift: true): KContextMenuIntent(),
  };

  /// On TV the OK keys are handled by [_onTvKey] (press, hold, release).
  static const _tvShortcuts = <ShortcutActivator, Intent>{
    SingleActivator(LogicalKeyboardKey.space, includeRepeats: false):
        ActivateIntent(),
    SingleActivator(LogicalKeyboardKey.contextMenu): KContextMenuIntent(),
    SingleActivator(LogicalKeyboardKey.f10, shift: true): KContextMenuIntent(),
  };

  static bool _isOk(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.enter ||
      key == LogicalKeyboardKey.numpadEnter ||
      key == LogicalKeyboardKey.select;

  FocusNode? _internalNode;
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  /// Running while OK is held on an element with a menu (TV).
  Timer? _holdTimer;

  FocusNode get _focusNode =>
      widget.focusNode ??
      (_internalNode ??= FocusNode(debugLabel: 'KInteractive'));

  bool get _hasPrimary => widget.enabled && widget.onTap != null;

  bool get _hasMenu => widget.enabled && widget.onContextMenu != null;

  bool get _isInteractive =>
      _hasPrimary || _hasMenu || (widget.enabled && widget.onDoubleTap != null);

  @override
  void didUpdateWidget(KInteractive oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && (_hovered || _pressed || _focused)) {
      _hovered = false;
      _pressed = false;
      _focused = false;
    }
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _internalNode?.dispose();
    super.dispose();
  }

  void _cancelHold() {
    _holdTimer?.cancel();
    _holdTimer = null;
    _setPressed(false);
  }

  /// The remote's OK on TV: one tap per press; with a menu, tap on release
  /// and open the menu once OK is held (timer or first key repeat).
  KeyEventResult _onTvKey(FocusNode node, KeyEvent event) {
    if (!_isOk(event.logicalKey)) return KeyEventResult.ignored;
    if (!widget.enabled || !_focusNode.hasPrimaryFocus) {
      return KeyEventResult.ignored;
    }
    if (!_hasPrimary && !_hasMenu) return KeyEventResult.ignored;
    switch (event) {
      case KeyDownEvent():
        _cancelHold();
        if (!_hasMenu) {
          widget.onTap?.call();
          return KeyEventResult.handled;
        }
        _setPressed(true);
        _holdTimer = Timer(KInteractive.tvMenuHold, _openMenuFromHold);
      case KeyRepeatEvent():
        if (_holdTimer != null) _openMenuFromHold();
      case KeyUpEvent():
        if (_holdTimer != null) {
          _cancelHold();
          widget.onTap?.call();
        }
    }
    // Repeats and releases of a press that began elsewhere are swallowed
    // too, so they never reach the app-level Enter → ActivateIntent.
    return KeyEventResult.handled;
  }

  void _openMenuFromHold() {
    if (_holdTimer == null || !mounted) return;
    _cancelHold();
    _openMenuAtCenter();
  }

  void _onFocusChange(bool focused) {
    if (!focused) _cancelHold();
    widget.onFocusChange?.call(focused);
  }

  void _setPressed(bool value) {
    if (_pressed == value || !mounted) return;
    setState(() => _pressed = value);
  }

  void _setHovered(bool value) {
    if (_hovered == value) return;
    setState(() => _hovered = value);
    widget.onHoverChange?.call(value);
  }

  void _setFocusHighlight(bool value) {
    if (_focused == value) return;
    setState(() => _focused = value);
  }

  void _handleTap() {
    if (widget.focusOnTap && widget.focusable && _focusNode.canRequestFocus) {
      _focusNode.requestFocus();
    }
    widget.onTap?.call();
  }

  /// The element a context menu acts on becomes the focused one, so focus
  /// returns to it when the menu closes.
  void _focusForMenu() {
    if (widget.focusOnTap && widget.focusable && _focusNode.canRequestFocus) {
      _focusNode.requestFocus();
    }
  }

  void _openMenuAtCenter() {
    final callback = widget.onContextMenu;
    if (callback == null || !widget.enabled) return;
    final box = context.findRenderObject();
    if (box is RenderBox && box.hasSize) {
      callback(box.localToGlobal(box.size.center(Offset.zero)));
    }
  }

  Map<Type, Action<Intent>> _actions() => {
    if (_hasPrimary) ...{
      ActivateIntent: CallbackAction<ActivateIntent>(
        onInvoke: (_) {
          widget.onTap?.call();
          return null;
        },
      ),
      ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
        onInvoke: (_) {
          widget.onTap?.call();
          return null;
        },
      ),
    },
    if (_hasMenu)
      KContextMenuIntent: CallbackAction<KContextMenuIntent>(
        onInvoke: (_) {
          _openMenuAtCenter();
          return null;
        },
      ),
  };

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    final state = KInteractionState(
      hovered: enabled && _hovered,
      focused: enabled && _focused,
      pressed: enabled && _pressed,
      enabled: enabled,
      selected: widget.selected,
    );
    Widget result = widget.builder(context, state, widget.child);

    result = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _hasPrimary ? (_) => _setPressed(true) : null,
      onTapUp: _hasPrimary ? (_) => _setPressed(false) : null,
      onTapCancel: _hasPrimary ? () => _setPressed(false) : null,
      onTap: _hasPrimary ? _handleTap : null,
      onDoubleTap: enabled ? widget.onDoubleTap : null,
      onSecondaryTapUp: _hasMenu
          ? (details) {
              _focusForMenu();
              widget.onContextMenu!(details.globalPosition);
            }
          : null,
      onLongPressStart: _hasMenu
          ? (details) {
              _setPressed(false);
              _focusForMenu();
              widget.onContextMenu!(details.globalPosition);
            }
          : null,
      child: result,
    );

    final cursor = _isInteractive
        ? (widget.mouseCursor ?? SystemMouseCursors.click)
        : MouseCursor.defer;

    // Hover comes straight from the mouse (FocusableActionDetector would hide
    // it while the focus highlight mode is "touch"); the focus highlight
    // follows Flutter's keyboard/touch highlight mode.
    result = MouseRegion(
      cursor: cursor,
      onEnter: enabled ? (_) => _setHovered(true) : null,
      onExit: (_) => _setHovered(false),
      child: result,
    );

    if (widget.focusable) {
      final tv = KTvMode.of(context);
      result = FocusableActionDetector(
        focusNode: _focusNode,
        autofocus: widget.autofocus,
        enabled: enabled,
        shortcuts: tv ? _tvShortcuts : _shortcuts,
        actions: _actions(),
        onShowFocusHighlight: _setFocusHighlight,
        onFocusChange: tv ? _onFocusChange : widget.onFocusChange,
        child: result,
      );
      if (tv) {
        // An ancestor of the detector's node, so it sees OK after the
        // detector's shortcuts (which no longer bind it) pass.
        result = Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onKeyEvent: _onTvKey,
          child: result,
        );
      }
    }

    return Semantics(
      container: true,
      button: widget.isButton && widget.onTap != null,
      enabled: enabled,
      selected: widget.selected,
      label: widget.semanticLabel,
      child: result,
    );
  }
}

/// Paints a focus ring around [child] (outside its bounds) and fades it in
/// and out. Used by buttons whose own fill is white or red, where the
/// card-style inner border would be invisible. Under [KTvMode] the ring is
/// at least 3 px, readable from the couch.
class KFocusRing extends StatelessWidget {
  const KFocusRing({
    super.key,
    required this.visible,
    required this.child,
    this.borderRadius = KRadii.button,
    this.gap = 3,
    this.width = 2,
    this.color = KColors.focusRing,
    this.circle = false,
  });

  /// Whether the ring shows.
  final bool visible;

  /// The decorated element.
  final Widget child;

  /// Corner radius of [child]; the ring adds [gap].
  final double borderRadius;

  /// Space between [child] and the ring.
  final double gap;

  /// Ring stroke width.
  final double width;

  /// Ring color.
  final Color color;

  /// Draw a circle instead of a rounded rectangle.
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final width = KTvMode.of(context) && this.width < 3 ? 3.0 : this.width;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: visible ? 1 : 0),
      duration: KMotion.of(context, KDurations.hover),
      curve: KMotion.hover,
      child: child,
      builder: (context, t, child) => CustomPaint(
        foregroundPainter: t == 0
            ? null
            : _RingPainter(
                color: color.withValues(alpha: color.a * t),
                radius: borderRadius,
                gap: gap,
                width: width,
                circle: circle,
              ),
        child: child,
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.color,
    required this.radius,
    required this.gap,
    required this.width,
    required this.circle,
  });

  final Color color;
  final double radius;
  final double gap;
  final double width;
  final bool circle;

  @override
  void paint(Canvas canvas, Size size) {
    final inflate = gap + width / 2;
    final rect = (Offset.zero & size).inflate(inflate);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    if (circle) {
      canvas.drawOval(rect, paint);
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(radius + inflate)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.radius != radius ||
      oldDelegate.gap != gap ||
      oldDelegate.width != width ||
      oldDelegate.circle != circle;
}

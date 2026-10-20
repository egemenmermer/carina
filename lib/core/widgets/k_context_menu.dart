import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:carina/core/icons/phosphor_icons.dart';

import 'package:carina/core/tokens.dart';
import 'package:carina/core/widgets/k_buttons.dart';
import 'package:carina/core/widgets/k_popup.dart';

/// Where context-menu rows show their icon.
enum KMenuIconPosition {
  /// Icon before the label (Playlist Manager menu in the tutorials).
  leading,

  /// Icon at the right end.
  trailing,
}

/// One row of a context menu, or a group separator.
@immutable
class KMenuEntry<T> {
  const KMenuEntry({
    required this.label,
    this.value,
    this.icon,
    this.destructive = false,
    this.enabled = true,
    this.checked = false,
    this.onSelected,
  }) : isSeparator = false;

  /// A thicker gap between groups of rows.
  const KMenuEntry.separator()
    : label = '',
      value = null,
      icon = null,
      destructive = false,
      enabled = false,
      checked = false,
      onSelected = null,
      isSeparator = true;

  /// Row text (wraps to two lines).
  final String label;

  /// Returned by [showKContextMenu] when the row is chosen.
  final T? value;

  /// Icon at the right end of the row (iPad style).
  final IconData? icon;

  /// Red text and icon (Remove, Delete).
  final bool destructive;

  /// Disabled rows are dimmed and skipped by keyboard navigation.
  final bool enabled;

  /// Shows a check mark at the right end (replaces [icon]).
  final bool checked;

  /// Called after the menu has closed when this row was chosen.
  final VoidCallback? onSelected;

  /// Whether this entry is a group separator.
  final bool isSeparator;

  bool get _selectable => !isSeparator && enabled;
}

/// Opens an iPad-style context menu at [position] (global coordinates) and
/// returns the chosen entry's [KMenuEntry.value], or null when dismissed.
///
/// Frosted material (blur 30, [KColors.material] at 85%, 1 px rim, soft
/// shadow), radius 18, 140 ms scale/fade. Rows: label left, icon right (or
/// left with [iconPosition]), thin separators ([separators]), destructive
/// rows in red, disabled rows dimmed, optional grey [title] header. The
/// hovered / keyboard-highlighted row is a white pill with black text (the
/// tvOS/Mac focus look). Up/Down/Home/End move the highlight,
/// Enter/Space choose, Esc or an outside click closes. The menu flips or
/// slides to stay inside the window.
///
/// ```dart
/// onContextMenu: (pos) async {
///   final action = await showKContextMenu<ChannelAction>(
///     context,
///     position: pos,
///     entries: [
///       KMenuEntry(label: l10n.liveAddToFavorites, icon: PhosphorIconsLight.star, value: ChannelAction.favorite),
///       const KMenuEntry.separator(),
///       KMenuEntry(label: l10n.liveHideChannel, icon: PhosphorIconsLight.eyeSlash, value: ChannelAction.hide),
///     ],
///  );
/// }
/// ```
Future<T?> showKContextMenu<T>(
  BuildContext context, {
  required Offset position,
  String? title,
  required List<KMenuEntry<T>> entries,
  double width = 300,
  KMenuIconPosition iconPosition = KMenuIconPosition.trailing,
  bool separators = true,
}) async {
  final chosen = await showKPopup<KMenuEntry<T>>(
    context,
    position: position,
    placement: KPopupPlacement.atPoint,
    builder: (context) => KContextMenu<T>(
      title: title,
      entries: entries,
      width: width,
      iconPosition: iconPosition,
      separators: separators,
      onSelected: (entry) => Navigator.of(context).pop(entry),
    ),
  );
  chosen?.onSelected?.call();
  return chosen?.value;
}

/// The context menu panel (without a route). Use [showKContextMenu] unless
/// you embed the menu in your own overlay.
class KContextMenu<T> extends StatefulWidget {
  const KContextMenu({
    super.key,
    required this.entries,
    required this.onSelected,
    this.title,
    this.width = 300,
    this.autofocus = true,
    this.onDismiss,
    this.iconPosition = KMenuIconPosition.trailing,
    this.separators = true,
  });

  final List<KMenuEntry<T>> entries;
  final ValueChanged<KMenuEntry<T>> onSelected;
  final String? title;
  final double width;
  final bool autofocus;
  final KMenuIconPosition iconPosition;

  /// Thin lines between rows (iPad style). Group separators always show.
  final bool separators;

  /// Called on Esc; defaults to popping the current route.
  final VoidCallback? onDismiss;

  @override
  State<KContextMenu<T>> createState() => _KContextMenuState<T>();
}

class _KContextMenuState<T> extends State<KContextMenu<T>> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'KContextMenu');
  final ScrollController _scroll = ScrollController();
  late List<GlobalKey> _rowKeys = _keys();
  int _highlight = -1;

  List<GlobalKey> _keys() =>
      List.generate(widget.entries.length, (_) => GlobalKey());

  @override
  void didUpdateWidget(KContextMenu<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entries.length != widget.entries.length) {
      _rowKeys = _keys();
      _highlight = -1;
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _move(int direction) {
    final entries = widget.entries;
    if (entries.every((e) => !e._selectable)) return;
    // Nothing highlighted yet: Down starts at the top, Up at the bottom.
    var i = _highlight >= 0
        ? _highlight
        : (direction > 0 ? -1 : entries.length);
    for (var step = 0; step < entries.length; step++) {
      i = (i + direction) % entries.length; // Dart's % is never negative.
      if (entries[i]._selectable) break;
    }
    setState(() => _highlight = i);
    final ctx = _rowKeys[i].currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
      Scrollable.ensureVisible(
        ctx,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      );
    }
  }

  void _jump(bool toEnd) {
    final entries = widget.entries;
    final indices = [
      for (var i = 0; i < entries.length; i++)
        if (entries[i]._selectable) i,
    ];
    if (indices.isEmpty) return;
    setState(() => _highlight = toEnd ? indices.last : indices.first);
  }

  void _choose(int index) {
    final entry = widget.entries[index];
    if (!entry._selectable) return;
    widget.onSelected(entry);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.tab) {
      _move(
        HardwareKeyboard.instance.isShiftPressed &&
                key == LogicalKeyboardKey.tab
            ? -1
            : 1,
      );
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _move(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.home) {
      _jump(false);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.end) {
      _jump(true);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.select) {
      if (_highlight >= 0) _choose(_highlight);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      final dismiss = widget.onDismiss;
      if (dismiss != null) {
        dismiss();
      } else {
        Navigator.of(context).maybePop();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.entries;
    final rows = <Widget>[];
    if (widget.title != null) {
      rows.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 13, 18, 11),
          child: Text(
            widget.title!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: KText.label.copyWith(fontSize: 13),
          ),
        ),
      );
    }
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      if (entry.isSeparator) {
        rows.add(Container(height: 7, color: const Color(0x4D000000)));
        continue;
      }
      final previousIsSeparator = i > 0 && entries[i - 1].isSeparator;
      if (widget.separators && rows.isNotEmpty && !previousIsSeparator) {
        rows.add(
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            color: KColors.separator,
          ),
        );
      }
      rows.add(
        _MenuRow(
          key: _rowKeys[i],
          entry: entry,
          iconPosition: widget.iconPosition,
          highlighted: _highlight == i,
          onHover: (inside) {
            if (inside && entry._selectable) {
              setState(() => _highlight = i);
            } else if (!inside && _highlight == i) {
              setState(() => _highlight = -1);
            }
          },
          onTap: () => _choose(i),
        ),
      );
    }
    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      onKeyEvent: _onKey,
      child: Semantics(
        scopesRoute: true,
        explicitChildNodes: true,
        child: KFrostedPanel(
          width: widget.width,
          borderRadius: KRadii.contextMenu,
          child: Material(
            type: MaterialType.transparency,
            child: SingleChildScrollView(
              controller: _scroll,
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: rows,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    super.key,
    required this.entry,
    required this.iconPosition,
    required this.highlighted,
    required this.onHover,
    required this.onTap,
  });

  final KMenuEntry<Object?> entry;
  final KMenuIconPosition iconPosition;
  final bool highlighted;
  final ValueChanged<bool> onHover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = entry.enabled;
    final pill = highlighted && enabled;
    final color = entry.destructive
        ? (pill ? KColors.accent : KButton.destructiveForeground)
        : (pill ? Colors.black : KColors.textPrimary);
    final icon = entry.checked ? PhosphorIconsBold.check : entry.icon;
    final iconWidget = icon == null
        ? null
        : SizedBox(width: 24, child: Icon(icon, size: 21, color: color));
    final leading = iconPosition == KMenuIconPosition.leading;
    Widget row = AnimatedContainer(
      duration: KMotion.of(context, const Duration(milliseconds: 90)),
      curve: KMotion.hover,
      constraints: const BoxConstraints(minHeight: 42),
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      padding: const EdgeInsets.fromLTRB(14, 9, 12, 9),
      decoration: BoxDecoration(
        color: pill ? KColors.focusRing : const Color(0x00F5F5F5),
        borderRadius: BorderRadius.circular(21),
      ),
      child: Row(
        children: [
          if (leading && iconWidget != null) ...[
            iconWidget,
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              entry.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: KText.menu.copyWith(color: color, height: 1.25),
            ),
          ),
          if (!leading && iconWidget != null) ...[
            const SizedBox(width: 14),
            iconWidget,
          ],
        ],
      ),
    );
    if (!enabled) row = Opacity(opacity: 0.35, child: row);
    return Semantics(
      button: true,
      enabled: enabled,
      label: entry.label,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: (_) => onHover(true),
        onExit: (_) => onHover(false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? onTap : null,
          child: row,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:carina/core/core.dart';

/// One button of [showPlaylistDialog].
@immutable
class PlaylistDialogAction<T> {
  const PlaylistDialogAction({
    required this.label,
    required this.value,
    this.destructive = false,
  });

  final String label;
  final T value;

  /// Red text; a red pill when highlighted.
  final bool destructive;
}

/// alert (tvOS/Mac "M3U import errors"): a small frosted
/// panel with a bold title, the message, an optional grey [note] and the
/// [actions] as stacked pills. The action at [autofocusIndex] has the
/// focus; the highlighted pill is white with black text. Esc or a click outside
/// returns null.
Future<T?> showPlaylistDialog<T>(
  BuildContext context, {
  required String title,
  String? message,
  String? note,
  IconData? icon,
  Color iconColor = KColors.textPrimary,
  required List<PlaylistDialogAction<T>> actions,
  int autofocusIndex = 0,
  double width = 420,
  bool barrierDismissible = true,
}) {
  return showKPopup<T>(
    context,
    placement: KPopupPlacement.center,
    barrierColor: const Color(0x99000000),
    barrierDismissible: barrierDismissible,
    margin: 24,
    builder: (context) => PlaylistDialog<T>(
      title: title,
      message: message,
      note: note,
      icon: icon,
      iconColor: iconColor,
      actions: actions,
      autofocusIndex: autofocusIndex,
      width: width,
      onSelected: (value) => Navigator.of(context).pop(value),
      onDismiss: barrierDismissible
          ? () => Navigator.of(context).maybePop()
          : null,
    ),
  );
}

/// The panel behind [showPlaylistDialog] (public for screenshots/tests).
class PlaylistDialog<T> extends StatelessWidget {
  const PlaylistDialog({
    super.key,
    required this.title,
    required this.actions,
    required this.onSelected,
    this.message,
    this.note,
    this.icon,
    this.iconColor = KColors.textPrimary,
    this.autofocusIndex = 0,
    this.width = 420,
    this.onDismiss,
  });

  final String title;
  final String? message;
  final String? note;
  final IconData? icon;
  final Color iconColor;
  final List<PlaylistDialogAction<T>> actions;

  /// The action that has the focus when the dialog opens (e.g. Cancel in a
  /// destructive confirmation).
  final int autofocusIndex;
  final double width;
  final ValueChanged<T> onSelected;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): ?onDismiss},
      child: FocusScope(
        autofocus: true,
        child: Semantics(
          scopesRoute: true,
          namesRoute: true,
          explicitChildNodes: true,
          label: title,
          child: KFrostedPanel(
            width: width,
            borderRadius: KRadii.sheet,
            child: Material(
              type: MaterialType.transparency,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (icon != null) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Icon(icon, size: 30, color: iconColor),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text(title, style: KText.title),
                    if (message != null) ...[
                      const SizedBox(height: 8),
                      Text(message!, style: KText.bodySecondary),
                    ],
                    if (note != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        note!,
                        style: KText.caption.copyWith(
                          color: KColors.textTertiary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    for (var i = 0; i < actions.length; i++)
                      Padding(
                        padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
                        child: DialogPill(
                          label: actions[i].label,
                          destructive: actions[i].destructive,
                          autofocus: i == autofocusIndex,
                          onTap: () => onSelected(actions[i].value),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Stacked pill button of dialogs and the wizard's source step: dark grey
/// at rest, white with black text when hovered or focused; destructive
/// pills have red text and turn into a red pill.
class DialogPill extends StatelessWidget {
  const DialogPill({
    super.key,
    required this.label,
    required this.onTap,
    this.destructive = false,
    this.autofocus = false,
    this.height = 44,
    this.textStyle,
    this.focusNode,
    this.selected = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool destructive;
  final bool autofocus;
  final double height;
  final TextStyle? textStyle;
  final FocusNode? focusNode;

  /// Keep the white "current choice" look without hover or focus.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final base = textStyle ?? KText.button;
    return KInteractive(
      onTap: onTap,
      enabled: onTap != null,
      autofocus: autofocus,
      focusNode: focusNode,
      selected: selected,
      semanticLabel: label,
      builder: (context, state, _) {
        final lit = state.highlighted || selected;
        final Color fill;
        final Color fg;
        if (destructive) {
          fill = lit
              ? (state.pressed ? KColors.accentPressed : KColors.accent)
              : const Color(0xFF2A2A2C);
          fg = lit ? Colors.white : KButton.destructiveForeground;
        } else {
          fill = lit
              ? (state.pressed ? const Color(0xFFDADADA) : KColors.focusRing)
              : (state.pressed
                    ? const Color(0xFF333336)
                    : const Color(0xFF2A2A2C));
          fg = lit ? Colors.black : KColors.textPrimary;
        }
        final duration = KMotion.of(context, const Duration(milliseconds: 90));
        Widget pill = AnimatedContainer(
          duration: duration,
          curve: KMotion.hover,
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: KRadii.pillBorder,
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: base.copyWith(color: fg),
          ),
        );
        if (!state.enabled) pill = Opacity(opacity: 0.4, child: pill);
        return AnimatedScale(
          scale: state.pressed ? 0.98 : 1,
          duration: duration,
          child: pill,
        );
      },
    );
  }
}

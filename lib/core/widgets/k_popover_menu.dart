import 'package:flutter/material.dart';
import 'package:carina/core/text_case.dart';
import 'package:flutter/services.dart';
import 'package:carina/core/icons/phosphor_icons.dart';

import 'package:carina/core/strings.dart';
import 'package:carina/core/tokens.dart';
import 'package:carina/core/widgets/k_buttons.dart';
import 'package:carina/core/widgets/k_interactive.dart';
import 'package:carina/core/widgets/k_popup.dart';

enum _PopoverItemKind { check, action, stepper }

/// A row of a [KPopoverMenu].
@immutable
class KPopoverItem {
  /// Selectable row with a ✓ when [checked] (tracks, player engines,
  /// aspect modes).
  const KPopoverItem.check({
    required this.label,
    required bool this.checked,
    this.detail,
    this.onTap,
    this.enabled = true,
    this.closeOnTap = true,
  }) : _kind = _PopoverItemKind.check,
       icon = null,
       destructive = false,
       valueText = null,
       onDecrement = null,
       onIncrement = null;

  /// Plain action row with an optional icon at the right
  /// ("Load from file…").
  const KPopoverItem.action({
    required this.label,
    this.icon,
    this.detail,
    this.onTap,
    this.enabled = true,
    this.destructive = false,
    this.closeOnTap = true,
  }) : _kind = _PopoverItemKind.action,
       checked = null,
       valueText = null,
       onDecrement = null,
       onIncrement = null;

  /// Stepper row: "Audio delay   −  +0.3 s  +". Left/Right arrows step
  /// while the row is focused. Never closes the popover.
  const KPopoverItem.stepper({
    required this.label,
    required String this.valueText,
    this.onDecrement,
    this.onIncrement,
    this.onTap,
    this.enabled = true,
  }) : _kind = _PopoverItemKind.stepper,
       checked = null,
       icon = null,
       detail = null,
       destructive = false,
       closeOnTap = false;

  final _PopoverItemKind _kind;
  final String label;

  /// Secondary text at the right (check/action rows).
  final String? detail;
  final bool? checked;
  final IconData? icon;
  final bool destructive;
  final String? valueText;

  /// Row activation (Enter / click). For stepper rows: reset to default.
  final VoidCallback? onTap;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;
  final bool enabled;

  /// Close the popover after [onTap].
  final bool closeOnTap;
}

/// A titled group of [KPopoverItem]s.
@immutable
class KPopoverSection {
  const KPopoverSection({this.header, required this.items});

  /// Uppercase header ("AUDIO", "SUBTITLES", "EXTERNAL SUBTITLES").
  final String? header;
  final List<KPopoverItem> items;
}

/// Builds the sections of a popover; called again after every item action
/// so values (✓, stepper text) stay current.
typedef KPopoverSectionsBuilder = List<KPopoverSection> Function(
  BuildContext context,
);

/// Player-style popover menu: frosted, radius 14, uppercase section
/// headers, ✓ rows, stepper rows. Use [showKPopoverMenu] to open it above
/// a button, or embed it in your own overlay.
class KPopoverMenu extends StatelessWidget {
  const KPopoverMenu({
    super.key,
    required this.sections,
    this.width = 320,
    this.maxHeight = 520,
    this.onClose,
    this.onChanged,
    this.autofocus = true,
  });

  final List<KPopoverSection> sections;
  final double width;
  final double maxHeight;

  /// Called after an item with `closeOnTap` ran.
  final VoidCallback? onClose;

  /// Called after any item action (used to rebuild values).
  final VoidCallback? onChanged;

  /// Focus the first checked (or first) row when shown.
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    var autofocusDone = !autofocus;
    final firstChecked = sections
        .expand((s) => s.items)
        .where((i) => i.checked == true && i.enabled)
        .firstOrNull;
    for (var s = 0; s < sections.length; s++) {
      final section = sections[s];
      if (s > 0) {
        children.add(Container(height: 1, color: KColors.separator));
      }
      if (section.header != null) {
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
            child: Text(
              section.header!.upper(context),
              style: KText.menuHeader.copyWith(color: KColors.textPrimary),
            ),
          ),
        );
      } else {
        children.add(const SizedBox(height: 6));
      }
      for (final item in section.items) {
        var focusThis = false;
        if (!autofocusDone && item.enabled) {
          if (firstChecked == null || identical(firstChecked, item)) {
            focusThis = true;
            autofocusDone = true;
          }
        }
        children.add(
          _PopoverRow(
            item: item,
            autofocus: focusThis,
            onActivated: () {
              onChanged?.call();
              if (item.closeOnTap) onClose?.call();
            },
            onStepped: onChanged,
          ),
        );
      }
      if (s == sections.length - 1) children.add(const SizedBox(height: 6));
    }
    return KFrostedPanel(
      width: width,
      borderRadius: KRadii.popover,
      child: Material(
        type: MaterialType.transparency,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SingleChildScrollView(
            child: FocusTraversalGroup(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PopoverRow extends StatelessWidget {
  const _PopoverRow({
    required this.item,
    required this.autofocus,
    required this.onActivated,
    required this.onStepped,
  });

  final KPopoverItem item;
  final bool autofocus;
  final VoidCallback onActivated;
  final VoidCallback? onStepped;

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (item._kind != _PopoverItemKind.stepper || !item.enabled) {
      return KeyEventResult.ignored;
    }
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      item.onDecrement?.call();
      onStepped?.call();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      item.onIncrement?.call();
      onStepped?.call();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final strings = KStrings.of(context);
    final isStepper = item._kind == _PopoverItemKind.stepper;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: KInteractive(
        autofocus: autofocus,
        enabled: item.enabled,
        selected: item.checked ?? false,
        semanticLabel: item.label,
        onTap: item.enabled && (item.onTap != null || !isStepper)
            ? () {
                item.onTap?.call();
                onActivated();
              }
            : null,
        builder: (context, state, _) {
          // the highlighted row is a white pill.
          final pill = state.highlighted;
          final Color color;
          if (item.destructive) {
            color = pill ? KColors.accent : KButton.destructiveForeground;
          } else {
            color = pill ? Colors.black : KColors.textPrimary;
          }
          final secondary = pill
              ? const Color(0xFF55555A)
              : KColors.textSecondary;
          Widget row = AnimatedContainer(
            duration: KMotion.of(context, const Duration(milliseconds: 90)),
            curve: KMotion.hover,
            constraints: const BoxConstraints(minHeight: 40),
            margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            padding: EdgeInsets.fromLTRB(14, 5, isStepper ? 5 : 14, 5),
            decoration: BoxDecoration(
              color: pill ? KColors.focusRing : const Color(0x00F5F5F5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: KText.menu.copyWith(
                      fontSize: 15,
                      color: color,
                      fontWeight: item.checked == true
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
                if (item.detail != null) ...[
                  const SizedBox(width: 10),
                  Text(
                    item.detail!,
                    style: KText.caption.copyWith(
                      fontSize: 14,
                      color: secondary,
                    ),
                  ),
                ],
                if (item.icon != null) ...[
                  const SizedBox(width: 10),
                  Icon(item.icon, size: 20, color: color),
                ],
                if (item._kind == _PopoverItemKind.check) ...[
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 18,
                    child: item.checked == true
                        ? Icon(PhosphorIconsBold.check, size: 16, color: color)
                        : null,
                  ),
                ],
                if (isStepper) ...[
                  const SizedBox(width: 8),
                  _StepButton(
                    icon: PhosphorIconsBold.minus,
                    tooltip: strings.decrease,
                    onLight: pill,
                    onTap: item.enabled && item.onDecrement != null
                        ? () {
                            item.onDecrement!();
                            onStepped?.call();
                          }
                        : null,
                  ),
                  SizedBox(
                    width: 74,
                    child: Text(
                      item.valueText!,
                      textAlign: TextAlign.center,
                      style: KText.button.copyWith(
                        color: color,
                        fontFeatures: KText.tabular,
                      ),
                    ),
                  ),
                  _StepButton(
                    icon: PhosphorIconsBold.plus,
                    tooltip: strings.increase,
                    onLight: pill,
                    onTap: item.enabled && item.onIncrement != null
                        ? () {
                            item.onIncrement!();
                            onStepped?.call();
                          }
                        : null,
                  ),
                ],
              ],
            ),
          );
          if (!item.enabled) row = Opacity(opacity: 0.4, child: row);
          return row;
        },
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.tooltip,
    required this.onLight,
    this.onTap,
  });

  final IconData icon;
  final String tooltip;

  /// Drawn on the white highlight pill.
  final bool onLight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return KIconButton(
      icon: icon,
      onPressed: onTap,
      size: 30,
      iconSize: 14,
      focusable: false,
      background: onLight ? const Color(0x1F000000) : null,
      foreground: onLight ? Colors.black : Colors.white,
      semanticLabel: tooltip,
    );
  }
}

/// Opens a [KPopoverMenu] centered above [anchorRect] (global coordinates,
/// e.g. `kGlobalRectOf(buttonContext)`), keeping it inside the window.
///
/// [sections] is called on every rebuild: after each item action and, when
/// given, whenever [listenable] notifies — so ✓ marks and stepper values
/// always show the current state. Esc or an outside click closes it.
Future<void> showKPopoverMenu(
  BuildContext context, {
  required Rect anchorRect,
  required KPopoverSectionsBuilder sections,
  double width = 320,
  KPopupPlacement placement = KPopupPlacement.above,
  Listenable? listenable,
}) {
  return showKPopup<void>(
    context,
    anchorRect: anchorRect,
    placement: placement,
    gap: 12,
    builder: (context) {
      Widget build(BuildContext context) => StatefulBuilder(
        builder: (context, setState) => KPopoverMenu(
          sections: sections(context),
          width: width,
          onChanged: () => setState(() {}),
          onClose: () => Navigator.of(context).maybePop(),
        ),
      );
      if (listenable == null) return build(context);
      return ListenableBuilder(
        listenable: listenable,
        builder: (context, _) => build(context),
      );
    },
  );
}

/// One option of [showChooser].
@immutable
class KChoice<T> {
  const KChoice({
    required this.value,
    required this.label,
    this.subtitle,
    this.icon,
    this.enabled = true,
  });

  final T value;
  final String label;
  final String? subtitle;
  final IconData? icon;
  final bool enabled;
}

/// Settings chooser: a centered frosted panel with
/// a bold [title], an optional one-line [description], the options as
/// stacked pills and a Cancel pill. The hovered / focused pill turns white
/// with black text; the current value ([selected]) carries a ✓ and starts
/// focused. Returns the chosen value, or null on Cancel / Esc / outside
/// click.
///
/// ```dart
/// final lang = await showChooser<String>(context,
///   title: l10n.settingsLanguage,
///   description: l10n.settingsLanguageHint,
///   selected: current,
///   choices: [KChoice(value: 'system', label: l10n.settingsSystem), …]);
/// ```
Future<T?> showChooser<T>(
  BuildContext context, {
  required String title,
  required List<KChoice<T>> choices,
  T? selected,
  String? description,
  String? cancelLabel,
  double width = 380,
}) async {
  final result = await showKPopup<_Chosen<T>>(
    context,
    placement: KPopupPlacement.center,
    barrierColor: const Color(0x80000000),
    margin: 24,
    builder: (context) => _Chooser<T>(
      title: title,
      description: description,
      choices: choices,
      selected: selected,
      cancelLabel: cancelLabel ?? KStrings.of(context).cancel,
      width: width,
    ),
  );
  return result?.value;
}

class _Chosen<T> {
  const _Chosen(this.value);
  final T value;
}

class _Chooser<T> extends StatelessWidget {
  const _Chooser({
    required this.title,
    required this.description,
    required this.choices,
    required this.selected,
    required this.cancelLabel,
    required this.width,
  });

  final String title;
  final String? description;
  final List<KChoice<T>> choices;
  final T? selected;
  final String cancelLabel;
  final double width;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = choices.indexWhere(
      (c) => c.value == selected && c.enabled,
    );
    final autofocusIndex = selectedIndex >= 0
        ? selectedIndex
        : choices.indexWhere((c) => c.enabled);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;
    return KFrostedPanel(
      width: width,
      borderRadius: KRadii.sheet,
      child: Material(
        type: MaterialType.transparency,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: FocusTraversalGroup(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(title, style: KText.title),
                  ),
                  if (description != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
                      child: Text(description!, style: KText.caption),
                    ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < choices.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _ChooserPill(
                                label: choices[i].label,
                                subtitle: choices[i].subtitle,
                                icon: choices[i].icon,
                                enabled: choices[i].enabled,
                                checked: i == selectedIndex,
                                autofocus: i == autofocusIndex,
                                onTap: () =>
                                    Navigator.of(context)
                                        .pop(_Chosen<T>(choices[i].value)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _ChooserPill(
                    label: cancelLabel,
                    strong: true,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChooserPill extends StatelessWidget {
  const _ChooserPill({
    required this.label,
    required this.onTap,
    this.subtitle,
    this.icon,
    this.enabled = true,
    this.checked = false,
    this.autofocus = false,
    this.strong = false,
  });

  final String label;
  final VoidCallback onTap;
  final String? subtitle;
  final IconData? icon;
  final bool enabled;
  final bool checked;
  final bool autofocus;

  /// Bold label (Cancel).
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return KInteractive(
      autofocus: autofocus,
      enabled: enabled,
      selected: checked,
      semanticLabel: label,
      onTap: onTap,
      builder: (context, state, _) {
        final pill = state.highlighted;
        final fg = pill ? Colors.black : KColors.textPrimary;
        Widget row = AnimatedContainer(
          duration: KMotion.of(context, const Duration(milliseconds: 90)),
          curve: KMotion.hover,
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: pill
                ? KColors.focusRing
                : state.pressed
                ? const Color(0xFF333336)
                : const Color(0xFF2A2A2C),
            borderRadius: KRadii.pillBorder,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                child: icon == null ? null : Icon(icon, size: 18, color: fg),
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: KText.menu.copyWith(
                        fontSize: 15,
                        color: fg,
                        fontWeight: strong || checked
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        textAlign: TextAlign.center,
                        style: KText.caption.copyWith(
                          color: pill
                              ? const Color(0xFF55555A)
                              : KColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(
                width: 22,
                child: checked
                    ? Icon(PhosphorIconsBold.check, size: 16, color: fg)
                    : null,
              ),
            ],
          ),
        );
        if (!enabled) row = Opacity(opacity: 0.4, child: row);
        return row;
      },
    );
  }
}

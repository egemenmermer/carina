import 'package:flutter/material.dart';
import 'package:carina/core/text_case.dart';
import 'package:carina/core/icons/phosphor_icons.dart';

import 'package:carina/core/tokens.dart';
import 'package:carina/core/widgets/k_buttons.dart';
import 'package:carina/core/widgets/k_interactive.dart';

/// Uppercase section header above a group of settings rows ("GENERAL").
class SettingsSectionHeader extends StatelessWidget {
  const SettingsSectionHeader(
    this.title, {
    super.key,
    this.padding = const EdgeInsets.fromLTRB(16, 28, 16, 8),
  });

  final String title;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Semantics(
        header: true,
        child: Text(title.upper(context), style: KText.sectionLabel),
      ),
    );
  }
}

/// Groups settings rows. By default rows sit directly on black with small
/// gaps (the default); [framed] draws the iOS grouped-list card with thin
/// separators instead.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.children, this.framed = false});

  final List<Widget> children;
  final bool framed;

  @override
  Widget build(BuildContext context) {
    if (!framed) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 4),
            children[i],
          ],
        ],
      );
    }
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: KColors.surface1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KColors.stroke),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Container(
                height: 1,
                margin: const EdgeInsets.only(left: 16),
                color: KColors.stroke,
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Settings row: title on the left, the current
/// value in red on the right, then a chevron. The hovered / focused row
/// turns into a white pill with dark text. Clicking typically opens
/// [showChooser].
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.title,
    this.value,
    this.subtitle,
    this.icon,
    this.onTap,
    this.showChevron = true,
    this.destructive = false,
    this.enabled = true,
    this.trailing,
    this.focusNode,
    this.autofocus = false,
  });

  final String title;

  /// Current value ("3 Days", "Türkçe").
  final String? value;

  /// Second line under the title.
  final String? subtitle;

  /// Leading icon.
  final IconData? icon;
  final VoidCallback? onTap;
  final bool showChevron;

  /// Red title (Remove playlist, Clear cache).
  final bool destructive;
  final bool enabled;

  /// Replaces the value + chevron.
  final Widget? trailing;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return KInteractive(
      onTap: onTap,
      enabled: enabled && onTap != null,
      focusNode: focusNode,
      autofocus: autofocus,
      semanticLabel: value == null ? title : '$title, $value',
      builder: (context, state, _) => _SettingsRowFrame(
        state: state,
        enabled: enabled,
        icon: icon,
        title: title,
        subtitle: subtitle,
        destructive: destructive,
        trailing:
            trailing ??
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (value != null)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: Text(
                      value!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: KText.settingsValue.copyWith(
                        color: state.highlighted
                            ? const Color(0xFF3A3A3C)
                            : KColors.accent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                if (showChevron && onTap != null) ...[
                  const SizedBox(width: 8),
                  Icon(
                    PhosphorIconsBold.caretRight,
                    size: 14,
                    color: state.highlighted
                        ? const Color(0xFF3A3A3C)
                        : KColors.textTertiary,
                  ),
                ],
              ],
            ),
      ),
    );
  }
}

/// Settings row with a switch at the right; the whole row toggles.
class SettingsSwitchRow extends StatelessWidget {
  const SettingsSwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon,
    this.enabled = true,
    this.focusNode,
  });

  final String title;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? subtitle;
  final IconData? icon;
  final bool enabled;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final canToggle = enabled && onChanged != null;
    return KInteractive(
      onTap: canToggle ? () => onChanged!(!value) : null,
      enabled: canToggle,
      focusNode: focusNode,
      selected: value,
      semanticLabel: title,
      builder: (context, state, _) => _SettingsRowFrame(
        state: state,
        enabled: enabled,
        icon: icon,
        title: title,
        subtitle: subtitle,
        destructive: false,
        trailing: KSwitch(value: value, enabled: canToggle),
      ),
    );
  }
}

class _SettingsRowFrame extends StatelessWidget {
  const _SettingsRowFrame({
    required this.state,
    required this.enabled,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.destructive,
    required this.trailing,
  });

  final KInteractionState state;
  final bool enabled;
  final IconData? icon;
  final String title;
  final String? subtitle;
  final bool destructive;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final pill = state.highlighted;
    final titleColor = destructive
        ? (pill ? KColors.accent : KButton.destructiveForeground)
        : (pill ? const Color(0xFF1C1C1E) : KColors.textPrimary);
    Widget row = AnimatedContainer(
      duration: KMotion.of(context, KDurations.hover),
      curve: KMotion.hover,
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
      decoration: BoxDecoration(
        color: pill
            ? (state.pressed ? const Color(0xFFDADADA) : KColors.focusRing)
            : const Color(0x00F5F5F5),
        borderRadius: KRadii.pillBorder,
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 22,
              color: destructive ? titleColor : KColors.accent,
            ),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: KText.settingsTitle.copyWith(color: titleColor),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    subtitle!,
                    style: KText.caption.copyWith(
                      color: pill
                          ? const Color(0xFF55555A)
                          : KColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          trailing,
        ],
      ),
    );
    if (!enabled) row = Opacity(opacity: 0.45, child: row);
    return row;
  }
}

/// Section entry of the settings page's left column: red icon, white
/// label and a chevron; the [selected] section is a white pill with black
/// text.
class SettingsSectionTile extends StatelessWidget {
  const SettingsSectionTile({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.selected = false,
    this.focusNode,
    this.autofocus = false,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool selected;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return KInteractive(
      onTap: onTap,
      selected: selected,
      focusNode: focusNode,
      autofocus: autofocus,
      semanticLabel: label,
      builder: (context, state, _) {
        final pill = selected || state.focused;
        final fg = pill ? Colors.black : KColors.textPrimary;
        return AnimatedContainer(
          duration: KMotion.of(context, KDurations.hover),
          curve: KMotion.hover,
          constraints: const BoxConstraints(minHeight: 46),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: pill
                ? KColors.focusRing
                : state.hovered
                ? KColors.rowHover
                : const Color(0x00FFFFFF),
            borderRadius: KRadii.pillBorder,
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 22, color: KColors.accent),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KText.settingsTitle.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(PhosphorIconsBold.caretRight, size: 14, color: fg),
            ],
          ),
        );
      },
    );
  }
}

/// iOS-style switch drawn in the Carina palette (red when on). Purely
/// visual when [onChanged] is null (rows toggle it themselves).
class KSwitch extends StatelessWidget {
  const KSwitch({
    super.key,
    required this.value,
    this.onChanged,
    this.enabled = true,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final duration = KMotion.of(context, const Duration(milliseconds: 160));
    final track = AnimatedContainer(
      duration: duration,
      curve: KMotion.enter,
      width: 46,
      height: 28,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: value ? KColors.accent : const Color(0xFF3A3A3C),
        borderRadius: KRadii.pillBorder,
      ),
      child: AnimatedAlign(
        duration: duration,
        curve: KMotion.enter,
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color(0x40000000),
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    );
    final visual = Opacity(opacity: enabled ? 1 : 0.5, child: track);
    final onChanged = this.onChanged;
    if (onChanged == null) return visual;
    return KInteractive(
      onTap: enabled ? () => onChanged(!value) : null,
      enabled: enabled,
      selected: value,
      builder: (context, state, _) =>
          KFocusRing(visible: state.focused, borderRadius: 14, child: visual),
    );
  }
}

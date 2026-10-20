import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../../data/settings/settings_store.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../settings_model.dart';

/// Centered bold group title inside a section ("Engine", "TV Live"), as in
/// the settings ("General", "Third party player").
class SettingsGroupTitle extends StatelessWidget {
  const SettingsGroupTitle(this.title, {super.key, this.first = false});

  final String title;

  /// Less space above the first group of a section.
  final bool first;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: first ? 6 : 26, bottom: 8),
      child: Semantics(
        header: true,
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: KText.panelHeader.copyWith(letterSpacing: -0.1),
        ),
      ),
    );
  }
}

/// Grey explanatory text inside a section.
class SettingsNote extends StatelessWidget {
  const SettingsNote(this.text, {super.key, this.center = false, this.color});

  final String text;
  final bool center;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Text(
        text,
        textAlign: center ? TextAlign.center : TextAlign.start,
        style: KText.caption.copyWith(color: color),
      ),
    );
  }
}

/// An action row: the title in red, no value;
/// the hovered / focused row turns into the white pill.
class SettingsActionRow extends StatelessWidget {
  const SettingsActionRow({
    super.key,
    required this.title,
    required this.onTap,
    this.icon,
    this.subtitle,
    this.trailing,
    this.destructive = false,
    this.enabled = true,
  });

  final String title;
  final VoidCallback? onTap;
  final IconData? icon;
  final String? subtitle;
  final Widget? trailing;

  /// Orange-red (Remove, Clear) instead of the accent red.
  final bool destructive;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final active = enabled && onTap != null;
    return KInteractive(
      onTap: onTap,
      enabled: active,
      semanticLabel: title,
      builder: (context, state, _) {
        final pill = state.highlighted;
        final base = destructive
            ? KButton.destructiveForeground
            : KColors.accent;
        final color = pill ? (destructive ? KColors.accent : base) : base;
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
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: KText.settingsTitle.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
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
              if (trailing != null) ...[const SizedBox(width: 12), trailing!],
            ],
          ),
        );
        if (!active) row = Opacity(opacity: 0.45, child: row);
        return row;
      },
    );
  }
}

/// A list entry inside a section (hidden item, reminder, locked channel):
/// leading widget, title, subtitle and an action button at the right.
class SettingsListTile extends StatelessWidget {
  const SettingsListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.fromLTRB(16, 8, 10, 8),
      decoration: BoxDecoration(
        color: KColors.tile,
        borderRadius: BorderRadius.circular(KRadii.tile + 4),
      ),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 14)],
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KText.settingsTitle.copyWith(
                    fontFamilyFallback: KText.emojiFallback,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KText.caption,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );
  }
}

/// A column of [SettingsListTile]s with an empty message.
class SettingsList extends StatelessWidget {
  const SettingsList({
    super.key,
    required this.children,
    required this.emptyMessage,
  });

  final List<Widget> children;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return SettingsNote(emptyMessage, center: true);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 6),
          children[i],
        ],
      ],
    );
  }
}

/// A row bound to a typed setting: title left, current value in red right;
/// clicking opens the chooser (title, one-line description, the values,
/// Cancel). Choosing a value stores it and shows the green toast.
class SettingSpecRow<T> extends ConsumerWidget {
  const SettingSpecRow({super.key, required this.spec, this.playlistId});

  final SettingSpec<T> spec;
  final int? playlistId;

  Future<void> _choose(BuildContext context, WidgetRef ref, T current) async {
    final l10n = L10n.of(context);
    final toasts = ref.read(toastControllerProvider);
    final store = ref.read(settingsStoreProvider);
    final value = await showChooser<T>(
      context,
      title: spec.title(l10n),
      description: spec.description(l10n),
      selected: current,
      choices: [
        for (final o in spec.options(l10n))
          KChoice<T>(value: o.value, label: o.label),
      ],
    );
    if (value == null || value == current) return;
    await store.set(spec.key, value, playlistId: playlistId);
    if (!context.mounted) return;
    final after = L10n.of(context);
    toasts.show(
      after.librarySettingChanged(
        spec.title(after),
        spec.valueLabel(after, value),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final value = ref.watchSetting(spec.key, playlistId: playlistId);
    return SettingsRow(
      key: spec.rowKey,
      title: spec.title(l10n),
      value: spec.valueLabel(l10n, value),
      onTap: () => _choose(context, ref, value),
    );
  }
}

/// The row of [spec] (typed, so the chooser keeps the value type).
Widget settingRow<T>(SettingSpec<T> spec, int? playlistId) =>
    SettingSpecRow<T>(spec: spec, playlistId: playlistId);

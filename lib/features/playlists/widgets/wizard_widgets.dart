import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:carina/core/core.dart';

/// Left column of the wizard: `03 / Name your playlist` and a one-line
/// hint.
class WizardStepHeader extends StatelessWidget {
  const WizardStepHeader({super.key, required this.label, required this.hint});

  /// `03 / Name your playlist`.
  final String label;
  final String hint;

  static const TextStyle labelStyle = TextStyle(
    fontFamily: KText.family,
    fontSize: 32,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.9,
    height: 1.18,
    color: KColors.textPrimary,
  );

  @override
  Widget build(BuildContext context) {
    final duration = KMotion.of(context, const Duration(milliseconds: 180));
    return Semantics(
      liveRegion: true,
      child: AnimatedSwitcher(
        duration: duration,
        switchInCurve: KMotion.enter,
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.topLeft,
          children: [...previous, ?current],
        ),
        child: Column(
          key: ValueKey(label),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: labelStyle),
            const SizedBox(height: 18),
            Text(
              hint,
              style: KText.bodySecondary.copyWith(
                fontSize: 16,
                color: const Color(0xFFC4C4C6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A form row that opens a chooser (EPG time shift, reload frequency):
/// the dark bar with the label on the left and the value on the
/// right. The current row gets the red outline. Left / Right step through
/// the values without opening the chooser.
class WizardChoiceRow extends StatelessWidget {
  const WizardChoiceRow({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.focusNode,
    this.highlighted = false,
    this.onStep,
    this.icon = PhosphorIconsRegular.caretUpDown,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final FocusNode? focusNode;

  /// The wizard's current field.
  final bool highlighted;

  /// Called with -1 / +1 for Left / Right.
  final ValueChanged<int>? onStep;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final step = onStep;
    Widget row = KInteractive(
      onTap: onTap,
      focusNode: focusNode,
      semanticLabel: '$label, $value',
      builder: (context, state, _) => _FieldBar(
        highlighted: highlighted || state.focused,
        hovered: state.hovered,
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: KText.input.copyWith(color: KColors.textSecondary),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              value,
              style: KText.input.copyWith(
                fontWeight: FontWeight.w600,
                fontFeatures: KText.tabular,
              ),
            ),
            const SizedBox(width: 10),
            Icon(icon, size: 16, color: KColors.textSecondary),
          ],
        ),
      ),
    );
    if (step != null) {
      row = CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () => step(-1),
          const SingleActivator(LogicalKeyboardKey.arrowRight): () => step(1),
        },
        child: row,
      );
    }
    return row;
  }
}

/// The M3U file row: the chosen file name (or a placeholder) and a
/// "Choose file…" pill; click / Enter opens the file picker.
class WizardFileRow extends StatelessWidget {
  const WizardFileRow({
    super.key,
    required this.fileName,
    required this.placeholder,
    required this.buttonLabel,
    required this.onPick,
    this.focusNode,
    this.highlighted = false,
    this.status,
    this.errorText,
  });

  final String? fileName;
  final String placeholder;
  final String buttonLabel;
  final VoidCallback onPick;
  final FocusNode? focusNode;
  final bool highlighted;
  final KFieldStatus? status;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final name = fileName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        KInteractive(
          onTap: onPick,
          focusNode: focusNode,
          semanticLabel: name ?? placeholder,
          builder: (context, state, _) => _FieldBar(
            highlighted: highlighted || state.focused,
            hovered: state.hovered,
            error: errorText != null,
            padding: const EdgeInsets.fromLTRB(_FieldBar._textInset, 0, 6, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    name ?? placeholder,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KText.input.copyWith(
                      color: name == null
                          ? KColors.textTertiary
                          : KColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IgnorePointer(
                  child: KPill(label: buttonLabel, onTap: () {}),
                ),
              ],
            ),
          ),
        ),
        if (errorText != null || status != null) ...[
          const SizedBox(height: 7),
          WizardStatusLine(
            status: errorText != null
                ? KFieldStatus.error(errorText!)
                : status!,
          ),
        ],
      ],
    );
  }
}

/// A status line like the one under [KTextField] (green check, red cross
/// or a spinner) for rows that are not text fields.
class WizardStatusLine extends StatelessWidget {
  const WizardStatusLine({super.key, required this.status});

  final KFieldStatus status;

  @override
  Widget build(BuildContext context) {
    final (Widget icon, Color color) = switch (status.kind) {
      KFieldStatusKind.ok => (
        const Icon(
          PhosphorIconsFill.checkCircle,
          size: 17,
          color: KColors.success,
        ),
        KColors.success,
      ),
      KFieldStatusKind.error => (
        const Icon(
          PhosphorIconsFill.xCircle,
          size: 17,
          color: KButton.destructiveForeground,
        ),
        KButton.destructiveForeground,
      ),
      KFieldStatusKind.checking => (
        const KSpinner(
          size: 14,
          strokeWidth: 1.8,
          color: KColors.textSecondary,
        ),
        KColors.textSecondary,
      ),
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(top: 1), child: icon),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            status.message ?? '',
            style: KText.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

/// An inline notice under a field with an action (the "This is an Xtream
/// link — Switch to Xtream" offer).
class WizardNotice extends StatelessWidget {
  const WizardNotice({
    super.key,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    this.icon = PhosphorIconsLight.lightbulb,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: KColors.surface1,
        borderRadius: BorderRadius.circular(KRadii.tile),
        border: Border.all(color: KColors.strokeStrong),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: KColors.star),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: KText.caption.copyWith(color: KColors.textPrimary),
            ),
          ),
          const SizedBox(width: 12),
          KButton.primaryWhite(
            label: actionLabel,
            size: KButtonSize.small,
            onPressed: onAction,
          ),
        ],
      ),
    );
  }
}

/// The dark rounded bar shared by the non-text rows (same look as
/// [KTextField]: surface3, radius 8, 46 px, red 2 px outline when current).
class _FieldBar extends StatelessWidget {
  const _FieldBar({
    required this.child,
    required this.highlighted,
    required this.hovered,
    this.error = false,
    this.padding = const EdgeInsets.fromLTRB(_textInset, 0, 14, 0),
  });

  /// Where [KTextField] starts its text, so labels line up with it.
  static const double _textInset = 29;

  final Widget child;
  final bool highlighted;
  final bool hovered;
  final bool error;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final Color border;
    final double width;
    if (highlighted) {
      border = KColors.accent;
      width = 2;
    } else if (error) {
      border = KColors.accent.withValues(alpha: 0.75);
      width = 1.5;
    } else {
      border = hovered ? const Color(0x33FFFFFF) : const Color(0x00FFFFFF);
      width = 1;
    }
    return AnimatedContainer(
      duration: KMotion.of(context, KDurations.hover),
      curve: KMotion.hover,
      height: 46,
      padding: padding,
      decoration: BoxDecoration(
        color: KColors.surface3,
        borderRadius: BorderRadius.circular(KRadii.field),
        border: Border.all(color: border, width: width),
      ),
      child: child,
    );
  }
}

/// The big source pills of step 02 ("Xtream (Recommended)", "M3U playlist
/// via URL", "M3U file"): white with black text when hovered or focused,
/// dark grey otherwise.
class WizardSourcePill extends StatelessWidget {
  const WizardSourcePill({
    super.key,
    required this.label,
    required this.onTap,
    this.autofocus = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return KInteractive(
      onTap: onTap,
      autofocus: autofocus,
      semanticLabel: label,
      builder: (context, state, _) {
        final lit = state.highlighted;
        final duration = KMotion.of(context, KDurations.hover);
        return AnimatedScale(
          scale: state.pressed
              ? 0.98
              : lit
              ? 1.02
              : 1,
          duration: duration,
          curve: KMotion.hover,
          child: AnimatedContainer(
            duration: duration,
            curve: KMotion.hover,
            height: 60,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: lit ? KColors.focusRing : const Color(0xFF2C2C2E),
              borderRadius: KRadii.pillBorder,
              boxShadow: lit ? KShadows.floating : const [],
            ),
            child: Text(
              label,
              style: KText.buttonLarge.copyWith(
                fontSize: 19,
                fontWeight: FontWeight.w600,
                color: lit ? Colors.black : KColors.textPrimary,
              ),
            ),
          ),
        );
      },
    );
  }
}

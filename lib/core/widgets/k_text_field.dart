import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:carina/core/icons/phosphor_icons.dart';

import 'package:carina/core/strings.dart';
import 'package:carina/core/tokens.dart';
import 'package:carina/core/widgets/k_buttons.dart';

/// Kind of a [KFieldStatus].
enum KFieldStatusKind { ok, error, checking }

/// Inline status under a [KTextField] (the wizard's live URL checks).
@immutable
class KFieldStatus {
  /// Green check + message ("Server reachable · account active").
  const KFieldStatus.ok(this.message) : kind = KFieldStatusKind.ok;

  /// Red cross + reason ("Unreachable", "401 Unauthorized").
  const KFieldStatus.error(this.message) : kind = KFieldStatusKind.error;

  /// Small spinner + optional message (defaults to "Checking…").
  const KFieldStatus.checking([this.message])
    : kind = KFieldStatusKind.checking;

  final KFieldStatusKind kind;
  final String? message;
}

/// Dark text field (surface3, radius 8). Focus — or [highlighted], for the
/// wizard's "current field" — draws a 2 px red outline. Shows an optional
/// [label] above, [errorText] or a [status] line below, and a show/hide
/// toggle when [obscure] is true.
class KTextField extends StatefulWidget {
  const KTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.label,
    this.hint,
    this.errorText,
    this.status,
    this.obscure = false,
    this.enabled = true,
    this.autofocus = false,
    this.highlighted = false,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.onEditingComplete,
    this.inputFormatters,
    this.maxLines = 1,
    this.prefixIcon,
    this.suffix,
    this.autofillHints,
    this.large = false,
    this.semanticLabel,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;

  /// Label above the field.
  final String? label;

  /// Placeholder.
  final String? hint;

  /// Error line below the field (red); wins over [status].
  final String? errorText;

  /// Inline status line below the field.
  final KFieldStatus? status;

  /// Mask the text and show an eye toggle.
  final bool obscure;
  final bool enabled;
  final bool autofocus;

  /// Draw the red outline even without focus (wizard current field).
  final bool highlighted;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onEditingComplete;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;
  final IconData? prefixIcon;

  /// Widget at the right end inside the field.
  final Widget? suffix;
  final Iterable<String>? autofillHints;

  /// 56 px tall with 20 pt text (search page) instead of 46 px / 16 pt.
  final bool large;
  final String? semanticLabel;

  @override
  State<KTextField> createState() => _KTextFieldState();
}

class _KTextFieldState extends State<KTextField> {
  FocusNode? _ownFocus;
  bool _focused = false;
  bool _hovered = false;
  bool _revealed = false;

  FocusNode get _focus =>
      widget.focusNode ?? (_ownFocus ??= FocusNode(debugLabel: 'KTextField'));

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(KTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocus)?.removeListener(_onFocus);
      _focus.addListener(_onFocus);
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _ownFocus?.dispose();
    super.dispose();
  }

  void _onFocus() {
    if (_focused != _focus.hasFocus) setState(() => _focused = _focus.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    final strings = KStrings.of(context);
    final hasError = widget.errorText != null;
    final outlined = widget.enabled && (_focused || widget.highlighted);
    final duration = KMotion.of(context, KDurations.hover);
    final textStyle = widget.large
        ? KText.input.copyWith(fontSize: 20, letterSpacing: -0.33)
        : KText.input;
    final Color borderColor;
    final double borderWidth;
    if (outlined) {
      borderColor = KColors.accent;
      borderWidth = 2;
    } else if (hasError) {
      borderColor = KColors.accent.withValues(alpha: 0.75);
      borderWidth = 1.5;
    } else {
      borderColor = _hovered && widget.enabled
          ? const Color(0x33FFFFFF)
          : const Color(0x00FFFFFF);
      borderWidth = 1;
    }

    final field = TextField(
      controller: widget.controller,
      focusNode: _focus,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      obscureText: widget.obscure && !_revealed,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      onEditingComplete: widget.onEditingComplete,
      inputFormatters: widget.inputFormatters,
      maxLines: widget.obscure ? 1 : widget.maxLines,
      autofillHints: widget.autofillHints,
      style: textStyle,
      cursorColor: KColors.accent,
      cursorWidth: 2,
      cursorRadius: const Radius.circular(1),
      decoration: InputDecoration(
        isCollapsed: true,
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        hintText: widget.hint,
        hintStyle: textStyle.copyWith(color: KColors.textTertiary),
      ),
    );

    final box = MouseRegion(
      cursor: widget.enabled
          ? SystemMouseCursors.text
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: duration,
        curve: KMotion.hover,
        constraints: BoxConstraints(minHeight: widget.large ? 56 : 46),
        padding: EdgeInsets.fromLTRB(
          widget.prefixIcon != null ? 12 : 14,
          widget.maxLines > 1 ? 12 : 0,
          widget.obscure || widget.suffix != null ? 6 : 14,
          widget.maxLines > 1 ? 12 : 0,
        ),
        decoration: BoxDecoration(
          color: KColors.surface3,
          borderRadius: BorderRadius.circular(KRadii.field),
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        child: Row(
          children: [
            if (widget.prefixIcon != null) ...[
              Icon(
                widget.prefixIcon,
                size: widget.large ? 22 : 18,
                color: KColors.textSecondary,
              ),
              const SizedBox(width: 10),
            ],
            Expanded(child: field),
            if (widget.suffix != null) ...[
              const SizedBox(width: 8),
              widget.suffix!,
            ],
            if (widget.obscure) ...[
              const SizedBox(width: 4),
              KIconButton(
                icon: _revealed
                    ? PhosphorIconsLight.eyeSlash
                    : PhosphorIconsLight.eye,
                size: 34,
                iconSize: 20,
                focusable: false,
                background: const Color(0x00000000),
                tooltip: _revealed
                    ? strings.hidePassword
                    : strings.showPassword,
                onPressed: widget.enabled
                    ? () => setState(() => _revealed = !_revealed)
                    : null,
              ),
            ],
          ],
        ),
      ),
    );

    final below = hasError
        ? _StatusLine(kind: KFieldStatusKind.error, message: widget.errorText!)
        : widget.status != null
        ? _StatusLine(
            kind: widget.status!.kind,
            message:
                widget.status!.message ??
                (widget.status!.kind == KFieldStatusKind.checking
                    ? strings.checking
                    : ''),
          )
        : null;

    return Semantics(
      textField: true,
      label: widget.semanticLabel ?? widget.label,
      child: Opacity(
        opacity: widget.enabled ? 1 : 0.5,
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.label != null) ...[
                Text(widget.label!, style: KText.label),
                const SizedBox(height: 7),
              ],
              box,
              if (below != null) ...[const SizedBox(height: 7), below],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.kind, required this.message});

  final KFieldStatusKind kind;
  final String message;

  @override
  Widget build(BuildContext context) {
    final (Widget icon, Color color) = switch (kind) {
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
        const SizedBox.square(
          dimension: 14,
          child: CircularProgressIndicator(
            strokeWidth: 1.8,
            color: KColors.textSecondary,
          ),
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
            message,
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

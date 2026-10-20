import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/core.dart';
import '../../../l10n/gen/app_localizations.dart';

/// Validates the text of [showLibraryTextInput]; returns an error message
/// or null when the value is fine.
typedef LibraryTextValidator = String? Function(String value);

/// Centered text-entry panel in the settings chooser style (frosted panel,
/// bold title, one-line description, a field, Cancel / Save pills).
/// Returns the trimmed text, or null on Cancel / Esc / outside click.
///
/// ```dart
/// final ua = await showLibraryTextInput(context,
///   title: l10n.librarySetUserAgentCustom,
///   initialValue: current);
/// ```
Future<String?> showLibraryTextInput(
  BuildContext context, {
  required String title,
  String? description,
  String? initialValue,
  String? hint,
  String? confirmLabel,
  TextInputType? keyboardType,
  List<TextInputFormatter>? inputFormatters,
  LibraryTextValidator? validator,
  bool allowEmpty = true,
}) async {
  final result = await showKPopup<_TextResult>(
    context,
    placement: KPopupPlacement.center,
    barrierColor: const Color(0x80000000),
    margin: 24,
    builder: (context) => _TextInputPanel(
      title: title,
      description: description,
      initialValue: initialValue ?? '',
      hint: hint,
      confirmLabel: confirmLabel ?? L10n.of(context).save,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      allowEmpty: allowEmpty,
    ),
  );
  return result?.text;
}

class _TextResult {
  const _TextResult(this.text);
  final String text;
}

class _TextInputPanel extends StatefulWidget {
  const _TextInputPanel({
    required this.title,
    required this.description,
    required this.initialValue,
    required this.hint,
    required this.confirmLabel,
    required this.keyboardType,
    required this.inputFormatters,
    required this.validator,
    required this.allowEmpty,
  });

  final String title;
  final String? description;
  final String initialValue;
  final String? hint;
  final String confirmLabel;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final LibraryTextValidator? validator;
  final bool allowEmpty;

  @override
  State<_TextInputPanel> createState() => _TextInputPanelState();
}

class _TextInputPanelState extends State<_TextInputPanel> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue)
        ..selection = TextSelection(
          baseOffset: 0,
          extentOffset: widget.initialValue.length,
        );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty && !widget.allowEmpty) {
      setState(() => _error = L10n.of(context).libraryFieldRequired);
      return;
    }
    final error = widget.validator?.call(text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(_TextResult(text));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return KFrostedPanel(
      width: 440,
      borderRadius: KRadii.sheet,
      child: Material(
        type: MaterialType.transparency,
        child: FocusTraversalGroup(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(widget.title, style: KText.title),
                ),
                if (widget.description != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
                    child: Text(widget.description!, style: KText.caption),
                  ),
                const SizedBox(height: 16),
                KTextField(
                  controller: _controller,
                  autofocus: true,
                  hint: widget.hint,
                  errorText: _error,
                  keyboardType: widget.keyboardType,
                  inputFormatters: widget.inputFormatters,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: LibraryDialogPill(
                        label: l10n.cancel,
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: LibraryDialogPill(
                        label: widget.confirmLabel,
                        primary: true,
                        onTap: _submit,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Stacked-pill button of the chooser style: dark pill, white with black
/// text when hovered / focused. [primary] rests in the accent red.
class LibraryDialogPill extends StatelessWidget {
  const LibraryDialogPill({
    super.key,
    required this.label,
    required this.onTap,
    this.primary = false,
    this.destructive = false,
    this.autofocus = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final bool destructive;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return KInteractive(
      onTap: onTap,
      enabled: onTap != null,
      autofocus: autofocus,
      semanticLabel: label,
      builder: (context, state, _) {
        final Color fill;
        final Color fg;
        if (state.highlighted) {
          fill = state.pressed ? const Color(0xFFDADADA) : KColors.focusRing;
          fg = destructive ? KColors.accent : Colors.black;
        } else if (primary) {
          fill = state.pressed ? KColors.accentPressed : KColors.accent;
          fg = Colors.white;
        } else {
          fill = state.pressed
              ? const Color(0xFF333336)
              : const Color(0xFF2A2A2C);
          fg = destructive
              ? KButton.destructiveForeground
              : KColors.textPrimary;
        }
        Widget pill = AnimatedContainer(
          duration: KMotion.of(context, const Duration(milliseconds: 90)),
          curve: KMotion.hover,
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: KRadii.pillBorder,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: KText.menu.copyWith(
              fontSize: 15,
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
        pill = KFocusRing(
          visible: state.focused,
          borderRadius: 22,
          gap: 2,
          child: pill,
        );
        if (!state.enabled) pill = Opacity(opacity: 0.4, child: pill);
        return pill;
      },
    );
  }
}

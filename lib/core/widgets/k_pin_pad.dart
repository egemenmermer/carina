import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:carina/core/icons/phosphor_icons.dart';

import 'package:carina/core/strings.dart';
import 'package:carina/core/tokens.dart';
import 'package:carina/core/widgets/k_interactive.dart';

/// Checks an entered PIN; return false to shake and clear.
typedef KPinValidator = Future<bool> Function(String pin);

/// Numeric PIN pad: title, subtitle, dots indicator and a 3×4 grid of round
/// keys. Keyboard digits (top row and numpad), Backspace / Delete and Esc
/// work. When [length] digits are entered the PIN is validated; a wrong PIN
/// shakes the dots, turns them red and shows "Wrong PIN".
///
/// Use [showPinPad] for the modal overlay.
class KPinPad extends StatefulWidget {
  const KPinPad({
    super.key,
    required this.title,
    required this.onCompleted,
    this.subtitle,
    this.length = 4,
    this.validate,
    this.onCancel,
    this.autofocus = true,
  });

  final String title;
  final String? subtitle;
  final int length;

  /// Called with the PIN once it is entered and accepted.
  final ValueChanged<String> onCompleted;
  final KPinValidator? validate;

  /// Called on Esc or the Cancel key.
  final VoidCallback? onCancel;
  final bool autofocus;

  @override
  State<KPinPad> createState() => _KPinPadState();
}

class _KPinPadState extends State<KPinPad> with SingleTickerProviderStateMixin {
  final FocusNode _focus = FocusNode(debugLabel: 'KPinPad');
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: KDurations.shake,
  );
  String _pin = '';
  bool _error = false;
  bool _busy = false;

  static final Map<LogicalKeyboardKey, String> _digitKeys = {
    LogicalKeyboardKey.digit0: '0',
    LogicalKeyboardKey.digit1: '1',
    LogicalKeyboardKey.digit2: '2',
    LogicalKeyboardKey.digit3: '3',
    LogicalKeyboardKey.digit4: '4',
    LogicalKeyboardKey.digit5: '5',
    LogicalKeyboardKey.digit6: '6',
    LogicalKeyboardKey.digit7: '7',
    LogicalKeyboardKey.digit8: '8',
    LogicalKeyboardKey.digit9: '9',
    LogicalKeyboardKey.numpad0: '0',
    LogicalKeyboardKey.numpad1: '1',
    LogicalKeyboardKey.numpad2: '2',
    LogicalKeyboardKey.numpad3: '3',
    LogicalKeyboardKey.numpad4: '4',
    LogicalKeyboardKey.numpad5: '5',
    LogicalKeyboardKey.numpad6: '6',
    LogicalKeyboardKey.numpad7: '7',
    LogicalKeyboardKey.numpad8: '8',
    LogicalKeyboardKey.numpad9: '9',
  };

  @override
  void dispose() {
    _focus.dispose();
    _shake.dispose();
    super.dispose();
  }

  Future<void> _add(String digit) async {
    if (_busy || _pin.length >= widget.length) return;
    setState(() {
      _pin += digit;
      _error = false;
    });
    if (_pin.length < widget.length) return;
    final pin = _pin;
    final validate = widget.validate;
    var ok = true;
    if (validate != null) {
      _busy = true;
      try {
        ok = await validate(pin);
      } finally {
        _busy = false;
      }
    }
    if (!mounted) return;
    if (ok) {
      widget.onCompleted(pin);
      return;
    }
    setState(() => _error = true);
    if (KMotion.reduced(context)) {
      setState(() => _pin = '');
      return;
    }
    await _shake.forward(from: 0);
    if (mounted) setState(() => _pin = '');
  }

  void _backspace() {
    if (_busy || _pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = false;
    });
  }

  void _cancel() => widget.onCancel?.call();

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final digit = _digitKeys[event.logicalKey];
    if (digit != null) {
      _add(digit);
      return KeyEventResult.handled;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.delete) {
      _backspace();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape && widget.onCancel != null) {
      _cancel();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final strings = KStrings.of(context);
    final dots = AnimatedBuilder(
      animation: _shake,
      builder: (context, child) {
        final t = _shake.value;
        final dx = math.sin(t * math.pi * 6) * 12 * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < widget.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9),
              child: AnimatedContainer(
                duration: KMotion.of(context, const Duration(milliseconds: 90)),
                width: 15,
                height: 15,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < _pin.length
                      ? (_error ? KColors.accent : Colors.white)
                      : const Color(0x00FFFFFF),
                  border: Border.all(
                    color: _error
                        ? KColors.accent
                        : i < _pin.length
                        ? Colors.white
                        : const Color(0x99FFFFFF),
                    width: 1.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    Widget key(String digit) => _PinKey(
      semanticLabel: digit,
      onTap: () => _add(digit),
      child: Text(
        digit,
        style: const TextStyle(
          fontFamily: KText.family,
          fontSize: 30,
          fontWeight: FontWeight.w400,
          color: KColors.textPrimary,
          fontFeatures: KText.tabular,
        ),
      ),
    );

    final grid = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < row.length; i++) ...[
                  if (i > 0) const SizedBox(width: 22),
                  key(row[i]),
                ],
              ],
            ),
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: _PinKey.size,
              height: _PinKey.size,
              child: widget.onCancel == null
                  ? null
                  : _PinKey(
                      semanticLabel: strings.cancel,
                      plain: true,
                      onTap: _cancel,
                      child: Text(
                        strings.cancel,
                        style: KText.button.copyWith(
                          color: KColors.textSecondary,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 22),
            key('0'),
            const SizedBox(width: 22),
            _PinKey(
              semanticLabel: strings.pinDeleteDigit,
              plain: true,
              onTap: _backspace,
              child: const Icon(
                PhosphorIconsLight.backspace,
                size: 30,
                color: KColors.textPrimary,
              ),
            ),
          ],
        ),
      ],
    );

    return Focus(
      focusNode: _focus,
      autofocus: widget.autofocus,
      onKeyEvent: _onKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            PhosphorIconsLight.lockSimple,
            size: 34,
            color: KColors.textPrimary,
          ),
          const SizedBox(height: 14),
          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: KText.sectionTitle,
          ),
          if (widget.subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              widget.subtitle!,
              textAlign: TextAlign.center,
              style: KText.bodySecondary,
            ),
          ],
          const SizedBox(height: 26),
          dots,
          SizedBox(
            height: 40,
            child: Center(
              widthFactor: 1,
              child: AnimatedOpacity(
                opacity: _error ? 1 : 0,
                duration: KMotion.of(context, KDurations.hover),
                child: Text(
                  strings.pinWrong,
                  style: KText.caption.copyWith(
                    color: KColors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          grid,
        ],
      ),
    );
  }
}

class _PinKey extends StatelessWidget {
  const _PinKey({
    required this.child,
    required this.onTap,
    required this.semanticLabel,
    this.plain = false,
  });

  static const double size = 76;

  final Widget child;
  final VoidCallback onTap;
  final String semanticLabel;

  /// No fill (Cancel / backspace keys).
  final bool plain;

  @override
  Widget build(BuildContext context) {
    return KInteractive(
      onTap: onTap,
      focusOnTap: false,
      semanticLabel: semanticLabel,
      builder: (context, state, _) {
        final duration = KMotion.of(context, const Duration(milliseconds: 90));
        final Color fill;
        if (plain) {
          fill = state.pressed
              ? const Color(0x1FFFFFFF)
              : state.highlighted
              ? const Color(0x14FFFFFF)
              : const Color(0x00FFFFFF);
        } else {
          fill = state.pressed
              ? const Color(0x59FFFFFF)
              : state.highlighted
              ? const Color(0x33FFFFFF)
              : const Color(0x1FFFFFFF);
        }
        return KFocusRing(
          visible: state.focused,
          circle: true,
          child: AnimatedContainer(
            duration: duration,
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
            child: child,
          ),
        );
      },
    );
  }
}

/// Shows a full-window PIN pad over a dimmed, blurred backdrop and returns
/// the accepted PIN, or null when cancelled (Esc, Cancel, outside click).
///
/// With [validate], wrong PINs shake and the pad stays open; without it the
/// first complete PIN is returned (use that to set a new PIN).
///
/// ```dart
/// final pin = await showPinPad(context,
///   title: l10n.parentalEnterPin,
///   validate: (pin) async => pin == storedPin);
/// if (pin != null) unlock();
/// ```
Future<String?> showPinPad(
  BuildContext context, {
  required String title,
  String? subtitle,
  int length = 4,
  KPinValidator? validate,
}) {
  final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  return Navigator.of(context, rootNavigator: true).push<String>(
    PageRouteBuilder<String>(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      transitionDuration: reduce ? Duration.zero : KDurations.sheet,
      reverseTransitionDuration: reduce
          ? Duration.zero
          : const Duration(milliseconds: 160),
      pageBuilder: (context, animation, _) => _PinPadPage(
        animation: animation,
        title: title,
        subtitle: subtitle,
        length: length,
        validate: validate,
      ),
    ),
  );
}

class _PinPadPage extends StatelessWidget {
  const _PinPadPage({
    required this.animation,
    required this.title,
    required this.subtitle,
    required this.length,
    required this.validate,
  });

  final Animation<double> animation;
  final String title;
  final String? subtitle;
  final int length;
  final KPinValidator? validate;

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: animation, curve: KMotion.enter);
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).maybePop(),
              child: AnimatedBuilder(
                animation: curved,
                builder: (context, _) => BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: 18 * curved.value,
                    sigmaY: 18 * curved.value,
                  ),
                  child: ColoredBox(
                    color: Color.fromRGBO(0, 0, 0, 0.72 * curved.value),
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: FadeTransition(
              opacity: curved,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(44, 36, 44, 28),
                  decoration: BoxDecoration(
                    color: KColors.surface1,
                    borderRadius: BorderRadius.circular(KRadii.sheet),
                    border: Border.all(color: KColors.stroke),
                    boxShadow: KShadows.menu,
                  ),
                  child: KPinPad(
                    title: title,
                    subtitle: subtitle,
                    length: length,
                    validate: validate,
                    onCompleted: (pin) => Navigator.of(context).pop(pin),
                    onCancel: () => Navigator.of(context).maybePop(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

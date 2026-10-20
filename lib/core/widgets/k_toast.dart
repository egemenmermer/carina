import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:carina/core/icons/phosphor_icons.dart';

import 'package:carina/core/strings.dart';
import 'package:carina/core/tokens.dart';
import 'package:carina/core/widgets/k_buttons.dart';

/// Toast flavors.
enum KToastKind {
  /// Green pill with a check (state changes: "Removed from favorites").
  success,

  /// Neutral dark pill with an info icon.
  info,

  /// Red pill with a warning icon.
  error,
}

/// An action button of a [KBanner].
@immutable
class KBannerAction {
  const KBannerAction({
    required this.label,
    required this.onPressed,
    this.primary = false,
  });

  final String label;
  final VoidCallback onPressed;

  /// Red filled instead of translucent.
  final bool primary;
}

/// A toast or banner currently managed by [ToastController].
@immutable
class KToastEntry {
  const KToastEntry._({
    required this.id,
    required this.message,
    required this.kind,
    required this.icon,
    required this.isBanner,
    this.title,
    this.actions = const [],
  });

  final int id;

  /// Toast text, or the banner body.
  final String message;
  final KToastKind kind;
  final IconData? icon;
  final bool isBanner;

  /// Banner title.
  final String? title;
  final List<KBannerAction> actions;
}

/// Owns the visible toasts and banners. Read it through
/// [toastControllerProvider]:
///
/// ```dart
/// ref.read(toastControllerProvider).show(l10n.liveRemovedFromFavorites);
/// ref.read(toastControllerProvider).showBanner(
///   title: programme.title,
///   message: l10n.remindersStartsIn(5),
///   icon: PhosphorIconsLight.bell,
///   actions: [
///     KBannerAction(label: l10n.remindersWatchNow, primary: true, onPressed: watch),
///   ],
/// );
/// ```
///
/// Toasts auto-hide after [KDurations.toast] (2.5 s) and at most
/// [maxToasts] show at once (the oldest leaves first). Banners stay until
/// dismissed or an action runs, unless a duration is given.
class ToastController extends ChangeNotifier {
  ToastController({this.maxToasts = 3, this.maxBanners = 2});

  final int maxToasts;
  final int maxBanners;

  final List<KToastEntry> _entries = [];
  final Map<int, Timer> _timers = {};
  int _nextId = 1;
  bool _disposed = false;

  /// Visible entries, oldest first.
  List<KToastEntry> get entries => List.unmodifiable(_entries);

  /// Shows a toast and returns its id.
  int show(
    String message, {
    KToastKind kind = KToastKind.success,
    IconData? icon,
    Duration duration = KDurations.toast,
  }) {
    final entry = KToastEntry._(
      id: _nextId++,
      message: message,
      kind: kind,
      icon: icon,
      isBanner: false,
    );
    _entries.add(entry);
    final toasts = _entries.where((e) => !e.isBanner).toList();
    for (final old in toasts.take(math.max(0, toasts.length - maxToasts))) {
      _remove(old.id, notify: false);
    }
    _timers[entry.id] = Timer(duration, () => dismiss(entry.id));
    notifyListeners();
    return entry.id;
  }

  /// Shows a reminder-style banner (title, message, actions, ×) and returns
  /// its id. Each action dismisses the banner after running.
  int showBanner({
    required String title,
    String message = '',
    IconData? icon,
    List<KBannerAction> actions = const [],
    Duration? duration,
  }) {
    final entry = KToastEntry._(
      id: _nextId++,
      message: message,
      kind: KToastKind.info,
      icon: icon,
      isBanner: true,
      title: title,
      actions: actions,
    );
    _entries.add(entry);
    final banners = _entries.where((e) => e.isBanner).toList();
    for (final old in banners.take(math.max(0, banners.length - maxBanners))) {
      _remove(old.id, notify: false);
    }
    if (duration != null) {
      _timers[entry.id] = Timer(duration, () => dismiss(entry.id));
    }
    notifyListeners();
    return entry.id;
  }

  /// Hides the toast or banner [id].
  void dismiss(int id) => _remove(id);

  /// Hides everything.
  void clear() {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    _entries.clear();
    if (!_disposed) notifyListeners();
  }

  void _remove(int id, {bool notify = true}) {
    _timers.remove(id)?.cancel();
    final before = _entries.length;
    _entries.removeWhere((e) => e.id == id);
    if (notify && before != _entries.length && !_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    super.dispose();
  }
}

/// The app-wide [ToastController].
final toastControllerProvider = Provider<ToastController>((ref) {
  final controller = ToastController();
  ref.onDispose(controller.dispose);
  return controller;
});

/// Renders toasts and banners above [child]. Put it once at the app root,
/// inside the [ProviderScope] — e.g. `MaterialApp(builder: (context, child)
/// => KToastHost(child: child!))`.
///
/// Toasts slide down and fade in at the top-right corner ([top], [right]),
/// newest on top; banners stack below them.
class KToastHost extends ConsumerStatefulWidget {
  const KToastHost({
    super.key,
    required this.child,
    this.top = 52,
    this.right = 24,
  });

  final Widget child;

  /// Distance from the top of the window.
  final double top;

  /// Distance from the right edge of the window.
  final double right;

  @override
  ConsumerState<KToastHost> createState() => _KToastHostState();
}

class _KToastHostState extends ConsumerState<KToastHost>
    with TickerProviderStateMixin {
  late final ToastController _controller;
  final List<_LiveEntry> _live = [];
  bool _reduced = false;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(toastControllerProvider);
    _controller.addListener(_sync);
    if (_controller.entries.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = KMotion.reduced(context);
  }

  @override
  void dispose() {
    _controller.removeListener(_sync);
    for (final e in _live) {
      e.animation.dispose();
    }
    super.dispose();
  }

  void _sync() {
    if (!mounted) return;
    final reduced = _reduced;
    final current = {for (final e in _controller.entries) e.id: e};
    setState(() {
      for (final live in _live) {
        if (!current.containsKey(live.entry.id) && !live.leaving) {
          live.leaving = true;
          live.animation.reverse().whenComplete(() {
            if (!mounted) return;
            setState(() => _live.remove(live));
            live.animation.dispose();
          });
        }
      }
      final known = _live.map((e) => e.entry.id).toSet();
      for (final entry in _controller.entries) {
        if (known.contains(entry.id)) continue;
        final animation = AnimationController(
          vsync: this,
          duration: reduced ? Duration.zero : KDurations.toastAnimation,
          reverseDuration: reduced
              ? Duration.zero
              : const Duration(milliseconds: 200),
        )..forward();
        _live.add(_LiveEntry(entry, animation));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final toasts = _live.where((e) => !e.entry.isBanner).toList().reversed;
    final banners = _live.where((e) => e.entry.isBanner).toList();
    return Stack(
      children: [
        widget.child,
        if (_live.isNotEmpty)
          Positioned(
            top: widget.top,
            right: widget.right,
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final e in toasts)
                    _Animated(
                      key: ValueKey('toast-${e.entry.id}'),
                      animation: e.animation,
                      child: KToast(
                        message: e.entry.message,
                        kind: e.entry.kind,
                        icon: e.entry.icon,
                        onTap: () => _controller.dismiss(e.entry.id),
                      ),
                    ),
                  for (final e in banners)
                    _Animated(
                      key: ValueKey('banner-${e.entry.id}'),
                      animation: e.animation,
                      child: KBanner(
                        title: e.entry.title ?? '',
                        message: e.entry.message,
                        icon: e.entry.icon,
                        actions: [
                          for (final a in e.entry.actions)
                            KBannerAction(
                              label: a.label,
                              primary: a.primary,
                              onPressed: () {
                                _controller.dismiss(e.entry.id);
                                a.onPressed();
                              },
                            ),
                        ],
                        onDismiss: () => _controller.dismiss(e.entry.id),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _LiveEntry {
  _LiveEntry(this.entry, this.animation);

  final KToastEntry entry;
  final AnimationController animation;
  bool leaving = false;
}

class _Animated extends StatelessWidget {
  const _Animated({super.key, required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: KMotion.enter,
      reverseCurve: Curves.easeIn,
    );
    return SizeTransition(
      sizeFactor: curved,
      alignment: Alignment.topCenter,
      child: FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.35),
            end: Offset.zero,
          ).animate(curved),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// The toast pill itself (green by default): check-circle icon and white 17/600
/// text on a rounded gradient pill. [KToastHost] renders these; use the widget
/// directly only in previews.
class KToast extends StatelessWidget {
  const KToast({
    super.key,
    required this.message,
    this.kind = KToastKind.success,
    this.icon,
    this.onTap,
  });

  final String message;
  final KToastKind kind;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (top, bottom, rim, iconColor, defaultIcon) = switch (kind) {
      KToastKind.success => (
        KColors.toastTop,
        KColors.toastBottom,
        KColors.toastStroke,
        KColors.toastIcon,
        PhosphorIconsFill.checkCircle,
      ),
      KToastKind.info => (
        const Color(0xFF2A2A2C),
        const Color(0xFF222224),
        const Color(0xFF444446),
        KColors.textPrimary,
        PhosphorIconsFill.info,
      ),
      KToastKind.error => (
        const Color(0xFFB81D00),
        const Color(0xFFCC2400),
        const Color(0xFFE85A40),
        KColors.textPrimary,
        PhosphorIconsFill.warningCircle,
      ),
    };
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 52, maxWidth: 520),
        padding: const EdgeInsets.fromLTRB(16, 12, 24, 12),
        decoration: BoxDecoration(
          borderRadius: KRadii.pillBorder,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [top, bottom],
          ),
          border: Border.all(color: rim),
          boxShadow: KShadows.floating,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon ?? defaultIcon, size: 26, color: iconColor),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: KText.toast,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reminder-style banner: frosted card with icon, title, message and
/// actions ("Watch now" / "Dismiss"), plus a close button.
class KBanner extends StatelessWidget {
  const KBanner({
    super.key,
    required this.title,
    this.message = '',
    this.icon,
    this.actions = const [],
    this.onDismiss,
    this.width = 420,
  });

  final String title;
  final String message;
  final IconData? icon;
  final List<KBannerAction> actions;
  final VoidCallback? onDismiss;
  final double width;

  @override
  Widget build(BuildContext context) {
    final strings = KStrings.of(context);
    final radius = BorderRadius.circular(16);
    return Container(
      width: width,
      decoration: BoxDecoration(borderRadius: radius, boxShadow: KShadows.menu),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
            decoration: BoxDecoration(
              color: KColors.surface2.withValues(alpha: 0.92),
              borderRadius: radius,
              border: Border.all(color: KColors.materialStroke),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: KColors.accent.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon ?? PhosphorIconsFill.bellRinging,
                    size: 21,
                    color: KColors.accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: KText.cardTitle,
                      ),
                      if (message.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: KText.caption,
                        ),
                      ],
                      if (actions.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final a in actions)
                              a.primary
                                  ? KButton.accent(
                                      label: a.label,
                                      onPressed: a.onPressed,
                                      size: KButtonSize.small,
                                    )
                                  : KButton.secondary(
                                      label: a.label,
                                      onPressed: a.onPressed,
                                      size: KButtonSize.small,
                                    ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (onDismiss != null)
                  KIconButton(
                    icon: PhosphorIconsRegular.x,
                    onPressed: onDismiss,
                    size: 28,
                    iconSize: 14,
                    background: const Color(0x00000000),
                    semanticLabel: strings.dismiss,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

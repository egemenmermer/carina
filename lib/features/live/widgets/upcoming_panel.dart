import 'package:flutter/material.dart';

import '../../../app/time_format.dart';
import '../../../core/core.dart';
import '../../../data/repositories/repository_models.dart';
import '../../../l10n/gen/app_localizations.dart';

/// UPCOMING: the next 24 hours of the
/// selected channel. Each row: a reminder bell in the icon column, `TODAY`
/// in red small caps over the time (22/600), the title and the duration.
/// A click opens the programme details; the bell toggles a reminder. The
/// list scrolls and fades out at the bottom.
class UpcomingPanel extends StatelessWidget {
  const UpcomingPanel({
    super.key,
    required this.programmes,
    required this.reminderStarts,
    required this.now,
    required this.format,
    required this.onOpen,
    required this.onToggleReminder,
    this.firstRowFocusNode,
  });

  /// Null while loading.
  final List<ProgrammeView>? programmes;

  /// Focus node of the first row (Right arrow from the channel list).
  final FocusNode? firstRowFocusNode;

  /// Programme starts (UTC ms) with a reminder.
  final Set<int> reminderStarts;
  final DateTime now;
  final CarinaTimeFormat format;
  final ValueChanged<ProgrammeView> onOpen;
  final ValueChanged<ProgrammeView> onToggleReminder;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final list = programmes;
    Widget body;
    if (list == null) {
      body = const SizedBox.shrink();
    } else if (list.isEmpty) {
      body = Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          l10n.liveNoUpcoming,
          style: KText.caption.copyWith(color: KColors.textTertiary),
        ),
      );
    } else {
      body = ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Colors.white, Color(0x00FFFFFF)],
          stops: [0, 0.82, 1],
        ).createShader(rect),
        child: LayoutBuilder(
          builder: (context, constraints) => ListView.builder(
            padding: const EdgeInsets.only(bottom: 28),
            itemCount: list.length,
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: UpcomingRow(
                compact: constraints.maxWidth < 380,
                focusNode: i == 0 ? firstRowFocusNode : null,
                programme: list[i],
                dayLabel: _dayLabel(l10n, list[i].start),
                format: format,
                reminderSet: reminderStarts.contains(list[i].startMs),
                onOpen: () => onOpen(list[i]),
                onToggleReminder: () => onToggleReminder(list[i]),
              ),
            ),
          ),
        ),
      );
    }
    return KPanel(
      padding: const EdgeInsets.fromLTRB(20, 18, 18, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PanelHeader(l10n.liveUpcoming),
          const SizedBox(height: 14),
          Expanded(child: body),
        ],
      ),
    );
  }

  String _dayLabel(L10n l10n, DateTime start) {
    final s = start.toLocal();
    final n = now.toLocal();
    final today = DateTime(n.year, n.month, n.day);
    final day = DateTime(s.year, s.month, s.day);
    final diff = day.difference(today).inDays;
    if (diff <= 0) return l10n.liveTodayCaps;
    if (diff == 1) return l10n.liveTomorrowCaps;
    return format.dayHeader(start).toUpperCase();
  }
}

/// One UPCOMING row.
class UpcomingRow extends StatelessWidget {
  const UpcomingRow({
    super.key,
    required this.programme,
    required this.dayLabel,
    required this.format,
    required this.reminderSet,
    required this.onOpen,
    required this.onToggleReminder,
    this.focusNode,
    this.compact = false,
  });

  final ProgrammeView programme;
  final FocusNode? focusNode;

  /// Narrow panel (small window): a narrower time column.
  final bool compact;
  final String dayLabel;
  final CarinaTimeFormat format;
  final bool reminderSet;
  final VoidCallback onOpen;
  final VoidCallback onToggleReminder;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final p = programme;
    return KInteractive(
      onTap: onOpen,
      focusNode: focusNode,
      // Right-click / Menu key: the keyboard path to the reminder bell.
      onContextMenu: (position) async {
        final choice = await showKContextMenu<bool>(
          context,
          position: position,
          entries: [
            KMenuEntry(
              label: reminderSet
                  ? l10n.liveCancelReminder
                  : l10n.liveScheduleReminder,
              icon: PhosphorIconsLight.bellSimpleRinging,
              value: true,
            ),
          ],
        );
        if (choice == true) onToggleReminder();
      },
      semanticLabel: '$dayLabel ${format.time(p.start)} ${p.title}',
      builder: (context, state, _) {
        final duration = KMotion.of(context, KDurations.hover);
        return AnimatedContainer(
          duration: duration,
          curve: KMotion.hover,
          height: 62,
          decoration: BoxDecoration(
            color: state.highlighted ? KColors.surface3 : KColors.tile,
            borderRadius: BorderRadius.circular(KRadii.tile),
            border: Border.all(
              color: state.focused ? KColors.focusRing : KColors.stroke,
              width: state.focused ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 42,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Icon(
                      PhosphorIconsLight.calendarCheck,
                      size: 16,
                      color: KColors.textTertiary.withValues(alpha: 0.55),
                    ),
                    _BellButton(
                      active: reminderSet,
                      tooltip: reminderSet
                          ? l10n.liveCancelReminder
                          : l10n.liveScheduleReminder,
                      onPressed: onToggleReminder,
                    ),
                  ],
                ),
              ),
              const SizedBox(
                width: 1,
                height: double.infinity,
                child: ColoredBox(color: KColors.stroke),
              ),
              SizedBox(
                width: compact ? 86 : 108,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      dayLabel,
                      maxLines: 1,
                      style: KText.badge.copyWith(
                        color: KColors.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 1),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        format.time(p.start),
                        maxLines: 1,
                        style: KText.timeLarge,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  p.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: KText.cardTitle,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                l10n.liveMinutes(p.duration.inMinutes),
                style: KText.caption.copyWith(fontFeatures: KText.tabular),
              ),
              const SizedBox(width: 16),
            ],
          ),
        );
      },
    );
  }
}

class _BellButton extends StatelessWidget {
  const _BellButton({
    required this.active,
    required this.tooltip,
    required this.onPressed,
  });

  final bool active;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final button = KInteractive(
      onTap: onPressed,
      focusable: false,
      semanticLabel: tooltip,
      builder: (context, state, _) => Padding(
        padding: const EdgeInsets.all(3),
        child: Icon(
          active ? PhosphorIconsFill.bell : PhosphorIconsLight.bell,
          size: 17,
          color: active
              ? KColors.accent
              : state.hovered
              ? KColors.textPrimary
              : KColors.textTertiary,
        ),
      ),
    );
    if (Overlay.maybeOf(context) == null) return button;
    return Tooltip(message: tooltip, excludeFromSemantics: true, child: button);
  }
}

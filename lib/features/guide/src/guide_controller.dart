/// Focus model and commands of the guide grid.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../../../data/repositories/repository_models.dart';
import 'guide_cells.dart';

/// The focused cell: a row (channel) and one of its cells.
@immutable
class GuideFocus {
  const GuideFocus({
    required this.row,
    required this.channel,
    required this.cell,
  });

  /// Index in the grid's channel list.
  final int row;
  final ChannelView channel;
  final GuideCell cell;

  @override
  bool operator ==(Object other) =>
      other is GuideFocus &&
      other.row == row &&
      other.channel == channel &&
      other.cell == cell;

  @override
  int get hashCode => Object.hash(row, channel.providerId, cell);

  @override
  String toString() => 'GuideFocus($row ${channel.displayName}, $cell)';
}

/// Commands the grid implements (see [GuideGridController]).
abstract interface class GuideGridCommands {
  void jumpToNow();
  void jumpToDay(DateTime localDay);
  void focusChannel(String providerId, {DateTime? at});
  int? get visibleStartMs;
}

/// Lets the screen read the focused cell and drive the grid: jump to now,
/// to a day, or to a channel.
class GuideGridController extends ChangeNotifier {
  GuideFocus? _focus;
  GuideGridCommands? _grid;
  bool _notifyPending = false;

  /// The focused cell (null until the grid has rows).
  GuideFocus? get focus => _focus;

  /// Time at the left edge of the grid (UTC ms), when attached.
  int? get visibleStartMs => _grid?.visibleStartMs;

  void jumpToNow() => _grid?.jumpToNow();

  /// Scrolls to [localDay] at the current time of day.
  void jumpToDay(DateTime localDay) => _grid?.jumpToDay(localDay);

  /// Focuses the row of [providerId] at [at] (default now).
  void focusChannel(String providerId, {DateTime? at}) =>
      _grid?.focusChannel(providerId, at: at);

  /// Called by the grid.
  void attach(GuideGridCommands grid) => _grid = grid;

  /// Called by the grid.
  void detach(GuideGridCommands grid) {
    if (identical(_grid, grid)) _grid = null;
  }

  /// Called by the grid when focus moves. Listeners are notified after the
  /// current frame when this happens during build or layout.
  void setFocus(GuideFocus? focus) {
    if (focus == _focus) return;
    _focus = focus;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      if (_notifyPending) return;
      _notifyPending = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _notifyPending = false;
        notifyListeners();
      });
    } else {
      notifyListeners();
    }
  }

  @override
  void notifyListeners() {
    if (!hasListeners) return;
    super.notifyListeners();
  }
}

/// Paint-time selection state of the grid canvas (focus, hover, press).
class GuideSelection extends ChangeNotifier {
  int? _focusRow;
  int? _focusStartMs;
  int? _hoverRow;
  int? _hoverStartMs;
  bool _pressed = false;

  int? get focusRow => _focusRow;
  int? get focusStartMs => _focusStartMs;
  int? get hoverRow => _hoverRow;
  int? get hoverStartMs => _hoverStartMs;

  /// The hovered cell is pressed.
  bool get pressed => _pressed;

  void setFocus(int? row, int? startMs) {
    if (row == _focusRow && startMs == _focusStartMs) return;
    _focusRow = row;
    _focusStartMs = startMs;
    notifyListeners();
  }

  void setHover(int? row, int? startMs) {
    if (row == _hoverRow && startMs == _hoverStartMs) return;
    _hoverRow = row;
    _hoverStartMs = startMs;
    if (row == null) _pressed = false;
    notifyListeners();
  }

  void setPressed(bool pressed) {
    if (pressed == _pressed) return;
    _pressed = pressed;
    notifyListeners();
  }

  bool isFocused(int row, int startMs) =>
      row == _focusRow && startMs == _focusStartMs;

  bool isHovered(int row, int startMs) =>
      row == _hoverRow && startMs == _hoverStartMs;
}

/// Keyboard map of the player. Pure, so the whole map is
/// unit-tested.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'player_options.dart';

/// What a key does in the player.
enum PlayerCommand {
  togglePlay,
  seekBack,
  seekForward,
  seekBackLong,
  seekForwardLong,

  /// Jump to [PlayerShortcut.digit] × 10 % (VOD, catch-up).
  seekPercent,
  volumeUp,
  volumeDown,
  toggleMute,
  toggleFullscreen,
  audioMenu,
  subtitlesMenu,
  infoPanel,
  closeInfoPanel,
  nextEpisode,
  audioDelayDown,
  audioDelayUp,
  toggleStats,

  /// Esc / browser back: close the top overlay, leave full screen, close.
  back,

  /// Backspace in live TV: the previous channel when nothing is open.
  previousChannel,
  zapPrevious,
  zapNext,
  actionSheet,
  miniGuide,
  fullGuide,

  /// Live number zapping with [PlayerShortcut.digit].
  numberZap,
}

/// A resolved key press.
@immutable
class PlayerShortcut {
  const PlayerShortcut(this.command, {this.digit});

  final PlayerCommand command;

  /// 0–9 for [PlayerCommand.seekPercent] and [PlayerCommand.numberZap].
  final int? digit;

  @override
  bool operator ==(Object other) =>
      other is PlayerShortcut &&
      other.command == command &&
      other.digit == digit;

  @override
  int get hashCode => Object.hash(command, digit);

  @override
  String toString() =>
      'PlayerShortcut(${command.name}${digit == null ? '' : ' $digit'})';
}

/// Modifier state at the time of the key press.
@immutable
class PlayerModifiers {
  const PlayerModifiers({
    this.shift = false,
    this.control = false,
    this.meta = false,
  });

  /// From [HardwareKeyboard.instance].
  factory PlayerModifiers.current() {
    final k = HardwareKeyboard.instance;
    return PlayerModifiers(
      shift: k.isShiftPressed,
      control: k.isControlPressed,
      meta: k.isMetaPressed,
    );
  }

  final bool shift;
  final bool control;
  final bool meta;
}

/// 0–9 for digit and numpad keys, else null.
int? digitOfKey(LogicalKeyboardKey key) {
  const digits = [
    LogicalKeyboardKey.digit0,
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.digit5,
    LogicalKeyboardKey.digit6,
    LogicalKeyboardKey.digit7,
    LogicalKeyboardKey.digit8,
    LogicalKeyboardKey.digit9,
  ];
  const numpad = [
    LogicalKeyboardKey.numpad0,
    LogicalKeyboardKey.numpad1,
    LogicalKeyboardKey.numpad2,
    LogicalKeyboardKey.numpad3,
    LogicalKeyboardKey.numpad4,
    LogicalKeyboardKey.numpad5,
    LogicalKeyboardKey.numpad6,
    LogicalKeyboardKey.numpad7,
    LogicalKeyboardKey.numpad8,
    LogicalKeyboardKey.numpad9,
  ];
  final d = digits.indexOf(key);
  if (d >= 0) return d;
  final n = numpad.indexOf(key);
  return n >= 0 ? n : null;
}

/// The command for [key] (a key-down or repeat), or null when the player
/// does not use it.
///
/// VOD and catch-up: Space/K/OK play-pause · ←/→ (J/L) seek · Shift+←/→ long
/// seek · ↑ volume up · ↓ info panel while the controls are visible, else
/// volume down · M mute · F full screen · A audio · S subtitles · I info ·
/// N next episode (VOD) · 0–9 jump to 0–90 % · [ ] audio delay.
///
/// Live: ↑/↓, PageUp/PageDown, Ch+/Ch− zap · Enter action sheet · G mini
/// guide · Shift+G full guide · Backspace previous channel · 0–9 number
/// zapping · M · F · A · S · I · +/− volume.
///
/// Everywhere: Esc back · Ctrl/⌘+Shift+D stats · +/− volume.
PlayerShortcut? playerShortcutFor(
  LogicalKeyboardKey key, {
  required PlayerKind kind,
  required bool controlsVisible,
  bool infoPanelOpen = false,
  PlayerModifiers modifiers = const PlayerModifiers(),
}) {
  PlayerShortcut c(PlayerCommand command, {int? digit}) =>
      PlayerShortcut(command, digit: digit);
  final shift = modifiers.shift;
  final commandKey = modifiers.control || modifiers.meta;

  // Shared keys.
  if (key == LogicalKeyboardKey.keyD && shift && commandKey) {
    return c(PlayerCommand.toggleStats);
  }
  if (commandKey) return null;
  if (key == LogicalKeyboardKey.escape ||
      key == LogicalKeyboardKey.browserBack ||
      key == LogicalKeyboardKey.goBack) {
    return c(PlayerCommand.back);
  }
  if (key == LogicalKeyboardKey.keyM ||
      key == LogicalKeyboardKey.audioVolumeMute) {
    return c(PlayerCommand.toggleMute);
  }
  if (key == LogicalKeyboardKey.keyF) return c(PlayerCommand.toggleFullscreen);
  if (key == LogicalKeyboardKey.keyA) return c(PlayerCommand.audioMenu);
  if (key == LogicalKeyboardKey.keyS) return c(PlayerCommand.subtitlesMenu);
  if (key == LogicalKeyboardKey.keyI) {
    return c(
      infoPanelOpen ? PlayerCommand.closeInfoPanel : PlayerCommand.infoPanel,
    );
  }
  if (key == LogicalKeyboardKey.equal ||
      key == LogicalKeyboardKey.add ||
      key == LogicalKeyboardKey.numpadAdd ||
      key == LogicalKeyboardKey.audioVolumeUp) {
    return c(PlayerCommand.volumeUp);
  }
  if (key == LogicalKeyboardKey.minus ||
      key == LogicalKeyboardKey.numpadSubtract ||
      key == LogicalKeyboardKey.audioVolumeDown) {
    return c(PlayerCommand.volumeDown);
  }
  if (key == LogicalKeyboardKey.bracketLeft) {
    return c(PlayerCommand.audioDelayDown);
  }
  if (key == LogicalKeyboardKey.bracketRight) {
    return c(PlayerCommand.audioDelayUp);
  }

  final digit = digitOfKey(key);

  if (kind == PlayerKind.live) {
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.pageUp ||
        key == LogicalKeyboardKey.channelUp) {
      if (infoPanelOpen && key == LogicalKeyboardKey.arrowUp) {
        return c(PlayerCommand.closeInfoPanel);
      }
      return c(PlayerCommand.zapPrevious);
    }
    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.pageDown ||
        key == LogicalKeyboardKey.channelDown) {
      return c(PlayerCommand.zapNext);
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.select) {
      return c(PlayerCommand.actionSheet);
    }
    if (key == LogicalKeyboardKey.keyG) {
      return c(shift ? PlayerCommand.fullGuide : PlayerCommand.miniGuide);
    }
    if (key == LogicalKeyboardKey.backspace) {
      return c(PlayerCommand.previousChannel);
    }
    if (digit != null) return c(PlayerCommand.numberZap, digit: digit);
    return null;
  }

  // VOD and catch-up.
  if (key == LogicalKeyboardKey.backspace) return c(PlayerCommand.back);
  if (key == LogicalKeyboardKey.space ||
      key == LogicalKeyboardKey.keyK ||
      key == LogicalKeyboardKey.mediaPlayPause ||
      key == LogicalKeyboardKey.mediaPlay ||
      key == LogicalKeyboardKey.mediaPause ||
      key == LogicalKeyboardKey.enter ||
      key == LogicalKeyboardKey.numpadEnter ||
      key == LogicalKeyboardKey.select) {
    return c(PlayerCommand.togglePlay);
  }
  if (key == LogicalKeyboardKey.arrowLeft) {
    return c(shift ? PlayerCommand.seekBackLong : PlayerCommand.seekBack);
  }
  if (key == LogicalKeyboardKey.arrowRight) {
    return c(shift ? PlayerCommand.seekForwardLong : PlayerCommand.seekForward);
  }
  if (key == LogicalKeyboardKey.keyJ || key == LogicalKeyboardKey.mediaRewind) {
    return c(PlayerCommand.seekBack);
  }
  if (key == LogicalKeyboardKey.keyL ||
      key == LogicalKeyboardKey.mediaFastForward) {
    return c(PlayerCommand.seekForward);
  }
  if (key == LogicalKeyboardKey.arrowUp) {
    return c(
      infoPanelOpen ? PlayerCommand.closeInfoPanel : PlayerCommand.volumeUp,
    );
  }
  if (key == LogicalKeyboardKey.arrowDown) {
    if (infoPanelOpen) return null;
    return c(
      controlsVisible ? PlayerCommand.infoPanel : PlayerCommand.volumeDown,
    );
  }
  if (kind == PlayerKind.vod &&
      (key == LogicalKeyboardKey.keyN ||
          key == LogicalKeyboardKey.mediaTrackNext)) {
    return c(PlayerCommand.nextEpisode);
  }
  if (digit != null) return c(PlayerCommand.seekPercent, digit: digit);
  return null;
}

/// Seek step of [command] for [kind]: VOD ±10 s / ±60 s, catch-up ±30 s /
/// ±5 min.
Duration seekStepFor(PlayerCommand command, PlayerKind kind) {
  final catchup = kind == PlayerKind.catchup;
  return switch (command) {
    PlayerCommand.seekBack => Duration(seconds: catchup ? -30 : -10),
    PlayerCommand.seekForward => Duration(seconds: catchup ? 30 : 10),
    PlayerCommand.seekBackLong => Duration(seconds: catchup ? -300 : -60),
    PlayerCommand.seekForwardLong => Duration(seconds: catchup ? 300 : 60),
    _ => Duration.zero,
  };
}

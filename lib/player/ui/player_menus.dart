/// Contents of the player popovers (SWITCH PLAYER, AUDIO, SUBTITLES,
/// PICTURE, SPEED, OPTIONS). Built from the controller on every rebuild so
/// ✓ marks and delays stay current.
library;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/core.dart';
import '../../l10n/gen/app_localizations.dart';
import '../engine/playback_engine.dart';
import 'player_controller.dart';
import 'player_options.dart';
import 'player_texts.dart';

/// The bar buttons, in order.
enum PlayerMenu { switchPlayer, audio, subtitles, picture, speed, more }

/// Opens the native file dialog for a subtitle file; null when cancelled.
typedef SubtitleFilePicker = Future<String?> Function();

/// Overridden in tests.
final subtitleFilePickerProvider = Provider<SubtitleFilePicker>(
  (ref) => () async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['srt', 'ass', 'ssa', 'vtt', 'sub', 'idx'],
      );
      return file?.path;
    } on Object catch (e) {
      // Android TV often has no document picker app.
      debugPrint('File picker unavailable: $e');
      return null;
    }
  },
);

/// Speed choices.
const List<double> kPlayerRates = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

List<KPopoverSection> switchPlayerSections(
  L10n l10n,
  PlayerController c, {
  required ValueChanged<EngineProfile> onSelect,
}) => [
  KPopoverSection(
    header: l10n.playerSwitchPlayer,
    items: [
      for (final p in EngineProfile.values)
        KPopoverItem.check(
          label: profileLabel(l10n, p),
          checked: c.profile == p,
          onTap: () => onSelect(p),
        ),
    ],
  ),
];

List<KPopoverSection> audioSections(L10n l10n, PlayerController c) {
  final tracks = c.state.audioTracks;
  return [
    KPopoverSection(
      header: l10n.playerAudio,
      items: [
        if (tracks.isEmpty)
          KPopoverItem.action(label: l10n.playerNoAudioTracks, enabled: false),
        for (final t in tracks)
          KPopoverItem.check(
            label: trackLabel(l10n, t),
            detail: trackDetail(l10n, t),
            checked: t.id == c.state.selectedAudioId,
            onTap: () => c.selectAudio(t),
          ),
      ],
    ),
    KPopoverSection(
      items: [
        KPopoverItem.stepper(
          label: l10n.playerAudioDelay,
          valueText: delayLabel(l10n, c.audioDelay),
          onDecrement: c.audioDelay > const Duration(seconds: -5)
              ? () => c.stepAudioDelay(-1)
              : null,
          onIncrement: c.audioDelay < const Duration(seconds: 5)
              ? () => c.stepAudioDelay(1)
              : null,
          onTap: () => c.setAudioDelay(Duration.zero),
        ),
      ],
    ),
  ];
}

List<KPopoverSection> subtitleSections(
  L10n l10n,
  PlayerController c, {
  required VoidCallback onLoadFile,
}) {
  final tracks = c.state.subtitleTracks;
  final internal = tracks.where((t) => !t.isExternal).toList();
  final external = tracks.where((t) => t.isExternal).toList();
  KPopoverItem row(EngineTrack t) => KPopoverItem.check(
    label: trackLabel(l10n, t),
    detail: trackDetail(l10n, t),
    checked: t.id == c.state.selectedSubtitleId,
    onTap: () => c.selectSubtitle(t),
  );
  return [
    KPopoverSection(
      header: l10n.playerSubtitles,
      items: [
        KPopoverItem.check(
          label: l10n.playerSubtitlesDisabled,
          checked: c.state.selectedSubtitleId == null,
          onTap: () => c.selectSubtitle(null),
        ),
        for (final t in internal) row(t),
      ],
    ),
    KPopoverSection(
      header: l10n.playerExternalSubtitles,
      items: [
        for (final t in external) row(t),
        KPopoverItem.action(
          label: l10n.playerLoadSubtitleFile,
          icon: PhosphorIconsLight.folderOpen,
          onTap: onLoadFile,
        ),
      ],
    ),
    KPopoverSection(
      items: [
        KPopoverItem.stepper(
          label: l10n.playerSubtitleDelay,
          valueText: delayLabel(l10n, c.subtitleDelay),
          onDecrement: c.subtitleDelay > const Duration(seconds: -5)
              ? () => c.stepSubtitleDelay(-1)
              : null,
          onIncrement: c.subtitleDelay < const Duration(seconds: 5)
              ? () => c.stepSubtitleDelay(1)
              : null,
          onTap: () => c.setSubtitleDelay(Duration.zero),
        ),
      ],
    ),
    KPopoverSection(
      header: l10n.playerSubtitleSize,
      items: [
        for (final size in SubtitleSize.values)
          KPopoverItem.check(
            label: subtitleSizeLabel(l10n, size),
            checked: c.subtitleSize == size,
            closeOnTap: false,
            onTap: () => c.setSubtitleSize(size),
          ),
      ],
    ),
  ];
}

List<KPopoverSection> pictureSections(L10n l10n, PlayerController c) => [
  KPopoverSection(
    header: l10n.playerAspectRatio,
    items: [
      for (final mode in AspectMode.values)
        KPopoverItem.check(
          label: aspectLabel(l10n, mode),
          checked: c.aspect == mode,
          closeOnTap: false,
          onTap: () => c.setAspect(mode),
        ),
    ],
  ),
  KPopoverSection(
    header: l10n.playerDeinterlace,
    items: [
      for (final mode in DeinterlaceMode.values)
        KPopoverItem.check(
          label: deinterlaceLabel(l10n, mode),
          checked: c.deinterlace == mode,
          closeOnTap: false,
          onTap: () => c.setDeinterlace(mode),
        ),
    ],
  ),
];

List<KPopoverSection> speedSections(L10n l10n, PlayerController c) => [
  KPopoverSection(
    header: l10n.playerSpeed,
    items: [
      for (final rate in kPlayerRates)
        KPopoverItem.check(
          label: rateLabel(l10n, rate),
          checked: (c.state.rate - rate).abs() < 0.001,
          onTap: () => c.setRate(rate),
        ),
    ],
  ),
];

/// OPTIONS: info, statistics, full screen and (series) next episode.
List<KPopoverSection> moreSections(
  L10n l10n,
  PlayerController c, {
  required bool statsVisible,
  required bool fullscreen,
  required VoidCallback onInfo,
  required VoidCallback onStats,
  required VoidCallback onFullscreen,
  VoidCallback? onNextEpisode,
}) => [
  KPopoverSection(
    header: l10n.playerOptions,
    items: [
      KPopoverItem.action(
        label: l10n.playerInfo,
        icon: PhosphorIconsLight.info,
        detail: 'I',
        onTap: onInfo,
      ),
      if (onNextEpisode != null)
        KPopoverItem.action(
          label: l10n.playerNextEpisode,
          icon: PhosphorIconsLight.skipForward,
          detail: 'N',
          onTap: onNextEpisode,
        ),
      KPopoverItem.check(
        label: l10n.playerStatistics,
        checked: statsVisible,
        detail: 'Ctrl+Shift+D',
        onTap: onStats,
      ),
      KPopoverItem.action(
        label: fullscreen ? l10n.playerExitFullscreen : l10n.playerFullscreen,
        icon: fullscreen
            ? PhosphorIconsLight.cornersIn
            : PhosphorIconsLight.cornersOut,
        detail: 'F',
        onTap: onFullscreen,
      ),
    ],
  ),
];

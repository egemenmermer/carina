import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import '../../core/core.dart';
import '../../data/db/tables.dart';
import '../../data/import/import.dart';
import '../../data/repositories/epg_repository.dart';
import '../../data/repositories/live_repository.dart';
import '../../data/settings/settings_store.dart';
import '../../features/details/details_api.dart';
import '../../features/guide/guide_api.dart';
import '../../features/live/live_api.dart';
import '../../features/multiview/multiview_api.dart';
import '../../player/player_api.dart';
import '../launch_options.dart';
import '../mock_seed.dart';
import '../router.dart';

/// Wraps the whole app (dialogs and toasts included) for `--capture`.
final captureBoundaryKey = GlobalKey(debugLabel: 'capture-boundary');

/// One screen state to capture.
class CaptureStep {
  const CaptureStep(this.name, this.enter, {this.settle = 1800});

  final String name;
  final Future<void> Function(CaptureSession s) enter;

  /// Real time to wait after [enter] before taking the picture (ms).
  final int settle;
}

class CaptureSession {
  CaptureSession(this.container, this.playlistId);

  final ProviderContainer container;
  final int playlistId;

  GoRouter get router => container.read(routerProvider);
  BuildContext get context => rootNavigatorKey.currentContext!;

  void go(String location) => router.go(location);

  Future<void> setting<T>(SettingKey<T> key, T value) => container
      .read(settingsStoreProvider)
      .set(key, value, playlistId: playlistId);

  /// Closes dialogs, sheets, menus and pushed routes (not go_router pages).
  void closeOverlays() {
    final nav = rootNavigatorKey.currentState;
    nav?.popUntil((route) => route.settings is Page);
  }
}

/// `--capture <dir>`: launches with the mock playlist, walks a
/// fixed list of states and saves one PNG per state, then exits.
class CaptureRunner {
  CaptureRunner(this.container, this.outDir);

  final ProviderContainer container;
  final String outDir;

  static List<CaptureStep> steps(int pid) => [
    CaptureStep('01_playlist_manager', (s) async => s.go(Routes.manager)),
    CaptureStep(
      '02_add_wizard',
      (s) async => s.go('${Routes.newPlaylist}?type=xtream'),
    ),
    CaptureStep(
      '03_import_progress',
      (s) async => s.go(Routes.importPlaylist(pid)),
      settle: 700,
    ),
    CaptureStep('04_movies_home', (s) async {
      s.go(Routes.tab(pid, MainTab.movies));
    }, settle: 2500),
    CaptureStep('05_shows_home', (s) async {
      s.go(Routes.tab(pid, MainTab.shows));
    }, settle: 2500),
    CaptureStep('06_series_sheet', (s) async {
      unawaited(
        showSeriesDetails(s.context, playlistId: pid, seriesId: '5001'),
      );
    }, settle: 2500),
    CaptureStep('07_movie_sheet', (s) async {
      s.go(Routes.tab(pid, MainTab.movies));
      await Future<void>.delayed(const Duration(milliseconds: 600));
      final context = s.context;
      if (!context.mounted) return;
      unawaited(showMovieDetails(context, playlistId: pid, movieId: '3001'));
    }, settle: 2500),
    CaptureStep('08_live_horizontal', (s) async {
      await s.setting(PlaylistSettings.liveLayout, 'horizontal');
      s.go(Routes.tab(pid, MainTab.live));
    }, settle: 3000),
    CaptureStep('09_live_vertical', (s) async {
      await s.setting(PlaylistSettings.liveLayout, 'vertical');
      s.go(Routes.tab(pid, MainTab.live));
    }, settle: 3000),
    CaptureStep('10_channel_context_menu', (s) async {
      await s.setting(PlaylistSettings.liveLayout, 'horizontal');
      s.go(Routes.tab(pid, MainTab.live));
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      if (!s.context.mounted) return;
      unawaited(
        showChannelActions(
          s.context,
          playlistId: pid,
          channelId: '1001',
          position: const Offset(380, 260),
        ),
      );
    }, settle: 1500),
    CaptureStep('11_tv_guide', (s) async {
      s.go(Routes.tab(pid, MainTab.guide));
    }, settle: 3000),
    CaptureStep('12_programme_details', (s) async {
      final start = await _nextProgrammeStart(s, '1001');
      if (start == null || !s.context.mounted) return;
      unawaited(
        showProgrammeDetails(
          s.context,
          playlistId: pid,
          channelId: '1001',
          startUtc: start,
        ),
      );
    }),
    CaptureStep('13_archive_sheet', (s) async {
      unawaited(
        showArchiveSheet(s.context, playlistId: pid, channelId: '1001'),
      );
    }, settle: 2000),
    CaptureStep('14_vod_player_audio_menu', (s) async {
      unawaited(
        openPlayer(
          s.context,
          VodPlayRequest(
            playlistId: pid,
            type: ItemType.movie,
            providerId: '3001',
            resume: false,
            initialOverlay: PlayerInitialOverlay.audioMenu,
          ),
        ),
      );
    }, settle: 4000),
    CaptureStep('15_live_player_mini_guide', (s) async {
      unawaited(
        openPlayer(
          s.context,
          LivePlayRequest(
            playlistId: pid,
            channelId: '1001',
            initialOverlay: PlayerInitialOverlay.miniGuide,
          ),
        ),
      );
    }, settle: 4000),
    CaptureStep('16_full_guide_overlay', (s) async {
      unawaited(
        openPlayer(
          s.context,
          LivePlayRequest(
            playlistId: pid,
            channelId: '1001',
            initialOverlay: PlayerInitialOverlay.fullGuide,
          ),
        ),
      );
    }, settle: 4000),
    CaptureStep('17_multiview_2x2', (s) async {
      unawaited(
        addToMultiview(
          s.context,
          playlistId: pid,
          channelId: '1001',
          layout: MultiviewLayout.grid2x2,
        ),
      );
    }, settle: 5000),
    CaptureStep('18_search_results', (s) async {
      s.go('${Routes.search(pid)}?q=sicak');
    }, settle: 2000),
    CaptureStep('19_settings_player', (s) async {
      s.go(Routes.playlistSettings(pid, 'player'));
    }),
    CaptureStep('20_pin_pad', (s) async {
      unawaited(showPinPad(s.context, title: 'Enter PIN'));
    }, settle: 1000),
    CaptureStep('21_toast', (s) async {
      s.go(Routes.tab(pid, MainTab.live));
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      s.container
          .read(toastControllerProvider)
          .show('Parental control channels updated');
    }, settle: 900),
  ];

  static Future<DateTime?> _nextProgrammeStart(
    CaptureSession s,
    String channelId,
  ) async {
    final channel = await s.container
        .read(liveRepositoryProvider)
        .channel(s.playlistId, channelId);
    if (channel == null) return null;
    final upcoming = await s.container
        .read(epgRepositoryProvider)
        .upcomingForChannel(s.playlistId, channel);
    return upcoming.isEmpty ? null : upcoming.first.start;
  }

  Future<void> run() async {
    final options = container.read(launchOptionsProvider);
    final dir = Directory(outDir)..createSync(recursive: true);
    final index = <Map<String, Object?>>[];
    try {
      final seeded = await ensureMockPlaylist(container, options.mockUrl);
      final pid = seeded.playlistId;
      final progress = await container.read(importServiceProvider).run(pid);
      stdout.writeln('CAPTURE import ${progress.step.name}');
      final session = CaptureSession(container, pid);
      for (final step in [
        ...steps(pid),
        ...extraCaptureSteps.map((f) => f(pid)),
      ]) {
        try {
          session.closeOverlays();
          await Future<void>.delayed(const Duration(milliseconds: 300));
          await step.enter(session);
          await Future<void>.delayed(Duration(milliseconds: step.settle));
          final file = await _save(p.join(dir.path, '${step.name}.png'));
          index.add({'name': step.name, 'file': p.basename(file.path)});
          stdout.writeln('CAPTURE ${step.name}');
        } catch (e) {
          index.add({'name': step.name, 'error': '$e'});
          stdout.writeln('CAPTURE ${step.name} failed: $e');
        }
      }
    } catch (e) {
      index.add({'name': 'setup', 'error': '$e'});
    }
    File(p.join(dir.path, 'index.json'))
        .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(index));
    final failed = index.where((e) => e.containsKey('error')).length;
    stdout.writeln('CAPTURE done: ${index.length - failed} ok, $failed failed');
    exit(0);
  }

  Future<File> _save(String path) async {
    await WidgetsBinding.instance.endOfFrame;
    final boundary =
        captureBoundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return File(path).writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
  }
}

/// Steps added by later milestones (player, multiview, search…).
final List<CaptureStep Function(int playlistId)> extraCaptureSteps = [];

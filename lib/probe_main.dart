/// Engine probe: plays test media through [MpvEngine] in a visible window
/// and writes a JSON report (codec matrix, MKV tracks, zap timings and
/// memory, profile switch, error mapping), then exits 0 (all passed) or 1.
///
/// Build (replaces the normal app binary in build/macos — rebuild the app
/// afterwards):
///   flutter build macos --debug -t lib/probe_main.dart
/// Run:
///   build/macos/Build/Products/Debug/carina.app/Contents/MacOS/carina \
///     --out build/probe.json --media tools/mock_server/media/a.ts ...
///
/// Options: `--out <json>`, `--media <path-or-url>` (repeatable),
/// `--seconds <n>` (default 6), `--zap-count <n>` (200), `--zap-a <path>`,
/// `--zap-b <path>`, `--switch-media <path>`, `--volume <0-100>` (20),
/// `--no-zap`, `--no-switch`, `--no-errors`, `--no-caps`.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:carina/player/engine/engine_errors.dart';
import 'package:carina/player/engine/engine_mapping.dart';
import 'package:carina/player/engine/mpv_engine.dart';
import 'package:carina/player/engine/playback_engine.dart';
import 'package:media_kit/media_kit.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  final config = ProbeConfig.parse(args);
  runApp(ProbeApp(config: config));
}

/// Parsed command line.
class ProbeConfig {
  ProbeConfig({
    required this.out,
    required this.media,
    this.seconds = 6,
    this.zapCount = 200,
    this.zapA,
    this.zapB,
    this.switchMedia,
    this.volume = 20,
    this.zap = true,
    this.switchProfile = true,
    this.errors = true,
    this.capabilities = true,
  });

  factory ProbeConfig.parse(List<String> args) {
    String? out;
    final media = <String>[];
    var seconds = 6;
    var zapCount = 200;
    String? zapA;
    String? zapB;
    String? switchMedia;
    var volume = 20.0;
    var zap = true;
    var switchProfile = true;
    var errors = true;
    var capabilities = true;
    for (var i = 0; i < args.length; i++) {
      final a = args[i];
      String next() => i + 1 < args.length ? args[++i] : '';
      switch (a) {
        case '--out':
          out = next();
        case '--media':
          media.add(next());
        case '--seconds':
          seconds = int.tryParse(next()) ?? seconds;
        case '--zap-count':
          zapCount = int.tryParse(next()) ?? zapCount;
        case '--zap-a':
          zapA = next();
        case '--zap-b':
          zapB = next();
        case '--switch-media':
          switchMedia = next();
        case '--volume':
          volume = double.tryParse(next()) ?? volume;
        case '--no-zap':
          zap = false;
        case '--no-switch':
          switchProfile = false;
        case '--no-errors':
          errors = false;
        case '--no-caps':
          capabilities = false;
      }
    }
    final ts = media.where((m) => m.toLowerCase().endsWith('.ts')).toList();
    final h264 = ts.where((m) => _base(m).startsWith('h264')).toList();
    final zapPool = h264.length >= 2 ? h264 : ts;
    return ProbeConfig(
      out: out ?? 'build/probe_report.json',
      media: media,
      seconds: seconds,
      zapCount: zapCount,
      zapA: zapA ?? (zapPool.isNotEmpty ? zapPool[0] : null),
      zapB: zapB ?? (zapPool.length > 1 ? zapPool[1] : null),
      switchMedia:
          switchMedia ??
          media.firstWhere(
            (m) => m.endsWith('.mp4'),
            orElse: () => media.firstWhere(
              (m) => m.endsWith('.mkv'),
              orElse: () => ts.isNotEmpty ? ts.first : '',
            ),
          ),
      volume: volume,
      zap: zap,
      switchProfile: switchProfile,
      errors: errors,
      capabilities: capabilities,
    );
  }

  final String out;
  final List<String> media;
  final int seconds;
  final int zapCount;
  final String? zapA;
  final String? zapB;
  final String? switchMedia;
  final double volume;
  final bool zap;
  final bool switchProfile;
  final bool errors;
  final bool capabilities;
}

String _base(String path) {
  final clean = path.split('?').first;
  return clean.split(RegExp(r'[\\/]')).lastWhere((p) => p.isNotEmpty);
}

/// What a test file should decode to (inferred from its name).
class _Expect {
  const _Expect({
    this.audioCodec,
    this.channels = const {2, 6},
    this.width,
    this.height,
    this.videoCodec,
    this.deinterlace = false,
    this.tracks = false,
  });

  final String? audioCodec;
  final Set<int> channels;
  final int? width;
  final int? height;
  final String? videoCodec;
  final bool deinterlace;
  final bool tracks;

  static _Expect forFile(String name) {
    final n = name.toLowerCase();
    if (n.startsWith('h264_aac_1080p25')) {
      return const _Expect(
        audioCodec: 'aac',
        channels: {2},
        width: 1920,
        height: 1080,
        videoCodec: 'h264',
      );
    }
    if (n.startsWith('h264_ac3_51_1080p25')) {
      return const _Expect(
        audioCodec: 'ac3',
        channels: {6},
        width: 1920,
        height: 1080,
        videoCodec: 'h264',
      );
    }
    if (n.startsWith('hevc_eac3_2160p25')) {
      return const _Expect(
        audioCodec: 'eac3',
        channels: {6},
        width: 3840,
        height: 2160,
        videoCodec: 'hevc',
      );
    }
    if (n.startsWith('mpeg2_mp2_576i25')) {
      return const _Expect(
        audioCodec: 'mp2',
        channels: {2},
        width: 720,
        height: 576,
        videoCodec: 'mpeg2video',
        deinterlace: true,
      );
    }
    if (n.startsWith('h264_aac_720p50')) {
      return const _Expect(
        audioCodec: 'aac',
        channels: {2},
        width: 1280,
        height: 720,
        videoCodec: 'h264',
      );
    }
    if (n.startsWith('vod_tracks')) {
      return const _Expect(
        audioCodec: 'aac',
        channels: {2},
        width: 1280,
        height: 720,
        videoCodec: 'h264',
        tracks: true,
      );
    }
    if (n.startsWith('m0_check_ac3')) {
      return const _Expect(
        audioCodec: 'ac3',
        channels: {6},
        width: 1280,
        height: 720,
        videoCodec: 'h264',
      );
    }
    return const _Expect();
  }
}

class ProbeApp extends StatefulWidget {
  const ProbeApp({super.key, required this.config});

  final ProbeConfig config;

  @override
  State<ProbeApp> createState() => _ProbeAppState();
}

class _ProbeAppState extends State<ProbeApp> {
  PlaybackEngine? _engine;
  String _status = 'Carina engine probe';
  final Map<String, Object?> _report = {};
  final List<String> _failures = [];

  ProbeConfig get config => widget.config;

  Timer? _framePump;
  DateTime _lastFrame = DateTime.now();

  @override
  void initState() {
    super.initState();
    // With the display asleep or the window occluded macOS stops vsync, and
    // media_kit_video initializes its controller in a post-frame callback.
    // Keep frames coming with warm-up frames when vsync is quiet.
    SchedulerBinding.instance.addPersistentFrameCallback((_) {
      _lastFrame = DateTime.now();
    });
    _framePump = Timer.periodic(const Duration(milliseconds: 250), (_) {
      final quiet = DateTime.now().difference(_lastFrame);
      final binding = SchedulerBinding.instance;
      if (quiet > const Duration(milliseconds: 400) &&
          binding.schedulerPhase == SchedulerPhase.idle) {
        binding.scheduleWarmUpFrame();
      }
    });
    unawaited(_run());
  }

  @override
  void dispose() {
    _framePump?.cancel();
    super.dispose();
  }

  void _say(String text) {
    stdout.writeln('[probe] $text');
    if (mounted) setState(() => _status = text);
  }

  Future<void> _frames([int n = 2]) async {
    for (var i = 0; i < n; i++) {
      final c = Completer<void>();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!c.isCompleted) c.complete();
      });
      WidgetsBinding.instance.scheduleFrame();
      await c.future.timeout(const Duration(seconds: 3), onTimeout: () {});
    }
  }

  Future<MpvEngine> _newEngine(
    EngineOptions options, {
    bool preview = false,
  }) async {
    final engine = MpvEngine(options: options, preview: preview);
    final old = _engine;
    if (mounted) setState(() => _engine = engine);
    await _frames();
    if (old != null) await old.dispose();
    await engine.setVolume(config.volume);
    return engine;
  }

  Future<void> _retire(PlaybackEngine engine) async {
    if (identical(_engine, engine) && mounted) {
      setState(() => _engine = null);
      await _frames();
    }
    await engine.dispose();
  }

  Future<void> _sleep(int ms) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  /// Opens [source] and returns the time until the state reports a video
  /// size, or null on timeout.
  Future<Duration?> _timedOpen(
    PlaybackEngine engine,
    PlaybackSource source, {
    Duration timeout = const Duration(seconds: 10),
    Duration? start,
  }) async {
    final sw = Stopwatch()..start();
    // open()'s synchronous part resets the state, so listening afterwards
    // cannot see the previous file's video size.
    final opening = engine.open(source, start: start);
    final frame = _videoShown(engine, sw, timeout);
    await opening;
    if (engine.state.hasVideo) return sw.elapsed;
    return frame;
  }

  /// Completes with the stopwatch time when the state first reports a video
  /// size; null on timeout. Never throws (it may be left un-awaited).
  Future<Duration?> _videoShown(
    PlaybackEngine engine,
    Stopwatch sw,
    Duration timeout,
  ) {
    return engine.stateStream
        .firstWhere((s) => s.hasVideo)
        .then<Duration?>((_) => sw.elapsed, onError: (Object _) => null)
        .timeout(timeout, onTimeout: () => null);
  }

  Future<Map<String, String?>> _props(
    PlaybackEngine engine,
    List<String> names,
  ) async {
    final out = <String, String?>{};
    for (final n in names) {
      out[n] = await engine.getProperty(n);
    }
    return out;
  }

  Future<void> _writeReport() async {
    final file = File(config.out);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(_report),
    );
  }

  Future<void> _run() async {
    final started = DateTime.now();
    // Hard stop: never leave a hung probe behind.
    Timer(const Duration(minutes: 25), () async {
      _failures.add('probe timed out after 25 minutes');
      _report['failures'] = _failures;
      _report['pass'] = false;
      await _writeReport();
      exit(2);
    });
    _report['startedAt'] = started.toIso8601String();
    _report['platform'] =
        '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
    _report['dart'] = Platform.version.split(' ').first;
    _report['buildMode'] = const bool.fromEnvironment('dart.vm.product')
        ? 'release'
        : 'debug';
    _report['args'] = {
      'media': config.media.map(_base).toList(),
      'seconds': config.seconds,
      'zapCount': config.zapCount,
      'zapA': config.zapA == null ? null : _base(config.zapA!),
      'zapB': config.zapB == null ? null : _base(config.zapB!),
      'switchMedia': config.switchMedia == null || config.switchMedia!.isEmpty
          ? null
          : _base(config.switchMedia!),
    };
    _report['rssStartMb'] = _mb(ProcessInfo.currentRss);
    await _frames();
    try {
      if (config.capabilities) await _step('capabilities', _capabilities);
      final media = <Object?>[];
      _report['media'] = media;
      for (final path in config.media) {
        await _step('media ${_base(path)}', () async {
          media.add(await _probeMedia(path));
        });
      }
      final mkv = config.media.where((m) => _base(m).startsWith('vod_tracks'));
      if (mkv.isNotEmpty) {
        await _step('language preference', () => _languagePrefs(mkv.first));
      }
      if (config.switchProfile &&
          config.switchMedia != null &&
          config.switchMedia!.isNotEmpty) {
        await _step('switch profile', _switchProfile);
      }
      if (config.zap && config.zapA != null && config.zapB != null) {
        await _step('zap', _zap);
      }
      if (config.errors) await _step('errors', _errors);
    } catch (error, stack) {
      _failures.add('probe crashed: $error');
      _report['crash'] = '$error\n$stack';
    }
    final engine = _engine;
    if (engine != null) await _retire(engine);
    _report['rssEndMb'] = _mb(ProcessInfo.currentRss);
    _report['finishedAt'] = DateTime.now().toIso8601String();
    _report['durationSec'] =
        DateTime.now().difference(started).inMilliseconds / 1000;
    _report['failures'] = _failures;
    _report['pass'] = _failures.isEmpty;
    await _writeReport();
    _say(
      'done: ${_failures.isEmpty ? 'PASS' : 'FAIL (${_failures.length})'} '
      '→ ${config.out}',
    );
    for (final f in _failures) {
      stdout.writeln('[probe] FAIL $f');
    }
    await stdout.flush();
    exit(_failures.isEmpty ? 0 : 1);
  }

  Future<void> _step(String name, Future<void> Function() body) async {
    _say('step: $name');
    try {
      await body().timeout(const Duration(minutes: 8));
    } catch (error, stack) {
      _failures.add('$name threw: $error');
      stdout.writeln('[probe] $name threw: $error\n$stack');
    }
  }

  // ---------------------------------------------------------------------------

  Future<void> _capabilities() async {
    final engine = await _newEngine(const EngineOptions());
    final caps = <String, Object?>{};
    caps['mpv-version'] = await engine.getProperty('mpv-version');
    caps['ffmpeg-version'] = await engine.getProperty('ffmpeg-version');
    caps['deinterlaceAutoSupported'] = MpvEngine.deinterlaceAutoSupported;
    caps['deinterlaceFilters'] = [
      for (final m
          in MpvEngine.deinterlaceFilters ?? const <DeinterlaceMethod>{})
        m.name,
    ];
    caps['defaults'] = await _props(engine, [
      'audio-buffer',
      'cache-pause',
      'demuxer-lavf-probe-info',
      'demuxer-lavf-analyzeduration',
      'interpolation',
      'video-latency-hacks',
      'stream-buffer-size',
      'vd-lavc-threads',
      'video-sync',
      'network-timeout',
      'hwdec',
      'vo',
      'cache-on-disk',
      'subs-fallback',
      'sub-ass',
    ]);
    // profile=low-latency: as a property, and through apply-profile.
    await engine.setRawProperty('video-latency-hacks', 'no');
    await engine.setRawProperty('profile', kMpvLowLatencyProfile);
    caps['profileProperty'] =
        await engine.getProperty('video-latency-hacks') == 'yes';
    await engine.setRawProperty('video-latency-hacks', 'no');
    await engine.runCommand(['apply-profile', kMpvLowLatencyProfile]);
    caps['applyProfileCommand'] =
        await engine.getProperty('video-latency-hacks') == 'yes';
    // demuxer-lavf-o change-list add/remove keeps media_kit's whitelist.
    final lavfBase = await engine.getProperty('demuxer-lavf-o');
    await engine.runCommand([
      'change-list',
      'demuxer-lavf-o',
      'remove',
      'fflags',
    ]);
    await engine.runCommand([
      'change-list',
      'demuxer-lavf-o',
      'add',
      'fflags=+nobuffer',
    ]);
    final lavfAdded = await engine.getProperty('demuxer-lavf-o');
    await engine.runCommand([
      'change-list',
      'demuxer-lavf-o',
      'remove',
      'fflags',
    ]);
    final lavfRemoved = await engine.getProperty('demuxer-lavf-o');
    caps['demuxerLavfO'] = {
      'base': lavfBase,
      'afterAdd': lavfAdded,
      'afterRemove': lavfRemoved,
      'ok':
          (lavfAdded ?? '').contains('fflags') &&
          !(lavfRemoved ?? '').contains('fflags') &&
          (lavfRemoved ?? '').contains('protocol_whitelist'),
    };
    // Byte sizes, deinterlace values.
    await engine.setRawProperty('stream-buffer-size', '4096');
    caps['streamBufferSize4096'] = await engine.getProperty(
      'stream-buffer-size',
    );
    await engine.setRawProperty('stream-buffer-size', '131072');
    await engine.setRawProperty('deinterlace', 'yes');
    caps['deinterlaceYes'] = await engine.getProperty('deinterlace');
    await engine.setRawProperty('deinterlace', 'no');
    _report['capabilities'] = caps;
    if (caps['demuxerLavfO'] case {'ok': false}) {
      _failures.add('capabilities: demuxer-lavf-o change-list not working');
    }
    await _retire(engine);
  }

  // ---------------------------------------------------------------------------

  Future<Map<String, Object?>> _probeMedia(String path) async {
    final name = _base(path);
    final expect = _Expect.forFile(name);
    final isLive = isHlsUrl(path) || path.contains('/live/');
    final engine = await _newEngine(const EngineOptions());
    final result = <String, Object?>{'file': name, 'live': isLive};
    final notes = <String>[];
    final limitations = <String>[];
    final samples = <EngineStats>[];
    final sub = engine.statsStream.listen(samples.add);
    final source = PlaybackSource(url: path, isLive: isLive, title: name);
    final ttff = await _timedOpen(engine, source);
    result['timeToFirstFrameMs'] = ttff?.inMilliseconds;
    final windowStart = engine.state.position;
    await _sleep(1500);
    final pos1 = engine.state.position;
    await _sleep(math.max(1000, config.seconds * 1000 - 1500));
    final pos2 = engine.state.position;
    final props = await _props(engine, [
      'audio-codec-name',
      'audio-codec',
      'audio-params/channel-count',
      'audio-params/samplerate',
      'audio-params',
      'audio-out-params',
      'video-params',
      'video-format',
      'video-codec',
      'hwdec-current',
      'deinterlace',
      'vf',
      'video-frame-info/interlaced',
      'estimated-vf-fps',
      'container-fps',
      'aid',
      'sid',
      'mute',
      'volume',
    ]);
    result['props'] = props;
    result['stats'] = engine.stats.toJson();
    result['statsSamples'] = samples.length;
    result['position'] = {
      'start': windowStart.inMilliseconds / 1000,
      'at1_5s': pos1.inMilliseconds / 1000,
      'atEnd': pos2.inMilliseconds / 1000,
    };
    final trackList = await engine.getProperty('track-list');
    result['trackListIsJson'] = trackList?.startsWith('[') ?? false;
    result['audioTracks'] = [for (final t in engine.audioTracks) t.toString()];
    result['subtitleTracks'] = [
      for (final t in engine.subtitleTracks) t.toString(),
    ];
    result['selectedAudioId'] = engine.state.selectedAudioId;
    result['selectedSubtitleId'] = engine.state.selectedSubtitleId;
    result['state'] = engine.state.toString();

    final checks = <String, bool>{};
    final audioCodec = props['audio-codec-name'] ?? '';
    final channels = int.tryParse(props['audio-params/channel-count'] ?? '');
    final w = engine.stats.width;
    final h = engine.stats.height;
    checks['audioDecodes'] = audioCodec.isNotEmpty;
    if (expect.audioCodec != null) {
      checks['audioCodec=${expect.audioCodec}'] =
          audioCodec == expect.audioCodec;
    }
    checks['channels in ${expect.channels.toList()}'] =
        channels != null && expect.channels.contains(channels);
    checks['videoDecodes'] = w > 0 && h > 0;
    if (expect.width != null) {
      checks['size=${expect.width}x${expect.height}'] =
          w == expect.width && h == expect.height;
    }
    if (expect.videoCodec != null) {
      checks['videoCodec=${expect.videoCodec}'] =
          (props['video-format'] ?? props['video-codec'] ?? '').startsWith(
            expect.videoCodec!,
          );
    }
    checks['positionAdvances'] = isLive
        ? pos2 > pos1
        : (pos2 - pos1) >= const Duration(milliseconds: 2500);
    checks['noError'] = engine.state.error == null;
    checks['state.playing'] = engine.state.playing;
    checks['state not buffering'] = !engine.state.buffering;
    if (expect.deinterlace) {
      final deint = props['deinterlace'];
      final fps = double.tryParse(props['estimated-vf-fps'] ?? '') ?? 0;
      final containerFps = double.tryParse(props['container-fps'] ?? '') ?? 0;
      final interlacedOut = props['video-frame-info/interlaced'];
      // Field-rate output doubles the fps; deinterlaced frames are
      // progressive.
      final effective =
          (containerFps > 0 && fps > containerFps * 1.6) ||
          interlacedOut == 'no';
      final missingFilter = engine.recentLog.any(
        (l) =>
            l.contains("filter 'yadif' not found") ||
            l.contains('no deinterlace filter available'),
      );
      result['deinterlace'] = {
        'property': deint,
        'vf': props['vf'],
        'estimatedVfFps': fps,
        'containerFps': containerFps,
        'interlacedFramesAtOutput': interlacedOut,
        'statsDeinterlacing': engine.stats.deinterlacing,
        'hwdecCurrent': props['hwdec-current'],
        'effective': effective,
        'buildLacksDeinterlacer': missingFilter,
      };
      checks['deinterlace requested (auto detected interlaced frames)'] =
          deint == 'yes' || deint == 'auto';
      if (effective) {
        checks['deinterlace effective'] = true;
      } else if (missingFilter) {
        limitations.add(
          'deinterlace=yes was set, but this libmpv build has no software '
          'deinterlacer (yadif/bwdif) and mpv 0.36 has none for '
          '${props['hwdec-current'] ?? 'software'} frames: output stays '
          'interlaced',
        );
      } else {
        checks['deinterlace effective'] = false;
      }
      result['deinterlaceModes'] = await _deinterlaceModes(engine);
    }
    if (name.startsWith('hevc')) {
      final hw = props['hwdec-current'] ?? '';
      result['hevcDecoder'] = hw.isEmpty ? 'software' : hw;
      notes.add(
        hw == 'videotoolbox' || hw == 'd3d11va'
            ? 'HEVC hardware decoded ($hw)'
            : 'HEVC software decoded (hwdec-current=$hw)',
      );
    }
    if (expect.tracks) {
      final audio = engine.audioTracks;
      final subs = engine.subtitleTracks;
      checks['2 audio tracks'] = audio.length == 2;
      checks['2 subtitle tracks'] = subs.length == 2;
      if (audio.length >= 2) {
        final second = audio[1];
        await engine.selectAudio(second);
        await _sleep(1500);
        final after = await _props(engine, [
          'aid',
          'audio-codec-name',
          'audio-params/channel-count',
        ]);
        result['afterSelectSecondAudio'] = {
          'track': second.toString(),
          ...after,
        };
        checks['aid=${second.id}'] = after['aid'] == second.id;
        checks['second audio codec=ac3'] = after['audio-codec-name'] == 'ac3';
      }
      if (subs.length >= 2) {
        await engine.selectSubtitle(subs[1]);
        await _sleep(500);
        final sid = await engine.getProperty('sid');
        checks['sid=${subs[1].id}'] = sid == subs[1].id;
        await engine.selectSubtitle(null);
        await _sleep(300);
        checks['subtitles off'] = await engine.getProperty('sid') == 'no';
      }
    }
    await sub.cancel();
    result['checks'] = checks;
    result['notes'] = notes;
    result['platformLimitations'] = limitations;
    if (limitations.isNotEmpty) {
      final list =
          (_report['platformLimitations'] ??= <String>[]) as List<String>;
      list.addAll(limitations.map((l) => '$name: $l'));
    }
    final pass = checks.values.every((v) => v);
    result['pass'] = pass;
    result['log'] = engine.recentLog;
    if (!pass) {
      final failed = checks.entries.where((e) => !e.value).map((e) => e.key);
      _failures.add('$name: ${failed.join(', ')}');
    }
    await _retire(engine);
    return result;
  }

  /// What each deinterlace mode does on an interlaced file (field-rate
  /// output doubles `estimated-vf-fps`).
  Future<Map<String, Object?>> _deinterlaceModes(MpvEngine engine) async {
    Future<Map<String, String?>> snap() => _props(engine, [
      'deinterlace',
      'vf',
      'estimated-vf-fps',
      'video-frame-info/interlaced',
    ]);
    final out = <String, Object?>{};
    await engine.setRawProperty('deinterlace', 'no');
    await _sleep(1500);
    out['rawNo'] = await snap();
    await engine.setRawProperty('deinterlace', 'yes');
    await _sleep(2000);
    out['rawYes'] = await snap();
    await engine.setDeinterlace(DeinterlaceMode.on);
    await _sleep(2000);
    out['forcedOn'] = await snap();
    await engine.setDeinterlace(DeinterlaceMode.off);
    await _sleep(1500);
    out['off'] = await snap();
    await engine.setDeinterlace(DeinterlaceMode.auto);
    await _sleep(2500);
    out['autoAgain'] = await snap();
    return out;
  }

  // ---------------------------------------------------------------------------

  Future<void> _languagePrefs(String mkv) async {
    final out = <String, Object?>{};
    Future<Map<String, Object?>> run(EngineOptions options) async {
      final engine = await _newEngine(options);
      final ttff = await _timedOpen(
        engine,
        PlaybackSource(url: mkv, title: _base(mkv)),
      );
      await _sleep(1500);
      final props = await _props(engine, ['aid', 'sid', 'audio-codec-name']);
      final r = <String, Object?>{
        'ttffMs': ttff?.inMilliseconds,
        'selectedAudio': engine.state.selectedAudioTrack?.toString(),
        'selectedSubtitle': engine.state.selectedSubtitleTrack?.toString(),
        ...props,
      };
      await _retire(engine);
      return r;
    }

    final tr = await run(
      const EngineOptions(
        preferredAudioLanguage: 'tr',
        preferredSubtitleLanguage: 'Türkçe',
      ),
    );
    out['tr'] = tr;
    final en = await run(
      const EngineOptions(
        preferredAudioLanguage: 'eng',
        preferredSubtitleLanguage: kSubtitlesDisabled,
      ),
    );
    out['enNoSubs'] = en;
    final checks = {
      'tr audio is ac3': tr['audio-codec-name'] == 'ac3',
      'tr subtitle selected': tr['sid'] != null && tr['sid'] != 'no',
      'tr subtitle is Turkish': '${tr['selectedSubtitle']}'.contains('tur'),
      'en audio is aac': en['audio-codec-name'] == 'aac',
      'disabled subtitles': en['sid'] == 'no',
    };
    out['checks'] = checks;
    out['pass'] = checks.values.every((v) => v);
    _report['languagePreference'] = out;
    if (out['pass'] != true) {
      _failures.add(
        'language preference: '
        '${checks.entries.where((e) => !e.value).map((e) => e.key).join(', ')}',
      );
    }
  }

  // ---------------------------------------------------------------------------

  Future<void> _switchProfile() async {
    final path = config.switchMedia!;
    final engine = await _newEngine(
      const EngineOptions(profile: EngineProfile.hardware),
    );
    final out = <String, Object?>{'file': _base(path)};
    final source = PlaybackSource(url: path, title: _base(path));
    await _timedOpen(engine, source);
    await _sleep(5000);
    Future<Map<String, Object?>> switchTo(EngineProfile p) async {
      final before = engine.state.position;
      final sw = Stopwatch()..start();
      final switching = engine.switchProfile(p);
      final frame = _videoShown(engine, sw, const Duration(seconds: 10));
      await switching;
      final shown = engine.state.hasVideo ? sw.elapsed : await frame;
      final switchMs = shown?.inMilliseconds;
      // Position right after the reopen (the first frame is at the old
      // position), then again 1.5 s later to prove playback goes on.
      await _sleep(200);
      final timePos = double.tryParse(
        await engine.getProperty('time-pos') ?? '',
      );
      await _sleep(1500);
      final timePosLater = double.tryParse(
        await engine.getProperty('time-pos') ?? '',
      );
      final hw = await engine.getProperty('hwdec-current');
      final beforeSec = before.inMilliseconds / 1000;
      final delta = timePos == null ? null : timePos - beforeSec;
      return {
        'to': p.name,
        'positionBeforeSec': beforeSec,
        'timePosAfterSec': timePos,
        'deltaSec': delta,
        'timePos1500msLaterSec': timePosLater,
        'keepsPlaying':
            timePos != null &&
            timePosLater != null &&
            timePosLater - timePos > 1.0,
        'statePlaying': engine.state.playing,
        'switchMs': switchMs,
        'hwdecCurrent': hw,
        'statsProfile': engine.stats.profile.name,
        'error': engine.state.error?.toString(),
      };
    }

    out['initialHwdec'] = await engine.getProperty('hwdec-current');
    final toSoftware = await switchTo(EngineProfile.software);
    await _sleep(2000);
    final toHardware = await switchTo(EngineProfile.hardware);
    out['toSoftware'] = toSoftware;
    out['toHardware'] = toHardware;
    bool within(Object? d) => d is double && d.abs() <= 1.0;
    final checks = {
      'software: position kept (±1 s)': within(toSoftware['deltaSec']),
      'software: keeps playing': toSoftware['keepsPlaying'] == true,
      'software: state.playing': toSoftware['statePlaying'] == true,
      'software: hwdec-current=no': toSoftware['hwdecCurrent'] == 'no',
      'hardware: position kept (±1 s)': within(toHardware['deltaSec']),
      'hardware: keeps playing': toHardware['keepsPlaying'] == true,
      'hardware: state.playing': toHardware['statePlaying'] == true,
      'hardware: hwdec active':
          toHardware['hwdecCurrent'] != null &&
          toHardware['hwdecCurrent'] != 'no',
    };
    out['checks'] = checks;
    out['pass'] = checks.values.every((v) => v);
    _report['switchProfile'] = out;
    if (out['pass'] != true) {
      _failures.add(
        'switchProfile: '
        '${checks.entries.where((e) => !e.value).map((e) => e.key).join(', ')}',
      );
      out['log'] = engine.recentLog;
    }
    await _retire(engine);
  }

  // ---------------------------------------------------------------------------

  Future<void> _zap() async {
    final a = PlaybackSource(url: config.zapA!, isLive: true, title: 'A');
    final b = PlaybackSource(url: config.zapB!, isLive: true, title: 'B');
    final rssBeforeEngine = _mb(ProcessInfo.currentRss);
    final engine = await _newEngine(const EngineOptions());
    final times = <int>[];
    var failures = 0;
    final rss = <Map<String, Object?>>[
      {'zap': 0, 'rssMb': _mb(ProcessInfo.currentRss)},
    ];
    final sw = Stopwatch()..start();
    for (var i = 0; i < config.zapCount; i++) {
      final source = i.isEven ? a : b;
      final t = await _timedOpen(
        engine,
        source,
        timeout: const Duration(seconds: 5),
      );
      if (t == null) {
        failures++;
      } else {
        times.add(t.inMilliseconds);
      }
      await _sleep(150);
      if ((i + 1) % 20 == 0) {
        rss.add({'zap': i + 1, 'rssMb': _mb(ProcessInfo.currentRss)});
        _say('zap ${i + 1}/${config.zapCount}');
      }
    }
    final totalSec = sw.elapsedMilliseconds / 1000;
    final audioAtEnd = await engine.getProperty('audio-codec-name');
    await engine.stop();
    await _sleep(1000);
    final rssAfterStop = _mb(ProcessInfo.currentRss);
    await _retire(engine);
    // media_kit destroys the mpv handle 5 s after dispose.
    await _sleep(6000);
    final rssAfterDispose = _mb(ProcessInfo.currentRss);
    times.sort();
    int pct(double p) => times.isEmpty
        ? -1
        : times[math.min(times.length - 1, (p * times.length).ceil() - 1)];
    final out = <String, Object?>{
      'files': [_base(config.zapA!), _base(config.zapB!)],
      'count': config.zapCount,
      'ok': times.length,
      'failures': failures,
      'totalSec': totalSec,
      'ttffMs': {
        'min': times.isEmpty ? -1 : times.first,
        'median': pct(0.5),
        'p95': pct(0.95),
        'max': times.isEmpty ? -1 : times.last,
        'mean': times.isEmpty
            ? -1
            : (times.reduce((x, y) => x + y) / times.length).round(),
      },
      'rssBeforeEngineMb': rssBeforeEngine,
      'rss': rss,
      'rssAfterStopMb': rssAfterStop,
      'rssAfterDisposeMb': rssAfterDispose,
      'audioCodecAtEnd': audioAtEnd,
      'budgetMs': 1200,
    };
    final warm = rss.length > 1 ? rss[1] : rss.first;
    final growth = (rss.last['rssMb']! as double) - (warm['rssMb']! as double);
    out['rssGrowthAfterWarmupMb'] = double.parse(growth.toStringAsFixed(1));
    final checks = {
      'all zaps showed video': failures == 0,
      'p95 < 1200 ms': pct(0.95) >= 0 && pct(0.95) < 1200,
      'no runaway memory (<150 MB growth after 20 zaps)': growth < 150,
    };
    out['checks'] = checks;
    out['pass'] = checks.values.every((v) => v);
    _report['zap'] = out;
    if (out['pass'] != true) {
      _failures.add(
        'zap: '
        '${checks.entries.where((e) => !e.value).map((e) => e.key).join(', ')}',
      );
    }
  }

  // ---------------------------------------------------------------------------

  Future<void> _errors() async {
    final tsFile = config.media.firstWhere(
      (m) => m.endsWith('.ts'),
      orElse: () => '',
    );
    final tsBytes = tsFile.isEmpty ? <int>[] : await File(tsFile).readAsBytes();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requests = <String, int>{};
    final pending = <HttpResponse>[];
    server.listen((req) async {
      final path = req.uri.path;
      requests[path] = (requests[path] ?? 0) + 1;
      final res = req.response;
      switch (path) {
        case '/e/404.ts' || '/e/live404.ts':
          res.statusCode = 404;
          await res.close();
        case '/e/403.ts':
          res.statusCode = 403;
          await res.close();
        case '/e/401.ts':
          res.statusCode = 401;
          await res.close();
        case '/e/500.ts':
          res.statusCode = 500;
          await res.close();
        case '/e/html.ts':
          res.headers.contentType = ContentType.html;
          res.write(
            '<html><body><h1>Account expired</h1>'
            '${'<p>padding</p>' * 400}</body></html>',
          );
          await res.close();
        case '/e/slow.ts':
          pending.add(res); // never answered
        case '/e/drop.ts':
          res.headers.contentType = ContentType('video', 'mp2t');
          final n = math.min(tsBytes.length, 700 * 1024);
          res.add(tsBytes.sublist(0, n - n % 188));
          await res.close();
        default:
          res.statusCode = 400;
          await res.close();
      }
    });
    final base = 'http://127.0.0.1:${server.port}';
    final cases = <Map<String, Object?>>[
      {'name': 'http404', 'url': '$base/e/404.ts', 'kind': 'http', 'code': 404},
      {'name': 'http403', 'url': '$base/e/403.ts', 'kind': 'http', 'code': 403},
      {'name': 'http401', 'url': '$base/e/401.ts', 'kind': 'http', 'code': 401},
      {'name': 'http500', 'url': '$base/e/500.ts', 'kind': 'http', 'code': 500},
      {'name': 'htmlPage', 'url': '$base/e/html.ts', 'kind': 'codec'},
      {
        'name': 'connectionRefused',
        'url': 'http://127.0.0.1:9/x.ts',
        'kind': 'network',
      },
      {
        'name': 'timeout',
        'url': '$base/e/slow.ts',
        'kind': 'timeout',
        'timeoutSec': 3,
      },
      {
        'name': 'liveRetryThen404',
        'url': '$base/e/live404.ts',
        'kind': 'http',
        'code': 404,
        'live': true,
        'retries': 3,
        'path': '/e/live404.ts',
      },
      if (tsBytes.isNotEmpty)
        {
          'name': 'liveDropEnded',
          'url': '$base/e/drop.ts',
          'kind': 'ended',
          'live': true,
          'retries': 2,
          'path': '/e/drop.ts',
        },
    ];
    final results = <Object?>[];
    for (final c in cases) {
      final name = c['name']! as String;
      _say('error case $name');
      final retries = (c['retries'] as int?) ?? 0;
      final engine = await _newEngine(
        EngineOptions(
          networkTimeoutSeconds: (c['timeoutSec'] as int?) ?? 15,
          reconnectAttempts: retries,
        ),
      );
      var maxAttempt = 0;
      final sub = engine.stateStream.listen((s) {
        maxAttempt = math.max(maxAttempt, s.reconnectAttempt);
      });
      final sw = Stopwatch()..start();
      final live = c['live'] == true;
      await engine.open(
        PlaybackSource(url: c['url']! as String, isLive: live, title: name),
      );
      EngineError? error;
      try {
        final s = await engine.stateStream
            .firstWhere((s) => s.error != null)
            .timeout(const Duration(seconds: 45));
        error = s.error;
      } on TimeoutException {
        error = engine.state.error;
      }
      final elapsed = sw.elapsedMilliseconds;
      await sub.cancel();
      final r = <String, Object?>{
        'name': name,
        'expectedKind': c['kind'],
        'expectedCode': c['code'],
        'kind': error?.kind.name,
        'statusCode': error?.statusCode,
        'message': error?.message,
        'detail': error?.detail,
        'elapsedMs': elapsed,
        'maxReconnectAttempt': maxAttempt,
        if (c['path'] != null) 'serverRequests': requests[c['path']],
      };
      final ok =
          error != null &&
          error.kind.name == c['kind'] &&
          (c['code'] == null || error.statusCode == c['code']) &&
          (retries == 0 ||
              (maxAttempt == retries &&
                  (requests[c['path']] ?? 0) >= retries + 1));
      r['pass'] = ok;
      if (!ok) {
        r['log'] = engine.recentLog;
        _failures.add('error case $name: got ${error?.kind.name}');
      }
      results.add(r);
      await _retire(engine);
    }
    for (final res in pending) {
      try {
        res.statusCode = 503;
        await res.close();
      } catch (_) {}
    }
    await server.close(force: true);
    _report['errors'] = results;
    _report['errorMapping'] = {
      'sampleMaskedUrl': maskUrlForLog(
        'http://provider.example:8080/live/user/secret/1001.ts?token=abc',
      ),
    };
  }

  static double _mb(int bytes) =>
      double.parse((bytes / (1024 * 1024)).toStringAsFixed(1));

  @override
  Widget build(BuildContext context) {
    final engine = _engine;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            if (engine != null)
              Positioned.fill(child: engine.buildVideo(key: ObjectKey(engine))),
            Positioned(
              left: 16,
              top: 16,
              right: 16,
              child: Text(
                _status,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  shadows: [Shadow(blurRadius: 4)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

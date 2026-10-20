import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/import/import.dart';
import '../../data/repositories/live_repository.dart';
import '../../data/repositories/stream_url_resolver.dart';
import '../../player/engine/playback_engine.dart';
import '../launch_options.dart';
import '../mock_seed.dart';

/// `--smoke-test`: adds the mock playlist headlessly, imports
/// it, plays three stream variants for ~5 s each through the real engine,
/// writes `smoke-result.json` (pass/fail, decode info, timings) and exits
/// with 0 or 1. CI runs it on Windows as a second gate.
class SmokeApp extends ConsumerStatefulWidget {
  const SmokeApp({super.key, required this.startedAt});

  /// Process start (for the cold-start timing).
  final DateTime startedAt;

  @override
  ConsumerState<SmokeApp> createState() => _SmokeAppState();
}

/// Channels from the mock fixtures: H.264/AAC, H.264/AC-3 5.1, HEVC/E-AC-3.
const kSmokeChannels = <String, String>{
  '1001': 'h264_aac',
  '1002': 'h264_ac3_51',
  '1003': 'hevc_eac3_2160p',
};

class _SmokeAppState extends ConsumerState<SmokeApp> {
  final List<String> _log = [];
  PlaybackEngine? _engine;
  final Map<String, Object?> _result = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_run()));
  }

  void _say(String line) {
    stdout.writeln('SMOKE $line');
    if (mounted) setState(() => _log.add(line));
  }

  Future<void> _run() async {
    final options = ref.read(launchOptionsProvider);
    final container = ProviderScope.containerOf(context);
    final firstFrame = DateTime.now();
    _result['coldStartMs'] = firstFrame
        .difference(widget.startedAt)
        .inMilliseconds;
    var pass = true;
    final watchdog = Timer(const Duration(minutes: 5), () {
      _result['error'] = 'watchdog: smoke test took longer than 5 minutes';
      unawaited(_finish(false));
    });
    try {
      await _waitForServer(options.mockUrl);
      final seeded = await ensureMockPlaylist(container, options.mockUrl);
      final pid = seeded.playlistId;
      _say('playlist $pid (created: ${seeded.created})');

      final importStart = DateTime.now();
      final progress = await ref
          .read(importServiceProvider)
          .run(pid, scope: ImportScope.all);
      final importMs = DateTime.now().difference(importStart).inMilliseconds;
      _result['import'] = {
        'ok': progress.succeeded,
        'ms': importMs,
        'live': progress.countOf(ImportStep.liveChannels),
        'movies': progress.countOf(ImportStep.movies),
        'series': progress.countOf(ImportStep.series),
        'programmes': progress.countOf(ImportStep.epgParsing),
        'epgError': progress.epgError?.toString(),
        'error': progress.error?.toString(),
      };
      _say('import ${progress.step.name} in $importMs ms');
      if (!progress.succeeded) pass = false;

      final factory = ref.read(playbackEngineFactoryProvider);
      final engine = factory.create(options: const EngineOptions(muted: true));
      setState(() => _engine = engine);
      final streams = <Map<String, Object?>>[];
      for (final entry in kSmokeChannels.entries) {
        final r = await _playOne(pid, entry.key, entry.value, engine);
        streams.add(r);
        if (r['pass'] != true) pass = false;
      }
      _result['streams'] = streams;
    } catch (e, st) {
      _result['error'] = '$e';
      _result['stack'] = '$st'.split('\n').take(8).join('\n');
      pass = false;
    }
    watchdog.cancel();
    await _finish(pass);
  }

  Future<void> _waitForServer(String base) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
    final deadline = DateTime.now().add(const Duration(seconds: 60));
    while (true) {
      try {
        final req = await client.getUrl(Uri.parse('$base/mock/health'));
        final res = await req.close();
        await res.drain<void>();
        if (res.statusCode == 200) {
          client.close();
          return;
        }
      } catch (_) {
        // not up yet
      }
      if (DateTime.now().isAfter(deadline)) {
        client.close();
        throw StateError('mock server not reachable at $base');
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  }

  Future<Map<String, Object?>> _playOne(
    int pid,
    String channelId,
    String label,
    PlaybackEngine engine,
  ) async {
    final out = <String, Object?>{'channel': channelId, 'variant': label};
    final channel = await ref
        .read(liveRepositoryProvider)
        .channel(pid, channelId);
    if (channel == null) {
      out['pass'] = false;
      out['error'] = 'channel not found';
      return out;
    }
    final stream = await ref
        .read(streamUrlResolverProvider)
        .live(pid, channel.row);
    out['url'] = stream.maskedUrl;
    final opened = DateTime.now();
    await engine.open(
      PlaybackSource(
        url: stream.url,
        headers: stream.headers,
        userAgent: stream.userAgent,
        referer: stream.referer,
        isLive: true,
        title: channel.displayName,
      ),
    );
    int? firstFrameMs;
    final deadline = opened.add(const Duration(seconds: 40));
    while (DateTime.now().isBefore(deadline)) {
      if (engine.state.width > 0) {
        firstFrameMs = DateTime.now().difference(opened).inMilliseconds;
        break;
      }
      if (engine.state.error != null) break;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    out['firstFrameMs'] = firstFrameMs;
    final startPos = engine.state.position;
    await Future<void>.delayed(const Duration(seconds: 5));
    final audioCodec = await engine.getProperty('audio-codec-name');
    final channels = await engine.getProperty('audio-params/channel-count');
    final videoCodec = await engine.getProperty('video-codec');
    final hwdec = await engine.getProperty('hwdec-current');
    out['videoCodec'] = videoCodec;
    out['width'] = engine.state.width;
    out['height'] = engine.state.height;
    out['audioCodec'] = audioCodec;
    out['audioChannels'] = channels;
    out['hwdec'] = hwdec;
    out['advancedMs'] = (engine.state.position - startPos).inMilliseconds;
    out['error'] = engine.state.error?.message;
    final ok =
        firstFrameMs != null &&
        engine.state.width > 0 &&
        (audioCodec ?? '').isNotEmpty;
    out['pass'] = ok;
    _say(
      '$label: ${ok ? 'PASS' : 'FAIL'} ${engine.state.width}x'
      '${engine.state.height} $videoCodec / $audioCodec ($channels ch) '
      'first frame ${firstFrameMs ?? '-'} ms',
    );
    await engine.stop();
    return out;
  }

  Future<void> _finish(bool pass) async {
    _result['pass'] = pass;
    _result['platform'] = Platform.operatingSystem;
    _result['finishedAt'] = DateTime.now().toIso8601String();
    final options = ref.read(launchOptionsProvider);
    final path = options.smokeOut ?? 'smoke-result.json';
    await File(path)
        .writeAsString(const JsonEncoder.withIndent('  ').convert(_result));
    _say('result ${pass ? 'PASS' : 'FAIL'} → $path');
    await _engine?.dispose();
    exit(pass ? 0 : 1);
  }

  @override
  Widget build(BuildContext context) {
    final engine = _engine;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Row(
          children: [
            Expanded(
              child: engine == null
                  ? const SizedBox.shrink()
                  : engine.buildVideo(),
            ),
            SizedBox(
              width: 420,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Carina smoke test',
                    style: TextStyle(color: Colors.white, fontSize: 20),
                  ),
                  for (final line in _log)
                    Text(line, style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

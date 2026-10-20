// Carina mock IPTV server.
//
//   dart run tools/mock_server/bin/mock_server.dart --port 8787 --scale small
//
// Serves a deterministic Xtream Codes catalog, live/VOD/catch-up streams
// from the generated test media, XMLTV, M3U and failure endpoints.
import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';

import '../src/server.dart';

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption(
      'port',
      abbr: 'p',
      defaultsTo: '8787',
      help: 'TCP port (0 = any free port).',
    )
    ..addOption(
      'scale',
      abbr: 's',
      defaultsTo: 'small',
      allowed: [for (final s in MockScale.values) s.name],
      help: 'Catalog size: small (300/2k/200) or large (20k/60k/8k).',
    )
    ..addOption(
      'media',
      abbr: 'm',
      help: 'Media directory (default: tools/mock_server/media).',
    )
    ..addOption(
      'live',
      abbr: 'l',
      help: 'Live HLS directory (default: <media>/../live).',
    )
    ..addOption(
      'host',
      defaultsTo: '127.0.0.1',
      help: 'Address to bind (0.0.0.0 for the LAN).',
    )
    ..addOption(
      'burst',
      defaultsTo: '2',
      help:
          'Seconds of live TS sent at once before real-time pacing. Players '
          'that analyze 5 s of a stream (ffmpeg/mpv defaults) start faster '
          'with a larger burst.',
    )
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this help.');

  final ArgResults args;
  try {
    args = parser.parse(arguments);
  } on FormatException catch (e) {
    stderr
      ..writeln(e.message)
      ..writeln(parser.usage);
    exitCode = 64;
    return;
  }
  if (args.flag('help')) {
    stdout
      ..writeln('Carina mock IPTV server')
      ..writeln(parser.usage);
    return;
  }

  final port = int.tryParse(args.option('port')!);
  if (port == null || port < 0 || port > 65535) {
    stderr.writeln('Invalid --port: ${args.option('port')}');
    exitCode = 64;
    return;
  }
  final burst = double.tryParse(args.option('burst')!);
  if (burst == null || burst < 0 || burst > 60) {
    stderr.writeln('Invalid --burst: ${args.option('burst')} (seconds, 0-60)');
    exitCode = 64;
    return;
  }
  final scale = MockScale.values.byName(args.option('scale')!);
  final mediaDir = args.option('media') ?? _defaultMediaDir();
  final liveDir = args.option('live');
  final host = args.option('host')!;
  final address =
      InternetAddress.tryParse(host) ??
      (host == 'localhost' ? InternetAddress.loopbackIPv4 : null);
  if (address == null) {
    stderr.writeln(
      'Invalid --host: $host (use an IP address such as 127.0.0.1 or 0.0.0.0)',
    );
    exitCode = 64;
    return;
  }

  final watch = Stopwatch()..start();
  final MockServer server;
  try {
    server = await MockServer.start(
      port: port,
      scale: scale,
      mediaDir: mediaDir,
      liveDir: liveDir,
      address: address,
      liveBurst: Duration(milliseconds: (burst * 1000).round()),
    );
  } on SocketException catch (e) {
    stderr.writeln('Could not listen on $host:$port: ${e.message}');
    exitCode = 1;
    return;
  }

  final c = server.catalog;
  stdout.writeln(
    'Carina mock server: ${scale.name} catalog (${c.channels.length} live, '
    '${c.movies.length} movies, ${c.series.length} series, '
    '${c.epgChannels.length} guide channels) ready in ${watch.elapsedMilliseconds} ms',
  );
  final missing = [
    for (final f in MockMedia.allFiles)
      if (!server.media.file(f).existsSync()) f,
  ];
  stdout.writeln(
    missing.isEmpty
        ? 'Media: ${server.media.mediaDir} (all ${MockMedia.allFiles.length} files present)'
        : 'Media: ${server.media.mediaDir} (missing: ${missing.join(', ')}; those streams return 404)',
  );
  final hls = server.media.hlsStatus();
  stdout.writeln(
    'Live HLS: ${hls.path} (${hls.fresh
        ? 'running'
        : hls.exists
        ? 'stale'
        : 'not running'})',
  );
  if (address == InternetAddress.anyIPv4 ||
      address == InternetAddress.anyIPv6) {
    stdout.writeln(
      'Bound to all interfaces; use this machine\'s LAN address from other devices.',
    );
  }
  stdout.writeln('Mock server listening on ${server.baseUrl}');

  final done = Completer<void>();
  Future<void> shutdown(ProcessSignal signal) async {
    if (done.isCompleted) return;
    stdout.writeln('Stopping mock server (${signal.name})...');
    await server.stop();
    done.complete();
  }

  final subscriptions = <StreamSubscription<ProcessSignal>>[
    ProcessSignal.sigint.watch().listen(shutdown),
    // Windows has no SIGTERM.
    if (!Platform.isWindows) ProcessSignal.sigterm.watch().listen(shutdown),
  ];
  await done.future;
  for (final s in subscriptions) {
    await s.cancel();
  }
  exit(0);
}

/// `tools/mock_server/media` next to this script, or relative to the
/// working directory when the script location is unknown.
String _defaultMediaDir() {
  final script = Platform.script;
  if (script.scheme == 'file' && script.path.endsWith('.dart')) {
    final binDir = File.fromUri(script).parent;
    return '${binDir.parent.path}${Platform.pathSeparator}media';
  }
  return 'tools${Platform.pathSeparator}mock_server${Platform.pathSeparator}media';
}

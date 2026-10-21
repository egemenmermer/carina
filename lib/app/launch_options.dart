import 'package:args/args.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Command-line flags.
///
/// - `--smoke-test` adds the mock playlist headlessly, plays three streams,
///   writes `--smoke-out` (default `smoke-result.json`) and exits 0/1.
/// - `--capture <dir>` walks a fixed list of screens and saves PNGs.
/// - `--mock` / `--mock-url <url>` adds the local mock Xtream playlist on
///   first start (default `http://127.0.0.1:8787`).
/// - `--data-dir <dir>` uses a separate profile folder.
/// - `--tv` forces the Android TV form factor on desktop (screenshots, dev).
/// - `--probe --media <path> [--probe-out <json>]` is the M0 decode probe.
class LaunchOptions {
  const LaunchOptions({
    this.smokeTest = false,
    this.smokeOut,
    this.captureDir,
    this.mock = false,
    this.mockUrl = defaultMockUrl,
    this.dataDir,
    this.probe = false,
    this.tv = false,
    this.probeMedia,
    this.probeOut,
  });

  static const defaultMockUrl = 'http://127.0.0.1:8787';

  /// The M0 decode probe flag (the Windows CI looks for this literal).
  static const probeFlag = '--probe';

  final bool smokeTest;
  final String? smokeOut;
  final String? captureDir;
  final bool mock;
  final String mockUrl;
  final String? dataDir;
  final bool probe;
  final bool tv;
  final String? probeMedia;
  final String? probeOut;

  bool get capture => captureDir != null;

  /// Smoke and capture runs need the mock playlist.
  bool get wantsMockPlaylist => mock || smokeTest || capture;

  static const _flags = {'smoke-test', 'mock', 'probe', 'tv'};
  static const _options = {
    'smoke-out',
    'capture',
    'mock-url',
    'data-dir',
    'media',
    'probe-out',
  };

  static LaunchOptions parse(List<String> args) {
    // Keep only our own flags: the OS or the Flutter tool may pass others
    // (e.g. `-NSDocumentRevisionsDebugMode YES` on macOS).
    final known = <String>[];
    for (var i = 0; i < args.length; i++) {
      final a = args[i];
      if (!a.startsWith('--')) continue;
      final name = a.substring(2).split('=').first;
      if (_flags.contains(name)) {
        known.add(a);
      } else if (_options.contains(name)) {
        known.add(a);
        if (!a.contains('=') && i + 1 < args.length) known.add(args[++i]);
      }
    }
    final parser = ArgParser()
      ..addFlag('smoke-test', negatable: false)
      ..addOption('smoke-out')
      ..addOption('capture')
      ..addFlag('mock', negatable: false)
      ..addOption('mock-url')
      ..addOption('data-dir')
      ..addFlag('probe', negatable: false)
      ..addFlag('tv', negatable: false)
      ..addOption('media')
      ..addOption('probe-out');
    final ArgResults r;
    try {
      r = parser.parse(known);
    } on FormatException {
      return const LaunchOptions();
    }
    final mockUrl = r['mock-url'] as String?;
    return LaunchOptions(
      smokeTest: r['smoke-test'] as bool,
      smokeOut: r['smoke-out'] as String?,
      captureDir: r['capture'] as String?,
      mock: (r['mock'] as bool) || mockUrl != null,
      mockUrl: mockUrl ?? defaultMockUrl,
      dataDir: r['data-dir'] as String?,
      probe: r['probe'] as bool,
      tv: r['tv'] as bool,
      probeMedia: r['media'] as String?,
      probeOut: r['probe-out'] as String?,
    );
  }
}

final launchOptionsProvider = Provider<LaunchOptions>(
  (ref) => const LaunchOptions(),
);

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:intl/date_symbol_data_local.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:media_kit/media_kit.dart';

import '../core/core.dart';
import '../data/app_paths.dart';
import '../data/db/database.dart';
import '../data/secrets/secret_store.dart';
import '../data/settings/settings_store.dart';
import 'app.dart';
import 'capture/capture_runner.dart';
import 'launch_options.dart';
import 'mock_seed.dart';
import 'platform/form_factor.dart';
import 'probe/m0_probe_app.dart';
import 'router.dart';
import 'smoke/smoke_runner.dart';
import 'window_setup.dart';

/// Windows AppUserModelID (matches the installer shortcuts, see DECISIONS).
const kAppUserModelId = 'Carina.Carina';

/// Everything the app needs before the first frame.
class AppContext {
  AppContext({
    required this.options,
    required this.paths,
    required this.db,
    required this.settings,
    required this.secrets,
    this.formFactor = FormFactor.desktop,
  });

  final LaunchOptions options;
  final AppPaths paths;
  final AppDatabase db;
  final SettingsStore settings;
  final SecretStore secrets;
  final FormFactor formFactor;

  List<Override> get overrides => [
    launchOptionsProvider.overrideWithValue(options),
    appPathsProvider.overrideWithValue(paths),
    appDatabaseProvider.overrideWithValue(db),
    settingsStoreProvider.overrideWithValue(settings),
    secretStoreProvider.overrideWithValue(secrets),
    formFactorProvider.overrideWithValue(formFactor),
  ];
}

/// Hooks filled in by later milestones (mock playlist seeding, smoke test,
/// capture). They receive the container after the app is running.
typedef PostLaunchHook = Future<void> Function(ProviderContainer container);

final List<PostLaunchHook> postLaunchHooks = [];

Future<void> bootstrap(List<String> args) async {
  final startedAt = DateTime.now();
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  final options = LaunchOptions.parse(args);

  if (options.probe && options.probeMedia != null) {
    runApp(
      M0App(media: options.probeMedia, probe: true, probeOut: options.probeOut),
    );
    return;
  }

  await initializeDateFormatting('en');
  await initializeDateFormatting('tr');

  final paths = await AppPaths.resolve(override: options.dataDir);
  KImageLoader.instance = KImageLoader(
    cacheDirectory: () async => Directory(paths.imageCache),
  );
  final db = AppDatabase.open(paths.database);
  final settings = SettingsStore(db);
  await settings.load();
  final secrets = PlatformSecretStore(fallbackDir: paths.root);
  final ctx = AppContext(
    options: options,
    paths: paths,
    db: db,
    settings: settings,
    secrets: secrets,
    formFactor: await resolveFormFactor(forceTv: options.tv),
  );

  await WindowSetup(settings).init(
    fullscreen: settings.get(AppSettings.startFullscreen) && !options.capture,
    forceSize: options.capture ? kDefaultWindowSize : null,
  );

  if (Platform.isWindows || Platform.isMacOS) {
    try {
      await localNotifier.setup(
        appName: kAppUserModelId,
        shortcutPolicy: ShortcutPolicy.ignore,
      );
    } catch (e) {
      debugPrint('Notifications unavailable: $e');
    }
  }

  if (options.smokeTest) {
    runApp(
      UncontrolledProviderScope(
        container: ProviderContainer(overrides: ctx.overrides),
        child: SmokeApp(startedAt: startedAt),
      ),
    );
    return;
  }

  final initialLocation = await resolveInitialLocation(ctx);
  final container = ProviderContainer(
    overrides: [
      ...ctx.overrides,
      initialLocationProvider.overrideWithValue(initialLocation),
    ],
  );
  runApp(
    UncontrolledProviderScope(container: container, child: const CarinaApp()),
  );
  if (options.capture) {
    unawaited(CaptureRunner(container, options.captureDir!).run());
  }
  if (options.mock && !options.capture) {
    unawaited(_seedMockPlaylist(container, options.mockUrl));
  }
  for (final hook in postLaunchHooks) {
    unawaited(hook(container));
  }
}

/// `--mock`: adds the mock playlist on first start and shows its import.
Future<void> _seedMockPlaylist(ProviderContainer c, String mockUrl) async {
  try {
    final seeded = await ensureMockPlaylist(c, mockUrl);
    if (seeded.created) {
      c.read(routerProvider).go(Routes.importPlaylist(seeded.playlistId));
    }
  } catch (e) {
    debugPrint('Mock playlist seeding failed: $e');
  }
}

/// Start screen: the Playlist Manager, or the last playlist when
/// "Auto-open last playlist" is on.
Future<String> resolveInitialLocation(AppContext ctx) async {
  if (ctx.options.smokeTest || ctx.options.capture) return Routes.manager;
  if (!ctx.settings.get(AppSettings.autoOpenLastPlaylist)) {
    return Routes.manager;
  }
  final last = ctx.settings.get(AppSettings.lastPlaylistId);
  if (last == null) return Routes.manager;
  final row = await (ctx.db.select(
    ctx.db.playlists,
  )..where((p) => p.id.equals(last))).getSingleOrNull();
  if (row == null || row.hasAccessPin) return Routes.manager;
  return initialTabLocation(ctx.settings, last);
}

/// The playlist's configured initial tab (`last` = the tab used last time).
String initialTabLocation(SettingsStore settings, int playlistId) {
  var tab = settings.get(PlaylistSettings.initialTab, playlistId: playlistId);
  if (tab == 'last') {
    tab =
        settings.get(PlaylistSettings.lastTab, playlistId: playlistId) ??
        'live';
  }
  final mainTab = MainTabPath.fromSegment(tab) ?? MainTab.live;
  return Routes.tab(playlistId, mainTab);
}

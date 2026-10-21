import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_paths.dart';
import '../../data/db/database.dart';
import '../../data/import/import.dart';
import '../router.dart';

/// The playlist row behind the shell (name, avatar, section counts).
final shellPlaylistProvider = StreamProvider.family<PlaylistRow?, int>((
  ref,
  pid,
) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(
    db.playlists,
  )..where((p) => p.id.equals(pid))).watchSingleOrNull();
});

/// All playlists, for the avatar "Switch playlist" menu.
final shellPlaylistsProvider = StreamProvider<List<PlaylistRow>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.playlists)..orderBy([
        (p) => OrderingTerm(expression: p.sortIndex),
        (p) => OrderingTerm(expression: p.id),
      ]))
      .watch();
});

/// Which main tab a location belongs to (null for search/settings/etc.).
MainTab? tabForLocation(String location) {
  final segments = Uri.parse(location).pathSegments;
  if (segments.length < 3 || segments.first != 'p') return null;
  return MainTabPath.fromSegment(segments[2]);
}

/// The playlist's home tab, where the remote's Back leads inside the shell:
/// the configured initial tab when it is a visible tab, else TV Live, else
/// the first visible tab (null when no tab is visible).
MainTab? shellHomeTab(String initialTab, List<MainTab> visible) {
  final configured = MainTabPath.fromSegment(initialTab);
  if (configured != null && visible.contains(configured)) return configured;
  if (visible.contains(MainTab.live)) return MainTab.live;
  return visible.isEmpty ? null : visible.first;
}

/// Where the remote's Back goes from [location] (a path) in the shell of
/// playlist [pid]: a "See All" grid or a settings section goes up to its
/// page, any other page to the [home] tab, and the home tab to the
/// Playlist Manager.
String shellBackLocation(String location, {required int pid, MainTab? home}) {
  final segments = Uri.parse(location).pathSegments;
  if (segments.length > 3) return '/${segments.take(3).join('/')}';
  final homeLocation = home == null ? null : Routes.tab(pid, home);
  if (homeLocation == null || location == homeLocation) return Routes.manager;
  return homeLocation;
}

/// Whether the category sidebar is open (one sidebar for the shell).
final categorySidebarOpenProvider = NotifierProvider<_SidebarOpen, bool>(
  _SidebarOpen.new,
);

class _SidebarOpen extends Notifier<bool> {
  @override
  bool build() => false;

  void open() => state = true;
  void close() => state = false;
  void toggle() => state = !state;
}

/// Latest background-import progress of a playlist for the top-bar chip.
/// Wired to `ImportService.watch` once the import pipeline lands.
final shellImportProgressProvider = StreamProvider.family<ImportProgress?, int>(
  (ref, pid) => Stream<ImportProgress?>.value(null),
);

/// Rough overall progress of an import for the chip (0..1).
double importFraction(ImportProgress p) {
  final bytes = p.byteFraction;
  if (bytes != null && p.step == ImportStep.epgDownloading) return bytes;
  final total = ImportStep.values.length - 3; // minus terminal states
  return (p.stepIndex / total).clamp(0, 1).toDouble();
}

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

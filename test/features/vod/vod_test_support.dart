/// Shared setup of the Movies & Shows widget and screenshot tests: the
/// real mock import, artwork from the generated mock media (so screenshots
/// show real posters and backdrops), prefetched provider details, seeded
/// watch state / favorites, and a recording player launcher.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:carina/app/clock.dart';
import 'package:carina/core/images/k_network_image.dart';
import 'package:carina/data/db/database.dart';
import 'package:carina/data/repositories/favorites_repository.dart';
import 'package:carina/data/repositories/vod_repository.dart';
import 'package:carina/data/repositories/watch_state_repository.dart';
import 'package:carina/features/home_movies/data/vod_providers.dart';
import 'package:carina/player/engine/fake_engine.dart';
import 'package:carina/player/engine/playback_engine.dart';
import 'package:carina/player/player_api.dart';

import '../../support/mock_import.dart';

export '../../support/mock_import.dart';

/// Records play requests instead of opening the player.
class RecordingLauncher extends VodPlayerLauncher {
  RecordingLauncher();

  final List<VodPlayRequest> requests = [];

  @override
  Future<void> open(BuildContext context, VodPlayRequest request) async {
    requests.add(request);
  }
}

/// Serves `/img/<name>` URLs from `tools/mock_server/media/img` (generated
/// by `tools/gen_media.sh`); other URLs fail like a missing image. Call in
/// `setUp`; it resets itself in `tearDown`.
void useMockArtwork() {
  final dir = Directory('tools/mock_server/media/img');
  KImageLoader.debugFetchOverride = (url) async {
    final name = Uri.parse(url).pathSegments.last;
    final file = File('${dir.path}/$name');
    if (!dir.existsSync() || !file.existsSync()) {
      throw KImageLoadException('no mock artwork for $name');
    }
    return Uint8List.fromList(await file.readAsBytes());
  };
  addTearDown(() => KImageLoader.debugFetchOverride = null);
}

/// Provider overrides for VOD screens on top of the fixture's.
List<Override> vodOverrides(
  MockImportFixture fx, {
  VodPlayerLauncher? launcher,
  DateTime? now,
}) {
  final clock = now ?? DateTime.now();
  return [
    ...fx.providerOverrides,
    minuteClockProvider.overrideWith((ref) => Stream.value(clock)),
    playbackEngineFactoryProvider.overrideWithValue(FakeEngineFactory()),
    vodPlayerLauncherProvider.overrideWithValue(
      launcher ?? RecordingLauncher(),
    ),
  ];
}

/// Real `HttpClient`s even inside `testWidgets` (whose binding mocks HTTP).
class _RealHttp extends HttpOverrides {}

/// Runs [body] with real HTTP (for the repository's lazy detail fetches).
Future<T> withRealHttp<T>(Future<T> Function() body) =>
    HttpOverrides.runWithHttpOverrides(body, _RealHttp());

/// What [seedVodLibrary] wrote.
class VodSeed {
  VodSeed({
    required this.continueMovies,
    required this.favoriteMovies,
    required this.watchedMovies,
    required this.continueSeries,
    required this.favoriteSeries,
  });

  final List<String> continueMovies;
  final List<String> favoriteMovies;
  final List<String> watchedMovies;
  final List<String> continueSeries;
  final List<String> favoriteSeries;
}

/// Seeds Continue watching, Favorites and watched flags, and fetches the
/// provider details (`get_vod_info` / `get_series_info`) that the hero and
/// sheets show, through real HTTP so the cached rows are in the database.
/// Call inside `tester.runAsync`.
Future<VodSeed> seedVodLibrary(MockImportFixture fx) async {
  final pid = fx.playlistId;
  final vod = VodRepository(
    db: fx.db,
    settings: fx.settings,
    secrets: fx.secrets,
  );
  try {
    final movies = await _ids(fx, 'movies');
    final series = await _ids(fx, 'series');
    const kis = '${MockFixtures.kisUykusu}';
    const sicak = '${MockFixtures.sicakKafa}';
    const gece = '${MockFixtures.geceYarisi}';
    const mavi = '${MockFixtures.maviKapi}';

    final heroMovies = await vod.heroCandidates(pid, SectionKind.movie);
    final heroSeries = await vod.heroCandidates(pid, SectionKind.series);
    final continueMovies = [movies[3], movies[7], movies[11], kis];
    final favoriteMovies = [kis, ...movies.skip(14).take(9)];
    final watchedMovies = [movies[15], movies[17]];
    final continueSeries = [mavi, gece, sicak];
    final favoriteSeries = [sicak, ...series.skip(4).take(7)];

    await withRealHttp(() async {
      for (final id in {
        ...continueMovies,
        ...favoriteMovies.take(3),
        for (final h in heroMovies.take(4)) h.providerId,
      }) {
        await vod.movieDetails(pid, id);
      }
      for (final id in {
        ...continueSeries,
        for (final h in heroSeries.take(4)) h.providerId,
      }) {
        await vod.seriesDetails(pid, id);
      }
    });

    var t = DateTime.now().subtract(const Duration(hours: 6));
    DateTime clock() => t = t.add(const Duration(minutes: 7));
    final watch = WatchStateRepository(
      db: fx.db,
      settings: fx.settings,
      clock: clock,
    );
    final fav = FavoritesRepository(
      db: fx.db,
      settings: fx.settings,
      clock: clock,
    );

    const progress = [0.62, 0.25, 0.81, 0.38];
    for (var i = 0; i < continueMovies.length; i++) {
      final details = await vod.movieDetails(pid, continueMovies[i]);
      final duration = details?.duration ?? const Duration(minutes: 104);
      await watch.save(
        pid,
        ItemType.movie,
        continueMovies[i],
        duration * progress[i],
        duration,
      );
    }
    for (final id in watchedMovies) {
      await watch.setWatched(pid, ItemType.movie, id, true);
    }
    for (final id in favoriteMovies.reversed) {
      await fav.add(pid, ItemType.movie, id);
    }

    // Shows: Mavi Kapı S1E3 (oldest), Gece Yarısı S1E1, Sıcak Kafa S1E2
    // (most recent: first in the row) with S1E1 watched.
    const seriesProgress = [0.55, 0.2, 0.3];
    for (var i = 0; i < continueSeries.length; i++) {
      final sid = continueSeries[i];
      final episodes = await vod.episodes(pid, sid);
      if (episodes.isEmpty) continue;
      final regular = episodes.where((e) => e.season > 0).toList();
      final pick = regular.length > 2
          ? (sid == sicak ? regular[1] : regular[sid == mavi ? 2 : 0])
          : regular.first;
      if (sid == sicak) {
        await watch.setWatched(
          pid,
          ItemType.episode,
          regular.first.providerId,
          true,
          seriesId: sid,
        );
      }
      final duration = pick.duration ?? const Duration(minutes: 45);
      await watch.save(
        pid,
        ItemType.episode,
        pick.providerId,
        duration * seriesProgress[i],
        duration,
        seriesId: sid,
      );
    }
    for (final id in favoriteSeries.reversed) {
      await fav.add(pid, ItemType.series, id);
    }
    return VodSeed(
      continueMovies: continueMovies,
      favoriteMovies: favoriteMovies,
      watchedMovies: watchedMovies,
      continueSeries: continueSeries,
      favoriteSeries: favoriteSeries,
    );
  } finally {
    vod.dispose();
  }
}

/// Provider ids of the visible movies / series in provider order (only
/// items with a poster).
Future<List<String>> _ids(MockImportFixture fx, String table) async {
  final art = table == 'series' ? 'cover' : 'poster';
  final rows = await fx.db
      .customSelect(
        'SELECT provider_id FROM $table WHERE playlist_id = ? '
        "AND $art IS NOT NULL AND $art != '' AND name != '' "
        'ORDER BY sort_index, id LIMIT 60',
        variables: [Variable.withInt(fx.playlistId)],
      )
      .get();
  return [for (final r in rows) r.read<String>('provider_id')];
}

/// Fetches details through real HTTP (e.g. before opening a sheet).
Future<void> prefetchDetails(
  MockImportFixture fx, {
  List<String> movies = const [],
  List<String> series = const [],
}) async {
  final vod = VodRepository(
    db: fx.db,
    settings: fx.settings,
    secrets: fx.secrets,
  );
  try {
    await withRealHttp(() async {
      for (final id in movies) {
        await vod.movieDetails(fx.playlistId, id);
      }
      for (final id in series) {
        await vod.seriesDetails(fx.playlistId, id);
      }
    });
  } finally {
    vod.dispose();
  }
}

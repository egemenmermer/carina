import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/db/tables.dart';
import '../features/downloads/downloads_screen.dart';
import '../features/guide/guide_screen.dart';
import '../features/home_movies/category_grid_screen.dart';
import '../features/home_movies/movies_home_screen.dart';
import '../features/home_shows/shows_home_screen.dart';
import '../features/live/live_screen.dart';
import '../features/multiview/multiview_screen.dart';
import '../features/playlists/avatar_picker_screen.dart';
import '../features/playlists/import_progress_screen.dart';
import '../features/playlists/playlist_manager_screen.dart';
import '../features/playlists/playlist_wizard_screen.dart';
import '../features/search/search_screen.dart';
import '../features/settings/settings_screen.dart';
import 'shell/playlist_shell.dart';

/// Main tabs of a playlist, in nav order.
enum MainTab { movies, shows, live, guide }

extension MainTabPath on MainTab {
  String get segment => switch (this) {
    MainTab.movies => 'movies',
    MainTab.shows => 'shows',
    MainTab.live => 'live',
    MainTab.guide => 'guide',
  };

  static MainTab? fromSegment(String? s) => switch (s) {
    'movies' => MainTab.movies,
    'shows' => MainTab.shows,
    'live' => MainTab.live,
    'guide' => MainTab.guide,
    _ => null,
  };
}

/// Route helpers so features never hand-build paths.
abstract final class Routes {
  static const manager = '/';
  static const newPlaylist = '/playlists/new';
  static String editPlaylist(int pid) => '/playlists/$pid/edit';
  static String importPlaylist(int pid) => '/playlists/$pid/import';
  static String avatar(int pid) => '/playlists/$pid/avatar';
  static String tab(int pid, MainTab tab) => '/p/$pid/${tab.segment}';
  static String search(int pid) => '/p/$pid/search';
  static String playlistSettings(int pid, [String? section]) =>
      section == null ? '/p/$pid/settings' : '/p/$pid/settings/$section';
  static String appSettings([String? section]) =>
      section == null ? '/settings' : '/settings/$section';
  static String seeAll(int pid, String section, String categoryId) =>
      '/p/$pid/$section/category/${Uri.encodeComponent(categoryId)}';
  static String multiview(int pid) => '/p/$pid/multiview';
  static const downloads = '/downloads';
}

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

/// The initial location is decided at bootstrap (auto-open last playlist,
/// capture mode…).
final initialLocationProvider = Provider<String>((ref) => Routes.manager);

final routerProvider = Provider<GoRouter>((ref) {
  int pid(GoRouterState s) => int.parse(s.pathParameters['pid']!);
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: ref.watch(initialLocationProvider),
    routes: [
      GoRoute(
        path: '/',
        pageBuilder: (c, s) => _fade(s, const PlaylistManagerScreen()),
      ),
      GoRoute(
        path: '/playlists/new',
        pageBuilder: (c, s) => _fade(
          s,
          PlaylistWizardScreen(
            initialType: switch (s.uri.queryParameters['type']) {
              'xtream' => PlaylistType.xtream,
              'm3u' => PlaylistType.m3u,
              'm3uFile' => PlaylistType.m3uFile,
              _ => null,
            },
          ),
        ),
      ),
      GoRoute(
        path: '/playlists/:pid/edit',
        pageBuilder: (c, s) =>
            _fade(s, PlaylistWizardScreen(playlistId: pid(s))),
      ),
      GoRoute(
        path: '/playlists/:pid/import',
        pageBuilder: (c, s) =>
            _fade(s, ImportProgressScreen(playlistId: pid(s))),
      ),
      GoRoute(
        path: '/playlists/:pid/avatar',
        pageBuilder: (c, s) => _fade(s, AvatarPickerScreen(playlistId: pid(s))),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (c, s) => _fade(s, const SettingsScreen()),
        routes: [
          GoRoute(
            path: ':section',
            pageBuilder: (c, s) =>
                _fade(s, SettingsScreen(section: s.pathParameters['section'])),
          ),
        ],
      ),
      GoRoute(
        path: '/downloads',
        pageBuilder: (c, s) => _fade(s, const DownloadsScreen()),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        pageBuilder: (c, s, child) => _fade(
          s,
          PlaylistShell(playlistId: pid(s), location: s.uri.path, child: child),
          key: const ValueKey('shell'),
        ),
        routes: [
          GoRoute(
            path: '/p/:pid/movies',
            pageBuilder: (c, s) =>
                _fade(s, MoviesHomeScreen(playlistId: pid(s))),
            routes: [
              GoRoute(
                path: 'category/:cid',
                pageBuilder: (c, s) => _fade(
                  s,
                  CategoryGridScreen(
                    playlistId: pid(s),
                    section: 'movies',
                    categoryId: s.pathParameters['cid']!,
                  ),
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/p/:pid/shows',
            pageBuilder: (c, s) =>
                _fade(s, ShowsHomeScreen(playlistId: pid(s))),
            routes: [
              GoRoute(
                path: 'category/:cid',
                pageBuilder: (c, s) => _fade(
                  s,
                  CategoryGridScreen(
                    playlistId: pid(s),
                    section: 'shows',
                    categoryId: s.pathParameters['cid']!,
                  ),
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/p/:pid/live',
            pageBuilder: (c, s) => _fade(s, LiveScreen(playlistId: pid(s))),
          ),
          GoRoute(
            path: '/p/:pid/guide',
            pageBuilder: (c, s) => _fade(s, GuideScreen(playlistId: pid(s))),
          ),
          GoRoute(
            path: '/p/:pid/search',
            pageBuilder: (c, s) => _fade(
              s,
              SearchScreen(
                playlistId: pid(s),
                initialQuery: s.uri.queryParameters['q'],
                initialPerson: s.uri.queryParameters['person'],
              ),
            ),
          ),
          GoRoute(
            path: '/p/:pid/settings',
            pageBuilder: (c, s) => _fade(s, SettingsScreen(playlistId: pid(s))),
            routes: [
              GoRoute(
                path: ':section',
                pageBuilder: (c, s) => _fade(
                  s,
                  SettingsScreen(
                    playlistId: pid(s),
                    section: s.pathParameters['section'],
                  ),
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/p/:pid/multiview',
            pageBuilder: (c, s) =>
                _fade(s, MultiviewScreen(playlistId: pid(s))),
          ),
        ],
      ),
    ],
  );
});

Page<void> _fade(GoRouterState s, Widget child, {LocalKey? key}) {
  return CustomTransitionPage<void>(
    key: key ?? s.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 180),
    reverseTransitionDuration: const Duration(milliseconds: 120),
    transitionsBuilder: (context, animation, secondary, child) {
      if (MediaQuery.of(context).disableAnimations) return child;
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

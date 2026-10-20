import 'package:flutter/material.dart';

import '../../data/db/database.dart';
import 'widgets/vod_home_view.dart';

/// Movies tab: hero, Continue watching, Favorites, Recently
/// added, Trending (with TMDb) and one row per provider category; a
/// sidebar category shows its poster grid instead (see [VodHomeView]).
class MoviesHomeScreen extends StatelessWidget {
  const MoviesHomeScreen({super.key, required this.playlistId});
  final int playlistId;

  @override
  Widget build(BuildContext context) =>
      VodHomeView(playlistId: playlistId, kind: SectionKind.movie);
}

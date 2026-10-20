import 'package:flutter/material.dart';

import '../../data/db/database.dart';
import '../home_movies/widgets/vod_home_view.dart';

/// Shows tab: the Movies home layout for series — the hero
/// shows `3 seasons (21 episodes)`, Continue watching resumes episodes and
/// recently modified shows carry NEW SHOW / NEW EPISODES.
class ShowsHomeScreen extends StatelessWidget {
  const ShowsHomeScreen({super.key, required this.playlistId});
  final int playlistId;

  @override
  Widget build(BuildContext context) =>
      VodHomeView(playlistId: playlistId, kind: SectionKind.series);
}

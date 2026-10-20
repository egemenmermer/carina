import 'package:flutter/widgets.dart';

import '../../core/core.dart';
import '../../data/db/tables.dart';
import 'favorite_tags_sheet.dart';

/// "Add to favorite with tags" sheet (existing tag chips, multi-select, New
/// tag field). Owner: `lib/features/favorites/`.
///
/// Save adds the item to the playlist's favorites when needed, creates the
/// new tags and replaces the item's tags (`FavoritesRepository.setTags`),
/// then shows the green toast. Cancel, Esc or the × leave everything as it
/// was.
Future<void> showFavoriteTagsSheet(
  BuildContext context, {
  required int playlistId,
  required ItemType type,
  required String providerId,
  required String title,
}) async {
  await showKSheet<void>(
    context,
    width: 560,
    child: FavoriteTagsSheet(
      playlistId: playlistId,
      type: type,
      providerId: providerId,
      title: title,
    ),
  );
}

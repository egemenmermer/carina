import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';

/// Search entry points. Owner: `lib/features/search/`.

/// Opens search showing every library title with [person] ("Search by
/// actor"): closes open sheets and menus (e.g. the details sheet the cast
/// name was clicked in) and navigates to `/p/<pid>/search?person=<name>`;
/// the search page then lists the person's movies and shows.
void openPersonSearch(
  BuildContext context, {
  required int playlistId,
  required String person,
}) {
  final name = person.trim();
  if (name.isEmpty) return;
  final router = GoRouter.maybeOf(context);
  if (router == null) {
    debugPrint('openPersonSearch: no router in this context');
    return;
  }
  // Pageless routes (sheets, popups) sit above the page; drop them so the
  // search page is visible.
  Navigator.maybeOf(
    context,
    rootNavigator: true,
  )?.popUntil((route) => route.settings is Page);
  router.go(
    '${Routes.search(playlistId)}?person=${Uri.encodeQueryComponent(name)}',
  );
}

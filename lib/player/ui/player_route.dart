/// The full-window player route on the root navigator.
library;

import 'package:flutter/material.dart';

import '../../app/router.dart' show rootNavigatorKey;
import '../../features/parental/parental_api.dart';
import '../player_api.dart';
import 'player_screen.dart';

/// Opaque black route that fades in; it covers the whole window (top nav
/// included) because it lives on the root navigator.
class PlayerPageRoute extends PageRouteBuilder<void> {
  PlayerPageRoute(this.request)
    : super(
        settings: const RouteSettings(name: 'player'),
        opaque: true,
        barrierColor: null,
        transitionDuration: const Duration(milliseconds: 200),
        reverseTransitionDuration: const Duration(milliseconds: 150),
        pageBuilder: (context, animation, secondary) =>
            PlayerScreen(request: request),
        transitionsBuilder: (context, animation, secondary, child) {
          if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
            return child;
          }
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          );
        },
      );

  final PlayRequest request;
}

/// [openPlayer]'s body: parental gate for channels, then the route.
Future<void> launchPlayer(BuildContext context, PlayRequest request) async {
  final navigator =
      rootNavigatorKey.currentState ??
      Navigator.of(context, rootNavigator: true);
  final channelId = switch (request) {
    LivePlayRequest(:final channelId) => channelId,
    CatchupPlayRequest(:final channelId) => channelId,
    VodPlayRequest() => null,
  };
  if (channelId != null) {
    final unlocked = await ensureChannelUnlocked(
      context,
      playlistId: request.playlistId,
      channelId: channelId,
    );
    if (!unlocked) return;
  }
  await navigator.push(PlayerPageRoute(request));
}

import 'package:flutter/material.dart';

import '../../../core/core.dart';
import '../../../l10n/gen/app_localizations.dart';
import 'player_overlays.dart';

/// Choices of the live player's action sheet.
enum LiveAction { fullGuide, miniGuide, addChannel }

/// "Channel name · What do you need to do?" with Full TV Guide, Mini TV
/// Guide, Add channel and Cancel. Null on Cancel / Esc.
Future<LiveAction?> showLiveActionSheet(
  BuildContext context, {
  required String channelName,
}) {
  return showKPopup<LiveAction>(
    context,
    placement: KPopupPlacement.center,
    barrierColor: const Color(0x66000000),
    builder: (context) => LiveActionSheet(channelName: channelName),
  );
}

class LiveActionSheet extends StatelessWidget {
  const LiveActionSheet({super.key, required this.channelName});

  final String channelName;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    void pick(LiveAction? action) => Navigator.of(context).pop(action);
    return KFrostedPanel(
      key: const ValueKey('player-action-sheet'),
      width: 380,
      borderRadius: KRadii.sheet,
      child: Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
          child: FocusTraversalGroup(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  channelName,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KText.title.copyWith(fontSize: 18),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.playerActionQuestion,
                  textAlign: TextAlign.center,
                  style: KText.caption,
                ),
                const SizedBox(height: 16),
                SheetPill(
                  label: l10n.playerActionFullGuide,
                  autofocus: true,
                  onTap: () => pick(LiveAction.fullGuide),
                ),
                const SizedBox(height: 8),
                SheetPill(
                  label: l10n.playerActionMiniGuide,
                  onTap: () => pick(LiveAction.miniGuide),
                ),
                const SizedBox(height: 8),
                SheetPill(
                  label: l10n.playerActionAddChannel,
                  onTap: () => pick(LiveAction.addChannel),
                ),
                const SizedBox(height: 8),
                SheetPill(
                  label: l10n.cancel,
                  strong: true,
                  onTap: () => pick(null),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

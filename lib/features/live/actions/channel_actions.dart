/// The channel context menu and its actions. Every state change ends with a
/// green toast.
library;

import 'dart:io' show File;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../../data/db/database.dart';
import '../../../data/repositories/category_repository.dart';
import '../../../data/repositories/epg_repository.dart';
import '../../../data/repositories/favorites_repository.dart';
import '../../../data/repositories/live_repository.dart';
import '../../../data/repositories/parental_service.dart';
import '../../../data/repositories/reminders_repository.dart';
import '../../../data/repositories/repository_models.dart';
import '../../../data/repositories/stream_url_resolver.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../live_externals.dart';
import 'channel_dump.dart';
import 'custom_epg_picker.dart';
import 'parental_pin.dart';
import 'rename_category_sheet.dart';

/// Rows of the channel menu.
enum LiveChannelAction {
  favoriteTags,
  favorite,
  customEpg,
  reminder,
  lockChannel,
  lockCategory,
  hideChannel,
  hideCategory,
  renameCategory,
  multiview,
  archive,
  copyUrl,
  dumpChannel,
  dumpCategory,
  removeLastWatched,
}

/// What the menu needs to know about the channel when it opens.
class LiveChannelMenuContext {
  const LiveChannelMenuContext({
    required this.channel,
    required this.category,
    required this.nowNext,
    required this.reminderSet,
    required this.listCategory,
  });

  final ChannelView channel;

  /// The provider category the category actions apply to (null when the
  /// channel has none).
  final CategoryView? category;
  final NowNext nowNext;

  /// A reminder is set on [NowNext.next].
  final bool reminderSet;
  final CategoryRef? listCategory;
}

/// The menu rows for [m]. "Start recording now" (P2) and
/// "Schedule Recording" (P3) are not offered yet.
List<KMenuEntry<LiveChannelAction>> liveChannelMenuEntries(
  L10n l10n,
  LiveChannelMenuContext m,
) {
  final c = m.channel;
  final category = m.category;
  return [
    KMenuEntry(
      label: l10n.liveAddToFavoriteWithTags,
      icon: PhosphorIconsLight.tag,
      value: LiveChannelAction.favoriteTags,
    ),
    KMenuEntry(
      label: c.favorite
          ? l10n.liveRemoveFromFavorites
          : l10n.liveAddToFavorites,
      icon: c.favorite ? PhosphorIconsFill.star : PhosphorIconsLight.star,
      value: LiveChannelAction.favorite,
    ),
    KMenuEntry(
      label: l10n.liveAssignCustomEpg,
      icon: PhosphorIconsLight.article,
      value: LiveChannelAction.customEpg,
    ),
    KMenuEntry(
      label: m.reminderSet
          ? l10n.liveCancelReminder
          : l10n.liveScheduleReminder,
      icon: PhosphorIconsLight.bellSimpleRinging,
      value: LiveChannelAction.reminder,
      enabled: m.nowNext.next != null,
    ),
    KMenuEntry(
      label: c.channelLocked
          ? l10n.liveRemoveFromParental
          : l10n.liveAddToParental,
      icon: c.channelLocked
          ? PhosphorIconsLight.lockSimpleOpen
          : PhosphorIconsLight.lockSimple,
      value: LiveChannelAction.lockChannel,
    ),
    if (category != null)
      KMenuEntry(
        label: category.locked
            ? l10n.liveRemoveCategoryFromParental
            : l10n.liveAddCategoryToParental,
        icon: category.locked
            ? PhosphorIconsLight.lockSimpleOpen
            : PhosphorIconsLight.lockSimple,
        value: LiveChannelAction.lockCategory,
      ),
    KMenuEntry(
      label: l10n.liveHideChannel,
      icon: PhosphorIconsLight.eyeSlash,
      value: LiveChannelAction.hideChannel,
    ),
    if (category != null) ...[
      KMenuEntry(
        label: l10n.liveHideCategory,
        icon: PhosphorIconsLight.eyeSlash,
        value: LiveChannelAction.hideCategory,
      ),
      KMenuEntry(
        label: l10n.liveRenameCategory,
        icon: PhosphorIconsLight.textAa,
        value: LiveChannelAction.renameCategory,
      ),
    ],
    KMenuEntry(
      label: l10n.liveAddToMultiview,
      icon: PhosphorIconsLight.squaresFour,
      value: LiveChannelAction.multiview,
      enabled: c.playable,
    ),
    if (c.hasArchive)
      KMenuEntry(
        label: l10n.liveTvArchive,
        icon: PhosphorIconsLight.clockCounterClockwise,
        value: LiveChannelAction.archive,
      ),
    const KMenuEntry.separator(),
    KMenuEntry(
      label: l10n.liveCopyStreamUrl,
      icon: PhosphorIconsLight.copy,
      value: LiveChannelAction.copyUrl,
      enabled: c.playable,
    ),
    KMenuEntry(
      label: l10n.liveDumpChannel,
      icon: PhosphorIconsLight.fileMagnifyingGlass,
      value: LiveChannelAction.dumpChannel,
    ),
    if (category != null)
      KMenuEntry(
        label: l10n.liveDumpCategory,
        icon: PhosphorIconsLight.folderSimple,
        value: LiveChannelAction.dumpCategory,
      ),
    if (m.listCategory is LastWatchedCategory)
      KMenuEntry(
        label: l10n.liveRemoveFromLastWatched,
        icon: PhosphorIconsLight.trash,
        value: LiveChannelAction.removeLastWatched,
        destructive: true,
      ),
  ];
}

/// Opens the channel menu (see `showChannelActions` in `live_api.dart`).
Future<void> showChannelActionsMenu(
  BuildContext context, {
  required int playlistId,
  required String channelId,
  required Offset position,
  String? categoryId,
  CategoryRef? listCategory,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  // The card that opened the menu may be gone after an action (hidden
  // channel); dialogs and sheets use the root navigator's context.
  final navigator = Navigator.of(context, rootNavigator: true);
  final l10n = L10n.of(context);
  final LiveChannelMenuContext? menu;
  try {
    menu = await _load(
      container,
      playlistId: playlistId,
      channelId: channelId,
      categoryId: categoryId,
      listCategory: listCategory,
    );
  } on Object catch (e) {
    debugPrint('Channel menu not available: $e');
    return;
  }
  if (menu == null) return;
  final menuContext = context.mounted ? context : navigator.context;
  if (!menuContext.mounted) return;
  final action = await showKContextMenu<LiveChannelAction>(
    menuContext,
    position: position,
    entries: liveChannelMenuEntries(l10n, menu),
  );
  if (action == null || !navigator.mounted) return;
  final shiftHeld = HardwareKeyboard.instance.isShiftPressed;
  try {
    await runLiveChannelAction(
      navigator.context,
      container,
      l10n,
      playlistId: playlistId,
      menu: menu,
      action: action,
      fullUrl: shiftHeld,
    );
  } on Object catch (e, st) {
    debugPrint('Channel action $action failed: $e\n$st');
    container
        .read(toastControllerProvider)
        .show(l10n.coreErrorTitle, kind: KToastKind.error);
  }
}

Future<LiveChannelMenuContext?> _load(
  ProviderContainer container, {
  required int playlistId,
  required String channelId,
  required String? categoryId,
  required CategoryRef? listCategory,
}) async {
  final channel = await container
      .read(liveRepositoryProvider)
      .channel(playlistId, channelId);
  if (channel == null) return null;
  final catId = categoryId ?? channel.row.categoryId;
  CategoryView? category;
  if (catId != null) {
    category = await container
        .read(categoryRepositoryProvider)
        .category(playlistId, SectionKind.live, catId);
  }
  var nowNext = NowNext.empty;
  try {
    nowNext = await container
        .read(epgRepositoryProvider)
        .nowNextForChannel(playlistId, channel);
  } on Object {
    // No guide: the reminder row is disabled.
  }
  final next = nowNext.next;
  final reminderSet =
      next != null &&
      await container
          .read(remindersRepositoryProvider)
          .isSet(playlistId, channelId, next.start);
  return LiveChannelMenuContext(
    channel: channel,
    category: category,
    nowNext: nowNext,
    reminderSet: reminderSet,
    listCategory: listCategory,
  );
}

/// Runs [action] for [menu]. [context] must stay mounted (the root
/// navigator's context). Exposed for tests.
Future<void> runLiveChannelAction(
  BuildContext context,
  ProviderContainer container,
  L10n l10n, {
  required int playlistId,
  required LiveChannelMenuContext menu,
  required LiveChannelAction action,
  bool fullUrl = false,
}) async {
  final channel = menu.channel;
  final channelId = channel.providerId;
  final category = menu.category;
  final externals = container.read(liveExternalsProvider);
  void toast(String message) =>
      container.read(toastControllerProvider).show(message);
  void dumped(File? file) => file == null
      ? container
            .read(toastControllerProvider)
            .show(l10n.liveDumpFailed, kind: KToastKind.error)
      : toast(l10n.liveDumpSaved(file.uri.pathSegments.last));

  switch (action) {
    case LiveChannelAction.favoriteTags:
      await externals.showFavoriteTagsSheet(
        context,
        playlistId: playlistId,
        providerId: channelId,
        title: channel.displayName,
      );
    case LiveChannelAction.favorite:
      final added = await container
          .read(favoritesRepositoryProvider)
          .toggle(playlistId, ItemType.channel, channelId);
      toast(added ? l10n.liveAddedToFavorites : l10n.liveRemovedFromFavorites);
    case LiveChannelAction.customEpg:
      await showCustomEpgPickerSheet(
        context,
        playlistId: playlistId,
        channelId: channelId,
      );
    case LiveChannelAction.reminder:
      final next = menu.nowNext.next;
      if (next == null) return;
      await externals.toggleReminder(
        context,
        playlistId: playlistId,
        channelId: channelId,
        startUtc: next.start,
      );
    case LiveChannelAction.lockChannel:
      final lock = !channel.channelLocked;
      final allowed = await authorizeParentalChange(
        context,
        container,
        l10n,
        playlistId: playlistId,
        unlocking: !lock,
      );
      if (!allowed) return;
      await container
          .read(parentalServiceProvider)
          .lockChannel(playlistId, channelId, lock);
      toast(l10n.liveParentalChannelsUpdated);
    case LiveChannelAction.lockCategory:
      final id = category?.providerId;
      if (id == null) return;
      final lock = !category!.locked;
      final allowed = await authorizeParentalChange(
        context,
        container,
        l10n,
        playlistId: playlistId,
        unlocking: !lock,
      );
      if (!allowed) return;
      await container
          .read(parentalServiceProvider)
          .lockCategory(playlistId, SectionKind.live, id, lock);
      toast(l10n.liveParentalCategoriesUpdated);
    case LiveChannelAction.hideChannel:
      await container
          .read(liveRepositoryProvider)
          .setHidden(playlistId, channelId, true);
      toast(l10n.liveChannelHidden);
    case LiveChannelAction.hideCategory:
      final id = category?.providerId;
      if (id == null) return;
      await container
          .read(categoryRepositoryProvider)
          .setHidden(playlistId, SectionKind.live, id, true);
      toast(l10n.liveCategoryHidden);
    case LiveChannelAction.renameCategory:
      final id = category?.providerId;
      if (id == null) return;
      await showRenameCategorySheet(
        context,
        playlistId: playlistId,
        categoryId: id,
      );
    case LiveChannelAction.multiview:
      await externals.addToMultiview(
        context,
        playlistId: playlistId,
        channelId: channelId,
      );
    case LiveChannelAction.archive:
      await externals.showArchiveSheet(
        context,
        playlistId: playlistId,
        channelId: channelId,
      );
    case LiveChannelAction.copyUrl:
      final stream = await container
          .read(streamUrlResolverProvider)
          .live(playlistId, channel.row);
      await Clipboard.setData(
        ClipboardData(text: fullUrl ? stream.url : stream.maskedUrl),
      );
      toast(fullUrl ? l10n.liveStreamUrlCopiedFull : l10n.liveStreamUrlCopied);
    case LiveChannelAction.dumpChannel:
      dumped(
        await dumpLiveChannel(
          container,
          playlistId: playlistId,
          channel: channel,
          nowNext: menu.nowNext,
        ),
      );
    case LiveChannelAction.dumpCategory:
      final id = category?.providerId;
      if (id == null) return;
      dumped(
        await dumpLiveCategory(
          container,
          playlistId: playlistId,
          category: category!,
        ),
      );
    case LiveChannelAction.removeLastWatched:
      await container
          .read(liveRepositoryProvider)
          .removeLastWatched(playlistId, channelId);
      toast(l10n.liveRemovedFromLastWatched);
  }
}

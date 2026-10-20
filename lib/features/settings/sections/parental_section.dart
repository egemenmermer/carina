import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../../../data/db/database.dart';
import '../../../data/repositories/parental_service.dart';
import '../../../data/repositories/playlist_repository.dart';
import '../../../data/repositories/repository_models.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../parental/parental_pin_flows.dart';
import '../settings_model.dart';
import '../widgets/settings_widgets.dart';

/// Settings → Parental Control: the parental PIN (set / change / remove), the
/// mode (ask PIN on open / hide locked content), the playlist access PIN and
/// the locked channels and categories with Unlock. Once a PIN exists, the
/// section asks for it first (once per session).
class ParentalSection extends ConsumerStatefulWidget {
  const ParentalSection({super.key, required this.playlistId});

  final int playlistId;

  @override
  ConsumerState<ParentalSection> createState() => _ParentalSectionState();
}

class _ParentalSectionState extends ConsumerState<ParentalSection> {
  bool? _hasPin;

  int get _pid => widget.playlistId;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(ParentalSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playlistId != widget.playlistId) _refresh();
  }

  Future<void> _refresh() async {
    final has = await ref.read(parentalServiceProvider).hasPin(_pid);
    if (mounted) setState(() => _hasPin = has);
  }

  Future<void> _enterPin() async {
    final l10n = L10n.of(context);
    final service = ref.read(parentalServiceProvider);
    final pin = await showPinPad(
      context,
      title: l10n.libraryParentalEnterPin,
      subtitle: l10n.libraryParentalSettingsLocked,
      validate: (pin) => service.verifyPin(_pid, pin),
    );
    if (pin != null) {
      ref.read(parentalSettingsAccessProvider.notifier).grant(_pid);
    }
  }

  Future<void> _pinActions() async {
    final l10n = L10n.of(context);
    if (_hasPin != true) {
      await createParentalPin(context, playlistId: _pid);
      await _refresh();
      return;
    }
    final action = await showChooser<String>(
      context,
      title: l10n.libraryParentalPin,
      description: l10n.libraryParentalPinHint,
      choices: [
        KChoice(value: 'change', label: l10n.libraryParentalChangePin),
        KChoice(value: 'remove', label: l10n.libraryParentalRemovePin),
      ],
    );
    if (!mounted || action == null) return;
    if (action == 'change') {
      await changeParentalPin(context, playlistId: _pid);
    } else {
      await removeParentalPin(context, playlistId: _pid);
    }
    await _refresh();
  }

  Future<void> _accessPinActions(PlaylistRow playlist) async {
    final l10n = L10n.of(context);
    final has = playlist.hasAccessPin;
    if (!has) {
      await editAccessPin(context, playlistId: _pid, hasPin: false);
      return;
    }
    final action = await showChooser<String>(
      context,
      title: l10n.libraryAccessPin,
      description: l10n.libraryAccessPinHint,
      choices: [
        KChoice(value: 'change', label: l10n.libraryParentalChangePin),
        KChoice(value: 'remove', label: l10n.libraryParentalRemovePin),
      ],
    );
    if (!mounted || action == null) return;
    await editAccessPin(
      context,
      playlistId: _pid,
      hasPin: true,
      remove: action == 'remove',
    );
  }

  Future<void> _unlockChannel(ChannelView channel) async {
    final l10n = L10n.of(context);
    await ref
        .read(parentalServiceProvider)
        .lockChannel(_pid, channel.providerId, false);
    ref
        .read(toastControllerProvider)
        .show(l10n.libraryParentalUnlocked(channel.displayName));
  }

  Future<void> _unlockCategory(CategoryView category) async {
    final l10n = L10n.of(context);
    final id = category.providerId;
    if (id == null) return;
    await ref
        .read(parentalServiceProvider)
        .lockCategory(_pid, category.kind, id, false);
    ref
        .read(toastControllerProvider)
        .show(l10n.libraryParentalUnlocked(category.title));
  }

  String _kindLabel(L10n l10n, SectionKind kind) => switch (kind) {
    SectionKind.live => l10n.shellLive,
    SectionKind.movie => l10n.shellMovies,
    SectionKind.series => l10n.shellShows,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final hasPin = _hasPin;
    if (hasPin == null) {
      return const Padding(
        padding: EdgeInsets.only(top: 80),
        child: KLoadingState(),
      );
    }
    final access = ref.watch(parentalSettingsAccessProvider).contains(_pid);
    if (hasPin && !access) {
      return Padding(
        key: const ValueKey('parental-locked'),
        padding: const EdgeInsets.only(top: 56),
        child: Column(
          children: [
            const Icon(
              PhosphorIconsLight.lockSimple,
              size: 52,
              color: KColors.success,
            ),
            const SizedBox(height: 18),
            Text(
              l10n.libraryParentalProtectedTitle,
              textAlign: TextAlign.center,
              style: KText.title,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.libraryParentalSettingsLocked,
              textAlign: TextAlign.center,
              style: KText.bodySecondary,
            ),
            const SizedBox(height: 24),
            KButton.accent(
              key: const ValueKey('parental-enter-pin'),
              label: l10n.libraryParentalEnterPin,
              icon: PhosphorIconsBold.lockSimpleOpen,
              onPressed: _enterPin,
              minWidth: 200,
            ),
          ],
        ),
      );
    }

    final playlist = ref.watch(playlistProvider(_pid)).value;
    final locked = ref.watch(lockedItemsProvider(_pid)).value;
    return Column(
      key: const ValueKey('parental-content'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroupTitle(l10n.libraryGroupPin, first: true),
        SettingsGroup(
          children: [
            SettingsRow(
              key: const ValueKey('row:parental-pin'),
              title: l10n.libraryParentalPin,
              value: hasPin ? l10n.on : l10n.libraryNotSet,
              onTap: _pinActions,
            ),
            settingRow(LibrarySettingSpecs.parentalMode, _pid),
            if (playlist != null)
              SettingsRow(
                key: const ValueKey('row:access-pin'),
                title: l10n.libraryAccessPin,
                value: playlist.hasAccessPin ? l10n.on : l10n.off,
                onTap: () => _accessPinActions(playlist),
              ),
          ],
        ),
        SettingsNote(l10n.libraryParentalNote, center: true),
        SettingsGroupTitle(l10n.libraryLockedChannels),
        if (locked == null)
          const Center(child: KSpinner(size: 22))
        else
          SettingsList(
            emptyMessage: l10n.libraryLockedChannelsEmpty,
            children: [
              for (final c in locked.channels)
                SettingsListTile(
                  key: ValueKey('locked-channel-${c.providerId}'),
                  leading: KLogoTile(
                    name: c.displayName,
                    url: c.logo,
                    size: 40,
                  ),
                  title: c.displayName,
                  subtitle: c.categoryName.isEmpty ? null : c.categoryName,
                  trailing: KButton.secondary(
                    label: l10n.libraryUnlock,
                    icon: PhosphorIconsBold.lockSimpleOpen,
                    size: KButtonSize.small,
                    onPressed: () => _unlockChannel(c),
                  ),
                ),
            ],
          ),
        SettingsGroupTitle(l10n.libraryLockedCategories),
        if (locked == null)
          const Center(child: KSpinner(size: 22))
        else
          SettingsList(
            emptyMessage: l10n.libraryLockedCategoriesEmpty,
            children: [
              for (final c in locked.categories)
                SettingsListTile(
                  key: ValueKey(
                    'locked-category-${c.kind.name}-${c.providerId}',
                  ),
                  leading: const Icon(
                    PhosphorIconsFill.folderSimpleLock,
                    size: 24,
                    color: KColors.success,
                  ),
                  title: c.title,
                  subtitle:
                      '${_kindLabel(l10n, c.kind)} · ${l10n.libraryItemCount(c.count)}',
                  trailing: KButton.secondary(
                    label: l10n.libraryUnlock,
                    icon: PhosphorIconsBold.lockSimpleOpen,
                    size: KButtonSize.small,
                    onPressed: () => _unlockCategory(c),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

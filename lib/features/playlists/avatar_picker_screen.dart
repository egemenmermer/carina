import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:carina/core/core.dart';
import 'package:carina/data/repositories/playlist_repository.dart';
import 'package:carina/features/playlists/data/playlists_navigation.dart';
import 'package:carina/features/playlists/widgets/playlists_chrome.dart';
import 'package:carina/l10n/gen/app_localizations.dart';

/// "Choose Avatar": the title centered at the top, the avatar
/// categories on the left (the selected one is a white pill; moving the
/// keyboard focus over a category shows it, as on tvOS) and the avatar grid
/// on the right. Choosing an avatar saves it, shows a toast and returns to
/// the Playlist Manager. Esc goes back without changes.
class AvatarPickerScreen extends ConsumerStatefulWidget {
  const AvatarPickerScreen({super.key, required this.playlistId});

  final int playlistId;

  @override
  ConsumerState<AvatarPickerScreen> createState() => _AvatarPickerScreenState();
}

class _AvatarPickerScreenState extends ConsumerState<AvatarPickerScreen> {
  AvatarCategory? _category;
  bool _saving = false;

  Future<void> _choose(AvatarSpec avatar) async {
    if (_saving) return;
    setState(() => _saving = true);
    final l10n = L10n.of(context);
    final toasts = ref.read(toastControllerProvider);
    await ref
        .read(playlistRepositoryProvider)
        .setAvatar(widget.playlistId, avatar.id);
    toasts.show(l10n.playlistsAvatarUpdated);
    if (mounted) goBackFromPlaylists(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final async = ref.watch(playlistProvider(widget.playlistId));
    final row = async.value;
    final current = AvatarCatalog.byId(row?.avatarId);
    final category =
        _category ?? current?.category ?? AvatarCategory.characters;
    final avatars = AvatarCatalog.byCategory(category);
    final topInset = macTitleBarInset();

    Widget body;
    if (row == null) {
      body = async.isLoading
          ? const KLoadingState()
          : KEmptyState(message: l10n.playlistsNotFound);
    } else {
      body = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The category list sits on a dark rounded panel.
          Padding(
            padding: const EdgeInsets.fromLTRB(40, 0, 16, 40),
            child: Container(
              width: 264,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: KColors.surface1,
                borderRadius: BorderRadius.circular(KRadii.contextMenu),
                border: Border.all(color: KColors.stroke),
              ),
              child: FocusTraversalGroup(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final (i, c) in AvatarCategory.values.indexed)
                      Padding(
                        padding: EdgeInsets.only(top: i == 0 ? 0 : 4),
                        child: _CategoryRow(
                          key: ValueKey('avatar-category-${c.name}'),
                          label: c.label(context),
                          count: AvatarCatalog.byCategory(c).length,
                          selected: c == category,
                          onSelect: () => setState(() => _category = c),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: FocusTraversalGroup(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(40, 8, 64, 48),
                child: Wrap(
                  spacing: 52,
                  runSpacing: 40,
                  children: [
                    for (final (index, avatar) in avatars.indexed)
                      _AvatarChoice(
                        key: ValueKey('avatar-${avatar.id}'),
                        avatar: avatar,
                        playlistName: row.name,
                        current: avatar.id == current?.id,
                        autofocus:
                            current == null || current.category != category
                            ? index == 0 && _category == null
                            : avatar.id == current.id,
                        currentLabel: l10n.playlistsAvatarCurrent,
                        onTap: () => _choose(avatar),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return PlaylistsWindowFrame(
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              goBackFromPlaylists(context),
        },
        child: FocusScope(
          autofocus: true,
          child: Padding(
            padding: EdgeInsets.only(top: topInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 108,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        left: 32,
                        child: KIconButton(
                          icon: PhosphorIconsRegular.arrowLeft,
                          size: 40,
                          iconSize: 20,
                          tooltip: l10n.back,
                          onPressed: () => goBackFromPlaylists(context),
                        ),
                      ),
                      Text(
                        l10n.playlistsChooseAvatarTitle,
                        style: KText.title.copyWith(fontSize: 26),
                      ),
                    ],
                  ),
                ),
                Expanded(child: body),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    super.key,
    required this.label,
    required this.count,
    required this.selected,
    required this.onSelect,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return KInteractive(
      onTap: onSelect,
      selected: selected,
      semanticLabel: label,
      onFocusChange: (focused) {
        // tvOS: moving the focus over a category shows it.
        if (focused && !selected) onSelect();
      },
      builder: (context, state, _) {
        final fill = selected
            ? KColors.focusRing
            : state.highlighted
            ? KColors.rowHover
            : const Color(0x00FFFFFF);
        final fg = selected ? Colors.black : KColors.textPrimary;
        return KFocusRing(
          visible: state.focused,
          borderRadius: 23,
          gap: 2,
          child: AnimatedContainer(
            duration: KMotion.of(context, KDurations.hover),
            curve: KMotion.hover,
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: KRadii.pillBorder,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KText.settingsTitle.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '$count',
                  style: KText.settingsValue.copyWith(
                    color: selected
                        ? const Color(0xFF6A6A6E)
                        : KColors.textTertiary,
                    fontFeatures: KText.tabular,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AvatarChoice extends StatelessWidget {
  const _AvatarChoice({
    super.key,
    required this.avatar,
    required this.playlistName,
    required this.current,
    required this.autofocus,
    required this.currentLabel,
    required this.onTap,
  });

  static const double size = 128;

  final AvatarSpec avatar;
  final String playlistName;
  final bool current;
  final bool autofocus;
  final String currentLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return KInteractive(
      onTap: onTap,
      autofocus: autofocus,
      selected: current,
      semanticLabel: current ? '${avatar.name}, $currentLabel' : avatar.name,
      builder: (context, state, _) {
        final duration = KMotion.of(context, KDurations.hover);
        final lit = state.highlighted;
        Widget circle = SizedBox.square(
          dimension: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              KAvatar(avatar.id, size, fallbackName: playlistName),
              if (current)
                Positioned(
                  right: 2,
                  bottom: 2,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: KColors.bg, width: 2),
                    ),
                    child: const Icon(
                      PhosphorIconsBold.check,
                      size: 16,
                      color: Colors.black,
                    ),
                  ),
                ),
            ],
          ),
        );
        circle = KFocusRing(
          visible: lit || current,
          circle: true,
          gap: 4,
          width: 3,
          color: lit ? KColors.focusRing : const Color(0x80F5F5F5),
          child: circle,
        );
        return AnimatedScale(
          scale: state.pressed
              ? 1.02
              : lit
              ? 1.08
              : 1,
          duration: duration,
          curve: KMotion.hover,
          child: circle,
        );
      },
    );
  }
}

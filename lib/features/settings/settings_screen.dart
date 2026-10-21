import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/platform/form_factor.dart';
import '../../app/router.dart';
import '../../core/core.dart';
import '../../data/db/database.dart';
import '../../data/repositories/playlist_repository.dart';
import '../../data/settings/settings_store.dart';
import '../../l10n/gen/app_localizations.dart';
import 'sections/app_sections.dart';
import 'sections/parental_section.dart';
import 'sections/playlist_sections.dart';
import 'sections/subpages.dart';
import 'settings_model.dart';
import 'widgets/standalone_page.dart';

/// The settings page: the section list on the left
/// (red icons; the selected section is a white pill with a chevron) and the
/// section on the right (title, rows with the value in red, choosers).
///
/// With a [playlistId] (inside the playlist shell) the playlist's sections
/// come first, under its avatar and name, then the app sections; without it
/// (`/settings`, from the Playlist Manager) only the app sections show, in
/// a standalone page. [section] is a [SettingsSection] id (`player`,
/// `parental`, `general`…); without it the last section of this session
/// (or the first one) opens.
///
/// On TV the selected section takes focus on entry, and Back walks up:
/// subpage → section → the section list → out.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, this.playlistId, this.section});

  final int? playlistId;
  final String? section;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

/// The last section opened per page (app / each playlist) this session.
final _lastSectionProvider =
    NotifierProvider<_LastSection, Map<String, SettingsSection>>(
      _LastSection.new,
    );

class _LastSection extends Notifier<Map<String, SettingsSection>> {
  @override
  Map<String, SettingsSection> build() => const {};

  void remember(String scope, SettingsSection section) =>
      state = {...state, scope: section};
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final ScrollController _scroll = ScrollController();

  /// Holds focus while the row that had it disappears (subpage open/close),
  /// so Esc and arrows keep working.
  final FocusNode _contentFocus = FocusNode(
    debugLabel: 'settings-content',
    skipTraversal: true,
  );
  late SettingsSection _section;
  SettingsSubpage? _subpage;

  /// Focus nodes of the section tiles (TV: Back from the content returns
  /// to the selected one).
  final Map<SettingsSection, FocusNode> _tileNodes = {};

  late final bool _tv = ref.read(formFactorProvider).isTv;

  int? get _pid => widget.playlistId;

  String get _scope => _pid == null ? 'app' : 'playlist:$_pid';

  List<SettingsSection> get _sections => _pid == null
      ? SettingsSection.appSections
      : const [
          ...SettingsSection.playlistSections,
          ...SettingsSection.appSections,
        ];

  @override
  void initState() {
    super.initState();
    _section = _resolve(widget.section);
    // TV: autofocus does not scroll; bring a deep section's tile into view.
    if (_tv) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final tile = _tileNodes[_section]?.context;
        if (mounted && tile != null) {
          Scrollable.ensureVisible(tile, alignment: 0.5);
        }
      });
    }
  }

  @override
  void didUpdateWidget(SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.section != widget.section ||
        oldWidget.playlistId != widget.playlistId) {
      _section = _resolve(widget.section);
      _subpage = null;
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _contentFocus.dispose();
    for (final node in _tileNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  FocusNode _tileNode(SettingsSection section) => _tileNodes.putIfAbsent(
    section,
    () => FocusNode(debugLabel: 'settings-section-${section.id}'),
  );

  /// Holds focus on [_contentFocus] while the content swaps; on TV, where
  /// that holder shows nothing, the content's first row takes it next.
  void _refocusContent() {
    _contentFocus.requestFocus();
    if (!_tv) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _contentFocus.hasPrimaryFocus) {
        kFocusFirstIn(_contentFocus);
      }
    });
  }

  SettingsSection _resolve(String? id) {
    final asked = SettingsSection.fromId(id);
    if (asked != null && _sections.contains(asked)) return asked;
    final last = ref.read(_lastSectionProvider)[_scope];
    if (last != null && _sections.contains(last)) return last;
    return _sections.first;
  }

  void _jumpTop() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _select(SettingsSection section) {
    setState(() {
      _section = section;
      _subpage = null;
    });
    ref.read(_lastSectionProvider.notifier).remember(_scope, section);
    _jumpTop();
  }

  void _openSubpage(SettingsSubpage page) {
    setState(() => _subpage = page);
    _refocusContent();
    _jumpTop();
  }

  void _closeSubpage() {
    setState(() => _subpage = null);
    _refocusContent();
    _jumpTop();
  }

  void _leave() {
    final router = GoRouter.maybeOf(context);
    if (router == null) return;
    final pid = _pid;
    if (pid == null) {
      router.go(Routes.manager);
      return;
    }
    final last = ref
        .read(settingsStoreProvider)
        .get(PlaylistSettings.lastTab, playlistId: pid);
    router.go(Routes.tab(pid, MainTabPath.fromSegment(last) ?? MainTab.live));
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.escape) {
      return KeyEventResult.ignored;
    }
    final focused = FocusManager.instance.primaryFocus;
    if (_tv) {
      // The remote's Back: subpage → section → section list → out (in a
      // playlist the shell takes it from there, to the home tab).
      if (_subpage != null) {
        _closeSubpage();
      } else if (_contentFocus.hasFocus) {
        _tileNode(_section).requestFocus();
      } else if (_pid != null) {
        return KeyEventResult.ignored;
      } else {
        _leave();
      }
    } else if (focused?.context?.widget is EditableText) {
      focused!.unfocus();
    } else if (_subpage != null) {
      _closeSubpage();
    } else {
      _leave();
    }
    return KeyEventResult.handled;
  }

  String _subpageTitle(L10n l10n, SettingsSubpage page) => switch (page) {
    SettingsSubpage.hiddenItems => l10n.libraryHiddenItems,
    SettingsSubpage.renamedCategories => l10n.libraryRenameCategories,
    SettingsSubpage.customEpg => l10n.libraryCustomEpg,
  };

  Widget _body() {
    final pid = _pid;
    final page = _subpage;
    if (page != null && pid != null) {
      return switch (page) {
        SettingsSubpage.hiddenItems => HiddenItemsPage(playlistId: pid),
        SettingsSubpage.renamedCategories => RenamedCategoriesPage(
          playlistId: pid,
        ),
        SettingsSubpage.customEpg => CustomEpgPage(playlistId: pid),
      };
    }
    if (_section.isPlaylist && pid == null) return const SizedBox.shrink();
    return switch (_section) {
      SettingsSection.playlist => PlaylistGeneralSection(playlistId: pid!),
      SettingsSection.management => ManagementSection(
        playlistId: pid!,
        onOpenSubpage: _openSubpage,
      ),
      SettingsSection.live => LiveSection(
        playlistId: pid!,
        onOpenSubpage: _openSubpage,
      ),
      SettingsSection.player => PlayerSection(playlistId: pid!),
      SettingsSection.parental => ParentalSection(playlistId: pid!),
      SettingsSection.general => const AppGeneralSection(),
      SettingsSection.tmdb => const TmdbSection(),
      SettingsSection.reminders => const RemindersSection(),
      SettingsSection.cache => const CacheSection(),
      SettingsSection.diagnostics => const DiagnosticsSection(),
      SettingsSection.about => const AboutSection(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final pid = _pid;
    final playlist = pid == null
        ? null
        : ref.watch(playlistProvider(pid)).value;
    final page = _subpage;
    final title = page == null
        ? _section.label(l10n)
        : _subpageTitle(l10n, page);
    final subtitle = _section.isPlaylist
        ? (playlist?.name ?? '')
        : l10n.librarySettingsAppScope;

    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 360,
          child: _SectionList(
            playlist: playlist,
            playlistId: pid,
            selected: _section,
            onSelect: _select,
            onBack: pid == null ? _leave : null,
            tileNode: _tileNode,
            autofocusSelected: _tv,
          ),
        ),
        Expanded(
          child: Focus(
            focusNode: _contentFocus,
            child: FocusTraversalGroup(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1080),
                  child: ListView(
                    key: ValueKey(
                      'settings-content-${_section.id}-${page?.name}',
                    ),
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(20, 22, 44, 64),
                    children: [
                      _ContentHeader(
                        title: title,
                        subtitle: subtitle,
                        playlistScoped: _section.isPlaylist,
                        onBack: page == null ? null : _closeSubpage,
                        backLabel: _section.label(l10n),
                      ),
                      const SizedBox(height: 6),
                      _body(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );

    final keyed = Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: ColoredBox(color: KColors.bg, child: content),
    );
    if (pid != null) return keyed;
    return LibraryStandalonePage(
      title: l10n.shellSettings,
      onBack: _leave,
      child: keyed,
    );
  }
}

class _SectionList extends StatelessWidget {
  const _SectionList({
    required this.playlist,
    required this.playlistId,
    required this.selected,
    required this.onSelect,
    required this.onBack,
    required this.tileNode,
    this.autofocusSelected = false,
  });

  final PlaylistRow? playlist;
  final int? playlistId;
  final SettingsSection selected;
  final ValueChanged<SettingsSection> onSelect;
  final VoidCallback? onBack;
  final FocusNode Function(SettingsSection section) tileNode;

  /// The selected tile takes focus when the page opens (TV).
  final bool autofocusSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    Widget tile(SettingsSection s) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: SettingsSectionTile(
        key: ValueKey('section:${s.id}'),
        label: s.label(l10n),
        icon: s.icon,
        selected: s == selected,
        focusNode: tileNode(s),
        autofocus: autofocusSelected && s == selected,
        onTap: () => onSelect(s),
      ),
    );
    final back = onBack;
    return FocusTraversalGroup(
      child: ListView(
        // TV: build every tile, so a deep selected one can take focus.
        cacheExtent: autofocusSelected ? 4000 : null,
        padding: const EdgeInsets.fromLTRB(32, 22, 16, 32),
        children: [
          if (back != null) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: LibraryBackButton(
                label: l10n.libraryBackToPlaylists,
                onPressed: back,
              ),
            ),
            const SizedBox(height: 18),
          ],
          if (playlistId != null) ...[
            _PlaylistHeader(playlist: playlist),
            const SizedBox(height: 18),
            for (final s in SettingsSection.playlistSections) tile(s),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
              child: Text(
                l10n.librarySettingsAppHeader.toUpperCase(),
                style: KText.sectionLabel,
              ),
            ),
          ],
          for (final s in SettingsSection.appSections) tile(s),
        ],
      ),
    );
  }
}

/// Avatar and name of the playlist above its sections.
class _PlaylistHeader extends StatelessWidget {
  const _PlaylistHeader({required this.playlist});

  final PlaylistRow? playlist;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final p = playlist;
    return Column(
      children: [
        KAvatar(p?.avatarId, 76, fallbackName: p?.name),
        const SizedBox(height: 10),
        Text(
          p?.name ?? '',
          key: const ValueKey('settings-playlist-name'),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: KText.channelName,
        ),
        const SizedBox(height: 2),
        Text(
          l10n.librarySettingsPlaylistScope,
          textAlign: TextAlign.center,
          style: KText.caption,
        ),
      ],
    );
  }
}

class _ContentHeader extends StatelessWidget {
  const _ContentHeader({
    required this.title,
    required this.subtitle,
    required this.playlistScoped,
    required this.onBack,
    required this.backLabel,
  });

  final String title;
  final String subtitle;
  final bool playlistScoped;
  final VoidCallback? onBack;
  final String backLabel;

  @override
  Widget build(BuildContext context) {
    final back = onBack;
    return SizedBox(
      height: 54,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (back != null)
            Align(
              alignment: Alignment.centerLeft,
              child: LibraryBackButton(
                key: const ValueKey('subpage-back'),
                label: backLabel,
                onPressed: back,
              ),
            ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                key: const ValueKey('settings-title'),
                textAlign: TextAlign.center,
                style: KText.title,
              ),
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    playlistScoped
                        ? PhosphorIconsFill.userCircle
                        : PhosphorIconsFill.gearSix,
                    size: 13,
                    color: playlistScoped
                        ? KColors.accent
                        : KColors.textTertiary,
                  ),
                  const SizedBox(width: 5),
                  Text(subtitle, style: KText.caption),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

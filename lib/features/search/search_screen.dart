import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/clock.dart';
import '../../app/platform/form_factor.dart';
import '../../app/router.dart';
import '../../app/time_format.dart';
import '../../core/core.dart';
import '../../data/db/tables.dart';
import '../../data/repositories/repository_models.dart';
import '../../data/repositories/search_repository.dart';
import '../../data/repositories/vod_models.dart';
import '../../data/settings/settings_store.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../player/player_api.dart';
import '../details/details_api.dart';
import '../guide/guide_api.dart';
import '../live/live_api.dart';
import '../reminders/reminders_api.dart';
import '../settings/widgets/shell_safe_input.dart';
import 'data/search_providers.dart';
import 'search_widgets.dart';

/// Full search page inside the playlist shell: a big field,
/// filter pills (All · Movies · Shows · Live · People) and results as you
/// type (150 ms debounce): Movies and Shows (posters), Live channels
/// (channel cards with the programme on air), Programmes (on air and
/// upcoming) and People. Clicking a person lists every title with them
/// ("Search by actor").
///
/// [initialQuery] prefills the field and runs the search; [initialPerson]
/// opens the titles of that cast member (the router passes the `q` and
/// `person` query parameters; [openPersonSearch] uses the latter).
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({
    super.key,
    required this.playlistId,
    this.initialQuery,
    this.initialPerson,
  });

  final int playlistId;
  final String? initialQuery;
  final String? initialPerson;

  /// Delay between the last keystroke and the query.
  static const Duration debounce = Duration(milliseconds: 150);

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _controller;
  final FocusNode _fieldFocus = FocusNode(debugLabel: 'search-field');
  final ScrollController _scroll = ScrollController();
  Timer? _debounce;

  /// The debounced, trimmed query.
  String _query = '';
  SearchFilter _filter = SearchFilter.all;

  /// Cast name of the "Search by actor" view, or null.
  String? _person;

  /// The last results shown (kept while the next query loads).
  SearchResults? _shown;

  int get _pid => widget.playlistId;

  static String? _nonBlank(String? s) {
    final t = s?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  @override
  void initState() {
    super.initState();
    final q = widget.initialQuery?.trim() ?? '';
    _controller = TextEditingController(text: q);
    _query = q;
    _person = _nonBlank(widget.initialPerson);
    // The shell already holds focus when the page opens, so `autofocus`
    // alone would not reach the field.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _person == null) _focusField();
    });
  }

  @override
  void didUpdateWidget(SearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialPerson != widget.initialPerson) {
      _person = _nonBlank(widget.initialPerson);
      if (_person == null) _focusField();
    }
    if (oldWidget.initialQuery != widget.initialQuery &&
        widget.initialQuery != null) {
      final q = widget.initialQuery!.trim();
      _controller.text = q;
      _query = q;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _fieldFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _focusField() {
    if (!mounted) return;
    _fieldFocus.requestFocus();
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    final trimmed = text.trim();
    if (_person != null && trimmed.isNotEmpty) _exitPerson(refocus: false);
    if (trimmed.isEmpty) {
      setState(() => _query = '');
      return;
    }
    _debounce = Timer(SearchScreen.debounce, () {
      if (mounted) setState(() => _query = trimmed);
    });
  }

  void _clear() {
    _debounce?.cancel();
    _controller.clear();
    setState(() {
      _query = '';
      _shown = null;
    });
    _focusField();
  }

  void _setFilter(SearchFilter filter) {
    if (_filter == filter) return;
    setState(() => _filter = filter);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _openPerson(PersonHit person) {
    setState(() => _person = person.name);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _exitPerson({bool refocus = true}) {
    setState(() => _person = null);
    // Drop `?person=` so opening the same person again is a change.
    if (_nonBlank(widget.initialPerson) != null) {
      GoRouter.maybeOf(context)?.go(Routes.search(_pid));
    }
    if (refocus) _focusField();
  }

  void _leave() {
    final router = GoRouter.maybeOf(context);
    if (router == null) return;
    final last = ref
        .read(settingsStoreProvider)
        .get(PlaylistSettings.lastTab, playlistId: _pid);
    router.go(Routes.tab(_pid, MainTabPath.fromSegment(last) ?? MainTab.live));
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.escape) {
      return KeyEventResult.ignored;
    }
    if (ref.read(formFactorProvider).isTv) {
      // The remote's Back leaves the field (its text stays), then the page.
      if (_fieldFocus.hasFocus &&
          _fieldFocus.focusInDirection(TraversalDirection.down)) {
        return KeyEventResult.handled;
      }
      if (_person != null) {
        _exitPerson();
      } else {
        _leave();
      }
    } else if (!_fieldFocus.hasFocus) {
      _focusField();
    } else if (_controller.text.isNotEmpty) {
      _clear();
    } else if (_person != null) {
      _exitPerson();
    } else {
      _leave();
    }
    return KeyEventResult.handled;
  }

  // -------------------------------------------------------------------------
  // Actions
  // -------------------------------------------------------------------------

  void _openVod(VodItem item) {
    if (item.kind == SectionKind.series) {
      showSeriesDetails(context, playlistId: _pid, seriesId: item.providerId);
    } else {
      showMovieDetails(context, playlistId: _pid, movieId: item.providerId);
    }
  }

  void _vodMenu(VodItem item, Offset position) {
    showVodActions(
      context,
      playlistId: _pid,
      type: item.itemType,
      providerId: item.providerId,
      position: position,
    );
  }

  /// The player passes the parental gate itself (`openPlayer`).
  Future<void> _playChannel(ChannelHit channel) => openPlayer(
    context,
    LivePlayRequest(
      playlistId: _pid,
      channelId: channel.providerId,
      categoryId: channel.categoryId,
    ),
  );

  void _channelMenu(ChannelHit channel, Offset position) {
    showChannelActions(
      context,
      playlistId: _pid,
      channelId: channel.providerId,
      position: position,
      categoryId: channel.categoryId,
    );
  }

  void _openProgramme(ProgrammeHit programme) {
    final channel = programme.channels.firstOrNull;
    if (channel == null) return;
    showProgrammeDetails(
      context,
      playlistId: _pid,
      channelId: channel.providerId,
      startUtc: programme.start,
    );
  }

  void _toggleReminder(ProgrammeHit programme) {
    final channel = programme.channels.firstOrNull;
    if (channel == null) return;
    toggleReminder(
      context,
      playlistId: _pid,
      channelId: channel.providerId,
      startUtc: programme.start,
    );
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final person = _person;
    final async = person == null && _query.isNotEmpty
        ? ref.watch(
            searchResultsProvider((
              playlistId: _pid,
              query: _query,
              filter: _filter,
            )),
          )
        : null;
    final current = async?.value;
    if (current != null && !(async?.isLoading ?? false)) _shown = current;
    final loading = async?.isLoading ?? false;

    final Widget body;
    if (person != null) {
      body = _PersonResults(
        playlistId: _pid,
        name: person,
        scroll: _scroll,
        onBack: _exitPerson,
        onOpen: _openVod,
        onMenu: _vodMenu,
      );
    } else if (_query.isEmpty) {
      body = KEmptyState(
        key: const ValueKey('search-idle'),
        icon: PhosphorIconsLight.magnifyingGlass,
        title: l10n.librarySearchIdleTitle,
        message: l10n.librarySearchIdleMessage,
      );
    } else {
      final results = async?.value ?? _shown;
      if (results == null) {
        body = async != null && async.hasError
            ? KErrorState(
                message: l10n.librarySearchFailed,
                onRetry: () => ref.invalidate(
                  searchResultsProvider((
                    playlistId: _pid,
                    query: _query,
                    filter: _filter,
                  )),
                ),
              )
            : const KLoadingState();
      } else if (results.isEmpty) {
        body = loading
            ? const KLoadingState()
            : KEmptyState(
                key: const ValueKey('search-empty'),
                icon: PhosphorIconsLight.magnifyingGlass,
                message: l10n.librarySearchNoResults(results.query.trim()),
                actionLabel: l10n.librarySearchClear,
                actionIcon: PhosphorIconsBold.x,
                onAction: _clear,
              );
      } else {
        body = _ResultList(
          playlistId: _pid,
          results: results,
          scroll: _scroll,
          onOpenVod: _openVod,
          onVodMenu: _vodMenu,
          onPlayChannel: _playChannel,
          onChannelMenu: _channelMenu,
          onOpenProgramme: _openProgramme,
          onToggleReminder: _toggleReminder,
          onOpenPerson: _openPerson,
        );
      }
    }

    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: ColoredBox(
        color: KColors.bg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                KSpacing.gutter,
                24,
                KSpacing.gutter,
                0,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: ShellSafeTextInput(
                    onArrowDown: () =>
                        _fieldFocus.focusInDirection(TraversalDirection.down),
                    child: KTextField(
                      key: const ValueKey('search-field'),
                      controller: _controller,
                      focusNode: _fieldFocus,
                      autofocus: true,
                      large: true,
                      hint: l10n.librarySearchHint,
                      prefixIcon: PhosphorIconsLight.magnifyingGlass,
                      textInputAction: TextInputAction.search,
                      onChanged: _onChanged,
                      semanticLabel: l10n.shellSearch,
                      suffix: _FieldSuffix(
                        loading: loading,
                        showClear: _controller.text.isNotEmpty,
                        onClear: _clear,
                        clearLabel: l10n.librarySearchClear,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (person == null)
              _FilterPills(filter: _filter, onChanged: _setFilter),
            Expanded(
              child: AnimatedSwitcher(
                duration: KMotion.of(context, KDurations.hover),
                child: body,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldSuffix extends StatelessWidget {
  const _FieldSuffix({
    required this.loading,
    required this.showClear,
    required this.onClear,
    required this.clearLabel,
  });

  final bool loading;
  final bool showClear;
  final VoidCallback onClear;
  final String clearLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (loading)
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: KSpinner(size: 18, strokeWidth: 2),
          ),
        if (showClear)
          KIconButton(
            icon: PhosphorIconsBold.x,
            size: 34,
            iconSize: 15,
            // A remote reaches it with → from the end of the text.
            focusable: KTvMode.of(context),
            tooltip: clearLabel,
            onPressed: onClear,
          ),
      ],
    );
  }
}

class _FilterPills extends StatelessWidget {
  const _FilterPills({required this.filter, required this.onChanged});

  final SearchFilter filter;
  final ValueChanged<SearchFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    String label(SearchFilter f) => switch (f) {
      SearchFilter.all => l10n.librarySearchFilterAll,
      SearchFilter.movies => l10n.librarySearchFilterMovies,
      SearchFilter.shows => l10n.librarySearchFilterShows,
      SearchFilter.live => l10n.librarySearchFilterLive,
      SearchFilter.people => l10n.librarySearchFilterPeople,
    };
    return FocusTraversalGroup(
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final f in SearchFilter.values)
            KPill(
              key: ValueKey('search-filter-${f.name}'),
              label: label(f),
              selected: f == filter,
              onTap: () => onChanged(f),
            ),
        ],
      ),
    );
  }
}

/// The result sections of a query.
class _ResultList extends ConsumerWidget {
  const _ResultList({
    required this.playlistId,
    required this.results,
    required this.scroll,
    required this.onOpenVod,
    required this.onVodMenu,
    required this.onPlayChannel,
    required this.onChannelMenu,
    required this.onOpenProgramme,
    required this.onToggleReminder,
    required this.onOpenPerson,
  });

  final int playlistId;
  final SearchResults results;
  final ScrollController scroll;
  final ValueChanged<VodItem> onOpenVod;
  final void Function(VodItem item, Offset position) onVodMenu;
  final ValueChanged<ChannelHit> onPlayChannel;
  final void Function(ChannelHit channel, Offset position) onChannelMenu;
  final ValueChanged<ProgrammeHit> onOpenProgramme;
  final ValueChanged<ProgrammeHit> onToggleReminder;
  final ValueChanged<PersonHit> onOpenPerson;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final r = results;
    final sections = <Widget>[
      if (r.movies.isNotEmpty)
        _PosterSection(
          key: const ValueKey('section-movies'),
          title: l10n.librarySearchMovies,
          items: r.movies,
          onOpen: onOpenVod,
          onMenu: onVodMenu,
        ),
      if (r.series.isNotEmpty)
        _PosterSection(
          key: const ValueKey('section-shows'),
          title: l10n.librarySearchShows,
          items: r.series,
          onOpen: onOpenVod,
          onMenu: onVodMenu,
        ),
      if (r.channels.isNotEmpty)
        _ChannelSection(
          key: const ValueKey('section-channels'),
          playlistId: playlistId,
          channels: r.channels,
          onPlay: onPlayChannel,
          onMenu: onChannelMenu,
        ),
      if (r.programmes.isNotEmpty)
        _ProgrammeSection(
          key: const ValueKey('section-programmes'),
          playlistId: playlistId,
          programmes: r.programmes,
          onOpen: onOpenProgramme,
          onMenu: onChannelMenu,
          onToggleReminder: onToggleReminder,
        ),
      if (r.people.isNotEmpty)
        _PeopleSection(
          key: const ValueKey('section-people'),
          people: r.people,
          onOpen: onOpenPerson,
        ),
    ];
    return FocusTraversalGroup(
      child: ListView.separated(
        key: ValueKey('results-${r.filter.name}'),
        controller: scroll,
        padding: const EdgeInsets.only(top: 22, bottom: 56),
        itemCount: sections.length,
        separatorBuilder: (_, _) => const SizedBox(height: 18),
        itemBuilder: (_, i) => sections[i],
      ),
    );
  }
}

class _PosterSection extends StatelessWidget {
  const _PosterSection({
    super.key,
    required this.title,
    required this.items,
    required this.onOpen,
    required this.onMenu,
  });

  final String title;
  final List<VodItem> items;
  final ValueChanged<VodItem> onOpen;
  final void Function(VodItem item, Offset position) onMenu;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SearchSectionTitle(title: title, count: items.length),
        KHorizontalRow(
          itemCount: items.length,
          itemWidth: SearchPosterCard.width,
          itemHeight: SearchPosterCard.height,
          itemBuilder: (context, i) => SearchPosterCard(
            key: ValueKey('vod-${items[i].kind.name}-${items[i].providerId}'),
            item: items[i],
            onTap: () => onOpen(items[i]),
            onContextMenu: (pos) => onMenu(items[i], pos),
          ),
        ),
      ],
    );
  }
}

class _ChannelSection extends ConsumerWidget {
  const _ChannelSection({
    super.key,
    required this.playlistId,
    required this.channels,
    required this.onPlay,
    required this.onMenu,
  });

  final int playlistId;
  final List<ChannelHit> channels;
  final ValueChanged<ChannelHit> onPlay;
  final void Function(ChannelHit channel, Offset position) onMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final clock = currentMinuteOf(ref);
    final fmt = ref.watch(timeFormatProvider);
    final keys = [
      for (final c in channels)
        if (c.epgChannelId != null) c.epgChannelId!,
    ];
    final nowNext = ref
        .watch(
          searchNowNextProvider((
            playlistId: playlistId,
            keys: keys.join(searchKeySeparator),
          )),
        )
        .value;
    ProgrammeView? nowOf(ChannelHit c) {
      final key = c.epgChannelId;
      final fresh = key == null ? null : nowNext?[key]?.now;
      if (fresh != null) return fresh;
      final hit = c.now;
      if (hit == null || !hit.isOnAirAt(clock)) return null;
      return ProgrammeView(
        id: hit.id,
        epgChannelId: hit.epgChannelId,
        start: hit.start,
        stop: hit.stop,
        title: hit.title,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SearchSectionTitle(
          title: l10n.librarySearchChannels,
          count: channels.length,
        ),
        KHorizontalRow(
          itemCount: channels.length,
          itemWidth: SearchChannelCard.width,
          itemHeight: SearchChannelCard.height,
          itemBuilder: (context, i) => SearchChannelCard(
            key: ValueKey('channel-${channels[i].providerId}'),
            channel: channels[i],
            now: nowOf(channels[i]),
            clock: clock,
            format: fmt,
            onTap: () => onPlay(channels[i]),
            onContextMenu: (pos) => onMenu(channels[i], pos),
          ),
        ),
      ],
    );
  }
}

class _ProgrammeSection extends ConsumerWidget {
  const _ProgrammeSection({
    super.key,
    required this.playlistId,
    required this.programmes,
    required this.onOpen,
    required this.onMenu,
    required this.onToggleReminder,
  });

  final int playlistId;
  final List<ProgrammeHit> programmes;
  final ValueChanged<ProgrammeHit> onOpen;
  final void Function(ChannelHit channel, Offset position) onMenu;
  final ValueChanged<ProgrammeHit> onToggleReminder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final clock = currentMinuteOf(ref);
    final fmt = ref.watch(timeFormatProvider);
    final locale = ref.watch(appLocaleCodeProvider);
    final reminders = ref.watch(searchReminderKeysProvider(playlistId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SearchSectionTitle(
          title: l10n.librarySearchProgrammes,
          count: programmes.length,
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: KSpacing.gutter),
          child: LayoutBuilder(
            builder: (context, constraints) {
              const gap = 14.0;
              final columns = constraints.maxWidth >= 900 ? 2 : 1;
              final width =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: 10,
                children: [
                  for (final p in programmes)
                    SizedBox(
                      width: width,
                      child: SearchProgrammeTile(
                        key: ValueKey('programme-${p.id}'),
                        programme: p,
                        clock: clock,
                        format: fmt,
                        localeCode: locale,
                        hasReminder:
                            p.channels.isNotEmpty &&
                            reminders.contains(
                              reminderKey(
                                p.channels.first.providerId,
                                p.start.millisecondsSinceEpoch,
                              ),
                            ),
                        onTap: () => onOpen(p),
                        onContextMenu: (pos) {
                          final channel = p.channels.firstOrNull;
                          if (channel != null) onMenu(channel, pos);
                        },
                        onToggleReminder: () => onToggleReminder(p),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PeopleSection extends StatelessWidget {
  const _PeopleSection({super.key, required this.people, required this.onOpen});

  final List<PersonHit> people;
  final ValueChanged<PersonHit> onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SearchSectionTitle(
          title: l10n.librarySearchPeople,
          count: people.length,
        ),
        KHorizontalRow(
          itemCount: people.length,
          itemWidth: SearchPersonTile.width,
          itemHeight: SearchPersonTile.height,
          spacing: 12,
          itemBuilder: (context, i) => SearchPersonTile(
            key: ValueKey('person-${people[i].name}'),
            person: people[i],
            onTap: () => onOpen(people[i]),
          ),
        ),
      ],
    );
  }
}

/// "Search by actor": every movie and show with [name] in the cast.
class _PersonResults extends ConsumerWidget {
  const _PersonResults({
    required this.playlistId,
    required this.name,
    required this.scroll,
    required this.onBack,
    required this.onOpen,
    required this.onMenu,
  });

  final int playlistId;
  final String name;
  final ScrollController scroll;
  final VoidCallback onBack;
  final ValueChanged<VodItem> onOpen;
  final void Function(VodItem item, Offset position) onMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final args = (playlistId: playlistId, name: name);
    final async = ref.watch(titlesByPersonProvider(args));
    final titles = async.value;
    final count = (titles?.movies.length ?? 0) + (titles?.series.length ?? 0);
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(40, 14, KSpacing.gutter, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          KIconButton(
            key: const ValueKey('person-back'),
            icon: PhosphorIconsBold.caretLeft,
            size: 40,
            iconSize: 18,
            tooltip: l10n.librarySearchBackToResults,
            onPressed: onBack,
          ),
          const SizedBox(width: 16),
          ClipOval(child: KMonogram(name: name, size: 56)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.librarySearchByActor.toUpperCase(),
                  style: KText.menuHeader.copyWith(color: KColors.accent),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KText.largeTitle,
                ),
                if (titles != null)
                  Text(l10n.libraryTitleCount(count), style: KText.caption),
              ],
            ),
          ),
        ],
      ),
    );

    final Widget content;
    if (titles == null) {
      content = async.hasError
          ? KErrorState(
              message: l10n.librarySearchFailed,
              onRetry: () => ref.invalidate(titlesByPersonProvider(args)),
            )
          : const KLoadingState();
    } else if (titles.isEmpty) {
      content = KEmptyState(
        icon: PhosphorIconsLight.userCircle,
        message: l10n.librarySearchNoTitlesWith(name),
        actionLabel: l10n.librarySearchBackToResults,
        onAction: onBack,
      );
    } else {
      content = FocusTraversalGroup(
        child: ListView(
          controller: scroll,
          padding: const EdgeInsets.only(top: 20, bottom: 56),
          children: [
            if (titles.movies.isNotEmpty)
              _PosterSection(
                key: const ValueKey('person-movies'),
                title: l10n.librarySearchMovies,
                items: titles.movies,
                onOpen: onOpen,
                onMenu: onMenu,
              ),
            if (titles.movies.isNotEmpty && titles.series.isNotEmpty)
              const SizedBox(height: 18),
            if (titles.series.isNotEmpty)
              _PosterSection(
                key: const ValueKey('person-shows'),
                title: l10n.librarySearchShows,
                items: titles.series,
                onOpen: onOpen,
                onMenu: onMenu,
              ),
          ],
        ),
      );
    }
    return Column(
      key: ValueKey('person-$name'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        Expanded(child: content),
      ],
    );
  }
}

/// The minute clock (falls back to the clock source while it loads).
DateTime currentMinuteOf(WidgetRef ref) =>
    ref.watch(minuteClockProvider).value ?? ref.read(clockSourceProvider)();

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/core.dart';
import '../../data/db/tables.dart';
import '../../data/repositories/favorites_repository.dart';
import '../../data/text/normalize.dart';
import '../../l10n/gen/app_localizations.dart';
import '../settings/widgets/text_input_dialog.dart';

/// "Add to favorite with tags": the playlist's tags as
/// multi-select chips, a "New tag" field and Save. Saving adds the item to
/// the favorites (when needed) and replaces its tags. Right-click a tag to
/// rename or delete it.
class FavoriteTagsSheet extends ConsumerStatefulWidget {
  const FavoriteTagsSheet({
    super.key,
    required this.playlistId,
    required this.type,
    required this.providerId,
    required this.title,
  });

  final int playlistId;
  final ItemType type;
  final String providerId;

  /// The item's name, shown under the sheet title.
  final String title;

  @override
  ConsumerState<FavoriteTagsSheet> createState() => _FavoriteTagsSheetState();
}

class _FavoriteTagsSheetState extends ConsumerState<FavoriteTagsSheet> {
  final TextEditingController _newTag = TextEditingController();
  final FocusNode _newTagFocus = FocusNode(debugLabel: 'new-tag');
  List<FavoriteTag> _tags = const [];
  final Set<int> _selected = {};

  /// New tag names (selected); created on Save.
  final List<String> _pending = [];
  bool _loading = true;
  bool _saving = false;
  bool _wasFavorite = false;

  FavoritesRepository get _repo => ref.read(favoritesRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _newTag.dispose();
    _newTagFocus.dispose();
    super.dispose();
  }

  Future<void> _load({bool keepSelection = false}) async {
    final tags = await _repo.tags(widget.playlistId);
    final current = keepSelection
        ? null
        : await _repo.tagsFor(
            widget.playlistId,
            widget.type,
            widget.providerId,
          );
    final favorite = keepSelection
        ? _wasFavorite
        : await _repo.isFavorite(
            widget.playlistId,
            widget.type,
            widget.providerId,
          );
    if (!mounted) return;
    setState(() {
      _tags = tags;
      if (current != null) {
        _selected
          ..clear()
          ..addAll(current.map((t) => t.id));
      }
      _selected.removeWhere((id) => !tags.any((t) => t.id == id));
      _wasFavorite = favorite;
      _loading = false;
    });
  }

  static String _clean(String name) =>
      name.trim().replaceAll(RegExp(r'\s+'), ' ');

  void _addPending() {
    final name = _clean(_newTag.text);
    if (name.isEmpty) return;
    final key = normalizeForSearch(name);
    bool same(String other) =>
        other == name || (key.isNotEmpty && normalizeForSearch(other) == key);
    final existing = _tags.where((t) => same(t.name)).firstOrNull;
    setState(() {
      if (existing != null) {
        _selected.add(existing.id);
      } else if (!_pending.any(same)) {
        _pending.add(name);
      }
      _newTag.clear();
    });
    _newTagFocus.requestFocus();
  }

  void _toggle(FavoriteTag tag) => setState(() {
    if (!_selected.remove(tag.id)) _selected.add(tag.id);
  });

  Future<void> _save() async {
    if (_saving) return;
    _addPending();
    setState(() => _saving = true);
    final l10n = L10n.of(context);
    final toasts = ref.read(toastControllerProvider);
    final navigator = Navigator.of(context);
    try {
      final ids = {..._selected};
      for (final name in _pending) {
        ids.add(await _repo.createTag(widget.playlistId, name));
      }
      await _repo.setTags(
        widget.playlistId,
        widget.type,
        widget.providerId,
        ids,
      );
      toasts.show(
        _wasFavorite ? l10n.libraryTagsSaved : l10n.libraryTagsAddedToFavorites,
      );
      if (mounted) navigator.pop();
    } catch (e) {
      debugPrint('Favorite tags: save failed: $e');
      toasts.show(l10n.libraryActionFailed, kind: KToastKind.error);
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _tagMenu(FavoriteTag tag, Offset position) async {
    final l10n = L10n.of(context);
    final action = await showKContextMenu<String>(
      context,
      position: position,
      title: tag.name,
      entries: [
        KMenuEntry(
          label: l10n.libraryTagsRename,
          icon: PhosphorIconsLight.pencilSimple,
          value: 'rename',
        ),
        KMenuEntry(
          label: l10n.libraryTagsDelete,
          icon: PhosphorIconsLight.trash,
          value: 'delete',
          destructive: true,
        ),
      ],
    );
    if (!mounted || action == null) return;
    final toasts = ref.read(toastControllerProvider);
    if (action == 'delete') {
      await _repo.deleteTag(tag.id);
      toasts.show(l10n.libraryTagsDeleted);
      await _load(keepSelection: true);
      return;
    }
    final name = await showLibraryTextInput(
      context,
      title: l10n.libraryTagsRename,
      initialValue: tag.name,
      allowEmpty: false,
    );
    if (!mounted || name == null || _clean(name) == tag.name) return;
    final ok = await _repo.renameTag(tag.id, name);
    if (ok) {
      toasts.show(l10n.libraryTagsRenamed);
    } else {
      toasts.show(l10n.libraryTagsNameTaken, kind: KToastKind.error);
    }
    await _load(keepSelection: true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final chips = <Widget>[
      for (final tag in _tags)
        KPill(
          key: ValueKey('tag-${tag.id}'),
          label: tag.name,
          selected: _selected.contains(tag.id),
          leading: Icon(
            _selected.contains(tag.id)
                ? PhosphorIconsBold.check
                : PhosphorIconsLight.tag,
          ),
          onTap: () => _toggle(tag),
          onContextMenu: (pos) => _tagMenu(tag, pos),
        ),
      for (final name in _pending)
        KPill(
          key: ValueKey('pending-$name'),
          label: name,
          selected: true,
          leading: const Icon(PhosphorIconsBold.plus),
          onTap: () => setState(() => _pending.remove(name)),
        ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 26, 28, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 48),
            child: Row(
              children: [
                const Icon(
                  PhosphorIconsFill.tag,
                  size: 22,
                  color: KColors.accent,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(l10n.libraryTagsTitle, style: KText.title),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(right: 48),
            child: Text(
              widget.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: KText.bodySecondary,
            ),
          ),
          const SizedBox(height: 22),
          Text(l10n.libraryTagsHeader.toUpperCase(), style: KText.sectionLabel),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: KSpinner(size: 22)),
            )
          else if (chips.isEmpty)
            Text(l10n.libraryTagsNone, style: KText.caption)
          else
            FocusTraversalGroup(
              child: Wrap(spacing: 8, runSpacing: 10, children: chips),
            ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: KTextField(
                  controller: _newTag,
                  focusNode: _newTagFocus,
                  hint: l10n.libraryTagsNewHint,
                  prefixIcon: PhosphorIconsLight.tag,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addPending(),
                  semanticLabel: l10n.libraryTagsNewHint,
                ),
              ),
              const SizedBox(width: 10),
              KButton.secondary(
                label: l10n.libraryTagsAdd,
                icon: PhosphorIconsBold.plus,
                onPressed: _addPending,
              ),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              KButton.secondary(
                label: l10n.cancel,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: 10),
              KButton.accent(
                label: l10n.save,
                icon: PhosphorIconsBold.check,
                onPressed: _loading || _saving ? null : _save,
                minWidth: 120,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

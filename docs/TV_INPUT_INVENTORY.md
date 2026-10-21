# Carina: input-handling inventory for Android TV (D-pad) port

Scope: `lib/features/*`, `lib/player/ui/`, `lib/app/shell/`, `lib/core/widgets/` (generated `*.g.dart` and `lib/l10n/gen/` ignored).
Method: read-only grep of `LogicalKeyboardKey`, `Shortcuts`/`CallbackShortcuts`, `onKeyEvent`, `SingleActivator`, `MouseRegion`, `onHover`, `GestureDetector`, `Listener`, `Platform.is*`, `TextField`, `FocusNode`, plus targeted reads of each handler. Line numbers are from the working tree at `/Volumes/Extreme SSD/Egemen/Projects/Local/carina`.
Flutter framework defaults were checked in the local SDK at `/opt/homebrew/share/flutter/packages/flutter/lib/src/widgets/app.dart:1263-1282`.
Not verified: runtime behaviour, and how Android Back is delivered by the Flutter embedder. Items marked **verify** need a device check.

Legend: **select-gap** = Enter/NumpadEnter handled at a screen level but `LogicalKeyboardKey.select` (the D-pad OK key) is not.

---

## 0. Shared primitives (core/widgets)

### k_interactive.dart (the primitive)
- Keyboard shortcuts, lines 148-155: `enter`, `numpadEnter`, `space`, `select` to `ActivateIntent`; `contextMenu` and `Shift+F10` to `KContextMenuIntent`.
- Actions, lines 229-251: `ActivateIntent` / `ButtonActivateIntent` call `onTap`; `KContextMenuIntent` calls `onContextMenu` at the element centre (227).
- Focus: `FocusableActionDetector` wraps the element only when `focusable` (302-312). Focus highlight is `onShowFocusHighlight` (309).
- Hover: `MouseRegion` (295-300) sets `_hovered`; `state.highlighted = hovered || focused` (39).
- Pointer: `GestureDetector` (265-286): tap (270), double-tap (271), secondary tap to context menu (272-277), long-press to context menu (278-284).
- Click also focuses the element (205-210).
- No arrow-key handling. Arrows fall through to Flutter's default directional traversal (see section 12).

### k_focusable.dart
- `KFocusable` (31-145) wraps `KInteractive`. Scale 1.04 when highlighted (45, 114-116). Ring when highlighted or selected (127-130). Exposes `onFocusChange` (64) and `onHoverChange` (67).
- `FocusableCard` (158-243) is the standard card surface (`color`, `borderRadius`, stroke, clip).

### k_context_menu.dart
- Keys (`_onKey`, 218-260): `arrowDown`/`tab` (223-230, shift+tab goes up), `arrowUp` (232-235), `home` (236-239), `end` (240-243), `enter`/`numpadEnter`/`space`/`select` activate (244-250), `escape` closes (251-258).
- Hover drives the highlight: `onEnter`/`onExit` (405-408, 302-308). Tap on row (409-412).
- Focus node and `Focus` at 313-316.

### k_horizontal_row.dart
- Keys: `arrowLeft`/`arrowRight` move focus between cards (202-220). Focus scrolls the row (`_onItemFocusChanged`, 222-229).
- Pointer wheel to horizontal scroll (174-200). `Listener` at 282-283.
- Edge arrows are hover-only: `_EdgeArrow visible: _hovered && _canLeft` (292-299). `MouseRegion` at 273-275.

### k_text_field.dart
- Wraps `TextField` (162-192). Hover is only a `MouseRegion` for cursor and border colour (194-199).
- No key handling.

### k_pin_pad.dart
- `_onKey` (131-151): digits 0-9 and numpad (59-79, 135-139), `backspace`/`delete` (141-145), `escape` cancels when `onCancel` is set (146-149).
- Outer scrim `GestureDetector` dismisses on tap (438-440).
- Focus at 266-269.

### k_popover_menu.dart
- Stepper items only: `arrowLeft`/`arrowRight` (211-229).
- Other items are `KInteractive` (239, 604).

### k_sheet.dart / k_popup.dart
- Scrim `GestureDetector` dismisses on tap (167-170). `barrierDismissible` (31, 43, 117).
- No `escape` binding in these files. Flutter's default `DismissIntent` on escape (widgets/app.dart:1272) may cover it. **verify**.

### k_toast.dart
- Toast is a `GestureDetector` with `onTap` (420-421). It is not focusable and has no keyboard path. The close `KIconButton` (555) is a separate element.

### k_top_nav.dart
- Tabs are `KInteractive` (251, 282, 404, 509).
- Window drag and double-tap maximise, `GestureDetector` (232-237). Desktop only.

### k_caption_buttons.dart / window/window_controls.dart
- `Platform`/`defaultTargetPlatform` gates (`k_caption_buttons.dart:31-33`, `window_controls.dart:44-46`). Desktop window chrome only.

### Other core widgets with no key or pointer handling
- `k_logo_tile`, `k_badges`, `k_panel`, `k_progress`, `k_states`, `k_theme`/`tokens`.
- Interactive ones are KInteractive-based: `k_buttons` (178, 325, 425, 500; `KIconButton` 382), `k_fab` (29), `k_pill` (50, 283), `k_settings` (125, 199, 320, 419; `KSwitch` 371), `k_popover_menu` (604).

---

## 1. App shell (app/, app/shell/)

### app/app.dart
- `CallbackShortcuts` (56-60): `F11` toggles full screen. Desktop-only.

### app/shell/playlist_shell.dart
- Keys (`CallbackShortcuts` 189-211): `Ctrl`/`Cmd`+`1`-`4` (190-202), `Ctrl`/`Cmd`+`F` search (203-206), `Ctrl`/`Cmd`+`,` settings (207-210).
- `Focus` 212-225: `/` opens search (217-224), skipped when an `EditableText` has focus (222).
- `select`, `enter`, `escape`: none here.
- Platform: `Platform.isMacOS ? 72 : 0` (231).
- Pointer: none directly. Tabs come from `KTopNav`.
- Note: this shell `Focus` (autofocus, 212-214) is the root focus for the tab screens.

### app/shell/category_sidebar.dart
- Escape closes (`CallbackShortcuts` 134-135). `FocusScope autofocus` (136-137).
- Scrim `GestureDetector` closes on tap (44-48). Scrim is `IgnorePointer` when closed (37).
- Items are `KInteractive` (241-250); `state.highlighted` (246) covers hover and focus.
- Back on TV: only Escape. No Back handling.

### app/shell/category_selection.dart, shell_state.dart
- No input handling.

### app/window_setup.dart, app/bootstrap.dart
- `Platform.isWindows/isMacOS/isLinux` (`window_setup.dart:23`, `38` `windowButtonVisibility: Platform.isMacOS`, `bootstrap.dart:96`). Desktop window setup.

---

## 2. Player (player/ui/)

### player_screen.dart
- Root `Focus` (758-760) with `_onKey` (666-691).
  - Key-up ignored (667).
  - Modal (resume offer or failure): only Escape reaches the player, plus zap keys on live (672-677).
  - Shortcut lookup via `playerShortcutFor` (678-684). If it returns a command the key is `handled` (689-690). If not, the key is ignored and controls are shown on key-down (686).
  - Keys handled here: see `player_shortcuts.dart` (section 2 below).
- Escape: via `player_shortcuts.dart:158-160` (back).
- Pointer:
  - `Listener` (761-763): mouse back button (`kBackMouseButton`) to `back()` (693-698).
  - Scroll wheel (700-718): live with wheel-zap enabled zaps; otherwise volume +/-5.
  - `MouseRegion onHover` (764-767) calls `_showControls()`. No hover on TV.
  - Video `GestureDetector` (775-781): tap (778) calls `_onVideoTap` (574-583): live opens the action sheet, VOD toggles play. Double-tap (779) toggles full screen.
  - Bar `MouseRegion` (833-835) pins controls while the pointer is over the bar (`_pointerOverBar`, consulted in `_maybeHide` 221).
- Focus is re-requested to the root in several places: lines 141, 177, 308, 383, 401, 415, 440.
- Controls auto-hide: `_scheduleHide` (209-212), `_maybeHide` (214-226). Controls are shown by `_showControls` (204-207), which is called from seek (596, 599), key-down on unhandled keys (686), and others.
- Platform: none.

### player_shortcuts.dart (key mapping, `playerShortcutFor` 141-266)
- Escape, `browserBack`, `goBack` to back (158-162). Backspace to back on VOD (225).
- Letter keys: `M` / `audioVolumeMute` (163-166), `F` full screen (167), `A` audio menu (168), `S` subtitles (169), `I` info (170-174), `K` play/pause on VOD (227), `J` / `mediaRewind` seek back (241-243), `L` / `mediaFastForward` seek forward (244-247), `N` / `mediaTrackNext` next episode on VOD (260-263), `G` mini guide on live (214-216).
- Volume: `=` / `+` / `numpadAdd` / `audioVolumeUp` (175-180); `-` / `numpadSubtract` / `audioVolumeDown` (181-185).
- `[` / `]` audio delay (186-191).
- Live branch (195-222):
  - `arrowUp` / `pageUp` / `channelUp` zap previous (196-203). With info panel open, `arrowUp` closes it (199-200).
  - `arrowDown` / `pageDown` / `channelDown` zap next (204-208).
  - `enter` / `numpadEnter` / **`select`** open the action sheet (209-213). Select is present here.
  - `backspace` previous channel (217-219). Digits: number zap (220).
  - `arrowLeft` / `arrowRight` are not mapped on live, so they are ignored (falls through to default focus traversal).
- VOD and catch-up branch (224-264):
  - `space` / `K` / `mediaPlayPause` / `mediaPlay` / `mediaPause` / `enter` / `numpadEnter` toggle play (226-234). **select-gap**: `LogicalKeyboardKey.select` is missing (lines 226-232).
  - `arrowLeft` / `arrowRight` seek, shift for long seek (235-240). Always consumed (returns a command), so they never reach directional focus.
  - `arrowUp` volume up, or close info panel if open (248-252). Always consumed.
  - `arrowDown` info panel, or volume down if controls hidden (253-258). Returns null (ignored) only when the info panel is open.
  - Digits: seek to percent (264).

### player/ui/guide/player_mini_guide.dart
- `Focus` (163-165) with `_onKey` (126-156):
  - Close: `escape` (132), `keyG` (133), `backspace` (134), `arrowLeft` (135).
  - Move selection: `arrowUp` / `arrowDown` (140-148).
  - Tune: `enter` / `numpadEnter` / `arrowRight` (149-154). **select-gap** at 149-151.
- Rows: `MouseRegion` (271-275) with hover highlight (`onHover` at 216-220). Tap `GestureDetector` (275-277) and `onTap` tune (221-224).
- Hover highlight and keyboard `selected` both apply (`highlighted = selected || hovered`, 270).

### player/ui/widgets/seek_bar.dart
- Not focusable: no `Focus`, no `KInteractive`. D-pad cannot reach it.
- `MouseRegion` (134-140): `onHover` sets hover X and calls `onInteraction` (controls show); `onExit` clears.
- Hover tooltip (127-132, `_Tooltip` 228, 294).
- `GestureDetector` (141-175): `onTapUp` seeks (143-147), horizontal drag start/update/end seeks (148-173).
- Keyboard seek exists only as shortcuts in `player_shortcuts.dart` (235-240, 264).

### player/ui/widgets/player_button.dart
- `PlayerIconButton` (9-86): `KInteractive` (31-33). Tooltip on hover (75).
- `PlayerPillButton` (88-): `KInteractive` (110-112) with optional `focusNode`.
- `FocusOnMount` (169-185): requests focus on mount.

### player/ui/widgets/player_bars.dart
- `PlayerMenuButtons` (32-62): `PlayerIconButton` (57-62).
- `VodBottomBar` (102-): `onInfo` on a KInteractive (213).
- `LiveBottomBar` (313-): `onOptions` (443).
- `PlayerHint` (452-471): `KInteractive` (466-471). Hover-only colour (`state.hovered`, 471).

### player/ui/widgets/player_overlays.dart
- `_SheetPill` (244-): `KInteractive` (261-264). Used by the action sheet (see below).
- Resume prompt `onTap` (198, 204), error overlay buttons `onPressed` (107-132), `NextEpisodeCard` (370, 388), `SkipIntroPill` (400-410), `PausedIndicator` (609-622) use `PlayerIconButton`/`KIconButton` (364).
- Overlays (`ZapOsd`, `NumberOsd`, `VolumeOsd`, `MuteIndicator`, `FlashOsd`): display only.

### player/ui/widgets/action_sheet.dart
- `LiveActionSheet` (24-79): `SheetPill` items with `onTap` (63-79). `FocusTraversalGroup` (41). First pill `autofocus: true` (62). Keyboard via `KInteractive`, so select works.

### player/ui/widgets/info_panel.dart, player_menus.dart, player_chapters.dart, player_options.dart, player_route.dart, player_window.dart, player_texts.dart, data/player_queries.dart, guide/mini_guide_adapter.dart
- No key, hover or pointer handling found by grep.

---

## 3. Guide (features/guide/)

### src/guide_grid.dart (the EPG canvas)
- `Focus` (637-640, `autofocus` from widget) with `_onKey` (465-497):
  - Arrows move row and cell: `arrowUp` / `arrowDown` (470-473), `arrowLeft` / `arrowRight` (474-477).
  - `pageUp` / `pageDown` (478-481). `home` jumps to now (482-483).
  - `enter` / `numpadEnter` / `space` / **`select`** activate (484-488).
  - `contextMenu` and `Shift+F10` open channel actions (489-492).
  - Escape: none here. The overlay handles it (see below).
- Pointer, canvas `GestureDetector` (668-674):
  - `onTapDown` / `onTapUp` (670-671): focus and activate the cell (534-550).
  - `onSecondaryTapUp` (673) and `onLongPressStart` (674): channel actions (552-559).
- Pointer, `Listener` (692-697):
  - Scroll wheel (561-576); Shift+wheel is horizontal (569-572).
  - Middle-button drag pans (578-596). **No keyboard equivalent for free pan**, though arrows and page keys scroll (low impact).
- Hover (`MouseRegion` 708-715): `onHover` sets selection hover (523-526). `onExit` clears (528-532). Keyboard focus sets the same selection (323-333), so hover and focus both highlight.
- Channel column `KInteractive` (1026-1032) and programme cells `KInteractive` (1166-1172) are `focusable: false`. Focus lives on the single grid `Focus`.
- Platform: none. Text fields: none.

### src/guide_overlay.dart
- `CallbackShortcuts` escape to `widget.onClose` (277-280). Full-guide close key.
- Channel actions open on pointer (260-270).

### src/mini_guide_overlay.dart
- `Focus` (245-247) with `_onKey` (143-169):
  - `arrowUp` / `arrowDown` select (147-150).
  - `arrowLeft` / `arrowRight` cycle category, key-down only (151-154).
  - `enter` / `numpadEnter` / `select` tune (155-162). Select present.
  - `escape` close (163-164).
- Rows: `KInteractive` `focusable: false` (336-338). `onTap` (337). Hover and `selected` both highlight (342).

### src/archive_sheet.dart
- Programme rows are `KInteractive` with `autofocus` (248-251). Focus draws the pill (254-255). Hover only lightens.

### src/guide_info_panel.dart, guide_preview.dart, guide_cells.dart, guide_canvas.dart, programme_details_sheet.dart, guide_actions.dart, guide_controller.dart
- No direct input handlers.

### guide_screen.dart
- Channel actions via `guide_actions` on pointer (322). `Tooltip` (365).

---

## 4. Home movies / shows (features/home_movies/, features/home_shows/)

### widgets/vod_grid.dart
- Filter field `KTextField` (439). `_filterFocus` (89), `_gridFocus` (93), `_bodyFocus` (99).
- `Focus` (296-298) with `_onKey` (175-208):
  - When the grid itself has focus, `arrowDown` or `arrowRight` enter the first cell (181-189).
  - `escape`: unfocus filter (192-194), else `onBack` (196-199).
  - `backspace` calls `onBack` when the filter is not focused (201-206).
- Body `Focus` (314-319, `canRequestFocus: false`).
- Context menu via `showVodActions` (587, 663) on `FocusableCard.onContextMenu`. Keyboard route is `KFocusable`.
- Platform: none.

### widgets/vod_hero.dart
- `MouseRegion` (318-320): hover pauses the hero carousel (`hold`/`release`).
- `Focus` (321-325, `canRequestFocus: false`): `onFocusChange` holds and releases too. Focus and hover both pause the carousel.

### widgets/vod_cards.dart
- `FocusableCard` (66-80): `onHoverChange` (69-71) and `onFocusChange` (72-74) both call `onHighlight`. Hover and focus are equivalent.
- `KInteractive` poster variant (232-241): same pattern (236-241).

### widgets/vod_home_view.dart, vod_rows.dart, vod_trending.dart, vod_actions.dart, vod_art.dart, vod_meta.dart, vod_providers.dart
- Context actions via `showVodActions` (vod_home_view.dart:183). Rows use `KHorizontalRow` (section 0). No other direct handlers.

### features/details/
- `details_parts.dart` `KInteractive` (67, 242). `VodPlayRing` highlight uses `state.hovered` only (81, 253). Focus gives no ring change here.
- `series_details_sheet.dart`: `KIconButton` (421), `KInteractive` (476).
- `movie_details_sheet.dart`: `KIconButton` (169).
- `details_api.dart`: `showVodActions` (48).

---

## 5. Live TV (features/live/)

### live_screen.dart
- Root `Focus` (778-780) with `_onScreenKey` (661-698). KeyDown only (662).
  - Digits 0-9 and numpad: number zap, if the setting is on and no ctrl, meta or alt (666-675). Map at 634-654.
  - Only when zap digits are pending (676-678): `backspace` removes a digit (679-686), `escape` clears (687-691), `enter` / `numpadEnter` commit (692-696). **select-gap** at 692-693.
  - With no pending digits, Enter is ignored and reaches the focused `KInteractive`.
- List `Focus` (911-912) with `_onListKey` (533-563):
  - `arrowDown` / `arrowUp` move (539-546). `arrowUp` on the first row goes to the category pill (542-543).
  - `pageDown` / `pageUp` (547-550), `home` / `end` (551-554).
  - `arrowLeft` opens the category sidebar (555-556). `arrowRight` goes to the upcoming panel (557-558).
- Grid `Focus` (1026-1029, `canRequestFocus: false`) with `_onGridKey` (566-605):
  - `arrowLeft` at column 0 opens sidebar (574-579), otherwise moves (578).
  - `arrowRight`, `arrowUp` (goes to pill on top row, 584), `arrowDown`, page, home, end (591-598).
- Pill `Focus` (839-840) with `_onPillKey` (607-618): `arrowDown` focuses the selected card, `arrowLeft` opens the sidebar.
- Upcoming `Focus` (957-958) with `_onUpcomingKey` (621-628): `arrowLeft` returns to the selected card.
- Escape: zap-digit clearing only (687-691). There is no Back to leave the live tab from this screen.
- Focus on card: `_onCardFocus` (328-340) selects the channel with a delay. Preview plays on keyboard focus as well as selection.
- Platform: none. `HardwareKeyboard.instance.isShiftPressed` (channel_actions.dart:215) is a modifier check, not a platform check.

### widgets/channel_cards.dart
- `LiveListCard` (45-66): `FocusableCard` with `KFocusRingWidth.tv` (55). `onHoverChange` sets `_hovered` (59). `onContextMenu` (60).
- Grid card (170-215): same pattern (176-177). `LiveMoreButton` at 212.
- `LiveMoreButton` (342-372): visible only when `_hovered` (354-358). `KIconButton` `focusable: false` (364). The "more" button is not focusable and is hidden without hover. (113-116 for the list card.)
- Keyboard route to the same menu: `Menu`/`contextMenu` or `Shift+F10` through `KInteractive` (k_interactive.dart:153-154). See the long-press issue in section 10.

### preview/live_preview_view.dart
- `KInteractive` `focusable: false` (83-86): `onTap` activates, `onContextMenu` (86).
- `_HoverPlay` overlay shows on hover only: `state.hovered && video != null` (118-119). Focus does not show it.

### widgets/upcoming_panel.dart
- Rows `KInteractive` (137). `firstRowFocusNode` at index 0 (70). Button `KInteractive` (263). Tooltip hover (281).

### widgets/live_overlays.dart, now_on_air_panel.dart, live_marquee.dart, layouts/live_layouts.dart, state/*
- No direct input handlers (`live_overlays.dart` takes a `focusNode` only, line 20).

### actions/custom_epg_picker.dart
- Escape pops (`CallbackShortcuts` 189-193).
- Search `Focus` (209-210) with `_onFieldKey` (143-150): `arrowDown` to first result row (145-148).
- Search field `KTextField` (211). Result rows `KInteractive` (279).

### actions/rename_category_sheet.dart
- Escape pops (`CallbackShortcuts` 86-90). Text `KTextField` (102).

### actions/channel_actions.dart, channel_dump.dart, parental_pin.dart
- `channel_actions.dart:215` reads Shift via `HardwareKeyboard` for the action's behaviour. No pointer handlers here.

---

## 6. Multiview (features/multiview/)

### multiview_screen.dart
- Root `Focus` (317-319) with `_onKey` (262-296):
  - `escape`: leave full tile (269-270), else `_leave` (272).
  - `enter` / `numpadEnter` toggle the focused tile to full (277-281). **select-gap** at 277-278.
  - Arrows move focus between tiles when not full (282-294), using `neighborTile` (292).
- Tiles (`_Tile` around 655-668):
  - `MouseRegion` (662-664) sets `_hoveredTile` (407-413). Chrome shows on `hovered || focused` (661).
  - `GestureDetector` (665-668): `onTap` focuses the tile (415-417, `_focus.requestFocus`), `onDoubleTap` toggles full (668).
  - Tiles are not focusable. Keyboard focus is an index on the root `Focus`.
- Top bar `KIconButton` (468, 773, 782, 791, 801), `Tooltip` (509, 743), `KInteractive` (511, 588).
- Focus re-requests: lines 95, 217, 228, 416.
- Platform: none.

### channel_picker.dart
- `Focus` (151-153) wraps a search `KTextField` (153). `_onKey` (114-135):
  - `arrowDown` / `arrowUp` move selection (120-128).
  - `enter` / `numpadEnter` pick (129-132). **select-gap** at 129-130.
  - No `escape` handling in this file.
- Result rows `KInteractive` `focusable: false` (210-213). Keyboard can select the row but **OK does not pick it**; only tap or Enter.

---

## 7. Playlists (features/playlists/)

### playlist_manager_screen.dart
- `CallbackShortcuts` (111-117): `Ctrl`/`Cmd`+`N` adds a playlist. Desktop shortcut.

### playlist_wizard_screen.dart
- Escape: `_onEscape` (764-765).
- Field navigation: `CallbackShortcuts` (856-860) `arrowDown` / `arrowUp` call `_move(1)` / `_move(-1)` (see 245). Field focus nodes (63-65).
- Text fields via `_text` helper (871-886), `KTextField` (882). `KIconButton` (779).
- Choosers use `wizard_widgets.dart` rows.

### widgets/wizard_widgets.dart
- Row `KInteractive` with `focusNode` (87-92). `onTap` (88).
- Step arrows: `CallbackShortcuts` `arrowLeft` / `arrowRight` on the row (118-126) cycle values.
- Other `KInteractive` at 162 and 373.

### widgets/playlist_avatar_tile.dart
- Hover `MouseRegion` (175-177) and focus listener (76-77). `showMore = hovered || focused` (66). Both paths work.
- Tile `KInteractive` (69). `KIconButton` (193).

### widgets/manager_rail.dart
- `MouseRegion` hover (57-59), `Focus` (`canRequestFocus: false`, 60-63) `onFocusChange`. `_expanded = hovered || focused` (51). Both work.
- Rail items `KInteractive` (157).

### widgets/playlist_dialog.dart
- Escape to `onDismiss` (94-96). `FocusScope autofocus` (96-97). Dialog `KInteractive` (187).

### import_progress_screen.dart
- Escape cancels import (`CallbackShortcuts` 310-311). `FocusScope autofocus` (312-313). `barrierDismissible: false` (154, 198).

### avatar_picker_screen.dart
- Escape to `goBackFromPlaylists` (123-127). `KInteractive` (183, 264). `KIconButton` (142, 147).

### widgets/playlists_chrome.dart
- `Platform.isMacOS` (10) gives a 34 px title inset. Not relevant on Android, but dead spacing.

### playlist_access.dart, data/*, playlist_details_sheet.dart
- `playlist_details_sheet.dart:70` `KIconButton`. No other direct handlers.

---

## 8. Settings (features/settings/)

### settings_screen.dart
- Keyed `Focus` (264-268, `canRequestFocus: false`) with `_onKey` (146-160):
  - `escape`: unfocus text field if focused (152-153), else close subpage (154-155), else `_leave` (157).
- `_contentFocus` focus node (58, 231-232). Re-requested on open and close (122, 128).
- `_leave` (132-144) uses `router.go`. This bypasses the navigator, so system Back is not wired to it.
- `LibraryStandalonePage` (271-275) for the non-playlist case.

### widgets/standalone_page.dart
- `CallbackShortcuts` escape to `onBack` (34-35). Platform (63): `Platform.isMacOS ? 72 : 0`.
- `LibraryBackButton` (70-82): `KInteractive` (82). Used in `downloads_screen.dart:66` and `settings_screen.dart:315,400`.

### widgets/settings_widgets.dart
- `SettingsActionRow` (58-): `KInteractive` (83-84), `onTap`.
- `SettingSpecRow` (236-): `SettingsRow` with `onTap` (276).
- `SettingsListTile` (149-205): plain `Container`. Not focusable or tappable. Used with trailing controls such as `KIconButton` (app_sections.dart:277-292), so the trailing control is the only focus target.

### widgets/shell_safe_input.dart
- Wrapper (`Focus`, `canRequestFocus: false`) for text fields inside the shell (17-43).
  - `/` swallowed with `skipRemainingHandlers` (20-25) so shell search shortcut does not fire.
  - `arrowDown` calls `onArrowDown` and consumes the key (26-30).

### widgets/text_input_dialog.dart
- `KTextField` (138) and `KInteractive` (199).

### sections/app_sections.dart, parental_section.dart, subpages.dart, playlist_sections.dart
- `KTextField` (`app_sections.dart:179`). Parental `onTap` (`parental_section.dart:209`). `SettingsListTile` trailing `KIconButton` (`app_sections.dart:292`).

---

## 9. Search (features/search/)

### search_screen.dart
- Escape (`_onKey` 178-190, `Focus` 339-342, `canRequestFocus: false`):
  - Focuses the field if not focused (183-184), else clears text (185-186), else exits person page (187-188), else `_leave` (190).
- Search `KTextField` (361). `_fieldFocus` (58). `_focusField` (119).
- Context menus: `showVodActions` (208), `showChannelActions` (228). `KIconButton` (423, 803).
- Text entry on TV: requires the Android IME. See section 10.

### search_widgets.dart
- `KIconButton` (429).

---

## 10. Cross-cutting issues

### 10a. Enter/Space handled but `select` is not
| Screen | Location | Handled keys | Missing |
|---|---|---|---|
| Player VOD / catch-up play-pause | player/ui/player_shortcuts.dart:226-232 | space, K, mediaPlayPause, mediaPlay, mediaPause, enter, numpadEnter | `select` |
| Player mini guide (tune) | player/ui/guide/player_mini_guide.dart:149-151 | enter, numpadEnter, arrowRight | `select` |
| Multiview channel picker (pick) | features/multiview/channel_picker.dart:129-130 | enter, numpadEnter | `select` |
| Multiview fullscreen tile | features/multiview/multiview_screen.dart:277-278 | enter, numpadEnter | `select` |
| Live number-zap commit | features/live/live_screen.dart:692-693 | enter, numpadEnter (only with pending digits) | `select` |

Handled with `select` (for reference): k_interactive.dart:152, guide_grid.dart:487, mini_guide_overlay.dart:157, k_context_menu.dart:247, player_shortcuts.dart:211 (live).

### 10b. Escape (or backspace) used as "back"
Escape is the only back path in these files. There is no `PopScope`, `didPopRoute` or `BackButtonListener` anywhere under `lib/` (grep confirmed).
- category_sidebar.dart:135 (close sidebar)
- guide_overlay.dart:279 (close full guide)
- mini_guide_overlay.dart:163-164
- player_mini_guide.dart:132 (also G, backspace, arrowLeft at 133-135)
- player_shortcuts.dart:158-160 (escape, browserBack, goBack); backspace on VOD at 225
- live_screen.dart:687 (clears zap digits only)
- multiview_screen.dart:268
- search_screen.dart:179-180
- settings_screen.dart:147-148
- standalone_page.dart:35
- import_progress_screen.dart:311 (cancel import)
- avatar_picker_screen.dart:125
- playlist_dialog.dart:95
- playlist_wizard_screen.dart:765
- custom_epg_picker.dart:191
- rename_category_sheet.dart:88
- vod_grid.dart:191 and backspace 201-206
- k_context_menu.dart:251, k_pin_pad.dart:146

Android TV Back: **verify** on device. The Flutter Android embedder usually delivers the system Back as a navigation pop (`popRoute`), not as a key event. If so, none of the Escape bindings above fire, and only the Navigator/GoRouter default pop runs.

### 10c. Hover-only affordances (no equivalent on focus)
- Live list and grid cards, "more" (⋯) button: channel_cards.dart:113-116, 212 (visible when `_hovered`), button at 342-372 with `focusable: false` (364). Keyboard route is Menu or Shift+F10 on the card.
- Live preview "play" overlay: live_preview_view.dart:118-119 (`state.hovered`). Preview itself plays on focus.
- Horizontal row edge arrows: k_horizontal_row.dart:292-299 (`_hovered`). Focus scrolls the row (226), so low impact.
- Player controls shown on pointer hover: player_screen.dart:764-767. On TV, controls only appear through `_showControls` from specific keys (686, 596, 599, 400). **verify** that every D-pad key shows controls.
- Seek-bar hover tooltip: seek_bar.dart:134-140, 228. The seek bar is not focusable at all.
- Player bar hover pin: player_screen.dart:833-835 (affects auto-hide only).
- Player hint colour: player_bars.dart:471 (`state.hovered`). Focus gives no change.
- Details play ring: details_parts.dart:81, 253 (`state.hovered`). Focus gives no change.
- Both hover and focus work: guide cells (guide_grid.dart:523-532 with selection 323-333), mini guide rows (player_mini_guide.dart:216-220, 270), VOD cards (vod_cards.dart:69-74), VOD hero (vod_hero.dart:318-325), multiview tile chrome (multiview_screen.dart:661), manager rail (manager_rail.dart:51), playlist avatar (playlist_avatar_tile.dart:66), context-menu rows (k_context_menu.dart:302-308), generic `highlighted` (k_interactive.dart:39).

### 10d. Pointer-only gestures with no keyboard equivalent (or none on TV)
- Middle-button drag pan in guide: guide_grid.dart:578-596 (`Listener` 692-697). Arrow and page keys cover scrolling.
- Mouse back button: player_screen.dart:693-698. TV has no mouse.
- Player wheel: volume or zap, player_screen.dart:700-718. Keys exist (`+`/`-`, zap keys).
- Seek drag and tap: seek_bar.dart:141-175. Keys exist (arrow seek, digit percent), but the bar is not focusable.
- Scrim tap dismiss, no Back: category_sidebar.dart:44-48; k_sheet.dart:167-170; k_pin_pad.dart:438-440.
- Toast tap: k_toast.dart:420-421. Not focusable.
- Multiview tile tap and double-tap: multiview_screen.dart:665-668. Tiles not focusable.
- Right-click and long-press context menus: k_interactive.dart:272-284, guide_grid.dart:552-559, 673-674. These are the pointer route to context menus (see 10e).

### 10e. Long-press and context menu on a D-pad remote
Context menus open through: secondary click, pointer long-press (k_interactive.dart:272-284), `LogicalKeyboardKey.contextMenu`, and Shift+F10 (k_interactive.dart:153-154; guide_grid.dart:489-492). A D-pad OK long-press arrives as repeated key-down, not as a long-press gesture, and KInteractive has no key-hold timer. The contextMenu key depends on the remote having a Menu key. Used by: channel cards (channel_cards.dart:60, 177), VOD cards (vod_cards.dart:68, 234), VOD grid (vod_grid.dart:587, 663), search (search_screen.dart:208, 228), playlist avatars, guide cells.

### 10f. Elements that are not focusable (`focusable: false` or `canRequestFocus: false`)
- Guide channel column and programme cells: guide_grid.dart:1028-1029, 1167 (focus is on the single grid `Focus`, 637-640).
- Mini guide rows: mini_guide_overlay.dart:336-338.
- Multiview channel picker rows: channel_picker.dart:210-213.
- Multiview tiles: multiview_screen.dart:662-668.
- Live preview: live_preview_view.dart:83-84.
- Live "more" button: channel_cards.dart:364.
- Live grid `Focus` and body wrappers: live_screen.dart:1026-1029; vod_grid.dart:314-319; vod_hero.dart:321-323; search_screen.dart:339-342; settings_screen.dart:264-268; manager_rail.dart:60-62.
- Seek bar: no focus node at all (seek_bar.dart).
- Toast: k_toast.dart:420.
These need per-item focus or key routing on TV.

### 10g. Text input
- `KTextField` wraps `TextField` (k_text_field.dart:162). Text fields: favorite_tags_sheet.dart:266; vod_grid.dart:439; custom_epg_picker.dart:211; rename_category_sheet.dart:102; channel_picker.dart:153; search_screen.dart:361; app_sections.dart:179; text_input_dialog.dart:138; playlist_wizard_screen.dart:882.
- On Android TV the text entry needs the IME. The code has no IME or on-screen keyboard handling.
- Shell `/` search key (playlist_shell.dart:217-224) and `ShellSafeTextInput` (shell_safe_input.dart) are desktop-keyboard concerns.
- Wizard `arrowUp` / `arrowDown` CallbackShortcuts (playlist_wizard_screen.dart:856-860) override directional traversal inside forms.

### 10h. Letter and modifier-only shortcuts (no remote keys for them)
- Player letters: M, F, A, S, I, K, J, L, N, G, `[`, `]`, `+`, `-` (player_shortcuts.dart:163-191, 214, 227, 241-263). Each must have an on-screen control, or the action is unreachable on TV. Menu buttons exist (player_bars.dart:32-62); verify mini guide and info panel.
- Ctrl/Cmd combos: playlist_shell.dart:192-210; playlist_manager_screen.dart:113-116; player_shortcuts.dart:154 (Ctrl/Cmd+Shift+D).
- F11: app.dart:58.
- Backspace as back: player_shortcuts.dart:217, 225; vod_grid.dart:201-206; player_mini_guide.dart:134.

### 10i. Platform checks (desktop-only code paths)
- `Platform.isWindows/isMacOS/isLinux`: window_setup.dart:23, 38; bootstrap.dart:96; window_controls.dart:46; reminder_services.dart:36; dio_factory.dart:18-25 (OS string); app_paths.dart:26; playlist_shell.dart:231 (72 px inset); standalone_page.dart:63 (72 px inset); playlists_chrome.dart:10 (34 px inset).
- `defaultTargetPlatform` windows/linux: k_caption_buttons.dart:31-33.
- `kIsWeb` and `FLUTTER_TEST`: window_controls.dart:44-45; k_network_image.dart:70.
- Android-specific code: none. `core/theme.dart:143-148` has page transitions for all platforms.

### 10j. Focus-management fragility
- Player root focus re-requested in 7 places (player_screen.dart:141, 177, 308, 383, 401, 415, 440). When controls are hidden the root `Focus` is the only focus target.
- Several wrappers use `canRequestFocus: false` with `skipTraversal` (settings_screen.dart:264-268; search_screen.dart:339-342; live_screen.dart:1026-1029; vod_grid.dart:314-319; vod_hero.dart:321-323; manager_rail.dart:60-62; popover stepper k_popover_menu.dart:235-238; wrappers in k_horizontal_row.dart:284-288). These route keys without taking focus; ordering with `autofocus` is fragile.

---

## 11. Top 15 problems for D-pad use (ordered by severity)

1. **No Back handling for the system Back button.** Escape is the only back path (about 19 sites, section 10b). No `PopScope` or `didPopRoute` under `lib/`. Sidebar, full guide, mini guide, multiview, settings subpages, search, dialogs and the player's Back all depend on Escape or `goBack`/`browserBack`. Verify on device. Blocker. (category_sidebar.dart:135; guide_overlay.dart:279; player_shortcuts.dart:158-160; settings_screen.dart:146-160; multiview_screen.dart:268)
2. **Player arrows are consumed on VOD and catch-up, so D-pad cannot move between control buttons.** The root `Focus` returns handled for every shortcut (player_screen.dart:689-690). VOD branch maps all four arrows (player_shortcuts.dart:235-258): left/right seek, up volume, down info panel. Directional traversal never runs. Blocker for VOD. (live branch 195-222 leaves left/right unmapped.)
3. **Mini guide OK does not tune.** Only Enter, NumpadEnter and right arrow tune (player_mini_guide.dart:149-151). Rows are not focusable. Blocker for live zapping through the guide.
4. **VOD and catch-up OK does not play or pause.** `select` is missing from the play-pause mapping (player_shortcuts.dart:226-232). With no button focused, OK does nothing. High.
5. **Multiview channel picker OK does not pick.** `select` missing (channel_picker.dart:129-130). Rows are `focusable: false` (210-213). Blocker for adding a channel to multiview.
6. **Multiview OK does not toggle fullscreen tile.** `select` missing (multiview_screen.dart:277-278). Tiles are not focusable (662-668). High.
7. **Number-zap commit OK does not work.** `select` missing (live_screen.dart:692-693). Typing digits works; committing with OK does not. High.
8. **Context menus need long-press, right-click, Menu key or Shift+F10.** D-pad OK long-press is not a pointer long-press (k_interactive.dart:153-154, 272-284). Affects channel cards, VOD cards, search, playlist tiles and guide cells. No on-screen equivalent (the "more" button is hover-only). High.
9. **Most rich elements are non-focusable.** Guide cells, mini guide rows, channel picker rows, multiview tiles, live preview, "more" button, toasts (section 10f). Focus model must be rebuilt per item on TV. High.
10. **Seek bar cannot be focused and shows its time only on hover.** seek_bar.dart:134-140 and 228; no focus node at all. Keyboard seek works only through the VOD arrow shortcuts. Medium-high.
11. **Hover-only affordances:** live "more" button (channel_cards.dart:113-116, 212), live hover-play (live_preview_view.dart:118-119), row edge arrows (k_horizontal_row.dart:292-299), player control reveal on pointer hover (player_screen.dart:764-767). Medium.
12. **Text entry and form navigation.** `KTextField` relies on the platform IME; no on-screen keyboard handling (k_text_field.dart:162). Escape in search clears text (search_screen.dart:179-190). Wizard `arrowUp` / `arrowDown` CallbackShortcuts override traversal inside forms (playlist_wizard_screen.dart:856-860). Medium.
13. **Desktop-only and letter-key shortcuts with no remote equivalent.** Player letters M, F, A, S, I, K, J, L, N, G, brackets (player_shortcuts.dart:163-263); Ctrl/Cmd combos (playlist_shell.dart:192-210; playlist_manager_screen.dart:113-116); F11 (app.dart:58). Each action needs an on-screen control. Medium.
14. **Pointer-only gestures with no D-pad path.** Middle-drag pan (guide_grid.dart:578-596); mouse back button (player_screen.dart:693-698); wheel zap or volume (player_screen.dart:700-718); seek drag (seek_bar.dart:148-173); scrim taps for dismiss (category_sidebar.dart:44-48; k_sheet.dart:167-170; k_pin_pad.dart:438-440). Medium-low; keys exist for most, scrims need Back.
15. **Focus-management fragility.** Player root focus re-requested in 7 places (player_screen.dart:141-440). Several `canRequestFocus: false` wrappers that route keys without taking focus (section 10j). Initial focus and focus return after overlays may land on a non-visible node. Medium. Platform-only code (section 10i: window controls, 72 px and 34 px macOS insets, `window_setup.dart`) also needs guarding for Android, low.

---

## 12. Summary of the two core primitives (for the port design)

- `KInteractive` (k_interactive.dart) gives every core control: hover state (MouseRegion, 295-300), focus state (FocusableActionDetector, 302-312), Enter, NumpadEnter, Space and Select activate (148-155), Menu or Shift+F10 context menu (153-154), pointer tap, double-tap, secondary tap and long-press (265-284). Clicking also focuses the element (205-210).
- `KFocusable` / `FocusableCard` (k_focusable.dart) add the tvOS-style scale-up, white ring, shadow and `onFocusChange` / `onHoverChange` on top of `KInteractive`.
- Missing for TV: no key-hold (long-press) to context menu; no arrow handling (left to Flutter defaults, which WidgetsApp maps in the SDK at widgets/app.dart:1277-1282 to `DirectionalFocusIntent`); no Back or escape in the primitive; hover-only states are the same as focus for `highlighted` but not for other custom uses.
- Keyboard focus highlight follows Flutter's highlight mode (k_interactive.dart:292-294), which is keyboard-driven on TV. Hover on TV has no effect.
- Default arrow traversal is unavailable inside the player root and inside the grid-style wrappers listed in 10j, because those consume arrows first.

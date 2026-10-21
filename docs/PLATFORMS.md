# Carina on Android TV / Google TV — plan

Status: **in progress** on branch `android-tv` (started 2026-10-21).

Scope: **Android TV / Google TV** next to the existing desktop builds
(macOS, Windows). Phones, tablets and iOS are out of scope (decided
2026-10-21); the Android build declares itself TV-only.

Legend: **[code]** = verified by reading the current code. **[device]** = an
assumption that must be confirmed on an emulator or a real TV before we rely
on it.

## 1. Where we start

- One Flutter codebase, ~103k lines in `lib/`, desktop-first UI:
  `kMinWindowSize` 1100×680, design size 1440×900. **[code]**
- The design system is already tvOS-style: `KFocusable` does focus rings,
  scale-on-focus, Enter/Space activation and long-press context menus;
  live, guide, player, pin pad and menus have keyboard navigation;
  `LogicalKeyboardKey.select` is handled in 5 places. **[code]**
- Desktop-only plugins (`window_manager`, `local_notifier`) are already
  behind `Platform.isWindows/isMacOS/isLinux` checks. **[code]**
- media_kit resolves `media_kit_libs_android_video`. **[code]** Codec coverage
  on Android is **[device]**.
- Back is handled with Escape (20 places); there is no `PopScope`. **[code]**
- 16 files use hover (`MouseRegion` / `onHover`) for affordances. **[code]**

## 2. Toolchain (done)

- Flutter 3.47.7 (same as CI): `/Volumes/Extreme SSD/Egemen/DeveloperTools/flutter/bin/flutter`.
  The Homebrew Flutter in `/opt/homebrew/share/flutter` is 3.47.5 and does
  not satisfy `sdk: ^3.13.5`.
- Android SDK: `/Volumes/Extreme SSD/Egemen/DeveloperTools/android-sdk`;
  JDK 17: `/opt/homebrew/opt/openjdk@17/...` (set with `flutter config`).
- The SSD path contains a space, which breaks the `sdkmanager` shell script.
  Run it through Java directly:
  ```sh
  CT="$SDK/cmdline-tools/latest"
  /opt/homebrew/opt/openjdk@17/bin/java -Dcom.android.sdklib.toolsdir="$CT" \
    -classpath "$CT/lib/*" com.android.sdklib.tool.sdkmanager.SdkManagerCli \
    --sdk_root="$SDK" <packages>
  ```
- Emulator image: `system-images;android-34;google-tv;arm64-v8a`.

## 3. Phases

Each phase reports **code**, **automated tests**, **visual check**
(screenshot harness) and **device acceptance** separately.

### Phase 0 — Scaffolding and go/no-go spike

1. `android/` runner; `applicationId` / namespace `app.carina.player`.
2. Manifest: `INTERNET` in the main manifest (the template only has it in
   debug/profile), cleartext HTTP allowed (IPTV is mostly `http://`),
   `LEANBACK_LAUNCHER`, `android.software.leanback` **required**,
   `android.hardware.touchscreen` not required, 320×180 banner, landscape.
3. Spike on the Google TV emulator with the mock server
   (`http://10.0.2.2:8787` from the emulator):
   - app boots to the Playlist Manager;
   - playback of every fixture: H.264/AAC TS, AC-3 5.1, HEVC/E-AC-3 2160p,
     MPEG-2 576i, live HLS, VOD with Range (`hwdec` mediacodec, software
     fallback);
   - SQLite FTS5 search;
   - large-scale Xtream + XMLTV import completes.
   Real-device check (Google TV stick class, 2 GB RAM) when available.

Done when the checklist is filled in with pass/fail per item. A failure in
playback or FTS5 stops the work for a decision.

### Phase 1 — Platform layer

- `lib/app/platform/`: `isTv` / form-factor provider (leanback feature via a
  small MethodChannel or `device_info_plus`), wakelock during playback,
  one back handler (`PopScope`) so the remote's Back does what Escape does.
- Reminders on TV: scheduled OS notifications via
  `flutter_local_notifications` (`POST_NOTIFICATIONS`); desktop keeps
  `local_notifier`.
- `AppPaths`, `SecretStore` (Android Keystore), `defaultUserAgent()`
  (`Android`) checked on Android.

### Phase 2 — TV layout and D-pad (design-heavy)

- Render the desktop layout into a fixed logical canvas (start 1280×720,
  tune) scaled to the screen, with a ~5% overscan safe area. Fix individual
  screens that read badly at TV distance.
- Focus audit on every screen: sidebar, top bar, playlist manager and
  wizard, live, guide grid, movies/shows, details, search, settings,
  dialogs, player overlays, multiview. No traps, every control reachable,
  visible focus everywhere.
- Remote keys: select/OK = activate, long-press OK = context menu, Back =
  pop, media play/pause, channel up/down, number zapping.
- Hover-only affordances get a focus equivalent.
- Text entry with the TV on-screen keyboard (playlist wizard, search, PIN).
- Player: controls appear on any key, OK toggles play/pause.
- Multiview: cap at 2 decoders on TV (tunable).

Done: **tests** — screenshot harness at 960×540 / 1280×720 for the main
screens, focus traversal widget tests. **visual** — screenshots reviewed.
**device** — full flow with the remote only: add playlist, import, live zap,
guide, catch-up, VOD resume, search, parental PIN.

### Phase 3 — CI and packaging

- `.github/workflows/android.yml` (Ubuntu): analyze, test, build release APK
  (arm64-v8a + armeabi-v7a), upload as artifact.
- Release signing key kept outside the repo (GitHub secret); never committed.
- Push only with explicit approval (public repo).

## 4. Decisions

| Topic | Decision |
|---|---|
| Platforms | Android TV / Google TV + existing macOS/Windows. No phone, tablet, iOS. |
| Distribution | Sideloaded APK first. Store release is a later, separate decision (GPL-3.0 + libmpv/FFmpeg licensing, Play policy for IPTV players). |
| Downloads | Desktop only for now; hidden on TV. |
| Multiview | Max 2 decoders on TV, tune on device. |
| TV layout | Scaled desktop layout first, bespoke screens only where needed. |

## 5. Risks

| Risk | Mitigation |
|---|---|
| A codec fails with mediacodec | `MpvEngine` already falls back to software decoding; verify in Phase 0 |
| Large imports on 2 GB TV sticks | Already streaming + batched; measure, lower batch size on TV |
| APK size (libmpv + FFmpeg per ABI) | Split per ABI |
| Text input on TV is painful | Later: add playlist from phone via QR + local web form |

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

**Results (2026-10-21/22, emulator `carina_gtv`, Google TV API 34 arm64,
debug APK, Impeller GLES).** The smoke test runs on the emulator through
the debug-only `carina_args` intent extra:
`adb shell am start -n app.carina.player/.MainActivity --es carina_args
"'--smoke-test --mock-url http://10.0.2.2:8787 --smoke-out
/data/user/0/app.carina.player/files/smoke.json'"`.

| Item | Result |
|---|---|
| Debug and release APK build | pass (release built before Phase 1; CI builds it now) |
| Boots to the Playlist Manager | pass |
| Xtream + XMLTV import (300 live, 2000 movies, 200 series, 66 583 programmes) | pass, 14–24 s |
| H.264/AAC TS decode | pass (`c2.goldfish.h264.decoder`, MediaCodec) |
| AC-3 5.1 decode | pass (6 ch) when it is the first stream |
| HEVC/E-AC-3 2160p, MPEG-2, HLS, VOD Range | not measured, see below |
| Video on screen | **emulator cannot tell**: mpv's `vo=gpu` fails `eglCreateContext` ("Could not create EGL context for GLES 2.x +") on both `-gpu host` and `-gpu swiftshader_indirect`, with and without Impeller. The first file decodes against the null VO; every later open fails because the VO cannot initialise. media_kit itself treats emulators as unsupported for hardware output. Needs a real device. |
| FTS5 search | import builds `programme_search`; UI search not exercised yet |
| Large import (`--scale large`) | not run |

`hwdec-current` and `video-codec` read back empty in the smoke result even
while MediaCodec decodes; the readout is wrong, not the decoder.
Real-device testing by testers is the next signal for playback.

### Phase 1 — Platform layer

Code is on branch `tv-platform`; everything that runs on Android is
**[device]** until a run on the emulator or a TV.

- `lib/app/platform/form_factor.dart`: `FormFactor { desktop, tv }`,
  `formFactorProvider` (overridden at bootstrap, `desktop` by default).
  Android asks `MainActivity` over `app.carina.player/platform` (`isTv`: UI
  mode television or the leanback feature); any Android counts as TV when
  the channel fails. `--tv` forces TV on desktop (UI gates only: OS
  integrations check `Platform.isAndroid`).
- Wakelock: `screenAwakeProvider` (`wakelock_plus`, Android only), held
  by the player while it plays and by multi-channel (ref-counted).
- Reminders: `flutter_local_notifications` on Android, `local_notifier` on
  desktop. `ReminderOsSync` schedules `zonedSchedule` notifications at
  `start - lead` (inexact alarms, UTC `TZDateTime`s: no exact-alarm
  permission, no timezone database); the due reminder replaces its
  notification (same id); `POST_NOTIFICATIONS` is requested when the first
  reminder is set. The Gradle file enables core library desugaring for it.
- Downloads: rail entry and `/downloads` hidden on TV. Multi-channel: two
  tiles (1 + 1) on TV.
- `AppPaths` (app support directory = app-private files), `SecretStore`
  (Android Keystore; `allowBackup=false` so a restored backup cannot leave
  undecryptable secrets) and `defaultUserAgent()` (`Carina/1.0 (Android)`)
  are in place. mpv sends the same per-OS agent (`lib/core/user_agent.dart`)
  unless the playlist overrides it.
- Still open: one back handler (`PopScope`) for the remote's Back key
  (Phase 2).

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

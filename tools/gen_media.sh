#!/usr/bin/env bash
if [ "${BASH_SOURCE[0]}" = "$0" ] && [ -z "${CARINA_GM_LF:-}" ] && grep -q "$(printf '\r')" "$0" 2>/dev/null; then _t="${TMPDIR:-/tmp}/carina_gen_media_$$.sh"; tr -d '\r' < "$0" > "$_t" && CARINA_GM_LF=1 CARINA_GM_SELF="$0" exec bash "$_t" "$@"; fi # CRLF checkout guard: re-run an LF copy
#
# tools/gen_media.sh - Carina test-media generator (docs/BRIEF.md section 11.1).
#
# Uses only ffmpeg and ffprobe. Writes into tools/mock_server/media/ (git-ignored):
#
#   h264_aac_1080p25.ts      H.264 High + AAC 2.0 48 kHz, 1920x1080 25p, MPEG-TS
#   h264_ac3_51_1080p25.ts   H.264 High + AC-3 5.1 384k, 1920x1080 25p, MPEG-TS
#   hevc_eac3_2160p25.ts     HEVC Main (x265 ultrafast) + E-AC-3 5.1, 3840x2160 25p, MPEG-TS
#   mpeg2_mp2_576i25.ts      MPEG-2 interlaced (top field first) + MP2 2.0, 720x576 25i 16:9, MPEG-TS
#   h264_aac_720p50.mp4      H.264 High + AAC 2.0, 1280x720 50p, MP4 with faststart
#   vod_tracks.mkv           H.264 720p25; audio eng AAC 2.0 "English" + tur AC-3 5.1 "Türkçe";
#                            subtitles eng + tur (SRT); chapters Intro (0-10 s), Main, Credits
#   img/poster_00..39.jpg (400x600), img/backdrop_00..19.jpg (1280x720),
#   img/logo_00..29.png (256x256), img/still_00..19.jpg (640x360)   original placeholder art
#   manifest.json            every file with codec details read back with ffprobe
#
# Videos are testsrc2 with burned-in text naming the codecs plus a running clock, and sine
# audio (in the 5.1 tracks every channel has its own frequency; the centre channel beeps once
# per second). Keyframes every 1-2 s; HEVC repeats VPS/SPS/PPS so a stream can be joined late.
#
# Usage:
#   bash tools/gen_media.sh [--out DIR] [--duration SEC] [--quick] [--force]
#                           [--only NAMES] [--text auto|drawtext|bitmap|none] [--verbose]
#
#   --out DIR       output folder (default: tools/mock_server/media next to this script)
#   --duration SEC  length of each video in seconds (default 90, minimum 12)
#   --quick         20-second videos (used by CI)
#   --force         rebuild files that already exist (default: keep them)
#   --only NAMES    comma-separated subset, e.g. "vod_tracks.mkv,images"
#   --text MODE     auto (default): drawtext when this ffmpeg has it and a test render works,
#                   otherwise a built-in 5x7 bitmap font that needs no libfreetype
#                   (Homebrew's ffmpeg has no drawtext). drawtext|bitmap|none force a mode.
#   --verbose       show ffmpeg's own progress output
#
# Environment: FFMPEG / FFPROBE override the binaries (default: PATH, then Chocolatey).
# Runs under bash 3.2 (macOS) and Git Bash on Windows. tools/live_hls.sh sources this file
# for its helpers; nothing runs when it is sourced.

GM_TAG=${GM_TAG:-gen_media}

gm_log() { printf '[%s] %s\n' "$GM_TAG" "$*"; }
gm_warn() { printf '[%s] WARNING: %s\n' "$GM_TAG" "$*" >&2; }
gm_die() {
  printf '[%s] ERROR: %s\n' "$GM_TAG" "$*" >&2
  exit 1
}

gm_is_windows() {
  case "$(uname -s 2>/dev/null)" in MINGW* | MSYS* | CYGWIN*) return 0 ;; esac
  return 1
}

# Path as the (native) ffmpeg binary expects it: C:/... under Git Bash, unchanged elsewhere.
gm_np() {
  if [ -n "${GM_CYGPATH:-}" ]; then cygpath -m "$1"; else printf '%s' "$1"; fi
}

# ffmpeg/ffprobe with MSYS argument conversion off: every path we pass is already native.
gm_ffx() { MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' "$FFMPEG" "$@"; }
gm_ffp() { MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' "$FFPROBE" "$@"; }

gm_ff() {
  if [ "${GM_VERBOSE:-0}" = 1 ]; then
    gm_ffx -nostdin -hide_banner -loglevel info -stats -y "$@"
  else
    gm_ffx -nostdin -hide_banner -loglevel error -nostats -y "$@"
  fi
}

gm_find_ffmpeg() {
  GM_CYGPATH=""
  if gm_is_windows && command -v cygpath >/dev/null 2>&1; then GM_CYGPATH=1; fi
  FFMPEG=${FFMPEG:-}
  FFPROBE=${FFPROBE:-}
  if [ -z "$FFMPEG" ]; then FFMPEG=$(command -v ffmpeg 2>/dev/null || true); fi
  if [ -z "$FFMPEG" ] && [ -x /c/ProgramData/chocolatey/bin/ffmpeg.exe ]; then
    FFMPEG=/c/ProgramData/chocolatey/bin/ffmpeg.exe
  fi
  [ -n "$FFMPEG" ] || gm_die "ffmpeg not found. Install it (macOS: brew install ffmpeg, Windows: choco install ffmpeg) or set FFMPEG=/path/to/ffmpeg."
  if [ -z "$FFPROBE" ]; then
    local d
    d=$(dirname "$FFMPEG")
    if [ -x "$d/ffprobe" ]; then
      FFPROBE="$d/ffprobe"
    elif [ -x "$d/ffprobe.exe" ]; then
      FFPROBE="$d/ffprobe.exe"
    else
      FFPROBE=$(command -v ffprobe 2>/dev/null || true)
    fi
  fi
  [ -n "$FFPROBE" ] || gm_die "ffprobe not found next to $FFMPEG or on PATH (set FFPROBE=/path/to/ffprobe)."
  GM_FFVER=$(gm_ffx -hide_banner -version 2>/dev/null | awk 'NR == 1 { print $3 }')
  [ -n "$GM_FFVER" ] || gm_die "cannot run $FFMPEG"
}

gm_has_filter() { gm_ffx -hide_banner -h "filter=$1" 2>/dev/null | grep -q "^Filter $1"; }

gm_find_fonts() {
  FONT=""
  FONT_BOLD=""
  local c
  for c in "/System/Library/Fonts/Supplemental/Arial.ttf" "/Library/Fonts/Arial.ttf" \
    "C:/Windows/Fonts/arial.ttf" "/c/Windows/Fonts/arial.ttf" \
    "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf" "/usr/share/fonts/TTF/DejaVuSans.ttf"; do
    if [ -f "$c" ]; then
      FONT=$(gm_np "$c")
      break
    fi
  done
  for c in "/System/Library/Fonts/Supplemental/Arial Bold.ttf" "/Library/Fonts/Arial Bold.ttf" \
    "C:/Windows/Fonts/arialbd.ttf" "/c/Windows/Fonts/arialbd.ttf" \
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" "/usr/share/fonts/TTF/DejaVuSans-Bold.ttf"; do
    if [ -f "$c" ]; then
      FONT_BOLD=$(gm_np "$c")
      break
    fi
  done
  if [ -z "$FONT_BOLD" ]; then FONT_BOLD=$FONT; fi
}

# Renders one tiny frame with exactly the drawtext options the real jobs use.
gm_probe_drawtext() {
  local saved=$TEXT_MODE
  TEXT_MODE=drawtext
  g_reset 320 180 25 0
  g_src "color=c=black:s=320x180:r=25:d=0.2"
  g_text "Probe: H.264 + AAC 2.0 | 5.1 (x/y) 50%" center 8 18 FFFFFF 1 1 1
  g_text "TITLE" 8 bottom:8 20 FFFFFF@0.8 0 1 1 "between(t,0,1)"
  g_clock stream center 60 24 FFD24A 1
  g_clock wall center 100 24 FFD24A 1
  g_chain "format=yuv420p"
  g_out pv
  TEXT_MODE=$saved
  gm_ffx -nostdin -hide_banner -loglevel error -filter_complex "$GF" -map "[pv]" -frames:v 2 -f null - >/dev/null 2>&1
}

gm_detect_text() {
  case "${TEXT_MODE:-auto}" in
    drawtext)
      gm_find_fonts
      return 0
      ;;
    bitmap | none) return 0 ;;
    auto) ;;
    *) gm_die "unknown --text mode '$TEXT_MODE' (auto, drawtext, bitmap or none)" ;;
  esac
  TEXT_MODE=bitmap
  if gm_has_filter drawtext; then
    gm_find_fonts
    if gm_probe_drawtext; then
      TEXT_MODE=drawtext
    else
      gm_warn "drawtext is available but a test render failed; using the built-in bitmap font"
    fi
  fi
}

# Escaping for values inside '...' in a filtergraph (the option parser still sees \ and :).
gm_fesc() {
  local s=$1 o="" c i
  for ((i = 0; i < ${#s}; i++)); do
    c=${s:i:1}
    case "$c" in
      \\) o="$o\\\\" ;;
      :) o="$o\\:" ;;
      \') gm_die "a quote in a filter value is not supported: $s" ;;
      *) o="$o$c" ;;
    esac
  done
  GM_ESC=$o
}

# drawtext text: drop quotes/backslashes, escape ':' for the option parser and '%' for expansion.
gm_dtesc() {
  local s=$1 o="" c i
  for ((i = 0; i < ${#s}; i++)); do
    c=${s:i:1}
    case "$c" in
      \\ | \') ;;
      :) o="$o\\:" ;;
      %) o="$o\\\\%" ;;
      *) o="$o$c" ;;
    esac
  done
  GM_ESC=$o
}

# ---------------------------------------------------------------------------------------------
# Filtergraph builder. A graph is a list of ';'-separated chains; GL is the current video label.
# Text helpers append drawtext filters, or bitmap-font overlays fed by extra inputs (GIN).
# ---------------------------------------------------------------------------------------------

g_reset() {
  GW=$1
  GH=$2
  GFPS=$3
  GIDX=${4:-0}
  GF=""
  GL=""
  GN=0
  GIN=()
}
g_add() { if [ -n "$GF" ]; then GF="$GF;$1"; else GF=$1; fi; }
g_src() {
  GN=$((GN + 1))
  g_add "$1[g$GN]"
  GL="[g$GN]"
}
g_from() { GL=$1; }
g_chain() {
  GN=$((GN + 1))
  g_add "$GL$1[g$GN]"
  GL="[g$GN]"
}
g_out() {
  g_add "${GL}null[$1]"
  GL="[$1]"
}
g_input() {
  GIN+=("$@")
  GIDX=$((GIDX + 1))
}

# gm_place X Y W H -> PX PY.  X: number | center | right:MARGIN   Y: number | center | bottom:MARGIN
gm_place() {
  case "$1" in
    center) PX=$(((GW - $3) / 2)) ;;
    right:*) PX=$((GW - $3 - ${1#right:})) ;;
    *) PX=$1 ;;
  esac
  case "$2" in
    center) PY=$(((GH - $4) / 2)) ;;
    bottom:*) PY=$((GH - $4 - ${2#bottom:})) ;;
    *) PY=$2 ;;
  esac
}

# g_text TEXT X Y SIZE COLOR [BOX] [SHADOW] [BOLD] [ENABLE]
#   SIZE is a drawtext font size in px; COLOR is RRGGBB or RRGGBB@alpha; ENABLE a timeline expr.
g_text() {
  case "$TEXT_MODE" in
    none) return 0 ;;
    drawtext) g_text_dt "$@" ;;
    *) g_text_bm "$@" ;;
  esac
}

g_text_dt() {
  local text=$1 x=$2 y=$3 size=$4 color=$5 box=${6:-0} shadow=${7:-0} bold=${8:-0} en=${9:-} raw=${10:-0}
  local font=$FONT s="drawtext=" xx yy
  if [ "$bold" = 1 ]; then font=$FONT_BOLD; fi
  if [ -n "$font" ]; then
    gm_fesc "$font"
    s="${s}fontfile='$GM_ESC':"
  fi
  if [ "$raw" = 1 ]; then GM_ESC=$text; else gm_dtesc "$text"; fi
  case "$x" in
    center) xx='(w-text_w)/2' ;;
    right:*) xx="w-text_w-${x#right:}" ;;
    *) xx=$x ;;
  esac
  case "$y" in
    center) yy='(h-text_h)/2' ;;
    bottom:*) yy="h-text_h-${y#bottom:}" ;;
    *) yy=$y ;;
  esac
  s="${s}text='$GM_ESC':fontsize=$size:fontcolor=0x$color:x=$xx:y=$yy"
  if [ "$box" = 1 ]; then s="$s:box=1:boxcolor=black@0.55:boxborderw=$((size / 4 + 2))"; fi
  if [ "$shadow" = 1 ]; then s="$s:shadowcolor=black@0.55:shadowx=$((size / 24 + 1)):shadowy=$((size / 24 + 1))"; fi
  if [ -n "$en" ]; then s="$s:enable='$en'"; fi
  g_chain "$s"
}

# Bitmap font scale for a drawtext-like size: cap height ~0.72*size, 7 font pixels per cap.
gm_bm_scale() {
  BMF=$(((${1} * 72 + 350) / 700))
  if [ "$BMF" -lt 1 ]; then BMF=1; fi
}

# gm_bm_layer SRC PRE W H COLOR SHADOW X Y ENABLE RATE
#   SRC is the label of a 4x gray glyph mask and PRE optional filters for it (e.g. a crop);
#   W x H is the final size. RATE is "still" for a single frame, else the frame rate of a
#   moving mask. Blends COLOR through the mask onto GL, with a soft shadow when SHADOW=1.
gm_bm_layer() {
  local src=$1 pre=$2 w=$3 h=$4 color=$5 shadow=$6 x=$7 y=$8 ena=$9 rate=${10}
  local hex=${color%@*} alpha=1 m mk csrc curve="clip((val-48)*1.35,0,255)"
  case "$color" in *@*) alpha=${color#*@} ;; esac
  csrc="s=${w}x${h}:r=$rate"
  if [ "$rate" = still ]; then csrc="s=${w}x${h}:r=1:d=1"; fi
  GN=$((GN + 1))
  m="m$GN"
  mk="[${m}g]"
  g_add "$src${pre}format=gray,scale=$w:$h:flags=bicubic$mk"
  if [ "$shadow" = 1 ]; then
    local o=$((h / 18 + 1))
    g_add "${mk}split[${m}g1][${m}g2]"
    g_add "[${m}g1]lut=y='$curve*$alpha*0.6'[${m}sa]"
    g_add "color=c=black:$csrc[${m}sc]"
    g_add "[${m}sc][${m}sa]alphamerge[${m}s]"
    GN=$((GN + 1))
    g_add "$GL[${m}s]overlay=x=$((x + o)):y=$((y + o)):format=auto$ena[g$GN]"
    GL="[g$GN]"
    mk="[${m}g2]"
  fi
  g_add "${mk}lut=y='$curve*$alpha'[${m}a]"
  g_add "color=c=0x$hex:$csrc[${m}c]"
  g_add "[${m}c][${m}a]alphamerge[${m}t]"
  GN=$((GN + 1))
  g_add "$GL[${m}t]overlay=x=$x:y=$y:format=auto$ena[g$GN]"
  GL="[g$GN]"
}

g_text_bm() {
  local text=$1 x=$2 y=$3 size=$4 color=$5 box=${6:-0} shadow=${7:-0} en=${9:-} ena="" w h idx
  gm_bm_scale "$size"
  w=$(((${#text} * 6 + 1) * BMF))
  h=$((9 * BMF))
  gm_place "$x" "$y" "$w" "$h"
  if [ -n "$en" ]; then ena=":enable='$en'"; fi
  gm_pgm "$text"
  idx=$GIDX
  g_input -i "$GM_PGM_N"
  if [ "$box" = 1 ]; then
    local p=$((size / 5))
    g_chain "drawbox=x=$((PX - p)):y=$((PY - p)):w=$((w + 2 * p)):h=$((h + 2 * p)):color=black@0.55:t=fill$ena"
  fi
  gm_bm_layer "[$idx:v]" "" "$w" "$h" "$color" "$shadow" "$PX" "$PY" "$ena" still
}

# g_clock stream|wall X Y SIZE COLOR [BOX]
#   stream: media time HH:MM:SS(.mmm); wall: local time of day (GM_WALL_S0 = seconds at start).
g_clock() {
  case "$TEXT_MODE" in
    none) return 0 ;;
    drawtext)
      local t='%{pts\:hms}'
      if [ "$1" = wall ]; then t='%{localtime\:%X}'; fi
      g_text_dt "$t" "$2" "$3" "$4" "$5" "${6:-0}" 0 1 "" 1
      ;;
    *) g_clock_bm "$@" ;;
  esac
}

# Bitmap clock: static "  :  :  " plus three crops of a looped "00".."59" strip whose y is
# computed from the frame time.
g_clock_bm() {
  local mode=$1 x=$2 y=$3 size=$4 color=$5 box=${6:-0} s0=0 w h ic is sp k v
  if [ "$mode" = wall ]; then s0=${GM_WALL_S0:-0}; fi
  gm_bm_scale "$size"
  w=$((49 * BMF))
  h=$((9 * BMF))
  gm_place "$x" "$y" "$w" "$h"
  gm_clock_assets
  ic=$GIDX
  g_input -i "$WORK_N/clock_colons.pgm"
  is=$GIDX
  g_input -loop 1 -framerate "$GFPS" -i "$WORK_N/clock_strip_p5.pgm"
  if [ "$box" = 1 ]; then
    local p=$((size / 5))
    g_chain "drawbox=x=$((PX - p)):y=$((PY - p)):w=$((w + 2 * p)):h=$((h + 2 * p)):color=black@0.55:t=fill"
  fi
  gm_bm_layer "[$ic:v]" "" "$w" "$h" "$color" 0 "$PX" "$PY" "" still
  GN=$((GN + 1))
  sp="c$GN"
  g_add "[$is:v]split=3[${sp}0][${sp}1][${sp}2]"
  for k in 0 1 2; do
    case $k in
      0) v="mod(floor((t+$s0)/3600),24)" ;;
      1) v="mod(floor((t+$s0)/60),60)" ;;
      2) v="mod(floor(t+$s0),60)" ;;
    esac
    gm_bm_layer "[${sp}$k]" "crop=w=52:h=36:x=0:y='36*$v'," "$((13 * BMF))" "$h" "$color" 0 \
      "$((PX + 18 * k * BMF))" "$PY" "" "$GFPS"
  done
}

# ---------------------------------------------------------------------------------------------
# Built-in 5x7 font (HD44780-style). Input lines "path<TAB>text" write a plain PGM per line
# (1 font pixel of padding); "@strip<TAB>path" writes "00".."59" stacked in 13x9 cells for the
# clock. Glyphs are upscaled 4x in awk with Scale2x (EPX) applied twice, which rounds corners
# and turns pixel staircases into clean diagonals, so ffmpeg only needs a bicubic resize.
# ---------------------------------------------------------------------------------------------
gm_font_awk() {
  cat <<'AWK'
BEGIN {
  FS = "\t"; HEX = "0123456789ABCDEF"; P[0] = 16; P[1] = 8; P[2] = 4; P[3] = 2; P[4] = 1
  G[" "] = "00000000000000"; G["!"] = "04040404040004"; G["\""] = "0A0A0A00000000"
  G["#"] = "0A0A1F0A1F0A0A"; G["$"] = "040F140E051E04"; G["%"] = "18190204081303"
  G["&"] = "0C12140815120D"; G["'"] = "0C040800000000"; G["("] = "02040808080402"
  G[")"] = "08040202020408"; G["*"] = "0004150E150400"; G["+"] = "0004041F040400"
  G[","] = "000000000C0408"; G["-"] = "0000001F000000"; G["."] = "00000000000C0C"
  G["/"] = "00010204081000"; G["0"] = "0E11131519110E"; G["1"] = "040C040404040E"
  G["2"] = "0E11010204081F"; G["3"] = "1F02040201110E"; G["4"] = "02060A121F0202"
  G["5"] = "1F101E0101110E"; G["6"] = "0608101E11110E"; G["7"] = "1F010204080808"
  G["8"] = "0E11110E11110E"; G["9"] = "0E11110F01020C"; G[":"] = "000C0C000C0C00"
  G[";"] = "000C0C000C0408"; G["<"] = "02040810080402"; G["="] = "00001F001F0000"
  G[">"] = "08040201020408"; G["?"] = "0E110102040004"; G["@"] = "0E11010D15150E"
  G["A"] = "0E1111111F1111"; G["B"] = "1E11111E11111E"; G["C"] = "0E11101010110E"
  G["D"] = "1C12111111121C"; G["E"] = "1F10101E10101F"; G["F"] = "1F10101E101010"
  G["G"] = "0E11101711110F"; G["H"] = "1111111F111111"; G["I"] = "0E04040404040E"
  G["J"] = "0702020202120C"; G["K"] = "11121418141211"; G["L"] = "1010101010101F"
  G["M"] = "111B1515111111"; G["N"] = "11111915131111"; G["O"] = "0E11111111110E"
  G["P"] = "1E11111E101010"; G["Q"] = "0E11111115120D"; G["R"] = "1E11111E141211"
  G["S"] = "0F10100E01011E"; G["T"] = "1F040404040404"; G["U"] = "1111111111110E"
  G["V"] = "11111111110A04"; G["W"] = "1111111515150A"; G["X"] = "11110A040A1111"
  G["Y"] = "1111110A040404"; G["Z"] = "1F01020408101F"; G["["] = "0E08080808080E"
  G["]"] = "0E02020202020E"; G["_"] = "0000000000001F"; G["a"] = "00000E010F110F"
  G["b"] = "1010161911111E"; G["c"] = "00000E1010110E"; G["d"] = "01010D1311110F"
  G["e"] = "00000E111F100E"; G["f"] = "0609081C080808"; G["g"] = "000F11110F010E"
  G["h"] = "10101619111111"; G["i"] = "04000C0404040E"; G["j"] = "0200060202120C"
  G["k"] = "10101214181412"; G["l"] = "0C04040404040E"; G["m"] = "00001A15151111"
  G["n"] = "00001619111111"; G["o"] = "00000E1111110E"; G["p"] = "00001E111E1010"
  G["q"] = "00000D130F0101"; G["r"] = "00001619101010"; G["s"] = "00000E100E011E"
  G["t"] = "08081C08080906"; G["u"] = "0000111111130D"; G["v"] = "00001111110A04"
  G["w"] = "0000111115150A"; G["x"] = "0000110A040A11"; G["y"] = "000011110F010E"
  G["z"] = "00001F0204081F"; G["|"] = "04040404040404"; G["~"] = "00000815020000"
}
function hx(s) { return (index(HEX, substr(s, 1, 1)) - 1) * 16 + index(HEX, substr(s, 2, 1)) - 1 }
function on(ch, row, col,   code) {
  code = (ch in G) ? G[ch] : G["?"]
  return int(hx(substr(code, row * 2 + 1, 2)) / P[col]) % 2
}
function bitat(text, n, x, y,   cx, ci, bx) {
  if (y < 1 || y > 7) return 0
  cx = x - 1
  if (cx < 0 || cx >= n * 6 - 1) return 0
  ci = int(cx / 6); bx = cx - ci * 6
  return (bx < 5) ? on(substr(text, ci + 1, 1), y - 1, bx) : 0
}
function s2x(A, W, H, O,   x, y, p, a, b, c, d) {
  for (y = 0; y < H; y++) for (x = 0; x < W; x++) {
    p = A[x, y]
    a = (y > 0) ? A[x, y - 1] : 0; d = (y < H - 1) ? A[x, y + 1] : 0
    c = (x > 0) ? A[x - 1, y] : 0; b = (x < W - 1) ? A[x + 1, y] : 0
    O[2 * x, 2 * y] = (c == a && c != d && a != b) ? a : p
    O[2 * x + 1, 2 * y] = (a == b && a != c && b != d) ? b : p
    O[2 * x, 2 * y + 1] = (d == c && d != b && c != a) ? c : p
    O[2 * x + 1, 2 * y + 1] = (b == d && b != a && d != c) ? d : p
  }
}
function emit4(path, A, W, H,   B, C, x, y, line) {
  s2x(A, W, H, B); s2x(B, 2 * W, 2 * H, C)
  for (y = 0; y < 4 * H; y++) {
    line = ""
    for (x = 0; x < 4 * W; x++) line = line (x ? " " : "") (C[x, y] ? 255 : 0)
    print line > path
  }
}
function render(path, text,   n, W, x, y, A) {
  n = length(text); W = n * 6 + 1
  for (y = 0; y < 9; y++) for (x = 0; x < W; x++) A[x, y] = bitat(text, n, x, y)
  printf "P2\n%d 36\n255\n", 4 * W > path
  emit4(path, A, W, 9)
  close(path)
}
function strip(path,   k, t, x, y, A) {
  printf "P2\n52 %d\n255\n", 60 * 36 > path
  for (k = 0; k < 60; k++) {
    t = sprintf("%02d", k)
    for (y = 0; y < 9; y++) for (x = 0; x < 13; x++) A[x, y] = bitat(t, 2, x, y)
    emit4(path, A, 13, 9)
  }
  close(path)
}
$1 == "@strip" { strip($2); next }
{ render($1, $2) }
AWK
}

gm_pgm() {
  GM_PGMN=$((${GM_PGMN:-0} + 1))
  GM_PGM="$WORK/t$GM_PGMN.pgm"
  GM_PGM_N="$WORK_N/t$GM_PGMN.pgm"
  printf '%s\t%s\n' "$GM_PGM" "$1" | awk -f "$WORK/font.awk"
}

# The clock strip is read again for every frame, so it is converted once to binary PGM (P5).
gm_clock_assets() {
  if [ ! -f "$WORK/clock_strip_p5.pgm" ]; then
    printf '@strip\t%s\n%s\t%s\n' "$WORK/clock_strip.pgm" "$WORK/clock_colons.pgm" "  :  :  " | awk -f "$WORK/font.awk"
    gm_ffx -nostdin -hide_banner -loglevel error -y -i "$WORK_N/clock_strip.pgm" \
      -frames:v 1 -update 1 -c:v pgm "$WORK_N/clock_strip_p5.pgm"
  fi
}

# Prepares WORK / WORK_N (both must be set) for the bitmap font.
gm_prepare_work() {
  mkdir -p "$WORK"
  gm_font_awk >"$WORK/font.awk"
}

# ---------------------------------------------------------------------------------------------
# Media jobs. Each gets the native path of a temporary output file as $1.
# ---------------------------------------------------------------------------------------------

# Two text lines and a clock, scaled to the frame (FFD24A = clock yellow).
gm_panel() {
  local u=$GH z1 z2 z3 y1 y2 y3
  if [ $((GW * 9 / 16)) -lt "$u" ]; then u=$((GW * 9 / 16)); fi
  z1=$((u * 60 / 1080))
  z2=$((u * 38 / 1080))
  z3=$((u * 100 / 1080))
  if [ "$z1" -lt 24 ]; then z1=24; fi
  if [ "$z2" -lt 17 ]; then z2=17; fi
  if [ "$z3" -lt 36 ]; then z3=36; fi
  y1=$((GH * 50 / 100))
  y2=$((y1 + z1 * 165 / 100))
  y3=$((y2 + z2 * 200 / 100))
  g_text "$1" center "$y1" "$z1" FFFFFF 1 0 1
  g_text "$2" center "$y2" "$z2" DCE6EE 1 0 0
  g_clock "${3:-stream}" center "$y3" "$z3" FFD24A 1
}

gm_a_stereo() { # FREQ LABEL
  g_add "sine=frequency=$1:sample_rate=48000:beep_factor=2:duration=$DUR,pan=stereo|c0=c0|c1=c0[$2]"
}

gm_a_51() { # LABEL FL FR FC LFE SL SR (Hz); the centre channel beeps every second
  local l=$1 i=0 f beep
  shift
  for f in "$@"; do
    beep=""
    if [ $i = 2 ]; then beep=":beep_factor=2"; fi
    g_add "sine=frequency=$f:sample_rate=48000$beep:duration=$DUR[${l}_$i]"
    i=$((i + 1))
  done
  g_add "[${l}_0][${l}_1][${l}_2][${l}_3][${l}_4][${l}_5]join=inputs=6:channel_layout=5.1(side):map=0.0-FL|1.0-FR|2.0-FC|3.0-LFE|4.0-SL|5.0-SR[$l]"
}

job_h264_aac_1080p25() {
  g_reset 1920 1080 25 0
  g_src "testsrc2=size=1920x1080:rate=25:duration=$DUR"
  gm_panel "H.264 High + AAC 2.0" "1920x1080 25p | 48 kHz | MPEG-TS"
  g_chain "format=yuv420p"
  g_out vout
  gm_a_stereo 440 a0
  gm_ff ${GIN[@]+"${GIN[@]}"} -filter_complex "$GF" -map "[vout]" -map "[a0]" -t "$DUR" \
    -c:v libx264 -preset veryfast -profile:v high -pix_fmt yuv420p -g 25 -keyint_min 25 -sc_threshold 0 \
    -b:v 4M -maxrate 5M -bufsize 8M \
    -c:a aac -b:a 128k -ar 48000 -ac 2 \
    -metadata service_provider=Carina -metadata "service_name=Carina H.264 AAC 1080p25" -f mpegts "$1"
}

job_h264_ac3_51_1080p25() {
  g_reset 1920 1080 25 0
  g_src "testsrc2=size=1920x1080:rate=25:duration=$DUR"
  gm_panel "H.264 High + AC-3 5.1 384k" "1920x1080 25p | 48 kHz | MPEG-TS"
  g_chain "format=yuv420p"
  g_out vout
  gm_a_51 a0 440 554 660 55 330 392
  gm_ff ${GIN[@]+"${GIN[@]}"} -filter_complex "$GF" -map "[vout]" -map "[a0]" -t "$DUR" \
    -c:v libx264 -preset veryfast -profile:v high -pix_fmt yuv420p -g 25 -keyint_min 25 -sc_threshold 0 \
    -b:v 4M -maxrate 5M -bufsize 8M \
    -c:a ac3 -b:a 384k -ar 48000 \
    -metadata service_provider=Carina -metadata "service_name=Carina H.264 AC-3 1080p25" -f mpegts "$1"
}

job_hevc_eac3_2160p25() {
  g_reset 3840 2160 25 0
  g_src "testsrc2=size=3840x2160:rate=25:duration=$DUR"
  gm_panel "HEVC Main (x265) + E-AC-3 5.1" "3840x2160 25p | 48 kHz | MPEG-TS"
  g_chain "format=yuv420p"
  g_out vout
  gm_a_51 a0 523 587 659 65 698 784
  gm_ff ${GIN[@]+"${GIN[@]}"} -filter_complex "$GF" -map "[vout]" -map "[a0]" -t "$DUR" \
    -c:v libx265 -preset ultrafast -profile:v main -pix_fmt yuv420p -b:v 6M -maxrate 8M -bufsize 12M \
    -x265-params "log-level=error:keyint=25:min-keyint=25:scenecut=0:open-gop=0:repeat-headers=1" \
    -c:a eac3 -b:a 384k -ar 48000 \
    -metadata service_provider=Carina -metadata "service_name=Carina HEVC E-AC-3 2160p25" -f mpegts "$1"
}

job_mpeg2_mp2_576i25() {
  # 50p source woven into 25 interlaced frames, so the two fields really differ in time.
  # setfield=tff marks the field order; ffmpeg 7+ dropped the -top encoder option, so it
  # is only added when this ffmpeg still accepts it.
  local top=()
  if gm_ffx -nostdin -hide_banner -loglevel quiet -f lavfi -i "color=s=64x64:d=0.04" \
    -c:v mpeg2video -top 1 -f null - >/dev/null 2>&1; then top=(-top 1); fi
  g_reset 720 576 50 0
  g_src "testsrc2=size=720x576:rate=50:duration=$DUR"
  gm_panel "MPEG-2 interlaced + MP2" "720x576 25i TFF | 16:9 | MPEG-TS"
  g_chain "tinterlace=mode=interleave_top,setfield=tff,format=yuv420p"
  g_out vout
  gm_a_stereo 440 a0
  gm_ff ${GIN[@]+"${GIN[@]}"} -filter_complex "$GF" -map "[vout]" -map "[a0]" -t "$DUR" \
    -c:v mpeg2video -pix_fmt yuv420p -flags +ilme+ildct+cgop ${top[@]+"${top[@]}"} -aspect 16:9 -g 12 -bf 2 \
    -sc_threshold 1000000000 \
    -b:v 4M -maxrate 6M -bufsize 1835k \
    -c:a mp2 -b:a 192k -ar 48000 -ac 2 \
    -metadata service_provider=Carina -metadata "service_name=Carina MPEG-2 MP2 576i25" -f mpegts "$1"
}

job_h264_aac_720p50() {
  g_reset 1280 720 50 0
  g_src "testsrc2=size=1280x720:rate=50:duration=$DUR"
  gm_panel "H.264 High + AAC 2.0" "1280x720 50p | 48 kHz | MP4 faststart"
  g_chain "format=yuv420p"
  g_out vout
  gm_a_stereo 440 a0
  gm_ff ${GIN[@]+"${GIN[@]}"} -filter_complex "$GF" -map "[vout]" -map "[a0]" -t "$DUR" \
    -c:v libx264 -preset veryfast -profile:v high -pix_fmt yuv420p -g 100 -keyint_min 50 -sc_threshold 0 \
    -b:v 3M -maxrate 4M -bufsize 6M \
    -c:a aac -b:a 128k -ar 48000 -ac 2 \
    -movflags +faststart -f mp4 "$1"
}

gm_write_srt() { # FILE eng|tur
  awk -v dur="$DUR" -v lang="$2" '
    function ts(ms) { return sprintf("%02d:%02d:%02d,%03d", int(ms / 3600000), int(ms / 60000) % 60, int(ms / 1000) % 60, ms % 1000) }
    function hms(s) { return sprintf("%02d:%02d:%02d", int(s / 3600), int(s / 60) % 60, s % 60) }
    BEGIN {
      n = 0
      for (s = 1; s + 3 <= dur; s += 4) {
        n++
        printf "%d\n%s --> %s\n", n, ts(s * 1000), ts(s * 1000 + 2500)
        if (lang == "tur") printf "Türkçe altyazı %d (%s)\nIşık, gölge, çiçek, şarkı: ĞÜŞİÖÇ ğüşıöç\n\n", n, hms(s)
        else printf "English subtitle %d (%s)\nThe quick brown fox jumps over the lazy dog.\n\n", n, hms(s)
      }
    }' >"$1"
}

gm_write_chapters() { # FILE
  local intro=10 credits
  credits=$((DUR >= 30 ? DUR - 10 : intro + (DUR - intro) / 2))
  {
    printf ';FFMETADATA1\ntitle=Carina VOD tracks test\n\n'
    printf '[CHAPTER]\nTIMEBASE=1/1000\nSTART=0\nEND=%d\ntitle=Intro\n\n' $((intro * 1000))
    printf '[CHAPTER]\nTIMEBASE=1/1000\nSTART=%d\nEND=%d\ntitle=Main\n\n' $((intro * 1000)) $((credits * 1000))
    printf '[CHAPTER]\nTIMEBASE=1/1000\nSTART=%d\nEND=%d\ntitle=Credits\n' $((credits * 1000)) $((DUR * 1000))
  } >"$1"
  GM_CREDITS=$credits
}

job_vod_tracks() {
  local tr i0 c
  tr=$(printf 'T\303\274rk\303\247e') # "Türkçe"
  gm_write_srt "$WORK/sub_eng.srt" eng
  gm_write_srt "$WORK/sub_tur.srt" tur
  gm_write_chapters "$WORK/chapters.txt"
  c=$GM_CREDITS
  g_reset 1280 720 25 0
  g_src "testsrc2=size=1280x720:rate=25:duration=$DUR"
  gm_panel "H.264 + AAC eng / AC-3 5.1 tur" "720p25 | SRT eng + tur | chapters | MKV"
  g_text "CHAPTER 1: INTRO" center 40 34 FFFFFF 1 0 1 "lt(t,10)"
  g_text "CHAPTER 2: MAIN" center 40 34 FFFFFF 1 0 1 "between(t,10,$c-0.001)"
  g_text "CHAPTER 3: CREDITS" center 40 34 FFFFFF 1 0 1 "gte(t,$c)"
  g_chain "format=yuv420p"
  g_out vout
  gm_a_stereo 440 a0
  gm_a_51 a1 523 587 659 65 698 784
  i0=$GIDX
  gm_ff ${GIN[@]+"${GIN[@]}"} -i "$WORK_N/sub_eng.srt" -i "$WORK_N/sub_tur.srt" -f ffmetadata -i "$WORK_N/chapters.txt" \
    -filter_complex "$GF" -map "[vout]" -map "[a0]" -map "[a1]" -map "$i0:s:0" -map "$((i0 + 1)):s:0" \
    -map_metadata "$((i0 + 2))" -map_chapters "$((i0 + 2))" -t "$DUR" \
    -c:v libx264 -preset veryfast -profile:v high -pix_fmt yuv420p -g 50 -keyint_min 25 -sc_threshold 0 \
    -b:v 2500k -maxrate 3M -bufsize 6M \
    -c:a:0 aac -b:a:0 128k -c:a:1 ac3 -b:a:1 384k -ar 48000 -c:s srt \
    -metadata:s:v:0 "title=Test pattern" \
    -metadata:s:a:0 language=eng -metadata:s:a:0 title=English \
    -metadata:s:a:1 language=tur -metadata:s:a:1 "title=$tr" \
    -metadata:s:s:0 language=eng -metadata:s:s:0 title=English \
    -metadata:s:s:1 language=tur -metadata:s:s:1 "title=$tr" \
    -disposition:v:0 default -disposition:a:0 default -disposition:a:1 0 \
    -disposition:s:0 0 -disposition:s:1 0 -default_mode passthrough \
    -f matroska "$1"
}

# ---------------------------------------------------------------------------------------------
# Catalog art: one awk program designs every image (palette, layout, procedural geq scene).
# Output fields: file|W|H|background chain|text1 x y size color shadow bold|text2 ... ("-" = none)
# ---------------------------------------------------------------------------------------------
gm_art_awk() {
  cat <<'AWK'
function absf(x) { return x < 0 ? -x : x }
function fmodp(x, m) { x = x - m * int(x / m); return x < 0 ? x + m : x }
function rnd() { SEED = (SEED * 16807) % 2147483647; return SEED / 2147483647 }
function hsv(name, h, s, v,   c, hp, x, m, r, g, b) {
  h = fmodp(h, 360); if (s < 0) s = 0; if (s > 1) s = 1; if (v < 0) v = 0; if (v > 1) v = 1
  c = v * s; hp = h / 60; x = c * (1 - absf(hp - 2 * int(hp / 2) - 1)); m = v - c
  if (hp < 1) { r = c; g = x; b = 0 } else if (hp < 2) { r = x; g = c; b = 0 }
  else if (hp < 3) { r = 0; g = c; b = x } else if (hp < 4) { r = 0; g = x; b = c }
  else if (hp < 5) { r = x; g = 0; b = c } else { r = c; g = 0; b = x }
  K[name, "r"] = int((r + m) * 255 + 0.5); K[name, "g"] = int((g + m) * 255 + 0.5); K[name, "b"] = int((b + m) * 255 + 0.5)
}
function hex(name) { return sprintf("%02X%02X%02X", K[name, "r"], K[name, "g"], K[name, "b"]) }
function vgrad(a, b, c) { return sprintf("st(1,%d+(%d-%d)*clip(Y/%.1f,0,1));", K[a, c], K[b, c], K[a, c], HZ) }
function halo(name, c, rad, k) { return sprintf("st(1,ld(1)+(%d-ld(1))*%.2f*pow(clip(1-ld(2)/%.1f,0,1),2));", K[name, c], k, rad) }
function disc(name, c, rad) { return sprintf("st(1,ld(1)+(%d-ld(1))*clip((%.1f-ld(2))/1.5+0.5,0,1));", K[name, c], rad) }
function ridge(y, a1, w1, p1, a2, w2, p2) {
  return sprintf("st(3,%.1f+%.1f*sin(X*%.6f+%.3f)+%.1f*sin(X*%.6f+%.3f));", y, a1, 6.28318 / w1, p1, a2, 6.28318 / w2, p2)
}
function fill(name, c) { return sprintf("st(1,ld(1)+(%d-ld(1))*clip((Y-ld(3))/1.2+0.5,0,1));", K[name, c]) }
function shade() { return sprintf("st(1,ld(1)*(1-%.2f*clip((Y-%.1f)/%.1f,0,1)));", DARK, H * 0.45, H * 0.55) }
function landscape(c,   e) {
  e = vgrad("top", "hor", c) sprintf("st(2,hypot(X-%.1f,Y-%.1f));", SX, SY)
  e = e halo("sun", c, SR * 4.5, 0.55) disc("sun", c, SR)
  e = e ridge(FY, FA1, FW1, FP1, FA2, FW2, FP2) fill("far", c)
  e = e ridge(MY, MA1, MW1, MP1, MA2, MW2, MP2) fill("mid", c)
  e = e ridge(NY, NA1, NW1, NP1, NA2, NW2, NP2) fill("near", c)
  return e shade() "ld(1)"
}
function orb(c,   e) {
  e = vgrad("top", "bot", c) sprintf("st(2,hypot(X-%.1f,Y-%.1f));", SX, SY)
  e = e halo("glow", c, SR * 2.4, 0.6)
  e = e sprintf("st(4,clip(1.15-hypot(X-%.1f,Y-%.1f)/%.1f,0.12,1));", SX - SR * 0.45, SY - SR * 0.45, SR * 1.75)
  e = e sprintf("st(1,ld(1)+(%d*ld(4)-ld(1))*clip((%.1f-ld(2))/1.5+0.5,0,1));", K["planet", c], SR)
  e = e sprintf("st(5,abs(hypot((X-%.1f)/%.1f,(Y-%.1f)/%.1f)-1));", SX, SR * 1.85, SY, SR * 0.42)
  e = e sprintf("st(1,ld(1)+(%d-ld(1))*0.9*clip((0.045-ld(5))/0.015,0,1)*gt(gt(Y,%.1f)+gt(ld(2),%.1f),0));", K["ring", c], SY, SR)
  return e shade() "ld(1)"
}
function burst(c,   e) {
  e = vgrad("top", "bot", c) sprintf("st(2,hypot(X-%.1f,Y-%.1f));", SX, SY)
  e = e sprintf("st(3,pow(max(0,sin(atan2(Y-%.1f,X-%.1f)*%d+%.2f)),4)*clip(1-ld(2)/%.1f,0,1));", SY, SX, RAYS, PH, H * 1.1)
  e = e sprintf("st(1,ld(1)+(%d-ld(1))*0.45*ld(3));", K["ray", c])
  e = e halo("sun", c, SR * 3.2, 0.6) disc("sun", c, SR)
  return e shade() "ld(1)"
}
function pal_landscape(h, tod) {
  if (tod == 0) {        # dusk
    hsv("top", h, 0.55, 0.40); hsv("hor", h + 50, 0.60, 0.98); hsv("sun", h + 60, 0.22, 1.0)
    hsv("far", h - 5, 0.32, 0.50); hsv("mid", h - 15, 0.40, 0.30); hsv("near", h - 25, 0.50, 0.11)
  } else if (tod == 1) { # night
    hsv("top", 222 + fmodp(h, 24), 0.75, 0.10); hsv("hor", 212 + fmodp(h, 30), 0.55, 0.38); hsv("sun", 52, 0.08, 0.95)
    hsv("far", 226, 0.38, 0.24); hsv("mid", 228, 0.45, 0.14); hsv("near", 232, 0.55, 0.05)
  } else if (tod == 2) { # day
    hsv("top", 203 + fmodp(h, 16), 0.58, 0.85); hsv("hor", 193, 0.22, 0.98); hsv("sun", 55, 0.10, 1.0)
    hsv("far", 150 + fmodp(h, 50), 0.22, 0.66); hsv("mid", 135 + fmodp(h, 40), 0.42, 0.42); hsv("near", 120 + fmodp(h, 40), 0.60, 0.22)
  } else {               # mist
    hsv("top", h, 0.24, 0.72); hsv("hor", h, 0.10, 0.96); hsv("sun", h + 25, 0.12, 1.0)
    hsv("far", h, 0.16, 0.66); hsv("mid", h, 0.24, 0.48); hsv("near", h, 0.34, 0.26)
  }
}
function geo_landscape(high,   m) {
  m = (W < H) ? W : H
  HZ = H * 0.64; SX = W * (0.22 + 0.56 * rnd()); SY = H * (high ? 0.24 : 0.47); SR = m * (high ? 0.06 : 0.10)
  FY = H * 0.55; FA1 = H * 0.05; FW1 = m * (1.2 + 0.8 * rnd()); FP1 = 6.28 * rnd(); FA2 = H * 0.02; FW2 = m * (0.35 + 0.2 * rnd()); FP2 = 6.28 * rnd()
  MY = H * 0.64; MA1 = H * 0.04; MW1 = m * (1.6 + 0.8 * rnd()); MP1 = 6.28 * rnd(); MA2 = H * 0.015; MW2 = m * (0.45 + 0.2 * rnd()); MP2 = 6.28 * rnd()
  NY = H * 0.74; NA1 = H * 0.035; NW1 = m * (2.2 + rnd()); NP1 = 6.28 * rnd(); NA2 = H * 0.012; NW2 = m * (0.6 + 0.3 * rnd()); NP2 = 6.28 * rnd()
}
function scene(style, h, tod,   r, g, b, FW, FH) {
  # The scene is computed at half size (geq is the slow part) and upscaled; grain is added after.
  FW = W; FH = H; W = int(W / 2); H = int(H / 2)
  if (style == "orb") {
    hsv("top", h, 0.60, 0.32); hsv("bot", h + 30, 0.75, 0.05); hsv("glow", h + 20, 0.50, 0.75)
    hsv("planet", h + 160, 0.42, 0.95); hsv("ring", h + 40, 0.22, 0.98)
    HZ = H; SX = W * 0.5; SY = H * (W < H ? 0.36 : 0.42); SR = ((W < H) ? W : H) * 0.26
    r = orb("r"); g = orb("g"); b = orb("b")
  } else if (style == "burst") {
    hsv("top", h, 0.75, 0.55); hsv("bot", h + 25, 0.85, 0.09); hsv("ray", h + 30, 0.40, 1.0); hsv("sun", h + 45, 0.18, 1.0)
    HZ = H; SX = W * 0.5; SY = H * 0.34; SR = ((W < H) ? W : H) * 0.10; RAYS = 9 + int(rnd() * 8); PH = 6.28 * rnd()
    r = burst("r"); g = burst("g"); b = burst("b")
  } else {
    pal_landscape(h, tod); geo_landscape(tod == 1)
    r = landscape("r"); g = landscape("g"); b = landscape("b")
  }
  W = FW; H = FH
  return sprintf("color=c=black:s=%dx%d:r=1:d=1,format=gbrp,geq=r='%s':g='%s':b='%s',scale=%d:%d:flags=bicubic,format=yuv444p,vignette=angle=0.5,noise=alls=5:allf=u:all_seed=%d", int(FW / 2), int(FH / 2), r, g, b, FW, FH, 1000 + IDX)
}
function fit(len, maxsz, frac) { return int(frac * W / (0.68 * len)) < maxsz ? int(frac * W / (0.68 * len)) : maxsz }
function emit(i,   h, style, tod, t, sz, y, bg, s) {
  IDX = i; h = fmodp(i * 137.508 + 15, 360)
  if (kind == "poster") {
    s = i % 4; style = (s == 1) ? "orb" : (s == 2) ? "burst" : "land"; tod = (s == 0) ? int(i / 4) % 4 : (int(i / 4) + 2) % 4
    DARK = 0.5; bg = scene(style, h, tod)
    t = TITLES[i + 1]; sz = fit(length(t), 84, 0.86); y = int(H * 0.66)
    printf "poster_%02d.jpg|%d|%d|%s|%s|center|%d|%d|FFFFFF|1|1|%s|center|%d|15|FFFFFF@0.75|0|0\n", i, W, H, bg, t, y, sz, sprintf("TEST POSTER %02d", i), y + sz + 16
  } else if (kind == "backdrop") {
    s = i % 5; style = (s == 4) ? "orb" : "land"; tod = s % 4
    DARK = 0.3; bg = scene(style, h, tod)
    printf "backdrop_%02d.jpg|%d|%d|%s|-|-|-|-|-|-|-|%s|right:28|bottom:24|20|FFFFFF@0.55|0|0\n", i, W, H, bg, sprintf("BACKDROP %02d", i)
  } else if (kind == "still") {
    s = i % 6; style = (s == 5) ? "burst" : "land"; tod = (i + 2) % 4
    DARK = 0.25; bg = scene(style, h, tod)
    printf "still_%02d.jpg|%d|%d|%s|-|-|-|-|-|-|-|%s|20|bottom:16|22|FFFFFF@0.9|1|1\n", i, W, H, bg, sprintf("S%02d E%02d", int(i / 10) + 1, i % 10 + 1)
  } else if (kind == "logo") {
    t = LOGOS[i + 1]; sz = fit(length(t), 120, 0.80)
    if (i % 2 == 0) {
      hsv("a", h, 0.70, 0.88); hsv("b", h + 14, 0.82, 0.58)
      bg = sprintf("color=c=black:s=%dx%d:r=1:d=1,format=gbrp,geq=r='%d+(%d-%d)*Y/H':g='%d+(%d-%d)*Y/H':b='%d+(%d-%d)*Y/H'", W, H, K["a", "r"], K["b", "r"], K["a", "r"], K["a", "g"], K["b", "g"], K["a", "g"], K["a", "b"], K["b", "b"], K["a", "b"])
      printf "logo_%02d.png|%d|%d|%s|%s|center|center|%d|FFFFFF|1|1|-|-|-|-|-|-|-\n", i, W, H, bg, t, sz
    } else {
      hsv("a", h, 0.85, 0.62)
      bg = sprintf("color=c=white:s=%dx%d:r=1:d=1,drawbox=x=0:y=ih-20:w=iw:h=20:color=0x%s:t=fill", W, H, hex("a"))
      printf "logo_%02d.png|%d|%d|%s|%s|center|center|%d|%s|0|1|-|-|-|-|-|-|-\n", i, W, H, bg, t, sz, hex("a")
    }
  }
}
BEGIN {
  SEED = 4242 + length(kind) * 97
  split("AURORA KUZEY MERIDIAN ATLAS SAHIL YILDIZ ECHO NEON POYRAZ LUNA VERTIGO ORMAN DELTA KUM SIS ZEPHYR MAVI ARDA PRISM ORBIT TUNDRA CIRCUS EMBER HALO KOSMOS RUZGAR VADI NOMAD ALTIN FENER PUSULA SERAP KAYIP GECE SAFAK DALGA BOZKIR ISIK YANKI SONSUZ", TITLES, " ")
  split("K1 K2 K3 HABER SPOR BELGE MUZIK COCUK SINEMA DIZI NEWS SPORT DOCS KIDS FILM MUSIC LIVE PLUS MAX ONE ARTI HD 4K UHD TEST LAB AIR NOVA ZEN ECO", LOGOS, " ")
  for (i = 0; i < n; i++) emit(i)
}
AWK
}

gm_image_one() { # DST_NATIVE EXT BGCHAIN, then 2 x (TEXT X Y SIZE COLOR SHADOW BOLD); "-" = none
  local dst=$1 ext=$2 pf=yuvj420p
  g_reset "$GM_IW" "$GM_IH" 1 0
  g_src "$3"
  if [ "$4" != - ]; then g_text "$4" "$5" "$6" "$7" "$8" 0 "$9" "${10}"; fi
  if [ "${11}" != - ]; then g_text "${11}" "${12}" "${13}" "${14}" "${15}" 0 "${16}" "${17}"; fi
  if [ "$ext" = png ]; then pf=rgb24; fi
  g_chain "format=$pf"
  g_out iv
  if [ "$ext" = png ]; then
    gm_ff ${GIN[@]+"${GIN[@]}"} -filter_complex "$GF" -map "[iv]" -frames:v 1 -c:v png -update 1 "$dst"
  else
    gm_ff ${GIN[@]+"${GIN[@]}"} -filter_complex "$GF" -map "[iv]" -frames:v 1 -c:v mjpeg -q:v 2 -update 1 "$dst"
  fi
}

gm_images() {
  gm_selected images || return 0
  local t0 made=0 kept=0 spec kind n ext log="$WORK/images.log"
  local file bg t1 x1 y1 s1 c1 sh1 b1 t2 x2 y2 s2 c2 sh2 b2
  t0=$(date +%s)
  gm_art_awk >"$WORK/art.awk"
  mkdir -p "$OUT/img"
  gm_log "make  img/ (40 posters, 20 backdrops, 30 logos, 20 stills) ..."
  for spec in "poster 40 400 600 jpg" "backdrop 20 1280 720 jpg" "logo 30 256 256 png" "still 20 640 360 jpg"; do
    # shellcheck disable=SC2086
    set -- $spec
    kind=$1 n=$2 GM_IW=$3 GM_IH=$4 ext=$5
    awk -v kind="$kind" -v n="$n" -v W="$GM_IW" -v H="$GM_IH" -f "$WORK/art.awk" >"$WORK/art_$kind.txt"
    while IFS='|' read -r file GM_IW GM_IH bg t1 x1 y1 s1 c1 sh1 b1 t2 x2 y2 s2 c2 sh2 b2; do
      if [ -f "$OUT/img/$file" ] && [ "$FORCE" != 1 ]; then
        kept=$((kept + 1))
        continue
      fi
      if ! gm_image_one "$OUT_N/img/.tmp_$file" "$ext" "$bg" "$t1" "$x1" "$y1" "$s1" "$c1" "$sh1" "$b1" \
        "$t2" "$x2" "$y2" "$s2" "$c2" "$sh2" "$b2" 2>"$log"; then
        if [ "$TEXT_MODE" = drawtext ]; then
          gm_warn "img/$file failed with drawtext; switching to the bitmap font"
          TEXT_MODE=bitmap
          gm_image_one "$OUT_N/img/.tmp_$file" "$ext" "$bg" "$t1" "$x1" "$y1" "$s1" "$c1" "$sh1" "$b1" \
            "$t2" "$x2" "$y2" "$s2" "$c2" "$sh2" "$b2" 2>"$log" || gm_fail_log "img/$file" "$log"
        else
          gm_fail_log "img/$file" "$log"
        fi
      fi
      mv -f "$OUT/img/.tmp_$file" "$OUT/img/$file"
      made=$((made + 1))
    done <"$WORK/art_$kind.txt"
  done
  local dt=$(($(date +%s) - t0))
  gm_log "done  img/ in ${dt}s ($made made, $kept kept)"
  GM_TIMES="${GM_TIMES}img/ (110 images)|$made made, $kept kept|${dt}s|$(du -sk "$OUT/img" | awk '{ printf "%.1f MB", $1 / 1024 }')
"
}

# ---------------------------------------------------------------------------------------------
# Job runner, manifest, main
# ---------------------------------------------------------------------------------------------

gm_selected() {
  [ -z "${ONLY:-}" ] && return 0
  case ",$ONLY," in *",$1,"* | *",${1%.*},"*) return 0 ;; esac
  return 1
}

gm_size() { wc -c <"$1" | awk '{ printf "%.1f MB", $1 / 1048576 }'; }

gm_fail_log() {
  printf '[%s] ERROR: %s failed. Last ffmpeg output:\n' "$GM_TAG" "$1" >&2
  tail -n 15 "$2" >&2 || true
  exit 1
}

gm_job() { # FILE FUNCTION
  local name=$1 fn=$2 dst t0 log dt
  gm_selected "$name" || return 0
  dst="$OUT/$name"
  if [ -f "$dst" ] && [ "$FORCE" != 1 ]; then
    gm_log "keep  $name (exists; --force rebuilds)"
    GM_TIMES="${GM_TIMES}$name|kept|-|$(gm_size "$dst")
"
    return 0
  fi
  log="$WORK/$name.log"
  if [ "${GM_VERBOSE:-0}" = 1 ]; then log=/dev/stderr; fi
  t0=$(date +%s)
  gm_log "make  $name ..."
  if ! "$fn" "$OUT_N/.tmp_$name" 2>"$log"; then
    if [ "$TEXT_MODE" = drawtext ]; then
      gm_warn "$name failed with drawtext; retrying with the bitmap font"
      tail -n 5 "$log" >&2 || true
      TEXT_MODE=bitmap
      "$fn" "$OUT_N/.tmp_$name" 2>"$log" || gm_fail_log "$name" "$log"
    else
      gm_fail_log "$name" "$log"
    fi
  fi
  mv -f "$OUT/.tmp_$name" "$dst"
  dt=$(($(date +%s) - t0))
  gm_log "done  $name in ${dt}s ($(gm_size "$dst"))"
  GM_TIMES="${GM_TIMES}$name|made|${dt}s|$(gm_size "$dst")
"
}

gm_flat2json_awk() {
  cat <<'AWK'
function unesc(s,   o, i, c, L) { o = ""; L = length(s); for (i = 1; i <= L; i++) { c = substr(s, i, 1); if (c == "\\" && i < L) { i++; c = substr(s, i, 1) } o = o c } return o }
function js(s,   o, i, c, L) { o = ""; L = length(s); for (i = 1; i <= L; i++) { c = substr(s, i, 1); if (c == "\\" || c == "\"") o = o "\\" c; else o = o c } return "\"" o "\"" }
function jsn(s) { return (s == "" || s == "N/A" || s == "unknown") ? "null" : js(s) }
function jn(s) { return (s ~ /^-?[0-9]+(\.[0-9]+)?$/) ? s : "null" }
function rest(p, from, n,   f, j) { f = p[from]; for (j = from + 1; j <= n; j++) f = f "_" p[j]; return f }
{
  eq = index($0, "="); if (!eq) next
  key = substr($0, 1, eq - 1); val = substr($0, eq + 1)
  if (val ~ /^".*"$/) val = unesc(substr(val, 2, length(val) - 2))
  n = split(key, p, "_")
  if (p[1] == "streams" && p[2] == "stream" && n >= 4) { i = p[3] + 0; if (i + 1 > ns) ns = i + 1; S[i, rest(p, 4, n)] = val }
  else if (p[1] == "chapters" && p[2] == "chapter" && n >= 4) { i = p[3] + 0; if (i + 1 > nc) nc = i + 1; C[i, rest(p, 4, n)] = val }
  else if (p[1] == "format" && n >= 2) F[rest(p, 2, n)] = val
}
END {
  printf "    {\"file\": %s, \"description\": %s,\n", js(name), js(desc)
  printf "     \"format\": %s, \"duration_s\": %s, \"size_bytes\": %s, \"bit_rate\": %s,\n", js(F["format_name"]), jn(F["duration"]), jn(F["size"]), jn(F["bit_rate"])
  printf "     \"streams\": ["
  for (i = 0; i < ns; i++) {
    t = S[i, "codec_type"]
    o = sprintf("{\"index\": %s, \"type\": %s, \"codec\": %s, \"profile\": %s", jn(S[i, "index"]), js(t), js(S[i, "codec_name"]), jsn(S[i, "profile"]))
    if (t == "video") o = o sprintf(", \"width\": %s, \"height\": %s, \"pix_fmt\": %s, \"field_order\": %s, \"frame_rate\": %s, \"sar\": %s, \"dar\": %s", jn(S[i, "width"]), jn(S[i, "height"]), jsn(S[i, "pix_fmt"]), jsn(S[i, "field_order"]), jsn(S[i, "r_frame_rate"]), jsn(S[i, "sample_aspect_ratio"]), jsn(S[i, "display_aspect_ratio"]))
    if (t == "audio") o = o sprintf(", \"channels\": %s, \"channel_layout\": %s, \"sample_rate\": %s", jn(S[i, "channels"]), jsn(S[i, "channel_layout"]), jn(S[i, "sample_rate"]))
    o = o sprintf(", \"language\": %s, \"title\": %s, \"default\": %s}", jsn(S[i, "tags_language"]), jsn(S[i, "tags_title"]), (S[i, "disposition_default"] == "1") ? "true" : "false")
    printf "%s\n       %s", (i ? "," : ""), o
  }
  printf "],\n     \"chapters\": ["
  for (i = 0; i < nc; i++) printf "%s{\"title\": %s, \"start_s\": %s, \"end_s\": %s}", (i ? ", " : ""), jsn(C[i, "tags_title"]), jn(C[i, "start_time"]), jn(C[i, "end_time"])
  printf "]}"
}
AWK
}

gm_probe_json() { # FILE DESCRIPTION
  gm_ffp -v error -of flat=s=_ \
    -show_entries "format=format_name,duration,size,bit_rate:stream=index,codec_type,codec_name,profile,width,height,pix_fmt,field_order,r_frame_rate,sample_aspect_ratio,display_aspect_ratio,sample_rate,channels,channel_layout:stream_tags=language,title:stream_disposition=default:chapter=start_time,end_time:chapter_tags=title" \
    "$OUT_N/$1" | awk -v name="$1" -v desc="$2" -f "$WORK/flat2json.awk"
}

GM_MEDIA="h264_aac_1080p25.ts|H.264 High + AAC 2.0 48 kHz, 1920x1080 25p, MPEG-TS
h264_ac3_51_1080p25.ts|H.264 High + AC-3 5.1 384k, 1920x1080 25p, MPEG-TS
hevc_eac3_2160p25.ts|HEVC Main (x265) + E-AC-3 5.1 384k, 3840x2160 25p, MPEG-TS
mpeg2_mp2_576i25.ts|MPEG-2 interlaced top field first + MP2 2.0, 720x576 25i, 16:9, MPEG-TS
h264_aac_720p50.mp4|H.264 High + AAC 2.0, 1280x720 50p, MP4 faststart
vod_tracks.mkv|H.264 1280x720 25p; audio eng AAC 2.0 + tur AC-3 5.1; subtitles eng + tur SRT; chapters Intro/Main/Credits"

gm_manifest() {
  local tmp="$OUT/.tmp_manifest.json" first=1 name desc kind n w h ext fmt cnt i f
  gm_flat2json_awk >"$WORK/flat2json.awk"
  {
    printf '{\n  "generator": "tools/gen_media.sh",\n'
    printf '  "generated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '  "requested_duration_s": %s,\n' "$DUR"
    printf '  "text_renderer": "%s",\n' "$TEXT_MODE"
    printf '  "ffmpeg_version": "%s",\n' "$GM_FFVER"
    printf '  "media": [\n'
    while IFS='|' read -r name desc; do
      [ -f "$OUT/$name" ] || continue
      if [ $first = 0 ]; then printf ',\n'; fi
      first=0
      gm_probe_json "$name" "$desc"
    done <<EOF
$GM_MEDIA
EOF
    printf '\n  ],\n  "images": [\n'
    first=1
    for f in "poster 40 400 600 jpg jpeg" "backdrop 20 1280 720 jpg jpeg" "logo 30 256 256 png png" "still 20 640 360 jpg jpeg"; do
      # shellcheck disable=SC2086
      set -- $f
      kind=$1 n=$2 w=$3 h=$4 ext=$5 fmt=$6
      cnt=0
      i=0
      while [ $i -lt "$n" ]; do
        if [ -f "$OUT/img/$(printf '%s_%02d.%s' "$kind" "$i" "$ext")" ]; then cnt=$((cnt + 1)); fi
        i=$((i + 1))
      done
      if [ $first = 0 ]; then printf ',\n'; fi
      first=0
      printf '    {"kind": "%s", "pattern": "img/%s_%%02d.%s", "count": %d, "expected": %d, "width": %d, "height": %d, "format": "%s"}' \
        "$kind" "$kind" "$ext" "$cnt" "$n" "$w" "$h" "$fmt"
    done
    printf '\n  ],\n'
    printf '  "live_hls": {"dir": "tools/mock_server/live", "playlist": "index.m3u8", "control": "bash tools/live_hls.sh start|stop|status"}\n'
    printf '}\n'
  } >"$tmp"
  mv -f "$tmp" "$OUT/manifest.json"
  gm_log "wrote manifest.json"
}

gm_usage() {
  awk 'NR > 2 { if ($0 !~ /^#/) exit; sub(/^# ?/, ""); print }' "$1"
}

gm_on_exit() {
  local rc=$?
  if [ "${GM_STARTED:-0}" = 1 ]; then
    rm -f "$OUT"/.tmp_* "$OUT"/img/.tmp_* 2>/dev/null || true
    if [ "${GM_OK:-0}" = 1 ]; then
      rm -rf "$WORK"
    elif [ -d "$WORK" ]; then
      gm_warn "work files kept for debugging: $WORK"
    fi
  fi
  if [ -n "${GM_LF_COPY:-}" ]; then rm -f "$GM_LF_COPY"; fi
  return $rc
}

gm_main() {
  set -euo pipefail
  local self=${CARINA_GM_SELF:-${BASH_SOURCE[0]}} here t0 total
  if [ -n "${CARINA_GM_LF:-}" ]; then GM_LF_COPY=${BASH_SOURCE[0]}; fi
  unset CARINA_GM_SELF CARINA_GM_LF
  GM_STARTED=0
  GM_OK=0
  trap gm_on_exit EXIT
  here=$(cd "$(dirname "$self")" && pwd)
  OUT="$here/mock_server/media"
  DUR=90
  FORCE=0
  ONLY=""
  GM_VERBOSE=0
  GM_TIMES=""
  TEXT_MODE=${CARINA_TEXT:-auto}
  while [ $# -gt 0 ]; do
    case "$1" in
      --out | --duration | --only | --text)
        [ $# -ge 2 ] || gm_die "$1 needs a value"
        case "$1" in
          --out) OUT=$2 ;;
          --duration) DUR=$2 ;;
          --only) ONLY=$2 ;;
          --text) TEXT_MODE=$2 ;;
        esac
        shift 2
        ;;
      --out=*) OUT=${1#*=} && shift ;;
      --duration=*) DUR=${1#*=} && shift ;;
      --only=*) ONLY=${1#*=} && shift ;;
      --text=*) TEXT_MODE=${1#*=} && shift ;;
      --quick) DUR=20 && shift ;;
      --force) FORCE=1 && shift ;;
      --verbose | -v) GM_VERBOSE=1 && shift ;;
      -h | --help)
        gm_usage "$self"
        exit 0
        ;;
      *) gm_die "unknown option '$1' (see --help)" ;;
    esac
  done
  case "$DUR" in '' | *[!0-9]*) gm_die "--duration must be a whole number of seconds" ;; esac
  [ "$DUR" -ge 12 ] || gm_die "--duration must be at least 12 seconds (the Intro chapter is 10 s)"

  gm_find_ffmpeg
  mkdir -p "$OUT" || gm_die "cannot create $OUT"
  OUT=$(cd "$OUT" && pwd)
  OUT_N=$(gm_np "$OUT")
  WORK="$OUT/.work"
  WORK_N="$OUT_N/.work"
  GM_STARTED=1
  rm -rf "$WORK"
  gm_prepare_work
  gm_detect_text

  gm_log "ffmpeg $GM_FFVER: $FFMPEG"
  if [ "$TEXT_MODE" = drawtext ]; then
    gm_log "text: drawtext, font ${FONT:-(ffmpeg default)}"
  else
    gm_log "text: $TEXT_MODE"
  fi
  gm_log "output: $OUT (videos ${DUR}s$([ "$FORCE" = 1 ] && printf ', --force'))"
  t0=$(date +%s)
  gm_job h264_aac_1080p25.ts job_h264_aac_1080p25
  gm_job h264_ac3_51_1080p25.ts job_h264_ac3_51_1080p25
  gm_job mpeg2_mp2_576i25.ts job_mpeg2_mp2_576i25
  gm_job h264_aac_720p50.mp4 job_h264_aac_720p50
  gm_job vod_tracks.mkv job_vod_tracks
  gm_images
  gm_job hevc_eac3_2160p25.ts job_hevc_eac3_2160p25
  gm_manifest
  total=$(($(date +%s) - t0))
  GM_OK=1
  gm_log "summary:"
  printf '%s' "$GM_TIMES" | awk -F'|' 'NF { printf "    %-24s %-20s %6s  %s\n", $1, $2, $3, $4 }'
  gm_log "finished in ${total}s, text renderer: $TEXT_MODE, output: $OUT"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  gm_main "$@"
fi

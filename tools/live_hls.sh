#!/usr/bin/env bash
if [ -z "${CARINA_LH_LF:-}" ] && grep -q "$(printf '\r')" "$0" 2>/dev/null; then _t="${TMPDIR:-/tmp}/carina_live_hls_$$.sh"; tr -d '\r' < "$0" > "$_t" && CARINA_LH_LF=1 CARINA_LH_SELF="$0" exec bash "$_t" "$@"; fi # CRLF checkout guard: re-run an LF copy
#
# tools/live_hls.sh - rolling live HLS source for the mock server (docs/BRIEF.md section 11.1).
#
# Usage:
#   bash tools/live_hls.sh start|stop|restart|status [--dir DIR] [--text auto|drawtext|bitmap|none]
#
#   start    starts a background ffmpeg (-re): testsrc2 1280x720 25p with a burned-in wall clock,
#            H.264 + AAC, written as DIR/index.m3u8 with 2 s segments, a 6-segment window,
#            delete_segments and EXT-X-PROGRAM-DATE-TIME. Returns once the playlist exists.
#            Does nothing when it is already running.
#   stop     stops it (SIGTERM, then a hard kill; taskkill /T on Windows).
#   restart  stop + start.
#   status   prints the state; exit code 0 = running, 3 = not running.
#
#   --dir DIR   output folder (default: tools/mock_server/live next to this script)
#   --text      how the clock is drawn; same meaning as in gen_media.sh (default auto)
#
# DIR/.live_hls.pid holds "<pid> <windows-pid>", DIR/.live_hls.log the ffmpeg log.
# Segment numbers start at the Unix time, so a restart never moves the media sequence back.
# Works with bash 3.2 (macOS) and Git Bash on Windows; needs ffmpeg (FFMPEG overrides it).

set -euo pipefail

LH_SELF=${CARINA_LH_SELF:-$0}
LH_COPY=""
if [ -n "${CARINA_LH_LF:-}" ]; then LH_COPY=$0; fi
unset CARINA_LH_SELF CARINA_LH_LF
LH_HERE=$(cd "$(dirname "$LH_SELF")" && pwd)

# Helpers (ffmpeg lookup, text rendering, paths) come from gen_media.sh, which only defines
# functions when it is sourced.
GM_TAG=live_hls
LH_LIB="$LH_HERE/gen_media.sh"
if [ ! -f "$LH_LIB" ]; then
  printf '[live_hls] ERROR: %s not found\n' "$LH_LIB" >&2
  exit 1
fi
if grep -q "$(printf '\r')" "$LH_LIB"; then
  LH_LIBCOPY="${TMPDIR:-/tmp}/carina_gen_media_lib_$$.sh"
  tr -d '\r' <"$LH_LIB" >"$LH_LIBCOPY"
  # shellcheck source=/dev/null
  . "$LH_LIBCOPY"
  rm -f "$LH_LIBCOPY"
else
  # shellcheck source=gen_media.sh
  . "$LH_LIB"
fi

lh_usage() { awk 'NR > 2 { if ($0 !~ /^#/) exit; sub(/^# ?/, ""); print }' "$LH_SELF"; }

lh_cleanup() {
  if [ -n "$LH_COPY" ]; then rm -f "$LH_COPY"; fi
}
trap lh_cleanup EXIT

ACTION=""
DIR="$LH_HERE/mock_server/live"
TEXT_MODE=${CARINA_TEXT:-auto}
while [ $# -gt 0 ]; do
  case "$1" in
    start | stop | restart | status)
      ACTION=$1
      shift
      ;;
    --dir | --text)
      [ $# -ge 2 ] || gm_die "$1 needs a value"
      if [ "$1" = --dir ]; then DIR=$2; else TEXT_MODE=$2; fi
      shift 2
      ;;
    --dir=*) DIR=${1#*=} && shift ;;
    --text=*) TEXT_MODE=${1#*=} && shift ;;
    -h | --help)
      lh_usage
      exit 0
      ;;
    *) gm_die "unknown argument '$1' (see --help)" ;;
  esac
done
[ -n "$ACTION" ] || gm_die "usage: bash tools/live_hls.sh start|stop|restart|status [--dir DIR]"

mkdir -p "$DIR"
DIR=$(cd "$DIR" && pwd)
PIDF="$DIR/.live_hls.pid"
LOG="$DIR/.live_hls.log"
WORK="$DIR/.live_hls_work"

lh_mtime() { stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0; }

lh_read_pid() {
  LH_PID=""
  LH_WINPID=""
  [ -f "$PIDF" ] || return 1
  read -r LH_PID LH_WINPID <"$PIDF" || true
  case "$LH_PID" in '' | *[!0-9]*) return 1 ;; esac
  return 0
}

# True when the pid is alive and (as far as we can tell) an ffmpeg.
lh_alive() {
  kill -0 "$1" 2>/dev/null || return 1
  local c=""
  if [ -r "/proc/$1/exename" ]; then
    c=$(cat "/proc/$1/exename" 2>/dev/null || true)
  elif [ -r "/proc/$1/cmdline" ]; then
    c=$(tr '\0' ' ' <"/proc/$1/cmdline" 2>/dev/null || true)
  else
    c=$(ps -p "$1" -o comm= 2>/dev/null || true)
  fi
  case "$c" in "" | *ffmpeg* | *FFMPEG*) return 0 ;; esac
  return 1
}

lh_running() { lh_read_pid && lh_alive "$LH_PID"; }

# Chocolatey's chocolatey/bin/ffmpeg.exe is a shim that starts the real binary as a child;
# run the real one in the background so the pid we store is ffmpeg itself.
lh_real_ffmpeg() {
  local c
  case "$FFMPEG" in
    */chocolatey/bin/ffmpeg | */chocolatey/bin/ffmpeg.exe)
      for c in /c/ProgramData/chocolatey/lib/ffmpeg*/tools/ffmpeg*/bin/ffmpeg.exe \
        /c/ProgramData/chocolatey/lib/ffmpeg*/tools/bin/ffmpeg.exe; do
        if [ -x "$c" ]; then
          printf '%s' "$c"
          return 0
        fi
      done
      ;;
  esac
  printf '%s' "$FFMPEG"
}

lh_status() {
  local segs=0 seq="" age="?" f
  if lh_running; then
    for f in "$DIR"/seg_*.ts; do
      if [ -e "$f" ]; then segs=$((segs + 1)); fi
    done
    if [ -f "$DIR/index.m3u8" ]; then
      seq=$(awk -F: '/^#EXT-X-MEDIA-SEQUENCE/ { print $2 }' "$DIR/index.m3u8" 2>/dev/null || true)
      age=$(($(date +%s) - $(lh_mtime "$DIR/index.m3u8")))
    fi
    gm_log "running: pid $LH_PID${LH_WINPID:+ (windows pid $LH_WINPID)}; $DIR/index.m3u8 media sequence ${seq:-?}, $segs segments on disk, updated ${age}s ago"
    return 0
  fi
  if [ -f "$PIDF" ]; then
    gm_log "not running (stale pid file removed)"
    rm -f "$PIDF"
  else
    gm_log "not running"
  fi
  return 3
}

lh_stop() {
  local i
  if ! lh_read_pid; then
    gm_log "not running"
    rm -rf "$WORK"
    return 0
  fi
  if lh_alive "$LH_PID"; then
    if gm_is_windows && [ -n "$LH_WINPID" ] && command -v taskkill >/dev/null 2>&1; then
      MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' taskkill /PID "$LH_WINPID" /T /F >/dev/null 2>&1 || true
    fi
    kill -TERM "$LH_PID" 2>/dev/null || true
    i=0
    while [ $i -lt 40 ] && kill -0 "$LH_PID" 2>/dev/null; do
      sleep 0.25
      i=$((i + 1))
    done
    if kill -0 "$LH_PID" 2>/dev/null; then kill -KILL "$LH_PID" 2>/dev/null || true; fi
    gm_log "stopped pid $LH_PID"
  else
    gm_log "not running (stale pid file removed)"
  fi
  rm -f "$PIDF"
  rm -rf "$WORK"
}

lh_start() {
  local hms ff i u z1 z2 z3 y1 y2 y3
  if lh_running; then
    gm_log "already running"
    lh_status
    return 0
  fi
  gm_find_ffmpeg
  ff=$(lh_real_ffmpeg)
  DIR_N=$(gm_np "$DIR")
  WORK_N="$DIR_N/.live_hls_work"
  rm -f "$PIDF" "$DIR"/index.m3u8 "$DIR"/index.m3u8.tmp "$DIR"/seg_*.ts "$DIR"/seg_*.ts.tmp
  rm -rf "$WORK"
  gm_prepare_work
  gm_detect_text

  # Wall clock: drawtext reads localtime per frame. The bitmap clock counts from the start
  # time: the graph is built with a placeholder, then ffmpeg starts right on a full second.
  GM_WALL_S0="@S0@"
  u=720
  z1=$((u * 60 / 1080))
  z2=$((u * 38 / 1080))
  z3=$((u * 100 / 1080))
  y1=$((720 * 46 / 100))
  y2=$((y1 + z1 * 165 / 100))
  y3=$((y2 + z2 * 200 / 100))
  g_reset 1280 720 25 2 # inputs 0 (video) and 1 (audio) are the lavfi sources
  g_from "[0:v]"
  g_chain "drawbox=x=36:y=36:w=28:h=28:color=0xE50914:t=fill:enable='lt(mod(t,1),0.5)'"
  g_text "LIVE | H.264 + AAC | HLS" center "$y1" "$z1" FFFFFF 1 0 1
  if [ "$TEXT_MODE" = drawtext ]; then
    g_text_dt '%{localtime\:%Y-%m-%d}' center "$y2" "$z2" DCE6EE 1 0 0 "" 1
  else
    g_text "$(date +%Y-%m-%d)" center "$y2" "$z2" DCE6EE 1 0 0
  fi
  g_clock wall center "$y3" "$z3" FFD24A 1
  g_text "1280x720 25p | 2 s segments | window 6" center bottom:36 22 FFFFFF@0.8 1 0 0
  g_chain "format=yuv420p"
  g_out vout

  hms=$(date +%H%M%S)
  if [ "$TEXT_MODE" != drawtext ]; then
    local first=$hms
    while [ "$hms" = "$first" ]; do hms=$(date +%H%M%S); done
  fi
  GF=${GF//@S0@/$((10#${hms:0:2} * 3600 + 10#${hms:2:2} * 60 + 10#${hms:4:2}))}
  (
    trap '' HUP
    export MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*'
    exec "$ff" -nostdin -hide_banner -loglevel warning \
      -re -f lavfi -i "testsrc2=size=1280x720:rate=25" \
      -re -f lavfi -i "sine=frequency=1000:sample_rate=48000:beep_factor=2" \
      ${GIN[@]+"${GIN[@]}"} \
      -filter_complex "$GF" -map "[vout]" -map 1:a \
      -c:v libx264 -preset veryfast -tune zerolatency -profile:v main -pix_fmt yuv420p \
      -g 50 -keyint_min 50 -sc_threshold 0 -force_key_frames "expr:gte(t,n_forced*2)" \
      -b:v 2500k -maxrate 2500k -bufsize 5000k \
      -c:a aac -b:a 128k -ar 48000 -ac 2 \
      -f hls -hls_time 2 -hls_list_size 6 -hls_flags delete_segments+program_date_time \
      -hls_start_number_source epoch -hls_segment_filename "$DIR_N/seg_%d.ts" "$DIR_N/index.m3u8"
  ) >"$LOG" 2>&1 </dev/null &
  LH_PID=$!
  printf '%s \n' "$LH_PID" >"$PIDF"

  i=0
  while [ ! -f "$DIR/index.m3u8" ]; do
    if ! kill -0 "$LH_PID" 2>/dev/null; then
      rm -f "$PIDF"
      printf '[%s] ERROR: ffmpeg exited. Log (%s):\n' "$GM_TAG" "$LOG" >&2
      tail -n 15 "$LOG" >&2 || true
      exit 1
    fi
    if [ $i -ge 60 ]; then
      gm_warn "no playlist after 30 s; ffmpeg keeps running (see $LOG)"
      break
    fi
    sleep 0.5
    i=$((i + 1))
  done
  LH_WINPID=""
  if [ -r "/proc/$LH_PID/winpid" ]; then LH_WINPID=$(cat "/proc/$LH_PID/winpid" 2>/dev/null || true); fi
  printf '%s %s\n' "$LH_PID" "$LH_WINPID" >"$PIDF"
  gm_log "started (text: $TEXT_MODE)"
  lh_status
}

case "$ACTION" in
  start) lh_start ;;
  stop) lh_stop ;;
  restart)
    lh_stop
    lh_start
    ;;
  status) lh_status || exit $? ;;
esac

// Next-episode autoplay timing (pure, unit-tested).

/** The countdown overlay starts this many seconds before the end. */
export const COUNTDOWN_SECS = 10;
/** Shorter clips never autoplay. */
export const NEXT_MIN_DURATION = 120;

/** Seconds to show in the countdown, or null when the overlay should not be visible. */
export function countdownSeconds(position: number, duration: number, hasNext: boolean, cancelled: boolean): number | null {
  if (!hasNext || cancelled || !isFinite(duration) || duration < NEXT_MIN_DURATION) return null;
  const left = duration - position;
  if (left > COUNTDOWN_SECS) return null;
  return Math.max(1, Math.ceil(left));
}

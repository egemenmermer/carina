// webOS / browser glue: key codes, 1280×720 design scaling, exit.

export type Key =
  | 'up' | 'down' | 'left' | 'right' | 'ok' | 'back'
  | 'chUp' | 'chDown' | 'red' | 'green' | 'yellow' | 'blue'
  | 'play' | 'pause' | 'playPause' | 'stop' | 'ff' | 'rew' | 'info'
  // Synthesised by app.ts: OK held for ~0.7 s.
  | 'okLong';

const codes: Record<number, Key> = {
  37: 'left', 38: 'up', 39: 'right', 40: 'down', 13: 'ok',
  461: 'back', 27: 'back', 10009: 'back',
  33: 'chUp', 34: 'chDown', 427: 'chUp', 428: 'chDown',
  403: 'red', 404: 'green', 405: 'yellow', 406: 'blue',
  415: 'play', 19: 'pause', 413: 'stop', 417: 'ff', 412: 'rew', 10252: 'playPause', 179: 'playPause',
  457: 'info',
};

export function keyOf(e: KeyboardEvent, inTextField: boolean): Key | null {
  const k = codes[e.keyCode];
  if (k) return k;
  if (e.keyCode === 8 && !inTextField) return 'back'; // Backspace in desktop browsers
  if (!inTextField) {
    if (e.keyCode === 32) return 'playPause';
    // Desktop stand-ins for the colour keys: F1–F4.
    if (e.keyCode >= 112 && e.keyCode <= 115) return (['red', 'green', 'yellow', 'blue'] as Key[])[e.keyCode - 112];
  }
  return null;
}

/** CSS px per design px (layout is designed at 1280×720). */
export let S = 1;

export function applyScale(): void {
  const w = window.innerWidth || 1280;
  const h = window.innerHeight || 720;
  S = Math.min(w / 1280, h / 720);
  // 1rem = 10 design px.
  document.documentElement.style.fontSize = 10 * S + 'px';
}

export const px = (design: number): number => Math.round(design * S);

interface WebOSGlobal {
  platformBack?: () => void;
}

export function exitApp(): void {
  const w = (window as unknown as { webOS?: WebOSGlobal }).webOS;
  if (w && typeof w.platformBack === 'function') w.platformBack();
  else window.close();
}

export function tvLanguage(): string {
  const n = navigator as Navigator & { userLanguage?: string };
  return (n.language || n.userLanguage || 'en').toLowerCase();
}

export const isWebOS = /web0s|webos/i.test(navigator.userAgent);

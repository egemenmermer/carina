// VOD resume points: last position per movie / episode, kept in one small
// localStorage entry. Capped (LRU by last save) so it can never outgrow the
// ~5 MB quota. Items near the end are marked watched instead of resumable.

export interface StorageLike {
  getItem(key: string): string | null;
  setItem(key: string, value: string): void;
  removeItem(key: string): void;
}

interface Entry {
  /** playlistId|itemKey */
  k: string;
  /** position, seconds */
  p: number;
  /** duration, seconds (0 = unknown) */
  d: number;
  /** watched to (near) the end */
  w: boolean;
}

export const RESUME_MAX = 200;
/** Less than this and the item counts as not started. */
export const RESUME_MIN_POS = 10;

const STORAGE_KEY = 'carina.resume';

function hash(s: string): string {
  let a = 5381;
  let b = 0;
  for (let i = 0; i < s.length; i++) {
    const c = s.charCodeAt(i);
    a = ((a << 5) + a + c) | 0;
    b = (c + (b << 6) + (b << 16) - b) | 0;
  }
  return 'h' + (a >>> 0).toString(36) + (b >>> 0).toString(36);
}

/** Stable key for an item; long ids (M3U stream URLs) are hashed to keep entries small. */
export function resumeKey(playlistId: string, itemId: string): string {
  return playlistId + '|' + (itemId.length > 40 ? hash(itemId) : itemId);
}

/** True when [pos] of [dur] is close enough to the end to call the item watched. */
export function isNearEnd(pos: number, dur: number): boolean {
  return dur >= 120 && dur - pos <= Math.max(45, dur * 0.05);
}

export class ResumeStore {
  private list: Entry[] | null = null;

  constructor(private storage: StorageLike | null, private max = RESUME_MAX) {}

  private load(): Entry[] {
    if (this.list) return this.list;
    let out: Entry[] = [];
    try {
      const raw = this.storage && this.storage.getItem(STORAGE_KEY);
      const parsed = raw ? JSON.parse(raw) : [];
      if (Array.isArray(parsed)) {
        out = parsed.filter((e) => e && typeof e.k === 'string' && typeof e.p === 'number');
      }
    } catch (e) {
      out = [];
    }
    this.list = out.slice(-this.max);
    return this.list;
  }

  private persist(): void {
    try {
      if (this.storage) this.storage.setItem(STORAGE_KEY, JSON.stringify(this.list));
    } catch (e) {
      // quota exceeded: halve the list and try once more, else run without persistence
      try {
        if (this.list && this.storage) {
          this.list = this.list.slice(-Math.floor(this.max / 2));
          this.storage.setItem(STORAGE_KEY, JSON.stringify(this.list));
        }
      } catch (e2) {
        /* ignore */
      }
    }
  }

  private find(key: string): number {
    const l = this.load();
    for (let i = l.length - 1; i >= 0; i--) if (l[i].k === key) return i;
    return -1;
  }

  /** Position to resume from, or null (never started, watched, or too early). */
  resumeAt(key: string): number | null {
    const i = this.find(key);
    if (i < 0) return null;
    const e = this.load()[i];
    return !e.w && e.p >= RESUME_MIN_POS ? e.p : null;
  }

  isWatched(key: string): boolean {
    const i = this.find(key);
    return i >= 0 && this.load()[i].w;
  }

  /** Records progress. Near the end the item becomes watched and loses its position. */
  save(key: string, pos: number, dur: number): void {
    if (!isFinite(pos) || pos < 0) return;
    if (!isFinite(dur) || dur < 0) dur = 0;
    pos = Math.floor(pos);
    dur = Math.floor(dur);
    const i = this.find(key);
    const watched = isNearEnd(pos, dur);
    if (!watched && pos < RESUME_MIN_POS) {
      // Just opened: keep whatever was stored, do not erase an earlier position.
      return;
    }
    const l = this.load();
    if (i >= 0) l.splice(i, 1);
    l.push({ k: key, p: watched ? 0 : pos, d: dur, w: watched });
    while (l.length > this.max) l.shift();
    this.persist();
  }

  /** Marks an item watched (e.g. playback ended). */
  markWatched(key: string, dur = 0): void {
    const i = this.find(key);
    const l = this.load();
    if (i >= 0) {
      dur = dur || l[i].d;
      l.splice(i, 1);
    }
    l.push({ k: key, p: 0, d: Math.floor(dur), w: true });
    while (l.length > this.max) l.shift();
    this.persist();
  }

  clear(key: string): void {
    const i = this.find(key);
    if (i < 0) return;
    this.load().splice(i, 1);
    this.persist();
  }

  /** Drops everything saved for one playlist. */
  removePlaylist(playlistId: string): void {
    const prefix = playlistId + '|';
    const l = this.load();
    const kept = l.filter((e) => e.k.indexOf(prefix) !== 0);
    if (kept.length !== l.length) {
      this.list = kept;
      this.persist();
    }
  }

  size(): number {
    return this.load().length;
  }
}

function defaultStorage(): StorageLike | null {
  try {
    return typeof localStorage !== 'undefined' ? localStorage : null;
  } catch (e) {
    return null;
  }
}

export const resume = new ResumeStore(defaultStorage());

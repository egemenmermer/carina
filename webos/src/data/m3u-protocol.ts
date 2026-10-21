// Messages between the main thread and the M3U parser worker.
import type { Category, Channel, Episode, Movie, Series } from './models';

export interface WorkerRequest {
  url: string;
  ungroupedName: string;
  /** Abort when no bytes arrive for this long. */
  stallMs: number;
}

export type WorkerMessage =
  | { t: 'progress'; bytes: number; total: number; entries: number }
  | { t: 'meta'; epgUrl: string | null; live: Category[]; movies: Category[]; series: Category[] }
  | { t: 'live'; items: Channel[] }
  | { t: 'movies'; items: Movie[] }
  | { t: 'series'; items: Series[] }
  | { t: 'episodes'; data: Record<string, Episode[]> }
  | { t: 'done' }
  | { t: 'error'; message: string; status: number };

/** Catalogue slices are posted in pieces so no single message blocks the UI thread. */
export const ITEM_CHUNK = 2000;
export const EPISODE_CHUNK = 400;

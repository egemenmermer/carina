// localStorage persistence: playlist configs, favourites, last channel and
// settings only — never catalogues (quota is ~5 MB).
import type { Channel, Playlist } from './data/models';
import { resume } from './resume';

const PREFIX = 'carina.';

function read<T>(key: string, fallback: T): T {
  try {
    const raw = localStorage.getItem(PREFIX + key);
    return raw ? (JSON.parse(raw) as T) : fallback;
  } catch (e) {
    return fallback;
  }
}

function write(key: string, value: unknown): void {
  try {
    if (value == null) localStorage.removeItem(PREFIX + key);
    else localStorage.setItem(PREFIX + key, JSON.stringify(value));
  } catch (e) {
    // quota or private mode: keep running without persistence
  }
}

export type Lang = 'auto' | 'en' | 'tr';

export interface Settings {
  lang: Lang;
  lastPlaylistId: string | null;
}

export const store = {
  playlists(): Playlist[] {
    return read<Playlist[]>('playlists', []);
  },
  savePlaylists(list: Playlist[]): void {
    write('playlists', list);
  },
  addPlaylist(p: Playlist): void {
    const list = store.playlists().filter((x) => x.id !== p.id);
    list.push(p);
    store.savePlaylists(list);
  },
  removePlaylist(id: string): void {
    store.savePlaylists(store.playlists().filter((x) => x.id !== id));
    write('fav.' + id, null);
    write('last.' + id, null);
    resume.removePlaylist(id);
  },
  settings(): Settings {
    return read<Settings>('settings', { lang: 'auto', lastPlaylistId: null });
  },
  saveSettings(patch: Partial<Settings>): void {
    const s = store.settings();
    for (const k of Object.keys(patch) as (keyof Settings)[]) (s as unknown as Record<string, unknown>)[k] = patch[k];
    write('settings', s);
  },
  /** Favourite channels are stored as slim snapshots so the list shows without loading every channel. */
  favourites(playlistId: string): Channel[] {
    return read<Channel[]>('fav.' + playlistId, []);
  },
  isFavourite(playlistId: string, channelId: string): boolean {
    return store.favourites(playlistId).some((c) => c.id === channelId);
  },
  toggleFavourite(playlistId: string, c: Channel): boolean {
    const list = store.favourites(playlistId);
    const i = list.findIndex((x) => x.id === c.id);
    if (i >= 0) list.splice(i, 1);
    else list.push({ id: c.id, name: c.name, num: c.num, logo: c.logo, epgId: c.epgId, categoryId: c.categoryId, url: c.url });
    write('fav.' + playlistId, list);
    return i < 0;
  },
  lastChannel(playlistId: string): { categoryId: string; channelId: string } | null {
    return read<{ categoryId: string; channelId: string } | null>('last.' + playlistId, null);
  },
  saveLastChannel(playlistId: string, categoryId: string, channelId: string): void {
    write('last.' + playlistId, { categoryId, channelId });
  },
};

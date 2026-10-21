// One interface over Xtream and M3U playlists. Catalogue lists are fetched
// per category and kept in a small LRU so memory stays bounded.
import { getText } from './http';
import { buildM3uCatalog, M3uCatalog, parseM3u } from './m3u';
import type { Category, Channel, Episode, Item, Movie, MovieDetails, Playlist, Programme, Section, Series, SeriesDetails } from './models';
import { fetchXmltvText, parseXmltv } from './xmltv';
import {
  liveFormats, parseCategories, parseChannels, parseMovieInfo, parseMovies, parseSeriesInfo, parseSeriesList, parseShortEpg,
  XtreamClient,
} from './xtream';

export const ALL = '__all';

export interface Source {
  readonly playlist: Playlist;
  open(): Promise<void>;
  categories(section: Section): Promise<Category[]>;
  /** Whether an "All" pseudo-category is cheap enough to offer. */
  hasAll(section: Section): boolean;
  items(section: Section, categoryId: string): Promise<Item[]>;
  movieDetails(m: Movie): Promise<MovieDetails | null>;
  seriesDetails(s: Series): Promise<SeriesDetails>;
  /** Now/next (and maybe more) for a channel; [] when unknown. */
  epg(c: Channel): Promise<Programme[]>;
  /** Candidate URLs in the order to try. */
  liveUrls(c: Channel): string[];
  movieUrl(m: Movie, ext: string | null): string;
  episodeUrl(e: Episode): string;
}

class Lru<T> {
  private keys: string[] = [];
  private map: Record<string, T> = {};
  constructor(private max: number) {}
  get(k: string): T | undefined {
    return this.map[k];
  }
  set(k: string, v: T): void {
    const i = this.keys.indexOf(k);
    if (i >= 0) this.keys.splice(i, 1);
    this.keys.push(k);
    this.map[k] = v;
    while (this.keys.length > this.max) delete this.map[this.keys.shift() as string];
  }
}

const sectionAction: Record<Section, [string, string]> = {
  live: ['get_live_categories', 'get_live_streams'],
  movies: ['get_vod_categories', 'get_vod_streams'],
  series: ['get_series_categories', 'get_series'],
};

export class XtreamSource implements Source {
  private client: XtreamClient;
  private formats = ['m3u8', 'ts'];
  private cats: Partial<Record<Section, Category[]>> = {};
  private lists = new Lru<Item[]>(6);
  private epgCache = new Lru<{ at: number; list: Programme[] }>(400);
  private pending: Record<string, Promise<Item[]>> = {};

  constructor(readonly playlist: Playlist & { kind: 'xtream' }) {
    this.client = new XtreamClient(playlist);
  }

  async open(): Promise<void> {
    const acc = await this.client.account();
    this.formats = liveFormats(acc.allowedFormats);
  }

  async categories(section: Section): Promise<Category[]> {
    const c = this.cats[section];
    if (c) return c;
    const list = parseCategories(await this.client.call({ action: sectionAction[section][0] }));
    this.cats[section] = list;
    return list;
  }

  hasAll(section: Section): boolean {
    // All channels (10k) is fine; 50k movies of JSON is not on a 1.5 GB TV.
    return section === 'live';
  }

  items(section: Section, categoryId: string): Promise<Item[]> {
    const key = section + '|' + categoryId;
    const hit = this.lists.get(key);
    if (hit) return Promise.resolve(hit);
    if (this.pending[key]) return this.pending[key];
    const params: Record<string, string> = { action: sectionAction[section][1] };
    if (categoryId !== ALL) params.category_id = categoryId;
    const p = this.client.call(params, 45000).then((json) => {
      const list: Item[] = section === 'live' ? parseChannels(json) : section === 'movies' ? parseMovies(json) : parseSeriesList(json);
      this.lists.set(key, list);
      delete this.pending[key];
      return list;
    }, (e) => {
      delete this.pending[key];
      throw e;
    });
    this.pending[key] = p;
    return p;
  }

  async movieDetails(m: Movie): Promise<MovieDetails | null> {
    return parseMovieInfo(await this.client.call({ action: 'get_vod_info', vod_id: m.id }));
  }

  async seriesDetails(s: Series): Promise<SeriesDetails> {
    return parseSeriesInfo(await this.client.call({ action: 'get_series_info', series_id: s.id }));
  }

  async epg(c: Channel): Promise<Programme[]> {
    const hit = this.epgCache.get(c.id);
    const now = Date.now();
    if (hit && now - hit.at < 10 * 60000 && (!hit.list.length || hit.list[hit.list.length - 1].stop > now)) return hit.list;
    let list: Programme[] = [];
    try {
      list = parseShortEpg(await this.client.call({ action: 'get_short_epg', stream_id: c.id, limit: '4' }, 15000));
    } catch (e) {
      list = [];
    }
    this.epgCache.set(c.id, { at: now, list });
    return list;
  }

  liveUrls(c: Channel): string[] {
    if (c.url) return [c.url];
    return this.formats.map((f) => this.client.urls.live(c.id, f));
  }

  movieUrl(m: Movie, ext: string | null): string {
    return m.url || this.client.urls.movie(m.id, ext || m.ext);
  }

  episodeUrl(e: Episode): string {
    return e.url || this.client.urls.episode(e.id, e.ext);
  }
}

export class M3uSource implements Source {
  private cat: M3uCatalog | null = null;
  private guide: Record<string, Programme[]> | null = null;
  private guideLoading: Promise<void> | null = null;

  constructor(readonly playlist: Playlist & { kind: 'm3u' }, private ungroupedName: string) {}

  async open(): Promise<void> {
    const text = await getText(this.playlist.url, 90000).promise;
    this.cat = buildM3uCatalog(parseM3u(text), this.ungroupedName);
  }

  private c(): M3uCatalog {
    if (!this.cat) throw new Error('not open');
    return this.cat;
  }

  async categories(section: Section): Promise<Category[]> {
    return this.c()[section].categories;
  }

  hasAll(): boolean {
    return true;
  }

  async items(section: Section, categoryId: string): Promise<Item[]> {
    const all = this.c()[section].items as Item[];
    if (categoryId === ALL) return all;
    return all.filter((i) => i.categoryId === categoryId);
  }

  async movieDetails(): Promise<MovieDetails | null> {
    return null;
  }

  async seriesDetails(s: Series): Promise<SeriesDetails> {
    const episodes = this.c().episodes[s.id] || [];
    const seasons: number[] = [];
    for (const e of episodes) if (seasons.indexOf(e.season) < 0) seasons.push(e.season);
    return { plot: null, genre: null, year: null, rating: null, cover: s.poster, backdrop: null, seasons, episodes };
  }

  async epg(c: Channel): Promise<Programme[]> {
    if (!c.epgId || !this.cat || !this.cat.epgUrl) return [];
    if (!this.guide) {
      if (!this.guideLoading) this.guideLoading = this.loadGuide();
      await this.guideLoading;
    }
    return (this.guide && this.guide[c.epgId.toLowerCase()]) || [];
  }

  private async loadGuide(): Promise<void> {
    const wanted: Record<string, boolean> = {};
    for (const ch of this.c().live.items) if (ch.epgId) wanted[ch.epgId.toLowerCase()] = true;
    try {
      const xml = await fetchXmltvText(this.c().epgUrl as string);
      const now = Date.now();
      this.guide = parseXmltv(xml, now - 3 * 3600000, now + 12 * 3600000, wanted);
    } catch (e) {
      this.guide = {}; // too large, gzipped or unreachable: no guide
    }
  }

  liveUrls(c: Channel): string[] {
    return c.url ? [c.url] : [];
  }

  movieUrl(m: Movie): string {
    return m.url || '';
  }

  episodeUrl(e: Episode): string {
    return e.url || '';
  }
}

export function createSource(p: Playlist, ungroupedName: string): Source {
  return p.kind === 'xtream' ? new XtreamSource(p) : new M3uSource(p, ungroupedName);
}

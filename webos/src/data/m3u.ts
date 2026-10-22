// Line-based M3U/M3U8 playlist parser (a slim port of the Flutter parser).
// Pure and synchronous so it can be unit-tested in Node. Avoids regex
// lookbehind: Chrome 53 (webOS 4.x) does not support it.
import type { Category, Channel, Episode, Movie, Series } from './models';

export type M3uKind = 'live' | 'movie' | 'episode';

export interface M3uEntry {
  name: string;
  url: string;
  group: string | null;
  logo: string | null;
  tvgId: string | null;
  duration: number;
  kind: M3uKind;
}

export interface M3uParseResult {
  epgUrl: string | null;
  entries: M3uEntry[];
}

const attrRe = /([A-Za-z0-9_\-]+)\s*=\s*"([^"]*)"/g;

/** key="value" attributes of an #EXTINF / #EXTM3U line, keys lower-cased. */
export function parseAttributes(line: string): Record<string, string> {
  const out: Record<string, string> = {};
  attrRe.lastIndex = 0;
  let m: RegExpExecArray | null;
  while ((m = attrRe.exec(line))) out[m[1].toLowerCase()] = m[2].trim();
  return out;
}

/** Text after the first comma that is outside double quotes. */
function displayName(line: string): string {
  let inQuote = false;
  for (let i = 0; i < line.length; i++) {
    const c = line.charAt(i);
    if (c === '"') inQuote = !inQuote;
    else if (c === ',' && !inQuote) return line.slice(i + 1).trim();
  }
  return '';
}

const movieExtensions = ['mp4', 'mkv', 'avi', 'mov'];

export function classifyM3u(url: string, duration: number): M3uKind {
  let path = url;
  const q = path.indexOf('?');
  if (q >= 0) path = path.slice(0, q);
  path = path.toLowerCase();
  if (path.indexOf('/movie/') >= 0) return 'movie';
  if (path.indexOf('/series/') >= 0) return 'episode';
  const dot = path.lastIndexOf('.');
  const extn = dot > path.lastIndexOf('/') ? path.slice(dot + 1) : '';
  if (duration > 0 && movieExtensions.indexOf(extn) >= 0) return 'movie';
  return 'live';
}

/**
 * Incremental parser: feed text in arbitrary chunks, entries are handed to
 * [onEntry] as soon as their URL line is complete. Nothing is accumulated, so
 * a playlist of any size never needs its raw text or entry list in memory.
 */
export class M3uParser {
  epgUrl: string | null = null;
  count = 0;
  private carry = '';
  private first = true;
  private pending: { attrs: Record<string, string>; name: string; duration: number } | null = null;
  private group: string | null = null;

  constructor(private onEntry: (e: M3uEntry) => void) {}

  /** Feeds a chunk; a trailing partial line is kept for the next call. */
  push(chunk: string): void {
    let text = this.carry ? this.carry + chunk : chunk;
    this.carry = '';
    if (this.first && text.length) {
      this.first = false;
      if (text.charCodeAt(0) === 0xfeff) text = text.slice(1);
    }
    let start = 0;
    for (;;) {
      const end = text.indexOf('\n', start);
      if (end < 0) break;
      this.line(text.slice(start, end));
      start = end + 1;
    }
    this.carry = start < text.length ? text.slice(start) : '';
  }

  /** Flushes the last line (a file without a trailing newline). */
  finish(): void {
    if (this.carry) this.line(this.carry);
    this.carry = '';
  }

  private line(raw: string): void {
    const line = raw.trim();
    if (!line) return;
    if (line.charAt(0) === '#') {
      const upper = line.slice(0, 10).toUpperCase();
      if (upper.indexOf('#EXTM3U') === 0) {
        const a = parseAttributes(line);
        const tvg = a['url-tvg'] || a['x-tvg-url'] || '';
        if (tvg) this.epgUrl = tvg.split(',')[0].trim() || null;
      } else if (upper.indexOf('#EXTINF:') === 0) {
        const body = line.slice(8);
        const duration = parseInt(body, 10);
        this.pending = { attrs: parseAttributes(body), name: displayName(body), duration: isFinite(duration) ? duration : -1 };
        this.group = null;
      } else if (upper.indexOf('#EXTGRP:') === 0) {
        this.group = line.slice(8).trim() || null;
      }
      return;
    }
    const pending = this.pending;
    if (!pending) return; // a bare URL without #EXTINF
    const a = pending.attrs;
    this.count++;
    this.onEntry({
      name: pending.name || a['tvg-name'] || line,
      url: line,
      group: a['group-title'] || this.group,
      logo: a['tvg-logo'] || a['logo'] || null,
      tvgId: a['tvg-id'] || null,
      duration: pending.duration,
      kind: classifyM3u(line, pending.duration),
    });
    this.pending = null;
    this.group = null;
  }
}

export function parseM3u(text: string): M3uParseResult {
  const entries: M3uEntry[] = [];
  const p = new M3uParser((e) => entries.push(e));
  p.push(text);
  p.finish();
  return { epgUrl: p.epgUrl, entries };
}

export interface SeriesMarker {
  seriesName: string;
  season: number;
  episode: number;
  episodeTitle: string | null;
}

// "(?:^|[^A-Za-z0-9])" stands in for the lookbehind of the Dart regex.
const seasonEpisode = /(^|[^A-Za-z0-9])S(\d{1,3})[ ._\-]*E(\d{1,4})(?!\d)/i;
const crossMarker = /(^|[^A-Za-z0-9])(\d{1,2})x(\d{1,3})(?![A-Za-z0-9])/i;
const tailJunk = ' \t-–—|:._,;([{';
const headJunk = ' \t-–—|:._,;)]}';

export function parseSeriesMarker(name: string): SeriesMarker | null {
  const m = seasonEpisode.exec(name) || crossMarker.exec(name);
  if (!m) return null;
  const startIdx = m.index + m[1].length;
  const endIdx = m.index + m[0].length;
  let a = startIdx;
  while (a > 0 && tailJunk.indexOf(name.charAt(a - 1)) >= 0) a--;
  const before = name.slice(0, a).trim();
  let b = endIdx;
  while (b < name.length && headJunk.indexOf(name.charAt(b)) >= 0) b++;
  const after = name.slice(b).trim();
  return {
    seriesName: before || after || name.trim(),
    season: parseInt(m[2], 10),
    episode: parseInt(m[3], 10),
    episodeTitle: before && after ? after : null,
  };
}

// ---- catalogue -----------------------------------------------------------

export interface M3uCatalog {
  epgUrl: string | null;
  live: { categories: Category[]; items: Channel[] };
  movies: { categories: Category[]; items: Movie[] };
  series: { categories: Category[]; items: Series[] };
  episodes: Record<string, Episode[]>;
}

const UNGROUPED = '__ungrouped';

function catId(group: string | null): string {
  return group ? 'g:' + group : UNGROUPED;
}

function addCategory(list: Category[], seen: Record<string, boolean>, group: string | null, ungroupedName: string): string {
  const id = catId(group);
  if (!seen[id]) {
    seen[id] = true;
    list.push({ id, name: group || ungroupedName });
  }
  return id;
}

/** Builds the catalogue entry by entry (see [M3uParser]); call [finish] once. */
export class M3uCatalogBuilder {
  private cat: M3uCatalog = {
    epgUrl: null,
    live: { categories: [], items: [] },
    movies: { categories: [], items: [] },
    series: { categories: [], items: [] },
    episodes: {},
  };
  private seenLive: Record<string, boolean> = {};
  private seenMovie: Record<string, boolean> = {};
  private seenSeries: Record<string, boolean> = {};
  private seriesIndex: Record<string, Series> = {};

  constructor(private ungroupedName = 'Other') {}

  // Ids derive from the stream URL, not the line number: the playlist is
  // downloaded again on every open, and favourites / last channel are saved
  // by id, so they must survive inserted or reordered lines.
  add(e: M3uEntry): void {
    const cat = this.cat;
    if (e.kind === 'live') {
      const categoryId = addCategory(cat.live.categories, this.seenLive, e.group, this.ungroupedName);
      cat.live.items.push({ id: 'l:' + e.url, name: e.name, num: cat.live.items.length + 1, logo: e.logo, epgId: e.tvgId, categoryId, url: e.url });
    } else if (e.kind === 'movie') {
      const categoryId = addCategory(cat.movies.categories, this.seenMovie, e.group, this.ungroupedName);
      const dot = e.url.split('?')[0].lastIndexOf('.');
      cat.movies.items.push({
        id: 'm:' + e.url, name: e.name, poster: e.logo, rating: null,
        ext: dot > 0 ? e.url.split('?')[0].slice(dot + 1) : null,
        year: (/(19|20)\d\d/.exec(e.name) || [null])[0], categoryId, url: e.url,
      });
    } else {
      const categoryId = addCategory(cat.series.categories, this.seenSeries, e.group, this.ungroupedName);
      const mk = parseSeriesMarker(e.name);
      const sName = mk ? mk.seriesName : e.name;
      const key = categoryId + '|' + sName.toLowerCase();
      let s = this.seriesIndex[key];
      if (!s) {
        s = { id: 's:' + key, name: sName, poster: e.logo, rating: null, year: null, categoryId };
        this.seriesIndex[key] = s;
        cat.series.items.push(s);
        cat.episodes[s.id] = [];
      }
      const eps = cat.episodes[s.id];
      eps.push({
        id: 'e:' + e.url,
        season: mk ? mk.season : 1,
        episode: mk ? mk.episode : eps.length + 1,
        title: mk && mk.episodeTitle ? mk.episodeTitle : e.name,
        ext: null, plot: null, durationSecs: e.duration > 0 ? e.duration : null, image: e.logo, url: e.url,
      });
    }
  }

  finish(epgUrl: string | null): M3uCatalog {
    const cat = this.cat;
    cat.epgUrl = epgUrl;
    for (const id of Object.keys(cat.episodes)) {
      cat.episodes[id].sort((a, b) => a.season - b.season || a.episode - b.episode);
    }
    this.seriesIndex = {};
    return cat;
  }
}

export function buildM3uCatalog(parsed: M3uParseResult, ungroupedName = 'Other'): M3uCatalog {
  const b = new M3uCatalogBuilder(ungroupedName);
  for (const e of parsed.entries) b.add(e);
  return b.finish(parsed.epgUrl);
}

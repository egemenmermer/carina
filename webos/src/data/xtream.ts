// Xtream Codes API: URL builders and pure response parsers (testable in
// Node), plus a small client on top of the XHR wrapper.
import { asDouble, asEpochMs, asId, asInt, asList, asMap, asString, decodeMaybeBase64, parseJsonLenient } from './json';
import { getText, HttpError } from './http';
import type { Category, Channel, Episode, Movie, MovieDetails, Programme, Series, SeriesDetails, XtreamPlaylist } from './models';

export function normalizeServer(server: string): string {
  let s = server.trim();
  while (s.charAt(s.length - 1) === '/') s = s.slice(0, -1);
  if (s && !/^[a-z][a-z0-9+.\-]*:\/\//i.test(s)) s = 'http://' + s;
  return s;
}

const enc = encodeURIComponent;

function ext(e: string | null | undefined, fallback: string): string {
  let s = (e || '').trim();
  while (s.charAt(0) === '.') s = s.slice(1);
  return s ? enc(s) : fallback;
}

const absoluteUrl = /^[A-Za-z][A-Za-z0-9+.\-]*:\/\/\S+$/;

export function usableDirectSource(d: string | null | undefined): string | null {
  const s = (d || '').trim();
  return s && absoluteUrl.test(s) ? s : null;
}

export class XtreamUrls {
  readonly server: string;
  constructor(server: string, readonly username: string, readonly password: string) {
    this.server = normalizeServer(server);
  }
  private cred(): string {
    return `${enc(this.username.trim())}/${enc(this.password.trim())}`;
  }
  live(id: string, format: string): string {
    return `${this.server}/live/${this.cred()}/${enc(id)}.${ext(format, 'ts')}`;
  }
  movie(id: string, e: string | null): string {
    return `${this.server}/movie/${this.cred()}/${enc(id)}.${ext(e, 'mp4')}`;
  }
  episode(id: string, e: string | null): string {
    return `${this.server}/series/${this.cred()}/${enc(id)}.${ext(e, 'mp4')}`;
  }
  api(params: Record<string, string> = {}): string {
    let u = `${this.server}/player_api.php?username=${enc(this.username)}&password=${enc(this.password)}`;
    for (const k of Object.keys(params)) u += `&${enc(k)}=${enc(params[k])}`;
    return u;
  }
}

/**
 * Live formats to try in order. webOS plays HLS natively, so .m3u8 goes
 * first when the panel allows it; .ts stays as the fallback.
 */
export function liveFormats(allowed: string[]): string[] {
  const norm = allowed
    .map((f) => {
      let s = f.trim().toLowerCase();
      while (s.charAt(0) === '.') s = s.slice(1);
      return s === 'hls' ? 'm3u8' : s;
    })
    .filter((f) => f === 'm3u8' || f === 'ts');
  if (!norm.length) return ['m3u8', 'ts'];
  const out: string[] = [];
  if (norm.indexOf('m3u8') >= 0) out.push('m3u8');
  if (norm.indexOf('ts') >= 0) out.push('ts');
  return out;
}

// ---- parsers -------------------------------------------------------------

export interface AccountInfo {
  auth: boolean;
  status: string | null;
  expires: number | null;
  allowedFormats: string[];
}

export function parseAccount(json: unknown): AccountInfo {
  const root = asMap(json);
  if (!root.user_info) throw new Error('unparseable');
  const u = asMap(root.user_info);
  const auth = asInt(u.auth);
  return {
    auth: auth == null ? true : auth !== 0,
    status: asString(u.status),
    expires: asEpochMs(u.exp_date),
    allowedFormats: asList(u.allowed_output_formats).map((f) => asString(f) || '').filter(Boolean),
  };
}

export function parseCategories(json: unknown): Category[] {
  const out: Category[] = [];
  for (const raw of asList(json)) {
    const m = asMap(raw);
    const id = asId(m.category_id);
    if (id == null) continue;
    out.push({ id, name: asString(m.category_name) || id });
  }
  return out;
}

export function parseChannels(json: unknown): Channel[] {
  const out: Channel[] = [];
  for (const raw of asList(json)) {
    const m = asMap(raw);
    const id = asId(m.stream_id);
    if (id == null) continue;
    out.push({
      id,
      name: asString(m.name) || asString(m.title) || '',
      num: asInt(m.num),
      logo: asString(m.stream_icon),
      epgId: asString(m.epg_channel_id),
      categoryId: asId(m.category_id),
      url: usableDirectSource(asString(m.direct_source)),
    });
  }
  return out;
}

function yearOf(...vals: unknown[]): string | null {
  for (const v of vals) {
    const s = asString(v);
    const m = s && /(19|20)\d\d/.exec(s);
    if (m) return m[0];
  }
  return null;
}

function rating(...vals: unknown[]): number | null {
  for (const v of vals) {
    const d = asDouble(v);
    if (d != null && d > 0) return Math.round(d * 10) / 10;
  }
  return null;
}

export function parseMovies(json: unknown): Movie[] {
  const out: Movie[] = [];
  for (const raw of asList(json)) {
    const m = asMap(raw);
    const id = asId(m.stream_id);
    if (id == null) continue;
    out.push({
      id,
      name: asString(m.name) || asString(m.title) || '',
      poster: asString(m.stream_icon) || asString(m.cover),
      rating: rating(m.rating, m.rating_5based != null ? (asDouble(m.rating_5based) || 0) * 2 : null),
      ext: asString(m.container_extension),
      year: yearOf(m.year, m.releasedate, m.name),
      categoryId: asId(m.category_id),
      url: usableDirectSource(asString(m.direct_source)),
    });
  }
  return out;
}

export function parseSeriesList(json: unknown): Series[] {
  const out: Series[] = [];
  for (const raw of asList(json)) {
    const m = asMap(raw);
    const id = asId(m.series_id);
    if (id == null) continue;
    out.push({
      id,
      name: asString(m.name) || asString(m.title) || '',
      poster: asString(m.cover) || asString(m.cover_big),
      rating: rating(m.rating, m.rating_5based != null ? (asDouble(m.rating_5based) || 0) * 2 : null),
      year: yearOf(m.year, m.releaseDate, m.releasedate),
      categoryId: asId(m.category_id),
    });
  }
  return out;
}

function firstString(v: unknown): string | null {
  if (Array.isArray(v)) {
    for (const x of v) {
      const s = asString(x);
      if (s) return s;
    }
    return null;
  }
  return asString(v);
}

export function parseMovieInfo(json: unknown): MovieDetails {
  const root = asMap(json);
  const info = asMap(root.info);
  const data = asMap(root.movie_data);
  return {
    plot: asString(info.plot) || asString(info.description),
    genre: asString(info.genre),
    year: yearOf(info.releasedate, info.year),
    rating: rating(info.rating),
    durationSecs: asInt(info.duration_secs),
    cover: asString(info.movie_image) || asString(info.cover_big),
    backdrop: firstString(info.backdrop_path),
    ext: asString(data.container_extension),
    cast: asString(info.cast) || asString(info.actors),
    director: asString(info.director),
  };
}

function parseEpisode(raw: unknown, seasonHint: number | null): Episode | null {
  const m = asMap(raw);
  const id = asId(m.id);
  if (id == null) return null;
  const info = asMap(m.info);
  const season = asInt(m.season) || seasonHint || 1;
  const episode = asInt(m.episode_num) || 0;
  return {
    id,
    season,
    episode,
    title: asString(m.title) || `S${season} E${episode}`,
    ext: asString(m.container_extension),
    plot: asString(info.plot) || asString(info.overview),
    durationSecs: asInt(info.duration_secs),
    image: asString(info.movie_image),
    url: usableDirectSource(asString(m.direct_source)),
  };
}

/** `episodes` may be {"1": [...]}, a list of per-season lists, or a flat list. */
export function parseSeriesInfo(json: unknown): SeriesDetails {
  const root = asMap(json);
  const info = asMap(root.info);
  const episodes: Episode[] = [];
  const raw = root.episodes;
  const add = (list: unknown, hint: number | null) => {
    for (const e of asList(list)) {
      if (Array.isArray(e)) add(e, hint);
      else {
        const ep = parseEpisode(e, hint);
        if (ep) episodes.push(ep);
      }
    }
  };
  if (Array.isArray(raw)) add(raw, null);
  else {
    const map = asMap(raw);
    for (const k of Object.keys(map)) add(map[k], asInt(k));
  }
  episodes.sort((a, b) => a.season - b.season || a.episode - b.episode);
  const seasons: number[] = [];
  for (const e of episodes) if (seasons.indexOf(e.season) < 0) seasons.push(e.season);
  return {
    plot: asString(info.plot) || asString(info.description),
    genre: asString(info.genre),
    year: yearOf(info.releaseDate, info.releasedate, info.year),
    rating: rating(info.rating),
    cover: asString(info.cover) || asString(info.cover_big),
    backdrop: firstString(info.backdrop_path),
    seasons,
    episodes,
  };
}

export function parseShortEpg(json: unknown): Programme[] {
  const root = json && !Array.isArray(json) ? asMap(json).epg_listings : json;
  const out: Programme[] = [];
  for (const raw of asList(root)) {
    const m = asMap(raw);
    const start = asEpochMs(m.start_timestamp);
    const stop = asEpochMs(m.stop_timestamp) || asEpochMs(m.end_timestamp);
    if (start == null || stop == null || stop <= start) continue;
    out.push({
      title: decodeMaybeBase64(asString(m.title)) || '',
      description: decodeMaybeBase64(asString(m.description)) || null,
      start,
      stop,
    });
  }
  out.sort((a, b) => a.start - b.start);
  return out;
}

// ---- client --------------------------------------------------------------

export class XtreamClient {
  readonly urls: XtreamUrls;
  constructor(p: XtreamPlaylist) {
    this.urls = new XtreamUrls(p.server, p.username, p.password);
  }

  async call(params: Record<string, string>, timeoutMs?: number): Promise<unknown> {
    const text = await getText(this.urls.api(params), timeoutMs).promise;
    try {
      return parseJsonLenient(text);
    } catch (e) {
      throw new HttpError('unparseable', 200);
    }
  }

  async account(): Promise<AccountInfo> {
    const a = parseAccount(await this.call({}));
    if (!a.auth) throw new HttpError('unauthorized', 401);
    return a;
  }
}

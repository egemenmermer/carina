// Slim catalogue records. Raw provider JSON is dropped right after parsing:
// providers list 10k+ channels and 50k movies, and the TV has ~1.5 GB RAM.

export type Section = 'live' | 'movies' | 'series';

export interface XtreamPlaylist {
  id: string;
  kind: 'xtream';
  name: string;
  server: string;
  username: string;
  password: string;
}

export interface M3uPlaylist {
  id: string;
  kind: 'm3u';
  name: string;
  url: string;
}

export type Playlist = XtreamPlaylist | M3uPlaylist;

export interface Category {
  id: string;
  name: string;
}

export interface Channel {
  id: string;
  name: string;
  num: number | null;
  logo: string | null;
  epgId: string | null;
  categoryId: string | null;
  /** Direct stream URL (M3U); Xtream URLs are built from the id. */
  url: string | null;
}

export interface Movie {
  id: string;
  name: string;
  poster: string | null;
  rating: number | null;
  ext: string | null;
  year: string | null;
  categoryId: string | null;
  url: string | null;
}

export interface Series {
  id: string;
  name: string;
  poster: string | null;
  rating: number | null;
  year: string | null;
  categoryId: string | null;
}

export interface Episode {
  id: string;
  season: number;
  episode: number;
  title: string;
  ext: string | null;
  plot: string | null;
  durationSecs: number | null;
  image: string | null;
  url: string | null;
}

export interface SeriesDetails {
  plot: string | null;
  genre: string | null;
  year: string | null;
  rating: number | null;
  cover: string | null;
  backdrop: string | null;
  seasons: number[];
  episodes: Episode[];
}

export interface MovieDetails {
  plot: string | null;
  genre: string | null;
  year: string | null;
  rating: number | null;
  durationSecs: number | null;
  cover: string | null;
  backdrop: string | null;
  ext: string | null;
  cast: string | null;
  director: string | null;
}

export interface Programme {
  title: string;
  description: string | null;
  start: number; // epoch ms
  stop: number; // epoch ms
}

export type Item = Channel | Movie | Series;

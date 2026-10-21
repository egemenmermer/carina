// Loads an M3U playlist into a catalogue. The download and the parse run in a
// Web Worker (inline Blob first, then the separate m3u-worker.js file); if no
// worker can be created, or it fails to start, the same incremental parser
// runs on the main thread in short time slices so the UI stays responsive.
import { getText, HttpError } from './http';
import { M3uCatalogBuilder, M3uParser, type M3uCatalog } from './m3u';
import type { WorkerMessage, WorkerRequest } from './m3u-protocol';

export interface M3uProgress {
  bytes: number;
  /** 0 when unknown. */
  total: number;
  entries: number;
}

/** The slice of the Worker API the loader uses (lets tests inject a fake). */
export interface WorkerLike {
  postMessage(m: WorkerRequest): void;
  terminate(): void;
  onmessage: ((e: { data: WorkerMessage }) => void) | null;
  onerror: ((e: unknown) => void) | null;
}

export interface LoadOptions {
  ungroupedName: string;
  onProgress?: (p: M3uProgress) => void;
  createWorker?: () => WorkerLike;
  fetchText?: (url: string) => Promise<string>;
  stallMs?: number;
  /** Characters parsed per main-thread slice (fallback path). */
  sliceChars?: number;
}

/** Worker could not start (or crashed before sending anything): use the main thread. */
class WorkerUnavailable extends Error {}

export function createDefaultWorker(): WorkerLike {
  if (typeof Worker === 'undefined') throw new Error('Worker not supported');
  if (typeof __M3U_WORKER_SRC__ === 'string' && __M3U_WORKER_SRC__ && typeof Blob === 'function' && typeof URL !== 'undefined' && URL.createObjectURL) {
    let blobUrl = '';
    try {
      blobUrl = URL.createObjectURL(new Blob([__M3U_WORKER_SRC__], { type: 'text/javascript' }));
      const w = new Worker(blobUrl) as unknown as WorkerLike;
      const url = blobUrl;
      const terminate = w.terminate.bind(w);
      w.terminate = () => {
        terminate();
        URL.revokeObjectURL(url);
      };
      return w;
    } catch (e) {
      if (blobUrl) URL.revokeObjectURL(blobUrl);
      // fall through to the script file
    }
  }
  return new Worker('m3u-worker.js') as unknown as WorkerLike;
}

export function loadM3uCatalog(url: string, o: LoadOptions): Promise<M3uCatalog> {
  return viaWorker(url, o).then(undefined, (e) => {
    if (e instanceof WorkerUnavailable) return onMainThread(url, o);
    throw e;
  });
}

function viaWorker(url: string, o: LoadOptions): Promise<M3uCatalog> {
  return new Promise<M3uCatalog>((resolve, reject) => {
    let w: WorkerLike;
    try {
      w = (o.createWorker || createDefaultWorker)();
    } catch (e) {
      reject(new WorkerUnavailable('no worker'));
      return;
    }
    const cat: M3uCatalog = {
      epgUrl: null,
      live: { categories: [], items: [] },
      movies: { categories: [], items: [] },
      series: { categories: [], items: [] },
      episodes: {},
    };
    let started = false;
    let settled = false;
    const end = (fn: () => void): void => {
      if (settled) return;
      settled = true;
      w.onmessage = null;
      w.onerror = null;
      try {
        w.terminate();
      } catch (e) {
        /* ignore */
      }
      fn();
    };
    w.onerror = () => end(() => reject(started ? new HttpError('parser crashed', 0) : new WorkerUnavailable('worker failed')));
    w.onmessage = (e) => {
      const m = e.data;
      started = true;
      switch (m.t) {
        case 'progress':
          if (o.onProgress) o.onProgress({ bytes: m.bytes, total: m.total, entries: m.entries });
          break;
        case 'meta':
          cat.epgUrl = m.epgUrl;
          cat.live.categories = m.live;
          cat.movies.categories = m.movies;
          cat.series.categories = m.series;
          break;
        case 'live':
          for (const it of m.items) cat.live.items.push(it);
          break;
        case 'movies':
          for (const it of m.items) cat.movies.items.push(it);
          break;
        case 'series':
          for (const it of m.items) cat.series.items.push(it);
          break;
        case 'episodes':
          for (const k of Object.keys(m.data)) cat.episodes[k] = m.data[k];
          break;
        case 'done':
          end(() => resolve(cat));
          break;
        case 'error':
          // A bare network error may be specific to the worker context: retry
          // once on the main thread. HTTP errors and timeouts are final.
          end(() => reject(m.message === 'network' ? new WorkerUnavailable('worker network') : new HttpError(m.message, m.status)));
          break;
      }
    };
    try {
      w.postMessage({ url, ungroupedName: o.ungroupedName, stallMs: o.stallMs || 60000 });
    } catch (e) {
      end(() => reject(new WorkerUnavailable('postMessage failed')));
    }
  });
}

function onMainThread(url: string, o: LoadOptions): Promise<M3uCatalog> {
  const fetchText = o.fetchText || ((u: string) => getText(u, 90000).promise);
  return fetchText(url).then((text) => {
    return new Promise<M3uCatalog>((resolve, reject) => {
      const builder = new M3uCatalogBuilder(o.ungroupedName);
      const parser = new M3uParser((e) => builder.add(e));
      const total = text.length;
      const slice = o.sliceChars || 256 * 1024;
      let pos = 0;
      const step = (): void => {
        try {
          if (pos < total) {
            parser.push(text.slice(pos, pos + slice));
            pos += slice;
            if (o.onProgress) o.onProgress({ bytes: Math.min(pos, total), total, entries: parser.count });
            setTimeout(step, 0);
            return;
          }
          parser.finish();
          resolve(builder.finish(parser.epgUrl));
        } catch (e) {
          reject(e);
        }
      };
      step();
    });
  });
}

// Web Worker entry: downloads and parses an M3U playlist off the main thread.
// The response is streamed (fetch) and fed to the incremental parser chunk by
// chunk, so the raw text is never held in memory; XHR is the fallback when the
// engine has no streaming body. Bundled separately by scripts/build.mjs.
import { M3uCatalogBuilder, M3uParser } from './m3u';
import { EPISODE_CHUNK, ITEM_CHUNK, type WorkerMessage, type WorkerRequest } from './m3u-protocol';
import type { Episode } from './models';

interface Ctx {
  postMessage(m: WorkerMessage): void;
  onmessage: ((e: { data: WorkerRequest }) => void) | null;
}
const ctx = self as unknown as Ctx;

function post(m: WorkerMessage): void {
  ctx.postMessage(m);
}

class Failure extends Error {
  constructor(message: string, public status: number) {
    super(message);
  }
}

function run(req: WorkerRequest): void {
  const builder = new M3uCatalogBuilder(req.ungroupedName);
  const parser = new M3uParser((e) => builder.add(e));
  let bytes = 0;
  let total = 0;
  let lastPost = 0;
  const progress = (force: boolean): void => {
    const now = Date.now();
    if (!force && now - lastPost < 150) return;
    lastPost = now;
    post({ t: 'progress', bytes, total, entries: parser.count });
  };
  const finish = (): void => {
    parser.finish();
    progress(true);
    const cat = builder.finish(parser.epgUrl);
    post({ t: 'meta', epgUrl: cat.epgUrl, live: cat.live.categories, movies: cat.movies.categories, series: cat.series.categories });
    for (let i = 0; i < cat.live.items.length; i += ITEM_CHUNK) post({ t: 'live', items: cat.live.items.slice(i, i + ITEM_CHUNK) });
    for (let i = 0; i < cat.movies.items.length; i += ITEM_CHUNK) post({ t: 'movies', items: cat.movies.items.slice(i, i + ITEM_CHUNK) });
    for (let i = 0; i < cat.series.items.length; i += ITEM_CHUNK) post({ t: 'series', items: cat.series.items.slice(i, i + ITEM_CHUNK) });
    const ids = Object.keys(cat.episodes);
    for (let i = 0; i < ids.length; i += EPISODE_CHUNK) {
      const data: Record<string, Episode[]> = {};
      for (const id of ids.slice(i, i + EPISODE_CHUNK)) data[id] = cat.episodes[id];
      post({ t: 'episodes', data });
    }
    post({ t: 'done' });
  };
  const fail = (e: unknown): void => {
    const f = e as Failure;
    post({ t: 'error', message: (f && f.message) || 'network', status: f && typeof f.status === 'number' ? f.status : 0 });
  };

  if (typeof fetch === 'function' && typeof TextDecoder === 'function') {
    streamFetch(req, parser, (n, t) => {
      bytes += n;
      if (t) total = t;
      progress(false);
    }).then(finish, fail);
  } else {
    viaXhr(req, parser, (n, t) => {
      bytes = n;
      if (t) total = t;
      progress(false);
    }).then(finish, fail);
  }
}

function streamFetch(req: WorkerRequest, parser: M3uParser, onBytes: (n: number, total: number) => void): Promise<void> {
  return new Promise<void>((resolve, reject) => {
    let stall = 0;
    const arm = (): void => {
      clearTimeout(stall);
      stall = setTimeout(() => reject(new Failure('timeout', 0)), req.stallMs) as unknown as number;
    };
    arm();
    fetch(req.url).then((resp) => {
      if (!resp.ok) throw new Failure('HTTP ' + resp.status, resp.status);
      const len = parseInt(resp.headers.get('content-length') || '0', 10) || 0;
      const body = resp.body as ReadableStream<Uint8Array> | null;
      if (!body || typeof body.getReader !== 'function') {
        // No streaming body: one text() call (still off the main thread).
        return resp.text().then((text) => {
          parser.push(text);
          onBytes(text.length, 0);
        });
      }
      const reader = body.getReader();
      const dec = new TextDecoder('utf-8');
      const pump = (): Promise<void> =>
        reader.read().then((r) => {
          arm();
          if (r.done) {
            parser.push(dec.decode());
            return;
          }
          const v = r.value as Uint8Array;
          parser.push(dec.decode(v, { stream: true }));
          onBytes(v.length, len);
          return pump();
        });
      return pump();
    }).then(() => {
      clearTimeout(stall);
      resolve();
    }, (e) => {
      clearTimeout(stall);
      reject(e && (e as Failure).status != null ? e : new Failure('network', 0));
    });
  });
}

function viaXhr(req: WorkerRequest, parser: M3uParser, onBytes: (n: number, total: number) => void): Promise<void> {
  return new Promise<void>((resolve, reject) => {
    const xhr = new XMLHttpRequest();
    let fed = 0;
    const feed = (): void => {
      const text = xhr.responseText;
      if (text.length > fed) {
        parser.push(text.slice(fed));
        fed = text.length;
      }
    };
    xhr.open('GET', req.url, true);
    xhr.timeout = 10 * req.stallMs;
    xhr.onprogress = (e) => {
      feed();
      onBytes(fed, e.lengthComputable ? e.total : 0);
    };
    xhr.onload = () => {
      if (xhr.status < 200 || xhr.status >= 300) return reject(new Failure('HTTP ' + xhr.status, xhr.status));
      feed();
      resolve();
    };
    xhr.onerror = () => reject(new Failure('network', 0));
    xhr.ontimeout = () => reject(new Failure('timeout', 0));
    xhr.send();
  });
}

ctx.onmessage = (e) => run(e.data);

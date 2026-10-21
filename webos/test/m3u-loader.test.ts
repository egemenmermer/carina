// Tests for the incremental M3U parser and the worker-with-fallback loader.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { M3uParser, parseM3u, type M3uEntry } from '../src/data/m3u';
import { loadM3uCatalog, type M3uProgress, type WorkerLike } from '../src/data/m3u-loader';
import type { WorkerMessage } from '../src/data/m3u-protocol';

function sample(n: number): string {
  let s = '﻿#EXTM3U url-tvg="http://epg/x.xml"\r\n';
  for (let i = 0; i < n; i++) {
    s += `#EXTINF:-1 tvg-id="c${i}" tvg-logo="http://l/${i}.png" group-title="G${i % 3}",Channel ${i}\r\nhttp://s/live/${i}.ts\r\n`;
  }
  s += '#EXTINF:5400 group-title="Movies",Film (2020)\nhttp://s/movie/u/p/1.mp4\n';
  s += '#EXTINF:2400 group-title="Shows",Show S01E02 - Two\nhttp://s/series/u/p/2.mp4';
  return s;
}

test('chunked parsing equals whole-text parsing for any chunk size', () => {
  const text = sample(40);
  const whole = parseM3u(text);
  for (const size of [1, 7, 64, 1000, text.length]) {
    const got: M3uEntry[] = [];
    const p = new M3uParser((e) => got.push(e));
    for (let i = 0; i < text.length; i += size) p.push(text.slice(i, i + size));
    p.finish();
    assert.deepEqual(got, whole.entries, 'chunk size ' + size);
    assert.equal(p.epgUrl, 'http://epg/x.xml');
    assert.equal(p.count, 42);
  }
});

class FakeWorker implements WorkerLike {
  onmessage: WorkerLike['onmessage'] = null;
  onerror: WorkerLike['onerror'] = null;
  terminated = false;
  constructor(private script: (w: FakeWorker) => void) {}
  postMessage(): void {
    setTimeout(() => this.script(this), 0);
  }
  terminate(): void {
    this.terminated = true;
  }
  send(m: WorkerMessage): void {
    if (this.onmessage) this.onmessage({ data: m });
  }
}

const mainText = '#EXTM3U\n#EXTINF:-1 group-title="G",One\nhttp://s/1.ts\n#EXTINF:-1 group-title="G",Two\nhttp://s/2.ts\n';

test('falls back to the main thread when Worker creation throws', async () => {
  const progress: M3uProgress[] = [];
  const cat = await loadM3uCatalog('http://x/p.m3u', {
    ungroupedName: 'Other',
    createWorker: () => {
      throw new Error('SecurityError');
    },
    fetchText: () => Promise.resolve(mainText),
    sliceChars: 16,
    onProgress: (p) => progress.push(p),
  });
  assert.equal(cat.live.items.length, 2);
  assert.equal(cat.live.items[1].id, 'l:http://s/2.ts');
  assert.ok(progress.length > 1);
  assert.equal(progress[progress.length - 1].bytes, mainText.length);
});

test('falls back when the worker script fails to start', async () => {
  const w = new FakeWorker((fw) => fw.onerror && fw.onerror({}));
  const cat = await loadM3uCatalog('http://x/p.m3u', {
    ungroupedName: 'Other',
    createWorker: () => w,
    fetchText: () => Promise.resolve(mainText),
  });
  assert.equal(cat.live.items.length, 2);
  assert.ok(w.terminated);
});

test('assembles the catalogue from worker messages and reports progress', async () => {
  const w = new FakeWorker((fw) => {
    fw.send({ t: 'progress', bytes: 10, total: 100, entries: 1 });
    fw.send({ t: 'meta', epgUrl: 'http://e', live: [{ id: 'g:A', name: 'A' }], movies: [], series: [] });
    const ch = (n: number) => ({ id: 'l:' + n, name: 'c' + n, num: n, logo: null, epgId: null, categoryId: 'g:A', url: 'u' + n });
    fw.send({ t: 'live', items: [ch(1), ch(2)] });
    fw.send({ t: 'live', items: [ch(3)] });
    fw.send({ t: 'done' });
  });
  const seen: M3uProgress[] = [];
  const cat = await loadM3uCatalog('http://x/p.m3u', {
    ungroupedName: 'Other',
    createWorker: () => w,
    fetchText: () => Promise.reject(new Error('must not be used')),
    onProgress: (p) => seen.push(p),
  });
  assert.deepEqual(cat.live.items.map((c) => c.num), [1, 2, 3]);
  assert.equal(cat.epgUrl, 'http://e');
  assert.deepEqual(seen, [{ bytes: 10, total: 100, entries: 1 }]);
  assert.ok(w.terminated);
});

test('HTTP errors from the worker are final, network errors retry on the main thread', async () => {
  const http = new FakeWorker((fw) => fw.send({ t: 'error', message: 'HTTP 401', status: 401 }));
  await assert.rejects(
    loadM3uCatalog('http://x', { ungroupedName: 'O', createWorker: () => http, fetchText: () => Promise.resolve(mainText) }),
    (e: Error & { status?: number }) => e.status === 401,
  );
  const net = new FakeWorker((fw) => fw.send({ t: 'error', message: 'network', status: 0 }));
  const cat = await loadM3uCatalog('http://x', { ungroupedName: 'O', createWorker: () => net, fetchText: () => Promise.resolve(mainText) });
  assert.equal(cat.live.items.length, 2);
});

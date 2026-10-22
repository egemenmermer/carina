import { test } from 'node:test';
import assert from 'node:assert/strict';
import { Lru } from '../src/data/lru';
import { BLANK, ImageGate, type ImgLike } from '../src/ui/imgload';

test('LRU evicts the least recently used entry and get() refreshes', () => {
  const c = new Lru<number>(3);
  c.set('a', 1);
  c.set('b', 2);
  c.set('c', 3);
  assert.equal(c.get('a'), 1); // a is now the most recent
  c.set('d', 4); // evicts b
  assert.equal(c.has('b'), false);
  assert.equal(c.has('a'), true);
  assert.equal(c.size, 3);
  c.set('a', 10); // overwrite does not grow
  assert.equal(c.size, 3);
  assert.equal(c.peek('a'), 10);
  c.deleteWhere((k) => k !== 'a');
  assert.equal(c.size, 1);
});

function fakeImg(): ImgLike {
  return { src: '', onload: null, onerror: null };
}

test('image gate caps concurrent loads and serves newest first', () => {
  const g = new ImageGate(2);
  const els = [0, 1, 2, 3, 4].map(fakeImg);
  els.forEach((e, i) => g.request(e, 'u' + i));
  assert.equal(g.loading, 2);
  assert.equal(g.pending, 3);
  assert.deepEqual(els.map((e) => e.src), ['u0', 'u1', '', '', '']);
  (els[0].onload as () => void)(); // slot frees: the newest queued (4) goes next
  assert.equal(els[4].src, 'u4');
  assert.equal(g.loading, 2);
  (els[1].onerror as () => void)(); // errors free slots too
  assert.equal(els[3].src, 'u3');
  assert.equal(g.pending, 1);
});

test('releasing cancels queued images and clears running ones', () => {
  const g = new ImageGate(1);
  const a = fakeImg();
  const b = fakeImg();
  g.request(a, 'ua');
  g.request(b, 'ub');
  g.release(b); // still queued: never loads
  assert.equal(g.pending, 0);
  assert.equal(b.src, '');
  g.release(a); // running: source cleared, slot returned
  assert.equal(a.src, BLANK);
  assert.equal(g.loading, 0);
  const c = fakeImg();
  g.request(c, 'uc');
  (c.onload as () => void)();
  g.release(c); // already loaded and off-screen: bitmap released
  assert.equal(c.src, BLANK);
  assert.equal(c.onload, null);
});

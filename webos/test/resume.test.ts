import { test } from 'node:test';
import assert from 'node:assert/strict';
import { isNearEnd, ResumeStore, resumeKey, type StorageLike } from '../src/resume';

class MemStorage implements StorageLike {
  data: Record<string, string> = {};
  getItem(k: string): string | null {
    return k in this.data ? this.data[k] : null;
  }
  setItem(k: string, v: string): void {
    this.data[k] = v;
  }
  removeItem(k: string): void {
    delete this.data[k];
  }
}

test('saves and returns a resume position; ignores the first seconds', () => {
  const r = new ResumeStore(new MemStorage());
  r.save('p|1', 5, 7200);
  assert.equal(r.resumeAt('p|1'), null);
  r.save('p|1', 1234.7, 7200);
  assert.equal(r.resumeAt('p|1'), 1234);
  r.save('p|1', 3, 7200); // re-opened and left quickly: keep the earlier position
  assert.equal(r.resumeAt('p|1'), 1234);
  r.clear('p|1');
  assert.equal(r.resumeAt('p|1'), null);
});

test('near the end marks watched and drops the position', () => {
  assert.equal(isNearEnd(7100, 7200), true);
  assert.equal(isNearEnd(6000, 7200), false);
  assert.equal(isNearEnd(100, 100), false); // too short to judge
  const r = new ResumeStore(new MemStorage());
  r.save('p|m', 3000, 3100);
  assert.equal(r.isWatched('p|m'), true);
  assert.equal(r.resumeAt('p|m'), null);
  r.save('p|m', 600, 3100); // watching again from the middle
  assert.equal(r.isWatched('p|m'), false);
  assert.equal(r.resumeAt('p|m'), 600);
  r.markWatched('p|m');
  assert.equal(r.isWatched('p|m'), true);
});

test('LRU cap evicts the least recently saved entries', () => {
  const st = new MemStorage();
  const r = new ResumeStore(st, 3);
  for (const k of ['a', 'b', 'c']) r.save(k, 100, 5000);
  r.save('a', 200, 5000); // touch a: b is now the oldest
  r.save('d', 100, 5000);
  assert.equal(r.size(), 3);
  assert.equal(r.resumeAt('b'), null);
  assert.equal(r.resumeAt('a'), 200);
  assert.equal(r.resumeAt('d'), 100);
  // persisted and reloadable, still capped
  const again = new ResumeStore(st, 2);
  assert.equal(again.size(), 2);
  assert.equal(again.resumeAt('d'), 100);
});

test('survives corrupt storage and removes a playlist', () => {
  const st = new MemStorage();
  st.data['carina.resume'] = '{not json';
  const r = new ResumeStore(st);
  assert.equal(r.size(), 0);
  r.save('p1|x', 100, 5000);
  r.save('p2|x', 100, 5000);
  r.removePlaylist('p1');
  assert.equal(r.resumeAt('p1|x'), null);
  assert.equal(r.resumeAt('p2|x'), 100);
  assert.doesNotThrow(() => new ResumeStore(null).save('k', 100, 5000));
});

test('long ids (M3U urls) are hashed to short stable keys', () => {
  const url = 'm:http://example.com/movie/user/pass/' + 'x'.repeat(80) + '.mp4';
  const k = resumeKey('pl', url);
  assert.ok(k.length < 40);
  assert.equal(k, resumeKey('pl', url));
  assert.notEqual(k, resumeKey('pl', url + '1'));
  assert.equal(resumeKey('pl', '123'), 'pl|123');
});

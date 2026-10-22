import { test } from 'node:test';
import assert from 'node:assert/strict';
import { countdownSeconds } from '../src/nextup';

test('countdown appears in the last 10 seconds only', () => {
  assert.equal(countdownSeconds(2000, 2400, true, false), null);
  assert.equal(countdownSeconds(2390, 2400, true, false), 10);
  assert.equal(countdownSeconds(2395.2, 2400, true, false), 5);
  assert.equal(countdownSeconds(2399.9, 2400, true, false), 1);
});

test('no countdown without a next episode, after cancelling, or for short / unknown media', () => {
  assert.equal(countdownSeconds(2395, 2400, false, false), null);
  assert.equal(countdownSeconds(2395, 2400, true, true), null);
  assert.equal(countdownSeconds(50, 60, true, false), null);
  assert.equal(countdownSeconds(2395, NaN, true, false), null);
  assert.equal(countdownSeconds(2395, Infinity, true, false), null);
});

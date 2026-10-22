// Unit tests for the pure data layer (run with `npm test`).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { asId, asInt, decodeMaybeBase64, parseJsonLenient } from '../src/data/json';
import { buildM3uCatalog, parseM3u, parseSeriesMarker } from '../src/data/m3u';
import { parseXmltv, parseXmltvTime } from '../src/data/xmltv';
import {
  liveFormats, normalizeServer, parseCategories, parseChannels, parseMovies, parseSeriesInfo, parseShortEpg, XtreamUrls,
} from '../src/data/xtream';

test('lenient json helpers', () => {
  assert.equal(asInt('12'), 12);
  assert.equal(asInt('7.9'), 7);
  assert.equal(asInt(''), null);
  assert.equal(asId(1001.0), '1001');
  assert.equal(asId(' 42 '), '42');
  assert.deepEqual(parseJsonLenient('﻿Warning: x\n[1,2]'), [1, 2]);
});

test('base64 EPG titles decode as UTF-8 (Turkish)', () => {
  const b64 = Buffer.from('Haber Bülteni – Gündem', 'utf8').toString('base64');
  assert.equal(decodeMaybeBase64(b64), 'Haber Bülteni – Gündem');
  assert.equal(decodeMaybeBase64('News'), 'News'); // length 4 but decodes to junk
  assert.equal(decodeMaybeBase64('Evening News'), 'Evening News');
});

test('xtream urls and server normalisation', () => {
  assert.equal(normalizeServer(' example.com:8080/// '), 'http://example.com:8080');
  const u = new XtreamUrls('http://h:1/', 'u s', 'p/w');
  assert.equal(u.live('5', 'm3u8'), 'http://h:1/live/u%20s/p%2Fw/5.m3u8');
  assert.equal(u.movie('9', '.mkv'), 'http://h:1/movie/u%20s/p%2Fw/9.mkv');
  assert.equal(u.episode('3', null), 'http://h:1/series/u%20s/p%2Fw/3.mp4');
  assert.equal(u.api({ action: 'get_live_streams', category_id: '1' }), 'http://h:1/player_api.php?username=u%20s&password=p%2Fw&action=get_live_streams&category_id=1');
  assert.deepEqual(liveFormats(['ts', 'm3u8']), ['m3u8', 'ts']);
  assert.deepEqual(liveFormats(['ts', 'rtmp']), ['ts']);
  assert.deepEqual(liveFormats([]), ['m3u8', 'ts']);
});

test('xtream lists tolerate PHP quirks', () => {
  assert.deepEqual(parseCategories([{ category_id: 3, category_name: 'News' }, { category_name: 'x' }]), [{ id: '3', name: 'News' }]);
  const ch = parseChannels([{ stream_id: '10', name: 'TRT 1', num: '1', stream_icon: '', epg_channel_id: null, category_id: 3 }]);
  assert.equal(ch.length, 1);
  assert.equal(ch[0].num, 1);
  assert.equal(ch[0].logo, null);
  assert.equal(ch[0].categoryId, '3');
  const mv = parseMovies([{ stream_id: 7, name: 'Film (2019)', rating: '7,5', container_extension: 'mkv' }]);
  assert.equal(mv[0].rating, 7.5);
  assert.equal(mv[0].year, '2019');
  assert.equal(mv[0].ext, 'mkv');
});

test('series info: map, nested list and flat list of episodes', () => {
  const ep = (id: number, season: number, n: number) => ({ id: String(id), season, episode_num: n, title: `E${n}`, container_extension: 'mp4' });
  const a = parseSeriesInfo({ info: { plot: 'p' }, episodes: { '2': [ep(3, 2, 1)], '1': [ep(2, 1, 2), ep(1, 1, 1)] } });
  assert.deepEqual(a.seasons, [1, 2]);
  assert.deepEqual(a.episodes.map((e) => e.id), ['1', '2', '3']);
  const b = parseSeriesInfo({ episodes: [[ep(1, 1, 1)], [ep(2, 2, 1)]] });
  assert.deepEqual(b.seasons, [1, 2]);
  const c = parseSeriesInfo({ episodes: [ep(5, 3, 4)] });
  assert.equal(c.episodes[0].season, 3);
});

test('short epg', () => {
  const t = Buffer.from('Akşam Haberleri', 'utf8').toString('base64');
  const list = parseShortEpg({ epg_listings: [{ title: t, start_timestamp: '200', stop_timestamp: '300' }, { title: 'x', start_timestamp: 100, stop_timestamp: 200 }] });
  assert.equal(list.length, 2);
  assert.equal(list[0].start, 100000);
  assert.equal(list[1].title, 'Akşam Haberleri');
});

test('m3u parsing and catalogue', () => {
  const text = [
    '﻿#EXTM3U url-tvg="http://e/epg.xml"',
    '#EXTINF:-1 tvg-id="trt1.tr" tvg-logo="http://l/1.png" group-title="Ulusal",TRT 1, HD',
    'http://s/live/u/p/1.ts',
    '#EXTINF:-1,No Group',
    '#EXTGRP:Music',
    'http://s/2.m3u8',
    '#EXTINF:7200 group-title="Films",Some Film (2020)',
    'http://s/movie/u/p/9.mkv',
    '#EXTINF:-1 group-title="Shows",My Show S01E02 Pilot',
    'http://s/series/u/p/11.mp4',
    '#EXTINF:-1 group-title="Shows",My Show S01 E01',
    'http://s/series/u/p/10.mp4',
    'http://bare/url-without-extinf.ts',
  ].join('\r\n');
  const p = parseM3u(text);
  assert.equal(p.epgUrl, 'http://e/epg.xml');
  assert.equal(p.entries.length, 5);
  assert.equal(p.entries[0].name, 'TRT 1, HD');
  assert.equal(p.entries[0].tvgId, 'trt1.tr');
  assert.equal(p.entries[1].group, 'Music');
  const cat = buildM3uCatalog(p, 'Other');
  assert.deepEqual(cat.live.categories.map((c) => c.name), ['Ulusal', 'Music']);
  assert.equal(cat.movies.items[0].ext, 'mkv');
  assert.equal(cat.series.items.length, 1);
  assert.equal(cat.series.items[0].name, 'My Show');
  const eps = cat.episodes[cat.series.items[0].id];
  assert.deepEqual(eps.map((e) => e.episode), [1, 2]);
  assert.equal(eps[1].title, 'Pilot');
});

test('series markers without lookbehind', () => {
  assert.deepEqual(parseSeriesMarker('Dark - S02E05 - Lost'), { seriesName: 'Dark', season: 2, episode: 5, episodeTitle: 'Lost' });
  assert.equal(parseSeriesMarker('BOSS02E05'), null);
  assert.equal(parseSeriesMarker('Show 1x03')!.episode, 3);
});

test('xmltv window', () => {
  assert.equal(parseXmltvTime('20261022120000 +0300'), Date.UTC(2026, 9, 22, 9, 0, 0));
  const xml = '<tv><programme start="20261022120000 +0000" stop="20261022130000 +0000" channel="A.tr"><title lang="tr">Haber &amp; Spor</title></programme>' +
    '<programme start="20261023120000 +0000" stop="20261023130000 +0000" channel="a.tr"><title>Later</title></programme>' +
    '<programme start="20261022120000 +0000" stop="20261022130000 +0000" channel="b"><title>B</title></programme></tv>';
  const from = Date.UTC(2026, 9, 22, 11);
  const g = parseXmltv(xml, from, from + 6 * 3600000, { 'a.tr': true });
  assert.deepEqual(Object.keys(g), ['a.tr']);
  assert.equal(g['a.tr'].length, 1);
  assert.equal(g['a.tr'][0].title, 'Haber & Spor');
});

test('m3u ids are stable when lines are inserted', () => {
  const a = '#EXTM3U\n#EXTINF:-1 group-title="G",One\nhttp://s/1.ts\n#EXTINF:-1 group-title="G",Two\nhttp://s/2.ts\n';
  const b = '#EXTM3U\n#EXTINF:-1 group-title="G",New\nhttp://s/0.ts\n' + a.slice(8);
  const ida = buildM3uCatalog(parseM3u(a)).live.items.map((c) => c.id);
  const idb = buildM3uCatalog(parseM3u(b)).live.items.map((c) => c.id);
  assert.equal(idb.length, 3);
  assert.deepEqual(idb.slice(1), ida);
});

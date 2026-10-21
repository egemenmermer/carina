// Fullscreen playback on the TV's native pipeline (one shared <video>).
// Live: m3u8 first, .ts fallback, zapping with Up/Down/CH±, info overlay.
// VOD: play/pause, seek, progress.
import { pop, toast, type Screen } from '../app';
import { t } from '../i18n';
import type { Channel, Programme } from '../data/models';
import type { Source } from '../data/source';
import type { Key } from '../platform';
import { countdownSeconds } from '../nextup';
import { resume } from '../resume';
import { store } from '../store';
import { fmtDuration, fmtTime, h, img, initials, setText, toggle } from '../ui/dom';
import { Buttons } from '../ui/zone';
import { nowNext } from './browse';

export type PlayerArgs =
  | {
      kind: 'live';
      channels: Channel[];
      index: number;
      categoryId: string;
      epg: Record<string, Programme[]>;
      onExit?: (index: number) => void;
    }
  | { kind: 'vod'; item: VodItem; startAt?: number; queue?: VodItem[]; queueIndex?: number };

/** One playable movie or episode; [key] is its resume key. */
export interface VodItem {
  title: string;
  url: string;
  key: string;
}

const START_TIMEOUT = 15000; // dead live streams often never fire "error"
const STALL_TIMEOUT = 30000;
const OSD_MS = 5000;
const ZAP_DELAY = 500;
const SAVE_EVERY_MS = 10000;

function mimeFor(url: string): string {
  const path = url.split('?')[0].toLowerCase();
  if (/\.m3u8$/.test(path)) return 'application/vnd.apple.mpegurl';
  if (/\.ts$/.test(path)) return 'video/mp2t';
  return '';
}

export class PlayerScreen implements Screen {
  el: HTMLElement;
  private video = document.getElementById('video') as HTMLVideoElement;
  private osd: HTMLElement;
  private spinner = h('div', { class: 'spinner big' });
  private errorBox: HTMLElement;
  private errorButtons: Buttons;
  private candidates: { url: string; type: string }[] = [];
  private cand = 0;
  private started = false;
  private failed = false;
  private startTimer = 0;
  private stallTimer = 0;
  private osdTimer = 0;
  private tickTimer = 0;
  private zapTimer = 0;
  private seekTimer = 0;
  private seekTarget: number | null = null;
  private seekStep = 10;
  private lastSeekAt = 0;
  private index = 0;
  private playingIndex = -1;
  private attempt = 0;
  private handled = -1;
  // OSD parts
  private oNum = h('span', { class: 'osd-num' });
  private oLogo = h('span', { class: 'logo' });
  private oName = h('span', { class: 'osd-name' });
  private oClock = h('span', { class: 'osd-clock' });
  private oNow = h('div', { class: 'osd-now' });
  private oTimes = h('div', { class: 'osd-times' });
  private oBar = h('i');
  private oNext = h('div', { class: 'osd-next' });
  private oState = h('span', { class: 'osd-state' });
  private listeners: [string, EventListener][] = [];
  // VOD: resume + next-episode autoplay
  private cur: VodItem | null = null;
  private qi = 0;
  private pendingStart = 0;
  private lastSave = 0;
  private nextCancelled = false;
  private nextShown = false;
  private nextTitle = h('div', { class: 'next-title' });
  private nextCount = h('div', { class: 'next-count' });
  private nextBox = h('div', { class: 'next-up' }, h('div', { class: 'next-head', text: t('nextEpisode') }), this.nextTitle, this.nextCount, h('div', { class: 'hint', text: t('hintNextUp') }));

  constructor(private source: Source, private args: PlayerArgs) {
    this.errorButtons = new Buttons([
      { label: t('retry'), cls: 'primary', action: () => this.retry() },
      { label: t('back'), action: () => pop() },
    ]);
    this.errorButtons.setActive(true);
    this.errorBox = h('div', { class: 'player-error' }, h('h2', { text: t('playbackFailed') }), h('p', { text: t('playbackFailedHint') }), this.errorButtons.el);
    const live = args.kind === 'live';
    this.osd = h(
      'div',
      { class: 'osd' },
      h('div', { class: 'osd-top' }, live ? this.oNum : null, live ? this.oLogo : null, this.oName, this.oClock),
      h(
        'div',
        { class: 'osd-bottom' },
        h('div', { class: 'osd-line' }, this.oState, this.oNow, this.oTimes),
        h('div', { class: 'bar osd-bar' }, this.oBar),
        live ? this.oNext : null,
        h('div', { class: 'hint', text: live ? t('hintPlayerLive') : t('hintPlayerVod') }),
      ),
    );
    this.el = h('div', { class: 'screen player' }, this.osd, this.nextBox, this.spinner, this.errorBox);
    this.el.addEventListener('mousemove', () => this.showOsd());
    this.el.addEventListener('click', (e) => {
      if (!this.errorBox.contains(e.target as Node)) this.onKey('ok');
    });
  }

  onShow(): void {
    document.body.classList.add('playing');
    this.on('playing', () => this.onPlaying());
    this.on('waiting', () => this.onWaiting());
    this.on('error', () => this.onError());
    this.on('ended', () => this.onEnded());
    this.on('loadedmetadata', () => this.applyStart());
    this.on('timeupdate', () => this.onTimeUpdate());
    this.on('pause', () => {
      this.paintState();
      this.saveProgress();
    });
    this.on('play', () => this.paintState());
    if (this.args.kind === 'live') {
      this.index = this.args.index;
      this.paintLive();
      this.startLive();
    } else {
      this.cur = this.args.item;
      this.qi = this.args.queueIndex || 0;
      this.pendingStart = this.args.startAt || 0;
      setText(this.oName, this.cur.title);
      this.load([this.cur.url]);
    }
    this.showOsd();
  }

  onDestroy(): void {
    for (const [ev, fn] of this.listeners) this.video.removeEventListener(ev, fn);
    this.listeners = [];
    for (const tm of [this.startTimer, this.stallTimer, this.osdTimer, this.tickTimer, this.zapTimer, this.seekTimer]) clearTimeout(tm);
    clearInterval(this.tickTimer);
    this.saveProgress();
    this.release();
    document.body.classList.remove('playing');
    if (this.args.kind === 'live' && this.args.onExit) this.args.onExit(this.index);
  }

  private on(ev: string, fn: () => void): void {
    this.video.addEventListener(ev, fn);
    this.listeners.push([ev, fn]);
  }

  /** Frees the decoder: matters on 1.5 GB TVs. */
  private release(): void {
    const v = this.video;
    try {
      v.pause();
    } catch (e) {
      /* ignore */
    }
    while (v.firstChild) v.removeChild(v.firstChild);
    v.removeAttribute('src');
    try {
      v.load();
    } catch (e) {
      /* ignore */
    }
  }

  // ---- loading & failure -------------------------------------------------------

  private load(urls: string[]): void {
    const c = urls.filter(Boolean).map((url) => ({ url, type: mimeFor(url) }));
    // Hedge: if the TV reports '' for the declared type it skips the source
    // instantly; retry the last URL once without a type.
    const last = c[c.length - 1];
    if (last && last.type) c.push({ url: last.url, type: '' });
    this.candidates = c;
    this.cand = 0;
    this.failed = false;
    toggle(this.errorBox, 'show', false);
    this.tryCurrent();
  }

  private tryCurrent(): void {
    const cand = this.candidates[this.cand];
    this.release();
    clearTimeout(this.startTimer);
    clearTimeout(this.stallTimer);
    this.started = false;
    if (!cand) {
      this.fail();
      return;
    }
    toggle(this.spinner, 'show', true);
    const s = document.createElement('source');
    s.src = cand.url;
    if (cand.type) s.type = cand.type;
    const attempt = ++this.attempt;
    s.addEventListener('error', () => attempt === this.attempt && this.onError());
    this.video.appendChild(s);
    this.video.load();
    const p = this.video.play() as Promise<void> | undefined;
    if (p && typeof p.then === 'function') p.then(undefined, () => undefined);
    this.startTimer = window.setTimeout(() => {
      this.handled = this.attempt;
      this.next();
    }, START_TIMEOUT);
  }

  private next(): void {
    if (this.failed) return;
    if (this.cand < this.candidates.length - 1) {
      this.cand++;
      this.tryCurrent();
    } else this.fail();
  }

  private fail(): void {
    this.failed = true;
    clearTimeout(this.startTimer);
    clearTimeout(this.stallTimer);
    this.release();
    toggle(this.spinner, 'show', false);
    toggle(this.errorBox, 'show', true);
    this.errorButtons.focus(0);
    this.showOsd(true);
  }

  private retry(): void {
    this.cand = 0;
    this.failed = false;
    toggle(this.errorBox, 'show', false);
    this.tryCurrent();
  }

  private onPlaying(): void {
    this.started = true;
    clearTimeout(this.startTimer);
    clearTimeout(this.stallTimer);
    toggle(this.spinner, 'show', false);
    this.paintState();
  }

  private onWaiting(): void {
    if (this.failed) return;
    toggle(this.spinner, 'show', true);
    if (this.started) {
      clearTimeout(this.stallTimer);
      this.stallTimer = window.setTimeout(() => this.fail(), STALL_TIMEOUT);
    }
  }

  private onError(): void {
    // <source> and <video> may both report the same failure.
    if (this.failed || this.handled === this.attempt) return;
    this.handled = this.attempt;
    if (this.started && this.args.kind === 'live') {
      // A running live stream broke: reconnect once from the same URL list.
      this.started = false;
      this.cand = 0;
      this.tryCurrent();
      return;
    }
    clearTimeout(this.startTimer);
    this.next();
  }

  private onEnded(): void {
    if (this.args.kind === 'live') {
      this.onError();
      return;
    }
    if (this.cur) resume.markWatched(this.cur.key, isFinite(this.video.duration) ? this.video.duration : 0);
    if (this.nextItem() && !this.nextCancelled) this.playNext();
    else pop();
  }

  // ---- live ---------------------------------------------------------------------

  private channel(): Channel {
    const a = this.args as Extract<PlayerArgs, { kind: 'live' }>;
    return a.channels[this.index];
  }

  private startLive(): void {
    const a = this.args as Extract<PlayerArgs, { kind: 'live' }>;
    const c = this.channel();
    if (this.playingIndex === this.index && !this.failed) return;
    this.playingIndex = this.index;
    store.saveLastChannel(this.source.playlist.id, a.categoryId, c.id);
    this.load(this.source.liveUrls(c));
    if (!a.epg[c.id]) {
      this.source.epg(c).then((p) => {
        a.epg[c.id] = p;
        if (this.channel() === c) this.paintLive();
      });
    }
  }

  private zap(delta: number): void {
    const a = this.args as Extract<PlayerArgs, { kind: 'live' }>;
    const n = a.channels.length;
    if (n < 2) return;
    this.index = (this.index + delta + n) % n;
    this.paintLive();
    this.showOsd();
    clearTimeout(this.zapTimer);
    this.zapTimer = window.setTimeout(() => this.startLive(), ZAP_DELAY);
  }

  private paintLive(): void {
    const a = this.args as Extract<PlayerArgs, { kind: 'live' }>;
    const c = this.channel();
    setText(this.oNum, c.num != null ? String(c.num) : '');
    this.oLogo.innerHTML = '';
    this.oLogo.appendChild(h('b', { text: initials(c.name) }));
    this.oLogo.appendChild(img(c.logo, 'logo-img'));
    setText(this.oName, c.name + (store.isFavourite(this.source.playlist.id, c.id) ? '  ★' : ''));
    const [now, next] = nowNext(a.epg[c.id]);
    setText(this.oNow, now ? now.title : t('noProgramme'));
    setText(this.oTimes, now ? fmtTime(now.start) + ' – ' + fmtTime(now.stop) : '');
    const p = now ? Math.max(0, Math.min(1, (Date.now() - now.start) / (now.stop - now.start))) : 0;
    this.oBar.style.width = Math.round(p * 100) + '%';
    setText(this.oNext, next ? t('next') + ':  ' + fmtTime(next.start) + '  ' + next.title : '');
    setText(this.oClock, fmtTime(Date.now()));
  }

  // ---- vod ----------------------------------------------------------------------

  /** Jumps to the saved position once the media is known. */
  private applyStart(): void {
    if (this.pendingStart <= 0) return;
    const v = this.video;
    const d = isFinite(v.duration) ? v.duration : 0;
    const at = d ? Math.min(this.pendingStart, Math.max(0, d - 5)) : this.pendingStart;
    this.pendingStart = 0;
    try {
      v.currentTime = at;
    } catch (e) {
      /* not seekable yet: start from the beginning */
    }
  }

  private onTimeUpdate(): void {
    if (this.args.kind !== 'vod') return;
    if (this.osd.classList.contains('show')) this.paintVod();
    if (!this.started || this.video.seeking) return;
    const now = Date.now();
    if (now - this.lastSave >= SAVE_EVERY_MS) this.saveProgress();
    this.checkNext();
  }

  private saveProgress(): void {
    if (!this.cur || !this.started || this.pendingStart > 0) return;
    const v = this.video;
    this.lastSave = Date.now();
    resume.save(this.cur.key, v.currentTime, isFinite(v.duration) ? v.duration : 0);
  }

  private nextItem(): VodItem | null {
    const a = this.args;
    return a.kind === 'vod' && a.queue ? a.queue[this.qi + 1] || null : null;
  }

  /** Shows the cancellable countdown during the last seconds of an episode. */
  private checkNext(): void {
    const next = this.nextItem();
    const v = this.video;
    const pos = this.seekTarget != null ? this.seekTarget : v.currentTime;
    const n = countdownSeconds(pos, v.duration, !!next, this.nextCancelled);
    if (n == null || !next) {
      if (this.nextShown) this.hideNext();
      return;
    }
    if (!this.nextShown) {
      this.nextShown = true;
      setText(this.nextTitle, next.title);
      toggle(this.nextBox, 'show', true);
    }
    setText(this.nextCount, t('nextIn', { n }));
  }

  private hideNext(): void {
    this.nextShown = false;
    toggle(this.nextBox, 'show', false);
  }

  private playNext(): void {
    const next = this.nextItem();
    if (!next || this.args.kind !== 'vod') return;
    if (this.cur) resume.markWatched(this.cur.key, isFinite(this.video.duration) ? this.video.duration : 0);
    this.qi++;
    this.cur = next;
    this.pendingStart = 0;
    this.started = false; // the old media's last 'pause' must not be saved under the new key
    this.nextCancelled = false;
    this.hideNext();
    setText(this.oName, next.title);
    this.load([next.url]);
    this.showOsd();
  }

  private paintVod(): void {
    const v = this.video;
    const d = isFinite(v.duration) ? v.duration : 0;
    const cur = this.seekTarget != null ? this.seekTarget : v.currentTime;
    setText(this.oNow, '');
    setText(this.oTimes, fmtDuration(cur) + (d ? ' / ' + fmtDuration(d) : ''));
    this.oBar.style.width = d ? Math.round((cur / d) * 1000) / 10 + '%' : '0%';
    setText(this.oClock, fmtTime(Date.now()));
  }

  private paintState(): void {
    setText(this.oState, this.args.kind === 'vod' && this.video.paused && this.started ? '❚❚' : '');
  }

  private seek(delta: number): void {
    const v = this.video;
    const now = Date.now();
    // Holding the key speeds up: 10 s → 30 s → 60 s steps.
    this.seekStep = now - this.lastSeekAt < 500 ? Math.min(60, this.seekStep + 10) : 10;
    this.lastSeekAt = now;
    const d = isFinite(v.duration) ? v.duration : 0;
    const base = this.seekTarget != null ? this.seekTarget : v.currentTime;
    let target = base + delta * this.seekStep;
    target = Math.max(0, d ? Math.min(d - 1, target) : target);
    this.seekTarget = target;
    this.paintVod();
    this.showOsd();
    clearTimeout(this.seekTimer);
    this.seekTimer = window.setTimeout(() => {
      if (this.seekTarget != null) v.currentTime = this.seekTarget;
      this.seekTarget = null;
    }, 600);
  }

  private togglePause(force?: 'play' | 'pause'): void {
    const v = this.video;
    const play = force ? force === 'play' : v.paused;
    if (play) {
      const p = v.play() as Promise<void> | undefined;
      if (p && typeof p.then === 'function') p.then(undefined, () => undefined);
    } else v.pause();
    this.showOsd();
  }

  // ---- OSD & keys -----------------------------------------------------------------

  private showOsd(sticky = false): void {
    toggle(this.osd, 'show', true);
    if (this.args.kind === 'vod') this.paintVod();
    else this.paintLive();
    clearTimeout(this.osdTimer);
    clearInterval(this.tickTimer);
    this.tickTimer = window.setInterval(() => (this.args.kind === 'vod' ? this.paintVod() : this.paintLive()), 1000);
    if (!sticky)
      this.osdTimer = window.setTimeout(() => {
        if (this.args.kind === 'vod' && this.video.paused) return;
        toggle(this.osd, 'show', false);
        clearInterval(this.tickTimer);
      }, OSD_MS);
  }

  private hideOsd(): void {
    clearTimeout(this.osdTimer);
    clearInterval(this.tickTimer);
    toggle(this.osd, 'show', false);
  }

  onKey(k: Key): boolean {
    const live = this.args.kind === 'live';
    if (this.nextShown) {
      // Countdown overlay: OK plays the next episode now, Back only cancels the countdown.
      if (k === 'ok' || k === 'play') return this.playNext(), true;
      if (k === 'back') {
        this.nextCancelled = true;
        this.hideNext();
        return true;
      }
    }
    if (k === 'back' || k === 'stop') {
      pop();
      return true;
    }
    if (live && (k === 'up' || k === 'chUp')) return this.zap(1), true;
    if (live && (k === 'down' || k === 'chDown')) return this.zap(-1), true;
    if (this.failed) {
      this.errorButtons.onKey(k);
      return true;
    }
    if (live) {
      if (k === 'ok' || k === 'info') {
        if (this.osd.classList.contains('show') && k === 'ok') this.hideOsd();
        else this.showOsd();
      } else if (k === 'red' || k === 'yellow' || k === 'okLong') {
        const added = store.toggleFavourite(this.source.playlist.id, this.channel());
        toast(added ? t('addedToFavourites') : t('removedFromFavourites'));
        this.showOsd();
      } else this.showOsd();
      return true;
    }
    switch (k) {
      case 'ok':
      case 'playPause':
        this.togglePause();
        break;
      case 'play':
        this.togglePause('play');
        break;
      case 'pause':
        this.togglePause('pause');
        break;
      case 'left':
      case 'rew':
        this.seek(-1);
        break;
      case 'right':
      case 'ff':
        this.seek(1);
        break;
      default:
        this.showOsd();
    }
    return true;
  }
}

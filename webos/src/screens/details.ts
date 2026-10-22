// Movie / series details: poster, meta, plot; series add seasons + episodes.
import { confirmDialog, pop, push, type Screen } from '../app';
import { t } from '../i18n';
import type { Episode, Movie, MovieDetails, Series, SeriesDetails } from '../data/models';
import type { Source } from '../data/source';
import type { Key } from '../platform';
import { resume, resumeKey } from '../resume';
import { fmtDuration, h, img, initials, releaseImages } from '../ui/dom';
import { VList } from '../ui/vlist';
import { Buttons } from '../ui/zone';
import { errorDetail, StatusPanel, ZoneScreen } from './common';
import { PlayerScreen, type VodItem } from './player';

export class DetailsScreen extends ZoneScreen implements Screen {
  el: HTMLElement;
  private actions: Buttons;
  private seasons = new Buttons([], false, 'seasons');
  private episodes: VList<Episode>;
  private status = new StatusPanel();
  private metaEl = h('div', { class: 'meta' });
  private plotEl = h('p', { class: 'plot' });
  private backdrop = h('div', { class: 'backdrop' });
  private posterBox: HTMLElement;
  private seriesInfo: SeriesDetails | null = null;
  private movieInfo: MovieDetails | null = null;
  private season = 0;
  private metaBase = '';

  constructor(private source: Source, private kind: 'movie' | 'series', private item: Movie | Series) {
    super();
    this.actions = new Buttons([]);
    this.refreshActions();
    this.episodes = new VList<Episode>({
      cls: 'episodes',
      itemW: 700,
      itemH: 64,
      cols: 1,
      render: (e) =>
        h(
          'div',
          { class: 'ep' },
          h('span', { class: 'ep-num', text: t('episodeShort', { n: e.episode }) }),
          h('span', { class: 'ep-title', text: e.title }),
          h('span', { class: 'ep-dur', text: e.durationSecs ? t('minutes', { n: Math.round(e.durationSecs / 60) }) : '' }),
          h('span', { class: 'ep-seen', text: this.seenMark(e) }),
        ),
      onSelect: (e) => this.playEpisode(e),
    });
    this.episodes.setEmptyText(t('noEpisodes'));
    this.posterBox = h('div', { class: 'poster big' }, h('b', { text: initials(item.name) }), img(item.poster, 'poster-img'));
    const info = h(
      'div',
      { class: 'details-info' },
      h('h1', { text: item.name }),
      this.metaEl,
      this.plotEl,
      this.actions.el,
      kind === 'series' ? h('div', { class: 'series-box' }, this.seasons.el, this.episodes.el) : null,
      this.status.el,
    );
    this.el = h('div', { class: 'screen details' + (kind === 'series' ? ' is-series' : '') }, this.backdrop, h('div', { class: 'details-row' }, this.posterBox, info));
    for (const z of [this.actions, this.seasons, this.episodes, this.status.retry]) this.bindPointer(z);
    this.activate(this.actions);
    this.renderMeta(item.year, item.rating, null, null);
    this.load();
  }

  onShow(): void {
    this.episodes.layout();
    // Back from the player: resume points and watched marks may have changed.
    this.refreshActions();
    this.paintMeta();
    this.episodes.refreshVisible();
  }

  onDestroy(): void {
    releaseImages(this.el);
  }

  private keyOf(id: string): string {
    return resumeKey(this.source.playlist.id, id);
  }

  private seenMark(e: Episode): string {
    const k = this.keyOf(e.id);
    return resume.isWatched(k) ? '✓' : resume.resumeAt(k) != null ? '◐' : '';
  }

  /** Movie buttons: Resume / Start over when a position is saved, else Play. */
  private refreshActions(): void {
    if (this.kind !== 'movie') {
      this.actions.setSpecs([{ label: t('back'), action: () => pop() }]);
      return;
    }
    const at = resume.resumeAt(this.keyOf(this.item.id));
    const specs = at != null
      ? [
          { label: '▶  ' + t('resumeFrom', { time: fmtDuration(at) }), cls: 'primary', action: () => this.playMovie(at) },
          { label: t('startOver'), action: () => this.playMovie(0) },
        ]
      : [{ label: '▶  ' + t('play'), cls: 'primary', action: () => this.playMovie(0) }];
    specs.push({ label: t('back'), cls: '', action: () => pop() });
    this.actions.setSpecs(specs);
  }

  private renderMeta(year: string | null, rating: number | null, secs: number | null, genre: string | null): void {
    const parts: string[] = [];
    if (year) parts.push(year);
    if (rating) parts.push('★ ' + rating.toFixed(1));
    if (secs) parts.push(fmtDuration(secs).replace(/:\d\d$/, '').replace(/^(\d+):(\d\d)$/, '$1h $2m'));
    if (genre) parts.push(genre);
    this.metaBase = parts.join('   ·   ');
    this.paintMeta();
  }

  private paintMeta(): void {
    const seen = this.kind === 'movie' && resume.isWatched(this.keyOf(this.item.id)) ? '✓ ' + t('watched') : '';
    this.metaEl.textContent = this.metaBase + (seen && this.metaBase ? '   ·   ' : '') + seen;
  }

  private setBackdrop(url: string | null): void {
    if (!url) return;
    const i = img(url, 'backdrop-img');
    i.onload = () => i.classList.add('shown');
    this.backdrop.appendChild(i);
  }

  private load(): void {
    this.status.loading();
    const done = () => this.status.hide();
    const fail = (e: unknown) => {
      this.status.error(t('loadFailed', { detail: errorDetail(e) }), () => this.load());
      if (this.kind === 'series') this.activate(this.status.retry);
    };
    if (this.kind === 'movie') {
      this.source.movieDetails(this.item as Movie).then((d) => {
        done();
        this.movieInfo = d;
        this.plotEl.textContent = (d && d.plot) || t('noDetails');
        if (d) {
          this.renderMeta(d.year || this.item.year, d.rating || this.item.rating, d.durationSecs, d.genre);
          this.setBackdrop(d.backdrop);
        }
      }, (e) => {
        // Details are optional for movies: playback still works.
        done();
        this.plotEl.textContent = t('noDetails');
        void e;
      });
      return;
    }
    this.source.seriesDetails(this.item as Series).then((d) => {
      done();
      this.seriesInfo = d;
      this.plotEl.textContent = d.plot || t('noDetails');
      this.renderMeta(d.year || this.item.year, d.rating || this.item.rating, null, d.genre);
      this.setBackdrop(d.backdrop);
      this.seasons.setSpecs(d.seasons.map((n, i) => ({ label: t('season', { n }), action: () => this.pickSeason(i, true) })));
      this.seasons.onFocusChange = (i) => this.pickSeason(i, false);
      if (d.seasons.length) this.pickSeason(0, false);
      else this.episodes.setItems([]);
      this.activate(d.seasons.length ? this.seasons : this.actions);
    }, fail);
  }

  private pickSeason(i: number, focusEpisodes: boolean): void {
    const d = this.seriesInfo;
    if (!d) return;
    this.season = d.seasons[i];
    for (let j = 0; j < this.seasons.el.children.length; j++) this.seasons.el.children[j].classList.toggle('on', j === i);
    this.episodes.setItems(d.episodes.filter((e) => e.season === this.season));
    if (focusEpisodes) this.activate(this.episodes);
  }

  private playMovie(startAt: number): void {
    const m = this.item as Movie;
    const ext = this.movieInfo && this.movieInfo.ext;
    const key = this.keyOf(m.id);
    if (!startAt) resume.clear(key);
    push(new PlayerScreen(this.source, { kind: 'vod', item: { title: m.name, url: this.source.movieUrl(m, ext), key }, startAt }));
  }

  private episodeItem(e: Episode): VodItem {
    return {
      title: this.item.name + ' · S' + e.season + ' E' + e.episode + (e.title && !/^S\d+ E\d+$/.test(e.title) ? ' · ' + e.title : ''),
      url: this.source.episodeUrl(e),
      key: this.keyOf(e.id),
    };
  }

  private playEpisode(e: Episode): void {
    const key = this.keyOf(e.id);
    const at = resume.resumeAt(key);
    if (at == null) {
      this.startEpisode(e, 0);
      return;
    }
    confirmDialog(t('resumeTitle'), this.episodeItem(e).title, [t('resumeFrom', { time: fmtDuration(at) }), t('startOver')]).then((i) => {
      if (i === 0) this.startEpisode(e, at);
      else if (i === 1) this.startEpisode(e, 0);
    });
  }

  private startEpisode(e: Episode, startAt: number): void {
    if (!startAt) resume.clear(this.keyOf(e.id));
    // The whole series in order, so the player can autoplay the next episode.
    const eps = this.seriesInfo ? this.seriesInfo.episodes : [e];
    const at = eps.indexOf(e);
    push(new PlayerScreen(this.source, { kind: 'vod', item: this.episodeItem(e), startAt, queue: eps.map((x) => this.episodeItem(x)), queueIndex: Math.max(0, at) }));
  }

  onKey(k: Key): boolean {
    if (k === 'back' && this.zone === this.episodes) {
      this.activate(this.seasons);
      return true;
    }
    return super.onKey(k);
  }

  protected move(k: Key): boolean {
    const z = this.zone;
    const hasSeasons = this.seasons.el.children.length > 0;
    if (z === this.actions && k === 'down' && this.kind === 'series' && hasSeasons) this.activate(this.seasons);
    else if (z === this.seasons && k === 'up') this.activate(this.actions);
    else if (z === this.seasons && k === 'down' && this.episodes.items.length) this.activate(this.episodes);
    else if (z === this.episodes && k === 'up') this.activate(this.seasons);
    else if (z === this.status.retry && k === 'up') this.activate(this.actions);
    else if (z === this.actions && k === 'down' && this.status.isError) this.activate(this.status.retry);
    else return false;
    return true;
  }
}

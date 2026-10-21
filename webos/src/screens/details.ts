// Movie / series details: poster, meta, plot; series add seasons + episodes.
import { pop, push, type Screen } from '../app';
import { t } from '../i18n';
import type { Episode, Movie, MovieDetails, Series, SeriesDetails } from '../data/models';
import type { Source } from '../data/source';
import type { Key } from '../platform';
import { fmtDuration, h, img, initials } from '../ui/dom';
import { VList } from '../ui/vlist';
import { Buttons } from '../ui/zone';
import { errorDetail, StatusPanel, ZoneScreen } from './common';
import { PlayerScreen } from './player';

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

  constructor(private source: Source, private kind: 'movie' | 'series', private item: Movie | Series) {
    super();
    this.actions = new Buttons(
      kind === 'movie'
        ? [{ label: '▶  ' + t('play'), cls: 'primary', action: () => this.playMovie() }, { label: t('back'), action: () => pop() }]
        : [{ label: t('back'), action: () => pop() }],
    );
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
  }

  private renderMeta(year: string | null, rating: number | null, secs: number | null, genre: string | null): void {
    const parts: string[] = [];
    if (year) parts.push(year);
    if (rating) parts.push('★ ' + rating.toFixed(1));
    if (secs) parts.push(fmtDuration(secs).replace(/:\d\d$/, '').replace(/^(\d+):(\d\d)$/, '$1h $2m'));
    if (genre) parts.push(genre);
    this.metaEl.textContent = parts.join('   ·   ');
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

  private playMovie(): void {
    const m = this.item as Movie;
    const ext = this.movieInfo && this.movieInfo.ext;
    push(new PlayerScreen(this.source, { kind: 'vod', title: m.name, url: this.source.movieUrl(m, ext) }));
  }

  private playEpisode(e: Episode): void {
    push(
      new PlayerScreen(this.source, {
        kind: 'vod',
        title: this.item.name + ' · S' + e.season + ' E' + e.episode + (e.title && !/^S\d+ E\d+$/.test(e.title) ? ' · ' + e.title : ''),
        url: this.source.episodeUrl(e),
      }),
    );
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

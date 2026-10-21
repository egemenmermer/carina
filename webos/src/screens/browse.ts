// Main screen for one playlist: rail (sections) → categories → items.
// Live: channel rows with now/next; Movies/Series: poster grid.
import { pop, push, toast, type Screen } from '../app';
import { t } from '../i18n';
import type { Category, Channel, Item, Movie, Programme, Section, Series } from '../data/models';
import { ALL, type Source } from '../data/source';
import type { Key } from '../platform';
import { store } from '../store';
import { fmtTime, h, img, initials, toggle } from '../ui/dom';
import { VList } from '../ui/vlist';
import { Buttons, Field } from '../ui/zone';
import { errorDetail, foldText, StatusPanel, ZoneScreen } from './common';
import { DetailsScreen } from './details';
import { PlayerScreen } from './player';
import { SettingsScreen } from './settings';

const FAV = '__fav';

export function nowNext(list: Programme[] | undefined, now = Date.now()): [Programme | null, Programme | null] {
  if (!list) return [null, null];
  for (let i = 0; i < list.length; i++) {
    if (list[i].start <= now && list[i].stop > now) return [list[i], list[i + 1] || null];
    if (list[i].start > now) return [null, list[i]];
  }
  return [null, null];
}

interface Memory {
  catIndex: number;
  itemIndex: number;
}

export class BrowseScreen extends ZoneScreen implements Screen {
  el: HTMLElement;
  private section: Section = 'live';
  private rail: Buttons;
  private cats: VList<Category>;
  private channels: VList<Channel>;
  private posters: VList<Movie | Series>;
  private search = new Field('', '');
  private status = new StatusPanel();
  private titleEl = h('h2', { class: 'content-title' });
  private countEl = h('span', { class: 'content-count' });
  private catTitle = h('h2', { class: 'cats-title' });
  private body = h('div', { class: 'content-body' });
  private hint = h('footer', { class: 'hint' });
  private categoryId = '';
  private base: Item[] = [];
  private shown: Item[] = [];
  private epg: Record<string, Programme[]> = {};
  private token = 0;
  private catTimer = 0;
  private searchTimer = 0;
  private memory: Partial<Record<Section, Memory>> = {};
  private pid: string;
  private resumePending = true;

  constructor(private source: Source) {
    super();
    this.pid = source.playlist.id;
    this.rail = new Buttons(
      [
        { label: t('live'), action: () => this.openSection('live') },
        { label: t('movies'), action: () => this.openSection('movies') },
        { label: t('series'), action: () => this.openSection('series') },
        { label: t('settings'), cls: 'rail-sep', action: () => push(new SettingsScreen(this.source)) },
        { label: t('playlists'), action: () => pop() },
      ],
      true,
      'rail-items',
    );
    this.cats = new VList<Category>({
      cls: 'cats',
      itemW: 270,
      itemH: 50,
      cols: 1,
      render: (c) => h('div', { class: 'cat' + (c.id === FAV ? ' cat-fav' : '') }, h('span', { text: c.name })),
      onFocus: (c) => {
        clearTimeout(this.catTimer);
        this.catTimer = window.setTimeout(() => this.loadCategory(c.id), 450);
      },
      onSelect: (c) => {
        clearTimeout(this.catTimer);
        if (c.id !== this.categoryId) this.loadCategory(c.id);
        if (this.shown.length) this.activate(this.itemsList());
      },
    });
    this.channels = new VList<Channel>({
      cls: 'channels',
      itemW: 760,
      itemH: 68,
      cols: 1,
      render: (c) => this.renderChannel(c),
      onSelect: (_c, i) => this.play(i),
      onLongPress: (c) => this.toggleFav(c),
      onVisible: (from, to) => this.fetchEpg(from, to),
    });
    this.posters = new VList<Movie | Series>({
      cls: 'posters',
      itemW: 152,
      itemH: 270,
      render: (m) => this.renderPoster(m),
      onSelect: (m) => push(new DetailsScreen(this.source, this.section === 'series' ? 'series' : 'movie', m)),
    });
    this.search.input.addEventListener('input', () => {
      clearTimeout(this.searchTimer);
      this.searchTimer = window.setTimeout(() => this.applyFilter(true), 300);
    });
    this.body.appendChild(this.channels.el);
    this.body.appendChild(this.posters.el);
    this.body.appendChild(this.status.el);
    this.el = h(
      'div',
      { class: 'screen browse' },
      h('nav', { class: 'rail' }, h('div', { class: 'rail-title', text: source.playlist.name }), this.rail.el),
      h('section', { class: 'cats-col' }, this.catTitle, this.cats.el),
      h('section', { class: 'content' }, h('div', { class: 'content-head' }, h('div', { class: 'content-titles' }, this.titleEl, this.countEl), this.search.el), this.body),
      this.hint,
    );
    for (const z of [this.rail, this.cats, this.channels, this.posters, this.search, this.status.retry]) this.bindPointer(z);
    this.openSection('live');
  }

  onShow(): void {
    // Re-measure after being hidden (display: none gives 0 sizes).
    this.cats.layout();
    this.itemsList().layout();
    if (this.section === 'live' && this.categoryId === FAV) this.loadCategory(FAV);
    else if (this.section === 'live') this.channels.refreshVisible();
  }

  private itemsList(): VList<Channel> | VList<Movie | Series> {
    return this.section === 'live' ? this.channels : this.posters;
  }

  // ---- sections & categories ------------------------------------------------

  private openSection(s: Section): void {
    const prev = this.section;
    if (this.cats.items.length) this.memory[prev] = { catIndex: this.cats.index, itemIndex: this.itemsList().index };
    this.section = s;
    ['live', 'movies', 'series'].forEach((x, i) => toggle(this.rail.el.children[i], 'on', x === s));
    toggle(this.el, 'is-live', s === 'live');
    this.hint.textContent = s === 'live' ? t('hintBrowse') : t('hintBrowseVod');
    this.catTitle.textContent = t(s);
    this.search.input.value = '';
    this.cats.setItems([]);
    this.channels.setItems([]);
    this.posters.setItems([]);
    this.base = this.shown = [];
    this.categoryId = '';
    const my = ++this.token;
    this.status.loading();
    this.source.categories(s).then(
      (list) => {
        if (my !== this.token) return;
        const cats: Category[] = [];
        if (s === 'live') cats.push({ id: FAV, name: '★ ' + t('favourites') });
        if (this.source.hasAll(s)) cats.push({ id: ALL, name: s === 'live' ? t('allChannels') : t('all') });
        const all = cats.concat(list);
        let idx = 0;
        const mem = this.memory[s];
        if (mem) idx = mem.catIndex;
        else if (s === 'live') {
          const last = store.lastChannel(this.pid);
          const li = last ? all.findIndex((c) => c.id === last.categoryId) : -1;
          if (li >= 0) idx = li;
          else if (!store.favourites(this.pid).length) idx = all.length > 1 ? 1 : 0;
        }
        this.cats.setItems(all, idx);
        if (all[idx]) this.loadCategory(all[idx].id, mem ? mem.itemIndex : -1);
        else this.status.hide();
        if (!this.zone || this.zone === this.status.retry) this.activate(this.cats);
      },
      (e) => {
        if (my !== this.token) return;
        this.status.error(t('loadFailed', { detail: errorDetail(e) }), () => this.openSection(s));
        this.activate(this.status.retry);
      },
    );
  }

  private loadCategory(id: string, focusIndex = -1): void {
    if (id === this.categoryId && id !== FAV && this.base.length) return;
    this.categoryId = id;
    const cat = this.cats.items.find((c) => c.id === id);
    this.titleEl.textContent = cat ? cat.name.replace(/^★ /, '') : '';
    this.search.input.placeholder = t('searchIn', { scope: this.searchScopeName() });
    const my = ++this.token;
    if (id === FAV) {
      this.setBase(store.favourites(this.pid), focusIndex);
      return;
    }
    this.status.loading();
    this.itemsList().setItems([]);
    this.source.items(this.section, id).then(
      (list) => {
        if (my !== this.token) return;
        this.setBase(list, focusIndex);
      },
      (e) => {
        if (my !== this.token) return;
        this.status.error(t('loadFailed', { detail: errorDetail(e) }), () => {
          this.categoryId = '';
          this.loadCategory(id);
          this.activate(this.cats);
        });
      },
    );
  }

  private searchScopeName(): string {
    return this.section === 'live' ? t('allChannels') : t(this.section);
  }

  private setBase(list: Item[], focusIndex: number): void {
    this.status.hide();
    this.base = list;
    let resume = false;
    if (focusIndex < 0 && this.section === 'live') {
      const last = store.lastChannel(this.pid);
      if (last && last.categoryId === this.categoryId) focusIndex = list.findIndex((c) => c.id === last.channelId);
      resume = focusIndex >= 0 && this.resumePending;
    }
    this.applyFilter(false, Math.max(0, focusIndex));
    // First open: put focus on the last watched channel so one OK resumes it.
    if (resume && this.zone === this.cats) this.activate(this.channels);
    if (this.section === 'live') this.resumePending = false;
  }

  private applyFilter(fromSearch: boolean, index = 0): void {
    const q = foldText(this.search.value);
    if (!q) {
      this.show(this.base, index);
      return;
    }
    const my = ++this.token;
    if (!this.source.hasAll(this.section)) {
      this.searchByCategory(q, my);
      return;
    }
    // "All" is cheap for this section: filter it in one go.
    const pool = this.source.items(this.section, ALL);
    if (fromSearch) this.status.loading();
    pool.then(
      (all) => {
        if (my !== this.token) return;
        this.status.hide();
        const out: Item[] = [];
        for (const it of all) if (foldText(it.name).indexOf(q) >= 0) out.push(it);
        this.show(out, 0, t('noResults', { q: this.search.value }));
      },
      (e) => {
        if (my !== this.token) return;
        this.status.error(t('loadFailed', { detail: errorDetail(e) }), () => this.applyFilter(true));
      },
    );
  }

  /**
   * Section-wide search without loading the whole catalogue at once (50k
   * movies would not fit): walk the categories one by one, keep only the
   * matches and show them as they arrive. A newer search or category change
   * bumps the token and stops the walk.
   */
  private searchByCategory(q: string, my: number): void {
    const cats = this.cats.items.filter((c) => c.id !== FAV && c.id !== ALL);
    const out: Item[] = [];
    const seen: Record<string, boolean> = {};
    const raw = this.search.value;
    let i = 0;
    this.status.hide();
    this.show([], 0, t('loading'));
    const step = (): void => {
      if (my !== this.token) return;
      if (i >= cats.length || out.length >= 500) {
        this.countEl.textContent = t('items', { n: out.length });
        if (!out.length) this.show([], 0, t('noResults', { q: raw }));
        return;
      }
      const cat = cats[i++];
      this.source.items(this.section, cat.id).then(
        (list) => {
          if (my !== this.token) return;
          const before = out.length;
          for (const it of list) {
            if (!seen[it.id] && foldText(it.name).indexOf(q) >= 0) {
              seen[it.id] = true;
              out.push(it);
            }
          }
          if (out.length !== before) this.show(out.slice(), this.zone === this.itemsList() ? this.itemsList().index : 0);
          this.countEl.textContent = t('items', { n: out.length }) + '  ·  ' + i + '/' + cats.length;
          step();
        },
        () => step(),
      );
    };
    step();
  }

  private show(list: Item[], index: number, emptyText?: string): void {
    this.shown = list;
    const n = list.length;
    this.countEl.textContent = this.section === 'live' ? t('channels', { n }) : t('items', { n });
    const empty = emptyText || (this.categoryId === FAV ? t('emptyFavourites') : t('emptyCategory'));
    if (this.section === 'live') {
      this.channels.setEmptyText(empty);
      this.channels.setItems(list as Channel[], index);
    } else {
      this.posters.setEmptyText(empty);
      this.posters.setItems(list as (Movie | Series)[], index);
    }
  }

  // ---- rendering -------------------------------------------------------------

  private renderChannel(c: Channel): HTMLElement {
    const [now, next] = nowNext(this.epg[c.id]);
    const fav = store.isFavourite(this.pid, c.id);
    let progress: HTMLElement | null = null;
    if (now) {
      const p = Math.max(0, Math.min(1, (Date.now() - now.start) / (now.stop - now.start)));
      progress = h('span', { class: 'bar' }, h('i', { style: 'width:' + Math.round(p * 100) + '%' }));
    }
    return h(
      'div',
      { class: 'ch' + (fav ? ' fav' : '') },
      h('span', { class: 'ch-num', text: c.num != null ? String(c.num) : '' }),
      h('span', { class: 'logo' }, h('b', { text: initials(c.name) }), img(c.logo, 'logo-img')),
      h(
        'span',
        { class: 'ch-text' },
        h('span', { class: 'ch-name', text: c.name }),
        h('span', { class: 'ch-now', text: now ? now.title : '' }),
        progress,
      ),
      h('span', { class: 'ch-next', text: next ? fmtTime(next.start) + '  ' + next.title : '' }),
      fav ? h('span', { class: 'ch-star', text: '★' }) : null,
    );
  }

  private renderPoster(m: Movie | Series): HTMLElement {
    return h(
      'div',
      { class: 'card' },
      h(
        'div',
        { class: 'poster' },
        h('b', { text: initials(m.name) }),
        img(m.poster, 'poster-img'),
        m.rating ? h('span', { class: 'rating', text: '★ ' + m.rating.toFixed(1) }) : null,
      ),
      h('div', { class: 'card-title', text: m.name }),
      m.year ? h('div', { class: 'card-meta', text: m.year }) : null,
    );
  }

  // ---- EPG ---------------------------------------------------------------------

  private fetchEpg(from: number, to: number): void {
    if (this.section !== 'live') return;
    const list = this.shown as Channel[];
    const todo: Channel[] = [];
    for (let i = from; i <= to && i < list.length; i++) if (!this.epg[list[i].id]) todo.push(list[i]);
    if (!todo.length) return;
    let running = 0;
    let changed = false;
    const next = (): void => {
      while (running < 3 && todo.length) {
        const c = todo.shift() as Channel;
        running++;
        this.source.epg(c).then((p) => {
          this.epg[c.id] = p;
          if (p.length) changed = true;
          running--;
          if (!todo.length && !running) {
            if (changed && this.shown === list) this.channels.refreshVisible();
          } else next();
        });
      }
    };
    next();
  }

  // ---- actions -------------------------------------------------------------------

  private play(index: number): void {
    const list = this.shown as Channel[];
    if (!list.length) return;
    push(
      new PlayerScreen(this.source, {
        kind: 'live',
        channels: list,
        index,
        categoryId: this.search.value ? ALL : this.categoryId,
        epg: this.epg,
        onExit: (i) => {
          if (this.shown === list) this.channels.moveTo(i);
        },
      }),
    );
  }

  private toggleFav(c: Channel): void {
    const added = store.toggleFavourite(this.pid, c);
    toast(added ? t('addedToFavourites') : t('removedFromFavourites'));
    if (this.categoryId === FAV && !this.search.value) {
      this.base = store.favourites(this.pid);
      this.show(this.base, Math.min(this.channels.index, this.base.length - 1));
    } else this.channels.refreshVisible();
  }

  // ---- keys ------------------------------------------------------------------------

  onKey(k: Key): boolean {
    const list = this.itemsList();
    if ((k === 'red' || k === 'yellow') && this.zone === this.channels) {
      const c = this.channels.current();
      if (c) this.toggleFav(c);
      return true;
    }
    if (k === 'back') {
      if (this.zone === this.search && this.search.value) {
        this.search.input.value = '';
        this.applyFilter(false);
        return true;
      }
      if (this.zone === list || this.zone === this.search || this.zone === this.status.retry) return this.activate(this.cats), true;
      if (this.zone === this.cats) return this.activate(this.rail), true;
      return false; // rail: back to the playlist picker
    }
    return super.onKey(k);
  }

  protected move(k: Key): boolean {
    const list = this.itemsList();
    const z = this.zone;
    const hasItems = this.shown.length > 0;
    const retry = this.status.isError ? this.status.retry : null;
    if (z === this.rail) {
      if (k === 'right') this.activate(this.cats.items.length ? this.cats : retry || this.cats);
      else return false;
    } else if (z === this.cats) {
      if (k === 'left') this.activate(this.rail);
      else if (k === 'right') this.activate(retry || (hasItems ? list : this.search));
      else return false;
    } else if (z === list) {
      if (k === 'left') this.activate(this.cats);
      else if (k === 'up') this.activate(this.search);
      else return false;
    } else if (z === this.search) {
      if (k === 'down') this.activate(hasItems ? list : retry || this.cats);
      else if (k === 'left') this.activate(this.cats);
      else return false;
    } else if (z === this.status.retry) {
      if (k === 'left') this.activate(this.cats);
      else if (k === 'up') this.activate(this.search);
      else return false;
    } else return false;
    return true;
  }
}

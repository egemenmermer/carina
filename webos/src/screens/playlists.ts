// Start screen: pick a playlist (or add one / open settings).
import { push, toast, type Screen } from '../app';
import { t } from '../i18n';
import type { Playlist } from '../data/models';
import { createSource, type Source } from '../data/source';
import { HttpError } from '../data/http';
import type { M3uProgress } from '../data/m3u-loader';
import type { Key } from '../platform';
import { store } from '../store';
import { h, setText } from '../ui/dom';
import { Buttons } from '../ui/zone';
import { brandMark, errorDetail, ZoneScreen } from './common';
import { AddPlaylistScreen } from './add-playlist';
import { BrowseScreen } from './browse';
import { SettingsScreen } from './settings';

export function hostOf(p: Playlist): string {
  const u = p.kind === 'xtream' ? p.server : p.url;
  const m = /^[a-z]+:\/\/([^/?#]+)/i.exec(u);
  return m ? m[1].replace(/^[^@]*@/, '') : u;
}

export function playlistErrorText(e: unknown): string {
  if (e instanceof HttpError && (e.status === 401 || e.status === 403 || e.message === 'unauthorized')) return t('loginFailed');
  return t('connectFailed', { detail: errorDetail(e) });
}

/** Shows the browse screen for an opened source. */
export function enterSource(source: Source): void {
  store.saveSettings({ lastPlaylistId: source.playlist.id });
  push(new BrowseScreen(source));
}

export function progressText(pr: M3uProgress): string {
  const mb = pr.total ? (pr.bytes / 1048576).toFixed(1) + ' / ' + (pr.total / 1048576).toFixed(1) : (pr.bytes / 1048576).toFixed(1);
  return t('loadingPlaylist', { mb, n: pr.entries });
}

/** Opens [p] (auth / download) and shows the browse screen. */
export function openPlaylist(p: Playlist, busy: (on: boolean, text?: string) => void): Promise<boolean> {
  const source = createSource(p, t('other'));
  busy(true);
  return source.open((pr) => busy(true, progressText(pr))).then(
    () => {
      busy(false);
      enterSource(source);
      return true;
    },
    (e) => {
      busy(false);
      toast(playlistErrorText(e));
      return false;
    },
  );
}

export class PlaylistsScreen extends ZoneScreen implements Screen {
  el: HTMLElement;
  private list = new Buttons([], true, 'playlist-list');
  private busyText = h('p', { text: t('loading') });
  private busyEl = h('div', { class: 'busy' }, h('div', { class: 'spinner' }), this.busyText);
  private opening = false;

  constructor() {
    super();
    this.el = h(
      'div',
      { class: 'screen playlists' },
      h('div', { class: 'pl-head' }, brandMark(), h('h1', { text: t('appName') })),
      h('p', { class: 'pl-sub', text: t('choosePlaylist') }),
      this.list.el,
      this.busyEl,
    );
    this.bindPointer(this.list);
    this.activate(this.list);
  }

  onShow(): void {
    const pls = store.playlists();
    const last = store.settings().lastPlaylistId;
    const specs = pls.map((p) => ({
      label: '',
      cls: 'pl-item',
      action: () => this.open(p),
    }));
    specs.push({ label: '+  ' + t('addPlaylist'), cls: 'pl-add', action: () => push(new AddPlaylistScreen()) });
    specs.push({ label: t('settings'), cls: 'pl-settings', action: () => push(new SettingsScreen(null)) });
    this.list.setSpecs(specs);
    // Richer labels for playlist rows.
    const nodes = this.list.el.children;
    pls.forEach((p, i) => {
      const n = nodes[i] as HTMLElement;
      n.textContent = '';
      n.appendChild(h('span', { class: 'pl-name', text: p.name }));
      n.appendChild(h('span', { class: 'pl-meta', text: (p.kind === 'xtream' ? t('xtream') : 'M3U') + ' · ' + hostOf(p) }));
    });
    let idx = pls.findIndex((p) => p.id === last);
    if (idx < 0) idx = pls.length ? 0 : pls.length; // focus "Add playlist" when empty
    this.list.focus(idx);
    this.el.classList.toggle('empty', !pls.length);
  }

  private open(p: Playlist): void {
    if (this.opening) return;
    this.opening = true;
    openPlaylist(p, (on, text) => {
      this.busyEl.classList.toggle('show', on);
      setText(this.busyText, on && text ? text : t('loading'));
    }).then(() => {
      this.opening = false;
    });
  }

  onKey(k: Key): boolean {
    if (this.opening) return true; // swallow keys while a playlist opens
    return super.onKey(k);
  }

  protected move(): boolean {
    return false;
  }
}

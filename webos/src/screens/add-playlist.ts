// Add an Xtream (server, user, password) or M3U URL playlist.
import { pop, type Screen } from '../app';
import { t } from '../i18n';
import type { Playlist } from '../data/models';
import { createSource } from '../data/source';
import { normalizeServer } from '../data/xtream';
import type { Key } from '../platform';
import { store } from '../store';
import { h } from '../ui/dom';
import { Buttons, Field, type Zone } from '../ui/zone';
import { ZoneScreen } from './common';
import { enterSource, hostOf, playlistErrorText } from './playlists';

export class AddPlaylistScreen extends ZoneScreen implements Screen {
  el: HTMLElement;
  private kind: 'xtream' | 'm3u' = 'xtream';
  private tabs: Buttons;
  private name = new Field(t('name'), t('namePlaceholder'));
  private server = new Field(t('server'), t('serverPlaceholder'), 'url');
  private user = new Field(t('username'), '');
  private pass = new Field(t('password'), '', 'password');
  private url = new Field(t('m3uUrl'), 'http://…/get.php?username=…&type=m3u_plus', 'url');
  private save: Buttons;
  private msg = h('p', { class: 'form-msg' });
  private formEl = h('div', { class: 'form' });
  private order: Zone[] = [];
  private busy = false;

  constructor() {
    super();
    this.tabs = new Buttons(
      [
        { label: t('xtream'), action: () => this.setKind('xtream') },
        { label: t('m3u'), action: () => this.setKind('m3u') },
      ],
      false,
      'segmented',
    );
    this.save = new Buttons([{ label: t('save'), cls: 'primary', action: () => this.submit() }]);
    this.el = h('div', { class: 'screen add-playlist' }, h('h1', { text: t('addPlaylist') }), this.tabs.el, this.formEl, this.msg, this.save.el,
      h('p', { class: 'hint', text: t('hintKeyboard') }));
    for (const z of [this.tabs, this.name, this.server, this.user, this.pass, this.url, this.save]) this.bindPointer(z);
    this.setKind('xtream');
    this.activate(this.tabs);
  }

  private setKind(kind: 'xtream' | 'm3u'): void {
    this.kind = kind;
    this.tabs.el.children[0].classList.toggle('on', kind === 'xtream');
    this.tabs.el.children[1].classList.toggle('on', kind === 'm3u');
    this.formEl.innerHTML = '';
    const fields = kind === 'xtream' ? [this.name, this.server, this.user, this.pass] : [this.name, this.url];
    for (const f of fields) this.formEl.appendChild(f.el);
    this.order = [this.tabs as Zone].concat(fields, [this.save]);
    this.msg.textContent = '';
  }

  protected move(k: Key): boolean {
    const i = this.order.indexOf(this.zone as Zone);
    if (k === 'down' && i < this.order.length - 1) this.activate(this.order[i + 1]);
    else if (k === 'up' && i > 0) this.activate(this.order[i - 1]);
    else return false;
    return true;
  }

  onKey(k: Key): boolean {
    if (this.busy) return true;
    return super.onKey(k);
  }

  private submit(): void {
    const id = 'p' + Date.now().toString(36);
    let p: Playlist;
    if (this.kind === 'xtream') {
      if (!this.server.value || !this.user.value || !this.pass.value) return this.fail(t('required'));
      const server = normalizeServer(this.server.value);
      p = { id, kind: 'xtream', name: '', server, username: this.user.value, password: this.pass.value };
    } else {
      if (!this.url.value) return this.fail(t('required'));
      p = { id, kind: 'm3u', name: '', url: normalizeServer(this.url.value) };
    }
    p.name = this.name.value || hostOf(p);
    this.busy = true;
    this.msg.className = 'form-msg';
    this.msg.textContent = t('checking');
    // Check first so typos surface here, not on the browse screen.
    const source = createSource(p, t('other'));
    source.open().then(
        () => {
          store.addPlaylist(p);
          this.busy = false;
          pop();
          enterSource(source);
        },
        (e) => {
          this.busy = false;
          this.fail(playlistErrorText(e));
        },
      );
  }

  private fail(text: string): void {
    this.msg.className = 'form-msg error';
    this.msg.textContent = text;
  }
}

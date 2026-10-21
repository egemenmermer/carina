// Settings: language and playlist removal.
import { confirmDialog, type Screen } from '../app';
import { t } from '../i18n';
import type { Source } from '../data/source';
import type { Key } from '../platform';
import { store, type Lang } from '../store';
import { h } from '../ui/dom';
import { Buttons } from '../ui/zone';
import { ZoneScreen } from './common';
import { hostOf } from './playlists';

export class SettingsScreen extends ZoneScreen implements Screen {
  el: HTMLElement;
  private lang: Buttons;
  private pls = new Buttons([], true, 'settings-playlists');

  constructor(private source: Source | null) {
    super();
    const langs: [Lang, string][] = [['auto', t('langAuto')], ['en', 'English'], ['tr', 'Türkçe']];
    const cur = store.settings().lang;
    this.lang = new Buttons(
      langs.map(([code, label]) => ({
        label,
        cls: code === cur ? 'on' : '',
        action: () => {
          if (code === store.settings().lang) return;
          store.saveSettings({ lang: code });
          location.reload(); // simplest way to rebuild every string
        },
      })),
      false,
      'segmented',
    );
    this.lang.focus(Math.max(0, langs.findIndex((l) => l[0] === cur)));
    this.el = h(
      'div',
      { class: 'screen settings' },
      h('h1', { text: t('settings') }),
      h('h3', { text: t('language') }),
      this.lang.el,
      h('h3', { text: t('playlists') }),
      this.pls.el,
      h('p', { class: 'version', text: t('version', { v: __VERSION__ }) }),
    );
    this.bindPointer(this.lang);
    this.bindPointer(this.pls);
    this.activate(this.lang);
    this.fillPlaylists();
  }

  private fillPlaylists(): void {
    const list = store.playlists();
    this.pls.setSpecs(
      list.map((p) => ({
        label: t('remove') + ' · ' + p.name + '  (' + hostOf(p) + ')',
        action: () => {
          confirmDialog(t('removePlaylistTitle', { name: p.name }), t('removePlaylistHint'), [t('remove'), t('cancel')]).then((i) => {
            if (i !== 0) return;
            store.removePlaylist(p.id);
            if (this.source && this.source.playlist.id === p.id) location.reload();
            else this.fillPlaylists();
          });
        },
      })),
    );
    if (!list.length && this.zone === this.pls) this.activate(this.lang);
  }

  protected move(k: Key): boolean {
    if (k === 'down' && this.zone === this.lang && this.pls.el.children.length) this.activate(this.pls);
    else if (k === 'up' && this.zone === this.pls) this.activate(this.lang);
    else return false;
    return true;
  }
}

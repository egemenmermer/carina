// Shared bits for screens: the brand mark, a zone-based screen base class
// and a loading/error panel.
import type { Key } from '../platform';
import { h } from '../ui/dom';
import { Buttons, type Zone } from '../ui/zone';
import { t } from '../i18n';

export function brandMark(cls = 'brand-mark'): HTMLElement {
  const el = h('span', { class: cls });
  el.innerHTML =
    '<svg viewBox="0 0 64 64" width="100%" height="100%"><defs><linearGradient id="cg" x1="0" y1="0" x2="1" y2="1">' +
    '<stop offset="0" stop-color="#FFB46B"/><stop offset="1" stop-color="#FF5E57"/></linearGradient></defs>' +
    '<circle cx="47" cy="18" r="3.4" fill="url(#cg)"/><path fill="url(#cg)" fill-rule="evenodd" d="M8 31H58L48.6 48.3C48 49.4 46.8 50 45.6 50H20.6C19 50 17.6 49.1 17 47.7ZM28.6 35.6v9.8c0 .8.9 1.3 1.6.9l8-4.9c.6-.4.6-1.3 0-1.7l-8-4.9c-.7-.4-1.6.1-1.6.8Z"/></svg>';
  return el;
}

/** Base for screens made of zones; subclasses route edge keys in [move]. */
export abstract class ZoneScreen {
  abstract el: HTMLElement;
  protected zone: Zone | null = null;

  protected activate(z: Zone | null): void {
    if (this.zone === z) return;
    if (this.zone) this.zone.setActive(false);
    this.zone = z;
    if (z) z.setActive(true);
  }

  protected bindPointer(z: Zone): void {
    z.onPointer = () => this.activate(z);
  }

  onKey(k: Key): boolean {
    if (this.zone && this.zone.onKey(k)) return true;
    return this.move(k);
  }

  /** Edge key not handled by the active zone. */
  protected abstract move(k: Key): boolean;
}

/** Loading text, or an error message with a Retry button. */
export class StatusPanel {
  el = h('div', { class: 'status' });
  retry = new Buttons([]);

  loading(): void {
    this.el.className = 'status show';
    this.el.innerHTML = '';
    this.el.appendChild(h('div', { class: 'spinner' }));
    this.el.appendChild(h('p', { text: t('loading') }));
  }

  error(message: string, onRetry: () => void): void {
    this.el.className = 'status show';
    this.el.innerHTML = '';
    this.retry.setSpecs([{ label: t('retry'), action: onRetry }]);
    this.el.appendChild(h('p', { class: 'error', text: message }));
    this.el.appendChild(this.retry.el);
  }

  hide(): void {
    this.el.className = 'status';
    this.el.innerHTML = '';
  }

  get isError(): boolean {
    return this.el.classList.contains('show') && !!this.el.querySelector('.error');
  }
}

export function errorDetail(e: unknown): string {
  const m = e && (e as Error).message;
  return m ? String(m) : 'error';
}

export function foldText(s: string): string {
  return s
    .toLowerCase()
    .replace(/̇/g, '')
    .replace(/[ıİ]/g, 'i')
    .replace(/ş/g, 's')
    .replace(/ğ/g, 'g')
    .replace(/ç/g, 'c')
    .replace(/ö/g, 'o')
    .replace(/ü/g, 'u');
}

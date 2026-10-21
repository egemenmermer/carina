// Virtualised list/grid. Only the rows in view (plus a small margin) exist
// in the DOM, positioned with transforms; the whole strip scrolls with one
// translateY. Providers list 10k+ channels and 50k movies.
import { px, type Key } from '../platform';
import { h, toggle } from './dom';
import type { Zone } from './zone';

export interface VListOptions<T> {
  cls: string;
  /** Cell size in design px, gaps included. */
  itemW: number;
  itemH: number;
  /** Columns; 0 = as many as fit the viewport width. */
  cols?: number;
  render(item: T, i: number): HTMLElement;
  onSelect(item: T, i: number): void;
  onLongPress?(item: T, i: number): void;
  onFocus?(item: T, i: number): void;
  /** Visible range changed (after scrolling settles). */
  onVisible?(from: number, to: number): void;
}

const MARGIN_ROWS = 2;

export class VList<T> implements Zone {
  el: HTMLElement;
  private inner: HTMLElement;
  private emptyEl: HTMLElement;
  items: T[] = [];
  index = 0;
  private cols = 1;
  private scroll = 0; // px
  private viewH = 0;
  private active = false;
  private nodes: Record<number, HTMLElement> = {};
  private visibleTimer = 0;
  private wheelAt = 0;
  onPointer?: () => void;

  constructor(private o: VListOptions<T>) {
    this.inner = h('div', { class: 'vlist-inner' });
    this.emptyEl = h('div', { class: 'vlist-empty' });
    this.el = h('div', { class: 'vlist ' + o.cls }, this.inner, this.emptyEl);
    const onWheel = (e: Event) => {
      const now = Date.now();
      const dy = (e as WheelEvent).deltaY || -((e as unknown as { wheelDelta?: number }).wheelDelta || 0);
      e.preventDefault();
      if (now - this.wheelAt < 90 || !dy) return;
      this.wheelAt = now;
      this.moveTo(this.index + (dy > 0 ? this.cols : -this.cols));
    };
    this.el.addEventListener('wheel', onWheel);
  }

  setEmptyText(text: string): void {
    this.emptyEl.textContent = text;
  }

  setItems(items: T[], index = 0): void {
    this.items = items;
    for (const k of Object.keys(this.nodes)) this.inner.removeChild(this.nodes[+k]);
    this.nodes = {};
    this.index = Math.max(0, Math.min(index, items.length - 1));
    this.scroll = 0;
    toggle(this.el, 'is-empty', items.length === 0);
    this.layout(true);
  }

  current(): T | undefined {
    return this.items[this.index];
  }

  /** Re-measures and re-renders; call after the list becomes visible or is resized. */
  layout(jump = false): void {
    this.viewH = this.el.clientHeight;
    const w = this.el.clientWidth;
    this.cols = this.o.cols || Math.max(1, Math.floor(w / px(this.o.itemW)));
    this.ensureVisible(jump);
    this.render();
  }

  refreshVisible(): void {
    for (const k of Object.keys(this.nodes)) {
      const i = +k;
      const old = this.nodes[i];
      const n = this.makeNode(i);
      this.inner.replaceChild(n, old);
      this.nodes[i] = n;
    }
    this.paintFocus();
  }

  setActive(a: boolean): void {
    this.active = a;
    toggle(this.el, 'active', a);
    this.paintFocus();
  }

  onKey(k: Key): boolean {
    const n = this.items.length;
    if (!n) return false;
    const col = this.index % this.cols;
    switch (k) {
      case 'up':
        if (this.index - this.cols < 0) return false;
        this.moveTo(this.index - this.cols);
        return true;
      case 'down':
        if (this.index + this.cols >= n) {
          // Last partial row: jump to the last item if it is on a lower row.
          const lastRow = Math.floor((n - 1) / this.cols);
          if (Math.floor(this.index / this.cols) < lastRow) {
            this.moveTo(n - 1);
            return true;
          }
          return false;
        }
        this.moveTo(this.index + this.cols);
        return true;
      case 'left':
        if (this.cols === 1 || col === 0) return false;
        this.moveTo(this.index - 1);
        return true;
      case 'right':
        if (this.cols === 1 || col === this.cols - 1 || this.index === n - 1) return false;
        this.moveTo(this.index + 1);
        return true;
      case 'chUp':
        this.moveTo(Math.max(0, this.index - this.pageItems()));
        return true;
      case 'chDown':
        this.moveTo(Math.min(n - 1, this.index + this.pageItems()));
        return true;
      case 'ok':
        this.o.onSelect(this.items[this.index], this.index);
        return true;
      case 'okLong':
        if (!this.o.onLongPress) return false;
        this.o.onLongPress(this.items[this.index], this.index);
        return true;
    }
    return false;
  }

  private pageItems(): number {
    return Math.max(1, Math.floor(this.viewH / px(this.o.itemH))) * this.cols;
  }

  moveTo(i: number, fromPointer = false): void {
    if (!this.items.length) return;
    i = Math.max(0, Math.min(this.items.length - 1, i));
    if (i === this.index && !fromPointer) return;
    this.index = i;
    if (!fromPointer) this.ensureVisible(false);
    this.render();
    if (this.o.onFocus) this.o.onFocus(this.items[i], i);
  }

  private ensureVisible(jump: boolean): void {
    const rowH = px(this.o.itemH);
    const row = Math.floor(this.index / this.cols);
    const rows = Math.ceil(this.items.length / this.cols);
    const maxScroll = Math.max(0, rows * rowH - this.viewH);
    let s = this.scroll;
    const top = row * rowH;
    // Keep one row of context above/below the focused row when possible.
    if (top - rowH < s) s = top - rowH;
    if (top + 2 * rowH > s + this.viewH) s = top + 2 * rowH - this.viewH;
    s = Math.max(0, Math.min(maxScroll, s));
    if (s !== this.scroll || jump) {
      this.scroll = s;
      toggle(this.inner, 'no-anim', jump);
      this.inner.style.transform = 'translate3d(0,' + -s + 'px,0)';
    }
  }

  private render(): void {
    const rowH = px(this.o.itemH);
    const view = this.viewH || rowH * 8;
    const first = Math.max(0, Math.floor(this.scroll / rowH) - MARGIN_ROWS);
    const last = Math.ceil((this.scroll + view) / rowH) + MARGIN_ROWS;
    const from = first * this.cols;
    const to = Math.min(this.items.length - 1, (last + 1) * this.cols - 1);
    for (const k of Object.keys(this.nodes)) {
      const i = +k;
      if (i < from || i > to) {
        this.inner.removeChild(this.nodes[i]);
        delete this.nodes[i];
      }
    }
    for (let i = from; i <= to; i++) {
      if (!this.nodes[i]) {
        const n = this.makeNode(i);
        this.nodes[i] = n;
        this.inner.appendChild(n);
      }
    }
    this.paintFocus();
    if (this.o.onVisible) {
      clearTimeout(this.visibleTimer);
      const vf = Math.floor(this.scroll / rowH) * this.cols;
      const vt = Math.min(this.items.length - 1, Math.ceil((this.scroll + view) / rowH) * this.cols - 1);
      this.visibleTimer = window.setTimeout(() => this.o.onVisible && this.o.onVisible(vf, vt), 350);
    }
  }

  private makeNode(i: number): HTMLElement {
    const n = this.o.render(this.items[i], i);
    n.classList.add('vitem');
    const row = Math.floor(i / this.cols);
    const col = i % this.cols;
    n.style.transform = 'translate3d(' + col * px(this.o.itemW) + 'px,' + row * px(this.o.itemH) + 'px,0)';
    n.addEventListener('mouseover', () => {
      if (this.onPointer) this.onPointer();
      if (this.index !== i) this.moveTo(i, true);
    });
    n.addEventListener('click', () => {
      this.moveTo(i, true);
      this.o.onSelect(this.items[i], i);
    });
    return n;
  }

  private paintFocus(): void {
    for (const k of Object.keys(this.nodes)) {
      const i = +k;
      toggle(this.nodes[i], 'focused', this.active && i === this.index);
      toggle(this.nodes[i], 'selected', i === this.index);
    }
  }
}

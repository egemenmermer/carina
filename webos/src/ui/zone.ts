// Focus model: each screen is a set of zones (lists, button rows, fields).
// Exactly one zone is active; it owns the D-pad until it hands an edge key
// back to its screen. Index-based, so virtualised items need no DOM lookups.
import type { Key } from '../platform';
import { h, toggle } from './dom';

export interface Zone {
  el: HTMLElement;
  /** Handles a key; false means "edge reached / not mine" so the screen can move focus. */
  onKey(k: Key): boolean;
  setActive(active: boolean): void;
  /** Called by pointer hover so the screen can make this zone active. */
  onPointer?: () => void;
}

export interface ButtonSpec {
  label: string;
  cls?: string;
  action: () => void;
  longAction?: () => void;
}

/** A row (horizontal) or column (vertical) of plain buttons. */
export class Buttons implements Zone {
  el: HTMLElement;
  index = 0;
  private active = false;
  private nodes: HTMLElement[] = [];
  onPointer?: () => void;
  onFocusChange?: (i: number) => void;

  constructor(private specs: ButtonSpec[], private vertical = false, cls = '') {
    this.el = h('div', { class: 'buttons ' + (vertical ? 'vertical ' : '') + cls });
    this.setSpecs(specs);
  }

  setSpecs(specs: ButtonSpec[]): void {
    this.specs = specs;
    this.el.innerHTML = '';
    this.nodes = specs.map((s, i) => {
      const b = h('div', { class: 'btn ' + (s.cls || ''), text: s.label });
      b.addEventListener('mouseover', () => {
        if (this.onPointer) this.onPointer();
        this.focus(i);
      });
      b.addEventListener('click', () => {
        this.focus(i);
        s.action();
      });
      this.el.appendChild(b);
      return b;
    });
    if (this.index >= specs.length) this.index = Math.max(0, specs.length - 1);
    this.paint();
  }

  focus(i: number): void {
    if (i < 0 || i >= this.nodes.length) return;
    this.index = i;
    this.paint();
    if (this.onFocusChange) this.onFocusChange(i);
  }

  setActive(a: boolean): void {
    this.active = a;
    this.paint();
  }

  private paint(): void {
    this.nodes.forEach((n, i) => toggle(n, 'focused', this.active && i === this.index));
  }

  onKey(k: Key): boolean {
    const prev = this.vertical ? 'up' : 'left';
    const next = this.vertical ? 'down' : 'right';
    if (k === prev) {
      if (this.index === 0) return false;
      this.focus(this.index - 1);
      return true;
    }
    if (k === next) {
      if (this.index >= this.nodes.length - 1) return false;
      this.focus(this.index + 1);
      return true;
    }
    if (k === 'ok') {
      const s = this.specs[this.index];
      if (s) s.action();
      return true;
    }
    if (k === 'okLong') {
      const s = this.specs[this.index];
      if (s && s.longAction) s.longAction();
      return !!(s && s.longAction);
    }
    return false;
  }
}

/**
 * A text field. OK puts the DOM focus in the <input> (the webOS virtual
 * keyboard opens); Up/Down/Back leave it again (handled in app.ts).
 */
export class Field implements Zone {
  el: HTMLElement;
  input: HTMLInputElement;
  onPointer?: () => void;

  constructor(label: string, placeholder: string, type = 'text', value = '') {
    this.input = h('input', { type, placeholder, spellcheck: 'false', autocomplete: 'off', autocapitalize: 'off' }) as HTMLInputElement;
    this.input.value = value;
    this.el = h('label', { class: 'field' }, label ? h('span', { class: 'field-label', text: label }) : null, this.input);
    this.el.addEventListener('mouseover', () => this.onPointer && this.onPointer());
  }

  get value(): string {
    return this.input.value.trim();
  }

  setActive(a: boolean): void {
    toggle(this.el, 'focused', a);
    if (!a && document.activeElement === this.input) this.input.blur();
  }

  onKey(k: Key): boolean {
    if (k === 'ok') {
      this.input.focus();
      return true;
    }
    return false;
  }
}

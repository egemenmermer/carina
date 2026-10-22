// Screen stack, key dispatch (incl. long-press OK), dialogs and toasts.
import { exitApp, keyOf, type Key } from './platform';
import { t } from './i18n';
import { h } from './ui/dom';
import { Buttons } from './ui/zone';

export interface Screen {
  el: HTMLElement;
  onKey(k: Key): boolean;
  onShow?(): void;
  onHide?(): void;
  onDestroy?(): void;
  /** Screens that react to OK on keydown instead of waiting for long-press detection. */
  instantOk?: boolean;
}

const stack: Screen[] = [];
let root: HTMLElement;
let modal: { el: HTMLElement; buttons: Buttons; resolve(i: number): void } | null = null;

export function initApp(el: HTMLElement): void {
  root = el;
  document.addEventListener('keydown', onKeyDown, true);
  document.addEventListener('keyup', onKeyUp, true);
  document.addEventListener(
    'click',
    (e) => {
      if (Date.now() - lastOkAt < DOUBLE_MS) {
        e.stopPropagation();
        e.preventDefault();
        return;
      }
      lastClickAt = Date.now();
    },
    true,
  );
  // Magic Remote: the pointer hides on key presses; nothing else to do.
}

export function top(): Screen | undefined {
  return stack[stack.length - 1];
}

export function push(s: Screen): void {
  const prev = top();
  if (prev) {
    prev.el.style.display = 'none';
    if (prev.onHide) prev.onHide();
  }
  stack.push(s);
  root.appendChild(s.el);
  if (s.onShow) s.onShow();
}

export function pop(): void {
  const s = stack.pop();
  if (!s) return;
  if (s.onHide) s.onHide();
  if (s.onDestroy) s.onDestroy();
  root.removeChild(s.el);
  const prev = top();
  if (prev) {
    prev.el.style.display = '';
    if (prev.onShow) prev.onShow();
  }
}

/** Clears the stack and shows [s] as the new root. */
export function reset(s: Screen): void {
  while (stack.length) pop();
  push(s);
}

// ---- keys -----------------------------------------------------------------

let okDownAt = 0;
let okSeenAt = 0;
let okTimer = 0;
let okLongFired = false;
// One Magic Remote press can produce both a click and an Enter key; whichever
// comes second must not act again on the screen the first one opened.
let lastOkAt = 0;
let lastClickAt = 0;
const DOUBLE_MS = 400;

function inTextField(): boolean {
  const a = document.activeElement;
  return !!a && (a.tagName === 'INPUT' || a.tagName === 'TEXTAREA');
}

function dispatch(k: Key): void {
  if (k === 'ok' || k === 'okLong') {
    if (Date.now() - lastClickAt < DOUBLE_MS) return;
    lastOkAt = Date.now();
  }
  if (modal) {
    if (k === 'back') modal.resolve(-1);
    else modal.buttons.onKey(k);
    return;
  }
  const s = top();
  if (!s) return;
  if (s.onKey(k)) return;
  if (k === 'back') {
    if (stack.length > 1) pop();
    else confirmExit();
  }
}

function onKeyDown(e: KeyboardEvent): void {
  const field = inTextField();
  const k = keyOf(e, field);
  if (!k) return;
  if (field) {
    // In a text field Left/Right move the caret; Up/Down/Back/OK leave it.
    if (k === 'left' || k === 'right') return;
    if (k === 'back' || k === 'ok') {
      e.preventDefault();
      (document.activeElement as HTMLElement).blur();
      return;
    }
    if (k === 'up' || k === 'down') (document.activeElement as HTMLElement).blur();
  }
  e.preventDefault();
  const s = top();
  if (k === 'ok' && !modal && !(s && s.instantOk)) {
    const now = Date.now();
    const gap = now - okSeenAt;
    okSeenAt = now;
    if (e.repeat) return;
    // A held key repeats keydown; a gap > 1.5 s means the keyup got lost.
    if (okDownAt && gap < 1500) return;
    clearTimeout(okTimer);
    okDownAt = now;
    okLongFired = false;
    okTimer = window.setTimeout(() => {
      okLongFired = true;
      dispatch('okLong');
    }, 700);
    return;
  }
  dispatch(k);
}

function onKeyUp(e: KeyboardEvent): void {
  if (e.keyCode !== 13 || !okDownAt) return;
  clearTimeout(okTimer);
  okDownAt = 0;
  if (!okLongFired) dispatch('ok');
  okLongFired = false;
}

window.addEventListener('blur', () => {
  clearTimeout(okTimer);
  okDownAt = 0;
});

// ---- dialogs & toasts -------------------------------------------------------

export function confirmDialog(title: string, body: string, labels: string[]): Promise<number> {
  return new Promise((resolve) => {
    const buttons = new Buttons(
      labels.map((label, i) => ({ label, action: () => done(i) })),
      false,
      'dialog-buttons',
    );
    const el = h('div', { class: 'modal' }, h('div', { class: 'dialog' }, h('h2', { text: title }), body ? h('p', { text: body }) : null, buttons.el));
    const done = (i: number) => {
      if (!modal) return;
      modal = null;
      document.body.removeChild(el);
      resolve(i);
    };
    buttons.setActive(true);
    document.body.appendChild(el);
    modal = { el, buttons, resolve: done };
  });
}

function confirmExit(): void {
  confirmDialog(t('exitTitle'), '', [t('exit'), t('cancel')]).then((i) => {
    if (i === 0) exitApp();
  });
}

let toastEl: HTMLElement | null = null;
let toastTimer = 0;

export function toast(text: string): void {
  if (!toastEl) {
    toastEl = h('div', { class: 'toast' });
    document.body.appendChild(toastEl);
  }
  toastEl.textContent = text;
  toastEl.classList.add('show');
  clearTimeout(toastTimer);
  toastTimer = window.setTimeout(() => toastEl && toastEl.classList.remove('show'), 2200);
}

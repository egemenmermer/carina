// Tiny DOM helpers (no framework: webOS 4 CPUs are slow).

type Child = Node | string | null | undefined | false;

export function h<K extends keyof HTMLElementTagNameMap>(
  tag: K,
  props?: { [k: string]: unknown } | null,
  ...children: (Child | Child[])[]
): HTMLElementTagNameMap[K] {
  const el = document.createElement(tag);
  if (props) {
    for (const k of Object.keys(props)) {
      const v = props[k];
      if (v == null || v === false) continue;
      if (k === 'class') el.className = String(v);
      else if (k === 'text') el.textContent = String(v);
      else if (k.indexOf('on') === 0 && typeof v === 'function') el.addEventListener(k.slice(2), v as EventListener);
      else if (k === 'style') el.setAttribute('style', String(v));
      else el.setAttribute(k, String(v));
    }
  }
  append(el, children);
  return el;
}

function append(el: Node, children: (Child | Child[])[]): void {
  for (const c of children) {
    if (c == null || c === false) continue;
    if (Array.isArray(c)) append(el, c);
    else el.appendChild(typeof c === 'string' ? document.createTextNode(c) : c);
  }
}

export function clear(el: Element): void {
  while (el.firstChild) el.removeChild(el.firstChild);
}

export function setText(el: Element, s: string): void {
  if (el.textContent !== s) el.textContent = s;
}

export function toggle(el: Element, cls: string, on: boolean): void {
  if (on) el.classList.add(cls);
  else el.classList.remove(cls);
}

/** Image that hides itself on error (providers ship many dead logo URLs). */
export function img(src: string | null, cls: string): HTMLImageElement {
  const i = h('img', { class: cls });
  i.onerror = () => i.classList.add('broken');
  if (src) i.src = src;
  else i.classList.add('broken');
  return i;
}

export function initials(name: string): string {
  const words = name.replace(/[^\wÀ-ɏ ]+/g, ' ').trim().split(/\s+/);
  return ((words[0] || '').charAt(0) + (words[1] || '').charAt(0)).toUpperCase() || '•';
}

export function fmtTime(ms: number): string {
  const d = new Date(ms);
  const two = (n: number) => (n < 10 ? '0' : '') + n;
  return two(d.getHours()) + ':' + two(d.getMinutes());
}

export function fmtDuration(secs: number): string {
  secs = Math.max(0, Math.floor(secs));
  const hh = Math.floor(secs / 3600);
  const mm = Math.floor((secs % 3600) / 60);
  const ss = secs % 60;
  const two = (n: number) => (n < 10 ? '0' : '') + n;
  return (hh ? hh + ':' + two(mm) : String(mm)) + ':' + two(ss);
}

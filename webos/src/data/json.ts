// Normalisation helpers for loosely typed Xtream JSON (ported from the
// Flutter app's json_utils.dart). PHP panels send the same field as 1, "1",
// 1.0, null, "", "null", false or [] — every helper accepts anything and
// never throws.

export function asInt(v: unknown): number | null {
  if (v == null) return null;
  if (typeof v === 'number') return isFinite(v) ? Math.trunc(v) : null;
  if (typeof v === 'boolean') return v ? 1 : 0;
  if (typeof v === 'string') {
    const s = v.trim();
    if (!s) return null;
    const d = Number(s);
    return isFinite(d) ? Math.trunc(d) : null;
  }
  return null;
}

export function asDouble(v: unknown): number | null {
  if (v == null || typeof v === 'boolean') return null;
  if (typeof v === 'number') return isFinite(v) ? v : null;
  if (typeof v === 'string') {
    let s = v.trim();
    if (!s) return null;
    if (s.indexOf('.') < 0 && s.split(',').length === 2) s = s.replace(',', '.');
    const d = Number(s);
    return isFinite(d) ? d : null;
  }
  return null;
}

export function asString(v: unknown): string | null {
  if (v == null) return null;
  if (typeof v === 'string') {
    const s = v.trim();
    if (!s || s.toLowerCase() === 'null') return null;
    return s;
  }
  if (typeof v === 'number') return isFinite(v) ? String(v) : null;
  return null;
}

/** Provider id as a string: 1001, 1001.0 and " 1001 " → "1001". */
export function asId(v: unknown): string | null {
  if (typeof v === 'number') return isFinite(v) ? String(v) : null;
  if (typeof v === 'string') return asString(v);
  return null;
}

export function asList(v: unknown): unknown[] {
  return Array.isArray(v) ? v : [];
}

export function asMap(v: unknown): Record<string, unknown> {
  return v && typeof v === 'object' && !Array.isArray(v) ? (v as Record<string, unknown>) : {};
}

/** Lenient JSON.parse: strips a BOM and leading PHP warnings before the JSON. */
export function parseJsonLenient(text: string): unknown {
  let s = text.charCodeAt(0) === 0xfeff ? text.slice(1) : text;
  try {
    return JSON.parse(s);
  } catch (e) {
    const i = firstJsonStart(s);
    if (i > 0) {
      s = s.slice(i);
      return JSON.parse(s);
    }
    throw e;
  }
}

function firstJsonStart(s: string): number {
  const a = s.indexOf('[');
  const o = s.indexOf('{');
  if (a < 0) return o;
  if (o < 0) return a;
  return Math.min(a, o);
}

const base64Shape = /^[A-Za-z0-9+/\-_]+={0,2}$/;

/** Decodes a base64 EPG title/description when it looks like one; else returns it unchanged. */
export function decodeMaybeBase64(value: string | null): string | null {
  if (value == null) return null;
  const s = value.trim();
  if (!s) return s;
  const compact = s.replace(/[\r\n]/g, '');
  if (compact.length % 4 !== 0 || !base64Shape.test(compact)) return s;
  let decoded: string;
  try {
    const bin = atobSafe(compact.replace(/-/g, '+').replace(/_/g, '/'));
    decoded = utf8FromBinary(bin);
  } catch (e) {
    return s;
  }
  return looksLikeText(decoded) ? decoded.trim() : s;
}

function atobSafe(s: string): string {
  if (typeof atob === 'function') return atob(s);
  // Node (tests) path.
  const B = (globalThis as unknown as { Buffer?: { from(s: string, e: string): { toString(e: string): string } } }).Buffer;
  if (!B) throw new Error('no base64 decoder');
  return B.from(s, 'base64').toString('binary');
}

/** atob() returns Latin-1 "bytes"; turn them into UTF-8 text (strict). */
export function utf8FromBinary(bin: string): string {
  return decodeURIComponent(escape(bin));
}

function looksLikeText(s: string): boolean {
  if (!s) return true;
  let good = 0;
  let total = 0;
  for (let i = 0; i < s.length; i++) {
    const c = s.charCodeAt(i);
    total++;
    const ws = c === 0x09 || c === 0x0a || c === 0x0d;
    if (c < 0x20 && !ws) return false;
    if (c === 0x7f || c === 0xfffd) return false;
    if (c === 0x20 || ws || (c >= 0x30 && c <= 0x39) || (c >= 0x41 && c <= 0x5a) || (c >= 0x61 && c <= 0x7a) || c >= 0xc0) good++;
  }
  return good * 10 >= total * 6;
}

/** Epoch seconds (number or numeric string) → ms, else null. */
export function asEpochMs(v: unknown): number | null {
  const i = asInt(v);
  return i == null || i <= 0 ? null : i * 1000;
}

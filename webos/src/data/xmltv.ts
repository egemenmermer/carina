// Light XMLTV reader for M3U playlists that announce url-tvg. Full guides
// are often 50–200 MB and gzipped; the TV has neither the RAM nor a gzip
// stream decoder (Chrome 53), so we only read plain XML up to a size cap and
// keep a short window of programmes for channels we actually have.
import type { Programme } from './models';
import { HttpError } from './http';

export const XMLTV_MAX_BYTES = 12 * 1024 * 1024;

/** "20261022120000 +0300" → epoch ms (null when malformed). */
export function parseXmltvTime(s: string): number | null {
  const m = /^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})?\s*([+-]\d{2}):?(\d{2})?/.exec(s.trim());
  if (!m) return null;
  const utc = Date.UTC(+m[1], +m[2] - 1, +m[3], +m[4], +m[5], m[6] ? +m[6] : 0);
  if (!m[7]) return utc;
  const sign = m[7].charAt(0) === '-' ? -1 : 1;
  const offMin = Math.abs(+m[7]) * 60 + (m[8] ? +m[8] : 0);
  return utc - sign * offMin * 60000;
}

function unescapeXml(s: string): string {
  return s
    .replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, '$1')
    .replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&apos;/g, "'")
    .replace(/&#(\d+);/g, (_m, d) => String.fromCharCode(+d))
    .replace(/&amp;/g, '&')
    .trim();
}

const progRe = /<programme\b([^>]*)>([\s\S]*?)<\/programme>/g;
const attr = (tag: string, name: string): string | null => {
  const m = new RegExp(name + '\\s*=\\s*"([^"]*)"').exec(tag);
  return m ? m[1] : null;
};

/**
 * Programmes per channel id within [from, to]. [wanted] limits the channels
 * kept (lower-cased tvg-ids); null keeps all.
 */
export function parseXmltv(xml: string, from: number, to: number, wanted: Record<string, boolean> | null): Record<string, Programme[]> {
  const out: Record<string, Programme[]> = {};
  progRe.lastIndex = 0;
  let m: RegExpExecArray | null;
  while ((m = progRe.exec(xml))) {
    const ch = attr(m[1], 'channel');
    if (!ch) continue;
    const key = ch.toLowerCase();
    if (wanted && !wanted[key]) continue;
    const start = parseXmltvTime(attr(m[1], 'start') || '');
    const stop = parseXmltvTime(attr(m[1], 'stop') || '');
    if (start == null || stop == null || stop < from || start > to) continue;
    const t = /<title\b[^>]*>([\s\S]*?)<\/title>/.exec(m[2]);
    const d = /<desc\b[^>]*>([\s\S]*?)<\/desc>/.exec(m[2]);
    (out[key] || (out[key] = [])).push({
      title: t ? unescapeXml(t[1]) : '',
      description: d ? unescapeXml(d[1]) : null,
      start,
      stop,
    });
  }
  for (const k of Object.keys(out)) out[k].sort((a, b) => a.start - b.start);
  return out;
}

/** Downloads plain XMLTV text, aborting past [maxBytes]. */
export function fetchXmltvText(url: string, maxBytes = XMLTV_MAX_BYTES): Promise<string> {
  return new Promise((resolve, reject) => {
    if (/\.gz(\?|$)/i.test(url)) {
      reject(new HttpError('gzip', 0));
      return;
    }
    const xhr = new XMLHttpRequest();
    xhr.open('GET', url, true);
    xhr.timeout = 60000;
    xhr.onprogress = (e) => {
      if (e.loaded > maxBytes) {
        xhr.abort();
        reject(new HttpError('too large', 0));
      }
    };
    xhr.onload = () => (xhr.status >= 200 && xhr.status < 300 ? resolve(xhr.responseText) : reject(new HttpError('HTTP ' + xhr.status, xhr.status)));
    xhr.onerror = () => reject(new HttpError('network', 0));
    xhr.ontimeout = () => reject(new HttpError('timeout', 0));
    xhr.send();
  });
}

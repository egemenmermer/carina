"""Generates lib/data/text/src/fold_data.dart from Python's unicodedata.

Usage (from the project root):
    python3 -I test/data/text/gen_fold_data.py lib/data/text/src/fold_data.dart

Rules: letters and numbers in the scanned blocks fold to their NFKD form with
combining marks removed, lowercased, when that is plain ASCII (runs and
multi-character folds); a few letters without a decomposition are folded by
hand (MANUAL); Greek, Cyrillic, Armenian, Hebrew and Arabic letters fold to a
lowercase base letter (case and diacritics removed). Decimal digits of every
script become ASCII digits. The script checks itself before exiting.
"""
import sys
import unicodedata as ud

OUT = sys.argv[1]

def is_alnum_ascii(s):
    return s != '' and all(('a' <= c <= 'z') or ('0' <= c <= '9') for c in s)

def strip_marks(s):
    return ''.join(c for c in s if not ud.combining(c) and ud.category(c)[0] != 'M')

# Letters without a decomposition that should still fold to ASCII.
MANUAL = {
    'æ': 'ae', 'Æ': 'ae', 'ð': 'd', 'Ð': 'd', 'ø': 'o', 'Ø': 'o', 'þ': 'th', 'Þ': 'th',
    'ß': 'ss', 'ẞ': 'ss', 'đ': 'd', 'Đ': 'd', 'ħ': 'h', 'Ħ': 'h', 'ı': 'i', 'ĸ': 'k',
    'ł': 'l', 'Ł': 'l', 'ŋ': 'n', 'Ŋ': 'n', 'œ': 'oe', 'Œ': 'oe', 'ŧ': 't', 'Ŧ': 't',
    'ƀ': 'b', 'Ɓ': 'b', 'ƃ': 'b', 'Ƃ': 'b', 'Ƈ': 'c', 'ƈ': 'c', 'Ɖ': 'd', 'Ɗ': 'd',
    'Ƌ': 'd', 'ƌ': 'd', 'Ǝ': 'e', 'ǝ': 'e', 'Ə': 'e', 'ə': 'e', 'Ɛ': 'e', 'ɛ': 'e',
    'Ƒ': 'f', 'ƒ': 'f', 'Ɠ': 'g', 'ɠ': 'g', 'Ɨ': 'i', 'ɨ': 'i', 'Ƙ': 'k', 'ƙ': 'k',
    'ƚ': 'l', 'Ɲ': 'n', 'ɲ': 'n', 'ƞ': 'n', 'Ɵ': 'o', 'ɵ': 'o', 'Ƥ': 'p', 'ƥ': 'p',
    'ƫ': 't', 'Ƭ': 't', 'ƭ': 't', 'Ʈ': 't', 'ʈ': 't', 'Ʋ': 'v', 'ʋ': 'v', 'Ƴ': 'y',
    'ƴ': 'y', 'Ƶ': 'z', 'ƶ': 'z', 'Ȥ': 'z', 'ȥ': 'z', 'ɓ': 'b', 'ɗ': 'd', 'ɖ': 'd',
    'ɡ': 'g', 'ɦ': 'h', 'ɱ': 'm', 'ɳ': 'n', 'ɽ': 'r', 'ʂ': 's', 'ʐ': 'z', 'ʑ': 'z',
    'ȡ': 'd', 'ȴ': 'l', 'ȵ': 'n', 'ȶ': 't', 'ȷ': 'j', 'ȸ': 'db', 'ȹ': 'qp', 'Ⱥ': 'a',
    'Ȼ': 'c', 'ȼ': 'c', 'Ƚ': 'l', 'Ⱦ': 't', 'ȿ': 's', 'ɀ': 'z', 'Ƀ': 'b', 'Ʉ': 'u',
    'Ɇ': 'e', 'ɇ': 'e', 'Ɉ': 'j', 'ɉ': 'j', 'Ɋ': 'q', 'ɋ': 'q', 'Ɍ': 'r', 'ɍ': 'r',
    'Ɏ': 'y', 'ɏ': 'y', 'Ȣ': 'ou', 'ȣ': 'ou',
    # Small capitals (used for "ʜᴅ", "ꜰʜᴅ", "ᴜʜᴅ" quality markers).
    'ᴀ': 'a', 'ʙ': 'b', 'ᴄ': 'c', 'ᴅ': 'd', 'ᴇ': 'e', 'ꜰ': 'f', 'ɢ': 'g', 'ʜ': 'h',
    'ɪ': 'i', 'ᴊ': 'j', 'ᴋ': 'k', 'ʟ': 'l', 'ᴍ': 'm', 'ɴ': 'n', 'ᴏ': 'o', 'ᴘ': 'p',
    'ʀ': 'r', 'ꜱ': 's', 'ᴛ': 't', 'ᴜ': 'u', 'ᴠ': 'v', 'ᴡ': 'w', 'ʏ': 'y', 'ᴢ': 'z',
}

# Ranges scanned for ASCII folds (letters and numbers only).
ASCII_RANGES = [
    (0x0080, 0x02FF), (0x1D00, 0x1DBF), (0x1E00, 0x1EFF), (0x2070, 0x209F),
    (0x2100, 0x218F), (0x2460, 0x24FF), (0xA720, 0xA7FF), (0xAB30, 0xAB6F),
    (0xFB00, 0xFB06), (0xFF00, 0xFFEF), (0x1D400, 0x1D7FF), (0x1F100, 0x1F1E5),
]
# Ranges scanned for non-ASCII folds (case + diacritics: Greek, Cyrillic,
# Armenian, Hebrew, Arabic).
NON_ASCII_RANGES = [(0x0370, 0x06FF), (0x1F00, 0x1FFF)]

single = {}   # cp -> ascii char
multi = {}    # cp -> ascii string (len > 1)
nonascii = {} # cp -> single non-ascii code unit

for lo, hi in ASCII_RANGES:
    for cp in range(lo, hi + 1):
        ch = chr(cp)
        cat = ud.category(ch)
        if ch in MANUAL:
            r = MANUAL[ch]
        elif cat[0] in 'LN' or (cat == 'So' and (0x2460 <= cp <= 0x24FF or 0x1F100 <= cp <= 0x1F1E5)):
            r = strip_marks(ud.normalize('NFKD', ch)).lower()
            if not is_alnum_ascii(r):
                continue
        else:
            continue
        if len(r) == 1:
            single[cp] = r
        else:
            multi[cp] = r

# Decimal digits of every script -> ASCII digits.
for cp in range(0x80, 0x20000):
    if 0xD800 <= cp <= 0xDFFF:
        continue
    ch = chr(cp)
    if ud.category(ch) == 'Nd' and cp not in single:
        single[cp] = str(ud.decimal(ch))

for lo, hi in NON_ASCII_RANGES:
    for cp in range(lo, hi + 1):
        ch = chr(cp)
        if ud.category(ch)[0] != 'L' or cp in single or cp in multi:
            continue
        r = strip_marks(ud.normalize('NFD', ch)).lower()
        if len(r) == 1 and r != ch and ord(r) < 0x10000:
            if ord(r) < 0x80:
                single[cp] = r
            else:
                nonascii[cp] = ord(r)

# Compress single ASCII folds into runs: start, end, firstAscii, step(0|1).
runs = []
cps = sorted(single)
i = 0
while i < len(cps):
    start = cps[i]
    a = ord(single[start])
    # try step 1 and step 0, take the longer run
    best_end, best_step = start, 0
    for step in (0, 1):
        j = i
        while j + 1 < len(cps) and cps[j + 1] == cps[j] + 1 and ord(single[cps[j + 1]]) == ord(single[cps[j]]) + step:
            j += 1
        if cps[j] > best_end or (cps[j] == best_end and step == 0):
            if cps[j] >= best_end:
                best_end, best_step = cps[j], step
    runs.append((start, best_end, a, best_step))
    i = cps.index(best_end) + 1

lines = []
lines.append('// GENERATED from Python unicodedata %s (NFKD, combining marks removed,' % ud.unidata_version)
lines.append('// lowercased) plus manual folds for letters without a decomposition.')
lines.append('// Do not edit by hand: python3 -I test/data/text/gen_fold_data.py <this file>')
lines.append('')
lines.append('/// Runs of code points that fold to one ASCII character:')
lines.append('/// `start, end, firstAscii, step` (step 0 = same char, 1 = consecutive).')
lines.append('const List<int> foldRuns = [')
for s, e, a, st in runs:
    lines.append('  0x%04X, 0x%04X, 0x%02X, %d, // %s..%s -> %s' % (s, e, a, st, chr(s), chr(e), chr(a) + ('..' + chr(a + (e - s)) if st else '')))
lines.append('];')
lines.append('')
lines.append('/// Code points that fold to more than one ASCII character.')
lines.append('const Map<int, String> foldMulti = {')
for cp in sorted(multi):
    lines.append("  0x%04X: '%s', // %s" % (cp, multi[cp], chr(cp)))
lines.append('};')
lines.append('')
lines.append('/// Non-Latin letters folded to a lowercase base letter (case and')
lines.append('/// diacritics removed: Greek tonos, Cyrillic Ё, Arabic hamza forms…).')
lines.append('const Map<int, int> foldNonAscii = {')
for cp in sorted(nonascii):
    lines.append('  0x%04X: 0x%04X, // %s -> %s' % (cp, nonascii[cp], chr(cp), chr(nonascii[cp])))
lines.append('};')
lines.append('')
open(OUT, 'w', encoding='utf-8').write('\n'.join(lines))
print('runs', len(runs), 'multi', len(multi), 'nonascii', len(nonascii), 'single', len(single))

# Self-check: expanding the runs must reproduce `single` exactly.
expanded = {}
for s, e, a, st in runs:
    for k, cp in enumerate(range(s, e + 1)):
        expanded[cp] = chr(a + k * st)
assert expanded == single, 'run compression mismatch'
for probe, want in [('İ', 'i'), ('I', None), ('ı', 'i'), ('Ş', 's'), ('ş', 's'), ('Ğ', 'g'), ('ğ', 'g'),
                    ('Ç', 'c'), ('ç', 'c'), ('Ö', 'o'), ('Ü', 'u'), ('é', 'e'), ('ñ', 'n'), ('ø', 'o'),
                    ('ý', 'y'), ('ÿ', 'y'), ('ᴴ', 'h'), ('ᴰ', 'd'), ('ᶠ', 'f'), ('ᵁ', 'u'), ('⁴', '4'),
                    ('ᴷ', 'k'), ('ʜ', 'h'), ('ꜰ', 'f'), ('Ｈ', 'h'), ('４', '4'), ('ș', 's'), ('ț', 't'),
                    ('ə', 'e'), ('Ə', 'e'), ('٣', '3'), ('𝐇', 'h'), ('𝟏', '1'), ('Ⓗ', 'h')]:
    got = expanded.get(ord(probe))
    assert got == want, (probe, got, want)
for probe, want in [('ß', 'ss'), ('æ', 'ae'), ('Œ', 'oe'), ('ﬁ', 'fi'), ('Ǆ', 'dz')]:
    assert multi.get(ord(probe)) == want, (probe, multi.get(ord(probe)))
for probe, want in [('Ё', 'е'), ('ά', 'α'), ('Ά', 'α'), ('أ', 'ا'), ('Я', 'я')]:
    assert nonascii.get(ord(probe)) == ord(want), (probe, nonascii.get(ord(probe)))
print('self-check ok')

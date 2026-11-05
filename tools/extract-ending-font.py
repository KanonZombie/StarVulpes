"""Scaled-text font of msprint (GSU 01:CEF0, MDSPRITE.MC `mscalechars`) for the ending texts (USA rev0).

Authority: ref/Star Fox (USA).sfc, SHA-256 3857b529...a84d. msprint reads glyph `code` row `r` at
mscalechars + (code - 1) * 32 + 2 r (getb / getbh: little-endian WORD, bit 15 = leftmost pixel, 16 x 16).
Base: ROM offset 0xA3EDA (build/intro-font-origin.json font_offset, the 26 letters the intro uses).
The ending strings (tools/ending-resources.py) also use 28..37 (digits 0..9), 40 (space) and 65 (%), so
the table is extracted up to code 65 (65 glyphs, 2080 bytes); codes 1..26 must equal
build/intro-text-font.bin, code 40 must be blank.

Output: build/agent-ending/ending-font.bin (65 x 16 WORDs, little-endian as in the ROM),
        build/agent-ending/ending-font.json, build/agent-ending/ending-font.png (sheet, codes 1..65).
Usage: python -I tools/extract-ending-font.py
"""
import hashlib
import json
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ROM = (ROOT / 'ref/Star Fox (USA).sfc').read_bytes()
assert hashlib.sha256(ROM).hexdigest() == '3857b5294ea8f7468849437bb2d8271564e8a0ff30774622e9c872bcbd53a84d'
BASE, CODES = 0xA3EDA, 65
OUT = ROOT / 'build/agent-ending'


def glyph(code):
    o = BASE + (code - 1) * 32
    return [ROM[o + 2 * r] | ROM[o + 2 * r + 1] << 8 for r in range(16)]


def png(path, w, h, rows):
    raw = b''.join(b'\x00' + bytes(r) for r in rows)

    def chunk(t, d):
        return struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xFFFFFFFF)
    path.write_bytes(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 0, 0, 0, 0))
                     + chunk(b'IDAT', zlib.compress(raw)) + chunk(b'IEND', b''))


def main():
    data = ROM[BASE:BASE + CODES * 32]
    intro = (ROOT / 'build/intro-text-font.bin').read_bytes()
    assert data[:len(intro)] == intro, 'codes 1..26 differ from the intro font'
    assert not any(glyph(40)), 'space (40) is not blank'
    res = json.loads((OUT / 'ending-resources.json').read_text(encoding='utf-8'))
    used = res['glyph_codes']
    assert max(used) <= CODES
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / 'ending-font.bin').write_bytes(data)
    cols = 16
    rowsn = (CODES + cols - 1) // cols
    img = [[0] * (cols * 18) for _ in range(rowsn * 18)]
    for code in range(1, CODES + 1):
        gx, gy = ((code - 1) % cols) * 18 + 1, ((code - 1) // cols) * 18 + 1
        for r, word in enumerate(glyph(code)):
            for c in range(16):
                img[gy + r][gx + c] = 255 if word & (0x8000 >> c) else (40 if code in used else 0)
    png(OUT / 'ending-font.png', cols * 18, rowsn * 18, img)
    meta = dict(rom_sha256=hashlib.sha256(ROM).hexdigest(), generator='tools/extract-ending-font.py',
                rom_offset='0x%05X' % BASE, glyphs=CODES, bytes=len(data),
                sha256=hashlib.sha256(data).hexdigest(), equals_intro_font_1_26=True,
                codes_used_by_ending=used, blank_codes=[c for c in range(1, CODES + 1) if not any(glyph(c))],
                layout='glyph code-1, 16 rows, little-endian WORD per row, bit 15 = leftmost pixel')
    (OUT / 'ending-font.json').write_text(json.dumps(meta, indent=1) + '\n', encoding='utf-8')
    print('font', meta['sha256'][:16], 'codes used', used, 'blank', meta['blank_codes'])


if __name__ == '__main__':
    main()

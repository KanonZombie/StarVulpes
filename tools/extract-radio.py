"""Star Fox (USA rev0) radio messages: table, font, faces and palette.

Research tool (standard library only).  Authority: ref/Star Fox (USA).sfc,
SHA-256 below, LoROM without copier header, physical = bank*0x8000 + (addr & 0x7FFF).

What it does
  1. Checks the ROM (size, hash, revision byte) and the code anchors that tie
     every data block to its consumer: send_message_l 03:E993 (table pointer
     01:FBB8, timer 50), friends_messages_l 03:E9EA (text/meter/face positions,
     face base $B9C0, facesounds 03:EB32) and the GSU kernels msprintstr
     01:B4EE / mfprintstr 01:B529 (clip 175/174, font tables 01:E696, 01:D90A,
     01:D996), mshowteammate2 01:B7D1 and mcopyface 01:D15B (ROM bank $17).
  2. Parses the 142 messages (person, sound, colour, NUL-terminated text) and
     checks pointers, bounds, contiguity and that every character has a glyph.
  3. Re-implements the original line layout (mgetlinelen 01:B604 + print loop
     01:B599): wrap at the last space when the accumulated width exceeds the
     clip, 13-pixel line pitch, space glyph = translation value, trans 0 = +5.
  4. Writes PNGs of the 140 glyph slots, the 18 face frames (32x40, 4bpp
     planar, 4 columns x 5 tiles), the palette and preview renders of the
     radio box as the GSU composes it on the 224x192 bitmap.
  5. Optional --check: compares those renders with BizHawk screenshots listed
     in build/research/radio/probe.json (tools/probe-starfox-radio.py).

Outputs: build/research/radio/ (messages.json, manifest.json, PNGs).  Never writes into ref/.
Usage: python tools/extract-radio.py [--check]
"""
from starfox_rom import radio_meter, rom_hex
import argparse
import hashlib
import json
import re
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ROM_PATH = ROOT / 'ref' / 'Star Fox (USA).sfc'
SHA = '3857b5294ea8f7468849437bb2d8271564e8a0ff30774622e9c872bcbd53a84d'
OUT = ROOT / 'build' / 'research' / 'radio'
USF_MSG = ROOT / 'ref/ultrastarfox-main/ultrastarfox-main/SF/MSG/ENGLISH.INC'

MSG_TABLE = (0x01, 0xFBB8)      # word pointers, bank 01
MSG_COUNT = 142
TRN_BASE = (0x01, 0xE696)       # font0trn-32: indexed by character code
WID_BASE = (0x01, 0xD90A)       # font0wid: indexed by translation value
FON_BASE = (0x01, 0xD996)       # font0fon: 24 bytes per glyph (12 rows x 16 bits)
GLYPHS = (0xD996 - 0xD90A)      # 140 slots: the width table ends where glyphs start
FACE_BASE = (0x17, 0xB9C0)      # facedata; frame n at +640*n
FACE_FRAMES = 18
FACE_BYTES = 640
FACESOUNDS = (0x03, 0xEB32)     # 6 persons x 4 (help, down, other, other)
GAMEPAL_CORNERIA = (0x03, 0x8B0A)  # gamepal 3 -> CGRAM row 7 (see sprites.md / extract-sprite-textures.py)
PERSONS = {0: 'fox', 1: 'rabbit (Peppy)', 2: 'falcon (Falco)', 3: 'frog (Slippy)', 4: 'pepper', 5: 'andross'}
SOUNDS = {0: 'help', 1: 'down', 2: 'other'}

# Bytes that must be present: (bank, addr, hex, meaning).
ANCHORS = [
    (0x03, 0xE993, rom_hex(0x1e993, 18), 'send_message_l: id-1, *2, lda.l $01FBB8,x'),
    (0x03, 0xE9B5, rom_hex(0x1e9b5, 16), 'friends_hp-1,y ($18A1+person) ==0 -> discard; meter request $1FFD==$FF'),
    (0x03, 0xE9DD, rom_hex(0x1e9dd, 8), 'msg_count1=50, msg_count2=0'),
    (0x03, 0xE9ED, rom_hex(0x1e9ed, 7), 'gameflags $14D2 & $42 (dying|dead) -> skip'),
    (0x03, 0xEA00, rom_hex(0x1ea00, 5), 'opening frames = 5'),
    (0x03, 0xEA0A, rom_hex(0x1ea0a, 10), 'random&31==0 -> face frame 4'),
    (0x03, 0xEA1A, rom_hex(0x1ea1a, 9), 'mouth animation only while msg_count1>=30'),
    (0x03, 0xEA36, rom_hex(0x1ea36, 6), 'sound $64 when msg_count1 reaches 0'),
    (0x03, 0xEA41, rom_hex(0x1ea41, 14), 'shadow text at (83,170)'),
    (0x03, 0xEA67, rom_hex(0x1ea67, 14), 'text at (82,169)'),
    (0x03, 0xEAB4, rom_hex(0x1eab4, 14), 'meter origin'),
    (0x03, 0xEB13, rom_hex(0x1eb13, 15), 'y-16 if person bit7, andross or meter'),
    (0x03, 0xEB29, rom_hex(0x1eb29, 3), 'y offset 16'),
    (0x03, 0xEB58, rom_hex(0x1eb58, 21), 'face ptr $B9C0+640n, tile column 6, y 152'),
    (0x01, 0xB4FA, rom_hex(0x0b4fa, 3), 'shadow clip 175'),
    (0x01, 0xB504, rom_hex(0x0b504, 2), 'shadow colour 9'),
    (0x01, 0xB535, rom_hex(0x0b535, 3), 'text clip 174'),
    (0x01, 0xB56D, rom_hex(0x0b56d, 6), 'trans base 01:E696, width base 01:D90A'),
    (0x01, 0xB593, rom_hex(0x0b593, 3), 'glyph base 01:D996'),
    (0x01, 0xB5B6, rom_hex(0x0b5b6, 3), 'trans 0: advance 5 (with r9; add #5)'),
    (0x01, 0xB5CF, rom_hex(0x0b5cf, 2), '12 glyph rows'),
    (0x01, 0xB5F9, rom_hex(0x0b5f9, 3), 'line pitch +13 (with r2; add #13)'),
    (0x01, 0xB7D4, rom_hex(0x0b7d4, 2), 'meter box colour 14'),
    (0x01, 0xB7DC, rom_hex(0x0b7dc, 6), 'meter box dimensions'),
    (0x01, 0xB7F9, rom_hex(0x0b7f9, 5), 'meter bar colour and height'),
    (0x01, 0xD15E, rom_hex(0x0d15e, 4), 'mcopyface ROM bank $17'),
    (0x01, 0xD179, rom_hex(0x0d179, 3), 'column stride 768 (24 tiles x 32 bytes)'),
    (0x01, 0xD17F, rom_hex(0x0d17f, 2), '4 tile columns'),
    (0x01, 0xD183, rom_hex(0x0d183, 2), '80 words per column (5 tiles)'),
]


def phys(bank, addr):
    return bank * 0x8000 + (addr & 0x7FFF)


def png(path, width, height, pixels, palette, transparent0=True):
    raw = b''.join(b'\x00' + bytes(row) for row in pixels)

    def chunk(tag, data):
        return struct.pack('>I', len(data)) + tag + data + struct.pack('>I', zlib.crc32(tag + data) & 0xFFFFFFFF)
    data = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 3, 0, 0, 0))
    data += chunk(b'PLTE', b''.join(bytes(c) for c in palette))
    if transparent0:
        data += chunk(b'tRNS', b'\x00' + b'\xff' * (len(palette) - 1))
    data += chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b'')
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    return hashlib.sha256(data).hexdigest()


def read_png_rgb(path):
    """Minimal reader for 8-bit RGB/RGBA non-interlaced PNGs (BizHawk screenshots)."""
    data = path.read_bytes()
    assert data[:8] == b'\x89PNG\r\n\x1a\n'
    pos, idat, w = 8, b'', None
    while pos < len(data):
        n, tag = struct.unpack('>I4s', data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + n]
        if tag == b'IHDR':
            w, h, depth, ctype, _, _, inter = struct.unpack('>IIBBBBB', body)
            assert depth == 8 and ctype in (2, 6) and inter == 0, (depth, ctype, inter)
            bpp = 3 if ctype == 2 else 4
        elif tag == b'IDAT':
            idat += body
        pos += 12 + n
    raw = zlib.decompress(idat)
    stride = w * bpp
    rows, prev = [], bytearray(stride)
    for y in range(h):
        f = raw[y * (stride + 1)]
        line = bytearray(raw[y * (stride + 1) + 1:(y + 1) * (stride + 1)])
        for i in range(stride):
            a = line[i - bpp] if i >= bpp else 0
            b = prev[i]
            c = prev[i - bpp] if i >= bpp else 0
            if f == 1: line[i] = (line[i] + a) & 255
            elif f == 2: line[i] = (line[i] + b) & 255
            elif f == 3: line[i] = (line[i] + (a + b) // 2) & 255
            elif f == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                line[i] = (line[i] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        rows.append([tuple(line[x * bpp:x * bpp + 3]) for x in range(w)])
        prev = line
    return w, h, rows


def bgr555_rgb(c):
    r, g, b = c & 31, (c >> 5) & 31, (c >> 10) & 31
    return ((r << 3) | (r >> 2), (g << 3) | (g >> 2), (b << 3) | (b >> 2))


class Radio:
    def __init__(self, rom):
        self.rom = rom
        self.trn = [rom[phys(*TRN_BASE) + c] for c in range(256)]
        self.wid = [rom[phys(*WID_BASE) + t] for t in range(256)]

    def glyph(self, t):
        """12 rows of pixel lists; row word = byte0 | byte1<<8, pixel i = bit 15-i (GSU: getb, getbh, add r0)."""
        p = phys(*FON_BASE) + 24 * t
        rows = []
        for r in range(12):
            w = self.rom[p + 2 * r] | self.rom[p + 2 * r + 1] << 8
            rows.append([(w >> (15 - i)) & 1 for i in range(16)])
        return rows

    def layout(self, text, x1, clip_abs):
        """Original mgetlinelen + print loop. Returns list of lines: [(char codes)], each with x positions."""
        clip = clip_abs - x1
        data = list(text) + [0]
        pos, lines = 0, []
        while True:
            lastspace, lastnum, lastlen = pos, 0, 0
            linelen, chars, wrap, i = 0, [], None, pos
            while True:
                c = data[i]
                i += 1
                if c == 0:
                    break
                if not clip >= linelen:          # cmp rlinelen / bcs .notwrap
                    i = lastspace
                    chars = chars[:lastnum]
                    linelen = lastlen
                    wrap = i
                    break
                if c == 32:
                    lastspace, lastnum, lastlen = i, len(chars), linelen
                t = self.trn[c]
                linelen += self.wid[t]
                chars.append(c)
            placed, x = [], x1
            for c in chars:
                t = self.trn[c]
                if t == 0:
                    x += 5
                    continue
                placed.append((c, t, x))
                x += self.wid[t]
            lines.append(dict(text=bytes(chars).decode('latin1'), glyphs=placed, width=x - x1))
            if wrap is None:
                return lines
            pos = wrap

    def text_pixels(self, text, x1, y1, clip_abs, colour, canvas):
        y = y1
        lines = self.layout(text, x1, clip_abs)
        for line in lines:
            for _, t, x in line['glyphs']:
                w = self.wid[t]
                if w == 0:
                    continue
                for r, row in enumerate(self.glyph(t)):
                    for i in range(w):
                        if row[i]:
                            plot(canvas, x + i, y + r, colour)
            y += 13
        return lines

    def face_pixels(self, frame):
        base = phys(*FACE_BASE) + FACE_BYTES * frame
        img = [[0] * 32 for _ in range(40)]
        for col in range(4):
            for tile in range(5):
                t = base + col * 160 + tile * 32
                for r in range(8):
                    b0, b1 = self.rom[t + 2 * r], self.rom[t + 2 * r + 1]
                    b2, b3 = self.rom[t + 16 + 2 * r], self.rom[t + 17 + 2 * r]
                    for i in range(8):
                        s = 7 - i
                        v = ((b0 >> s) & 1) | ((b1 >> s) & 1) << 1 | ((b2 >> s) & 1) << 2 | ((b3 >> s) & 1) << 3
                        img[tile * 8 + r][col * 8 + i] = v
        return img


def plot(canvas, x, y, colour):
    # Only within the 224x192 GSU bitmap; rows >= 192 are reported, not drawn (effect on SNES [H]).
    if 0 <= x < 224 and 0 <= y < 192:
        canvas[y][x] = colour
    else:
        canvas_overflow.append((x, y))


canvas_overflow = []


def compose(radio, msg, frame, meter_value=None, canvas=None):
    """Radio box exactly as friends_messages_l draws it in one tick (after the 3D frame)."""
    if canvas is None:
        canvas = [[0] * 224 for _ in range(192)]
    if frame is not None:
        img = radio.face_pixels(frame)
        for y in range(40):
            canvas[152 + y][48:80] = img[y]        # stw: copies whole words, index 0 included
    if msg is not None:
        down = 16 if (msg['person_raw'] & 0x80 or msg['person_raw'] & 0x7F == 5 or meter_value is not None) else 0
        text = msg['bytes'] if 'bytes' in msg else msg['text'].encode('latin1')
        radio.text_pixels(text, 83, 170 - down, 175, 9, canvas)
        radio.text_pixels(text, 82, 169 - down, 174, msg['colour'], canvas)
        if meter_value is not None:
            (x, y, width, height), (fill_x, fill_y, fill_height) = radio_meter()
            for i in range(width):
                plot(canvas, x + i, y, 14)
                plot(canvas, x + i, y + height - 1, 14)
            for j in range(1, height - 1):
                plot(canvas, x, y + j, 14)
                plot(canvas, x + width - 1, y + j, 14)
            if meter_value & 0xFF:
                for j in range(fill_height):
                    for i in range(meter_value):
                        plot(canvas, fill_x + i, fill_y + j, 2)
    return canvas


def usf_messages():
    if not USF_MSG.exists():
        return None
    out = []
    for line in USF_MSG.read_text(encoding='latin1').splitlines():
        m = re.match(r'\s*message\s+(\w+),(\w+),<(.*)>,?(\w*)', line)
        if m:
            out.append(dict(colour=m.group(1), person=m.group(2), text=m.group(3), sound=m.group(4) or 'other'))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--check', action='store_true', help='compare renders with probe screenshots')
    args = ap.parse_args()
    rom = ROM_PATH.read_bytes()
    assert len(rom) == 1048576, 'expected 1 MiB without copier header'
    assert hashlib.sha256(rom).hexdigest() == SHA, 'wrong ROM'
    assert rom[0x7FDB] == 0, 'expected revision 0'
    assert rom[0x7FC0:0x7FD5].rstrip(b' ') == b'STAR FOX', rom[0x7FC0:0x7FD5]
    for bank, addr, hx, what in ANCHORS:
        got = rom[phys(bank, addr):phys(bank, addr) + len(hx) // 2].hex()
        assert got == hx, f'anchor {bank:02X}:{addr:04X} ({what}): {got} != {hx}'
    radio = Radio(rom)
    manifest = dict(rom=str(ROM_PATH.relative_to(ROOT)).replace('\\', '/'), sha256=SHA,
                    generator='tools/extract-radio.py', anchors=[dict(addr=f'{b:02X}:{a:04X}', bytes=h, meaning=w)
                                                                for b, a, h, w in ANCHORS], blocks={}, files={})

    def block(name, bank, addr, size, note):
        p = phys(bank, addr)
        assert (addr & 0x8000) and (addr & 0x7FFF) + size <= 0x8000, f'{name} crosses a LoROM bank'
        manifest['blocks'][name] = dict(addr=f'{bank:02X}:{addr:04X}', rom_offset=f'0x{p:06X}', size=size,
                                        sha256=hashlib.sha256(rom[p:p + size]).hexdigest(), note=note)

    # ---- messages
    tp = phys(*MSG_TABLE)
    ptrs = [rom[tp + 2 * i] | rom[tp + 2 * i + 1] << 8 for i in range(MSG_COUNT)]
    assert rom[tp + 2 * MSG_COUNT:tp + 2 * MSG_COUNT + 2] == b'\xff\xff', 'table not followed by $FFFF'
    first = ptrs[0]
    messages, expect = [], first
    for i, ptr in enumerate(ptrs):
        assert ptr == expect, f'message {i + 1} not contiguous: {ptr:04X} != {expect:04X}'
        p = phys(0x01, ptr)
        person, sound, colour = rom[p], rom[p + 1], rom[p + 2]
        end = rom.index(0, p + 3)
        text = rom[p + 3:end]
        assert person & 0x7F <= 5 and sound <= 2 and 1 <= colour <= 15, (i + 1, person, sound, colour)
        assert all(32 <= c < 127 for c in text), (i + 1, text)
        missing = sorted({chr(c) for c in text if c != 32 and radio.trn[c] == 0})
        assert not missing, f'message {i + 1}: characters without glyph {missing}'
        layout_plain = radio.layout(text, 82, 174)
        messages.append(dict(id=i + 1, addr=f'01:{ptr:04X}', rom_offset=f'0x{p:06X}', person_raw=person,
                             person=PERSONS[person & 0x7F], three_lines_flag=bool(person & 0x80),
                             sound=SOUNDS[sound], sound_raw=sound, colour=colour, text=text.decode('latin1'),
                             bytes=text, face_frames=[(person & 0x7F) * 2 + 5, (person & 0x7F) * 2 + 6],
                             lines_at_x82=[l['text'] for l in layout_plain],
                             line_widths=[l['width'] for l in layout_plain]))
        expect = (end + 1 - 0x8000 * 0x01) & 0x7FFF | 0x8000
    assert expect == MSG_TABLE[1], f'messages end at {expect:04X}, table at {MSG_TABLE[1]:04X}'
    block('message_pointers', *MSG_TABLE, 2 * MSG_COUNT, '142 little-endian words -> bank 01')
    block('message_data', 0x01, first, MSG_TABLE[1] - first, 'person, sound, colour, text, 0')

    # comparison with UltraStarFox ENGLISH.INC (orientation only)
    usf = usf_messages()
    usf_map = {'fox': 0, 'rabbit': 1, 'falcon': 2, 'frog': 3, 'pepper': 4, 'andross': 5}
    diffs = []
    if usf:
        assert len(usf) == MSG_COUNT
        for m, u in zip(messages, usf):
            up = usf_map[u['person'].rstrip('3')] | (0x80 if u['person'].endswith('3') else 0)
            if u['text'] != m['text'] or up != m['person_raw'] or u['sound'] != m['sound']:
                diffs.append(dict(id=m['id'], rom=[m['person_raw'], m['sound'], m['text']],
                                  usf=[up, u['sound'], u['text']]))
    manifest['usf_english_inc_differences'] = diffs

    # ---- font
    used = sorted({c for m in messages for c in m['bytes']})
    trn_used = max(c for c in range(256) if radio.trn[c] and c < 128)
    block('font_translation', 0x01, 0xE696 + 32, 96, 'trans[c-32] for c = 32..127 (base 01:E696 = table-32)')
    block('font_widths', *WID_BASE, GLYPHS, 'width per translation value (pixels plotted and advance)')
    block('font_glyphs', *FON_BASE, GLYPHS * 24, '140 x 24 bytes: 12 rows, word = b0|b1<<8, bit15 = left')
    assert phys(*FON_BASE) + GLYPHS * 24 == phys(0x01, 0xE6B6), 'glyphs must end at the translation table'
    assert all(radio.trn[c] < GLYPHS for c in range(32, 128))
    sheet_w, sheet_h = 20 * 18, 7 * 14
    sheet = [[0] * sheet_w for _ in range(sheet_h)]
    for t in range(GLYPHS):
        gx, gy = (t % 20) * 18, (t // 20) * 14
        for r, row in enumerate(radio.glyph(t)):
            for i in range(16):
                sheet[gy + r][gx + i] = (1 if row[i] else 0) if i < radio.wid[t] else (3 if row[i] else 2)
    pal_font = [(0, 0, 0), (255, 255, 255), (40, 40, 60), (255, 64, 64)]
    manifest['files']['font_glyphs.png'] = png(OUT / 'font_glyphs.png', sheet_w, sheet_h, sheet, pal_font, False)
    font_json = dict(translation={chr(c): radio.trn[c] for c in range(32, 127)},
                     widths=radio.wid[:GLYPHS], used_characters=''.join(chr(c) for c in used),
                     note=('glyph t at 01:D996+24t; pixel colour = message colour (text) or 9 (shadow); '
                           'white = plotted pixels inside the width, red = bits beyond the width (not plotted)'))

    # ---- faces
    block('faces', *FACE_BASE, FACE_FRAMES * FACE_BYTES,
          '18 x 640 bytes: 4 columns x 5 SNES 4bpp tiles (column-major, as the GSU bitmap)')
    p = phys(*FACE_BASE)
    gp = phys(*GAMEPAL_CORNERIA)
    pal = [bgr555_rgb(rom[gp + 2 * i] | rom[gp + 2 * i + 1] << 8) for i in range(16)]
    block('gamepal_corneria', *GAMEPAL_CORNERIA, 32, 'BGR555 x16, CGRAM row 7 in Corneria (index 0 transparent)')
    names = ['open0', 'open1', 'open2', 'open3', 'open4/static', 'fox1', 'fox2', 'peppy1', 'peppy2', 'falco1',
             'falco2', 'slippy1', 'slippy2', 'pepper1', 'pepper2', 'andross1', 'andross2', 'frame17 (not used by friends_messages_l)']
    faces = []
    fsheet = [[0] * (FACE_FRAMES * 34) for _ in range(40)]
    for f in range(FACE_FRAMES):
        img = radio.face_pixels(f)
        manifest['files'][f'faces/face_{f:02d}.png'] = png(OUT / f'faces/face_{f:02d}.png', 32, 40, img, pal)
        for y in range(40):
            fsheet[y][f * 34:f * 34 + 32] = img[y]
        faces.append(dict(frame=f, name=names[f], rom_offset=f'0x{p + 640 * f:06X}',
                          sha256=hashlib.sha256(rom[p + 640 * f:p + 640 * (f + 1)]).hexdigest(),
                          colours=sorted({v for row in img for v in row})))
    manifest['files']['faces_sheet.png'] = png(OUT / 'faces_sheet.png', FACE_FRAMES * 34, 40, fsheet, pal)
    fs = phys(*FACESOUNDS)
    facesounds = {PERSONS[i]: [f'${rom[fs + 4 * i + k]:02X}' for k in range(4)] for i in range(6)}
    block('facesounds', *FACESOUNDS, 24, 'trigse id = table[person*4 + sound]')

    # ---- palette
    pal_png = [[i for i in range(16) for _ in range(8)] for _ in range(8)]
    manifest['files']['palette_corneria.png'] = png(OUT / 'palette_corneria.png', 128, 8, pal_png, pal, False)

    # ---- previews (Corneria messages, face mouth closed, full meter if msgwithmeter)
    previews = {1: None, 5: None, 45: None, 25: None, 78: None, 64: None, 7: 40, 47: 40, 27: 40, 15: 30,
                9: 0, 69: 30, 81: 10, 75: 40, 50: None, 13: None}
    bymsg = {m['id']: m for m in messages}
    for mid, meter in previews.items():
        m = bymsg[mid]
        canvas_overflow.clear()
        c = compose(radio, m, m['face_frames'][0], meter)
        crop = [row[40:184] for row in c[136:192]]
        name = f'previews/m{mid:03d}.png'
        manifest['files'][name] = png(OUT / name, 144, 56, crop, pal)
        m.setdefault('preview', name)
        if canvas_overflow:
            m['preview_rows_beyond_bitmap'] = sorted({y for _, y in canvas_overflow})
    for m in messages:   # rows beyond y=191 for every message, without and with meter
        for meter in (None, 40):
            canvas_overflow.clear()
            compose(radio, m, None, meter)
            if canvas_overflow:
                m['overflow_rows' + ('_meter' if meter is not None else '')] = sorted({y for _, y in canvas_overflow})
        del m['bytes']
    manifest['files']['messages.json'] = None
    (OUT / 'font.json').write_text(json.dumps(font_json, indent=1) + '\n')
    msg_doc = dict(rom=manifest['rom'], sha256=SHA, table='01:FBB8', count=MSG_COUNT,
                   persons=PERSONS, facesounds=facesounds, faces=faces, messages=messages)
    text = json.dumps(msg_doc, indent=1, ensure_ascii=False) + '\n'
    (OUT / 'messages.json').write_text(text, encoding='utf-8')
    manifest['files']['messages.json'] = hashlib.sha256(text.encode('utf-8')).hexdigest()

    # ---- optional check against BizHawk screenshots
    if args.check:
        manifest['check'] = check_shots(radio, bymsg, pal)
    (OUT / 'manifest.json').write_text(json.dumps(manifest, indent=1) + '\n')
    print(f'{MSG_COUNT} messages, {GLYPHS} glyphs, {FACE_FRAMES} faces; USF differences: {len(diffs)}')
    if args.check:
        print('GSU window offset in screenshots:', manifest['check']['screen_offset_of_gsu_window'])
        for r in manifest['check']['shots']:
            print(r)


def close(a, b):
    # BizHawk's SNES output does not use the plain c<<3|c>>2 expansion (e.g. 7FFD -> 239,251,255),
    # so colours are compared with a tolerance of 8 per channel; palette entries differ by more.
    return max(abs(a[i] - b[i]) for i in range(3)) <= 8


def check_shots(radio, bymsg, pal_rom):
    """Text/shadow/meter pixels and the best-matching face frame.

    The screen offset of the 224x192 GSU window is searched (dx, dy in 8..23) on
    the first shot with visible text and then used for every shot.  The picture
    on screen is the bitmap of an earlier tick, so text is only compared on shots
    taken while the text is visible (count2 == 5, count1 <= 48), and the face is
    matched against every frame 0..17 (the reported frame is the one presented)."""
    probe = json.loads((OUT / 'probe.json').read_text())
    results, offset = [], None
    for s in probe['shots']:
        if not s['msg_id']:
            continue
        w, h, img = read_png_rgb(OUT / 'shots' / f"{s['name']}.png")
        assert (w, h) == (256, 224), (w, h)
        m = bymsg[s['msg_id']]
        meter = s['meter'] & 0x7F if s['meter'] else None
        row = dict(shot=s['name'], msg=s['msg_id'], count1=s['count1'], count2=s['count2'])
        if s['count2'] == 5 and 0 < s['count1'] <= 48:
            c = compose(radio, m, None, meter)
            pix = [(x, y, c[y][x]) for y in range(136, 192) for x in range(80, 184) if c[y][x]]

            def bad_at(dx, dy):
                return sum(not close(img[y + dy][x + dx], pal_rom[v]) for x, y, v in pix)
            if offset is None:
                offset = min(((bad_at(dx, dy), dx, dy) for dy in range(8, 24) for dx in range(8, 24)))[1:]
            row.update(text_pixels=len(pix), text_mismatches=bad_at(*offset))
        if offset is not None:
            dx, dy = offset
            best = None
            for frame in range(FACE_FRAMES):
                f = radio.face_pixels(frame)
                pix = [(x, y, f[y][x]) for y in range(40) for x in range(32) if f[y][x]]
                bad = sum(not close(img[152 + dy + y][48 + dx + x], pal_rom[v]) for x, y, v in pix)
                if best is None or bad < best[2]:
                    best = (frame, len(pix), bad)
            row.update(face_frame=best[0], face_pixels=best[1], face_mismatches=best[2])
        results.append(row)
    return dict(screen_offset_of_gsu_window=offset, shots=results)


if __name__ == '__main__':
    main()

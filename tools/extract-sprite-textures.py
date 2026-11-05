"""Star Fox (USA rev0) sprite-shape textures, original `mssprite` model and HUD OBJ graphics.

Research tool (standard library only).  Authority: ref/Star Fox (USA).sfc, SHA-256 below,
LoROM without copier header, physical = bank*0x8000 + (addr & 0x7FFF).

What it does
  1. Parses the selected sprite shapes (headers in bank 00), their point/face streams and the
     colour words of their colour table (header+$12, bank 03), following animated tables
     (GSU mdo_colour 01:904F/9076) down to the texture descriptor
     (textureaddrtab 03:8918, texturexytab 03:8A3E).
  2. Cuts every referenced texture frame out of the GSU texture pages (256-byte rows, one texel
     per byte, low or high nibble) and writes indexed PNGs with the Corneria GSU palette
     (CGRAM row 7 <- 03:8B0A, gamepal 3); texel 0 = transparent (CMODE bit0 = 0).
  3. Re-implements the original software-sprite drawer `mssprite` (GSU 01:CCA8, incl. the
     projection 01:CDFA, colour lookup 01:9076, small path 01:CD71 and large path 01:CE3F with
     mdivu3216 01:8183) as a plain Python model (`render_ssprite`) and checks it pixel by pixel
     against an execution of the ROM's own GSU bytes in a small GSU interpreter (semantics from
     ares component/processor/gsu + sfc/coprocessor/superfx, see sprites.md).
  4. Decompresses the HUD OBJ characters (init_sprites_l 03:DAEB: stream ending 14:E0C3 ->
     VRAM word $6800 = OBJ tiles $80..$FF with OBSEL=3) and the OBJ palettes (02:F1C8: CGRAM
     128..255 <- 7F:1360 of the boot palette collection), and renders the HUD elements.

Outputs: build/research/sprites/ (PNGs + manifest.json).  Never writes into ref/.
Usage: python tools/extract-sprite-textures.py [--cases N] [--seed S] [--no-gsu]
"""
from starfox_rom import rom_hex
import argparse
import hashlib
import json
import random
import runpy
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ROM_PATH = ROOT / 'ref' / 'Star Fox (USA).sfc'
SHA = '3857b5294ea8f7468849437bb2d8271564e8a0ff30774622e9c872bcbd53a84d'
OUT = ROOT / 'build' / 'research' / 'sprites'

# Sprite shapes in scope: (name, header CPU address in bank 00, how the original draws it, frames
# shown in play with the strategy that drives colframe).  Strategy facts: sprites.md section 5.
SPRITES = [
    ('smoke', 0xADD5, 'ssprite', '06:8F72/8FA7: colframe $80, +1 mod 8 each tick before drawing, removed when it returns to 0 -> colframes 1..7'),
    ('bouncyball', 0xAEED, 'ssprite', '06:AD53 Hplasma: sflags|=$20, colframe not owned -> gameframe&127, frame = gameframe&1'),
    ('flash_large', 0xB075, 'ssprite', '06:B662/B6E6/B715 muzzle flash (distance >=1000): colframe $80 drawn 0,1,2 then removed -> frames 0,1,0'),
    ('flash_medium', 0xB091, 'ssprite', '06:B662 (distance 500..999): same strategy as flash_large'),
    ('flash_small', 0xB0AD, 'ssprite', '06:B662 (distance <500): same strategy as flash_large'),
    ('explosion', 0xB101, 'ssprite', '06:F45F explode_Istrat sh_size<$40, count1=4; 06:F7AD colframe +1 before drawing -> colframes 1..3'),
    ('explosion2', 0xB11D, 'ssprite', '06:F45F sh_size<$80, count1=6 -> colframes 1..5'),
    ('explosion3', 0xB139, 'ssprite', '06:F45F sh_size<$100, count1=8 -> colframes 1..7'),
    ('explosion4', 0xB155, 'ssprite', '06:F45F sh_size>=$100, count1=8 -> colframes 1..7'),
    ('missile_flame', 0xB219, 'ssprite', '06:916D: sflags|=$20, tx=lo8(parent ymax-24), colframe not owned -> frame = gameframe&1'),
    ('spark', 0xB2A5, 'stub', '06:A066/8D60: created without ssprite; shape opcode $50 reaches 01:8CA2 -> mshowspr 01:A787 = jmp r11 (draws nothing)'),
]
DRAWN_COLFRAMES = {'smoke': [1, 2, 3, 4, 5, 6, 7], 'flash_large': [0, 1, 2], 'flash_medium': [0, 1, 2],
                   'flash_small': [0, 1, 2], 'explosion': [1, 2, 3], 'explosion2': [1, 2, 3, 4, 5],
                   'explosion3': [1, 2, 3, 4, 5, 6, 7], 'explosion4': [1, 2, 3, 4, 5, 6, 7]}

TEXTUREADDRTAB = 0x8918   # bank 03, 3 bytes per texture: addr16, bank
TEXTUREXYTAB = 0x8A3E     # bank 03, word pointers (bank 03) to {mask16, u0 v0 u1 v1 u2 v2 u3 v3}
RECIPTAB = 0x9647         # bank 00, word[n] = min(32767, 32768 // n)
ZTAB = 0x896C             # bank 14, word[z & ~1]
GAMEPAL_CORNERIA = 0x18B0A  # 03:8B0A = 03:8AAA + 3*32 (gamepal 3), CGRAM row 7 in Corneria
GAMEPAL_INTRO = 0x18ACA     # 03:8ACA (gamepal 1), intro/title GSU palette


def phys(bank, addr):
    bank &= 0x7F
    if bank < 0x40:
        return (bank & 0x3F) * 0x8000 + (addr & 0x7FFF)
    if bank < 0x60:
        return ((bank - 0x40) << 16) | (addr & 0xFFFF)
    raise ValueError('not ROM: %02X:%04X' % (bank, addr))


def s16(v):
    v &= 0xFFFF
    return v - 0x10000 if v & 0x8000 else v


def s8(v):
    v &= 0xFF
    return v - 0x100 if v & 0x80 else v


def fq(a, b):
    """GSU FMULT + ROL: bits 30..15 of the signed 16x16 product = floor(a*b / 2^15) & $FFFF."""
    return ((s16(a) * s16(b)) >> 15) & 0xFFFF


class Rom:
    def __init__(self, data):
        self.data = data

    def b(self, bank, addr):
        return self.data[phys(bank, addr)]

    def w(self, bank, addr):
        return self.data[phys(bank, addr)] | (self.data[phys(bank, (addr + 1) & 0xFFFF)] << 8)


# --------------------------------------------------------------------------------------------
# PNG writer (indexed, 8-bit, PLTE + tRNS)

def write_png(path, width, height, pixels, palette, transparent0=True, scale=1):
    """pixels: list of rows of palette indices.  palette: list of (r,g,b)."""
    if scale > 1:
        pixels = [[p for p in row for _ in range(scale)] for row in pixels for _ in range(scale)]
        width, height = width * scale, height * scale
    raw = b''.join(b'\x00' + bytes(row) for row in pixels)

    def chunk(tag, data):
        return struct.pack('>I', len(data)) + tag + data + struct.pack('>I', zlib.crc32(tag + data) & 0xFFFFFFFF)
    png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 3, 0, 0, 0))
    png += chunk(b'PLTE', b''.join(bytes(c) for c in palette))
    if transparent0:
        png += chunk(b'tRNS', b'\x00' + b'\xff' * (len(palette) - 1))
    png += chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b'')
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(png)
    return hashlib.sha256(png).hexdigest()


def bgr555_rgb(c):
    r, g, b = c & 31, (c >> 5) & 31, (c >> 10) & 31
    return ((r << 3) | (r >> 2), (g << 3) | (g >> 2), (b << 3) | (b >> 2))


def palette16(data, offset):
    return [bgr555_rgb(data[offset + 2 * i] | (data[offset + 2 * i + 1] << 8)) for i in range(16)]


# --------------------------------------------------------------------------------------------
# Shape and colour-table parsing (ROM data)

def parse_shape(rom, header):
    p = header & 0x7FFF
    h = rom.data[p:p + 28]
    bank = h[2]
    info = dict(header_cpu='00:%04X' % header, header_phys=p, header_hex=h.hex(),
                points='%02X:%04X' % (bank, h[0] | h[1] << 8), faces='%02X:%04X' % (bank, h[3] | h[4] << 8),
                shift=h[7], xmax=h[10] | h[11] << 8, ymax=h[12] | h[13] << 8, zmax=h[14] | h[15] << 8,
                sh_size=h[16] | h[17] << 8, col_ptr=h[18] | h[19] << 8,
                lod=['%04X' % (h[22 + 2 * i] | h[23 + 2 * i] << 8) for i in range(3)])
    # points: opcode 4 (rotpoints8) count, count*(x,y,z) s8, then 12 (endpoints)
    q = phys(bank, h[0] | h[1] << 8)
    assert rom.data[q] == 4, 'points opcode'
    n = rom.data[q + 1]
    info['points_list'] = [[s8(v) for v in rom.data[q + 2 + 3 * i:q + 5 + 3 * i]] for i in range(n)]
    assert rom.data[q + 2 + 3 * n] == 12
    # faces: 48 vizis n (n*3 bytes), then 20 faces ... -2 | 80 p,colour,size; then 0 endshape
    f = phys(bank, h[3] | h[4] << 8)
    stream = []
    assert rom.data[f] == 48
    nv = rom.data[f + 1]
    stream.append(dict(op='$30 vizis', bytes=rom.data[f:f + 2 + 3 * nv].hex()))
    f += 2 + 3 * nv
    if rom.data[f] == 0x14:
        start = f
        f += 1
        faces = []
        while rom.data[f] not in (0xFE, 0xFF):
            cnt = rom.data[f] & 63
            faces.append(dict(count=cnt, vis=rom.data[f + 1], colour=rom.data[f + 2],
                              normal=[s8(v) for v in rom.data[f + 3:f + 6]], points=list(rom.data[f + 6:f + 6 + cnt])))
            f += 6 + cnt
        f += 1
        stream.append(dict(op='$14 faces', bytes=rom.data[start:f].hex(), faces=faces))
    elif rom.data[f] == 0x50:
        stream.append(dict(op='$50 s_sprite', bytes=rom.data[f:f + 4].hex(), point=rom.data[f + 1],
                           colour=rom.data[f + 2], size=rom.data[f + 3]))
        f += 4
    else:
        raise AssertionError('unexpected face opcode %02X' % rom.data[f])
    assert rom.data[f] == 0, 'endshape'
    stream.append(dict(op='$00 endshape', bytes='00'))
    info['face_stream'] = stream
    return info


def texture_from_word(rom, word):
    """Textured colour word (bit15=0, bit14=1) as decoded by GSU 01:90BC..910D."""
    assert word & 0xC000 == 0x4000, hex(word)
    idx = word & 0x7F
    hi = bool(word & 0x80)
    xy = (word >> 8) & 63
    addr = rom.w(3, TEXTUREADDRTAB + 3 * idx)
    bank = rom.b(3, TEXTUREADDRTAB + 3 * idx + 2)
    xyptr = rom.w(3, TEXTUREXYTAB + 2 * xy)
    mask = rom.w(3, xyptr)
    uv = [rom.b(3, xyptr + 2 + i) for i in range(8)]
    return dict(colour_word='%04X' % word, texture_index=idx, nibble='high' if hi else 'low',
                cmode=4 if hi else 0, xy_index=xy, data='%02X:%04X' % (bank, addr), bank=bank, addr=addr,
                phys=phys(bank, addr), xy_ptr='03:%04X' % xyptr, mask='%04X' % mask,
                width=(mask & 0xFF) + 1, height=(mask >> 8) + 1, uv=uv,
                table_entry='03:%04X' % (TEXTUREADDRTAB + 3 * idx))


def colour_frames(rom, col_ptr, colour_index=0):
    """All frames of the colour word (animated tables) at col_ptr + 2*colour_index (bank 03)."""
    word = rom.w(3, col_ptr + 2 * colour_index)
    if word & 0xC000 == 0x8000:
        off = word & 0x3FFF
        n = rom.b(3, off)
        entries = [rom.w(3, off + 1 + 2 * i) for i in range(n)]
        return dict(word='%04X' % word, anim_table='03:%04X' % (off | 0x8000), n=n), entries
    return dict(word='%04X' % word, anim_table=None, n=1), [word]


def resolve_colour(rom, col_ptr, colour_index, colframe):
    """GSU mdo_colour_ng 01:9076 for the textured case; returns the texture descriptor."""
    word = rom.w(3, col_ptr + 2 * colour_index)
    while word & 0x8000:
        assert not word & 0x4000, 'smooth-shaded colour: not a sprite texture'
        off = word & 0x3FFF
        n = rom.b(3, off)
        word = rom.w(3, (off + 1 + 2 * ((colframe & (n - 1)) & 0xFFFF)) & 0xFFFF)
    if not word & 0x4000:
        return None   # light-sourced/flat colour: m_texturemap = 0 -> mssprite exits
    return texture_from_word(rom, word)


def texture_pixels(rom, tex):
    rows, raw = [], bytearray()
    for y in range(tex['height']):
        line = []
        for x in range(tex['width']):
            byte = rom.data[phys(tex['bank'], (tex['addr'] + y * 256 + x) & 0xFFFF)]
            raw.append(byte)
            line.append(byte >> 4 if tex['nibble'] == 'high' else byte & 15)
        rows.append(line)
    return rows, bytes(raw)


# --------------------------------------------------------------------------------------------
# Port model of the original software sprite (`mssprite` 01:CCA8).  16-bit wrap everywhere,
# conditions on the GSU S/C flags exactly as in the ROM.  Returns plotted (x, y, index) in order.

def neg_flag(v):
    return bool(v & 0x8000)


def project_sprite(rom, bigx, bigy, bigz, size):
    """mfast_projectpnt 01:CDFA (z clamp, near doubling, ztab, centre 112/96)."""
    x, y, z, s = bigx & 0xFFFF, bigy & 0xFFFF, bigz & 0xFFFF, size & 0xFFFF
    if neg_flag(0x3000 - z):
        z = 0x2FFF
    while not neg_flag(0x100 - z):
        s, x, y, z = (2 * s) & 0xFFFF, (2 * x) & 0xFFFF, (2 * y) & 0xFFFF, (2 * z) & 0xFFFF
    k = rom.w(0x14, (ZTAB + (z & 0xFFFE)) & 0xFFFF)
    return (fq(x, k) + 112) & 0xFFFF, (fq(y, k) + 96) & 0xFFFF, fq(s, k)


def divu3216(hi, lo, div):
    """Result of 01:8183 for the ranges used here (hi < div < $8000): floor((hi:lo)/div)."""
    assert 0 <= hi < div < 0x8000
    return ((hi << 16) | lo) // div


def render_ssprite(rom, bigx, bigy, bigz, tx, shift, sh_size, col_ptr, colour_index, colframe, details=None):
    d = details if details is not None else {}
    plots = []
    if not neg_flag(128 - (bigz & 0xFFFF)):          # 01:CCAC  z <= 128 -> nothing
        d['exit'] = 'near'
        return plots
    size = s8(tx) & 0xFFFF                             # sex(dl+$1C)
    for _ in range(shift):                             # 01:CCC2  << sh_shift
        size = (size * 2) & 0xFFFF
    size = (2 * sh_size + size) & 0xFFFF               # 01:CCCA  + 2*sh_size
    if size == 0:
        size = 1
    sx, sy, ps = project_sprite(rom, bigx, bigy, bigz, size)
    d.update(world_size=size, sx=sx, sy=sy, projected=ps)
    if ps == 0:                                        # 01:CCE8
        d['exit'] = 'size0'
        return plots
    if neg_flag(240 - ps):                             # 01:CCF2  clamp to 240 (S flag only)
        ps = 240
    d['size'] = ps
    tex = resolve_colour(rom, col_ptr, colour_index, colframe)
    if tex is None:
        d['exit'] = 'untextured'
        return plots
    texsize = (int(tex['mask'], 16) & 0xFF) + 1
    hi = tex['nibble'] == 'high'
    base, bank = tex['addr'], tex['bank']
    d.update(texture=tex['texture_index'], texsize=texsize)

    def texel(addr):
        byte = rom.data[phys(bank, addr & 0xFFFF)]
        return byte >> 4 if hi else byte & 15

    def plot(x, y, c):
        if c:                                           # CMODE bit0=0: index 0 not written
            plots.append((x & 0xFF, y & 0xFF, c))

    clipright = (223 - ps) & 0xFFFF
    half = (ps >> 1) + (ps & 1)                        # lsr / sbc #-1 = ceil(ps/2)
    x0 = (sx - half) & 0xFFFF
    if neg_flag(x0 - (((-ps) + 1) & 0xFFFF)):          # 01:CD43  wholly left
        d['exit'] = 'left'
        return plots
    if not neg_flag(x0 - 223):                         # 01:CD51  x0 >= 223
        d['exit'] = 'right'
        return plots
    y0 = (sy - half) & 0xFFFF
    d.update(x0=s16(x0), y0=s16(y0))
    if ps < texsize:                                   # 01:CD68 sub/bcc (unsigned)
        d['path'] = 'small'
        recip = rom.w(0, (RECIPTAB + 2 * ps) & 0xFFFF)
        step = fq(texsize << 8, recip)                 # texels*256 per screen pixel
        d['step'] = step
        width, r5, x, acc8 = ps, base, x0, 0
        if neg_flag(x):                                # 01:CD9F left clip
            count = width
            while True:
                acc8 = (acc8 + step) & 0xFFFF
                count -= 1
                x = (x + 1) & 0xFFFF
                if count == 0:
                    d['exit'] = 'leftclip-all'
                    return plots
                if not neg_flag(x):
                    break
            width = count
            r5 = (r5 + ((acc8 >> 8) & 0xFF)) & 0xFFFF   # merge with r7=0
        if neg_flag((clipright - x) & 0xFFFF):         # 01:CDBB right clip
            count, r1 = width, x
            while count:
                if neg_flag(223 - r1):
                    break
                count -= 1
                r1 = (r1 + 1) & 0xFFFF
            width -= count
        acc7, y = 0, y0
        for _ in range(ps):                            # lines = projected size
            if (y & 0xFFFF) <= 192:                    # 01:CDD7 192-y carry: line 192 included
                acc8 = 0
                for j in range(width):
                    col = (acc8 >> 8) & 0xFF
                    plot(x + j, y, texel(r5 + ((acc7 & 0xFF00) | col)))
                    acc8 = (acc8 + step) & 0xFFFF
            acc7 = (acc7 + step) & 0xFFFF
            y = (y + 1) & 0xFFFF
        return plots
    # large path 01:CE3F (projected size >= texture size): texel-major, carry-driven repeats
    d['path'] = 'large'
    scale = 0xFFFF if ps == texsize else divu3216(texsize, 0, ps)
    scale &= 0xFFFE                                    # bic #1
    d['step'] = scale
    count = texsize
    vis = fq(scale >> 1, (223 - x0) & 0xFFFF)          # 01:CE77 texels up to x=223
    if not neg_flag(count - vis - 1):
        count = vis
    frac, x, r5 = 0, x0, base
    if neg_flag(x):                                    # 01:CE86 left clip
        product = (scale >> 1) * ((-s16(x)) & 0xFFFF)  # LMULT (signed, operands < $8000)
        hi_w, lo_w = (product >> 16) & 0xFFFF, product & 0xFFFF
        frac = (lo_w * 2) & 0xFFFF
        skip = ((hi_w << 1) | (lo_w >> 15)) & 0xFFFF
        if neg_flag(skip):
            d['exit'] = 'leftclip-all'
            return plots
        r5 = (r5 + skip) & 0xFFFF
        count = (count - skip) & 0xFFFF
        if neg_flag(count):
            d['exit'] = 'leftclip-all'
            return plots
        x = 0
    if count == 0:
        d['exit'] = 'width0'
        return plots
    row, acc7, y = 0, 0, y0
    while True:
        if neg_flag(y):                                # 01:CEAB line above the window: skipped
            pass
        elif neg_flag(191 - y):                        # below line 191: finished
            return plots
        else:
            addr = (r5 + (row << 8)) & 0xFFFF
            r1, acc = x, frac
            for t in range(count - 1):                 # all texels but the last
                c = texel(addr + t)
                while True:
                    acc += scale
                    carry = acc > 0xFFFF
                    acc &= 0xFFFF
                    plot(r1, y, c)
                    r1 = (r1 + 1) & 0xFFFF
                    if carry:
                        break
            c = texel(addr + count - 1)                # last texel: per-pixel right clip
            while not neg_flag(223 - r1):
                acc += scale
                carry = acc > 0xFFFF
                acc &= 0xFFFF
                plot(r1, y, c)
                r1 = (r1 + 1) & 0xFFFF
                if carry:
                    break
        borrow = acc7 < scale                          # 01:CEDE r7 -= scale, bcs = no borrow
        acc7 = (acc7 - scale) & 0xFFFF
        y = (y + 1) & 0xFFFF
        if borrow:
            row += 1
            if row == texsize:
                return plots


# --------------------------------------------------------------------------------------------
# Minimal GSU interpreter (enough for 01:CCA8 and callees).  Pipeline, delay slots, ROM buffer
# (R14 writes latch ROMDR with the current ROMBR), prefixes, flags and PLOT as in ares.

class GSU:
    SENTINEL = 0xFFF0

    def __init__(self, rom):
        self.rom = rom
        self.r = [0] * 16
        self.ram = bytearray(0x10000)
        self.alt1 = self.alt2 = self.b = False
        self.sreg = self.dreg = 0
        self.s = self.z = self.cy = self.ov = False
        self.rombr, self.pbr, self.romdr, self.colr, self.por, self.ramaddr = 0, 1, 0, 0, 0, 0
        self.plots, self.steps = [], 0
        self.m14 = self.m15 = False

    def fetch(self, addr):
        return self.rom.data[phys(self.pbr, addr)]

    def setr(self, n, v):
        self.r[n] = v & 0xFFFF
        if n == 14:
            self.m14 = True
        elif n == 15:
            self.m15 = True

    def word(self, a, v=None):
        if v is None:
            return self.ram[a] | (self.ram[a ^ 1] << 8)
        self.ram[a] = v & 255
        self.ram[a ^ 1] = (v >> 8) & 255

    def sr(self):
        return self.r[self.sreg]

    def setdr(self, v):
        self.setr(self.dreg, v)

    def reset(self):
        self.alt1 = self.alt2 = self.b = False
        self.sreg = self.dreg = 0

    def sz(self, v):
        self.s = bool(v & 0x8000)
        self.z = (v & 0xFFFF) == 0

    def pipe(self):
        value = self.pipeline
        self.r[15] = (self.r[15] + 1) & 0xFFFF
        self.pipe_addr = self.r[15]
        self.pipeline = self.fetch(self.r[15])
        self.m15 = False
        return value

    def color(self, src):
        if self.por & 4:
            return (self.colr & 0xF0) | (src >> 4)
        if self.por & 8:
            return (self.colr & 0xF0) | (src & 0x0F)
        return src & 0xFF

    def plot(self):
        x, y = self.r[1] & 0xFF, self.r[2] & 0xFF
        if self.por & 1 or self.colr & 0x0F:          # 4bpp: transparent if low nibble is 0
            c = self.colr
            if self.por & 2 and (x ^ y) & 1:
                c >>= 4
            self.plots.append((x, y, c & 0x0F))
        self.r[1] = (self.r[1] + 1) & 0xFFFF

    def run(self, entry, limit=5_000_000):
        self.pipe_addr = entry
        self.pipeline = self.fetch(entry)
        self.r[15] = (entry + 1) & 0xFFFF
        while True:
            self.steps += 1
            assert self.steps < limit, 'GSU step limit'
            op, addr = self.pipeline, self.pipe_addr
            if addr == self.SENTINEL:
                return
            self.pipe_addr = self.r[15]
            self.pipeline = self.fetch(self.r[15])
            self.m15 = False
            self.execute(op, addr)
            if self.m14:
                self.m14 = False
                self.romdr = self.rom.data[phys(self.rombr, self.r[14])]
            if self.m15:
                self.m15 = False
            else:
                self.r[15] = (self.r[15] + 1) & 0xFFFF

    def execute(self, op, addr):
        n = op & 15
        r = self.r
        if op == 0x00:
            raise AssertionError('STOP at %04X' % addr)
        elif op in (0x01, 0x02):
            self.reset()
        elif op == 0x03:
            v = self.sr()
            self.cy = bool(v & 1)
            self.setdr(v >> 1)
            self.sz(v >> 1)
            self.reset()
        elif op == 0x04:
            v = self.sr()
            res = ((v << 1) | self.cy) & 0xFFFF
            self.cy = bool(v & 0x8000)
            self.setdr(res)
            self.sz(res)
            self.reset()
        elif 0x05 <= op <= 0x0F:
            disp = s8(self.pipe())
            take = {5: True, 6: self.s == self.ov, 7: self.s != self.ov, 8: not self.z, 9: self.z,
                    10: not self.s, 11: self.s, 12: not self.cy, 13: self.cy, 14: not self.ov, 15: self.ov}[op]
            if take:
                self.setr(15, r[15] + disp)
        elif 0x10 <= op <= 0x1F:
            if not self.b:
                self.dreg = n
            else:
                self.setr(n, self.sr())
                self.reset()
        elif 0x20 <= op <= 0x2F:
            self.sreg = self.dreg = n
            self.b = True
        elif 0x30 <= op <= 0x3B:
            self.ramaddr = r[n]
            self.ram[self.ramaddr] = self.sr() & 255
            if not self.alt1:
                self.ram[self.ramaddr ^ 1] = self.sr() >> 8
            self.reset()
        elif op == 0x3C:
            r[12] = (r[12] - 1) & 0xFFFF
            self.sz(r[12])
            if not self.z:
                self.setr(15, r[13])
            self.reset()
        elif op == 0x3D:
            self.b = False
            self.alt1 = True
        elif op == 0x3E:
            self.b = False
            self.alt2 = True
        elif op == 0x3F:
            self.b = False
            self.alt1 = self.alt2 = True
        elif 0x40 <= op <= 0x4B:
            self.ramaddr = r[n]
            v = self.ram[self.ramaddr]
            if not self.alt1:
                v |= self.ram[self.ramaddr ^ 1] << 8
            self.setdr(v)
            self.reset()
        elif op == 0x4C:
            assert not self.alt1, 'RPIX not modelled'
            self.plot()
            self.reset()
        elif op == 0x4D:
            v = self.sr()
            res = ((v >> 8) | (v << 8)) & 0xFFFF
            self.setdr(res)
            self.sz(res)
            self.reset()
        elif op == 0x4E:
            if not self.alt1:
                self.colr = self.color(self.sr() & 0xFF)
            else:
                self.por = self.sr() & 0x1F
            self.reset()
        elif op == 0x4F:
            res = (~self.sr()) & 0xFFFF
            self.setdr(res)
            self.sz(res)
            self.reset()
        elif 0x50 <= op <= 0x5F:
            v = n if self.alt2 else r[n]
            a = self.sr()
            res = a + v + (self.cy if self.alt1 else 0)
            self.ov = bool(~(a ^ v) & (v ^ res) & 0x8000)
            self.s = bool(res & 0x8000)
            self.cy = res >= 0x10000
            self.z = (res & 0xFFFF) == 0
            self.setdr(res)
            self.reset()
        elif 0x60 <= op <= 0x6F:
            v = r[n] if (not self.alt2 or self.alt1) else n
            a = self.sr()
            res = a - v - ((not self.cy) if (not self.alt2 and self.alt1) else 0)
            self.ov = bool((a ^ v) & (a ^ res) & 0x8000)
            self.s = bool(res & 0x8000)
            self.cy = res >= 0
            self.z = (res & 0xFFFF) == 0
            if not (self.alt2 and self.alt1):
                self.setdr(res)
            self.reset()
        elif op == 0x70:
            res = (r[7] & 0xFF00) | (r[8] >> 8)
            self.setdr(res)
            self.ov = bool(res & 0xC0C0)
            self.s = bool(res & 0x8080)
            self.cy = bool(res & 0xE0E0)
            self.z = bool(res & 0xF0F0)
            self.reset()
        elif 0x71 <= op <= 0x7F:
            v = n if self.alt2 else r[n]
            res = self.sr() & ((~v) if self.alt1 else v) & 0xFFFF
            self.setdr(res)
            self.sz(res)
            self.reset()
        elif 0x80 <= op <= 0x8F:
            v = n if self.alt2 else r[n]
            a = self.sr()
            res = ((a & 255) * (v & 255)) if self.alt1 else (s8(a) * s8(v))
            self.setdr(res)
            self.sz(res & 0xFFFF)
            self.reset()
        elif op == 0x90:
            self.ram[self.ramaddr] = self.sr() & 255
            self.ram[self.ramaddr ^ 1] = self.sr() >> 8
            self.reset()
        elif 0x91 <= op <= 0x94:
            self.setr(11, r[15] + n)
            self.reset()
        elif op == 0x95:
            res = s8(self.sr()) & 0xFFFF
            self.setdr(res)
            self.sz(res)
            self.reset()
        elif op == 0x96:
            v = self.sr()
            self.cy = bool(v & 1)
            res = (s16(v) >> 1) + (((v + 1) >> 16) if self.alt1 else 0)
            self.setdr(res)
            self.sz(res & 0xFFFF)
            self.reset()
        elif op == 0x97:
            v = self.sr()
            res = (self.cy << 15) | (v >> 1)
            self.cy = bool(v & 1)
            self.setdr(res)
            self.sz(res)
            self.reset()
        elif 0x98 <= op <= 0x9D:
            assert not self.alt1, 'LJMP not modelled'
            self.setr(15, r[op - 0x90])
            self.reset()
        elif op == 0x9E:
            res = self.sr() & 0xFF
            self.setdr(res)
            self.s = bool(res & 0x80)
            self.z = res == 0
            self.reset()
        elif op == 0x9F:
            product = (s16(self.sr()) * s16(r[6])) & 0xFFFFFFFF
            if self.alt1:
                self.setr(4, product)
            res = product >> 16
            self.setdr(res)
            self.s = bool(res & 0x8000)
            self.cy = bool(product & 0x8000)
            self.z = res == 0
            self.reset()
        elif 0xA0 <= op <= 0xAF:
            if self.alt1:
                self.ramaddr = self.pipe() << 1
                self.setr(n, self.word(self.ramaddr))
            elif self.alt2:
                self.ramaddr = self.pipe() << 1
                self.word(self.ramaddr, r[n])
            else:
                self.setr(n, s8(self.pipe()))
            self.reset()
        elif 0xB0 <= op <= 0xBF:
            if not self.b:
                self.sreg = n
            else:
                res = r[n]
                self.setdr(res)
                self.ov = bool(res & 0x80)
                self.sz(res)
                self.reset()
        elif op == 0xC0:
            res = self.sr() >> 8
            self.setdr(res)
            self.s = bool(res & 0x80)
            self.z = res == 0
            self.reset()
        elif 0xC1 <= op <= 0xCF:
            v = n if self.alt2 else r[n]
            res = (self.sr() ^ v) if self.alt1 else (self.sr() | v)
            self.setdr(res)
            self.sz(res)
            self.reset()
        elif 0xD0 <= op <= 0xDE:
            self.setr(n, r[n] + 1)
            self.sz(r[n])
            self.reset()
        elif op == 0xDF:
            if not self.alt2:
                self.colr = self.color(self.romdr)
            elif not self.alt1:
                pass                                   # RAMB: single RAM bank modelled
            else:
                self.rombr = self.sr() & 0x7F
            self.reset()
        elif 0xE0 <= op <= 0xEE:
            self.setr(n, r[n] - 1)
            self.sz(r[n])
            self.reset()
        elif op == 0xEF:
            mode = (self.alt2 << 1) | self.alt1
            v = self.romdr
            res = [v, (v << 8) | (self.sr() & 255), (self.sr() & 0xFF00) | v, s8(v) & 0xFFFF][mode]
            self.setdr(res)
            self.reset()
        else:   # 0xF0..0xFF
            lo = self.pipe()
            hi = self.pipe()
            if self.alt1:
                self.ramaddr = lo | hi << 8
                self.setr(n, self.word(self.ramaddr))
            elif self.alt2:
                self.ramaddr = lo | hi << 8
                self.word(self.ramaddr, r[n])
            else:
                self.setr(n, lo | hi << 8)
            self.reset()


def gsu_ssprite(rom, bigx, bigy, bigz, tx, shift, sh_size, col_ptr, colour_index, colframe, shapebank=0x11):
    """Executes the ROM's mssprite (01:CCA8) with the RAM a drawlist entry would leave (01:AEBB..AEED)."""
    g = GSU(rom)
    for addr, value in {0x26: bigx, 0x28: bigy, 0x2A: bigz, 0xBC: s8(tx), 0x32: shift, 0x98: sh_size,
                        0xC4: colour_index, 0x4A: col_ptr, 0x46: colframe, 0x34: 112, 0x36: 96,
                        0x1C: shapebank, 0x58: 0x0400}.items():
        g.word(addr, value & 0xFFFF)
    g.por = 4                      # stale CMODE from earlier objects must not matter
    g.r[10] = 0x1E00               # GSU stack (r10) in free RAM
    g.r[11] = GSU.SENTINEL         # return address pushed by mssprite
    g.run(0xCCA8)
    return g.plots, g.steps


# --------------------------------------------------------------------------------------------
# HUD OBJ graphics

HUD = [
    # name, OAM entries (x, y, tile, attr) exactly as written by the 65816 routine, source, note
    ('lives', [(16, 17, 0xBD, 0x20), (24, 17, 0xE2, 0x20), (32, 17, 0xE3 + 2, 0x20)], '03:DBDD do_lives',
     'tile 3 = $E3 + max(lives($16EE),1) - 1; example drawn with lives=3'),
    ('shield_label', [(24, 183, 0xCB, 0x20), (32, 183, 0xCC, 0x20), (40, 183, 0xCD, 0x20), (48, 183, 0xCE, 0x20)],
     '03:DC20 do_shield', 'fixed; the bar itself is drawn by the GSU (01:AFBC)'),
    ('enemy_label', [(128 + 8 * k, 16, 0xF1 + k, 0x20) for k in range(4)], '03:E148 do_enemy',
     'x = 200 - w + 8k with w = m_bossmaxHP (>>1 if >=128); example w=72 (Corneria route 1)'),
    ('bombs', [(225 - 9 * k, 182, 0xBC, 0x20) for k in range(3)], '03:E04E do_spec_weap',
     'one per bomb ($15AF), first at x=225, each next 9 px left; example 3 bombs'),
    ('crosshair', [(0x74, 0x5C, 0xE1, 0x28), (0x84, 0x5C, 0xE1, 0x68), (0x74, 0x6C, 0xE1, 0xA8), (0x84, 0x6C, 0xE1, 0xE8)],
     '03:E0B5 do_crosshair', 'only if $14DD==3 and $15AD!=0; offsets ($16F4,$16F6) = 0 in the example'),
]


def snes_tile(chr_data, tile):
    """4bpp SNES planar tile -> 8 rows of 8 indices."""
    off = (tile - 0x80) * 32
    t = chr_data[off:off + 32]
    rows = []
    for y in range(8):
        p0, p1, p2, p3 = t[2 * y], t[2 * y + 1], t[16 + 2 * y], t[17 + 2 * y]
        rows.append([((p0 >> (7 - x)) & 1) | (((p1 >> (7 - x)) & 1) << 1) | (((p2 >> (7 - x)) & 1) << 2)
                     | (((p3 >> (7 - x)) & 1) << 3) for x in range(8)])
    return rows


def hud_graphics(rom, out):
    decode = runpy.run_path(str(ROOT / 'tools/extract-intro-background.py'))['decode']
    # init_sprites_l 03:DAEB..DB2B (bytes asserted): m_decoffset=0, end 14:E0C3, VRAM word $6800, $1000 bytes
    assert rom.data[0x1DAF5:0x1DB27].hex() == (rom_hex(0x1daf5, 50))
    end = phys(0x14, 0xE0C3)
    window = rom.data[end - 0x4000:end]
    output, trace = decode(window)
    start = end - 0x4000 + trace['source_word_offset']
    again, _ = decode(rom.data[start:end])
    assert again == output and len(output) >= 0x1000
    chr_data = output[:0x1000]
    # palettes: boot collection 0B:E6C0.. (physical BE6C0..BF21C, decoded to 7F:0000); 02:F1C8 DMA 7F:1360, 256 B
    assert rom.data[0x171C8:0x171E3].hex() == rom_hex(0x171c8, 27)
    pals_raw, ptrace = decode(rom.data[0xB8000:0xBF21C])
    assert 0xB8000 + ptrace['source_word_offset'] == 0xBE6C0 and len(pals_raw) == 5120
    obj_pal = [palette16(pals_raw, 0x1360 + 32 * p) for p in range(5)]   # rows 5..7 lie past the 5120 decoded bytes
    files = {}
    # whole OBJ sheet (tiles $80..$FF) with palette 0 and palette 4
    for pal_no in (0, 4):
        rows = [[0] * 128 for _ in range(64)]
        for t in range(128):
            tile = snes_tile(chr_data, 0x80 + t)
            for y in range(8):
                for x in range(8):
                    rows[(t // 16) * 8 + y][(t % 16) * 8 + x] = tile[y][x]
        name = f'hud/obj_tiles_80_FF_pal{pal_no}.png'
        files[name] = write_png(out / name, 128, 64, rows, obj_pal[pal_no], scale=3)
    elements = []
    for name, entries, source, note in HUD:
        xs = [e[0] for e in entries]
        ys = [e[1] for e in entries]
        x0, y0 = min(xs), min(ys)
        w, h = max(xs) - x0 + 8, max(ys) - y0 + 8
        canvas = [[0] * w for _ in range(h)]
        for x, y, tile, attr in entries:
            pix = snes_tile(chr_data, tile)
            if attr & 0x40:
                pix = [row[::-1] for row in pix]
            if attr & 0x80:
                pix = pix[::-1]
            for yy in range(8):
                for xx in range(8):
                    if pix[yy][xx]:
                        canvas[y - y0 + yy][x - x0 + xx] = pix[yy][xx]
        pal_no = (entries[0][3] >> 1) & 7
        fname = f'hud/{name}.png'
        files[fname] = write_png(out / fname, w, h, canvas, obj_pal[pal_no], scale=4)
        elements.append(dict(name=name, source=source, note=note, png=fname, palette=pal_no,
                             cgram_row=8 + pal_no, priority=(entries[0][3] >> 4) & 3,
                             oam=[dict(x=x, y=y, tile='%02X' % t, attr='%02X' % a) for x, y, t, a in entries]))
    # digits used by the lives counter ($E3.. ) for reference
    rows = [[0] * 80 for _ in range(8)]
    for k in range(10):
        pix = snes_tile(chr_data, 0xE3 + k)
        for y in range(8):
            for x in range(8):
                rows[y][k * 8 + x] = pix[y][x]
    files['hud/tiles_E3_EC.png'] = write_png(out / 'hud/tiles_E3_EC.png', 80, 8, rows, obj_pal[0], scale=4)
    # whole-screen layout example (256x224, OAM y as written; SNES shows OBJ one line lower)
    screen = [[0] * 256 for _ in range(224)]
    for name, entries, source, note in HUD:
        if name == 'crosshair':
            continue
        for x, y, tile, attr in entries:
            pix = snes_tile(chr_data, tile)
            for yy in range(8):
                for xx in range(8):
                    if pix[yy][xx] and y + 1 + yy < 224 and x + xx < 256:
                        screen[y + 1 + yy][x + xx] = pix[yy][xx]
    files['hud/layout_example_256x224.png'] = write_png(out / 'hud/layout_example_256x224.png', 256, 224, screen, obj_pal[0], scale=2)
    return dict(
        chr=dict(routine='init_sprites_l 03:DAEB (decvramnotrans: m_decoffset=0, end 14:E0C3, VRAM word $6800, $1000 bytes)',
                 obsel='OBSEL=3 (02:F19E lda #3 / 02:F1A0 sta $2101): OBJ name base word $6000 -> word $6800 = tile $80',
                 compressed_rom_range='%05X..%05X' % (start, end), compressed_sha256=hashlib.sha256(rom.data[start:end]).hexdigest(),
                 decoded_bytes=len(output), used_bytes=0x1000, used_sha256=hashlib.sha256(chr_data).hexdigest(),
                 tiles='$80..$FF (4bpp SNES planar, 32 bytes/tile)'),
        palette=dict(routine='02:F1C8: DMA 7F:1360 -> CGRAM 128..255 (256 bytes)',
                     collection_rom_range='BE6C0..BF21C (decoded to 7F:0000, 5120 bytes)',
                     rows={str(p): ' '.join('%04X' % (pals_raw[0x1360 + 32 * p + 2 * i] | pals_raw[0x1361 + 32 * p + 2 * i] << 8)
                                           for i in range(16)) for p in range(5)},
                     rows_sha256=hashlib.sha256(pals_raw[0x1360:0x1400]).hexdigest(),
                     note='OBJ palettes 5..7 come from 7F:1400..145F, outside the decoded collection (not used by the HUD)'),
        elements=elements, files=files)


# --------------------------------------------------------------------------------------------

def gsu_check(rom, shapes, cases, seed):
    rnd = random.Random(seed)
    results = dict(cases=0, identical=0, paths={}, exits={}, pixels=0, pixels_on_line_192=0, steps=0, mismatches=[])
    usable = [(n, s) for n, s in shapes if n != 'spark']
    fixed = [  # hand-picked edges: tiny, exact texsize, clamp 240, left/right/top/bottom clipping, z<=256
        ('explosion2', 0, 0, 3000, -2, 1), ('explosion2', 0, 0, 129, 0, 2), ('explosion4', 0, 0, 300, 0, 3),
        ('explosion3', -600, 40, 2000, 0, 4), ('explosion3', 700, -50, 2000, 0, 5), ('smoke', 0, -500, 1300, 0, 6),
        ('smoke', 0, 520, 1300, 0, 7), ('flash_large', 0, 0, 1000, 0, 0), ('bouncyball', 30, 20, 640, 0, 1),
        ('explosion', -10, 0, 256, -8, 2), ('explosion', 0, 0, 200, 0, 3), ('missile_flame', 5, 5, 900, 0, 0),
        ('explosion2', 0, 0, 128, 0, 1), ('explosion2', 0, 0, -100, 0, 1), ('explosion2', 0, 0, -32700, 0, 1),
        ('explosion2', 0, 230, 1500, 0, 1), ('explosion4', -900, 0, 1200, 0, 1), ('explosion4', 0, 400, 700, 0, 1),
    ]
    todo = []
    for name, x, y, z, tx, cf in fixed:
        todo.append((name, x, y, z, tx, cf))
    while len(todo) < cases:
        name = rnd.choice(usable)[0]
        z = rnd.choice([rnd.randint(129, 400), rnd.randint(400, 3000), rnd.randint(3000, 12287), rnd.randint(12288, 20000)])
        spread = max(64, z // 2)
        todo.append((name, rnd.randint(-spread, spread), rnd.randint(-spread, spread), z,
                     rnd.choice([0, 0, -1, -2, -3, -8, 1, 2, 4, rnd.randint(-8, 8)]), rnd.randint(0, 127)))
    info = dict(shapes)
    for name, x, y, z, tx, cf in todo:
        s = info[name]
        args = (x, y, z, tx, s['shift'], s['sh_size'], s['col_ptr'], 0, cf)
        d = {}
        model = render_ssprite(rom, *args, details=d)
        native, steps = gsu_ssprite(rom, *args)
        results['cases'] += 1
        results['steps'] += steps
        results['pixels'] += len(native)
        results['pixels_on_line_192'] += sum(1 for px in native if px[1] == 192)
        key = d.get('path', 'none')
        results['paths'][key] = results['paths'].get(key, 0) + 1
        if 'exit' in d:
            results['exits'][d['exit']] = results['exits'].get(d['exit'], 0) + 1
        if model == native:
            results['identical'] += 1
        elif len(results['mismatches']) < 10:
            results['mismatches'].append(dict(case=[name, x, y, z, tx, cf], model=len(model), native=len(native), details=d))
    return results


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--cases', type=int, default=160)
    ap.add_argument('--seed', type=int, default=1993)
    ap.add_argument('--no-gsu', action='store_true')
    args = ap.parse_args()
    data = ROM_PATH.read_bytes()
    assert len(data) == 1048576 and hashlib.sha256(data).hexdigest() == SHA and data[0x7FDB] == 0
    rom = Rom(data)
    # Code anchors (selected ROM): shape jump table entries, sprite opcode, mshowspr stub, mssprite.
    anchors = {
        'msh $14 faces -> 01:8D14': (0x8014, rom_hex(0x08014, 4)), 'msh $50 s_sprite -> 01:8CA2': (0x8050, rom_hex(0x08050, 4)),
        'mshowspr stub 01:A787 jmp r11': (0xA787, rom_hex(0x0a787, 2)), 'drawlist ssprite test 01:AEBB': (0xAEBB, rom_hex(0x0aebb, 4)),
        'mssprite 01:CCA8': (0xCCA8, rom_hex(0x0cca8, 7)), 'projection 01:CDFA': (0xCDFA, rom_hex(0x0cdfa, 4)),
    }
    for label, (off, hexbytes) in anchors.items():
        assert data[off:off + len(hexbytes) // 2].hex() == hexbytes, label
    OUT.mkdir(parents=True, exist_ok=True)
    pal = palette16(data, GAMEPAL_CORNERIA)
    pal_intro = palette16(data, GAMEPAL_INTRO)
    manifest = dict(rom=str(ROM_PATH.relative_to(ROOT)).replace('\\', '/'), rom_sha256=SHA,
                    palette=dict(corneria='03:8B0A (CGRAM row 7, gamepal 3)', rgb555=data[GAMEPAL_CORNERIA:GAMEPAL_CORNERIA + 32].hex(),
                                 intro='03:8ACA (gamepal 1)', note='texel value = colour index of the GSU 4bpp screen; 0 = not plotted'),
                    textures={}, sprites=[], pages=[])
    # texture pages (context): banks 12 and 13, 256x128 bytes each, low and high nibble
    for bank in (0x12, 0x13):
        for nib in ('low', 'high'):
            rows = []
            for y in range(128):
                row = data[phys(bank, 0x8000 + 256 * y):phys(bank, 0x8000 + 256 * y) + 256]
                rows.append([(b >> 4) if nib == 'high' else (b & 15) for b in row])
            name = f'pages/bank{bank:02X}_{nib}.png'
            write_png(OUT / name, 256, 128, rows, pal, scale=2)
            manifest['pages'].append(dict(png=name, bank='%02X' % bank, phys='%05X..%05X' % (phys(bank, 0x8000), phys(bank, 0x8000) + 0x8000),
                                          nibble=nib, sha256_bank=hashlib.sha256(data[phys(bank, 0x8000):phys(bank, 0x8000) + 0x8000]).hexdigest()))
    shapes = []
    for name, header, path, strategy in SPRITES:
        s = parse_shape(rom, header)
        shapes.append((name, s))
        table, words = colour_frames(rom, s['col_ptr'])
        frames = []
        for i, w in enumerate(words):
            tex = texture_from_word(rom, w)
            key = 't%02X' % tex['texture_index']
            if key not in manifest['textures']:
                rows, raw = texture_pixels(rom, tex)
                fname = f'textures/{key}_{tex["nibble"]}_{tex["width"]}x{tex["height"]}.png'
                png_sha = write_png(OUT / fname, tex['width'], tex['height'], rows, pal, scale=1)
                write_png(OUT / fname.replace('.png', '_intro_pal.png'), tex['width'], tex['height'], rows, pal_intro, scale=1)
                used = sorted({v for row in rows for v in row})
                manifest['textures'][key] = dict(
                    texture_index=tex['texture_index'], data=tex['data'], nibble=tex['nibble'],
                    width=tex['width'], height=tex['height'], mask=tex['mask'], xy_index=tex['xy_index'],
                    rom_rows=[f'{phys(tex["bank"], (tex["addr"] + 256 * y) & 0xFFFF):05X}+{tex["width"]}' for y in (0, tex['height'] - 1)],
                    row_stride=256, raw_sha256=hashlib.sha256(raw).hexdigest(),
                    texels_sha256=hashlib.sha256(bytes(v for row in rows for v in row)).hexdigest(),
                    palette_indices=used, opaque_texels=sum(1 for row in rows for v in row if v),
                    png=fname, png_sha256=png_sha, table_entry=tex['table_entry'])
            frames.append(dict(frame=i, colour_word=tex['colour_word'], texture=key))
        strip = []
        for f in frames:
            t = manifest['textures'][f['texture']]
            tex = texture_from_word(rom, int(f['colour_word'], 16))
            rows, _ = texture_pixels(rom, tex)
            strip.append(rows)
        hmax = max(len(r) for r in strip)
        wsum = sum(len(r[0]) for r in strip) + 2 * (len(strip) - 1)
        canvas = [[0] * wsum for _ in range(hmax)]
        xo = 0
        for rows in strip:
            for y, row in enumerate(rows):
                canvas[y][xo:xo + len(row)] = row
            xo += len(rows[0]) + 2
        strip_name = f'{name}_frames.png'
        write_png(OUT / strip_name, wsum, hmax, canvas, pal, scale=3)
        entry = dict(name=name, header=s['header_cpu'], header_phys='%05X' % s['header_phys'], header_hex=s['header_hex'],
                     points=s['points'], faces=s['faces'], points_list=s['points_list'], face_stream=s['face_stream'],
                     shift=s['shift'], sh_size=s['sh_size'], xmax=s['xmax'], ymax=s['ymax'], zmax=s['zmax'],
                     lod=s['lod'], colour_table='03:%04X' % s['col_ptr'], colour=table, frames=frames,
                     frame_select='colframe & (n-1)' if table['anim_table'] else 'single',
                     draw_path=path, strategy=strategy, drawn_colframes=DRAWN_COLFRAMES.get(name),
                     strip_png=strip_name)
        manifest['sprites'].append(entry)
    manifest['hud'] = hud_graphics(rom, OUT)
    if not args.no_gsu:
        res = gsu_check(rom, shapes, args.cases, args.seed)
        manifest['gsu_check'] = dict(entry='01:CCA8', method='ROM GSU bytes executed by GSU class vs render_ssprite; '
                                     'compares the ordered list of written pixels (x, y, index)', seed=args.seed, **res)
        assert res['identical'] == res['cases'], res['mismatches']
        print('GSU check: %d/%d identical (%s), %d pixels, %d GSU steps' % (res['identical'], res['cases'], res['paths'], res['pixels'], res['steps']))
    (OUT / 'manifest.json').write_text(json.dumps(manifest, indent=1) + '\n', encoding='utf-8')
    print('PASS: %d sprites, %d textures, HUD %d elements -> %s' % (len(manifest['sprites']), len(manifest['textures']),
                                                                   len(manifest['hud']['elements']), OUT.relative_to(ROOT)))


if __name__ == '__main__':
    main()

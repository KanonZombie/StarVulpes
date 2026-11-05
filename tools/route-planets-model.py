"""Star Fox (USA rev0) route-map planets: reference model + correspondence checks.

Authority: ref/Star Fox (USA).sfc, SHA-256 below (rev0, LoROM, no copier header).
Spec and evidence: build/research/route-map-planets.md.

What it does
  1. Python model (semantic translation, 16-bit wrap kept) of the GSU drawers used by the route
     map: mdrawtsphere 01:B807 (+ mvector_from 01:80BC, mnormalise16 01:80C5, sqrt 01:8086,
     mdivu3216 01:8183, mcrotmatzxy16 01:829F, msph_sqrt16 01:B9A1, mgenzlist 01:B9C2,
     mtsphereline 01:BA20, mgenuvlistx 01:BA9A, mdrawuvlistx 01:BB18), mdrawsprite32 01:CBF6 and
     musprite 01:CC59 (scaled path of mssprite from 01:CD23), plus the 65816 logic that feeds
     them: copylight 03:C4FD, spinplanets 03:C57B, setupplanetcoord 03:C9B4, drawplanetsprites
     03:CA67, drawplanetincentre 03:CA08, drawselectedplanet 03:C942, the zoom loop
     03:C23A..C2D5 and the light/comet part of the planets IRQ (ROM 02:849E..869D, executed
     from its WRAM copy, offset $4E6D).
  2. Oracle: executes the ROM's own bytes -- 65816 in tools/cpu65816.py and GSU in
     tools/gsu_interp8.py (8bpp PLOT/RPIX/STOP extension of the sprite-study interpreter) --
     and compares plots, GSU RAM bitmaps and logic state with the model (exact equality).
  3. Cross-check against GSU/WRAM images inside earlier BizHawk savestates (read only, the
     emulator is not run) when they are present and Python has compression.zstd.
  4. Writes build/research/route-planets-check.json and PNGs in build/research/route-planets/,
     including the colour-quantisation study used by the port recommendation.

Usage: python tools/route-planets-model.py [--cases N] [--seed S] [--passes N] [--frames-per-pass K]
Standard library only (zstd needs Python >= 3.14 and is optional).
"""
import argparse
import hashlib
import importlib.util
import json
import random
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import gsu_interp8 as gi  # noqa: E402


def _load(name, file):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'tools' / file)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


C65 = _load('cpu65816_route', 'cpu65816.py')
ROM_PATH = ROOT / 'ref' / 'Star Fox (USA).sfc'
SHA = '3857b5294ea8f7468849437bb2d8271564e8a0ff30774622e9c872bcbd53a84d'
OUT = ROOT / 'build' / 'research' / 'route-planets'
CHECK = ROOT / 'build' / 'research' / 'route-planets-check.json'
STATES = ROOT / '.emulator-mcp' / 'runtime' / 'snes' / 'states'

phys, s8, s16, fq = gi.phys, gi.s8, gi.s16, gi.fq

# ---- ROM addresses (rev0) ------------------------------------------------------------------
PLANETSPRS = 0xD365      # 03: 17 x (id|$80 sphere, rot index*2)
PLANETNAMES = 0xD387     # 03: 17 message ids
PLANETPOS = 0xD398       # 03: 17 x (BG1 tilemap word address, x, y)
STARTPOS = 0xD3DC        # 03: 17 x (x, y) ship path start
ENDPOS = 0xD3FE          # 03: 17 x (x, y)
FADETAB0 = 0xD420        # 03: 16 words, colour 0 fade
PLANSELPAL = 0xD440      # 03: 256 BGR555 words
SPEEDS = 0xC593          # 03: 6 words roty speed
PLANET_ROTZ = 0xC59F     # 03: 6 words rotz
TEXADDR = 0x8918         # 03: 3 bytes per texture (addr16, bank)
SINTAB = 0x99E5          # 00: 257 words, sin * 32767, 256 steps per turn
RECIP = 0x9647           # 00: words, min(32767, 32768 div n)
UVTAB = 0xBBF6           # 01: 2048 words (m_uvtab)
IRQ_SIN = 0xAAD9         # 02: s8 sin table (WRAM copy 7E:5C6C); cos = +64 (7E:5CAC)
WRAM_COPY_OFFSET = 0x4E6D  # ROM 02:xxxx runs at WRAM 7E:(xxxx - $4E6D)

# GSU RAM variables (bank 70) used by the planet code
GV = dict(rotx=0x020, roty=0x022, rotz=0x024, bigx=0x026, bigy=0x028, bigz=0x02A, scale=0x030,
          y1=0x02C, ytop=0x03C, ybot=0x03E, sprdata=0x096, msprite=0x098, pal=0x09A,
          sprsize=0x0B6, sprxscale=0x0BC, rotlight=0x0F4, smat=0x1BE, lx=0x1D0, lxpos=0x1D6,
          lypos=0x1D8, lzpos=0x1DA, xlen=0x198, radius=0x1F2, rr=0x1F6, xc=0x1F8, yc=0x1FA)
GSU_SCBR = 0x0B          # bitmap at 70:2C00 (SCBR = $2C00/1024), 8bpp, height 128
SPHERE_ENTRY, SPRITE32_ENTRY, MUSPRITE_ENTRY, CLEAR_ENTRY = 0xB807, 0xCBF6, 0xCC59, 0xB09B
NAMES = ['Corneria', 'Asteroid Belt (1)', 'Asteroid Belt (3)', 'Sector X', 'Fortuna', 'Titania',
         'Space Armada', 'Sector Z', 'Meteor', 'Sector Y', 'Black Hole', 'Macbeth', 'Venom (1)',
         'Venom (2)', 'Out Of This Dimension', 'Venom (3, sphere)', 'unused (16)']


def u16(v):
    return v & 0xFFFF


def neg(v):
    return bool(v & 0x8000)


def asr16(v):
    return (s16(v) >> 1) & 0xFFFF


def swap(v):
    return ((v >> 8) | (v << 8)) & 0xFFFF


def lmult(a, b):
    """GSU LMULT: signed 16x16 -> (hi16, lo16)."""
    p = (s16(a) * s16(b)) & 0xFFFFFFFF
    return p >> 16, p & 0xFFFF


class Tables:
    def __init__(self, data):
        self.data = data
        self.rom = gi.Rom(data)

    def w(self, bank, addr):
        return self.rom.w(bank, addr & 0xFFFF)

    def b(self, bank, addr):
        return self.rom.b(bank, addr & 0xFFFF)

    def texture(self, tid):
        tid &= 0xFF
        e = (TEXADDR + 3 * tid) & 0xFFFF
        return self.w(3, e), self.b(3, e + 2)

    def planets(self):
        out = []
        for k in range(17):
            spr, rot = self.b(3, PLANETSPRS + 2 * k), self.b(3, PLANETSPRS + 2 * k + 1)
            word = self.w(3, PLANETPOS + 4 * k)
            x, y = self.b(3, PLANETPOS + 4 * k + 2), self.b(3, PLANETPOS + 4 * k + 3)
            tid = spr & 0x7F
            addr, bank = self.texture(tid)
            out.append(dict(index=k, name=NAMES[k], sphere=bool(spr & 0x80), texture=tid, rot_index=rot,
                            texture_addr='%02X:%04X' % (bank if not spr & 0x80 else 0x12, addr),
                            nibble='high' if (spr & 0x80 or tid & 0x20) else 'low',
                            tile_word='%04X' % word, map_x=x, map_y=y, msg=self.b(3, PLANETNAMES + k),
                            cell=k if k < 16 else None,
                            cell_centre=[16 + 32 * (k % 4), 16 + 32 * (k // 4)] if k < 16 else None))
        return out


# =============================================================================================
# GSU routines -- semantic model (bit-exact translation, not an instruction trace)

def m_sqrt32(r4, r5):
    """01:8086: 16 steps of 2 bits; r6 = floor(sqrt(r4:r5)) while 2*root fits 16 bits."""
    r6 = r8 = 0
    for _ in range(16):
        for _ in range(2):
            t = r5 + r5
            r5, cy = t & 0xFFFF, t >> 16
            t = (r4 << 1) | cy
            r4, cy = t & 0xFFFF, t >> 16
            r8 = ((r8 << 1) | cy) & 0xFFFF
        r6 = (r6 * 2) & 0xFFFF
        r7 = (r6 * 2) & 0xFFFF
        if r7 < r8:                                     # bcs not taken: r8 -= r7 + 1
            r8 = (r8 - r7 - 1) & 0xFFFF
            r6 = (r6 + 1) & 0xFFFF
    return r6


def m_div3216(r0, r4, r6):
    """01:8183 mdivu3216: (r0:r4) / r6 -> r4 (both halved first if r0 or r6 has bit 15)."""
    if neg(r0) or neg(r6):
        r6 >>= 1
        cy = r0 & 1
        r0 >>= 1
        r4 = (cy << 15) | (r4 >> 1)
    r4 = (r4 * 2) & 0x1FFFF
    cy, r4 = r4 >> 16, r4 & 0xFFFF
    r0 = ((r0 << 1) | cy) & 0xFFFF
    for _ in range(16):
        t = r0 - r6
        if t >= 0:                                      # no borrow
            r0 = t & 0xFFFF
            t = (r4 << 1) | 1
        else:
            t = r4 << 1
        r4, cy = t & 0xFFFF, t >> 16
        r0 = ((r0 << 1) | cy) & 0xFFFF
    return r4


def m_normalise(v1, v2, v3):
    """01:80C5 mnormalise16: v * ((32767 << k) div |v|) >> k, k = bitlength(|v|) - 1."""
    hi1, lo1 = lmult(v1, v1)
    hi2, lo2 = lmult(v2, v2)
    hi3, lo3 = lmult(v3, v3)
    t = lo1 + lo2
    r5, c = t & 0xFFFF, t >> 16
    r0 = (hi1 + hi2 + c) & 0xFFFF
    t = r5 + lo3
    r5, c = t & 0xFFFF, t >> 16
    r0 = (r0 + hi3 + c) & 0xFFFF
    if r0 == 0 and r5 == 0:
        return 0, 0, 0
    root = m_sqrt32(r0, r5)
    k, t = 0, root >> 1
    while t:
        k += 1
        t >>= 1
    big = 0x7FFF << k
    q = m_div3216((big >> 16) & 0xFFFF, big & 0xFFFF, root)
    out = []
    for v in (v1, v2, v3):
        p = (s16(v) * s16(q)) & 0xFFFFFFFF
        if p & 0x80000000:
            p -= 1 << 32
        out.append((p >> k) & 0xFFFF)
    return tuple(out)


def m_sin(t, angle):
    """Interpolated sine of 01:829F: table 00:99E5 (word per 1/256 turn), fq(frac<<7, delta)."""
    i = (angle >> 8) & 0xFF
    a = t.w(0, SINTAB + 2 * i)
    b = t.w(0, SINTAB + 2 * i + 2)
    return (fq(((angle & 0xFF) << 8) >> 1, (b - a) & 0xFFFF) + a) & 0xFFFF


def m_matrix(t, rx, ry, rz):
    """01:829F mcrotmatzxy16 -> m_mat11..33 (9 words, row-major as stored at 70:0120)."""
    sx, cx = m_sin(t, rx), m_sin(t, rx + 0x4000)
    sy, cy = m_sin(t, ry), m_sin(t, ry + 0x4000)
    sz, cz = m_sin(t, rz), m_sin(t, rz + 0x4000)
    r1, r2, r13, r14 = fq(sy, cz), fq(cy, cz), fq(sy, sz), fq(cy, sz)
    return [u16(fq(r13, sx) + r2), u16(fq(r1, sx) - r14), fq(sy, cx),
            fq(sz, cx), fq(cz, cx), u16(-sx),
            u16(fq(r14, sx) - r1), u16(fq(r2, sx) + r13), fq(cy, cx)]


def m_sqrt16(v):
    """01:B9A1 msph_sqrt16: floor(sqrt(v)) for 16-bit unsigned v."""
    r6 = r4 = 0
    for _ in range(8):
        for _ in range(2):
            t = v + v
            v, cy = t & 0xFFFF, t >> 16
            r4 = ((r4 << 1) | cy) & 0xFFFF
        r6 = (r6 * 2) & 0xFFFF
        r0 = (r6 * 2) & 0xFFFF
        if r0 < r4:
            r4 = (r4 - r0 - 1) & 0xFFFF
            r6 = (r6 + 1) & 0xFFFF
    return r6


def sphere_setup(t, p):
    """Everything mdrawtsphere computes before its line loop (01:B807..B91D)."""
    v = [u16(p['lxpos'] - p['bigx']), u16(p['lypos'] - p['bigy']), u16(p['lzpos'] - p['bigz'])]
    n = m_normalise(*v)
    rotlight = [s8(c >> 8) & 0xFFFF for c in n]
    texbase = t.w(3, TEXADDR + (p['msprite'] & 0xFF) * 3)
    mat = m_matrix(t, p['rotx'], p['roty'], p['rotz'])
    mat = list(m_normalise(*mat[0:3]) + m_normalise(*mat[3:6]) + m_normalise(*mat[6:9]))
    r = p['radius'] & 0xFFFF
    rr = t.w(0, RECIP + 2 * r)
    smat = []
    for m in mat:
        v2 = fq(m, rr)
        smat.append(u16(v2 + 1) if neg(v2) else v2)
    k = fq(p['scale'], rr)
    light = [fq(swap(c), k) for c in rotlight]
    se, sp, spe = smat[0:3], smat[3:6], smat[6:9]
    return dict(light_n=n, rotlight=rotlight, texbase=texbase, mat=mat, rr=rr, smat=smat, light=light,
                se=se, sp=sp, spe=spe)


def sphere_model(t, p, details=None):
    """mdrawtsphere 01:B807.  p: dict of the GSU RAM inputs (see GV).  Returns plots [(x,y,c)]."""
    d = sphere_setup(t, p)
    if details is not None:
        details.update(d)
    se, sp, spe, light = d['se'], d['sp'], d['spe'], d['light']
    texbase = d['texbase']
    r = p['radius'] & 0xFFFF
    xspx, xsex, xspex, xlx = u16(sp[0] * 2), u16(se[0] * 2), u16(spe[0] * 2), u16(light[0] * 2)
    acc = [0, 0, 0, 0]                                  # yspy ysey yspey yly
    plots = []
    rsq = (r & 0xFF) * (r & 0xFF)
    yp = 0
    while True:
        ysq = (yp & 0xFF) * (yp & 0xFF)
        xlen = m_sqrt16(u16(rsq - ysq))
        # mgenzlist 01:B9C2: per 2-pixel column, z and its products (low words of LMULT)
        nz = xlen
        n = ((xlen + 1) >> 1) + 1
        r2 = u16(rsq - ysq)
        r1 = 0
        zl = []
        for _ in range(n):
            zl.append((lmult(sp[2], nz)[1], lmult(se[2], nz)[1], lmult(spe[2], nz)[1], lmult(light[2], nz)[1]))
            r1 = u16(r1 + 2)
            r2 = u16(r2 - (4 * r1 + 4))
            while True:
                tt = u16(r2 - (nz & 0xFF) * (nz & 0xFF))
                nz = u16(nz - 1)
                if not neg(tt):
                    break
            nz = u16(nz + 1)
        for sign, y in ((-1, u16(p['yc'] - yp)), (1, u16(p['yc'] + yp))):
            if sign < 0:
                if s16(y) < s16(p['ytop']):
                    continue
            elif s16(y) >= s16(u16(p['ybot'] + 1)):
                continue
            xl = 111 if not neg(u16(xlen - 111)) else xlen
            a = [u16(-v) for v in acc] if sign < 0 else list(acc)
            lists = []
            for flip in (1, -1):
                c = [u16(flip * v) for v in (xspx, xsex, xspex, xlx)]
                q1, q2, q3, q9 = a
                ent = []
                for z0, z1, z2, z3 in zl:
                    r4 = u16(z0 + q1)
                    w0 = u16(asr16(r4) + 0x4000)
                    mag = u16(-r4) if neg(r4) else r4
                    uv = t.w(1, UVTAB + ((mag >> 4) << 1))
                    hi, lo = lmult(uv, u16(z1 + q2))
                    mid = ((hi & 0xFF) << 8) | (lo >> 8)
                    w1 = u16(asr16(mid) + 0x4000)
                    if neg(u16(z2 + q3)):
                        w1 = u16(-w1)
                    ent.append((w0, w1, u16(z3 + q9)))
                    q1, q2, q3, q9 = u16(q1 + c[0]), u16(q2 + c[1]), u16(q3 + c[2]), u16(q9 + c[3])
                lists.append(ent)
            for ent, flag in ((lists[0], 0), (lists[1], 0x8000)):
                plots.extend(draw_uvlist(t, ent, u16(p['xc'] + flag), y, texbase, xl))
        acc = [u16(acc[0] + sp[1]), u16(acc[1] + se[1]), u16(acc[2] + spe[1]), u16(acc[3] + light[1])]
        yp = u16(yp + 1)
        if yp == r:
            return plots


def shade_row(rnd, l):
    """Brightness from 01:BB67..BB8E: returns (new rnd, colour high nibble << 4)."""
    r0 = u16(rnd * 2)
    if (rnd * 2) >> 16:
        r0 ^= 0xA63D
    rnd = r0
    h = (u16((r0 & 0xFF) * 8 + l) >> 8) & 0xFF
    if h & 0x80:
        h = 0
    h = ((h & ~7) ^ 0x78) * 2
    if h == 0xF0:
        h = 0xE0                                        # palette row 15 never used
    return rnd, h


def draw_uvlist(t, ent, x, y, texbase, xlen):
    """mdrawuvlistx 01:BB18: two pixels per list entry, midpoints, random dither of the shade."""
    plots = []
    r0 = u16(4 * y)
    r0 = u16(s8(r0) * 13 + y)
    rnd = u16(swap(r0) + x)
    v, u, l = ent[0]
    i, count = 1, xlen

    def pixel(vv, uu, ll, xx):
        nonlocal rnd
        m = (vv & 0xFF00) | (uu >> 8)
        addr = u16(((m >> 2) & 0x1F3F) + texbase)
        rnd, row = shade_row(rnd, ll)
        c = ((t.b(0x12, addr) >> 4) | row) & 0xFF
        if c:
            plots.append((xx & 0xFF, y & 0xFF, c))
        xx = u16(xx + 1)
        if neg(xx):
            xx = u16(xx - 2)
        return xx

    while True:
        nv, nu, nl = ent[i]
        mu = u16(nu + asr16(u16(u - nu)))
        s = v + nv
        v = ((s >> 16) << 15) | ((s & 0xFFFF) >> 1)
        ml = u16(nl + asr16(u16(l - nl)))
        texv, texu, light_a = v, u, l
        u, v = mu, nv
        count -= 1
        x = pixel(texv, texu, light_a, x)
        if count == 0:
            return plots
        i += 1
        l = ml
        x = pixel(v, u, ml, x)
        count -= 1
        if count == 0:
            return plots


def sprite_colour_setup(pal, msprite):
    colr = (s8(pal) * 16) & 0xFF
    high = bool((msprite & 0xFF) & 0x20)
    return colr, high


def sprite32_model(t, msprite, pal, xc, yc):
    """mdrawsprite32 01:CBF6: 32x32 texels from a 256-byte-wide page, CMODE freezehigh."""
    colr, high = sprite_colour_setup(pal, msprite)
    addr, bank = t.texture(msprite)
    plots = []
    x0, y0 = u16(xc - 16), u16(yc - 16)
    for row in range(32):
        for col in range(32):
            byte = t.b(bank, addr + row * 256 + col)
            nib = byte >> 4 if high else byte & 15
            if nib:
                plots.append(((x0 + col) & 0xFF, (y0 + row) & 0xFF, (colr & 0xF0) | nib))
    return plots


def musprite_model(t, msprite, pal, xc, yc, size, texsize=32):
    """musprite 01:CC59 -> scaled-sprite path of mssprite entered at 01:CD23 with r1 = size.
    Body adapted from render_ssprite in tools/extract-sprite-textures.py (01:CD28..CEEE), with
    the projection removed and the colour of musprite (COLR = pal*16, CMODE 8|4)."""
    colr, hi = sprite_colour_setup(pal, msprite)
    base, bank = t.texture(msprite)
    ps, sx, sy = size & 0xFFFF, xc & 0xFFFF, yc & 0xFFFF
    plots = []

    def texel(a):
        byte = t.b(bank, a)
        return byte >> 4 if hi else byte & 15

    def plot(x, y, c):
        if c:
            plots.append((x & 0xFF, y & 0xFF, (colr & 0xF0) | c))

    clipright = (223 - ps) & 0xFFFF
    half = (ps >> 1) + (ps & 1)
    x0 = (sx - half) & 0xFFFF
    if neg(x0 - (((-ps) + 1) & 0xFFFF)) or not neg(x0 - 223):
        return plots
    y0 = (sy - half) & 0xFFFF
    if ps < texsize:
        recip = t.w(0, RECIP + 2 * ps)
        step = fq(texsize << 8, recip)
        width, r5, x, acc8 = ps, base, x0, 0
        if neg(x):
            count = width
            while True:
                acc8 = (acc8 + step) & 0xFFFF
                count -= 1
                x = (x + 1) & 0xFFFF
                if count == 0:
                    return plots
                if not neg(x):
                    break
            width = count
            r5 = (r5 + ((acc8 >> 8) & 0xFF)) & 0xFFFF
        if neg((clipright - x) & 0xFFFF):
            count, r1 = width, x
            while count:
                if neg(223 - r1):
                    break
                count -= 1
                r1 = (r1 + 1) & 0xFFFF
            width -= count
        acc7, y = 0, y0
        for _ in range(ps):
            if (y & 0xFFFF) <= 192:
                acc8 = 0
                for j in range(width):
                    plot(x + j, y, texel(r5 + ((acc7 & 0xFF00) | ((acc8 >> 8) & 0xFF))))
                    acc8 = (acc8 + step) & 0xFFFF
            acc7 = (acc7 + step) & 0xFFFF
            y = (y + 1) & 0xFFFF
        return plots
    scale = 0xFFFF if ps == texsize else ((texsize << 16) // ps)
    scale &= 0xFFFE
    count = texsize
    vis = fq(scale >> 1, (223 - x0) & 0xFFFF)
    if not neg(count - vis - 1):
        count = vis
    frac, x, r5 = 0, x0, base
    if neg(x):
        product = (scale >> 1) * ((-s16(x)) & 0xFFFF)
        hi_w, lo_w = (product >> 16) & 0xFFFF, product & 0xFFFF
        frac = (lo_w * 2) & 0xFFFF
        skip = ((hi_w << 1) | (lo_w >> 15)) & 0xFFFF
        if neg(skip):
            return plots
        r5 = (r5 + skip) & 0xFFFF
        count = (count - skip) & 0xFFFF
        if neg(count):
            return plots
        x = 0
    if count == 0:
        return plots
    row, acc7, y = 0, 0, y0
    while True:
        if neg(y):
            pass
        elif neg(191 - y):
            return plots
        else:
            addr = (r5 + (row << 8)) & 0xFFFF
            r1, acc = x, frac
            for k in range(count - 1):
                c = texel(addr + k)
                while True:
                    acc += scale
                    carry = acc > 0xFFFF
                    acc &= 0xFFFF
                    plot(r1, y, c)
                    r1 = (r1 + 1) & 0xFFFF
                    if carry:
                        break
            c = texel(addr + count - 1)
            while not neg(223 - r1):
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


# =============================================================================================
# 65816 logic -- model

class MapState:
    """Inputs of a pass of the route map (WRAM + GSU RAM values the planet code reads)."""

    def __init__(self, t):
        self.roty = [0] * 6                         # DP $24..$2F (roty1..roty6)
        self.lightx, self.lighty, self.lightz = 0, 0, 150      # $16E6/$16E8/$16EA
        self.lightangle = 0                          # $16EC (hi byte = 8-bit angle)
        self.comet = 0                               # $16EF
        self.oldcomet = 0                            # $56
        self.lpos = [0, 0, 150]                      # m_lxpos/m_lypos/m_lzpos 70:01D6..01DA
        self.nebula_on = 0                           # 7E:F0CC
        self.currentplanet = 0xFFFE                  # $16DB (16-bit word as compared by cpx)
        self.speeds = [t.w(3, SPEEDS + 2 * i) for i in range(6)]
        self.rotz = [t.w(3, PLANET_ROTZ + 2 * i) for i in range(6)]
        self.sounds = []

    def copy(self):
        o = MapState.__new__(MapState)
        o.__dict__ = {k: (list(v) if isinstance(v, list) else v) for k, v in self.__dict__.items()}
        return o


def irq_sin(t, i):
    return s8(t.b(2, IRQ_SIN + (i & 0xFF)))


def irq_mul(a, b):
    """8-bit signed multiply of the IRQ rotate (02:A61B..): hi byte of (2|a|)*|b|, sign applied."""
    pa, pb = (a & 0xFF), (b & 0xFF)
    na, nb = bool(pa & 0x80), bool(pb & 0x80)
    ma = ((-s8(pa)) & 0xFF) if na else pa
    mb = ((-s8(pb)) & 0xFF) if nb else pb
    hi = (((ma << 1) & 0xFF) * mb) >> 8
    return (-hi) & 0xFF if na != nb else hi


def irq_light_step(t, st):
    """Light target / comet of the planets IRQ (ROM 02:8587..8695), once per frame."""
    if st.comet:
        st.lightx = (st.lightx & 0xFF00) | ((st.lightx - 2) & 0xFF)
        st.lighty = (st.lighty & 0xFF00) | ((st.lighty + 2) & 0xFF)
        if (st.lightx & 0xFF) < 0x12 or (st.lighty & 0xFF) >= 0xE0:
            st.comet = 0
            st.lightangle = (st.lightangle & 0xFF) | 0x1E00
        return
    a = (st.lightangle >> 8) & 0xFF
    idx = (-a) & 0xFF
    sy, cy = irq_sin(t, idx), irq_sin(t, idx + 64)
    x2 = (irq_mul(0, cy) + irq_mul(125, sy)) & 0xFF        # x1 = 0, z1 = 125
    z2 = ((-irq_mul(0, sy)) + irq_mul(125, cy)) & 0xFF
    st.lightx = u16(s8(x2) + 0x80)
    st.lighty = u16(s8(z2) + 0x64)
    st.lightz = 0xC8
    st.lightangle = u16(st.lightangle + 0x10)
    if (st.lightangle >> 8) == 0xA0:
        st.comet = 1
        st.lightx, st.lighty = 0x00FF, 0x0000


def copylight(st):
    """03:C4FD: m_lzpos = lightz; m_lxpos/m_lypos chase lightx/lighty by 1 (16 with comet)."""
    if st.oldcomet == 0 and st.comet != 0:
        st.sounds.append(0x91)
    st.oldcomet = st.comet
    st.lpos[2] = st.lightz
    step = 16 if st.comet & 0xFF else 1
    for i, target in ((0, st.lightx), (1, st.lighty)):
        v = st.lpos[i]
        st.lpos[i] = u16(v + step) if neg(u16(v - target)) else u16(v - step)


def spinplanets(st):
    """03:C57B: roty[i] += speed[i] (16-bit wrap), six counters."""
    st.roty = [u16(r + s) for r, s in zip(st.roty, st.speeds)]


def setupplanetcoord(t, st, k):
    """03:C9B4: bigx/bigy = planetpos[k] pixel (top-left of the 32x32 on the map), bigz = 0,
    roty = roty[rot index], rotz = planet_rotz[rot index] (the $FFFF swap case never occurs)."""
    rot = t.b(3, PLANETSPRS + 2 * k + 1)
    p = dict(bigx=t.b(3, PLANETPOS + 4 * k + 2), bigy=t.b(3, PLANETPOS + 4 * k + 3), bigz=0)
    roty, rotz = st.roty[rot // 2], st.rotz[rot // 2]
    if rotz == 0xFFFF:
        roty, rotz = 0xFFFF, roty
    p.update(roty=roty, rotz=rotz)
    return p


def sphere_params(t, st, k, xc, yc, radius, rotx=0):
    p = setupplanetcoord(t, st, k)
    p.update(rotx=rotx, lxpos=st.lpos[0], lypos=st.lpos[1], lzpos=st.lpos[2],
             msprite=t.b(3, PLANETSPRS + 2 * k) & 0x7F, radius=radius, scale=0x7800,
             xc=xc, yc=yc, ytop=0, ybot=0x7F)
    return p


def planet_jobs(t, st, rotx=0):
    """drawplanetsprites 03:CA67 -> ordered list of GSU jobs (kind, params)."""
    jobs = []
    for k in range(16):
        if st.nebula_on == 0 and k == 14:
            continue
        xc, yc = 16 + 32 * (k % 4), 16 + 32 * (k // 4)
        if k == st.currentplanet:
            continue
        spr = t.b(3, PLANETSPRS + 2 * k)
        if spr & 0x80:
            jobs.append(('sphere', sphere_params(t, st, k, xc, yc, 15, rotx)))
        elif (st.currentplanet & 0xFF) != 0xFE:
            jobs.append(('sprite32', dict(msprite=spr, pal=6, xc=xc, yc=yc)))
    return jobs


def incentre_job(t, st, radius, rotx=0):
    """drawplanetincentre 03:CA08: centre (64,64), pal 6, m_sprsize 32, m_sprxscale = radius+17."""
    k = st.currentplanet & 0xFFFF
    spr = t.b(3, PLANETSPRS + 2 * k)
    if spr & 0x80:
        return ('sphere', sphere_params(t, st, k, 64, 64, radius, rotx))
    return ('musprite', dict(msprite=spr, pal=6, xc=64, yc=64, size=u16(radius + 17)))


def run_model_job(t, job):
    kind, p = job
    if kind == 'sphere':
        return sphere_model(t, p)
    if kind == 'sprite32':
        return sprite32_model(t, p['msprite'], p['pal'], p['xc'], p['yc'])
    return musprite_model(t, p['msprite'], p['pal'], p['xc'], p['yc'], p['size'])


def apply_plots(bitmap, plots):
    for x, y, c in plots:
        assert x < 128 and y < 128, 'plot outside the 128x128 bitmap'
        bitmap[y][x] = c
    return bitmap


def new_bitmap():
    return [[0] * 128 for _ in range(128)]


def render_jobs(t, jobs, bitmap=None):
    bitmap = bitmap if bitmap is not None else new_bitmap()
    per_job = []
    for job in jobs:
        plots = run_model_job(t, job)
        apply_plots(bitmap, plots)
        per_job.append(plots)
    return bitmap, per_job


def zoom_model(t, st, radius=15, snapshot=None):
    """drawplanetincentre + zoom loop 03:C1E9..C2D5 (model).  Returns the list of
    (radius drawn, bitmap copy) for the first draw (C1FC) and every loop draw (C241)."""
    st = st.copy()
    is_sphere = bool(t.b(3, PLANETSPRS + 2 * (st.currentplanet & 0xFF)) & 0x80)
    bmp = new_bitmap()
    out = []
    render_jobs(t, [incentre_job(t, st, radius)], bmp)
    out.append((radius, [r[:] for r in bmp]))
    x = 40
    while True:
        spinplanets(st)
        render_jobs(t, [incentre_job(t, st, radius)], bmp)
        out.append((radius, [r[:] for r in bmp]))
        if not is_sphere:
            nr = radius + 1
            if nr != 126:
                radius = nr
                if nr & 1:
                    x += 1
        elif radius + 1 != 58:
            radius += 1
        st.lpos[0] = u16(st.lpos[0] - 10)
        st.lpos[2] = u16(st.lpos[2] + 10)
        x -= 1
        if x == 0:
            return out, radius, st


# =============================================================================================
# Oracle: the ROM's own 65816 and GSU bytes

class Oracle:
    """cpu65816 + GSU8 sharing one GSU RAM.  runmario 7E:4EE3 is hooked to run the GSU entry
    (A = bank, X = address) to STOP; the bank-02 block that the game runs from WRAM is copied
    to 7E:(addr - $4E6D) so that the planets IRQ code (jsr $5797 rotate, jmp $5802...) runs."""

    def __init__(self, data):
        self.data = data
        self.rom = gi.Rom(data)
        self.bus = C65.Bus(data)
        base = 0x8000 - WRAM_COPY_OFFSET
        self.bus.wram[base:base + 0x8000] = data[2 * 0x8000:3 * 0x8000]
        self.cpu = C65.CPU(self.bus, hooks={0x7E4EE3: self._runmario, 0x7E401B: self._rts,
                                            0x03B7E5: self._sound})
        self.gsu_jobs = []
        self.sounds = []

    def _rts(self, c):
        c.do_rts()

    def _sound(self, c):
        self.sounds.append(c.a & 0xFF)
        c.do_rtl()

    def _runmario(self, c):
        g = gi.GSU8(self.rom, ram=self.bus.gsuram, scbr=GSU_SCBR, md=3, ht=0)
        g.run(c.x & 0xFFFF, pbr=c.a & 0xFF)
        self.gsu_jobs.append(dict(entry='%02X:%04X' % (c.a & 0xFF, c.x & 0xFFFF), plots=g.plot_log,
                                  steps=g.steps, plot_calls=g.plot_calls))
        c.do_rtl()

    def w16(self, addr, v):
        self.bus.wram[addr] = v & 0xFF
        self.bus.wram[addr + 1] = (v >> 8) & 0xFF

    def r16(self, addr):
        return self.bus.wram[addr] | (self.bus.wram[addr + 1] << 8)

    def gw(self, addr, v):
        self.bus.gsuram[addr] = v & 0xFF
        self.bus.gsuram[addr + 1] = (v >> 8) & 0xFF

    def gr(self, addr):
        return self.bus.gsuram[addr] | (self.bus.gsuram[addr + 1] << 8)

    def call(self, bank, addr, m8=True, x8=False):
        """JSR-style call of a 65816 routine ending in RTS."""
        c = self.cpu
        c.pb, c.d, c.db, c.s, c.m, c.xf = bank, 0, bank, 0x1FF0, m8, x8
        c.push16(0xFFEF)
        c.pc = addr
        c.run((bank << 16) | 0xFFF0, limit=20_000_000)

    def load_state(self, st):
        for i, r in enumerate(st.roty):
            self.w16(0x24 + 2 * i, r)
        self.w16(0x16E6, st.lightx)
        self.w16(0x16E8, st.lighty)
        self.w16(0x16EA, st.lightz)
        self.w16(0x16EC, st.lightangle)
        self.bus.wram[0x16EF] = st.comet
        self.bus.wram[0x56] = st.oldcomet
        self.w16(0x16DB, st.currentplanet)
        self.w16(0x1F0CC, st.nebula_on)
        for i, v in enumerate(st.lpos):
            self.gw(GV['lxpos'] + 2 * i, v)
        self.gw(GV['rotx'], 0)
        self.gw(GV['ytop'], 0)
        self.gw(GV['ybot'], 0x7F)
        self.gw(GV['pal'], 6)                           # 03:BE23 / BF33 set mspr_pal = 6 around the draw

    def read_state(self, st):
        o = st.copy()
        o.roty = [self.r16(0x24 + 2 * i) for i in range(6)]
        o.lightx, o.lighty, o.lightz = self.r16(0x16E6), self.r16(0x16E8), self.r16(0x16EA)
        o.lightangle, o.comet, o.oldcomet = self.r16(0x16EC), self.bus.wram[0x16EF], self.bus.wram[0x56]
        o.lpos = [self.gr(GV['lxpos'] + 2 * i) for i in range(3)]
        return o

    def bitmap(self):
        return gi.decode_bitmap(self.bus.gsuram, scbr=GSU_SCBR)

    def irq_frame(self):
        """ROM 02:849E..869D (runs at 7E:3631 from the WRAM copy) once: ship OBJ + light/comet."""
        self.bus.wram[0x34] = 0
        c = self.cpu
        c.s, c.m, c.xf, c.d, c.db = 0x1FF0, True, False, 0, 0
        c.push8(0x7F)
        c.push16(0xFFEF)
        c.pb, c.pc = 0x7E, 0x849E - WRAM_COPY_OFFSET
        c.run(0x7FFFF0, limit=100_000)


def gsu_with(t, entry, values):
    ram = bytearray(0x20000)
    for k, v in values.items():
        ram[GV[k]] = v & 0xFF
        ram[GV[k] + 1] = (v >> 8) & 0xFF
    g = gi.GSU8(t.rom, ram=ram, scbr=GSU_SCBR)
    g.run(entry, pbr=1)
    return g


def sphere_gsu(t, p):
    return gsu_with(t, SPHERE_ENTRY, {k: v for k, v in p.items() if k in GV})


# =============================================================================================
# Checks

def rand_sphere(rnd, t):
    k = rnd.choice([0, 4, 5, 11, 15])
    p = dict(bigx=rnd.choice([t.b(3, PLANETPOS + 4 * k + 2), rnd.randrange(256)]),
             bigy=rnd.choice([t.b(3, PLANETPOS + 4 * k + 3), rnd.randrange(256)]), bigz=0,
             lxpos=rnd.choice([rnd.randrange(-400, 600), rnd.randrange(0, 256)]) & 0xFFFF,
             lypos=rnd.choice([rnd.randrange(-400, 600), rnd.randrange(0, 256)]) & 0xFFFF,
             lzpos=rnd.choice([150, 200, rnd.randrange(150, 700)]),
             msprite=t.b(3, PLANETSPRS + 2 * k) & 0x7F,
             rotx=rnd.choice([0, 0, 0, rnd.randrange(65536)]), roty=rnd.randrange(65536),
             rotz=rnd.choice([t.w(3, PLANET_ROTZ + 2 * rnd.randrange(6)), rnd.randrange(65536)]),
             radius=rnd.choice([15, 15, rnd.randrange(1, 58)]), scale=0x7800, ytop=0, ybot=0x7F)
    r = p['radius']
    p['xc'] = rnd.randrange(r, 128 - r)
    if rnd.random() < 0.15:                            # partly outside the y window 0..127
        p['yc'] = rnd.choice([rnd.randrange(0, r), rnd.randrange(128 - r, 128)])
    else:
        p['yc'] = rnd.randrange(r, 128 - r)
    return p


def fixed_spheres(t):
    out = []
    for k in (0, 4, 5, 11, 15):
        rot = t.b(3, PLANETSPRS + 2 * k + 1) // 2
        for lx, ly, lz in ((0, 0, 150), (255, 0, 200), (128, 224, 200), (-320, 30, 600), (20, 20, 200)):
            for radius in (15, 40, 57):
                xc, yc = (16 + 32 * (k % 4), 16 + 32 * (k // 4)) if radius == 15 else (64, 64)
                out.append(dict(bigx=t.b(3, PLANETPOS + 4 * k + 2), bigy=t.b(3, PLANETPOS + 4 * k + 3), bigz=0,
                                lxpos=lx & 0xFFFF, lypos=ly & 0xFFFF, lzpos=lz,
                                msprite=t.b(3, PLANETSPRS + 2 * k) & 0x7F, rotx=0, roty=(k * 0x3100) & 0xFFFF,
                                rotz=t.w(3, PLANET_ROTZ + 2 * rot), radius=radius, scale=0x7800,
                                xc=xc, yc=yc, ytop=0, ybot=0x7F))
    return out


def check_units(t, cases, seed):
    rnd = random.Random(seed)
    res = dict(sphere=dict(cases=0, exact=0, plots=0, failures=[]),
               sprite32=dict(cases=0, exact=0, plots=0, failures=[]),
               musprite=dict(cases=0, exact=0, plots=0, failures=[]))
    steps_by_radius = {}
    for p in fixed_spheres(t) + [rand_sphere(rnd, t) for _ in range(cases)]:
        g = sphere_gsu(t, p)
        m = sphere_model(t, p)
        s = res['sphere']
        s['cases'] += 1
        s['plots'] += len(g.plot_log)
        steps_by_radius.setdefault(p['radius'], []).append((g.steps, g.plot_calls))
        if m == g.plot_log:
            s['exact'] += 1
        elif len(s['failures']) < 5:
            s['failures'].append(dict(params=p, model=len(m), gsu=len(g.plot_log),
                                      first_diff=next((i for i, (a, b) in enumerate(zip(m, g.plot_log)) if a != b), None)))
    res['sphere']['gsu_instructions_by_radius'] = {
        str(r): dict(n=len(v), instructions=round(sum(a for a, _ in v) / len(v)), plot_instr=round(sum(b for _, b in v) / len(v)))
        for r, v in sorted(steps_by_radius.items()) if r in (1, 5, 10, 15, 20, 30, 40, 50, 54, 57)}
    sprites = sorted({t.b(3, PLANETSPRS + 2 * k) for k in range(17) if not t.b(3, PLANETSPRS + 2 * k) & 0x80})
    for spr in sprites:
        for pal in (6, 0, 15, 16):
            for xc, yc in ((16, 16), (112, 112), (48, 80)):
                g = gsu_with(t, SPRITE32_ENTRY, dict(msprite=spr, pal=pal, xc=xc, yc=yc))
                m = sprite32_model(t, spr, pal, xc, yc)
                s = res['sprite32']
                s['cases'] += 1
                s['plots'] += len(g.plot_log)
                s['exact'] += m == g.plot_log
                if m != g.plot_log and len(s['failures']) < 5:
                    s['failures'].append(dict(msprite=spr, pal=pal, model=len(m), gsu=len(g.plot_log)))
        for radius in range(15, 96):
            size = radius + 17
            g = gsu_with(t, MUSPRITE_ENTRY, dict(msprite=spr, pal=6, xc=64, yc=64, sprsize=32, sprxscale=size))
            m = musprite_model(t, spr, 6, 64, 64, size)
            s = res['musprite']
            s['cases'] += 1
            s['plots'] += len(g.plot_log)
            s['exact'] += m == g.plot_log
            if m != g.plot_log and len(s['failures']) < 5:
                s['failures'].append(dict(msprite=spr, size=size, model=len(m), gsu=len(g.plot_log)))
    return res


def check_irq(t, frames):
    """Planets IRQ light/comet: ROM 65816 (WRAM copy) vs irq_light_step, lock-step per frame."""
    o = Oracle(t.data)
    st = MapState(t)
    st.lightx, st.lighty, st.lightz, st.lightangle = 0, 0, 150, 0
    o.load_state(st)
    mism, trace, comet_frames = 0, [], []
    for f in range(frames):
        o.irq_frame()
        irq_light_step(t, st)
        got = o.read_state(st)
        a = (got.lightx, got.lighty, got.lightz, got.lightangle, got.comet)
        b = (st.lightx, st.lighty, st.lightz, st.lightangle, st.comet)
        if a != b:
            mism += 1
            if len(trace) < 3:
                trace.append(dict(frame=f, rom=a, model=b))
        if st.comet:
            comet_frames.append(f)
        o.load_state(st)
    circle = []
    s2 = MapState(t)
    for a in range(256):
        s2.lightangle, s2.comet = a << 8, 0
        irq_light_step(t, s2)
        circle.append([s16(s2.lightx), s16(s2.lighty)])
    return dict(frames=frames, mismatches=mism, first_mismatches=trace,
                comet_first_frame=comet_frames[0] if comet_frames else None,
                comet_length_frames=len(comet_frames), light_target_by_angle_byte=circle)


def check_passes(t, passes, fpp, start_angle):
    """Selection loop 03:BF25..: per pass, K IRQ frames, then copylight, spinplanets and
    drawplanetsprites (currentplanet $FFFE: spheres only), preceded by the setup draw of
    03:BE12..BE29 (copylight + drawplanetsprites with currentplanet $FF: sprites too)."""
    o = Oracle(t.data)
    st = MapState(t)
    st.lightangle, st.currentplanet = start_angle, 0x00FF
    o.load_state(st)
    o.call(3, 0xC4FD)
    o.call(3, 0xCA67)
    copylight(st)
    model_bmp, per_job = render_jobs(t, planet_jobs(t, st))
    out = dict(passes=passes, frames_per_pass=fpp, start_lightangle='%04X' % start_angle,
               setup_jobs=len(o.gsu_jobs), setup_bitmap_equal=o.bitmap() == model_bmp,
               setup_plots_equal=[j['plots'] for j in o.gsu_jobs] == per_job,
               pass_bitmaps_equal=0, state_equal=0, plots_equal=0, gsu_jobs=0, comet_passes=0)
    snapshots = [('setup', [r[:] for r in model_bmp])]
    st.currentplanet = 0xFFFE
    o.w16(0x16DB, 0xFFFE)
    steps = []
    for n in range(passes):
        for _ in range(fpp):
            irq_light_step(t, st)
        o.load_state(st)
        o.gsu_jobs = []
        o.call(3, 0xC4FD)
        o.call(3, 0xC57B)
        o.call(3, 0xCA67)
        copylight(st)
        spinplanets(st)
        model_bmp, per_job = render_jobs(t, planet_jobs(t, st), model_bmp)
        got = o.read_state(st)
        out['state_equal'] += (got.roty, got.lpos, got.oldcomet) == (st.roty, st.lpos, st.oldcomet)
        out['pass_bitmaps_equal'] += o.bitmap() == model_bmp
        out['plots_equal'] += [j['plots'] for j in o.gsu_jobs] == per_job
        out['gsu_jobs'] += len(o.gsu_jobs)
        steps.extend(j['steps'] for j in o.gsu_jobs)
        out['comet_passes'] += bool(st.comet)
        if n in (0, passes // 2, passes - 1) or (st.comet and not any(s[0].startswith('comet') for s in snapshots)):
            snapshots.append(('comet_%d' % n if st.comet else 'pass_%d' % n, [r[:] for r in model_bmp]))
    out['sounds_rom'], out['sounds_model'] = o.sounds, st.sounds
    out['sphere_gsu_instructions'] = dict(min=min(steps), max=max(steps), mean=round(sum(steps) / len(steps)))
    return out, snapshots


def check_zoom(t, planet):
    """Pepper zoom: ROM 03:C739 (GSU clear) + C1EC..C1FF + loop C23A..C2D5 executed with the
    DMA (03:C867) hooked to snapshot the GSU bitmap, vs zoom_model."""
    o = Oracle(t.data)
    st = MapState(t)
    st.currentplanet = planet
    st.lpos = [0x30, 0x60, 0xC8]
    st.roty = [0x1234, 0x4321, 0x8000, 0x0100, 0xF000, 0]
    o.load_state(st)
    snaps = []

    def dma(c):
        snaps.append(o.bitmap())
        c.do_rts()

    def stop(c):
        raise C65.Halt()
    o.cpu.hooks[0x03C867] = dma
    o.cpu.hooks[0x03C2D8] = stop
    o.call(3, 0xC739)
    c = o.cpu
    c.pb, c.pc, c.d, c.db, c.m, c.xf, c.s = 3, 0xC1EC, 0, 3, False, False, 0x1FF0
    try:
        c.run(0xFFFFFF, limit=200_000_000)
    except C65.Halt:
        pass
    model, radius, mst = zoom_model(t, st)
    equal = sum(1 for a, (_, b) in zip(snaps, model) if a == b)
    return dict(planet=planet, name=NAMES[planet], sphere=bool(t.b(3, PLANETSPRS + 2 * planet) & 0x80),
                rom_draws=len(snaps), model_draws=len(model), bitmaps_equal=equal,
                radii_drawn=[model[0][0], model[-1][0]],
                final_radius=[o.gr(GV['radius']), radius],
                final_lxpos_lzpos=[[o.gr(GV['lxpos']), o.gr(GV['lzpos'])], [mst.lpos[0], mst.lpos[2]]]), model


# ---- savestates (read only) --------------------------------------------------------------

def load_state_images(name):
    """WRAM and GSU RAM images of a BizHawk 2.9.1 SNES savestate (zstd Core.bin), located by
    content: WRAM by the runmario copy (ROM 02:9D50 at 7E:4EE3), GSU RAM by the planets
    viewport/scale signature.  Returns None when unavailable."""
    path = STATES / (name + '.state')
    try:
        from compression import zstd
    except ImportError:
        return None
    if not path.exists():
        return None
    core = zstd.decompress(zipfile.ZipFile(path).read('Core.bin'))
    rom = ROM_PATH.read_bytes()
    w = core.find(rom[2 * 0x8000 + 0x1D50:2 * 0x8000 + 0x1D50 + 16]) - 0x4EE3
    g = next(o for o in range(len(core) - 0x200) if core[o + 0x30] == 0 and core[o + 0x31] == 0x78
             and core[o + 0x3E] == 0x7F and core[o + 0x3C] == 0 and core[o + 0x34] == 0x40 and core[o + 0x36] == 0x40)
    return dict(path=str(path.relative_to(ROOT)), sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                wram=core[w:w + 0x20000], gsu=bytearray(core[g:g + 0x10000]), wram_offset=w, gsu_offset=g)


def check_savestates(t):
    out = {}
    img = load_state_images('sf_map')
    if img is None:
        return dict(skipped='savestates or compression.zstd (Python >= 3.14) not available')
    wr = lambda a: img['wram'][a] | (img['wram'][a + 1] << 8)
    gr = lambda a: img['gsu'][a] | (img['gsu'][a + 1] << 8)
    st = MapState(t)
    st.roty = [wr(0x24 + 2 * i) for i in range(6)]
    st.lpos = [gr(GV['lxpos'] + 2 * i) for i in range(3)]
    st.currentplanet = wr(0x16DB)
    st.nebula_on = wr(0x1F0CC)
    rotx = gr(GV['rotx'])
    sprites = MapState(t)
    sprites.currentplanet = 0xFFFF
    bmp, _ = render_jobs(t, [j for j in planet_jobs(t, sprites) if j[0] == 'sprite32'])
    bmp, _ = render_jobs(t, planet_jobs(t, st, rotx=rotx), bmp)
    ref = gi.decode_bitmap(img['gsu'], scbr=GSU_SCBR)
    diff = sum(a != b for ra, rb in zip(ref, bmp) for a, b in zip(ra, rb))
    out['sf_map'] = dict(state=img['path'], state_sha256=img['sha256'], gameframe=img['wram'][0x15BD],
                         currentplanet='%04X' % st.currentplanet, roty=['%04X' % r for r in st.roty],
                         m_lpos=st.lpos, rotx=rotx, ytop_ybot=[gr(GV['ytop']), gr(GV['ybot'])],
                         lightangle='%04X' % wr(0x16EC), comet=img['wram'][0x16EF],
                         bitmap_pixels_different=diff,
                         note='sprites (setup draw) + the 5 spheres drawn with WRAM roty and GSU m_lxpos..m_lzpos of the state')
    for name in ('scr_pepper',):
        img = load_state_images(name)
        if img is None:
            continue
        gr = lambda a, img=img: img['gsu'][a] | (img['gsu'][a + 1] << 8)
        p = {k: gr(a) for k, a in GV.items() if k in ('rotx', 'roty', 'rotz', 'bigx', 'bigy', 'bigz', 'scale', 'ytop', 'ybot',
                                                       'msprite', 'lxpos', 'lypos', 'lzpos', 'radius', 'xc', 'yc')}
        ref = gi.decode_bitmap(img['gsu'], scbr=GSU_SCBR)
        # The state was saved while the GSU was drawing (m_yp = 70:01FC): the two previous loop
        # draws (radius -1/-2, roty - speed[0] per step, m_lxpos +10, m_lzpos -10 per step) and
        # the lines yp < m_yp of the current draw.
        p['msprite'] &= 0x7F
        yp_now = gr(0x1FC)
        speed = t.w(3, SPEEDS)
        bmp = new_bitmap()
        for back in (2, 1):
            q = dict(p, radius=p['radius'] - back, roty=u16(p['roty'] - back * speed),
                     lxpos=u16(p['lxpos'] + 10 * back), lzpos=u16(p['lzpos'] - 10 * back))
            apply_plots(bmp, sphere_model(t, q))
        apply_plots(bmp, [(x, y, c) for x, y, c in sphere_model(t, p) if abs(y - p['yc']) < yp_now])
        diff = sum(a != b for ra, rb in zip(ref, bmp) for a, b in zip(ra, rb))
        out[name] = dict(state=img['path'], state_sha256=img['sha256'], radius=p['radius'], m_yp=yp_now,
                         roty='%04X' % p['roty'], m_lpos=[p['lxpos'], p['lypos'], p['lzpos']],
                         bitmap_pixels_different=diff,
                         note='saved mid-draw: previous two zoom draws + current draw lines with |y-yc| < m_yp')
    return out


# =============================================================================================
# Port study: per-sphere work counts and colour quantisation to Mega Drive palettes

def sphere_counts(t, p):
    """Work done by mdrawtsphere for p (from the model's own loop structure)."""
    r = p['radius']
    c = dict(radius=r, lines=0, zlist_entries=0, zlist_search_steps=0, uv_entries=0, pixels_plotted=0)
    rsq = (r & 0xFF) ** 2
    for yp in range(r):
        xlen = m_sqrt16(u16(rsq - yp * yp))
        n = ((xlen + 1) >> 1) + 1
        c['zlist_entries'] += n
        nz, r1, r2 = xlen, 0, u16(rsq - yp * yp)
        for _ in range(n):
            r1 += 2
            r2 = u16(r2 - (4 * r1 + 4))
            while True:
                c['zlist_search_steps'] += 1
                tt = u16(r2 - (nz & 0xFF) ** 2)
                nz = u16(nz - 1)
                if not neg(tt):
                    break
            nz = u16(nz + 1)
        for y in (p['yc'] - yp, p['yc'] + yp):
            if 0 <= y <= 127:
                c['lines'] += 1
                c['uv_entries'] += 2 * n
                c['pixels_plotted'] += 2 * min(xlen, 111)
    return c


def bgr555(t, idx):
    v = t.w(3, PLANSELPAL + 2 * idx)
    r, g, b = v & 31, (v >> 5) & 31, (v >> 10) & 31
    return ((r << 3) | (r >> 2), (g << 3) | (g >> 2), (b << 3) | (b >> 2))


def md_level(v):
    """Nearest Mega Drive 3-bit level of an 8-bit channel, shown as round(n*255/7) [H: linear DAC]."""
    n = min(7, max(0, round(v * 7 / 255)))
    return round(n * 255 / 7)


def md_colour(rgb):
    return tuple(md_level(c) for c in rgb)


def dist(a, b):
    return sum((x - y) ** 2 for x, y in zip(a, b)) ** 0.5


def kmeans(hist, k, iters=40):
    """Weighted Lloyd k-means on RGB, deterministic farthest-point init, centres snapped to MD."""
    pts = sorted(hist.items(), key=lambda kv: -kv[1])
    if len(pts) <= k:
        return sorted({md_colour(p) for p, _ in pts})
    cents = [pts[0][0]]
    while len(cents) < k:
        cents.append(max(pts, key=lambda kv: kv[1] ** 0.25 * min(dist(kv[0], c) for c in cents))[0])
    for _ in range(iters):
        acc = [[0, 0, 0, 0] for _ in cents]
        for p, w in pts:
            j = min(range(len(cents)), key=lambda i: dist(p, cents[i]))
            a = acc[j]
            a[0] += p[0] * w
            a[1] += p[1] * w
            a[2] += p[2] * w
            a[3] += w
        new = [tuple(a[i] / a[3] for i in range(3)) if a[3] else c for a, c in zip(acc, cents)]
        if new == cents:
            break
        cents = new
    return sorted({md_colour(c) for c in cents})


def quant_error(hist, palette):
    tot = w_all = 0
    mx = 0
    for p, w in hist.items():
        d = min(dist(p, q) for q in palette)
        tot += d * w
        w_all += w
        mx = max(mx, d)
    return dict(mean=round(tot / w_all, 2), max=round(mx, 2))


def quantisation_study(t, irq_circle):
    """Histograms of the colours the original produces (indices of planselpal), then the error
    of (a) 9-bit MD colour depth alone, (b) one 15-colour palette per planet, (c) one shared
    15-colour palette per group (five spheres, all sprites, whole bitmap)."""
    st = MapState(t)
    per_planet = {}
    lights = [irq_circle[a] + [200] for a in (0, 64, 128, 192)] + [[60, 200, 200]]
    for k in range(16):
        spr = t.b(3, PLANETSPRS + 2 * k)
        idx_hist = {}
        if spr & 0x80:
            for li, (lx, ly, lz) in enumerate(lights):
                for i in range(0, 256, 16):
                    st.roty = [i << 8] * 6
                    st.lpos = [lx & 0xFFFF, ly & 0xFFFF, lz]
                    for radius, xc, yc in ((15, 16 + 32 * (k % 4), 16 + 32 * (k // 4)), (54, 64, 64)):
                        if radius == 54 and (i % 64 or li % 2):
                            continue
                        for x, y, c in sphere_model(t, sphere_params(t, st, k, xc, yc, radius)):
                            idx_hist[c] = idx_hist.get(c, 0) + 1
        else:
            for x, y, c in sprite32_model(t, spr, 6, 16, 16):
                idx_hist[c] = idx_hist.get(c, 0) + 1
        per_planet[k] = idx_hist
    res = dict(method='pixel-weighted histograms of the original colour indices (model renders: spheres '
                      'radius 15 at 16 roty x 5 light positions + radius 54; sprites once, pal 6); '
                      'RGB888 from planselpal 03:D440 BGR555; MD levels round(n*255/7) [H: linear DAC]; '
                      'error = Euclidean RGB888 distance to the nearest palette colour',
               per_planet=[], groups={})
    rgb_all, rgb_spheres, rgb_sprites = {}, {}, {}
    for k, ih in per_planet.items():
        rh = {}
        for c, w in ih.items():
            rgb = bgr555(t, c)
            rh[rgb] = rh.get(rgb, 0) + w
        is_sphere = bool(t.b(3, PLANETSPRS + 2 * k) & 0x80)
        for target in (rgb_all, rgb_spheres if is_sphere else rgb_sprites):
            for rgb, w in rh.items():
                target[rgb] = target.get(rgb, 0) + w
        pal = kmeans(rh, 15)
        res['per_planet'].append(dict(cell=k, name=NAMES[k], sphere=is_sphere, pixels=sum(ih.values()),
                                      distinct_indices=len(ih), distinct_rgb=len(rh),
                                      rows_used=sorted({c >> 4 for c in ih}),
                                      md_depth_only=quant_error(rh, [md_colour(c) for c in rh]),
                                      palette15=quant_error(rh, pal), palette15_size=len(pal)))
    for name, h in (('five_spheres', rgb_spheres), ('all_sprites', rgb_sprites), ('whole_bitmap', rgb_all)):
        pal = kmeans(h, 15)
        res['groups'][name] = dict(distinct_rgb=len(h), md_depth_only=quant_error(h, [md_colour(c) for c in h]),
                                   palette15=quant_error(h, pal), palette=['%02X%02X%02X' % c for c in pal])
    # sprite planets draw with COLR = 6*16: CGRAM row 6 = BG2 map palette 6 (one MD line, exact up to 9-bit depth)
    row6 = [bgr555(t, 96 + i) for i in range(16)]
    res['sprites_use_row6_only'] = all((c >> 4) == 6 for k, ih in per_planet.items()
                                       if not t.b(3, PLANETSPRS + 2 * k) & 0x80 for c in ih)
    res['row6_md_depth'] = quant_error({c: 1 for c in row6[1:]}, [md_colour(c) for c in row6[1:]])
    # two MD lines for the five spheres: every 2-way partition, one 15-colour palette per side
    spheres = [k for k in range(16) if t.b(3, PLANETSPRS + 2 * k) & 0x80]
    rgbh = {}
    for k in spheres:
        rgbh[k] = {}
        for c, w in per_planet[k].items():
            rgbh[k][bgr555(t, c)] = rgbh[k].get(bgr555(t, c), 0) + w
    parts = []
    for mask in range(1, 1 << (len(spheres) - 1)):
        sides = [[k for i, k in enumerate(spheres) if (mask >> i) & 1 == s] for s in (1, 0)]
        tot = wsum = 0
        worst = 0
        for side in sides:
            h = {}
            for k in side:
                for c, w in rgbh[k].items():
                    h[c] = h.get(c, 0) + w
            e = quant_error(h, kmeans(h, 15))
            w = sum(h.values())
            tot += e['mean'] * w
            wsum += w
            worst = max(worst, e['max'])
        parts.append(dict(lines=[[NAMES[k] for k in s] for s in sides], mean=round(tot / wsum, 2), max=worst))
    parts.sort(key=lambda d: d['mean'])
    res['spheres_two_lines'] = dict(best=parts[0], second=parts[1], worst=parts[-1], partitions=len(parts))
    return res


# =============================================================================================
# Output

def save_png(t, path, bitmap, scale=2):
    pal = [bgr555(t, i) for i in range(256)]
    return gi.base.write_png(path, len(bitmap[0]), len(bitmap), bitmap, pal, transparent0=False, scale=scale)


def table_hashes(t, data):
    tabs = {}
    for name, bank, addr, size in (('planetsprs', 3, PLANETSPRS, 34), ('planetnames', 3, PLANETNAMES, 17),
                                   ('planetpos', 3, PLANETPOS, 68), ('startplanetpos', 3, STARTPOS, 34),
                                   ('endplanetpos', 3, ENDPOS, 34), ('fadetab0', 3, FADETAB0, 32),
                                   ('planselpal', 3, PLANSELPAL, 512), ('speeds', 3, SPEEDS, 12),
                                   ('planet_rotz', 3, PLANET_ROTZ, 12), ('sintab16', 0, SINTAB, 514),
                                   ('reciptab_0_127', 0, RECIP, 256), ('m_uvtab', 1, UVTAB, 4096),
                                   ('irq_sintab', 2, IRQ_SIN, 320)):
        p = phys(bank, addr)
        tabs[name] = dict(cpu='%02X:%04X' % (bank, addr), rom='0x%05X..0x%05X' % (p, p + size), size=size,
                          sha256=hashlib.sha256(data[p:p + size]).hexdigest())
    for tid in sorted({t.b(3, PLANETSPRS + 2 * k) & 0x7F for k in range(17)}):
        addr, bank = t.texture(tid)
        sphere = any(t.b(3, PLANETSPRS + 2 * k) == (tid | 0x80) for k in range(17))
        bank = 0x12 if sphere else bank
        w, h = (64, 32) if sphere else (32, 32)
        raw = b''.join(bytes(t.b(bank, addr + r * 256 + c) for c in range(w)) for r in range(h))
        tabs['texture_%02X' % tid] = dict(cpu='%02X:%04X' % (bank, addr), rom='0x%05X' % phys(bank, addr),
                                          bytes='%dx%d (256-byte rows)' % (w, h),
                                          nibble='high' if (sphere or tid & 0x20) else 'low',
                                          sha256=hashlib.sha256(raw).hexdigest())
    return tabs


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--cases', type=int, default=120, help='random mdrawtsphere cases (plus 75 fixed)')
    ap.add_argument('--seed', type=int, default=1993)
    ap.add_argument('--passes', type=int, default=24)
    ap.add_argument('--frames-per-pass', type=int, default=10)
    ap.add_argument('--zoom', default='0,4,1,9', help='planets (indices) for the zoom check')
    ap.add_argument('--skip-quant', action='store_true')
    args = ap.parse_args()
    data = ROM_PATH.read_bytes()
    sha = hashlib.sha256(data).hexdigest()
    assert sha == SHA, 'unexpected ROM'
    assert data[0x7FDB] == 0, 'not rev0'
    t = Tables(data)
    OUT.mkdir(parents=True, exist_ok=True)
    report = dict(rom=str(ROM_PATH.relative_to(ROOT)), rom_sha256=sha, tool='tools/route-planets-model.py',
                  interpreter='tools/gsu_interp8.py (subclass of the GSU interpreter of tools/extract-sprite-textures.py)',
                  args=vars(args), tables=table_hashes(t, data), planets=t.planets())
    print('units...', flush=True)
    report['units'] = check_units(t, args.cases, args.seed)
    print('irq...', flush=True)
    irq = check_irq(t, 0xA00 + 300)
    report['irq_light'] = irq
    print('passes...', flush=True)
    passes, snaps = check_passes(t, args.passes, args.frames_per_pass, 0x9E00)
    report['selection_passes'] = passes
    report['pngs'] = {}
    for name, bmp in snaps:
        report['pngs'][name] = save_png(t, OUT / ('map_bitmap_%s.png' % name), bmp)
    print('zoom...', flush=True)
    report['zoom'] = []
    for k in [int(v) for v in args.zoom.split(',') if v]:
        z, model = check_zoom(t, k)
        report['zoom'].append(z)
        report['pngs']['zoom_%02d' % k] = save_png(t, OUT / ('zoom_%02d_final.png' % k), model[-1][1])
    print('savestates...', flush=True)
    report['savestates'] = check_savestates(t)
    print('port study...', flush=True)
    report['work_counts'] = {str(r): sphere_counts(t, dict(radius=r, yc=64)) for r in (15, 30, 40, 54, 57)}
    if not args.skip_quant:
        report['quantisation'] = quantisation_study(t, irq['light_target_by_angle_byte'])
    st = MapState(t)
    sheet = [[0] * (32 * 16) for _ in range(32 * 5)]
    for row, k in enumerate((0, 4, 5, 11, 15)):
        for i in range(16):
            st.roty = [(i * 0x1000) & 0xFFFF] * 6
            st.lpos = [0, 0, 200]
            for x, y, c in sphere_model(t, sphere_params(t, st, k, 16, 16, 15)):
                sheet[row * 32 + y][i * 32 + x] = c
    report['pngs']['spheres_turn'] = save_png(t, OUT / 'spheres_turn.png', sheet)
    u = report['units']
    ok = (all(u[k]['exact'] == u[k]['cases'] for k in ('sphere', 'sprite32', 'musprite'))
          and irq['mismatches'] == 0 and passes['setup_bitmap_equal'] and passes['setup_plots_equal']
          and passes['pass_bitmaps_equal'] == passes['plots_equal'] == passes['state_equal'] == passes['passes']
          and all(z['bitmaps_equal'] == z['rom_draws'] == z['model_draws'] for z in report['zoom']))
    report['check'] = 'PASS' if ok else 'FAIL'
    CHECK.write_text(json.dumps(report, indent=1))
    print(report['check'], 'spheres %d/%d' % (u['sphere']['exact'], u['sphere']['cases']),
          'sprite32 %d/%d' % (u['sprite32']['exact'], u['sprite32']['cases']),
          'musprite %d/%d' % (u['musprite']['exact'], u['musprite']['cases']),
          'irq mismatches %d' % irq['mismatches'],
          'passes %d/%d' % (passes['pass_bitmaps_equal'], passes['passes']),
          'zoom %s' % [(z['bitmaps_equal'], z['rom_draws']) for z in report['zoom']])


if __name__ == '__main__':
    main()


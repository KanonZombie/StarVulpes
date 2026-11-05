"""Star Fox (USA rev0) route map and Pepper screen: logic and presentation tables for the MD port.

Research tool (needs Pillow through tools/convert-screen-bg.py; use tools/emulator-mcp/.venv-local). Authority: ref/Star Fox (USA).sfc, SHA-256 below,
LoROM without copier header, physical = bank*0x8000 + (addr & 0x7FFF).

What it does
  1. Checks the ROM and code anchors (bytes of the 65816 routines that consume every
     table: planetseq_l 03:BDCB, drawplanetlines_l 03:CC2A, moveshipalongpath 03:C470,
     drawroutename 03:C66B, setupplanetwindow 03:C5FD, calcdxdy 03:C8B7, copyfox 03:C5C0,
     fadecol0 03:CB3B, pepperspeaking 03:D11F, showplanetname 03:D1A7, irqplanets 02:837D,
     irqplanets2 02:8363, GSU mgprintstr entry 01:B509).
  2. Parses stagepaths 03:D671 and re-implements drawplanetlines (markers, the stray
     position write, newmap/peppermsg/currentlevel), moveshipalongpath (targets) and the
     IRQ ship step (1 px per frame), with 16-bit wrap as in the original.
  3. Re-implements calcdxdy/dividebynum (the 32-frame scroll of the selected planet).
  4. Lays out the Pepper texts (planet names 93..105, messages of stagepaths) with the
     radio font/layout of tools/extract-radio.py (clip 190, x1 0/2) and lists the
     typewriter order (one character per pass, m_totalchars/m_lastchar).
  5. Extracts palettes (planselpal 03:D440, fadetab0 03:D420), the OBJ characters
     00:A08B, HDMA tables (02:8FD0 copied to 7E:4163) and the BG2 cells of the
     Pepper text bitmap (dogpcr 17:827C) with SHA-256.
  6. If build/research/route-map/probe-*.json exist (tools/probe-route-map.py), adds a
     'measured' section and compares markers, ship steps and scroll with the model.

Output: build/route-map.json. Usage: python tools/extract-route-map.py
"""
from starfox_rom import rom_hex, route_defaults, route_write
import hashlib
import json
import runpy
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SHA = '3857b5294ea8f7468849437bb2d8271564e8a0ff30774622e9c872bcbd53a84d'
ROM = (ROOT / 'ref/Star Fox (USA).sfc').read_bytes()
assert len(ROM) == 0x100000 and hashlib.sha256(ROM).hexdigest() == SHA and ROM[0x7fdb] == 0


def phys(bank, addr):
    return (bank & 0x7f) * 0x8000 + (addr & 0x7fff)


def blk(bank, addr, n):
    o = phys(bank, addr)
    return ROM[o:o + n]


def info(bank, addr, n, note=''):
    b = blk(bank, addr, n)
    return dict(addr=f'{bank:02X}:{addr:04X}', rom=f'0x{phys(bank, addr):05X}', size=n,
                sha256=hashlib.sha256(b).hexdigest(), note=note)


# ---------------------------------------------------------------- anchors
ANCHORS = [
    (0x03, 0xBF5C, rom_hex(0x1bf5c, 12), 'selection: gameframe bit1 -> drawplanetlines / undraw'),
    (0x03, 0xBF72, rom_hex(0x1bf72, 6), 'selection: trig0 & $2F00 (Select Up Down Left Right)'),
    (0x03, 0xBF88, rom_hex(0x1bf88, 6), 'selection: & $2A00 (Select Up Left) = previous route'),
    (0x03, 0xBFAE, rom_hex(0x1bfae, 6), 'sound $11 on route change'),
    (0x03, 0xBFB9, rom_hex(0x1bfb9, 6), 'selection: trig0 & $9080 (B Start A) = go'),
    (0x03, 0xC02A, rom_hex(0x1c02a, 6), 'stage>0 wait: trig0 & $D0C0 (B Y Start A X)'),
    (0x03, 0xC044, rom_hex(0x1c044, 12), 'go: sound $10, flashship=1, 83 frames'),
    (0x03, 0xC08A, rom_hex(0x1c08a, 3), 'window fade: 32 steps'),
    (0x03, 0xC0E1, rom_hex(0x1c0e1, 3), 'scroll: 32 frames'),
    (0x03, 0xC151, rom_hex(0x1c151, 12), 'dogccr -> VRAM $6820, $1000'),
    (0x03, 0xC184, rom_hex(0x1c184, 15), 'dogpcr -> VRAM $7C00, +2'),
    (0x03, 0xC1C3, rom_hex(0x1c1c3, 13), 'Pepper BG2 subtract 31'),
    (0x03, 0xC204, rom_hex(0x1c204, 5), 'BG1VOFS = -40'),
    (0x03, 0xC23A, rom_hex(0x1c23a, 3), 'zoom loop 40 (+1 on odd radius for sprite planets)'),
    (0x03, 0xC25C, rom_hex(0x1c25c, 3), 'sprite zoom radius limit 126'),
    (0x03, 0xC26B, rom_hex(0x1c26b, 3), 'sprite: pepperfade $FE at x == 20'),
    (0x03, 0xC27F, rom_hex(0x1c27f, 3), 'sphere: pepperfade $FE at x == 5'),
    (0x03, 0xC294, rom_hex(0x1c294, 3), 'sphere zoom radius limit 58'),
    (0x03, 0xC2CB, rom_hex(0x1c2cb, 5), 'fadetable 03:D660 read, value unused'),
    (0x03, 0xC2EF, rom_hex(0x1c2ef, 4), 'HDMA inidisp: Pepper visible to line 207'),
    (0x03, 0xC323, rom_hex(0x1c323, 10), 'typing sound $89 unless next glyph is 39 (space)'),
    (0x03, 0xC372, rom_hex(0x1c372, 12), 'message: read_joypadt + line 120 per char'),
    (0x03, 0xC386, rom_hex(0x1c386, 19), 'cut: Start ($1000) B ($8000) A ($0080)'),
    (0x03, 0xC3A3, rom_hex(0x1c3a3, 4), 'message ends at pepperchars 255'),
    (0x03, 0xC3AF, rom_hex(0x1c3af, 6), 'sound $13 on exit'),
    (0x03, 0xC3EC, rom_hex(0x1c3ec, 13), 'exit fade: subtract BG1+BG2'),
    (0x03, 0xC41F, rom_hex(0x1c41f, 2), 'exit fade: 32 steps'),
    (0x03, 0xC42B, rom_hex(0x1c42b, 14), 'setlevel: mapptr/mapbank <- newmap'),
    (0x03, 0xC4E9, rom_hex(0x1c4e9, 2), 'moveshipalongpath: y1 += delta'),
    (0x03, 0xC4EC, rom_hex(0x1c4ec, 3), 'newshipxy = y1 - $0810'),
    (0x03, 0xC495, rom_hex(0x1c495, 4), 'endplanetpos 03:D3FE'),
    (0x03, 0xBE9F, rom_hex(0x1be9f, 4), 'startplanetpos 03:D3DC'),
    (0x03, 0xC5D9, rom_hex(0x1c5d9, 6), 'copyfox: VRAM $5200 -> $6C20'),
    (0x03, 0xC5ED, rom_hex(0x1c5ed, 3), 'copyfox: 320 words'),
    (0x03, 0xC614, rom_hex(0x1c614, 8), 'window WH0 = planet x + 1'),
    (0x03, 0xC61D, rom_hex(0x1c61d, 5), 'window WH1 = WH0 + 29'),
    (0x03, 0xC65A, rom_hex(0x1c65a, 15), 'window: CGWSEL $20, CGADSUB $93'),
    (0x03, 0xC67D, rom_hex(0x1c67d, 6), 'route name at BG2 map $7F38'),
    (0x03, 0xC6A6, rom_hex(0x1c6a6, 6), 'score at BG2 map $7F18'),
    (0x03, 0xC6CC, rom_hex(0x1c6cc, 9), 'credits at $7EFB, tile $18DE'),
    (0x03, 0xC6FB, rom_hex(0x1c6fb, 3), 'digit tile $18A8 + d'),
    (0x03, 0xC8CF, rom_hex(0x1c8cf, 3), 'calcdxdy: centre x 112'),
    (0x03, 0xC8EC, rom_hex(0x1c8ec, 3), 'calcdxdy: centre y 88'),
    (0x03, 0xCB50, rom_hex(0x1cb50, 4), 'fadetab0 03:D420'),
    (0x03, 0xCB2C, rom_hex(0x1cb2c, 4), 'planselpal 03:D440'),
    (0x03, 0xCC34, rom_hex(0x1cc34, 5), 'drawplanetlines waits line 30'),
    (0x03, 0xCC79, rom_hex(0x1cc79, 3), 'PATHCHOICE: routes[] at $16D0'),
    (0x03, 0xD13B, rom_hex(0x1d13b, 10), 'pepperspeaking shadow: colour 5, clip $C0'),
    (0x03, 0xD171, rom_hex(0x1d171, 10), 'pepperspeaking text: colour 13, clip $BE'),
    (0x03, 0xD1CA, rom_hex(0x1d1ca, 10), 'name shadow: colour 1, clip $C0'),
    (0x03, 0xD1DF, rom_hex(0x1d1df, 3), 'name shadow y 50'),
    (0x03, 0xD203, rom_hex(0x1d203, 10), 'name text: colour 4, clip $BE'),
    (0x03, 0xD218, rom_hex(0x1d218, 3), 'name text y 48'),
    (0x02, 0x839B, rom_hex(0x1039b, 3), 'IRQ: OAM DMA of 28 entries (spriteblk 7E:1263)'),
    (0x02, 0x84AD, rom_hex(0x104ad, 6), 'IRQ: flashship += $40, hidden while bit 7'),
    (0x02, 0x8560, rom_hex(0x10560, 10), 'IRQ: ship chars $0D/$09/$05 by angle'),
    (0x02, 0x8579, rom_hex(0x10579, 2), 'IRQ: ship attribute $3E'),
    (0x02, 0x85BC, rom_hex(0x105bc, 10), 'IRQ: comet chars $11/$15'),
    (0x02, 0x85D5, rom_hex(0x105d5, 2), 'IRQ: comet attribute $1E'),
    (0x02, 0x85F2, rom_hex(0x105f2, 9), 'IRQ: comet ends x < 18 or y >= 224'),
    (0x02, 0x8661, rom_hex(0x10661, 3), 'IRQ: lightangle += $10 per frame'),
    (0x02, 0x866C, rom_hex(0x1066c, 2), 'IRQ: comet when lightangle hi == $A0'),
    (0x02, 0x8603, rom_hex(0x10603, 5), 'IRQ: lightangle hi = $1E after the comet'),
    (0x02, 0x8363, rom_hex(0x10363, 18), 'irqplanets2: pepperfade -1 per frame'),
    (0x01, 0xB509, rom_hex(0x0b509, 31), 'GSU mgprintstr'),
    (0x01, 0xB599, rom_hex(0x0b599, 14), 'GSU: stop when m_totalchars = 0, m_lastchar = next glyph'),
    (0x03, 0xCEEE, rom_hex(0x1ceee, 14), 'IRQ position 03:8000 (V) / 03:8002 (H)'),
    (0x03, 0xCDBC, rom_hex(0x1cdbc, 5), 'OBJSEL $01: OBJ base word $2000, 8x8/16x16'),
    (0x03, 0xBE3E, rom_hex(0x1be3e, 12), 'OBJ/dot characters 00:A08B -> VRAM $2020'),
]


def check_anchors():
    out = []
    for b, a, hx, note in ANCHORS:
        got = blk(b, a, len(hx) // 2).hex()
        assert got == hx, (f'{b:02X}:{a:04X}', got, hx)
        out.append(dict(addr=f'{b:02X}:{a:04X}', bytes=hx, meaning=note))
    return out


# ---------------------------------------------------------------- stagepaths
SP = (0x03, 0xD671)
SP_END = 0xD8EB
SPD = blk(0x03, 0xD671, SP_END - 0xD671)
PATH_NAMES = [f'path{i}' for i in range(1, 23)] + ['end3', 'end2', 'end', 'otherend']
ROUTES_DEFAULT = route_defaults()
ROUTE_CHANGES = [  # routine, bank 03 entry, callers
    ('routechange1', 0xd0c2, '02:E4A7 (levelfinished 14), 04:A6AE; also nebula_on 7E:F0CC'),
    ('routechange2', 0xd0d1, '0A:DED6'),
    ('routechange3', 0xd0dc, 'no literal caller in rev0'),
    ('bhole1', 0xd0e7, '02:E495 (levelfinished 11)'),
    ('bhole2', 0xd0f2, '02:E49B (levelfinished 12)'),
    ('bhole3', 0xd0fd, '02:E4A1 (levelfinished 13)'),
]
SEGNAME = {0x4e04: 'PATHUP (char 4, h-flip)', 0x0e02: 'PATHUPRIGHT (char 2)', 0x0e03: 'PATHRIGHT (char 3)',
           0x0e00: 'hidden (char 0)'}


def w16(o):
    return SPD[o] | SPD[o + 1] << 8


def s8(v):
    return v - 256 if v > 127 else v


def parse_stagepaths():
    recs, i = [], 6
    names = iter(PATH_NAMES)
    while i < len(SPD):
        op = SPD[i]
        if op == 3:
            x, y, pl, lo, hi, bk, msg, lev = SPD[i + 1:i + 9]
            segs, j = [], i + 9
            while w16(j) != 0xffff:
                segs.append(dict(offset=j, char_word=f'{w16(j):04X}', kind=SEGNAME[w16(j)],
                                 dx=s8(SPD[j + 2]), dy=s8(SPD[j + 3])))
                j += 4
            recs.append(dict(offset=i, name=next(names), op='PATHSTART', cell=[x, y], pixel=[8 * x, 8 * y],
                             planet=pl, newmap_raw=f'{bk:02X}:{hi << 8 | lo:04X}',
                             map_addr=f'{bk:02X}:{(hi << 8 | lo) | 0x8000:04X}', peppermsg=msg, currentlevel=lev,
                             segments=segs))
            i = j + 2
        elif op in (1, 2):
            recs.append(dict(offset=i, op='PATHNEXT' if op == 1 else 'PATHCHOICE', operand=SPD[i + 1] | SPD[i + 2] << 8))
            i += 3
        elif op == 0:
            recs.append(dict(offset=i, op='NOMOREPATHS'))
            i += 1
        else:
            raise AssertionError(i)
    assert i == len(SPD) and next(names, None) is None
    return recs


def convertaddr(x, y):
    return (x * 8 & 0xff) | (y * 8 & 0xff) << 8


class Map:
    """65816 state used by drawplanetlines/moveshipalongpath/IRQ (rev0 RAM)."""

    def __init__(self, whichroute, stage, routes=None):
        self.route = whichroute            # converted index: 0 = LEVEL 2, 1 = LEVEL 1, 2 = LEVEL 3
        self.stage = stage
        self.routes = list(routes or ROUTES_DEFAULT)
        self.spr = [[0, 0, 0, 0] for _ in range(28)]   # spriteblk (x, y, char, attr); p_init_sprites clears
        self.cursprite = 8
        self.x1 = self.y1 = 0
        self.planet = self.newmap = self.msg = self.level = None
        self.shipxy = self.newshipxy = 0
        self.shipangle = 1

    def undraw(self):
        self.cursprite = 8
        for k in range(8, 28):
            self.spr[k][0] = self.spr[k][1] = 0xf8

    def draw(self):
        """drawplanetlines_l 03:CC2A. Returns True (sec) at NOMOREPATHS, False (clc) at PATHSTART with x1 = 0."""
        self.cursprite = 8
        x1 = self.stage
        x = w16(2 * self.route & 0xff)
        writes = []
        while True:
            op = SPD[x]
            if op == 0:
                return True, writes
            if op == 3:
                y = convertaddr(SPD[x + 1], SPD[x + 2])
                self.planet = SPD[x + 3]
                self.newmap = SPD[x + 4] | SPD[x + 5] << 8 | SPD[x + 6] << 16
                self.msg, self.level = SPD[x + 7], SPD[x + 8]
                x += 9
                if x1 == 0:
                    self.x1, self.y1 = x, y
                    return False, writes
                while True:
                    s = self.spr[self.cursprite]
                    s[0], s[1] = y & 0xff, y >> 8
                    y = (y + w16(x + 2)) & 0xffff
                    c = w16(x)
                    if c == 0xffff:
                        writes.append(('stray', self.cursprite, s[0], s[1]))
                        x += 2
                        x1 -= 1
                        break
                    s[2], s[3] = c & 0xff, c >> 8
                    writes.append(('marker', self.cursprite, s[0], s[1], c))
                    self.cursprite += 1
                    x += 4
            elif op == 1:
                x = w16(x + 1)
            else:
                x = self.routes[w16(x + 1) // 2]

    def move(self, start_end):
        """moveshipalongpath 03:C470; returns True when finished (sec)."""
        if self.shipxy != self.newshipxy:
            return False
        x = self.x1
        if x and SPD[x] < 0x80:
            c = SPD[x]
            self.shipangle = 0 if c == 4 else 1 if c == 2 else 2
            s = self.spr[self.cursprite]
            s[2], s[3] = c, SPD[x + 1]
            s[0], s[1] = self.y1 & 0xff, self.y1 >> 8
            self.cursprite += 1
            self.y1 = (self.y1 + w16(x + 2)) & 0xffff
            self.newshipxy = (self.y1 - 0x0810) & 0xffff
            self.x1 = x + 4
            return False
        self.draw()
        self.x1 = 0
        ex, ey = start_end['end'][self.planet]
        self.newshipxy = ex | ey << 8
        if self.newshipxy == self.shipxy:
            return True
        if (ey - (self.shipxy >> 8)) & 0x80:   # lda newY; cmp shipY; bmi .different
            return False
        self.newshipxy = (self.newshipxy & 0xff) | (self.shipxy & 0xff00)
        return self.newshipxy == self.shipxy


def irq_ship_step(sx, sy, nx, ny):
    """irqplanets 02:84D4..852E: one frame of ship movement (8-bit, rev0)."""
    if (sy - ny) & 0x80:                        # bmi .incit
        sy = (sy + 1) & 0xff
        if sx != nx:
            sx = (sx + 1) & 0xff
        return sx, sy
    d = (sx - nx) & 0xff
    if d:
        if sx >= nx:
            e = (sy - ny) & 0xff
            if e == 0 or e == d:
                sx = (sx - 1) & 0xff
        else:
            e = (ny - sy) & 0xff
            if e == 0 or e == d:
                sx = (sx + 1) & 0xff
    if sy != ny:
        if not (sy - ny) & 0x80:
            sy = (sy - 1) & 0xff
        else:
            sy = (sy + 1) & 0xff
            if sx != nx:
                sx = (sx + 1) & 0xff
    return sx, sy


def ship_oam(sx, sy, angle):
    c = (9, 5, 0x0d)[angle]
    return [[(sx + 8) & 0xff, (sy + 8) & 0xff, c, 0x3e], [(sx + 16) & 0xff, (sy + 8) & 0xff, c + 1, 0x3e],
            [(sx + 8) & 0xff, (sy + 16) & 0xff, c + 2, 0x3e], [(sx + 16) & 0xff, (sy + 16) & 0xff, c + 3, 0x3e]]


def flight(route, stage, routes, se, pass_frames=None, max_frames=4000):
    """planetseq_l with stage > 0 (.shownext 03:BFDD): markers of completed stages, ship targets
    and, if pass_frames is given, a per-frame simulation where moveshipalongpath runs once every
    pass_frames frames (the IRQ moves the ship every frame)."""
    m = Map(route, stage, routes)
    m.draw()
    nxt = m.planet
    m.stage = stage - 1
    m.draw()
    done_planet = m.planet
    m.stage = stage
    sx, sy = se['start'][done_planet]
    m.shipxy = m.newshipxy = sx | sy << 8
    base = [list(s) for s in m.spr]
    targets, frames = [], []
    if pass_frames is None:  # targets only: pass = instantaneous when the ship arrives
        while True:
            m.shipxy = m.newshipxy
            fin = m.move(se)
            targets.append(dict(newshipxy=[m.newshipxy & 0xff, m.newshipxy >> 8], angle=m.shipangle,
                                markers=sum(1 for k in range(8, 28) if m.spr[k][2] or m.spr[k][3])))
            if fin:
                break
        return dict(route=route, stage=stage, completed_planet=done_planet, next_planet=nxt,
                    ship_start=[sx, sy], initial_oam_lines=base[8:28], targets=targets)
    f = 0
    while f < max_frames:
        if f % pass_frames == pass_frames - 1:
            if m.move(se):
                break
        sx, sy = m.shipxy & 0xff, m.shipxy >> 8
        sx, sy = irq_ship_step(sx, sy, m.newshipxy & 0xff, m.newshipxy >> 8)
        m.shipxy = sx | sy << 8
        frames.append([sx, sy])
        f += 1
    return frames


# ---------------------------------------------------------------- scroll (calcdxdy)
def scroll_path(px, py):
    """continuewithgame .scrollitabit 03:C0E1: 32 frames, BG1HOFS/VOFS per frame (16-bit, rev0)."""
    def divide(a, f, rem):
        if a < 0x8000:
            x = -1
            while True:
                x += 1
                c = a >= f
                a = (a - f) & 0xffff
                if not c:
                    break
            a = (a + f) & 0xffff
            a = (a + rem) & 0xffff
            if a >= f:
                a = (a - f) & 0xffff
                x += 1
            return x & 0xffff, a
        x = 1
        while True:
            x -= 1
            c = a + f > 0xffff
            a = (a + f) & 0xffff
            if c:
                break
        a = (a - f) & 0xffff
        a = (a + rem) & 0xffff
        if a >= f:
            a = (a - f) & 0xffff
            x -= 1
        return x & 0xffff, a
    sx = sy = dxl = dyl = 0
    out = []
    for f in range(32, 0, -1):
        rem = dxl
        a = (px - 0x70 - sx) & 0xffff
        dx = 0
        if a:
            dx, rem = divide(a, f, rem)
        dxl = rem
        rem = dyl
        a = (py - 0x58 - sy) & 0xffff
        dy = 0
        if a:
            dy, rem = divide(a, f, rem)
        dyl = rem
        sx = (sx + dx) & 0xffff
        sy = (sy + dy) & 0xffff
        out.append([sx, sy])
    return out


# ---------------------------------------------------------------- data blocks
def planet_tables():
    sprs = [blk(0x03, 0xD365 + 2 * i, 2) for i in range(17)]
    names = list(blk(0x03, 0xD387, 17))
    pos = [blk(0x03, 0xD398 + 4 * i, 4) for i in range(17)]
    start = [list(blk(0x03, 0xD3DC + 2 * i, 2)) for i in range(17)]
    end = [list(blk(0x03, 0xD3FE + 2 * i, 2)) for i in range(17)]
    planets = []
    for i in range(17):
        p = pos[i]
        planets.append(dict(index=i, sphere=bool(sprs[i][0] & 0x80), sprite_id=sprs[i][0] & 0x7f,
                            rot_select=sprs[i][1], name_msg=names[i],
                            bg1_cell_word=f'{p[0] | p[1] << 8:04X}', pixel=[p[2], p[3]],
                            ship_start=start[i], ship_end=end[i],
                            window=dict(wh0=(p[2] + 1) & 0xff, wh1=(p[2] + 30) & 0xff,
                                        hdma_lines=[p[3] >> 1, p[3] - (p[3] >> 1)], height=30),
                            scroll_to_centre=scroll_path(p[2], p[3])))
    return planets


def bgr(c):
    return f'{c:04X}'


def palettes():
    pal = blk(0x03, 0xD440, 0x220)
    words = [pal[2 * i] | pal[2 * i + 1] << 8 for i in range(0x110)]
    fade = blk(0x03, 0xD420, 32)
    return dict(
        planselpal=dict(**info(0x03, 0xD440, 512, 'CGRAM 0..255: rows 0..14 map_c.col, row 15 map-obj.col'),
                        colours=[bgr(c) for c in words[:256]]),
        planselpal_tail_unused=dict(**info(0x03, 0xD640, 32, 'after planselpal; setupplanetpal copies 512 B only'),
                                    colours=[bgr(c) for c in words[256:]]),
        obj_palette_row15=[bgr(c) for c in words[240:256]],
        bg2_row6_pepper_text=[bgr(c) for c in words[96:112]],
        fadetab0=dict(**info(0x03, 0xD420, 32, 'CGRAM colour 0 during the window fade: entry = step >> 1'),
                      colours=[bgr(fade[2 * i] | fade[2 * i + 1] << 8) for i in range(16)]),
        fadetable_unused=dict(**info(0x03, 0xD660, 17, 'read at 03:C2CB, never stored'), bytes=blk(0x03, 0xD660, 17).hex()))


def obj_chars():
    raw = blk(0x00, 0xA08B, 960)
    tiles = []
    for t in range(30):
        b = raw[32 * t:32 * t + 32]
        px = []
        for y in range(8):
            for x in range(8):
                s = 7 - x
                px.append((b[2 * y] >> s & 1) | (b[2 * y + 1] >> s & 1) << 1 |
                          (b[16 + 2 * y] >> s & 1) << 2 | (b[17 + 2 * y] >> s & 1) << 3)
        tiles.append(dict(obj_char=2 + t, pixels=''.join(f'{p:x}' for p in px)))
    return dict(**info(0x00, 0xA08B, 960, 'copied to VRAM words $2020 and $5020; OBJ base $2000 -> OBJ chars 2..31'),
                use={'2': 'route up-right', '3': 'route right', '4': 'route up (h-flip)', '0': 'hidden segment',
                     '5-8': 'ship angle 1 (up-right)', '9-12': 'ship angle 0 (up)', '13-16': 'ship angle 2 (right)',
                     '17-20 / 21-24': 'comet frames (alternate every IRQ)'},
                tiles=tiles)


def hdma_tables():
    src = blk(0x02, 0x8FD0 + 0x493, 0x20)
    return dict(source=info(0x02, 0x8FD0, 0xD80, 'hdma_start copied to 7E:4163 by setup_planets_l'),
                inidisp_pepper_ch1='7E:45F6 ' + src[0:9].hex(),
                inidisp_map_ch3='7E:45FF ' + src[9:20].hex(),
                window_ch2='7E:460A ' + src[20:29].hex(),
                map_visible_lines=[15, 214], map_fadein_brightness=[1, 3, 5, 7, 9, 11, 13, 15],
                pepper_visible_lines_zoom=[47, 175], pepper_visible_lines_text=[47, 207])


def pepper_layout(radio):
    import collections
    dec = runpy.run_path(str(ROOT / 'tools/extract-intro-background.py'))['decode']
    conv = runpy.run_path(str(ROOT / 'tools/convert-screen-bg.py'), run_name='route-map')
    pcr, pinfo = conv['mdecru'](ROM, dec, 0x17, 0x827C)
    cells = []
    for cy in range(32):
        for cx in range(32):
            w = pcr[2 * (32 * cy + cx)] | pcr[2 * (32 * cy + cx) + 1] << 8
            t = w & 1023
            if t < 384:
                cells.append(dict(screen_cell=[cx, cy], bitmap_tile=[t >> 4, t & 15], priority=w >> 13 & 1,
                                  palette=w >> 10 & 7))
            elif 448 <= t < 468:
                cells.append(dict(screen_cell=[cx, cy], fox_tile=t - 448, mapccr_tile=t - 448, palette=w >> 10 & 7))
    rows = collections.Counter(tuple(c['bitmap_tile']) for c in cells if 'bitmap_tile' in c)
    assert all(v == 1 for v in rows.values())
    return dict(dogpcr=pinfo, note='BG2 tile = raw + 2; bitmap 4bpp column-major, 16 tiles per column; '
                'raw < 384 = text bitmap (GSU 7000:2C00 -> VRAM $5020/$5820/$6020 in 3 IRQs), '
                'raw 448..467 = Fox face copied from mapccr tiles 0..19 (copyfox)', cells=cells)


def texts(radio, msgs):
    ptr = blk(0x01, 0xFBB8, 2 * 142)

    def text_of(mid):
        a = ptr[2 * (mid - 1)] | ptr[2 * (mid - 1) + 1] << 8
        o = phys(0x01, a) + 3
        e = ROM.index(0, o)
        return a, ROM[o:e].decode('latin1')

    def lay(mid, x_text, y_text, clip):
        a, s = text_of(mid)
        lines = radio.layout(s.encode('latin1'), x_text, clip + x_text)
        seq = []
        for n, ln in enumerate(lines):
            x = x_text
            for ch in ln['text']:
                t = radio.trn[ord(ch)]
                seq.append(dict(c=ch, glyph=t, x=x, y=y_text + 13 * n, line=n))
                x += 5 if t == 0 else radio.wid[t]
        return dict(id=mid, ptr=f'01:{a:04X}', text=s, lines=[ln['text'] for ln in lines],
                    widths=[ln['width'] for ln in lines], chars=len(seq),
                    sounds=sum(1 for g in seq if g['glyph'] != 39) + 1,
                    sequence=seq)
    out = dict(names={}, messages={})
    for mid in sorted(set(msgs['names'])):
        out['names'][mid] = lay(mid, 0, 48, 190)
    for mid in sorted(set(msgs['messages'])):
        d = lay(mid, 0, 0, 190)
        d['rows_used'] = 13 * (len(d['lines']) - 1) + 12 + 2
        d['fits_48_rows'] = d['rows_used'] <= 48
        out['messages'][mid] = d
    out['params'] = dict(
        name=dict(shadow=dict(x=2, y=50, colour=1), text=dict(x=0, y=48, colour=4), clip=190),
        message=dict(shadow=dict(x=2, y=2, colour=5), text=dict(x=0, y=0, colour=13), clip=190),
        line_pitch=13, kernel='GSU mgprintstr 01:B509 -> mprintstr 01:B566 (m_totalchars typewriter)',
        typing='per pass k: draw the first k glyphs (shadow then text) of the line buffers; '
               'm_lastchar = glyph k; sound $89 if m_totalchars = 0 and glyph k != 39; name: exit when '
               'm_totalchars != 0 (k = chars + 1); message: continue to pepperchars 255 or Start/B/A')
    return out


def route_table(recs, routes):
    """Every stage of each route as drawplanetlines sees it with the given routes[]."""
    out = []
    for r in range(3):
        stages = []
        for st in range(12):
            m = Map(r, st, routes)
            fin, wr = m.draw()
            if fin:
                break
            stages.append(dict(stage=st, planet=m.planet, newmap=f'{m.newmap >> 16:02X}:{m.newmap & 0xffff:04X}',
                               peppermsg=m.msg, currentlevel=m.level,
                               markers_before=[list(w[1:]) for w in wr if w[0] == 'marker'],
                               stray_write=[list(w[1:]) for w in wr if w[0] == 'stray'][-1:]))
        m = Map(r, 10, routes)
        m.draw()
        sel = [dict(slot=k, x=s[0], y=s[1], char=s[2], attr=s[3]) for k, s in enumerate(m.spr) if k >= 8 and (s[2] or s[3] or s[0] or s[1])]
        out.append(dict(whichroute_converted=r, label={0: 'LEVEL 2', 1: 'LEVEL 1', 2: 'LEVEL 3'}[r],
                        selection_markers_stage10=sel, stages=stages))
    return out


def snes_tiles_4bpp(raw, n):
    out = []
    for t in range(n):
        b = raw[32 * t:32 * t + 32]
        out.append([(b[2 * y] >> (7 - x) & 1) | (b[2 * y + 1] >> (7 - x) & 1) << 1 |
                    (b[16 + 2 * y] >> (7 - x) & 1) << 2 | (b[17 + 2 * y] >> (7 - x) & 1) << 3
                    for y in range(8) for x in range(8)])
    return out


GLYPHS = {}


def render_pepper(model, radio, planet, msg, k_msg=None):
    """Pepper bitmap (192x128, GSU colours) as showplanetname + pepperspeaking draw it."""
    img = [[0] * 192 for _ in range(128)]
    texts = model['pepper_texts']

    def draw(seq, dx, dy, colour):
        for g in seq:
            t = g['glyph']
            if t == 0:
                continue
            if t not in GLYPHS:
                GLYPHS[t] = radio.glyph(t)
            for r, row in enumerate(GLYPHS[t]):
                for i in range(radio.wid[t]):
                    x, y = g['x'] + dx + i, g['y'] + dy + r
                    if row[i] and 0 <= x < 192 and 0 <= y < 128:
                        img[y][x] = colour
    name = texts['names'][model['planets'][planet]['name_msg']]['sequence']
    draw(name, 2, 2, 1)
    draw(name, 0, 0, 4)
    if msg:
        seq = texts['messages'][msg]['sequence']
        seq = seq if k_msg is None else seq[:k_msg]
        draw(seq, 2, 2, 5)
        draw(seq, 0, 0, 13)
    return img


def timeline(g, model, radio):
    """Events of a probe run (one sample per frame)."""
    rows = g['rows']
    ev, prev = [], {}
    for o in rows:
        b = bytes.fromhex(o['oam'])
        cur = dict(trans_flag=o['trans_flag'], ship_hidden=all(v == 0 for v in b[16:32]),
                   scroll=(o['bg1scrx'], o['bg1scry']), pepperfade=o['pepperfade'], pepperchars=o['pepperchars'],
                   hdma_45fa=bytes.fromhex(o['hdma'])[4], mapptr=o['mapptr'], stage=o['stage'], planet=o['planet'],
                   ship=(o['shipxy'] & 0xff, o['shipxy'] >> 8), target=(o['newshipxy'] & 0xff, o['newshipxy'] >> 8))
        for k, v in cur.items():
            if prev.get(k) != v:
                ev.append([o['frame'], k, list(v) if isinstance(v, tuple) else v])
        prev = cur
    res = dict(frames=len(rows), events=ev)
    pc = [(o['frame'], o['pepperchars']) for o in rows]
    inc = [f for (f, c), (_, c0) in zip(pc[1:], pc) if c != c0]
    res['pepperchars_change_frames'] = inc
    sc = []
    for o in rows:
        v = [o['bg1scrx'], o['bg1scry']]
        if not sc or sc[-1] != v:
            sc.append(v)
    planet = next((o['planet'] for o in rows if o['trans_flag'] == 8 and o['planet'] < 17), None)
    if planet is not None:
        model_sc = model['planets'][planet]['scroll_to_centre']
        res['scroll_planet'] = planet
        res['scroll_distinct_values'] = sc
        res['scroll_matches_model'] = any(sc[i:i + 32] == model_sc for i in range(len(sc)))
    if any(o['trans_flag'] == 8 and o['stage'] > 0 and o['planet'] == 0xff for o in rows):
        # flight: check the IRQ rule frame by frame and the target sequence against the model
        ok = bad = 0
        tg = []
        for a, b in zip(rows, rows[1:]):
            sa, sb = a['shipxy'], b['shipxy']
            if a['newshipxy'] != (tg[-1] if tg else None):
                tg.append(a['newshipxy'])
            if sa != a['newshipxy'] or sb != sa:
                exp = irq_ship_step(sa & 0xff, sa >> 8, a['newshipxy'] & 0xff, a['newshipxy'] >> 8)
                if a['newshipxy'] == b['newshipxy']:
                    if [sb & 0xff, sb >> 8] == list(exp):
                        ok += 1
                    else:
                        bad += 1
        st = rows[0]['stage']
        model_t = [t['newshipxy'] for t in flight(rows[0]['route'], st, ROUTES_DEFAULT, SE)['targets']]
        moves = [o['frame'] for a, o in zip(rows, rows[1:]) if o['newshipxy'] != a['newshipxy']]
        res['flight'] = dict(route=rows[0]['route'], stage=st, irq_steps_ok=ok, irq_steps_bad=bad,
                             targets_measured=[[t & 0xff, t >> 8] for t in tg],
                             targets_model=model_t, target_change_frames=moves,
                             first_visible_ship_frame=next((o['frame'] for o in rows if bytes.fromhex(o['oam'])[18]), None))
    mk = g.get('mark', {})
    if 'text_bitmap_5020' in mk:
        raw = bytes.fromhex(mk['text_bitmap_5020'])
        tiles = snes_tiles_4bpp(raw, 384)
        img = [[0] * 192 for _ in range(128)]
        for t, px in enumerate(tiles):
            c, r = t >> 4, t & 15
            for i, v in enumerate(px):
                img[8 * r + i // 8][8 * c + i % 8] = v
        msg = model['routes'][g['start']['route']]['stages'][g['start']['stage']]['peppermsg']
        n = model['pepper_texts']['messages'][msg]['chars']
        def cost(k):
            e = render_pepper(model, radio, 0, msg, k)
            return sum(1 for y in range(128) for x in range(192) if img[y][x] != e[y][x])
        best = min(range(n + 1), key=cost)
        exp = render_pepper(model, radio, 0, msg, best)
        diff = sum(1 for y in range(128) for x in range(192) if img[y][x] != exp[y][x])
        res['text_bitmap'] = dict(vram_frame=mk['vram_full'], planet=0, message=msg, best_glyph_count=best,
                                  differing_pixels=diff, nonzero_pixels=sum(1 for row in img for v in row if v))
        dec = runpy.run_path(str(ROOT / 'tools/extract-intro-background.py'))['decode']
        conv = runpy.run_path(str(ROOT / 'tools/convert-screen-bg.py'), run_name='route-map')
        mapccr, _ = conv['mdecru'](ROM, dec, 0x15, 0xE898)
        res['fox_vram_6c20_equals_mapccr_0_19'] = bytes.fromhex(mk['fox_6c20']) == mapccr[:640]
    return res


def measured(model, radio):
    res = {}
    d = ROOT / 'build/research/route-map'
    p = d / 'probe-select.json'
    if p.exists():
        s = json.loads(p.read_text())

        def lines(o):
            b = bytes.fromhex(o['oam'])
            return [list(b[4 * k:4 * k + 4]) for k in range(8, 28)]
        ok = []
        m = Map(1, 10)  # carry spriteblk across the changes, starting from the probed OAM buffer
        b0 = bytes.fromhex(s['idle'][0]['oam'])
        m.spr = [list(b0[4 * k:4 * k + 4]) for k in range(28)]
        for ch in s['changes']:
            r = ch['rows'][-1]['route']
            lit = [lines(o) for o in ch['rows'] if any(e[:2] != [0xf8, 0xf8] for e in lines(o))]
            m.undraw()
            m.route = r
            m.draw()
            ok.append(dict(button=ch['button'], route=r,
                           oam_8_27_equal=bool(lit) and lit[-1] == [list(e) for e in m.spr[8:28]],
                           stray=[e for e in lit[-1] if e[:2] == [0, 0]] if lit else None,
                           bg2_row25=[f'{v:04X}' for v in ch['bg2_rows_23_25'][2][24:30]]))
        gfs = [o['gf'] for o in s['idle']]
        changes = [i for i in range(1, len(gfs)) if gfs[i] != gfs[i - 1]]
        res['select'] = dict(route_changes=ok, frames_per_pass=[b - a for a, b in zip(changes, changes[1:])])
    for case in ('go', 'next', 'cut', 'text', 'flight'):
        p = d / f'probe-{case}.json'
        if p.exists():
            res[case] = timeline(json.loads(p.read_text()), model, radio)
    return res


SE = {}


def comet_model():
    frames = []
    lx, ly, c = 0xff, 0, 0x15
    while True:
        c = 0x15 if c == 0x11 else 0x11
        frames.append([(lx - 15) & 0xff, ly & 0xff, c])
        lx, ly = lx - 2, ly + 2
        if lx < 0x12 or ly >= 0xe0:
            break
    return dict(trigger='irqplanets: lightangle += $10 per IRQ; when lightangle hi == $A0: comet = 1, lightx = 255, lighty = 0',
                after='comet = 0, lightangle hi = $1E -> next comet after (0xA0 - 0x1E) * 16 = 2080 IRQs',
                sound='$91 in copylight when comet goes 0 -> 1 (main loop)',
                oam='entries 0..3: (X,Y,c) (X,Y+8,c+2) (X+8,Y,c+1) (X+8,Y+8,c+3), attr $1E (pri 1, pal 7); X = lightx - 15',
                frames_x_y_char=frames)


def main():
    anchors = check_anchors()
    recs = parse_stagepaths()
    names = {row['offset']: row['name'] for row in recs if row['op'] == 'PATHSTART'}
    route_changes = {}
    for routine, entry, callers in ROUTE_CHANGES:
        index, value = route_write(entry + 3)
        route_changes[f'{routine} 03:{entry:04X}'] = dict(index=index, value=f'{value:03X} {names[value]}', callers=callers)
    planets = planet_tables()
    se = dict(start={p['index']: tuple(p['ship_start']) for p in planets},
              end={p['index']: tuple(p['ship_end']) for p in planets})
    SE.update(se)
    radio_ns = runpy.run_path(str(ROOT / 'tools/extract-radio.py'), run_name='route-map')
    radio = radio_ns['Radio'](ROM)
    routes_tbl = route_table(recs, ROUTES_DEFAULT)
    msgs = dict(names=[p['name_msg'] for p in planets],
                messages=[r['peppermsg'] for r in recs if r['op'] == 'PATHSTART'])
    flights = []
    for r in range(3):
        for st in range(1, len(routes_tbl[r]['stages'])):
            flights.append(flight(r, st, ROUTES_DEFAULT, se))
    model = dict(
        rom=dict(file='ref/Star Fox (USA).sfc', sha256=SHA, revision='USA rev0', mapping='LoROM, no header'),
        generated_by='tools/extract-route-map.py',
        anchors=anchors,
        ram=dict(stage='$16D8', whichroute='$16DA (converted while on the map: 0 LEVEL 2, 1 LEVEL 1, 2 LEVEL 3)',
                 currentplanet='$16DB', routes='$16D0..$16D7', gameframe='$15BD', flashship='$34',
                 shipxy='$32 (x) $33 (y)', newshipxy='$38/$39', shipangle='$36', x1='$02', y1='$08',
                 currentsprite='$30', spriteblk='7E:1263 (28 OAM entries: 0..3 comet, 4..7 ship, 8..27 route)',
                 planetdma='$1FE7', comet='$16EF', lightx='$16E6', lighty='$16E8', lightangle='$16EC',
                 pepperfade='7E:F0B8', pepperchars='7E:F0B9', peppermsg='7E:F0BA', newmap='$1FF9..$1FFB',
                 currentlevel='$1FFF', bg1scr='$10/$12', scrd='$18/$1A', scrdl='$1E/$20', remainder='$22',
                 trig0='$1209', cont0l='$1201', mspr_pal='70:009A', m_radius='70:01F2', m_totalchars='70:00BC',
                 m_lastchar='70:00BE'),
        stagepaths=dict(**info(0x03, 0xD671, SP_END - 0xD671), header=[w16(0), w16(2), w16(4)],
                        records=recs, routes_default=[f'{v:03X} {names[v]}' for v in ROUTES_DEFAULT],
                        route_changes=route_changes),
        planet_tables=dict(planetsprs=info(0x03, 0xD365, 34), planetnames=info(0x03, 0xD387, 17),
                           planetpos=info(0x03, 0xD398, 68), startplanetpos=info(0x03, 0xD3DC, 34),
                           endplanetpos=info(0x03, 0xD3FE, 34)),
        planets=planets,
        routes=routes_tbl,
        flights=flights,
        route_name=dict(bg2_map_word=0x7F38, cell=[24, 25], tiles={'0 (LEVEL 2)': '1894..1899', '1 (LEVEL 1)': '188E..1893',
                                                                  '2 (LEVEL 3)': '189A..189F'},
                        chars_table=info(0x03, 0xC702, 6, 'dw $1894,$188E,$189A (palette 6, BG2 tile = mapccr + 32)'),
                        score=dict(cell=[24, 24], digits=3, tile='$18A8 + digit', suffix='2 x $18A8 ("00")',
                                   value='sum of specbuf[0..specptr-1] skipping 101 (calctotalscore 02:E8A6)',
                                   digit_method='repeated subtraction of 100, 10, 1 (no clamp)'),
                        credits=dict(cell=[27, 23], tile='$18DE', count='credits $189A')),
        comet=comet_model(),
        ship_flash=dict(rule='IRQ: if flashship bit0: flashship += $40; ship entries 4..7 zeroed while bit 7 of the new value',
                        pattern_from_first_irq=['visible' if (1 + 64 * n) & 0x80 == 0 else 'hidden' for n in range(1, 9)]),
        ship_oam=dict(entries='4..7 = (x+8,y+8,c) (x+16,y+8,c+1) (x+8,y+16,c+2) (x+16,y+16,c+3), attr $3E (pri 3, pal 7)',
                      chars_by_angle={'0 up (segment char 4)': 9, '1 up-right (char 2, initial)': 5, '2 right (char 3 or 0)': 13}),
        sounds=dict(route_change='$11', go='$10 (and startbgm $F1)', typing='$89', exit='$13', comet='$91',
                    bgm=dict(map='jsl 03:AD89', black_hole_or_ootd_next='$0F', pepper_sphere='$0B', pepper_sprite='$0D')),
        timeline_code=dict(
            map_fadein='8 steps INIDISP 1,3,..,15 via HDMA ch3, 1 frame each',
            selection_pass='gameframe++ ; spheres GSU ; dma256screen 4 IRQ ; switch ; draw (waits line 30) / undraw ; read pad once',
            go_blink='83 x waitdma224; IRQ flashship += $40: ship hidden while bit 7 (2 frames on, 2 off)',
            window='sei; line 224; setupplanetwindow; 2 frames; 32 steps: colour 0 = fadetab0[i>>1], COLDATA = $E0|i',
            only_planet='clearscreen; TM=BG1; drawselectedplanet; dma256 (4 IRQ); switch; window off',
            scroll='32 frames: BG1 scroll by calcdxdy towards (112,88)',
            pepper_setup='HDMA ch1 (lines 47..175); dogccr/dogpcr; copyfox; TM=BG1+BG2; BG2 subtract 31; IRQ V=186 irqplanets2',
            zoom='sphere 40 iterations radius 15->55, pepperfade $FE at x=5; sprite 80 iterations radius 15->95, at x=20; '
                 'pepperfade: BG2 subtract 29..0, one step per IRQ',
            typing='IRQ V=222; HDMA to line 207; name: 1 glyph per pass (clear+print+3-IRQ DMA); message: 1 glyph per pass '
                   '(+ read_joypadt + line 120), up to pepperchars 255; Start/B/A cut',
            exit='sound $13; 2 frames; sei; 32 frames subtract BG1+BG2 0..31; convertroute; setlevel; jml gamestart 02:E3BF'),
        palettes=palettes(),
        obj_chars=obj_chars(),
        hdma=hdma_tables(),
        pepper_bg2=pepper_layout(radio),
        pepper_texts=texts(radio, msgs),
        fox_copy=dict(source='VRAM words $5200..$533F = BG2 tiles 32..51 = mapccr tiles 0..19 (map cells (6..9,3..7))',
                      dest='VRAM $6C20 = BG2 tiles 450..469 = dogpcr raw 448..467 (cells (26..29,15..19))',
                      note='dogccr tiles 64..83 are zero in ROM: the face exists only after copyfox'),
    )
    model['measured'] = measured(model, radio)
    out = ROOT / 'build/route-map.json'
    out.write_text(json.dumps(model, indent=1) + '\n')
    print(f'{out}: {len(recs)} records, {len(flights)} flights, sha256 {hashlib.sha256(out.read_bytes()).hexdigest()[:16]}')
    for k, v in model['measured'].items():
        print(k, json.dumps(v)[:600])


if __name__ == '__main__':
    sys.exit(main())

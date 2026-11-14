"""Stage backgrounds (setbg n -> bglists 03:AC42) -> Mega Drive plane B data.

ROM authority: ref/Star Fox (USA).sfc (USA rev0, SHA-256 3857b529...).
For every background number used by the stage maps, the routine reached
through bglists 03:AC42+n is read from the ROM with a small 65816 model
(linear, M/X widths tracked, forward branches marked conditional, waittrans
loops recognised by their bytes) and every effect it has is recorded:
initmode (03:AAF9 mode 1 / 03:AB12 mode 2), the inline helpers bg2chr
03:AB95, bg2scr 03:ABCD and palette 03:ABFE (inline arguments), the BG3
decrunchers 03:AB2B/03:AB60 with their WRAM arguments, the stores (levelinfo
$1787, newplayerstrat $1788/$178A, $14DD/$14DE, gamepal $1899, zdepth table
70:0050, hofmode $1FE4, bg2Yscroll $169E/$194F, m_meters 70:021C, 70:004E/4F,
shadowheight $1961, inatunnel $16CB, gamemode $18C4, ...), the HDMA enable
bits ($120E |= n, HDMAEN $420C), and the long calls (changeviewmode 06:BA91,
setgamepal 02:F484, music 03:ADxx/AExx, shared parts in bank 03).
Guidance only: UltraStarFox SF/ASM/BGS.ASM and SF/INC/BGMACS.INC (names).

Each distinct BG2 image (chr, scr and palette resources) is converted to MD
tiles + a 64-row name table + CRAM lines 0-1 (the level palette layout:
line 0 slots 1..14, line 1 slots 1..11; line 2 = GSU palette, line 3 = HUD,
line 0 slot 15 = cockpit crosshair, line 1 slots 12..15 = OBJ colours),
reusing the helpers of tools/convert-screen-bg.py (MDECRU, SNES cells) and of
tools/extract-title-background.py (MD colour, palette optimiser, tiles).
The tiles go to VRAM $9A40 up to M4_LEVEL_MSG_TILES ($B100): 182 tiles.

Verification: every image is rendered twice at 512x512 (the SNES BG2 64x64
map from the ROM resources, and the MD plane rebuilt from the generated
tiles, name table and CRAM) and compared pixel by pixel (MD colour of the
SNES colour = component >> 2).

Usage: convert-level-backgrounds.py [--force] [--png]
Output: build/level-backgrounds.inc, build/level-backgrounds.json,
        (--png) build/agent-bg/png/bg-XX-{snes,md}.png
       convert-level-backgrounds.py --check-rom ROM.bin ROM.lst
Runs the 68000 side (src/level/level_backgrounds.asm and, when integrated,
M4ScTransSwap) of an assembled ROM in tools/m68k_sim.py and checks it against
the ROM resources and build/level-backgrounds.json (build/agent-bg/BACKGROUNDS.md).
"""
from starfox_rom import rom_hex
import collections
import hashlib
import json
import runpy
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CS = runpy.run_path(str(ROOT / 'tools/convert-screen-bg.py'))
T = CS['T']
SHA = CS['SHA']
lorom, mdecru, snes_cell = CS['lorom'], CS['mdecru'], CS['snes_cell']
md9, dist2, flip, tile_bytes = T['md9'], T['dist2'], T['flip'], T['tile_bytes']
DIS = runpy.run_path(str(ROOT / 'tools/dis65816.py'))
OPS, OPSIZE = DIS['M'], DIS['SIZE']

# Level palette layout (level_scramble.asm M4ScBgPalette copies 28 WORDs:
# line 0 slots 0..15 and line 1 slots 0..11; slot 15 of line 0 is replaced
# by M4_LVHUD_XHAIR_COLOUR).
SLOTS = {0: list(range(1, 15)), 1: list(range(1, 12))}
_G = T['optimise_palettes'].__globals__   # the real globals of the title tool functions
_G['LINES'] = (0, 1)
_G['line_capacity'] = lambda line: len(SLOTS[line])
VRAM_BASE = 0x9a40
VRAM_END = 0xc000 - 120 * 32          # M4_LEVEL_MSG_TILES (build/level-messages.inc: 120 OBJ tiles)
TILE_BUDGET = (VRAM_END - VRAM_BASE) // 32
BG2_CHR_BASE = 0x5000                 # BG12NBA high nibble 5 (mode-2 handler 02:F193)
BG2_MAP_BASE = 0x7000                 # BG2SC $73: word $7000, 64x64 (4 screens of $400 WORDs)

# Background numbers used by the stage maps (build/research/levels-inventory.json bg_ids).
NUMBERS = [0x03, 0x15, 0x1B, 0x21, 0x27, 0x2D, 0x33, 0x39, 0x3F, 0x45, 0x4B, 0x51, 0x57, 0x5D, 0x63,
           0x69, 0x6F, 0x75, 0x7B, 0x81, 0x87, 0x8D, 0x93, 0x99, 0x9F, 0xA5, 0xAB, 0xB7, 0xBD, 0xC9,
           0xD5, 0xDB, 0xE1, 0xE7, 0xED, 0x10B]
# Already handled by M4ScTransSwap (level_scramble.asm): converted and verified
# here, but left out of the runtime table.
PORT_HANDLED = {0x03: 'M4ScTransSwap (bg_1_1i: no BG load, plane B keeps Corneria)',
                0x1B: 'M4ScTransSwap + level_video.asm (extract-corneria-background.py)',
                0x21: 'M4ScTransSwap -> M4SpaceBgLoad (convert-screen-bg.py space12)'}

# Helper routines and handlers whose behaviour the parser assumes (selected ROM bytes).
HELPERS = {
    (0x03, 0xAAF9): rom_hex(0x1aaf9, 25),   # initmode1: trans_flag 36
    (0x03, 0xAB12): rom_hex(0x1ab12, 25),   # initmode2: trans_flag 38
    (0x03, 0xAB2B): rom_hex(0x1ab2b, 23),       # dec_chr_l (SFX RAM 2800)
    (0x03, 0xAB42): rom_hex(0x1ab42, 30),  # dec_bg_l (+$C0)
    (0x03, 0xAB60): rom_hex(0x1ab60, 30),  # dec_bg3_l
    (0x03, 0xAB95): rom_hex(0x1ab95, 56),            # bg2chr inline
    (0x03, 0xABCD): rom_hex(0x1abcd, 49),                          # bg2scr inline
    (0x03, 0xABFE): rom_hex(0x1abfe, 68),  # palette: E0 bytes -> 7E:178B
    (0x02, 0x8037): rom_hex(0x10037, 23),       # mode-1 handler (BG2SC/BG12NBA untouched)
    (0x02, 0xF193): rom_hex(0x17193, 31),  # mode-2 handler
    (0x02, 0xF484): rom_hex(0x17484, 43),  # setgamepal
    (0x03, 0xEFE6): rom_hex(0x1efe6, 187),                         # setbginfo 03:EFE6..F0A0
}
WAITTRANS = bytes.fromhex(rom_hex(0x19056, 8))
INLINE = {0xAB95: ('bg2chr', 7), 0xABCD: ('bg2scr', 7), 0xABFE: ('palette', 5)}
INITMODE = {0xAAF9: 1, 0xAB12: 2}
DECODERS = {0x03AB2B: 'dec_chr_l', 0x03AB60: 'dec_bg3_l'}
KNOWN_JSL = {0x06BA91: 'changeviewmode_l', 0x02F484: 'setgamepal_l'}

# newplayerstrat (bank 0B) -> port Istrat routine (only existing ones).
PSTRATS = {0x0B835B: ('playerinsidespaceflyin', 'M4SpInsideFlyinI'),
           0x0BB882: ('playerinspace', 'M4SpInSpaceI'),
           0x0B8004: ('playeropening', 'M4ScPlayerOpeningInit'),
           0x0BBB03: ('playeronplanet', 'M4ScOnPlanetNew'),
           0x0BB9B1: ('playeroncont', 'M4CtlPlayerIstrat')}
# Stage units add their ported player modes in tools/stages/<name>.py PSTRATS.
for _f in sorted((Path(__file__).resolve().parents[1] / 'tools/stages').glob('*.py')):
    PSTRATS.update(runpy.run_path(str(_f)).get('PSTRATS', {}))
# UltraStarFox names of the other bank-0B Istrats (labels only, levels-inventory.json bg_pstrat_names).
PSTRAT_NAMES = {0x0B822A: 'playerspaceflyin', 0x0B84C8: 'playerplanetflyin', 0x0B8975: 'playerwarpout',
                0x0B8D1E: 'playerdivegnd', 0x0B9AE1: 'playerclearship2', 0x0BA535: 'playerOutofLB1',
                0x0BA6CD: 'playerOutofLB2', 0x0BA907: 'playerOutofLB3', 0x0BAA30: 'playerclearcolony',
                0x0BAA79: 'playerwashent', 0x0BB566: 'playercred', 0x0BBC25: 'playerundergnd',
                0x0BBE5E: 'playeronbridge', 0x0BC03A: 'playerinstunnel', 0x0BC10C: 'playerinmtunnel',
                0x0BC1DE: 'playerinLtunnel', 0x0BC52E: 'playerinLTexit', 0x0BC699: 'playerinnucleus',
                0x0BD05E: 'playernull', 0x0B86F1: 'playercolonyflyin'}
# zdepth tables (70:0050) with an existing port copy.
DEPTHS = {0x8FAA: 'M4DepthNormal', 0x8FB6: 'M4DepthStage1', 0x8FAE: 'M4DepthTunnel'}
# Stores consumed by dedicated ops (not by the generic variable writer).
SPECIAL = {0x001787: 'levelinfo', 0x001788: 'newplayerstrat', 0x001789: 'newplayerstrat+1',
           0x00178A: 'newplayerstrat bank', 0x001899: 'gamepal', 0x700050: 'zdepthtable', 0x700051: 'zdepthtable+1',
           0x000000: 'trans_flag', 0x00120E: 'hdmaen_gc', 0x00420C: 'HDMAEN'}
NAMES = {0x0014DD: 'splayerflymode', 0x0014DE: 'splayerflymodeopt', 0x001FE4: 'hofmode (hposjmp)',
         0x001FE5: 'hposjmp+1', 0x00169E: 'bg2Yscroll', 0x00169F: 'bg2Yscroll+1', 0x00194F: 'bg2scroll',
         0x001950: 'bg2scroll+1', 0x70021C: 'm_meters', 0x70004E: 'planet depth (m_depthstab)',
         0x70004F: 'm_depthstab+1', 0x001961: 'shadowheight', 0x001962: 'shadowheight+1', 0x0016CB: 'inatunnel',
         0x0018C4: 'gamemode', 0x001951: 'lastrot', 0x001952: 'lastrot+1', 0x0016A4: 'dospacesc',
         0x001F49: 'startbgm id', 0x001F48: 'startbgm', 0x0018BA: 'bg3scrollflag', 0x00212C: 'TM',
         0x002109: 'BG3SC', 0x00210C: 'BG34NBA', 0x002112: 'BG3VOFS', 0x00178B: 'pal0palette[0]',
         0x00178C: 'pal0palette[0]+1', 0x001FC8: 'noxrot (USF bg_3_5)', 0x7001A8: 'testk2 (USF bhole hofmode)',
         0x7001A9: 'testk2+1', 0x7001AA: 'testk3 (bholelimit)', 0x7001AB: 'testk3+1', 0x7001AC: 'testk4', 0x7001AD: 'testk4+1',
         0x001F11: 'flashbg', 0x001F15: 'bgflags'}
# Original address the port's variable table (level_mapvars.asm M4LvVarTable) uses for it.
PORT_ALIAS = {0x70021C: 0x00021C}   # m_meters: the table keys it by its low address (setvar)

ROM = (ROOT / 'ref/Star Fox (USA).sfc').read_bytes()
assert len(ROM) == 1 << 20 and hashlib.sha256(ROM).hexdigest() == SHA and ROM[0x7fdb] == 0


def phys(bank, addr):
    return lorom(bank, addr)


def a24(v):
    return f'{v >> 16:02X}:{v & 0xffff:04X}'


def check_helpers():
    for (bank, addr), hexbytes in HELPERS.items():
        b = bytes.fromhex(hexbytes)
        o = phys(bank, addr)
        assert ROM[o:o + len(b)] == b, f'helper {bank:02X}:{addr:04X} differs from the selected ROM'


def bglists_entry(n):
    o = phys(0x03, 0xAC42 + n)
    bank, addr = ROM[o], ROM[o + 1] | ROM[o + 2] << 8
    assert ROM[o + 3:o + 6] == b'\0\0\0', f'bglists +{n:X}: entry not followed by 0,0'
    assert bank == 0x03 and 0x8000 <= addr < 0xAC42, f'bglists +{n:X}: {bank:02X}:{addr:04X}'
    return addr


class Routine:
    """Linear 65816 model of a bg routine (bank 03)."""

    def __init__(self, addr):
        self.events, self.ranges, self.notes = [], [], []
        self.walk(addr, m8=True, x8=False, depth=0)

    def walk(self, addr, m8, x8, depth):
        start = addr
        a = x = y = None
        cond_until, cond = None, None
        wram = {}          # WORD/byte values written so far (for the BG3 decoder arguments)
        while True:
            if cond_until is not None and addr >= cond_until:
                cond_until, cond = None, None
            o = phys(3, addr)
            if ROM[o:o + 8] == WAITTRANS:
                self.events.append(dict(op='waittrans', at=f'03:{addr:04X}'))
                addr += 8
                continue
            op = ROM[o]
            name, mode = OPS[op]
            n = OPSIZE.get(mode, 0)
            if mode == '#m': n = 1 if m8 else 2
            if mode == '#x': n = 1 if x8 else 2
            arg = int.from_bytes(ROM[o + 1:o + 1 + n], 'little') if n else None
            here = f'03:{addr:04X}'
            nxt = addr + 1 + n

            def ev(**kw):
                kw['at'] = here
                if cond: kw['cond'] = cond
                self.events.append(kw)

            def target():
                if mode == 'dp': return arg
                if mode == 'abs': return arg
                if mode == 'long': return arg
                raise AssertionError(f'{here}: {name} {mode}')
            if name == 'sep':
                m8 = m8 or bool(arg & 0x20); x8 = x8 or bool(arg & 0x10)
            elif name == 'rep':
                m8 = m8 and not arg & 0x20; x8 = x8 and not arg & 0x10
            elif name == 'lda':
                a = ('imm', arg) if mode == '#m' else ('mem', target())
            elif name == 'ldx':
                assert mode == '#x', here; x = arg
            elif name == 'ldy':
                assert mode == '#x', here; y = arg
            elif name in ('ora', 'and', 'bit', 'cmp'):
                assert mode == '#m', here
                if name == 'ora' and a and a[0] == 'mem':
                    a = ('or', a[1], arg)
                elif name == 'bit' and a and a[0] == 'mem':
                    a = ('test', a[1], arg)
                elif name != 'bit':
                    a = None
            elif name in ('sta', 'stx', 'sty', 'stz'):
                t = target()
                if mode == 'long' and t >> 16 == 0x7e:
                    t &= 0xffff
                width = 1 if (m8 if name in ('sta', 'stz') else x8) else 2
                if name == 'stz': val = ('imm', 0)
                elif name == 'stx': val = ('imm', x)
                elif name == 'sty': val = ('imm', y)
                else: val = a
                assert val is not None, f'{here}: store of an unknown value'
                ev(op='store', addr=t, width=width, value=val)
                if val[0] == 'imm':
                    for k in range(width):
                        wram[t + k] = (val[1] >> (8 * k)) & 0xff
            elif name == 'jsr':
                assert mode == 'abs', here
                if arg in INITMODE:
                    ev(op='initmode', mode=INITMODE[arg], routine=f'03:{arg:04X}')
                elif arg in INLINE:
                    kind, size = INLINE[arg]
                    p = ROM[phys(3, nxt):phys(3, nxt) + size]
                    if kind == 'palette':
                        ev(op='palette', source=p[2] << 16 | p[0] | p[1] << 8, length=p[3] | p[4] << 8,
                           inline=p.hex())
                    else:
                        ev(op=kind, bank=p[2], end=p[0] | p[1] << 8, vram_word=p[3] | p[4] << 8,
                           dma_bytes=p[5] | p[6] << 8, inline=p.hex())
                    nxt += size
                else:
                    raise AssertionError(f'{here}: jsr {arg:04X} not modelled')
            elif name == 'jsl':
                if arg in DECODERS:
                    get = lambda ad, w=2: sum(wram[ad + k] << (8 * k) for k in range(w))
                    vr = (0x188C, 0x188E) if arg == 0x03AB2B else (0x1890, 0x1892)
                    ev(op=DECODERS[arg], end=get(0x700062), bank=get(0x700064, 1), vram_word=get(vr[0]),
                       dma_bytes=get(vr[1]), decoffset=get(0x700090))
                elif arg >> 16 == 0x03 and (arg & 0xffff) < 0xAB00:
                    ev(op='call', target=a24(arg))
                    self.walk(arg & 0xffff, m8, x8, depth + 1)   # shared part (bg16b26c): ends with rtl
                else:
                    ev(op='jsl', target=a24(arg), name=KNOWN_JSL.get(arg, 'music (setbgm)' if arg >> 8 in (0x03AD, 0x03AE) else '?'))
            elif name in ('beq', 'bne', 'bpl', 'bmi', 'bcc', 'bcs'):
                d = arg - 256 if arg >= 128 else arg
                assert d > 0, f'{here}: backward branch'
                cond_until = nxt + d
                cond = f'{name} at {here} skips to 03:{cond_until:04X} (A={a})'
            elif name == 'inc' and mode == 'abs':
                ev(op='inc', addr=arg, width=1 if m8 else 2)
            elif name in ('rtl', 'rts'):
                self.ranges.append((start, nxt))
                return m8, x8
            else:
                raise AssertionError(f'{here}: {name} {mode} not modelled')
            addr = nxt


def parse(n):
    addr = bglists_entry(n)
    r = Routine(addr)
    ev = r.events
    info = dict(number=n, routine=f'03:{addr:04X}',
                ranges=[f'03:{a:04X}..03:{b - 1:04X}' for a, b in r.ranges],
                bytes_sha256=hashlib.sha256(b''.join(ROM[phys(3, a):phys(3, b)] for a, b in r.ranges)).hexdigest())
    return info, ev


# ---------------------------------------------------------------- parameters
OWN = {0x1787, 0x1788, 0x1789, 0x178A, 0x1899, 0x700050, 0x700051, 0x0000, 0x120E, 0x420C}
# Inputs of the BG3 decrunch calls (recorded with the dec_chr_l/dec_bg3_l events)
# and PPU registers written directly (BG3 set-up): JSON only, no program op.
DECODER_ARGS = {0x700062, 0x700063, 0x700064, 0x700065, 0x700090, 0x700091} | set(range(0x188C, 0x1894))


def is_register(a):
    return 0x2100 <= a <= 0x21FF or 0x4200 <= a <= 0x43FF


def derive(n, events):
    """Summary of the effects of one routine."""
    res = {k: [e for e in events if e['op'] == k] for k in ('bg2chr', 'bg2scr', 'palette', 'initmode',
                                                            'dec_chr_l', 'dec_bg3_l')}
    for k in ('bg2chr', 'bg2scr', 'palette', 'initmode'):
        assert len(res[k]) == 1, f'{n:X}: {len(res[k])} {k}'
    stores = collections.OrderedDict()   # byte address -> value (unconditional immediate stores)
    for e in events:
        if e['op'] == 'store' and e['value'][0] == 'imm' and not e.get('cond'):
            for k in range(e['width']):
                stores[e['addr'] + k] = (e['value'][1] >> (8 * k)) & 0xff

    def word(addr):
        lo, hi = stores.get(addr), stores.get(addr + 1)
        return None if lo is None or hi is None else lo | hi << 8
    gamepal = 1 if res['initmode'] else None
    for e in events:
        if e['op'] == 'jsl' and e['target'] == '02:F484':
            gamepal = stores.get(0x1899)
            assert gamepal is not None and not e.get('cond')
    pstrat = word(0x1788) | stores[0x178A] << 16 if 0x1788 in stores else None
    p = dict(
        initmode=res['initmode'][0]['mode'],
        trans_flag_00=stores.get(0x0000),
        levelinfo_1787=stores.get(0x1787),
        pstrat_1788=a24(pstrat) if pstrat is not None else None,
        splayerflymode_14DD=stores.get(0x14DD), splayerflymodeopt_14DE=stores.get(0x14DE),
        changeviewmode_06BA91=any(e['op'] == 'jsl' and e['target'] == '06:BA91' for e in events),
        gamepal_1899=gamepal,
        zdepthtable_700050=f'03:{word(0x700050):04X}' if word(0x700050) is not None else ('03:8FAA' if res['initmode'] else None),
        hofmode_1FE4=stores.get(0x1FE4),
        bg2Yscroll_169E=word(0x169E), bg2scroll_194F=word(0x194F),
        m_meters_70021C=stores.get(0x70021C),
        planet_70004E_4F=[stores.get(0x70004E), stores.get(0x70004F)],
        shadowheight_1961=word(0x1961), inatunnel_16CB=stores.get(0x16CB), gamemode_18C4=stores.get(0x18C4),
        dospacesc_16A4=stores.get(0x16A4),
        hdmaen_gc_120E_or=[e['value'][2] for e in events if e['op'] == 'store' and e['addr'] == 0x120E
                           and e['value'][0] == 'or'],
        hdmaen_420C_from_120E=any(e['op'] == 'store' and e['addr'] == 0x420C for e in events),
        flashbg_inc_1F0D=any(e['op'] == 'inc' and e['addr'] == 0x1F0D for e in events),
        music=[dict(target=e['target'], cond=e.get('cond')) for e in events
               if e['op'] == 'jsl' and e['name'].startswith('music')],
        bg3=[dict({k: v for k, v in e.items() if k != 'op'}, decoder=e['op']) for e in events
             if e['op'] in ('dec_chr_l', 'dec_bg3_l')],
        conditional=[dict(at=e['at'], op=e['op'], cond=e['cond']) for e in events if e.get('cond')],
    )
    p['other_stores'] = {a24(a) + (f' {NAMES[a]}' if a in NAMES else ''): f'${v:02X}' for a, v in stores.items()
                         if a not in OWN and a not in (0x14DD, 0x14DE, 0x1FE4, 0x169E, 0x169F, 0x194F, 0x1950,
                                                       0x70021C, 0x70004E, 0x70004F, 0x1961, 0x1962, 0x16CB,
                                                       0x18C4, 0x16A4)}
    li = p['levelinfo_1787']
    p['setbginfo'] = None
    if li is not None:   # setbginfo 03:EFE6..F0A0
        dots = 1 if li & 8 else (0xff if li & 0x10 else 0)
        star = 1 if li & 0x20 else (2 if li & 0x40 else 0)
        if star:
            dots = 0xff
        p['setbginfo'] = dict(dotsflag_16FB=dots, starmode_701A26=star, dozrot_16F3=1 if li & 4 else 0,
                              hofs_per_line_1955=1 if li & 2 else 0, offset_per_tile_1956_bgmode2=1 if li & 1 else 0)
    return res, p, stores


# ---------------------------------------------------------------- SNES BG2 model
_DECODE = runpy.run_path(str(ROOT / 'tools/extract-intro-background.py'))['decode']
_COLL = []


def collection():
    if not _COLL:
        _COLL.append(mdecru(ROM, _DECODE, 0x17, 0xF21C))
        assert len(_COLL[0][0]) == 5120
    return _COLL[0]


def snes_bg2(res):
    """VRAM model of BG2 after the routine: chr tiles (BG2 base $5000), the
    64x64 map ($7000, 4 screens) and CGRAM rows 0..6. None = stale VRAM."""
    c, s, p = res['bg2chr'][0], res['bg2scr'][0], res['palette'][0]
    chars, chr_info = mdecru(ROM, _DECODE, c['bank'], c['end'])
    scr, scr_info = mdecru(ROM, _DECODE, s['bank'], s['end'])
    assert (c['vram_word'] - BG2_CHR_BASE) % 16 == 0 and c['vram_word'] >= BG2_CHR_BASE
    first_tile = (c['vram_word'] - BG2_CHR_BASE) // 16
    known_tiles = min(len(chars), c['dma_bytes']) // 32
    vram_map = [None] * 4096
    w0 = s['vram_word'] - BG2_MAP_BASE
    assert 0 <= w0 and w0 + s['dma_bytes'] // 2 <= 4096
    addend = 0xC0   # dec_bg_l 03:AB42: m_decoffset $00C0 added to every decoded map word
    for i in range(s['dma_bytes'] // 2):
        if 2 * i + 1 < len(scr):
            vram_map[w0 + i] = ((scr[2 * i] | scr[2 * i + 1] << 8) + addend) & 0xffff
    if p['source'] >> 16 == 0x7F:
        col, col_info = collection()
        off = p['source'] & 0xffff
        raw = col[off:off + 0xE0]
        pal_info = dict(source=a24(p['source']), collection='7F:0000 <- MDECRU 17:F21C', collection_rom=col_info['rom'])
    else:
        o = lorom(p['source'] >> 16, p['source'] & 0xffff)
        raw = ROM[o:o + 0xE0]
        pal_info = dict(source=a24(p['source']), rom=f'0x{o:05X}')
    assert len(raw) == 0xE0   # dopalette 03:ABFE always copies 7*32 bytes
    cgram = [raw[2 * i] | raw[2 * i + 1] << 8 for i in range(112)]
    pal_info['sha256'] = hashlib.sha256(raw).hexdigest()
    return dict(chars=chars, first_tile=first_tile, known_tiles=known_tiles, map=vram_map, cgram=cgram,
                chr=dict(chr_info, end=f"{c['bank']:02X}:{c['end']:04X}", vram_word=f"{c['vram_word']:04X}",
                         dma_bytes=c['dma_bytes'], decoded_bytes=len(chars)),
                scr=dict(scr_info, end=f"{s['bank']:02X}:{s['end']:04X}", vram_word=f"{s['vram_word']:04X}",
                         dma_bytes=s['dma_bytes'], decoded_bytes=len(scr), map_word_addend=addend),
                palette=dict(pal_info, length_inline=p['length']))


def map_word(bg, x, y):
    sc = (x >> 5) + 2 * (y >> 5)
    return bg['map'][sc * 1024 + (y & 31) * 32 + (x & 31)]


def cell(bg, x, y):
    """-> (64 SNES colour indices, palette row, priority, kind) of map cell (x, y);
    kind: ok, stale_map (map word not written by this routine), stale_chr
    (tile outside the chr this routine loaded)."""
    w = map_word(bg, x, y)
    if w is None:
        return [0] * 64, 0, 0, 'stale_map'
    t = (w & 1023) - bg['first_tile']
    if not 0 <= t < bg['known_tiles']:
        return [0] * 64, (w >> 10) & 7, (w >> 13) & 1, 'stale_chr'
    idx, pal, pri = snes_cell(bg['chars'], (w & ~1023) | t)
    return idx, pal, pri, 'ok'


def snes_image(bg):
    """512x512 SNES BG2: md9 colour, None (colour 0: transparent) or 'S' (stale)."""
    img = [[None] * 512 for _ in range(512)]
    for cy in range(64):
        for cx in range(64):
            idx, pal, pri, kind = cell(bg, cx, cy)
            for k, c in enumerate(idx):
                if kind != 'ok':
                    img[cy * 8 + k // 8][cx * 8 + k % 8] = 'S'
                elif c:
                    img[cy * 8 + k // 8][cx * 8 + k % 8] = md9(bg['cgram'][pal * 16 + c])
    return img


# ---------------------------------------------------------------- MD conversion
def convert_image(bg):
    width = 64
    if all(map_word(bg, x, y) == map_word(bg, x + 32, y) for y in range(64) for x in range(32)):
        width = 32   # both screen columns equal: horizontal period 256 px = the MD plane width
    cells, groups = {}, collections.OrderedDict()
    stats = collections.Counter()
    for cy in range(64):
        for cx in range(width):
            idx, pal, pri, kind = cell(bg, cx, cy)
            stats[kind] += 1
            stats['priority1'] += pri
            w = map_word(bg, cx, cy) or 0
            if kind == 'ok':
                stats[f'row{pal}'] += 1
                key = (w & 0x1c00) | (w & 1023)
            else:
                key = 'blank'
            cells[(cx, cy)] = (idx, pal, key)
            if key not in groups:
                groups[key] = dict(hist=collections.Counter(md9(bg['cgram'][pal * 16 + c]) for c in idx if c),
                                   group=f'p{pal}', n=0)
            groups[key]['n'] += 1
    items = [dict(hist=collections.Counter({c: k * g['n'] for c, k in g['hist'].items()}), group=g['group'], key=key)
             for key, g in groups.items()]
    cost, owner, palettes = T['optimise_palettes'](items)
    line_of = {it['key']: o for it, o in zip(items, owner)}
    slot_of = {}
    for line, colours in palettes.items():
        assert len(colours) <= len(SLOTS[line])
        slot_of[line] = {c: s for c, s in zip(colours, SLOTS[line])}
    tiles, tile_ids, words = [], {}, []
    for cy in range(64):
        for cx in range(width):
            idx, pal, key = cells[(cx, cy)]
            line = line_of[key]
            slot = slot_of[line]
            md = []
            for c in idx:
                if not c:
                    md.append(0)
                    continue
                m = md9(bg['cgram'][pal * 16 + c])
                md.append(slot[m] if m in slot else slot[min(slot, key=lambda k: (dist2(m, k), k))])
            md = tuple(md)
            found = None
            for h in (0, 1):
                for v in (0, 1):
                    f = flip(md, h, v)
                    if f in tile_ids:
                        found = (tile_ids[f], h, v)
                        break
                if found:
                    break
            if not found:
                tile_ids[md] = len(tiles)
                tiles.append(md)
                found = (tile_ids[md], 0, 0)
            t, h, v = found
            words.append([line, v, h, t])
    return dict(width=width, tiles=tiles, words=words, slot_of=slot_of, stats=dict(stats),
                lines={str(k): [f'{c:03x}' for c in v] for k, v in palettes.items()})


def reduce_tiles(conv, budget):
    """Fewer tiles than the VRAM budget: repeatedly fold the tile whose loss
    (uses x squared colour distance to its nearest other tile, any flip) is
    smallest into that tile. Deliberate, measured difference."""
    tiles, words = conv['tiles'], conv['words']
    if len(tiles) <= budget:
        return 0
    rgb = {line: [None] * 16 for line in (0, 1)}
    for line, slots in conv['slot_of'].items():
        for c, k in slots.items():
            rgb[line][k] = T['md_rgb'](c)
    lines = collections.defaultdict(collections.Counter)
    for line, v, h, t in words:
        lines[t][line] += 1
    far = 3 * 8 * 8  # transparent against opaque: worse than any colour pair (components 0..7)

    def dist(a, b, line):
        d, tab = 0, rgb[line]
        for p, q in zip(a, b):
            if p != q:
                if not p or not q or tab[p] is None or tab[q] is None:
                    d += far
                else:
                    x, y = tab[p], tab[q]
                    d += (x[0] - y[0]) ** 2 + (x[1] - y[1]) ** 2 + (x[2] - y[2]) ** 2
        return d
    alive = set(range(len(tiles)))
    remap = {t: (t, 0, 0) for t in alive}
    best = {}

    def nearest(t):
        """(weighted loss, target, h, v): loss = sum over the lines t is shown
        with of uses x squared distance."""
        b = None
        for u in sorted(alive):
            if u != t:
                for h in (0, 1):
                    for v in (0, 1):
                        f = flip(tiles[u], h, v)
                        d = sum(n * dist(tiles[t], f, line) for line, n in lines[t].items())
                        if b is None or d < b[0]:
                            b = (d, u, h, v)
        return b
    folded = 0
    while len(alive) > budget:
        for t in alive:
            if t not in best:
                best[t] = nearest(t)
        t = min(alive, key=lambda k: (best[k][0], k))
        d, u, h, v = best[t]
        alive.discard(t)
        for k, (r, rh, rv) in remap.items():
            if r == t:
                remap[k] = (u, rh ^ h, rv ^ v)
        lines[u].update(lines[t])
        folded += 1
        for k in list(best):
            if k == t or best[k][1] == t or k == u:
                best.pop(k)
    order = sorted(alive)
    new_id = {t: i for i, t in enumerate(order)}
    for w in words:
        r, rh, rv = remap[w[3]]
        w[3], w[2], w[1] = new_id[r], w[2] ^ rh, w[1] ^ rv
    conv['tiles'] = [tiles[t] for t in order]
    return folded


def finish(conv):
    """Name table words and the 28 CRAM WORDs (M4_SPB_CRAM layout)."""
    conv['name_table'] = [(line << 13) | (v << 12) | (h << 11) | (VRAM_BASE // 32 + t) for line, v, h, t in conv['words']]
    cram = [0] * 28
    for line, slots in conv['slot_of'].items():
        for c, s in slots.items():
            cram[16 * line + s] = c
    conv['cram'] = cram


def md_image(conv):
    """512x512 rebuilt from the generated MD data only (4bpp tile bytes, name
    table words, CRAM WORDs): md9 colour or None (index 0)."""
    data = [tile_bytes(t) for t in conv['tiles']]
    width = conv['width']
    img = [[None] * 512 for _ in range(512)]
    for y in range(512):
        cy, py = y >> 3, y & 7
        row = conv['name_table'][cy * width:(cy + 1) * width]
        for x in range(512):
            word = row[(x >> 3) % width]
            t = (word & 0x7ff) - VRAM_BASE // 32
            line, v, h = (word >> 13) & 3, (word >> 12) & 1, (word >> 11) & 1
            sx, sy = (7 - (x & 7) if h else x & 7), (7 - py if v else py)
            b = data[t][sy * 4 + sx // 2]
            i = (b >> 4) if sx % 2 == 0 else (b & 15)
            img[y][x] = conv['cram'][16 * line + i] if i else None
    return img


def compare(snes, md):
    r = collections.Counter()
    err = 0
    for y in range(512):
        for x in range(512):
            s, m = snes[y][x], md[y][x]
            if s == 'S':
                r['stale'] += 1
            elif s is None:
                r['transparent'] += 1
                r['transparent_kept' if m is None else 'transparent_filled'] += 1
            else:
                r['opaque'] += 1
                if m == s:
                    r['exact'] += 1
                elif m is not None:
                    err += dist2(s, m)
    r['squared_error'] = err
    return dict(r)


# ---------------------------------------------------------------- outputs
CONVERTER_VERSION = 'v3 initmode state and gamepal, depth palette consumers'
OP = dict(END=0, LOAD=1, VAR=2, VIEW=3, GAMEPAL=4, DEPTH=5, PSTRAT=6)


def stages_of():
    """Stage names and the byte-pattern scan of tools/inventory-levels.py
    (build/research/levels-inventory.json), used as an independent cross-check
    when present."""
    f = ROOT / 'build/research/levels-inventory.json'
    if not f.exists():
        print('note: build/research/levels-inventory.json absent (tools/inventory-levels.py): no cross-check')
        return collections.defaultdict(list), {}
    inv = json.loads(f.read_text(encoding='utf-8'))
    out = collections.defaultdict(list)
    for lv in inv['levels']:
        for b in lv['bg_ids']:
            if lv['name'] not in out[int(b, 16)]:
                out[int(b, 16)].append(lv['name'])
    return out, inv['bglists']


def port_var_table():
    """Original addresses of level_mapvars.asm M4LvVarTable (consumers known to the port)."""
    import re
    txt = (ROOT / 'src/level/level_mapvars.asm').read_text(encoding='latin-1')
    tab = txt[txt.index('M4LvVarTable:'):]
    tab = tab[:tab.index('dc.l 0')]
    return {int(a, 16): v for a, v in re.findall(r'dc\.l \$([0-9a-fA-F]+),([\w+]+)', tab)}


def _last(events, addr, width):
    v = None
    for e in events:
        if e['op'] == 'store' and e['addr'] == addr and e['width'] == width and e['value'][0] == 'imm':
            v = e['value'][1]
    return v


def program(n, events, image_label, depth_labels):
    """68000 op list in ROM order (see level_backgrounds.asm)."""
    ops, notes = [], []
    loaded = False
    for e in events:
        k = e['op']
        if k == 'initmode':
            ops.extend([('GAMEPAL', 1, f"{e['at']} irqsetmode{e['mode']} 02:8062/80E4"),
                        ('DEPTH', 'M4DepthNormal', 'initmode normal zdepth'),
                        ('VAR', (0x16A4, 0), 'initmode dospacesc=0'),
                        ('VAR', (0x1EF3, 0), 'initmode fadepal=0')])
        elif k in ('bg2chr', 'bg2scr', 'palette'):
            if not loaded:
                ops.append(('LOAD', image_label, f"{e['at']} bg2chr/bg2scr/palette"))
                loaded = True
        elif k == 'store':
            a = e['addr']
            if e.get('cond') or e['value'][0] != 'imm':
                continue
            if a == 0x178A:
                ps = (e['value'][1] << 16) | _last(events, 0x1788, 2)
                port = PSTRATS.get(ps)
                ops.append(('PSTRAT', port[1] if port else '0', f"{e['at']} newplayerstrat {a24(ps)} "
                            + (port[0] if port else PSTRAT_NAMES.get(ps, '?') + ' (PEND: player keeps its strategy)')))
                if not port:
                    notes.append(f'pstrat {a24(ps)} {PSTRAT_NAMES.get(ps, "?")} PEND')
            elif a == 0x700050:
                v = e['value'][1]
                ops.append(('DEPTH', depth_labels[v], f"{e['at']} zdepthtable 70:0050 = 03:{v:04X}"))
            elif a in OWN or a in DECODER_ARGS or is_register(a):
                continue
            else:
                for b in range(e['width']):
                    orig = a + b
                    ops.append(('VAR', (PORT_ALIAS.get(orig, orig), (e['value'][1] >> (8 * b)) & 0xff),
                                f"{e['at']} {a24(orig)} {NAMES.get(orig, '')}".rstrip()))
        elif k == 'jsl' and e['target'] == '06:BA91':
            ops.append(('VIEW', None, f"{e['at']} changeviewmode_l 06:BA91"))
        elif k == 'jsl' and e['target'] == '02:F484':
            ops.append(('GAMEPAL', _last(events, 0x1899, 1), f"{e['at']} setgamepal_l 02:F484"))
    return ops, notes


def save_png(img, path):
    from PIL import Image
    im = Image.new('RGB', (512, 512))
    px = im.load()
    for y in range(512):
        for x in range(512):
            c = img[y][x]
            if c == 'S':
                px[x, y] = (255, 0, 255)
            elif c is None:
                px[x, y] = (0, 0, 0)
            else:
                px[x, y] = T['to_png_md'](c)
    im.save(path)


def main(force=False, png=False):
    out_inc, out_json = ROOT / 'build/level-backgrounds.inc', ROOT / 'build/level-backgrounds.json'
    key = hashlib.sha256((CONVERTER_VERSION + SHA + repr(NUMBERS) + repr(sorted(PSTRATS.items()))
                          + repr(sorted(PORT_HANDLED))).encode()).hexdigest()
    if not force and not png and out_inc.exists() and out_json.exists():
        if json.loads(out_json.read_text(encoding='utf-8')).get('tool_key') == key:
            print('level backgrounds: cached build/level-backgrounds.inc')
            return
    check_helpers()
    stages, inv_bg = stages_of()
    vartab = port_var_table()
    images, report_bgs, programs = collections.OrderedDict(), [], []
    depth_used = {}
    for n in NUMBERS:
        info, ev = parse(n)
        res, prm, stores = derive(n, ev)
        # independent cross-check: byte-pattern scan of tools/inventory-levels.py
        iv = inv_bg.get('%02X' % n, dict(addr=info['routine'], inatunnel_16CB=prm['inatunnel_16CB'],
                                         gamemode_18C4=prm['gamemode_18C4']))
        assert iv['addr'] == info['routine'], (n, iv['addr'])
        if 'levelinfo_1787' in iv:
            assert int(iv['levelinfo_1787'], 16) == prm['levelinfo_1787'], n
        if 'pstrat' in iv:
            assert iv['pstrat'] == prm['pstrat_1788'].replace(':', ''), n
        if 'bg2Yscroll' in iv:
            assert (iv['bg2Yscroll'] & 0xffff) == prm['bg2Yscroll_169E'], n
        assert iv['inatunnel_16CB'] == prm['inatunnel_16CB'] and iv['gamemode_18C4'] == prm['gamemode_18C4'], n
        rkey = (res['bg2chr'][0]['inline'], res['bg2scr'][0]['inline'], res['palette'][0]['inline'])
        if rkey not in images:
            images[rkey] = dict(first=n, numbers=[], res=res)
        images[rkey]['numbers'].append(n)
        if prm['zdepthtable_700050']:
            v = int(prm['zdepthtable_700050'][3:], 16)
            assert 0x8F9A <= v <= 0x8FB6 and (v - 0x8F9A) % 4 == 0, v
            depth_used[v] = DEPTHS.get(v, f'M4LbgDepth{v:04X}')
        report_bgs.append(dict(info, stages=stages.get(n, []), names_usf=iv.get('names'), params=prm, events=ev,
                               image=f"M4LbgImg{images[rkey]['first']:02X}", runtime=n not in PORT_HANDLED,
                               port_handled=PORT_HANDLED.get(n)))
    # ---- convert, reduce, verify
    img_report = {}
    for rkey, im in images.items():
        label = f"M4LbgImg{im['first']:02X}"
        bg = snes_bg2(im['res'])
        conv = convert_image(bg)
        before = len(conv['tiles'])
        folded = reduce_tiles(conv, TILE_BUDGET)
        finish(conv)
        snes, md = snes_image(bg), md_image(conv)
        cmp_ = compare(snes, md)
        assert len(conv['tiles']) <= TILE_BUDGET
        assert cmp_.get('transparent_filled', 0) == 0
        colours = {c for row in snes for c in row if c not in (None, 'S')}
        if not folded and len(colours) <= sum(len(v) for v in SLOTS.values()):
            # enough slots and tiles: the conversion must be exact unless the
            # cells force a split no 2-line assignment satisfies (reported)
            if cmp_.get('exact', 0) != cmp_.get('opaque', 0):
                print(f'  note {label}: {len(colours)} colours fit 25 slots but not per 8x8 cell', flush=True)
        im.update(label=label, conv=conv)
        if png:
            d = ROOT / 'build/agent-bg/png'
            d.mkdir(parents=True, exist_ok=True)
            save_png(snes, d / f"bg-{im['first']:02X}-snes.png")
            save_png(md, d / f"bg-{im['first']:02X}-md.png")
        opaque = cmp_.get('opaque', 0)
        backdrop = md9(bg['cgram'][0])
        img_report[label] = dict(
            numbers=[f'{n:02X}' for n in im['numbers']], chr=bg['chr'], scr=bg['scr'], palette=bg['palette'],
            snes_backdrop_cgram0=f"{bg['cgram'][0]:04X} (md {backdrop:03x})",
            width_cells=conv['width'], horizontal_period_px=8 * conv['width'],
            plane='static 32x64' if conv['width'] == 32 else 'streamed 64 source columns',
            tiles=len(conv['tiles']), tiles_before_reduction=before, tiles_folded=folded,
            vram=f'{VRAM_BASE:04X}..{VRAM_BASE + 32 * len(conv["tiles"]):04X}',
            cells=conv['stats'], md_lines=conv['lines'], md_colours_in_image=len(colours),
            pixels=dict(cmp_, exact_ratio=round(cmp_.get('exact', 0) / opaque, 6) if opaque else None),
            cram_words=[f'{c:03x}' for c in conv['cram']])
        print(f"{label} {','.join(img_report[label]['numbers'])}: w{conv['width']} tiles {len(conv['tiles'])}"
              f" (folded {folded}) exact {cmp_.get('exact', 0)}/{opaque} stale {cmp_.get('stale', 0)}"
              f" transparent {cmp_.get('transparent', 0)}", flush=True)
    # ---- programs
    label_of = {n: im['label'] for im in images.values() for n in im['numbers']}
    pend = {}
    for b in report_bgs:
        n = b['number']
        ops, notes = program(n, b['events'], label_of[n], depth_used)
        b['program'] = [dict(op=o, arg=(f'${a[0]:06X}=${a[1]:02X}' if o == 'VAR' else a), src=src,
                             port_consumer=(vartab.get(a[0]) if o == 'VAR' else None)) for o, a, src in ops]
        b['pend'] = notes
        pend[n] = notes
        programs.append((n, b, ops))
    # ---- .inc
    L = [f'; Generated by tools/convert-level-backgrounds.py ({CONVERTER_VERSION}).',
         f'; ROM {SHA[:16]}..., bglists 03:AC42. Provenance: build/level-backgrounds.json.',
         f'; LBG_* opcodes and M4_LBG_VRAM (${VRAM_BASE:04x}) are defined in src/level/level_backgrounds.asm;',
         '; include this file in a data area after it (main.asm, next to level_video.asm).']
    L.append('; number.w, (dotsflag << 8 | 70:1A26 star mode).w, program.l (setbginfo 03:EFE6 from levelinfo $1787)')
    L.append('M4LbgTable:')
    for n, b, ops in programs:
        if not b['runtime']:
            continue
        si = b['params']['setbginfo'] or dict(dotsflag_16FB=0, starmode_701A26=0)
        L.append(f"        dc.w ${n:x},${si['dotsflag_16FB'] << 8 | si['starmode_701A26']:04x} ;{b['routine']} "
                 f"{'/'.join(b['names_usf'] or [])} levelinfo ${(b['params']['levelinfo_1787'] or 0):02X}")
        L.append(f'        dc.l M4LbgProg{n:02X}')
    L.append('        dc.w -1')
    used_images = set()
    for n, b, ops in programs:
        if not b['runtime']:
            continue
        L.append(f"M4LbgProg{n:02X}: ;{b['routine']} ({', '.join(b['stages'])})")
        for o, a, src in ops:
            if o == 'LOAD':
                L.append(f'        dc.w LBG_LOAD ;{src}')
                L.append(f'        dc.l {a}')
                used_images.add(a)
            elif o == 'VAR':
                L.append(f'        dc.w LBG_VAR ;{src}')
                L.append(f'        dc.l ${a[0]:06x}')
                L.append(f'        dc.w ${a[1]:02x}')
            elif o == 'VIEW':
                L.append(f'        dc.w LBG_VIEW ;{src}')
            elif o == 'GAMEPAL':
                L.append(f'        dc.w LBG_GAMEPAL,{a} ;{src}')
            elif o in ('DEPTH', 'PSTRAT'):
                L.append(f'        dc.w LBG_{o} ;{src}')
                L.append(f'        dc.l {a}')
        L.append('        dc.w LBG_END')
    for v, lab in sorted(depth_used.items()):
        if v not in DEPTHS:
            o = lorom(3, v)
            L.append(f'{lab}: dc.b ' + ','.join(f'${x:02x}' for x in ROM[o:o + 4]) + f' ;03:{v:04X} zdepth table')
    L.append('        even')
    for im in images.values():
        if im['label'] not in used_images:
            continue
        c, lab = im['conv'], im['label']
        L.append(f"{lab}: ;numbers {','.join('$%X' % n for n in im['numbers'])}: tiles, width, tiles.l, map.l, CRAM.l")
        L.append(f"        dc.w {len(c['tiles'])},{c['width']}")
        L.append(f'        dc.l {lab}Tiles,{lab}Map,{lab}Cram')
        L.append(f'{lab}Cram: ;28 WORDs: line 0 slots 0..15, line 1 slots 0..11 (M4_SPB_CRAM)')
        for r in range(0, 28, 14):
            L.append('        dc.w ' + ','.join(f'${x:03x}' for x in c['cram'][r:r + 14]))
        L.append(f'{lab}Tiles:')
        for t in c['tiles']:
            bb = tile_bytes(t)
            L.append('        dc.l ' + ','.join(f'${int.from_bytes(bb[i:i + 4], "big"):08x}' for i in range(0, 32, 4)))
        w = c['width']
        L.append(f"{lab}Map: ;64 rows x {w} cells")
        for r in range(64):
            L.append('        dc.w ' + ','.join(f'${x:04x}' for x in c['name_table'][r * w:(r + 1) * w]))
    out_inc.write_text('\n'.join(L) + '\n', encoding='ascii')
    for b in report_bgs:
        b.pop('events')
    report = dict(rom='ref/Star Fox (USA).sfc', rom_sha256=SHA, generator='tools/convert-level-backgrounds.py',
                  converter_version=CONVERTER_VERSION, tool_key=key, bglists='03:AC42 (+n, entries bank,addr)',
                  helpers={f'{b:02X}:{a:04X}': h for (b, a), h in HELPERS.items()},
                  target=dict(vram=f'{VRAM_BASE:04X}..{VRAM_END:04X}', tile_budget=TILE_BUDGET, plane_b='E000 32x64',
                              cram='lines 0 (slots 1..14) and 1 (slots 1..11); 2 GSU, 3 HUD',
                              priority='plane B words priority 0'),
                  backgrounds=report_bgs, images=img_report,
                  pstrat_port={a24(k): v for k, v in PSTRATS.items()},
                  pend={f'{n:02X}': v for n, v in pend.items() if v})
    out_json.write_text(json.dumps(report, indent=1) + '\n', encoding='utf-8')
    print(f'build/level-backgrounds.inc: {sum(1 for _, b, _ in programs if b["runtime"])} runtime backgrounds, '
          f'{len(used_images)} images')


# ---------------------------------------------------------------- 68000 check
def check_rom(rom_path, lst_path):
    """Runs M4LevelBgSwap / M4LevelBgStream / M4LevelBgInfo / M4ScBgPalette of
    an assembled port ROM in tools/m68k_sim.py (VDP data/control ports
    modelled for VRAM writes) and checks, for every runtime number: the VRAM
    tiles and plane B rebuilt into a 512x512 image against the SNES BG2 of
    the ROM resources (same counts as the converter's report), the column
    streaming over a full horizontal sweep, the CRAM lines, and the RAM
    effects of the program against the routine's parameters."""
    sys.path.insert(0, str(ROOT / 'tools'))
    import m68k_sim
    sym = m68k_sim.load_listing(lst_path)
    rom = Path(rom_path).read_bytes()
    rep = json.loads((ROOT / 'build/level-backgrounds.json').read_text(encoding='utf-8'))

    class Sim(m68k_sim.M68K):
        def __init__(self, rom):
            super().__init__(rom)
            self.vram = bytearray(0x10000)
            self.vdp_addr, self.vdp_inc, self.vdp_code, self.vdp_first = 0, 2, 0, None
            self.vram_writes = 0

        def ww(self, addr, v):
            a = addr & 0xFFFFFF
            if a in (0xC00004, 0xC00006):
                v &= 0xffff
                if self.vdp_first is None and (v & 0xC000) == 0x8000:
                    if (v >> 8) & 0x1f == 0x0f:
                        self.vdp_inc = v & 0xff
                    return
                if self.vdp_first is None:
                    self.vdp_first = v
                    return
                w1, self.vdp_first = self.vdp_first, None
                self.vdp_addr = (w1 & 0x3fff) | ((v & 3) << 14)
                self.vdp_code = ((w1 >> 14) & 3) | ((v >> 2) & 0x3c)
                return
            if a in (0xC00000, 0xC00002):
                assert self.vdp_code == 1 and not self.vdp_addr & 1, (hex(self.vdp_code), hex(self.vdp_addr))
                self.vram[self.vdp_addr] = (v >> 8) & 0xff
                self.vram[self.vdp_addr + 1] = v & 0xff
                self.vdp_addr = (self.vdp_addr + self.vdp_inc) & 0xffff
                self.vram_writes += 1
                return
            super().ww(addr, v)

        def wl(self, addr, v):
            if 0xC00000 <= (addr & 0xFFFFFF) < 0xC00008:
                self.ww(addr, (v >> 16) & 0xffff)
                self.ww(addr + 2, v & 0xffff)
                return
            super().wl(addr, v)

    def rd(cpu, name, size):
        return cpu.read(sym[name], size)

    def vram_pixel(cpu, cram, word, px, py):
        t = word & 0x7ff
        line, v, h = (word >> 13) & 3, (word >> 12) & 1, (word >> 11) & 1
        sx, sy = (7 - px if h else px), (7 - py if v else py)
        b = cpu.vram[t * 32 + sy * 4 + sx // 2]
        i = (b >> 4) if sx % 2 == 0 else (b & 15)
        return cram[16 * line + i] if i else None

    def plane_word(cpu, c, r):
        o = 0xE000 + r * 64 + c * 2
        return cpu.vram[o] << 8 | cpu.vram[o + 1]

    snes_cache, failures, checked = {}, [], 0
    gamepals = sym['M4LevelGamepals']
    for b in rep['backgrounds']:
        n = b['number']
        if not b['runtime']:
            continue
        p = b['params']
        img = rep['images'][b['image']]
        if b['image'] not in snes_cache:
            info, ev = parse(n)
            res, _, _ = derive(n, ev)
            snes_cache[b['image']] = snes_image(snes_bg2(res))
        snes = snes_cache[b['image']]
        cpu = Sim(rom)
        cpu.a[7] = 0xFFFF00
        cpu.write(sym['M4_SC_BGBLACK'], 0xff, 1)      # makeBG2black in effect: the load must undo it
        cpu.write(sym['M4_SC_BGSHOWN'], 0xff, 1)
        cpu.write(sym['M4_SC_NEWPSTRAT'], 0x12345678, 4)
        cpu.write(sym['M4_SC_DEPTH'], 0x0BADBAD0, 4)
        cpu.write(sym['M4_BG_HSCROLL'], 0, 2)
        cpu.call(sym['M4LevelBgSwap'], d0=n)
        errs = []
        if cpu.z:
            errs.append('M4LevelBgSwap: Z=1')
        width = img['width_cells']
        cram = [cpu.read(sym['M4_SPB_CRAM'] + 2 * i, 2) for i in range(28)] + [0] * 36
        exp_cram = [int(c, 16) for c in img['cram_words']]
        exp_cram[15] = sym['M4_LVHUD_XHAIR_COLOUR']
        if cram[:28] != exp_cram:
            errs.append('M4_SPB_CRAM')
        cram[15] = 0   # crosshair slot: no BG pixel uses it (slots 1..14)
        if rd(cpu, 'M4_SPB_ON', 1) != 2 or rd(cpu, 'M4_SC_BGBLACK', 1) != 0 or rd(cpu, 'M4_SC_BGSHOWN', 1) == 0:
            errs.append('M4_SPB_ON / BGBLACK / BGSHOWN')
        # pixels: 32 columns whole; 64 columns from two scroll positions (L = 63 and 31)
        md = [[None] * 512 for _ in range(512)]
        windows = [None] if width == 32 else [0, 256]
        for h in windows:
            if h is not None:
                cpu.call(sym['M4LevelBgStream'], d0=h)
            cols = [cpu.read(sym['M4_SPB_COLS'] + c, 1) for c in range(32)]
            for x in range(512):
                cx = x >> 3
                if width == 32:
                    c = cx & 31
                else:
                    if cols[cx & 31] != cx:
                        continue
                    c = cx & 31
                for y in range(512):
                    md[y][x] = vram_pixel(cpu, cram, plane_word(cpu, c, y >> 3), x & 7, y & 7)
        got = compare(snes, md)
        want = {k: v for k, v in img['pixels'].items() if k != 'exact_ratio'}
        if got != want:
            errs.append(f'pixels {got} != {want}')
        if width == 64:   # full sweep: after each step every plane column holds its source column's words
            mp = rd(cpu, 'M4_LBG_MAP', 4)
            for h in range(0, 1024, 8):
                cpu.call(sym['M4LevelBgStream'], d0=h)
                L = (((10 - h) >> 3) - 1) & 63   # neg.w / addi #10 / asr.w #3 / subq #1 / andi #63
                for s in [(L + k) & 63 for k in range(32)]:
                    c = s & 31
                    if cpu.read(sym['M4_SPB_COLS'] + c, 1) != s:
                        errs.append(f'h={h}: plane column {c} does not hold {s}')
                        break
                    if any(plane_word(cpu, c, r) != cpu.read(mp + r * 128 + s * 2, 2) for r in range(64)):
                        errs.append(f'h={h}: plane column {c} words differ from source column {s}')
                        break
                if errs:
                    break
        # RAM effects
        def expect(name, size, value, what):
            got = cpu.read(sym[name], size)
            if got != value:
                errs.append(f'{what}: {name} = {got:X}, want {value:X}')
        if p['splayerflymode_14DD'] is not None:
            expect('M4_SPP_FM', 1, p['splayerflymode_14DD'], '$14DD')
        if p['splayerflymodeopt_14DE'] is not None:
            expect('M4_SPP_FMOPT', 1, p['splayerflymodeopt_14DE'], '$14DE')
        if p['bg2Yscroll_169E'] is not None:
            expect('M4_SC_BG2Y', 2, p['bg2Yscroll_169E'], 'bg2Yscroll')
        if p['m_meters_70021C'] is not None:
            expect('M4_SC_MMETERS', 1, p['m_meters_70021C'], 'm_meters')
        if p['changeviewmode_06BA91'] and p['splayerflymode_14DD'] in (0, 1):
            expect('M4_LP_VIEWDIST', 2, (120, 60)[p['splayerflymode_14DD']], 'changeviewmode')
        if p['zdepthtable_700050']:
            v = int(p['zdepthtable_700050'][3:], 16)
            ptr = rd(cpu, 'M4_SC_DEPTH', 4)
            if bytes(cpu.read(ptr + k, 1) for k in range(4)) != ROM[lorom(3, v):lorom(3, v) + 4]:
                errs.append('zdepth table bytes')
        else:
            expect('M4_SC_DEPTH', 4, 0x0BADBAD0, 'zdepth untouched')
        if p['pstrat_1788']:
            ps = int(p['pstrat_1788'].replace(':', ''), 16)
            expect('M4_SC_NEWPSTRAT', 4, sym[PSTRATS[ps][1]] if ps in PSTRATS else 0, 'newplayerstrat')
        else:
            expect('M4_SC_NEWPSTRAT', 4, 0x12345678, 'newplayerstrat untouched')
        if p['gamepal_1899'] is not None:
            got = [cpu.read(sym['M4_BASE_CRAM'] + 64 + 2 * i, 2) for i in range(16)]
            want = [cpu.read(gamepals + 32 * p['gamepal_1899'] + 2 * i, 2) for i in range(16)]
            if got != want:
                errs.append('gamepal line 2')
        # M4ScBgPalette applies the rows to the CRAM base
        cpu.call(sym['M4ScBgPalette'])
        base = [cpu.read(sym['M4_BASE_CRAM'] + 2 * i, 2) for i in range(28)]
        if base != exp_cram:
            errs.append('M4ScBgPalette rows')
        # setbginfo part
        cpu.call(sym['M4LevelBgInfo'], d0=n)
        si = p['setbginfo']
        if cpu.z or (cpu.d[1] & 0xff) != si['dotsflag_16FB'] or cpu.read(sym['M4_MV'] + 30, 1) != si['starmode_701A26']:
            errs.append('M4LevelBgInfo')
        checked += 1
        print(f"check {n:02X} {b['image']} w{width}: {'OK' if not errs else errs}", flush=True)
        if errs:
            failures.append((n, errs))
    for n in (0x03, 0x1B, 0x21, 0xFF, 0xF3, 0x111):   # handled elsewhere: not in the table
        cpu = Sim(rom)
        cpu.a[7] = 0xFFFF00
        cpu.call(sym['M4LevelBgSwap'], d0=n)
        z1 = cpu.z
        cpu.call(sym['M4LevelBgInfo'], d0=n)
        if not (z1 and cpu.z and cpu.vram_writes == 0):
            failures.append((n, 'number outside the table handled'))
    # Integrated transswap (M4ScTransSwap with the BACKGROUNDS.md patch): setbg +
    # setbginfo requests at the tick end -> program, dotsflag, newplayerstrat.
    integrated = None
    for b in rep['backgrounds']:
        if not b['runtime']:
            continue
        n, p = b['number'], b['params']
        cpu = Sim(rom)
        cpu.a[7] = 0xFFFF00
        ctx = sym['TEXT_MAP_CONTEXT']
        cpu.write(ctx + 11, 0x0c, 1)
        cpu.write(ctx + 12, n, 2)
        cpu.write(sym['M4_LV_STATUS'], 1, 2)
        cpu.write(sym['LV_PLAYER'] + 32, 0xCAFEBABE, 4)
        cpu.call(sym['M4ScTransSwap'])
        if cpu.read(sym['M4_LV_STATUS'], 2) == 0xFFFF:
            if integrated is None:
                integrated = False
                break
            failures.append((n, 'M4ScTransSwap: number rejected'))
            continue
        integrated = True
        errs = []
        if cpu.read(ctx + 11, 1) & 0x0c:
            errs.append('requests not cleared')
        if cpu.read(sym['M4_SC_DOTS'], 1) != p['setbginfo']['dotsflag_16FB']:
            errs.append('dotsflag')
        ps = int(p['pstrat_1788'].replace(':', ''), 16) if p['pstrat_1788'] else None
        want = sym[PSTRATS[ps][1]] if ps in PSTRATS else 0xCAFEBABE
        if cpu.read(sym['LV_PLAYER'] + 32, 4) != want:
            errs.append(f"player strategy {cpu.read(sym['LV_PLAYER'] + 32, 4):X} want {want:X}")
        if cpu.read(sym['M4_SPB_ON'], 1) != 2:
            errs.append('plane B not loaded')
        if errs:
            failures.append((n, errs))
    print('M4ScTransSwap integration:', {None: 'no runtime numbers', False: 'ABSENT (M4ScSwapBad for table numbers)',
                                         True: 'present, checked'}[integrated])
    print(f'68000 check: {checked} backgrounds, {len(failures)} failures')
    assert not failures, failures


if __name__ == '__main__':
    if '--check-rom' in sys.argv:
        k = sys.argv.index('--check-rom')
        check_rom(sys.argv[k + 1], sys.argv[k + 2])
    else:
        main(force='--force' in sys.argv, png='--png' in sys.argv)

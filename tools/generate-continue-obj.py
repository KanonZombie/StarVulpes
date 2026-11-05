"""CONTINUE screen OBJ (foxy_continue_l 03:E3C7) as Mega Drive sprite data.

Source (selected USA rev0 ROM, build/agent-continue/CONTINUE.md):
- fobjccr: MDECRU ending 16:E024 (0xB59F4..0xB6024), VRAM word $6800 =
  OBJ tile $80 (the tables add spradd $80); 80 tiles.
- OBJ palette 0 (attribute $30: priority 3, palette 0, no flips) = CGRAM
  128..143 = bgfoxpac (palette collection 7F:00E0, 512 bytes) row 8.
- fox_sprites_l 03:E8C2 / copyfoxsprites 03:E967: entries (x, y, chr) of
  3 bytes, x = $FF ends; animation offsets are relative to 03:E967
  (foxsprites). Index tables foxeyeanim 03:EB7E (4 words), foxarmanim
  03:EB86 (4), foxfootanim 03:EB8E (8); the lists follow up to 03:ECF4
  (shapeslist). Cursor $BC at (45|93, 179).
MD: the 80 fobjccr tiles in order (MD tile = base + chr - $80), colours on
CRAM line 3 (slots 1/2 are the reserved black/white). The table block
03:EB7E..03:ECF3 is emitted byte for byte (M4CnFoxTables) and read by the
68000 transcription of fox_sprites_l (src/screens/continue.asm). Entries whose
tile is outside fobjccr (the arm lists' $D4/$E0 fillers) must lie outside
the visible INIDISP window (capture rows 16..205): asserted here.
Output: build/continue-obj.inc, build/continue-obj.json.
"""
from starfox_rom import rom_hex
import hashlib
import json
import runpy
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
R = runpy.run_path(str(ROOT / 'tools/convert-screen-bg.py'))
T = R['T']
lorom = R['lorom']
rom = (ROOT / 'ref/Star Fox (USA).sfc').read_bytes()
assert hashlib.sha256(rom).hexdigest() == R['SHA'] and rom[0x7fdb] == 0
decode = runpy.run_path(str(ROOT / 'tools/extract-intro-background.py'))['decode']

# Code checks (rev0 bytes, re-disassembled with tools/dis65816.py).
fs = rom[lorom(0x03, 0xE8C2):lorom(0x03, 0xE967)]
for pat in (rom_hex(0x1e8c7, 5), rom_hex(0x1e8d0, 2), rom_hex(0x1e8d4, 2), rom_hex(0x1e8d9, 5), rom_hex(0x1e8de, 5),  # cursor y/x/chr/attr
            rom_hex(0x1e8f3, 4), rom_hex(0x1e8fa, 3),  # foxarmanim -> entry 14
            rom_hex(0x1e915, 4), rom_hex(0x1e91c, 3),  # foxeyeanim -> entry 0
            rom_hex(0x1e92b, 4), rom_hex(0x1e932, 3),  # foxfootanim -> entry 30
            rom_hex(0x1e948, 6), rom_hex(0x1e950, 4), rom_hex(0x1e956, 6), rom_hex(0x1e960, 4)):  # foot: random_l, $81, +8
    assert bytes.fromhex(pat) in fs, pat
cp = rom[lorom(0x03, 0xE967):lorom(0x03, 0xE993)]
assert cp.hex() == (rom_hex(0x1e967, 44)), cp.hex()
init = rom[lorom(0x03, 0xE3C7):lorom(0x03, 0xE614)]
assert bytes.fromhex(rom_hex(0x1e4a7, 9)) in init  # bgfoxccr -> $5C00
assert bytes.fromhex(rom_hex(0x1e4f3, 17)) in init  # fobjccr 16:E024 -> $6800
assert bytes.fromhex(rom_hex(0x1e40c, 17)) in init  # CGRAM <- 7F:00E0, 512

obj, obj_info = R['mdecru'](rom, decode, 0x16, 0xE024)
assert len(obj) == 2560 and obj_info['decoded_sha256'].startswith('b13cef20e68b6816'), obj_info
col, _ = R['mdecru'](rom, decode, 0x17, 0xF21C)
pal = [col[0xE0 + 0x100 + 2 * i] | col[0xE1 + 0x100 + 2 * i] << 8 for i in range(16)]
NTILES = len(obj) // 32

BASE = 0xE967  # foxsprites
TAB0, TAB1 = 0xEB7E, 0xECF4
tab = rom[lorom(0x03, TAB0):lorom(0x03, TAB1)]
assert hashlib.sha256(rom[lorom(0x03, BASE):lorom(0x03, TAB1)]).hexdigest().startswith('0bec19a6abfb81a4')


def word(addr):
    o = lorom(0x03, addr)
    return rom[o] | rom[o + 1] << 8


eye = [word(0xEB7E + 2 * i) for i in range(4)]
arm = [word(0xEB86 + 2 * i) for i in range(4)]
foot = [word(0xEB8E + 2 * i) for i in range(8)]


def entries(off):
    o = lorom(0x03, BASE + off)
    out = []
    while rom[o] != 0xFF:
        out.append((rom[o], rom[o + 1], rom[o + 2]))
        o += 3
    assert rom[o + 1] == 0xFF  # foxend: db -1,-1
    return out, BASE + off + 3 * len(out) + 2


lists = {}
end = 0
for off in sorted(set(eye + arm + foot)):
    lists[off], e = entries(off)
    end = max(end, e)
assert end == TAB1, hex(end)
assert [len(lists[o]) for o in sorted(lists)] == [14, 14, 14, 16, 16, 16, 6, 6, 6]

VIS0, VIS1 = 16, 205  # INIDISP window of the screen (every capture: rows 16..205)
# Capture rows: BG2 row = row + 1, OBJ rows OAMy..OAMy+7 (measured: build/agent-continue/check_continue_gfx.py).


def visible(x, y, chr_):
    return 0x80 <= chr_ < 0x80 + NTILES and y + 7 >= VIS0 and y <= VIS1


hidden = []
for off, es in lists.items():
    for x, y, c in es:
        if not (0x80 <= c < 0x80 + NTILES):
            assert not (y + 7 >= VIS0 and y <= VIS1), (off, x, y, c)
            hidden.append((hex(BASE + off), x, y, hex(c)))
        else:
            assert visible(x, y, c), (off, x, y, c)

slot = {0x000: 1, 0xeee: 2}
free = list(range(3, 16))
colours, inexact = [], 0


def md_index(c):
    global inexact
    if not c:
        return 0
    v = T['md9'](pal[c])
    if v not in slot:
        if not free:
            inexact += 1
            return slot[min(slot, key=lambda k: (T['dist2'](v, k), k))]
        slot[v] = free.pop(0)
        colours.append((slot[v], v, c))
    return slot[v]


def snes_tile(n):
    out = []
    for y in range(8):
        for x in range(8):
            c = 0
            for p in range(4):
                c |= ((obj[n * 32 + y * 2 + (p & 1) + (p >> 1) * 16] >> (7 - x)) & 1) << p
            out.append(c)
    return out


tiles = [[md_index(c) for c in snes_tile(n)] for n in range(NTILES)]
assert inexact == 0, 'OBJ colours do not fit CRAM line 3'

out = ['; Generated by tools/generate-continue-obj.py (USA rev0 foxy_continue_l 03:E3C7: fobjccr 16:E024,',
       '; bgfoxpac 7F:00E0 row 8, foxsprites tables 03:EB7E..03:ECF3).',
       f'M4_CN_OBJ_TILES equ {NTILES} ;fobjccr tiles: MD tile = M4_CN_OBJ_VRAM/32 + chr - $80',
       'M4CnObjColours: ;CRAM byte offset (line 3), MD colour']
for s, v, c in colours:
    out.append(f'        dc.w {96 + 2 * s},${v:03x} ;OBJ palette 0 colour {c}')
out.append('        dc.w -1')
out.append('M4CnObjTiles:')
for t in tiles:
    b = T['tile_bytes'](t)
    out.append('        dc.l ' + ','.join(f'${int.from_bytes(b[i:i + 4], "big"):08x}' for i in range(0, 32, 4)))
out.append(f'M4CnFoxBase equ M4CnFoxTables-${TAB0 - BASE:x} ;foxsprites 03:E967 (offsets base)')
out.append('M4CnFoxEyeAnim equ M4CnFoxTables+0 ;foxeyeanim 03:EB7E')
out.append('M4CnFoxArmAnim equ M4CnFoxTables+8 ;foxarmanim 03:EB86')
out.append('M4CnFoxFootAnim equ M4CnFoxTables+16 ;foxfootanim 03:EB8E')
out.append('M4CnFoxTables: ;03:EB7E..03:ECF3 verbatim (little-endian offset WORDs, then x,y,chr lists)')
for i in range(0, len(tab), 16):
    out.append('        dc.b ' + ','.join(f'${b:02x}' for b in tab[i:i + 16]))
out.append('        even')
(ROOT / 'build/continue-obj.inc').write_text('\n'.join(out) + '\n', encoding='ascii')
report = dict(rom_sha256=R['SHA'], fobjccr=obj_info, tiles=NTILES, obj_palette=[f'{c:04x}' for c in pal],
              line3={str(s): f'{v:03x}' for v, s in sorted(slot.items(), key=lambda kv: kv[1])},
              eyeanim=[hex(BASE + o) for o in eye], armanim=[hex(BASE + o) for o in arm],
              footanim=[hex(BASE + o) for o in foot],
              lists={hex(BASE + o): [list(e) for e in es] for o, es in sorted(lists.items())},
              hidden_entries=hidden, table_sha256=hashlib.sha256(tab).hexdigest())
(ROOT / 'build/continue-obj.json').write_text(json.dumps(report, indent=1) + '\n')
print(f'continue OBJ: {NTILES} tiles, {len(colours)} new colours on line 3, hidden filler entries {len(hidden)}')

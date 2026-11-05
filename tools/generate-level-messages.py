"""Level OBJ sprites of do_sprites_l 03:DB5A as Mega Drive sprites: the texts
"SCRAMBLE", "STAGE n", "STAGE n CLEAR" (n = stage + 1) and "TRAINING" and the HUD labels and counters (lives, SHIELD,
ENEMY, nova bombs).

Source (selected USA rev0 ROM; research build/research/corneria-scramble.md
section 4.1 and build/research/sprites.md section 8; tools/extract-sprite-messages.py,
whose byte checks of prt_scramble 03:DD08, do_stage 03:DD53 and
print_sprite_mes 03:DDF1 this generator re-runs): glyph tables at sprsbase
03:DE88, HUD OBJ characters 14:E0C3 (VRAM $6800, tiles $80..$FF) and OBJ
palettes 7F:1360 + 32p.
  scramblemes  tpx $4848, attribute |= $0400 (OBJ palette 2)
  stagemes + stageptrs[stage 0 + 1] ("1")  tpx $4850, OBJ palette 0
  lives 03:DBDD: (16,17) BD icon, (24,17) E2 "x", (32,17) E3+d digit
  SHIELD 03:DC20: (24..48,183) CB..CE
  ENEMY 03:E148: (200-w+8k, 16) F1..F4
  bombs 03:E04E: (225-9i, 182) BC
MD: one sprite per glyph (16x16 -> 2x2 cells in VDP column order TL, BL, TR,
BR; 8x16 -> 1x2; label rows -> 4x1), high priority. Colours: OBJ palette 0
(HUD, STAGE) on line 3, reusing equal MD values and filling its free slots
(1 black margin, 2 FPS, 4/5/7/13/14 HUD bars are taken); OBJ palette 2
(SCRAMBLE) on line 1 slots 12..15, which the Corneria BG leaves free and the
tunnel black-out (makeBG2black) keeps. Screen position: x = OAM x; y = OAM y
+ 1 (SNES OBJ appear one line below OAM Y) + 1 (the SNES 3D window starts at
line 15, the MD bitmap at line 16) [H, research pending point 7].
Output: build/level-messages.inc and build/level-messages.json.
"""
import hashlib
import json
import runpy
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
S = runpy.run_path(str(ROOT / 'tools/extract-sprite-textures.py'))
X = runpy.run_path(str(ROOT / 'tools/extract-sprite-messages.py'), run_name='sprite_messages')
data = (ROOT / 'ref/Star Fox (USA).sfc').read_bytes()
assert hashlib.sha256(data).hexdigest() == X['SHA'] and data[0x7fdb] == 0
for off, hx in {**X['CHECKS'], **X['WRITERS']}.items():
    assert data[off:off + len(hx) // 2].hex() == hx, hex(off)
HUD_CODE = {0x1dbdd: 'lives', 0x1dc20: 'shield', 0x1e148: 'enemy', 0x1e04e: 'bombs'}
for off in HUD_CODE:
    assert data[off] in (0xe2, 0xc2, 0xad, 0xa9, 0xac, 0xae, 0xda, 0x08, 0xa2, 0xa0), (hex(off), hex(data[off]))
base = 0x18000 + (0xDE88 & 0x7FFF)
w = lambda o: data[base + o] | data[base + o + 1] << 8


def message(off):
    glyphs = []
    while w(off) != 0xFFFF:
        g = w(off)
        if w(g) == 0xFFFE:
            glyphs.append(('8x16', [w(g + 2), w(g + 4)]))
        else:
            glyphs.append(('16x16', [w(g + i) for i in (0, 2, 4, 6)]))
        off += 2
    return glyphs


decode = runpy.run_path(str(ROOT / 'tools/extract-intro-background.py'))['decode']
end = S['phys'](0x14, 0xE0C3)
chr_data = decode(data[end - 0x4000:end])[0][:0x1000]
pals_raw, ptr = decode(data[0xB8000:0xBF21C])
assert 0xB8000 + ptr['source_word_offset'] == 0xBE6C0 and len(pals_raw) == 5120
snes_pal = lambda p, i: pals_raw[0x1360 + 32 * p + 2 * i] | pals_raw[0x1361 + 32 * p + 2 * i] << 8
md_colour = lambda c: (((c >> 10) & 31) >> 2 << 9) | (((c >> 5) & 31) >> 2 << 5) | ((c & 31) >> 2 << 1)

# MD lines: OBJ palette -> (line, {MD colour: slot} already present, free slots)
LINE3_TAKEN = {0x000: 1, 0xeee: 2}                 # margin black, FPS white (HUD bar colours are not reused)
lines_for = {0: (3, dict(LINE3_TAKEN), [3, 6, 8, 9, 10, 11, 12, 15]), 2: (1, {}, [12, 13, 14, 15])}
# Crosshair (OBJ palette 4, one colour $03E0): line 3 is full; the cockpit
# exists only in space stages, whose BG uses line 0 slots 1..7, so its colour
# goes to line 0 slot 15 through the space BG CRAM rows (level_space_bg.asm,
# M4_LVHUD_XHAIR_COLOUR), not through M4LvMsgColours.
lines_for[4] = (0, {}, [15])
XHAIR_PAL = 4
slot = {}
colours = []
xhair_colour = []


def colour_slot(pal, c):
    if (pal, c) not in slot:
        line, have, free = lines_for[pal]
        v = md_colour(snes_pal(pal, c))
        if v not in have:
            assert free, (pal, c, 'no free CRAM slot')
            have[v] = free.pop(0)
            if pal == XHAIR_PAL:
                xhair_colour.append(v)
            else:
                colours.append((line, have[v], v, pal, c))
        slot[(pal, c)] = have[v]
    return slot[(pal, c)]


tiles = []


def tile_of(v):
    pal = (v >> 9) & 7
    pix = S['snes_tile'](chr_data, v & 0xFF)
    return b''.join(bytes((colour_slot(pal, r[i]) if r[i] else 0) << 4 | (colour_slot(pal, r[i + 1]) if r[i + 1] else 0)
                          for i in (0, 2, 4, 6)) for r in pix)


def add_tiles(words):
    """Tiles of the glyph cells in sprite order; a run already present (same
    glyph in another text) is shared, so the VRAM area stays small."""
    run = [tile_of(v) for v in words]
    for first in range(len(tiles) - len(run) + 1):
        if tiles[first:first + len(run)] == run:
            return first
    first = len(tiles)
    tiles.extend(run)
    return first


out, report = [], {}


def sprite_list(name, glyphs, tpx, attr_or):
    x, y = tpx & 0xFF, tpx >> 8
    sprites = []
    for kind, ws in glyphs:
        if kind == 'gap':                       # tpx += 8 (prt_stageclear 03:DDB3)
            x += ws
            continue
        ws = [v | attr_or for v in ws]
        assert all((v >> 12) & 3 == 3 and not v & 0xC000 for v in ws), [hex(v) for v in ws]   # priority 3, no flip
        first = add_tiles([ws[0], ws[2], ws[1], ws[3]] if kind == '16x16' else ws)
        line = lines_for[(ws[0] >> 9) & 7][0]
        sprites.append((y + 2, 0x05 if kind == '16x16' else 0x01, line, first, x))
        x += 16 if kind == '16x16' else 8
    out.append(f'M4LvMsg{name}:')
    out.append(f'        dc.w {len(sprites)}')
    for sy, size, line, first, sx in sprites:
        out.append(f'        dc.w {sy + 128},${size:02x}00,${0x8000 | line << 13:04x}|(M4_LEVEL_MSG_TILES/32+{first}),{sx + 128}')
    report[name] = dict(tpx=f'{tpx:04X}', sprites=[dict(y=sy, x=sx, size=size, line=line, first_tile=first)
                                                   for sy, size, line, first, sx in sprites])


sprite_list('Scramble', message(0x0E), 0x4848, 0x0400)
# do_stage 03:DD53 / prt_stageclear 03:DDB3: STAGE + stageptrs[stage + 1]
# (sprsbase+$2C); clear: tpx $3020, tpx += 8, CLEAR. One text per stage 0..7.
STAGES = 8
for k in range(STAGES):
    sprite_list(f'Stage{k}', message(0x00) + message(w(0x2C + 2 * (k + 1))), 0x4850, 0)
    sprite_list(f'StageClear{k}', message(0x00) + message(w(0x2C + 2 * (k + 1))) + [('gap', 8)] + message(0x20), 0x3020, 0)
out.append('M4LvMsgStageTab: ;by stage (M4_GM+7)')
out += [f'        dc.l M4LvMsgStage{k}' for k in range(STAGES)]
out.append('M4LvMsgClearTab:')
out += [f'        dc.l M4LvMsgStageClear{k}' for k in range(STAGES)]
out.append(f'M4_LV_MSG_STAGES equ {STAGES}')
# trainingmes (sprsbase + $88, 03:DF10) at tpx $4848: do_stage with prttraining $1FE0 != 0 (03:DD53)
sprite_list('Training', message(0x88), 0x4848, 0)
# HUD (attribute $20: priority 2, OBJ palette 0); y + 2 as above
hud = dict(icon=add_tiles([0x30BD]), times=add_tiles([0x30E2]), digits=add_tiles([0x3000 | t for t in range(0xE3, 0xED)]),
           shield=add_tiles([0x30CB, 0x30CC, 0x30CD, 0x30CE]), enemy=add_tiles([0x30F1, 0x30F2, 0x30F3, 0x30F4]),
           bomb=add_tiles([0x30BC]),
           # do_crosshair 03:E0B5: tile $E1, OBJ palette 4, priority 2 (attribute $28)
           xhair=add_tiles([0x3000 | 4 << 9 | 0xE1]))
for k, v in hud.items():
    line = 0 if k == 'xhair' else 3
    out.append(f'M4_LVHUD_{k.upper()} equ ${0x8000 | line << 13:04x}|(M4_LEVEL_MSG_TILES/32+{v})')
assert len(xhair_colour) == 1
out.append(f'M4_LVHUD_XHAIR_COLOUR equ ${xhair_colour[0]:03x} ;line 0 slot 15 (OBJ palette 4 colour 1)')
out.append('M4_LVHUD_Y_LIVES equ 17+2+128\nM4_LVHUD_Y_SHIELD equ 183+2+128\nM4_LVHUD_Y_ENEMY equ 16+2+128\nM4_LVHUD_Y_BOMB equ 182+2+128')
out.insert(0, f'M4_LEVEL_MSG_COUNT equ {len(tiles)}')
out.append('M4LvMsgColours: ;CRAM byte offset, MD colour')
for line, s, v, pal, c in colours:
    out.append(f'        dc.w {32 * line + 2 * s},${v:03x} ;line {line} slot {s}: OBJ palette {pal} colour {c} ${snes_pal(pal, c):04X}')
out.append('        dc.w -1')
out.append('M4LvMsgTiles:')
for t in tiles:
    out.append('        dc.l ' + ','.join(f'${int.from_bytes(t[i:i + 4], "big"):08x}' for i in range(0, 32, 4)))
out.insert(0, '; Generated by tools/generate-level-messages.py (USA rev0 03:DB5A..03:E148, 03:DDF1, 14:E0C3).')
(ROOT / 'build/level-messages.inc').write_text('\n'.join(out) + '\n', encoding='ascii')
(ROOT / 'build/level-messages.json').write_text(json.dumps(dict(
    rom_sha256=X['SHA'], tiles=len(tiles), colours=[dict(line=l, slot=s, md=f'{v:03x}', obj_palette=p, colour=c)
                                                    for l, s, v, p, c in colours],
    texts=report, hud=hud, y_convention='MD y = OAM y + 2 [H]'), indent=1) + '\n')
print('Generated level OBJ sprites:', len(tiles), 'tiles,', len(colours), 'colours')

"""SNES BG2 screens outside the levels -> Mega Drive plane B (tiles, name table,
CRAM lines), for the controls, route map, Pepper, game over, continue and
credits screens (build/research/screens-and-flow.md).

Resources come from tools/extract-screen-resources.py (MDECRU decoded twice,
hashes in build/research/screens/resources.json). Palette mapping reuses the
optimiser of tools/extract-title-background.py: original colours only, MD
value = SNES component >> 2, lines (0, 1, 3) with line 3 slots 1/2 reserved;
the GSU palette keeps line 2. Every 8x8 cell is converted exactly when its
colours fit the chosen line; the report gives the exact-pixel ratio and the
error of the others (a deliberate, measured difference).

Usage: convert-screen-bg.py NAME (controls, ...). Output:
build/screen-NAME.inc (tiles, maps, CRAM) and build/screen-NAME.json.
"""
import collections
import hashlib
import json
import runpy
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
T = runpy.run_path(str(ROOT / 'tools/extract-title-background.py'))
_item_cost = T['item_cost']


def _safe_item_cost(hist, colours):  # an empty line costs every pixel (the title never had one)
    if not colours:
        return sum(hist.values()), 10 ** 9
    return _item_cost(hist, colours)


T['optimise_palettes'].__globals__['item_cost'] = _safe_item_cost
SHA = '3857b5294ea8f7468849437bb2d8271564e8a0ff30774622e9c872bcbd53a84d'


def lorom(bank, addr):
    return (bank & 0x7f) * 0x8000 + (addr & 0x7fff)


def mdecru(rom, decode, bank, end):
    e = lorom(bank, end)
    lo = max(e - 0x4000, bank * 0x8000 - 0x4000, 0)
    out, tr = decode(rom[lo:e])
    s = lo + tr['source_word_offset']
    again, _ = decode(rom[s:e])
    assert again == out
    return out, dict(rom=f'0x{s:05X}..0x{e:05X}', decoded_sha256=hashlib.sha256(out).hexdigest())


# name: chr (bank, end, VRAM word base), scr (bank, end, map addend), palette
# collection (offset, bytes, first CGRAM row), views = list of (map x0, y0)
# 32x32 cell windows (one MD plane B map each), MD tile base (VRAM byte).
SCREENS = {
    'controls': dict(chr=(0x17, 0x9618, 0x5C00), scr=(0x17, 0x98C4, 0x00C0, 64), pal=(0x440, 0xE0, 0),
                     views=[(0, 0), (32, 0), (0, 32), (32, 32)], vram=0x9a40,
                     source='bg_cont_1 03:A85B; set_c_type 1F:FE0A quadrants A (0,0) B (256,0) C (0,256) D (256,256)'),
    # Route map (setup_planets_l 03:CCF5): mapccr at VRAM word $5200 (BG2 char
    # base $5000: tile = map word + $20), mappcr, planselpal 03:D440 (CGRAM 0..255,
    # BG2 row 6). Cells outside mapccr are the GSU/OBJ area: transparent.
    # extra: words drawroutename 03:C66B writes at run time (LEVEL n labels
    # $188E..$189F, digits $18A8..$18B1, $18BA, credit $18DE; chr index =
    # word - $20), converted as extra cells (table M4ScrRoutemapExtra).
    'routemap': dict(chr=(0x15, 0xE898, 0x5200), scr=(0x16, 0xB334, 0x0000, 32), pal=None,
                     pal_rom=(0x03, 0xD440, 512), tile_offset=0, views=[(0, 0)], vram=0x9a40,
                     extra=[0x1800 | t for t in list(range(0x8e, 0xa0)) + list(range(0xa8, 0xb2)) + [0xba, 0xde]],
                     extra_sub=0x20, exact_row=6,
                     source='planetseq_l 03:BDCB setup_planets_l 03:CCF5 mapccr/mappcr, planselpal 03:D440'),
    # Game over (bg_gameover_1 03:A963): Andross on BG2, chr at VRAM word $5C00,
    # scr +$C0, palette collection 7F:0440 rows 0..6, bg2vofsreq 32.
    'gameover': dict(chr=(0x05, 0xFF74, 0x5C00), scr=(0x00, 0xFF96, 0x00C0, 32), pal=(0x440, 0xE0, 0),
                     views=[(0, 0)], vram=0x9a40,
                     source='gameover_l 02:E4C2, bg_gameover_1 03:A963 (Andross), palette collection 7F:0440'),
    # copy: copyfox 03:C5C0 copies VRAM words $5200..$533F (mapccr tiles
    # 0..19, the map's Fox face) to $6C20 = dogccr tiles 64..83, zero in ROM.
    'pepper': dict(chr=(0x11, 0xFB89, 0x6820), scr=(0x17, 0x827C, 0x0000, 32), pal=None,
                   pal_rom=(0x03, 0xD440, 512), tile_offset=384, views=[(0, 0)], vram=0x9a40,
                   copy=dict(src=(0x15, 0xE898), src_tile=0, dst_tile=64, tiles=20),
                   source='continuewithgame 03:C038 dogccr (VRAM word $6820 = BG2 tile 386) / dogpcr (+2): '
                          'chr tile = word - 384; the other cells show the GSU bitmap (transparent here)'),
    # Continue (foxy_continue_l 03:E3C7, build/agent-continue/CONTINUE.md):
    # bgfoxccr at VRAM word $5C00 (BG2 char base $5000: tile = map word + $C0),
    # bgfoxpcr +$C0 (32x32, BG2 rows 4..5), bgfoxpac = palette collection
    # 7F:00E0, 512 bytes, CGRAM 0..255. extra: the CREDIT digit foxirq3 02:8712
    # rewrites at VRAM $731D every transfer (word credits + $3528: chr $68 + n,
    # palette 5, priority), n = 0..9; chr index = word - $C0.
    'continue': dict(chr=(0x14, 0xF253, 0x5C00), scr=(0x14, 0xF41B, 0x00C0, 32), pal=(0xE0, 0x200, 0),
                     views=[(0, 0)], vram=0x9a40, extra=[0x3528 + n for n in range(10)], extra_sub=0xC0,
                     source='foxy_continue_l 03:E3C7 bgfoxccr/bgfoxpcr, bgfoxpac 7F:00E0; credit digit foxirq3 02:8712'),
    # Asteroid Belt 1 (setbg $21, bg_1_2 03:92DF): space, BG2 64x64 cells
    # (512 px period both ways), chr 15:A408 at VRAM word $5C00, scr 16:B944
    # +$C0, palette collection 7F:0D40 rows 0..6 (row 5 zero: the 48 cells on
    # palette 5 are black in the original). Plane B streams the 64 columns
    # (level_space_bg.asm), so the four views are the four SNES screens.
    'space12': dict(chr=(0x15, 0xA408, 0x5C00), scr=(0x16, 0xB944, 0x00C0, 64), pal=(0xD40, 0xE0, 0),
                    views=[(0, 0), (32, 0), (0, 32), (32, 32)], vram=0x9a40,
                    source='bg_1_2 03:92DF (setbg $21 at 0D:D268 asteroid1), palette collection 7F:0D40'),
}


def snes_cell(chars, word, bpp=4):
    tile = word & 1023
    if (tile + 1) * bpp * 8 > len(chars):  # outside the converted chr: transparent
        return [0] * 64, (word >> 10) & 7, (word >> 13) & 1
    pal = (word >> 10) & 7
    out = []
    for y in range(8):
        fy = 7 - y if word & 0x8000 else y
        base = tile * bpp * 8 + fy * 2
        for x in range(8):
            fx = 7 - x if word & 0x4000 else x
            c = 0
            for plane in range(bpp):
                byte = chars[base + (plane & 1) + (plane >> 1) * 16]
                c |= ((byte >> (7 - fx)) & 1) << plane
            out.append(c)
    return out, pal, (word >> 13) & 1


def convert(name):
    cfg = SCREENS[name]
    rom = (ROOT / 'ref/Star Fox (USA).sfc').read_bytes()
    assert hashlib.sha256(rom).hexdigest() == SHA and rom[0x7fdb] == 0
    decode = runpy.run_path(str(ROOT / 'tools/extract-intro-background.py'))['decode']
    cbank, cend, cbase = cfg['chr']
    sbank, send, addend, width = cfg['scr']
    chars, chr_info = mdecru(rom, decode, cbank, cend)
    if cfg.get('copy'):
        cp = cfg['copy']
        src, _ = mdecru(rom, decode, *cp['src'])
        chars = bytearray(chars)
        d0, s0, n = cp['dst_tile'] * 32, cp['src_tile'] * 32, cp['tiles'] * 32
        assert not any(chars[d0:d0 + n]), 'copy target not empty'
        chars[d0:d0 + n] = src[s0:s0 + n]
        chars = bytes(chars)
    scr, scr_info = mdecru(rom, decode, sbank, send)
    col, col_info = mdecru(rom, decode, 0x17, 0xF21C)
    assert len(col) == 5120
    cgram = {}
    if cfg.get('pal'):
        off, nbytes, row0 = cfg['pal']
        for i in range(nbytes // 2):
            cgram[row0 * 16 + i] = col[off + 2 * i] | col[off + 2 * i + 1] << 8
    else:
        pb, pa, pn = cfg['pal_rom']
        o = lorom(pb, pa)
        for i in range(pn // 2):
            cgram[i] = rom[o + 2 * i] | rom[o + 2 * i + 1] << 8

    def map_word(x, y):  # SNES 64x64 = four 32x32 screens in order (0,0) (1,0) (0,1) (1,1)
        if width == 64:
            sc = (x >> 5) + 2 * (y >> 5)
            o = sc * 2048 + ((y & 31) * 32 + (x & 31)) * 2
        else:
            o = (y * 32 + x) * 2
        w = scr[o] | scr[o + 1] << 8
        return w  # raw decoded words index the decoded chr (the addend is applied at load)

    # cells of every view: (snes indices, snes palette row, priority)
    cells, items = {}, []
    for v, (x0, y0) in enumerate(cfg['views']):
        for cy in range(32):
            for cx in range(32):
                word = map_word(x0 + cx, y0 + cy)
                t = (word & 1023) - cfg.get('tile_offset', 0)
                word = (word & ~1023) | (t if t >= 0 else 1023)
                idx, pal, pri = snes_cell(chars, word)
                hist = collections.Counter(T['md9'](cgram.get(pal * 16 + c, 0)) for c in idx if c)
                cells[(v, cx, cy)] = (idx, pal, pri)
                items.append(dict(hist=hist, group=f'p{pal}', key=(v, cx, cy)))
    extra = cfg.get('extra', [])
    for i, word in enumerate(extra):
        t = (word & 1023) - cfg.get('extra_sub', 0)
        idx, pal, pri = snes_cell(chars, (word & ~1023) | t)
        hist = collections.Counter(T['md9'](cgram.get(pal * 16 + c, 0)) for c in idx if c)
        cells[('x', i, 0)] = (idx, pal, pri)
        items.append(dict(hist=hist, group=f'p{pal}', key=('x', i, 0)))
    if cfg.get('exact_row') is not None:
        # One CRAM line equal to the SNES palette row (MD index = SNES index):
        # the SVP planet sprites draw raw row-6 texels on the same line.
        r = cfg['exact_row']
        assert all(cells[it['key']][1] == r for it in items)
        palettes = {0: [T['md9'](cgram.get(r * 16 + i, 0)) for i in range(1, 16)]}
        owner = [0] * len(items)
    else:
        cost, owner, palettes = T['optimise_palettes'](items)
    line_of = {it['key']: o for it, o in zip(items, owner)}
    # MD tiles: indices into the chosen line (exact colour or nearest)
    tiles, tile_ids, maps = [], {}, []
    exact = total = 0
    err = 0
    views = [[(v, cx, cy) for cy in range(32) for cx in range(32)] for v in range(len(cfg['views']))]
    views.append([('x', i, 0) for i in range(len(extra))])
    for keys in views:
        words = []
        for key0 in keys:
                idx, pal, pri = cells[key0]
                line = line_of[key0]
                colours = palettes[line]
                slot = {}
                if line == 3:
                    slot = {c: s for s, c in T['LINE3_FIXED'].items()}
                free = [s for s in range(1, 16) if s not in slot]
                for c in colours:
                    if c not in slot:
                        slot[c] = free.pop(0)
                md = []
                for c in idx:
                    if not c:
                        md.append(0); continue
                    m = T['md9'](cgram.get(pal * 16 + c, 0))
                    total += 1
                    if m in slot:
                        exact += 1; md.append(slot[m])
                    else:
                        near = min(slot, key=lambda k: T['dist2'](m, k))
                        err += T['dist2'](m, near); md.append(slot[near])
                key = tuple(md)
                found = None
                for h in (0, 1):
                    for vv in (0, 1):
                        f = T['flip'](key, h, vv)
                        if f in tile_ids:
                            found = (tile_ids[f], h, vv); break
                    if found: break
                if not found:
                    tile_ids[key] = len(tiles); tiles.append(key); found = (tile_ids[key], 0, 0)
                n, h, vv = found
                words.append((pri << 15) | (line << 13) | (vv << 12) | (h << 11) | (cfg['vram'] // 32 + n))
        maps.append(words)
    blank = (0,) * 64  # a fully transparent tile (margins over the BG)
    if blank not in tile_ids:
        tile_ids[blank] = len(tiles); tiles.append(blank)
    cram = {}
    for line, colours in palettes.items():
        slot = {c: s for s, c in T['LINE3_FIXED'].items()} if line == 3 else {}
        free = [s for s in range(1, 16) if s not in slot]
        for c in colours:
            if c not in slot:
                slot[c] = free.pop(0)
        for c, s in slot.items():
            cram[(line, s)] = c
    backdrop = T['md9'](cgram.get(0, 0))
    out = [f'; Generated by tools/convert-screen-bg.py {name} ({cfg["source"]}).',
           f'M4_SCR_{name.upper()}_TILES equ {len(tiles)}', f'M4_SCR_{name.upper()}_VRAM equ ${cfg["vram"]:04x}',
           f'M4_SCR_{name.upper()}_BLANK equ {cfg["vram"] // 32 + tile_ids[blank]} ;transparent tile number',
           f'M4Scr{name.capitalize()}Tiles:']
    for t in tiles:
        b = T['tile_bytes'](t)
        out.append('        dc.l ' + ','.join(f'${int.from_bytes(b[i:i + 4], "big"):08x}' for i in range(0, 32, 4)))
    extra_words = maps.pop()
    if extra:
        out.append(f'M4Scr{name.capitalize()}Extra: ;run-time SNES word, MD name table word')
        out += [f'        dc.w ${sw:04x},${mw:04x}' for sw, mw in zip(extra, extra_words)]
        out.append('        dc.w 0')
    for v, words in enumerate(maps):
        out.append(f'M4Scr{name.capitalize()}Map{v}: ;32x32 cells, view {cfg["views"][v]}')
        for r in range(32):
            out.append('        dc.w ' + ','.join(f'${w:04x}' for w in words[r * 32:(r + 1) * 32]))
    out.append(f'M4Scr{name.capitalize()}Cram: ;CRAM byte offset, MD colour (line 2: GSU palette)')
    out.append(f'        dc.w 0,${backdrop:03x}')
    for (line, s), c in sorted(cram.items()):
        out.append(f'        dc.w {32 * line + 2 * s},${c:03x}')
    out.append('        dc.w -1')
    (ROOT / f'build/screen-{name}.inc').write_text('\n'.join(out) + '\n', encoding='ascii')
    end = cfg['vram'] + 32 * len(tiles)
    report = dict(rom_sha256=SHA, screen=name, source=cfg['source'], chr=chr_info, scr=scr_info, palette_collection=col_info,
                  tiles=len(tiles), vram=f'{cfg["vram"]:04X}..{end:04X}', exact_pixels=exact, pixels=total,
                  exact_ratio=round(exact / max(total, 1), 4), squared_error=err,
                  lines={str(k): [f'{c:03x}' for c in v] for k, v in palettes.items()}, backdrop=f'{backdrop:03x}')
    (ROOT / f'build/screen-{name}.json').write_text(json.dumps(report, indent=1) + '\n')
    print(f'{name}: {len(tiles)} tiles VRAM {report["vram"]}, exact {exact}/{total} ({report["exact_ratio"]})')
    assert end <= 0xc000, 'tile area overflows plane A'


# Bump when the conversion algorithm changes (the cache key no longer hashes
# the whole source: unrelated edits do not redo the slow palette searches).
CONVERTER_VERSION = 'v3 extra cells, copy, exact_row'


def cached(name):
    """Skip the (slow) palette search when the output was produced by this
    same tool source and configuration."""
    key = hashlib.sha256((CONVERTER_VERSION + repr(SCREENS[name])).encode()).hexdigest()
    rep = ROOT / f'build/screen-{name}.json'
    if (ROOT / f'build/screen-{name}.inc').exists() and rep.exists():
        if json.loads(rep.read_text()).get('tool_key') == key:
            return key, True
    return key, False


if __name__ == '__main__':
    for n in sys.argv[1:] or SCREENS:
        key, hit = cached(n)
        if hit:
            print(f'{n}: cached build/screen-{n}.inc')
            continue
        convert(n)
        rep = ROOT / f'build/screen-{n}.json'
        d = json.loads(rep.read_text()); d['tool_key'] = key
        rep.write_text(json.dumps(d, indent=1) + chr(10))

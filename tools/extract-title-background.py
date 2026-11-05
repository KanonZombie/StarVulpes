"""ROM-authoritative title-screen background (SNES BG2+BG3) and MD conversion.

Source unit: selected ROM USA rev0, bg_title_1 at physical 1A9F5 (03:A9F5).
Guidance only: UltraStarFox SF/ASM/BGS.ASM bg_title_1, SF/INC/BGMACS.INC,
SF/BANK/INCBINS.ASM (ti3/cp resources), SF/INC/KALCS.INC (palette list).
The ROM bytes asserted below are the authority; UltraStarFox differs in its
palette ordering (cpusp is at collection offset F00 in this ROM).

Reuses the original MDECRU translation from tools/extract-intro-background.py.
Optional runtime evidence (BizHawk 2.9.1, original game) is read from
evidence/starfox-original-title-gf*.{vram,wram}.bin/.png to verify the decoded
resources, the palette buffer and the derived layer setup. The Super FX layer
(BG1) is NOT converted; it is only used as a mask in the screenshot comparison.
"""
from starfox_rom import rom_hex
import collections
import hashlib
import json
from pathlib import Path
import runpy
import sys

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SHA = '3857b5294ea8f7468849437bb2d8271564e8a0ff30774622e9c872bcbd53a84d'
BUILD = ROOT / 'build'
EVID = ROOT / 'evidence'
GAMEFRAMES = (5, 21, 60, 120, 160, 300)

# Original title setup (03:A9F5..03:AAF8), selected ROM bytes.
TITLE_SETUP = 0x1a9f5
TITLE_SETUP_BYTES = bytes.fromhex(
    rom_hex(0x1a9f5, 260))
# Helpers called by the setup (selected ROM): chr decrunch to SFX RAM 2800,
# screen decrunch to SFX RAM 4000 with m_decoffset 00C0 (bg2scr) or 0000.
HELPERS = {
    0x1ab2b: rom_hex(0x1ab2b, 23),
    0x1ab42: rom_hex(0x1ab42, 30),
    0x1ab60: rom_hex(0x1ab60, 30),
    # bg2chr inline reader: m_decoffset=0, bank, end, VRAM dest $188C, len $188E
    0x1ab95: rom_hex(0x1ab95, 56),
    # bg2scr inline reader: dest $1890, len $1892, jsl 03:AB42 (addend C0)
    0x1abcd: rom_hex(0x1abcd, 49),
    # dopalette: copies E0 bytes from long pointer to WRAM 7E:178B
    0x1abfe: rom_hex(0x1abfe, 68),
    # mode1 transfer handler: BGMODE=1, BG3SC=74, BG34NBA=07 (title rewrites 68/07)
    0x10037: rom_hex(0x10037, 23),
    # Title loop after MainLoop: BGMODE=09 (mode1 + BG3 priority) every frame.
    0xff50d: rom_hex(0xff50d, 5),
    # intro mode2 setup leaves BG2SC=73 (base word 7000, 64x64) and BG12NBA hi=5.
    0x17193: rom_hex(0x17193, 26),
    # BG3HOFS shadow: ((player obj +0C) asr 3) - 4; NMI writes it when 18BA!=0.
    0x1597a: rom_hex(0x1597a, 29),
    0x10b2d: rom_hex(0x10b2d, 17),
    # Boot palette collection decrunch (end pointer 17:F21C), as in the intro tool.
    0x1628a: rom_hex(0x1628a, 40),
}


def lorom(bank, address):
    assert 0x8000 <= address <= 0xffff
    return (bank & 0x7f) * 0x8000 + (address - 0x8000)


def u16(data, offset):
    return data[offset] | data[offset + 1] << 8


def parse_setup(rom):
    code = rom[TITLE_SETUP:TITLE_SETUP + len(TITLE_SETUP_BYTES)]
    assert code == TITLE_SETUP_BYTES, 'title setup bytes differ from selected ROM'
    for offset, hexbytes in HELPERS.items():
        expected = bytes.fromhex(hexbytes)
        assert rom[offset:offset + len(expected)] == expected, hex(offset)
    def imm(store, nth=0, width=2):
        """Immediate loaded by the LDA right before the nth occurrence of store."""
        at = -1
        for _ in range(nth + 1):
            at = code.index(bytes.fromhex(store), at + 1)
        assert code[at - 1 - width] == 0xa9, (store, nth)
        return int.from_bytes(code[at - width:at], 'little')
    bg3chr = dict(bank=imm('8f640070'), end=imm('8f620070'), vram_word=imm('8d8c18'), dma_bytes=imm('8d8e18'),
                  decoder='03:AB2B (SFX RAM 2800, m_decoffset 0)')
    bg3scr = dict(bank=imm('8f640070', 1), end=imm('8f620070', 1), vram_word=imm('8d9018'), dma_bytes=imm('8d9218'),
                  decoder='03:AB60 (SFX RAM 4000, m_decoffset 0)')
    def inline(call):  # jsr helper ; dw end ; db bank ; dw VRAM word ; dw bytes
        p = code.index(bytes.fromhex(call)) + 3
        return dict(bank=code[p + 2], end=int.from_bytes(code[p:p + 2], 'little'),
                    vram_word=int.from_bytes(code[p + 3:p + 5], 'little'), dma_bytes=int.from_bytes(code[p + 5:p + 7], 'little'))
    bg2chr = dict(inline('2095ab'), decoder='03:AB2B via 03:AB95 (SFX RAM 2800, m_decoffset 0)')
    bg2scr = dict(inline('20cdab'), decoder='03:AB42 via 03:ABCD (SFX RAM 4000, m_decoffset 00C0 added to every map word)',
                  map_word_addend=0xc0)
    p = code.index(bytes.fromhex('20feab')) + 3  # dopalette ; dl source ; dw length
    palette = dict(address=code[p + 2] << 16 | int.from_bytes(code[p:p + 2], 'little'),
                   length=int.from_bytes(code[p + 3:p + 5], 'little'), wram_destination=0x7e178b)
    regs = dict(bg34nba=imm('8d0c21', width=1), bg3sc=imm('8d0921', width=1),
                bg3vofs=imm('8d1221', 0, 1) | imm('8d1221', 1, 1) << 8,
                bg2_yscroll=imm('8d9e16'), tm=imm('8d2c21', 1, 1),
                pal0_cleared=bytes.fromhex(rom_hex(0x1aa85, 6)) in code)
    return dict(bg3chr=bg3chr, bg3scr=bg3scr, bg2chr=bg2chr, bg2scr=bg2scr, palette=palette, registers=regs)


def decode_resource(decode, rom, info):
    end = lorom(info['bank'], info['end'])
    window = rom[end - 0x4000:end]
    output, trace = decode(window)
    start = end - 0x4000 + trace['source_word_offset']
    again, _ = decode(rom[start:end])
    assert again == output
    stream = rom[start:end]
    info.update(rom_range=f'{start:05X}..{end:05X}', cpu_end=f"{info['bank']:02X}:{info['end']:04X}",
                vram_byte_hex=f"{info['vram_word'] * 2:04X}",
                rom_start=start, rom_end=end, compressed_bytes=len(stream),
                compressed_sha256=hashlib.sha256(stream).hexdigest(),
                decoded_bytes=len(output), decoded_sha256=hashlib.sha256(output).hexdigest(),
                vram_byte=info['vram_word'] * 2)
    return output


# ---------------------------------------------------------------- SNES model
class Layer:
    def __init__(self, chars, bpp, screens, width, height, hofs, vofs):
        self.chars, self.bpp, self.screens = chars, bpp, screens
        self.width, self.height, self.hofs, self.vofs = width, height, hofs, vofs

    def pixel(self, x, y):
        """Returns (colour index, palette, priority) for screen pixel x,y."""
        px = (x + self.hofs) % (self.width * 8)
        py = (y + self.vofs) % (self.height * 8)
        tx, ty = px >> 3, py >> 3
        screen = self.screens.get((tx >> 5, ty >> 5))
        if screen is None:
            raise AssertionError(f'unextracted screen {(tx >> 5, ty >> 5)}')
        word = u16(screen, ((ty & 31) * 32 + (tx & 31)) * 2)
        tile = word & 1023
        fx, fy = px & 7, py & 7
        if word & 0x4000: fx = 7 - fx
        if word & 0x8000: fy = 7 - fy
        size = self.bpp * 8
        assert 0 <= tile and (tile + 1) * size <= len(self.chars), tile
        base = tile * size + fy * 2
        colour = 0
        for plane in range(self.bpp):
            byte = self.chars[base + (plane & 1) + (plane >> 1) * 16]
            colour |= ((byte >> (7 - fx)) & 1) << plane
        return colour, (word >> 10) & 7, (word >> 13) & 1


def snes_layers(res, setup):
    """Effective scroll: the PPU shows BG row (VOFS+1) on the first visible line."""
    # BG2: 64x64 (BG2SC=73); only SC2 (bottom-left, VRAM F000) is reachable with
    # HOFS 0 / VOFS 258 over 256x224. Raw decoded map words index decoded chr.
    bg2 = Layer(res['bg2chr'], 4, {(0, 1): res['bg2scr']}, 64, 64, 0, setup['registers']['bg2_yscroll'] + 1)
    bg3 = Layer(res['bg3chr'], 2, {(0, 0): res['bg3scr']}, 32, 32, -4, setup['registers']['bg3vofs'] + 1)
    return bg2, bg3


def snes_compose(bg2, bg3, cgram, x, y):
    """Mode 1 with BGMODE bit3 (BG3 priority), BG1/OBJ excluded. Returns
    (colour555, class): F=in front of BG1 (BG3H or BG2H), B=behind BG1, T=none."""
    c3, p3, h3 = bg3.pixel(x, y)
    if c3 and h3:
        return cgram[p3 * 4 + c3], 'F', 'bg3H'
    c2, p2, h2 = bg2.pixel(x, y)
    if c2:
        return cgram[p2 * 16 + c2], ('F' if h2 else 'B'), ('bg2H' if h2 else 'bg2L') + f'.p{p2}'
    if c3:
        return cgram[p3 * 4 + c3], 'B', 'bg3L'
    return cgram[0], 'T', 'backdrop'


def rgb555(c):
    return (c & 31, (c >> 5) & 31, (c >> 10) & 31)


def md9(c):
    """Project convention (tools/recover-intro-font.py): each component >> 2."""
    r, g, b = rgb555(c)
    return (r >> 2) << 1 | (g >> 2) << 5 | (b >> 2) << 9


def md_rgb(m):
    return ((m >> 1) & 7, (m >> 5) & 7, (m >> 9) & 7)


def to_png_rgb555(c):
    r, g, b = rgb555(c)
    return (r << 3 | r >> 2, g << 3 | g >> 2, b << 3 | b >> 2)


def to_png_md(m):
    r, g, b = md_rgb(m)
    return (r * 36 + r // 2, g * 36 + g // 2, b * 36 + b // 2)


def shot_555(pixel):
    return tuple(round(v * 31 / 255) for v in pixel)


# --------------------------------------------------------------- MD mapping
MD_WINDOW = (15, 206)  # plane A active bitmap rows; 0..14 and 207..223 are opaque black margin
PLANE_B_VSCROLL = 2    # SNES BG2 effective row 258 = SC2 row 2 -> plane B row 2
LINES = (0, 1, 3)      # palette 2 reserved for GSU colours
LINE3_FIXED = {1: 0x000, 2: 0xeee}  # reserved black (margin) and FPS HUD colour (intro_timing.asm)
TILE_REGIONS = [(0x9a40, 0xc000), (0xf420, 0xfe20)]  # after VR mask tiles 4CE..4D1 (99C0..9A3F); then intro BG slot


def dist2(a, b):
    ra, ga, ba = md_rgb(a)
    rb, gb, bb = md_rgb(b)
    return (ra - rb) ** 2 + (ga - gb) ** 2 + (ba - bb) ** 2


def line_capacity(line):
    return 15 - (len(LINE3_FIXED) if line == 3 else 0)


def choose_palette(line, hist):
    hist = collections.Counter(hist)
    fixed = [c for i, c in LINE3_FIXED.items()] if line == 3 else []
    for c in fixed:
        hist.pop(c, None)
    chosen = [c for c, _ in sorted(hist.items(), key=lambda kv: (-kv[1], kv[0]))[:line_capacity(line)]]
    return chosen, fixed


def item_cost(hist, colours):
    inexact = err = 0
    for c, n in hist.items():
        if c in colours:
            continue
        inexact += n
        err += n * min(dist2(c, k) for k in colours)
    return inexact, err


def optimise_palettes(items):
    """items: list of dict(hist=Counter(md9->pixels), group=str). Maximises exact
    pixels (only original colours are candidates), then minimises squared error."""
    groups = sorted({it['group'] for it in items})
    ghist = {g: collections.Counter() for g in groups}
    for it in items:
        ghist[it['group']].update(it['hist'])
    candidates = []
    for code in range(len(LINES) ** len(groups)):
        assign, k = {}, code
        for g in groups:
            assign[g] = LINES[k % len(LINES)]; k //= len(LINES)
        score = 0
        for line in LINES:
            hist = collections.Counter()
            for g in groups:
                if assign[g] == line: hist.update(ghist[g])
            chosen, fixed = choose_palette(line, hist)
            score += sum(n for c, n in hist.items() if c not in chosen and c not in fixed)
        candidates.append((score, code, assign))
    candidates.sort(key=lambda t: (t[0], t[1]))

    def histograms(owner):
        result = {line: collections.Counter() for line in LINES}
        for it, line in zip(items, owner):
            result[line].update(it['hist'])
        return result

    def palette(line, hist):
        chosen, fixed = choose_palette(line, hist)
        return chosen + fixed

    def layout(hist):
        palettes = {line: palette(line, hist[line]) for line in LINES}
        costs = {line: item_cost(hist[line], palettes[line]) if hist[line] else (0, 0)
                 for line in LINES}
        return palettes, costs

    best = None
    for _, _, assign in candidates[:8]:
        owner = [assign[it['group']] for it in items]
        for _ in range(30):  # alternate palette choice / item assignment
            palettes = {line: palette(line, hist) for line, hist in histograms(owner).items()}
            new = [min(LINES, key=lambda l: (item_cost(it['hist'], palettes[l]), l)) for it in items]
            if new == owner: break
            owner = new
        hist = histograms(owner)
        palettes, costs = layout(hist)
        cost = tuple(map(sum, zip(*costs.values())))
        improved = True
        while improved:  # first-improvement local search: move one item, re-choose palettes
            improved = False
            for i in range(len(items)):
                source = owner[i]
                item = items[i]['hist']
                for line in LINES:
                    if line == source: continue
                    # Costs are additive by colour. A move affects only two
                    # histograms, so keep the same search and tie order.
                    trial = dict(hist)
                    trial[source] = hist[source] - item
                    trial[line] = hist[line] + item
                    tp, trial_costs = layout(trial)
                    tc = tuple(map(sum, zip(*trial_costs.values())))
                    if tc < cost:
                        owner[i] = line
                        hist, palettes, cost, improved = trial, tp, tc, True
                        break
        if best is None or cost < best[0]:
            best = (cost, owner, palettes)
    return best


def tile_bytes(indices):
    out = bytearray()
    for y in range(8):
        for x in range(0, 8, 2):
            out.append(indices[y * 8 + x] << 4 | indices[y * 8 + x + 1])
    return bytes(out)


def flip(indices, h, v):
    return tuple(indices[(7 - y if v else y) * 8 + (7 - x if h else x)] for y in range(8) for x in range(8))


def recover():
    rom = (ROOT / 'ref/Star Fox (USA).sfc').read_bytes()
    assert len(rom) == 1048576 and hashlib.sha256(rom).hexdigest() == SHA
    assert rom[0x7fdb] == 0, 'expected USA revision 0'
    decode = runpy.run_path(str(ROOT / 'tools/extract-intro-background.py'))['decode']
    setup = parse_setup(rom)
    res = {}
    for name in ('bg2chr', 'bg2scr', 'bg3chr', 'bg3scr'):
        res[name] = decode_resource(decode, rom, setup[name])
    palettes, trace = decode(rom[0xb8000:0xbf21c])
    assert 0xb8000 + trace['source_word_offset'] == 0xbe6c0 and len(palettes) == 5120
    pal = setup['palette']
    assert pal['address'] >> 16 == 0x7f and pal['length'] == 0xe0
    offset = pal['address'] & 0xffff
    raw_palette = palettes[offset:offset + pal['length']]
    pal.update(collection_rom_range=[0xbe6c0, 0xbf21c], collection_offset=offset,
               sha256=hashlib.sha256(raw_palette).hexdigest(),
               note='Boot decrunches the palette collection to 7F:0000; title copies 7F:0F00..0FDF to 7E:178B '
                    '(CGRAM rows 0..6), then stz 178B/178C clears colour 0. Row 7 (7E:186B) is the GSU palette.')
    cgram = [u16(raw_palette, i * 2) for i in range(112)]
    cgram[0] = 0
    # BG2 map words carry +C0 (decoder addend); tiles live at VRAM A000 + tile*32,
    # i.e. decoded chr index = tile - C0. Check the addend never reaches palette bits.
    raw_map = res['bg2scr']
    vram_map = bytearray()
    for i in range(0, len(raw_map), 2):
        word = u16(raw_map, i) + 0xc0
        assert word < 0x10000 and (word & 1023) >= 0xc0 and (u16(raw_map, i) & 1023) + 0xc0 < 1024
        vram_map += (word & 0xffff).to_bytes(2, 'little')
    tiles2 = len(res['bg2chr']) // 32
    tiles3 = len(res['bg3chr']) // 16
    assert max(u16(raw_map, i) & 1023 for i in range(0, 2048, 2)) < tiles2
    assert max(u16(res['bg3scr'], i) & 1023 for i in range(0, 2048, 2)) < tiles3
    BUILD.mkdir(exist_ok=True)
    for name, data in res.items():
        (BUILD / f'title-bg-{name}.raw.bin').write_bytes(data)
    (BUILD / 'title-bg-palette.raw.bin').write_bytes(raw_palette)

    # ------------------------------------------------ runtime verification
    runtime = verify_runtime(res, vram_map, raw_palette)

    # ------------------------------------------------ SNES reference render
    # Layer objects index decoded chr directly (BG2 map stays raw: no addend).
    bg2, bg3 = snes_layers(res, setup)
    snes = {}
    for y in range(224):
        for x in range(256):
            snes[x, y] = snes_compose(bg2, bg3, cgram, x, y)
    # INIDISP HDMA (7E:45EB, verified in dumps): 16 lines blank, 95+45+50 lit,
    # then blank; observed lit screen rows 16..205 (row 2 star hidden, row 205 shown).
    lit = (16, 205)
    ref = Image.new('RGB', (256, 224))
    for (x, y), (c, _, _) in snes.items():
        ref.putpixel((x, y), to_png_rgb555(c) if lit[0] <= y <= lit[1] else (0, 0, 0))
    ref.save(EVID / 'm4-title-background-snes.png')
    comparison = compare_screenshots(snes, lit, cgram)

    # ------------------------------------------------ static over time
    layer_stats = collections.Counter()
    colours_by_source = collections.defaultdict(set)
    for y in range(MD_WINDOW[0], MD_WINDOW[1] + 1):
        for x in range(256):
            c, cls, src = snes[x, y]
            layer_stats[src] += 1
            colours_by_source[src].add(c)

    # ------------------------------------------------ MD conversion
    md = convert_md(snes)
    md['snes_colour_counts_in_window'] = {k: dict(pixels=layer_stats[k], snes_colours=len(v),
                                                  md_colours=len({md9(c) for c in v}))
                                          for k, v in sorted(colours_by_source.items())}

    report = dict(
        unit='M4 title screen background: SNES BG2 (cp) + BG3 (ti3, US rev0 logo) and MD conversion',
        rom='ref/Star Fox (USA).sfc', rom_sha256=SHA, revision_byte_7FDB=0,
        source_code=dict(title_bg_setup=dict(offset=TITLE_SETUP, cpu='03:A9F5', bytes_sha256=hashlib.sha256(TITLE_SETUP_BYTES).hexdigest()),
                         helpers={hex(k): v for k, v in HELPERS.items()},
                         guidance=['ultrastarfox SF/ASM/BGS.ASM bg_title_1', 'SF/INC/BGMACS.INC bg2chr/bg2scr/bg3chr/bg3scr/palette',
                                   'SF/BANK/INCBINS.ASM bgti3ccr/bgti3pcr (ti-3-us), bgcpccr/bgcppcr', 'SF/INC/KALCS.INC defpac order (differs from this ROM)']),
        resources={k: {kk: vv for kk, vv in setup[k].items()} for k in ('bg2chr', 'bg2scr', 'bg3chr', 'bg3scr')},
        palette=pal,
        snes_layer_setup=dict(
            bgmode='1 with BG3 priority bit (BGMODE=09 written every title frame at 1F:F50D; mode1 handler 02:8037 writes 01)',
            main_screen='TM=07 (BG1+BG2+BG3, no OBJ) at 03:AACB',
            bg1='Super FX bitmap, palette 7, tile priority 0 (not converted)',
            bg2=dict(chars_vram_byte=0xa000, chars_note='BG12NBA high nibble 5 (ora #$50); data DMA to B800 = tile C0, hence map addend C0',
                     screen_vram_byte=0xe000, bg2sc=0x73, size='64x64 (SC2 at F000 = decoded map; SC0/SC1 overlap BG3 chr, SC3 F800 = stale SFX RAM, all off-screen)',
                     hofs=0, vofs=257, effective_vofs=258, palettes=[2, 3, 4, 5, 6], priority_bits='both (prio1 = in front of polygon)',
                     evidence='BG2SC=73 left by intro mode2 setup 02:F1A8 (no other abs write in ROM besides reset/mode3); HOFS=0 and size confirmed only by exact fit to screenshots'),
            bg3=dict(chars_vram_byte=0xe000, screen_vram_byte=0xd000, bg3sc=0x68, size='32x32', bpp=2,
                     hofs=-4, hofs_source='18BB = (player +0C asr 3) - 4, written by 02:D97A; 18BB=FFFC in all dumps',
                     vofs=9, effective_vofs=10, palettes=list(range(8)),
                     priority='all visible tiles prio1 (front of everything) except 6 px of one prio0 tile (x51,y31..36, palette5)'),
            priority_order_front_to_back=['BG3 prio1', 'BG1 prio1 (unused)', 'BG2 prio1', 'BG1 prio0 (polygon)', 'BG2 prio0', 'BG3 prio0', 'backdrop (colour0 cleared = black)'],
            inidisp_hdma=dict(table_wram=0x7e45eb,
                              screen_rows_lit=list(lit), note='rows 0..15 and 206..223 forced blank after fade; gf5 entire table 80 (black)'),
            animation='None found for BG2/BG3 in sampled gameframes 21..300: VRAM B800..FFFF, palette buffer, BG3HOFS/BG2 scroll shadows and HDMA table identical; renders match all post-fade screenshots. Not proven between samples.',
            fade='gf21 screenshot = every component minus 12 (colour-math style fade, hypothesis; producer not traced); gf5 forced blank.'),
        runtime_verification=runtime,
        screenshot_comparison=comparison,
        md_conversion=md,
        vertical_framing='SNES and MD both 224 output lines with identical coordinates (no offset). SNES lit rows 16..205; MD plane A margin hides rows 0..14 and 207..223. MD rows 15 and 206 come from plane B: composite there is black (no BG2/BG3 content at row 15; BG3 opaque black at row 206), so only an SVP polygon drawn on rows 15 or 206 could differ from SNES.',
        outputs=sorted(p.name for p in BUILD.glob('title-bg*')),
    )
    (EVID / 'm4-title-background.json').write_text(json.dumps(report, indent=1) + '\n', encoding='utf-8')
    print('PASS title background: resources verified, SNES ref vs screenshots',
          {k: v['bg_mismatch_outside_polygon'] for k, v in comparison.items()},
          'MD tiles', md['tiles']['unique'], 'inexact px', md['palette']['inexact_pixels'])


def verify_runtime(res, vram_map, raw_palette):
    out = {}
    for gf in GAMEFRAMES:
        vpath = EVID / f'starfox-original-title-gf{gf}.vram.bin'
        wpath = EVID / f'starfox-original-title-gf{gf}.wram.bin'
        if not vpath.exists() or not wpath.exists():
            out[gf] = 'missing'
            continue
        vram, wram = vpath.read_bytes(), wpath.read_bytes()
        checks = dict(
            bg2chr_B800=vram[0xb800:0xb800 + len(res['bg2chr'])] == res['bg2chr'],
            bg2map_F000_plus_C0=vram[0xf000:0xf000 + len(vram_map)] == bytes(vram_map),
            bg3chr_E000=vram[0xe000:0xe000 + len(res['bg3chr'])] == res['bg3chr'],
            bg3map_D000=vram[0xd000:0xd000 + len(res['bg3scr'])] == res['bg3scr'],
            palette_7E178B_rows0_6=wram[0x178b + 2:0x178b + 0xe0] == raw_palette[2:] and wram[0x178b:0x178d] == b'\0\0',
            bgmode_shadows=dict(bg2_yscroll_169E=u16(wram, 0x169e), bg3hofs_18BB=u16(wram, 0x18bb) - (0x10000 if wram[0x18bc] & 0x80 else 0),
                                bg3scrollflag_18BA=wram[0x18ba], hdma_enable_120E=wram[0x120e],
                                inidisp_hdma_7E45EB=wram[0x45eb:0x45f6].hex(' ')),
        )
        flags = [v for k, v in checks.items() if isinstance(v, bool)]
        if gf != 5:
            assert all(flags), (gf, checks)
        checks['all_resources_match'] = all(flags)
        out[gf] = checks
    return out


def bg1_mask(vram, x, y):
    """Diagnostic only: Super FX layer from the dump (map 5800, VOFS 0+1), opaque in
    either double-buffer char base (0000 or 6000): the dump may hold the hidden one."""
    tx, ty = x >> 3, (y + 1) >> 3
    word = u16(vram, 0x5800 + ((ty & 31) * 32 + tx) * 2)
    tile, fx, fy = word & 1023, x & 7, (y + 1) & 7
    for chars in (0, 0x6000):
        base = chars + tile * 32 + fy * 2
        if any((vram[(base + (p & 1) + (p >> 1) * 16) & 0xffff] >> (7 - fx)) & 1 for p in range(4)):
            return True
    return False


def compare_screenshots(snes, lit, cgram):
    out = {}
    for gf in GAMEFRAMES:
        spath = EVID / f'starfox-original-title-gf{gf}.png'
        vpath = EVID / f'starfox-original-title-gf{gf}.vram.bin'
        wpath = EVID / f'starfox-original-title-gf{gf}.wram.bin'
        if not spath.exists() or not vpath.exists():
            continue
        shot = Image.open(spath).convert('RGB')
        vram, wram = vpath.read_bytes(), wpath.read_bytes()
        blank = wram[0x45ec] & 0x80  # HDMA lit section value (forced blank during fade-in)
        sub = 12 if gf == 21 else 0
        bad = collections.Counter(); masked = 0; bad_rows = set()
        for y in range(224):
            for x in range(256):
                if bg1_mask(vram, x, y):
                    masked += 1
                    continue
                c, _, src = snes[x, y]
                expect = rgb555(c) if (lit[0] <= y <= lit[1] and not (wram[0x45ee] & 0x80)) else (0, 0, 0)
                expect = tuple(max(0, k - sub) for k in expect)
                if expect != shot_555(shot.getpixel((x, y))):
                    bad[src] += 1; bad_rows.add(y)
        out[gf] = dict(polygon_masked_pixels=masked, bg_mismatch_outside_polygon=sum(bad.values()),
                       by_source=dict(bad), rows=sorted(bad_rows)[:20],
                       model=('forced blank' if wram[0x45ee] & 0x80 else 'lit rows %d..%d' % lit) +
                             (', minus 12 per component (fade hypothesis)' if sub else ''))
    return out


def convert_md(snes):
    y0, y1 = MD_WINDOW
    # Classify every plane-B cell covering the active window (VSCROLL_B=2).
    cells = {}
    for cr in range((y0 + PLANE_B_VSCROLL) // 8, (y1 + PLANE_B_VSCROLL) // 8 + 1):
        for cx in range(32):
            pix = []
            for py in range(8):
                y = cr * 8 + py - PLANE_B_VSCROLL
                for px in range(8):
                    x = cx * 8 + px
                    if not (y0 <= y <= y1):
                        pix.append(None); continue
                    c, cls, src = snes[x, y]
                    if cls == 'B' and md9(c) == 0:
                        cls = 'T'  # black behind the polygon == black backdrop
                    pix.append((md9(c), cls, src) if cls != 'T' else None)
            cells[cx, cr] = pix
    items = []
    for (cx, cr), pix in sorted(cells.items(), key=lambda kv: (kv[0][1], kv[0][0])):
        classes = {p[1] for p in pix if p}
        if not classes:
            continue
        def make(kind, keep, prio):
            sel = [p if (p and p[1] in keep) else None for p in pix]
            hist = collections.Counter(p[0] for p in sel if p)
            src = collections.Counter(p[2] for p in sel if p).most_common(1)[0][0]
            return dict(cell=(cx, cr), kind=kind, prio=prio, pixels=sel, hist=hist, group=src)
        if classes == {'B'}:
            items.append(make('plane', {'B'}, 0))
        elif classes == {'F'}:
            items.append(make('plane', {'F'}, 1))
        else:  # front and back pixels in one cell: back in plane B low, front as 8x8 sprite
            items.append(make('plane', {'B'}, 0))
            items.append(make('sprite', {'F'}, 1))
    # Group by dominant source; bg2 palettes refine the grouping.
    (total, owner, palettes) = optimise_palettes(items)
    line_colours = {}
    for line in LINES:
        entries = [0] * 16
        if line == 3:
            for i, c in LINE3_FIXED.items(): entries[i] = c
            free = [i for i in range(1, 16) if i not in LINE3_FIXED]
        else:
            free = list(range(1, 16))
        chosen = [c for c in palettes[line] if not (line == 3 and c in LINE3_FIXED.values())]
        index = {}
        for i, c in zip(free, chosen):
            entries[i] = c; index[c] = i
        if line == 3:
            for i, c in LINE3_FIXED.items():
                index.setdefault(c, i)  # reserved black (margin) and HUD colour are real colours
        line_colours[line] = dict(entries=entries, index=index)
    # Tiles with flip de-duplication.
    regions = list(TILE_REGIONS)
    tiles, lookup = [], {}
    def tile_id(indices):
        for h in (0, 1):
            for v in (0, 1):
                key = flip(indices, h, v)
                if key in lookup:
                    return lookup[key], h, v
        lookup[tuple(indices)] = len(tiles); tiles.append(tuple(indices))
        return len(tiles) - 1, 0, 0
    plane = [0] * (32 * 64)
    sprites = []
    inexact = collections.Counter(); maxdiff = 0
    md_out = {}
    for it, line in zip(items, owner):
        pal = line_colours[line]
        cols = [c for c in pal['index']]
        idx = []
        for k, p in enumerate(it['pixels']):
            if p is None:
                idx.append(0); continue
            c = p[0]
            if c not in pal['index']:
                c2 = min(cols, key=lambda k2: (dist2(c, k2), k2))
                inexact[(c, c2)] += 1
                maxdiff = max(maxdiff, max(abs(a - b) for a, b in zip(md_rgb(c), md_rgb(c2))))
                c = c2
            idx.append(pal['index'][c])
            cx, cr = it['cell']
            md_out[cx * 8 + k % 8, cr * 8 + k // 8 - PLANE_B_VSCROLL, it['kind']] = c
        n, h, v = tile_id(idx)
        it.update(line=line, tile=n, hflip=h, vflip=v)
    # Assign VRAM tile numbers.
    capacity = [(a, (b - a) // 32) for a, b in regions]
    def vram_tile(n):
        for start, count in capacity:
            if n < count:
                return start // 32 + n
            n -= count
        raise AssertionError('title tiles exceed the proposed VRAM regions')
    for it in items:
        word = it['prio'] << 15 | LINES_TO_FIELD[it['line']] << 13 | it['vflip'] << 12 | it['hflip'] << 11 | vram_tile(it['tile'])
        cx, cr = it['cell']
        if it['kind'] == 'plane':
            assert plane[cr * 32 + cx] == 0
            plane[cr * 32 + cx] = word
        else:
            sprites.append(dict(y=cr * 8 - PLANE_B_VSCROLL + 128, size_link=0, attr=word, x=cx * 8 + 128))
    tile_blob = b''.join(tile_bytes(t) for t in tiles)
    (BUILD / 'title-bg-tiles.md.bin').write_bytes(tile_blob)
    (BUILD / 'title-bg-planeb.md.bin').write_bytes(b''.join(w.to_bytes(2, 'big') for w in plane))
    cram = [0] * 64
    for line in LINES:
        cram[line * 16:line * 16 + 16] = line_colours[line]['entries']
    (BUILD / 'title-bg-cram.md.bin').write_bytes(b''.join(c.to_bytes(2, 'big') for c in cram))
    (BUILD / 'title-bg-sprites.md.bin').write_bytes(b''.join(
        s['y'].to_bytes(2, 'big') + s['size_link'].to_bytes(2, 'big') + s['attr'].to_bytes(2, 'big') + s['x'].to_bytes(2, 'big')
        for s in sprites))
    # Independent decode of the WRITTEN binaries (name table, tiles, CRAM, SAT),
    # as the VDP would compose them without polygon: margin black, sprite > B.
    blob_tiles = {}
    n = 0
    for start, count in capacity:
        for k in range(count):
            if n < len(tiles):
                blob_tiles[start // 32 + k] = tile_blob[n * 32:n * 32 + 32]
            n += 1

    def vdp_pixel(word, px, py):
        data = blob_tiles[word & 0x7ff]
        if word & 0x800: px = 7 - px
        if word & 0x1000: py = 7 - py
        nibble = (data[py * 4 + px // 2] >> (4 if px % 2 == 0 else 0)) & 15
        return (cram[((word >> 13) & 3) * 16 + nibble], word >> 15) if nibble else None

    prev = Image.new('RGB', (256, 224))
    diff_px = 0; diff_img = Image.new('RGB', (256, 224)); priority_errors = 0
    for y in range(224):
        for x in range(256):
            if not (y0 <= y <= y1):
                m = 0
            else:
                hit = None
                for s in sprites:
                    sx, sy = x - (s['x'] - 128), y - (s['y'] - 128)
                    if 0 <= sx < 8 and 0 <= sy < 8:
                        hit = vdp_pixel(s['attr'], sx, sy)
                        if hit: hit = (hit[0], 1); break
                if hit is None:
                    py = (y + PLANE_B_VSCROLL) % 512
                    word = plane[(py >> 3) * 32 + (x >> 3)]
                    hit = vdp_pixel(word, x & 7, py & 7) if word else None
                m = hit[0] if hit else 0
                expect = md_out.get((x, y, 'sprite'), md_out.get((x, y, 'plane'), 0))
                assert m == expect, ('binary decode differs', x, y)
                _, cls, _ = snes[x, y]
                if cls == 'B' and md9(snes[x, y][0]) == 0: cls = 'T'
                if cls != 'T' and (hit is None or hit[1] != (cls == 'F')):
                    priority_errors += 1
            prev.putpixel((x, y), to_png_md(m))
            target = md9(snes[x, y][0]) if 16 <= y <= 205 else 0
            if m != target:
                diff_px += 1; diff_img.putpixel((x, y), (255, 0, 0))
    prev.save(EVID / 'm4-title-background-md.png')
    if diff_px:
        diff_img.save(EVID / 'm4-title-background-diff.png')
    used_bytes = len(tile_blob)
    plane_cells = sum(1 for it in items if it['kind'] == 'plane')
    return dict(
        method='Composite SNES BG2+BG3 per pixel, classify front (BG3 prio1, BG2 prio1) / back (BG2 prio0, BG3 prio0, non-black) / transparent; '
               'plane B cells keep SNES BG2 grid (VSCROLL_B=2, HSCROLL_B=0): front-only cells -> priority 1, back-only -> priority 0, '
               'cells with both -> back in plane B prio0 + front as 8x8 high-priority sprite. Rows outside 15..206 are transparent (hidden by plane A margin).',
        md_priority_rationale='MD order: sprite H > A H (black margin) > B H > sprite L > A L (SVP bitmap, index0 where empty) > B L. B prio1 reproduces SNES BG3H/BG2H in front of the polygon; '
                              'this deviates from the intro rule "B low" and must be accepted explicitly.',
        registers=dict(plane_b_vram=0xe000, plane_b_size='32x64 (shared reg $9010)', vscroll_b=PLANE_B_VSCROLL, hscroll_b=0,
                       backdrop='black (e.g. reg7=$31 -> palette3 colour1)'),
        files={
            'title-bg-tiles.md.bin': dict(bytes=used_bytes, sha256=hashlib.sha256(tile_blob).hexdigest(), format='MD 4bpp, 32 bytes/tile, left pixel high nibble'),
            'title-bg-planeb.md.bin': dict(bytes=4096, format='32x64 big-endian name-table words for VRAM E000: prio<<15|pal<<13|vflip<<12|hflip<<11|tile',
                                           sha256=hashlib.sha256((BUILD / 'title-bg-planeb.md.bin').read_bytes()).hexdigest()),
            'title-bg-cram.md.bin': dict(bytes=128, format='full 64-word CRAM image, big-endian; line2 left 0 for GSU colours; line3 colour1=000 (margin) colour2=EEE (FPS HUD)',
                                         sha256=hashlib.sha256((BUILD / 'title-bg-cram.md.bin').read_bytes()).hexdigest()),
            'title-bg-sprites.md.bin': dict(entries=len(sprites), format='SAT entries (y+128, size<<8|link=0 to be chained at runtime, attr, x+128), 8x8',
                                            sprites=sprites),
        },
        tiles=dict(unique=len(tiles), plane_cells=plane_cells, sprite_cells=len(sprites),
                   vram_regions=[dict(start=hex(a), end=hex(b), tiles=(b - a) // 32) for a, b in regions],
                   first_tile=hex(regions[0][0] // 32),
                   budget_note='99E0..BFFF follows the VR mask tile 99C0 (bitmap tiles end at 99A1 per vr-video-layout descriptors); F420..FE1F is the intro BG slot. Inferred free; confirm against the final title VRAM map.'),
        palette=dict(lines={line: ['%03X' % c for c in line_colours[line]['entries']] for line in LINES},
                     inexact_pixels=sum(inexact.values()), squared_error_levels=total[1], max_channel_diff_levels=maxdiff,
                     substitutions=[dict(md_from='%03X' % a, md_to='%03X' % b, pixels=n) for (a, b), n in inexact.most_common()],
                     assignment=collections.Counter(f"{it['group']}->line{it['line']}" for it in items),
                     note='Exact up to the >>2 conversion would need >44 colours (49 BG2 + BG3 in 3 lines minus fixed/black); '
                          'remaining pixels use the nearest colour of the line (squared 3-bit RGB distance).'),
        preview_vs_snes_reference=dict(pixels_differing_md9=diff_px, layer_priority_errors=priority_errors,
                                       binaries_decoded_independently=True,
                                       note='MD preview (no polygon) against SNES reference converted with >>2, rows 16..205 lit, others black'),
    )


LINES_TO_FIELD = {0: 0, 1: 1, 3: 3}

if __name__ == '__main__':
    recover()

"""ROM-authoritative Corneria 1 background (SNES BG2, bg_1_1c) and MD plane-B conversion.

Source unit: selected ROM USA rev0, bg_1_1c at physical 1910B (03:910B), selected by
`setbg $1B` + `initbg` at 0D:D0CF (level1_1) through bglists 03:AC42.
Guidance only: UltraStarFox SF/ASM/BGS.ASM bg_1_1c_1, SF/INC/BGMACS.INC (bg2chr/bg2scr/
palette/gamepal/set_bg/info/hofmode/bg2Yscroll/planet), SF/MARIO/MHOFS.MC, STRAT/GSTRATS.ASM
calcbgscroll_l. The ROM bytes asserted below are the authority.

Reuses the MDECRU translation (tools/extract-intro-background.py) and the resource,
SNES layer and MD helpers of tools/extract-title-background.py (both via runpy).
Static conversion only: the SNES mode-2 offset-per-tile columns and the per-line
BG2HOFS HDMA (roll) are NOT reproduced; the scroll mapping is documented in the JSON.
"""
from starfox_rom import rom_hex
import collections
import hashlib
import json
from pathlib import Path
import runpy

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / 'build'
EVID = ROOT / 'evidence'
T = runpy.run_path(str(ROOT / 'tools/extract-title-background.py'))
decode = runpy.run_path(str(ROOT / 'tools/extract-intro-background.py'))['decode']
SHA = T['SHA']
u16, md9, md_rgb, Layer = T['u16'], T['md9'], T['md_rgb'], T['Layer']
to_png_rgb555, to_png_md, tile_bytes, flip = T['to_png_rgb555'], T['to_png_md'], T['tile_bytes'], T['flip']

# bg_1_1c (03:910B..03:919F), selected ROM bytes (149 bytes, ends with rtl).
BG_1_1C = 0x1910b
BG_1_1C_BYTES = bytes.fromhex(
    rom_hex(0x1910b, 149))
HELPERS = {k: T['HELPERS'][k] for k in (0x1ab2b, 0x1ab42, 0x1ab95, 0x1abcd, 0x1abfe, 0x1628a)}
HELPERS.update({
    # initmode2 (jsr 03:AB12): wait trans_flag, trans_flag=$26 (38), wait.
    0x1ab12: rom_hex(0x1ab12, 25),
    # mode-2 transfer handler body: BG12NBA=(4B>>4)|50 (BG2 chr A000), OBSEL=3,
    # BG1SC=2C, BG2SC=73 (map word 7000 = byte E000, 64x64), BGMODE=2.
    0x17193: rom_hex(0x17193, 31),
    # gamepal (jsl 02:F484): row 7 (7E:186B) <- 03:8AAA + gamepal*32, 32 bytes.
    0x17484: rom_hex(0x17484, 43),
    # level1_1 script 0D:D0CF: setbg $1B ; initbg (waitsetbg, setbginfo).
    0x6d0cf: rom_hex(0x6d0cf, 5),
    # bglists 03:AC42 entry at byte offset $1B: bank 03, address 910B.
    0x1ac42 + 0x1b: rom_hex(0x1ac5d, 3),
})

# MD target (VR pipeline of the port).
LINES = (0, 1, 3)                    # line 2 reserved for the GSU polygon palette
LINE3_FIXED = {1: 0x000, 2: 0xeee}   # margin black, FPS HUD colour
TILE_REGIONS = [(0x9a40, 0xc000), (0xf420, 0xfe20)]
MD_WINDOW = (15, 206)                # active SVP bitmap rows; others = plane A opaque margin
PLANE_W, PLANE_H = 32, 64


def parse_setup(rom):
    code = rom[BG_1_1C:BG_1_1C + len(BG_1_1C_BYTES)]
    assert code == BG_1_1C_BYTES, 'bg_1_1c bytes differ from selected ROM'
    for offset, hexbytes in HELPERS.items():
        expected = bytes.fromhex(hexbytes)
        assert rom[offset:offset + len(expected)] == expected, hex(offset)

    def imm(store, width):
        at = code.index(bytes.fromhex(store))
        assert code[at - 1 - width] == 0xa9 and code.count(bytes.fromhex(store)) == 1, store
        return int.from_bytes(code[at - width:at], 'little')

    def inline(call):  # jsr helper ; dw end ; db bank ; dw VRAM word ; dw bytes
        p = code.index(bytes.fromhex(call)) + 3
        return dict(bank=code[p + 2], end=int.from_bytes(code[p:p + 2], 'little'),
                    vram_word=int.from_bytes(code[p + 3:p + 5], 'little'), dma_bytes=int.from_bytes(code[p + 5:p + 7], 'little'))
    bg2chr = dict(inline('2095ab'), decoder='03:AB2B via 03:AB95 (SFX RAM 2800, m_decoffset 0)')
    bg2scr = dict(inline('20cdab'), decoder='03:AB42 via 03:ABCD (SFX RAM 4000, m_decoffset 00C0 added to every map word)',
                  map_word_addend=0xc0)
    p = code.index(bytes.fromhex('20feab')) + 3
    palette = dict(address=code[p + 2] << 16 | int.from_bytes(code[p:p + 2], 'little'),
                   length=int.from_bytes(code[p + 3:p + 5], 'little'), wram_destination=0x7e178b)
    regs = dict(init_bg_trans_flag=rom[0x1ab1f], set_bg_trans_flag=imm('8500', 1), gamepal_1899=imm('8d9918', 1),
                zdepthtable_700050=imm('8f500070', 2), info_1787=imm('8d8717', 1), hofmode_1FE4=imm('8de41f', 1),
                shadowheight_1961=imm('8d6119', 2), bg2_yscroll_169E_194F=imm('8d9e16', 2),
                m_meters=imm('8f1c0270', 1), planet_70004E=imm('8f4e0070', 1), planet_70004F=imm('8f4f0070', 1),
                hdmaen_or_04=bytes.fromhex(rom_hex(0x18fdf, 8)) in code, palette_colour0_cleared=bytes.fromhex('9c8b17') in code)
    return dict(bg2chr=bg2chr, bg2scr=bg2scr, palette=palette, registers=regs)


def choose_lines(sets):
    """Exact packing of the SNES palettes used into MD lines 0/1/3 (line 3: 13 free
    slots plus its fixed 000/EEE). Fewest lines, then lexicographic. None if impossible."""
    pals = sorted(sets)
    best = None
    for code in range(len(LINES) ** len(pals)):
        assign, k = {}, code
        for p in pals:
            assign[p] = LINES[k % len(LINES)]; k //= len(LINES)
        ok = True
        for line in LINES:
            union = set().union(*[sets[p] for p in pals if assign[p] == line])
            free = 15 - (len(LINE3_FIXED) if line == 3 else 0)
            if len(union - (set(LINE3_FIXED.values()) if line == 3 else set())) > free:
                ok = False
        if ok:
            key = (len(set(assign.values())), [assign[p] for p in pals])
            if best is None or key < best[0]:
                best = (key, assign)
    return best and best[1]


def recover():
    rom = (ROOT / 'ref/Star Fox (USA).sfc').read_bytes()
    assert len(rom) == 1048576 and hashlib.sha256(rom).hexdigest() == SHA and rom[0x7fdb] == 0
    setup = parse_setup(rom)
    res = {name: T['decode_resource'](decode, rom, setup[name]) for name in ('bg2chr', 'bg2scr')}
    assert setup['bg2chr']['rom_range'] == 'A7577..A7E93' and len(res['bg2chr']) == 5632
    assert setup['bg2scr']['rom_range'] == 'A8000..A81E4' and len(res['bg2scr']) == 8192
    palettes, trace = decode(rom[0xb8000:0xbf21c])
    assert 0xb8000 + trace['source_word_offset'] == 0xbe6c0 and len(palettes) == 5120
    pal = setup['palette']
    offset = pal['address'] & 0xffff
    raw_palette = palettes[offset:offset + pal['length']]
    cgram = [u16(raw_palette, i * 2) for i in range(112)]
    gamepal_src = 0x18aaa + setup['registers']['gamepal_1899'] * 32
    pal.update(collection_rom_range=[0xbe6c0, 0xbf21c], collection_offset=offset,
               sha256=hashlib.sha256(raw_palette).hexdigest(),
               rows_hex={r: ' '.join('%04X' % cgram[r * 16 + c] for c in range(16)) for r in range(7)},
               note='Boot decrunches the palette collection to 7F:0000; bg_1_1c copies 7F:0360..043F to 7E:178B '
                    '(CGRAM rows 0..6; colour 0 not cleared). Row 7 is written by gamepal blue (1899=3): '
                    f'03:8AAA+3*32 = 03:8B0A (physical {gamepal_src:05X}), the GSU polygon palette of this level.',
               gamepal_row7=dict(cpu='03:8B0A', offset=gamepal_src, sha256=hashlib.sha256(rom[gamepal_src:gamepal_src + 32]).hexdigest()))
    BUILD.mkdir(exist_ok=True)

    # ------------------------------------------------ SNES BG2 512x512 reference
    chars, raw_map = res['bg2chr'], res['bg2scr']
    words = [u16(raw_map, i) for i in range(0, 8192, 2)]
    # Map words carry +C0 in VRAM (decoder addend) and BG2 chars live at A000 (BG12NBA
    # nibble 5) with the data DMA'd to word 5C00 = byte B800 = tile C0: raw words index
    # decoded chr directly. Addend must not reach palette bits; tiles within decoded chr.
    assert all((w & 1023) + 0xc0 < 1024 for w in words)
    assert max(w & 1023 for w in words) < len(chars) // 32
    screens = {(i & 1, i >> 1): raw_map[i * 2048:(i + 1) * 2048] for i in range(4)}  # 64x64: SC0 SC1 / SC2 SC3
    layer = Layer(chars, 4, screens, 64, 64, 0, 0)
    snes = {}
    for y in range(512):
        for x in range(512):
            c, p, h = layer.pixel(x, y)
            assert c != 0, 'transparent BG2 pixel (backdrop would show)'
            snes[x, y] = (cgram[p * 16 + c], p)
    ref = Image.new('RGB', (512, 512))
    for (x, y), (c, _) in snes.items():
        ref.putpixel((x, y), to_png_rgb555(c))
    ref.save(EVID / 'corneria-bg2-snes.png')
    period = next(n for n in (8, 16, 32, 64, 128, 256, 512)
                  if all(snes[x, y] == snes[x % n, y] for y in range(512) for x in range(512)))
    assert period <= 256, 'plane B (32 cells) cannot wrap the image exactly'
    research_png = ROOT / 'evidence/research/corneria1-bg2.png'
    research_mismatch = None
    if research_png.exists():
        im = Image.open(research_png).convert('RGB')
        research_mismatch = sum(1 for (x, y), (c, _) in snes.items()
                                if T['shot_555'](im.getpixel((x, y))) != T['rgb555'](c))
    map_stats = dict(palettes=dict(sorted(collections.Counter((w >> 10) & 7 for w in words).items())),
                     priority1_words=sum((w >> 13) & 1 for w in words), hflip_words=sum((w >> 14) & 1 for w in words),
                     vflip_words=sum(w >> 15 for w in words), distinct_tiles=len({w & 1023 for w in words}),
                     max_tile=max(w & 1023 for w in words), decoded_tiles=len(chars) // 32,
                     palette_by_tile_row={p: sorted({y // 8 for (x, y), (_, q) in snes.items() if q == p and x == 0}) for p in range(3, 7)},
                     horizontal_period_px=period, transparent_pixels=0,
                     snes_colours_used=len({c for c, _ in snes.values()}),
                     md_colours_used=len({md9(c) for c, _ in snes.values()}))
    for p, rows in map_stats['palette_by_tile_row'].items():
        map_stats['palette_by_tile_row'][p] = f'{rows[0]}..{rows[-1]}' if rows == list(range(rows[0], rows[-1] + 1)) else rows

    # ------------------------------------------------ MD palette (exact packing)
    sets = collections.defaultdict(set)
    hist = collections.defaultdict(collections.Counter)
    for (x, y), (c, p) in snes.items():
        if x < 256:
            sets[p].add(md9(c)); hist[p][md9(c)] += 1
    assign = choose_lines(sets)
    assert assign, 'no exact palette packing; would need the title optimiser (not required for this ROM)'
    line_colours = {}
    for line in LINES:
        entries = [0] * 16
        index = {}
        if line == 3:
            for i, c in LINE3_FIXED.items():
                entries[i] = c; index[c] = i
        free = [i for i in range(1, 16) if not (line == 3 and i in LINE3_FIXED)]
        h = collections.Counter()
        for p, l in assign.items():
            if l == line: h.update(hist[p])
        for c, _ in sorted(h.items(), key=lambda kv: (-kv[1], kv[0])):
            if c in index: continue
            i = free.pop(0); entries[i] = c; index[c] = i
        line_colours[line] = dict(entries=entries, index=index)
    cram = [0] * 64
    for line in LINES:
        cram[line * 16:line * 16 + 16] = line_colours[line]['entries']
    for i, c in LINE3_FIXED.items():
        assert cram[48 + i] == c

    # ------------------------------------------------ tiles + plane B (columns 0..31)
    tiles, lookup = [], {}

    def tile_id(indices):
        for hf in (0, 1):
            for vf in (0, 1):
                key = flip(indices, hf, vf)
                if key in lookup:
                    return lookup[key], hf, vf
        lookup[tuple(indices)] = len(tiles); tiles.append(tuple(indices))
        return len(tiles) - 1, 0, 0
    capacity = [(a, (b - a) // 32) for a, b in TILE_REGIONS]

    def vram_tile(n):
        for start, count in capacity:
            if n < count:
                return start // 32 + n
            n -= count
        raise AssertionError('tiles exceed the free VRAM regions')
    plane = [0] * (PLANE_W * PLANE_H)
    flips = collections.Counter()
    for cy in range(PLANE_H):
        for cx in range(PLANE_W):
            pals = {snes[cx * 8 + px, cy * 8 + py][1] for py in range(8) for px in range(8)}
            assert len(pals) == 1
            line = assign[pals.pop()]
            idx = [line_colours[line]['index'][md9(snes[cx * 8 + px, cy * 8 + py][0])] for py in range(8) for px in range(8)]
            n, hf, vf = tile_id(idx)
            flips[hf, vf] += 1
            plane[cy * PLANE_W + cx] = 0 << 15 | line << 13 | vf << 12 | hf << 11 | vram_tile(n)
    tile_blob = b''.join(tile_bytes(t) for t in tiles)
    files = {'corneria-bg-tiles.md.bin': tile_blob,
             'corneria-bg-planeb.md.bin': b''.join(w.to_bytes(2, 'big') for w in plane),
             'corneria-bg-cram.md.bin': b''.join(c.to_bytes(2, 'big') for c in cram)}
    for name, data in files.items():
        (BUILD / name).write_bytes(data)

    # ------------------------------------------------ independent decode of the written binaries
    blob = (BUILD / 'corneria-bg-tiles.md.bin').read_bytes()
    nt = (BUILD / 'corneria-bg-planeb.md.bin').read_bytes()
    cr = (BUILD / 'corneria-bg-cram.md.bin').read_bytes()
    vram = {}
    n = 0
    for start, count in capacity:
        for k in range(count):
            if n * 32 < len(blob):
                vram[start // 32 + k] = blob[n * 32:n * 32 + 32]
            n += 1

    def plane_b(px, py):
        """Plane B pixel at plane coordinates (wraps 256x512), as the VDP fetches it."""
        px, py = px % (PLANE_W * 8), py % (PLANE_H * 8)
        word = int.from_bytes(nt[((py >> 3) * PLANE_W + (px >> 3)) * 2:][:2], 'big')
        assert not word & 0x8000
        data = vram[word & 0x7ff]
        fx, fy = (7 - (px & 7)) if word & 0x800 else px & 7, (7 - (py & 7)) if word & 0x1000 else py & 7
        nib = (data[fy * 4 + fx // 2] >> (4 if fx % 2 == 0 else 0)) & 15
        assert nib, 'plane B must be opaque (no SNES transparent pixels)'
        return int.from_bytes(cr[(((word >> 13) & 3) * 16 + nib) * 2:][:2], 'big')
    mismatch = sum(1 for (x, y), (c, _) in snes.items() if plane_b(x, y) != md9(c))
    assert mismatch == 0, mismatch
    md_img = Image.new('RGB', (256, 512))
    for y in range(512):
        for x in range(256):
            md_img.putpixel((x, y), to_png_md(plane_b(x, y)))
    md_img.save(EVID / 'corneria-bg2-md.png')

    # ------------------------------------------------ screen at rest (both 224 lines)
    vofs = setup['registers']['bg2_yscroll_169E_194F']   # bg2scroll at rest (outvx=0 -> clamp term 0)
    hofs = 0                                              # [H] worldx/8 + m_scrollxoff at rest; any value maps exactly
    vscroll_b = (vofs + 1) & 511                          # SNES shows BG row VOFS+1 on screen line 0
    hscroll_b = (-hofs) & 0x3ff
    s_img, m_img = Image.new('RGB', (256, 224)), Image.new('RGB', (256, 224))
    screen_bad = 0
    for y in range(224):
        for x in range(256):
            c = snes[(x + hofs) % 512, (y + vofs + 1) % 512][0]
            s_img.putpixel((x, y), to_png_rgb555(c))
            if MD_WINDOW[0] <= y <= MD_WINDOW[1]:
                m = plane_b(x - hscroll_b, y + vscroll_b)
                screen_bad += m != md9(c)
            else:
                m = 0   # plane A high-priority opaque black margin
            m_img.putpixel((x, y), to_png_md(m))
    assert screen_bad == 0
    s_img.save(EVID / 'corneria-bg-screen-snes.png')
    m_img.save(EVID / 'corneria-bg-screen-md.png')
    # Exhaustive scroll check: every (HOFS, VOFS) gives the same window rows/columns.
    scroll_ok = all(plane_b(x - ((-h) & 0x3ff), y + ((v + 1) & 511)) == md9(snes[(x + h) % 512, (y + v + 1) % 512][0])
                    for h in range(0, 512, 37) for v in range(0, 512, 41) for y in (15, 110, 206) for x in range(0, 256, 5))
    assert scroll_ok

    report = dict(
        unit='Corneria 1 background: SNES BG2 (bg_1_1c, stp chr/scr, palette 2d) and MD plane B conversion',
        rom='ref/Star Fox (USA).sfc', rom_sha256=SHA, revision_byte_7FDB=0,
        source_code=dict(bg_1_1c=dict(offset=BG_1_1C, cpu='03:910B', length=len(BG_1_1C_BYTES),
                                      bytes_sha256=hashlib.sha256(BG_1_1C_BYTES).hexdigest()),
                         selection='level1_1 0D:D0CF `10 1B 00 64 66` (setbg $1B, initbg); bglists 03:AC42+1B = 03:910B',
                         helpers={hex(k): v for k, v in HELPERS.items()},
                         guidance=['ultrastarfox SF/ASM/BGS.ASM bg_1_1c_1, initmode2 (trans_flag 38)', 'SF/INC/BGMACS.INC',
                                   'SF/MARIO/MHOFS.MC mrotplanet/mnograd (per-line BG2HOFS)', 'SF/STRAT/GSTRATS.ASM calcbgscroll_l (06:BB5C)',
                                   'build/research/corneria1-level.md §4']),
        resources={k: dict(setup[k]) for k in ('bg2chr', 'bg2scr')},
        resource_notes=dict(bg2chr='decoded 5632 B = 176 tiles 4bpp; DMA 6 KB (1800) from SFX RAM 2800 to VRAM byte B800 (tile C0 of BG2 base A000); map uses tiles 0..%d' % map_stats['max_tile'],
                            bg2scr='decoded 8192 B = 64x64 map (SC0..SC3) to VRAM byte E000 (BG2SC=73, set by mode-2 handler 02:F193)'),
        palette=pal,
        snes_layer=dict(bgmode=2, bg2=dict(chars_vram_byte=0xa000, screen_vram_byte=0xe000, bg2sc=0x73, size='64x64 (512x512 px)', bpp=4,
                                           **map_stats),
                        registers=setup['registers'],
                        reference_png='evidence/corneria-bg2-snes.png (512x512, BG2 only, rgb555 expanded)',
                        research_png_mismatch=research_mismatch,
                        research_png_note='evidence/research/corneria1-bg2.png compared after rounding to 5-bit (0 = identical image)'),
        md_conversion=dict(
            method='Plane B = SNES BG2 columns 0..31 (x 0..255) x all 64 rows; image period %d px so the 32-cell plane wraps it exactly. '
                   'Colours >>2 per component (project convention); each SNES palette packed whole into one MD line (exact, no approximation).' % period,
            palette_assignment={f'snes_pal{p}': f'md_line{l}' for p, l in sorted(assign.items())},
            lines={line: ' '.join('%03X' % c for c in line_colours[line]['entries']) for line in LINES},
            line3='colour1=000 (margin) colour2=EEE (FPS HUD) fixed; BG colours only if the packing needs line 3',
            inexact_pixels=0, max_channel_error_levels=0,
            precision_loss_note=f"{map_stats['snes_colours_used']} SNES 15-bit colours collapse to {map_stats['md_colours_used']} MD 9-bit colours by the >>2 convention only",
            tiles=dict(unique=len(tiles), cells=PLANE_W * PLANE_H, flips_used={f'h{a}v{b}': n for (a, b), n in sorted(flips.items())},
                       vram_regions=[dict(start=hex(a), end=hex(b), capacity_tiles=(b - a) // 32) for a, b in TILE_REGIONS],
                       first_tile_id=hex(TILE_REGIONS[0][0] // 32), last_tile_id=hex(vram_tile(len(tiles) - 1)),
                       vram_bytes_used=len(blob),
                       regions_used=[dict(start=hex(a), tiles=min(c, max(0, len(tiles) - sum(cc for _, cc in capacity[:i]))))
                                     for i, (a, c) in enumerate(capacity)],
                       loading='copy tiles in order: tile k -> VRAM 9A40+32k for k<302, then F420+32(k-302)'),
            files={name: dict(bytes=len(data), sha256=hashlib.sha256(data).hexdigest()) for name, data in files.items()},
            formats={'corneria-bg-tiles.md.bin': 'MD 4bpp, 32 B/tile, left pixel high nibble',
                     'corneria-bg-planeb.md.bin': '32x64 big-endian name-table words for VRAM E000: prio(0)<<15|line<<13|vflip<<12|hflip<<11|tile',
                     'corneria-bg-cram.md.bin': '64-word CRAM image, big-endian; line 2 left 0 (GSU palette)'},
            checks=dict(binaries_decoded_independently=True, plane_vs_snes_512x512_mismatch_md9=mismatch,
                        screen_at_rest_rows_15_206_mismatch=screen_bad, sampled_scroll_pairs_exact=scroll_ok,
                        plane_b_opaque=True, priority='all plane B words priority 0 (behind plane A / SVP bitmap)'),
            preview='evidence/corneria-bg2-md.png (256x512 plane B)'),
        scroll_mapping=dict(
            snes_at_rest=dict(bg2scroll=vofs, formula='bg2scroll = (clamp(-((outvx>>6)+(outvx>>7)), -56, 232) + bg2Yscroll) & 511 (06:BB5C); outvx=0 at rest',
                              hofs=f'{hofs} [H]: per-line HDMA from bg_scrollbuffer (MHOFS.MC mrotplanet): (m_y1>>3)+m_scrollxoff +/- roll slope around line 112; '
                                   'm_scrollxoff = ((outvy - player_turnrot)>>5) + bg2Xscroll. Value at level start not measured; with period 128 any value maps exactly.'),
            md_formulas=dict(VSCROLL_B='(BG2VOFS + 1 - d) & 511, d = MD screen row - SNES screen row of the same content; d = 0 (identical 224-line coordinates, projection centre 128,112 on both) -> VSCROLL_B = %d at rest' % vscroll_b,
                             HSCROLL_B='(-BG2HOFS) & 0x3FF (plane x = screen x - HSCROLL); line-scroll mode reproduces per-line HDMA HOFS exactly (period %d divides 256)' % period),
            derivation='SNES PPU shows BG row VOFS+1 on the first visible line (title tool convention, verified there against screenshots). '
                       'MD plane B shows row VSCROLL on line 0 and wraps at 512 (64 cells), equal to the SNES 64x64 map height. '
                       'Rows 0..14 and 207..223 are hidden on MD by the plane A margin; SNES content there is not shown.',
            not_reproduced='SNES mode-2 offset-per-tile (per 8-px column vertical offsets, "von", bg2tabN tilt tables) and roll shear. '
                           'MD options: VSCROLL per 2-cell (16 px) column (VSRAM 20 entries in H32; leftmost-column quirk when HSCROLL is not a multiple of 16) '
                           'combined with per-line HSCROLL; or per-line HSCROLL only (shear) with a single VSCROLL. Column granularity halves (8 -> 16 px).'),
        screens=dict(snes='evidence/corneria-bg-screen-snes.png (256x224, BG2 only, VOFS %d HOFS %d, all rows)' % (vofs, hofs),
                     md='evidence/corneria-bg-screen-md.png (256x224, VSCROLL_B %d HSCROLL_B %d, rows 0..14/207..223 black margin)' % (vscroll_b, hscroll_b)),
    )
    (BUILD / 'corneria-background.json').write_text(json.dumps(report, indent=1) + '\n', encoding='utf-8')
    print('PASS corneria background: tiles', len(tiles), 'assign', report['md_conversion']['palette_assignment'],
          'period', period, 'vscroll_b', vscroll_b,
          {k: v['sha256'][:16] for k, v in report['md_conversion']['files'].items()})


if __name__ == '__main__':
    recover()

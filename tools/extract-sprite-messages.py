"""OBJ text messages of the level HUD (SCRAMBLE, STAGE-n, CLEAR, TRAINING, 1-credit fox) - research only.

Selected ROM USA rev0 (SHA-256 asserted). Units, all bytes asserted below:
  do_sprites_l   03:DB5A  order/conditions (dogyirq $1F0F, stayblack $1964, m_meters 70:021C, doingwipe $1FD3)
  prt_scramble   03:DD08  scramble $15B7 (8 bit), tpx $3A = $4848, mes $0E, attr |= $0400 (palette 2)
  do_stage       03:DD53  stagecnt $15BB (16 bit), tpx $4850, stagemes + stageptrs[stage $16D8 + 1];
                           prttraining $1FE0 -> trainingmes at $4848
  prt_stageclear 03:DDB3  stageclear $15BA, tpx $3020, STAGE + digit, tpx += 8, CLEAR
  print_sprite_mes 03:DDF1 glyph table base sprsbase 03:DE88; glyph = 4 words (16x16: tpx, +8, +$0800,
                           +$0808) or $FFFE + 2 words (8x16: tpx, +$0800); OAM low words at $1263+Y
  do_1credit     03:E356  onecredspr $1FCF, credits $189A; genfoxspr 03:E384 (tiles $C0/$C1, attr $24/$64)
Guidance only: UltraStarFox SF/ASM/SPRITES.ASM (prt_scramble, do_stage, print_sprite_mes, do_1credit).

OAM word convention (SNES low table): low byte X, high byte Y; tile word low = tile, high = attribute
(vhoopppN). The OBJ characters are the HUD set of init_sprites_l (14:E0C3 -> VRAM word $6800 = tiles $80..$FF)
and the OBJ palettes 7F:1360 + 32*p (CGRAM 128+16p), both decoded with tools/extract-sprite-textures.py.

Outputs: build/research/sprites/messages/*.png and messages.json.
"""
from starfox_rom import rom_hex
import hashlib
import json
import runpy
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
S = runpy.run_path(str(ROOT / 'tools/extract-sprite-textures.py'))
OUT = ROOT / 'build/research/sprites/messages'
SHA = '3857b5294ea8f7468849437bb2d8271564e8a0ff30774622e9c872bcbd53a84d'

CHECKS = {  # physical offset: bytes (LoROM 03:xxxx -> 0x18000 + (addr & 0x7FFF))
    0x1db5a: rom_hex(0x1db5a, 74),
    0x1dd08: rom_hex(0x1dd08, 75),
    0x1dd53: rom_hex(0x1dd53, 72),
    0x1e356: rom_hex(0x1e356, 46),
    0x1e384: rom_hex(0x1e384, 28),
}
WRITERS = {  # stagecnt=50 stores and the scramble=50 map command
    0x1f555: rom_hex(0x1f555, 11),   # 03:F555 map opcode $0E setstage (jmp table 03:ED83+$0E)
    0x49973: rom_hex(0x49973, 5),               # 09:9973 restart_l
    0x59070: rom_hex(0x59070, 5),               # 0B:9070 playerExitBaseGo_init (USF name)
    0x6d09f: rom_hex(0x6d09f, 5),               # 0D:D09F setvar.b scramble($15B7)=50
}


def main():
    data = (ROOT / 'ref/Star Fox (USA).sfc').read_bytes()
    assert hashlib.sha256(data).hexdigest() == SHA and data[0x7fdb] == 0
    for off, hx in {**CHECKS, **WRITERS}.items():
        assert data[off:off + len(hx) // 2].hex() == hx, hex(off)
    rom = S['Rom'](data)
    base = 0x18000 + (0xDE88 & 0x7FFF)
    w = lambda o: data[base + o] | data[base + o + 1] << 8

    def message(off):
        glyphs = []
        while w(off) != 0xFFFF:
            g = w(off)
            if w(g) == 0xFFFE:
                glyphs.append(dict(at='%03X' % g, kind='8x16', words=['%04X' % w(g + 2), '%04X' % w(g + 4)]))
            else:
                glyphs.append(dict(at='%03X' % g, kind='16x16', words=['%04X' % w(g + i) for i in (0, 2, 4, 6)]))
            off += 2
        return glyphs

    def layout(glyphs, tpx, attr_or=0):
        """print_sprite_mes 03:DDF1: returns OAM entries (x, y, tile, attr)."""
        x, y = tpx & 0xFF, tpx >> 8
        oam = []
        for g in glyphs:
            ws = [int(v, 16) | attr_or for v in g['words']]
            if g['kind'] == '8x16':
                oam += [(x, y, ws[0] & 0xFF, ws[0] >> 8), (x, y + 8, ws[1] & 0xFF, ws[1] >> 8)]
                x += 8
            else:
                oam += [(x, y, ws[0] & 0xFF, ws[0] >> 8), (x + 8, y, ws[1] & 0xFF, ws[1] >> 8),
                        (x, y + 8, ws[2] & 0xFF, ws[2] >> 8), (x + 8, y + 8, ws[3] & 0xFF, ws[3] >> 8)]
                x += 16
        return oam

    # HUD OBJ characters and palettes (same decode as extract-sprite-textures hud_graphics)
    decode = runpy.run_path(str(ROOT / 'tools/extract-intro-background.py'))['decode']
    end = S['phys'](0x14, 0xE0C3)
    out, tr = decode(data[end - 0x4000:end])
    chr_data = out[:0x1000]
    pals_raw, ptr = decode(data[0xB8000:0xBF21C])
    assert 0xB8000 + ptr['source_word_offset'] == 0xBE6C0 and len(pals_raw) == 5120
    pal = [S['palette16'](pals_raw, 0x1360 + 32 * p) for p in range(5)]

    def render(name, oam, scale=4):
        xs, ys = [e[0] for e in oam], [e[1] for e in oam]
        x0, y0 = min(xs), min(ys)
        wd, ht = max(xs) - x0 + 8, max(ys) - y0 + 8
        canvas = [[0] * wd for _ in range(ht)]
        pal_no = (oam[0][3] >> 1) & 7
        for x, y, t, a in oam:
            assert (a >> 1) & 7 == pal_no and 0x80 <= t <= 0xFF
            pix = S['snes_tile'](chr_data, t)
            if a & 0x40:
                pix = [r[::-1] for r in pix]
            if a & 0x80:
                pix = pix[::-1]
            for yy in range(8):
                for xx in range(8):
                    if pix[yy][xx]:
                        canvas[y - y0 + yy][x - x0 + xx] = pix[yy][xx]
        h = S['write_png'](OUT / f'{name}.png', wd, ht, canvas, pal[pal_no], scale=scale)
        return dict(png=f'build/research/sprites/messages/{name}.png', sha256=h, palette=pal_no,
                    box=dict(x=x0, y=y0, w=wd, h=ht))

    msgs = {'stagemes': 0x00, 'scramblemes': 0x0E, 'clearmes': 0x20, 'trainingmes': 0x88}
    report = dict(rom=SHA, sprsbase='03:DE88', messages={})
    for name, off in msgs.items():
        report['messages'][name] = dict(offset='%02X' % off, glyphs=message(off))
    stageptrs = ['%02X' % w(0x2C + 2 * i) for i in range(14)]
    report['stageptrs'] = dict(at='03:DEB4', entries=stageptrs)
    digit = message(w(0x2C + 2 * 1))   # stage $16D8 = 0 -> stageptrs[1]
    # Effective screens:
    scr = layout(report['messages']['scramblemes']['glyphs'], 0x4848, attr_or=0x0400)
    stg = layout(report['messages']['stagemes']['glyphs'] + digit, 0x4850)
    report['render'] = {
        'scramble': dict(rule='03:DD08: scramble!=0 -> scramble-- ; draw iff (gameframe&7) > 3 ; tpx $4848 ; attr|$04',
                         oam=[dict(x=x, y=y, tile='%02X' % t, attr='%02X' % a) for x, y, t, a in scr], **render('scramble', scr)),
        'stage1': dict(rule='03:DD53: stagecnt!=0 -> stagecnt-- ; draw iff (stagecnt&7) >= 3 ; tpx $4850 ; STAGE + dash + stageptrs[stage+1]',
                       oam=[dict(x=x, y=y, tile='%02X' % t, attr='%02X' % a) for x, y, t, a in stg], **render('stage1', stg)),
    }
    clr = layout(report['messages']['stagemes']['glyphs'] + digit, 0x3020)
    nx = (0x3020 & 0xFF) + 16 * 5 + 8 + 16 + 8
    clr += layout(report['messages']['clearmes']['glyphs'], 0x3000 | nx)
    report['render']['stage1clear'] = dict(rule='03:DDB3: stageclear!=0 ; tpx $3020 ; STAGE-n ; tpx+=8 ; CLEAR',
                                           oam=[dict(x=x, y=y, tile='%02X' % t, attr='%02X' % a) for x, y, t, a in clr],
                                           **render('stage1clear', clr))
    fox = [(0xA0, 0x24, 0xC0, 0x24), (0xA8, 0x24, 0xC0, 0x64), (0xA0, 0x2C, 0xC1, 0x24), (0xA8, 0x2C, 0xC1, 0x64)]
    report['render']['onecredit_fox'] = dict(rule='03:E356/E384: per credit, tpa from $24A0, +17 each', **render('onecredit_fox', fox))
    sheet = [[0] * 128 for _ in range(64)]
    for t in range(128):
        pix = S['snes_tile'](chr_data, 0x80 + t)
        for y in range(8):
            for x in range(8):
                sheet[(t // 16) * 8 + y][(t % 16) * 8 + x] = pix[y][x]
    report['sheet_pal2'] = S['write_png'](OUT / 'obj_tiles_80_FF_pal2.png', 128, 64, sheet, pal[2], scale=3)
    report['obj_palette_rows'] = {p: ' '.join('%04X' % (pals_raw[0x1360 + 32 * p + 2 * i] | pals_raw[0x1361 + 32 * p + 2 * i] << 8)
                                             for i in range(16)) for p in range(5)}
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / 'messages.json').write_text(json.dumps(report, indent=1), encoding='utf-8')
    for k, v in report['render'].items():
        print(k, v['box'], 'pal', v['palette'], v['png'])
    print('pal2', report['obj_palette_rows'][2])


if __name__ == '__main__':
    main()

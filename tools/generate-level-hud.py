"""Extract HUD geometry to JSON, then generate the port's tiles and palette."""
import json
from pathlib import Path
import re
import sys

from starfox_rom import read_rom


ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / 'build'
PARAMETERS = BUILD / 'level-hud.json'
# CRAM slots reserved by level_video.asm. These are destination assignments.
SLOTS = {'shield': (13, 4), 'boost': (13, 7), 'boss': (14, 5)}


def extract():
    rom = read_rom()
    bars = {}
    for name, start, end in (('shield', 0xafbc, 0xafea), ('boost', 0xaf85, 0xafb6)):
        body = rom[start:end]
        frame, = re.findall(rb'\xa3(.)\xa4(.)\xa0(.)\x94\xff\x6c\xb0', body, re.S)
        x_opcode, x_size = (0xf1, 2) if name == 'boost' else (0xa1, 1)
        assert body[0] == x_opcode
        x = int.from_bytes(body[1:1 + x_size], 'little')
        fill, = re.findall(bytes([x_opcode]) + b'(' + b'.' * x_size + rb')\xf2(..)\xa4(.)\xa0(.)', body, re.S)
        y_offset = 2 + x_size
        assert body[y_offset - 1] == 0xf2
        y = int.from_bytes(body[y_offset:y_offset + 2], 'little')
        bars[name] = dict(source=f'01:{start:04X}..{end - 1:04X}', width=frame[0][0], height=frame[1][0],
                          outline_colour=frame[2][0], fill_left=int.from_bytes(fill[0], 'little') - x,
                          fill_top=int.from_bytes(fill[1], 'little') - y,
                          fill_height=fill[2][0], fill_colour=fill[3][0], right_width=8)

    body = rom[0xafeb:0xb05d]
    padding, height = re.search(rb'(\xd3+)\xa4(.)', body, re.S).groups()
    dx, dy = re.search(rb'(\xd1+)(\xd2+)', body).groups()
    outline, = re.findall(rb'\xa0(.)\x94\xff\x6c\xb0', body, re.S)
    fill_height, fill_colour = re.search(rb'\xa4(.)\xa0(.)\x94\xff\x53\xb0', body, re.S).groups()
    bars['boss'] = dict(source='01:AFEB..B05C', height=height[0], outline_colour=outline[0],
                        fill_left=len(dx), fill_top=len(dy), fill_height=fill_height[0],
                        fill_colour=fill_colour[0], right_width=len(padding))
    palette = json.loads((BUILD / 'corneria-background.json').read_text())['palette']['rows_hex']['2'].split()
    PARAMETERS.write_text(json.dumps(dict(palette_bgr555=palette, bars=bars), indent=2) + '\n', encoding='ascii')


def tile(bar, kind, fill, slots):
    px = [[0] * 8 for _ in range(8)]
    width = bar['right_width'] if kind == 'last' else 8
    height = bar['height']
    for x in range(width):
        px[0][x] = px[height - 1][x] = slots[0]
    if kind == 'first':
        for y in range(height):
            px[y][0] = slots[0]
    if kind == 'last':
        for y in range(height):
            px[y][width - 1] = slots[0]
    start = bar['fill_left'] if kind == 'first' else 0
    for y in range(bar['fill_top'], bar['fill_top'] + bar['fill_height']):
        for x in range(start, start + fill):
            px[y][x] = slots[1]
    return bytes((px[y][x] << 4) | px[y][x + 1] for y in range(8) for x in range(0, 8, 2))


def md_colour(value):
    colour = int(value, 16)
    if not 0 <= colour <= 0x7fff:
        raise ValueError(f'Invalid BGR555 colour: {value}')
    return (colour & 31) >> 2 << 1 | ((colour >> 5) & 31) >> 2 << 5 | ((colour >> 10) & 31) >> 2 << 9


def generate():
    data = json.loads(PARAMETERS.read_text(encoding='ascii'))
    bars, palette = data['bars'], data['palette_bgr555']
    colours = [md_colour(value) for value in palette]
    if len(colours) != 16:
        raise ValueError('level-hud.json requires a 16-colour palette')
    for name in SLOTS:
        bar = bars[name]
        fields = ('height', 'outline_colour', 'fill_left', 'fill_top', 'fill_height', 'fill_colour', 'right_width')
        if any(type(bar[key]) is not int for key in fields):
            raise ValueError(f'Invalid HUD parameter type: {name}')
        if not (1 <= bar['fill_left'] < bar['right_width'] <= 8 and
                1 <= bar['height'] <= 8 and 0 <= bar['fill_top'] and
                1 <= bar['fill_height'] <= bar['height'] - bar['fill_top'] and
                0 <= bar['outline_colour'] < 16 and 0 <= bar['fill_colour'] < 16):
            raise ValueError(f'Invalid HUD geometry or colour index: {name}')
    shield, boost = bars['shield'], bars['boost']
    if (shield['fill_left'], shield['width'], shield['right_width']) != (boost['fill_left'], boost['width'], boost['right_width']):
        raise ValueError('Shield and boost share their horizontal tile layout')
    if type(shield['width']) is not int or not 16 <= shield['width'] <= 64 or shield['width'] % 8:
        raise ValueError('The shield/boost width must be a multiple of 8 between 16 and 64')
    if shield['right_width'] != 8 or colours[shield['outline_colour']] != colours[boost['outline_colour']]:
        raise ValueError('Shield and boost use full end tiles and share their outline CRAM slot')

    out = bytearray()
    lines = ['; Generated from editable build/level-hud.json.']
    for name, slots in SLOTS.items():
        bar = bars[name]
        first, last = 8 - bar['fill_left'], bar['right_width'] - bar['fill_left']
        mid_index, last_index = first + 1, first + 1 + 9
        prefix = 'LV_HUD_' + name.upper()
        layout = dict(base=len(out) // 32, first=first, last=last, mid_index=mid_index, last_index=last_index)
        for key, value in layout.items():
            lines.append(f'{prefix}_{key.upper()} equ {value}')
        lines.append(f'{prefix}_INSET equ {bar["fill_left"]}')
        for kind, capacity in (('first', first), ('mid', 8), ('last', last)):
            out.extend(b''.join(tile(bar, kind, n, slots) for n in range(capacity + 1)))
    if len(out) > 80 * 32:
        raise ValueError('HUD tiles exceed the reserved VRAM range')
    lines.extend([f'LV_HUD_CELLS equ {shield["width"] // 8}',
                  f'LV_HUD_LIMIT equ {shield["width"] - 2 * shield["fill_left"]}'])
    for symbol, name, field in (('OUTLINE', 'shield', 'outline_colour'), ('BOOST', 'boost', 'fill_colour'),
                                 ('RED', 'shield', 'fill_colour'), ('BOSSEDGE', 'boss', 'outline_colour'),
                                 ('BOSSFILL', 'boss', 'fill_colour')):
        lines.append(f'LV_HUD_{symbol} equ ${colours[bars[name][field]]:03x}')
    (BUILD / 'level-hud-tiles.bin').write_bytes(out)
    (BUILD / 'level-hud.inc').write_text('\n'.join(lines) + '\n', encoding='ascii')
    print(f'Generated {len(out) // 32} HUD bar tiles from level-hud.json')


if __name__ == '__main__':
    if '--extract' in sys.argv[1:]:
        extract()
    generate()

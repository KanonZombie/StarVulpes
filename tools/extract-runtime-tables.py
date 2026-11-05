"""Extract the original tables used directly by the 68000 port."""
import hashlib
import runpy
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'build'
ROM = (ROOT / 'ref/Star Fox (USA).sfc').read_bytes()
assert hashlib.sha256(ROM).hexdigest() == '3857b5294ea8f7468849437bb2d8271564e8a0ff30774622e9c872bcbd53a84d'

# Label, LoROM file offset, item count, width in bytes. FloatBob and VbPos
# are read a byte at a time by the target and keep their original byte order.
TABLES = [
    ('M4LvBonerTab', 0x16f7f, 12, 2),
    ('M4LpWobbleTable', 0x5eb8f, 28, 1),
    ('M4RadioFaceSounds', 0x1eb32, 24, 1),
    ('M4LevelViewFloat', 0x33ada, 36, 2),
    ('M4PmColonyTab', 0x3655f, 42, 1),
    ('M4PmWashTab', 0x36818, 26, 1),
    ('M4Szaco0Tables', 0x5244f, 80, 2),
    ('M4Cam2X', 0x43aea, 6, 2),
    ('M4Cam2Y', 0x43af6, 6, 2),
    ('M4CnBaTyTab', 0x3a182, 9, 1),
    ('M4CkUpDown', 0x4bc4f, 32, 1),
    ('M4MtFadeTab', 0x17831, 64, 2),
    ('M4SxFloatRot', 0x5eb8f, 28, 1),
    ('M4SxFloatBob', 0x33ada, 72, 1),
    ('M4SmRandomShapes', 0x4f923, 32, 2),
    ('M4VbPosTab', 0x3aecf, 260, 1),
    ('M4VrRndPosTab', 0x3c767, 16, 2),
    ('M4VrOuchTab', 0x3ccda, 96, 1),
    ('M4VoWarpPos', 0x54677, 16, 2),
]


def write(name, data, width):
    assert len(data) % width == 0
    converted = b''.join(data[i:i+width][::-1] for i in range(0, len(data), width))
    (OUT / f'{name}.bin').write_bytes(converted)


for name, offset, count, width in TABLES:
    data = ROM[offset:offset + count * width]
    assert len(data) == count * width
    write(name, data, width)

decode = runpy.run_path(str(ROOT / 'tools/extract-intro-background.py'))['decode']
palettes, _ = decode(ROM[0xb8000:0xbf21c])
assert len(palettes) == 5120
# Meteor bg_1_4 palette at 7F:0B80. The port's fade reads rows 1 and 5.
write('M4MtPalInit', palettes[0xba0:0xbc0] + palettes[0xc20:0xc40], 2)

ending = runpy.run_path(str(ROOT / 'tools/ending-resources.py'))
paths = ending['SETTHEPATH']
(OUT / 'M4EndPathTab.bin').write_bytes(b''.join(int(row['path'], 16).to_bytes(2, 'big')
                                             for row in paths.values()))
print(f'Extracted {len(TABLES) + 2} runtime tables')

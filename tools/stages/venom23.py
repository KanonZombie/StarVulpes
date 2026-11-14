"""Venom 2/3 orbital and planet graphics from the selected USA ROM.

All models use WORD descriptor indices and the shared 84-vertex,
76-visibility contract, including the animated barrier and the truck.
Strategies resolve descriptors through original ROM shape headers.
"""
import re
from pathlib import Path

_ROOT = Path(__file__).resolve().parents[2]

_SHAPES = [
    # Venom 2 planet (colony, 05:9380..): cars car_0 (aircar1..5), car_1 (truck1/2), road line_2
    # (roadline), colony exit E59C (colonyexit 0A:F235) and E5B8 (nocoll, 0D:E16C), barrier
    # (aircar2 / madtrucker), madbiker air_1 BA84, madtrucker boss_9_5 C99C, its trailer boss_9_0.
    ('car_0', 0xE468), ('car_1', 0xE484), ('line_2', 0xE580), ('e59c', 0xE59C), ('e5b8', 0xE5B8),
    ('barrier', 0xC9B8), ('air_1', 0xBA84), ('boss_9_5', 0xC99C), ('boss_9_0', 0xC980),
    # Venom 2 orbital: wire_man C558 (wireman 08:D249), castanet parts C9D4/C9F0/CA0C/CA28 (09:CC60
    # family, no USF name in the shape table) and boss_e_4 CDE0 (minicastanet paths, map pathdha).
    ('wire_man', 0xC558), ('c9d4', 0xC9D4), ('c9f0', 0xC9F0), ('ca0c', 0xCA0C),
    ('ca28', 0xCA28), ('boss_e_4', 0xCDE0),
    # Venom 3: bossF 0B:EBB3 (orbital) boss_f_3 D4FC and parts D4A8/D4E0/D588/D5A4; airship 09:E128
    # (planet) boss_f_4 D518.
    ('d4a8', 0xD4A8), ('d4e0', 0xD4E0), ('boss_f_3', 0xD4FC), ('boss_f_4', 0xD518),
    ('d588', 0xD588), ('d5a4', 0xD5A4),
    # Other headers of these maps seen in the census and not catalogued yet.
    ('b2c1', 0xB2C1), ('d25c', 0xD25C), ('r_bu_6', 0xD8EC), ('dcf8', 0xDCF8), ('mine_2', 0xE4A0),
]


def _catalogued_elsewhere():
    me = Path(__file__).name
    found = set()
    files = [p for p in (_ROOT / 'tools/stages').glob('*.py')
             if p.name != me and (p.name < me or p.name.startswith('venom_'))]
    files += [_ROOT / 'tools/level-shapes.py', _ROOT / 'tools/generate-level-shapes.py']
    for p in files:
        for m in re.finditer(r'0x([0-9A-Fa-f]{4})\b', p.read_text(encoding='utf-8')):
            found.add(int(m.group(1), 16))
    return found


_seen = _catalogued_elsewhere()
# Not drawable yet (see above): effect descriptors.
_NO_MODEL = set()
DRAW_MODELS = True  # WORD descriptor indices and 76 visibility flags are supported.
if DRAW_MODELS:
    SHAPES = [(n, h) for n, h in _SHAPES if h not in _seen and h not in _NO_MODEL]
    EFFECTS = [('V3_' + n.upper(), h, -1) for n, h in _SHAPES if h not in _seen and h in _NO_MODEL]
else:
    SHAPES = []
    EFFECTS = [('V3_' + n.upper(), h, -1) for n, h in _SHAPES if h not in _seen]

# Textured colour words of the drawn models (svp-texpoly): air_1 BA84 (madbiker) materials 59/60
# (0x40DB, 0x48DB; tools/generate-intro-colours.py fails without them).
TEX_WORDS = [0x40DB, 0x48DB]

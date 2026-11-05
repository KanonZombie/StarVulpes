"""Venom 2 (maps 0D:E085 orbital / 0D:E0F5 planet, route 2) and Venom 3 (0D:E8B9 / 0D:E929, route 3).

Loaded by tools/level-shapes.py stage_modules() and the other generators. Owner: build/agent-venom23/
(VENOM23.md). Strategies: src/stages/level_venom23.asm, which finds every shape by its ROM header
(M4LevelShapeIndex), so a drawn shape added later with the same header replaces the effect without
touching the 68000 code. Headers read from ref/Star Fox (USA).sfc (rev0, SHA-256 3857b529...a84d):
the shapes the ROM itself writes into the objects of these four maps (build/agent-venom23/census.py,
ROM 65816 executed through tools/path-oracle.py; and the map listings venom23-map-listing.py), minus
those already catalogued. Names: UltraStarFox (labels only).

SVP drawing: the model geometry now lives in its own ROM block (build/svp-geo-rom.inc), so the shapes
that fit the SVP limits (<= 85 vertices per model; cmd9 register: 64 vertices / 64 visibility entries per
object, |coord| < 16384) are drawn (SHAPES, own SVP model). The others stay effect descriptors (svp -1:
ROM header box, sortz, size and shift for collision, z-remove and explosions; never drawn):
boss_9_5 C99C (74 vertices, 68 visibility entries > 64), barrier C9B8 (point opcode 8 not decoded by
tools/recover-intro-model.py) and DCF8 (not decoded). Counts: build/agent-venom23/shape-check.txt
(shape-check.py).

Dedup: headers literally present in tools/level-shapes.py, tools/generate-level-shapes.py, a stage
module sorting before this file, or a venom_*.py module (those do not dedup) are skipped (text scan,
no runpy: meteor*.py runpy the stage modules).
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
_NO_MODEL = {0xC99C, 0xC9B8, 0xDCF8}
DRAW_MODELS = False  # True needs INTEGRATION.md section 2 (FX indices > 255 in level_boss1.asm dc.b table)
if DRAW_MODELS:
    SHAPES = [(n, h) for n, h in _SHAPES if h not in _seen and h not in _NO_MODEL]
    EFFECTS = [('V3_' + n.upper(), h, -1) for n, h in _SHAPES if h not in _seen and h in _NO_MODEL]
else:
    SHAPES = []
    EFFECTS = [('V3_' + n.upper(), h, -1) for n, h in _SHAPES if h not in _seen]

# Textured colour words of the drawn models (svp-texpoly): air_1 BA84 (madbiker) materials 59/60
# (0x40DB, 0x48DB; tools/generate-intro-colours.py fails without them).
TEX_WORDS = [0x40DB, 0x48DB]

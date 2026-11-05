"""Sector X (0D:DF4C), Sector Y (0D:E02A) and Sector Z (0D:E6D8): shapes of the stage unit `sectors`.

Owner: build/agent-sectors/SECTORS.md (survey: build/agent-sectors/shape-survey.py, colours colour-check.py).
Loaded by tools/level-shapes.py stage_modules() and the other generators. src/stages/level_sectors.asm finds every
shape by its ROM header (M4LevelShapeIndex / M4ArCreateHdr), so a header already catalogued by an earlier stage
module (sorted file name) is skipped here without breaking the 68000 code.

Drawn SHAPES: headers of the unit that fit the SVP cmd9 registry (<= 64 vertices, <= 64
visibilities, |coord| < 16384) and the generator (<= its colbox cap, no rotx colboxes), not catalogued before.
EFFECTS (svp -1, not drawn, ROM header box/sortz/size/shift only):
  - the 16 spacebars DF7C..E190: point opcode 52 (pointsxw, 16-bit mirrored) is not decoded by
    tools/recover-intro-model.py (8 vertices, |coord| <= 250 once it is: INTEGRATION.md section 1);
  - colony_0 E1AC: 78 vertices (> 64);
  - pole0 E698 (drawable, 18 vertices) and the XP/SXP spacebars: 10 colboxes (rotz) above the generator cap of 8
    (INTEGRATION.md section 2); with the cap raised their colboxes are emitted (EFFECT_COLBOXES);
Headers read from ref/Star Fox (USA).sfc (rev0); names from UltraStarFox only.
"""
import re
import runpy
from pathlib import Path

_ROOT = Path(__file__).resolve().parents[2]
_caps = [int(c) for c in re.findall(r'assert len\((?:e\[.boxes.\]|boxes)\) <= (\d+)',
                                    (_ROOT / 'tools/generate-level-shapes.py').read_text(encoding='utf-8'))]
_BOX10 = len(_caps) >= 2 and min(_caps) >= 10

_SPACEBARS = [  # (name, header, more than 8 colboxes)
    ('xwirespacebar', 0xDF7C, False), ('xsolidspacebar', 0xDF98, False), ('xpwirespacebar', 0xDFB4, True),
    ('xpsolidspacebar', 0xDFD0, True), ('ywirespacebar', 0xE024, False), ('ysolidspacebar', 0xE040, False),
    ('zwirespacebar', 0xE05C, False), ('zsolidspacebar', 0xE078, False), ('sxwirespacebar', 0xE094, False),
    ('sxsolidspacebar', 0xE0B0, False), ('sxpwirespacebar', 0xE0CC, True), ('sxpsolidspacebar', 0xE0E8, True),
    ('sywirespacebar', 0xE13C, False), ('sysolidspacebar', 0xE158, False), ('szwirespacebar', 0xE174, False),
    ('szsolidspacebar', 0xE190, False)]

# Drawn: every header of the three maps / strategies that fits the SVP limits (<= 85 vertices per model in the
# geometry ROM block build/svp-geo-rom.inc, cmd9 <= 64 vertices and visibilities per object, |coord| < 16384),
# the generator (colbox cap, no rotx colboxes) and whose colour words all resolve (colour-check.py), not
# catalogued before. Strategies of this unit: s_fish (sfish 0A:E9E8), colony_1/colony_2 (0A:D417/D44B),
# Bwarker_3 (map spacebarwalker 0A:D4D0, 12 frames), flingboss (09:AA4F). Map objects: colony3L/R (nocoll
# 06:873F, Sector X). Path enemies of the three maps (pathdha 04:8004 / path 04:8022): shark, shieldr, ray_0/1,
# ika, DBA8 and E67C (no UltraStarFox name in the listing).
_SHAPES = [('s_fish', 0xE4F4), ('colony_1', 0xE1C8), ('colony_2', 0xE2A8), ('bwarker_3', 0xDE10),
           ('flingboss', 0xB92F), ('colony3l', 0xE200), ('colony3r', 0xE21C), ('shark', 0xDB38), ('shieldr', 0xE350),
           ('ray_0', 0xE3A4), ('ray_1', 0xE3DC), ('ika', 0xE52C), ('sx_dba8', 0xDBA8), ('sx_e67c', 0xE67C),
           # flingboss arms (arm_istrat 09:A3FB): the grabber hand B94B (32 frames). The segments B8F7 / B913 have
           # rotx colboxes ($41) the generator rejects: effects of earlier/later modules (armada_tunnel, titania).
           ('grabber', 0xB94B)]
_PENDING = []
_EFFECTS = [('SX_COLONY_0', 0xE1AC, -1)] + [('SX_' + n.upper(), h, -1) for n, h in _PENDING]
# Colbox chains of the 10-box headers (rotz, XP/SXP spacebars and pole0) only once the generator accepts them
# (INTEGRATION.md section 2); they cost no SVP space.
EFFECT_COLBOXES = {0xDFB4, 0xDFD0, 0xE0CC, 0xE0E8, 0xE698} if _BOX10 else set()
_EFFECTS.append(('SX_POLE0', 0xE698, -1))
# Children of the Sector Y mothers (mapmother 04:F60D, script 05:56FA): amoeba 0A:9F67 (level_spacemisc.asm) with
# shape B1A9 (points with their own end, animated colour 03:8719): header box only, not drawn.
_EFFECTS.append(('SX_AMOEBA', 0xB1A9, -1))
# flingboss phase-2 tail end AF25 (arm_istrat 09:A87E with the tail flag): textured sprite word $40A9.
_EFFECTS.append(('SX_ARMTAIL', 0xAF25, -1))
_EFFECTS += [('SX_' + n.upper(), h, -1) for n, h, _ in _SPACEBARS]

_earlier = set()
for _f in sorted((_ROOT / 'tools/stages').glob('*.py')):
    if _f.name >= 'sectors.py':
        continue
    _m = runpy.run_path(str(_f))
    _earlier |= {h for _, h in _m.get('SHAPES', [])} | {e[1] for e in _m.get('EFFECTS', [])}
# headers of the base catalog (tools/level-shapes.py SHAPES, read as text: running it would recurse here)
_lsrc = (_ROOT / 'tools/level-shapes.py').read_text(encoding='utf-8')
_earlier |= {int(h, 16) for h in re.findall(r"\('[\w]+', 0x([0-9a-fA-F]{4})\)", _lsrc[:_lsrc.index('def stage_modules')])}
SHAPES = [(n, h) for n, h in _SHAPES if h not in _earlier]
EFFECTS = [e for e in _EFFECTS if e[1] not in _earlier]
EFFECT_COLBOXES = {h for h in EFFECT_COLBOXES if h not in _earlier}

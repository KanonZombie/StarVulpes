"""Sector X/Y/Z polygon and sprite dependencies from the selected USA ROM.

All spacebars, colony_0, pole0 and articulated boss parts are admitted by
the 84-vertex / 76-visibility contract. Collision chains retain their ROM
boxes, including ten-box rotz chains. Animated amoebas and the tail use
original billboard texture descriptors.
"""
import re
import runpy
from pathlib import Path

_ROOT = Path(__file__).resolve().parents[2]
_SPACEBARS = [  # (name, header, more than 8 colboxes)
    ('xwirespacebar', 0xDF7C, False), ('xsolidspacebar', 0xDF98, False), ('xpwirespacebar', 0xDFB4, True),
    ('xpsolidspacebar', 0xDFD0, True), ('ywirespacebar', 0xE024, False), ('ysolidspacebar', 0xE040, False),
    ('zwirespacebar', 0xE05C, False), ('zsolidspacebar', 0xE078, False), ('sxwirespacebar', 0xE094, False),
    ('sxsolidspacebar', 0xE0B0, False), ('sxpwirespacebar', 0xE0CC, True), ('sxpsolidspacebar', 0xE0E8, True),
    ('sywirespacebar', 0xE13C, False), ('sysolidspacebar', 0xE158, False), ('szwirespacebar', 0xE174, False),
    ('szsolidspacebar', 0xE190, False)]

# Drawn: headers of these maps / strategies within the shared 84-vertex,
# 76-visibility contract, with decoded collision chains and colour words, not
# catalogued before. Strategies of this unit: s_fish (sfish 0A:E9E8), colony_1/colony_2 (0A:D417/D44B),
# Bwarker_3 (map spacebarwalker 0A:D4D0, 12 frames), flingboss (09:AA4F). Map objects: colony3L/R (nocoll
# 06:873F, Sector X). Path enemies of the three maps (pathdha 04:8004 / path 04:8022): shark, shieldr, ray_0/1,
# ika, DBA8 and E67C (no UltraStarFox name in the listing).
_SHAPES = [('s_fish', 0xE4F4), ('colony_1', 0xE1C8), ('colony_2', 0xE2A8), ('bwarker_3', 0xDE10),
           ('flingboss', 0xB92F), ('colony3l', 0xE200), ('colony3r', 0xE21C), ('shark', 0xDB38), ('shieldr', 0xE350),
           ('ray_0', 0xE3A4), ('ray_1', 0xE3DC), ('ika', 0xE52C), ('sx_dba8', 0xDBA8), ('sx_e67c', 0xE67C),
           # The animated grabber and articulated segments share descriptors
           # with armada_tunnel and titania, including their rotx collision boxes.
           ('grabber', 0xB94B), ('colony_0', 0xE1AC), ('pole0', 0xE698)]
_SHAPES += [(name, header) for name, header, _ in _SPACEBARS]
_PENDING = []
_EFFECTS = []
# Ten-box chains are retained by the collision data producer.
EFFECT_COLBOXES = {0xDFB4, 0xDFD0, 0xE0CC, 0xE0E8, 0xE698}

# Children of the Sector Y mothers (mapmother 04:F60D, script 05:56FA): amoeba 0A:9F67 (level_spacemisc.asm) with
# shape B1A9 (points with their own end, animated colour 03:8719).
_EFFECTS.append(('SX_AMOEBA', 0xB1A9, 22))
# flingboss phase-2 tail end: original textured billboard.
_EFFECTS.append(('SX_ARMTAIL', 0xAF25, 22))
SPRITE_HEADERS = {h for _, h, model in _EFFECTS if model == 22}

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

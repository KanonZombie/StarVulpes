"""Meteor (map 0D:D586, route 1 stage 4): shapes, textures and player mode of the stage unit.

Loaded by tools/level-shapes.py stage_modules() (and the other generators). Headers and uses:
build/research/stage-meteor.md section 4.1 and build/agent-meteor/METEOR.md. The boss shapes are in
tools/stages/meteor_boss.py.

Shapes are referenced from src/stages/level_meteor.asm by their ROM header (M4LevelShapeIndex), so a
header already catalogued by an earlier stage module is skipped here without breaking the 68000 code.
"""
import re
import runpy
from pathlib import Path

_ROOT = Path(__file__).resolve().parents[2]

# SVP model space: the level geometry now lives in its own ROM block (build/svp-geo-rom.inc, PM4), so
# r_bu_7 and base_0 fit (INTEGRATION.md section 4, resolved by the coordinator). They are still added only
# when the tools of sections 1 and 3 support them.
SVP_ROOM_FOR_METEOR_SHAPES = True

_SHAPES = [
    # Map objects (0D:B5DE..BC50, stage-meteor.md section 2.2): rocks (hard180YR / hard180YRfog),
    # building, turret hou_5 (12 frames), walker (18 frames), tanks, helicopter (3 frames), bases.
    ('gro_6', 0xCE34), ('gro_4', 0xCD54), ('gro_5', 0xCDA8), ('gro_0', 0xCC04), ('gro_1', 0xCC58),
    ('bu_3', 0xD400), ('hou_5', 0xE778), ('walker_0', 0xB42D), ('s_tank_0', 0xC884), ('tank_1', 0xE6EC),
    ('heli', 0xCDC4), ('base_0_0', 0xE740), ('base_0_1', 0xE75C), ('tank_2', 0xDF28),
    ('btank_1', 0xE708),
    # Created by strategies (section 3): walker without its right/left leg (walking 09:8CC1/8E43),
    # tank2 fighters DA90 (0A:C697, 10 frames), up1man pieces C504 (08:D85A), Smark B3A1 (smarkexplode
    # 06:F046: one textured quad, colour word $4018).
    ('walker_r', 0xB411), ('walker_l', 0xB3F5), ('zaco_7', 0xDA90), ('up1_man', 0xC504), ('smark', 0xB3A1),
]
# Pillar r_bu_7 D908 uses the 16-bit mirrored point opcode 52 (pointsxw): added only once
# tools/recover-intro-model.py decodes it (build/agent-meteor/INTEGRATION.md section 1). Until then the
# effect descriptor VP_R_BU_7 of venom_planet.py (svp -1) gives the pillars collision but no drawing.
_src = (_ROOT / 'tools/recover-intro-model.py').read_text(encoding='utf-8')
if SVP_ROOM_FOR_METEOR_SHAPES and re.search(r'op\s*(==\s*52\b|in\s*\([^)]*\b52\b)', _src):
    _SHAPES.append(('r_bu_7', 0xD908))
# base1 0A:88AC door base_0 E794 (map 0D:BA12, BB1C, BB2A; 9 frames). Its collision chain is 3 static walls
# + an animated record of 16 frames whose records chain to a second box (02:9E41..9E6E, A102): added only
# once tools/generate-level-shapes.py emits that layout (INTEGRATION.md section 3); before, the generator
# rejects it and the build would fail.
_gen = (_ROOT / 'tools/generate-level-shapes.py').read_text(encoding='utf-8')
if SVP_ROOM_FOR_METEOR_SHAPES and re.search(r'^MIXED_ANIMATED_COLBOX\s*=\s*True', _gen, re.M):
    _SHAPES.append(('base_0', 0xE794))

_earlier = set()
for _f in sorted((_ROOT / 'tools/stages').glob('*.py')):
    if _f.name >= 'meteor.py':
        continue
    _earlier |= {h for _, h in runpy.run_path(str(_f)).get('SHAPES', [])}
SHAPES = [(n, h) for n, h in _SHAPES if h not in _earlier]

# Textured colour word of Smark (03:852E entry 0): texture through svp-texpoly.
TEX_WORDS = [0x4018]

# setbginfo newplayerstrat of bg_1_4 ($51): playerplanetflyin 0B:84C8 (level_meteor.asm).
PSTRATS = {0x0B84C8: ('playerplanetflyin', 'M4MtFlyinI')}

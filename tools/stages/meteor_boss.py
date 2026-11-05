"""Meteor boss bossh 00:E8D4 (map 0D:BBF5): shapes, effects, sprites and textures.

Loaded by tools/level-shapes.py stage_modules() and the other generators. Sources (ROM USA rev0, bank 00):
build/agent-meteor/BOSS.md section 3. Code: src/stages/level_meteor_boss.asm.
"""
import runpy
from pathlib import Path

_ROOT = Path(__file__).resolve().parents[2]

_SHAPES = [
    # Body boss_h_0 BBF0 (15 vertices, material 105 = $463C texture 3C), legs boss_h_1 BC0C and
    # boss_h_1a BC28 (15 vertex frames each; BC28 from animframe 13, 00:F51B), top boss_h_2 BC44,
    # teleporter boss_h_3 BCEC (one textured quad $40B4 = texture 34, 20 vertex frames).
    ('boss_h_0', 0xBBF0), ('boss_h_1', 0xBC0C), ('boss_h_1a', 0xBC28), ('boss_h_2', 0xBC44),
    ('boss_h_3', 0xBCEC),
]
_earlier = set()
for _f in sorted((_ROOT / 'tools/stages').glob('*.py')):
    if _f.name >= 'meteor_boss.py':
        continue
    _earlier |= {h for _, h in runpy.run_path(str(_f)).get('SHAPES', [])}
SHAPES = [(n, h) for n, h in _SHAPES if h not in _earlier]

# Sprites: fireball AD9D (bonfire and its trail, object coltab bonfire_c 03:8574) and Lsmoke ADF1
# (createsmoke ED6A, colframe 0..7 selects the anim8 texture frame). Billboard model 22.
EFFECTS = [('FIREBALL', 0xAD9D, 22), ('LSMOKE', 0xADF1, 22)]
SPRITE_HEADERS = {0xAD9D, 0xADF1}
COLTAB_SPRITES = [(0x8574, 0xAD9D)]

# Textured colour words: body material 105 (03:8213+210) and teleporter material 0 (03:8572).
TEX_WORDS = [0x463C, 0x40B4]

# Object colour table of the red legs / vulnerable body (alx+$20 = id_1_c 03:82ED). Consumed only once
# tools/generate-intro-colours.py reads MESH_COLTABS (build/agent-meteor/INTEGRATION-BOSS.md section 1).
MESH_COLTABS = [0x82ED]

"""Corneria 2 (map 0D:DD66), Corneria 3 (0D:E3CF) and Training (0D:EE9A): shapes of the stage unit.

Loaded by tools/level-shapes.py stage_modules() (and the other generators). Strategies:
src/stages/level_corneria23.asm; documentation and oracle: build/agent-corneria23/CORNERIA23.md,
build/agent-corneria23/c23-compare.py. Headers of the map objects and of the objects created by the
strategies and paths of these maps that were not catalogued yet (ROM USA rev0, bank 00; names from
UltraStarFox SHAPES.ASM where it has one). Every one has <= 64 vertices (SVP cmd9 registry).

The 68000 code finds every shape by its ROM header (M4LevelShapeIndex), so a header already catalogued
by an earlier stage module is skipped here without breaking the strategies.
"""
import runpy
from pathlib import Path

_ROOT = Path(__file__).resolve().parents[2]

_SHAPES = [
    # Map objects: turret houdai/houdaiNS (08:B539/B56F, 12 vertices), parachutist para_0 (04:F667,
    # created by carrier 0A:86B4) and its landed shape para_1 (04:F701 sta $04).
    ('houdai_0', 0xC1F4), ('para_0', 0xB481), ('para_1', 0xB4A2),
    # Shapes taken by path objects of these maps (pathdha 04:8004, path setshape; no USF name):
    # B882 and C440 (8 colboxes each; c23-survey: Corneria 2 / Corneria 3).
    ('c23_b882', 0xB882), ('c23_c440', 0xC440),
    # Corneria 3 boss bossA 07:9B0F: body boss_A_2 C6C4 (62 vertices, 3 frames), turrets boss_A_1 C6A8,
    # cups C68C (7 frames) and the three pieces of the destroyed tank (07:A225: boss_a_3 C734 body,
    # boss_a_4 C750, boss_a_5 C76C); path shape BD78 (27 vertices).
    ('boss_A_2', 0xC6C4), ('boss_A_1', 0xC6A8), ('boss_A_0', 0xC68C), ('boss_A_3', 0xC734),
    ('boss_A_4', 0xC750), ('boss_A_5', 0xC76C), ('c23_bd78', 0xBD78),
]

_earlier = set()
for _f in sorted((_ROOT / 'tools/stages').glob('*.py')):
    if _f.name >= 'corneria23.py':
        continue
    _earlier |= {h for _, h in runpy.run_path(str(_f)).get('SHAPES', [])}
SHAPES = [(n, h) for n, h in _SHAPES if h not in _earlier]

# base_1 00:BAF4 (hangar door of Corneria 2/3 and Training, 44 vertices): its colbox list is mixed
# (3 fixed boxes + one animated record of 8 frames, 02:9E41/02:A21B) and tools/generate-level-shapes.py
# only accepts single boxes or a pure 16-frame animated list. Until the shared change of
# build/agent-corneria23/INTEGRATION.md section 2 is integrated it is an effect without drawing:
# its descriptor carries the ROM header box (320/640/360) for z-remove and explosions; collision is
# disabled by the strategy (M4StratBase1x, documented difference) because the header box would close
# the door that the player flies through.
EFFECTS = [('C23_BASE_1', 0xBAF4, -1)]

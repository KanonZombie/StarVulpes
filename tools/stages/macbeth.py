"""Macbeth (map 0D:E81C, route 3 stage 5, interior with the train): shapes and effects of the stage unit.

Loaded by tools/level-shapes.py stage_modules() and the other generators. Owner: build/agent-macbeth/
(MACBETH.md). Strategies: src/stages/level_macbeth.asm, which finds every shape by its ROM header
(M4LevelShapeIndex). Headers read from ref/Star Fox (USA).sfc (rev0, SHA-256 3857b529...a84d); names
UltraStarFox (SF/MAPS/MAP3_5.ASM, SF/STRAT/GASTRATS.ASM, GA2STRAT.ASM, GBSTRATS.ASM). Vertex counts and
coordinate ranges (build/agent-macbeth/shape-check.py): every model below fits the SVP cmd9 register
(<= 20 vertices, <= 19 visibility entries, |coord| <= 640 after the shape shift).

Headers already catalogued by tools/level-shapes.py or by an earlier stage module are skipped with a
text scan (no runpy of other stage modules: tools/stages/meteor*.py runpy this file, so a runpy here
would recurse). Only the headers this unit declares are written as literals here.
"""
import re
from pathlib import Path
from starfox_rom import macbeth_petals

_ROOT = Path(__file__).resolve().parents[2]

_SHAPES = [
    # Map objects (05:B488..BE52, build/agent-macbeth/macbeth-map-listing.txt): rocks ro_0..ro_5
    # (rockhard 06:85D9) and ro_6 (hard/hard180YR), rails rail_0 (nocoll) and rail_4 (trackcorner
    # 08:BF70), the train truck (truck 08:BE2C), ceiling/floor launcher miss_1_1 (nocoll) and its
    # missile miss_1_2 (woods 08:B7C1), volcano (volcano 0A:D76B) and Svolcano (firepillar 0A:DAC6).
    ('ro_0', 0xCBCC), ('ro_1', 0xCC20), ('ro_2', 0xCC74), ('ro_3', 0xCCC8), ('ro_4', 0xCD1C),
    ('ro_5', 0xCD70), ('ro_6', 0xCDFC), ('rail_0', 0xB760), ('rail_4', 0xB77C), ('truck', 0xB744),
    ('miss_1_1', 0xB7B9), ('miss_1_2', 0xB7D5), ('volcano', 0xE2FC), ('svolcano', 0xE2E0),
    # Boss boss2 08:8BBE (Spinning top): body boss_2_2 BEC8 (map), top boss_2_1 BEAC (child 1),
    # petals (children 2..5, shape table 08:9793),
    # turrets boss_2_0 BE90 (children 7, 9, 11, 13).
    ('boss_2_2', 0xBEC8), ('boss_2_1', 0xBEAC),
    *zip(('boss_2_5', 'boss_2_4', 'boss_2_3'), macbeth_petals(), strict=True),
    ('boss_2_0', 0xBE90),
]
# Billboard sprites (points 11:F0D4, texture by the header's colour table): L2smoke AE0D (boss2 state
# 0 smoke, anim 03:8814) and rockbeam B1E1 (boss2plasma 08:9799, anim 03:8707). fireball AD9D
# (volcano/firepillar shots) is already the effect FIREBALL of tools/stages/meteor_boss.py.
_EFFECTS = [('MB_L2SMOKE', 0xAE0D, 22), ('MB_ROCKBEAM', 0xB1E1, 22)]


def _catalogued_elsewhere():
    found = set()
    files = [p for p in (_ROOT / 'tools/stages').glob('*.py') if p.name < Path(__file__).name]
    files += [_ROOT / 'tools/level-shapes.py', _ROOT / 'tools/generate-level-shapes.py']
    for p in files:
        for m in re.finditer(r'0x([0-9A-Fa-f]{4})\b', p.read_text(encoding='utf-8')):
            found.add(int(m.group(1), 16))
    return found


_seen = _catalogued_elsewhere()
# M4B1ExplShapes stores WORD descriptor indices. Polygon geometry is admitted
# independently of the number of effects in the catalogue.
DRAW_MODELS = True
DRAW_ROCKBEAM = True
if DRAW_MODELS:
    SHAPES = [(n, h) for n, h in _SHAPES if h not in _seen]
    EFFECTS = []
else:
    SHAPES = []
    EFFECTS = [('MB_' + n.upper(), h, -1) for n, h in _SHAPES if h not in _seen]
# L2smoke reuses textures already in the window (39L, 08L, 41H..46H of SMOKE/LSMOKE): no window cost.
EFFECTS += [(n, h, s if (h != 0xB1E1 or DRAW_ROCKBEAM) else -1) for n, h, s in _EFFECTS if h not in _seen]
SPRITE_HEADERS = {h for _, h, s in EFFECTS if s == 22}
# Single-box colbox chains (header+8 -> 02:(addr+$4E6D)): boss_2_1 (0,-35,0) rf $13 (40,120,80) flagset 1
# and boss_2_0 (0,-168,35) rf $23 (48,40,80) flagset 1; the other headers have none (header box only).
EFFECT_COLBOXES = {h for _, h, _ in EFFECTS if h in (0xBEAC, 0xBE90)}

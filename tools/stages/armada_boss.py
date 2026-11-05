"""Space Armada boss (boss8 07:919C, map 0D:B4FB) and stage ending (05:DA3F): shapes and effects.

Loaded by tools/level-shapes.py stage_modules() and the other generators. Owner: build/agent-armada-boss/
(INTEGRATION.md). Code: src/stages/level_armada_boss.asm, src/stages/level_armada_final.asm. Headers (bank 00, USA
rev0; UltraStarFox names) from build/agent-armada/research/boss/SPEC.md section 6 and final/SPEC.md section 9:
  C574 boss_8_0 body (15 point frames: animframe 0..14), C590 boss_8_1c / C5AC boss_8_1 cover closed/open
  (18 point frames, C5AC carries the colbox chain 6C5E), C5C8 boss_8_4 pillar, C5E4 boss_8_5 beam emitter,
  C600 sparklas beam (8 frames, colbox chain 6DEA), C61C hou_4 launcher (4 frames), C638 shrap1 shrapnel,
  BF8C Shyper line (colour table 03:8004), C034 Sship_0_c falling mothership (ship0cdown), D2E8/D390/D358/
  D3C8 Bmyship black silhouettes (ClearShip2 state 1, table 06:80FD: same streams as myship, colour table
  03:807C = $3F99) and the clasteroid sprite AFE9 (texture t1B, same billboard as AF5D).

DRAW = False (previous): every polygon shape is an undrawn effect descriptor (svp -1) carrying the ROM header
box/sortz/size/shift used by explosions, view and collision. Drawing them needs 14 290 bytes of SVP program
window (vertices + point frames, tools/generate-intro-geometry.py) and the window had about 1 950 bytes left
(full build of 15/10/2026: `dcb.b $20000-*` failed by 12 336 bytes with DRAW = True). Moving the level
geometry to the SVP ROM data block is a shared change (build/agent-armada-boss/INTEGRATION.md); then set
DRAW = True (current, since the geometry moved to the SVP ROM block). The emitter's material 53 is the animated list 03:87AD (n = 8; frames 5..7 are the bytes of
03:87B8, the emitter only selects colframe 0..4): it also needs REACHABLE_FRAMES[0x87ad] = 5 in
tools/generate-intro-colours.py, detected below. The clasteroid sprite reuses the t1B texture (no SVP data).
"""
import runpy
from pathlib import Path

_ROOT = Path(__file__).resolve().parents[2]
DRAW = True

_POLY = [
    ('boss_8_0', 0xC574), ('boss_8_1c', 0xC590), ('boss_8_1', 0xC5AC), ('boss_8_4', 0xC5C8),
    ('sparklas', 0xC600), ('hou_4', 0xC61C), ('shrap1', 0xC638), ('shyper', 0xBF8C),
    ('sship_0_c', 0xC034), ('bmyship_4', 0xD2E8), ('bmyship_l', 0xD390), ('bmyship_r', 0xD358),
    ('bmyship_lr', 0xD3C8), ('boss_8_5', 0xC5E4),
]
_EMITTER_COLOURS = '0x87ad' in (_ROOT / 'tools/generate-intro-colours.py').read_text().lower()
_earlier = set()
for _f in sorted((_ROOT / 'tools/stages').glob('*.py')):
    if _f.name >= 'armada_boss.py':
        continue
    _earlier |= {h for _, h in runpy.run_path(str(_f)).get('SHAPES', [])}
_drawn = [(n, h) for n, h in _POLY if DRAW and (h != 0xC5E4 or _EMITTER_COLOURS)]
SHAPES = [(n, h) for n, h in _drawn if h not in _earlier]
EFFECTS = [('AB_' + n.upper(), h, -1) for n, h in _POLY if (n, h) not in _drawn and h not in _earlier]
EFFECTS.append(('AB_CLASTEROID', 0xAFE9, 22))
SPRITE_HEADERS = {0xAFE9}
# Colbox chains of the open cover C5AC (2 boxes, rotflags 3) and of the beam C600 (2 boxes, rotflags 3/$23):
# emitted for the effect descriptors too (tools/generate-level-shapes.py EFFECT_COLBOXES).
EFFECT_COLBOXES = {0xC5AC, 0xC600}

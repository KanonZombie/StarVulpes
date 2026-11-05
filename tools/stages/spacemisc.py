"""Stage unit `spacemisc`: Asteroid Belt 3 (map 0D:E5F6), Black Hole (0D:C8A9) and Out of This Dimension (0D:C8E5).

Owner: build/agent-spacemisc/ (SPACEMISC.md). Strategies: src/stages/level_spacemisc.asm, which finds every shape by its
ROM header (M4LevelShapeIndex), so a drawn shape added later with the same header replaces the effect without
touching the strategies. Headers read from ref/Star Fox (USA).sfc (rev0, SHA-256 3857b529...a84d); names
UltraStarFox where it has one. Survey: build/agent-spacemisc/shape-survey.py (headers reached by the three maps,
their mother scripts, paths, the random-enemy table 09:F923 and this unit's strategies).

Drawn shapes (SHAPES, SVP models): every polygon model below fits the per-model limit (<= 85 vertices) and the SVP
cmd9 register (<= 64 vertices / 64 visibility entries per object, |coord| < 16384 after the shift;
build/agent-macbeth/shape-check.py: at most 58 vertices, 42 visibility entries, |coord| <= 400). The model geometry
lives in the SVP ROM block (build/svp-geo-rom.inc), not in the program window. Effects (svp -1, never drawn, the
descriptor carries the ROM header box, sortz, size and sh_shift for collision, z-remove and explosions): the sprites
B059 / B18D (points 11:F0xx, textures not converted) and paper_1 DCA4, whose point stream the model decoder does
not delimit (tools/recover-intro-model.py assertion; build/agent-spacemisc/SPACEMISC.md). DRAW_MODELS = False turns
every model back into an effect.

Headers already catalogued by tools/level-shapes.py or by a stage module that sorts before this one are skipped
with a text scan (no runpy of other stage modules), as tools/stages/macbeth.py does.
"""
import re
from pathlib import Path

_ROOT = Path(__file__).resolve().parents[2]

_EFFECTS = [  # (name, header): drawn when DRAW_MODELS unless in _NOT_MODELS
    # Asteroid 3: meteo0 0A:DD08 (map 05:F54B.., mother 05:D7B1), boss webmonster 09:D77F: body boss_0_1
    # CA7C, legs CA98 (09:DF4D, children 1..6), web CA44 / CA60 closed (09:DA75, child 7), net CAB4 (09:DD83).
    ('meteo_0', 0xBBB8), ('boss_0_1', 0xCA7C), ('web_leg', 0xCA98), ('web', 0xCA44), ('web_closed', 0xCA60),
    ('web_net', 0xCAB4),
    # Asteroid 3 OOTD trigger: big_meteor path 0176 spawns B059 (path 01D0) and the bird BC60 (path 01F4) with
    # its wings BA47 / BA63 (spawnchild 1 / 2).
    ('bird_gate', 0xB059), ('bird_ootd', 0xBC60), ('bird_wing_l', 0xBA47), ('bird_wing_r', 0xBA63),
    # Random path enemies 09:F901 (table 09:F923) without a descriptor yet.
    ('rnd_b983', 0xB983), ('rnd_e5f0', 0xE5F0),
    # Black Hole: amoeba 0A:9F67 once stuck to the ship (0A:A033).
    ('amoeba_stuck', 0xB18D),
    # Out of This Dimension: paper planes paper_1 / paper_3 (pathdha 390A / 3A40 / 39A4), the slot machine
    # slot_0 BD08 (path 3B8B), the THE END letters (0A:938E..96B3): upright sword1 / tilted sword2 shapes.
    ('paper_1', 0xDCA4), ('paper_3', 0xDC88), ('slot_0', 0xBD08),
    ('font_t', 0xE804), ('font_t2', 0xE820), ('font_h', 0xE874), ('font_h2', 0xE890), ('font_e', 0xE7B0),
    ('font_e2', 0xE7CC), ('font_e3', 0xE7E8), ('font_n', 0xE83C), ('font_n2', 0xE858), ('font_d', 0xC8F4),
    ('font_d2', 0xC910),
]


def _catalogued_elsewhere():
    found = set()
    files = [p for p in (_ROOT / 'tools/stages').glob('*.py') if p.name < Path(__file__).name]
    files += [_ROOT / 'tools/level-shapes.py', _ROOT / 'tools/generate-level-shapes.py']
    for p in files:
        for m in re.finditer(r'0x([0-9A-Fa-f]{4})\b', p.read_text(encoding='utf-8')):
            found.add(int(m.group(1), 16))
    return found


_NOT_MODELS = {0xB059, 0xB18D, 0xDCA4, 0xDC88, 0xCA44}  # sprites; DCA4 undecodable; DC88 colour lists with DD20 frames; CA44 frame-dependent colbox chain (INTEGRATION.md)
_seen = _catalogued_elsewhere()
DRAW_MODELS = False  # True once level_boss1.asm M4B1ExplShapes is dc.w (INTEGRATION.md section 3)
if DRAW_MODELS:
    SHAPES = [('sm_' + n, h) for n, h in _EFFECTS if h not in _seen and h not in _NOT_MODELS]
    EFFECTS = [('SM_' + n.upper(), h, -1) for n, h in _EFFECTS if h not in _seen and h in _NOT_MODELS]
else:
    SHAPES = []
    EFFECTS = [('SM_' + n.upper(), h, -1) for n, h in _EFFECTS if h not in _seen]
# Textured materials of the drawn models (tools/generate-svp-texpoly.py CASE_WORDS): meteo_0 BBB8 material 48
# ($401B) and slot_0 BD08 material 106 ($400C), colour table 03:8213.
TEX_WORDS = [0x401B, 0x400C] if DRAW_MODELS else []

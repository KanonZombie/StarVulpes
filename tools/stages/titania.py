"""Titania (map 0D:DFA7, route 2 stage 3) and Fortuna (map 0D:E651, route 3 stage 3): shapes, sprites and
effects of the stage unit (strategies: src/stages/level_titania.asm; build/agent-titania/TITANIA.md).

Loaded by tools/level-shapes.py stage_modules() and the other generators. Headers: the shapes seen on
live objects by the ROM surveys of both maps (build/agent-titania/rom-survey.py, survey-*.json) and the
ones the ported strategies set. Every model was decoded from the selected ROM with
tools/recover-intro-model.py and checked against the cmd9 register (<= 64 vertices, <= 64 visibilities,
|coord| < 16384, all frames): build/agent-titania/shape-check.py. Names: UltraStarFox SHAPES where
tools/inventory-levels.py resolves them, else the header.

The 68000 code finds every shape by its ROM header (M4LevelShapeIndex), so a header catalogued by an
earlier stage module is skipped here (same pattern as tools/stages/meteor.py).
"""
import runpy
from pathlib import Path

_ROOT = Path(__file__).resolve().parents[2]

_SHAPES = [
    # Titania 2_3a: rocks bro_0..6 (rockhard / hard180YR), islands clisla_s/m/l, weather unit CFBC and
    # its propellers CFD8/CFF4 (path 1AAE), misstank m_tank B7F1 and its missile small_m B4BE, base
    # entrance kichi_0 CB24 / kichi_1 CB40 (massivebase), tunnel pieces kichi_3 CB78 and doors k_door
    # CBB0 (kichi2 / kdoor).
    ('bro_0', 0xCBE8), ('bro_1', 0xCC3C), ('bro_2', 0xCC90), ('bro_3', 0xCCE4), ('bro_4', 0xCD38),
    ('bro_5', 0xCD8C), ('bro_6', 0xCE18), ('clisla_s', 0xE44C), ('clisla_m', 0xE430), ('clisla_l', 0xE414),
    ('ti_CFBC', 0xCFBC), ('ti_CFD8', 0xCFD8), ('ti_CFF4', 0xCFF4), ('m_tank', 0xB7F1), ('small_m', 0xB4BE),
    ('kichi_0', 0xCB24), ('kichi_1', 0xCB40), ('kichi_3', 0xCB78), ('k_door', 0xCBB0),
    # Titania 2_3b/2_3c: sea monster sea_0_0 B680 and its frames B65F/B69C (0A:F2B3), flying fish CE50
    # (torpedo 08:C821), bossg shadow boss_g_s D17C. The bossg spark B2C1 (sgenspark 0B:AC5E) is the
    # effect M4_FX_V3_B2C1 of tools/stages/venom23.py (found by header).
    ('sea_0_0', 0xB680), ('ti_B65F', 0xB65F), ('ti_B69C', 0xB69C), ('f_fish', 0xCE50), ('ti_D17C', 0xD17C),
    # Fortuna map3_3a: bees beeanim B465, stalk CEA4 and the sprout pieces, flowers flower_1/2, the
    # sea dragon snake_1 CEDC and the dragon f_dragon DF44, chicken boss boss_d_* and its pieces.
    ('beeanim', 0xB465), ('stalk', 0xCEA4), ('ti_CE6C', 0xCE6C), ('ti_CE88', 0xCE88), ('ti_CEC0', 0xCEC0),
    ('snake_1', 0xCEDC), ('ti_CEF8', 0xCEF8), ('flower_1', 0xCF4C), ('flower_2', 0xCF68), ('ti_CF84', 0xCF84),
    ('ti_CFA0', 0xCFA0), ('f_dragon', 0xDF44), ('ti_B983', 0xB983),
    ('boss_d_1', 0xB99F), ('ti_B9BB', 0xB9BB), ('boss_d_4', 0xB9D7), ('ti_BA0F', 0xBA0F), ('ti_BA2B', 0xBA2B),
    ('ti_BA47', 0xBA47), ('ti_BA63', 0xBA63),
]
_earlier = set()
for _f in sorted((_ROOT / 'tools/stages').glob('*.py')):
    if _f.name >= 'titania.py':
        continue
    _m = runpy.run_path(str(_f))
    _earlier |= {h for _, h in _m.get('SHAPES', [])} | {h for _, h, _ in _m.get('EFFECTS', [])}
SHAPES = [(n, h) for n, h in _SHAPES if h not in _earlier]

# Effects: descriptors with the ROM header box (collision, z-remove, explosion class).
#  - sprites (mssprite, billboard svp 22): splash makeSsplash AEB5 / makesplash AED1 (06:8C1A/8C31,
#    anim 03:88BF), explosion5 B171 (bossgexplode 04:F32E, anim 03:8851), Fortuna AD2D (anim 03:875C)
#    and B059 (texture word $40AA);
#  - not drawn (svp -1): D87C (pathdha clouds of 2_3a: its point stream uses opcode 8, not decoded by
#    tools/recover-intro-model.py), bossg boss_g_0 CB94 (69 vertices > the cmd9 register's 64), and
#    three models whose colbox chain tools/generate-level-shapes.py does not accept (the effect keeps the
#    header box only; drawing and the exact colboxes PEND, TITANIA.md): base_0 E794 (base1: one box then
#    a 16-frame animated list) and the chicken pieces B913 / B967 (rotx/rotxyz colboxes).
_EFFECTS = [('TI_SSPLASH', 0xAEB5, 22), ('TI_EXPLOSION5', 0xB171, 22), ('TI_SPLASH', 0xAED1, 22), ('TI_AD2D', 0xAD2D, 22),
            ('TI_B059', 0xB059, 22), ('TI_D87C', 0xD87C, -1), ('TI_BOSS_G_0', 0xCB94, -1),
            ('TI_BASE_0', 0xE794, -1), ('TI_B913', 0xB913, -1), ('TI_B967', 0xB967, -1)]
EFFECTS = [(n, h, s) for n, h, s in _EFFECTS if h not in _earlier]
SPRITE_HEADERS = {h for _, h, s in EFFECTS if s == 22}

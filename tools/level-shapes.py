"""Level shape catalog: selected-ROM shape headers used by the Corneria port.

Order defines the 68000 shape index (M4LevelShapeDescriptors) and the SVP
model ids of new geometry (23.. after the intro models and level effects). Shapes whose point
and face streams are identical to an intro model reuse that SVP model.
Sources: build/research/corneria1-level.md (script decode, totals.shapes),
player_shapes 06:80D5 entry0 (D320/D3AC/D374/D3E4), ELASER header 00:B369.
nullshape 00:ACA1 has no geometry: objects using it are never drawn.
"""
import runpy
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
NULLSHAPE = 0xaca1
SHAPES = [
    # Player ship (normal / left wing broken / right / both), player laser.
    ('myship_4', 0xd320), ('myship_l', 0xd3ac), ('myship_r', 0xd374), ('myship_lr', 0xd3e4),
    ('p_laser', 0xb369),
    # Corneria 1 map1_1b and level1_1 objects (static decode of the script).
    ('bu_1', 0xc964), ('bu_4', 0xd41c), ('bu_0', 0xc92c), ('bu_6', 0xd454), ('bu_5', 0xd438),
    ('pillar3', 0xb84a), ('zaco_5', 0xc22c), ('r_bu_1', 0xd844), ('zaco_a', 0xe388),
    ('friendship_4', 0xd33c), ('bu_2', 0xdd4c), ('arch_0', 0xc868), ('bom_wing', 0xc53c),
    ('tower_2', 0xc424), ('tow_0', 0xdc6c), ('walker_2', 0xe2c4), ('bu_7', 0xd470),
    ('zaco_6', 0xc2f0), ('kamikaze', 0xb70c), ('bu_8', 0xc948), ('robot_0', 0xbb9c),
    ('gate_0', 0xb8bf), ('rader_0', 0xc3ec), ('rader_1', 0xc408), ('big_gate', 0xbad8),
    ('item_7', 0xc478), ('item_5', 0xc494), ('carrier', 0xe6d0), ('boss_7_1', 0xc264),
    # Created by strategies: gate_2 (explode_Istrat 06:F45F, special), repair
    # wing (item7 08:DDEC).
    ('gate_2', 0xe4d8), ('item_wing', 0xc4cc),
    # Boss boss7 07:CF7C (build/research/corneria-boss.md): open body, hatch,
    # shield, upper/lower launchers and the launchers' HMISSILE (06:B0DE).
    ('boss_7_1o', 0xc280), ('boss_7_0', 0xc248), ('boss_7_2', 0xc29c), ('boss_7_3', 0xc2b8),
    ('boss_7_4', 0xc2d4), ('hmissile', 0xbabc),
    # SCRAMBLE and ExitBase (build/research/corneria-scramble.md section 5):
    # tunnel pieces op_0/op_1/op_2 (map1_1a 0D:8000), imyship_4 (= myship_4
    # streams, sortz 500: player and wingmen in the tunnel), base mybase_1 and
    # mybase_0 (0D:D11D).
    ('op_0', 0xbb48), ('op_1', 0xbb64), ('op_2', 0xbb80), ('imyship_4', 0xd304),
    ('mybase_1', 0xdda0), ('mybase_0', 0xdd84),
    # Controls screen (briefing_l 1F:F9CD, playeroncont 0B:BADF): my_demoS.
    ('my_demos', 0xbcb4),
    # Game over (gameoverinit_l 06:BBDA): the 3D words GAME and OVER.
    ('gamesh', 0xb235), ('oversh', 0xb251),
    # Training (build/research/training.md section 4): ring, pilon, MY_W
    # formation marker.
    ('training', 0xbd40), ('pilon', 0xdd30), ('my_w', 0xc360),
    # Asteroid Belt 1 (build/research/stage-asteroid1.md section 4): worm
    # body/head, turrets b/r/s_hou_0 (same streams, own colour tables),
    # cameleon, szaco2/szaco0 and their debris, tadpole (12 frames), zaco_b,
    # shield bird E660 (17 frames), boss1 core, Warp trail.
    ('d_body_0', 0xb61d), ('d_head_0', 0xb601), ('b_hou_0', 0xe28c), ('r_hou_0', 0xe254),
    ('s_hou_0', 0xe270), ('cameleon', 0xb643), ('zaco_8', 0xc30c), ('tadpole', 0xc84c),
    ('zaco_b', 0xe36c), ('zaco_4', 0xd924), ('bird', 0xe660), ('boss_1_core', 0xbe3c),
    ('zaco_4d', 0xd940), ('zaco_8d', 0xc344), ('warp_trail', 0xbf70),
    # Cockpit transitions (space-player-cockpit.md section 1.4; 06:80D5 entry
    # 6 in this order: no broken wing, left, right, both): Arwing at x16 and
    # the canopy D748.
    ('zoom_4', 0xdd68), ('zoom_l', 0xd7b8), ('zoom_r', 0xd79c), ('zoom_lr', 0xd780), ('cockpit', 0xd748),
    # Asteroid Belt 1 textured quads (stage-asteroid1.md section 4): big_meteor
    # AFCD (00:FA62, one face, coltab 03:857D word $46D3 = t53) and the szaco0
    # escapee B26D [H name] (06:F181, two faces, coltab 03:854E $40DF = t5F).
    # Both read the points 11:F05B, stored AFTER/BEFORE their faces.
    ('big_meteor', 0xafcd), ('escapee', 0xb26d),
    # Asteroid Belt 1 boss boss1 08:816E (build/agent-boss1/BOSS1.md): body
    # boss_1_2 BE74 (0E:88D7/891B: two 7-vertex faces, material 54) and the
    # eight capsules BE58 (0E:887A/8891, material 54); colour table 03:8213.
    ('boss_1_2', 0xbe74), ('boss_1_1', 0xbe58),
    # Enemy weapon projectile (build/agent-weapons/WEAPONS.md): chickhmissile1
    # 06:B2B2 make_obj c_miss E334 (UltraStarFox name). kamiHmissile1's zaco_9
    # C7DC is an effect descriptor (textured material 57, $40AC).
    ('c_miss', 0xe334),
    # kamiHmissile1 06:B240 (build/agent-weapons/WEAPONS.md): zaco_9, textured
    # material 57 ($40AC, svp-texpoly).
    ('zaco_9', 0xc7dc),
]
# Headers whose point stream is not immediately followed by their faces: the
# point stream is bounded by its own end opcode 12 (same decoder otherwise).
OWN_POINT_END = {0xafcd, 0xb26d, 0xac4d}
def stage_modules():
    """Per-stage extensions tools/stages/*.py (sorted by file name): optional
    SHAPES [(name, header)], EFFECTS [(NAME, header, svp)], SPRITE_HEADERS
    {header}, COLTAB_SPRITES [(coltab, header)], TEX_WORDS [word]. Each stage
    unit owns its file, so parallel work does not edit the shared lists."""
    import runpy as _runpy
    out = []
    for f in sorted((ROOT / 'tools/stages').glob('*.py')):
        out.append(_runpy.run_path(str(f)))
    return out


for _m in stage_modules():
    SHAPES += list(_m.get('SHAPES', []))

# Route-1 strategies still use some historical M4_FX_* descriptor names.
# Recover their real polygon geometry too; generate-level-shapes redirects
# those aliases to the same drawn descriptor, not a second invisible object.
ROUTE1 = runpy.run_path(str(ROOT / 'tools/route1-catalog.py'))
ROUTE1_ADDED = ROUTE1['additions'](SHAPES)
SHAPES += ROUTE1_ADDED


# Every level shape gets its own SVP model (id 23+index), even when its point
# and face streams equal an intro model: the intro mesh code special-cases ids.
INTRO_MODELS = {}
FIRST_LEVEL_MODEL = 23


def _recover(rom, header):
    if header == 0xb369:
        return runpy.run_path(str(ROOT / 'tools/recover-intro-weapons.py'))['laser_model'](rom)
    recover = runpy.run_path(str(ROOT / 'tools/recover-intro-model.py'))['recover']
    if header in OWN_POINT_END:
        frames = recover.__globals__['point_frames']

        def own_end(rom_, start, end, shift):
            p = start
            while rom_[p] in (4, 56):          # plain point lists only (no frames)
                p += 2 + 3 * rom_[p + 1]
            assert rom_[p] == 12, (hex(header), hex(p))
            return frames(rom_, start, p + 1, shift)
        recover.__globals__['point_frames'] = own_end
    return recover(rom, header - 0x8000)


def catalog(rom):
    out, next_model = [], FIRST_LEVEL_MODEL
    for index, (name, header) in enumerate(SHAPES):
        model = _recover(rom, header)
        if header in INTRO_MODELS:
            svp = INTRO_MODELS[header]
        else:
            svp, next_model = next_model, next_model + 1
        out.append(dict(index=index, name=name, header=header, svp_model=svp, model=model,
                        new_geometry=header not in INTRO_MODELS))
    return out


def geometry_models(rom):
    return [('Level_' + e['name'], e['model']) for e in catalog(rom) if e['new_geometry']]


def index_of(header):
    for i, (_, h) in enumerate(SHAPES):
        if h == header:
            return i
    return None

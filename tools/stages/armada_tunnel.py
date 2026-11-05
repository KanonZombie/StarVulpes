"""Space Armada (map 0D:D2C3, route 1 stage 3): fleet, ship interiors/tunnels, corridor and pipe.

Owner: build/agent-armada-fleet/ (FLEET.md). Strategies: src/stages/level_armada_fleet.asm (fleet) and
src/stages/level_armada_tunnel.asm (interiors). Headers that the catalog can convert (build/agent-armada-fleet/
shape-check.py: model recovery, colour tables, colbox layout, <= 64 vertices for cmd9) are drawn SHAPES;
the others stay effects (svp -1, never drawn: the descriptor carries the ROM header box, sortz, size,
sh_shift used by collision, z-remove and explode_Istrat). The 68000 code finds every shape by its ROM
header (M4LevelShapeIndex), so moving a header between both lists does not touch the strategies. Headers read from ref/Star Fox (USA).sfc
(rev0, SHA-256 3857b529...a84d); names UltraStarFox. Uses: build/research/stage-armada.md (fleet annex
section 0) and build/agent-armada/research/tunnel/SPEC.md section 4. Boss (0D:B4FB..) and ending
(05:DA3F..) shapes belong to the armada-boss unit. Headers already catalogued by another module (any
file of tools/stages/ or tools/level-shapes.py / generate-level-shapes.py) are skipped (text scan: no
runpy of other stage modules, which would recurse).
"""
import re
from pathlib import Path

_ROOT = Path(__file__).resolve().parents[2]

_EFFECTS = [
    # Fleet (stage-armada.md annex, section 0)
    ('AR_SHIPS', 0xDA04),        # ships 0A:B304
    ('AR_SHIP_S_0', 0xBB2C),     # ships 0A:B304
    ('AR_SHIP_S_1', 0xDDBC),     # ships 0A:B304
    ('AR_SHIP_1', 0xC7C0),       # ship1a 08:A386 (2 boxes: HF1 hull, HF2 weak point)
    ('AR_SHIP_3', 0xC018),       # ship2 08:9E1F
    ('AR_S_DOOR_1', 0xDA3C),     # sdoor1 0A:B50A
    ('AR_S_DOOR_2', 0xDA74),     # sdoor2 0A:B5FD
    ('AR_SHIP_0_C', 0xC050),     # ship3 08:A035
    ('AR_SSHIP_0_C', 0xC034),    # ship3a 0A:CC0D
    ('AR_SHIP_4', 0xDDD8),       # cruiser1/cruiser1F 0A:B721/B727
    ('AR_SHIP_5S', 0xD9B0),      # cruiser2 0A:B01C
    ('AR_SHIP_5M', 0xD994),      # cruiser2 0A:B01C
    ('AR_SHIP_5', 0xD95C),       # cruiser2fire 0A:AF28
    ('AR_HOU_3', 0xD9E8),        # cruiser2fire launchers 0A:B0E1
    ('AR_ZACO7_DEBRIS', 0xDAAC), # szaco5 debrisshape (explode_Istrat 06:F1DA)
    ('AR_SMOKE_AE29', 0xAE29),   # ship1a smoke shape (08:A3D3)
    ('AR_S_ZACO_0', 0xDB70),     # path enemies (pathdha 04:8004) of the fleet
    # Interiors (tunnel SPEC section 4)
    ('AR_OPEN_L', 0xBB10),       # openlr 0A:F0EC
    ('AR_UP_DOOR', 0xD198),      # updoor 0A:F17D (animated rf $11 boxes: not emitted)
    ('AR_BOU_0', 0xDCC0),        # twall0 0A:BB1F
    ('AR_WARKER_3', 0xDE2C),     # warker3 0A:BBFA
    ('AR_S_WARK_0', 0xDB8C),     # warker3 0A:BBFA (map shape)
    ('AR_LENG_0', 0xDB1C),       # leng0 0A:B69C (3 boxes)
    ('AR_IRIS', 0xBDE8),         # iris 09:9529 (chained animated boxes: not emitted)
    ('AR_IRIS_RES', 0xB8F7),     # iris child reservation (overwritten at once)
    ('AR_IRIS_CHILD', 0xC8BC),   # iris child 00:FACF
    ('AR_ITEM_6', 0xC4B0),       # item6 08:D5F0
    ('AR_CORE_1_0', 0xC6E0),     # core0 08:A258 (2 boxes)
    ('AR_CORE_1_1', 0xC6FC),     # core1 08:A299 (1 box)
    ('AR_EXIT_2', 0xC718),       # exit 08:F145
    ('AR_MWIREEXIT', 0xC0DC),    # nocoll (mtunnelexit)
    ('AR_BMTUNNELFACE', 0xC130), # gnd (mtunnelexit)
    ('AR_MEXITFACE', 0xC168),    # exitopen/exitopensnd 08:F206/F200
    ('AR_MBLACKFACE', 0xC1D8),   # nocoll (mtunnelexit)
    ('AR_BSHIPEXITFACE', 0xC1A0),  # exitopensnd2 08:F1F7
    ('AR_WALL_0', 0xD630),       # hard180YR
    ('AR_WALL_5', 0xD6BC),       # hard180YR
    # Corridor and pipe (0D:D34C..D576)
    ('AR_C8D8', 0xC8D8),         # nocoll
    ('AR_COLONYEXIT', 0xE5D4),   # colonyexit 0A:F235
    ('AR_PIPE_D1B4', 0xD1B4), ('AR_PIPE_D1D0', 0xD1D0), ('AR_PIPE_D1EC', 0xD1EC),
    ('AR_PIPE_D208', 0xD208), ('AR_PIPE_D224', 0xD224), ('AR_PIPE_D240', 0xD240),
]

# Static single-box colbox chains (generate-level-shapes.py: no animated records).
_COLBOXES = {0xC7C0, 0xC6E0, 0xC6FC, 0xDB1C}


def _catalogued_elsewhere():
    found = set()
    files = [p for p in (_ROOT / 'tools/stages').glob('*.py') if p.name != Path(__file__).name]
    files += [_ROOT / 'tools/level-shapes.py', _ROOT / 'tools/generate-level-shapes.py']
    for p in files:
        for m in re.finditer(r'0x([0-9A-Fa-f]{4})\b', p.read_text(encoding='utf-8')):
            found.add(int(m.group(1), 16))
    return found


# Not convertible (shape-check.py): AE29 smoke (point stream), DCC0 bou_0 (textured material 107 $400D),
# B8F7 (rotx colbox; reservation only), C0DC/C130/C1D8 (16-bit point lists, op 08). up_door D198 (10-frame
# animated colbox) and iris BDE8 (4 chained 8-frame lists) are SHAPES since generate-level-shapes.py emits
# those lists (MIXED_ANIMATED_COLBOX layout).
_EFFECT_ONLY = {0xAE29, 0xDCC0, 0xB8F7, 0xC0DC, 0xC130, 0xC1D8}
_seen = _catalogued_elsewhere()
SHAPES = [(n.lower(), h) for n, h in _EFFECTS if h not in _seen and h not in _EFFECT_ONLY]
EFFECTS = [(n, h, 4 if h == 0xAE29 else -1) for n, h in _EFFECTS if h not in _seen and h in _EFFECT_ONLY]
SPRITE_HEADERS = {0xAE29}  # same point/face/colour pointers as ADD5; original size 320, shift 5
EFFECT_COLBOXES = {h for _, h, _ in EFFECTS if h in _COLBOXES}

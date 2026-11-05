"""Player modes (bank-0B player strategies): newplayerstrat Istrats and shapes of the player-modes unit.

Port: src/stages/level_armada_player.asm (M4Pm*); documentation build/agent-player-modes/PLAYER-MODES.md; oracle
build/agent-player-modes/pm-compare.py. Loaded by tools/convert-level-backgrounds.py (PSTRATS) and
tools/level-shapes.py stage_modules() (SHAPES).

PSTRATS: newplayerstrat ($1788) of the background routines -> port Istrat (same pass as the ROM's Istrat).
SHAPES: WarpOut trail shapes of the generator 0B:8B38 (table 0B:8B90); BF70 is already `warp_trail`.
"""
import runpy
from pathlib import Path

_ROOT = Path(__file__).resolve().parents[2]

PSTRATS = {
    0x0B8975: ('playerwarpout', 'M4PmWarpOutI'),
    0x0BC03A: ('playerinstunnel', 'M4PmSTunnelI'),
    0x0BC10C: ('playerinmtunnel', 'M4PmMTunnelI'),
    0x0BC1DE: ('playerinLtunnel', 'M4PmLTunnelI'),
    0x0BC52E: ('playerinLTexit', 'M4PmLTexitI'),
    0x0BAA79: ('playerwashent', 'M4PmWashentI'),
    0x0BC699: ('playerinnucleus', 'M4PmNucleusI'),
    0x0B9AE1: ('playerclearship2', 'M4PmClearShip2I'),
    0x0B822A: ('playerspaceflyin', 'M4PmSpaceFlyinI'),
    0x0B86F1: ('playercolonyflyin', 'M4PmColonyFlyinI'),
    0x0B8D1E: ('playerdivegnd', 'M4PmDiveGndI'),
    0x0BAA30: ('playerclearcolony', 'M4PmClearColonyI'),
    0x0BB566: ('playercred', 'M4PmCredI'),
    0x0BBC25: ('playerundergnd', 'M4PmUnderGndI'),
    0x0BBE5E: ('playeronbridge', 'M4PmOnBridgeI'),
    0x0BD05E: ('playernull', 'M4PmNull'),
}

_SHAPES = [('warp_trail_1', 0xBFA8), ('warp_trail_2', 0xBFC4), ('warp_trail_3', 0xBFE0)]
_earlier = set()
for _f in sorted((_ROOT / 'tools/stages').glob('*.py')):
    if _f.name >= 'player_modes.py':
        continue
    _earlier |= {h for _, h in runpy.run_path(str(_f)).get('SHAPES', [])}
SHAPES = [(n, h) for n, h in _SHAPES if h not in _earlier]

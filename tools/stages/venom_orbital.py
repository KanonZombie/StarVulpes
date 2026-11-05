"""Venom 1 unit `orbital` (map 05:E1F1.., route 1): effect descriptors of its shapes.

Owner: build/agent-venom/orbital/ORBITAL.md. No drawn geometry (svp -1): the descriptors carry the ROM header
box (xmax/ymax/zmax), sortz, sh_size and sh_shift used by collision, z-remove and explode_Istrat 06:F45F.
src/stages/level_venom_orbital.asm uses local aliases (M4VoSh*) of these equates, or finds them by ROM header
(M4LevelShapeIndex) for map-created objects. Headers read from ref/Star Fox (USA).sfc (rev0); names UltraStarFox.
"""
EFFECTS = [
    ('VO_UPER_M', 0xDE9C, -1),     # uperM 0A:C24B (map and mother script 05:570D)
    ('VO_WARP', 0xDEB8, -1),       # warp 0A:C359; the ordered table is read from 0A:C66F
    ('VO_WARP_1', 0xDED4, -1),
    ('VO_WARP_2', 0xDEF0, -1),
    ('VO_WARP_3', 0xDF0C, -1),
    ('VO_BIG_M', 0xB4DA, -1),      # misspod 08:E602
    ('VO_ROUND_0', 0xBDCC, -1),    # windmill 08:EBB2
    ('VO_ROUND0P', 0xE4BC, -1),    # windmill pieces (windexp 08:ECFC -> windspin 08:EFF6)
    ('VO_BAZOOKA', 0xDE48, -1),    # bazookaL/R 0A:BF4D/BF53
    ('VO_BAZOOKA1', 0xDE64, -1),   # bazooka debrisshape ($1CE4), explode_Istrat debris pieces
    ('VO_BAZOOKA2', 0xDE80, -1),   # bazooka sword1: falling part (bazexp 0A:C1C1 -> bazfall 0A:C1F9)
    ('VO_W_L', 0xC45C, -1),        # winglazerman 08:DB39 (port: level_armada_fleet.asm)
    ('VO_MINE', 0xB80D, -1),       # mine 09:9660 (nobj 05:E412..E474)
    # Other headers of the orbital script without a catalogued shape: path enemies zaco_1 DBC4 and bzaco_8 C328
    # (pathdha 04:8004, z-remove box) and the generator AE99 (mapmother; zero box, mapremove matches it).
    ('VO_ZACO_1', 0xDBC4, -1),
    ('VO_BZACO_8', 0xC328, -1),
    ('VO_MOTHER', 0xAE99, -1),
]

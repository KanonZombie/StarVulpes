"""Venom 1 unit `planet` (surface 0D:BC57.. and final tunnel 0D:D726..DAB4, exit 0D:CDA3).

Owner: build/agent-venom/planet/PLANET.md. Strategies: src/stages/level_venom_planet.asm.
Effects only (svp -1, never drawn): the descriptor carries the ROM header box (xmax/ymax/zmax,
sortz, size, sh_shift) used by collision, z-remove and explosions. The 68000 code finds every
shape by its ROM header (M4LevelShapeIndex), so a drawn shape added later with the same header
replaces the effect without touching the strategies. Drawing still pending: see PLANET.md.
hou_5 E778 (houdai5f) is already a drawn shape (tools/stages/meteor.py).
"""
EFFECTS = [
    ('VP_XSOLIDSPACEBAR', 0xDF98, -1),   # spacebarshoot 0A:D567 (map)
    ('VP_YSOLIDSPACEBAR', 0xE040, -1),   # spacebarshoot 0A:D567 (map)
    ('VP_WALL1', 0xB4FB, -1),            # walll/wallr 09:9171/917A (map)
    ('VP_WALL_L', 0xB533, -1),           # walll/wallr open left (09:9231)
    ('VP_WALL_R', 0xB54F, -1),           # walll/wallr open right (09:925D)
    ('VP_FLYPILLAR', 0xB866, -1),        # flypillars 08:D075 (map), flypillar 08:D0A5 (mother 05:53B5)
    ('VP_PILLAR2', 0xB449, -1),          # pillar2 09:97B7 (mother 05:533B)
    ('VP_TUNNEL_0', 0xCAEC, -1),         # topright1/topleft1/botleft1/botright1 09:F72B..F74F
    ('VP_TUNPILLAR_A', 0xDBE0, -1),      # 0A:F65E (map nobj)
    ('VP_TUNPILLAR_B', 0xDBFC, -1),      # 0A:F65E (map nobj)
    ('VP_EXIT_1', 0xC0A4, -1),           # exit 08:F145
    ('VP_EXITLIGHT', 0xC0F8, -1),        # exitlight3..6 08:F18B.., nocoll (0D:CE72..)
    ('VP_EXITFACE', 0xC14C, -1),         # exitopen/exitopensnd 08:F206/F200
    ('VP_LAST_B_3', 0xD048, -1),         # nocollanim0 06:8738 (final), lseqdoor2 06:D30B
    # Objects of the same map ranges created by strategies already ported (hard 06:8599, hard180YR
    # 06:85B9, path 04:8022, gnd 08:F15D, nocoll 06:873F) whose header was not catalogued: without a
    # descriptor they were nullshape (no box for collision / z-remove).
    ('VP_R_BU_4', 0xD8B4, -1), ('VP_R_BU_7', 0xD908, -1), ('VP_R_BU_0', 0xD828, -1),
    ('VP_R_BU_2', 0xD860, -1), ('VP_WALL_2', 0xD668, -1), ('VP_WALL_4', 0xD6A0, -1),
    ('VP_DCDC', 0xDCDC, -1),             # hard180YR in the tunnel (0D:DA0C), no USF name
    ('VP_BLTUNNELFACE', 0xC114, -1),     # gnd, tunnel exit 0D:CEAD
    ('VP_LWIREEXIT', 0xC0C0, -1),        # nocoll, tunnel exit 0D:CEA2
    ('VP_LBLACKFACE', 0xC1BC, -1),       # nocoll, tunnel exit 0D:CF13
]

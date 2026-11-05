"""Venom 1 escape unit (0D:DB46 .. 0D:DD4C): shapes without drawing and player modes.

Owner: build/agent-venom/escape/ESCAPE.md. Loaded by every generator (tools/level-shapes.py stage_modules()).
EFFECTS (svp -1: not drawn) carry the ROM header box/sortz/size/shift used by z-remove and collisions;
src/stages/level_venom_escape.asm reaches them through M4_FX_VE_* aliases and finds map objects by header.
PSTRATS: newplayerstrat of the backgrounds $6F (1_7a), $75 (1_7b) and $7B (1_7c) -> port Istrats.
"""
EFFECTS = [
    ('VE_DOOR_L', 0xD064, -1),      # lseqdoor1 06:D2A5 (map 0D:DB86)
    ('VE_LAST_B_0', 0xD010, -1),    # gnd 08:F15D (map 0D:DBEC), removed by pshipoutofLB1 state 3
    ('VE_LAST_B_2', 0xD02C, -1),    # nocoll 06:873F (map 0D:DB90)
    ('VE_LAST_B_3', 0xD048, -1),    # nocollanim0 06:8738 (0D:DB9B) and lseqdoor2 06:D30B (0D:DBFB)
    ('VE_MY_DEMO', 0xBCD0, -1),     # pshipoutofLB3 06:DB45 / shipoutofLB3 06:D9C9
    ('VE_MY_DEMOBS', 0xBC98, -1),   # pshipoutofLB1 state 1 (06:D4FA)
    ('VE_SHRAP1', 0xC638, -1),      # shrapnel_srou 0B:A7DE
]
PSTRATS = {0x0BA535: ('playerOutofLB1', 'M4VeOutLB1I'),
           0x0BA6CD: ('playerOutofLB2', 'M4VeOutLB2I'),
           0x0BA907: ('playerOutofLB3', 'M4VeOutLB3I')}

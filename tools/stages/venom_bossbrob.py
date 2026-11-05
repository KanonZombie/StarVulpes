"""Venom 1 unit bossbrob (bossBrob 07:B848, planet boss): effect descriptors.

Owner: build/agent-venom/bossbrob/BOSSBROB.md. Drawn models and their
descriptors carry the ROM header box/sortz/size/shift used by collision,
z-remove and explosions. The headers below are written by the ROM code of the
unit (USA rev0): C7A4 map/images (07:AC22), C788 legs (07:BED0, C853), D7D4
kick (07:C796), D7F0 foot (07:C7DD), C814/C830 halves (07:CAF3, CB5C), C7F8
remains (07:CBC5). C7A4 is declared by venom_bossb.py (boss_b_1): the
map-created body takes the first match (M4LevelShapeIndex); identity is the
header (X_SHAPEHDR), never the descriptor index.
"""
SHAPES = [('boss_b_0', 0xc788), ('boss_b_6', 0xd7d4),
          ('boss_b_7', 0xd7f0), ('boss_b_l', 0xc814), ('boss_b_r', 0xc830),
          ('boss_b_h', 0xc7f8)]
EFFECTS = []
# Legs boss_b_0 C788 and kick boss_b_6 D7D4 share the ROM colbox list 7E:714A: HF1 body (0,0,0;
# 80,60,80), HF2 left leg (-40,200,20; 40,80,120), HF3 right leg (40,200,20; 40,80,120), rotflags
# $22. bossBrobcol CC8B damages only through HF1. Used by the generator patch of
# build/agent-venom/bossbrob/INTEGRATION.md (ignored by the current generator).
COLBOX_EFFECTS = {0xc788, 0xd7d4}

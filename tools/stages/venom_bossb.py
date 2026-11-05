"""Venom 1 unit bossb (orbital boss bossB 07:AAD1): effect descriptors.

Owner: build/agent-venom/bossb/BOSSB.md. Code: src/stages/level_venom_bossb.asm.
boss_b_1 00:C7A4 (body, its fading images 07:B586 and decoys 07:B234): header box
xmax/ymax/zmax 180/140/240, size 252, sh_shift 2, sortz 0, no colbox list (ROM bytes).
The body now uses the original polygon/BSP model (alias M4VbShBody). bossBrob
07:B848 uses the same header: this module sorts first, so M4LevelShapeIndex($C7A4)
resolves to this model.
"""
SHAPES = [('boss_b_1', 0xC7A4)]
EFFECTS = []

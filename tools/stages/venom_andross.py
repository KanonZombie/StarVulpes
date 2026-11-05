"""Venom unit `andross`: Andross (monolith 07:DEAB) shapes as effect descriptors.

Loaded by tools/level-shapes.py stage_modules() and the other generators. Owner:
build/agent-venom/andross/ANDROSS.md. Code: src/stages/level_venom_andross.asm (aliases M4VaSh*).
Original geometry is drawn by the SVP; the descriptor carries the ROM header box (xmax/ymax/zmax),
sortz, sh_size and sh_shift used by collision, zremove and explosions. Headers (bank 00, USA rev0)
and UltraStarFox names (SF/STRAT/GB3STRAT.ASM):
  D0B8 face_b (map 0D:DAFE), D144 face_0, D160 face_0_1, E6B4 face_1 (route 3), D0F0 sface2_b and
  D0D4 sface_b (16 panels), AC85 androsscube (core, routes 1), BD5C face_box (core, routes 2/3),
  D128 fireface1_b (eye shot), D10C fireface_b (cubes), BF8C Shyper (suck bits), AC4D andross
  (final cubes of the core explosion).
"""
SHAPES = [
    ('face_b', 0xD0B8), ('face_0', 0xD144), ('face_0_1', 0xD160),
    ('sface2_b', 0xD0F0), ('sface_b', 0xD0D4),
    ('androsscube', 0xAC85), ('fireface1_b', 0xD128),
    ('fireface_b', 0xD10C), ('andross', 0xAC4D),
]
# Route 2/3 variants remain outside this route-1 integration.
EFFECTS = [('VA_FACE_1', 0xE6B4, -1), ('VA_FACE_BOX', 0xBD5C, -1)]
TEX_WORDS = [0x46A6]  # original core/explosion cube texture
# Colbox chains of the faces (header+8, 02:(addr+$4E6D)): face box flagset 1 (HF1, rebelasercol), left eye 2,
# right eye 4 (monolithcol 07:F172). Consumed only once tools/generate-level-shapes.py emits colboxes for effects
# (build/agent-venom/andross/INTEGRATION.md section 1); ignored until then.
EFFECT_COLBOXES = {0xD144, 0xD160, 0xE6B4}

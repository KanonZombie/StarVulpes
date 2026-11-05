"""Venom (route 1) stage module: common shapes/effects and player modes.

Owner: build/agent-venom/VENOM.md. Units add their own modules
tools/stages/venom_<unit>.py (bossb, bossbrob, andross, orbital, planet,
escape); the generators load every tools/stages/*.py in file-name order.
Optional lists: SHAPES [(name, header)], EFFECTS [(NAME, header, svp)],
SPRITE_HEADERS {header}, COLTAB_SPRITES [(coltab, header)], TEX_WORDS [word],
PSTRATS {0x0Bxxxx: ('name', 'PortRoutine')}.
"""
SHAPES = []
EFFECTS = []
PSTRATS = {}

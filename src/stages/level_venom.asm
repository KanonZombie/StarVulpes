; Stage unit: Venom 1/2/3 orbital and planet (0D:D602, D67F, E085, E0F5, E8B9, E929). Strategies, player modes and effects of
; this stage; its strategy table is searched by M4LevelFindStrategy
; (M4LevelStrategyTables, level_objects.asm). Shapes/effects/sprites/textures:
; tools/stages/venom.py and tools/stages/venom_<unit>.py (one per unit file).
; Documentation (Spanish): build/agent-venom/VENOM.md.
; Units (each owns its strats/code files, its stage module and its RAM):
;   (common, player modes) this file          RAM $FF9F00..$FF9F1F
;   bossB 07:AAD1 (orbital)    level_venom_bossb*.asm     $FF9F20..$FF9F3F
;   bossBrob 07:B848 (planet)  level_venom_bossbrob*.asm  $FF9F40..$FF9F5F
;   monolith 07:DEAB (Andross) level_venom_andross*.asm   $FF9F60..$FF9F7F
;   orbital enemies            level_venom_orbital*.asm   $FF9F80..$FF9F9F
;   planet/tunnel enemies      level_venom_planet*.asm    $FF9FA0..$FF9FBF
;   escape sequence            level_venom_escape*.asm    $FF9FC0..$FF9FDF
;   (spare)                                               $FF9FE0..$FF9FFF
M4_VN equ $ff9f00
M4StrategiesVenom:
        include 'stages/level_venom_bossb_strats.asm'
        include 'stages/level_venom_bossbrob_strats.asm'
        include 'stages/level_venom_andross_strats.asm'
        include 'stages/level_venom_orbital_strats.asm'
        include 'stages/level_venom_planet_strats.asm'
        include 'stages/level_venom_escape_strats.asm'
        dc.l 0

        include 'stages/level_venom_bossb.asm'
        include 'stages/level_venom_bossbrob.asm'
        include 'stages/level_venom_andross.asm'
        include 'stages/level_venom_orbital.asm'
        include 'stages/level_venom_planet.asm'
        include 'stages/level_venom_escape.asm'
        even

; Player modes of this stage (original pstrat 24-bit address.l, port Istrat.l;
; 0 ends), searched by M4LevelFindPlayerMode (level_warp.asm).
M4PlayerModesVenom:
        dc.l $0b9e4a,M4VePlayerDiveI ;set_playerDIVE_l (cl_player_mode 05:E0B6, Venom orbital)
        dc.l $0ba535,M4VeOutLB1I ;playerOutofLB1_Istrat (bg $6F newplayerstrat)
        dc.l $0ba6cd,M4VeOutLB2I ;playerOutofLB2_Istrat (bg $75)
        dc.l $0ba907,M4VeOutLB3I ;playerOutofLB3_Istrat (bg $7B)
        dc.l 0

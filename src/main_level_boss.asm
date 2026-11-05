; Test ROM (build.ps1 -Target m4-level-boss): the level starts at the Corneria 1
; boss (0D:9051) and the player cannot die (tools/probe-level-end.py).
M4_LEVEL_BOSS_TEST equ 1
        include 'main.asm'

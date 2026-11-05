; MegaSVP: Star Fox (SNES) port for Mega Drive + SVP. Game ROM entry point
; (build.ps1 -Target m4-intro -> build/megasvp-m4-intro.bin). Assembled from
; src/ (asm68k working directory). Build configuration of the game (the old
; main_m4_intro_vr -> main_m4_intro -> main_m4_script chain, archived in
; archive/milestones/): VR-style SVP pipeline with DMA by blocks, H32 output,
; 256x192 SVP bitmap from screen line 16.
M4_VR_DMA equ 1
M4_INTRO equ 1
M4_TEXT_TEST equ 1
M4_BLOCK_DMA equ 1
M4_RENDER_HEIGHT equ 192
M4_RENDER_TOP equ 16
M4_RENDER_WORDS equ M4_RENDER_HEIGHT*64
M4_RENDER_BYTES equ M4_RENDER_HEIGHT*128
M4_SCRIPT_TEST equ 1
M4_LOGIC_TEST equ 1
M4_BG_TEST equ 1
GRAPHICS_TEST equ 1
        include 'system/core.asm'

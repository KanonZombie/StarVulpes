; Space background of Asteroid Belt 1: setbg $21 = bg_1_2 03:92DF (chr
; 15:A408, scr 16:B944 64x64 cells, palette collection 7F:0D40 rows 0..6),
; converted exactly by tools/convert-screen-bg.py space12 (130 tiles, line 0).
; The SNES BG2 is 512 px wide (horizontal period 512); MD plane B is 32 cells
; (256 px) because plane A keeps the 32x64 VR layout and the VDP plane size is
; shared. Plane B therefore streams the 64 source columns: column c of the
; plane holds source column s with s & 31 = c, s in [L, L+31],
; L = ((HOFS + 10) >> 3) - 1. The visible SNES window is x 16..239 and the
; tilt adds HOFS - 6..+5 per line (bg-tilt.md section 3), so one image needs
; at most 31 columns: one column of slack on the left, 0..1 on the right.
; Columns are written when an image is sealed (M4VRFramebufferReady); an
; image still shown with a scroll more than one column away can show the
; replaced edge column for that frame (deliberate difference, documented in
; LEVEL_ORIGIN.md). Rows: 64 cells = 512 px, exactly as the SNES map.
M4_SPB equ $fff900
M4_SPB_ON equ M4_SPB ;.b 1: plane B streams the space map
M4_SPB_L equ M4_SPB+2 ;.w first source column of the plane window
M4_SPB_COLS equ M4_SPB+4 ;32 .b source column held by each plane column ($ff none)
M4_SPB_CRAM equ M4_SPB+36 ;28 .w CRAM lines 0-1 (slots 0..11 of line 1) of this BG
M4_SPB_END equ M4_SPB+92

        include '../build/packed-2d/screen-space12.inc'

; transswap of setbg $21: tiles, CRAM rows and the whole plane window for
; the scroll of this tick. Interrupts are masked only per chunk.
M4SpaceBgLoad:
        movem.l d0-d3/a0-a1,-(sp)
        jsr M4VRBgReplaceBegin
        lea M4ScrSpace12Tiles,a0
        move.w #M4_SCR_SPACE12_VRAM,d0
        jsr M4BgUploadStage
        lea M4ScrSpace12Map,a0
        lea M4_BG_MAP_RAM,a1
        jsr M4BgDecode
        move.l a1,M4_LBG_MAP
        lea M4_SPB_CRAM,a1
        moveq #27,d1
M4SpbCramClear:
        clr.w (a1)+
        dbra d1,M4SpbCramClear
        lea M4ScrSpace12Cram,a0
        lea M4_SPB_CRAM,a1
M4SpbCramEntry:
        move.w (a0)+,d0 ;CRAM byte offset
        bmi.s M4SpbCramDone
        move.w (a0)+,d1
        cmpi.w #56,d0 ;lines 0-1 up to line 1 slot 11 (M4ScBgPalette)
        bhs.s M4SpbCramEntry
        move.w d1,(a1,d0.w)
        bra.s M4SpbCramEntry
M4SpbCramDone:
        move.w #M4_LVHUD_XHAIR_COLOUR,M4_SPB_CRAM+30 ;line 0 slot 15: cockpit crosshair
        lea M4_SPB_COLS,a0
        moveq #31,d1
M4SpbColsClear:
        st (a0)+
        dbra d1,M4SpbColsClear
        move.b #1,M4_SPB_ON
        move.b M4_SC_BGBLACK,d0 ;M4ScBgPalette applies the new rows
        not.b d0
        move.b d0,M4_SC_BGSHOWN
        move.w M4_BG_HSCROLL,d0
        jsr M4SpaceBgStream
        jsr M4VRBgReplaceEnd
        movem.l (sp)+,d0-d3/a0-a1
        rts

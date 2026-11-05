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

        include '../build/screen-space12.inc'

; transswap of setbg $21: tiles, CRAM rows and the whole plane window for
; the scroll of this tick. Interrupts are masked only per chunk.
M4SpaceBgLoad:
        movem.l d0-d3/a0-a1,-(sp)
        jsr M4VRBgReplaceBegin
        lea M4ScrSpace12Tiles,a0
        move.w #M4_SCR_SPACE12_VRAM,d1
        move.w #M4_SCR_SPACE12_TILES*2-1,d3 ;16-byte chunks
M4SpbTileChunk:
        move.w sr,-(sp)
        ori.w #$0700,sr
        move.w d1,d0
        jsr M4TextVideoWriteAddress ;d0/d2
        move.l (a0)+,VDP_DATA
        move.l (a0)+,VDP_DATA
        move.l (a0)+,VDP_DATA
        move.l (a0)+,VDP_DATA
        move.w (sp)+,sr
        addi.w #16,d1
        dbra d3,M4SpbTileChunk
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
        bsr.s M4SpaceBgStream
        jsr M4VRBgReplaceEnd
        movem.l (sp)+,d0-d3/a0-a1
        rts

; d0 = plane B HSCROLL of the image (-HOFS & $3ff). Loads the plane columns
; whose source column differs from the window of this image.
M4SpaceBgStream:
        movem.l d0-d7/a0-a2,-(sp)
        neg.w d0 ;HOFS
        addi.w #10,d0
        asr.w #3,d0
        subq.w #1,d0
        andi.w #63,d0
        move.w d0,M4_SPB_L
        move.w d0,d5 ;s
        moveq #31,d6
M4SpbStreamNext:
        move.w d5,d4
        andi.w #31,d4 ;plane column c
        lea M4_SPB_COLS,a0
        cmp.b (a0,d4.w),d5
        beq.s M4SpbStreamHeld
        move.b d5,(a0,d4.w)
        bsr.s M4SpbColumn
M4SpbStreamHeld:
        addq.w #1,d5
        andi.w #63,d5
        dbra d6,M4SpbStreamNext
        movem.l (sp)+,d0-d7/a0-a2
        rts

; d4 = plane column c, d5 = source column s. Four chunks of 16 rows written
; down the column with autoincrement 64 (plane B 32 cells: 64 bytes a row).
M4SpbColumn:
        move.w d5,d0
        andi.w #31,d0
        add.w d0,d0
        lea M4ScrSpace12Map0,a1 ;rows 0..31: screen (0,0) or (1,0)
        lea M4ScrSpace12Map2,a2 ;rows 32..63: screen (0,1) or (1,1)
        btst #5,d5
        beq.s M4SpbColumnLeft
        lea M4ScrSpace12Map1,a1
        lea M4ScrSpace12Map3,a2
M4SpbColumnLeft:
        adda.w d0,a1
        adda.w d0,a2
        move.w d4,d2
        add.w d2,d2
        addi.w #$e000,d2 ;VRAM of row 0
        moveq #3,d3
M4SpbColumnChunk:
        cmpi.w #1,d3
        bne.s M4SpbColumnSrc
        movea.l a2,a1 ;rows 32..63
M4SpbColumnSrc:
        move.w sr,-(sp)
        ori.w #$0700,sr
        move.w #$8f40,VDP_CTRL
        moveq #0,d0
        move.w d2,d0
        andi.w #$3fff,d0
        swap d0
        ori.l #$40000003,d0 ;VRAM write, address bits 15-14 = 3
        move.l d0,VDP_CTRL
        moveq #15,d1
M4SpbColumnWord:
        move.w (a1),VDP_DATA
        lea 64(a1),a1
        dbra d1,M4SpbColumnWord
        move.w #$8f02,VDP_CTRL
        move.w (sp)+,sr
        addi.w #16*64,d2
        dbra d3,M4SpbColumnChunk
        rts

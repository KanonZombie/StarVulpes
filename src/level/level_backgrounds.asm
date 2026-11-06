; Stage backgrounds: setbg n -> bglists 03:AC42+n (selected ROM USA rev0).
; Generalises the Asteroid 1 loader (level_space_bg.asm M4SpaceBgLoad) to
; every background routine the stage maps use. tools/convert-level-
; backgrounds.py reads each routine from the ROM (65816 model with byte
; assertions) and generates build/level-backgrounds.inc: per number, the
; setbginfo result (dotsflag / 70:1A26 star mode from levelinfo $1787) and a
; program of the routine's effects in ROM order; per distinct image (chr,
; scr, palette), MD tiles for VRAM $9A40.., a 64-row name table of 32 or 64
; columns and the 28 CRAM WORDs of lines 0-1 (M4_SPB_CRAM layout, consumed by
; M4ScBgPalette). Table, exactness and differences: build/agent-bg/
; BACKGROUNDS.md; provenance: build/level-backgrounds.json.
;
; transswap order (02:DAA3): the request (setbg, bgflags bit 2) is applied at
; the end of the tick by M4ScTransSwap, which calls M4LevelBgSwap for the
; numbers it does not handle itself; setbginfo (bit 3, 03:EFE6) then installs
; newplayerstrat (M4_SC_NEWPSTRAT) unless keeppstrat, and sets dotsflag from
; levelinfo (M4LevelBgInfo).
;
; Program ops (WORD opcode, then arguments):
;   LBG_LOAD .l image   tiles, CRAM lines 0-1, plane B (bg2chr/bg2scr/palette)
;   LBG_VAR .l addr .w byte   store to an original WRAM/GSU address through
;                       M4LvVarAddr (level_mapvars.asm); addresses the port
;                       does not model are skipped (listed in the JSON)
;   LBG_VIEW            changeviewmode_l 06:BA91 (M4SpChangeView)
;   LBG_GAMEPAL .w n    setgamepal_l 02:F484 (M4LvGamepal)
;   LBG_DEPTH .l table  zdepth table 70:0050 (M4_SC_DEPTH)
;   LBG_PSTRAT .l istrat  newplayerstrat $1788 (0 = Istrat not ported: the
;                       player keeps its strategy, PEND)
; Not modelled (recorded in the JSON): music, BGMODE/initmode, HDMA enables
; and the hofmode HDMA patterns other than rotate, BG3 layers (water), the
; flashbg counter, offset-per-tile columns.
;
; Plane B: a 32-column image (horizontal period 256 px) is written whole
; (64 rows); a 64-column image streams its source columns into the 32 plane
; columns exactly as M4SpaceBgStream does for bg_1_2 (window L = ((HOFS + 10)
; >> 3) - 1, 31 columns per image), from M4LevelBgStream.
LBG_END equ 0
LBG_LOAD equ 1
LBG_VAR equ 2
LBG_VIEW equ 3
LBG_GAMEPAL equ 4
LBG_DEPTH equ 5
LBG_PSTRAT equ 6
M4_LBG_VRAM equ $9a40 ;tiles up to M4_LEVEL_MSG_TILES ($b100, 182 tiles)
M4_LBG_W64 equ M4_SPB+1 ;.b 1: the image streams 64 source columns (M4_SPB_ON = 2)
M4_LBG_MAP equ M4_SPB_END ;.l decoded name table in WRAM

; d0.w = background number -> a0 = program, d1.w = dotsflag << 8 | star mode.
; Z = 1 when the number is not in the table. Other registers preserved.
M4LevelBgFind:
        move.l a1,-(sp)
        lea M4LbgTable,a1
M4LbgFindNext:
        move.w (a1)+,d1
        bmi.s M4LbgFindNone ;-1 ends the table
        cmp.w d1,d0
        beq.s M4LbgFindHit
        addq.l #6,a1
        bra.s M4LbgFindNext
M4LbgFindHit:
        move.w (a1)+,d1
        movea.l (a1),a0
        movea.l (sp)+,a1
        andi.b #$fb,ccr ;Z = 0
        rts
M4LbgFindNone:
        movea.l (sp)+,a1
        ori.b #4,ccr ;Z = 1
        rts

; transswap of setbg d0.w: runs the program of the background. Z = 1 (and
; nothing done) when the number is not in the table. Registers preserved.
M4LevelBgSwap:
        movem.l d0-d3/a0-a4,-(sp)
        bsr.s M4LevelBgFind
        beq M4LbgSwapNone
        movea.l a0,a4
M4LbgOp:
        move.w (a4)+,d0
        beq.s M4LbgSwapDone
        cmpi.w #LBG_LOAD,d0
        beq.s M4LbgOpLoad
        cmpi.w #LBG_VAR,d0
        beq.s M4LbgOpVar
        cmpi.w #LBG_VIEW,d0
        beq.s M4LbgOpView
        cmpi.w #LBG_GAMEPAL,d0
        beq.s M4LbgOpGamepal
        cmpi.w #LBG_DEPTH,d0
        beq.s M4LbgOpDepth
        cmpi.w #LBG_PSTRAT,d0
        beq.s M4LbgOpPstrat
        move.w #-1,M4_LV_STATUS ;bad program (generator error)
M4LbgSwapDone:
        movem.l (sp)+,d0-d3/a0-a4
        andi.b #$fb,ccr ;Z = 0: handled
        rts
M4LbgSwapNone:
        movem.l (sp)+,d0-d3/a0-a4
        ori.b #4,ccr
        rts
M4LbgOpLoad:
        movea.l (a4)+,a2
        bsr.s M4LbgLoad
        bra.s M4LbgOp
M4LbgOpVar:
        move.l (a4)+,d0 ;original address
        move.w (a4)+,d3 ;byte
        jsr M4LvVarAddr ;-> a3, d1 = 0 when the port holds it
        tst.l d1
        bmi.s M4LbgOp
        move.b d3,(a3)
        bra.s M4LbgOp
M4LbgOpView:
        jsr M4SpChangeView
        bra.s M4LbgOp
M4LbgOpGamepal:
        move.w (a4)+,d0
        jsr M4LvGamepal
        bra.s M4LbgOp
M4LbgOpDepth:
        move.l (a4)+,M4_SC_DEPTH
        bra.s M4LbgOp
M4LbgOpPstrat:
        move.l (a4)+,M4_SC_NEWPSTRAT ;0: not ported, setbginfo keeps the player's strategy
        bra.s M4LbgOp

; setbginfo 03:EFE6 for the numbers of the table: d0.w = number -> d1.b =
; dotsflag $16FB (1 grid, $FF stars/snow/pollen, 0 none); 70:1A26 (star
; colour mode) is written through M4LvVarAddr. Z = 1 when not in the table.
; Registers other than d1 preserved.
M4LevelBgInfo:
        jsr M4SoundSetBg
        movem.l d0/d2-d3/a0/a3,-(sp)
        bsr M4LevelBgFind
        beq.s M4LbgInfoNone
        move.w d1,d3
        move.l #$701a26,d0
        jsr M4LvVarAddr
        tst.l d1
        bmi.s M4LbgInfoDots
        move.b d3,(a3)
M4LbgInfoDots:
        move.w d3,d1
        lsr.w #8,d1
        movem.l (sp)+,d0/d2-d3/a0/a3
        andi.b #$fb,ccr
        rts
M4LbgInfoNone:
        movem.l (sp)+,d0/d2-d3/a0/a3
        ori.b #4,ccr
        rts

; a2 = image (tiles.w, width.w, tiles.l, map.l, CRAM.l): tiles, CRAM rows
; and the plane window for the scroll of this tick (M4SpaceBgLoad order).
; Interrupts are masked only per chunk (IRQ4 presentation window).
M4LbgLoad:
        movem.l d0-d3/a0-a1,-(sp)
        jsr M4VRBgReplaceBegin
        movea.l 4(a2),a0
        move.w #M4_LBG_VRAM,d0
        jsr M4BgUploadStage
        movea.l 8(a2),a0
        lea M4_BG_MAP_RAM,a1
        jsr M4BgDecode
        move.l a1,M4_LBG_MAP
        movea.l 12(a2),a0 ;CRAM lines 0-1 (slots 0..11 of line 1)
        lea M4_SPB_CRAM,a1
        moveq #27,d1
M4LbgCram:
        move.w (a0)+,(a1)+
        dbra d1,M4LbgCram
        move.w #M4_LVHUD_XHAIR_COLOUR,M4_SPB_CRAM+30 ;line 0 slot 15: cockpit crosshair
        lea M4_SPB_COLS,a0
        moveq #31,d1
M4LbgColsClear:
        st (a0)+
        dbra d1,M4LbgColsClear
        move.b #2,M4_SPB_ON
        clr.b M4_SC_BGBLACK ;the palette op reloads the BG rows (makeBG2black undone)
        st M4_SC_BGSHOWN ;M4ScBgPalette applies the new rows with the next image
        clr.b M4_LBG_W64
        cmpi.w #64,2(a2)
        bne.s M4LbgLoadStatic
        move.b #1,M4_LBG_W64
        move.w M4_BG_HSCROLL,d0
        bsr.s M4LbgStream64
        bra.s M4LbgLoadDone
M4LbgLoadStatic:
        lea M4_BG_MAP_RAM,a1 ;32 columns: the 64 rows at plane B $E000
        move.w #$e000,d1
        moveq #63,d3
M4LbgPlaneRow:
        move.w sr,-(sp)
        ori.w #$0700,sr
        move.w d1,d0
        jsr M4TextVideoWriteAddress
        moveq #15,d2
M4LbgPlaneLong:
        move.l (a1)+,VDP_DATA
        dbra d2,M4LbgPlaneLong
        move.w (sp)+,sr
        addi.w #64,d1
        dbra d3,M4LbgPlaneRow
M4LbgLoadDone:
        jsr M4VRBgReplaceEnd
        movem.l (sp)+,d0-d3/a0-a1
        rts

; Replaces the call to M4SpaceBgStream in M4VRFramebufferReady: d0 = plane B
; HSCROLL of the image (-HOFS & $3ff). M4_SPB_ON 1 = bg_1_2 (level_space_bg),
; 2 = this module (64-column images stream, 32-column images are static).
M4LevelBgStream:
        cmpi.b #1,M4_SPB_ON
        bne.s M4LbgStreamGeneric
        jmp M4SpaceBgStream
M4LbgStreamGeneric:
        cmpi.b #2,M4_SPB_ON
        bne.s M4LbgStreamNone
        tst.b M4_LBG_W64
        bne.s M4LbgStream64
M4LbgStreamNone:
        rts
M4SpaceBgStream:
M4LbgStream64:
        movem.l d0-d7/a0-a2,-(sp)
        neg.w d0 ;HOFS
        addi.w #10,d0
        asr.w #3,d0
        subq.w #1,d0
        andi.w #63,d0
        move.w d0,M4_SPB_L
        move.w d0,d5 ;s
        moveq #31,d6
M4LbgStreamNext:
        move.w d5,d4
        andi.w #31,d4 ;plane column c
        lea M4_SPB_COLS,a0
        cmp.b (a0,d4.w),d5
        beq.s M4LbgStreamHeld
        move.b d5,(a0,d4.w)
        bsr.s M4LbgColumn
M4LbgStreamHeld:
        addq.w #1,d5
        andi.w #63,d5
        dbra d6,M4LbgStreamNext
        movem.l (sp)+,d0-d7/a0-a2
        rts

; d4 = plane column c, d5 = source column s: 64 rows (map row stride 128
; bytes) in four chunks of 16 written down the column (autoincrement 64).
M4LbgColumn:
        movea.l M4_LBG_MAP,a1
        move.w d5,d0
        add.w d0,d0
        adda.w d0,a1
        move.w d4,d2
        add.w d2,d2
        addi.w #$e000,d2 ;VRAM of row 0
        moveq #3,d3
M4LbgColumnChunk:
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
M4LbgColumnWord:
        move.w (a1),VDP_DATA
        lea 128(a1),a1
        dbra d1,M4LbgColumnWord
        move.w #$8f02,VDP_CTRL
        move.w (sp)+,sr
        addi.w #16*64,d2
        dbra d3,M4LbgColumnChunk
        rts

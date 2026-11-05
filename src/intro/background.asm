; Original intro resources, isolated diagnostic display of lower-left map
; block. No invented camera/motion: full intro scheduling is not integrated.
BG_DIAG        equ $ff4100
BG_DECODE_SP   equ $ff4138
BG_RECORDS     equ $ff4140
BG_TILES       equ $ff5000
BG_MAP         equ $ff6000
BG_INPUT       equ $301000
BG_OUTPUT equ $309000 ;startup only, before bank1 becomes a producer
        include '../build/intro-bg-constants.inc'

M4BackgroundStart:
        move.w #$8104,VDP_CTRL
        lea BG_DIAG,a0
        moveq #0,d0
        moveq #31,d1
BG_ClearDiag:
        move.l d0,(a0)+
        dbra d1,BG_ClearDiag
        move.l #'M4BG',BG_DIAG
        lea $ff4180,a0
        move.l #$78700000,(a0)
        move.l #$000080a5,4(a0) ; already blank, like the original entry context
        moveq #0,d0
        move.b BG_ScriptPrefix,d0
        bsr M4MapFadeCommand
        cmpi.w #1,d0
        bne BG_BadDecode
        moveq #0,d0
        move.b BG_ScriptPrefix+1,d0
        bsr M4MapFadeCommand
        cmpi.w #1,d0
        bne BG_BadDecode
        lea $ff4190,a1
        move.w (a0),(a1)
        clr.l 2(a1)
        movea.l a1,a0
        moveq #0,d0
        move.b BG_ScriptPrefix+4,d0
        lsl.w #8,d0
        move.b BG_ScriptPrefix+3,d0
        bsr M4SetBgRequest
        move.w 2(a0),BG_DIAG+22
        move.w 4(a0),BG_DIAG+24
        move.w (a0),BG_DIAG+28
        move.w #$a55a,BG_TILES-2
        move.w #$a55a,BG_TILES+2560
        move.w #$a55a,BG_MAP-2
        move.w #$a55a,BG_MAP+8192
        ; No old decoded buffer may validate a new loader invocation.
        move.w #$dead,d0
        lea BG_TILES,a0
        move.w #1279,d1
BG_PoisonTiles:
        move.w d0,(a0)+
        dbra d1,BG_PoisonTiles
        lea BG_MAP,a0
        move.w #4095,d1
BG_PoisonMap:
        move.w d0,(a0)+
        dbra d1,BG_PoisonMap
        lea BG_TileCompressed,a4
        lea BG_TileCompressedEnd,a0
        lea BG_TILES,a2
        bsr M4Decrunch
        tst.w d0
        bne BG_BadDecode
        move.w #2560,BG_DIAG+6
        lea BG_MapCompressed,a4
        lea BG_MapCompressedEnd,a0
        lea BG_MAP,a2
        bsr M4Decrunch
        tst.w d0
        bne BG_BadDecode
        move.w #8192,BG_DIAG+8
        cmpi.w #$a55a,BG_TILES-2
        bne BG_BadGuard
        cmpi.w #$a55a,BG_TILES+2560
        bne BG_BadGuard
        cmpi.w #$a55a,BG_MAP-2
        bne BG_BadGuard
        cmpi.w #$a55a,BG_MAP+8192
        bne BG_BadGuard
        lea BG_TILES,a0
        lea BG_INPUT,a1
        move.w #1279,d0
BG_CopyPlanar:
        move.w (a0)+,(a1)+
        dbra d0,BG_CopyPlanar
        move.w #$a55a,BG_INPUT-2
        move.w #$a55a,BG_INPUT+2560
        move.w #$a55a,BG_OUTPUT-2
        move.w #$a55a,BG_OUTPUT+2560
        lea BG_RECORDS,a5
        move.w #$6001,BG_DIAG+10
        move.w #BG_TILE_SUM,BG_DIAG+18
        bsr BG_Request
        tst.w d0
        bne BG_Failed
        eori.w #$8000,BG_INPUT ; word bus; Fusion ignores this byte-RMW form
        addq.w #1,BG_DIAG+10
        move.w #BG_MODIFIED_SUM,BG_DIAG+18
        lea 16(a5),a5
        bsr BG_Request
        tst.w d0
        bne BG_Failed
        eori.w #$8000,BG_INPUT ; restore original before presenting
        addq.w #1,BG_DIAG+10
        move.w #BG_TILE_SUM,BG_DIAG+18
        lea 16(a5),a5
        bsr BG_Request
        tst.w d0
        bne BG_Failed
        bsr BG_Present
        move.w BG_DIAG+10,BG_DIAG+12
        move.w #$f3,BG_DIAG+26
        move.w #1,BG_DIAG+4
        jmp M4IntroStart
        move.w #$8144,VDP_CTRL
BG_Stop:
        bra.s BG_Stop

BG_Request:
        move.w BG_DIAG+10,(a5)
        move.w BG_DIAG+18,2(a5)
        move.w BG_INPUT,4(a5) ; observed operand word, not a constant assertion
        move.w #$dead,BG_OUTPUT
        move.w #$dead,BG_OUTPUT+2558
        move.w BG_DIAG+10,d0
        not.w d0
        move.w d0,MAILBOX+6
        move.w d0,ACK_SEQUENCE
        move.w #$dead,MAILBOX+4
        move.w #$dead,MAILBOX+16
        move.w #6,MAILBOX+8
        move.w XST_STATUS,d0
        move.w BG_DIAG+10,XST
        move.l #TIMEOUT_POLLS,d1
BG_Poll:
        move.w XST_STATUS,d0
        andi.w #1,d0
        bne.s BG_Completed
        subq.l #1,d1
        bne.s BG_Poll
        moveq #2,d0
        rts
BG_Completed:
        move.w MAILBOX+4,6(a5)
        move.w MAILBOX+6,8(a5)
        move.w ACK_SEQUENCE,10(a5)
        move.w MAILBOX+16,12(a5)
        move.w BG_DIAG+10,d0
        cmp.w 8(a5),d0
        bne.s BG_SequenceError
        cmp.w 10(a5),d0
        bne.s BG_SequenceError
        cmpi.w #1280,6(a5)
        bne.s BG_SequenceError
        move.w #1280,BG_DIAG+20
        cmpi.w #$a55a,BG_INPUT-2
        bne.s BG_RequestGuard
        cmpi.w #$a55a,BG_INPUT+2560
        bne.s BG_RequestGuard
        cmpi.w #$a55a,BG_OUTPUT-2
        bne.s BG_RequestGuard
        cmpi.w #$a55a,BG_OUTPUT+2560
        bne.s BG_RequestGuard
        lea BG_OUTPUT,a0
        moveq #0,d0
        move.w #1279,d1
BG_Checksum:
        add.w (a0)+,d0
        dbra d1,BG_Checksum
        move.w d0,BG_DIAG+16
        cmp.w BG_DIAG+18,d0
        bne.s BG_ChecksumError
        cmp.w 12(a5),d0
        bne.s BG_ChecksumError
        addq.w #1,BG_DIAG+14
        move.w #1,14(a5)
        moveq #0,d0
        rts
BG_SequenceError:
        moveq #4,d0
        rts
BG_RequestGuard:
        moveq #7,d0
        rts
BG_ChecksumError:
        moveq #8,d0
        rts
BG_BadDecode:
        moveq #3,d0
        bra.s BG_Failed
BG_BadGuard:
        moveq #7,d0
BG_Failed:
        move.w d0,BG_DIAG+4
        moveq #24,d6
        jsr SetRow
        lea BG_FailureText,a0
        jsr DrawText
        move.w BG_DIAG+4,d4
        jsr DrawHex
        move.w #$8144,VDP_CTRL
        bra BG_Stop

; ROM 03:F502 / 03:F514: original handler advances index three times after
; setbg_l writes currentbg and ORs word flags. Destination state has no SNES
; address aliases: pointer.w, currentbg.w, flags.w; d0=original operand word.
M4SetBgRequest:
        move.w d0,2(a0)
        ori.w #4,4(a0)
        addq.w #3,(a0)
        rts

BG_Present:
        move.l #$40000003,VDP_CTRL ; clear A text from the native image field
        moveq #0,d0
        move.w #2047,d1
BG_ClearA:
        move.w d0,VDP_DATA
        dbra d1,BG_ClearA
        move.l #$60000003,VDP_CTRL ; clear B's 64x32 name table
        move.w #2047,d1
BG_ClearB:
        move.w d0,VDP_DATA
        dbra d1,BG_ClearB
        move.l #$48000000,VDP_CTRL
        lea BG_OUTPUT,a0
        move.w #1279,d1
BG_UploadTiles:
        move.w (a0)+,VDP_DATA ; actual fresh SVP words, no expected image upload
        dbra d1,BG_UploadTiles
        move.l #$c0000000,VDP_CTRL
        lea BG_Palette,a0
        moveq #31,d1
BG_UploadPalette:
        move.w (a0)+,VDP_DATA
        dbra d1,BG_UploadPalette
        move.w #$870f,VDP_CTRL ; original map's black index 15 as backdrop
        lea BG_MAP+4096,a0     ; lower-left block of actual decoded map
        moveq #0,d6
BG_MapRow:
        move.w d6,d0
        lsl.w #7,d0
        addi.w #$e008,d0
        moveq #0,d1
        move.w d0,d1
        andi.w #$3fff,d1
        swap d1
        lsr.w #8,d0
        lsr.w #6,d0
        or.w d0,d1
        ori.l #$40000000,d1
        move.l d1,VDP_CTRL
        moveq #31,d7
BG_MapCell:
        move.w (a0)+,d0
        rol.w #8,d0           ; original raw tilemap is little endian
        move.w d0,d1
        andi.w #1023,d1
        addi.w #64,d1         ; MD tile allocation replaces SNES C0 relocation
        move.w d0,d2
        lsr.w #8,d2
        lsr.w #2,d2
        andi.w #7,d2
        beq.s BG_MapPalette
        ori.w #$2000,d1       ; source palette 6 -> MD palette 1
BG_MapPalette:
        btst #14,d0
        beq.s BG_MapVFlip
        ori.w #$0800,d1
BG_MapVFlip:
        btst #15,d0
        beq.s BG_MapPriority
        ori.w #$1000,d1
BG_MapPriority:
        btst #13,d0
        beq.s BG_MapWrite
        ori.w #$8000,d1
BG_MapWrite:
        move.w d1,VDP_DATA
        dbra d7,BG_MapCell
        addq.w #1,d6
        cmpi.w #28,d6
        bne BG_MapRow
        rts

        include 'system/decrunch.asm'
        even
        dc.b $a5            ; exercise odd ROM alignment like original A4DEB
BG_TileCompressed:
        incbin '../build/intro-bg-tiles.compressed.bin'
BG_TileCompressedEnd:
BG_MapCompressed:
        incbin '../build/intro-bg-map.compressed.bin'
BG_MapCompressedEnd:
        even
BG_Palette:
        incbin '../build/intro-bg-palette.md.bin'
BG_ScriptPrefix:
        incbin '../build/intro-bg-script-prefix.bin'
BG_FailureText:
        dc.b 'M4 BG FAIL ',0
        even

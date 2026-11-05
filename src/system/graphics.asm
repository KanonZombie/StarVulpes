; M1: one outstanding DSP job and one 32-byte DRAM buffer.
; Ownership: host invalidates -> DSP writes -> ACK -> host verifies/copies
; at VBlank -> host publishes presented sequence -> next job may reuse buffer.
GFX_DIAG        equ $ff0080
GFX_BUFFER      equ $300020
GFX_TILE        equ 64          ; VRAM $0800, safely above the 58 font tiles
GFX_GUARD       equ $a55a

GraphicsStart:
        lea GFX_DIAG,a0
        moveq #0,d0
        moveq #7,d1
GFX_ClearDiag:
        move.l d0,(a0)+
        dbra d1,GFX_ClearDiag
        move.l #'M1SV',GFX_DIAG
        move.w #$5000,GFX_DIAG+8
        move.w #3,GFX_DIAG+10
        move.w #$8104,VDP_CTRL  ; hide display while preparing palette/tilemap
        move.l #$c0060000,VDP_CTRL
        move.w #$000e,VDP_DATA  ; palette 3 red
        move.w #$00e0,VDP_DATA  ; palette 4 green
        moveq #19,d6
        bsr SetRow
        lea GFX_Title,a0
        bsr DrawText
        moveq #21,d6
GFX_MapRow:
        bsr SetRow
        moveq #37,d0           ; remove any old M0 text across these rows
GFX_ClearMapRow:
        move.w #0,VDP_DATA
        dbra d0,GFX_ClearMapRow
        bsr SetRow
        moveq #15,d0
GFX_MapTile:
        move.w #GFX_TILE,VDP_DATA
        dbra d0,GFX_MapTile
        addq.w #1,d6
        cmpi.w #25,d6
        bne.s GFX_MapRow
        move.w #$8144,VDP_CTRL
GFX_NextJob:
        clr.w GFX_DIAG+4        ; pending, never reuse a success flag
        addq.w #1,GFX_DIAG+8
        bne.s GFX_SequenceReady
        addq.w #1,GFX_DIAG+8    ; reserve zero as invalid/never-presented
GFX_SequenceReady:
        bsr GraphicsRequest
        cmpi.w #6,GFX_DIAG+4
        bne GFX_Failure
        bsr WaitVBlank         ; transfer only after ACK, during blanking
        move.l #$48000000,VDP_CTRL ; VRAM write $0800
        lea GFX_BUFFER,a0
        moveq #15,d0
GFX_Upload:
        move.w (a0)+,VDP_DATA   ; use ACTUAL DSP output, not expected constants
        dbra d0,GFX_Upload
        move.w GFX_DIAG+8,GFX_DIAG+26 ; sequence actually presented
        addq.w #1,GFX_DIAG+6
        move.w #1,GFX_DIAG+4    ; presented, distinct from ready-to-upload
        moveq #26,d6
        bsr SetRow
        lea GFX_Pass,a0
        bsr DrawText
        move.w GFX_DIAG+8,d4
        bsr DrawHex
        lea GFX_Color,a0
        bsr DrawText
        move.w GFX_DIAG+10,d4
        bsr DrawHex
        moveq #59,d7           ; hold the completed tile for 60 VBlank events
GFX_Hold:
        bsr WaitVBlank
        dbra d7,GFX_Hold
        eori.w #7,GFX_DIAG+10   ; alternate indices 3 and 4
        bra GFX_NextJob
GFX_Failure:
        moveq #26,d6
        bsr SetRow
        lea GFX_Fail,a0
        bsr DrawText
        move.w GFX_DIAG+4,d4
        bsr DrawHex
        rts                    ; leave last presented tile untouched

GraphicsRequest:
        move.w XST_STATUS,d0   ; consume previous completion
        move.w GFX_DIAG+10,d0
        move.w d0,MAILBOX      ; palette index is the ONLY pixel input
        lsl.w #4,d0
        ori.w #2,d0
        move.w d0,d1
        lsl.w #8,d0
        or.w d1,d0             ; independent host expectation C2C2
        move.w d0,GFX_DIAG+12
        not.w d0
        move.w d0,MAILBOX+4
        lea GFX_BUFFER,a0
        moveq #15,d1
GFX_Poison:
        move.w d0,(a0)+
        dbra d1,GFX_Poison
        move.w #GFX_GUARD,GFX_BUFFER-2
        move.w #GFX_GUARD,GFX_BUFFER+32
        move.w GFX_DIAG+8,d0
        not.w d0
        move.w d0,MAILBOX+6
        move.w d0,ACK_SEQUENCE
        clr.w MAILBOX+2
        clr.w GFX_DIAG+18
        move.w #1,MAILBOX+8    ; graphics command
        move.w GFX_DIAG+8,XST  ; request published LAST
        move.l #TIMEOUT_POLLS,d0
GFX_Poll:
        move.w XST_STATUS,d1
        btst #0,d1
        bne.s GFX_Completed
        subq.l #1,d0
        bne.s GFX_Poll
        move.w #2,GFX_DIAG+4
        rts
GFX_Completed:
        move.w ACK_SEQUENCE,GFX_DIAG+18
        move.w MAILBOX+4,GFX_DIAG+14
        move.w MAILBOX+6,GFX_DIAG+16
        move.w GFX_BUFFER-2,GFX_DIAG+22
        move.w GFX_BUFFER+32,GFX_DIAG+24
        move.w GFX_DIAG+8,d0
        cmp.w GFX_DIAG+18,d0
        bne.s GFX_BadSequence
        cmp.w GFX_DIAG+16,d0
        bne.s GFX_BadSequence
        move.w GFX_DIAG+12,d0
        cmp.w GFX_DIAG+14,d0
        bne.s GFX_BadTile
        lea GFX_BUFFER,a0
        moveq #15,d1
        moveq #0,d2
GFX_CheckWord:
        move.w (a0)+,d3
        cmp.w d0,d3
        bne.s GFX_BadTile
        add.w d3,d2
        dbra d1,GFX_CheckWord
        move.w d2,GFX_DIAG+20
        cmpi.w #GFX_GUARD,GFX_DIAG+22
        bne.s GFX_BadGuard
        cmpi.w #GFX_GUARD,GFX_DIAG+24
        bne.s GFX_BadGuard
        move.w #6,GFX_DIAG+4    ; verified result, not yet presented
        rts
GFX_BadSequence:
        move.w #3,GFX_DIAG+4
        rts
GFX_BadTile:
        move.w #4,GFX_DIAG+4
        rts
GFX_BadGuard:
        move.w #5,GFX_DIAG+4
        rts

; Poll a complete VBlank edge, not just an already-active level.
WaitVBlank:
        move.w VDP_CTRL,d0
        btst #3,d0
        bne.s WaitVBlank
GFX_WaitBlankStart:
        move.w VDP_CTRL,d0
        btst #3,d0
        beq.s GFX_WaitBlankStart
        rts

GFX_Title: dc.b 'M1 DSP TILE / DRAM / VRAM',0
GFX_Pass:  dc.b 'M1 PASS SEQ ',0
GFX_Color: dc.b 'COLOR ',0
GFX_Fail:  dc.b 'M1 FAIL CODE ',0
        even

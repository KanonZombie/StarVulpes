; MD joypad -> original SNES joypad word (deliberate input adaptation).
; SNES c_type 0 (02:8CC0): cont0 = B Y Sel St U D L R, contl0 = A X L R.
; MD mapping: B->Y (laser), C->X (boost), A->B (brake), Start->Start,
; six-button pad: Y->A (Nova bomb), X->L, Z->R (bank/roll), Mode->Select.
; Three-button pads report no X/Y/Z/Mode: no bank keys, no bomb.
; Result in M4_LP_JOY; previous tick in M4_LP_LASTJOY (getcont0 copies).
M4LevelReadPad:
        movem.l d0-d3,-(sp)
        move.w M4_LP_JOY,M4_LP_LASTJOY
        move.w sr,-(sp)
        ori.w #$0700,sr
        move.b #$40,$a10009
        ; cycle1 TH=1: C B R L D U ; cycle2 TH=0: St A 0 0 D U
        move.b #$40,$a10003
        nop
        nop
        move.b $a10003,d0 ;TH=1
        move.b #$00,$a10003
        nop
        nop
        move.b $a10003,d1 ;TH=0
        ; six-button: two more TH pulses, third TH=0 read has bits0-3 = 0
        move.b #$40,$a10003
        nop
        nop
        move.b #$00,$a10003
        nop
        nop
        move.b #$40,$a10003
        nop
        nop
        move.b #$00,$a10003
        nop
        nop
        move.b $a10003,d2 ;TH=0 third: 0 in low nibble on a six-button pad
        move.b #$40,$a10003
        nop
        nop
        move.b $a10003,d3 ;TH=1 fourth: Mode X Y Z in bits3..0
        move.b #$00,$a10003
        nop
        nop
        move.b #$40,$a10003
        move.w (sp)+,sr
        not.b d0
        not.b d1
        not.b d3
        moveq #0,d2 ;MD active bits -> SNES word
        btst #0,d0
        beq.s M4PadNoUp
        bset #11,d2
M4PadNoUp:
        btst #1,d0
        beq.s M4PadNoDown
        bset #10,d2
M4PadNoDown:
        btst #2,d0
        beq.s M4PadNoLeft
        bset #9,d2
M4PadNoLeft:
        btst #3,d0
        beq.s M4PadNoRight
        bset #8,d2
M4PadNoRight:
        btst #4,d0 ;B
        beq.s M4PadNoB
        bset #14,d2 ;SNES Y laser
M4PadNoB:
        btst #5,d0 ;C
        beq.s M4PadNoC
        bset #6,d2 ;SNES X boost
M4PadNoC:
        btst #4,d1 ;A
        beq.s M4PadNoA
        bset #15,d2 ;SNES B brake
M4PadNoA:
        btst #5,d1 ;Start
        beq.s M4PadNoStart
        bset #12,d2
M4PadNoStart:
        move.b M4_LP_SIXBUTTON,d0
        beq M4PadDone
        btst #2,d3 ;X
        beq.s M4PadNoX
        bset #5,d2 ;SNES L
M4PadNoX:
        btst #0,d3 ;Z
        beq.s M4PadNoZ
        bset #4,d2 ;SNES R
M4PadNoZ:
        btst #1,d3 ;Y
        beq.s M4PadNoY
        bset #7,d2 ;SNES A bomb
M4PadNoY:
        btst #3,d3 ;Mode
        beq.s M4PadDone
        bset #13,d2 ;SNES Select
M4PadDone:
        ; c_type 02:8CC0/8D56 (controls screen): bit0 swaps B and Y, bit1
        ; swaps up and down.
        move.b M4_CTL_TYPE,d0
        btst #0,d0
        beq.s M4PadNoSwapBY
        move.w d2,d1
        andi.w #$3fff,d2
        btst #15,d1
        beq.s M4PadSwapNoB
        bset #14,d2
M4PadSwapNoB:
        btst #14,d1
        beq.s M4PadNoSwapBY
        bset #15,d2
M4PadNoSwapBY:
        btst #1,d0
        beq.s M4PadNoSwapUD
        move.w d2,d1
        andi.w #$f3ff,d2
        btst #11,d1
        beq.s M4PadSwapNoUp
        bset #10,d2
M4PadSwapNoUp:
        btst #10,d1
        beq.s M4PadNoSwapUD
        bset #11,d2
M4PadNoSwapUD:
        move.w d2,M4_LP_JOY
        movem.l (sp)+,d0-d3
        rts

; Detect a six-button pad once (third TH=0 read has low nibble 0).
M4LevelDetectPad:
        movem.l d0-d1,-(sp)
        move.b #$40,$a10009
        moveq #2,d1
M4PadDetectPulse:
        move.b #$40,$a10003
        nop
        nop
        move.b #$00,$a10003
        nop
        nop
        dbra d1,M4PadDetectPulse
        move.b $a10003,d0
        move.b #$40,$a10003
        andi.b #$0f,d0
        seq M4_LP_SIXBUTTON
        movem.l (sp)+,d0-d1
        rts

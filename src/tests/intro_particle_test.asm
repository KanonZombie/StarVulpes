; Real SSP jobs versus executed commercial GSU; no injected particle state.
; FF45A0:M4PT,status,completed,failed case,WORD offset,expected,actual,sequence.
M4_PART_STATE equ $31d060
M4_PART_STATE_BYTES equ 6016
M4_PART_INPUT equ $31e800
M4_PART_PLOTS equ $31f000
M4_PART_DIAG equ $ff45a0
M4IntroParticleTest:
        movem.l d1-d7/a0-a6,-(sp)
        lea M4_PART_DIAG,a0
        moveq #7,d0
M4PartTestClear:
        clr.l (a0)+
        dbra d0,M4PartTestClear
        move.l #'M4PT',M4_PART_DIAG
        move.w #$a55a,M4_PART_STATE-2
        move.w #$a55a,M4_PART_STATE+M4_PART_STATE_BYTES
        move.w #$a55a,M4_PART_INPUT-2
        move.w #$a55a,M4_PART_INPUT+32
        move.w #$a55a,M4_PART_PLOTS-2
        move.w #$a55a,M4_PART_PLOTS+1440
        lea M4ParticleCases,a4
        move.w #M4_PARTICLE_CASES-1,d7
M4PartTestCase:
        move.w (a4),d0
        btst #0,d0
        beq.s M4PartTestParams
        lea M4_PART_STATE,a0
        move.w #3007,d6
M4PartTestPoison:
        move.w #$dead,(a0)+
        dbra d6,M4PartTestPoison
M4PartTestParams:
        movea.l 4(a4),a0
        lea M4_PART_INPUT,a1
        moveq #15,d6
M4PartTestCopy:
        move.w (a0)+,(a1)+
        dbra d6,M4PartTestCopy
        move.w (a4),d0
        move.w d0,M4_GEO_EXPECT
        move.w d0,MAILBOX+20
        move.w 20(a4),d5
        subq.w #1,d5
M4PartTestJob:
        moveq #11,d0
        bsr M4IntroGeometryRequest
        tst.w d0
        bne M4PartTestBad
        addq.w #1,M4_PART_DIAG+16
        dbra d5,M4PartTestJob
        lea M4_PART_STATE,a0
        movea.l 8(a4),a1
        bsr M4PartTestCompare
        tst.w d0
        bne M4PartTestBad
        lea M4_PART_PLOTS,a0
        movea.l 12(a4),a1
        bsr M4PartTestCompare
        tst.w d0
        bne M4PartTestBad
        move.l 16(a4),d0
        beq.s M4PartTestGuards
        movea.l d0,a1
        lea TEXT_BITMAP,a0
        bsr M4PartTestCompare
        tst.w d0
        bne M4PartTestBad
M4PartTestGuards:
        cmpi.w #$a55a,M4_PART_STATE-2
        bne M4PartTestBad
        cmpi.w #$a55a,M4_PART_STATE+M4_PART_STATE_BYTES
        bne M4PartTestBad
        cmpi.w #$a55a,M4_PART_INPUT-2
        bne M4PartTestBad
        cmpi.w #$a55a,M4_PART_INPUT+32
        bne M4PartTestBad
        cmpi.w #$a55a,M4_PART_PLOTS-2
        bne M4PartTestBad
        cmpi.w #$a55a,M4_PART_PLOTS+1440
        bne M4PartTestBad
        cmpi.w #$a55a,TEXT_BITMAP-2
        bne M4PartTestBad
        cmpi.w #$a55a,TEXT_BITMAP_GUARD_END
        bne M4PartTestBad
        addq.w #1,M4_PART_DIAG+6
        lea 24(a4),a4
        dbra d7,M4PartTestCase
        move.w #1,M4_PART_DIAG+4
        move.w TEXT_VIDEO_DIAG+6,M4_PART_DIAG+18
        moveq #0,d0
        bra.s M4PartTestReturn
M4PartTestBad:
        move.w #-1,M4_PART_DIAG+4
        move.w M4_PART_DIAG+6,M4_PART_DIAG+8
        move.w TEXT_VIDEO_DIAG+6,M4_PART_DIAG+18
        moveq #-1,d0
M4PartTestReturn:
        movem.l (sp)+,d1-d7/a0-a6
        rts

; a0=actual buffer,a1=golden RLE. Compare all literal and zero blocks.
M4PartTestCompare:
        movea.l a0,a3
M4PartTestBlock:
        move.w (a1)+,d6
        beq.s M4PartTestCompared
        bmi.s M4PartTestZeros
        subq.w #1,d6
M4PartTestLiteral:
        move.w (a1)+,d2
        move.w (a0)+,d3
        cmp.w d2,d3
        bne.s M4PartTestMismatch
        dbra d6,M4PartTestLiteral
        bra.s M4PartTestBlock
M4PartTestZeros:
        neg.w d6
        subq.w #1,d6
        moveq #0,d2
M4PartTestZero:
        move.w (a0)+,d3
        bne.s M4PartTestMismatch
        dbra d6,M4PartTestZero
        bra.s M4PartTestBlock
M4PartTestCompared:
        moveq #0,d0
        rts
M4PartTestMismatch:
        move.l a0,d0
        sub.l a3,d0
        subq.l #2,d0
        lsr.l #1,d0
        move.w d0,M4_PART_DIAG+10
        move.w d2,M4_PART_DIAG+12
        move.w d3,M4_PART_DIAG+14
        moveq #-1,d0
        rts

; Game initialization must not inherit alternate seeds/poses from test cases.
M4IntroParticlesReset:
        movem.l d1-d7/a0-a6,-(sp)
        lea M4_PART_INPUT,a0
        moveq #7,d0
M4PartResetParams:
        clr.l (a0)+
        dbra d0,M4PartResetParams
        move.w #1,M4_PART_INPUT
        move.w #1,M4_PART_INPUT+8 ;positive dummy owner; no generation/show
        move.w #$1234,M4_PART_INPUT+16
        move.w #1,M4_GEO_EXPECT
        move.w #1,MAILBOX+20
        moveq #11,d0
        bsr M4IntroGeometryRequest
        movem.l (sp)+,d1-d7/a0-a6
        rts

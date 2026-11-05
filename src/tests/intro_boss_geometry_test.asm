; Execute fresh SVP9 jobs, poisoning all output before every distinct input.
; FF4580: M4BG,status,completed,index,WORD offset,expected,actual,sequence.
M4_BOSS_GEO_DIAG equ $ff4580
M4IntroBossGeometryTest:
        movem.l d1-d7/a0-a6,-(sp)
        lea M4_BOSS_GEO_DIAG,a0
        moveq #7,d0
M4BossGeoClear:
        clr.l (a0)+
        dbra d0,M4BossGeoClear
        move.l #'M4BG',M4_BOSS_GEO_DIAG
        lea M4BossGeometryCases,a4
        move.w #M4_BOSS_GEO_CASES-1,d7
M4BossGeoCase:
        lea M4_GEO_OUTPUT,a0
        move.w #511,d6
M4BossGeoPoison:
        move.w #$dead,(a0)+
        dbra d6,M4BossGeoPoison
        lea M4_GEO_INPUT,a0
        moveq #8,d6
M4BossGeoInput:
        move.w (a4)+,(a0)+
        dbra d6,M4BossGeoInput
        move.w #1,M4_GEO_EXPECT
        move.w #1,MAILBOX+20
        moveq #9,d0
        bsr M4IntroGeometryRequest
        tst.w d0
        bne M4BossGeoBad
        lea M4_GEO_OUTPUT,a0
        moveq #15,d6
        bsr M4BossGeoCompare
        tst.w d0
        bne M4BossGeoBad
        move.w M4_GEO_OUTPUT+18,d6
        mulu.w #5,d6
        subq.w #1,d6
        bsr M4BossGeoCompare
        tst.w d0
        bne M4BossGeoBad
        lea M4_GEO_OUTPUT+872,a0
        move.w M4_GEO_OUTPUT+20,d6
        subq.w #1,d6
        bsr M4BossGeoCompare
        tst.w d0
        bne M4BossGeoBad
        cmpi.w #$a55a,M4_GEO_OUTPUT-2
        bne M4BossGeoBad
        cmpi.w #$a55a,M4_GEO_OUTPUT+40960
        bne M4BossGeoBad
        addq.w #1,M4_BOSS_GEO_DIAG+6
        dbra d7,M4BossGeoCase
        move.w #1,M4_BOSS_GEO_DIAG+4
        move.w TEXT_VIDEO_DIAG+6,M4_BOSS_GEO_DIAG+18
        moveq #0,d0
        bra M4BossGeoReturn
M4BossGeoBad:
        move.w #-1,M4_BOSS_GEO_DIAG+4
        move.w M4_BOSS_GEO_DIAG+6,M4_BOSS_GEO_DIAG+8
        move.w TEXT_VIDEO_DIAG+6,M4_BOSS_GEO_DIAG+18
        moveq #-1,d0
M4BossGeoReturn:
        movem.l (sp)+,d1-d7/a0-a6
        rts
M4BossGeoCompare:
        move.w (a4)+,d2
        move.w (a0)+,d3
        cmp.w d2,d3
        bne.s M4BossGeoMismatch
        dbra d6,M4BossGeoCompare
        moveq #0,d0
        rts
M4BossGeoMismatch:
        move.l a0,d0
        subi.l #M4_GEO_OUTPUT+2,d0
        lsr.l #1,d0
        move.w d0,M4_BOSS_GEO_DIAG+10
        move.w d2,M4_BOSS_GEO_DIAG+12
        move.w d3,M4_BOSS_GEO_DIAG+14
        moveq #-1,d0
        rts

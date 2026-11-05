; FF4550: M4LT,status,total; five completed counts; failure unit.
M4_LATE_DIAG equ $ff4550
M4_LATE_CONTEXT equ $ffbd00
M4_LATE_SCROLL equ $ffbd20
M4IntroLaterTest:
        movem.l d1-d7/a0-a6,-(sp)
        lea M4_LATE_DIAG,a0
        moveq #7,d0
M4LateClear:
        clr.l (a0)+
        dbra d0,M4LateClear
        move.l #'M4LT',M4_LATE_DIAG
        move.w #1,M4_LATE_DIAG+18
        lea M4LateBossCases,a4
        move.w #M4_LATE_BOSS_CASES-1,d7
M4LateBossCase:
        lea M4_LATE_CONTEXT,a0
        movea.l a0,a3
        movea.l a4,a2
        moveq #5,d6
M4LateBossInput:
        move.w (a2)+,(a3)+
        dbra d6,M4LateBossInput
        move.w (a2)+,M4_LATE_SCROLL
        move.w (a2)+,d0
        move.w (a2)+,d1
        lea M4_LATE_SCROLL,a1
        bsr M4IntroBossTick
        movea.l a0,a3
        moveq #5,d6
M4LateBossCompare:
        move.w (a2)+,d3
        cmp.w (a3)+,d3
        bne M4LateBad
        dbra d6,M4LateBossCompare
        move.w (a2)+,d3
        cmp.w M4_LATE_SCROLL,d3
        bne M4LateBad
        addq.w #1,M4_LATE_DIAG+8
        lea 32(a4),a4
        dbra d7,M4LateBossCase
        move.w #2,M4_LATE_DIAG+18
        lea M4LateExitCases,a4
        move.w #M4_LATE_EXIT_CASES-1,d7
M4LateExitCase:
        move.w (a4)+,d0
        move.w (a4)+,d1
        move.w (a4)+,d2
        bsr M4IntroZacoExit
        cmp.w (a4)+,d0
        bne M4LateBad
        addq.w #1,M4_LATE_DIAG+10
        dbra d7,M4LateExitCase
        move.w #3,M4_LATE_DIAG+18
        lea M4LatePhaseCases,a4
        move.w #M4_LATE_PHASE_CASES-1,d7
M4LatePhaseCase:
        lea M4_LATE_CONTEXT,a0
        move.b (a4)+,20(a0)
        move.b (a4)+,18(a0)
        move.b (a4)+,12(a0)
        move.b (a4)+,13(a0)
        move.b (a4)+,14(a0)
        bsr M4IntroZacoPhases01
        move.b (a4)+,d0
        cmp.b 20(a0),d0
        bne M4LateBad
        move.b (a4)+,d0
        cmp.b 18(a0),d0
        bne M4LateBad
        move.b (a4)+,d0
        cmp.b 12(a0),d0
        bne M4LateBad
        move.b (a4)+,d0
        cmp.b 13(a0),d0
        bne M4LateBad
        move.b (a4)+,d0
        cmp.b 14(a0),d0
        bne M4LateBad
        addq.w #1,M4_LATE_DIAG+12
        dbra d7,M4LatePhaseCase
        move.w #4,M4_LATE_DIAG+18
        lea M4LateTitleCases,a4
        move.w #M4_LATE_TITLE_CASES-1,d7
M4LateTitleCase:
        lea M4_LATE_CONTEXT,a0
        move.w (a4)+,4(a0)
        move.w (a4)+,d1
        bsr M4IntroTitleInit
        moveq #0,d0
        move.b 12(a0),d0
        cmp.w (a4)+,d0
        bne M4LateBad
        move.b 13(a0),d0
        cmp.w (a4)+,d0
        bne M4LateBad
        move.b 14(a0),d0
        cmp.w (a4)+,d0
        bne M4LateBad
        move.w 4(a0),d0
        cmp.w (a4)+,d0
        bne M4LateBad
        addq.w #1,M4_LATE_DIAG+14
        dbra d7,M4LateTitleCase
        move.w #5,M4_LATE_DIAG+18
        lea M4LateAnimationCases,a4
        moveq #0,d7
M4LateAnimationCase:
        move.w d7,d0
        bsr M4IntroZacoAnimation
        cmp.b (a4)+,d0
        bne M4LateBad
        addq.w #1,M4_LATE_DIAG+16
        addq.w #1,d7
        cmpi.w #256,d7
        blo.s M4LateAnimationCase
        clr.w M4_LATE_DIAG+18
        move.w #714,M4_LATE_DIAG+6
        move.w #1,M4_LATE_DIAG+4
        moveq #0,d0
        bra.s M4LateTestReturn
M4LateBad:
        move.w #$ffff,M4_LATE_DIAG+4
        moveq #-1,d0
M4LateTestReturn:
        movem.l (sp)+,d1-d7/a0-a6
        rts

; Selected USA ROM units, not substitute motion. See INTRO_LATER_ORIGIN.md.
; Context reuses xyz0/2/4, velocity6/8/10, angles12/13/14,
; countdown18 and state20 from our32-byte actor representation.

; 07:8D4E..8DFA. a0=context,a1=bg2Yscroll WORD,d0=gameframe,d1=playerVelZ.
; Word subtraction tests N exactly as the source, not unsigned comparisons.
M4IntroBossTick:
        move.w (a1),d2
        subi.w #160,d2
        bmi.s M4BossScrollIncrement
        move.w (a1),d2
        subi.w #200,d2
        bpl.s M4BossScrollSlowest
        btst #0,d0
        bne.s M4BossScrollDone
        bra.s M4BossScrollIncrement
M4BossScrollSlowest:
        move.w (a1),d2
        subi.w #232,d2
        beq.s M4BossScrollFour
        bpl.s M4BossScrollDone
M4BossScrollFour:
        move.w d0,d2
        andi.w #3,d2
        bne.s M4BossScrollDone
M4BossScrollIncrement:
        addq.w #1,(a1)
M4BossScrollDone:
        move.w 2(a0),d2
        subi.w #$fe34,d2
        bmi.s M4BossMove
        move.w d0,d2
        andi.w #3,d2
        bne.s M4BossMove
        tst.w 8(a0)
        beq.s M4BossMove
        subq.w #1,8(a0)
M4BossMove:
        move.w 6(a0),d2
        add.w d2,(a0)
        move.w 8(a0),d2
        add.w d2,2(a0)
        move.w 10(a0),d2
        add.w d1,d2
        add.w d2,4(a0)
        rts

; 07:8F0C..8F24, byte-identical at8FC1. d0 animation BYTE -> d0 BYTE.
M4IntroZacoAnimation:
        addq.b #1,d0
        tst.b d0
        bmi.s M4ZacoAnimationMasked
        addi.b #12,d0
M4ZacoAnimationMasked:
        andi.w #127,d0
        cmpi.b #12,d0
        blo.s M4ZacoAnimationReady
        subi.b #12,d0
M4ZacoAnimationReady:
        ori.b #128,d0
        rts

; 07:8FDA..9031. Must fall through to state2 in the same actor tick.
M4IntroZacoPhases01:
        tst.b 20(a0)
        bne.s M4ZacoPhase1
        addq.b #6,14(a0)
        subq.b #1,18(a0)
        bne.s M4ZacoPhase1
        move.b #1,20(a0)
        move.b #42,18(a0)
M4ZacoPhase1:
        cmpi.b #1,20(a0)
        bne.s M4ZacoPhasesDone
        addq.b #4,12(a0)
        addi.b #9,13(a0)
        addq.b #6,14(a0)
        subq.b #1,18(a0)
        bne.s M4ZacoPhasesDone
        move.b #2,20(a0)
        move.b #20,18(a0)
M4ZacoPhasesDone:
        rts

; 07:917C..9193. d0=objZ,d1=playerZ,d2=previous exit BYTE -> d0 exit BYTE.
M4IntroZacoExit:
        sub.w d1,d0
        bmi.s M4ZacoExitSet
        move.w d2,d0
        rts
M4ZacoExitSet:
        moveq #1,d0
        rts

        include '../build/m4-title-parameters.inc'

M4InitTitleRotation macro
        move.b #M4TitleDemoPitch,12(a0)
        move.b #M4TitleDemoYaw,13(a0)
        if M4TitleDemoRoll=0
        clr.b 14(a0)
        else
        move.b #M4TitleDemoRoll,14(a0)
        endif
        endm

; 1F:F600..F624. Init falls through to first tick, which adds roll2 and velZ.
M4IntroTitleInit:
        M4InitTitleRotation
M4IntroTitleTick:
        addq.b #2,14(a0)
        add.w d1,4(a0)
        rts

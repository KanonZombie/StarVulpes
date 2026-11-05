; Whole-stream producer test, not a replacement for object strategies.
; Events are recorded for the original scene consumer. No event is silently
; dropped in the production interface; this diagnostic explicitly commits it.
M4ScriptTest:
        move.l #'M4SC',$ff4400
        clr.l $ff4404
        lea $ff4500,a0
        lea $ff4800,a5
        moveq #0,d7
M4ScriptTestStart:
        movem.l d7/a5,-(sp)
        moveq #0,d0
        moveq #7,d1
        movea.l a0,a1
M4ScriptTestClear:
        move.l d0,(a1)+
        dbra d1,M4ScriptTestClear
        move.w #$7870,(a0)
        tst.w d7
        beq.s M4ScriptTestIntro
        move.w #$79f2,(a0)
M4ScriptTestIntro:
        move.b #13,19(a0)
        move.b #$80,18(a0)
        move.w #$1234,10(a0) ; unrelated flag bits must survive ORs
        move.w #$f3,14(a0) ; loader list must initially block
        moveq #0,d6
        move.w #1023,d7
M4ScriptTestTick:
        move.w 8(a0),d0
        addi.w #65,d0 ; TEST INPUT, not a transplanted camera clock
        bsr M4ScriptTick
M4ScriptTestResult:
        tst.w d0
        bmi M4ScriptTestBad
        beq M4ScriptTestBlocked
        move.w (a0),(a5)+
        move.w 20(a0),(a5)+
        move.w 22(a0),(a5)+
        move.w 24(a0),(a5)+
        move.w 8(a0),(a5)+
        move.w 2(a0),(a5)+
        move.w 10(a0),(a5)+
        move.w d6,(a5)+
        addq.w #1,$ff4406
        move.w 20(a0),d0
        cmpi.w #$78,d0
        bne.s M4ScriptTestObject
        cmpi.w #1,24(a0)
        bne.s M4ScriptTestCommit
        clr.w 4(a0) ; exact embedded block clears original lastplayZ
        clr.w 8(a0) ; and original player's worldZ
        bra.s M4ScriptTestCommit
M4ScriptTestObject:
        cmpi.w #$74,d0
        beq.s M4ScriptTestWordCount
        cmpi.w #$86,d0
        beq.s M4ScriptTestWordCount
        cmpi.w #$76,d0
        bne.s M4ScriptTestCommit
        moveq #0,d1
        move.b 1(a1),d1
        lsl.w #4,d1
        move.w d1,2(a0)
        bra.s M4ScriptTestCommit
M4ScriptTestWordCount:
        bsr M4ScriptOperand
        move.w d1,2(a0)
M4ScriptTestCommit:
        bsr M4ScriptCommit
        bra M4ScriptTestResult
M4ScriptTestBlocked:
        ; Explicit diagnostic consumer: loader acknowledges its list's END;
        ; no timing or DMA completion behavior is claimed by this test.
        cmpi.w #$64,20(a0)
        bne.s M4ScriptTestFade
        move.w #$f6,14(a0)
M4ScriptTestFade:
        ; Fade is an external presentation-completion event, not Tick itself.
        ; This diagnostic provides blank/zero only to unblock script flow.
        clr.b 17(a0)
        move.b #$80,18(a0)
        addq.w #1,d6
        dbra d7,M4ScriptTestTick
        ; Snapshot the final loop state; neither script runs off its boundary.
        movem.l (sp)+,d7/a1
        movea.l a1,a5
        addq.w #1,d7
        cmpi.w #2,d7
        beq.s M4ScriptTestDone
        ; Event buffer appended, not overwritten between intro and title.
        moveq #0,d0
        move.w $ff4406,d0
        lsl.w #4,d0
        lea $ff4800,a5
        adda.w d0,a5
        bra M4ScriptTestStart
M4ScriptTestDone:
        ; Execute original-derived word boundary vectors on the real 68000.
        lea M4ScriptNumericVectors,a4
        lea $ffb000,a5
        move.w #M4_SCRIPT_NUMERIC_CASES-1,d7
M4ScriptNumericNext:
        move.w #$7875,(a0)
        move.w (a4)+,2(a0)
        move.w (a4)+,4(a0)
        move.w (a4)+,d0
        move.w #$f3,14(a0)
        clr.w 26(a0)
        bsr M4ScriptTick
        tst.w d0
        bne.s M4ScriptNumericBad
        move.w 2(a0),(a5)+
        move.w 4(a0),(a5)+
        move.w 6(a0),(a5)+
        move.w (a0),(a5)+
        moveq #3,d1
        lea -8(a5),a1
M4ScriptNumericCheck:
        move.w (a4)+,d0
        cmp.w (a1)+,d0
        bne.s M4ScriptNumericBad
        dbra d1,M4ScriptNumericCheck
        dbra d7,M4ScriptNumericNext
        move.w #M4_SCRIPT_NUMERIC_CASES,$ff4408
        ; An event remains pending until committed; Tick must not mutate it.
        move.w #1,26(a0)
        move.l (a0),d4
        move.l 4(a0),d5
        moveq #1,d0
        bsr M4ScriptTick
        cmpi.w #$ffff,d0
        bne.s M4ScriptNumericBad
        cmp.l (a0),d4
        bne.s M4ScriptNumericBad
        cmp.l 4(a0),d5
        bne.s M4ScriptNumericBad
        move.w #1,$ff4404
        rts
M4ScriptNumericBad:
        move.w #$ffff,$ff4404
        rts
M4ScriptTestBad:
        movem.l (sp)+,d7/a5
        move.w #$ffff,$ff4404
        rts
M4ScriptNumericVectors:
        include '../build/m4-script-numeric.inc'

; Six exact bitmap tests for own MD/SVP visual backend, not game logic.
; All14336 output words checked, including zeros, via ROM RLE expectations.
; Header FF44D0:M4PY,status,count. Six records(seq,result,sum,status) follow.
M4IntroPolyTest:
        move.l #'M4PY',$ff44d0
        clr.l $ff44d4
        lea M4IntroPolyCases,a4
        lea $ff44d8,a5
        move.w #M4_POLY_TEST_CASES-1,d7
M4IntroPolyTestNext:
        move.w (a4),MAILBOX+20
        move.w 2(a4),MAILBOX+22
        movea.l 6(a4),a0
        lea M4_POLY_INPUT,a1
        move.w (a4),d0
        beq.s M4IntroPolyInputsDone
        lsl.w #3,d0
        subq.w #1,d0
M4IntroPolyCopyInput:
        move.w (a0)+,(a1)+
        dbra d0,M4IntroPolyCopyInput
M4IntroPolyInputsDone:
        addq.w #1,TEXT_VIDEO_DIAG+6
        move.w TEXT_VIDEO_DIAG+6,(a5)
        moveq #8,d0
        bsr M4TextVideoRequest
        move.w d0,6(a5)
        tst.w d0
        bne M4IntroPolyTestBad
        move.w MAILBOX+4,2(a5)
        move.w MAILBOX+16,4(a5)
        move.w 4(a4),d0
        cmp.w MAILBOX+16,d0
        bne M4IntroPolyTestBad
        movea.l 10(a4),a0
        lea TEXT_BITMAP,a1
        clr.w d6
M4IntroPolyExpectedBlock:
        move.w (a0)+,d0
        beq.s M4IntroPolyCompared
        bmi.s M4IntroPolyZeroBlock
        add.w d0,d6
        subq.w #1,d0
M4IntroPolyLiteral:
        move.w (a0)+,d1
        cmp.w (a1)+,d1
        bne.s M4IntroPolyTestBad
        dbra d0,M4IntroPolyLiteral
        bra.s M4IntroPolyExpectedBlock
M4IntroPolyZeroBlock:
        neg.w d0
        add.w d0,d6
        subq.w #1,d0
M4IntroPolyZero:
        tst.w (a1)+
        bne.s M4IntroPolyTestBad
        dbra d0,M4IntroPolyZero
        bra.s M4IntroPolyExpectedBlock
M4IntroPolyCompared:
        cmpi.w #M4_RENDER_WORDS,d6
        bne.s M4IntroPolyTestBad
        move.w #1,6(a5)
        addq.w #1,$ff44d6
        lea 8(a5),a5
        lea 14(a4),a4
        dbra d7,M4IntroPolyTestNext
        move.w #1,$ff44d4
        rts
M4IntroPolyTestBad:
        move.w #$ffff,$ff44d4
        rts

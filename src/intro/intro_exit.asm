; Semantic translation of selected USA ROM 1F:F5D0..F5EF.
; Input a0: frame.w, exit.b, padHi.b, padLo.b, fadeMode.b, fadeTimer.b, spare.
; Called AFTER a logical game update, not once per presented image.
; Output d0 = 0 continue / 1 begin fade. Only mode/timer may change.
; Original LDA frame runs with M=8: wrap at 256 matters, not a 16-bit >=30.
        include '../build/m4-origin.inc'
M4IntroExit:
        moveq #0,d0
        cmpi.b #M4_INTRO_MIN_FRAME,1(a0)
        blo.s M4IntroReturn
        tst.b 2(a0)
        bne.s M4IntroFade
        move.b 3(a0),d0
        or.b 4(a0),d0
        bne.s M4IntroFade
        moveq #0,d0
M4IntroReturn:
        rts
M4IntroFade:
        move.b #M4IntroExitFadeMode,5(a0)
        move.b #M4IntroExitFadeTicks,6(a0)
        moveq #1,d0
        rts

; ROM 1F:F514..F529: timer decrement precedes timeout and Start checks.
; a0: frame.w, remaining.w, padHi.b, spare.b. d0: 0 wait, 1 Start, 2 timeout.
; This decision does not yet perform original fade/music/reinit side effects.
M4TitleDecision:
        moveq #2,d0
        subq.w #1,2(a0)
        beq.s M4TitleReturn
        moveq #0,d0
        cmpi.w #M4TitleStartGate,(a0)
        blo.s M4TitleReturn
        btst #4,4(a0)
        beq.s M4TitleReturn
        moveq #1,d0
M4TitleReturn:
        rts

; Bounded unit harness. This is not the M4 intro presentation.
M4LogicTest:
        lea $ff2000,a0
        moveq #0,d0
        move.w #$120/4-1,d1
M4ClearTests:
        move.l d0,(a0)+
        dbra d1,M4ClearTests
        move.l #'M4UT',$ff2000
        lea M4Vectors,a4
        lea $ff2020,a5
        moveq #15,d7
M4TestNext:
        move.l (a4)+,(a5)
        move.l (a4)+,4(a5)
        move.w (a4)+,12(a5)
        movea.l a5,a0
        bsr M4IntroExit
        move.w d0,8(a5)
        move.b 5(a5),10(a5)
        move.b 6(a5),11(a5)
        addq.w #1,$ff2006
        cmp.w 12(a5),d0
        bne.s M4TestFailed
        move.w #1,14(a5)
        lea 16(a5),a5
        dbra d7,M4TestNext
        move.w #1,$ff2004
        bsr M4TitleTest
        cmpi.w #1,$ff2204
        bne.s M4TestFailed
        bsr M4FadeTest
        cmpi.w #1,$ff2404
        bne.s M4TestFailed
        bsr M4MapFadeTest
        cmpi.w #1,$ff3404
        bne.s M4TestFailed
        moveq #20,d6
        jsr SetRow
        lea M4Pass,a0
        jmp DrawText
M4TestFailed:
        move.w #$ffff,$ff2004
        moveq #20,d6
        jsr SetRow
        lea M4Fail,a0
        jmp DrawText
M4Pass: dc.b 'M4 INTRO/TITLE/FADE UNITS PASS',0
M4Fail: dc.b 'M4 INTRO/TITLE/FADE UNITS FAIL',0
        even
M4Vectors:
        dc.w 0
        dc.b 1,1,1,5,9,0
        dc.w 0
        dc.w M4_INTRO_MIN_FRAME-1
        dc.b 1,1,1,5,9,0
        dc.w 0
        dc.w M4_INTRO_MIN_FRAME
        dc.b 0,0,0,5,9,0
        dc.w 0
        dc.w M4_INTRO_MIN_FRAME
        dc.b 1,0,0,5,9,0
        dc.w 1
        dc.w M4_INTRO_MIN_FRAME
        dc.b 0,$10,0,5,9,0
        dc.w 1
        dc.w M4_INTRO_MIN_FRAME
        dc.b 0,0,1,5,9,0
        dc.w 1
        dc.w M4_INTRO_MIN_FRAME+1
        dc.b 0,0,0,5,9,0
        dc.w 0
        dc.w 255
        dc.b 0,0,$80,5,9,0
        dc.w 1
        dc.w 256
        dc.b 1,1,1,5,9,0
        dc.w 0
        dc.w 256+M4_INTRO_MIN_FRAME-1
        dc.b 1,1,1,5,9,0
        dc.w 0
        dc.w 256+M4_INTRO_MIN_FRAME
        dc.b 1,0,0,5,9,0
        dc.w 1
        dc.w $ffff
        dc.b 0,1,0,5,9,0
        dc.w 1
        dc.w M4_INTRO_MIN_FRAME
        dc.b $80,0,0,$fd,$ff,0
        dc.w 1
        dc.w M4_INTRO_MIN_FRAME
        dc.b 0,0,0,$fd,$ff,0
        dc.w 0
        dc.w M4_INTRO_MIN_FRAME-2
        dc.b 0,0,$ff,$fd,$ff,0
        dc.w 0
        dc.w M4TitleStartGate
        dc.b 0,$80,$80,0,0,0
        dc.w 1

M4TitleTest:
        move.l #'M4TT',$ff2200
        clr.l $ff2204
        lea M4TitleVectors,a4
        lea $ff2220,a5
        moveq #15,d7
M4TitleTestNext:
        move.l (a4)+,(a5)
        move.l (a4)+,4(a5)
        move.w 6(a5),12(a5)
        movea.l a5,a0
        bsr M4TitleDecision
        move.w d0,8(a5)
        move.w 2(a5),10(a5)
        addq.w #1,$ff2206
        cmp.w 12(a5),d0
        bne.s M4TitleTestFailed
        move.w #1,14(a5)
        lea 16(a5),a5
        dbra d7,M4TitleTestNext
        move.w #1,$ff2204
        rts
M4TitleTestFailed:
        move.w #$ffff,$ff2204
        rts
M4TitleVectors:
        dc.w 0,M4TitleLoopTicks,$1000,0
        dc.w M4TitleStartGate-1,M4TitleLoopTicks,$1000,0
        dc.w M4TitleStartGate,M4TitleLoopTicks,$1000,1
        dc.w M4TitleStartGate,M4TitleLoopTicks,0,0
        dc.w M4TitleStartGate,M4TitleLoopTicks,$0100,0
        dc.w M4TitleStartGate,M4TitleLoopTicks,$8000,0
        dc.w 255,2,$1000,1
        dc.w 256,2,$1000,1
        dc.w M4TitleStartGate,1,$1000,2
        dc.w 0,1,0,2
        dc.w M4TitleStartGate,0,$1000,1
        dc.w M4TitleStartGate-1,0,$1000,0
        dc.w $ffff,$ffff,$1000,1
        dc.w M4TitleStartGate,2,$ff00,1
        dc.w M4TitleStartGate,2,$ef00,0
        dc.w M4TitleStartGate,2,0,0
        include 'system/fade.asm'
        include 'system/map_fade.asm'

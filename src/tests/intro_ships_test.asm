; 688 intermediate states computed by executing selected-ROM 65816 bytes.
; Real target code runs full trajectories with four gameframe phases,
; positive/negative player velocity and WORD position wrap.
; FF44A0:magic,status.word,passed.word,trajectoriesLeft,statesLeft,frame,delta.
M4IntroShipTest:
        move.l #'M4SH',$ff44a0
        clr.l $ff44a4
        move.w #M4_INTRO_SHIP_TRAJECTORIES,$ff44a8
        lea M4IntroShipVectorsCases,a4
M4IntroShipTestNext:
        lea $ffa0e0,a0
        move.w (a4)+,d0
        move.w (a4)+,$ff44ac
        move.w (a4)+,$ff44ae
        move.w (a4)+,d1
        move.w (a4)+,$ff44aa
        bsr M4IntroShipInit
        tst.w d0
        bne.s M4IntroShipTestBad
M4IntroShipTestTick:
        move.w $ff44ac,d0
        move.w $ff44ae,d1
        bsr M4IntroShipTick
        cmpi.w #-1,d0
        beq.s M4IntroShipTestBad
        movea.l a0,a1
        moveq #31,d2
M4IntroShipTestCompare:
        move.b (a4)+,d3
        cmp.b (a1)+,d3
        bne.s M4IntroShipTestBad
        dbra d2,M4IntroShipTestCompare
        addq.w #1,$ff44a6
        addq.w #1,$ff44ac
        subq.w #1,$ff44aa
        bne.s M4IntroShipTestTick
        subq.w #1,$ff44a8
        bne.s M4IntroShipTestNext
        cmpi.w #M4_INTRO_SHIP_CASES,$ff44a6
        bne.s M4IntroShipTestBad
        move.w #1,$ff44a4
        rts
M4IntroShipTestBad:
        move.w #$ffff,$ff44a4
        rts

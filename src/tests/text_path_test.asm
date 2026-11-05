M4TextPathTest:
        move.l #'M4TX',$ff4440
        clr.l $ff4444
        lea $ffa000,a0
        lea M4TextZoomVectors,a4
        lea $ffb400,a5
        move.w #M4_TEXT_ZOOM_CASES-1,d7
M4TextZoomTestNext:
        move.w (a4)+,(a0)
        move.w (a0),(a5)+
        bsr M4TextZoom
        move.w (a0),(a5)+
        move.w d0,(a5)+
        move.w (a4)+,d1
        cmp.w (a0),d1
        bne M4TextPathTestBad
        cmp.w (a4)+,d0
        bne M4TextPathTestBad
        addq.w #1,$ff4446
        dbra d7,M4TextZoomTestNext
        lea $ffa000,a1
        moveq #0,d0
        moveq #15,d1
M4TextTestClear:
        move.l d0,(a1)+
        dbra d1,M4TextTestClear
        move.w #-3000,(a0)
        move.w #-100,2(a0)
        move.w #4000,4(a0)
        move.w #$44ef,6(a0)
        move.b #14,10(a0)
        move.w #1,16(a0)
        move.w #$c8e3,18(a0)
        lea 32(a0),a1
        move.w #3000,(a1)
        move.w #100,2(a1)
        move.w #4000,4(a1)
        move.w #$44ef,6(a1)
        move.b #14,10(a1)
        move.w #1,16(a1)
        move.w #$c8f6,18(a1)
        move.b #$e0,20(a1)
        lea $ffb800,a5
        moveq #0,d6
M4TextTestTick:
        moveq #0,d5
M4TextTestObject:
        lea $ffa000,a0
        tst.w d5
        beq.s M4TextTestInput
        lea 32(a0),a0
M4TextTestInput:
        ; Supplied camera/advance inputs, deliberately including word wrap.
        ; The game driver must later provide these at its original invocation.
        move.w d6,d0
        mulu.w #61,d0
        addi.w #$fff0,d0
        moveq #65,d1
        bsr M4TextPathTick
        tst.w d0
        bne M4TextPathTestBad
        moveq #7,d0
        movea.l a0,a1
M4TextTestRecord:
        move.l (a1)+,(a5)+
        dbra d0,M4TextTestRecord
        addq.w #1,d5
        cmpi.w #2,d5
        bne M4TextTestObject
        addq.w #1,d6
        cmpi.w #48,d6
        bne M4TextTestTick
        move.w #48,$ff4448
        move.w #1,$ff4444
        rts
M4TextPathTestBad:
        move.w #$ffff,$ff4444
        rts
M4TextZoomVectors:
        include '../build/intro-text-zoom.inc'

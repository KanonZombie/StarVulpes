; Actual 68000 correspondence records, separate from production context.
; Header FF4480: 'M4CM',status.w,numericCount.w,trajectoryCount.w.
; FFc400:56 records(pviewZ.w,velocity.w); FFc600:71 records
; (worldZ.w,pviewZ.w,velocity.w,viewZ.w), frames2..72.
M4IntroCameraTest:
        movem.l d0-d7/a0-a6,-(sp)
        move.l #'M4CM',$ff4480
        clr.l $ff4484
        clr.w $ff4488
        lea $ffa080,a0
        lea M4IntroCameraVectors,a4
        lea $ffc400,a5
        move.w #M4_CAMERA_CASES-1,d7
M4IntroCameraTestNext:
        move.w (a4)+,4(a0)
        move.w (a4)+,6(a0)
        move.w (a4)+,2(a0)
        move.w (a4)+,12(a0)
        move.w (a4)+,d0
        move.b d0,15(a0)
        bsr M4IntroCameraViewMove
        move.w 4(a0),(a5)+
        move.w 6(a0),(a5)+
        move.w (a4)+,d0
        cmp.w 4(a0),d0
        bne M4IntroCameraTestBad
        move.w (a4)+,d0
        cmp.w 6(a0),d0
        bne M4IntroCameraTestBad
        addq.w #1,$ff4486
        dbra d7,M4IntroCameraTestNext
        moveq #0,d0
        move.l d0,(a0)
        move.l d0,4(a0)
        move.l d0,8(a0)
        move.l d0,12(a0)
        move.l d0,16(a0)
        move.w #63,2(a0) ; Original background initializer retains previous cache
        bsr M4IntroCameraReset
        lea $ffc600,a5
        moveq #70,d7
        bra.s M4IntroCameraTestPlayer
M4IntroCameraTestTick:
        bsr M4IntroCameraBeginTick
M4IntroCameraTestPlayer:
        bsr M4IntroCameraPlayer
        tst.w d0
        bne.s M4IntroCameraTestBad
        bsr M4IntroCameraFinish
        move.w (a0),(a5)+
        move.w 4(a0),(a5)+
        move.w 6(a0),(a5)+
        move.w 8(a0),(a5)+
        addq.w #1,$ff4488
        dbra d7,M4IntroCameraTestTick
        move.w #1,$ff4484
        bra.s M4IntroCameraTestReturn
M4IntroCameraTestBad:
        move.w #$ffff,$ff4484
M4IntroCameraTestReturn:
        movem.l (sp)+,d0-d7/a0-a6
        rts
M4IntroCameraVectors:
        include '../build/intro-camera-cases.inc'

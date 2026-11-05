; Selected-ROM dintro1, paths base 04:A3FE + index 44EF.
; a0: X.w,Y.w,Z.w,path.w,count.b,trail.b,depth.b,relative.b,
; keepTrigger.w,fadeTrigger.w,alive.w,text.w,size.b,spare.b,
; emitTrail.w,trailX.w,trailY.w,trailZ.w (32 bytes).
; Tick d0=viewposZ at invocation, d1=original lastZchange. No camera clock here.
; Outputs d0=0 success / FFFF unsupported path; clobbers d0/d1/d2.
; A trail request records position BEFORE keep4000, like PATHS .move.
M4TextPathTick:
        clr.w 22(a0)
        tst.w 16(a0)
        beq M4TextPathReturn
        move.w d0,d2
        move.w 6(a0),d0
        cmpi.w #$45b5,d0
        beq M4TextPathRemove
        cmpi.w #$44ef,d0
        beq.s M4TextPathInit
        cmpi.w #$44f6,d0
        beq.s M4TextPathZoom
        cmpi.w #$4532,d0
        beq.s M4TextPathWait
        cmpi.w #$4538,d0
        beq M4TextPathMove
        moveq #-1,d0
        rts
M4TextPathInit:
        move.b #1,11(a0)
        move.w #$454f,12(a0)
        move.b #7,9(a0)
M4TextPathZoom:
        move.w d1,-(sp)
        bsr M4TextZoom
        move.w (sp)+,d1
        cmpi.w #$4530,d0
        beq.s M4TextPathCentered
        move.w #$44f6,6(a0) ; P_GOTO yields to .move, not another zoom
        bra M4TextPathMove
M4TextPathCentered:
        clr.b 9(a0)
        move.w #$4532,6(a0)
M4TextPathWait:
        cmpi.b #20,8(a0)
        beq.s M4TextPathAfterWait
        addq.b #1,8(a0)
        bra.s M4TextPathMove
M4TextPathAfterWait:
        clr.b 8(a0)
        move.w #$453b,14(a0)
        move.w #$4538,6(a0)
M4TextPathMove:
        tst.b 11(a0)
        beq.s M4TextPathTrail
        add.w d1,4(a0)
M4TextPathTrail:
        tst.b 9(a0)
        beq.s M4TextPathTriggers
        moveq #0,d0
        move.b 9(a0),d0
        move.w d0,22(a0)
        move.l (a0),24(a0)
        move.w 4(a0),28(a0)
M4TextPathTriggers:
        tst.w 12(a0)
        beq.s M4TextPathFade
        addi.w #4000,d2
        move.w d2,4(a0)
M4TextPathFade:
        tst.w 14(a0)
        beq.s M4TextPathReturn
        subq.b #1,10(a0)
        cmpi.b #9,10(a0)
        bne.s M4TextPathReturn
        ; P_FORCE replaces the saved main path; P_REMOVE runs NEXT tick.
        move.w #$45b5,6(a0)
M4TextPathReturn:
        moveq #0,d0
        rts
M4TextPathRemove:
        clr.w 16(a0)
        bra.s M4TextPathReturn

; Exact original zoom semantic: signed divide by two toward zero, clamp,
; negate/add word, force tiny +/-1 to center, return the original path index.
M4TextZoom:
        move.w (a0),d0
        move.w d0,d1
        asr.w #1,d1
        tst.w d0
        bpl.s M4TextZoomHalf
        btst #0,d0
        beq.s M4TextZoomHalf
        addq.w #1,d1
M4TextZoomHalf:
        cmpi.w #-400,d1
        bpl.s M4TextZoomLower
        move.w #-400,d1
M4TextZoomLower:
        cmpi.w #400,d1
        bmi.s M4TextZoomClamped
        move.w #400,d1
M4TextZoomClamped:
        neg.w d1
        beq.s M4TextZoomCenter
        add.w d1,d0
        move.w d0,(a0)
        bne.s M4TextZoomContinue
M4TextZoomCenter:
        clr.w (a0)
        move.w #$4530,d0
        rts
M4TextZoomContinue:
        move.w #$452d,d0
        rts


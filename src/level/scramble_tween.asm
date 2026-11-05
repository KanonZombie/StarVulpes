; Optional single midpoint in the fixed-camera SCRAMBLE tunnel only.
; Visual adaptation: shortest-arc BYTE angles and WORD positions, no new
; strategy/RNG/audio/HUD/fade/collision step. Full endpoints remain exact.
; These intro-only buffers are dead throughout the level. No overlap with
; the draw list B200, SAT5400/5A00, shadows5800, object/path RAM6000/7000.
M4_SC_TIME_SAVE equ $ffb400 ;64 x64 current object contexts
M4_SC_TIME_PREV equ $ffc400 ;64 x24 previous pose + identity/visibility
M4_SC_TIME_LP equ $ffca00 ;256 current player-state bytes
M4_SC_TIME_VIEW equ $ffcb00 ;80 current view-state bytes
M4_SC_TIME_GEO equ $ffcb50 ;64 current view/grid DRAM bytes
M4_SC_TIME_SPP equ $ffcb90 ;32 current crosshair/fire scratch bytes

M4ScTimingSnapshot:
        clr.w M4_SC_TIME_VALID
        tst.w M4_SC_TIME_ON
        beq M4ScSnapshotDone
        tst.w INTRO_CAPTURE
        bne M4ScSnapshotDone
        cmpi.b #3,M4_SC_VIEWTYPE
        bne M4ScSnapshotDone
        tst.b M4_SC_DOTS
        bne M4ScSnapshotDone
        move.l M4_SC_VIEWPOS,M4_SC_TIME_CAMERA
        move.w M4_SC_VIEWPOS+4,M4_SC_TIME_CAMERA+4
        lea M4_LV_OBJ,a0
        lea M4_SC_TIME_PREV,a1
        moveq #63,d7
M4ScSnapshotObject:
        move.l (a0),(a1)
        move.l 4(a0),4(a1)
        move.l 8(a0),8(a1)
        move.l 12(a0),12(a1)
        move.w 46(a0),16(a1)
        move.w 52(a0),18(a1)
        move.b 49(a0),20(a1)
        move.b 21(a0),21(a1)
        move.w 22(a0),22(a1)
        lea 64(a0),a0
        lea 24(a1),a1
        dbra d7,M4ScSnapshotObject
        move.w #1,M4_SC_TIME_VALID
M4ScSnapshotDone:
        rts

; a0 source,a1 destination,d0 LONG count minus1. Both buffers WORD-aligned.
M4ScTimingCopy:
        move.l (a0)+,(a1)+
        dbra d0,M4ScTimingCopy
        rts

M4ScTimingTween:
        movem.l d1-d7/a0-a6,-(sp)
        moveq #0,d0
        tst.w M4_SC_TIME_VALID
        beq M4ScTweenReturn
        tst.w M4_SC_TIME_ON
        beq M4ScTweenReturn
        tst.w INTRO_CAPTURE
        bne M4ScTweenReturn
        cmpi.b #3,M4_SC_VIEWTYPE
        bne M4ScTweenReturn
        tst.b M4_SC_DOTS
        bne M4ScTweenReturn
        tst.b M4_SC_WIPE
        bne M4ScTweenReturn
        move.b M4_BRIGHT,d0
        andi.w #15,d0
        cmpi.w #15,d0
        bne M4ScTweenSkip
        move.w LV_PLAYER+4,d0
        sub.w M4_SC_TIME_PREV+4,d0
        bpl.s M4ScTweenDistance
        neg.w d0
M4ScTweenDistance:
        cmpi.w #256,d0 ;do not interpolate the ExitBase teleport
        bhi M4ScTweenSkip
        jsr M4ScTimingDelay
        move.w M4_SC_TIME_COST,d1
        addq.w #3,d1 ;measured extra cost plus three VBlanks for the endpoint
        cmp.w d1,d0
        blo M4ScTweenSkip
        jsr M4PipeFlush ;do not change any inputs still read by the SVP
        tst.w d0
        bne M4ScTweenReturn
        move.w M4_CLOCK,M4_SC_TIME_STAMP
        lea M4_LV_OBJ,a0
        lea M4_SC_TIME_SAVE,a1
        move.w #1023,d0
        bsr M4ScTimingCopy
        lea M4_LP,a0
        lea M4_SC_TIME_LP,a1
        moveq #63,d0
        bsr M4ScTimingCopy
        lea M4_LVW,a0
        lea M4_SC_TIME_VIEW,a1
        moveq #19,d0
        bsr M4ScTimingCopy
        lea M4_GEO_VIEW,a0
        lea M4_SC_TIME_GEO,a1
        moveq #15,d0
        bsr M4ScTimingCopy
        lea M4_SPP,a0
        lea M4_SC_TIME_SPP,a1
        moveq #7,d0
        bsr M4ScTimingCopy
        move.l M4_SC_VIEWPOS,M4_SC_TIME_SAVECAM
        move.w M4_SC_VIEWPOS+4,M4_SC_TIME_SAVECAM+4
M4ScTweenInputsSaved:
        lea M4_LV_OBJ,a0
        lea M4_SC_TIME_PREV,a1
        moveq #63,d7
M4ScTweenObject:
        move.w 22(a0),d0
        beq.s M4ScTweenNext
        cmp.w 22(a1),d0
        bne.s M4ScTweenNext
        move.w 46(a0),d0
        cmp.w 16(a1),d0
        bne.s M4ScTweenNext
        move.w 52(a0),d0
        cmp.w 18(a1),d0
        bne.s M4ScTweenNext
        move.b 49(a0),d0
        move.b 20(a1),d1
        eor.b d1,d0
        btst #1,d0
        bne.s M4ScTweenNext
        move.b 21(a0),d0
        cmp.b 21(a1),d0
        bne.s M4ScTweenNext
        moveq #0,d6
        moveq #2,d5
M4ScTweenPosition:
        move.w (a0,d6.w),d0
        sub.w (a1,d6.w),d0
        asr.w #1,d0
        add.w (a1,d6.w),d0
        move.w d0,(a0,d6.w)
        addq.w #2,d6
        dbra d5,M4ScTweenPosition
        moveq #12,d6
        moveq #2,d5
M4ScTweenAngle:
        move.b (a0,d6.w),d0
        sub.b (a1,d6.w),d0
        asr.b #1,d0
        add.b (a1,d6.w),d0
        move.b d0,(a0,d6.w)
        addq.w #1,d6
        dbra d5,M4ScTweenAngle
M4ScTweenNext:
        lea 64(a0),a0
        lea 24(a1),a1
        dbra d7,M4ScTweenObject
        lea M4_SC_VIEWPOS,a0
        lea M4_SC_TIME_CAMERA,a1
        moveq #2,d5
M4ScTweenCamera:
        move.w (a0),d0
        sub.w (a1)+,d0
        asr.w #1,d0
        add.w -2(a1),d0
        move.w d0,(a0)+
        dbra d5,M4ScTweenCamera
        move.w #1,M4_SC_TIME_TWEEN
        jsr M4LevelView ;recompute look-at/orthogonal matrix; no matrix blending
        jsr M4LevelDraw ;SVP geometry/raster; callback is disabled for this image
        tst.w d0
        bne.s M4ScTweenRestore
        jsr M4LevelStarsInput
        tst.w d0
        bne.s M4ScTweenRestore
        moveq #0,d0
        jsr M4TextVideoDraw
        tst.w d0
        bne.s M4ScTweenRestore
        ; Cmd9/10 have consumed the temporary poses/view. Cmd8 consumes the
        ; sealed polygon inputs, and grid/stars are off in this tunnel.
        ; Keep the normal cmd8/DMA overlap instead of waiting for a flip here.
        addq.w #1,M4_SC_TIME_EXTRA
M4ScTweenRestore:
        move.w d0,-(sp)
        lea M4_SC_TIME_SAVE,a0
        lea M4_LV_OBJ,a1
        move.w #1023,d0
        bsr M4ScTimingCopy
        lea M4_SC_TIME_LP,a0
        lea M4_LP,a1
        moveq #63,d0
        bsr M4ScTimingCopy
        lea M4_SC_TIME_VIEW,a0
        lea M4_LVW,a1
        moveq #19,d0
        bsr M4ScTimingCopy
        lea M4_SC_TIME_GEO,a0
        lea M4_GEO_VIEW,a1
        moveq #15,d0
        bsr M4ScTimingCopy
        lea M4_SC_TIME_SPP,a0
        lea M4_SPP,a1
        moveq #7,d0
        bsr M4ScTimingCopy
        move.l M4_SC_TIME_SAVECAM,M4_SC_VIEWPOS
        move.w M4_SC_TIME_SAVECAM+4,M4_SC_VIEWPOS+4
        clr.w M4_SC_TIME_TWEEN
        if def(M4_GRAPHICS117)
        move.w #$ffff,G117_EPOCH ;never reuse midpoint view coordinates for logic
        else
        dcb.w 4,$4e71 ;same layout in the generated-program comparison build
        endif
        move.w M4_CLOCK,d0
        sub.w M4_SC_TIME_STAMP,d0
        cmpi.w #2,d0
        bhs.s M4ScTweenCost
        moveq #2,d0
M4ScTweenCost:
        move.w d0,M4_SC_TIME_COST
        move.w (sp)+,d0
        bra.s M4ScTweenReturn
M4ScTweenSkip:
        moveq #0,d0
M4ScTweenReturn:
        movem.l (sp)+,d1-d7/a0-a6
        rts

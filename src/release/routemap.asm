; Route-map video ownership changes. Drain the previous bitmap before
; replacing plane A/B mappings or their palettes. Display stays blank until
; the next complete image publishes its own palette at the VR DMA tail.
ReleaseMapHold equ M4VR_SCENE_HOLD
ReleaseMapBlack:
        movem.l d0-d7/a0-a6,-(sp)
        jsr M4RmNativeLeave
        jsr M4PipeFlush
        bne.s ReleaseMapFailed
        jsr M4VRWaitWork
        bne.s ReleaseMapFailed
ReleaseMapDrain:
        tst.w M4VR_ERROR
        bne.s ReleaseMapFailed
        tst.w M4VR_READY_BUSY
        bne.s ReleaseMapDrain
ReleaseMapVBlank:
        move.w VDP_CTRL,d0
        btst #3,d0
        beq.s ReleaseMapVBlank
        move.w sr,-(sp)
        ori.w #$0700,sr
        move.w #$8134,VDP_CTRL
        move.b #1,ReleaseMapHold
        move.b #$ff,M4VR_SHOWN_BRIGHT
        move.w (sp)+,sr
        movem.l (sp)+,d0-d7/a0-a6
        rts
ReleaseMapFailed:
        jmp M4IntroFailed
ReleaseMapAlone:
        bsr ReleaseMapBlack
        movem.l d0-d1/a0-a2,-(sp)
        moveq #0,d0
        jmp M4RmPlanetAlone+6
ReleaseMapPepper:
        bsr ReleaseMapBlack
        movem.l d0-d2/a0-a1,-(sp)
        move.w sr,-(sp)
        jmp M4RmPepperVideo+6
; Visual interpolation between logical radius steps. No changes to COUNT,
; ITER, angles, light, state transitions or the 312-frame zoom duration.
ReleaseMapRadius:
        move.w M4_RM_RADIUS,d0
        cmpi.b #1,(a0) ;sprite planets retain their original integer scaling
        bne.s ReleaseMapRadiusDone
        cmpi.b #RM_ZOOM,M4_RM_STATE
        bne.s ReleaseMapRadiusDone
        cmpi.w #54,d0
        bhs.s ReleaseMapRadiusDone
        movem.l d1-d2,-(sp)
        move.w M4_RM_ZTOTAL,d1
        sub.w M4_RM_COUNT,d1
        subq.w #1,d1
        bmi.s ReleaseMapRadiusPop
        mulu.w #40*256,d1
        divu.w M4_RM_ZTOTAL,d1
        andi.w #$ff,d1
        lsl.w #8,d1
        or.w d1,d0
ReleaseMapRadiusPop:
        movem.l (sp)+,d1-d2
ReleaseMapRadiusDone:
        rts

; Hold all three DMA runs blank, revealing only the completed new image.
ReleaseMapDisplay:
        tst.b ReleaseMapHold
        beq.s ReleaseMapDisplayOn
        cmpi.w #3,M4VR_STAGE
        bne.s ReleaseMapDisplayOff
        cmpi.b #3,ReleaseMapHold
        bhs.s ReleaseMapDisplayOff ;a loader can be interrupted between chunks
        cmpi.b #2,ReleaseMapHold
        bne.s ReleaseMapReveal
        move.w M4VR_READY_FRAME,d0
        sub.w M4VR_SCENE_FRAME,d0 ;signed distance, including 16-bit wrap
        bmi.s ReleaseMapDisplayOff ;old image from the overlapped producer
ReleaseMapReveal:
        clr.b ReleaseMapHold
ReleaseMapDisplayOn:
        move.w #$8174,(a5)
        bra.s ReleaseMapDisplayTime
ReleaseMapDisplayOff:
        move.w #$8134,(a5)
ReleaseMapDisplayTime:
        move.w $c00008,2(a1)
        jmp M4VRDisplayOn+12

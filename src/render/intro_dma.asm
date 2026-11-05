        include 'render/intro_vr_dma.asm'
        if def(M4_DMA_STRESS)
; Every pixel of all four quarters changes. Exercises front/hidden page swaps,
; full bandwidth and first/last words. Deliberately absent from normal ROM.
M4BlockStressLoop:
        move.w INTRO_DIAG+6,d0
        addq.w #1,d0
        move.w d0,M4_SCENE_TICK
        clr.l M4_PHASE_WORK
        clr.l M4_PHASE_WORK+4
        clr.w M4_PHASE_WORK+8
        move.w M4_CLOCK,M4_PHASE_STAMP
        lea M4_POLY_INPUT,a0
        moveq #16,d6
        moveq #3,d7
        moveq #0,d5
        move.w INTRO_DIAG+6,d5
        subq.w #4,d5
        divu.w #13,d5
        swap d5
        addq.w #2,d5
M4BlockStressQuarter:
        move.w #3,(a0)+
        clr.w (a0)+
        move.w d6,(a0)+
        move.w #255,(a0)+
        move.w d6,(a0)+
        move.w #255,(a0)+
        move.w d6,d0
        addi.w #47,d0
        move.w d0,(a0)+
        move.w d5,(a0)+
        move.w #3,(a0)+
        clr.w (a0)+
        move.w d6,(a0)+
        move.w #255,(a0)+
        move.w d0,(a0)+
        clr.w (a0)+
        move.w d0,(a0)+
        move.w d5,(a0)+
        addi.w #48,d6
        addq.w #1,d5
        cmpi.w #15,d5
        blo.s M4BlockStressNext
        moveq #2,d5
M4BlockStressNext:
        dbra d7,M4BlockStressQuarter
        move.w #8,M4_POLY_COUNT
        clr.w INTRO_DRAW_COUNT
        moveq #0,d1
        bsr M4IntroPhaseEnd
        moveq #0,d0
        bsr M4TextVideoDraw
        tst.w d0
        bne M4IntroFailed
        addq.w #1,INTRO_DIAG+6
        move.w #1,INTRO_DIAG+4
        bsr M4IntroTimingPublish
M4BlockStressCapture:
        cmpi.w #2,INTRO_CAPTURE
        bne.s M4BlockStressCaptureWait
        move.w #1,INTRO_CAPTURE
        bra M4BlockStressLoop
M4BlockStressCaptureWait:
        tst.w INTRO_CAPTURE
        bne.s M4BlockStressCapture
        bra M4BlockStressLoop
        endif


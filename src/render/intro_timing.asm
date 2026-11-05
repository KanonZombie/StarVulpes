; Hardware VBlank clock: presentation metrics and SCRAMBLE tick deadlines.
; Deadlines schedule unchanged strategy passes; flight has no FPS cap.
; IRQ reads status and touches RAM only. Control commands are atomic MOVE.L
; instructions; it never writes VDP address/data or changes the current address.
M4_CLOCK equ $ff9230
M4_FPS_LAST_VB equ $ff9232
M4_FPS_LAST_PRESENT equ $ff9234
M4_FPS_VALUE equ $ff9236
M4_PHASE_LAST equ $ff9240 ; five WORD VBlank deltas for last full image
M4_PHASE_WORK equ $ff9260
M4_PHASE_STAMP equ $ff926a

M4IntroVBlankIRQ:
        move.l d0,-(sp)
        move.w VDP_CTRL,d0
        addq.w #1,M4_CLOCK
        move.w #M4VR_HINTS,M4VR_HCOUNT
        if def(M4_SFX_TEST)
        jsr M4SoundTestTick
        endif
        move.l (sp)+,d0
        rte

M4IntroTimingInit:
        lea M4_CLOCK,a0
        moveq #15,d0
M4IntroTimingClear:
        clr.l (a0)+
        dbra d0,M4IntroTimingClear
        clr.w M4_FPS_LAST_PRESENT
        ; Dedicated glyphs9000..919F, away from bitmap/BG/SAT/scroll/maps.
        move.w #M4_DMA_FONT,d0
        bsr M4TextVideoWriteAddress
        lea M4IntroFpsGlyphs,a1
        moveq #12,d7
M4IntroTimingGlyph:
        moveq #0,d0
        move.b (a1)+,d0
        lsl.w #5,d0
        lea PixelFont,a0
        adda.w d0,a0
        moveq #7,d1
M4IntroTimingGlyphRow:
        move.l (a0)+,VDP_DATA
        dbra d1,M4IntroTimingGlyphRow
        dbra d7,M4IntroTimingGlyph
        move.l #$c0640000,VDP_CTRL ; palette3, colour2, original font nibble2
        move.w #$eee,VDP_DATA
        bsr M4IntroFpsDraw
        rts

; d1=offset0/2/4/6/8. Timing granularity is one VBlank, not zero-cost proof.
M4IntroPhaseEnd:
        movem.l d0-d2/a0,-(sp)
        move.w M4_CLOCK,d0
        move.w d0,d2
        sub.w M4_PHASE_STAMP,d0
        lea M4_PHASE_WORK,a0
        move.w d0,(a0,d1.w)
        move.w d2,M4_PHASE_STAMP
        movem.l (sp)+,d0-d2/a0
        rts

M4IntroTimingPublish:
        bra M4IntroFpsUpdate ;IRQ publishes metrics from the sealed READY image
        move.l M4_GEOM_WORK,M4_GEOM_PHASES
        move.l M4_GEOM_WORK+4,M4_GEOM_PHASES+4
        move.l M4_PHASE_WORK,M4_PHASE_LAST
        move.l M4_PHASE_WORK+4,M4_PHASE_LAST+4
        move.w M4_PHASE_WORK+8,M4_PHASE_LAST+8
        bra M4IntroFpsUpdate

; Count completed images, not SVP requests. Update after>=60 hardware VBlank.
M4IntroFpsUpdate:
        tst.w INTRO_CAPTURE
        bne M4IntroFpsReturn
        movem.l d0-d3,-(sp)
        move.w M4_CLOCK,d0
        move.w d0,d3
        sub.w M4_FPS_LAST_VB,d0
        cmpi.w #60,d0
        blo.s M4IntroFpsNoUpdate
        move.w M4VR_PRESENT_COUNT,d1
        sub.w M4_FPS_LAST_PRESENT,d1
        andi.l #$ffff,d1
        mulu.w #60,d1
        divu.w d0,d1
        cmpi.w #99,d1
        bls.s M4IntroFpsWithinRange
        moveq #99,d1
M4IntroFpsWithinRange:
        move.w d1,M4_FPS_VALUE
        move.w d3,M4_FPS_LAST_VB
        move.w M4VR_PRESENT_COUNT,M4_FPS_LAST_PRESENT
        bsr M4IntroFpsDraw
M4IntroFpsNoUpdate:
        movem.l (sp)+,d0-d3
M4IntroFpsReturn:
        rts

; H32 HUD occupies the top16-row margin; field256x192 begins at y16.
M4IntroFpsDraw:
        bra M4VRFpsSprites
        movem.l d0-d3,-(sp)
        move.w M4_FPS_VALUE,d2
        andi.l #$ffff,d2
        divu.w #10,d2
        move.w d2,d3
        addi.w #$e7f4,d3
        swap d2
        addi.w #$e7f4,d2
        moveq #1,d1
        move.w #$a000,d0
M4IntroFpsPage:
        bsr M4IntroFpsAddress
        move.w #$e7f1,VDP_DATA
        move.w #$e7f2,VDP_DATA
        move.w #$e7f3,VDP_DATA
        move.w #0,VDP_DATA
        addi.w #128,d0
        bsr M4IntroFpsAddress
        move.w d3,VDP_DATA
        move.w d2,VDP_DATA
        move.l #0,VDP_DATA
        move.w #$c000,d0
        dbra d1,M4IntroFpsPage
        movem.l (sp)+,d0-d3
        rts

M4IntroFpsAddress:
        movem.l d0/d2,-(sp)
        bsr M4TextVideoWriteAddress
        movem.l (sp)+,d0/d2
        rts

M4IntroFpsGlyphs:
        dc.b 6,16,19,27,28,29,30,31,32,33,34,35,36
        even

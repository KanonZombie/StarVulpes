; Resident VDP patterns for planet selection and Pepper's stable briefing.
; Rendering remains on SVP (the tested sphere/glyph primitives). The 68000
; packs descriptors and schedules rectangular, tile-pair DMA runs only.
; RAM 6C00..6DFF is unused object-extension storage while planetseq owns it.
M4N_ON equ M4_RM+348
M4N_FIRST equ M4N_ON+2
M4N_PHASE equ M4N_ON+4
M4N_TEXT equ M4N_ON+6
M4N_RUNS equ M4N_ON+8
M4N_NEXT equ M4N_ON+10
M4N_PAGE equ M4N_ON+14
M4N_FORCE equ M4N_ON+52
M4N_HIDEMSG equ M4N_ON+54
M4N_INITIAL equ M4N_ON+12
M4N_KEYS equ M4N_ON+16 ;9 WORDs: light and rotations
M4N_BYTES equ M4N_ON+36 ;LONG actual useful pattern bytes
M4N_JOBS equ M4N_ON+40 ;LONG SVP raster requests
M4N_IMAGES equ M4N_ON+44
M4N_ZSIZE equ M4N_ON+48 ;previous zoom envelope, in pixels
M4N_VBLANK equ M4N_ON+50 ;bounded native upload with display continuously on
M4N_LIST equ $ff6c00 ;64 entries: DRAM byte offset, byte length

; d0=1 handled, 0 use the ordinary VR path. No pending reader when returning.
M4RmNativeTry:
        moveq #0,d0
        move.b M4_RM_STATE,d0
        cmpi.b #RM_WINDOW,d0
        bls.s M4NEligible
        cmpi.b #RM_NAME,d0
        beq.s M4NEligible
        cmpi.b #RM_ZOOM,d0
        beq.s M4NEligible
        cmpi.b #RM_MESSAGE,d0
        beq.s M4NEligible
        cmpi.b #RM_EXIT,d0
        beq.s M4NEligible
        bsr M4RmNativeLeave
        moveq #0,d0
        rts
M4NEligible:
        movem.l d1-d7/a0-a6,-(sp)
        tst.w M4N_ON
        bne.s M4NEntered
        bsr M4NEnter
M4NEntered:
        cmpi.b #RM_ZOOM,M4_RM_STATE
        beq M4NZoom
        bsr M4NWaitPrevious
        clr.w M4N_RUNS
        clr.w M4N_NEXT
        clr.w M4_FACE_COUNT
        clr.w M4_POLY_COUNT
        clr.b M4_BSP_SVP ;M4RadioRecord: forwards, not reversed cmd12 slots
        moveq #0,d0
        move.b M4_RM_STATE,d0
        cmpi.b #RM_WINDOW,d0
        bhi M4NBriefing
        tst.w M4N_FIRST
        bne.s M4NMapChanged
        lea M4_RM_LPOS,a0
        lea M4N_KEYS,a1
        moveq #8,d1
M4NMapCompare:
        move.w (a0)+,d0
        cmp.w (a1)+,d0
        dbne d1,M4NMapCompare
        beq M4NPrepared
M4NMapChanged:
        lea M4_RM_LPOS,a0
        lea M4N_KEYS,a1
        moveq #8,d1
M4NMapSave:
        move.w (a0)+,(a1)+
        dbra d1,M4NMapSave
        moveq #0,d7
M4NMapPlanet:
        move.w d7,d0
        lsl.w #2,d0
        lea M4RmPlanetJob,a0
        tst.b (a0,d0.w)
        beq.s M4NMapNext
        tst.w M4N_FIRST
        bne.s M4NMapDraw
        cmpi.b #1,(a0,d0.w)
        bne.s M4NMapNext ;flat images remain resident
M4NMapDraw:
        moveq #0,d5
        moveq #0,d6
        bsr M4RmMapPlanet
        lea M4RmPlanetPos,a0
        moveq #0,d1
        moveq #0,d2
        move.w 2(a0,d0.w),d2
        move.b d2,d1
        lsr.w #8,d2
        ; planetpos is the cell anchor, not its centre. MapPlanet adds16
        ; to x and uses bitmap centre y=anchor-1. yp=0..14 =>29 rows.
        subi.w #15,d2
        move.w #32,d3
        move.w #29,d4
        bsr M4NRect
M4NMapNext:
        addq.w #1,d7
        cmpi.w #16,d7
        blo.s M4NMapPlanet
        bra M4NRender

; Same SVP sphere/sprite renderer and fractional radius as the full path.
; Clear the backing cache on SVP, but DMA only the old/new planet envelope.
; Keeping the previous envelope also makes a smaller radius erase its rim.
M4NZoom:
        ; Two DRAM banks: render WORK while IRQ consumes the previous READY.
        ; Its run list, palette and SAT remain immutable until acknowledgement.
        clr.w M4_FACE_COUNT
        clr.w M4_POLY_COUNT
        clr.b M4_BSP_SVP
        move.w M4VR_READY_SLOT,d0
        eori.w #1,d0
        move.w d0,M4VR_WORK_SLOT
        lsl.w #2,d0
        lea M4VRBitmapAddresses,a0
        move.l (a0,d0.w),d0
        move.l d0,M4VR_WORK_PTR
        subi.l #$300000,d0
        lsr.l #1,d0
        move.w d0,MAILBOX+24
        bsr M4RmZoomPlanet
        bsr M4NPack
        clr.w MAILBOX+22
        move.w M4_POLY_COUNT,MAILBOX+20
        move.w #M4_RENDER_WORDS,M4_GEO_EXPECT
        moveq #8,d0
        jsr M4IntroGeometryRequest
        tst.w d0
        bne M4NFailed
        addq.l #1,M4N_JOBS
        bsr M4NWaitPrevious
        clr.w M4N_RUNS
        clr.w M4N_NEXT
        move.w M4_RM_RADIUS,d3
        moveq #0,d0
        move.b M4_GS_CURPLANET,d0
        lsl.w #2,d0
        lea M4RmPlanetJob,a0
        cmpi.b #1,(a0,d0.w)
        bne.s M4NZoomFlat
        addq.w #1,d3 ;fractional radius can reach the next pixel
        add.w d3,d3
        bra.s M4NZoomSize
M4NZoomFlat:
        addi.w #19,d3 ;original radius+17 size, plus a guard pixel per side
M4NZoomSize:
        move.w d3,d4
        cmp.w M4N_ZSIZE,d3
        bhs.s M4NZoomBounds
        move.w M4N_ZSIZE,d3
M4NZoomBounds:
        move.w d4,M4N_ZSIZE
        move.w d3,d4
        move.w d3,d0
        lsr.w #1,d0
        move.w #128,d1
        sub.w d0,d1
        moveq #87,d2 ;SNES centre104 minus17 bitmap offset
        sub.w d0,d2
        bsr M4NRect
        clr.w M4N_FIRST
        bra M4NPrepared

M4NBriefing:
        cmpi.w #RM_ZOOM,M4N_PHASE
        bne.s M4NBriefPhase
        move.w #1,M4N_FIRST ;publish final un-interpolated planet with NAME
M4NBriefPhase:
        cmpi.b #RM_MESSAGE,d0
        bne.s M4NBriefExit
        cmp.w M4N_PHASE,d0
        beq.s M4NBriefExit
        move.w #1,M4N_FORCE ;encoded already-visible name prefix +1
        cmpi.w #RM_NAME,M4N_PHASE
        bne.s M4NBriefExit
        move.w M4N_TEXT,d1
        bmi.s M4NBriefExit
        addq.w #1,d1
        move.w d1,M4N_FORCE ;finish only the missing name glyphs on MESSAGE entry
M4NBriefExit:
        cmpi.b #RM_EXIT,d0
        bne.s M4NBriefCount
        cmp.w M4N_PHASE,d0
        beq M4NPrepared
        move.w #1,M4N_HIDEMSG ;remove the text through plane cells, not a full clear
        bra M4NPrepared
M4NBriefCount:
        tst.w M4N_FIRST
        beq.s M4NBriefText
        bsr M4NTextParams
        move.w d6,M4N_TEXT
        bsr M4RmDrawHook
        ; The final zoom image is already visible. Only its planet area and
        ; completed name change; keep it visible until one native publication.
        moveq #72,d1
        moveq #16,d2
        move.w #120,d3 ;flat scaler includes its last x pixel (x=184)
        move.w #128,d4
        bsr M4NRect
        bsr M4NMarkName
        clr.w M4N_FORCE ;the cold image already includes the full name
        bra M4NRender
M4NBriefText:
        cmpi.b #RM_EXIT,d0
        beq M4NPrepared
        bsr M4NTextParams
        bra M4NTextReady
M4NTextParams:
        move.w M4_RM_PCHARS,d6
        cmpi.b #RM_NAME,d0
        bne.s M4NMessagePtr
        moveq #0,d0
        move.b M4_GS_CURPLANET,d0
        lea M4RmPlanetNames,a0
        move.b (a0,d0.w),d0
        bsr M4RmTextPtr
        moveq #-17,d5
        bra.s M4NTextPtr
M4NMessagePtr:
        moveq #0,d0
        move.b M4_GS_PEPPERMSG,d0
        bsr M4RmTextPtr
        move.w #151,d5
M4NTextPtr:
        move.w (a0)+,d0
        cmp.w d0,d6
        bls.s M4NCountClamped
        move.w d0,d6
M4NCountClamped:
        moveq #0,d0
        move.b M4_RM_STATE,d0
        rts
M4NTextReady:
        moveq #0,d0
        move.b M4_RM_STATE,d0
        cmp.w M4N_PHASE,d0
        beq.s M4NTextSamePhase
        clr.w M4N_TEXT ;name remains; MESSAGE starts with an empty prefix
M4NTextSamePhase:
        tst.w M4N_FORCE
        bne.s M4NTextChanged
        cmp.w M4N_TEXT,d6
        beq M4NPrepared
M4NTextChanged:
        move.w M4N_TEXT,d7
        bmi.s M4NTextAll
        move.w d7,d0
        lsl.w #2,d0
        adda.w d0,a0
        bra.s M4NTextDirty
M4NTextAll:
        moveq #0,d7
M4NTextDirty:
        cmp.w d6,d7
        bhs.s M4NTextDraw
        moveq #0,d1
        moveq #0,d2
        move.b 1(a0),d1
        move.b 2(a0),d2
        addi.w #32,d1 ;M4RmDrawText + M4TxGlyph
        add.w d5,d2
        move.w #18,d3 ;up to16 glyph pixels, shadow offset2
        move.w #14,d4
        bsr M4NRect
        addq.l #4,a0
        addq.w #1,d7
        bra.s M4NTextDirty
M4NTextDraw:
        move.w d6,M4N_TEXT
        tst.w M4N_FORCE
        beq.s M4NTextNoName
        bsr M4NMarkName
        clr.w M4N_FORCE
M4NTextNoName:
        bsr M4RmPepperDraw

M4NRender:
        ; Only packet representation changes. No CPU geometry/pixel loop.
        bsr M4NPack
        tst.w M4N_FIRST
        beq.s M4NAppend
        clr.w MAILBOX+22
        cmpi.w #1,M4N_INITIAL
        bne.s M4NRequest
        bsr M4NFullRuns
        bra.s M4NRequest
M4NAppend:
        move.w #1,MAILBOX+22
M4NRequest:
        move.w #$1800,MAILBOX+24
        move.w M4_POLY_COUNT,MAILBOX+20
        move.w #M4_RENDER_WORDS,M4_GEO_EXPECT
        moveq #8,d0
        jsr M4IntroGeometryRequest
        tst.w d0
        bne M4NFailed
        addq.l #1,M4N_JOBS
        clr.w M4N_FIRST
M4NPrepared:
        cmpi.b #RM_ZOOM,M4_RM_STATE
        beq.s M4NReadyBank
        clr.w M4VR_WORK_SLOT
        move.l #M4VR_BITMAP0,M4VR_WORK_PTR
M4NReadyBank:
        move.w M4VR_WORK_SLOT,M4VR_READY_SLOT
        move.l M4VR_WORK_PTR,M4VR_READY_PTR
        moveq #0,d0
        move.b M4_RM_STATE,d0
        move.w d0,M4N_PHASE
        jsr M4LevelHudSprites
        move.b M4_RM_BRIGHT,d0
        or.b M4_SC_PALVER,d0
        move.b d0,M4_BRIGHT ;latch this image's palette generation, not the previous one
        move.b M4_BRIGHT,M4VR_READY_BRIGHT
        move.b M4_BRIGHT,M4VR_PEND_BRIGHT
        jsr M4VRFadePalette
        addq.w #1,INTRO_DIAG+6
        move.w INTRO_DIAG+6,M4_SCENE_TICK ;same tag at the next pipeline drain
        move.w INTRO_DIAG+6,M4VR_READY_FRAME
        move.w INTRO_DIAG+6,M4VR_READY_SEQUENCE
        move.w M4_CLOCK,M4VR_QUEUED_CLOCK
        bsr M4NSelectWindow
M4NPublish:
        move.w #1,M4VR_READY_BUSY ;publish only after descriptors and DSP ACK
        cmpi.b #RM_ZOOM,M4_RM_STATE
        bne.s M4NWaitStart
        tst.w INTRO_CAPTURE
        beq.s M4NShown ;free run overlaps the next render with this DMA
M4NWaitStart:
        move.l #TIMEOUT_POLLS,d1
M4NWait:
        tst.w M4VR_ERROR
        bne M4NFailed
        tst.w M4VR_READY_BUSY
        beq.s M4NShown
        subq.l #1,d1
        bne.s M4NWait
        move.w #$30,M4VR_ERROR
        bra M4NFailed
M4NShown:
        move.w M4_RM_FRAME,M4_LV_DIAG+4
        movem.l (sp)+,d1-d7/a0-a6
        moveq #1,d0
        rts

; Same measured envelope as the steady map. Classify descriptors, never
; pixels: text bands, SAT/CRAM-only images and small zooms can use VBlank.
; Large/cold images retain the existing hidden transfer, without dropping
; tiles, splitting a visible glyph or changing the logical text prefix.
M4NSelectWindow:
        clr.w M4N_VBLANK
        tst.w M4N_INITIAL
        bne.s M4NWindowDone
        cmpi.w #112,M4_LV_SATWORDS
        bhi.s M4NWindowDone
        move.w M4N_RUNS,d1
        cmpi.w #11,d1
        bhi.s M4NWindowDone
        moveq #0,d0
        lea M4N_LIST,a0
        bra.s M4NWindowCheck
M4NWindowRun:
        add.w 2(a0),d0
        addq.l #4,a0
        subq.w #1,d1
M4NWindowCheck:
        tst.w d1
        bne.s M4NWindowRun
        cmpi.w #2816,d0
        bhi.s M4NWindowDone
        move.w #1,M4N_VBLANK
M4NWindowDone:
        rts

M4NWaitPrevious:
        move.l #TIMEOUT_POLLS,d1
M4NPrevious:
        tst.w M4VR_ERROR
        bne M4NFailed
        tst.w M4VR_READY_BUSY
        beq.s M4NPreviousDone
        subq.l #1,d1
        bne.s M4NPrevious
        move.w #$30,M4VR_ERROR
        bra M4NFailed
M4NPreviousDone:
        rts

M4NMarkName:
        movem.l d0-d7/a0-a1,-(sp)
        moveq #0,d0
        move.b M4_GS_CURPLANET,d0
        lea M4RmPlanetNames,a0
        move.b (a0,d0.w),d0
        bsr M4RmTextPtr
        move.w (a0)+,d7
        cmpi.b #RM_NAME,M4_RM_STATE
        bne.s M4NNamePrefixReady
        cmp.w M4N_TEXT,d7
        bls.s M4NNamePrefixReady
        move.w M4N_TEXT,d7
M4NNamePrefixReady:
        tst.w M4N_FORCE
        beq.s M4NNameStart
        move.w M4N_FORCE,d6
        subq.w #1,d6
        cmp.w d7,d6
        bhs.s M4NNameDone
        sub.w d6,d7
        lsl.w #2,d6
        adda.w d6,a0
M4NNameStart:
        bra.s M4NNameCheck
M4NNameGlyph:
        moveq #0,d1
        moveq #0,d2
        move.b 1(a0),d1
        move.b 2(a0),d2
        addi.w #32,d1
        subi.w #17,d2
        moveq #18,d3
        moveq #14,d4
        bsr M4NRect
        addq.l #4,a0
        subq.w #1,d7
M4NNameCheck:
        tst.w d7
        bne.s M4NNameGlyph
M4NNameDone:
        movem.l (sp)+,d0-d7/a0-a1
        rts

M4NPack:
        lea M4_FACE_INPUT,a0
        lea M4_POLY_INPUT,a1
        move.w M4_FACE_COUNT,d7
        move.w d7,M4_POLY_COUNT
        beq.s M4NPackDone
        cmpi.w #256,d7
        bhi M4NFailed
        subq.w #1,d7
M4NPackOne:
        cmpi.w #$8022,6(a0)
        beq.s M4NPackRaw
        cmpi.w #$8020,6(a0)
        bne M4NFailed
        move.w #7,(a1)+
        moveq #5,d0
        lea 8(a0),a2
M4NPackGlyph:
        move.w (a2)+,(a1)+
        dbra d0,M4NPackGlyph
        clr.w (a1)+
        bra.s M4NPackNext
M4NPackRaw:
        move.l 8(a0),(a1)+
        move.l 12(a0),(a1)+
        move.l 16(a0),(a1)+
        move.l 20(a0),(a1)+
M4NPackNext:
        lea 32(a0),a0
        dbra d7,M4NPackOne
M4NPackDone:
        rts

; Rectangle in bitmap pixels. DMA layout follows VR's vertical tile pairs:
; pairrow*2048 + tilecolumn*64; copy whole pairs, never scan their pixels.
M4NRect:
        movem.l d0-d7/a0-a1,-(sp)
        add.w d1,d3
        add.w d2,d4
        tst.w d1
        bpl.s M4NRectX
        moveq #0,d1
M4NRectX:
        tst.w d2
        bpl.s M4NRectY
        moveq #0,d2
M4NRectY:
        cmpi.w #256,d3
        bls.s M4NRectRight
        move.w #256,d3
M4NRectRight:
        cmpi.w #192,d4
        bls.s M4NRectBottom
        move.w #192,d4
M4NRectBottom:
        cmp.w d1,d3
        ble.s M4NRectDone
        cmp.w d2,d4
        ble.s M4NRectDone
        lsr.w #3,d1
        addq.w #7,d3
        lsr.w #3,d3
        sub.w d1,d3
        lsl.w #6,d3
        lsl.w #6,d1
        lsr.w #4,d2
        addi.w #15,d4
        lsr.w #4,d4
M4NRectRow:
        move.w d2,d0
        lsl.w #8,d0
        lsl.w #3,d0
        add.w d1,d0
        bsr M4NRun
        addq.w #1,d2
        cmp.w d4,d2
        blo.s M4NRectRow
M4NRectDone:
        movem.l (sp)+,d0-d7/a0-a1
        rts
M4NRun:
        cmpi.w #$3940,d0
        bhs.s M4NRunBounded
        move.w d0,d5
        add.w d3,d5
        cmpi.w #$3940,d5
        bls.s M4NRunBounded
        movem.l d0/d3,-(sp)
        move.w #$3940,d3
        sub.w d0,d3
        bsr M4NRunBounded
        movem.l (sp),d0/d3
        add.w d0,d3
        subi.w #$3940,d3
        move.w #$3940,d0
        bsr M4NRunBounded
        movem.l (sp)+,d0/d3
        rts
M4NRunBounded:
        ; Merge intersecting/adjacent tile-pair spans, not unrelated planets.
        ; Text is proportional: several new glyphs often touch the same tiles.
        movem.l d1-d2/d4/d6/a0,-(sp)
        lea M4N_LIST,a0
        move.w M4N_RUNS,d6
        move.w d0,d1
        add.w d3,d1
        move.w d0,d4
        andi.w #$f800,d4
        bra.s M4NMergeCheck
M4NMerge:
        cmpi.w #$3940,d0
        blo.s M4NMergeLow
        cmpi.w #$3940,(a0)
        blo.s M4NMergeNext
        bra.s M4NMergeSide
M4NMergeLow:
        cmpi.w #$3940,(a0)
        bhs.s M4NMergeNext
M4NMergeSide:
        move.w (a0),d2
        andi.w #$f800,d2
        cmp.w d4,d2
        bne.s M4NMergeNext
        move.w (a0),d2
        cmp.w d1,d2
        bhi.s M4NMergeNext
        add.w 2(a0),d2
        cmp.w d0,d2
        blo.s M4NMergeNext
        cmp.w d1,d2
        bhs.s M4NMergeEnd
        move.w d1,d2
M4NMergeEnd:
        cmp.w (a0),d0
        bhs.s M4NMergeStart
        move.w d0,(a0)
M4NMergeStart:
        sub.w (a0),d2
        move.w d2,2(a0)
        movem.l (sp)+,d1-d2/d4/d6/a0
        rts
M4NMergeNext:
        addq.l #4,a0
        subq.w #1,d6
M4NMergeCheck:
        tst.w d6
        bne.s M4NMerge
        movem.l (sp)+,d1-d2/d4/d6/a0
        move.w M4N_RUNS,d5
        cmpi.w #64,d5
        bhs M4NFailed
        lsl.w #2,d5
        lea M4N_LIST,a1
        move.w d0,(a1,d5.w)
        move.w d3,2(a1,d5.w)
        addq.w #1,M4N_RUNS
        rts
M4NFullRuns:
        clr.w M4N_RUNS
        moveq #0,d0
        move.w #2048,d3
        moveq #11,d6
M4NFullRow:
        bsr M4NRun
        addi.w #2048,d0
        dbra d6,M4NFullRow
        rts

M4NEnter:
        jsr M4PipeFlush
        tst.w d0
        bne M4NFailed
        jsr M4VRWaitWork
        tst.w d0
        bne M4NFailed
M4NDrain:
        tst.w M4VR_ERROR
        bne M4NFailed
        tst.w M4VR_READY_BUSY
        bne.s M4NDrain
        move.w sr,-(sp)
        ori.w #$0700,sr
        lea M4N_ON,a0
        moveq #13,d0
M4NClear:
        clr.l (a0)+
        dbra d0,M4NClear
        clr.w M4_GEO_GRID
        jsr M4LevelStarsOff
        move.w #1,M4N_ON
        move.w #1,M4N_FIRST
        move.w #1,M4N_INITIAL
        move.w #-1,M4N_PHASE
        move.w #-1,M4N_TEXT
        clr.w M4VR_WORK_SLOT
        move.l #M4VR_BITMAP0,M4VR_WORK_PTR
        cmpi.b #RM_WINDOW,M4_RM_STATE
        bls.s M4NEnterMap
        move.w #2,M4N_INITIAL
        move.w M4VR_FRONT_SLOT,M4N_PAGE
        bra.s M4NEnterDone
M4NEnterMap:
        move.w #$8134,VDP_CTRL
        move.l #$40000010,VDP_CTRL
        move.w #1,VDP_DATA
        move.w #1,VDP_DATA
M4NEnterDone:
        clr.b M4_RM+344
        move.w (sp)+,sr
        rts

M4RmNativeLeave:
        tst.w M4N_ON
        beq.s M4NLeaveDone
        bsr M4NWaitPrevious
        move.w sr,-(sp)
        ori.w #$0700,sr
        move.w #$8134,VDP_CTRL
        clr.w M4N_ON
        clr.w M4VR_READY_BUSY
        clr.w M4VR_COMPLETE
        clr.w M4P_STATE
        clr.w M4VR_STAGE
        clr.w M4VR_WORK_SLOT
        move.w #1,M4VR_FRONT_SLOT
        move.l #M4VR_BITMAP0,M4VR_WORK_PTR
        move.w #$1800,MAILBOX+24
        moveq #0,d0
        jsr M4CtlPlaneA
        move.w (sp)+,sr
M4NLeaveDone:
        rts

; IRQ caller has masked interrupts, acknowledged PCM gate and blanked VDP.
; At most8KiB useful patterns/window (old VR largest run:9920 bytes).
M4NIRQ:
        move.w #8192,d7
M4NIRQRun:
        move.w M4N_NEXT,d0
        cmp.w M4N_RUNS,d0
        bhs M4NIRQFinish
        lsl.w #2,d0
        lea M4N_LIST,a0
        moveq #0,d2
        move.w (a0,d0.w),d2
        moveq #0,d3
        move.w 2(a0,d0.w),d3
        cmp.w d7,d3
        bhi M4NIRQHold
        sub.w d3,d7
        add.l d3,M4N_BYTES
        move.l d2,d4
        add.l M4VR_READY_PTR,d4
        move.l d4,a0
        addq.l #2,d4 ;SVP delay, repair first LONGWORD below
        lsr.l #1,d4
        move.w d3,d0
        lsr.w #1,d0
        ; Native runs are adjacent resident patterns, with no VR padding
        ; word after each run. Exact destination length; CPU repairs the
        ; delayed first LONGWORD without overwriting the next resident tile.
        move.w #$9300,d1
        move.b d0,d1
        move.w d1,(a5)
        lsr.w #8,d0
        ori.w #$9400,d0
        move.w d0,(a5)
        move.w #$9500,d1
        move.b d4,d1
        move.w d1,(a5)
        lsr.l #8,d4
        move.w #$9600,d1
        move.b d4,d1
        move.w d1,(a5)
        lsr.l #8,d4
        ori.w #$9700,d4
        move.w d4,(a5)
        cmpi.w #$3940,d2
        bhs.s M4NDmaShared
        addi.w #$20,d2
        tst.w M4N_PAGE
        beq.s M4NDmaAddress
        addi.w #$3960,d2
        bra.s M4NDmaAddress
M4NDmaShared:
        addi.w #$39a0,d2
M4NDmaAddress:
        move.l d2,d4
        andi.w #$3fff,d4
        swap d4
        lsr.w #8,d2
        lsr.w #6,d2
        or.w d2,d4
        ori.l #$40000000,d4
        move.l d4,d0
        ori.b #$80,d0
        move.w #$a,$a15006
        move.l d0,(a5)
        move.w #0,$a15006
        move.l d4,(a5)
        move.l (a0),(a6)
        addq.w #1,M4N_NEXT
        bra M4NIRQRun
M4NIRQHold:
        jsr M4SoundDmaEnd
        rts ;initial complete-image upload remains hidden across windows
M4NIRQFinish:
        tst.w M4N_HIDEMSG
        beq.s M4NIRQObjects
        clr.w M4N_HIDEMSG
        move.w M4N_PAGE,d4
        mulu.w #$680,d4
        addi.w #$c000+20*64+4,d4
        moveq #5,d5
M4NHideRow:
        move.w d4,d0
        jsr M4TextVideoWriteAddress
        moveq #27,d0
M4NHideCell:
        move.w #$c000,(a6) ;transparent tile0, keep bitmap palette/priority
        dbra d0,M4NHideCell
        addi.w #64,d4
        dbra d5,M4NHideRow
M4NIRQObjects:
        move.l M4_LV_SATREADY,d0
        beq.s M4NIRQPalette
        move.l d0,a0
        move.w #$d868,d0
        jsr M4TextVideoWriteAddress
        move.w M4_LV_SATWORDS,d0
        subq.w #1,d0
M4NIRQSat:
        move.w (a0)+,(a6)
        dbra d0,M4NIRQSat
M4NIRQPalette:
        tst.w M4N_VBLANK
        beq.s M4NIRQPaletteCopy
        move.b M4VR_READY_BRIGHT,d0
        cmp.b M4VR_SHOWN_BRIGHT,d0
        beq.s M4NIRQDisplay
M4NIRQPaletteCopy:
        lea M4_BASE_CRAM,a0
        move.b M4VR_READY_BRIGHT,d0
        andi.w #$3f,d0
        cmpi.w #15,d0
        beq.s M4NIRQCram
        lea M4_FADE_CRAM,a0
        tst.w M4VR_READY_SLOT
        beq.s M4NIRQCram
        lea 128(a0),a0
M4NIRQCram:
        move.l #$c0000000,(a5)
        moveq #31,d0
M4NIRQColour:
        move.l (a0)+,(a6)
        dbra d0,M4NIRQColour
        move.b M4VR_READY_BRIGHT,M4VR_SHOWN_BRIGHT
M4NIRQDisplay:
        tst.w M4N_VBLANK
        bne.s M4NIRQVisible
        move.w #$8174,(a5)
M4NIRQVisible:
        jsr M4SoundDmaEnd
        move.w M4VR_READY_FRAME,M4VR_PRESENT_FRAME
        move.w M4VR_READY_SEQUENCE,M4VR_PRESENT_SEQUENCE
        move.w M4VR_READY_SEQUENCE,TEXT_VIDEO_DIAG+8
        move.w M4N_PAGE,M4VR_FRONT_SLOT
        addq.w #1,M4VR_PRESENT_COUNT
        addq.l #1,M4N_IMAGES
        move.w #1,TEXT_VIDEO_DIAG+4
        clr.w M4VR_READY_BUSY
        clr.w M4N_INITIAL
        tst.w M4N_VBLANK
        beq.s M4NIRQFps
        cmpi.w #5,M4N_RUNS
        bhi.s M4NIRQEnd ;reserve the heavy window for image/SAT/CRAM only
M4NIRQFps:
        jsr M4IntroFpsUpdate
M4NIRQEnd:
        move.w M4N_VBLANK,M4VR_TRACE+8 ;completed image, not the producer's next one
        move.w M4N_PHASE,M4VR_TRACE+10
        move.w M4N_RUNS,M4VR_TRACE+12
        move.w $c00008,M4VR_TRACE+2 ;end of the whole native IRQ, including HUD
        rts

M4NFailed:
        jmp M4IntroFailed

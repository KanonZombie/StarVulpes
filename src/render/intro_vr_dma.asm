; VR-method backend; selected through the validated m4-intro-vr entry.
; Own maps/descriptors checked against local Virtua Racing; see layout JSON.
; Two DRAM banks, one sealed READY job; first two runs touch hidden exclusives.
; IRQ4 performs the shared final run and VScroll flip while display is off.
        include '../build/vr-video-layout.inc'
; Level logic overlap (level.asm M4OvlWindow): the logic of tick k+1 runs while
; the SVP computes cmd10(k). Defined here, in the first file that tests it.
; Assembling with M4_NO_LOGIC_OVERLAP defined gives the serial reference.
        if ~def(M4_NO_LOGIC_OVERLAP)
M4_LOGIC_OVERLAP equ 1
        if ~def(M4_NO_DRAWLIST_OVERLAP)
M4_DRAWLIST_OVERLAP equ 1 ;and the RAM-only draw list of k+1 (level_view.asm)
        endif
        endif
; Test controls (never written by the ROM; valid only with the magic, so boot
; RAM contents cannot enable them): bit0 serial path, bit1 fixed framerate 4 in
; every M4LevelTick loop (capture-mode rate without the gate), bit2 negative test:
; M4PipeLatch reads M4_SCENE_TICK after the logic of k+1 (a deliberate leak).
; bit3 selects BSP on the 68000; bit4 retains separate cmd9/8/12/10 requests.
M4_OVL_CTL equ $fff838 ;.b test flags
M4_OVL_STATE equ $fff839 ;.b bit0 tick k+1 done, bit1 its draw list done, bit2 early tail of k done, bit3 scalars latched
M4_OVL_LOOP equ $fff83a ;.b loop naming itself before M4LevelDraw (level.asm M4OvlLoops index + 1)
M4_OVL_EXIT equ $fff83b ;.b decision of the tail run in the window (M4OvlWindow)
M4_OVL_MAGIC equ $fff83c ;.l 'OVLT' validates M4_OVL_CTL
M4_OVL_SAT equ $fff9a2 ;.l HUD SAT buffer of k built during cmd10(k), published later
M4_OVL_SATW equ $fff9a6 ;.w its WORD count
M4_OVL_WHITE equ $fff9a8 ;.b M4_WHITEADD of image k, latched with the scrolls
M4_OVL_BRIGHT equ $fff9a9 ;.b M4_BRIGHT before the tail of k (the fade that follows belongs to k+1's image)
M4_DMA_DIAG equ $ff9b40
M4_DMA_BG equ $f420
M4_DMA_FONT equ $fe20
M4_DMA_FONT_TILE equ $7f1
M4VR_METRICS equ $ff9bd0
M4VR_PHASES equ $ff9bd8
M4VR_QUEUED_CLOCK equ $ff9be2
M4VR_READY_SCROLL_A equ $ff9be4
M4VR_WORK_PTR equ $ff9b80
M4VR_WORK_SLOT equ $ff9b84
M4VR_READY_PTR equ $ff9b88
M4VR_READY_SLOT equ $ff9b8c
M4VR_READY_FRAME equ $ff9b8e
M4VR_READY_SEQUENCE equ $ff9b90
M4VR_READY_CHECKSUM equ $ff9b92
M4VR_READY_SCROLL equ $ff9b94
M4VR_READY_BUSY equ $ff9b96
M4VR_STAGE equ $ff9b98
M4VR_HCOUNT equ $ff9b9a
M4VR_PRESENT_FRAME equ $ff9b9c
M4VR_PRESENT_SEQUENCE equ $ff9b9e
M4VR_PRESENT_COUNT equ $ff9ba0
M4VR_FRONT_SLOT equ $ff9ba2
M4VR_ERROR equ $ff9ba4
M4VR_LATE equ $fff834 ;.w re-enables after line 15 (late display: counted, not fatal)
; 26th H-INT (every8 lines from line7) = line207, the measured start of VR's
; long tandas; long runs then end near line6 instead of14, keeping margin to15.
        if def(M4_GRAPHICS117)
; hw108 (tools/hw-boot/make-round47.py): a single H-INT at line207 instead of
; 26 interrupts every eight lines; same window, fewer 68000 interruptions.
M4VR_HINTS equ 1
M4VR_HINT_REG equ $8acf
        else
M4VR_HINTS equ 26
M4VR_HINT_REG equ $8a07
        endif
M4VR_TRACE equ $ff9bb0 ;three(beginHV,endHV,beginVB,endVB) eight-byte records
M4VR_PEND_FRAME equ $ff9c60 ;sealed WORK waiting for READY release
M4VR_PEND_SEQUENCE equ $ff9c62
M4VR_PEND_CHECKSUM equ $ff9c64
M4VR_PEND_SCROLL equ $ff9c66
M4VR_PEND_CLOCK equ $ff9c68
M4VR_PEND_METRICS equ $ff9c6a ;8 geometry + 10 phase bytes
M4VR_COMPLETE equ $ff9c7e ;1 while sealed WORK waits; cleared by M4VRPromote
; Original INIDISP brightness travels with each image (fades are per tick).
M4_BRIGHT equ $ff9c86 ;BYTE 0..15 of the tick being produced
M4VR_PEND_BRIGHT equ $ff9c87
M4VR_READY_BRIGHT equ $ff9c88
M4VR_SHOWN_BRIGHT equ $ff9c89
M4VR_SCENE_FRAME equ $ff9c8a ;first image allowed after an in-level BG replacement
M4VR_SCENE_HOLD equ $ff5f58 ;0 visible,1 new scene,2 wait frame,3/5 loading BG
M4_BASE_CRAM equ $ffd600 ;64 WORDs at full brightness
M4_FADE_CRAM equ $ffd680 ;two 64-WORD faded copies, indexed by WORK slot
; Plane B horizontal scroll per image (level BG; 0 in intro/title).
M4_BG_HSCROLL equ $ffd840 ;producer value of the tick being drawn
M4P_HSCROLL equ $ffd842 ;latched with the overlapped cmd8
M4VR_PEND_HSCROLL equ $ffd844
M4VR_READY_HSCROLL equ $ffd846
; Corneria BG2 roll tilt (build/research/bg-tilt.md): plrotz travels with the
; image; FramebufferReady builds, outside the IRQ, 16 plane-B column VSCROLL
; values + 224 per-line HSCROLL values into the PEND buffer; Promote swaps it
; to READY; the stage-3 IRQ (display off) writes them with the new image.
M4_LEVEL_TILT equ $ffd84a ;.w 1: level column/line scroll modes active
M4_BG_TILT equ $ffd84c ;.w producer plrotz (state of the image being drawn)
M4P_TILT equ $ffd84e ;.w latched with the overlapped cmd8
M4VR_ARG_TILT equ $ffd850 ;.w FramebufferReady argument
M4VR_TILT_PEND equ $ffd852 ;.l buffer of the sealed image
M4VR_TILT_READY equ $ffd856 ;.l buffer of the READY image
M4_TILT_BUF0 equ $ff5000 ;16 + 224 WORDs (intro background decode area)
M4_TILT_BUF1 equ $ff5200

M4BlockVideoInit:
M4VRVideoInit:
        lea TEXT_VIDEO_DIAG,a0
        moveq #15,d0
M4VRClearVideoDiag:
        clr.l (a0)+
        dbra d0,M4VRClearVideoDiag
        move.l #'M4TV',TEXT_VIDEO_DIAG
        move.w #$6000,TEXT_VIDEO_DIAG+6
        lea M4_DMA_DIAG,a0
        moveq #15,d0
M4VRClearDMADiag:
        clr.l (a0)+
        dbra d0,M4VRClearDMADiag
        move.l #'M4VR',M4_DMA_DIAG
        move.w #$a55a,TEXT_BITMAP-2
        move.w #$a55a,TEXT_BITMAP_GUARD_END
        move.w #$8104,VDP_CTRL
        move.w #$8b00,VDP_CTRL ;full-screen scroll (the level sets $8B07)
        lea M4VR_WORK_PTR,a0
        moveq #19,d0
M4VRClearState:
        clr.l (a0)+
        dbra d0,M4VRClearState
        clr.w M4VR_COMPLETE
        clr.w M4_TITLE_SPRITE
        clr.w M4_LEVEL_HUD
        clr.l M4_BG_HSCROLL
        clr.l M4VR_PEND_HSCROLL
        clr.l M4_LEVEL_TILT ;and M4_BG_TILT
        clr.l M4P_TILT ;and M4VR_ARG_TILT
        move.l #M4_TILT_BUF0,M4VR_TILT_PEND
        move.l #M4_TILT_BUF1,M4VR_TILT_READY
        move.l #$0f0f0f0f,M4_BRIGHT ;bright/pending/ready/shown = 15
        clr.w M4P_STATE
        clr.w M4N_ON
        clr.b M4VR_SCENE_HOLD
        clr.w M4P_EARLY
        clr.b M4_OVL_STATE ;no tick, draw list or tail run ahead
        clr.b M4_OVL_LOOP
        move.l #M4VR_BITMAP0,M4VR_WORK_PTR
        move.w #$1800,MAILBOX+24 ;current work destination in DRAM WORD units
        move.w #1,M4VR_FRONT_SLOT ;blank page1 visible, first producer targets0
        move.w #M4VR_HINTS,M4VR_HCOUNT
        move.w #$8f02,VDP_CTRL
        move.l #$40000000,VDP_CTRL
        move.w #32767,d0
M4VRClearVRAM:
        ; 68000 CLR reads first: invalid with a VDP write command (HW 58/59).
        move.w #0,VDP_DATA
        dbra d0,M4VRClearVRAM
        move.w #M4VR_MASK_VRAM,d0
        bsr M4TextVideoWriteAddress
        moveq #31,d0
M4VRBlackMarginPattern:
        move.l #$11111111,VDP_DATA ;opaque palette3 index1, not transparent0
        dbra d0,M4VRBlackMarginPattern
        move.l #$c0620000,VDP_CTRL
        move.w #0,VDP_DATA ;palette3 colour1 is reserved black
        move.w #$9010,VDP_CTRL ;32x64:256x512 pixels, BOTH planes
        move.w #$8230,VDP_CTRL ;BG A fixed C000; never flip reg2
        move.w #$8407,VDP_CTRL ;BG B E000
        move.w #$856c,VDP_CTRL ;SAT D800
        move.w #$8d34,VDP_CTRL ;HScroll D000, outside BG A
        move.w #$8c00,VDP_CTRL ;H32
        move.w #M4VR_HINT_REG,VDP_CTRL ;H-INT line counter, see M4VR_HINTS
        move.w #$9100,VDP_CTRL
        move.w #$9200,VDP_CTRL ;window disabled; HUD will use sprites
        move.l #$40000003,VDP_CTRL
        lea M4VRPlaneAMap,a0
        move.w #2047,d0
M4VRCopyPlaneA:
        move.w (a0)+,VDP_DATA
        dbra d0,M4VRCopyPlaneA
        move.l #$40000010,VDP_CTRL
        move.w #$d1,VDP_DATA
        move.w #0,VDP_DATA
        ; Caller loads original BG/CRAM/HUD then enables H-INT with reg0=$14,
        ; V-INT/display/DMA with reg1=$74 and CPU IPL3. No unbound IRQ here.
        rts

; Called by IRQ6. Preserve the clock/status handling of the normal IRQ6.
M4VRVBlankHook:
        move.w #M4VR_HINTS,M4VR_HCOUNT
        rts

; d0=completed logical frame,d1=fresh SSP sequence,d2=checked CRC,d3=BG scroll.
; WORK is never the READY bank. Queue waits before reusing the consumed bank.
M4VRFramebufferReady:
        movem.l d1-d7/a0-a2,-(sp)
        tst.w M4VR_ERROR
        bne M4VRQueueBad
        tst.w M4VR_COMPLETE
        bne M4VRQueueBad ;producer must wait for WORK before another image
        move.w d0,M4VR_PEND_FRAME
        move.w d1,M4VR_PEND_SEQUENCE
        move.w d2,M4VR_PEND_CHECKSUM
        move.w d3,M4VR_PEND_SCROLL
        swap d3
        move.w d3,M4VR_PEND_HSCROLL ;high WORD of d3: plane B HSCROLL
        tst.b M4_SPB_ON
        beq.s M4VRNoSpaceBg
        move.w d3,d0
        jsr M4LevelBgStream ;plane B columns of this image (level_space_bg.asm)
M4VRNoSpaceBg:
        swap d3
        tst.w M4_LEVEL_TILT
        beq.s M4VRNoTiltBuild
        bsr M4VRTiltBuild
M4VRNoTiltBuild:
        move.b M4_BRIGHT,M4VR_PEND_BRIGHT
        bsr M4VRFadePalette
        move.w M4_CLOCK,M4VR_PEND_CLOCK
        lea M4VR_PEND_METRICS,a0
        move.l M4_GEOM_WORK,(a0)+
        move.l M4_GEOM_WORK+4,(a0)+
        move.l M4_PHASE_WORK,(a0)+
        move.l M4_PHASE_WORK+4,(a0)+
        move.w M4_PHASE_WORK+8,(a0)
        move.w sr,-(sp)
        ori.w #$0700,sr ;short: only the READY decision and promotion
        move.w #1,M4VR_COMPLETE
        ; Non-blocking seal: promote now if READY is free, else IRQ4 promotes
        ; this sealed WORK when it releases the presented bank.
        tst.w M4VR_READY_BUSY
        bne.s M4VRSealQueued
        bsr.s M4VRPromote
M4VRSealQueued:
        move.w (sp)+,sr
        moveq #0,d0
        bra.s M4VRQueueReturn
M4VRQueueBad:
        moveq #-6,d0 ;error code
M4VRQueueReturn:
        movem.l (sp)+,d1-d7/a0-a2
        rts

; IRQ masked. Sealed WORK becomes READY; the released bank becomes WORK.
; COMPLETE clears LAST, after WORK pointer and SVP destination are switched.
M4VRPromote:
        movem.l d4/a0,-(sp)
        move.l M4VR_TILT_PEND,d4 ;tilt tables follow the sealed image
        move.l M4VR_TILT_READY,M4VR_TILT_PEND
        move.l d4,M4VR_TILT_READY
        move.l M4VR_WORK_PTR,M4VR_READY_PTR
        move.w M4VR_WORK_SLOT,M4VR_READY_SLOT
        move.w M4VR_PEND_FRAME,M4VR_READY_FRAME
        move.w M4VR_PEND_SEQUENCE,M4VR_READY_SEQUENCE
        move.w M4VR_PEND_CHECKSUM,M4VR_READY_CHECKSUM
        move.w M4VR_PEND_SCROLL,M4VR_READY_SCROLL
        move.w M4VR_PEND_HSCROLL,M4VR_READY_HSCROLL
        move.b M4VR_PEND_BRIGHT,M4VR_READY_BRIGHT
        move.w M4VR_WORK_SLOT,d4
        add.w d4,d4
        lea M4VRScrollValues,a0
        move.w (a0,d4.w),M4VR_READY_SCROLL_A
        lea M4VR_PEND_METRICS,a0
        move.l (a0)+,M4VR_METRICS
        move.l (a0)+,M4VR_METRICS+4
        move.l (a0)+,M4VR_PHASES
        move.l (a0)+,M4VR_PHASES+4
        move.w (a0),M4VR_PHASES+8
        move.w M4VR_PEND_CLOCK,M4VR_QUEUED_CLOCK
        clr.w M4VR_STAGE
        lea M4VR_TRACE,a0
        moveq #5,d4
M4VRClearTrace:
        clr.l (a0)+
        dbra d4,M4VRClearTrace
        eori.w #1,M4VR_WORK_SLOT
        move.w M4VR_WORK_SLOT,d4
        lsl.w #2,d4
        lea M4VRBitmapAddresses,a0
        move.l (a0,d4.w),d4
        move.l d4,M4VR_WORK_PTR
        subi.l #$300000,d4
        lsr.l #1,d4
        move.w d4,MAILBOX+24
        move.w #1,M4VR_READY_BUSY ;publish sealed job
        clr.w M4VR_COMPLETE ;WORK is free for the next cmd7/cmd8
        movem.l (sp)+,d4/a0
        rts

; WORK slot's faded copy of M4_BASE_CRAM for M4_BRIGHT b: SNES INIDISP
; scales every component by (b+1)/16; MD 3-bit components floor that.
; Bits 4..5 select a level hit flash (init_strats_l 06:84DA, colour math
; add on BG1-3+backdrop): 1 G=B=31, 2 R=31, 3 G=B=7; MD adds (c>>2)<<1
; per 3-bit component with saturation, after the fade.
M4VRFadePalette:
        movem.l d0-d7/a0-a2,-(sp)
        moveq #0,d4
        move.b M4VR_PEND_BRIGHT,d4
        andi.b #$3f,d4 ;bit6: CRAM base version only
        cmpi.b #15,d4
        bne.s M4VRFadeNeeded
        tst.b M4_WHITEADD
        beq M4VRFadeDone
M4VRFadeNeeded:
        move.w d4,d7
        lsr.w #4,d7 ;flash code
        andi.w #15,d4
        addq.w #1,d4
        lea M4_BASE_CRAM,a0
        lea M4_FADE_CRAM,a1
        tst.w M4VR_WORK_SLOT
        beq.s M4VRFadeSlot
        lea 128(a1),a1
M4VRFadeSlot:
        moveq #63,d5
M4VRFadeColour:
        move.w (a0)+,d0
        moveq #0,d3
        moveq #2,d2
M4VRFadeComponent:
        move.w d0,d1
        andi.w #$e,d1 ;3-bit component in bits1..3
        mulu.w d4,d1
        lsr.w #4,d1
        andi.w #$e,d1
        or.w d1,d3
        ror.w #4,d3
        lsr.w #4,d0
        dbra d2,M4VRFadeComponent
        ror.w #4,d3 ;components back to B..G..R positions
        tst.w d7
        beq.s M4VRFadeStore
        move.w d7,d0
        add.w d0,d0
        lea M4VRFlashAdd-2,a2
        move.w (a2,d0.w),d0 ;0BBB0GGG0RRR addend
        moveq #2,d2
M4VRFlashComponent:
        move.w d3,d1
        andi.w #$e,d1
        move.w d0,d6
        andi.w #$e,d6
        add.w d6,d1
        cmpi.w #$e,d1
        bls.s M4VRFlashSat
        moveq #$e,d1
M4VRFlashSat:
        andi.w #$fff0,d3
        or.w d1,d3
        ror.w #4,d3
        lsr.w #4,d0
        dbra d2,M4VRFlashComponent
        ror.w #4,d3
M4VRFadeStore:
        move.b M4_WHITEADD,d0 ;constant colour add (02:FD0F fade to white)
        beq.s M4VRFadeNoWhite
        andi.w #7,d0
        add.w d0,d0 ;MD component units
        moveq #2,d2
M4VRWhiteComponent:
        move.w d3,d1
        andi.w #$e,d1
        add.w d0,d1
        cmpi.w #$e,d1
        bls.s M4VRWhiteSat
        moveq #$e,d1
M4VRWhiteSat:
        andi.w #$fff0,d3
        or.w d1,d3
        ror.w #4,d3
        dbra d2,M4VRWhiteComponent
        ror.w #4,d3
M4VRFadeNoWhite:
        move.w d3,(a1)+
        dbra d5,M4VRFadeColour
M4VRFadeDone:
        movem.l (sp)+,d0-d7/a0-a2
        rts
M4_WHITEADD equ $fff9a1 ;.b 0..7: MD component add of the white fade (level_warp.asm)
M4VRFlashAdd:
        dc.w $0ee0,$000e,$0220 ;cyan G=B=31, red R=31, dim cyan G=B=7

; Shadow the complete CRAM after palettes are loaded (fade source).
M4VRCaptureCram:
        move.w sr,-(sp)
        ori.w #$0700,sr
        lea M4_BASE_CRAM,a0
        move.l #$00000020,VDP_CTRL ;CRAM read address0
        moveq #63,d0
M4VRCaptureWord:
        move.w VDP_DATA,(a0)+
        dbra d0,M4VRCaptureWord
        move.w (sp)+,sr
        rts

; Producer side: wait until a queued sealed image has been promoted.
M4VRWaitWork:
        tst.w M4VR_ERROR
        bne.s M4VRWaitWorkBad
        tst.w M4VR_COMPLETE
        bne.s M4VRWaitWork
        moveq #0,d0
        rts
M4VRWaitWorkBad:
        moveq #-7,d0 ;error code
        rts

; Capture/serialization only. Normal producer may render WORK during READY DMA.
; d0=frame to wait for. No acknowledgement of a partial shared-tile copy.
M4VRWaitPresented:
        tst.w M4VR_ERROR
        bne.s M4VRPresentedBad
        cmp.w M4VR_PRESENT_FRAME,d0
        bne.s M4VRWaitPresented
        moveq #0,d0
        rts
M4VRPresentedBad:
        moveq #-8,d0 ;error code
        rts

M4VRHBlankIRQ:
        movem.l d0-d7/a0-a6,-(sp)
        subq.w #1,M4VR_HCOUNT
        bne M4VRIRQReturn
        move.w #M4VR_HINTS,M4VR_HCOUNT ;VR020D84 reloads before the authorized update
        tst.w M4VR_ERROR
        bne M4VRIRQReturn
        tst.w M4VR_READY_BUSY
        beq M4VRIRQReturn
        ; VR dispatch authorizes updates from its early-frame counter1A wait.
        ; Our producer is asynchronous: defer a missed window, never begin a
        ; long copy at223 after delayed IRQ6. This is transfer scheduling only.
        move.w $c00008,d0
        lsr.w #8,d0
        tst.w M4N_ON
        beq.s M4VRNormalWindow
        tst.w M4N_VBLANK
        beq.s M4VRNormalWindow
        cmpi.w #223,d0
        blo M4VRWindowEarly
        cmpi.w #225,d0
        bhi M4VRIRQReturn ;never start a map upload late in VBlank
        move.w #$2700,sr ;IRQ6 must not release the PCM gate at line224
M4VRMapVBlank:
        move.w $c00008,d0
        lsr.w #8,d0
        cmpi.w #224,d0
        blo.s M4VRMapVBlank
        bra.s M4VRWindowOpen
M4VRNormalWindow:
        cmpi.w #215,d0
        bhi M4VRIRQReturn
        ; Final run (stage 2: third DMA + VSRAM columns + CRAM on a brightness
        ; change, before the line-15 reenable): measured 215 -> 15 with the
        ; level tilt, so it only starts up to line 212; later it is deferred.
        cmpi.w #2,M4VR_STAGE
        bne.s M4VRWindowLate
        cmpi.w #212,d0
        bhi M4VRIRQReturn
M4VRWindowLate:
        cmpi.w #207,d0
        bhs.s M4VRWindowOpen
M4VRWindowEarly:
        move.w #1,M4VR_HCOUNT ;early count phase: retry at the next H-INT
        bra M4VRIRQReturn
M4VRWindowOpen:
        move.w #$2700,sr ;VR020D90 masks IRQ6 during the update
        jsr M4SoundDmaBegin
        lea VDP_CTRL,a5
        lea VDP_DATA,a6
        tst.w M4N_ON
        beq.s M4VRTraceNormal
        moveq #0,d0 ;native uploads use one trace slot, not a stale VR stage3
        bra.s M4VRTraceSlot
M4VRTraceNormal:
        move.w M4VR_STAGE,d0
        mulu.w #8,d0
M4VRTraceSlot:
        lea M4VR_TRACE,a1
        adda.w d0,a1
        move.w $c00008,(a1)
        move.w M4_CLOCK,4(a1)
        tst.w M4N_ON
        beq.s M4VRNormalImage
        tst.w M4N_VBLANK
        bne.s M4VRNativeImage
        move.w #$8134,(a5)
M4VRNativeImage:
        jsr M4NIRQ
        bra M4VRIRQReturn
M4VRNormalImage:
        move.w #$8134,(a5) ;full bitmap retains the late force-blank method
        move.w M4VR_READY_SLOT,d0
        mulu.w #66,d0 ;three complete22-byte VR descriptors per page
        move.w M4VR_STAGE,d1
        mulu.w #22,d1
        add.w d1,d0
        lea M4VRDMADescriptors,a2
        adda.w d0,a2
        ; VR025974 writes precomputed registers, avoiding setup in late IRQ.
        move.w (a2)+,(a5)
        move.w (a2)+,(a5)
        move.w (a2)+,(a5)
        move.w (a2)+,(a5)
        move.w (a2)+,(a5)
        move.w #$a,$a15006
        move.w $c00008,$ff9c00 ;actual trigger diagnostic
        move.l (a2)+,(a5)
        move.w $c00008,$ff9c02 ;actual completion diagnostic
        move.w #0,$a15006
        move.l (a2)+,(a5) ;restore useful first-data destination
        movea.l (a2)+,a0
        move.l (a0),(a6) ;repair the first LONGWORD after SVP delay
        addq.w #1,M4VR_STAGE
        tst.w M4_LEVEL_TILT
        beq.s M4VRTiltTableDone
        cmpi.w #2,M4VR_STAGE
        bne.s M4VRTiltTableDone
        ; second run (the short one: measured end at lines 231..239, about 40
        ; lines of slack; runs 1 and 3 end at lines 0..14): line HSCROLL B of
        ; the READY image into the hidden page's table (D000/D400 = page 0/1).
        ; DMA from RAM to VRAM D002/D402 + 4n, autoincrement 4.
        movea.l M4VR_TILT_READY,a0
        lea 32(a0),a0
        move.w #$8f04,(a5)
        move.l a0,d0
        lsr.l #1,d0
        move.w #$9500,d1
        move.b d0,d1
        move.w d1,(a5)
        lsr.l #8,d0
        move.w #$9600,d1
        move.b d0,d1
        move.w d1,(a5)
        lsr.l #8,d0
        move.w #$9700,d1
        move.b d0,d1
        andi.w #$ff7f,d1
        move.w d1,(a5)
        move.w #$93e0,(a5) ;224 WORDs
        move.w #$9400,(a5)
        move.l #$50020083,d0 ;68000 -> VRAM D002 (DMA)
        tst.w M4VR_READY_SLOT
        beq.s M4VRTiltTableCmd
        move.l #$54020083,d0 ;VRAM D402
M4VRTiltTableCmd:
        move.l d0,(a5)
        move.w #$8f02,(a5)
M4VRTiltTableDone:
        ; second run: level HUD sprites (SAT from sprite 13) by DMA from the
        ; buffer published by M4LevelHudSprites (no VDP access in the producer).
        cmpi.w #2,M4VR_STAGE
        bne.s M4VRHudSatDone
        tst.w M4_LEVEL_HUD
        beq.s M4VRHudSatDone
        move.l M4_LV_SATREADY,d0
        beq.s M4VRHudSatDone
        lsr.l #1,d0
        move.w #$9500,d1
        move.b d0,d1
        move.w d1,(a5)
        lsr.l #8,d0
        move.w #$9600,d1
        move.b d0,d1
        move.w d1,(a5)
        lsr.l #8,d0
        move.w #$9700,d1
        move.b d0,d1
        andi.w #$ff7f,d1
        move.w d1,(a5)
        move.w M4_LV_SATWORDS,d0
        move.w #$9300,d1
        move.b d0,d1
        move.w d1,(a5)
        lsr.w #8,d0
        move.w #$9400,d1
        move.b d0,d1
        move.w d1,(a5)
        move.l #$58680083,(a5) ;68000 -> VRAM D868 (SAT sprite 13), DMA
M4VRHudSatDone:
        cmpi.w #3,M4VR_STAGE
        bne M4VRDisplayOn
        tst.w M4_LEVEL_TILT
        bne.s M4VRTiltPresent
        move.l #$40000010,(a5)
        move.w M4VR_READY_SCROLL_A,(a6)
        move.w M4VR_READY_SCROLL,(a6)
        move.w #$8d34,(a5) ;HSCROLL table D000 (a tilt image may have left D400)
        move.l #$50020003,(a5) ;VRAM D002: plane B full-screen HSCROLL
        move.w M4VR_READY_HSCROLL,(a6)
        bra.s M4VRScrollsDone
M4VRTiltPresent:
        ; VSRAM column mode: A page value in every column, B tilt columns
        movea.l M4VR_TILT_READY,a0
        move.l #$40000010,(a5)
        move.w M4VR_READY_SCROLL_A,d0
        moveq #15,d1
M4VRTiltColumns:
        move.w d0,(a6)
        move.w (a0)+,(a6)
        dbra d1,M4VRTiltColumns
        move.w #$8d34,(a5) ;HSCROLL table of the page now shown
        tst.w M4VR_READY_SLOT
        beq.s M4VRScrollsDone
        move.w #$8d35,(a5) ;D400
M4VRScrollsDone:
        move.b M4VR_READY_BRIGHT,d0
        tst.b M4VR_SCENE_HOLD
        bne.s M4VRCramChanged ;resource replacement invalidates the CRAM shadow
        cmp.b M4VR_SHOWN_BRIGHT,d0
        beq.s M4VRDisplayOn
M4VRCramChanged:
        move.b d0,M4VR_SHOWN_BRIGHT
        andi.b #$3f,d0 ;bit6: CRAM base version (level BG palette)
        lea M4_BASE_CRAM,a0
        cmpi.b #15,d0
        beq.s M4VRCramCopy
        lea M4_FADE_CRAM,a0
        tst.w M4VR_READY_SLOT
        beq.s M4VRCramCopy
        lea 128(a0),a0
M4VRCramCopy:
        move.l #$c0000000,(a5) ;display is still off: no CRAM dots
        moveq #31,d0
M4VRCramWord:
        move.l (a0)+,(a6)
        dbra d0,M4VRCramWord
M4VRDisplayOn:
        move.w #$8174,(a5)
        move.w $c00008,2(a1)
        move.w M4_CLOCK,6(a1)
        jsr M4SoundDmaEnd
        move.w 2(a1),d0
        lsr.w #8,d0
        cmpi.w #224,d0
        bhs.s M4VRReenableOK
        cmpi.w #15,d0
        blo.s M4VRReenableOK
        ; Late: the first lines of this field show the end of the blanking
        ; work. The game goes on (it used to stop with M4VR_ERROR 2); the
        ; count is the measurable cost (smoke/measure tools read it).
        addq.w #1,M4VR_LATE
M4VRReenableOK:
        cmpi.w #3,M4VR_STAGE
        bne M4VRIRQReturn
        ; Only VDP work belongs to the blanking deadline. Publish RAM metadata
        ; after reenable; WORK cannot reuse READY until this IRQ releases it.
        move.w M4VR_READY_SLOT,M4VR_FRONT_SLOT
        move.w M4VR_READY_SEQUENCE,M4VR_PRESENT_SEQUENCE
        move.w M4VR_READY_FRAME,M4VR_PRESENT_FRAME
        addq.w #1,M4VR_PRESENT_COUNT
        move.w M4VR_READY_SCROLL,M4_BOSS_SCROLL_PRESENT
        move.w M4VR_READY_SEQUENCE,TEXT_VIDEO_DIAG+8
        move.w M4VR_READY_SLOT,d0
        mulu.w #$680,d0
        addi.w #$c000,d0
        move.w d0,TEXT_VIDEO_DIAG+20
        move.w #1,TEXT_VIDEO_DIAG+4
        move.l M4VR_METRICS,M4_GEOM_PHASES
        move.l M4VR_METRICS+4,M4_GEOM_PHASES+4
        move.l M4VR_PHASES,M4_PHASE_LAST
        move.l M4VR_PHASES+4,M4_PHASE_LAST+4
        move.w M4_CLOCK,d0
        sub.w M4VR_QUEUED_CLOCK,d0
        move.w d0,M4_PHASE_LAST+8
        clr.w M4VR_READY_BUSY ;release DRAM only AFTER all copies/scrolls
        tst.w M4VR_COMPLETE
        beq.s M4VRNoQueued
        bsr M4VRPromote ;queued sealed WORK; stage0 starts at the next window
M4VRNoQueued:
        bsr M4IntroFpsUpdate
M4VRIRQReturn:
        movem.l (sp)+,d0-d7/a0-a6
        rte

; Scene entries have no live producer when they replace VRAM. Drain before
; changing the scroll mode, and let only the final DMA reveal the new scene.
M4VRSceneBegin:
        movem.l d0-d7/a0-a6,-(sp)
        jsr M4PipeFlush
        tst.w d0
        bne M4VRSceneFailed
        jsr M4VRWaitWork
        tst.w d0
        bne M4VRSceneFailed
        move.l #TIMEOUT_POLLS,d1
M4VRSceneDrain:
        tst.w M4VR_ERROR
        bne M4VRSceneFailed
        tst.w M4VR_READY_BUSY
        beq.s M4VRSceneIdle
        subq.l #1,d1
        bne.s M4VRSceneDrain
        move.w #$31,M4VR_ERROR
        bra M4VRSceneFailed
M4VRSceneIdle:
        jsr M4RmNativeLeave
        move.w sr,-(sp)
        ori.w #$0700,sr
        move.w #$8134,VDP_CTRL
        move.b #1,M4VR_SCENE_HOLD
        move.b #$ff,M4VR_SHOWN_BRIGHT
        move.w #$8f02,VDP_CTRL
        move.w #$8b00,VDP_CTRL
        move.w #$8d34,VDP_CTRL
        move.l #$50000003,VDP_CTRL
        move.l #0,VDP_DATA
        move.w (sp)+,sr
        movem.l (sp)+,d0-d7/a0-a6
        rts
M4VRSceneFailed:
        jmp M4IntroFailed

; A BG can change during the logic overlapped with the previous raster.
; Never flush that request recursively or reset its intended camera scroll.
; Old images may retire, but cannot reveal the partially replaced resources.
M4VRBgReplaceBegin:
        move.w sr,-(sp)
        ori.w #$0700,sr
        cmpi.b #1,M4VR_SCENE_HOLD
        beq.s M4VRBgLoadingScene
        move.b #3,M4VR_SCENE_HOLD
        bra.s M4VRBgHidden
M4VRBgLoadingScene:
        move.b #5,M4VR_SCENE_HOLD ;initial setbg precedes the new tick counter
M4VRBgHidden:
        move.w #$8134,VDP_CTRL
        move.w (sp)+,sr
        rts
M4VRBgReplaceEnd:
        move.w sr,-(sp)
        ori.w #$0700,sr
        cmpi.b #5,M4VR_SCENE_HOLD
        bne.s M4VRBgFrame
        move.b #1,M4VR_SCENE_HOLD
        bra.s M4VRBgInvalid
M4VRBgFrame:
        move.w M4_SCENE_TICK,M4VR_SCENE_FRAME
        move.b #2,M4VR_SCENE_HOLD
M4VRBgInvalid:
        move.b #$ff,M4VR_SHOWN_BRIGHT
        move.w (sp)+,sr
        rts

; Free-running overlap (capture mode stays serial): tick k's cmd8 is latched,
; started right after SVP9(k+1) and runs while the 68000 orders BSP faces of
; k+1. Particle primitives read SVP9 emitter records by pointer, so such a
; tick starts cmd8 at once and SVP9(k+1) waits for it (logic overlap only). It is completed, verified and sealed before any other SVP request, at
; the next draw and at intro stop. cmd8 reads only primitives/particles/WORK,
; which nothing writes between latch and seal; mailbox inputs are latched.
M4P_STATE equ $ff9c20 ;0 none,1 latched,2 started,3 raster owned by cmd13
M4P_COUNT equ $ff9c22
M4P_FLAG equ $ff9c24
M4P_TICK equ $ff9c26
; calcbg2voffsets 02:DB54 + mrotplanet 06:FB87 for the sealed image, into
; the PEND buffer: 16 WORDs plane-B column VSCROLL, then 224 WORDs line
; HSCROLL (MD lines 0..223 = SNES rows). Column j takes the SNES 8-px slot of
; its centre pixel on the pivot line 112 (HOFS = B): value = bg2scroll +
; table[hi|plrotz| & 7] (mirrored for plrotz < 0); bg2scroll = VSCROLL - 16
; (the flat table value). Lines: s = asr7(~plrotz), a_k = floor(k*s/256);
; HOFS(112-k) = B + a_k, HOFS(111+k) = B - a_k - 1; HSCROLL = -HOFS.
M4VRTiltBuild:
        if def(M4_GRAPHICS117)
        jmp G117H110TiltBuild
        dc.l M4VR_TILT_PEND ;unreachable tail of the displaced movea
        else
        movem.l d0-d7/a0-a1,-(sp)
        movea.l M4VR_TILT_PEND,a0
        endif
        move.w M4VR_ARG_TILT,d0
        moveq #0,d6 ;mirror
        move.w d0,d1
        bpl.s M4VRTiltAbs
        neg.w d1
        moveq #1,d6
M4VRTiltAbs:
        lsr.w #8,d1
        andi.w #7,d1
        lsl.w #5,d1
        lea M4TiltTables,a1
        adda.w d1,a1
        move.w M4VR_PEND_HSCROLL,d2 ;H = -B
        move.w d2,d3
        neg.w d3
        andi.w #7,d3 ;f = B & 7
        move.w d2,d4
        andi.w #15,d4 ;sh = (-B) & 15
        move.w M4VR_PEND_SCROLL,d5
        subi.w #16,d5 ;bg2scroll
        moveq #0,d7
M4VRTiltColumn:
        move.w d7,d1
        lsl.w #4,d1
        addq.w #8,d1
        add.w d4,d1 ;centre x
        cmpi.w #255,d1
        bls.s M4VRTiltCentre
        move.w #255,d1
M4VRTiltCentre:
        add.w d3,d1
        lsr.w #3,d1 ;slot
        subq.w #1,d1 ;table entry (slot 0: hidden column, entry 0)
        bpl.s M4VRTiltEntryLow
        moveq #0,d1
M4VRTiltEntryLow:
        cmpi.w #31,d1
        bls.s M4VRTiltEntry
        moveq #31,d1
M4VRTiltEntry:
        tst.w d6
        beq.s M4VRTiltDirect
        neg.w d1
        addi.w #31,d1
M4VRTiltDirect:
        moveq #0,d0
        move.b (a1,d1.w),d0
        add.w d5,d0
        andi.w #511,d0
        move.w d0,(a0)+
        addq.w #1,d7
        cmpi.w #16,d7
        bne.s M4VRTiltColumn
        move.w M4VR_ARG_TILT,d0
        not.w d0
        asr.w #7,d0 ;s
        move.w d0,d1
        muls.w #112,d1 ;k*s, k = 112 at line 0
        moveq #111,d7
M4VRTiltUpper:
        move.w d1,d4
        asr.w #8,d4 ;a_k
        move.w d2,d5
        sub.w d4,d5 ;-(B + a_k)
        andi.w #$3ff,d5
        move.w d5,(a0)+
        sub.w d0,d1
        dbra d7,M4VRTiltUpper
        move.w d0,d1 ;k = 1 at line 112
        moveq #111,d7
M4VRTiltLower:
        move.w d1,d4
        asr.w #8,d4
        move.w d2,d5
        add.w d4,d5
        addq.w #1,d5 ;-(B - a_k - 1)
        andi.w #$3ff,d5
        move.w d5,(a0)+
        add.w d0,d1
        dbra d7,M4VRTiltLower
        movem.l (sp)+,d0-d7/a0-a1
        rts
M4VRTiltEnd:

M4P_SCROLL equ $ff9c28
M4P_METRICS equ $ff9c2a ;8 geometry + 10 phase bytes of tick k
M4P_SAVED equ $ff9c40 ;same layout, current tick while sealing k
M4P_EARLY equ $ff9c3e ;1: tick has particle primitives reading SVP9 records

M4PipeLatch:
        move.w MAILBOX+20,M4P_COUNT
        move.w MAILBOX+22,M4P_FLAG
        if def(M4_LOGIC_OVERLAP)
        bclr #3,M4_OVL_STATE ;latched by M4OvlWindow before the logic of k+1
        beq.s M4PipeLatchNow
        cmpi.l #'OVLT',M4_OVL_MAGIC
        bne.s M4PipeLatchScalarsDone
        btst #2,M4_OVL_CTL ;negative test: read the tick after the logic of k+1
        beq.s M4PipeLatchScalarsDone
        move.w M4_SCENE_TICK,M4P_TICK
        bra.s M4PipeLatchScalarsDone
M4PipeLatchNow:
        endif
        bsr.s M4PipeLatchScalars
M4PipeLatchScalarsDone:
        move.l M4_GEOM_WORK,M4P_METRICS
        move.l M4_GEOM_WORK+4,M4P_METRICS+4
        move.l M4_PHASE_WORK,M4P_METRICS+8
        move.l M4_PHASE_WORK+4,M4P_METRICS+12
        move.w M4_PHASE_WORK+8,M4P_METRICS+16
        tst.w M4_DMA_DIAG+28
        beq.s M4PipeLatchMapReady
        tst.w M4_DMA_DIAG+26
        bne.s M4PipeLatchMapReady
        bsr M4BlockPrepareMap
M4PipeLatchMapReady:
        move.w #1,M4P_STATE
        tst.b M4_CHAIN_ACTIVE ;cmd13 consumes old particle geometry before cmd9
        bne.s M4PipeLatchDeferred
        tst.w M4P_EARLY
        beq.s M4PipeLatchDeferred
        bsr.s M4PipeKick ;overlap the next tick's logic instead of its BSP
M4PipeLatchDeferred:
        moveq #0,d0
        rts
; Producer state of the image that travels with its cmd8 (sealed by M4PipeFlush).
M4PipeLatchScalars:
        move.w M4_SCENE_TICK,M4P_TICK
        move.w M4_BOSS_SCROLL,M4P_SCROLL
        move.w M4_BG_HSCROLL,M4P_HSCROLL
        move.w M4_BG_TILT,M4P_TILT
        rts

; Same fresh-tag protocol as M4TextVideoRequest, without polling.
M4PipeKick:
        cmpi.w #1,M4P_STATE
        bne.s M4PipeKickReturn
        move.l M4_GEO_VP,MAILBOX+26 ;vanishing point offset (sprites)
        move.w #8,MAILBOX+8
        move.w M4P_COUNT,MAILBOX+20
        move.w M4P_FLAG,MAILBOX+22
        addq.w #1,TEXT_VIDEO_DIAG+6
        move.w d0,-(sp)
        move.w TEXT_VIDEO_DIAG+6,d0
        not.w d0
        move.w d0,MAILBOX+6
        move.w d0,ACK_SEQUENCE
        move.w #$dead,MAILBOX+4
        move.w #$dead,MAILBOX+16
        move.w XST_STATUS,d0
        move.w TEXT_VIDEO_DIAG+6,XST
        move.w (sp)+,d0
        move.w #2,M4P_STATE
M4PipeKickReturn:
        rts

; Returns d0=0 (nothing pending or sealed) or the M4TextVideo error code.
M4PipeFlush:
        tst.w M4P_STATE
        bne.s M4PipeFlushPending
        moveq #0,d0
        rts
M4PipeFlushPending:
        movem.l d1-d3/a0,-(sp)
        cmpi.w #3,M4P_STATE
        beq M4PipeFlushChain
        bsr M4PipeKick
        move.l #TIMEOUT_POLLS,d1
M4PipeFlushPoll:
        move.w XST_STATUS,d0
        btst #0,d0
        bne.s M4PipeFlushDone
        subq.l #1,d1
        bne.s M4PipeFlushPoll
        moveq #2,d0
        bra M4PipeFlushError
M4PipeFlushDone:
        moveq #4,d0
        move.w TEXT_VIDEO_DIAG+6,d1
        cmp.w MAILBOX+6,d1
        bne M4PipeFlushError
        cmp.w ACK_SEQUENCE,d1
        bne M4PipeFlushError
        cmpi.w #M4_RENDER_WORDS,MAILBOX+4
        bne M4PipeFlushError
        move.w MAILBOX+16,TEXT_VIDEO_DIAG+10
M4PipeFlushGuards:
        moveq #7,d0
        cmpi.w #$a55a,TEXT_BITMAP-2
        bne M4PipeFlushError
        cmpi.w #$a55a,TEXT_BITMAP_GUARD_END
        bne M4PipeFlushError
        lea M4_GEOM_WORK,a0
        move.l (a0),M4P_SAVED
        move.l 4(a0),M4P_SAVED+4
        move.l M4P_METRICS,(a0)
        move.l M4P_METRICS+4,4(a0)
        lea M4_PHASE_WORK,a0
        move.l (a0),M4P_SAVED+8
        move.l 4(a0),M4P_SAVED+12
        move.w 8(a0),M4P_SAVED+16
        move.l M4P_METRICS+8,(a0)
        move.l M4P_METRICS+12,4(a0)
        move.w M4P_METRICS+16,8(a0)
        move.w M4P_TICK,d0
        move.w TEXT_VIDEO_DIAG+6,d1
        move.w TEXT_VIDEO_DIAG+10,d2
        move.w M4P_HSCROLL,d3
        swap d3
        move.w M4P_SCROLL,d3
        move.w M4P_TILT,M4VR_ARG_TILT
        bsr M4VRFramebufferReady
        move.w d0,d1
        lea M4_GEOM_WORK,a0
        move.l M4P_SAVED,(a0)
        move.l M4P_SAVED+4,4(a0)
        lea M4_PHASE_WORK,a0
        move.l M4P_SAVED+8,(a0)
        move.l M4P_SAVED+12,4(a0)
        move.w M4P_SAVED+16,8(a0)
        clr.w M4P_STATE
        moveq #-1,d0
        tst.w d1
        bne.s M4PipeFlushError
        move.w TEXT_VIDEO_DIAG+6,TEXT_VIDEO_DIAG+8
        move.w #1,TEXT_VIDEO_DIAG+4
        moveq #0,d0
        bra.s M4PipeFlushReturn
M4PipeFlushError:
        clr.w M4P_STATE
        move.w d0,TEXT_VIDEO_DIAG+4
M4PipeFlushReturn:
        movem.l (sp)+,d1-d3/a0
        tst.w d0
        rts

; Read only the cmd8 sub-result. Final XST/ACK belongs to cmd13 and is
; consumed by M4GeometryPoll; the header is retained until that ACK.
M4PipeFlushChain:
        if def(M4_GRAPHICS117)
        jmp G117PollCopy         ; same poll, run from RAM
        else
        move.l #TIMEOUT_POLLS,d1
        endif
M4PipeFlushChainPoll:
        tst.w M4_CHAIN_HDR+6
        bne.s M4PipeFlushChainDone
        subq.l #1,d1
        bne.s M4PipeFlushChainPoll
        moveq #2,d0
        bra M4PipeFlushError
M4PipeFlushChainDone:
        if def(M4_GRAPHICS117)
        jmp G117Marker           ; replays both displaced instructions
        dc.l M4_CHAIN_HDR+6      ; unreachable tail of the displaced cmpi
        else
        moveq #4,d0
        cmpi.w #1,M4_CHAIN_HDR+6
        endif
M4PipeFlushChainDone10:
        bne M4PipeFlushError
        cmpi.w #M4_RENDER_WORDS,M4_CHAIN_HDR+8
        bne M4PipeFlushError
        move.w M4_CHAIN_HDR+10,TEXT_VIDEO_DIAG+10
        bra M4PipeFlushGuards

; Existing producer API: maps fixed once, rendering needs no per-image map DMA.
M4BlockPrepareMap:
        move.w #768,TEXT_VIDEO_DIAG+14
        move.w #1,M4_DMA_DIAG+26
        clr.w M4_DMA_DIAG+24
        rts
M4BlockVideoUpload:
        movem.l d1-d7/a0-a6,-(sp)
        if def(M4_LOGIC_OVERLAP)
        bclr #3,M4_OVL_STATE ;no cmd8 for this image: M4OvlWindow latched what
        beq.s M4VRUploadLive ;travels with it before the logic of the next tick
        move.w M4P_TICK,d0
        cmpi.l #'OVLT',M4_OVL_MAGIC ;negative test (M4_OVL_CTL bit2): the tick after the logic of k+1
        bne.s M4VRUploadLatched
        btst #2,M4_OVL_CTL
        beq.s M4VRUploadLatched
        move.w M4_SCENE_TICK,d0
M4VRUploadLatched:
        move.w TEXT_VIDEO_DIAG+6,d1
        move.w TEXT_VIDEO_DIAG+10,d2
        move.w M4P_HSCROLL,d3
        swap d3
        move.w M4P_SCROLL,d3
        move.w M4P_TILT,M4VR_ARG_TILT
        move.b M4_WHITEADD,d4 ;the fade of the palette reads the white add of this image
        move.b M4_OVL_WHITE,M4_WHITEADD
        move.b M4_BRIGHT,d5 ;and the brightness the serial path has at this point
        move.b M4_OVL_BRIGHT,M4_BRIGHT
        bsr M4VRFramebufferReady
        move.b d4,M4_WHITEADD
        move.b d5,M4_BRIGHT
        bra.s M4VRUploadSealed
M4VRUploadLive:
        endif
        move.w M4_SCENE_TICK,d0
        move.w TEXT_VIDEO_DIAG+6,d1
        move.w TEXT_VIDEO_DIAG+10,d2
        move.w M4_BG_HSCROLL,d3
        swap d3
        move.w M4_BOSS_SCROLL,d3
        move.w M4_BG_TILT,M4VR_ARG_TILT
        bsr M4VRFramebufferReady
M4VRUploadSealed:
        tst.w d0
        bne.s M4VRUploadReturn
        tst.w INTRO_CAPTURE
        beq.s M4VRUploadReturn
        move.w M4_SCENE_TICK,d0
        bsr M4VRWaitPresented ;capture only after complete publication
M4VRUploadReturn:
        movem.l (sp)+,d1-d7/a0-a6
        rts

; HUD lives in sprites: it cannot occupy the two overlapping map margins.
; Five8x8 glyphs at y7 in the top margin; sprite priority preserves the HUD.
M4VRFpsSprites:
        movem.l d0-d7/a0,-(sp)
        move.w sr,-(sp)
        ori.w #$0700,sr ;IRQ4 must never interrupt a VDP address/data sequence
        move.w #M4VR_SAT,d0
        bsr M4TextVideoWriteAddress
        moveq #0,d2
        move.w M4_FPS_VALUE,d2
        divu.w #10,d2
        move.w d2,d3
        swap d2
        moveq #0,d7
M4VRFpsGlyph:
        move.w #135,VDP_DATA ;7+sprite origin128
        move.w d7,d0
        addq.w #1,d0
        cmpi.w #5,d0
        bne.s M4VRFpsLink
        moveq #5,d0
M4VRFpsLink:
        move.w d0,VDP_DATA ;size1x1/link
        move.w #$e7f1,d0
        add.w d7,d0
        cmpi.w #3,d7
        blo.s M4VRFpsPattern
        move.w #$e7f4,d0
        cmpi.w #3,d7
        bne.s M4VRFpsUnits
        add.w d3,d0
        bra.s M4VRFpsPattern
M4VRFpsUnits:
        add.w d2,d0
M4VRFpsPattern:
        move.w d0,VDP_DATA
        move.w d7,d0
        lsl.w #3,d0
        cmpi.w #3,d7
        blo.s M4VRFpsX
        addq.w #8,d0
M4VRFpsX:
        addi.w #128,d0
        move.w d0,VDP_DATA
        addq.w #1,d7
        cmpi.w #5,d7
        bne.s M4VRFpsGlyph
        ; Eight4x1 opaque sprites cover y223, where the overlapped map would
        ; otherwise expose the peer's first graphics row. No extra blank IRQ.
        moveq #0,d7
M4VRFooterMaskSprite:
        move.w #351,VDP_DATA ;223+sprite origin128
        move.w d7,d0
        addq.w #6,d0
        cmpi.w #7,d7
        bne.s M4VRFooterMaskLink
        moveq #0,d0
        tst.w M4_TITLE_SPRITE
        bne.s M4VRFooterChain
        tst.w M4_LEVEL_HUD
        beq.s M4VRFooterMaskLink
M4VRFooterChain:
        moveq #13,d0 ;title BG cell sprite / level HUD sprites follow
M4VRFooterMaskLink:
        ori.w #$0c00,d0 ;four tiles wide, one tile high
        move.w d0,VDP_DATA
        move.w #$e4ce,VDP_DATA ;palette3, high priority, four black patterns
        move.w d7,d0
        lsl.w #5,d0
        addi.w #128,d0
        move.w d0,VDP_DATA
        addq.w #1,d7
        cmpi.w #8,d7
        bne.s M4VRFooterMaskSprite
        tst.w M4_TITLE_SPRITE
        beq.s M4VRSatDone
        ; Title BG cell (6,4): BG3/BG2 front part as one high-priority 8x8
        ; sprite (extract-title-background.py); link0 ends the list.
        lea M4TitleSprite,a0
        move.l (a0)+,VDP_DATA
        move.l (a0),VDP_DATA
M4VRSatDone:
        move.w (sp)+,sr
        movem.l (sp)+,d0-d7/a0
        rts

; Work-in-progress intro: Nintendo Presents, first ships and original boss.
; Explicit entry at script $78ae, after the original background/player reset.
; Boss/FASTdebris/zacointro; next unimplemented event is zaco2intro296.
; Boot wipe, later effects and transition to title remain separate consumers.
; No replacement movement or guessed 65-unit camera clock.
INTRO_DIAG equ $ff8240
INTRO_CAMERA equ $ff82c0
INTRO_CAPTURE equ $ff8260

M4IntroStart:
        clr.l M4_GEO_VP ;levels and intro project around the GSU 112/96 centre
        clr.w M4VR_LATE
        bsr M4IntroZacoTest
        tst.w d0
        bne M4IntroFailed
        bsr M4IntroDebrisVectorTest
        tst.w d0
        bne M4IntroFailed
        bsr M4IntroLaterTest
        tst.w d0
        bne M4IntroFailed
        bsr M4TextProjectTest
        cmpi.w #1,$ff4494
        bne M4IntroFailed
        bsr M4IntroCameraTest
        cmpi.w #1,$ff4484
        bne M4IntroFailed
        bsr M4IntroShipTest
        cmpi.w #1,$ff44a4
        bne M4IntroFailed
        bsr M4IntroMatrixTest
        cmpi.w #1,$ff44c4
        bne M4IntroFailed
        bsr M4IntroFireTest
        cmpi.w #1,$ff4524
        bne M4IntroFailed
        bsr M4IntroWeaponTest
        cmpi.w #1,$ff4534
        bne M4IntroFailed
        bsr M4IntroEffectsTest
        cmpi.w #1,$ff4544
        bne M4IntroFailed
        bsr M4TextVideoInit
        bsr M4IntroPolyTest
        cmpi.w #1,$ff44d4
        bne M4IntroFailed
        move.w #$8104,VDP_CTRL
        bsr M4IntroBackdrop
        move.l #'M4IN',INTRO_DIAG
        clr.l INTRO_DIAG+4
        clr.w INTRO_CAPTURE
        lea INTRO_CAMERA,a0
        moveq #0,d0
        moveq #4,d1
M4IntroClearCamera:
        move.l d0,(a0)+
        dbra d1,M4IntroClearCamera
        ; Background replaces playercred after the first zero-angle update.
        ; Reconstruct its retained cache with the original vector routine.
        lea INTRO_CAMERA,a0
        bsr M4IntroCameraReset
        bsr M4IntroCameraPlayer
        bsr M4IntroCameraBeginTick
        bsr M4IntroCameraReset
        bsr M4IntroCameraPlayer
        bsr M4IntroCameraFinish
        moveq #1,d7
M4IntroBeforeText:
        bsr M4IntroCameraBeginTick
        bsr M4IntroCameraPlayer
        bsr M4IntroCameraFinish
        dbra d7,M4IntroBeforeText
        bsr M4TextObjectsInit
        tst.w d0
        bne M4IntroFailed
        cmpi.w #2,TEXT_OBJECT_COUNT
        bne M4IntroFailed
        lea TEXT_OBJECTS,a0
        lea INTRO_TRAILS,a1
        move.w #INTRO_TRAIL_SLOTS,d1
        bsr M4IntroTrailsInit
        bsr M4IntroSceneInit
        bsr M4IntroBossGeometryTest
        tst.w d0
        bne M4IntroFailed
        bsr M4IntroParticleTest
        tst.w d0
        bne M4IntroFailed
        bsr M4IntroParticlesReset
        tst.w d0
        bne M4IntroFailed
        bsr M4IntroTimingInit
        move.w #4,INTRO_DIAG+6 ; original logical frame at this entry point
        move.w #$8c00,VDP_CTRL ;H32, 256px, matching VR gameplay
        move.w #$8174,VDP_CTRL
        move.w #$8014,VDP_CTRL
        bsr M4VRCaptureCram
        lea M4_FADE,a0
        clr.l (a0)
        move.l #$0f0f0f00,4(a0)
        move.b #15,1(a0)
        clr.b M4_EXIT_INTRO
        clr.w M4_EXITING
        move.w #$2300,sr
M4IntroLoop:
        if def(M4_DMA_STRESS)
        bra M4BlockStressLoop
        endif
        clr.l M4_PHASE_WORK
        clr.l M4_PHASE_WORK+4
        clr.w M4_PHASE_WORK+8
        move.w M4_CLOCK,M4_PHASE_STAMP
        bsr M4IntroRandom ; native init_strats final call once per game tick
        lea INTRO_CAMERA,a0
        bsr M4IntroCameraBeginTick
        move.w INTRO_DIAG+6,d0
        addq.w #1,d0
        move.w d0,M4_SCENE_TICK
        bsr M4IntroSceneMap
        cmpi.w #1,d0
        beq M4IntroPending
        tst.w d0
        bne M4IntroFailed
        bsr M4IntroSceneShips
        cmpi.w #1,d0
        beq M4IntroPending
        tst.w d0
        bne M4IntroFailed
        move.w INTRO_CAMERA+6,d1 ; original pviewvelZ, not map delta
        move.w INTRO_CAMERA+8,d0 ; previous camera during object strategies
        lea TEXT_OBJECTS+32,a0 ; original insert-first order: Presents first
        jsr M4TextPathTick
        tst.w d0
        bne M4IntroFailed
        bsr M4IntroNativeParent
        lea INTRO_TRAILS,a1
        move.w INTRO_CAMERA+6,d0
        move.w #INTRO_TRAIL_SLOTS,d1
        bsr M4IntroTrailsStep
        tst.w d0
        bne M4IntroFailed
        move.w INTRO_CAMERA+6,d1
        move.w INTRO_CAMERA+8,d0
        lea TEXT_OBJECTS,a0
        jsr M4TextPathTick
        tst.w d0
        bne M4IntroFailed
        bsr M4IntroNativeParent
        lea INTRO_TRAILS,a1
        move.w INTRO_CAMERA+6,d0
        move.w #INTRO_TRAIL_SLOTS,d1
        bsr M4IntroTrailsStep
        tst.w d0
        bne M4IntroFailed
        lea INTRO_CAMERA,a0
        bsr M4IntroCameraPlayer
        tst.w d0
        bne M4IntroFailed
        bsr M4IntroCameraFinish
        bsr M4IntroWeaponsDiscardFlashes
        tst.w d0
        bne M4IntroFailed
        bsr M4IntroFlashesZRemove ;showview, new camera; observed flash then zaco2
        bsr M4IntroZacosZRemove
        bsr M4IntroTextList
        tst.w d0
        bne M4IntroFailed
        lea TEXT_DESC,a1
        lea INTRO_DRAW_LIST,a4
        move.w INTRO_DRAW_COUNT,d7
        beq.s M4IntroProjectDone
        subq.w #1,d7
M4IntroProjectNext:
        movea.l (a4)+,a0
        move.w (a4)+,d0
        bsr M4TextProject
        tst.w d0
        bne M4IntroFailed
        move.w #SVP_TextNintendo/2,8(a1)
        cmpi.w #$c8e3,18(a0)
        beq.s M4IntroProjected
        cmpi.w #$c8f6,18(a0)
        bne M4IntroFailed
        move.w #SVP_TextPresents/2,8(a1)
M4IntroProjected:
        move.w #8,10(a1)
        lea 14(a1),a1
        dbra d7,M4IntroProjectNext
M4IntroProjectDone:
        tst.w M4_NATIVE_ERROR
        bne M4IntroFailed
        bsr M4IntroSceneDraw
        tst.w d0
        bne M4IntroFailed
        moveq #0,d1
        bsr M4IntroPhaseEnd
        move.w INTRO_DRAW_COUNT,d0
        jsr M4TextVideoDraw
        tst.w d0
        bne M4IntroFailed
        addq.w #1,INTRO_DIAG+6
        move.w #1,INTRO_DIAG+4
        bsr M4IntroTimingPublish
        bsr M4IntroExitStep
        bne M4IntroTitle
M4IntroCapture:
        cmpi.w #2,INTRO_CAPTURE ;one logical tick credit, capture tooling only
        bne.s M4IntroCaptureWait
        move.w #1,INTRO_CAPTURE ;consume before starting the next producer job
        bra M4IntroLoop
M4IntroCaptureWait:
        tst.w INTRO_CAPTURE
        bne.s M4IntroCapture
        bra M4IntroLoop
; Selected ROM intro_l (1F:F5D0, ENDSEQ.ASM .lp3/.finishlp): after a game
; frame, gameframe BYTE>=30 and exitintro start fadedir-2/fade11; frames keep
; running and M4FadeStep (01:0C12) runs once per frame until fadedir is 0.
; Returns Z clear when the fade has finished (title follows). Pads ignored.
M4_FADE equ $ff9c90 ;mode,timer,gameframe.w,INIDISP x3,spare
M4_EXITING equ $ff9c98
M4IntroExitStep:
        tst.w M4_EXITING
        bne.s M4ExitFading
        cmpi.b #M4_INTRO_MIN_FRAME,INTRO_DIAG+7
        blo.s M4ExitContinue
        tst.b M4_EXIT_INTRO
        beq.s M4ExitContinue
        move.b #M4IntroExitFadeMode,M4_FADE
        move.b #M4IntroExitFadeTicks,M4_FADE+1
        move.w #1,M4_EXITING
M4ExitContinue:
        moveq #0,d0
        rts
M4ExitFading:
        lea M4_FADE,a0
        move.w INTRO_DIAG+6,2(a0)
        jsr M4FadeStep
        moveq #0,d0
        move.b M4_FADE+4,d0
        bpl.s M4ExitBright
        moveq #0,d0 ;forced blank
M4ExitBright:
        andi.b #15,d0
        move.b d0,M4_BRIGHT
        tst.b M4_FADE
        bne.s M4ExitContinue
        moveq #1,d0
        rts

M4IntroPending:
        bsr M4PipeFlush ;publish the last overlapped tick before stopping
        bne M4IntroFailed
        move.w #3,INTRO_DIAG+4 ; original next event awaits a real consumer
M4IntroStop:
        bsr M4IntroFpsUpdate
        bra.s M4IntroStop
M4IntroFailed:
        if def(M4_GRAPHICS117)
        jmp G117FatalContext
        dc.w (INTRO_DIAG+4)&$ffff ;unreachable tail of the displaced move
        else
        move.w #$ffff,INTRO_DIAG+4
        endif
        bra.s M4IntroStop

; Original bg_intro_1 sets bg2Yscroll24 at ROM physical1A92D.
; Full64x64 original map, unchanged pixels/attributes; +32px X centres the
; 256px field on the H40 output. Palette2 reserved for original text ramp.
M4IntroBackdrop:
        move.w #M4_DMA_BG,d0
        jsr M4TextVideoWriteAddress
        lea BG_OUTPUT,a0
        move.w #1279,d1
M4IntroBackdropTiles:
        move.w (a0)+,VDP_DATA
        dbra d1,M4IntroBackdropTiles
        move.l #$60000003,VDP_CTRL
        moveq #0,d6
M4IntroBackdropRow:
        moveq #0,d7
M4IntroBackdropCell:
        move.w d7,d3
        ; H32 uses the original source column directly
        andi.w #63,d3
        move.w d6,d0
        andi.w #32,d0
        lsl.w #6,d0
        move.w d6,d1
        andi.w #31,d1
        lsl.w #5,d1
        add.w d1,d0
        move.w d3,d1
        andi.w #32,d1
        lsl.w #5,d1
        add.w d1,d0
        move.w d3,d1
        andi.w #31,d1
        add.w d1,d0
        add.w d0,d0
        lea BG_MAP,a0
        move.w (a0,d0.w),d0
        rol.w #8,d0
        move.w d0,d1
        andi.w #1023,d1
        addi.w #M4_DMA_BG/32,d1
        move.w d0,d2
        andi.w #$1c00,d2
        beq.s M4IntroBackdropPalette
        ori.w #$2000,d1
M4IntroBackdropPalette:
        btst #14,d0
        beq.s M4IntroBackdropVFlip
        ori.w #$800,d1
M4IntroBackdropVFlip:
        btst #15,d0
        beq.s M4IntroBackdropPriority
        ori.w #$1000,d1
M4IntroBackdropPriority:
M4IntroBackdropWrite:
        move.w d1,VDP_DATA
        addq.w #1,d7
        cmpi.w #32,d7
        bne M4IntroBackdropCell
        addq.w #1,d6
        cmpi.w #64,d6
        bne M4IntroBackdropRow
        move.l #$40000000,VDP_CTRL
        move.l #0,VDP_DATA
        move.l #$40000010,VDP_CTRL
        move.w #$d1,VDP_DATA
        move.w #24,VDP_DATA
        move.l #$c0400000,VDP_CTRL
        lea M4IntroTextPalette,a0
        moveq #15,d1
M4IntroPalette:
        move.w (a0)+,VDP_DATA
        dbra d1,M4IntroPalette
        rts

M4IntroTextPalette:
        incbin '../build/intro-scene-palette.md.bin'
        even

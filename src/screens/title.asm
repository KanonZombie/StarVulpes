; Title screen after intro_l (ENDSEQ titleredo, selected ROM 1F:F4C8..F5A0).
; Map title 0D:79F2. The commands before the mapwait at 7A16 run during the
; original title init (probe evidence/starfox-original-title-start.json shows
; pointer 7A18, counter800, Z/pview/lastplayz0 and fadedir FE at init):
; 50 quick fade down (already black), 4C, 10/64/66 setbg title + initbg
; (our upload of build/title-bg-*), 78 reset_z, 7A initblack_l, 5C stayblack10.
; stayblack/initblack act while INIDISP is still $80: no visible effect here.
; Per tick: map tick, playercred initializer at tick1 (as at the intro start),
; my_demo (76 at 7A18 -> tit_istrat 1F:F600), player, draw, fade step.
; Loop 1F:F4FF: countdown per frame; Start gated by the frame threshold.
M4_TITLE_DEMO equ $ffd800  ;32-byte context, ship layout; kind19 -> mesh17
M4_TITLE_TIMER equ $ffd820 ;original loop counter
M4_TITLE_SPRITE equ $ffd822 ;1: SAT chains the mixed BG cell sprite
M4_TITLE_EXIT equ $ffd824  ;0 running, 1 Start fade-out, 2 timeout fade-out
M4_TITLE_DIAG equ $ffd830  ;'M4TI', phase.w, gameframe.w, timer.w, demo.w
M4_TITLE_TILES_A equ $9a40 ;302 tiles after VR mask tiles 4CE..4D1
M4_TITLE_TILES_B equ $f420 ;10 tiles in the intro BG slot (plane B replaced)

M4IntroTitle:
        bsr M4PipeFlush ;publish the last faded intro image
        bne M4IntroFailed
        move.w M4_SCENE_TICK,d0
        bsr M4VRWaitPresented ;READY consumed: VRAM/CRAM shadow are free
        bne M4IntroFailed
        bsr M4TitleInit
        move.w #4,INTRO_DIAG+4 ;title phase
M4TitleLoop:
        lea INTRO_CAMERA,a0
        bsr M4IntroCameraBeginTick
        move.w INTRO_DIAG+6,d0
        addq.w #1,d0
        move.w d0,M4_SCENE_TICK
        bsr M4TitleMap
        tst.w d0
        bne M4TitleFailed
        cmpi.w #2,M4_SCENE_TICK
        bne.s M4TitleNoReset
        ; Second title frame: original playercred initializer resets the
        ; camera like the intro start and clears lastplayz (probe: counter
        ; 737 with lastz0, world63, pview64, pvel64 after this frame).
        lea INTRO_CAMERA,a0
        bsr M4IntroCameraReset
        clr.w TEXT_MAP_CONTEXT+4
M4TitleNoReset:
        bsr M4TitleDemoTick
        lea INTRO_CAMERA,a0
        bsr M4IntroCameraPlayer
        tst.w d0
        bne M4TitleFailed
        bsr M4IntroCameraFinish
        bsr M4TitleDraw
        tst.w d0
        bne M4TitleFailed
        moveq #0,d1
        bsr M4IntroPhaseEnd
        moveq #0,d0 ;no text objects in the title
        jsr M4TextVideoDraw
        tst.w d0
        bne M4TitleFailed
        addq.w #1,INTRO_DIAG+6
        bsr M4IntroTimingPublish
        bsr M4TitleFrameEnd
        bne.s M4TitleDone
M4TitleCapture:
        cmpi.w #2,INTRO_CAPTURE ;one logical tick credit, capture tooling only
        bne.s M4TitleCaptureWait
        move.w #1,INTRO_CAPTURE
        bra M4TitleLoop
M4TitleCaptureWait:
        tst.w INTRO_CAPTURE
        bne.s M4TitleCapture
        bra M4TitleLoop
; Faded out. Start leads to the controls map (contmap); the timeout runs
; intro_l again and then titleredo (1F:F503..F528): the port restarts its
; intro entry with a fresh stack, as after the boot.
M4TitleDone:
        bsr M4PipeFlush
        bne M4TitleFailed
        cmpi.w #1,M4_TITLE_EXIT
        bne.s M4TitleIdleOut
        jmp M4ControlsStart ;Start: briefing_l controls screen (controls.asm)
M4TitleIdleOut:
        move.w #$2700,sr
        lea $ffff00,sp
        jmp M4IntroStart
M4TitleFailed:
        move.w #$ffff,M4_TITLE_DIAG+4
        bra M4IntroFailed

M4TitleInit:
        jsr M4SoundStopLoops
        jsr M4VRSceneBegin
        move.l #'M4TI',M4_TITLE_DIAG
        move.w #1,M4_TITLE_DIAG+4
        clr.l M4_TITLE_DIAG+6
        clr.w M4_TITLE_DIAG+10
        lea M4_TITLE_DEMO,a0
        moveq #7,d0
M4TitleClearDemo:
        clr.l (a0)+
        dbra d0,M4TitleClearDemo
        move.w #M4TitleLoopTicks,M4_TITLE_TIMER
        clr.w M4_TITLE_EXIT
        move.b #$40,$a10009 ;port1 TH output for the three-button read
        move.b #$40,$a10003
        ; BG title: VRAM uploads with IRQ4 masked; pipeline is idle.
        move.w sr,-(sp)
        ori.w #$0700,sr
        move.w #M4_TITLE_TILES_A,d0
        jsr M4TextVideoWriteAddress
        lea M4TitleTiles,a0
        move.w #302*8-1,d1
M4TitleTilesA:
        move.l (a0)+,VDP_DATA
        dbra d1,M4TitleTilesA
        move.w #M4_TITLE_TILES_B,d0
        jsr M4TextVideoWriteAddress
        move.w #10*8-1,d1
M4TitleTilesB:
        move.l (a0)+,VDP_DATA
        dbra d1,M4TitleTilesB
        ; Original title: BG3/BG2 priority-1 cells lie IN FRONT of the GSU
        ; layer. The bitmap entries of plane A drop to low priority; window
        ; and margin tiles stay high. Same tiles, same DMA.
        move.w #$c000,d0
        jsr M4TextVideoWriteAddress
        lea M4VRPlaneAMap,a0
        move.w #2047,d1
M4TitlePlaneA:
        move.w (a0)+,d0
        cmpi.w #$e000|M4VR_MASK_TILE,d0
        beq.s M4TitlePlaneAWrite
        andi.w #$7fff,d0
M4TitlePlaneAWrite:
        move.w d0,VDP_DATA
        dbra d1,M4TitlePlaneA
        move.w #$8731,VDP_CTRL ;backdrop palette3 colour1, reserved black
        move.w #$e000,d0
        jsr M4TextVideoWriteAddress
        lea M4TitlePlaneB,a0
        move.w #1023,d1
M4TitlePlane:
        move.l (a0)+,VDP_DATA
        dbra d1,M4TitlePlane
        move.w (sp)+,sr
        ; Palette source: cpusp rows (lines0/1/3) and row7=03:8ACA (line2,
        ; same GSU palette as the intro). Faded per image by M4VRFadePalette.
        lea M4TitleCram,a0
        lea M4_BASE_CRAM,a1
        moveq #63,d1
M4TitleCramCopy:
        move.w (a0)+,(a1)+
        dbra d1,M4TitleCramCopy
        lea M4IntroTextPalette,a0
        lea M4_BASE_CRAM+64,a1
        moveq #15,d1
M4TitleCramScene:
        move.w (a0)+,(a1)+
        dbra d1,M4TitleCramScene
        ; Object state: no intro actor survives initgame_l.
        bsr M4IntroSceneInit
        move.w #2,M4_BOSS_SCROLL ;BG2 VOFS257 -> plane B row2 (extractor)
        move.w #2,M4_BOSS_SCROLL_PRESENT
        move.w #1,M4_TITLE_SPRITE
        ; reset_z: lastplayz, pviewposz and player worldZ are zero. pviewvel
        ; is 64 after the init (probe); the initgame camera values remain.
        lea INTRO_CAMERA,a0
        clr.w (a0)
        clr.w 2(a0)
        clr.w 4(a0)
        move.w #64,6(a0)
        lea TEXT_MAP_CONTEXT,a0
        move.w #$7a18,(a0) ;after 8A32 at 7A16: counter800
        move.w #800,2(a0)
        clr.l 4(a0)
        clr.w 8(a0)
        clr.w 26(a0)
        move.b #13,19(a0)
        lea M4_FADE,a0
        move.b #$fe,(a0) ;script 50 quick down, completes on the first step
        clr.b 1(a0)
        move.l #$80808000,4(a0)
        clr.w INTRO_DIAG+6 ;stz gameframe
        rts

; Map tick with the original fade variables (fadedir/fade/INIDISP live in
; M4_FADE; the map context mirrors them). Consumers: 76 my_demo, 78 at 7A1F.
M4TitleMap:
        lea TEXT_MAP_CONTEXT,a0
        move.b M4_FADE,16(a0)
        move.b M4_FADE+1,17(a0)
        move.b M4_FADE+4,18(a0)
        move.w INTRO_CAMERA+2,d0
        jsr M4ScriptTick
M4TitleEvent:
        lea TEXT_MAP_CONTEXT,a0
        move.b 16(a0),M4_FADE ;4E setfadeup quick writes fadedir2
        cmpi.w #1,d0
        bne M4TitleMapReturn
        cmpi.w #$7a18,(a0)
        beq.s M4TitleCreateDemo
        cmpi.w #$7a1f,(a0)
        bne M4TitleMapBad
        cmpi.w #$78,20(a0)
        bne M4TitleMapBad
        ; Embedded block clears pfm_wobble and sets psf_noctrl/nofire. The
        ; title player has no wobble/fire consumer here: no port state.
        jsr M4ScriptCommit
        bra M4TitleEvent
M4TitleCreateDemo:
        ; Demo event at 0D:FA18 (handler 03:F560): wait, relative position
        ; and quick-object ID for my_demo/tit_istrat.
        cmpi.w #$76,20(a0)
        bne M4TitleMapBad
        lea M4TitleDemoCommand,a2 ;script bytes may be odd-aligned
        moveq #5,d1
M4TitleDemoBytes:
        move.b (a1,d1.w),d2
        cmp.b (a2,d1.w),d2
        bne M4TitleMapBad
        dbra d1,M4TitleDemoBytes
        tst.w M4_TITLE_DEMO+22
        bne M4TitleMapBad
        clr.w 2(a0)
        lea M4_TITLE_DEMO,a2
        move.w #M4TitleDemoX,(a2)
        move.w #M4TitleDemoY,2(a2)
        move.w INTRO_CAMERA+2,d1
        addi.w #M4TitleDemoZ,d1
        move.w d1,4(a2)
        move.b #19,21(a2)
        move.w #1,22(a2)
        move.w M4_SCENE_TICK,26(a2)
        move.w #1,M4_TITLE_DIAG+10
        jsr M4ScriptCommit
        bra M4TitleEvent
M4TitleMapReturn:
        tst.w d0
        bmi.s M4TitleMapBad
        moveq #0,d0
        rts
M4TitleMapBad:
        moveq #-1,d0
        rts

; tit_istrat 1F:F600: set initial rotation, then tit_strat in the same
; frame; tit_strat 1F:F619: rotz+=2, Z += pviewvelZ (1F:DC69).
M4TitleDemoTick:
        lea M4_TITLE_DEMO,a0
        tst.w 22(a0)
        beq.s M4TitleDemoReturn
        move.w M4_SCENE_TICK,d0
        cmp.w 26(a0),d0
        bne.s M4TitleDemoStrat
        M4InitTitleRotation
M4TitleDemoStrat:
        addq.b #2,14(a0)
        move.w INTRO_CAMERA+6,d0
        add.w d0,4(a0)
M4TitleDemoReturn:
        rts

M4TitleDraw:
        clr.w M4P_EARLY
        clr.w M4_POLY_COUNT
        clr.w M4_MESH_ERROR
        clr.w M4_SHIP_DRAW_COUNT
        tst.w M4_TITLE_DEMO+22
        beq.s M4TitleDrawList
        lea M4_TITLE_DEMO,a0
        bsr M4IntroSceneSortObject
M4TitleDrawList:
        bra M4IntroSceneDrawSorted

; After each frame: NMI fade step, then 1F:F512..F528 counter/Start.
; Returns Z clear when a requested fade-out has finished.
M4TitleFrameEnd:
        lea M4_FADE,a0
        move.w INTRO_DIAG+6,2(a0)
        jsr M4FadeStep
        moveq #0,d0
        move.b M4_FADE+4,d0
        bpl.s M4TitleBright
        moveq #0,d0
M4TitleBright:
        andi.b #15,d0
        move.b d0,M4_BRIGHT
        move.w INTRO_DIAG+6,M4_TITLE_DIAG+6
        move.w M4_TITLE_TIMER,M4_TITLE_DIAG+8
        tst.w M4_TITLE_EXIT
        bne.s M4TitleFading
        subq.w #1,M4_TITLE_TIMER
        beq.s M4TitleTimeout
        cmpi.w #M4TitleStartGate,INTRO_DIAG+6
        blo.s M4TitleContinue
        bsr M4TitleStartPressed
        beq.s M4TitleContinue
        move.w #1,M4_TITLE_EXIT
        M4PlaySfx $10
        move.w #2,M4_TITLE_DIAG+4
        move.b #$fd,M4_FADE ;fadedir -3
        bra.s M4TitleContinue
M4TitleTimeout:
        move.w #2,M4_TITLE_EXIT
        move.w #2,M4_TITLE_DIAG+4
        move.b #$fd,M4_FADE
M4TitleContinue:
        moveq #0,d0
        rts
M4TitleFading:
        tst.b M4_FADE
        bne.s M4TitleContinue
        moveq #1,d0
        rts

; Three-button pad, port1: TH low, bit5 = Start (active low). Z clear if held.
M4TitleStartPressed:
        move.b #0,$a10003
        nop
        nop
        move.b $a10003,d0
        move.b #$40,$a10003
        not.b d0
        andi.w #$20,d0
        rts

        even
M4TitleDemoCommand:
        include '../build/m4-title-demo-command.inc'
M4TitleTiles:
        incbin '../build/title-bg-tiles.md.bin'
M4TitlePlaneB:
        incbin '../build/title-bg-planeb.md.bin'
M4TitleCram:
        incbin '../build/title-bg-cram.md.bin'
M4TitleSprite:
        incbin '../build/title-bg-sprites.md.bin'
        even

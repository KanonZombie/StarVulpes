; Controls screen briefing_l 1F:F9CD (build/research/game-start-and-player.md
; 1.2, screens-and-flow.md section 2). Runs on the level engine: initgame_l
; with the contmap script 0D:FA3C (playercred, fade down, setbg $FF cont,
; setbginfo -> newplayerstrat playeroncont 0B:B9B1, reset z, initblack,
; stayblack 3, fade up, endless waits), the GSU vanishing point (64, 48)
; (m_vanishx/y: offset -48/-48 from the 112/96 of the levels), m_meters 0.
; contcancel 1F:FAAB: free Arwing; Select cycles c_type (BG2 quadrant,
; set_c_type 1F:FE0A); Start with gameframe >= 16 -> conttraining 1F:FAF9:
; the TRAINING/GAME box (contsprites 1F:FC61), Select toggles contexit, up
; TRAINING, down GAME, X/Y back to contcancel, A/B/Start: fade out, then
; GAME -> the game (the route map is pending: Corneria 1) and TRAINING ->
; training (pending: back to this screen with TRAINING, as its own exit).
; Not modelled: the stars of the window (kcvpos particles), the smart bomb
; flash counter contsmart (1F:FDB6), sounds and music.

M4_SCREEN equ $fff836 ;.b 0 level, 1 controls screen
M4_CTL equ $fff840
M4_CTL_TYPE equ M4_CTL+0 ;.b c_type $1F11 (kept across games)
M4_CTL_EXIT equ M4_CTL+1 ;.b contexit
M4_CTL_DEFTRAIN equ M4_CTL+2 ;.b defaulttrain
M4_CTL_PHASE equ M4_CTL+3 ;.b 0 contcancel, 1 conttraining, 2 fade out
M4_CTL_SHOWN equ M4_CTL+4 ;.b c_type of the plane B map in VRAM
M4_CTL_VRAM equ $9a40 ;plane B tiles (tools/convert-screen-bg.py controls)
M4_CTL_OBJ_VRAM equ M4_CTL_VRAM+M4_SCR_CONTROLS_TILES*32

; From the title (Start). The options persist (c_type, contexit, defaulttrain).
M4ControlsStart:
        jsr M4SoundStopLoops
        move.b #1,M4_SCREEN
        jsr M4PipeFlush
        beq.s M4CtlOk1
        jmp M4IntroFailed
M4CtlOk1:
        move.w M4_SCENE_TICK,d0
        jsr M4VRWaitPresented
        beq.s M4CtlOk2
        jmp M4IntroFailed
M4CtlOk2:
        move.l #$ffd0ffd0,M4_GEO_VP ;m_vanishx 64, m_vanishy 48
        jsr M4LevelInit ;initgame_l (M4CtlVideoInit for M4_SCREEN 1)
        jsr M4PathGameInit
        jsr M4GameInit
        move.b #3,M4_LP_LIVES
        lea LV_PLAYER,a0
        move.l #M4ScPlayerCred,32(a0)
        bset #1,49(a0)
        ori.b #$60,M4_LP_PSF
        lea M4_FADE,a0
        clr.w (a0)
        move.l #$80808000,4(a0)
        move.b #8,M4_AR_GF2 ;initgame_strats 06:8004: gameflags2 = gf2_ingame
        jsr M4LevelObjectsTick
        clr.b M4_SC_MMETERS ;m_meters 0
        lea TEXT_MAP_CONTEXT,a0
        move.w #$7a3c,(a0) ;contmap 0D:FA3C
        clr.w 4(a0)
        move.l #M4ScriptProgramMap0D,28(a0)
        jsr M4LevelMapForce
        tst.w M4_LV_STATUS
        bpl.s M4CtlOk3
        jmp M4IntroFailed
M4CtlOk3:
        move.l #$3aa7557f,M4_RNG ;initgame_l 02:E2C6 -> 02:E394 -> 03:B819 random_l seed (after newobjs)
        clr.w M4_LV_GAMEFRAME
        clr.b M4_CTL_PHASE
        tst.b M4_CTL_DEFTRAIN
        bne.s M4CtlMenuFirst
        tst.b M4_CTL_EXIT
        beq.s M4CtlLoopStart
M4CtlMenuFirst:
        move.b #1,M4_CTL_PHASE
M4CtlLoopStart:
        move.w #6,INTRO_DIAG+4
M4CtlLoop:
        if def(M4_LOGIC_OVERLAP)
        bclr #0,M4_OVL_STATE ;tick and M4CtlMenu ran during the previous cmd10
        beq.s M4CtlTick
        tst.w M4_LV_STATUS
        bpl.s M4CtlTicked
        jmp M4IntroFailed
M4CtlTick:
        endif
        jsr M4LevelTick
        tst.w M4_LV_STATUS
        bpl.s M4CtlOk4
        jmp M4IntroFailed
M4CtlOk4:
        jsr M4CtlMenu ;contcancel / conttraining after their conttrans
M4CtlTicked:
        if def(M4_LOGIC_OVERLAP)
        move.b #2,M4_OVL_LOOP ;M4OvlWindow: M4CtlTail, then tick + M4CtlMenu of k+1
        endif
        jsr M4LevelDraw
        move.w d0,INTRO_DIAG+8
        tst.w d0
        beq.s M4CtlOk5
        jmp M4IntroFailed
M4CtlOk5:
        moveq #0,d1
        jsr M4IntroPhaseEnd
        moveq #0,d0
        jsr M4TextVideoDraw
        move.w d0,INTRO_DIAG+10
        tst.w d0
        beq.s M4CtlOk6
        jmp M4IntroFailed
M4CtlOk6:
        addq.w #1,INTRO_DIAG+6
        jsr M4IntroTimingPublish
        if def(M4_LOGIC_OVERLAP)
        bclr #2,M4_OVL_STATE ;M4CtlTail ran during cmd10: its decision
        beq.s M4CtlTailNow
        jsr M4OvlSatPublish ;its HUD buffer, at the serial point
        move.b M4_OVL_EXIT,d0
        bra.s M4CtlTailDone
M4CtlTailNow:
        endif
        bsr M4CtlTail
M4CtlTailDone:
        tst.b d0
        bne.s M4CtlExit
M4CtlCapture:
        if def(M4_LOGIC_OVERLAP)
        btst #0,M4_OVL_STATE ;the gate came up after the logic of k+1 ran: hold one
        bne M4CtlLoop ;image later, after a serial iteration (consistent state)
        endif
        cmpi.w #2,INTRO_CAPTURE
        bne.s M4CtlCaptureWait
        move.w #1,INTRO_CAPTURE
        bra M4CtlLoop
M4CtlCaptureWait:
        tst.w INTRO_CAPTURE
        bne.s M4CtlCapture
        bra M4CtlLoop
; Tail of the image after TextVideoDraw (also run by M4OvlWindow during cmd10):
; fade, box sprites, diagnostics; d0.b = 2 when faded out (leave), else 0.
M4CtlTail:
        jsr M4LevelFade
        jsr M4LevelHudSprites ;the box sprites in controls mode
        move.w M4_LV_GAMEFRAME,M4_LV_DIAG+4
        moveq #0,d0
        cmpi.b #3,M4_CTL_PHASE
        bne.s M4CtlTailRet
        moveq #2,d0
M4CtlTailRet:
        rts
; Faded out: GAME -> the game; TRAINING -> training (training.asm).
M4CtlExit:
        jsr M4PipeFlush
        beq.s M4CtlOk7
        jmp M4IntroFailed
M4CtlOk7:
        jsr M4VRSceneBegin
        moveq #0,d0
        bsr M4CtlPlaneA ;the 224-column window and margins of the 3D view again
        tst.b M4_CTL_EXIT
        beq.s M4CtlTraining
        clr.b M4_SCREEN
        clr.l M4_GEO_VP
        lea $ffff00,sp
        jmp M4GameStartNew ;initialise_l, initplanets_l, planetseq_l
M4CtlTraining: ;contexit 0 -> 1F:FBBE training
        lea $ffff00,sp
        jmp M4TrainingStart

; contcancel / conttraining logic of this tick (trig = new presses).
M4CtlMenu:
        movem.l d0-d2,-(sp)
        move.w M4_LP_JOY,d1
        move.w M4_LP_LASTJOY,d0
        not.w d0
        and.w d0,d1 ;trig0 (J_* bits)
        move.b M4_CTL_PHASE,d0
        bne.s M4CtlTrainingPhase
        andi.b #$1f,M4_LP_PSF ;s_playerctrl on
        btst #J_SELECT,d1
        beq.s M4CtlCancelStart
        addq.b #1,M4_CTL_TYPE ;sound $11
        M4PlaySfx $11
        andi.b #3,M4_CTL_TYPE
M4CtlCancelStart:
        cmpi.w #16,M4_LV_GAMEFRAME
        blo.w M4CtlMenuDone
        btst #J_START,d1
        beq.w M4CtlMenuDone
        move.b #1,M4_CTL_PHASE ;sound $10
        M4PlaySfx $10
        bra.w M4CtlMenuDone
M4CtlTrainingPhase:
        cmpi.b #1,d0
        bne M4CtlFading
        ori.b #$60,M4_LP_PSF ;no control, no fire
        btst #J_SELECT,d1
        beq.s M4CtlNoSelect
        eori.b #1,M4_CTL_EXIT
        M4PlaySfx $11
M4CtlNoSelect:
        tst.b M4_CTL_EXIT
        beq.s M4CtlNoUp
        btst #J_UP,d1
        beq.s M4CtlNoUp
        clr.b M4_CTL_EXIT
        M4PlaySfx $11
M4CtlNoUp:
        tst.b M4_CTL_EXIT
        bne.s M4CtlNoDown
        btst #J_DOWN,d1
        beq.s M4CtlNoDown
        move.b #1,M4_CTL_EXIT
        M4PlaySfx $11
M4CtlNoDown:
        move.w d1,d2
        andi.w #(1<<J_X)|(1<<J_Y),d2
        beq.s M4CtlNoBack
        clr.b M4_CTL_PHASE ;goto contcancel
        bra.s M4CtlMenuDone
M4CtlNoBack:
        andi.w #(1<<J_A)|(1<<J_B)|(1<<J_START),d1
        beq.s M4CtlMenuDone
        move.b #2,M4_CTL_PHASE ;startbgm $F1; fadedir $FF
        M4PlaySfx $10
        move.b #$ff,M4_FADE
        bra.s M4CtlMenuDone
M4CtlFading:
        tst.b M4_FADE ;until fadedir == 0
        bne.s M4CtlMenuDone
        move.b #1,M4_CTL_DEFTRAIN ;dogyirq 0; the next visit opens the menu
        move.b #3,M4_CTL_PHASE
M4CtlMenuDone:
        jsr M4CtlQuadrant
        movem.l (sp)+,d0-d2
        rts

; set_c_type 1F:FE0A: BG2 quadrant of c_type (A (0,0), B (256,0), C (0,256),
; D (256,256)) = the plane B map of that view, rewritten when it changes.
M4CtlQuadrant:
        move.b M4_CTL_TYPE,d0
        cmp.b M4_CTL_SHOWN,d0
        beq.s M4CtlQuadDone
        move.b d0,M4_CTL_SHOWN
M4CtlWriteMap:
        movem.l d0-d2/a0,-(sp)
        moveq #0,d0
        move.b M4_CTL_TYPE,d0
        lsl.w #2,d0
        lea M4CtlMaps,a0
        movea.l (a0,d0.w),a0
        move.w #$e000,d0 ;plane B 32 x 64 (the VR plane size): rows 0..31
        jsr M4BgUpload
        movem.l (sp)+,d0-d2/a0
M4CtlQuadDone:
        rts
M4CtlMaps:
        dc.l M4ScrControlsMap0,M4ScrControlsMap1,M4ScrControlsMap2,M4ScrControlsMap3

; Video of the screen (instead of M4LevelVideoInit): plane B diagram, its
; colours (lines 0, 1, 3) and the OBJ box tiles/colours (line 3), the level
; polygon palette on line 2 (GSU gamepal), no tilt, plane B scrolled 1 line
; (SNES BG row VOFS+1 on the first line).
M4CtlVideoInit:
        move.w #M4_CTL_VRAM,d0
        lea M4ScrControlsTiles,a0
        jsr M4BgUpload
        move.w #M4_CTL_OBJ_VRAM,d0
        lea M4CtlObjTiles,a0
        jsr M4BgUpload
        move.w sr,-(sp)
        ori.w #$0700,sr
        move.w #$e000,d0 ;clear plane B (32 x 64)
        jsr M4TextVideoWriteAddress
        move.w #1023,d1
M4CtlClearB:
        move.l #0,VDP_DATA
        dbra d1,M4CtlClearB
        move.w #$8731,VDP_CTRL
        move.w #$8b00,VDP_CTRL ;full-screen scroll (no tilt)
        move.w (sp)+,sr
        move.w #M4_SCR_CONTROLS_BLANK,d0
        bsr M4CtlPlaneA
        clr.w M4_LEVEL_TILT
        lea M4_BASE_CRAM,a1
        moveq #31,d1
M4CtlCramClear:
        clr.l (a1)+
        dbra d1,M4CtlCramClear
        lea M4ScrControlsCram,a0
        bsr.w M4CtlCram
        lea M4CtlObjColours,a0
        bsr.w M4CtlCram
        lea M4LevelScenePalette,a0
        lea M4_BASE_CRAM+64,a1
        moveq #15,d1
M4CtlScene:
        move.w (a0)+,(a1)+
        dbra d1,M4CtlScene
        clr.w M4_BASE_CRAM+98 ;line3 colour1 black (margin tiles)
        move.w #$eee,M4_BASE_CRAM+100
        clr.w M4_TITLE_SPRITE
        st M4_CTL_SHOWN
        bsr M4CtlQuadrant
        clr.l M4_LV_SATREADY
        move.w sr,-(sp)
        ori.w #$0700,sr
        move.w #$d800+13*8,d0
        jsr M4TextVideoWriteAddress
        move.l #0,VDP_DATA
        move.l #0,VDP_DATA
        move.w (sp)+,sr
        move.w #1,M4_LEVEL_HUD
        move.w #1,M4_BOSS_SCROLL
        move.w #1,M4_BOSS_SCROLL_PRESENT
        clr.w M4_BG_HSCROLL
        rts
; Plane A map (M4VRPlaneAMap). d0 != 0: the opaque margin cells (224-column
; window, rows outside the 192-line bitmap) become the transparent tile d0
; (each screen's own blank tile), as BG2 fills the whole 256 x 224 screen
; and the GSU layer only its window; d0 = 0: the map as the VR init wrote it.
M4CtlPlaneA:
        movem.l d0-d3/a0,-(sp)
        move.w d0,d3
        move.w sr,-(sp)
        ori.w #$0700,sr
        move.w #$c000,d0
        jsr M4TextVideoWriteAddress
        lea M4VRPlaneAMap,a0
        move.w #2047,d1
M4CtlPlaneACell:
        move.w (a0)+,d0
        tst.w d3
        beq.s M4CtlPlaneAWrite
        cmpi.w #$e000|M4VR_MASK_TILE,d0
        bne.s M4CtlPlaneAWrite
        move.w d3,d0 ;transparent, low priority
M4CtlPlaneAWrite:
        move.w d0,VDP_DATA
        dbra d1,M4CtlPlaneACell
        move.w (sp)+,sr
        movem.l (sp)+,d0-d3/a0
        rts
M4CtlCram: ;a0: (CRAM byte offset, colour) pairs, -1 ends
        move.w (a0)+,d0
        bmi.s M4CtlCramDone
        lea M4_BASE_CRAM,a1
        move.w (a0)+,(a1,d0.w)
        bra.s M4CtlCram
M4CtlCramDone:
        rts

; contsprites 1F:FC61 in conttraining: the box (6 MD sprites) after the
; texts; a1 = next SAT entry, d7 = its sprite number.
M4CtlSprites:
        cmpi.b #1,M4_CTL_PHASE
        blo.s M4CtlSprDone
        lea M4CtlBoxTrain,a0
        tst.b M4_CTL_EXIT
        beq.s M4CtlSprBox
        lea M4CtlBoxGame,a0
M4CtlSprBox:
        moveq #5,d1
M4CtlSprEntry:
        move.w (a0)+,(a1)+ ;y
        move.w (a0)+,d0 ;size
        addq.w #1,d7
        or.w d7,d0
        move.w d0,(a1)+
        move.l (a0)+,(a1)+ ;tile word, x
        dbra d1,M4CtlSprEntry
M4CtlSprDone:
        rts

; playeroncont_Istrat 0B:B9B1: control on, viewCY -50, x limits 0/0, y
; limits -50/-70, flymode 2, pmoveand 0, viewrot, notdie, pviewvelz 65.
M4CtlPlayerIstrat:
        andi.b #$1f,M4_LP_PSF
        move.w #-50,M4_LP_VIEWCY
        clr.w M4_LP_MINX
        clr.w M4_LP_MAXX
        move.w #-50,M4_LP_MINY
        move.w #-70,M4_LP_MAXY
        move.b #2,M4_LP_FLYMODE
        clr.b M4_LP_PMOVEAND
        ori.b #$20,M4_LP_GAMEFLAGS
        andi.b #$fb,M4_BOSS_PSTRATF
        ori.b #2,M4_LP_PSF3
        andi.b #$fb,M4_LP_PSF2
        andi.b #$d7,M4_BOSS_PSTRATF
        andi.b #$fe,M4_LP_PSF3
        ori.b #$20,M4_BOSS_PSTRATF ;notdie
        move.w #65,M4_LP_PVIEWVZ
        bclr #SF_INVISIBLE,49(a0)
        move.l #M4CtlPlayerTick,32(a0)
; playeroncont 0B:BA9D: playermove 0B:E884 (playermove_srou, gen_3dvecs,
; framescalevecs, add_vecs2pos, limitx, playerfire; no vy scaling),
; pviewpos = (x, y), viewmove, outvx = outvy = 0, outdist = viewdist = 200,
; shape my_demoS. conttrans keeps 3 nova bombs (1F:FDB6).
M4CtlPlayerTick:
        movem.l d0-d7/a1,-(sp)
        move.w #3,M4_LP_SPECWEP
        jsr M4LpMove
        moveq #0,d0
        move.b 15(a0),d0
        jsr M4LevelGen3dVecs
        jsr M4LpFrameScale
        jsr M4EnMove
        andi.b #$f3,M4_LP_ARROWS ;playerlimitx 0B:DF21
        move.w (a0),d0
        cmp.w M4_LP_MINX,d0
        bgt.s M4CtlLimitMax
        move.w M4_LP_MINX,(a0)
M4CtlLimitMax:
        move.w (a0),d0
        cmp.w M4_LP_MAXX,d0
        blt.s M4CtlLimitDone
        move.w M4_LP_MAXX,(a0)
M4CtlLimitDone:
        jsr M4LpFire
        move.w (a0),M4_LP_PVIEWX
        move.w 2(a0),M4_LP_PVIEWY
        jsr M4LpViewMove
        clr.w M4_LP_OUTVX
        clr.w M4_LP_OUTVY
        move.w #200,M4_LP_OUTDIST
        move.w #200,M4_LP_VIEWDIST
        move.l #M4_SH_MY_DEMOS,d0 ;descriptor index may exceed 127
        jsr M4LevelSetShape
        andi.b #$fd,M4_LP_PSF3
        movem.l (sp)+,d0-d7/a1
        jsr M4LevelFireBomb
        jsr M4LevelFireLasers
        moveq #0,d0
        rts

; contmap 0D:FA3C runs from the bank-0D map program (M4ScriptProgramMap0D).
        include '../build/packed-2d/screen-controls.inc'
        include '../build/packed-2d/screen-controls-obj.inc'

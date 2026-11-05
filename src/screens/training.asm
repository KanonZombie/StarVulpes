; Training mode (build/research/training.md): from the controls screen with
; TRAINING (conttraining 1F:FAF9, contexit 0) -> 1F:FBBE: initialise_l,
; mapbank $0D / mapptr $6E9A (trainingmap 0D:EE9A), initgame_l, lives = 1,
; gameframe = 0; own loop 1F:FBE2..FC14 (no pause): setblack_l, transfer_l,
; friends_messages_l; the first 20 ticks ignore everything; levelfinished
; 10 (death with lives 0) -> controls with TRAINING preselected (contexit 0,
; defaulttrain 1); Start (new press, not during the death sequence) ->
; fadedir $FF with the world running until fade 0 -> controls with GAME
; preselected (contexit 1, defaulttrain 1). No game over, no end of course.
; Background $111 (03:9235) = bg_1_1c of Corneria + playeronplanet, $14DD 0,
; $14DE 2 (M4ScTransSwap). Not modelled: music (03:AD7E, startbgm $F1).

M4_TR equ $fff860
M4_TR_PRTTRAIN equ M4_TR+0 ;.b $1FE0 prttraining (do_stage prints TRAINING)
M4_TR_FADING equ M4_TR+1 ;.b Start taken: fading out
M4_TR_ACTIVE equ M4_TR+2 ;.b training loop running
M4_TR_ENTRY equ $6e9a ;0D:EE9A trainingmap

M4TrainingStart:
        jsr M4PipeFlush
        beq.s M4TrOk1
        jmp M4IntroFailed
M4TrOk1:
        move.w M4_SCENE_TICK,d0
        jsr M4VRWaitPresented
        beq.s M4TrOk2
        jmp M4IntroFailed
M4TrOk2:
        clr.b M4_SCREEN
        clr.l M4_GEO_VP
        move.w #$6ee7,M4_LV_RESTART ;set_restart 0D:EED5 registers 0D:EEE7
        clr.l M4_LV_RSTACK
        clr.l M4_LV_RSTACK+4
        clr.l M4_LV_RSTACK+8
        clr.l M4_LV_RSTACK+12
        clr.w M4_LV_RSTACK+16
        jsr M4LevelInit
        jsr M4PathGameInit ;initialise_l 02:E260: friends_hp 40
        jsr M4GameInit
        move.b #3,M4_LP_LIVES
        ; initgame_l 02:E2C6: player from playercred, then the map up to its
        ; first wait (as M4LevelStart).
        lea LV_PLAYER,a0
        move.l #M4ScPlayerCred,32(a0)
        ; USA 0B:B541..B545: player_Istrat clears invisible after playercred.
        ; Training's planet strategy inherits this flag without changing it.
        bclr #1,49(a0)
        ori.b #$60,M4_LP_PSF
        move.w #-60,M4_LP_VIEWCY
        move.w #-240,M4_LP_MINX
        move.w #240,M4_LP_MAXX
        move.w #-190,M4_LP_MINY
        move.w #60,M4_LP_MAXY
        move.b #$02,M4_LP_FLYMODE
        clr.b M4_LP_PMOVEAND
        andi.b #$fb,M4_LP_PSF2
        andi.b #$fe,M4_LP_PSF3
        ori.b #2,M4_LP_PSF3
        lea M4_FADE,a0
        clr.w (a0)
        move.l #$80808000,4(a0)
        move.b #8,M4_AR_GF2 ;initgame_strats 06:8004: gameflags2 = gf2_ingame
        jsr M4LevelObjectsTick
        lea TEXT_MAP_CONTEXT,a0
        move.w #M4_TR_ENTRY,(a0)
        clr.w 4(a0)
        jsr M4LevelMapForce
        tst.w M4_LV_STATUS
        bpl.s M4TrOk3
        jmp M4IntroFailed
M4TrOk3:
        move.l #$3aa7557f,M4_RNG ;initgame_l 02:E2C6 -> 02:E394 -> 03:B819 random_l seed (after newobjs)
        move.b #1,M4_LP_LIVES ;1F:FBD5 lives = 1
        clr.w M4_LV_GAMEFRAME ;gameframe = 0 (16 bits)
        clr.b M4_TR_FADING
        move.b #1,M4_TR_ACTIVE
        move.w #6,INTRO_DIAG+4
M4TrLoop:
        if def(M4_LOGIC_OVERLAP)
        bclr #0,M4_OVL_STATE ;this tick ran during the previous cmd10
        bne.s M4TrTicked
        endif
        jsr M4LevelTick
M4TrTicked:
        tst.w M4_LV_STATUS
        bpl.s M4TrOk4
        jmp M4IntroFailed
M4TrOk4:
        if def(M4_LOGIC_OVERLAP)
        move.b #4,M4_OVL_LOOP ;M4OvlWindow: M4TrTail, then the tick of k+1
        endif
        jsr M4LevelDraw
        move.w d0,INTRO_DIAG+8
        tst.w d0
        beq.s M4TrOk5
        jmp M4IntroFailed
M4TrOk5:
        moveq #0,d1
        jsr M4IntroPhaseEnd
        moveq #0,d0
        jsr M4TextVideoDraw
        move.w d0,INTRO_DIAG+10
        tst.w d0
        beq.s M4TrOk6
        jmp M4IntroFailed
M4TrOk6:
        addq.w #1,INTRO_DIAG+6
        jsr M4IntroTimingPublish
        if def(M4_LOGIC_OVERLAP)
        bclr #2,M4_OVL_STATE ;M4TrTail ran during cmd10: its decision
        beq.s M4TrTailNow
        jsr M4OvlSatPublish ;its HUD buffer, at the serial point
        move.b M4_OVL_EXIT,d0
        bra.s M4TrTailDone
M4TrTailNow:
        endif
        bsr M4TrTail
M4TrTailDone:
        cmpi.b #3,d0
        bne.s M4TrNoRestart
        jmp M4LevelRestartTick
M4TrNoRestart:
        cmpi.b #2,d0
        bne.s M4TrNoGame
        moveq #1,d0 ;Start: GAME preselected
        bra M4TrExit
M4TrNoGame:
        cmpi.b #4,d0
        bne.s M4TrCapture
        moveq #0,d0 ;TRAINING preselected
        bra M4TrExit
M4TrCapture:
        if def(M4_LOGIC_OVERLAP)
        btst #0,M4_OVL_STATE ;the gate came up after the logic of k+1 ran: hold one
        bne M4TrLoop ;image later, after a serial iteration (consistent state)
        endif
        cmpi.w #2,INTRO_CAPTURE
        bne.s M4TrCaptureWait
        move.w #1,INTRO_CAPTURE
        bra M4TrLoop
M4TrCaptureWait:
        tst.w INTRO_CAPTURE
        bne.s M4TrCapture
        bra M4TrLoop
; Tail of the image after TextVideoDraw (also run by M4OvlWindow during cmd10):
; fade, HUD, diagnostics and the rules of 1F:FBF0..FC1E. d0.b = 0 go on, 2 leave
; with GAME preselected, 3 restart_l, 4 leave with TRAINING preselected.
M4TrTail:
        jsr M4LevelFade
        jsr M4LevelHudSprites
        move.w M4_LV_GAMEFRAME,M4_LV_DIAG+4
        move.w M4_LV_COUNT,M4_LV_DIAG+6
        move.w M4_LV_SKIPPED,M4_LV_DIAG+8
        moveq #3,d0
        cmpi.w #4,M4_LV_STATUS ;restart_l (unreachable with 1 life)
        beq.s M4TrTailRet
        moveq #0,d0
        tst.b M4_TR_FADING
        beq.s M4TrRules
        tst.b M4_FADE+1 ;1F:FC1E: until fadedir == 0 (faded out)
        bne.s M4TrTailRet
        moveq #2,d0 ;Start: GAME preselected
        rts
M4TrRules:
        cmpi.w #20,M4_LV_GAMEFRAME ;1F:FBF0: the first 20 ticks ignore all
        blo.s M4TrTailRet
        cmpi.w #5,M4_LV_STATUS ;levelfinished 10: dead with lives 0
        bne.s M4TrAlive
        moveq #4,d0 ;TRAINING preselected
        rts
M4TrAlive:
        ; death sequence in progress (gameflags $14D3 & 8 and pshipflags2
        ; $80; the port's PLAYERDYING flag stands for $14D3 & 8 [H]): Start
        ; ignored
        btst #1,M4_LP_GAMEFLAGS
        beq.s M4TrStart
        btst #7,M4_LP_PSF2
        bne.s M4TrTailRet
M4TrStart:
        move.w M4_LP_JOY,d1 ;trig0h $120A & $10: new Start press
        move.w M4_LP_LASTJOY,d2
        not.w d2
        and.w d2,d1
        btst #J_START,d1
        beq.s M4TrTailRet
        st M4_TR_FADING ;startbgm $F1 (not modelled), fadedir $FF
        move.b #$ff,M4_FADE
M4TrTailRet:
        rts
; 1F:FC3B / 1F:FC47: initialise_l, contexit = d0, defaulttrain = 1, then
; levelfinished = 0 and briefing_l.
M4TrExit:
        move.b d0,M4_CTL_EXIT
        move.b #1,M4_CTL_DEFTRAIN
        clr.b M4_TR_ACTIVE
        jsr M4PipeFlush
        beq.s M4TrOk7
        jmp M4IntroFailed
M4TrOk7:
        lea $ffff00,sp
        jmp M4ControlsStart

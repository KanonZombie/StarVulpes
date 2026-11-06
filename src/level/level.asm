; Corneria 1 level play (first stage). Entry after the title Start fade.
; Reductions (documented in src/m4/LEVEL_ORIGIN.md): the controls screen and
; route map are not ported (their default options are the minimum path). The
; first pass starts at the level entry 0D:D068 (initgame_l 02:E2C6: SCRAMBLE
; and ExitBase, level_scramble.asm); a restart after a death resumes at the
; checkpoint (0D:D209, restart_l 09:9914).
; Order per tick (transfer_l 02:D950): input, gameframe++, init_strats
; (player_posz), map script 03:ED42, strategies (player first), getview,
; showview/zremove, calcmeters 02:DD04, draw and presentation.
M4_LV equ $fff200
M4_LV_GAMEFRAME equ M4_LV+0 ;.w $15BD
M4_LV_LASTCLOCK equ M4_LV+2 ;.w M4_CLOCK at the previous tick
M4_LV_STATUS equ M4_LV+4 ;.w 1 running, $FFFF failed, 2 unsupported event
M4_LV_STACK equ M4_LV+6 ;.w map call stack depth
M4_LV_CALLS equ M4_LV+8 ;8 WORD return indices (mapjsr)
M4_LV_LOOPS equ M4_LV+24 ;8 WORD loop counters indexed by call depth
M4_LV_BADOP equ M4_LV+40 ;.w last unsupported opcode/kind
M4_LV_BADINDEX equ M4_LV+42 ;.w its script index
M4_LV_SPECIALS equ M4_LV+44 ;.w $173E specialobjtotal
M4_LV_SPECIALDEAD equ M4_LV+46 ;.w $14DB specials_dead
M4_LV_RESTART equ M4_LV+58 ;.w checkpoint index (set_restart 09:98CB)
; Map indices saved by mapjsr and set_restart carry the bank in bit 15
; (0 = 0D, 1 = 05; indices are CPU address & $7FFF): M4LvPackIndex.
M4_LEVEL_SCRIPT_ENTRY equ $5068 ;0D:D068 level1_1
M4_LV_FLASHCODE equ M4_LV+56 ;.b screen flash code <<4 of this tick
M4_LV_RSTACK equ M4_LV+60 ;.w + 8 WORDs: saved map call stack
M4_LV_DIAG equ M4_LV+48 ;'M4LV' frame.w objects.w skipped.w

M4LevelStart:
        jsr M4PipeFlush
        bne M4IntroFailed
        move.w M4_SCENE_TICK,d0
        jsr M4VRWaitPresented
        bne M4IntroFailed
        move.w M4_GS_NEWMAP,d0 ;gamestart 02:E3BF: map of setlevel (planetseq)
        andi.w #$7fff,d0
        move.w d0,M4_LV_RESTART ;until the map's set_restart (0D:D1F7 in Corneria 1)
        clr.l M4_LV_RSTACK
        clr.l M4_LV_RSTACK+4
        clr.l M4_LV_RSTACK+8
        clr.l M4_LV_RSTACK+12
        clr.w M4_LV_RSTACK+16
        move.w M4_GS_NEWMAP,-(sp) ;map index of setlevel
        clr.w -(sp) ;no saved map call stack
        move.b M4_GS_NEWBANK,-(sp)
M4LvStartInit: ;(sp).b bank, 2(sp).w saved call stack flag [+18 bytes], index
        jsr M4LevelInit
        jsr M4MusicLevel
        clr.b M4_SCREEN
        clr.l M4_GEO_VP
        ; initialise_l 02:E265 (friends_hp 40, credits, stage, totals) runs
        ; once at game start (M4GameStartNew), not per level
        clr.l M4_TX_HOOK
        move.b M4_GS_LIVES,M4_LP_LIVES ;lives $16EE (initplanets_l 03:BD9E: 3)
        if ~def(M4_LEVEL_BOSS_TEST)
        ; initgame_l 02:E2C6: player from playercred (0,0,0), invisible, then
        ; the level script from 0D:D068 up to its first wait (newobjs_l).
        lea LV_PLAYER,a0
        move.l #M4ScPlayerCred,32(a0)
        bset #1,49(a0)
        ori.b #$60,M4_LP_PSF ;playercred_Istrat 0B:B566: no control
        move.w #-60,M4_LP_VIEWCY ;and its limits (0B:B5F6..B65F): the
        move.w #-240,M4_LP_MINX ;player keeps y = 0 (probe), the
        move.w #240,M4_LP_MAXX ;viewopening camera starts from it
        move.w #-190,M4_LP_MINY
        move.w #60,M4_LP_MAXY
        move.b #$02,M4_LP_FLYMODE ;$12, then &= $EF (0B:B6A1)
        clr.b M4_LP_PMOVEAND
        andi.b #$fb,M4_LP_PSF2
        andi.b #$fe,M4_LP_PSF3
        ori.b #2,M4_LP_PSF3
        lea M4_FADE,a0 ;after the title fade: fade 0, INIDISP $80
        clr.w (a0)
        move.l #$80808000,4(a0)
        move.b #8,M4_AR_GF2 ;initgame_strats 06:8004: gameflags2 = gf2_ingame
        jsr M4LevelObjectsTick ;initgame_strats_l 06:8004: one strategy pass
        lea TEXT_MAP_CONTEXT,a0
        move.b (sp)+,19(a0)
        tst.w (sp)+
        beq.s M4LvStartNoStack
        move.w (sp)+,M4_LV_STACK ;levelfinished 7: the map call stack is kept
        movem.l (sp)+,d0-d3
        movem.l d0-d3,M4_LV_CALLS
M4LvStartNoStack:
        move.w (sp)+,d0
        andi.w #$7fff,d0
        move.w d0,(a0)
        clr.w 2(a0) ;mapcnt $16FD = 0 (02:E305)
        clr.w 4(a0) ;lastplayz $1701 = 0 (playercred_Istrat)
        clr.w 26(a0)
        jsr M4LevelMapForce
        tst.w M4_LV_STATUS
        bmi M4IntroFailed
        ; initgame_l 02:E2C6 ends with 02:E394 -> 03:B819 (initgame3d): random_l
        ; seed 3A A7 55 7F after the starter map, initgame_strats and this
        ; newobjs: their draws (and the 4 of M4IntroEffectsInit) do not count.
        move.l #$3aa7557f,M4_RNG
        else
        addq.l #6,sp
        endif
        move.w #6,INTRO_DIAG+4 ;level phase
M4LevelLoop:
        if def(M4_GRAPHICS117)
        jmp G117Probe            ; runs the displaced profile mark
        dc.l M4ProfMark          ; unreachable tail of the displaced jsr
        move.l (sp)+,d0          ; unreachable
        elseif def(M4_PROFILE)
        move.l d0,-(sp)
        moveq #8,d0
        jsr M4ProfMark
        move.l (sp)+,d0
        endif
M4LevelLoopResume:
        if def(M4_PROFILE)
        addq.w #1,M4_PROF_IMAGES
        endif
        if def(M4_LOGIC_OVERLAP)
        bclr #0,M4_OVL_STATE ;this tick already ran during the previous cmd10
        bne.s M4LvLoopTicked
        endif
        jsr M4LevelTick
M4LvLoopTicked:
        jsr M4ScTimingTween
        tst.w d0
        bne M4IntroFailed
        if def(M4_PROFILE)
        move.l d0,-(sp)
        moveq #0,d0
        jsr M4ProfMark
        move.l (sp)+,d0
        endif
        tst.w M4_LV_STATUS
        bmi M4IntroFailed
        if def(M4_LOGIC_OVERLAP)
        move.b #1,M4_OVL_LOOP ;M4OvlWindow: level tail (M4LvOvlTail)
        endif
        jsr M4LevelDraw
        move.w d0,INTRO_DIAG+8 ;failure code: draw result
        tst.w d0
        bne M4IntroFailed
        if def(M4_LOGIC_OVERLAP)
        bclr #2,M4_OVL_STATE ;the tail before TextVideoDraw ran inside cmd10
        bne M4LvLateTail
        endif
        jsr M4LevelStarsInput ;seal the overlapped cmd8, then this image's star inputs
        tst.w d0
        bne M4IntroFailed
        ; collisions and z-remove run inside the draw (M4LevelOverlapWork)
        moveq #0,d1
        jsr M4IntroPhaseEnd
        moveq #0,d0
        jsr M4TextVideoDraw
        move.w d0,INTRO_DIAG+10 ;failure code: present result
        tst.w d0
        bne M4IntroFailed
        addq.w #1,INTRO_DIAG+6
        jsr M4IntroTimingPublish
        jsr M4LevelFade
        jsr M4LevelHudSprites
        move.w M4_LV_GAMEFRAME,M4_LV_DIAG+4
        move.w M4_LV_COUNT,M4_LV_DIAG+6
        move.w M4_LV_SKIPPED,M4_LV_DIAG+8
        jsr M4LevelPause
        jsr M4EndPostDraw ;status 9: end_game_seq starts; phase 8: credits map (does not return)
        ; restart/game over after this tick's image is published (the
        ; restart waits for it to be presented)
        cmpi.w #4,M4_LV_STATUS
        beq M4LevelRestartTick
        cmpi.w #5,M4_LV_STATUS
        beq M4LevelGameOver
        cmpi.w #7,M4_LV_STATUS
        beq M4LevelFinish15
        cmpi.w #8,M4_LV_STATUS ;levelfinished 5 / 16: fades without end_level_seq
        beq M4LevelEnding
        cmpi.w #3,M4_LV_STATUS
        bne.s M4LvNotFinished
        move.w #1,M4_LV_STATUS ;levelfinished 3: end_level_seq keeps the world running
        jsr M4LvResultsStart
M4LvNotFinished:
        tst.b M4_GM_RESULTS
        beq.s M4LvNoResults
        cmpi.b #1,M4_GM_CLB2 ;clb2 = 1: out of the results loop (2: hidden, waits)
        bne.s M4LvNoResults
        cmpi.b #7,M4_GS_LEVELFIN ;02:E43D: 7 -> the same level goes on
        beq M4LevelContinue
        bra M4LevelEnding
M4LvNoResults:
M4LevelCapture:
        if def(M4_LOGIC_OVERLAP)
        btst #0,M4_OVL_STATE ;the gate came up after the logic of k+1 ran: hold one
        bne M4LevelLoop ;image later, after a serial iteration (consistent state)
        endif
        cmpi.w #2,INTRO_CAPTURE
        bne M4LevelCaptureWait
        move.w #1,INTRO_CAPTURE
        bra M4LevelLoop
M4LevelCaptureWait:
        tst.w INTRO_CAPTURE
        bne M4LevelCapture
        bra M4LevelLoop

        if def(M4_LOGIC_OVERLAP)
; After cmd10(k) when M4OvlWindow ran the tail of k up to M4EndPostDraw: only
; what needs the cmd10 result is left (count, latch of cmd8(k), timing). The
; status tests were made by M4OvlWindow (running, no results exit, no end
; sequence) and nothing since changes them: straight to the capture gate.
M4LvLateTail:
        moveq #0,d1
        jsr M4IntroPhaseEnd
        moveq #0,d0
        jsr M4TextVideoDraw
        move.w d0,INTRO_DIAG+10 ;failure code: present result
        tst.w d0
        bne M4IntroFailed
        addq.w #1,INTRO_DIAG+6
        jsr M4IntroTimingPublish
        jsr M4OvlSatPublish
        bra M4LvNoResults

; Run by the cmd10(k) request (M4_GEO_OVERLAP, intro_geometry.asm) while the
; SVP computes cmd10(k); by M4LevelDraw when no cmd10 ran. Order, as the serial
; loops: collisions/z-remove of k; the tail of k that does not need cmd10 (the
; loop's routine in M4OvlLoops, which also decides whether the loop goes on);
; then the logic of k+1, the loop's step between logic and draw (M4CtlMenu...)
; and the draw list of k+1. Nothing here writes what cmd10(k) reads
; (FACE_INPUT, GEO_OUTPUT, mailbox) nor reads what it writes (POLY_INPUT,
; mailbox): hazard list of tools/trace-level-overlap.py.
; The loop names itself in M4_OVL_LOOP before M4LevelDraw (consumed here; 0:
; serial, e.g. route map and continue). Serial with the capture gate, with the
; test control bit0, or with a cmd8 still pending (fallback without cmd10).
; Tail routine -> d0.b: -1 not run (serial tail), 0 ran and the loop goes on,
; 1 ran, goes on, no logic overlap (pause), 2.. ran, the loop leaves (its code).
M4OvlLoops: ;tail of k, step between the logic and the draw of k+1 (0 none)
        dc.l M4LvOvlTail,0 ;1 level (M4LevelLoop)
        dc.l M4CtlTail,M4CtlMenu ;2 controls (controls.asm)
        dc.l M4GoTail,M4GoPreDraw ;3 game over (gameover.asm)
        dc.l M4TrTail,0 ;4 training (training.asm)
M4OvlLoopsEnd:
M4OvlWindow:
        if def(M4_PROFILE)
        move.l d0,-(sp)
        moveq #7,d0 ;the cmd10 request so far: wait for cmd8(k-1), kick
        jsr M4ProfMark
        move.l (sp)+,d0
        endif
        jsr M4LevelOverlapWork
        cmpi.w #3,M4P_STATE ;cmd13: collisions run during raster(k-1), then
        bne.s M4OvlRasterSealed ;seal before tail/logic can change its state
        if def(M4_PROFILE)
        moveq #0,d0
        jsr M4ProfMark ;collisions, excluding the raster wait
        endif
        jsr M4PipeFlush
        if def(M4_PROFILE)
        move.l d0,-(sp)
        moveq #9,d0
        jsr M4ProfMark ;separate wait/seal of raster(k-1) inside cmd13
        move.l (sp)+,d0
        endif
        tst.w d0
        bne M4OvlSerial
M4OvlRasterSealed:
        if def(M4_PROFILE)
        move.l d0,-(sp)
        moveq #0,d0 ;collisions and z-remove: logic of k
        jsr M4ProfMark
        move.l (sp)+,d0
        endif
        moveq #0,d0
        move.b M4_OVL_LOOP,d0
        clr.b M4_OVL_LOOP
        subq.w #1,d0
        bmi M4OvlSerial
        cmpi.w #(M4OvlLoopsEnd-M4OvlLoops)/8,d0
        bhs M4OvlSerial
        if def(M4_OVL_LEVEL_ONLY) ;assembly switch: the other scenes stay serial
        tst.w d0
        bne M4OvlSerial
        endif
        cmpi.l #'OVLT',M4_OVL_MAGIC
        bne.s M4OvlEligible
        btst #0,M4_OVL_CTL ;test control: serial path
        bne M4OvlSerial
M4OvlEligible:
        tst.w INTRO_CAPTURE
        bne M4OvlSerial
        tst.w M4P_STATE ;a pending cmd8 is sealed by the serial tail first
        bne M4OvlSerial
        lsl.w #3,d0
        lea M4OvlLoops,a0
        adda.w d0,a0
        move.l 4(a0),-(sp) ;step between logic and draw
        movea.l (a0),a0
        move.l M4_LV_SATREADY,-(sp) ;the HUD buffer of k is published when the serial
        move.w M4_LV_SATWORDS,-(sp) ;path does, after cmd10(k): M4OvlSatPublish
        ; What travels with image k (tick label, BG scrolls, tilt, white add) is
        ; read now, before the logic of k+1 changes it: M4PipeLatch (cmd8 path)
        ; and M4BlockVideoUpload (no cmd8) both take it from here.
        move.b M4_WHITEADD,M4_OVL_WHITE
        move.b M4_BRIGHT,M4_OVL_BRIGHT ;(the serial no-cmd8 path seals before the tail's fade: k-1's)
        jsr M4PipeLatchScalars
        bset #3,M4_OVL_STATE
        jsr (a0)
        move.l M4_LV_SATREADY,M4_OVL_SAT
        move.w M4_LV_SATWORDS,M4_OVL_SATW
        move.w sr,d1
        ori.w #$0700,sr ;pointer and size change together (IRQ4 second run)
        move.w (sp)+,M4_LV_SATWORDS
        move.l (sp)+,M4_LV_SATREADY
        move.w d1,sr
        tst.b d0
        bpl.s M4OvlTailRan
        bclr #3,M4_OVL_STATE ;serial tail: nothing was run ahead
        bra.s M4OvlPop
M4OvlTailRan:
        move.b d0,M4_OVL_EXIT
        bset #2,M4_OVL_STATE
        if def(M4_PROFILE)
        move.l d0,-(sp)
        moveq #8,d0 ;tail of k
        jsr M4ProfMark
        move.l (sp)+,d0
        endif
        tst.b d0
        bne.s M4OvlPop ;the loop leaves, or a pause: no logic of k+1 now
        tst.w M4_SC_TIME_ON
        bne.s M4OvlPop ;retain the two pose endpoints until this tick is drawn
        jsr M4LevelTick
        bset #0,M4_OVL_STATE
        tst.w M4_LV_STATUS
        bmi.s M4OvlPopMark ;the loop fails before its next step
        move.l (sp)+,d0
        beq.s M4OvlNoStep
        movea.l d0,a0
        jsr (a0)
M4OvlNoStep:
        if def(M4_PROFILE)
        move.l d0,-(sp)
        moveq #0,d0
        jsr M4ProfMark
        move.l (sp)+,d0
        endif
        if def(M4_DRAWLIST_OVERLAP)
        jsr M4LevelDrawList ;marks slot 1 itself
        bset #1,M4_OVL_STATE
        endif
        rts
M4OvlPopMark:
        if def(M4_PROFILE)
        move.l d0,-(sp)
        moveq #0,d0
        jsr M4ProfMark
        move.l (sp)+,d0
        endif
M4OvlPop:
        addq.l #4,sp
M4OvlSerial:
        rts

; The HUD SAT buffer built by the tail in M4OvlWindow, published at the point
; of the serial loop (after TextVideoDraw/TimingPublish of k).
M4OvlSatPublish:
        move.w sr,-(sp)
        ori.w #$0700,sr
        move.w M4_OVL_SATW,M4_LV_SATWORDS
        move.l M4_OVL_SAT,M4_LV_SATREADY
        move.w (sp)+,sr
        rts

; Level tail of k before TextVideoDraw (serial order of M4LevelLoop): only in
; plain play (status running, no results exit, no end_game_seq, no pause in
; progress); M4EndPostDraw is a no-op with M4_END_ON 0 and the status tests
; after it do nothing, so M4LvLateTail goes straight to the capture gate.
M4LvOvlTail:
        moveq #-1,d0
        tst.b M4_SCREEN
        bne.s M4LvOvlTailRet
        cmpi.w #1,M4_LV_STATUS
        bne.s M4LvOvlTailRet
        tst.b M4_END_ON
        bne.s M4LvOvlTailRet
        tst.b M4_TX_PAUSE
        bne.s M4LvOvlTailRet
        tst.b M4_GM_RESULTS
        beq.s M4LvOvlTailRun
        cmpi.b #1,M4_GM_CLB2
        beq.s M4LvOvlTailRet
M4LvOvlTailRun:
        jsr M4LevelStarsInput ;M4P_STATE 0: no flush, d0 = 0
        jsr M4LevelFade
        jsr M4LevelHudSprites
        move.w M4_LV_GAMEFRAME,M4_LV_DIAG+4
        move.w M4_LV_COUNT,M4_LV_DIAG+6
        move.w M4_LV_SKIPPED,M4_LV_DIAG+8 ;(overwrites M4_LV_FLASHCODE: after the fade, as serial)
        jsr M4LevelPause
        moveq #0,d0
        tst.b M4_TX_PAUSE ;Start this tick: the pause ticks run serially
        beq.s M4LvOvlTailRet
        moveq #1,d0
M4LvOvlTailRet:
        rts
        endif

M4LevelInit:
        clr.w M4_SC_TIME_ON
        clr.w M4_SC_TIME_TWEEN
        clr.w M4_SC_TIME_VALID
        clr.w M4_SC_TIME_EXTRA
        move.w #3,M4_SC_TIME_COST
        jsr M4VRSceneBegin
        if def(M4_LOGIC_OVERLAP)
        clr.b M4_OVL_STATE ;a scene (re)start drops anything run ahead or latched
        clr.b M4_OVL_LOOP
        endif
        move.l #'M4LV',M4_LV_DIAG
        lea M4_LV,a0
        moveq #11,d0
M4LvInitClear:
        clr.l (a0)+
        dbra d0,M4LvInitClear
        move.w #1,M4_LV_STATUS
        move.w M4_CLOCK,M4_LV_LASTCLOCK
        clr.b M4_TR_PRTTRAIN ;initgame_l: $1FE0 = 0
        clr.b M4_SPB_ON ;plane B is not the streamed space map
        clr.b M4_LV_MAPEND
        lea $ff9f00,a0 ;Venom stage units RAM (level_venom.asm): 0 at stage start, as after boot
        moveq #256/4-1,d0
M4LvInitVenom:
        clr.l (a0)+
        dbra d0,M4LvInitVenom
        jsr M4MapVarsInit
        jsr M4LevelStarsInit ;initgame3d_l -> minitdust 01:A861 (SVP idle)
        jsr M4IntroSceneInit ;draw/geometry state, no intro actors
        tst.b M4_SCREEN
        beq.s M4LvInitLevelVideo
        cmpi.b #2,M4_SCREEN
        beq.s M4LvInitGameOver
        cmpi.b #3,M4_SCREEN
        beq.s M4LvInitRouteMap
        cmpi.b #4,M4_SCREEN
        beq.s M4LvInitContinue
        jsr M4CtlVideoInit ;controls screen (controls.asm)
        bra.s M4LvInitVideoDone
M4LvInitGameOver:
        jsr M4GoVideoInit ;game over (gameover.asm)
        bra.s M4LvInitVideoDone
M4LvInitRouteMap:
        jsr M4RmVideoInit ;route map (routemap.asm)
        bra.s M4LvInitVideoDone
M4LvInitContinue:
        jsr M4CnVideoInit ;continue screen (continue.asm)
        bra.s M4LvInitVideoDone
M4LvInitLevelVideo:
        jsr M4LevelVideoInit ;after SceneInit: it resets the BG B scroll
M4LvInitVideoDone:
        jsr M4LevelObjectsInit
        jsr M4PathLevelInit
        jsr M4BossLevelInit
        jsr M4ScInit
        jsr M4RadioInit
        ; Player object (playermove_init + onplanet). Restart position: the
        ; checkpoint keeps worldZ; the port starts the stream at worldZ 0.
        lea LV_PLAYER,a0
        move.w #1,22(a0)
        clr.w (a0)
        clr.w 2(a0) ;restart_l: player (0,0,0); first planet pass grounds it at -20
        clr.l 4(a0)
        move.b #LP_MEDPSPEED,15(a0)
        moveq #0,d0
        jsr M4LevelSetShape ;myship_4
        clr.b 45(a0) ;playermove_init: player has no atzremove
        move.b #$ff,38(a0) ;player HP $FF, AP 8 (damage goes to body/wings)
        move.b #8,39(a0)
        move.b #CF_FRIEND,44(a0)
        move.l #M4LcPlayerColl,X_COLL(a0)
        move.l #M4LcPlayerDead,X_EXP(a0)
        move.l #M4LevelPlayerStrat,32(a0)
        bset #F2_SHADOW,48(a0) ;playermove_init: asf_shadow
        jsr M4LevelPlayerInit
        jsr M4LevelDetectPad ;after the player block is cleared (M4_LP_SIXBUTTON)
        ; Map script at the restart point 0D:D209.
        lea TEXT_MAP_CONTEXT,a0
        moveq #7,d0
M4LvCtxClear:
        clr.l (a0)+
        dbra d0,M4LvCtxClear
        lea TEXT_MAP_CONTEXT,a0
        move.w #$5209,(a0)
        move.b #13,19(a0)
        move.b #$80,18(a0)
        move.l #M4ScriptProgramMap0D,28(a0)
        if def(M4_LEVEL_BOSS_TEST)
        move.w #$1051,(a0) ;test ROM only: map1_1b boss section, called from 0D:D239
        move.w #1,M4_LV_STACK
        move.w #$5239,M4_LV_CALLS
        bset #5,M4_BOSS_PSTRATF ;notdie
        endif
        clr.w INTRO_DIAG+6
        ; restart_l 09:9914: fadedir=1 (fade up one step per frame), fade=0
        lea M4_FADE,a0
        move.b #1,(a0)
        clr.b 1(a0)
        move.l #$80808000,4(a0)
        rts

; calcbgscroll_l 06:BB5C (values of the previous tick). Vertical:
; v = -(asr6(outvx)+asr7(outvx)) clamped to [-56,232], bg2scroll =
; (v+232)&511; mode-2 columns add the flat table t0=16 (00:8C29): MD
; VSCROLL_B = (bg2scroll+16)&511 (248 at rest, measured against the original
; screenshots: ground edge at line 115). Horizontal: HOFS = asr3(player x) +
; asr5(outvy - turnrot) (mrotplanet base, bg2Xscroll 0); HSCROLL_B = -HOFS.
; Roll tilt: plrotz of this state travels with the image (M4_BG_TILT) and the
; VR presentation builds the column/line scrolls (M4VRTiltBuild).
M4LevelBgScroll:
        tst.b M4_SCREEN ;controls screen: fixed diagram (set_c_type)
        bne M4LvBgFixed
        move.w M4_LP_PLROTZ,M4_BG_TILT
        move.w M4_LP_OUTVX,d0
        asr.w #6,d0
        move.w d0,d1
        asr.w #1,d1
        add.w d1,d0
        neg.w d0
        tst.b M4_SC_NOMAXBG ;$14CE (ExitBase): no clamp
        bne M4LvBgMin
        cmpi.w #232,d0
        blt M4LvBgMax
        move.w #232,d0
M4LvBgMax:
        cmpi.w #-56,d0
        bge M4LvBgMin
        moveq #-56,d0
M4LvBgMin:
        add.w M4_SC_BG2Y,d0 ;+ bg2Yscroll $169E
        addi.w #16,d0
        andi.w #511,d0
        move.w d0,M4_BOSS_SCROLL
        move.w M4_LP_OUTVY,d0
        sub.w M4_LP_TURNROT,d0
        asr.w #5,d0
        move.w LV_PLAYER,d1
        asr.w #3,d1
        add.w d1,d0
        neg.w d0
        andi.w #$3ff,d0
        move.w d0,M4_BG_HSCROLL
M4LvBgFixed:
        rts

; NMI fade step (01:0C12) after each tick; brightness travels with the image.
M4LevelFade:
        lea M4_FADE,a0
        move.w M4_LV_GAMEFRAME,2(a0)
        jsr M4FadeStep
        moveq #0,d0
        move.b M4_FADE+4,d0
        bpl M4LvFadeBright
        moveq #0,d0
M4LvFadeBright:
        andi.w #15,d0
        jsr M4ScBlackBright ;stayblack/blackfade (setblack_l 02:FD76)
        jsr M4ScBgPalette ;makeBG2black_l / bg_1_1c palette
        or.b M4_SC_PALVER,d0 ;bit6: CRAM base changed
        or.b M4_LV_FLASHCODE,d0 ;hit flash travels with the image
        move.b d0,M4_BRIGHT
        rts

; One original tick (transfer_l order).
M4LevelTick:
        movem.l d0-d7/a0-a6,-(sp)
        jsr M4ScTimingWait ;SCRAMBLE only; IRQ/audio keep their hardware cadence
        jsr M4ScTimingSnapshot
        jsr M4LevelReadPad
        move.w M4_CLOCK,d0 ;framerate = VBlanks of the previous tick
        move.w d0,d1
        sub.w M4_LV_LASTCLOCK,d0
        move.w d1,M4_LV_LASTCLOCK
        tst.w INTRO_CAPTURE
        bne.s M4LvRateFixed
        cmpi.l #'OVLT',M4_OVL_MAGIC ;test control bit1: capture rate without the gate
        bne.s M4LvRate
        btst #1,M4_OVL_CTL
        beq.s M4LvRate
M4LvRateFixed:
        moveq #4,d0 ;capture mode: fixed rate (tools may override)
M4LvRate:
        cmpi.w #1,d0
        bhs M4LvRateMin
        moveq #1,d0
M4LvRateMin:
        cmpi.w #15,d0
        bls M4LvRateMax
        moveq #15,d0
M4LvRateMax:
        move.w d0,M4_LP_FRAMERATE
        addq.w #1,M4_LV_GAMEFRAME
        ; init_strats_l 06:84DA: screenflashcnt -> colour math of this tick.
        ; body (type0, cnt4): 4-3 cyan, 2-1 red; wing (type1, cnt2): dim cyan.
        clr.b M4_LV_FLASHCODE
        move.b M4_LP_FLASHCNT,d0
        beq M4LvFlashDone
        moveq #$30,d1
        tst.b M4_LP_FLASHTYPE
        bne M4LvFlashSet
        moveq #$10,d1
        cmpi.b #3,d0
        bhs M4LvFlashSet
        moveq #$20,d1
M4LvFlashSet:
        move.b d1,M4_LV_FLASHCODE
        subq.b #1,M4_LP_FLASHCNT
M4LvFlashDone:
        move.w M4_LV_GAMEFRAME,d0
        move.w d0,M4_SCENE_TICK
        jsr M4MvWhiteTick ;fadewhite2norm 02:FEE8 (initfadewhite2norm_l)
        tst.b M4_WP_WHITE ;gamestart 02:E467/E481 fades: transfer_l only, the world stays
        beq.s M4LvWorldRuns
        jsr M4LevelView
        bra M4LvNoRadio
M4LvWorldRuns:
        jsr M4LevelBgScroll ;calcbgscroll_l runs before the strategies
        jsr M4SpInitStrats ;init_strats_l 06:81E7..835D: HUD flag, crosshairon, Select
        ; player_pos $150F/$1511/$1513: init_strats_l 06:81D5 copies the
        ; player's position after the strategy pass; strategies of this tick
        ; read it (the player itself has already moved: it runs first).
        lea LV_PLAYER,a0
        move.w 4(a0),M4_LP_POSZ
        move.w (a0),M4_SC_PPOSX
        move.w 2(a0),M4_SC_PPOSY
        jsr M4ScWipeTick ;circleanim record of this tick (02:DD49)
        ; dostrats (TRANS.ASM): init_strats_l ends with its random_l (06:858E)
        ; before update_objects_l (map) and the strategy pass; its 06:8380
        ; part (M4LevelPlayerDying, end of the previous tick) precedes it.
        jsr M4IntroRandom
        jsr M4LevelMap
        jsr M4LevelObjectsTick ;Do_strat_l: allst, the player is the head
        lea LV_PLAYER,a0 ;wing boxes pLWing/pRWing 0B:B039/B2DA (allst tail)
        jsr M4PmWings ;level_armada_player.asm: $14E0 bits 0..5, $158F
        jsr M4LevelPlayerDying ;init_strats_l 06:8380..84D9 after the pass
        jsr M4LevelView
        jsr M4BossHudTick
        jsr M4ScSetBlack ;setblack_l before transfer_l
        jsr M4ScTransSwap ;transswap 02:DAA3: BG requests at the tick end
        tst.b M4_END_ON ;end_game_seq / credits (level_ending.asm): loop body after transfer_l
        beq.s M4LvNotEnding
        jsr M4EndTick
        bra.s M4LvNoRadio
M4LvNotEnding:
        tst.b M4_GM_RESULTS ;end_level_seq does not run friends_messages_l
        beq.s M4LvRadio
        jsr M4LvResultsTick ;printspeclp 02:EC42 after its transfer_l
        bra.s M4LvNoRadio
M4LvRadio:
        jsr M4RadioTick ;friends_messages_l after transfer_l (02:E3F9)
M4LvNoRadio:
        jsr M4SoundTick ;original dosounds_l: continuous ports 1/2
        ; calcmeters 02:DD04
        tst.b M4_LP_BOOSTCNT
        beq M4LvMeterFill
        subq.b #2,M4_LP_BOOSTMETER
        bpl M4LvMeterDone
        clr.b M4_LP_BOOSTMETER
        clr.b M4_LP_BOOSTCNT
        bra M4LvMeterDone
M4LvMeterFill:
        cmpi.b #40,M4_LP_BOOSTMETER
        beq M4LvMeterDone
        addq.b #1,M4_LP_BOOSTMETER
M4LvMeterDone:
        movem.l (sp)+,d0-d7/a0-a6
        rts

; ---------------------------------------------------------------------
; Map script consumers (tools/recover-level-script.py tables).
; The map context mirrors fadedir/fade/INIDISP (M4_FADE) for 44/4E/50/4C and
; the waitfadefin block; fadedir written by the script is copied back.
M4LevelMap:
        tst.b M4_LV_MAPEND ;end (02) reached: the script does nothing more
        bne.s M4LvMapEnded
        lea TEXT_MAP_CONTEXT,a0
        move.b M4_FADE,16(a0)
        move.b M4_FADE+1,17(a0)
        move.b M4_FADE+4,18(a0)
        lea LV_PLAYER,a1
        move.w 4(a1),d0 ;03:ED42 reads the player worldZ itself
        jsr M4ScriptTick
        bra.s M4LvEvent
M4LvMapEnded:
        rts
; initgame newobjs_l: dispatch from the current index without a Z advance.
M4LevelMapForce:
        lea TEXT_MAP_CONTEXT,a0
        move.b M4_FADE,16(a0)
        move.b M4_FADE+1,17(a0)
        move.b M4_FADE+4,18(a0)
        jsr M4ScriptNext
M4LvEvent:
        lea TEXT_MAP_CONTEXT,a0
        move.b 16(a0),M4_FADE
        cmpi.w #1,d0
        beq M4LvEventPending
        tst.w d0
        bmi M4LvMapBad
        rts
M4LvEventPending:
        move.w 20(a0),d0
        cmpi.w #$0e,d0
        beq M4LvSetStage
        cmpi.w #$0a,d0
        beq.s M4LvGoMother
        cmpi.w #$0c,d0
        beq.s M4LvGoMapRemove
        cmpi.w #$3e,d0
        beq.s M4LvGoSetAlxW
        cmpi.w #$48,d0
        beq.s M4LvGoSetAlvarPtr
        cmpi.w #$4a,d0
        beq.s M4LvGoSetVarObj
        bra.s M4LvEventKnown
M4LvGoMother:
        jmp M4LvMother
M4LvGoMapRemove:
        jmp M4LvMapRemove
M4LvGoSetAlxW:
        jmp M4LvSetAlxW
M4LvGoSetAlvarPtr:
        jmp M4LvSetAlvarPtr
M4LvGoSetVarObj:
        jmp M4LvSetVarObj
M4LvEventKnown:
        cmpi.w #$00,d0
        beq M4LvCreate
        cmpi.w #$26,d0 ;mapobjzrot 03:F8C6: mapobj + rotz
        beq M4LvCreate
        cmpi.w #$70,d0
        beq M4LvCreate
        cmpi.w #$74,d0
        beq M4LvCreate
        cmpi.w #$76,d0
        beq M4LvCreate
        cmpi.w #$86,d0
        beq M4LvCreate
        cmpi.w #$36,d0
        beq M4LvSetAlvar
        cmpi.w #$38,d0
        beq M4LvSetAlvar
        cmpi.w #$84,d0
        beq M4LvCSpecial
        cmpi.w #$5a,d0
        beq M4LvSpecial
        cmpi.w #$8c,d0
        beq M4LvSetPath
        cmpi.w #$14,d0
        beq M4LvCommit ;setbgm: no audio in this port stage
        cmpi.w #$82,d0
        beq M4LvSendMessage
        cmpi.w #$5c,d0
        beq M4LvSetVar
        cmpi.w #$5e,d0
        beq M4LvSetVarW
        cmpi.w #$28,d0
        beq M4LvMapJsr
        cmpi.w #$2a,d0
        beq M4LvMapRts
        cmpi.w #$78,d0
        beq M4LvBlock
        cmpi.w #$7a,d0 ;mapcode_jsl: routines listed in the block table
        beq M4LvBlock
        cmpi.w #$2c,d0
        beq M4LvMapIf
        cmpi.w #$02,d0
        beq M4LvEnd
        cmpi.w #$04,d0
        beq M4LvLoop
        cmpi.w #$3c,d0
        beq M4LvSetAlx
        cmpi.w #$6a,d0
        beq M4LvAddAlvarPtr
        cmpi.w #$6c,d0 ;fadetosea 03:EF20 / fadetoground 03:EF3A: fixed-colour
        beq M4LvFadeSeaGround ;fade parameters $1EEB..$1EF1 (visual PEND)
        cmpi.w #$6e,d0
        beq M4LvFadeSeaGround
M4LvUnsupported:
        move.w 20(a0),M4_LV_BADOP
        move.w (a0),M4_LV_BADINDEX
        move.w #2,M4_LV_STATUS
        rts ;event stays pending: no silent skip
M4LvMapBad:
        move.w #-1,M4_LV_STATUS
        rts
M4LvCommit:
        jsr M4ScriptCommit
        bra M4LvEvent

; 00/26/70/74/76/86: create, then the command's wait.
M4LvCreate:
        movem.l d2-d5/a0,-(sp)
        bsr.s M4LvDecodeSpawn
        move.w d1,2(a0) ;wait_after (ROM units)
        clr.l M4_LV_LAST
        jsr M4LevelFindStrategy
        move.l a2,d1
        beq.s M4LvCreateSkip
        movea.l a2,a3 ;Istrat
        jsr M4LevelAlloc
        move.l a0,d0
        beq.s M4LvCreateDone ;original: allocation failure skips the object
        move.w d2,(a0)
        move.w d3,2(a0)
        add.w LV_PLAYER+4,d4 ;z = player worldZ + zrel (WORD wrap)
        move.w d4,4(a0)
        move.w d5,X_SHAPEHDR(a0)
        move.w d5,d0
        jsr M4LevelShapeIndex
        jsr M4LevelSetShape
        cmpi.b #$26,(a1)
        bne.s M4LvCreateNoRotz
        move.b 11(a1),14(a0) ;mapobjzrot
M4LvCreateNoRotz:
        move.l a3,32(a0) ;first traversal runs the Istrat
M4LvCreateDone:
        movem.l (sp)+,d2-d5/a0
        bra.w M4LvCommit
M4LvCreateSkip:
        addq.w #1,M4_LV_SKIPPED
        bra.s M4LvCreateDone

; a1 = original map command, possibly odd-aligned. d0.l = strategy address;
; d1-d5.w = wait, x, y, zrel, shape header. Clobbers a2, preserves a0/a1.
; Original handlers at 03:F75F/F8C6/F560/F812/F9DB (70 and 76 share F560).
M4LvDecodeSpawn:
        move.b (a1),d0
        cmpi.b #$70,d0
        beq.s M4LvSpawnShort
        cmpi.b #$76,d0
        beq.s M4LvSpawnShort
        move.b 2(a1),d1
        lsl.w #8,d1
        move.b 1(a1),d1
        move.b 4(a1),d2
        lsl.w #8,d2
        move.b 3(a1),d2
        move.b 6(a1),d3
        lsl.w #8,d3
        move.b 5(a1),d3
        move.b 8(a1),d4
        lsl.w #8,d4
        move.b 7(a1),d4
        cmpi.b #$86,d0
        beq.s M4LvSpawnDirect
        lea 9(a1),a2
        bra.s M4LvSpawnIndices
M4LvSpawnShort:
        moveq #0,d1
        move.b 1(a1),d1
        lsl.w #4,d1
        move.b 2(a1),d2
        ext.w d2
        lsl.w #2,d2
        move.b 3(a1),d3
        ext.w d3
        lsl.w #2,d3
        moveq #0,d4
        move.b 4(a1),d4
        lsl.w #4,d4
        lea 5(a1),a2
M4LvSpawnIndices:
        cmpi.b #$74,d0
        beq.s M4LvSpawnImplicit
        cmpi.b #$76,d0
        beq.s M4LvSpawnImplicit
        moveq #0,d5
        move.b (a2)+,d5 ;explicit shape index
        bra.s M4LvSpawnStrategy
M4LvSpawnImplicit:
        moveq #-1,d5 ;shape index comes from the Istrat entry
M4LvSpawnStrategy:
        moveq #0,d0
        move.b (a2),d0
        lsl.w #2,d0
        lea M4MapSpawnStrategies,a2
        move.l (a2,d0.w),d0
        tst.w d5
        bpl.s M4LvSpawnShape
        move.l d0,d5
        rol.l #8,d5
        andi.w #$ff,d5
M4LvSpawnShape:
        andi.l #$ffffff,d0
        add.w d5,d5
        lea M4MapSpawnShapes,a2
        move.w (a2,d5.w),d5
        rts
M4LvSpawnDirect:
        move.b 10(a1),d5
        lsl.w #8,d5
        move.b 9(a1),d5
        moveq #0,d0
        move.b 13(a1),d0
        lsl.l #8,d0
        move.b 12(a1),d0
        lsl.l #8,d0
        move.b 11(a1),d0
        rts

; 36/38 setalvar on the last created object (offsets used by map1_1b).
M4LvSetAlvar:
        move.l M4_LV_LAST,d0
        beq M4LvCommit
        movea.l d0,a3
        moveq #0,d0
        move.b 1(a1),d0 ;script bytes may be odd-aligned: read bytes
        bsr.s M4LvAlvarByte
        bmi M4LvUnsupported
        move.b 3(a1),(a3,d2.w) ;36 setalvar.b / low byte of 38 setalvar.w
        cmpi.w #$38,20(a0)
        bne M4LvCommit
        addq.w #1,d0 ;38: the high byte goes to the next original byte
        bsr.s M4LvAlvarByte
        bmi M4LvUnsupported
        move.b 4(a1),(a3,d2.w)
        bra M4LvCommit
; d0 = original object byte offset -> d2 = port offset (N set: not mapped).
; Original WORDs are little-endian, the port's big-endian.
M4LvAlvarByte:
        lea M4LvAlvarMap,a2
M4LvAlvarFind:
        move.w (a2)+,d1
        bmi.s M4LvAlvarNone
        move.w (a2)+,d2
        cmp.w d1,d0
        bne.s M4LvAlvarFind
        moveq #0,d1 ;N clear
        rts
M4LvAlvarNone:
        rts ;N set (d1 = -1)
M4LvAlvarMap: ;x, y, z, rotx/y/z, vel, sbyte1/2/3, sword1, path ($28), HP, AP
        dc.w $06,X_ALPTR+1,$07,X_ALPTR,$0c,1,$0d,0,$0e,3,$0f,2,$10,5,$11,4
        dc.w $12,12,$13,13,$14,14,$15,15
        dc.w $22,36,$23,37,$24,X_SBYTE3,$26,41,$27,40,$28,43,$29,42,$2a,38,$2b,39,-1

; 8C mapsetpath (03:EE11): path pointer ($28) of the last created object.
M4LvSetPath:
        move.l M4_LV_LAST,d0
        beq M4LvCommit
        movea.l d0,a3
        move.b 2(a1),42(a3)
        move.b 1(a1),43(a3)
        bra M4LvCommit

; 5A mapspecial (obj+$1D=1) / 84 mapcspecial (obj+$20=$80): count specials.
; 5A mapspecial 03:F0F9: special (drops gate_2); 84 mapCspecial 03:F116:
; Cspecial (sflags4 $80, only counted). Both count specialobjtotal.
M4LvSpecial:
        move.l M4_LV_LAST,d0
        beq M4LvCommit
        movea.l d0,a3
        bset #2,49(a3)
        addq.w #1,M4_LV_SPECIALS
        bra M4LvCommit
M4LvCSpecial:
        move.l M4_LV_LAST,d0
        beq M4LvCommit
        movea.l d0,a3
        bset #F2_CSPECIAL,48(a3)
        addq.w #1,M4_LV_SPECIALS
        bra M4LvCommit

; 5C setvar.b: addresses used by the playable stream.
M4LvSetVar:
        cmpi.b #$b7,2(a1) ;7E:F0B7 skillfly
        bne M4LvSetVarOther
        cmpi.b #$f0,3(a1)
        bne M4LvSetVarOther
        move.b 1(a1),M4_LV_SKILLFLY
        bra M4LvCommit
M4LvSetVarOther:
        move.b 3(a1),d0
        lsl.w #8,d0
        move.b 2(a1),d0
        lea M4LvSetVarTable,a2
M4LvSetVarFind:
        move.w (a2)+,d1
        beq.s M4LvSetVarNotTable
        movea.l (a2)+,a3
        cmp.w d1,d0
        bne.s M4LvSetVarFind
        move.b 1(a1),(a3)
        bra M4LvCommit
M4LvSetVarNotTable:
        cmpi.w #$1fd4,d0 ;levelfinished: gamestart dispatch (02:E3FF)
        bne M4LvSetVarClear
        move.b 1(a1),M4_GS_LEVELFIN
        tst.b M4_GM_RESULTS ;end_level_seq already running (later writes)
        bne M4LvCommit
        jsr M4LvLevelFinished ;gamestart dispatch 02:E3FF..E4BE
        bra M4LvCommit
M4LvSetVarClear:
        cmpi.w #$15ba,d0 ;stageclear (HUD text 03:DDB3: strings pending)
        bne M4LvSetVarIgnore
        move.b 1(a1),M4_BOSS_STAGECLEAR
        bra M4LvCommit
M4LvSetVarIgnore:
        andi.l #$ffff,d0 ;other variables: generic map (level_mapvars.asm)
        jsr M4LvVarAddr
        tst.l d1
        bmi M4LvUnsupported
        move.b 1(a1),(a3)
        bra M4LvCommit
; setvar.b targets of the start sequence (0D:D068..D0EA).
M4LvSetVarTable:
        dc.w $021c ;70:021C m_meters
        dc.l M4_SC_MMETERS
        dc.w $1964 ;stayblack
        dc.l M4_SC_STAYBLACK
        dc.w $15b7 ;scramble
        dc.l M4_SC_SCRAMBLE
        dc.w $1f07 ;keeppstrat
        dc.l M4_SC_KEEPPSTRAT
        dc.w $173e ;specialobjtotal (low BYTE of the port's WORD)
        dc.l M4_LV_SPECIALS+1
        dc.w $14db ;specials_dead
        dc.l M4_LV_SPECIALDEAD+1
        dc.w $001c ;clb2: end_level_seq exit (0D:D030/D062)
        dc.l M4_GM_CLB2
        dc.w $1fd0 ;doneacircle
        dc.l M4_GM_DONEACIRCLE
        dc.w $1fe0 ;prttraining (trainingmap 0D:EEE7)
        dc.l M4_TR_PRTTRAIN
        dc.w $1fcf ;onecredspr (end of the space stages, 05:D9F9)
        dc.l M4_GM_ONECRED
        dc.w 0
; 5E setvar.w: circleanim ($16AD). 280/270 start the wipes of the start
; sequence (M4ScWipeTick); the end-of-level iris is not modelled.
M4LvSetVarW:
        cmpi.b #$ad,3(a1)
        bne.s M4LvSetVarWGen
        cmpi.b #$16,4(a1)
        beq.s M4LvSetVarWCircle
M4LvSetVarWGen: ;other WORDs: generic map (level_mapvars.asm), low byte first
        moveq #0,d0
        move.b 4(a1),d0
        lsl.w #8,d0
        move.b 3(a1),d0
        move.l d0,-(sp)
        jsr M4LvVarAddr
        tst.l d1
        bmi.s M4LvSetVarWBad
        move.b 1(a1),(a3)
        move.l (sp)+,d0
        addq.w #1,d0
        jsr M4LvVarAddr
        tst.l d1
        bmi M4LvUnsupported
        move.b 2(a1),(a3)
        bra M4LvCommit
M4LvSetVarWBad:
        addq.l #4,sp
        bra M4LvUnsupported
M4LvSetVarWCircle:
        move.b 2(a1),d0
        lsl.w #8,d0
        move.b 1(a1),d0
        cmpi.w #280,d0
        beq.s M4LvSetCircle
        cmpi.w #258,d0 ;end-of-level clock wipe (0D:D046)
        beq.s M4LvSetCircle
        cmpi.w #270,d0
        bne M4LvCommit
M4LvSetCircle:
        move.w d0,M4_SC_CIRCLE
        clr.w M4_SC_WIPETICK
        bra M4LvCommit
; 04 loop 03:F984 (M4ScLoop).
M4LvLoop:
        jsr M4ScLoop
        tst.w d0
        bmi M4LvMapBad
        bra M4LvGoTo
; 3C setalxvar.b 03:F2B3 on the last object: offset $FCDF = $1CDF depthoffset.
M4LvSetAlx:
        move.l M4_LV_LAST,d0
        beq M4LvCommit
        movea.l d0,a3
        cmpi.b #$fc,2(a1)
        bne M4LvUnsupported
        cmpi.b #$f4,1(a1) ;$1CF4 sprite texture offset (X_TX)
        bne.s M4LvSetAlxDepth
        move.b 3(a1),X_TX(a3)
        bra M4LvCommit
M4LvSetAlxDepth:
        cmpi.b #$df,1(a1)
        bne M4LvUnsupported
        move.b 3(a1),X_DEPTHOFF(a3)
        bra M4LvCommit
; 6A addalvarptr.w 03:EF9F: with a last object, its WORD at byte 1 +=
; the WORD at the long address of bytes 3..5.
M4LvAddAlvarPtr:
        move.l M4_LV_LAST,d0
        beq M4LvCommit
        movea.l d0,a4
        moveq #0,d0
        move.b 5(a1),d0
        swap d0
        move.b 4(a1),d0
        lsl.w #8,d0
        move.b 3(a1),d0
        move.l d0,-(sp)
        jsr M4LvVarAddr ;source low byte
        tst.l d1
        bmi M4LvAapBad
        moveq #0,d3
        move.b (a3),d3
        move.l (sp),d0
        addq.l #1,d0
        jsr M4LvVarAddr
        tst.l d1
        bmi M4LvAapBad
        move.b (a3),d0
        lsl.w #8,d0
        or.w d0,d3 ;source WORD
        addq.l #4,sp
        moveq #0,d0
        move.b 1(a1),d0
        movea.l a4,a3
        jsr M4LvAlvarByte
        bmi M4LvUnsupported
        move.w d2,d4 ;port offset of the low byte
        addq.w #1,d0
        jsr M4LvAlvarByte
        bmi M4LvUnsupported
        move.b (a4,d2.w),d0 ;high
        lsl.w #8,d0
        move.b (a4,d4.w),d0 ;low
        add.w d3,d0
        move.b d0,(a4,d4.w)
        lsr.w #8,d0
        move.b d0,(a4,d2.w)
        bra M4LvCommit
M4LvAapBad:
        addq.l #4,sp
        bra M4LvUnsupported
M4LvFadeSeaGround:
        moveq #$1e,d0 ;$1EEB/$1EED = $1E (sea) or $3E (ground)
        cmpi.w #$6c,20(a0)
        beq.s M4LvFadeSeaSet
        moveq #$3e,d0
M4LvFadeSeaSet:
        move.b d0,M4_MV+22 ;target colour, $1EF1 = 2, $1EEF = $1E (visual PEND)
        move.b #2,M4_MV+23
        move.b #$1e,M4_MV+24
        bra M4LvCommit

; 28 mapjsr / 2A maprts (03:F3EF / 03:F41B): return to call +4.
M4LvMapJsr:
        move.w M4_LV_STACK,d1
        cmpi.w #8,d1
        bhs M4LvMapBad
        add.w d1,d1
        lea M4_LV_CALLS,a2
        bsr M4LvPackIndex
        move.w d0,(a2,d1.w)
        addq.w #1,M4_LV_STACK
        moveq #0,d0
        move.b 2(a1),d0
        lsl.w #8,d0
        move.b 1(a1),d0
        andi.w #$7fff,d0
        move.w d0,(a0)
        move.b 3(a1),19(a0) ;3-byte target (03:F3EF)
        clr.w 26(a0)
        jsr M4ScriptNext
        bra M4LvEvent
M4LvMapRts:
        move.w M4_LV_STACK,d1
        beq M4LvMapBad
        subq.w #1,d1
        move.w d1,M4_LV_STACK
        add.w d1,d1
        lea M4_LV_CALLS,a2
        move.w (a2,d1.w),d0
        bsr M4LvUnpackIndex
        addq.w #4,(a0)
        clr.w 26(a0)
        jsr M4ScriptNext
        bra M4LvEvent

; Map index (a0) and bank 19(a0) <-> WORD with the bank in bit 15.
M4LvPackIndex:
        move.w (a0),d0
        cmpi.b #5,19(a0)
        bne.s M4LvPackDone
        ori.w #$8000,d0
M4LvPackDone:
        rts
M4LvUnpackIndex: ;d0 packed -> (a0), 19(a0)
        move.b #13,19(a0)
        bclr #15,d0
        beq.s M4LvUnpackDone
        move.b #5,19(a0)
M4LvUnpackDone:
        move.w d0,(a0)
        rts

; 78 embedded blocks / 2C mapif / 7A: explicit consumers from the sorted
; block table of the context bank (M4Map0DBlocks / M4Map05Blocks).
M4LvBlockFind: ;d2 index -> a2 record or 0
        movem.l d0-d1,-(sp)
        lea M4Map0DBlocks,a2
        move.w #M4_MAP0D_BLOCKS,d1
        cmpi.b #5,19(a0)
        bne.s M4LvBlockSearch
        lea M4Map05Blocks,a2
        move.w #M4_MAP05_BLOCKS,d1
M4LvBlockSearch:
        moveq #16,d0
        jsr M4BSearch
        movem.l (sp)+,d0-d1
        rts
M4LvBlock:
        move.w (a0),d2
        jsr M4LvBlockFind
        move.l a2,d0
        beq M4LvUnsupported
        move.w 2(a2),d0
        cmpi.w #M4_LEVEL_KIND_BRANCH_IF_BYTE_MASK,d0
        beq M4LvBranchMask
        cmpi.w #M4_LEVEL_KIND_PLAYER_MODE,d0
        beq M4LvPlayerMode
        cmpi.w #M4_LEVEL_KIND_SET_RESTART,d0
        beq M4LvSetRestart
        cmpi.w #M4_LEVEL_KIND_TRIGGER_SE,d0
        beq M4LvSound
        cmpi.w #M4_LEVEL_KIND_MAPEXPLODEROBOT,d0
        beq M4LvExplodeRobot
        cmpi.w #M4_LEVEL_KIND_OR_BYTE,d0
        beq M4LvOrByte
        cmpi.w #M4_LEVEL_KIND_AND_BYTE,d0
        beq M4LvAndByte
        cmpi.w #M4_LEVEL_KIND_NOFIRE_BOSS_HP,d0
        beq M4LvNofireBoss
        cmpi.w #M4_LEVEL_KIND_MARK_BOSS,d0
        beq M4LvGoNext ;markboss list $1F6B: not used by the port
        cmpi.w #M4_LEVEL_KIND_CLEAR_DEMO,d0
        beq M4LvClearDemo
        cmpi.w #M4_LEVEL_KIND_FRIEND_MESSAGE,d0
        beq M4LvFriendMessage
        cmpi.w #M4_LEVEL_KIND_INITBLACK_L,d0
        beq M4LvInitBlack
        cmpi.w #M4_LEVEL_KIND_SETCHARMAPFROMMAP_L,d0
        beq M4LvGoNext ;BG1 map of the GSU bitmap: no MD equivalent
        cmpi.w #M4_LEVEL_KIND_CTL_RESET,d0
        beq M4LvCtlReset
        cmpi.w #M4_LEVEL_KIND_BRANCH_IF_WORD_LT,d0
        beq M4LvWordLt
        cmpi.w #M4_LEVEL_KIND_PLAYER_OUT_VIEW,d0
        beq M4LvPlayerOutView
        cmpi.w #M4_LEVEL_KIND_CL_PLAYER_MODE,d0
        beq M4LvClPlayerModeGo
        cmpi.w #M4_LEVEL_KIND_PLAYER_OUT_VIEW_SHORT,d0
        beq M4LvPlayerOutView
        jmp M4MvBlockExt ;level_mapvars.asm
M4LvClPlayerModeGo:
        jsr M4LvClPlayerMode ;level_warp.asm
        tst.w d0
        bne M4LvUnsupported
        bra M4LvGoNext
; player_out_view 05:D887 ($1F; $32 without $14DF |= 8): player dead ->
; branch (the previous command: retry); else inseq; outside the cockpit ->
; arg2 (skips the next command); in it $14DD = 4 and 06:BA91 (exit).
M4LvPlayerOutView:
        tst.b M4_LP_PSF2
        bpl.s M4LvPovAlive
        move.w 6(a2),d0
        bra M4LvGoTo
M4LvPovAlive:
        cmpi.w #M4_LEVEL_KIND_PLAYER_OUT_VIEW,2(a2)
        bne.s M4LvPovSeq
        ori.b #8,M4_BOSS_PSTRATF
M4LvPovSeq:
        cmpi.b #3,M4_SPP_FM
        beq.s M4LvPovCockpit
        move.w 14(a2),d0
        bra M4LvGoTo
M4LvPovCockpit:
        move.b #4,M4_SPP_FM
        jsr M4SpChangeView
        bra M4LvGoNext
; 0E setstage 03:F555: stagecnt $15BB = 50 (do_stage prints STAGE n or
; TRAINING), same pass.
M4LvSetStage:
        move.w #50,M4_SC_STAGECNT
        bra M4LvCommit
; branch_if_word_lt (0D:F11F): word at arg (path global 7E:F0D9) < arg2
; (unsigned) -> branch, else next.
M4LvWordLt:
        move.w 10(a2),d0
        jsr M4PvGlobalPtr
        move.l a3,d0
        beq M4LvUnsupported
        moveq #0,d0
        move.b 1(a3),d0
        lsl.w #8,d0
        move.b (a3),d0
        cmp.w 14(a2),d0
        bhs M4LvGoNext
        move.w 6(a2),d0
        bra M4LvGoTo
; contmap 0D:FA43: lastplayz $1701, pviewposz $14FC and the player's worldZ
; = 0; playerflymode &= $EF (no wobble).
M4LvCtlReset:
        clr.w 4(a0)
        clr.w M4_LP_PVIEWZ
        clr.w LV_PLAYER+4
        andi.b #$ef,M4_LP_FLYMODE
        bra M4LvGoNext
M4LvInitBlack:
        jsr M4ScInitBlack
        bra M4LvGoNext
; or_byte: pstratflags $14DF (notdie $20) only.
M4LvOrByte:
        move.l 8(a2),d0
        jsr M4LvVarAddr
        tst.l d1
        bmi M4LvUnsupported
        move.b 15(a2),d0
        or.b d0,(a3)
        bra M4LvGoNext
; and_byte: pshipflags3 $14DA only.
M4LvAndByte:
        move.l 8(a2),d0
        jsr M4LvVarAddr
        tst.l d1
        bmi M4LvUnsupported
        move.b 15(a2),d0
        and.b d0,(a3)
        bra M4LvGoNext
; 0D:9087: pshipflags nofire, boss bar maximum 0.
M4LvNofireBoss:
        bset #6,M4_LP_PSF
        clr.b M4_BOSS_MAXHP
        bra M4LvGoNext
; 0D:CF2A: calcteamdamage 06:BB22, set_playerClearDemo 0B:9558 (the
; player's strategy; its Istrat runs this tick), playerflymode &= $EF.
M4LvClearDemo:
        jsr M4LvCalcTeamDamage
        move.l #M4CdIstrat,LV_PLAYER+32
        andi.b #$ef,M4_LP_FLYMODE
        bra M4LvGoNext
; 82 sendmessage 03:EE58: id in the next byte, continue without a wait.
M4LvSendMessage:
        move.b 1(a1),d0
        jsr M4RadioSend
        bra M4LvCommit
; clfriendmsg (cl_ground 0D:CF5F/CFAA/CFF5): friends_meter $FF; with the
; friend alive, a message chosen by its exact shield (10/20/30/other).
M4LvFriendMessage:
        st M4_PV_METER
        move.l 8(a2),d0
        movem.l a2,-(sp)
        jsr M4LvReadByte
        movem.l (sp)+,a2
        bmi M4LvUnsupported
        tst.b d1
        beq M4LvGoNext
        move.b 15(a2),d0 ;other
        cmpi.b #10,d1
        bne.s M4LvFriendNot10
        move.b 12(a2),d0
M4LvFriendNot10:
        cmpi.b #20,d1
        bne.s M4LvFriendNot20
        move.b 13(a2),d0
M4LvFriendNot20:
        cmpi.b #30,d1
        bne.s M4LvFriendSend
        move.b 14(a2),d0
M4LvFriendSend:
        jsr M4RadioSend
        bra M4LvGoNext
; mapexploderobot 09:B1DE: first robot_0 (00:BB9C) of allst gets sflags4
; $20 (flagged: its path reacts through ifflag/whenflagged).
M4LvExplodeRobot:
        move.w M4_LV_HEAD,d0
M4LvRobotNext:
        tst.w d0
        beq M4LvGoNext
        movea.w d0,a3
        move.w X_NEXT(a3),d0
        cmpi.w #M4_SH_ROBOT_0,46(a3)
        bne M4LvRobotNext
        bset #5,X2_FL4(a3)
        bra M4LvGoNext
M4LvPlayerMode:
        movem.l d0-d7/a0-a6,-(sp)
        cmpi.l #$000b8ec5,8(a2) ;ExitBase (0D:D0FF)
        bne.s M4LvPlayerOnPlanet
        jsr M4ScExitBaseInit
        movem.l (sp)+,d0-d7/a0-a6
        bra M4LvGoNext
M4LvPlayerOnPlanet:
        cmpi.l #$000bbaef,8(a2) ;set_playerOnPlanet_l (0D:D21B)
        bne.s M4LvPlayerModeBad
        jsr M4ScSetOnPlanet
        movem.l (sp)+,d0-d7/a0-a6
        bra M4LvGoNext
M4LvPlayerModeBad:
        jsr M4PmPlayerMode ;level_armada_player.asm (a2 = record; d0 = 0 handled)
        tst.w d0
        bne.s M4LvPlayerModeNone
        movem.l (sp)+,d0-d7/a0-a6
        bra M4LvGoNext
M4LvPlayerModeNone:
        movem.l (sp)+,d0-d7/a0-a6
        bra M4LvUnsupported
M4LvBranchMask:
        move.l 8(a2),d0 ;address
        jsr M4LvReadByte
        bmi M4LvUnsupported
        and.b 15(a2),d1
        beq M4LvGoNext
        move.w 6(a2),d0
        bra M4LvGoTo
M4LvSound:
        move.w 14(a2),d0 ;low WORD of arg2 = original trigse ID
        jsr M4Sfx
        bra M4LvGoNext
M4LvGoNext:
        move.w 4(a2),d0
M4LvGoTo:
        move.w d0,(a0)
        clr.w 26(a0)
        jsr M4ScriptNext
        bra M4LvEvent
M4LvMapIf:
        move.w (a0),d2
        jsr M4LvBlockFind
        move.l a2,d0
        beq M4LvUnsupported
        cmpi.w #M4_LEVEL_KIND_CHKSTRATDONE1,2(a2)
        bne.s M4LvMapIfBoss
        ; chkstratdone1 06:8BB9: gameflags stratdone1 -> cleared, true branch.
        bclr #3,M4_LP_GAMEFLAGS
        beq M4LvBossAlive
        move.w 6(a2),d0
        bra M4LvGoTo
M4LvMapIfBoss:
        cmpi.w #M4_LEVEL_KIND_CHKBOSSDEAD,2(a2)
        beq.s M4LvMapIfBossDead
        jmp M4MvMapIfExt ;level_mapvars.asm
M4LvMapIfBossDead:
        ; chkbossdead 06:8BE1: gameflags bossdead (set by bossbigoutexplode)
        ; -> cleared, bar off, continue at the true branch; else wait 1.
        bclr #2,M4_LP_GAMEFLAGS
        beq M4LvBossAlive
        clr.b M4_BOSS_MAXHP
        clr.b M4_BOSS_HP
        move.w 6(a2),d0
        bra M4LvGoTo
M4LvBossAlive:
        move.w 4(a2),(a0)
        move.w #1,2(a0)
        clr.w 26(a0)
        rts
; end (02): the script stops here (the event stays pending, nothing else
; happens); the level ends through levelfinished (setvar $1FD4).
M4LvEnd:
        st M4_LV_MAPEND
        rts
M4_LV_MAPEND equ $fff9a0 ;.b map script stopped by end (02)

; d0.l = original byte address; d1 = value, N set if not modelled.
M4LvReadByte:
        cmpi.l #$7ef0b7,d0
        bne M4LvReadDead
        move.b M4_LV_SKILLFLY,d1
        rts
M4LvReadDead:
        cmpi.l #$0018a2,d0 ;friends_hp $18A1+id (rabbit, falcon, frog)
        blo M4LvReadPsf2
        cmpi.l #$0018a4,d0
        bhi M4LvReadPsf2
        lea M4_PV_FRIENDHP-$18a1,a3
        move.b (a3,d0.w),d1
        moveq #0,d0
        rts
M4LvReadPsf2:
        cmpi.l #$0018b4,d0 ;fadedir (waitfadefin 0D:D0AB)
        bne.s M4LvReadPsf2Dead
        move.b M4_FADE,d1
        moveq #0,d0
        rts
M4LvReadPsf2Dead:
        cmpi.l #$0014d9,d0 ;pshipflags2: bit7 player dead
        bne M4LvReadUnknown
        move.b M4_LP_PSF2,d1
        moveq #0,d0
        rts
M4LvReadUnknown:
        move.l a3,-(sp)
        jsr M4LvVarAddr ;generic map (level_mapvars.asm)
        tst.l d1
        bmi.s M4LvReadNone
        move.b (a3),d1
        movea.l (sp)+,a3
        moveq #0,d0
        rts
M4LvReadNone:
        movea.l (sp)+,a3
        moveq #-1,d0
        rts

; d0 = shape header (bank 00 CPU address) -> level shape index or $FFFF.
M4LevelShapeIndex:
        movem.l d1/a2,-(sp)
        lea M4LevelShapeDescriptors+16,a2
        moveq #0,d1
M4LvShapeFind:
        cmpi.w #M4_LEVEL_DESCRIPTORS,d1
        beq M4LvShapeNull
        cmp.w (a2),d0
        beq M4LvShapeFound
        lea 32(a2),a2
        addq.w #1,d1
        bra M4LvShapeFind
M4LvShapeNull:
        move.w #$ffff,d1 ;nullshape or not in the catalog: not drawn
M4LvShapeFound:
        move.w d1,d0
        movem.l (sp)+,d1/a2
        rts

; Player lasers requested by playerfire: ELASER (1F:D17A id4 -> 06:A7E3):
; shape B369, Istrat 06:A18A; gen_weapon 06:B552: type 2 (atmissile),
; rotate the spawn offset by roll/pitch/yaw x4 + mother,
; angles copied to $22/$23, $24 = mother speed. Created during the traversal:
; inserted right after its creator (1F:D3A9), so its Istrat runs this tick.
LV_PLASER_SHAPE equ 4 ;p_laser in tools/level-shapes.py
; Double laser (0B:E12F, $14D9 bit0): two ELASER at separate offsets,
; each counted in numplasers; a failed creation stops.
M4LevelFireLasers:
        tst.b M4_LP_FIREREQ
        beq M4LvFireDone
        movem.l d0-d7/a0-a3,-(sp)
        lea M4LvFireSingle,a3
        moveq #0,d7
        cmpi.b #2,M4_LP_FIREREQ
        bne M4LvFireOne
        lea M4LvFireDouble,a3
        moveq #1,d7
M4LvFireOne:
        lea LV_PLAYER,a2
        jsr M4LevelAlloc
        move.l a0,d0
        beq M4LvFireFull
        move.b (a3)+,d3
        move.b (a3)+,d4
        move.b (a3)+,d5
        jsr M4WeaponOffset
        add.w (a2),d3
        add.w 2(a2),d4
        add.w 4(a2),d5
        move.w d3,(a0)
        move.w d4,2(a0)
        move.w d5,4(a0)
        move.b 12(a2),12(a0)
        move.b 13(a2),13(a0)
        clr.b 14(a0) ;gen_weapon 06:B563: rotz 0
        move.b 12(a2),36(a0) ;$22
        move.b 13(a2),37(a0) ;$23
        move.b 15(a2),54(a0) ;$24 mother speed
        move.b 15(a2),X_SBYTE3(a0) ;$24 as read by Pelaser 06:A18A (level_weapons.asm)
        move.b #2,45(a0) ;al_type atmissile (no atzremove)
        ori.b #CF_LASER|CF_FRIEND,44(a0)
        move.l #M4LcPLaserColl,X_COLL(a0)
        move.l #M4LcPLaserDeath,X_EXP(a0)
        move.b #M4WpCfg07HP,38(a0)
        move.b #M4WpCfg07AP,39(a0)
        move.b #M4WpCfg07Speed,15(a0)
        move.b #M4WpCfg07Life,19(a0)
        moveq #LV_PLASER_SHAPE,d0
        jsr M4LevelSetShape
        move.l #M4WpPelaserInit,32(a0) ;06:A18A/A1F5 (oracle-checked: build/agent-weapons/WEAPONS.md)
        addq.b #1,M4_LP_NUMLASERS
        dbra d7,M4LvFireOne
        cmpi.b #2,M4_LP_FIREREQ
        beq.s M4LvFireSoundDouble
        M4PlaySfx $35 ;0B:DF6C: only after successful allocation
        bra.s M4LvFireFull
M4LvFireSoundDouble:
        M4PlaySfx $34
M4LvFireFull:
        movem.l (sp)+,d0-d7/a0-a3
M4LvFireDone:
        rts

M4LvFireSingle:
        include '../build/m4-player-laser-single.inc'
M4LvFireDouble:
        include '../build/m4-player-laser-double.inc'
        even
; Pelaser Istrat 06:A18A: angles from $22/$23, v = 4*gen3d(speed) +
; gen3d($24) (1F:D5D4 + 1F:C41E), animation 4|$80; no move this tick.
M4StratPLaserInit:
        move.b 36(a0),12(a0)
        move.b 37(a0),13(a0)
        moveq #0,d0
        move.b 54(a0),d0
        jsr M4LevelGen3dVecs
        movem.w 6(a0),d4-d6
        moveq #0,d0
        move.b 15(a0),d0
        jsr M4LevelGen3dVecs
        movem.w 6(a0),d1-d3
        asl.w #2,d1
        asl.w #2,d2
        asl.w #2,d3
        add.w d4,d1
        add.w d5,d2
        add.w d6,d3
        movem.w d1-d3,6(a0)
        move.b #4|$80,16(a0) ;al animation (geometry frame source for kinds>=14)
        move.l #M4StratPLaserTick,32(a0)
        moveq #0,d0
        rts
; 06:A1F5: pos += v (1F:C7BB); lifecnt-- -> remove, numplasers--.
M4StratPLaserTick:
        move.w 6(a0),d0
        add.w d0,(a0)
        move.w 8(a0),d0
        add.w d0,2(a0)
        move.w 10(a0),d0
        add.w d0,4(a0)
        subq.b #1,19(a0)
        bne M4PLaserKeep
        subq.b #1,M4_LP_NUMLASERS
        moveq #1,d0
        rts
M4PLaserKeep:
        moveq #0,d0
        rts

; marioshowview 02:F581 + alienflags_l 02:F4F1 (after the draw), allst
; order: al_flags bits 1..4 cleared and afFrontPl set when the draw list is
; built; then z = rel.W z + sh_zmax: z < 0 clears afFrontPl and removes the
; object if al_type & atzremove and not in its first frame (gf_nozremove is
; clear); every object that stays gets afInviewPl, plus afLeftPl when its
; view x is negative. Port: invisible (nullshape counter) objects keep their
; own removal rule.
M4LevelZRemove:
        movem.l d0-d3/a0/a2-a3,-(sp)
        jsr M4LcOrder
M4LvZNext:
        move.l (a2)+,d0
        beq M4LvZDone
        movea.l d0,a0
        andi.b #$e1,51(a0)
        ori.b #1<<AF_FRONTPL,51(a0)
        move.w 46(a0),d0
        cmpi.w #$ffff,d0
        beq M4LvZNull
        lsl.w #5,d0
        lea M4LevelShapeDescriptors,a3
        move.w 24(a3,d0.w),d1 ;sh_zmax
        bra M4LvZTest
M4LvZNull:
        move.w #$90,d1 ;nullshape 00:ACA1 zmax
M4LvZTest:
        if def(M4_GRAPHICS117)
        jsr G117H106ViewXZ ;cached view x/z of this draw list
        else
        jsr M4LvViewXZ ;d0 = view z, d2 = view x
        endif
        add.w d0,d1
        bpl M4LvZFlags
        bclr #AF_FRONTPL,51(a0)
        btst #1,49(a0)
        bne M4LvZFlags
        btst #3,45(a0)
        beq M4LvZFlags
        btst #0,M4_LP_GAMEFLAGS ;gf_nozremove
        bne M4LvZFlags
        btst #2,44(a0)
        bne M4LvZFlags ;acf_firstframe
        jsr M4LevelRemove
        bra M4LvZNext
M4LvZFlags:
        bset #AF_INVIEWPL,51(a0)
        tst.w d2
        bpl M4LvZNext
        bset #AF_LEFTPL,51(a0)
        bra M4LvZNext
M4LvZDone:
        movem.l (sp)+,d0-d3/a0/a2-a3
        rts
; View coordinates of a0 (rel.W columns 3 and 1) -> d0 = z, d2 = x.
M4LvViewXZ:
        movem.l d1/d3-d5,-(sp)
        move.w (a0),d3
        sub.w M4_LVW_POS,d3
        move.w 2(a0),d4
        sub.w M4_LVW_POS+2,d4
        move.w 4(a0),d5
        sub.w M4_LVW_POS+4,d5
        move.w d3,d0
        move.w M4_LVW_W,d1
        jsr M4LvwFq
        move.w d0,d2
        move.w d4,d0
        move.w M4_LVW_W+6,d1
        jsr M4LvwFq
        add.w d0,d2
        move.w d5,d0
        move.w M4_LVW_W+12,d1
        jsr M4LvwFq
        add.w d0,d2
        move.w d3,d0
        move.w M4_LVW_W+4,d1
        jsr M4LvwFq
        move.w d0,d3
        move.w d4,d0
        move.w M4_LVW_W+10,d1
        jsr M4LvwFq
        add.w d0,d3
        move.w d5,d0
        move.w M4_LVW_W+16,d1
        jsr M4LvwFq
        add.w d3,d0
        movem.l (sp)+,d1/d3-d5
        rts

; set_restart 09:98CB: checkpoint index and a copy of the map call stack.
M4LvSetRestart:
        move.w 14(a2),d0 ;arg2 low WORD = restart index, in the table's bank
        cmpi.b #5,19(a0)
        bne.s M4LvRestartBank
        ori.w #$8000,d0
M4LvRestartBank:
        move.w d0,M4_LV_RESTART
        move.w M4_LV_STACK,M4_LV_RSTACK
        movem.l M4_LV_CALLS,d0-d3
        movem.l d0-d3,M4_LV_RSTACK+2
        bra M4LvGoNext

; Player strategy at its allst position (the head: created first; the map
; links its objects right after the head, 03:F767). Its lasers and bombs are
; linked right after it and run in this same traversal.
M4LevelPlayerStrat:
        jsr M4LevelPlayerTick
        jsr M4LevelFireBomb ;bomb block runs before the laser block (0B:E010)
        jsr M4LevelFireLasers
        moveq #0,d0
        rts

; Player died with lives left: restart_l 09:9914 reduced to the port state:
; objects cleared, player re-created at (0,0,0) with full shield (playerstart
; _init_l), map from the checkpoint with its saved call stack, fade up.
M4LevelRestartTick:
        jsr M4PipeFlush
        bne M4IntroFailed
        move.w M4_SCENE_TICK,d0
        jsr M4VRWaitPresented
        bne M4IntroFailed
        move.b M4_LP_LIVES,-(sp)
        move.l M4_LV_SPECIALS,-(sp) ;restart_l keeps $173E/$14DB (D3)
        move.w TEXT_MAP_CONTEXT+12,-(sp) ;$1774: background of the stage
        jsr M4LevelInit
        move.w (sp)+,d0
        jsr M4MusicLevel
        move.l (sp)+,M4_LV_SPECIALS
        move.b (sp)+,M4_LP_LIVES
        ; restart_l 09:9963 -> initgame_l 02:E2C6 (its newobjs from the restart
        ; point run here in the first tick; they draw nothing).
        move.b #8,M4_AR_GF2 ;initgame_strats 06:8004: gameflags2 = gf2_ingame
        move.l #$3aa7557f,M4_RNG ;initgame_l 02:E2C6 -> 02:E394 -> 03:B819 random_l seed 

        cmpi.w #$21,d0 ;restart_l 09:997A: setbg $1774 + setbginfo again (space:
        beq.s M4LvRestartReq ;playerinsidespaceflyin); planet stages keep the onplanet player
        jsr M4LevelBgFind ;stage backgrounds of level_backgrounds.asm: request again
        beq.s M4LvRestartBg
M4LvRestartReq:
        move.w d0,TEXT_MAP_CONTEXT+12
        ori.b #$0c,TEXT_MAP_CONTEXT+11 ;transswap at the end of the first tick
M4LvRestartBg:
        move.w #50,M4_SC_STAGECNT ;restart_l 09:9973 (STAGE- 1)
        lea TEXT_MAP_CONTEXT,a0
        move.w M4_LV_RESTART,d0
        bsr M4LvUnpackIndex
        move.w M4_LV_RSTACK,M4_LV_STACK
        movem.l M4_LV_RSTACK+2,d0-d3
        movem.l d0-d3,M4_LV_CALLS
        bra M4LevelLoop
; levelfinished = 3 (0D:D03A): the level is completed. The results screen
; (end_level_seq 02:EC20) is out of scope: the port stops (phase 8).
; After the results (clb2 = 1): back to planetseq_l with the lives left.
; levelfinished 15 (Black Hole, after routechange2 03:D0D1 in the strategy):
; gamestart 02:E40C stage++, then E4AB: specbuf[specptr++] = $65 (no
; percentage), planetseq without results or fade (the hole faded to black).
; gamestart 02:E3FF..E4BE when levelfinished becomes nonzero: stage++ (E40C);
; 5 -> E455 (no end_level_seq); 11..14 route changes 03:D0E7/D0F2/D0FD/D0C2,
; then like 15 -> E4AB (specbuf $65, planetseq); 16 -> E463; other values ->
; end_level_seq (status 3; stage++ in M4LvResultsStart). 10 (game over) comes
; from the player death (status 5). d0/d1 free.
M4LvLevelFinished:
        tst.b M4_END_ON ;end_game_seq / credits: levelfinished is only stored (02:E683)
        bne M4LvFinDone
        cmpi.b #6,M4_GS_LEVELFIN ;6: end_level_seq finis1 + end_game_seq (level_ending.asm)
        bne.s *+8
        jmp M4EndLevelFinished ;far (level_ending.asm)
        move.w #3,M4_LV_STATUS
        move.b M4_GS_LEVELFIN,d1
        cmpi.b #15,d1
        beq.s M4LvFin15
        cmpi.b #5,d1
        beq.s M4LvFinFade
        cmpi.b #16,d1
        beq.s M4LvFinFade
        cmpi.b #11,d1
        blo.s M4LvFinDone
        cmpi.b #14,d1
        bhi.s M4LvFinDone
        cmpi.b #14,d1
        bne.s M4LvFinRoute3
        move.w #M4RouteChange1,M4_GS_ROUTES ;03:D0C2: route 0 $16D0 and 7E:F0CC
        move.b #(M4RouteChange1&$ff),M4_PV_GLOB+$1c
        move.b #(M4RouteChange1>>8),M4_PV_GLOB+$1d
        bra.s M4LvFin15
M4LvFinRoute3:
        move.w #M4RouteBlackHole1,d0 ;11: 03:D0E7
        cmpi.b #12,d1
        bne.s M4LvFinR13
        move.w #M4RouteBlackHole2,d0 ;12: 03:D0F2
M4LvFinR13:
        cmpi.b #13,d1
        bne.s M4LvFinRSet
        move.w #M4RouteBlackHole3,d0 ;13: 03:D0FD
M4LvFinRSet:
        move.w d0,M4_GS_ROUTES+6 ;route 3 $16D6
M4LvFin15:
        move.w #7,M4_LV_STATUS
        rts
M4LvFinFade:
        addq.b #1,M4_GM_STAGE ;E40C
        clr.b M4_WP_WHITE
        move.w #8,M4_LV_STATUS
M4LvFinDone:
        rts
M4LevelFinish15:
        addq.b #1,M4_GM_STAGE
        moveq #0,d0
        move.b M4_GM_SPECPTR,d0
        cmpi.b #8,d0
        bhs M4LevelComplete
        lea M4_GM_SPECBUF,a0
        move.b #$65,(a0,d0.w)
        addq.b #1,M4_GM_SPECPTR
        bra M4LevelComplete
; gamestart 02:E43B..E491 after end_level_seq: levelfinished 4 without
; doneacircle (Warp): 40 x (02:FD0F white step + transfer_l), the white
; level +1 per call up to 31 (MD add = level >> 2), then fadedir $FF until
; black, then planetseq. The world keeps running one tick per call.
M4LevelEnding:
        cmpi.b #16,M4_GS_LEVELFIN ;E436: 16 -> E463 white + black
        beq.s M4LvEndWhite
        tst.b M4_GM_DONEACIRCLE ;E455: doneacircle -> planetseq at once
        bne M4LevelComplete
        cmpi.b #4,M4_GS_LEVELFIN ;E45F: 4 -> white + black, else black only
        beq.s M4LvEndWhite
        tst.b M4_WP_WHITE
        bmi.s M4LvEndBlack
        st M4_WP_WHITE
        move.b #$ff,M4_FADE ;E476 fadedir $FF until black
        bra M4LvNoResults
M4LvEndWhite:
        move.b M4_WP_WHITE,d0
        bmi.s M4LvEndBlack
        addq.b #1,d0
        move.b d0,M4_WP_WHITE
        cmpi.b #31,d0
        bls.s M4LvEndLevel
        moveq #31,d0
M4LvEndLevel:
        lsr.b #2,d0
        move.b d0,M4_WHITEADD
        cmpi.b #40,M4_WP_WHITE
        blo M4LvNoResults
        st M4_WP_WHITE
        move.b #$ff,M4_FADE ;fadedir $FF
        bra M4LvNoResults
M4LvEndBlack:
        tst.b M4_FADE ;fade mode back to 0: black reached
        bne M4LvNoResults
M4LevelComplete:
        clr.b M4_WHITEADD
        jsr M4PipeFlush
        beq.s M4LvCompleteOk
        jmp M4IntroFailed
M4LvCompleteOk:
        move.b M4_LP_LIVES,M4_GS_LIVES
        clr.b M4_GM_RESULTS
        clr.l M4_TX_HOOK
        lea $ffff00,sp
        jmp M4PlanetSeq
; levelfinished 7 (Venom 1/2/3 orbital -> planet, 0D:D664 written during
; end_level_seq): gamestart 02:E43D stz $15AA, jml 02:E3BF -> jsl 02:E2C6
; initgame_l (screen, objects, playercred player, $1FD4/$16FD/$1701/$1703/
; viewposz = 0, initgame_strats 06:8004) and newobjs 03:ED65 from the saved
; map position $16FF/$1FF6; the map call stack, the restart point and the
; stage counter (stage++ was done for levelfinished 3) are kept.
M4LevelContinue:
        clr.b M4_GS_LEVELFIN ;02:E2FF
        clr.b M4_GM_RESULTS ;end_level_seq is over
        clr.b M4_WHITEADD
        move.b M4_LP_LIVES,M4_GS_LIVES
        jsr M4PipeFlush
        beq.s M4LvContFlushed
        jmp M4IntroFailed
M4LvContFlushed:
        move.w M4_SCENE_TICK,d0
        jsr M4VRWaitPresented
        beq.s M4LvContWaited
        jmp M4IntroFailed
M4LvContWaited:
        lea $ffff00,sp
        move.w TEXT_MAP_CONTEXT,-(sp) ;$16FF
        movem.l M4_LV_CALLS,d0-d3
        movem.l d0-d3,-(sp)
        move.w M4_LV_STACK,-(sp)
        move.w #-1,-(sp)
        move.b TEXT_MAP_CONTEXT+19,-(sp) ;$1FF6
        bra M4LvStartInit
; levelfinished $0A: gameover_l 02:E4C2 (gameover.asm).
M4LevelGameOver:
        jsr M4PipeFlush
        beq.s M4LvGameOverGo
        jmp M4IntroFailed
M4LvGameOverGo:
        lea $ffff00,sp
        jmp M4GameOverStart


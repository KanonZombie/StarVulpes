; Route map planetseq_l 03:BDCB (build/research/route-map.md; tables in
; build/routemap-data.inc from tools/generate-routemap-data.py). Runs on the
; level engine with M4_SCREEN = 3 (no objects drawn; the SVP bitmap will hold
; the planets and Pepper's text). Two clocks as the original: per frame
; (irqplanets 02:837D: ship step and blink, light and comet) and per pass
; (main loop: route blink, one pad read, ship targets). The original pass
; lasts what the GSU and the DMA take (11 frames measured on the map); the
; port fixes it at 11 frames (M4_RM_PASS, deliberate difference).
; Pending (documented): planets (SVP sphere primitive), plane A scroll of
; the chosen planet, Pepper's screen (zoom, name, message), the colour
; window inside the planet box (the whole screen is faded by CRAM), sounds.

M4_RM_PASS equ 11

; Game state kept across levels (planetseq / gamestart).
M4_GS equ $fff8b0
M4_GS_WHICHROUTE equ M4_GS+0 ;.b $16DA whichroute (game encoding)
M4_GS_CURPLANET equ M4_GS+1 ;.b $16DB currentplanet
M4_GS_CURLEVEL equ M4_GS+2 ;.b $1FFF currentlevel
M4_GS_PEPPERMSG equ M4_GS+3 ;.b 7E:F0BA peppermsg
M4_GS_NEWMAP equ M4_GS+4 ;.w $1FF9 newmap pointer
M4_GS_NEWBANK equ M4_GS+6 ;.b $1FFB newmap bank
M4_GS_LIVES equ M4_GS+7 ;.b $16EE lives between levels
M4_GS_ROUTES equ M4_GS+8 ;4 WORDs $16D0 routes[] (byte offsets in stagepaths)
M4_GS_LEVELFIN equ M4_GS+16 ;.b $1FD4 levelfinished (last value written)
M4_GS_SIZE equ 18

; Route map work RAM (screen only).
M4_RM equ $ff5e00
M4_RM_STATE equ M4_RM+0 ;.b
M4_RM_PASSCNT equ M4_RM+1 ;.b frames into the current pass
M4_RM_COUNT equ M4_RM+2 ;.w frames left in the state / step
M4_RM_X1 equ M4_RM+4 ;.w $02 x1: stagepaths offset (0 = none)
M4_RM_Y1 equ M4_RM+6 ;.w $08 y1: position X | Y << 8
M4_RM_CUR equ M4_RM+8 ;.w $30 currentsprite (byte offset into the OAM copy)
M4_RM_SX equ M4_RM+10 ;.b $32 shipxy
M4_RM_SY equ M4_RM+11 ;.b $33
M4_RM_NX equ M4_RM+12 ;.b $38 newshipxy
M4_RM_NY equ M4_RM+13 ;.b $39
M4_RM_ANGLE equ M4_RM+14 ;.b $36 shipangle
M4_RM_FLASH equ M4_RM+15 ;.b $34 flashship
M4_RM_FRAME equ M4_RM+16 ;.w $15BD gameframe (per pass)
M4_RM_PAD equ M4_RM+18 ;.w cont0l of the previous pass
M4_RM_TRIG equ M4_RM+20 ;.w trig0 of this pass
M4_RM_BRIGHT equ M4_RM+22 ;.b brightness 0..15 of the image
M4_RM_FADE equ M4_RM+23 ;.b CRAM subtraction 0..31 (window / exit fade)
M4_RM_SAVEDPL equ M4_RM+24 ;.b currentplanet before the wait (restored)
M4_RM_HIDE equ M4_RM+25 ;.b 1: TM = 1 (only BG1: plane B and OBJ hidden)
M4_RM_LIGHTANGLE equ M4_RM+26 ;.w $16EC
M4_RM_LIGHTX equ M4_RM+28 ;.w $16E6
M4_RM_LIGHTY equ M4_RM+30 ;.w $16E8
M4_RM_LIGHTZ equ M4_RM+32 ;.w $16EA
M4_RM_COMET equ M4_RM+34 ;.b $16EF
M4_RM_OLDCOMET equ M4_RM+35 ;.b $56
M4_RM_LPOS equ M4_RM+36 ;3 WORDs m_lxpos/m_lypos/m_lzpos (copylight)
M4_RM_ROTY equ M4_RM+42 ;6 WORDs roty1..6 (spinplanets)
M4_RM_SHOWNFADE equ M4_RM+54 ;.b fade applied to M4_BASE_CRAM
M4_RM_PCHARS equ M4_RM+56 ;.w 7E:F0B9 pepperchars (typewriter)
M4_RM_PASSES equ M4_RM+58 ;.w passes left in the message loop
M4_RM_FADESTART equ M4_RM+60 ;.w zoom frame of pepperfade $FE
M4_RM_OAM equ M4_RM+64 ;28 x (X, Y, char, attr) spriteblk 7E:1263
M4_RM_CRAM equ M4_RM+176 ;64 WORDs: CRAM before the fades
M4_RM_REC equ M4_RM+304 ;2 x 8 WORDs: cmd8 records being built
M4_RM_RADIUS equ M4_RM+336 ;.w zoom radius (m_radius)
M4_RM_ITER equ M4_RM+338 ;.w zoom iterations done
M4_RM_ZTOTAL equ M4_RM+340 ;.w zoom frames
M4_RM_ZITERS equ M4_RM+342 ;.w zoom iterations

RM_FADEIN equ 0
RM_SELECT equ 1
RM_FLY equ 2
RM_WAIT equ 3
RM_BLINK equ 4
RM_WINDOW equ 5
RM_ONLYPLANET equ 6
RM_SCROLL equ 7
RM_EXIT equ 8
RM_DONE equ 9
RM_PEPPERSETUP equ 10
RM_ZOOM equ 11
RM_NAME equ 12
RM_MESSAGE equ 13

        include '../build/m4-route-parameters.inc'

; firsttimeuse / initialise_l (02:E260) + initplanets_l 03:BD9B: lives 3,
; credits 0, default routes, stage 0; then planetseq_l.
M4GameStartNew:
        jsr M4PathGameInit
        jsr M4GameInit
        move.b #3,M4_GS_LIVES
        clr.b M4_GM_CREDITS
        clr.b M4_GM_STAGE
        move.l #((M4RouteStart0<<16)|M4RouteStart1),M4_GS_ROUTES
        move.l #((M4RouteStart2<<16)|M4RouteStart3),M4_GS_ROUTES+4
        clr.b M4_GS_WHICHROUTE ;contexit 1 keeps whichroute 0 (LEVEL 1 after convertroute)
        clr.b M4_GS_LEVELFIN
        ; fall through

M4PlanetSeq:
        jsr M4PipeFlush
        beq.s M4RmOk1
        jmp M4IntroFailed
M4RmOk1:
        move.w M4_SCENE_TICK,d0
        jsr M4VRWaitPresented
        beq.s M4RmOk2
        jmp M4IntroFailed
M4RmOk2:
        move.b #3,M4_SCREEN
        clr.l M4_GEO_VP
        move.l M4_RNG,-(sp) ;planetseq_l does not run initgame_l: random_l is kept
        jsr M4LevelInit ;M4RmVideoInit for M4_SCREEN 3
        move.l (sp)+,M4_RNG
        clr.b M4_SC_MMETERS ;no HUD on the map
        move.w #1,M4_GEO_VIEW ;level draw path (radio / text hook) without objects
        move.l #M4RmDrawHook,M4_TX_HOOK ;planets and Pepper's texts
        lea LV_PLAYER,a0 ;no 3D object on the map
        clr.l 32(a0)
        bset #1,49(a0)
        bset #0,49(a0)
        lea M4_RM,a0
        moveq #176/4-1,d0
M4RmClear:
        clr.l (a0)+
        dbra d0,M4RmClear
        bsr M4RmConvertRoute
        move.w #150,M4_RM_LIGHTZ ;03:BDE2 light (0, 0, 150)
        move.w #150,M4_RM_LPOS+4
        move.w #8*4,M4_RM_CUR ;currentsprite = entry 8
        move.b #1,M4_RM_ANGLE
        tst.b M4_GM_STAGE ;03:BE74: stage > 0: the completed route so far
        beq.s M4RmNoLines
        move.b M4_GM_STAGE,d0
        bsr M4RmDrawLines
        move.b M4_GM_STAGE,d0
        subq.b #1,d0
        bsr M4RmDrawLines
M4RmNoLines:
        moveq #0,d0 ;03:BE94 ship = startplanetpos[max(currentplanet, 0)]
        move.b M4_GS_CURPLANET,d0
        bpl.s M4RmShipStart
        moveq #0,d0
M4RmShipStart:
        add.w d0,d0
        lea M4RmStartPos,a0
        move.w (a0,d0.w),d0
        move.b d0,M4_RM_SX
        move.b d0,M4_RM_NX
        lsr.w #8,d0
        move.b d0,M4_RM_SY
        move.b d0,M4_RM_NY
        bsr M4RmRouteName
        clr.b M4_RM_STATE ;fade in: INIDISP 1, 3, ... 15 (one frame each)
        move.w #8,M4_RM_COUNT
        move.w M4_CLOCK,M4_LV_LASTCLOCK
        move.w #6,INTRO_DIAG+4
M4RmLoop:
        move.w M4_CLOCK,d7
        move.w d7,d0
        sub.w M4_LV_LASTCLOCK,d7
        move.w d0,M4_LV_LASTCLOCK
        tst.w INTRO_CAPTURE
        beq.s M4RmFrames
        moveq #4,d7 ;capture mode: fixed rate
M4RmFrames:
        tst.w d7
        bgt.s M4RmFrameLoop
        moveq #1,d7
M4RmFrameLoop:
        bsr M4RmFrame
        cmpi.b #RM_DONE,M4_RM_STATE
        beq M4RmLeave
        subq.w #1,d7
        bne.s M4RmFrameLoop
        bsr M4RmApplyFade
        bsr M4RmNativeTry
        tst.b d0
        bne M4RmCapture
        jsr M4LevelDraw
        move.w d0,INTRO_DIAG+8
        tst.w d0
        beq.s M4RmOk3
        jmp M4IntroFailed
M4RmOk3:
        moveq #0,d1
        jsr M4IntroPhaseEnd
        moveq #0,d0
        jsr M4TextVideoDraw
        move.w d0,INTRO_DIAG+10
        tst.w d0
        beq.s M4RmOk4
        jmp M4IntroFailed
M4RmOk4:
        addq.w #1,INTRO_DIAG+6
        jsr M4IntroTimingPublish
        moveq #0,d0
        move.b M4_RM_BRIGHT,d0
        or.b M4_SC_PALVER,d0
        move.b d0,M4_BRIGHT
        jsr M4LevelHudSprites ;M4RmSprites in route map mode
        move.w M4_RM_FRAME,M4_LV_DIAG+4
M4RmCapture:
        cmpi.w #2,INTRO_CAPTURE
        bne.s M4RmCaptureWait
        move.w #1,INTRO_CAPTURE
        bra M4RmLoop
M4RmCaptureWait:
        tst.w INTRO_CAPTURE
        bne.s M4RmCapture
        bra M4RmLoop
; setlevel 03:C42A (mapptr/mapbank = newmap) + jml gamestart 02:E3BF.
M4RmLeave:
        jsr M4RmNativeLeave
        jsr M4PipeFlush
        beq.s M4RmOk5
        jmp M4IntroFailed
M4RmOk5:
        moveq #0,d0
        jsr M4CtlPlaneA ;plane A of the VR pipeline again
        clr.l M4_TX_HOOK
        clr.b M4_SCREEN
        lea $ffff00,sp
        jmp M4LevelStart
M4RmNativeFailed:
        jmp M4IntroFailed

; ---------------------------------------------------------------------
; One frame: irqplanets (02:837D: ship blink/step, light/comet) and the
; state machine of the main loop.
M4RmFrame:
        movem.l d0-d7/a0-a6,-(sp)
        bsr M4RmIrq
        moveq #0,d0
        move.b M4_RM_STATE,d0
        add.w d0,d0
        move.w M4RmStates(pc,d0.w),d0
        jsr M4RmStates(pc,d0.w)
        movem.l (sp)+,d0-d7/a0-a6
        rts
M4RmStates:
        dc.w M4RmFadeIn-M4RmStates,M4RmSelect-M4RmStates,M4RmFly-M4RmStates
        dc.w M4RmWait-M4RmStates,M4RmBlink-M4RmStates,M4RmWindow-M4RmStates
        dc.w M4RmOnlyPlanet-M4RmStates,M4RmScroll-M4RmStates,M4RmExit-M4RmStates
        dc.w M4RmIdle-M4RmStates,M4RmPepperSetup-M4RmStates,M4RmZoom-M4RmStates
        dc.w M4RmName-M4RmStates,M4RmMessage-M4RmStates
M4RmIdle:
        rts

; 03:BEE7: INIDISP 1, 3, ..., 15 by HDMA, one step per frame.
M4RmFadeIn:
        move.w #8,d0
        sub.w M4_RM_COUNT,d0
        add.w d0,d0
        addq.w #1,d0
        move.b d0,M4_RM_BRIGHT
        subq.w #1,M4_RM_COUNT
        bne.s M4RmFadeInDone
        move.b #15,M4_RM_BRIGHT
        clr.b M4_RM_PASSCNT
        move.b #RM_FLY,M4_RM_STATE
        tst.b M4_GM_STAGE
        bne.s M4RmFadeInDone
        move.b #10,M4_GM_STAGE ;03:BF17 select: stage 10 draws the whole route
        move.b #RM_SELECT,M4_RM_STATE
M4RmFadeInDone:
        rts

; Pass clock: Z set when this frame ends a pass.
M4RmPassTick:
        addq.b #1,M4_RM_PASSCNT
        cmpi.b #M4_RM_PASS,M4_RM_PASSCNT
        bne.s M4RmPassNo
        clr.b M4_RM_PASSCNT
        moveq #0,d0 ;Z set
        rts
M4RmPassNo:
        moveq #1,d0 ;Z clear
        rts

; read_joypad_l 03:CBE7: trig0 = cur & (cur ^ cont0l), once per pass.
M4RmReadPad:
        jsr M4LevelReadPad
        move.w M4_LP_JOY,d0
        move.w M4_RM_PAD,d1
        move.w d0,M4_RM_PAD
        eor.w d0,d1
        and.w d0,d1
        move.w d1,M4_RM_TRIG
        rts

; SELECT 03:BF17: gameframe++, copylight, spinplanets (planets drawn by the
; SVP: pending), route markers drawn when gameframe & 2 else hidden; Select
; up/down/left/right change the route; B, Start or A start the game.
M4RmSelect:
        bsr M4RmPassTick
        bne M4RmSelectDone
        addq.w #1,M4_RM_FRAME
        bsr M4RmCopyLight
        bsr M4RmSpinPlanets
        btst #1,M4_RM_FRAME+1
        beq.s M4RmSelectUndraw
        move.b M4_GM_STAGE,d0
        bsr M4RmDrawLines
        bra.s M4RmSelectPad
M4RmSelectUndraw:
        bsr M4RmUndrawLines
M4RmSelectPad:
        bsr M4RmReadPad
        move.w M4_RM_TRIG,d0
        andi.w #$2f00,d0 ;Select, up, down, left, right
        beq.s M4RmSelectGo
        bsr M4RmUndrawLines
        move.b M4_GS_WHICHROUTE,d1
        move.w M4_RM_TRIG,d0
        andi.w #$2a00,d0 ;Select, up, left: previous
        beq.s M4RmRouteNext
        subq.b #1,d1
        bpl.s M4RmRouteSet
        moveq #2,d1
        bra.s M4RmRouteSet
M4RmRouteNext:
        addq.b #1,d1
        cmpi.b #3,d1
        blo.s M4RmRouteSet
        moveq #0,d1
M4RmRouteSet:
        move.b d1,M4_GS_WHICHROUTE ;trigse $11 (sound, not modelled)
        M4PlaySfx $11
        bsr M4RmRouteName
M4RmSelectGo:
        move.w M4_RM_TRIG,d0
        andi.w #$9080,d0 ;B, Start, A
        beq.s M4RmSelectDone
        clr.b M4_GM_STAGE
        clr.b M4_GS_CURPLANET
        moveq #0,d0
        bsr M4RmDrawLines
        bra M4RmGo
M4RmSelectDone:
        rts

; .shownext 03:BFDD: passes of moveshipalongpath until it returns C = 1;
; then the whole route, currentplanet = -2 and rotateforabit.
M4RmFly:
        bsr M4RmPassTick
        bne.s M4RmFlyDone
        addq.w #1,M4_RM_FRAME
        bsr M4RmCopyLight
        bsr M4RmSpinPlanets
        bsr M4RmMoveShip
        bcc.s M4RmFlyDone
        move.b M4_GM_STAGE,d0
        bsr M4RmDrawLines
        move.b M4_GS_CURPLANET,M4_RM_SAVEDPL
        move.b #-2,M4_GS_CURPLANET
        move.b #RM_WAIT,M4_RM_STATE
M4RmFlyDone:
        rts
; rotateforabit 03:C007: until B, Y, Start, A or X.
M4RmWait:
        bsr M4RmPassTick
        bne.s M4RmWaitDone
        addq.w #1,M4_RM_FRAME
        bsr M4RmCopyLight
        bsr M4RmSpinPlanets
        bsr M4RmReadPad
        move.w M4_RM_TRIG,d0
        andi.w #$d0c0,d0
        beq.s M4RmWaitDone
        move.b M4_RM_SAVEDPL,M4_GS_CURPLANET
        bra.s M4RmGo
M4RmWaitDone:
        rts

; continuewithgame 03:C038: startbgm $F1, trigse $10, flashship 1, then 83
; frames of waitdma224 while the IRQ blinks the ship.
M4RmGo:
        M4PlaySfx $10
        move.b #1,M4_RM_FLASH
        move.w #83,M4_RM_COUNT
        move.b #RM_BLINK,M4_RM_STATE
        rts
M4RmBlink:
        subq.w #1,M4_RM_COUNT
        bne.s M4RmBlinkDone
        move.w #3+32,M4_RM_COUNT
        move.b #RM_WINDOW,M4_RM_STATE
M4RmBlinkDone:
        rts
; 03:C058..C08D: sei (the IRQ stops: ship and comet frozen), 3 frames, then
; 32 steps i = 0..31: COLDATA = $E0 | i subtracted outside the planet box
; and colour 0 = fadetab0[i >> 1]. The port subtracts i from the whole
; plane B / OBJ CRAM (the box keeps its colours in the original: PEND).
M4RmWindow:
        subq.w #1,M4_RM_COUNT
        cmpi.w #32,M4_RM_COUNT
        bhs.s M4RmWindowDone
        moveq #31,d0
        sub.w M4_RM_COUNT,d0 ;i
        move.b d0,M4_RM_FADE
        tst.w M4_RM_COUNT
        bne.s M4RmWindowDone
        move.b #1,M4_RM_HIDE ;03:C0A6 TM = 1: only BG1
        move.w #6,M4_RM_COUNT
        move.b #RM_ONLYPLANET,M4_RM_STATE
        bsr M4RmPlanetAlone
M4RmWindowDone:
        rts
M4RmOnlyPlanet:
        subq.w #1,M4_RM_COUNT
        bne.s M4RmOnlyDone
        move.w #32,M4_RM_COUNT
        move.b #RM_SCROLL,M4_RM_STATE
M4RmOnlyDone:
        rts
; 03:C0D5..C115: 32 frames of calcdxdy scroll (M4RmScroll table) moving the
; chosen planet to (112, 88): pending with the planets.
M4RmScroll:
        subq.w #1,M4_RM_COUNT
        bne.s M4RmScrollDone
        move.w #15,M4_RM_COUNT
        move.b #RM_PEPPERSETUP,M4_RM_STATE
        bsr M4RmPepperVideo
M4RmScrollDone:
        rts

; 03:C117..C1FF (15 frames): HDMA ch1 black on lines 0..46 and from 176,
; dogccr/dogpcr and copyfox (plane B Pepper screen, convert-screen-bg.py
; pepper), TM = BG1 + BG2 (no OBJ), BG2 black (pepperfade $FF), the text
; bitmap cleared, the chosen planet at radius 15 in the centre (pending: SVP
; planets).
M4RmPepperSetup:
        subq.w #1,M4_RM_COUNT
        bne.s M4RmPepperSetupDone
        moveq #0,d0 ;planetsprs bit 7: sphere (zoom 312 frames, pepperfade
        move.b M4_GS_CURPLANET,d0 ;after 253) or sprite (90 / 40), measured
        add.w d0,d0 ;(route-map.md 5; the GSU time sets them in the original)
        lea M4RmPlanetSprs,a0
        move.w #312,M4_RM_COUNT
        move.w #312-253,M4_RM_FADESTART
        move.w #40,M4_RM_ZITERS
        move.b 1(a0,d0.w),d1 ;low byte of the WORD: id | $80 (sphere)
        bmi.s M4RmZoomSet
        move.w #90,M4_RM_COUNT
        move.w #90-40,M4_RM_FADESTART
        move.w #80,M4_RM_ZITERS
M4RmZoomSet:
        move.w M4_RM_COUNT,M4_RM_ZTOTAL
        clr.w M4_RM_ITER
        move.b #RM_ZOOM,M4_RM_STATE
M4RmPepperSetupDone:
        rts
; ZOOM (03:C23A..C2D5): spinplanets, drawplanetincentre, radius 15 -> 55
; (sphere) or 15 -> 95 (sprite); pepperfade $FE at x = 5 / 20, then
; irqplanets2 removes one subtraction level per frame (29 .. 0).
M4RmZoom:
        move.w M4_RM_ZTOTAL,d0 ;iteration it = (total - left) * iters / total:
        sub.w M4_RM_COUNT,d0 ;each one spinplanets, radius + 1, light x - 10,
        mulu.w M4_RM_ZITERS,d0 ;z + 10 (03:C23A..C2D5; the original's GSU
        divu.w M4_RM_ZTOTAL,d0 ;time per iteration replaced by equal steps)
        cmp.w M4_RM_ITER,d0
        bls.s M4RmZoomFrame
        addq.w #1,M4_RM_ITER
        addq.w #1,M4_RM_RADIUS
        bsr M4RmSpinPlanets
        subi.w #10,M4_RM_LPOS
        addi.w #10,M4_RM_LPOS+4
M4RmZoomFrame:
        move.w M4_RM_COUNT,d0
        cmp.w M4_RM_FADESTART,d0
        bhi.s M4RmZoomNoFade
        move.b M4_RM_FADE,d1
        cmpi.b #31,d1
        bne.s M4RmZoomFadeStep
        moveq #30,d1
M4RmZoomFadeStep:
        tst.b d1
        beq.s M4RmZoomNoFade
        subq.b #1,d1
        move.b d1,M4_RM_FADE
M4RmZoomNoFade:
        subq.w #1,M4_RM_COUNT
        bne.s M4RmZoomDone
        clr.b M4_RM_FADE
        bsr M4RmPepperTextRows ;HDMA visible to line 207 from here
        clr.w M4_RM_PCHARS
        clr.b M4_RM_PASSCNT
        move.b #RM_NAME,M4_RM_STATE
M4RmZoomDone:
        rts
; NAME (03:C2D8..C336): passes of 3 frames; each draws the first pepperchars
; glyphs of the planet's name; it ends when they are all drawn
; (m_totalchars != 0: chars + 2 passes).
M4RmName:
        addq.b #1,M4_RM_PASSCNT
        cmpi.b #3,M4_RM_PASSCNT
        bne.s M4RmNameStDone
        clr.b M4_RM_PASSCNT
        bsr M4RmNameCount
        cmp.w M4_RM_PCHARS,d0
        blo.s M4RmNameEnd
        addq.w #1,M4_RM_PCHARS
        rts
M4RmNameEnd:
        clr.w M4_RM_PCHARS
        move.w #256,M4_RM_PASSES
        move.b #RM_MESSAGE,M4_RM_STATE
M4RmNameStDone:
        rts
; MESSAGE (03:C338..C3AE): 256 passes (the counter of 50 never waits: bug of
; the original kept); full name, the first pepperchars glyphs of peppermsg;
; Start, B (trig0h) or A (trig0l) cut it. Pass fixed at 6 frames (measured
; 5/6, route-map.md 5).
M4RmMessage:
        addq.b #1,M4_RM_PASSCNT
        cmpi.b #6,M4_RM_PASSCNT
        bne.s M4RmMessageDone
        clr.b M4_RM_PASSCNT
        cmpi.w #255,M4_RM_PCHARS
        bhs.s M4RmMessageNoInc
        addq.w #1,M4_RM_PCHARS
M4RmMessageNoInc:
        bsr M4RmReadPad
        move.w M4_RM_TRIG,d0
        andi.w #$9080,d0 ;Start, B, A
        bne.s M4RmMessageEnd
        subq.w #1,M4_RM_PASSES
        bne.s M4RmMessageDone
M4RmMessageEnd:
        move.w #2+32+1,M4_RM_COUNT ;trigse $13
        M4PlaySfx $13
        move.b #RM_EXIT,M4_RM_STATE
M4RmMessageDone:
        rts
; d0 = glyph count of the current planet's name.
M4RmNameCount:
        moveq #0,d0
        move.b M4_GS_CURPLANET,d0
        lea M4RmPlanetNames,a0
        move.b (a0,d0.w),d0
        bsr.s M4RmTextPtr
        move.w (a0),d0
        rts
; d0 = message id (88..116) -> a0 = composed text (count, glyph records).
M4RmTextPtr:
        subi.w #88,d0
        add.w d0,d0
        lea M4RmTextTab,a0
        move.w (a0,d0.w),d0
        lea M4RmTexts,a0
        adda.w d0,a0
        rts
; TX hook while Pepper speaks: name (shadow colour 1 at (+2, +2), text 4)
; and message (shadow 5, text 13) with mgprintstr's typewriter count; GSU y
; = SNES line - 17 so that MD line = SNES line - 1 as plane B (vscroll 1),
; GSU x = 16 + bitmap x (screen x = 32 + bitmap x).
M4RmPepperDraw:
        move.w M4_RM_PCHARS,d6
        moveq #0,d0
        move.b M4_GS_CURPLANET,d0
        lea M4RmPlanetNames,a0
        move.b (a0,d0.w),d0
        bsr.s M4RmTextPtr
        cmpi.b #RM_NAME,M4_RM_STATE
        beq.s M4RmDrawName
        move.w #999,d6 ;message phase: the whole name
M4RmDrawName:
        moveq #1,d5
        moveq #2,d4
        move.w #-17+2,d1
        bsr.s M4RmDrawText
        moveq #4,d5
        moveq #0,d4
        move.w #-17,d1
        bsr.s M4RmDrawText
        cmpi.b #RM_MESSAGE,M4_RM_STATE
        bne.s M4RmDrawDone
        move.w M4_RM_PCHARS,d6
        moveq #0,d0
        move.b M4_GS_PEPPERMSG,d0
        bsr.s M4RmTextPtr
        moveq #5,d5
        moveq #2,d4
        move.w #168-17+2,d1
        bsr.s M4RmDrawText
        moveq #13,d5
        moveq #0,d4
        move.w #168-17,d1
        bsr.s M4RmDrawText
M4RmDrawDone:
        rts
; a0 text, d6 glyph count limit, d5 colour, d4 x offset, d1 y offset.
M4RmDrawText:
        movem.l d0-d7/a0-a2,-(sp)
        move.w (a0)+,d3
        cmp.w d6,d3
        bls.s M4RmDrawCount
        move.w d6,d3
M4RmDrawCount:
        subq.w #1,d3
        bmi.s M4RmDrawTextDone
        movea.w d1,a1
M4RmDrawGlyph:
        move.w d3,-(sp)
        moveq #0,d0
        move.b (a0),d0 ;glyph
        moveq #0,d2
        move.b 1(a0),d2
        addi.w #16,d2
        add.w d4,d2
        moveq #0,d3
        move.b 2(a0),d3
        add.w a1,d3
        lea M4RadioWidth,a2
        moveq #0,d7
        move.b (a2,d0.w),d7
        jsr M4TxGlyph
        move.w (sp)+,d3
        addq.l #4,a0
        dbra d3,M4RmDrawGlyph
M4RmDrawTextDone:
        movem.l (sp)+,d0-d7/a0-a2
        rts

; Pepper's plane B (03:C117): tiles over the map's, name table, CRAM lines
; 0/3 and the text colours on line 2 (1, 4, 5, 13 of CGRAM row 6), the
; black HDMA bands as opaque black cells (rows 0..5 and 22..27: lines
; 0..47 / 176..223, one line more than the original 0..46 / 176..).
M4RmPepperVideo:
        movem.l d0-d2/a0-a1,-(sp)
        move.w sr,-(sp)
        ori.w #$0700,sr
        move.w #M4_SCR_PEPPER_VRAM,d0
        jsr M4TextVideoWriteAddress
        lea M4ScrPepperTiles,a0
        move.w #M4_SCR_PEPPER_TILES*8-1,d1
M4RmPepperTiles:
        move.l (a0)+,VDP_DATA
        dbra d1,M4RmPepperTiles
        move.w #$e000,d0
        jsr M4TextVideoWriteAddress
        lea M4ScrPepperMap0,a0
        moveq #0,d2 ;row
M4RmPepperRow:
        moveq #31,d1
M4RmPepperCell:
        move.w (a0)+,d0
        cmpi.w #6,d2
        blo.s M4RmPepperBlack
        cmpi.w #22,d2
        blo.s M4RmPepperPut
M4RmPepperBlack:
        move.w #$64ce,d0 ;margin cover tile (line 3 colour 1), low priority
M4RmPepperPut:
        move.w d0,VDP_DATA
        dbra d1,M4RmPepperCell
        addq.w #1,d2
        cmpi.w #32,d2
        blo.s M4RmPepperRow
        move.w (sp)+,sr
        lea M4_BASE_CRAM,a1
        moveq #31,d1
M4RmPepperCramClr:
        clr.l (a1)+
        dbra d1,M4RmPepperCramClr
        lea M4ScrPepperCram,a0
        jsr M4CtlCram
        clr.w M4_BASE_CRAM ;colour 0 stays black (fadetab0 end of the window fade)
        moveq #0,d0 ;line 2: the zoom LUT colours of a sphere, row 6 for a
        move.b M4_GS_CURPLANET,d0 ;sprite (still on line 2 since ONLY_PLANET)
        add.w d0,d0
        add.w d0,d0
        lea M4RmPlanetJob,a0
        lea M4_RM_CRAM+64,a1
        cmpi.b #1,(a0,d0.w)
        bne.s M4RmPepperLine2
        moveq #0,d1
        move.b 1(a0,d0.w),d1
        lsl.w #5,d1
        lea M4SphereCramZoom0,a1
        adda.w d1,a1
M4RmPepperLine2:
        lea M4_BASE_CRAM+64,a0
        moveq #15,d1
M4RmPepperLine2Copy:
        move.w (a1)+,(a0)+
        dbra d1,M4RmPepperLine2Copy
        move.w #15,M4_RM_RADIUS ;m_radius 15, drawplanetincentre
        lea M4RmPepperCram,a0
        move.w (a0)+,M4_BASE_CRAM+64+2*1
        move.w (a0)+,M4_BASE_CRAM+64+2*4
        move.w (a0)+,M4_BASE_CRAM+64+2*5
        move.w (a0)+,M4_BASE_CRAM+64+2*13
        clr.w M4_BASE_CRAM+98
        move.w #$eee,M4_BASE_CRAM+100
        lea M4_BASE_CRAM,a0
        lea M4_RM_CRAM,a1
        moveq #63,d1
M4RmPepperSave:
        move.w (a0)+,(a1)+
        dbra d1,M4RmPepperSave
        move.b #31,M4_RM_FADE ;pepperfade $FF: BG2 black
        st M4_RM_SHOWNFADE ;apply with the next image
        move.b #2,M4_RM_HIDE ;TM = 3: no OBJ
        movem.l (sp)+,d0-d2/a0-a1
        rts
; From the name on, HDMA ch1 shows lines 47..207: rows 22..25 of plane B
; back to Pepper's map (the message cells are transparent there).
M4RmPepperTextRows:
        movem.l d0-d2/a0,-(sp)
        move.w sr,-(sp)
        ori.w #$0700,sr
        move.w #$e000+22*64,d0
        jsr M4TextVideoWriteAddress
        lea M4ScrPepperMap0+22*64,a0
        move.w #4*32-1,d1
M4RmPepperRestore:
        move.w (a0)+,VDP_DATA
        dbra d1,M4RmPepperRestore
        move.w (sp)+,sr
        movem.l (sp)+,d0-d2/a0
        rts

; 03:C3AF..C43B: trigse $13, 2 frames, 32 steps of colour subtraction on
; BG1 + BG2 (i = 0..31, one per frame), one frame, convertroute, setlevel.
M4RmExit:
        subq.w #1,M4_RM_COUNT
        cmpi.w #33,M4_RM_COUNT
        bhs.s M4RmExitDone
        tst.w M4_RM_COUNT
        beq.s M4RmExitEnd
        moveq #32,d0
        sub.w M4_RM_COUNT,d0
        cmpi.w #31,d0
        bls.s M4RmExitStep
        moveq #31,d0
M4RmExitStep:
        move.b d0,M4_RM_FADE
        cmpi.b #31,d0
        bne.s M4RmExitDone
        clr.b M4_RM_BRIGHT
        rts
M4RmExitEnd:
        clr.l M4_TX_HOOK
        bsr M4RmConvertRoute
        move.b #RM_DONE,M4_RM_STATE
M4RmExitDone:
        rts

; convertroute 03:D108: whichroute 0 <-> 1.
M4RmConvertRoute:
        move.b M4_GS_WHICHROUTE,d0
        beq.s M4RmConv0
        cmpi.b #1,d0
        bne.s M4RmConvDone
        clr.b M4_GS_WHICHROUTE
        rts
M4RmConv0:
        move.b #1,M4_GS_WHICHROUTE
M4RmConvDone:
        rts

; ---------------------------------------------------------------------
; drawplanetlines_l 03:CC2A, d0.b = stage count: from entry 8, the markers
; of `count` legs of the route whichroute; on each PATHSTART the planet,
; newmap, peppermsg and currentlevel; with count 0 left: X1 = first segment,
; Y1 = position, carry clear; NOMOREPATHS: carry set. The $FFFF terminator
; still writes its position (spurious entry) and does not advance.
M4RmDrawLines:
        movem.l d1-d4/a0-a2,-(sp)
        move.w #8*4,M4_RM_CUR
        moveq #0,d3
        move.b d0,d3 ;$02 count
        lea M4RmStagePaths,a0
        moveq #0,d0
        move.b M4_GS_WHICHROUTE,d0
        add.w d0,d0
        andi.w #$ff,d0
        bsr M4RmWordAt ;header offset
        move.w d1,d2 ;x
M4RmLinesOp:
        moveq #0,d0
        move.b (a0,d2.w),d0
        beq M4RmLinesEnd
        cmpi.b #3,d0
        beq.s M4RmLinesStart
        move.w d2,d0
        addq.w #1,d0
        bsr M4RmWordAt
        cmpi.b #2,(a0,d2.w)
        bne.s M4RmLinesNext
        lea M4_GS_ROUTES,a1 ;PATHCHOICE: routes[ww/2] (byte offset ww)
        move.w (a1,d1.w),d1
M4RmLinesNext:
        move.w d1,d2
        bra.s M4RmLinesOp
M4RmLinesStart: ;03:CC7F
        move.b 1(a0,d2.w),d4 ;cell x, y -> pixels (03:CB9E: each byte << 3)
        lsl.b #3,d4
        move.b 2(a0,d2.w),d1
        lsl.b #3,d1
        lsl.w #8,d1
        andi.w #$ff,d4
        or.w d4,d1 ;y = X | Y << 8
        move.b 3(a0,d2.w),M4_GS_CURPLANET
        move.b 5(a0,d2.w),d0 ;newmap: pointer (4, 5), bank (6)
        lsl.w #8,d0
        move.b 4(a0,d2.w),d0
        move.w d0,M4_GS_NEWMAP
        move.b 6(a0,d2.w),M4_GS_NEWBANK
        move.b 7(a0,d2.w),M4_GS_PEPPERMSG
        move.b 8(a0,d2.w),M4_GS_CURLEVEL
        addi.w #9,d2
        tst.w d3
        beq.s M4RmLinesStop
M4RmLinesSeg: ;03:CCBC
        lea M4_RM_OAM,a1
        adda.w M4_RM_CUR,a1
        move.b d1,(a1) ;position (X, Y)
        move.w d1,d4
        lsr.w #8,d4
        move.b d4,1(a1)
        move.w d2,d0
        addq.w #2,d0
        bsr.s M4RmWordAtD4 ;d4 = dx | dy << 8
        add.w d4,d1 ;16-bit add
        move.w d2,d0
        bsr.s M4RmWordAtD4 ;char word
        cmpi.w #$ffff,d4
        beq.s M4RmLinesLegEnd
        move.b d4,2(a1) ;char, attribute
        lsr.w #8,d4
        move.b d4,3(a1)
        addq.w #4,M4_RM_CUR
        addq.w #4,d2
        bra.s M4RmLinesSeg
M4RmLinesLegEnd:
        addq.w #2,d2
        subq.w #1,d3
        bra M4RmLinesOp
M4RmLinesStop: ;03:CCEE
        move.w d2,M4_RM_X1
        move.w d1,M4_RM_Y1
        movem.l (sp)+,d1-d4/a0-a2
        andi.b #$fe,ccr
        rts
M4RmLinesEnd:
        movem.l (sp)+,d1-d4/a0-a2
        ori.b #1,ccr
        rts
; d0 = offset -> d1 = little-endian WORD of stagepaths.
M4RmWordAt:
        move.b 1(a0,d0.w),d1
        lsl.w #8,d1
        move.b (a0,d0.w),d1
        rts
M4RmWordAtD4:
        move.b 1(a0,d0.w),d4
        lsl.w #8,d4
        move.b (a0,d0.w),d4
        rts

; undrawplanetlines_l: X = Y = $F8 in the 20 route entries.
M4RmUndrawLines:
        lea M4_RM_OAM+8*4,a0
        moveq #19,d0
M4RmUndraw:
        move.b #$f8,(a0)
        move.b #$f8,1(a0)
        addq.l #4,a0
        dbra d0,M4RmUndraw
        rts

; moveshipalongpath 03:C470 (once per pass). Carry set: arrived.
M4RmMoveShip:
        move.b M4_RM_SX,d0
        cmp.b M4_RM_NX,d0
        bne M4RmShipBusy
        move.b M4_RM_SY,d0
        cmp.b M4_RM_NY,d0
        bne M4RmShipBusy
        lea M4RmStagePaths,a0
        move.w M4_RM_X1,d2
        beq.s M4RmShipLegEnd
        move.b (a0,d2.w),d0
        bmi.s M4RmShipLegEnd
        moveq #2,d1 ;shipangle from the segment character
        cmpi.b #4,d0
        bne.s M4RmShipAng1
        moveq #0,d1
        bra.s M4RmShipAng
M4RmShipAng1:
        cmpi.b #2,d0
        bne.s M4RmShipAng
        moveq #1,d1
M4RmShipAng:
        move.b d1,M4_RM_ANGLE
        lea M4_RM_OAM,a1
        adda.w M4_RM_CUR,a1
        move.b (a0,d2.w),2(a1)
        move.b 1(a0,d2.w),3(a1)
        move.w M4_RM_Y1,d1
        move.b d1,(a1)
        move.w d1,d0
        lsr.w #8,d0
        move.b d0,1(a1)
        addq.w #4,M4_RM_CUR
        move.b 3(a0,d2.w),d0 ;y1 += dx | dy << 8
        lsl.w #8,d0
        move.b 2(a0,d2.w),d0
        add.w d0,d1
        move.w d1,M4_RM_Y1
        subi.w #$0810,d1 ;newshipxy = y1 - $0810
        move.b d1,M4_RM_NX
        lsr.w #8,d1
        move.b d1,M4_RM_NY
        addq.w #4,d2
        move.w d2,M4_RM_X1
        bra.s M4RmShipBusy
M4RmShipLegEnd: ;03:C488
        move.b M4_GM_STAGE,d0
        bsr M4RmDrawLines
        clr.w M4_RM_X1
        moveq #0,d0
        move.b M4_GS_CURPLANET,d0
        add.w d0,d0
        lea M4RmEndPos,a0
        move.w (a0,d0.w),d0
        move.b d0,M4_RM_NX
        lsr.w #8,d0
        move.b d0,M4_RM_NY
        bsr.s M4RmShipAtTarget
        beq.s M4RmShipArrived
        move.b M4_RM_NY,d0 ;03:C49F: a target above the ship keeps its Y
        sub.b M4_RM_SY,d0
        bmi.s M4RmShipBusy
        move.b M4_RM_SY,M4_RM_NY
        bsr.s M4RmShipAtTarget
        beq.s M4RmShipArrived
M4RmShipBusy:
        andi.b #$fe,ccr
        rts
M4RmShipArrived:
        ori.b #1,ccr
        rts
M4RmShipAtTarget: ;Z set when shipxy == newshipxy
        move.b M4_RM_SX,d0
        cmp.b M4_RM_NX,d0
        bne.s M4RmAtDone
        move.b M4_RM_SY,d0
        cmp.b M4_RM_NY,d0
M4RmAtDone:
        rts

; ---------------------------------------------------------------------
; irqplanets 02:84A2..8695 (one frame). Not run while the IRQ is stopped
; (sei of the window, the planet-only and the scroll steps).
M4RmIrq:
        move.b M4_RM_STATE,d0
        cmpi.b #RM_WINDOW,d0
        bhs M4RmIrqDone
        lea M4_RM_OAM+16,a0 ;entries 4..7: the ship
        move.b M4_RM_FLASH,d0
        btst #0,d0
        beq.s M4RmIrqStep
        addi.b #$40,d0
        move.b d0,M4_RM_FLASH
        bpl.s M4RmIrqStep
        clr.l (a0) ;hidden: entries zeroed, no step this frame
        clr.l 4(a0)
        clr.l 8(a0)
        clr.l 12(a0)
        bra M4RmIrqComet
M4RmIrqStep: ;02:84D4: 1 pixel per frame, 8-bit compares
        move.b M4_RM_SY,d0
        cmp.b M4_RM_NY,d0
        bmi.s M4RmStepDown
        move.b M4_RM_SX,d0
        sub.b M4_RM_NX,d0
        beq.s M4RmStepY
        bcs.s M4RmStepRight
        move.b d0,d2 ;sx > nx
        move.b M4_RM_SY,d1
        sub.b M4_RM_NY,d1
        beq.s M4RmStepDecX
        cmp.b d2,d1
        bne.s M4RmStepY
M4RmStepDecX:
        subq.b #1,M4_RM_SX
        bra.s M4RmStepY
M4RmStepRight:
        move.b d0,d2 ;sx < nx
        move.b M4_RM_NY,d1
        sub.b M4_RM_SY,d1
        beq.s M4RmStepIncX
        cmp.b d2,d1
        bne.s M4RmStepY
M4RmStepIncX:
        addq.b #1,M4_RM_SX
M4RmStepY: ;02:8511
        move.b M4_RM_SY,d0
        cmp.b M4_RM_NY,d0
        beq.s M4RmStepDone
        bpl.s M4RmStepUp
M4RmStepDown: ;02:851B
        addq.b #1,M4_RM_SY
        move.b M4_RM_SX,d0
        cmp.b M4_RM_NX,d0
        beq.s M4RmStepDone
        addq.b #1,M4_RM_SX
        bra.s M4RmStepDone
M4RmStepUp:
        subq.b #1,M4_RM_SY
M4RmStepDone: ;02:852E: entries 4..7, chars 9 / 5 / 13 by angle, attr $3E
        move.b M4_RM_SX,d0
        addq.b #8,d0
        move.b d0,(a0)
        move.b d0,8(a0)
        addq.b #8,d0
        move.b d0,4(a0)
        move.b d0,12(a0)
        move.b M4_RM_SY,d0
        addq.b #8,d0
        move.b d0,1(a0)
        move.b d0,5(a0)
        addq.b #8,d0
        move.b d0,9(a0)
        move.b d0,13(a0)
        moveq #9,d0
        move.b M4_RM_ANGLE,d1
        beq.s M4RmShipChar
        moveq #5,d0
        subq.b #1,d1
        beq.s M4RmShipChar
        moveq #13,d0
M4RmShipChar:
        move.b d0,2(a0)
        addq.b #1,d0
        move.b d0,6(a0)
        addq.b #1,d0
        move.b d0,10(a0)
        addq.b #1,d0
        move.b d0,14(a0)
        move.b #$3e,3(a0)
        move.b #$3e,7(a0)
        move.b #$3e,11(a0)
        move.b #$3e,15(a0)
M4RmIrqComet: ;02:8587: comet entries 0..3 or the light rotation
        lea M4_RM_OAM,a0
        tst.b M4_RM_COMET
        beq.w M4RmIrqLight
        move.b M4_RM_LIGHTX+1,d0
        subi.b #15,d0
        move.b d0,(a0)
        move.b d0,4(a0)
        addq.b #8,d0
        move.b d0,8(a0)
        move.b d0,12(a0)
        move.b M4_RM_LIGHTY+1,d0
        move.b d0,1(a0)
        move.b d0,9(a0)
        addq.b #8,d0
        move.b d0,5(a0)
        move.b d0,13(a0)
        moveq #$11,d0
        cmpi.b #$11,2(a0)
        bne.s M4RmCometChar
        moveq #$15,d0
M4RmCometChar:
        move.b d0,2(a0)
        addq.b #1,d0
        move.b d0,10(a0)
        addq.b #1,d0
        move.b d0,6(a0)
        addq.b #1,d0
        move.b d0,14(a0)
        move.b #$1e,3(a0)
        move.b #$1e,7(a0)
        move.b #$1e,11(a0)
        move.b #$1e,15(a0)
        subq.b #2,M4_RM_LIGHTX+1
        addq.b #2,M4_RM_LIGHTY+1
        cmpi.b #$12,M4_RM_LIGHTX+1
        blo.s M4RmCometEnd
        cmpi.b #$e0,M4_RM_LIGHTY+1
        blo.w M4RmIrqDone
M4RmCometEnd:
        clr.b M4_RM_COMET
        move.b #$1e,M4_RM_LIGHTANGLE
        rts
; 02:860B: light target on a circle of centre (128, 100), z 200; the comet
; starts when the angle's high byte reaches $A0 (light (255, 0)).
M4RmIrqLight:
        moveq #0,d0
        move.b M4_RM_LIGHTANGLE,d0
        neg.b d0
        lea M4RmIrqSin,a1
        move.b (a1,d0.w),d1 ;sy
        addi.b #64,d0
        move.b (a1,d0.w),d2 ;cy
        moveq #125,d0 ;x2 = mul(125, sy) (x1 = 0), z2 = mul(125, cy)
        bsr.s M4RmIrqMul ;d0 125, d1 -> d3
        move.b d3,d4
        move.b d2,d1
        moveq #125,d0
        bsr.s M4RmIrqMul
        ext.w d4
        addi.w #$80,d4
        move.w d4,M4_RM_LIGHTX
        ext.w d3
        addi.w #$64,d3
        move.w d3,M4_RM_LIGHTY
        move.w #$c8,M4_RM_LIGHTZ
        addi.w #$10,M4_RM_LIGHTANGLE
        cmpi.b #$a0,M4_RM_LIGHTANGLE
        bne.s M4RmIrqDone
        move.b #1,M4_RM_COMET
        move.w #$ff,M4_RM_LIGHTX
        clr.w M4_RM_LIGHTY
M4RmIrqDone:
        rts
; 02:A61B: 8-bit signed multiply, hi byte of (2|a|)*|b| with the sign.
M4RmIrqMul: ;d0.b a, d1.b b -> d3.b
        movem.l d0-d2,-(sp)
        moveq #0,d2
        tst.b d0
        bpl.s M4RmMulA
        neg.b d0
        not.b d2
M4RmMulA:
        tst.b d1
        bpl.s M4RmMulB
        neg.b d1
        not.b d2
M4RmMulB:
        andi.w #$ff,d0
        andi.w #$ff,d1
        add.b d0,d0
        andi.w #$ff,d0
        mulu.w d1,d0
        lsr.w #8,d0
        tst.b d2
        beq.s M4RmMulPos
        neg.b d0
M4RmMulPos:
        move.b d0,d3
        movem.l (sp)+,d0-d2
        rts

; copylight 03:C4FD (per pass): m_lzpos = lightz; m_lxpos/m_lypos chase
; lightx/lighty by 1 (16 with the comet); sound $91 when the comet starts.
M4RmCopyLight:
        move.b M4_RM_COMET,M4_RM_OLDCOMET
        move.w M4_RM_LIGHTZ,M4_RM_LPOS+4
        moveq #1,d2
        tst.b M4_RM_COMET
        beq.s M4RmLightStep
        moveq #16,d2
M4RmLightStep:
        lea M4_RM_LPOS,a0
        move.w M4_RM_LIGHTX,d1
        bsr.s M4RmLightAxis
        lea M4_RM_LPOS+2,a0
        move.w M4_RM_LIGHTY,d1
M4RmLightAxis:
        move.w (a0),d0
        sub.w d1,d0
        bmi.s M4RmLightUp
        sub.w d2,(a0)
        rts
M4RmLightUp:
        add.w d2,(a0)
        rts
; spinplanets 03:C57B: roty[i] += speed[i] (16 bits).
M4RmSpinPlanets:
        lea M4_RM_ROTY,a0
        lea M4RmSpinSpeeds,a1
        moveq #5,d0
M4RmSpin:
        move.w (a1)+,d1
        add.w d1,(a0)+
        dbra d0,M4RmSpin
        rts

; drawroutename 03:C66B: BG2 cells (24..29, 25) = chars[whichroute] + 0..5,
; score (24..28, 24) = hundreds, tens, units of calctotalscore and "00",
; credits (27.., 23) = credit icons. Written to plane B through the extra
; cell table of the converter.
M4RmRouteName:
        movem.l d0-d4/a0-a1,-(sp)
        move.w sr,-(sp)
        ori.w #$0700,sr
        moveq #0,d0
        move.b M4_GS_WHICHROUTE,d0
        add.w d0,d0
        lea M4RmRouteChars,a0
        move.w (a0,d0.w),d3
        move.w #$e000+(25*32+24)*2,d0
        jsr M4TextVideoWriteAddress
        moveq #5,d4
M4RmNameCell:
        move.w d3,d0
        bsr.w M4RmExtraWord
        move.w d0,VDP_DATA
        addq.w #1,d3
        dbra d4,M4RmNameCell
        jsr M4LvTotalScore ;d0 = total
        move.w #$e000+(24*32+24)*2,d0
        jsr M4TextVideoWriteAddress
        jsr M4LvTotalScore
        moveq #0,d1
        move.w d0,d1
        divu.w #100,d1
        move.w d1,d0
        addi.w #$18a8,d0
        bsr.w M4RmExtraWord
        move.w d0,VDP_DATA
        clr.w d1
        swap d1
        divu.w #10,d1
        move.w d1,d0
        addi.w #$18a8,d0
        bsr.w M4RmExtraWord
        move.w d0,VDP_DATA
        swap d1
        move.w d1,d0
        addi.w #$18a8,d0
        bsr.w M4RmExtraWord
        move.w d0,VDP_DATA
        move.w #$18a8,d0
        bsr.w M4RmExtraWord
        move.w d0,VDP_DATA
        move.w d0,VDP_DATA
        moveq #0,d4
        move.b M4_GM_CREDITS,d4
        beq.s M4RmNameDone
        move.w #$e000+(23*32+27)*2,d0
        jsr M4TextVideoWriteAddress
        subq.w #1,d4
M4RmCredit:
        move.w #$18de,d0
        bsr.w M4RmExtraWord
        move.w d0,VDP_DATA
        dbra d4,M4RmCredit
M4RmNameDone:
        move.w (sp)+,sr
        movem.l (sp)+,d0-d4/a0-a1
        rts
; d0 SNES BG2 word -> d0 MD name table word (M4ScrRoutemapExtra).
M4RmExtraWord:
        lea M4ScrRoutemapExtra,a1
M4RmExtraFind:
        tst.w (a1)
        beq.s M4RmExtraNone
        cmp.w (a1),d0
        beq.s M4RmExtraFound
        addq.l #4,a1
        bra.s M4RmExtraFind
M4RmExtraFound:
        move.w 2(a1),d0
        rts
M4RmExtraNone:
        move.w #M4_SCR_ROUTEMAP_BLANK,d0
        rts

; Window / exit colour subtraction: lines 0, 1, 3 (plane B, OBJ) from the
; saved CRAM minus M4_RM_FADE (M4GoSubOne), colour 0 = fadetab0[i >> 1]
; during the window, line 2 (bitmap) only in the exit fade.
M4RmApplyFade:
        move.b M4_RM_FADE,d0
        cmp.b M4_RM_SHOWNFADE,d0
        beq.s M4RmFadeDone
        move.b d0,M4_RM_SHOWNFADE
        movem.l d0-d5/a0-a1,-(sp)
        moveq #0,d5
        move.b d0,d5
        lea M4_RM_CRAM,a0
        lea M4_BASE_CRAM,a1
        moveq #0,d4
M4RmFadeColour:
        move.w (a0)+,d0
        cmpi.w #32,d4
        blo.s M4RmFadeSub
        cmpi.w #48,d4
        bhs.s M4RmFadeSub
        cmpi.b #RM_EXIT,M4_RM_STATE
        beq.s M4RmFadeSub
        move.w d0,(a1)+
        bra.s M4RmFadeNext
M4RmFadeSub:
        jsr M4GoSubOne
        move.w d3,(a1)+
M4RmFadeNext:
        addq.w #1,d4
        cmpi.w #64,d4
        blo.s M4RmFadeColour
        cmpi.b #RM_WINDOW,M4_RM_STATE
        bne.s M4RmFadeBack
        moveq #0,d0
        move.b d5,d0
        lsr.w #1,d0
        add.w d0,d0
        lea M4RmFadeTab0,a0
        move.w (a0,d0.w),M4_BASE_CRAM
M4RmFadeBack:
        movem.l (sp)+,d0-d5/a0-a1
        eori.b #$40,M4_SC_PALVER
M4RmFadeDone:
        rts

; Video (instead of M4LevelVideoInit): route map on plane B (vscroll 1: the
; SNES shows BG one line above OBJ), OBJ characters, CRAM lines 0/3 (plane
; B), 1 (OBJ palette 7), 2 (bitmap: planselpal, pending with the planets).
M4RmVideoInit:
        clr.w M4N_ON
        move.w sr,-(sp)
        ori.w #$0700,sr
        ; The previous level is still displayed here. Replace tiles/maps only
        ; while hidden; the native cold upload reveals the complete map.
        move.w #$8134,VDP_CTRL
        move.w #$8d34,VDP_CTRL ;flight may have selected the D400 tilt table
        move.l #$50000003,VDP_CTRL ;D000: reset both planes' horizontal scroll
        move.l #0,VDP_DATA
        move.w #M4_SCR_ROUTEMAP_VRAM,d0
        jsr M4TextVideoWriteAddress
        lea M4ScrRoutemapTiles,a0
        move.w #M4_SCR_ROUTEMAP_TILES*8-1,d1
M4RmTiles:
        move.l (a0)+,VDP_DATA
        dbra d1,M4RmTiles
        move.w #M4_RM_OBJ_VRAM,d0
        jsr M4TextVideoWriteAddress
        lea M4RmObjTiles,a0
        move.w #M4_RM_OBJ_TILES*8-1,d1
M4RmObjCopy:
        move.l (a0)+,VDP_DATA
        dbra d1,M4RmObjCopy
        move.w #$e000,d0
        jsr M4TextVideoWriteAddress
        lea M4ScrRoutemapMap0,a0
        move.w #32*32/2-1,d1
M4RmMap:
        move.l (a0)+,VDP_DATA
        dbra d1,M4RmMap
        move.w #32*32/2-1,d1
M4RmMapClear:
        move.l #0,VDP_DATA
        dbra d1,M4RmMapClear
        move.w #$c000,d0 ;plane A: planet cells with their CRAM lines
        jsr M4TextVideoWriteAddress
        lea M4RmPlaneA,a0
        move.w #2047,d1
M4RmPlaneACopy:
        move.w (a0)+,VDP_DATA
        dbra d1,M4RmPlaneACopy
        move.w #$8700,VDP_CTRL ;backdrop = CGRAM 0 (map background colour)
        move.w #$8b00,VDP_CTRL
        move.w (sp)+,sr
        clr.w M4_LEVEL_TILT
        lea M4_BASE_CRAM,a1
        moveq #31,d1
M4RmCramClear:
        clr.l (a1)+
        dbra d1,M4RmCramClear
        lea M4ScrRoutemapCram,a0
        jsr M4CtlCram
        lea M4RmObjCram+2,a0
        lea M4_BASE_CRAM+34,a1
        moveq #14,d1
M4RmObjPal:
        move.w (a0)+,(a1)+
        dbra d1,M4RmObjPal
        lea M4SphereCramMap0,a0 ;line 2: {Corneria, Fortuna}, line 3: {Titania,
        lea M4_BASE_CRAM+64,a1 ;Macbeth, Venom} (colour 1 = margin black)
        moveq #31,d1
M4RmSphereCram:
        move.w (a0)+,(a1)+
        dbra d1,M4RmSphereCram
        clr.w M4_BASE_CRAM+98 ;line 3 colour 1 black (margin tiles)
        lea M4_BASE_CRAM,a0
        lea M4_RM_CRAM,a1
        moveq #63,d1
M4RmCramSave:
        move.w (a0)+,(a1)+
        dbra d1,M4RmCramSave
        clr.w M4_TITLE_SPRITE
        clr.l M4_LV_SATREADY
        move.w #1,M4_LEVEL_HUD ;SAT chained after the footer mask
        move.w #1,M4_BOSS_SCROLL
        move.w #1,M4_BOSS_SCROLL_PRESENT
        clr.w M4_BG_HSCROLL
        rts
M4_RM_OBJ_VRAM equ M4_SCR_ROUTEMAP_VRAM+M4_SCR_ROUTEMAP_TILES*32

; Sprites (M4LevelHudSprites hook, M4_SCREEN 3): spriteblk entries 0..27
; with a visible character (2..31) as 8x8 sprites. Original OBJ priority3
; (the ship) is high; comet/route markers stay low. OBJ palette 7 is on
; CRAM line 1, flips from the attribute; none while TM = 1. a1 = SAT
; buffer, d7 = next sprite number (as M4ScTextSprites).
M4RmSprites:
        tst.b M4_RM_HIDE
        bne M4RmSprDone
        lea M4_RM_OAM,a0
        moveq #27,d6
M4RmSprEntry:
        moveq #0,d0
        move.b 2(a0),d0
        cmpi.b #2,d0
        blo.s M4RmSprNext
        cmpi.b #31,d0
        bhi.s M4RmSprNext
        moveq #0,d1
        move.b 1(a0),d1
        addi.w #128,d1
        move.w d1,(a1)+ ;y
        addq.w #1,d7
        move.w d7,(a1)+ ;size 8x8, link
        subq.w #2,d0
        addi.w #M4_RM_OBJ_VRAM/32,d0
        ori.w #$2000,d0 ;line 1; priority translated from the original attribute
        move.b 3(a0),d1 ;SNES attribute: bit6 h-flip, bit7 v-flip
        btst #5,d1 ;ship uses original OBJ priority3 ($3E), comet priority1
        beq.s M4RmSprPriority
        bset #15,d0
M4RmSprPriority:
        btst #6,d1
        beq.s M4RmSprNoH
        bset #11,d0
M4RmSprNoH:
        btst #7,d1
        beq.s M4RmSprNoV
        bset #12,d0
M4RmSprNoV:
        move.w d0,(a1)+
        moveq #0,d1
        move.b (a0),d1
        addi.w #128,d1
        move.w d1,(a1)+ ;x
M4RmSprNext:
        addq.l #4,a0
        dbra d6,M4RmSprEntry
M4RmSprDone:
        rts


; ---------------------------------------------------------------------
; Planets (SVP cmd8 types 9/10 of tools/generate-svp-sphere.py through SVP10
; face kind 34, one raw record each): the map (drawplanetsprites 03:CA67,
; every planet in its cell), the chosen planet alone and scrolled to the
; centre (drawselectedplanet + calcdxdy 03:C08F..C115) and Pepper's zoom
; (drawplanetincentre 03:CA08, centre (128, 104)). Atlas coordinates (xc, yc)
; keep the dither of the original; MD bitmap row = SNES line - 17 (MD line =
; SNES line - 1, as plane B with vscroll 1). Drawn first in the image, then
; Pepper's texts. The original redraws only the spheres per pass and leaves
; the sprites in the bitmap; the port clears its bitmap each image and draws
; both (same picture).
M4RmDrawHook:
        move.b M4_RM_STATE,d0
        cmpi.b #RM_ONLYPLANET,d0
        blo.s M4RmHookAll
        cmpi.b #RM_SCROLL,d0
        bls.s M4RmHookOne
        bsr M4RmZoomPlanet
        move.b M4_RM_STATE,d0
        cmpi.b #RM_NAME,d0
        beq M4RmPepperDraw
        cmpi.b #RM_MESSAGE,d0
        beq M4RmPepperDraw
        cmpi.b #RM_EXIT,d0
        beq M4RmPepperDraw
        rts
M4RmHookAll:
        moveq #0,d7 ;planet k
M4RmHookPlanet:
        moveq #0,d5
        moveq #0,d6
        bsr M4RmMapPlanet
        addq.w #1,d7
        cmpi.w #16,d7
        blo.s M4RmHookPlanet
        rts
; ONLY_PLANET / SCROLL: the chosen planet, its cell moved by bg1scr.
M4RmHookOne:
        moveq #0,d7
        move.b M4_GS_CURPLANET,d7
        moveq #0,d5
        moveq #0,d6
        cmpi.b #RM_SCROLL,d0
        bne.s M4RmHookOneDraw
        moveq #32,d0 ;step i = 32 - frames left (0..31)
        sub.w M4_RM_COUNT,d0
        cmpi.w #31,d0
        bls.s M4RmHookStep
        moveq #31,d0
M4RmHookStep:
        move.w d7,d1 ;M4RmScrollTab + planet * 128 + step * 4
        lsl.w #7,d1
        add.w d0,d0
        add.w d0,d0
        add.w d0,d1
        lea M4RmScrollTab,a0
        move.w (a0,d1.w),d5 ;bg1scrx
        move.w 2(a0,d1.w),d6 ;bg1scry
M4RmHookOneDraw:
; d7 = planet, d5/d6 = BG1 scroll subtracted from its screen position.
M4RmMapPlanet:
        movem.l d0-d7/a0-a2,-(sp)
        move.w d7,d0
        add.w d0,d0
        add.w d0,d0
        lea M4RmPlanetJob,a0
        adda.w d0,a0 ;kind, id, line, rot
        tst.b (a0)
        beq M4RmMapPlanetDone
        lea M4RmPlanetPos,a1 ;(cell word, X | Y << 8) per planet
        move.w 2(a1,d0.w),d1 ;pixel X | Y << 8
        moveq #0,d2
        move.b d1,d2 ;px
        lsr.w #8,d1 ;py
        lea M4_RM_REC,a2
        move.w d7,d3
        andi.w #3,d3
        lsl.w #5,d3 ;32 * (k mod 4)
        move.w d7,d4
        lsr.w #2,d4
        lsl.w #5,d4 ;32 * (k div 4)
        move.w d3,d0
        addi.w #16,d0
        move.w d0,2(a2) ;xc
        move.w d4,d0
        addi.w #16,d0
        move.w d0,4(a2) ;yc
        move.w d2,d0
        sub.w d3,d0
        sub.w d5,d0
        move.w d0,6(a2) ;dx
        move.w d1,d0
        subi.w #17,d0
        sub.w d4,d0
        sub.w d6,d0
        move.w d0,8(a2) ;dy
        cmpi.b #1,(a0)
        bne.s M4RmMapSprite
        move.w #9,(a2)
        move.w #15,10(a2) ;radius
        moveq #0,d0
        move.b 1(a0),d0
        move.w d0,d3
        lsl.w #8,d3
        or.w d3,d0 ;texture | map LUT << 8
        move.w d0,12(a2)
        move.w #$7800,14(a2)
        bsr M4RmSphereRec1 ;d2 bigx, d1 bigy, a0 job
        bra.s M4RmMapPlanetSend
M4RmMapSprite:
        move.w #10,(a2)
        clr.w 10(a2) ;mdrawsprite32
        moveq #0,d0
        move.b 1(a0),d0
        move.w d0,12(a2)
        clr.w 14(a2)
        bsr M4RmRawRecord
M4RmMapPlanetDone:
        movem.l (sp)+,d0-d7/a0-a2
        rts
M4RmMapPlanetSend:
        bsr M4RmRawRecord
        lea M4_RM_REC+16,a2
        bsr M4RmRawRecord2
        bra.s M4RmMapPlanetDone
; Second sphere record: rotx 0, roty[rot], planet_rotz[rot], light - (bigx,
; bigy, 0), ytop 0, ybot $7F. d2 = bigx, d1 = bigy, a0 = job.
M4RmSphereRec1:
        lea M4_RM_REC+16,a1
        clr.w (a1)
        moveq #0,d0
        move.b 3(a0),d0
        add.w d0,d0
        lea M4_RM_ROTY,a2
        move.w (a2,d0.w),2(a1)
        lea M4RmPlanetRotZ,a2
        move.w (a2,d0.w),4(a1)
        move.w M4_RM_LPOS,d0
        sub.w d2,d0
        move.w d0,6(a1)
        move.w M4_RM_LPOS+2,d0
        sub.w d1,d0
        move.w d0,8(a1)
        move.w M4_RM_LPOS+4,10(a1)
        clr.w 12(a1)
        move.w #$7f,14(a1)
        lea M4_RM_REC,a2
        rts
; Face kind 34 with the 8 WORDs at a2 (SVP10 copies them as one cmd8 record).
M4RmRawRecord:
        lea M4_RM_REC,a2
M4RmRawRecord2:
        movem.l d0-d3/a1-a2,-(sp)
        movea.l a2,a1
        move.w #34,d1
        move.w (a1)+,d2
        move.w (a1)+,d3
        jsr M4RadioRecord ;a2 = face packet (kind 34, words 0..1)
        move.l (a1)+,12(a2)
        move.l (a1)+,16(a2)
        move.l (a1)+,20(a2)
        movem.l (sp)+,d0-d3/a1-a2
        rts
; Pepper's zoom: the chosen planet at the centre with the zoom radius (zoom
; LUT 5 + id), or musprite of size radius + 17; centre (128, 104): dx 64,
; dy 104 - 17 - 64 = 23. The light of the iteration is M4_RM_LPOS.
M4RmZoomPlanet:
        movem.l d0-d7/a0-a2,-(sp)
        moveq #0,d7
        move.b M4_GS_CURPLANET,d7
        move.w d7,d0
        add.w d0,d0
        add.w d0,d0
        lea M4RmPlanetJob,a0
        adda.w d0,a0
        tst.b (a0)
        beq M4RmZoomPlanetDone
        lea M4RmPlanetPos,a1
        move.w 2(a1,d0.w),d1
        moveq #0,d2
        move.b d1,d2 ;bigx
        lsr.w #8,d1 ;bigy
        lea M4_RM_REC,a2
        move.w #64,2(a2)
        move.w #64,4(a2)
        move.w #64,6(a2)
        move.w #23,8(a2)
        move.w M4_RM_RADIUS,d0
        cmpi.b #1,(a0)
        bne.s M4RmZoomSprite
        move.w #9,(a2)
        move.w d0,10(a2)
        moveq #0,d0
        move.b 1(a0),d0
        move.w d0,d3
        addq.w #5,d3
        lsl.w #8,d3
        or.w d3,d0 ;texture | (5 + id) << 8
        move.w d0,12(a2)
        move.w #$7800,14(a2)
        bsr M4RmSphereRec1
        bsr M4RmRawRecord
        lea M4_RM_REC+16,a2
        bsr M4RmRawRecord2
        bra.s M4RmZoomPlanetDone
M4RmZoomSprite:
        move.w #10,(a2)
        addi.w #17,d0
        move.w d0,10(a2) ;musprite size radius + 17
        moveq #0,d0
        move.b 1(a0),d0
        move.w d0,12(a2)
        clr.w 14(a2)
        bsr M4RmRawRecord
M4RmZoomPlanetDone:
        movem.l (sp)+,d0-d7/a0-a2
        rts
; ONLY_PLANET: plane A back to the VR map (CRAM line 2 everywhere) with the
; chosen planet's colours on line 2 (its map line, or row 6 for a sprite).
M4RmPlanetAlone:
        movem.l d0-d1/a0-a2,-(sp)
        moveq #0,d0
        jsr M4CtlPlaneA
        moveq #0,d0
        move.b M4_GS_CURPLANET,d0
        add.w d0,d0
        add.w d0,d0
        lea M4RmPlanetJob,a0
        move.b 2(a0,d0.w),d0 ;CRAM line of the map cell
        lea M4SphereCramMap0,a0
        cmpi.b #2,d0
        beq.s M4RmAloneCram
        lea M4SphereCramMap1,a0
        cmpi.b #3,d0
        beq.s M4RmAloneCram
        lea M4_RM_CRAM,a0 ;sprite: row 6 = plane B line 0 of the map
M4RmAloneCram:
        lea M4_BASE_CRAM+64,a1
        lea M4_RM_CRAM+64,a2
        moveq #15,d1
M4RmAloneCopy:
        move.w (a0),(a1)+
        move.w (a0)+,(a2)+
        dbra d1,M4RmAloneCopy
        st M4_RM_SHOWNFADE
        movem.l (sp)+,d0-d1/a0-a2
        rts

M4RmIrqSin: ;02:AAD9 signed sine table (256 bytes) of the planets IRQ
        incbin '../build/routemap-irqsin.bin'
M4RmSpinSpeeds: ;03:C593 roty speeds (6 WORDs)
        include '../build/routemap-spin.inc'
        include '../build/routemap-data.inc'
        include '../build/screen-routemap.inc'
        include '../build/screen-pepper.inc'
        include 'screens/routemap_native.asm'
        include '../build/agent-sphere/sphere-cram.inc'
        even

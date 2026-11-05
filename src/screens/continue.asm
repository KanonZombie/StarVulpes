; CONTINUE screen foxy_continue_l 03:E3C7 (build/agent-continue/CONTINUE.md,
; build/research/screens-and-flow.md 8.3..8.5). Entered after GAME OVER.
; credits == 0: setnoclash, jml restart 1F:BDEE (controls screen with GAME).
; Otherwise: lives = 3; BG2 bgfoxccr/bgfoxpcr on plane B (vscroll 1 = BG2
; VOFS 0), OBJ fobjccr (Fox's eyes/arm/foot, cursor), the Arwing my_demo
; drawn by the SVP through the level draw path (mshowobj3 01:840A: m_bigx =
; m_bigy = 0, m_bigz, m_rotx/y/z, vanishing point (76, 92) of the 224x192
; window). Passes (main loop 03:E614): foxytrans 03:E772 = fox_sprites_l
; 03:E8C2, drawsome3d 03:E79F (draw, then m_rot += foxy_xa/ya/za), then the
; input logic. Pad: foxirq3 02:8722 stores the raw joypad ($4218, no c_type
; mapping, no getcont0) at $1201 and trig0 = new presses at each transfer.
; Deliberate differences (CONTINUE.md): my_demo (sh_shift 1) is drawn as
; my_demoS (same points/faces/colours, shift 0) at view z = m_bigz / 2
; (equal projection); m_clrbitmaps 0 (A held) does not keep the old bitmap;
; the second pad shape selector (debug) is absent; music and sounds; fades
; follow the elapsed VBlanks of each published image; the BG2 priority mask
; of the GSU layer is per plane A cell (1 line at the bottom edge of a cell).

M4_CN equ $ff5d00 ;screen-only (the game over CRAM copy M4_GO_CRAM is dead here)
M4_CN_PHASE equ M4_CN+0 ;.b 0 foxytrans x2 at INIDISP 0, 1 fade in, 2 loop, 3 fade out
M4_CN_EXIT equ M4_CN+1 ;.b 1 YES (.yahay 03:E746), 2 NO (.end 03:E716)
M4_CN_COUNT equ M4_CN+2 ;.w first passes left / fade-out frames
M4_CN_BRIGHT equ M4_CN+4 ;.b INIDISP brightness of the image
M4_CN_OPTION equ M4_CN+5 ;.b $12 foxy_option (0 YES, $FF NO)
M4_CN_FRAME equ M4_CN+6 ;.b $14 foxy_frame
M4_CN_FOOT equ M4_CN+7 ;.b $1C foxy_foot
M4_CN_XA equ M4_CN+8 ;.b $16 foxy_xa
M4_CN_YA equ M4_CN+9 ;.b $18 foxy_ya
M4_CN_ZA equ M4_CN+10 ;.b $1A foxy_za
M4_CN_FLAG equ M4_CN+11 ;.b $22 foxy_flag (second pad latch)
M4_CN_ROT equ M4_CN+12 ;3 BYTEs m_rotx/y/z 70:0020/22/24 (high bytes 0)
M4_CN_LASTSEL equ M4_CN+15 ;.b 7E:F0CE lastselected
M4_CN_BIGZ equ M4_CN+16 ;.w 70:002A m_bigz
M4_CN_PAD equ M4_CN+18 ;.w $1201 word: raw pad of the last transfer
M4_CN_TRIG equ M4_CN+20 ;.w $1209 trig0 (new presses)
M4_CN_CLR equ M4_CN+22 ;.b 70:01B2 m_clrbitmaps
M4_CN_SHOWN equ M4_CN+23 ;.b credit digit in plane B ($FF: none)
M4_CN_LASTCLOCK equ M4_CN+24 ;.w M4_CLOCK at the previous image
M4_CN_OBJ equ M4_CN+28 ;.l the Arwing object
M4_CN_OAM equ M4_CN+32 ;37 x (x, y, chr, attr): spriteblk 7E:1263 entries 0..36
M4_CN_SIZE equ 32+37*4
M4_CN_OBJ_VRAM equ M4_SCR_CONTINUE_VRAM+M4_SCR_CONTINUE_TILES*32
M4_CN_DIGIT equ $e000+(24*32+29)*2 ;VRAM $731D = BG2 map row 24, column 29

M4ContinueStart:
        jsr M4SoundStopLoops
        tst.b M4_GM_CREDITS ;03:E3D1: credits == 0 -> .end2: jml restart
        bne.s M4CnGo
        jmp M4ControlsStart
M4CnGo:
        jsr M4PipeFlush
        beq.s M4CnOk1
        jmp M4IntroFailed
M4CnOk1:
        move.w M4_SCENE_TICK,d0
        jsr M4VRWaitPresented
        beq.s M4CnOk2
        jmp M4IntroFailed
M4CnOk2:
        move.b #4,M4_SCREEN
        move.l #$ffdcfffc,M4_GEO_VP ;m_vanishx 76, m_vanishy 92 (03:E7C5/E7CC)
        clr.l M4_TX_HOOK
        move.l M4_RNG,-(sp) ;foxy_continue_l 03:E3C7 does not run initgame_l: random_l is kept
        jsr M4LevelInit ;M4CnVideoInit for M4_SCREEN 4
        move.l (sp)+,M4_RNG
        move.b #3,M4_LP_LIVES ;03:E44B lives = numlives
        move.b #3,M4_GS_LIVES
        lea LV_PLAYER,a0 ;no player: invisible, no strategy, no collision
        clr.l 32(a0)
        ori.b #3,49(a0)
        bclr #F2_SHADOW,48(a0)
        clr.b M4_SC_MMETERS
        move.b #2,M4_SC_VIEWTYPE ;fixed view at (0,0,0): W = R(0,0,0)
        clr.l M4_SC_VIEWPOS
        clr.w M4_SC_VIEWPOS+4
        clr.w M4_LP_OUTVX
        clr.w M4_LP_OUTVY
        clr.b M4_SC_DOTS
        move.l #M4DepthNormal,M4_SC_DEPTH ;set_zdepthtable normal (70:0050 = $8FAA)
        clr.l M4_LV_CREATOR
        jsr M4LevelAlloc
        move.l a0,d0
        bne.s M4CnObjOk
        jmp M4IntroFailed
M4CnObjOk:
        move.l a0,-(sp)
        lea M4_CN,a1
        moveq #M4_CN_SIZE/4-1,d0
M4CnClear:
        clr.l (a1)+
        dbra d0,M4CnClear
        move.l (sp)+,a0
        move.l a0,M4_CN_OBJ
        move.l #M4_SH_MY_DEMOS,d0 ;descriptor index may exceed 127 ;foxy_shape my_demo 00:BCD0 (see header)
        jsr M4LevelSetShape
        clr.b 45(a0) ;no atzremove
        ori.b #1,49(a0) ;colldisable
        ; 03:E450..E489: option, frame, foot 0; m_bigz 350; xa 0, ya 4, za 0;
        ; m_rot 0; cont0l/cont1l/trig0/trig1 0. lastselected is not written
        ; (stale in the original): 0 here.
        move.w #350,M4_CN_BIGZ
        move.b #4,M4_CN_YA
        move.b #1,M4_CN_CLR
        st M4_CN_SHOWN
        move.w M4_CLOCK,M4_CN_LASTCLOCK
        bsr M4CnFoxSprites ;03:E541 fox_sprites_l during the setup (foot, random_l)
        move.w #2,M4_CN_COUNT ;03:E5F2/E5F6: foxytrans twice at INIDISP 0
        move.w #6,INTRO_DIAG+4
M4CnLoop:
        bsr M4CnTick
        jsr M4LevelDraw
        move.w d0,INTRO_DIAG+8
        tst.w d0
        beq.s M4CnOk3
        jmp M4IntroFailed
M4CnOk3:
        moveq #0,d1
        jsr M4IntroPhaseEnd
        moveq #0,d0
        jsr M4TextVideoDraw
        move.w d0,INTRO_DIAG+10
        tst.w d0
        beq.s M4CnOk4
        jmp M4IntroFailed
M4CnOk4:
        addq.w #1,INTRO_DIAG+6
        jsr M4IntroTimingPublish
        moveq #0,d0
        move.b M4_CN_BRIGHT,d0
        or.b M4_SC_PALVER,d0
        move.b d0,M4_BRIGHT
        jsr M4LevelHudSprites ;M4CnSprites for M4_SCREEN 4
        move.w M4_LV_GAMEFRAME,M4_LV_DIAG+4
        cmpi.b #3,M4_CN_PHASE
        bne.s M4CnCapture
        tst.b M4_CN_BRIGHT
        beq.s M4CnExit
M4CnCapture:
        cmpi.w #2,INTRO_CAPTURE
        bne.s M4CnCaptureWait
        move.w #1,INTRO_CAPTURE
        bra M4CnLoop
M4CnCaptureWait:
        tst.w INTRO_CAPTURE
        bne.s M4CnCapture
        bra M4CnLoop
; Faded to 0: YES -> rtl to gameover_l -> jml planetseq_l (route, stage,
; specbuf and the team are kept); NO -> setnoclash, jml restart 1F:BDEE.
M4CnExit:
        jsr M4PipeFlush
        beq.s M4CnOk5
        jmp M4IntroFailed
M4CnOk5:
        jsr M4VRSceneBegin
        moveq #0,d0
        jsr M4CtlPlaneA ;plane A of the VR pipeline again
        clr.b M4_SCREEN
        clr.l M4_GEO_VP
        lea $ffff00,sp
        cmpi.b #1,M4_CN_EXIT
        bne.s M4CnExitNo
        jmp M4PlanetSeq
M4CnExitNo:
        move.b #1,M4_CTL_DEFTRAIN ;as left by gameover_l (defaulttrain = contexit = 1)
        move.b #1,M4_CTL_EXIT
        jmp M4ControlsStart

; One image. Passes run in phases 0 and 2; the fades of 03:E5FA (INIDISP
; 1..15) and 03:E724/E751 (15..0) are one step per VBlank in the original,
; here the steps of the VBlanks elapsed since the previous image.
M4CnTick:
        movem.l d0-d7/a0-a6,-(sp)
        move.w M4_CLOCK,d7
        move.w d7,d0
        sub.w M4_CN_LASTCLOCK,d7
        move.w d0,M4_CN_LASTCLOCK
        tst.w INTRO_CAPTURE
        beq.s M4CnRate
        moveq #4,d7 ;capture mode: fixed rate
M4CnRate:
        tst.w d7
        bgt.s M4CnRateOk
        moveq #1,d7
M4CnRateOk:
        jsr M4LevelReadPad
        addq.w #1,M4_LV_GAMEFRAME ;drawsome3d inc gameframe (m_framenum/m_colframe)
        move.b M4_CN_PHASE,d0
        beq.s M4CnFirst
        cmpi.b #1,d0
        beq.s M4CnFadeIn
        cmpi.b #2,d0
        beq.s M4CnMain
        add.w d7,M4_CN_COUNT ;fade out: 15 after the first VBlank ... 0 after 16
        moveq #16,d0
        sub.w M4_CN_COUNT,d0
        bpl.s M4CnFadeOutPos
        moveq #0,d0
M4CnFadeOutPos:
        cmpi.w #15,d0
        bls.s M4CnFadeOutSet
        moveq #15,d0
M4CnFadeOutSet:
        move.b d0,M4_CN_BRIGHT
        bra.s M4CnView
M4CnFirst:
        bsr M4CnSample
        bsr M4CnPassDraw
        subq.w #1,M4_CN_COUNT
        bne.s M4CnView
        move.b #1,M4_CN_PHASE
        bra.s M4CnView
M4CnFadeIn: ;the image drawn by the second pass stays (no pass runs)
        add.b d7,M4_CN_BRIGHT
        cmpi.b #15,M4_CN_BRIGHT
        blo.s M4CnView
        move.b #15,M4_CN_BRIGHT
        move.b #2,M4_CN_PHASE
        bra.s M4CnView
M4CnMain:
        bsr M4CnSample
        bsr M4CnPassDraw
        bsr M4CnLogic
        tst.b M4_CN_EXIT
        beq.s M4CnView
        move.b #3,M4_CN_PHASE
        clr.w M4_CN_COUNT
        cmpi.b #1,M4_CN_EXIT
        bne.s M4CnView
        move.b #3,M4_LP_LIVES ;03:E748 lives = 3; playerstart_init_l 0B:D2EF
        move.b #3,M4_GS_LIVES ;runs with every level start (M4LevelPlayerInit)
M4CnView:
        jsr M4LevelView ;fixed view: W = R(0,0,0)
        move.w M4_LV_GAMEFRAME,M4_SCENE_TICK
        bsr M4CnCredit
        movem.l (sp)+,d0-d7/a0-a6
        rts

; foxirq3 02:8722: trig0 = joy & (joy ^ [$1201]); [$1201] = joy (raw: the
; c_type swaps of M4LevelReadPad are undone, getcont0 does not run here).
M4CnSample:
        move.w M4_LP_JOY,d0
        move.b M4_CTL_TYPE,d1
        btst #0,d1
        beq.s M4CnSampleBY
        move.w d0,d2
        lsr.w #1,d2
        eor.w d0,d2
        andi.w #$4000,d2 ;B != Y: swap them back
        beq.s M4CnSampleBY
        eori.w #$c000,d0
M4CnSampleBY:
        btst #1,d1
        beq.s M4CnSampleUD
        move.w d0,d2
        lsr.w #1,d2
        eor.w d0,d2
        andi.w #$0400,d2 ;up != down: swap them back
        beq.s M4CnSampleUD
        eori.w #$0c00,d0
M4CnSampleUD:
        move.w M4_CN_PAD,d1
        eor.w d0,d1
        and.w d0,d1
        move.w d1,M4_CN_TRIG
        move.w d0,M4_CN_PAD
        rts

; foxytrans_l 03:E772: fox_sprites_l, then drawsome3d 03:E79F (the object
; takes m_rot and m_bigz; after the GSU call m_rot += foxy_xa/ya/za, bytes).
M4CnPassDraw:
        bsr M4CnFoxSprites
        movea.l M4_CN_OBJ,a0
        move.b M4_CN_ROT,12(a0)
        move.b M4_CN_ROT+1,13(a0)
        move.b M4_CN_ROT+2,14(a0)
        clr.l (a0)
        move.w M4_CN_BIGZ,d0
        lsr.w #1,d0 ;my_demo shift 1 = my_demoS at half the distance
        addq.w #1,d0 ;rel.W: floor(z * $7FFE / $8000) = z - 1 for 0 < z <= 16384
        move.w d0,4(a0)
        lea M4_CN_ROT,a0
        move.b M4_CN_XA,d0
        add.b d0,(a0)+
        move.b M4_CN_YA,d0
        add.b d0,(a0)+
        move.b M4_CN_ZA,d0
        add.b d0,(a0)
        rts

; Main loop logic 03:E618..E713 after the pass. Pad bits (SNES word):
; [$1202] = high byte (B Y Sel St U D L R), [$1201] = low (A X L R).
M4CnLogic:
        move.w M4_CN_PAD,d1
        move.b M4_CN_FRAME,d0
        beq.s M4CnNoInc
        addq.b #1,M4_CN_FRAME ;03:E61C inc, compare the old value
        cmpi.b #32,d0
        bne.s M4CnNotSelect
        move.b #1,M4_CN_EXIT ;.yahay 03:E746
        rts
M4CnNoInc:
        clr.b M4_CN_FLAG ;03:E628: no second pad ($1208 | $1206 = 0)
        btst #13,d1 ;Select held
        beq.s M4CnNotSelect
        tst.b M4_CN_LASTSEL
        bne.s M4CnNotSelect2
        not.b M4_CN_OPTION ;eor #255 (se_cursor $11)
        move.b #1,M4_CN_LASTSEL
        bra.s M4CnNotSelect2
M4CnNotSelect:
        clr.b M4_CN_LASTSEL
M4CnNotSelect2:
        btst #9,d1 ;left
        beq.s M4CnNoLeft
        addq.b #1,M4_CN_YA
M4CnNoLeft:
        btst #8,d1 ;right
        beq.s M4CnNoRight
        subq.b #1,M4_CN_YA
M4CnNoRight:
        btst #11,d1 ;up
        beq.s M4CnNoUp
        addq.b #1,M4_CN_XA
M4CnNoUp:
        btst #10,d1 ;down
        beq.s M4CnNoDown
        subq.b #1,M4_CN_XA
M4CnNoDown:
        btst #5,d1 ;[$1201] & $20: L -> m_bigz - 20 unless below 150
        beq.s M4CnNoZoomIn
        move.w M4_CN_BIGZ,d0
        subi.w #20,d0
        cmpi.w #150,d0
        blo.s M4CnNoZoomIn
        move.w d0,M4_CN_BIGZ
M4CnNoZoomIn:
        btst #4,d1 ;[$1201] & $10: R -> m_bigz + 20 while below 1000
        beq.s M4CnNoZoomOut
        move.w M4_CN_BIGZ,d0
        addi.w #20,d0
        cmpi.w #1000,d0
        bhs.s M4CnNoZoomOut
        move.w d0,M4_CN_BIGZ
M4CnNoZoomOut:
        moveq #1,d0 ;[$1201] & $80: A -> m_clrbitmaps 0
        btst #7,d1
        beq.s M4CnClrSet
        moveq #0,d0
M4CnClrSet:
        move.b d0,M4_CN_CLR
        move.w M4_CN_TRIG,d2
        btst #6,d2 ;X pressed: stop the spin
        beq.s M4CnNotX
        clr.b M4_CN_XA
        clr.b M4_CN_YA
        clr.b M4_CN_ZA
M4CnNotX:
        btst #12,d2 ;Start pressed
        beq.s M4CnNotStart
        tst.b M4_CN_OPTION
        beq.s M4CnStartYes
        move.b #2,M4_CN_EXIT ;.end (sound $10, startbgm $F1)
        M4PlaySfx $10
        rts
M4CnStartYes:
        tst.b M4_CN_FRAME
        bne.s M4CnNotStart
        subq.b #1,M4_GM_CREDITS ;dec credits; inc foxy_frame (sound $67, startbgm $F1)
        M4PlaySfx $67
        addq.b #1,M4_CN_FRAME
M4CnNotStart:
        rts

; fox_sprites_l 03:E8C2: cursor (entry 36), arm (14..), eyes (0.., only with
; foxy_frame >= 8), foot (30..), then the foot tap state with random_l.
M4CnFoxSprites:
        movem.l d0-d1/a0-a1,-(sp)
        lea M4_CN_OAM+36*4,a1
        moveq #45,d0
        tst.b M4_CN_OPTION
        beq.s M4CnCursorX
        moveq #93,d0
M4CnCursorX:
        move.b d0,(a1)+
        move.b #179,(a1)+
        move.b #$bc,(a1)+ ;foxcursor $3C + spradd
        move.b #$30,(a1)
        moveq #0,d0
        move.b M4_CN_FRAME,d0
        andi.w #$fe,d0
        cmpi.w #8,d0
        blo.s M4CnArm
        moveq #6,d0
M4CnArm:
        lea M4CnFoxArmAnim,a0
        bsr M4CnAnimWord
        lea M4_CN_OAM+14*4,a1
        bsr M4CnCopy
        move.b M4_CN_FRAME,d0
        subq.b #8,d0
        bmi.s M4CnNoEyes
        andi.w #$fe,d0
        cmpi.w #8,d0
        blt.s M4CnEyes
        moveq #6,d0
M4CnEyes:
        lea M4CnFoxEyeAnim,a0
        bsr M4CnAnimWord
        lea M4_CN_OAM,a1
        bsr M4CnCopy
M4CnNoEyes:
        moveq #7,d0
        and.b M4_CN_FOOT,d0
        add.w d0,d0
        lea M4CnFoxFootAnim,a0
        bsr M4CnAnimWord
        lea M4_CN_OAM+30*4,a1
        bsr M4CnCopy
        moveq #7,d0
        and.b M4_CN_FOOT,d0
        beq.s M4CnFootIdle
        addq.b #1,M4_CN_FOOT
        bra.s M4CnFootDone
M4CnFootIdle:
        btst #7,M4_CN_FOOT
        beq.s M4CnFootNorm
        jsr M4IntroRandom ;random_l 02:FC4A
        andi.b #31,d0
        bne.s M4CnFootDone
        move.b #$81,M4_CN_FOOT
        bra.s M4CnFootDone
M4CnFootNorm:
        jsr M4IntroRandom
        andi.b #127,d0
        bne.s M4CnFootDone
        addq.b #8,M4_CN_FOOT
M4CnFootDone:
        movem.l (sp)+,d0-d1/a0-a1
        rts
; a0 table, d0.w byte index -> a0 = foxsprites + little-endian offset WORD.
M4CnAnimWord:
        move.b 1(a0,d0.w),d1
        lsl.w #8,d1
        move.b (a0,d0.w),d1
        lea M4CnFoxBase,a0
        adda.w d1,a0
        rts
; copyfoxsprites 03:E967: (x, y, chr) until x = $FF, attribute $30.
M4CnCopy:
        move.b (a0)+,d1
        cmpi.b #$ff,d1
        beq.s M4CnCopyEnd
        move.b d1,(a1)+
        move.b (a0)+,(a1)+
        move.b (a0)+,(a1)+
        move.b #$30,(a1)+
        bra.s M4CnCopy
M4CnCopyEnd:
        rts

; Sprites (M4LevelHudSprites hook, M4_SCREEN 4): spriteblk entries 0..36 in
; OAM order (lowest first = in front), 8x8, priority. Screen row = OAM y
; (plane B is scrolled 1 line: BG2 row y + 1 on row y, measured on the
; captures). Entries with tiles outside fobjccr (cleared entries, the arm
; fillers $D4/$E0 at y 216) or outside the INIDISP window (rows 16..205)
; are not shown in the original and not emitted. a1 = SAT entry, d7 = its
; sprite number.
M4CnSprites:
        movem.l d0-d2/a0,-(sp)
        lea M4_CN_OAM,a0
        moveq #36,d2
M4CnSprEntry:
        moveq #0,d0
        move.b 2(a0),d0
        subi.w #$80,d0
        bmi.s M4CnSprSkip
        cmpi.w #M4_CN_OBJ_TILES,d0
        bhs.s M4CnSprSkip
        moveq #0,d1
        move.b 1(a0),d1
        cmpi.w #205,d1
        bhi.s M4CnSprSkip
        cmpi.w #16-7,d1
        blo.s M4CnSprSkip
        addi.w #128,d1
        move.w d1,(a1)+ ;y
        addq.w #1,d7
        move.w d7,(a1)+ ;1x1, link
        addi.w #$e000|(M4_CN_OBJ_VRAM/32),d0
        move.w d0,(a1)+ ;priority, line 3
        moveq #0,d1
        move.b (a0),d1
        addi.w #128,d1
        move.w d1,(a1)+ ;x
M4CnSprSkip:
        addq.l #4,a0
        dbra d2,M4CnSprEntry
        movem.l (sp)+,d0-d2/a0
        rts

; foxirq3 02:8712: the CREDIT digit (credits + $3528 at VRAM $731D) on
; every transfer; written here when the value changes. Values above 9 have
; no converted cell (the cell keeps the previous digit).
M4CnCredit:
        moveq #0,d0
        move.b M4_GM_CREDITS,d0
        cmp.b M4_CN_SHOWN,d0
        beq.s M4CnCreditDone
        move.w d0,d1
        addi.w #$3528,d1
        lea M4ScrContinueExtra,a0
M4CnCreditFind:
        move.w (a0)+,d3
        beq.s M4CnCreditDone
        move.w (a0)+,d4
        cmp.w d1,d3
        bne.s M4CnCreditFind
        move.b d0,M4_CN_SHOWN
        move.w sr,-(sp)
        ori.w #$0700,sr
        move.w #M4_CN_DIGIT,d0
        jsr M4TextVideoWriteAddress
        move.w d4,VDP_DATA
        move.w (sp)+,sr
M4CnCreditDone:
        rts

; Video (instead of M4LevelVideoInit): plane B = BG2 (rows 0..31, vscroll 1),
; OBJ tiles after the BG tiles, CRAM lines 0/1 (BG2 rows 4/5), 2 (setpal_l 1
; 02:F456: CGRAM row 7 = 03:8ACA, the 3D colours), 3 (OBJ palette 0).
M4CnVideoInit:
        move.w sr,-(sp)
        ori.w #$0700,sr
        move.w #M4_SCR_CONTINUE_VRAM,d0
        jsr M4TextVideoWriteAddress
        lea M4ScrContinueTiles,a0
        move.w #M4_SCR_CONTINUE_TILES*8-1,d1
M4CnTiles:
        move.l (a0)+,VDP_DATA
        dbra d1,M4CnTiles
        move.w #M4_CN_OBJ_VRAM,d0
        jsr M4TextVideoWriteAddress
        lea M4CnObjTiles,a0
        move.w #M4_CN_OBJ_TILES*8-1,d1
M4CnObjTileCopy:
        move.l (a0)+,VDP_DATA
        dbra d1,M4CnObjTileCopy
        move.w #$e000,d0
        jsr M4TextVideoWriteAddress
        lea M4ScrContinueMap0,a0
        move.w #32*32/2-1,d1
M4CnMap:
        move.l (a0)+,VDP_DATA
        dbra d1,M4CnMap
        move.w #32*32/2-1,d1 ;rows 32..63 unused
M4CnMapClear:
        move.l #0,VDP_DATA
        dbra d1,M4CnMapClear
        move.w #$8731,VDP_CTRL
        move.w #$8b00,VDP_CTRL ;full-screen scroll (no tilt)
        move.w (sp)+,sr
        bsr M4CnPlaneA
        clr.w M4_LEVEL_TILT
        lea M4_BASE_CRAM,a1
        moveq #31,d1
M4CnCramClear:
        clr.l (a1)+
        dbra d1,M4CnCramClear
        lea M4ScrContinueCram,a0
        jsr M4CtlCram
        lea M4CnObjColours,a0
        jsr M4CtlCram
        moveq #1,d0 ;03:E427 setpal_l 1
        jsr M4LvGamepal
        clr.w M4_BASE_CRAM+98 ;line 3 colour 1 black (margin tiles)
        move.w #$eee,M4_BASE_CRAM+100
        clr.w M4_TITLE_SPRITE
        clr.l M4_LV_SATREADY
        move.w sr,-(sp)
        ori.w #$0700,sr
        move.w #$d800+13*8,d0
        jsr M4TextVideoWriteAddress
        move.l #0,VDP_DATA
        move.l #0,VDP_DATA
        move.w (sp)+,sr
        move.w #1,M4_LEVEL_HUD
        move.w #1,M4_BOSS_SCROLL ;BG2 VOFS 0
        move.w #1,M4_BOSS_SCROLL_PRESENT
        clr.w M4_BG_HSCROLL
        rts

; Plane A map (M4VRPlaneAMap) for this screen: in the bitmap rows of both
; pages (2..25 of each) the side margin columns become the transparent
; tile (setcharmapfox_l 03:E87A: BG1 border cells $2A0 show BG2), and the
; bitmap cells under a BG2 priority-1 cell (everything but the grid) lose
; their priority: BG2 pri 1 is in front of BG1 pri 0 (charmap $1C00).
M4CnPlaneA:
        movem.l d0-d4/a0-a1,-(sp)
        move.w sr,-(sp)
        ori.w #$0700,sr
        move.w #$c000,d0
        jsr M4TextVideoWriteAddress
        lea M4VRPlaneAMap,a0
        lea M4ScrContinueMap0,a1
        moveq #0,d3
M4CnPlaneACell:
        move.w (a0)+,d0
        move.w d3,d1
        lsr.w #5,d1 ;plane row
        cmpi.w #28,d1
        blo.s M4CnPlaneAPage
        subi.w #26,d1 ;page 1 starts at plane row 26
M4CnPlaneAPage:
        cmpi.w #2,d1
        blo.s M4CnPlaneAWrite
        cmpi.w #26,d1
        bhs.s M4CnPlaneAWrite
        cmpi.w #$e000|M4VR_MASK_TILE,d0
        bne.s M4CnPlaneAActive
        move.w #M4_SCR_CONTINUE_BLANK,d0
        bra.s M4CnPlaneAWrite
M4CnPlaneAActive:
        move.w d3,d4
        andi.w #31,d4
        lsl.w #5,d1
        add.w d1,d4
        add.w d4,d4
        tst.w (a1,d4.w) ;BG2 cell of this screen cell (MD priority = SNES priority)
        bpl.s M4CnPlaneAWrite
        andi.w #$7fff,d0
M4CnPlaneAWrite:
        move.w d0,VDP_DATA
        addq.w #1,d3
        cmpi.w #2048,d3
        blo.s M4CnPlaneACell
        move.w (sp)+,sr
        movem.l (sp)+,d0-d4/a0-a1
        rts

        include '../build/screen-continue.inc'
        include '../build/continue-obj.inc'

; Corneria 1 start: SCRAMBLE take-off (map1_1a 0D:8000) and ExitBase
; (0B:8EC5) from the level entry 0D:D068 to the restart point 0D:D209, plus
; the 2D level state they drive (stayblack, BG requests, m_meters, OBJ texts).
; Research: build/research/corneria-scramble.md (USA rev0, ROM disassembly and
; tools/scramble-oracle.py); correspondence in src/m4/LEVEL_ORIGIN.md.
; Field names: SNES object $0C/$0E/$10 = x/y/z (0/2/4), $12/$13/$14 =
; rotx/roty/rotz (12/13/14), $15 vel (15), $0A life (19), $22/$23 sbyte1/2
; (36/37), $24/$25 sbyte3/4 (X_SBYTE3/4), $26 sword1 (40), $20 bit3
; invisible (49 bit1), $1E bit0 no collision (49 bit0), $09 al_type (45).
M4_SC equ $fff280
M4_SC_VIEWTYPE equ M4_SC+0 ;.b $15CC viewtype (bit1 Fpos, bit0 toobj)
M4_SC_MMETERS equ M4_SC+1 ;.b 70:021C m_meters
M4_SC_VIEWPOS equ M4_SC+2 ;3 WORDs $C1/$C3/$C5 (viewtype bit1)
M4_SC_STAYBLACK equ M4_SC+8 ;.b $1964 stayblack
M4_SC_BLACKVAL equ M4_SC+9 ;.b $148B+7 blackfade subtraction (0..30)
M4_SC_SCRAMBLE equ M4_SC+10 ;.b $15B7 scramble
M4_SC_KEEPPSTRAT equ M4_SC+11 ;.b $1F07 keeppstrat
M4_SC_STAGECNT equ M4_SC+12 ;.w $15BB stagecnt
M4_SC_NEWPSTRAT equ M4_SC+14 ;.l $1788 newplayerstrat (port routine)
M4_SC_P1553 equ M4_SC+18 ;.b psvar_byte1 $1553
M4_SC_P1554 equ M4_SC+19 ;.b psvar_byte2 $1554
M4_SC_P1555 equ M4_SC+20 ;.b psvar_byte3 $1555
M4_SC_BGBLACK equ M4_SC+21 ;.b makeBG2black_l 02:F7E1 in effect (BG rows 0-6)
M4_SC_NOMAXBG equ M4_SC+22 ;.b $14CE nomaxbg2Yscroll
M4_SC_DOTS equ M4_SC+23 ;.b dotsflag (ground dots)
M4_SC_CIRCLE equ M4_SC+24 ;.w $16AD circleanim (wipe id, 0 = none)
M4_SC_WIPE equ M4_SC+26 ;.b $1FD3 doingwipe
M4_SC_WIPEREC equ M4_SC+27 ;.b wipe record shown this tick
M4_SC_LOOPS equ M4_SC+28 ;4 x (index.w, count.w): loop table $174D/$1745
M4_SC_BGSHOWN equ M4_SC+44 ;.b BG rows black in M4_BASE_CRAM
M4_SC_PALVER equ M4_SC+45 ;.b CRAM version bit (M4_BRIGHT bit6)
M4_SC_DEPTH equ M4_SC+46 ;.l zdepth table of the level path (set_zdepthtable)
M4_SC_PPOSX equ M4_SC+50 ;.w player_posx $150F (init_strats_l)
M4_SC_WIPETICK equ M4_SC+52 ;.w ticks since the wipe started
M4_SC_CIRCLEOBJ equ M4_SC+54 ;.w $16AB circleobj (object low WORD, 0 = centre)
M4_SC_BG2Y equ M4_SC+56 ;.w $169E bg2Yscroll (232; ClearDemo phase 2 -1 per tick)
M4_SC_PPOSY equ M4_SC+58 ;.w player_posy $1511 (init_strats_l)
M4_SC_VIEWTOOBJ equ M4_SC+60 ;.w $15A0 viewtoobj (object low WORD, 0 = the player)
M4_SC_SIZE equ 64
; Level-only timing state overlays dead intro fixture RAM, not object/path RAM.
M4_SC_TIME_ON equ $ffb000 ;WORD active only from playeropening to control
M4_SC_TIME_BASE equ $ffb002 ;WORD absolute VBlank origin (wrap-safe <32768)
M4_SC_TIME_COST equ $ffb004 ;last extra-image cost, whole VBlanks
M4_SC_TIME_TWEEN equ $ffb006 ;WORD visual-only draw, never a strategy pass
M4_SC_TIME_VALID equ $ffb008 ;previous tunnel pose available
M4_SC_TIME_CAMERA equ $ffb00a ;previous fixed camera xyz
M4_SC_TIME_SAVECAM equ $ffb010 ;current fixed camera xyz
M4_SC_TIME_EXTRA equ $ffb016 ;WORD extra images queued (DMA count measured separately)
M4_SC_TIME_STAMP equ $ffb018
X_DEPTHOFF equ -$8000+24 ;.b alx depthoffset ($1CDF): 1 -> table 03:8F9A
X_STATE equ -$8000+25 ;.b stratstate ($1CDC)
X_SCFLAGS equ -$8000+26 ;.b sflags2 $10 (companion boost done)
        include '../build/level-messages.inc'
M4_LEVEL_MSG_TILES equ $c000-M4_LEVEL_MSG_COUNT*32 ;OBJ texts at the top of the BG tile area

; Level 2D state after a (re)start: Corneria BG (1_1c) settings.
M4ScInit:
        lea M4_SC,a0
        moveq #M4_SC_SIZE/4-1,d0
M4ScInitClear:
        clr.l (a0)+
        dbra d0,M4ScInitClear
        move.b #1,M4_SC_MMETERS
        st M4_SC_STAYBLACK
        move.b #1,M4_SC_DOTS
        move.l #M4DepthStage1,M4_SC_DEPTH
        move.w #232,M4_SC_BG2Y
        rts

; ---------------------------------------------------------------------
; Map script helpers (level.asm consumers).

; d0 = VBlanks left until the NEXT original tick, or0 when due/unpaced.
; Absolute deadlines avoid accumulating DMA/CPU jitter. Never skip a tick
; to catch up. Capture/oracle controls retain their previous fixed-rate path.
M4ScTimingDelay:
        moveq #0,d0
        tst.w M4_SC_TIME_ON
        beq.s M4ScTimingReady
        tst.w INTRO_CAPTURE
        bne.s M4ScTimingReady
        cmpi.l #'OVLT',M4_OVL_MAGIC
        bne.s M4ScTimingLive
        btst #1,M4_OVL_CTL
        bne.s M4ScTimingReady
M4ScTimingLive:
        move.w M4_LV_GAMEFRAME,d0
        addq.w #1,d0
        cmpi.w #321,d0
        bhi.s M4ScTimingUnpaced
        add.w d0,d0
        lea M4ScTimingDeadlines,a0
        move.w (a0,d0.w),d0
        add.w M4_SC_TIME_BASE,d0
        sub.w M4_CLOCK,d0
        bgt.s M4ScTimingReady
M4ScTimingUnpaced:
        moveq #0,d0
M4ScTimingReady:
        rts

M4ScTimingWait:
        tst.w M4_SC_TIME_ON
        beq.s M4ScTimingWaitDone
        tst.w INTRO_CAPTURE
        bne.s M4ScTimingWaitDone
        jsr M4PipeFlush ;publish the previous image before its pacing wait
        tst.w d0
        beq.s M4ScTimingFlushed
        jmp M4IntroFailed
M4ScTimingFlushed:
        bsr.s M4ScTimingDelay
        tst.w d0
        beq.s M4ScTimingWaitDone
        add.w M4_CLOCK,d0
        move.w d0,d1
        move.w sr,-(sp)
M4ScTimingHold:
        stop #$2300 ;idle the 68000 bus; H-INT/VBlank and the Z80 keep running
        move.w M4_CLOCK,d0
        sub.w d1,d0
        bmi.s M4ScTimingHold
        move.w (sp)+,sr
M4ScTimingWaitDone:
        rts

        include '../build/scramble-cadence.inc'
        include 'level/scramble_tween.asm'

; 04 loop 03:F984: table keyed by the command index. First visit stores the
; count and jumps; later visits decrement and jump while nonzero, else free
; the slot and continue after the command (body runs count+1 times).
; a0 context, a1 bytes. Returns d0 = next index.
M4ScLoop:
        move.w (a0),d2
        lea M4_SC_LOOPS,a2
        moveq #3,d1
M4ScLoopFind:
        cmp.w (a2),d2
        beq.s M4ScLoopFound
        addq.l #4,a2
        dbra d1,M4ScLoopFind
        lea M4_SC_LOOPS,a2 ;first visit: a free slot
        moveq #3,d1
M4ScLoopFree:
        tst.w (a2)
        beq.s M4ScLoopNew
        addq.l #4,a2
        dbra d1,M4ScLoopFree
        moveq #-1,d0
        rts
M4ScLoopNew:
        move.w d2,(a2)
        moveq #0,d0
        move.b 4(a1),d0
        lsl.w #8,d0
        move.b 3(a1),d0
        move.w d0,2(a2)
        bra.s M4ScLoopJump
M4ScLoopFound:
        subq.w #1,2(a2)
        bne.s M4ScLoopJump
        clr.l (a2)
        move.w d2,d0
        addq.w #5,d0
        rts
M4ScLoopJump:
        moveq #0,d0
        move.b 2(a1),d0
        lsl.w #8,d0
        move.b 1(a1),d0
        andi.w #$7fff,d0
        rts

; initblack_l 02:FD48: stayblack 40, blackfade 30, fade 0.
M4ScInitBlack:
        move.b #40,M4_SC_STAYBLACK
        move.b #30,M4_SC_BLACKVAL
        clr.b M4_FADE+1
        rts

; setblack_l 02:FD76 once per tick: count stayblack down, then remove the
; subtraction 2 by 2 (oncewipe = 1) and release ($FF).
M4ScSetBlack:
        move.b M4_SC_STAYBLACK,d0
        cmpi.b #$ff,d0
        beq.s M4ScSetBlackDone
        tst.b d0
        beq.s M4ScSetBlackFade
        subq.b #1,M4_SC_STAYBLACK
        rts
M4ScSetBlackFade:
        tst.b M4_SC_BLACKVAL
        bne.s M4ScSetBlackStep
        st M4_SC_STAYBLACK
        rts
M4ScSetBlackStep:
        subq.b #2,M4_SC_BLACKVAL
M4ScSetBlackDone:
        rts

; Wipe timing (02:DD49 + 02:E207): one record per tick from the tick after
; circleanim is written; doingwipe stays set one tick after the last record.
; 280 = mstarwipe (16 records), 270 = mscramwipe (12), $39 = smartbomb
; (nova bomb screen circle 02:E0BC: 46 calls, corneria-missing.md 1.4),
; 258 = mroundwipefill clock wipe (30 records, 14:8182), then 262 = the
; mwipefill loop: full black until the level is left (4.5).
M4ScWipeTick:
        move.w M4_SC_CIRCLE,d0
        beq.w M4ScWipeEnd
        cmpi.w #262,d0
        bne.s M4ScWipeNotFill
        move.b #1,M4_SC_WIPE
        move.b #$fe,M4_SC_WIPEREC ;fill: all black
        rts
M4ScWipeNotFill:
        moveq #30,d1
        cmpi.w #258,d0
        beq.s M4ScWipeKnown
        moveq #16,d1
        cmpi.w #280,d0
        beq.s M4ScWipeKnown
        moveq #46,d1
        cmpi.w #$39,d0
        beq.s M4ScWipeKnown
        moveq #12,d1
        cmpi.w #270,d0
        bne.s M4ScWipeOff
M4ScWipeKnown:
        move.w M4_SC_WIPETICK,d0
        addq.w #1,M4_SC_WIPETICK
        move.b #1,M4_SC_WIPE
        move.b d0,M4_SC_WIPEREC
        cmp.w d1,d0
        blo.s M4ScWipeDone
        cmpi.w #258,M4_SC_CIRCLE
        bne.s M4ScWipeLast
        move.w #262,M4_SC_CIRCLE ;circleanim 261 -> 262 (mwipefill)
        move.b #$fe,M4_SC_WIPEREC
        rts
M4ScWipeLast:
        clr.w M4_SC_CIRCLE ;last tick: no record, doingwipe still 1
        st M4_SC_WIPEREC
        rts
M4ScWipeEnd:
        tst.b M4_SC_WIPE
        beq.s M4ScWipeDone
M4ScWipeOff:
        clr.b M4_SC_WIPE
        clr.w M4_SC_CIRCLE
        st M4_SC_WIPEREC
M4ScWipeDone:
        rts

; transswap 02:DAA3 at the end of the tick: bgflags bit2 = setbg request
; (dobgreq_l), bit3 = setbginfo request (setbginforeq_l 03:EFE6).
; Backgrounds used: 3 = bg_1_1i 03:905F (pstrat playeropening 0B:8004,
; m_meters 0, nodots, tunnel depth table 03:8FAE), 27 = bg_1_1c 03:910B
; (Corneria BG loaded again, dots, stage1 depth table 03:8FB6).
M4ScTransSwap:
        lea TEXT_MAP_CONTEXT,a0
        btst #2,11(a0)
        beq M4ScSwapInfo
        bclr #2,11(a0)
        move.w 12(a0),d0
        cmpi.w #3,d0
        bne.s M4ScSwapNot11i
        move.l #M4ScPlayerOpeningInit,M4_SC_NEWPSTRAT
        clr.b M4_SC_MMETERS
        clr.b M4_SC_DOTS
        move.l #M4DepthTunnel,M4_SC_DEPTH
        bra.s M4ScSwapInfo
M4ScSwapNot11i:
        cmpi.w #$ff,d0 ;bg cont (briefing_l contmap): pstrat playeroncont
        bne.s M4ScSwapNotCont
        move.l #M4CtlPlayerIstrat,M4_SC_NEWPSTRAT
        clr.b M4_SC_MMETERS
        bra.s M4ScSwapInfo
M4ScSwapNotCont:
        cmpi.w #$111,d0 ;training 03:9235 = bg_1_1c + playeronplanet, $14DD 0, $14DE 2
        bne.s M4ScSwapNotTraining
        move.l #M4ScOnPlanetNew,M4_SC_NEWPSTRAT
        move.w #120,M4_LP_VIEWDIST ;06:BA91 for $14DD = 0
        bra.s M4ScSwap11c
M4ScSwapNotTraining:
        cmpi.w #$21,d0 ;bg_1_2 03:92DF: Asteroid Belt space
        beq M4ScSwapSpace
        cmpi.w #27,d0
        beq.s M4ScSwap11c
        jsr M4LevelBgSwap ;other stage backgrounds (level_backgrounds.asm)
        beq.s M4ScSwapBad ;Z: number not in the table
        bra M4ScSwapInfo
M4ScSwap11c:
        clr.b M4_SPP_FM ;bg_1_1c / training: $14DD 0, $14DE 2
        move.b #2,M4_SPP_FMOPT
        clr.b M4_SC_BGBLACK ;palette rows of bg_1_1c loaded again
        move.l #M4DepthStage1,M4_SC_DEPTH
M4ScSwapInfo:
        btst #3,11(a0)
        beq.s M4ScSwapDone
        bclr #3,11(a0)
        move.w 12(a0),d0
        jsr M4LevelBgInfo ;table backgrounds: d1 = dotsflag (setbginfo 03:EFE6)
        bne.s M4ScSwapDots
        moveq #0,d1
        cmpi.w #3,d0
        beq.s M4ScSwapDots
        cmpi.w #$ff,d0 ;cont: no ground dots
        beq.s M4ScSwapDots
        cmpi.w #$21,d0 ;levelinfo $17 (03:EFDC): dotsflag $FF = stars (SVP_Stars), no grid
        bne.s M4ScSwapGrid
        moveq #-1,d1
        bra.s M4ScSwapDots
M4ScSwapGrid:
        moveq #1,d1 ;1_1c: dots, dozrot
M4ScSwapDots:
        move.b d1,M4_SC_DOTS
        tst.b M4_SC_KEEPPSTRAT
        bne.s M4ScSwapKeep
        move.l M4_SC_NEWPSTRAT,d0
        beq.s M4ScSwapDone
        move.l d0,LV_PLAYER+32
        rts
M4ScSwapKeep:
        clr.b M4_SC_KEEPPSTRAT
M4ScSwapDone:
        rts
M4ScSwapBad:
        move.w #-1,M4_LV_STATUS
        rts
; bg_1_2 03:92DF: BG2 space map (level_space_bg.asm), initmode2 zdepth
; 03:8FAA and gamepal 1 (03:8ACA, CGRAM row 7 = MD line 2) [stage-asteroid1.md
; annex], pstrat 0B:835B playerinsidespaceflyin (level_cockpit.asm).
M4ScSwapSpace:
        jsr M4SpaceBgLoad
        movem.l d1/a0-a1,-(sp)
        lea M4IntroTextPalette,a0
        lea M4_BASE_CRAM+64,a1
        moveq #15,d1
M4ScSwapSpacePal:
        move.w (a0)+,(a1)+
        dbra d1,M4ScSwapSpacePal
        movem.l (sp)+,d1/a0-a1
        eori.b #$40,M4_SC_PALVER
        clr.b M4_SC_BGBLACK
        move.l #M4DepthNormal,M4_SC_DEPTH
        move.l #M4SpInsideFlyinI,M4_SC_NEWPSTRAT ;0B:835B
        move.b #5,M4_SPP_FMOPT ;$14DE 5
        move.b #1,M4_SPP_FM ;$14DD 1, 06:BA91: viewdist 60
        jsr M4SpChangeView
        bra M4ScSwapInfo

; clearmap 1F:D3E0: every object except the player (playerobj) is removed.
M4ScClearMap:
        movem.l d0-d1/a0,-(sp)
        move.w M4_LV_HEAD,d0
M4ScClearNext:
        tst.w d0
        beq.s M4ScClearDone
        movea.w d0,a0
        move.w X_NEXT(a0),d0
        cmpa.w #LV_PLAYER&$ffff,a0 ;allst links are sign-extended WORDs
        beq.s M4ScClearNext
        move.w d0,-(sp)
        jsr M4LevelRemove
        move.w (sp)+,d0
        bra.s M4ScClearNext
M4ScClearDone:
        movem.l (sp)+,d0-d1/a0
        rts

; ---------------------------------------------------------------------
; Player strategies. a0 = player.

; playercred strategy 0B:B6EA before the first BG swap (initgame pass and
; the first tick): playermove 0B:E884 (= the planet body without control:
; gen_3dvecs, framescalevecs, add_vecs2pos) and viewmove 0B:D083; the
; invisible player advances (oracle: 63 Z per pass).
M4ScPlayerCred:
        jsr M4LevelPlayerTick
        moveq #0,d0
        rts

; playeropening_Istrat 0B:8004 (Ltunnel mode).
M4ScPlayerOpeningInit:
        ori.b #$60,M4_LP_PSF ;no control, no fire
        move.w #-60,M4_LP_VIEWCY
        move.w #-120,M4_LP_MINX
        move.w #120,M4_LP_MAXX
        move.w #-120,M4_PM_1575 ;$1575/$1577/$1581 (enemy shots; no port consumer)
        move.w #120,M4_PM_1577
        clr.w M4_PM_1581
        move.w #-120,M4_PM_157D ;wing roof/floor (M4PmWings)
        move.w #5,M4_PM_157F
        move.w #-120,M4_LP_MINY
        move.w #-20,M4_LP_MAXY
        move.b #9,M4_LP_FLYMODE
        st M4_LP_PMOVEAND
        andi.b #$df,M4_LP_GAMEFLAGS ;no viewrot
        andi.b #$fb,M4_BOSS_PSTRATF
        ori.b #2,M4_LP_PSF3
        andi.b #$fb,M4_LP_PSF2
        andi.b #$d7,M4_BOSS_PSTRATF
        bset #F2_SHADOW,48(a0)
        ori.b #1,M4_LP_PSF3
        clr.l X_COLL(a0) ;1F:D450
        clr.l X_EXP(a0)
        clr.w M4_LV_GAMEFRAME ;stz gameframe
        move.w #1,M4_SC_TIME_ON
        move.w M4_CLOCK,M4_SC_TIME_BASE
        move.b #2,M4_FADE ;fadedir 2
        move.w #$f800,M4_LP_OUTVX
        ori.b #1,M4_LP_GAMEFLAGS ;nozremove
        move.b #3,M4_SC_VIEWTYPE
        bclr #1,49(a0) ;visible (oracle trace)
        jsr M4LevelAlloc ;viewopening: nullshape, inserted after the player
        move.l a0,d0
        movea.l a0,a2
        movea.l M4_LV_CREATOR,a0
        beq.s M4ScOpeningNoView
        move.l (a0),(a2) ;1F:DAD9 copies the player's position
        move.w 4(a0),4(a2)
        move.l #M4ScViewOpeningInit,32(a2)
M4ScOpeningNoView:
        andi.b #$ef,M4_LP_GAMEFLAGS
        move.b #70,M4_SC_P1555
        move.l #M4_SH_IMYSHIP_4,d0 ;descriptor index may exceed 127
        jsr M4LevelSetShape
        clr.b M4_SC_P1553
        clr.b M4_SC_P1554
        move.l #M4ScPlayerOpening,32(a0)
; playeropening 0B:8134: wobble from 0B:EB8F and 06:BADA, 65 Z per tick;
; 70 ticks after stratdone2 the boost starts.
M4ScPlayerOpening:
        moveq #0,d0
        move.b M4_SC_P1553,d0
        addq.b #1,d0
        cmpi.b #28,d0
        bne.s M4ScOpenRot
        moveq #0,d0
M4ScOpenRot:
        move.b d0,M4_SC_P1553
        lea M4LpWobbleTable,a2
        move.b (a2,d0.w),14(a0)
        moveq #0,d0
        move.b M4_SC_P1554,d0
        addq.b #2,d0
        cmpi.b #$48,d0
        bne.s M4ScOpenFloat
        moveq #0,d0
M4ScOpenFloat:
        move.b d0,M4_SC_P1554
        lea M4LevelViewFloat,a2
        move.b 1(a2,d0.w),d0 ;low BYTE of the WORD, sign-extended
        ext.w d0
        add.w d0,d0
        subi.w #30,d0
        move.w d0,2(a0)
        btst #4,M4_LP_GAMEFLAGS ;stratdone2
        beq.s M4ScOpenMove
        tst.b M4_SC_P1555
        beq.s M4ScOpenBoost
        subq.b #1,M4_SC_P1555
M4ScOpenMove:
        addi.w #65,4(a0)
        st M4_SC_BGBLACK ;makeBG2black_l 02:F7E1
        moveq #0,d0
        rts
; boost 0B:81C8: boostobj, flame sprite B219 (06:8671), then 0B:8211 every
; tick: rotz -> 0 (Achase8 n=3), 115 Z per tick.
M4ScOpenBoost:
        jsr M4LevelBoostFlame
        andi.b #$fd,M4_LP_PSF3
        move.l #M4ScPlayerOpeningBoost,32(a0)
M4ScPlayerOpeningBoost:
        move.b 14(a0),d0
        moveq #0,d1
        moveq #3,d2
        jsr M4LpAchase8
        move.b d0,14(a0)
        addi.w #115,4(a0)
        moveq #0,d0
        rts

; ExitBase 0B:8EC5 (map player_mode at 0D:D0FF, run inside the dispatch).
M4ScExitBaseInit:
        movem.l d0-d2/a0,-(sp)
        clr.w TEXT_MAP_CONTEXT+4 ;lastplayz $1701 = 0
        jsr M4ScClearMap
        ori.b #1,M4_LP_GAMEFLAGS ;nozremove
        move.w #-50,M4_LP_VIEWCY
        move.w #-500,M4_LP_MINX
        move.w #500,M4_LP_MAXX
        move.w #-500,M4_PM_1575 ;0B:8EC5: $1575/$1577/$1581, wing roof/floor
        move.w #500,M4_PM_1577
        clr.w M4_PM_1581
        move.w #-600,M4_PM_157D
        move.w #5,M4_PM_157F
        move.w #-600,M4_LP_MINY
        move.w #-20,M4_LP_MAXY
        move.b #$0b,M4_LP_FLYMODE ;no wobble
        move.b #$a8,M4_LP_PMOVEAND
        andi.b #$fb,M4_BOSS_PSTRATF
        ori.b #2,M4_LP_PSF3
        andi.b #$fb,M4_LP_PSF2
        andi.b #$d7,M4_BOSS_PSTRATF
        ori.b #$20,M4_BOSS_PSTRATF ;notdie
        lea LV_PLAYER,a0
        bset #F2_SHADOW,48(a0)
        andi.b #$fe,M4_LP_PSF3
        move.l #M4ScExitBaseWait,32(a0)
        move.l #M4LcPlayerColl,X_COLL(a0) ;0B:E729
        move.l #M4LcPlayerDead,X_EXP(a0) ;0B:E215
        andi.b #$df,M4_LP_GAMEFLAGS ;no viewrot
        ori.b #$60,M4_LP_PSF
        move.b #3,M4_SC_VIEWTYPE
        move.w #-400,M4_SC_VIEWPOS
        move.w #-145,M4_SC_VIEWPOS+2
        move.w #1000,M4_SC_VIEWPOS+4
        move.b #55,M4_SC_P1553
        clr.b M4_LP_MEDSPEED
        move.w #-216,(a0)
        move.w #-312,2(a0)
        move.w #-200,4(a0)
        bset #1,49(a0) ;invisible
        move.b #1,M4_SC_NOMAXBG
        andi.b #$fd,M4_LP_PSF3
        movem.l (sp)+,d0-d2/a0
        rts
; 0B:9031: 55 ticks at the base, position held, planet body without control.
M4ScExitBaseWait:
        move.w #-216,(a0)
        move.w #-312,2(a0)
        move.w #-200,4(a0)
        subq.b #1,M4_SC_P1553
        bne M4ScExitBody
        move.b #60,M4_SC_P1553 ;0B:9058 Go
        move.l #M4ScExitBaseGo,32(a0)
        bclr #1,49(a0) ;visible
        move.w #50,M4_SC_STAGECNT ;"STAGE- 1"
        clr.b M4_SC_P1554
; 0B:9085: 60 ticks leaving the base at medspeed 50 (engine sounds skipped).
M4ScExitBaseGo:
        addq.b #1,M4_SC_P1554
        move.b #50,M4_LP_MEDSPEED
        subq.b #1,M4_SC_P1553
        bne M4ScExitBody
        move.l #M4ScExitBaseFollow,32(a0)
        ori.b #2,M4_LP_PSF3
; 0B:90DB: x -> 0, y -> viewCY (Achase n=2); the camera $C1/$C3/$C5 follows
; (minimum steps 4/4/8, n = 2/2/3) plus the player's vz; hand over when the
; previous getview position (viewblk) is within 170 Z of the player.
M4ScExitBaseFollow:
        move.w (a0),d0
        moveq #0,d1
        moveq #2,d2
        jsr M4LpAchase
        move.w d0,(a0)
        move.w 2(a0),d0
        move.w M4_LP_VIEWCY,d1
        jsr M4LpAchase
        move.w d0,2(a0)
        move.w M4_SC_VIEWPOS,d0
        moveq #0,d1
        moveq #2,d2
        jsr M4LpAchase
        move.w d0,M4_SC_VIEWPOS
        move.w M4_SC_VIEWPOS+2,d0
        move.w M4_LP_VIEWCY,d1
        jsr M4LpAchase
        move.w d0,M4_SC_VIEWPOS+2
        move.w M4_SC_VIEWPOS+4,d0
        move.w M4_LP_POSZ,d1
        moveq #3,d2
        jsr M4LpAchase
        add.w 10(a0),d0
        move.w d0,M4_SC_VIEWPOS+4
        move.w M4_LVW_POS+4,d0
        sub.w 4(a0),d0
        bpl.s M4ScExitDist
        neg.w d0
M4ScExitDist:
        cmpi.w #170,d0
        bge M4ScExitBody ;N clear: still far
        ; hand-over 0B:91E1: exterior view, companion 07:806D, control.
        clr.w M4_SC_TIME_ON ;normal flight keeps its unrestricted presentation
        clr.b M4_SC_VIEWTYPE
        andi.b #$fe,M4_LP_GAMEFLAGS
        move.b #65,M4_LP_MEDSPEED
        movea.l a0,a3 ;player
        jsr M4LevelAlloc ;inserted after the player: Istrat runs this tick
        move.l a0,d0
        beq.s M4ScExitNoMate
        move.l #M4_SH_MYSHIP_4,d0 ;descriptor index may exceed 127
        jsr M4LevelSetShape
        bset #0,49(a0) ;no collision
        move.w #-50,(a0) ;1F:DAD9 copy, then x -50, y -100, z -200
        move.w #-100,2(a0)
        move.w 4(a3),d0
        subi.w #200,d0
        move.w d0,4(a0)
        move.l #M4ScMateInit,32(a0)
M4ScExitNoMate:
        movea.l a3,a0
        clr.b M4_SC_NOMAXBG
        jsr M4ScOnPlanetIstrat
M4ScExitBody:
        jsr M4LevelPlayerTick ;0B:BBE3 planet body (control off)
        moveq #0,d0
        rts

; playeronplanet_Istrat 0B:BB03 (then the planet strategy at its allst
; position, M4LevelPlayerStrat).
M4ScOnPlanetIstrat:
        andi.b #$1f,M4_LP_PSF ;control
        move.w #-50,M4_LP_VIEWCY
        move.w #-500,M4_LP_MINX
        move.w #500,M4_LP_MAXX
        move.w #-500,M4_PM_1575 ;0B:BB03: $1575/$1577/$1581, wing roof/floor
        move.w #500,M4_PM_1577
        clr.w M4_PM_1581
        move.w #-255,M4_PM_157D
        move.w #5,M4_PM_157F
        move.w #-255,M4_LP_MINY
        move.w #-20,M4_LP_MAXY
        move.b #$1b,M4_LP_FLYMODE
        move.b #$a8,M4_LP_PMOVEAND
        ori.b #$20,M4_LP_GAMEFLAGS ;viewrot
        andi.b #$fb,M4_BOSS_PSTRATF
        ori.b #2,M4_LP_PSF3
        andi.b #$fb,M4_LP_PSF2
        andi.b #$d7,M4_BOSS_PSTRATF ;notdie cleared
        bset #F2_SHADOW,48(a0)
        andi.b #$fe,M4_LP_PSF3
        move.l #M4LevelPlayerStrat,32(a0)
        move.l #M4LcPlayerColl,X_COLL(a0)
        move.l #M4LcPlayerDead,X_EXP(a0)
        rts

; newplayerstrat = playeronplanet_Istrat 0B:BB03 as the player's strategy
; (training background $111): Istrat, then the planet strategy (d0 = 0).
M4ScOnPlanetNew:
        jsr M4ScOnPlanetIstrat
        jmp M4LevelPlayerStrat

; set_playerOnPlanet_l 0B:BAEF (map player_mode at 0D:D21B): Istrat and one
; planet body pass inside the map dispatch.
M4ScSetOnPlanet:
        movem.l d0-d7/a0-a4,-(sp)
        lea LV_PLAYER,a0
        jsr M4ScOnPlanetIstrat
        jsr M4LevelPlayerTick
        movem.l (sp)+,d0-d7/a0-a4
        rts

; ---------------------------------------------------------------------
; Object strategies. a0 = object, a1 = player.

; viewopening_Istrat 07:873F: camera carrier, invisible nullshape.
M4ScViewOpeningInit:
        bset #1,49(a0)
        addi.w #-1200,(a0)
        addi.w #-2000,2(a0)
        addi.w #3500,4(a0)
        move.b #$80,13(a0)
        move.b #4,12(a0)
        move.b #90,36(a0)
        andi.b #$f7,M4_LP_GAMEFLAGS
        andi.b #$fd,M4_LP_PSF3
        clr.b X_STATE(a0)
        move.l #M4ScViewOpening,32(a0)
; viewopening 07:8792: state 0 chases player + (-400,-700,-700) by n=5 for
; 90 ticks (then stratdone2), state 1 chases (x, -10, z-300) by 3/4/4 for
; 80 ticks (then stratdone1, every 256 ticks); z += 65; viewpos = position.
M4ScViewOpening:
        move.w M4_SC_PPOSX,d3 ;w1 player_posx
        moveq #-30,d4 ;w2
        move.w M4_LP_POSZ,d5 ;w3 player_posz
        tst.b X_STATE(a0)
        bne.s M4ScViewState1
        addi.w #-400,d3
        addi.w #-700,d4
        addi.w #-700,d5
        moveq #5,d2
        move.w (a0),d0
        move.w d3,d1
        jsr M4LpAchase
        move.w d0,(a0)
        move.w 2(a0),d0
        move.w d4,d1
        jsr M4LpAchase
        move.w d0,2(a0)
        move.w 4(a0),d0
        move.w d5,d1
        jsr M4LpAchase
        move.w d0,4(a0)
        subq.b #1,36(a0)
        bne.s M4ScViewMove
        move.b #1,X_STATE(a0)
        move.b #80,36(a0)
        ori.b #$10,M4_LP_GAMEFLAGS ;stratdone2
        ori.b #2,M4_LP_PSF3
M4ScViewState1:
        subq.b #1,36(a0)
        bne.s M4ScViewChase
        ori.b #8,M4_LP_GAMEFLAGS ;stratdone1
M4ScViewChase:
        andi.b #$fe,M4_LP_GAMEFLAGS
        addi.w #20,d4
        addi.w #-300,d5
        move.w 2(a0),d0
        move.w d4,d1
        moveq #4,d2
        jsr M4LpAchase
        move.w d0,2(a0)
        move.w (a0),d0
        cmp.w d3,d0
        beq.s M4ScViewXDone ;1F:D6AB returns carry when equal
        move.w d3,d1
        moveq #3,d2
        jsr M4LpAchase
        move.w d0,(a0)
        move.w 4(a0),d0
        move.w d5,d1
        moveq #4,d2
        jsr M4LpAchase
        move.w d0,4(a0)
        bra.s M4ScViewMove
M4ScViewXDone:
        addi.w #10,4(a0)
M4ScViewMove:
        addi.w #65,4(a0)
        move.l (a0),M4_SC_VIEWPOS
        move.w 4(a0),M4_SC_VIEWPOS+4
        moveq #0,d0
        rts

; gnd 08:F15D: static, drawn behind everything (atgnd), no collision.
M4StratGnd:
        clr.l 32(a0)
        clr.l X_COLL(a0)
        clr.l X_EXP(a0)
        ori.b #1,45(a0)
        bset #0,49(a0)
        moveq #0,d0
        rts

; shipintro_Istrat 07:8673: random float phase (random_l twice), sbyte2
; doubled, shadow, life 40, no zremove.
M4StratShipIntro:
        jsr M4IntroRandom
        andi.b #15,d0
        move.b d0,X_SBYTE3(a0)
        jsr M4IntroRandom
        andi.b #7,d0
        move.b d0,X_SBYTE4(a0)
        move.b 37(a0),d0
        add.b d0,d0
        move.b d0,37(a0)
        andi.b #$ef,M4_LP_GAMEFLAGS
        bset #F2_SHADOW,48(a0)
        move.b #40,19(a0)
        bclr #3,45(a0)
        move.l #M4StratShipIntroTick,32(a0)
; shipintro 07:86AD: after stratdone2 count sbyte1 down (z += 50 per tick
; once it reaches 0) and the life down; float (06:E915), y += sword1,
; z += 65. Boost flame when sbyte1 == 2 (07:86E4, every path); no sounds.
M4StratShipIntroTick:
        moveq #0,d7
        btst #4,M4_LP_GAMEFLAGS
        beq.s M4ShipIntroFloat
        tst.b 36(a0)
        bmi.s M4ShipIntroLife
        subq.b #1,36(a0)
        bne.s M4ShipIntroFloat
        move.b #1,36(a0)
        addi.w #50,4(a0)
M4ShipIntroLife:
        subq.b #1,19(a0)
        bne.s M4ShipIntroFloat
        moveq #1,d7 ;delete 1F:D501: removed after this tick's move
M4ShipIntroFloat:
        cmpi.b #2,36(a0) ;07:86E4: boostobj = this ship, flame B219
        bne.s M4ShipIntroNoFlame
        jsr M4LevelBoostFlame
M4ShipIntroNoFlame:
        moveq #0,d0 ;floatCLship_l 06:E915
        move.b X_SBYTE3(a0),d0
        addq.b #1,d0
        cmpi.b #28,d0
        bne.s M4ShipIntroRot
        moveq #0,d0
M4ShipIntroRot:
        move.b d0,X_SBYTE3(a0)
        lea M4LpWobbleTable,a2
        move.b (a2,d0.w),d0
        add.b d0,d0
        move.b d0,14(a0)
        moveq #0,d0
        move.b X_SBYTE4(a0),d0
        addq.b #1,d0
        add.b d0,d0
        cmpi.b #$48,d0
        bne.s M4ShipIntroY
        moveq #0,d0
M4ShipIntroY:
        lea M4LevelViewFloat,a2
        move.b 1(a2,d0.w),d1
        ext.w d1
        add.w d1,d1
        move.w d1,2(a0)
        lsr.b #1,d0 ;cmp #$80 / ror: k < $80
        move.b d0,X_SBYTE4(a0)
        move.w 40(a0),d0
        add.w d0,2(a0)
        addi.w #65,4(a0)
        move.l d7,d0
        rts

; friendexitbase_Istrat 07:8137: invisible, no collision, life 30; after
; sbyte1 ticks it flies out at 50 Z per tick (sounds skipped).
M4StratFriendExitBase:
        bset #0,49(a0)
        move.b #30,19(a0)
        bset #F2_SHADOW,48(a0)
        bset #1,49(a0)
        move.b #11,37(a0)
        move.l #M4StratFriendExitTick,32(a0)
M4StratFriendExitTick:
        subq.b #1,36(a0)
        bne.s M4FriendExitKeep
        move.b #1,36(a0)
        tst.b 37(a0)
        beq.s M4FriendExitGo
        subq.b #1,37(a0)
M4FriendExitGo:
        addi.w #50,4(a0)
        bclr #1,49(a0)
        subq.b #1,19(a0)
        bne.s M4FriendExitKeep
        moveq #1,d0
        rts
M4FriendExitKeep:
        moveq #0,d0
        rts

; Companion of the hand-over 07:806D: life 70, vel 30, rotz $C0; once the
; player is behind it (16-bit N of player.z - z) it levels (rotz -> 0) and
; climbs (rotx -> $C0 every 4th gameframe), moves by gen_3dvecs and
; addplayerZ. The first time: boostobj = this ship and its flame (07:80A5).
M4ScMateInit:
        bclr #3,45(a0)
        bset #0,49(a0)
        move.b #70,19(a0)
        move.b #30,15(a0)
        move.b #$c0,14(a0)
        clr.b X_SCFLAGS(a0)
        move.l #M4ScMate,32(a0)
M4ScMate:
        move.w 4(a1),d0
        sub.w 4(a0),d0
        bpl.s M4ScMateMove
        bset #4,X_SCFLAGS(a0) ;sflags2 $10: boost sprite once
        bne.s M4ScMateFlamed
        jsr M4LevelBoostFlame
M4ScMateFlamed:
        move.b 14(a0),d0
        moveq #0,d1
        moveq #4,d2
        jsr M4LpAchase8
        move.b d0,14(a0)
        move.w M4_LV_GAMEFRAME,d0
        andi.w #3,d0
        bne.s M4ScMateMove
        move.b 12(a0),d0
        move.b #$c0,d1
        moveq #4,d2
        jsr M4LpAchase8
        move.b d0,12(a0)
M4ScMateMove:
        moveq #0,d0
        move.b 15(a0),d0
        jsr M4LevelGen3dVecs
        jsr M4EnMove
        jsr M4EnAddPZ
        subq.b #1,19(a0)
        bne.s M4ScMateKeep
        moveq #1,d0
        rts
M4ScMateKeep:
        moveq #0,d0
        rts

; ---------------------------------------------------------------------
; Presentation helpers (producer side, once per published tick).

; Brightness of the next image: INIDISP fade level limited by the blackfade
; subtraction (stayblack 1..$FE: black; 0: 15 - val/2). MD has no colour
; subtraction: the step is approximated by the brightness scale.
; d0 = fade brightness 0..15 -> d0 adjusted.
M4ScBlackBright:
        move.b M4_SC_STAYBLACK,d1
        cmpi.b #$ff,d1
        beq.s M4ScBlackNone
        tst.b d1
        bne.s M4ScBlackTotal
        moveq #0,d1
        move.b M4_SC_BLACKVAL,d1
        lsr.w #1,d1
        neg.w d1
        addi.w #15,d1
        cmp.w d1,d0
        bls.s M4ScBlackNone
        move.w d1,d0
M4ScBlackNone:
        rts
M4ScBlackTotal:
        moveq #0,d0
        rts

; makeBG2black_l / setbg 1_1c on the CRAM base: BG lines 0-1 black or
; restored; the version bit makes the presentation reload the CRAM with the
; next image.
M4ScBgPalette:
        movem.l d0-d2/a0-a1,-(sp)
        move.b M4_SC_BGBLACK,d0
        cmp.b M4_SC_BGSHOWN,d0
        beq.s M4ScBgPaletteDone
        move.b d0,M4_SC_BGSHOWN
        lea M4_BASE_CRAM,a1
        lea M4LevelBgCram,a0
        tst.b M4_SPB_ON
        beq.s M4ScBgPaletteRows
        lea M4_SPB_CRAM,a0 ;bg_1_2 rows (level_space_bg.asm)
M4ScBgPaletteRows:
        moveq #27,d1 ;lines 0-1 except line 1 slots 12..15 (SCRAMBLE OBJ colours)
M4ScBgPaletteColour:
        move.w (a0)+,d2
        tst.b d0
        beq.s M4ScBgPaletteSet
        moveq #0,d2
M4ScBgPaletteSet:
        move.w d2,(a1)+
        dbra d1,M4ScBgPaletteColour
        eori.b #$40,M4_SC_PALVER
M4ScBgPaletteDone:
        movem.l (sp)+,d0-d2/a0-a1
        rts

; do_sprites_l 03:DB5A text part: prt_scramble 03:DD08 (only without a
; wipe: scramble-- when nonzero, drawn while gameframe&7 > 3) and do_stage
; 03:DD53 (stagecnt-- when nonzero, drawn while stagecnt&7 >= 3). a1 = SAT
; buffer, d7 = next sprite number. Returns a1/d7 advanced.
M4ScTextSprites:
        tst.b M4_SC_WIPE
        bne.s M4ScTextStage
        tst.b M4_SC_SCRAMBLE
        beq.s M4ScTextStage
        subq.b #1,M4_SC_SCRAMBLE
        move.w M4_LV_GAMEFRAME,d0
        andi.w #7,d0
        cmpi.w #3,d0
        bls.s M4ScTextStage
        lea M4LvMsgScramble,a0
        bsr.s M4ScTextCopy
M4ScTextStage:
        tst.w M4_SC_STAGECNT
        beq.s M4ScTextDone
        subq.w #1,M4_SC_STAGECNT
        move.w M4_SC_STAGECNT,d0
        andi.w #7,d0
        cmpi.w #3,d0
        blo.s M4ScTextDone
        lea M4LvMsgStageTab,a0
        jsr M4ScStageText
        tst.b M4_TR_PRTTRAIN ;prttraining: trainingmes (03:DF10) at $4848
        beq.s M4ScTextStageCopy
        lea M4LvMsgTraining,a0
M4ScTextStageCopy:
        bsr.s M4ScTextCopy
M4ScTextDone:
        tst.b M4_BOSS_STAGECLEAR ;prt_stageclear 03:DDB3 (no blink)
        beq.s M4ScTextNoClear
        tst.b M4_SC_MMETERS
        beq.s M4ScTextNoClear
        lea M4LvMsgClearTab,a0
        jsr M4ScStageText
        bsr.s M4ScTextCopy
M4ScTextNoClear:
        rts
M4ScTextCopy:
        move.w (a0)+,d1
        subq.w #1,d1
M4ScTextSprite:
        move.w (a0)+,(a1)+ ;y
        move.w (a0)+,d0 ;size
        addq.w #1,d7
        or.w d7,d0 ;link to the next sprite
        move.w d0,(a1)+
        move.l (a0)+,(a1)+ ;tile/attribute, x
        dbra d1,M4ScTextSprite
        rts

M4DepthTunnel:
        include '../build/m4-depth-tunnel.inc' ;03:8FAE set_zdepthtable tunnel (bg_1_1i)
        even

; stageptrs[stage + 1] (03:DD53 / 03:DDB3): a0 = table of the per-stage
; texts (tools/generate-level-messages.py) -> a0 = text of this stage.
M4ScStageText:
        moveq #0,d0
        move.b M4_GM_STAGE,d0
        cmpi.w #M4_LV_MSG_STAGES-1,d0
        bls.s M4ScStageTextOk
        moveq #M4_LV_MSG_STAGES-1,d0
M4ScStageTextOk:
        lsl.w #2,d0
        movea.l (a0,d0.w),a0
        rts

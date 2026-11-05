; Space player, cockpit and view cycle (selected ROM USA rev0). Specification
; build/research/space-player-cockpit.md, ROM traces build/research/space-
; player-trace.json (tools/space-player-oracle.py). Units:
;   0B:835B/848A playerinsidespaceflyin (Asteroid 1, bg $21)
;   0B:B882/B95C playerinspace (Istrat / strat), 0B:B719 playerstraight
;   0B:C87E..CACA into the cockpit, 0B:CC7C..CE88 out of it
;   0B:CB92/CC44/CF65/CFFA animation objects, 0B:EA5E dupplayer
;   06:BA91 changeviewmode, 06:81E7..835D init_strats (HUD flag,
;   crosshairon, Select), 02:FB9D..FC49 crosshair, 03:E0B5 do_crosshair.
; Deliberate differences: the player keeps its myship shape while invisible
; (nullplayer 00:D2CC has no geometry and the same collision box); the
; crosshair projection uses the port's 256 focal division (projectlog 03:B9DE
; differs by 1 px in 17 % of the trace rows); the GSU cockpit HUD (01:D76B)
; is PEND; Select is the six-button pad's Mode (level_input.asm). The canopy
; 00:D748 (83 vertices, 66 visibility triples) exceeds the cmd9 object record
; (64 vertices / 64 visibilities): its objects run but are not drawn (PEND).
M4_SPP equ $fff960
M4_SPP_FM equ M4_SPP+0 ;.b $14DD splayerflymode
M4_SPP_FMOPT equ M4_SPP+1 ;.b $14DE splayerflymodeopt (modes of the cycle)
M4_SPP_HUDON equ M4_SPP+2 ;.b $14C6 (m_hudrot high byte: cockpit HUD)
M4_SPP_XHAIRON equ M4_SPP+3 ;.b $15AD crosshairon
M4_SPP_XHAIR equ M4_SPP+4 ;2 .w $16F4/$16F6 crosshair offset from (112,96)
M4_SPP_HUDFLAGS equ M4_SPP+8 ;.b 70:2B26 m_hudflags (broken wings)
M4_SPP_FIREON equ M4_SPP+9 ;.b cockpit fire origin valid this tick
M4_SPP_FIREORG equ M4_SPP+10 ;3 .w (pviewposx, pviewposy+50, pviewposz[+200])
M4_SPP_SAVEPOS equ M4_SPP+16 ;3 .w player position kept while firing ($151D..$1521)
M4_SPP_LIMITS equ M4_SPP+28 ;.b $14D7 pmovelimits (8 planet: enemy shots die at y >= 0; 0 space)
M4_SPP_END equ M4_SPP+58 ;+22..27: level_warp.asm; +32..57 HUD records
M4_LP_OUTVZ equ M4_LP+94 ;.w $18CB outvz

SFM_NORM equ 0
SFM_CLOSE equ 1
SFM_TOINSIDE equ 2
SFM_INSIDE equ 3
SFM_TONORM equ 4

; Level start (playermove_init): exterior far, planet cycle of 2.
M4SpInit:
        clr.l M4_SPP
        clr.l M4_SPP+4
        clr.l M4_SPP+8
        clr.l M4_SPP+12
        clr.l M4_SPP+16
        clr.l M4_SPP+20
        clr.l M4_SPP+24 ;Warp words and state (level_warp.asm)
        clr.w M4_SPP+28
        clr.b M4_WHITEADD
        move.b #8,M4_SPP_LIMITS ;planet value (playeronplanet)
        move.b #2,M4_SPP_FMOPT
        clr.w M4_LP_OUTVZ
        rts

; "space" fly-mode block of 0B:835B/B882/CACA/CE88. d1 = X limit (240/600).
M4SpFlyMode:
        move.w #-60,M4_LP_VIEWCY
        move.w d1,M4_LP_MAXX
        move.w d1,M4_PM_1577 ;$1577 (enemy shots; no port consumer)
        neg.w d1
        move.w d1,M4_LP_MINX
        move.w d1,M4_PM_1575 ;$1575
        move.w #10000,M4_PM_1581 ;$1581 (no ground)
        move.w #-190,M4_PM_157D ;wing roof (M4PmWings)
        move.w #85,M4_PM_157F ;wing floor
        move.w #-190,M4_LP_MINY
        move.w #60,M4_LP_MAXY
        move.b #$12,M4_LP_FLYMODE ;bit4 wobble; no bit3: no ground, no shadow
        clr.b M4_LP_PMOVEAND ;$14E1 = 0
        clr.b M4_SPP_LIMITS ;$14D7 = 0: no limit kills of enemy shots (06:901A)
        ori.b #$20,M4_LP_GAMEFLAGS ;viewrot
        andi.b #$fb,M4_BOSS_PSTRATF
        ori.b #2,M4_LP_PSF3 ;engine
        rts

; changeviewmode_l 06:BA91.
M4SpChangeView:
        move.b M4_SPP_FM,d0
        bne.s M4SpCvNot0
        move.w #120,M4_LP_VIEWDIST
        rts
M4SpCvNot0:
        cmpi.b #SFM_CLOSE,d0
        bne.s M4SpCvNot1
        move.w #60,M4_LP_VIEWDIST
        rts
M4SpCvNot1:
        cmpi.b #SFM_TOINSIDE,d0
        bne.s M4SpCvNot2
        move.l #M4SpIntoCockI,LV_PLAYER+32 ;0B:C87E: runs at the player's next pass
        rts
M4SpCvNot2:
        cmpi.b #SFM_TONORM,d0
        bne.s M4SpCvDone
        move.l #M4SpOutCockI,LV_PLAYER+32 ;0B:CC7C
M4SpCvDone:
        rts

; init_strats_l 06:81E7..835D, before the map and the strategies.
M4SpInitStrats:
        movem.l d0-d1/a0,-(sp)
        clr.b M4_SPP_HUDON
        cmpi.b #SFM_INSIDE,M4_SPP_FM
        bne.s M4SpIsHud
        st M4_SPP_HUDON
M4SpIsHud:
        st M4_SPP_XHAIRON ;06:82D4
        btst #6,M4_LP_PSF ;nofire
        beq.s M4SpIsXh
        clr.b M4_SPP_XHAIRON
M4SpIsXh:
        move.w M4_LP_VIEWDIST,d0 ;06:82E5 Select
        cmp.w M4_LP_OUTDIST,d0
        bne.s M4SpIsDone
        cmpi.b #$ff,M4_SC_STAYBLACK
        bne.s M4SpIsDone
        btst #5,M4_LP_PSF ;noctrl
        bne.s M4SpIsDone
        move.b M4_BOSS_PSTRATF,d0
        andi.b #$28,d0 ;notdie | inseq
        bne.s M4SpIsDone
        lea LV_PLAYER,a0
        tst.b 37(a0) ;sbyte2
        bne.s M4SpIsDone
        btst #J_SELECT,M4_LP_JOY
        beq.s M4SpIsDone
        btst #J_SELECT,M4_LP_LASTJOY
        bne.s M4SpIsDone
        M4PlaySfx $65
        move.b M4_SPP_FM,d0 ;trigse $65
        addq.b #1,d0
        cmp.b M4_SPP_FMOPT,d0
        blt.s M4SpIsOk
        moveq #0,d0
M4SpIsOk:
        move.b d0,M4_SPP_FM
        jsr M4SpChangeView
M4SpIsDone:
        movem.l (sp)+,d0-d1/a0
        rts

; ---------------------------------------------------------------------
; Player strategies. a0 = player; d0 = 0 on return.

; newplayerstrat of bg_1_2: Istrat 0B:835B then its strategy, same pass.
M4SpInsideFlyinI:
        ori.b #$60,M4_LP_PSF
        move.w #240,d1
        bsr M4SpFlyMode
        andi.b #$fb,M4_LP_PSF2
        andi.b #$d7,M4_BOSS_PSTRATF
        andi.b #$fe,M4_LP_PSF3
        move.l #M4LcPlayerColl,X_COLL(a0) ;0B:E729
        move.l #M4LcPlayerDead,X_EXP(a0) ;0B:E215
        clr.w (a0)
        move.w #-400,2(a0)
        clr.w 4(a0)
        ori.b #1,M4_BOSS_PSTRATF ;novdistC
        move.w 4(a0),M4_LP_PVIEWZ
        move.w #60,M4_LP_OUTDIST
        move.w #60,M4_LP_VIEWDIST
        bsr M4SpMedSpeed
        move.l #M4SpInsideFlyin,32(a0)
; 0B:848A
M4SpInsideFlyin:
        addq.w #3,M4_LP_OUTDIST
        ; 1F:D6AB: C only when y == viewCY on entry (no chase); else chase n=3
        move.w 2(a0),d0
        move.w M4_LP_VIEWCY,d1
        cmp.w d1,d0
        beq.s M4SpFlyinArrived
        moveq #3,d2
        jsr M4LpAchase
        move.w d0,2(a0)
        bra M4SpInSpaceStrat
M4SpFlyinArrived:
        andi.b #$fe,M4_BOSS_PSTRATF
        move.b #SFM_TOINSIDE,M4_SPP_FM
        bsr M4SpChangeView ;next pass: M4SpIntoCockI
        bra M4SpInSpaceStrat

; playerinspace_Istrat 0B:B882 (other space backgrounds, end of the exits).
M4SpInSpaceI:
        andi.b #$1f,M4_LP_PSF
        move.w #240,d1
        bsr M4SpFlyMode
        andi.b #$fb,M4_LP_PSF2
        andi.b #$d7,M4_BOSS_PSTRATF
        andi.b #$fe,M4_LP_PSF3
        move.l #M4LcPlayerColl,X_COLL(a0)
        move.l #M4LcPlayerDead,X_EXP(a0)
        move.l #M4SpInSpaceStrat,32(a0)
; playerinspace_strat 0B:B95C + the laser/bomb factories (M4LevelPlayerStrat).
; In the cockpit playerfire replaces the position by its origin while the
; weapons are created (0B:DF87/E1EE) and restores it afterwards.
M4SpInSpaceStrat:
        bsr.s M4SpInSpace
M4SpFactories:
        tst.b M4_SPP_FIREON
        beq.s M4SpFactNormal
        move.l (a0),M4_SPP_SAVEPOS
        move.w 4(a0),M4_SPP_SAVEPOS+4
        move.l M4_SPP_FIREORG,(a0)
        move.w M4_SPP_FIREORG+4,4(a0)
        jsr M4LevelFireBomb
        jsr M4LevelFireLasers
        move.l M4_SPP_SAVEPOS,(a0)
        move.w M4_SPP_SAVEPOS+4,4(a0)
        moveq #0,d0
        rts
M4SpFactNormal:
        jsr M4LevelFireBomb
        jsr M4LevelFireLasers
        moveq #0,d0
        rts
M4SpInSpace:
        movem.l d0-d7/a1,-(sp)
        jsr M4LpMove ;0B:D33A
        moveq #0,d0
        move.b 15(a0),d0
        jsr M4LevelGen3dVecs ;no do_player_Yvel125
        jsr M4LpFrameScale
        move.w 6(a0),d0
        add.w d0,(a0)
        move.w 8(a0),d0
        add.w d0,2(a0)
        move.w 10(a0),d0
        add.w d0,4(a0)
        bsr M4SpLimitX ;0B:DF21
        jsr M4LpFire ;0B:DF6C
        jsr M4PmArrows ;0B:E9D0 (level_armada_player.asm)
        clr.b M4_SPP_FIREON
        cmpi.b #SFM_INSIDE,M4_SPP_FM
        bne.s M4SpFireOrgDone
        move.b M4_LP_FIREREQ,d0
        or.b M4_LP_BOMBREQ,d0
        beq.s M4SpFireOrgDone
        st M4_SPP_FIREON ;pviewpos of the previous tick (before viewmove)
        move.w M4_LP_PVIEWX,M4_SPP_FIREORG
        move.w M4_LP_PVIEWY,d0
        addi.w #50,d0
        move.w d0,M4_SPP_FIREORG+2
        move.w M4_LP_PVIEWZ,d0
        btst #4,M4_LP_PSF3 ;beamball
        beq.s M4SpFireOrgZ
        addi.w #200,d0
M4SpFireOrgZ:
        move.w d0,M4_SPP_FIREORG+4
M4SpFireOrgDone:
        cmpi.b #SFM_INSIDE,M4_SPP_FM
        bne.s M4SpPvOut
        move.w (a0),M4_LP_PVIEWX
        move.w 2(a0),M4_LP_PVIEWY
        bra.s M4SpPvDone
M4SpPvOut:
        move.w (a0),d0 ;perc75 1F:D4BA
        move.w d0,d1
        asr.w #1,d1
        asr.w #2,d0
        add.w d1,d0
        move.w d0,M4_LP_PVIEWX
        move.w 2(a0),d0 ;perc62(y + 60) - 60 (1F:D4A8)
        addi.w #60,d0
        move.w d0,d1
        asr.w #1,d1
        asr.w #3,d0
        add.w d1,d0
        subi.w #60,d0
        move.w d0,M4_LP_PVIEWY
M4SpPvDone:
        jsr M4LpViewMove ;0B:D083
        cmpi.b #SFM_INSIDE,M4_SPP_FM ;0B:D1C9: pviewpos = pos in the cockpit
        bne.s M4SpVmDone
        move.l (a0),M4_LP_PVIEWX
        move.w 4(a0),M4_LP_PVIEWZ
M4SpVmDone:
        movem.l (sp)+,d0-d7/a1
        rts

; playerlimitx 0B:DF21.
M4SpLimitX:
        andi.b #$f3,M4_LP_ARROWS
        move.w (a0),d0
        cmp.w M4_LP_MINX,d0
        bgt.s M4SpLxMax
        move.w M4_LP_MINX,(a0)
        ori.b #$04,M4_LP_ARROWS
M4SpLxMax:
        move.w (a0),d0
        cmp.w M4_LP_MAXX,d0
        blt.s M4SpLxDone
        move.w M4_LP_MAXX,(a0)
        ori.b #$08,M4_LP_ARROWS
M4SpLxDone:
        rts

; makeallmedpspeed 0B:D317 ($14EC: no port consumer).
M4SpMedSpeed:
        move.b #LP_MEDPSPEED,15(a0)
        move.w #LP_MEDPSPEED,M4_LP_PVIEWVZ
        move.b #LP_MEDPSPEED,M4_LP_MEDSPEED
        move.b #LP_MEDPSPEED,M4_LP_TOSPEED
        rts

; Achase n = 1: x -> 0, y -> -60, Ztilt -> 0, plrotz -> 0 (C8B5..C935).
M4SpCentre:
        move.w (a0),d0
        moveq #0,d1
        moveq #1,d2
        jsr M4LpAchase
        move.w d0,(a0)
        move.w 2(a0),d0
        moveq #-60,d1
        jsr M4LpAchase
        move.w d0,2(a0)
        move.b M4_LP_ZTILT,d0
        moveq #0,d1
        jsr M4LpAchase8
        move.b d0,M4_LP_ZTILT
        move.w M4_LP_PLROTZ,d0
        moveq #0,d1
        jsr M4LpAchase
        move.w d0,M4_LP_PLROTZ
        rts

; playerintocock_Istrat 0B:C893.
M4SpIntoCockI:
        ori.b #$60,M4_LP_PSF
        ori.b #1,M4_BOSS_PSTRATF ;novdistC
        move.l #M4SpIntoCockStrat,32(a0)
        bsr M4SpMedSpeed
; 0B:C8B3: the block runs twice; at outdist 0 -> CA45.
M4SpIntoCockStrat:
        movem.l d3,-(sp)
        moveq #1,d3
M4SpIcPass:
        bsr.s M4SpCentre
        tst.w M4_LP_OUTDIST
        beq.s M4SpIc2Go
        move.w M4_LP_OUTDIST,d0
        moveq #0,d1
        moveq #1,d2
        jsr M4LpAchase
        move.w d0,M4_LP_OUTDIST
        dbra d3,M4SpIcPass
        movem.l (sp)+,d3
        bra M4SpInSpaceStrat ;jml 0B:B95C
M4SpIc2Go:
        movem.l (sp)+,d3
; 0B:CA45: copy of the ship at x16 coming toward the camera.
        move.l #M4SpIntoCock2,32(a0)
        clr.w M4_LP_OUTDIST
        clr.w M4_LP_OUTVX
        clr.w M4_LP_OUTVY
        clr.w M4_LP_OUTVZ
        move.w M4_LP_PVIEWZ,d0 ;previous tick
        addi.w #60,d0
        move.w d0,4(a0)
        bsr M4SpDupPlayer ;a2 = copy (0: no free slot)
        move.l a2,d0
        beq.s M4SpIc2NoDup
        bsr M4SpZoomShape
        move.l #M4SpCockDumpI,32(a2)
        move.w 4(a0),d0 ;Y.z = pviewposz + 16 (z - pviewposz)
        sub.w M4_LP_PVIEWZ,d0
        lsl.w #4,d0
        add.w M4_LP_PVIEWZ,d0
        move.w d0,4(a2)
M4SpIc2NoDup:
        move.b #20,M4_SC_P1553
; 0B:CAC1 / CACA.
M4SpIntoCock2:
        subq.b #1,M4_SC_P1553
        beq.s M4SpCaca
        bsr M4SpStraight
        moveq #0,d0
        rts
M4SpCaca:
        move.w #600,d1
        bsr M4SpFlyMode
        move.b #SFM_INSIDE,M4_SPP_FM
        bclr #SF_COLLDISABLE,49(a0)
        move.l #M4SpInSpaceStrat,32(a0)
        andi.b #$1f,M4_LP_PSF
        andi.b #$fe,M4_BOSS_PSTRATF
        move.b #10,37(a0) ;sbyte2: boost/brake and Select blocked 10 ticks
        bra M4SpInSpaceStrat

; playerstraight 0B:B719 (no playermove, no fire, no viewmove).
M4SpStraight:
        clr.b M4_LP_ARROWS ;stz $1FC9
        clr.b M4_SC_VIEWTYPE
        clr.l M4_LP_PLROTX ;plrotx, plroty
        clr.w M4_LP_PLROTZ
        move.w M4_LP_OUTVX,d0
        moveq #0,d1
        moveq #3,d2
        jsr M4LpAchase
        move.w d0,M4_LP_OUTVX
        move.w M4_LP_OUTVY,d0
        jsr M4LpAchase
        move.w d0,M4_LP_OUTVY
        clr.w M4_LP_OUTVZ
        clr.b 12(a0)
        clr.b 13(a0)
        clr.b 14(a0)
        clr.w M4_LP_VIEWSHAKE
        clr.b M4_LP_VIEWSHAKE+2
        move.w #LP_MEDPSPEED,M4_LP_PVIEWVZ
        move.b #LP_MEDPSPEED,15(a0)
        moveq #LP_MEDPSPEED,d0
        jsr M4LevelGen3dVecs ;rotx = roty = 0
        move.w 6(a0),d0
        add.w d0,(a0)
        move.w 8(a0),d0
        add.w d0,2(a0)
        move.w 10(a0),d0
        add.w d0,4(a0)
        clr.w (a0)
        move.w M4_LP_VIEWCY,2(a0)
        clr.w M4_LP_PVIEWX
        move.w M4_LP_VIEWCY,M4_LP_PVIEWY
        move.w M4_LP_PVIEWVZ,d0
        add.w d0,M4_LP_PVIEWZ
        rts

; playeroutofcock_Istrat 0B:CC91.
M4SpOutCockI:
        ori.b #$60,M4_LP_PSF
        andi.b #$fe,M4_BOSS_PSTRATF
        move.l #M4SpOutCockStrat,32(a0)
        move.w #120,M4_LP_VIEWDIST
        move.w #120,M4_LP_OUTDIST
        clr.w M4_LP_OUTVX
        clr.w M4_LP_OUTVY
        clr.w M4_LP_OUTVZ
        move.b #23,M4_SC_P1553
        bsr M4SpMedSpeed
; 0B:CCE8 / CE88.
M4SpOutCockStrat:
        bsr M4SpCentre
        bsr M4SpCentre
        cmpi.b #19,M4_SC_P1553
        bne.s M4SpOcNoObj
        bsr M4SpMakeCockpitOut
        bsr M4SpMakeShipOut
M4SpOcNoObj:
        tst.b M4_LP_PSF2 ;$14D9 bit7: HP 0
        bpl.s M4SpOcAlive
        addq.b #4,M4_LP_ZSTRATADD
M4SpOcAlive:
        subq.b #1,M4_SC_P1553
        beq.s M4SpOcEnd
        bsr M4SpStraight
        moveq #0,d0
        rts
M4SpOcEnd:
        move.w #240,d1
        bsr M4SpFlyMode
        bclr #SF_INVISIBLE,49(a0)
        tst.b M4_LP_PSF2
        bmi.s M4SpOcDead
        move.l #M4SpInSpaceStrat,32(a0)
        btst #3,M4_BOSS_PSTRATF ;inseq
        bne.s M4SpOcSeq
        andi.b #$1f,M4_LP_PSF
M4SpOcSeq:
        move.w #120,M4_LP_VIEWDIST
        clr.b M4_SPP_FM
        bclr #2,31(a0) ;$1D &= ~2 hitflash
        bra M4SpInSpaceStrat
M4SpOcDead:
        jmp M4LcPlayerDead ;0B:E215 with $14DD = 4 (normal path)

; ---------------------------------------------------------------------
; Animation objects. a0 = object, a1 = player.

; dupplayer 0B:EA5E: nullshape copy with the player's shape, position and
; rotation, no collision; the player becomes invisible. a2 = copy or 0.
M4SpDupPlayer:
        movem.l d0-d1/a0/a3,-(sp)
        movea.l a0,a3
        jsr M4LevelAlloc ;creator = player: behind it, runs in this pass
        movea.l a0,a2
        movea.l a3,a0
        move.l a2,d0
        beq.s M4SpDupDone
        move.w 46(a0),d0
        exg a0,a2
        jsr M4LevelSetShape
        exg a0,a2
        move.l (a0),(a2) ;x, y
        move.w 4(a0),4(a2)
        move.b 12(a0),12(a2)
        move.b 13(a0),13(a2)
        move.b 14(a0),14(a2)
        bset #SF_COLLDISABLE,49(a2)
        bset #SF_INVISIBLE,49(a0)
M4SpDupDone:
        movem.l (sp)+,d0-d1/a0/a3
        rts

; setYplayershape_l 06:810D with A = 6: "zoom" shape of a2 by $14D8 & $18.
M4SpZoomShape:
        movem.l d0-d1,-(sp)
        moveq #0,d0
        move.b M4_LP_PSF,d1
        andi.b #$18,d1
        beq.s M4SpZsSet
        moveq #1,d0 ;$08 only -> D7B8
        cmpi.b #$08,d1
        beq.s M4SpZsSet
        moveq #2,d0 ;$10 only -> D79C
        cmpi.b #$10,d1
        beq.s M4SpZsSet
        moveq #3,d0 ;both -> D780
M4SpZsSet:
        addi.w #M4_SH_ZOOM_4,d0 ;DD68, D7B8, D79C, D780 (tools/level-shapes.py)
        exg a0,a2
        jsr M4LevelSetShape
        exg a0,a2
        movem.l (sp)+,d0-d1
        rts

; cockdumpl_Istrat 0B:CB92 / cockdumpl 0B:CBBF.
M4SpCockDumpI:
        move.b #$ff,38(a0)
        clr.b 39(a0)
        bset #SF_COLLDISABLE,49(a0)
        bclr #F2_SFLAG1,48(a0)
        move.b #8,19(a0)
        clr.b 12(a0)
        clr.b 13(a0)
        clr.b 14(a0)
        move.l #M4SpCockDump,32(a0)
M4SpCockDump:
        moveq #0,d7
        subq.b #1,19(a0)
        bne.s M4SpCdLive
        moveq #1,d7 ;removed after the body
M4SpCdLive:
        move.w M4_LP_PVIEWVZ,d0
        add.w d0,4(a0)
        subi.w #160,4(a0)
        btst #F2_SFLAG1,48(a0)
        bne.s M4SpCdDone
        move.w 4(a1),d0
        sub.w 4(a0),d0
        bpl.s M4SpCdDoCock ;player ahead or level
        neg.w d0
        cmpi.w #50,d0
        bge.s M4SpCdDone
M4SpCdDoCock: ;docock 0B:CC11: cockpit behind this copy
        move.l a0,-(sp)
        jsr M4LevelAlloc
        move.l a0,d0
        beq.s M4SpCdFail
        move.w #M4_SH_COCKPIT,d0
        jsr M4LevelSetShape
        move.l (a1),(a0)
        move.w 4(a1),4(a0)
        move.l #M4SpCockpitI,32(a0)
        movea.l (sp)+,a0
        bset #F2_SFLAG1,48(a0)
        bra.s M4SpCdDone
M4SpCdFail:
        movea.l (sp)+,a0
M4SpCdDone:
        move.l d7,d0
        rts

; cockpit_Istrat 0B:CC44 / cockpit 0B:CC5F (life not set: 0 -> 255).
M4SpCockpitI:
        bset #SF_INVISIBLE,49(a0) ;canopy not drawn (cmd9 record limit)
        move.b #$ff,38(a0)
        clr.b 39(a0)
        bset #SF_COLLDISABLE,49(a0)
        move.l #M4SpCockpit,32(a0)
M4SpCockpit:
        moveq #0,d7
        subq.b #1,19(a0)
        bne.s M4SpCpLive
        moveq #1,d7
M4SpCpLive:
        move.w M4_LP_PVIEWVZ,d0
        add.w d0,4(a0)
        subi.w #10,4(a0)
        move.l d7,d0
        rts

; CDFB..CE68 (a0 = player): cockpit at z - 105, x16 copy at z - 611.
M4SpMakeCockpitOut:
        movem.l d0/a0/a2,-(sp)
        movea.l a0,a2
        jsr M4LevelAlloc
        move.l a0,d0
        beq.s M4SpMcoDone
        move.w #M4_SH_COCKPIT,d0
        jsr M4LevelSetShape
        move.l (a2),(a0)
        move.w 4(a2),d0
        subi.w #105,d0
        move.w d0,4(a0)
        move.l #M4SpCockpitOutI,32(a0)
M4SpMcoDone:
        movem.l (sp)+,d0/a0/a2
        rts
M4SpMakeShipOut:
        movem.l d0/a0/a2-a3,-(sp)
        movea.l a0,a3
        jsr M4LevelAlloc
        movea.l a0,a2
        movea.l a3,a0
        move.l a2,d0
        beq.s M4SpMsoDone
        bsr M4SpZoomShape
        move.l (a0),(a2)
        move.w 4(a0),d0
        subi.w #611,d0
        move.w d0,4(a2)
        move.l #M4SpCockShipOutI,32(a2)
M4SpMsoDone:
        movem.l (sp)+,d0/a0/a2-a3
        rts

; cockshipout 0B:CF65 / CF93 and cockpitout 0B:CFFA / D01F.
M4SpCockShipOutI:
        move.b #$ff,38(a0)
        clr.b 39(a0)
        bset #SF_COLLDISABLE,49(a0)
        andi.b #~AT_ZREMOVE,45(a0)
        move.b #19,19(a0)
        move.w #60,40(a0)
        move.l #M4SpCockShipOut,32(a0)
M4SpCockShipOut:
        bsr.s M4SpOutFollow
        move.w 40(a0),d0
        add.w d0,4(a0)
        addi.w #10,40(a0)
        move.l d7,d0
        rts
M4SpCockpitOutI:
        bset #SF_INVISIBLE,49(a0) ;canopy not drawn (cmd9 record limit)
        move.b #$ff,38(a0)
        clr.b 39(a0)
        bset #SF_COLLDISABLE,49(a0)
        andi.b #~AT_ZREMOVE,45(a0)
        move.b #8,19(a0)
        move.l #M4SpCockpitOut,32(a0)
M4SpCockpitOut:
        bsr.s M4SpOutFollow
        addi.w #20,4(a0)
        move.l d7,d0
        rts
; Common part: spin and flash when the player died, x/y = player_pos,
; life--, addplayerZ. d7 = 1: remove.
M4SpOutFollow:
        tst.b M4_LP_PSF2
        bpl.s M4SpOfAlive
        move.b M4_LP_ZSTRATADD,14(a0)
        btst #0,M4_LV_GAMEFRAME+1
        bne.s M4SpOfAlive
        bset #2,31(a0)
M4SpOfAlive:
        move.w M4_SC_PPOSX,(a0)
        move.w M4_SC_PPOSY,2(a0)
        moveq #0,d7
        subq.b #1,19(a0)
        bne.s M4SpOfLive
        moveq #1,d7
M4SpOfLive:
        move.w M4_LP_PVIEWVZ,d0
        add.w d0,4(a0)
        rts

; ---------------------------------------------------------------------
; Crosshair 02:FB9D..FC49 (end of getview, M4LevelView): (0, 0, 500) by the
; player's rotx then roty with M(w,b) of 02:FC62, plus the player's position
; relative to viewpos (y + 50 in the cockpit), times W, projected with focal
; 256 around (112, 96): M4_SPP_XHAIR = (sx - 112, sy - 96).
M4SpCrosshairCalc:
        movem.l d0-d4/a0-a2,-(sp)
        lea LV_PLAYER,a0
        lea M4IntroShipSine,a1 ;00:98A5
        moveq #0,d0
        move.b 12(a0),d0 ;rotate_16yz(rotx): a' = -a
        neg.b d0
        move.b 64(a1,d0.w),d1 ;c
        ext.w d1
        move.b (a1,d0.w),d2 ;s
        ext.w d2
        move.w #500,d0
        bsr M4SpMwb ;z2 = M(500, c)
        move.w d0,d3
        move.w #500,d0
        move.w d2,d1
        bsr M4SpMwb
        neg.w d0 ;y2 = -M(500, s)
        move.w d0,d4
        moveq #0,d0
        move.b 13(a0),d0 ;rotate_16xz(roty)
        move.b 64(a1,d0.w),d1
        ext.w d1
        move.b (a1,d0.w),d2
        ext.w d2
        move.w d3,d0
        bsr M4SpMwb ;z3 = M(z2, c)
        exg d0,d3
        move.w d2,d1
        bsr M4SpMwb
        neg.w d0 ;x2 = -M(z2, s) (DP $04 = 0)
        lea M4_SPP_SAVEPOS,a2 ;scratch: m (3 WORDs)
        add.w (a0),d0
        sub.w M4_LVW_POS,d0
        move.w d0,(a2)
        add.w 2(a0),d4
        sub.w M4_LVW_POS+2,d4
        cmpi.b #SFM_INSIDE,M4_SPP_FM
        bne.s M4SpXcY
        addi.w #50,d4
M4SpXcY:
        move.w d4,2(a2)
        add.w 4(a0),d3
        sub.w M4_LVW_POS+4,d3
        move.w d3,4(a2)
        movea.l a2,a0
        lea M4_LVW_W,a1
        lea M4_SPP_FIREORG,a2 ;scratch b (not read outside the strategies)
        jsr M4LvwRowTimes
        move.w 4(a2),d2
        ble.s M4SpXcBehind
        move.w (a2),d0
        ext.l d0
        asl.l #8,d0
        divs.w d2,d0
        bvs.s M4SpXcBehind
        move.w d0,M4_SPP_XHAIR
        move.w 2(a2),d0
        ext.l d0
        asl.l #8,d0
        divs.w d2,d0
        bvs.s M4SpXcBehind
        move.w d0,M4_SPP_XHAIR+2
M4SpXcBehind:
        movem.l (sp)+,d0-d4/a0-a2
        rts
; 02:FC62: d0 = w, d1 = b (sign-extended byte) -> d0 = sgn * ((|w| * ((2|b|) & $FF)) >> 8).
M4SpMwb:
        movem.l d1-d2,-(sp)
        moveq #0,d2
        tst.w d0
        bpl.s M4SpMwbW
        neg.w d0
        not.w d2
M4SpMwbW:
        tst.w d1
        bpl.s M4SpMwbB
        neg.w d1
        not.w d2
M4SpMwbB:
        add.w d1,d1
        andi.w #$ff,d1
        mulu.w d1,d0
        lsr.l #8,d0
        tst.w d2
        beq.s M4SpMwbDone
        neg.w d0
M4SpMwbDone:
        movem.l (sp)+,d1-d2
        rts

; do_crosshair 03:E0B5 (M4LevelHudSprites; a1 = next SAT entry, d7 = sprite
; number): cockpit and crosshairon, 4 OBJ $E1 (OBJ palette 4) with 8-bit
; offsets from lo8($16F4/$16F6), flips H/V.
M4SpCrosshairObj:
        cmpi.b #SFM_INSIDE,M4_SPP_FM
        bne.s M4SpXoDone
        tst.b M4_SPP_XHAIRON
        beq.s M4SpXoDone
        movem.l d0-d6/a2,-(sp)
        lea M4SpXoTab,a2
        moveq #3,d6
M4SpXoNext:
        move.b M4_SPP_XHAIR+3,d0 ;lo8($16F6)
        add.b 1(a2),d0
        andi.w #$ff,d0
        addi.w #2+128,d0 ;MD y = OAM y + 2 (generate-level-messages.py)
        moveq #0,d1 ;8x8
        move.w #M4_LVHUD_XHAIR,d2
        or.w 2(a2),d2
        move.b M4_SPP_XHAIR+1,d3 ;lo8($16F4)
        add.b (a2),d3
        andi.w #$ff,d3
        addi.w #128,d3
        jsr M4LvHudSpr
        addq.l #4,a2
        dbra d6,M4SpXoNext
        movem.l (sp)+,d0-d6/a2
M4SpXoDone:
        rts
M4SpXoTab: ;dx, dy, VDP flip
        include '../build/m4-cockpit-crosshair.inc'

; ---------------------------------------------------------------------
; Cockpit HUD of the GSU 01:D76B (after the meters, drawn even without
; m_meters): with m_hudrot high byte set ($14C6, cockpit), 4 segments rotated
; by hudrot $14C5 (rot 01:962A) drawn with colour c1 from (112, 96) + P'..Q'
; and mirrored with c2 (GSU line 01:D8B3 = cmd8 type 12, tools/check-cockpit-
; hud.py: 64 angles exact). m_hudcolour 15; m_hudflags bit0 -> c2 = 2, bit1
; -> c1 = 2. GSU (x, y) -> cmd8 (x + 16, y + 16).
M4SpCockpitHud:
        tst.b M4_SPP_HUDON
        beq M4SpHudDone
        movem.l d0-d7/a0-a2,-(sp)
        moveq #15,d6 ;c1
        moveq #15,d7 ;c2
        btst #0,M4_SPP_HUDFLAGS
        beq.s M4SpHudC2
        moveq #2,d7
M4SpHudC2:
        btst #1,M4_SPP_HUDFLAGS
        beq.s M4SpHudC1
        moveq #2,d6
M4SpHudC1:
        lea M4SpHudSegs,a0
        moveq #3,d5
M4SpHudSeg:
        move.w (a0)+,d0
        move.w (a0)+,d1
        bsr M4SpHudRot
        move.w d0,d3 ;P'
        move.w d1,d4
        move.w (a0)+,d0
        move.w (a0)+,d1
        bsr M4SpHudRot ;Q' in d0/d1
        lea M4_SP_HUDREC+16,a1 ;5-WORD line scratch
        move.w #12,(a1)
        move.w d3,d2
        addi.w #112+16,d2
        move.w d2,2(a1)
        move.w d4,d2
        addi.w #96+16,d2
        move.w d2,4(a1)
        move.w d0,d2
        addi.w #112+16,d2
        move.w d2,6(a1)
        move.w d1,d2
        addi.w #96+16,d2
        move.w d2,8(a1)
        move.w d6,d2
        bsr.s M4SpHudLine
        move.w #112+16,d2 ;mirrored: (112 - P'x, 96 - P'y) .. (112 - Q'x, 96 - Q'y)
        sub.w d3,d2
        move.w d2,2(a1)
        move.w #96+16,d2
        sub.w d4,d2
        move.w d2,4(a1)
        move.w #112+16,d2
        sub.w d0,d2
        move.w d2,6(a1)
        move.w #96+16,d2
        sub.w d1,d2
        move.w d2,8(a1)
        move.w d7,d2
        bsr.s M4SpHudLine
        dbra d5,M4SpHudSeg
        movem.l (sp)+,d0-d7/a0-a2
M4SpHudDone:
        rts
; a1 = record (type, x0, y0, x1, y1), d2 = GSU colour -> raw cmd8 record
; (kind 34) with the colour byte HL = c * $11 (solid, no dither).
M4SpHudLine:
        movem.l d0-d3/a2,-(sp)
        mulu.w #$11,d2
        lea M4_SP_HUDREC,a2
        move.l (a1),(a2)
        move.l 4(a1),4(a2)
        move.w 8(a1),8(a2)
        clr.l 10(a2)
        move.w d2,14(a2)
        jsr M4RmRawRecord2
        movem.l (sp)+,d0-d3/a2
        rts
; rot 01:962A: d0 = x, d1 = y, angle hudrot -> d0 = x', d1 = y'.
; S = s8(00:98E5[a]) * 256, C = s8(00:98A5[a]) * 256;
; x' = asr1(hi16(x C + y S)); y' = asr1(hi(x S) - hi(y C) - [lo(y C) < lo(x S)]).
M4SpHudRot:
        movem.l d2-d7/a0,-(sp)
        lea M4IntroShipSine,a0 ;00:98A5
        moveq #0,d2
        move.b M4_LP_HUDROT,d2
        move.b 64(a0,d2.w),d3 ;98E5[a]
        ext.w d3
        lsl.w #8,d3 ;S
        move.b (a0,d2.w),d4
        ext.w d4
        lsl.w #8,d4 ;C
        move.w d0,d5
        muls.w d4,d5 ;x C
        move.w d1,d6
        muls.w d3,d6 ;y S
        add.l d6,d5
        swap d5
        asr.w #1,d5 ;x'
        move.w d0,d6
        muls.w d3,d6 ;x S
        move.w d1,d7
        muls.w d4,d7 ;y C
        move.l d6,d2
        swap d2 ;hi(x S)
        move.l d7,d3
        swap d3 ;hi(y C)
        sub.w d3,d2
        cmp.w d6,d7 ;lo(y C) < lo(x S) (unsigned)
        bhs.s M4SpHudNoBorrow
        subq.w #1,d2
M4SpHudNoBorrow:
        asr.w #1,d2
        move.w d5,d0
        move.w d2,d1
        movem.l (sp)+,d2-d7/a0
        rts
M4SpHudSegs: ;01:D76B (P, Q)
        include '../build/m4-cockpit-hud-segments.inc'
M4_SP_HUDREC equ M4_SPP+32 ;16 bytes: raw cmd8 record, then 10 bytes of line scratch

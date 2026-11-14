; ClearBridge 0B:9347, ClearEarth 0B:9725 and ClearTurn 0B:9D61.
; USA ROM bytecode in build/lot3-strategies/*-rom.txt. Reuse the existing
; original movement, duplication and clear-ship object strategies.
M4_CLEAR_BGX equ M4_PM+32 ;.b $16A0, ClearShip horizontal turn phase
M4_CLEAR_BGSCROLL equ M4_PM+34 ;.w $194F
M4_CLEAR_LASTROT equ M4_PM+36 ;.w $1951

M4ClearBridgeI:
        move.l #M4ClearBridge,32(a0)
        ori.b #$60,M4_LP_PSF
        move.w #-10000,M4_LP_MINY
        move.w #-10000,M4_PM_157D
        ori.b #9,M4_BOSS_PSTRATF
        clr.w M4_WP_W1556
        clr.w M4_WP_W1558
        move.b #163,M4_SC_P1553
M4ClearBridge:
        jsr M4WpViewAngles
        tst.b M4_SC_P1553
        beq.s M4ClearBridgeDup
        subq.b #1,M4_SC_P1553
        moveq #4,d2
        move.w 2(a0),d0
        move.w M4_LP_VIEWCY,d1
        jsr M4LpAchase
        move.w d0,2(a0)
        move.w (a0),d0
        moveq #0,d1
        jsr M4LpAchase
        move.w d0,(a0)
        move.b #85,M4_LP_TOSPEED
        cmpi.w #500,M4_LP_OUTDIST
        bgt.s M4ClearBridgeMove
        addq.w #4,M4_LP_OUTDIST
M4ClearBridgeMove:
        jmp M4PmOnBridge
M4ClearBridgeDup:
        jsr M4SpDupPlayer
        cmpa.w #0,a2
        beq.s M4ClearBridgeDupDone
        move.l #M4TiClBoostInit,32(a2)
M4ClearBridgeDupDone:
        move.l #M4ClearBridgeOut,32(a0)
M4ClearBridgeOut:
        addq.w #3,(a0)
        jmp M4PmOnBridge

M4ClearTurnI:
        move.w #270,M4_WP_W1556
        move.l #M4ClearTurn,32(a0)
        ori.b #$60,M4_LP_PSF
        ori.b #9,M4_BOSS_PSTRATF
        andi.b #$df,M4_LP_GAMEFLAGS
        ori.b #$10,M4_LP_FLYMODE
M4ClearTurn:
        jsr M4WpViewAngles
        tst.w M4_WP_W1556
        beq.s M4ClearTurnDup
        subq.w #1,M4_WP_W1556
        cmpi.w #100,M4_LP_OUTDIST
        blt.s M4ClearTurnCentre
        subq.w #1,M4_LP_OUTDIST
M4ClearTurnCentre:
        move.w 2(a0),d0
        moveq #-40,d1
        moveq #4,d2
        jsr M4LpAchase
        move.w d0,2(a0)
        move.w (a0),d0
        moveq #0,d1
        jsr M4LpAchase
        move.w d0,(a0)
        jmp M4SpInSpaceStrat
M4ClearTurnDup:
        jsr M4SpDupPlayer
        cmpa.w #0,a2
        beq.s M4ClearTurnDupDone
        move.l #M4SxTurn1,32(a2)
        move.b #46,36(a2)
        bclr #F2_SFLAG2,48(a2)
M4ClearTurnDupDone:
        move.l #M4SpInSpaceStrat,32(a0)
        clr.w M4_LP_OUTVY
        jmp M4SpInSpaceStrat

M4ClearEarthI:
        move.l #M4ClearEarthIn,32(a0)
        move.b #20,M4_SC_P1553
        ori.b #8,M4_BOSS_PSTRATF
        ori.b #$60,M4_LP_PSF
M4ClearEarthIn:
        jsr M4WpViewAngles
        moveq #3,d2
        bsr M4ClearEarthCentre
        tst.b M4_SC_P1553
        beq.s M4ClearEarthShipI
        subq.b #1,M4_SC_P1553
        jmp M4SpInSpaceStrat
M4ClearEarthShipI:
        move.l #M4ClearEarthShip,32(a0)
        move.b #40,M4_SC_P1553
        move.b #80,15(a0)
        ori.b #8,M4_BOSS_PSTRATF
        ori.b #$10,M4_LP_FLYMODE
        clr.b M4_CLEAR_BGX
        lea M4PmLimClear,a2 ;same ClearShip flight limits as 0B:9850
        jsr M4PmLimits
        andi.b #$df,M4_LP_GAMEFLAGS
        andi.b #$fb,M4_BOSS_PSTRATF
        ori.b #2,M4_LP_PSF3
        andi.b #$fe,M4_LP_PSF3
        ori.b #$21,M4_BOSS_PSTRATF
        ori.b #$60,M4_LP_PSF
        andi.b #$7f,M4_LP_GAMEFLAGS
        move.b #100,X_SBYTE3(a0)
        bclr #7,X2_FL2(a0)
M4ClearShip:
        move.w #232,M4_CLEAR_BGSCROLL
        clr.w M4_CLEAR_LASTROT
        subq.b #1,X_SBYTE3(a0)
        beq.s M4ClearShipTurn
        moveq #3,d0
        and.w M4_LV_GAMEFRAME,d0
        bne M4ClearShipMove
        moveq #67,d0
        moveq #1,d1
        jsr M4EnSpeedTo
        bra M4ClearShipMove
M4ClearEarthShip:
        ori.b #$10,M4_LP_FLYMODE
        tst.b M4_SC_P1553
        beq M4ClearShip
        subq.b #1,M4_SC_P1553
        jsr M4WpViewAngles
        moveq #4,d2
        bsr M4ClearEarthCentre
        bra M4ClearShip
M4ClearEarthCentre:
        move.w (a0),d0
        moveq #0,d1
        jsr M4LpAchase
        move.w d0,(a0)
        move.w 2(a0),d0
        moveq #-100,d1
        jsr M4LpAchase
        move.w d0,2(a0)
        rts
M4ClearShipTurn:
        move.b #1,X_SBYTE3(a0)
        cmpi.b #254,M4_CLEAR_BGX
        beq.s M4ClearShipBoost
        addq.b #2,M4_CLEAR_BGX
        cmpi.b #222,M4_CLEAR_BGX
        bne.s M4ClearShipScroll
        andi.b #$fd,M4_LP_PSF3
        jsr M4LevelBoostFlame
        M4PlaySfx $32
        bset #7,X2_FL2(a0)
        bra.s M4ClearShipBoost
M4ClearShipScroll:
        bcs.s M4ClearShipTilt
M4ClearShipBoost:
        addq.w #8,M4_LP_PLROTY
        subi.w #256,M4_LP_PLROTX
        ori.b #$80,M4_LP_GAMEFLAGS
        addi.w #100,4(a0)
        subi.w #10,2(a0)
        move.b #120,15(a0)
M4ClearShipTilt:
        subi.b #4,M4_LP_ZTILT
        cmpi.b #$f8,M4_LP_OUTVY ;original little-endian outvy+1, high byte
        bmi.s M4ClearShipMove
        subi.w #32,M4_LP_OUTVY
M4ClearShipMove:
        cmpi.w #50,M4_LP_OUTDIST
        bmi.s M4ClearShipBody
        subq.w #1,M4_LP_OUTDIST
M4ClearShipBody:
        jsr M4LpMove
        addi.w #65,M4_LP_PVIEWZ
        jsr M4EnGen3d
        move.w 4(a0),d0
        sub.w M4_LP_PVIEWZ,d0
        subi.w #4000,d0
        bmi.s M4ClearShipView
        bset #SF_INVISIBLE,49(a0)
M4ClearShipView:
        move.w (a0),d0
        move.w d0,d1
        asr.w #1,d1
        move.w d0,d2
        asr.w #2,d2
        add.w d2,d1
        asr.w #3,d0
        add.w d0,d1
        move.w d1,M4_LP_PVIEWX
        move.w M4_LP_PVIEWY,d0
        moveq #-60,d1
        moveq #4,d2
        jsr M4LpAchase
        move.w d0,M4_LP_PVIEWY
        jsr M4EnMove
        moveq #0,d0
        rts

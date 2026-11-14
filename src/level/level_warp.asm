; End of the space stages (build/research/stage-asteroid1.md section 5.2,
; ROM USA rev0 disassembly, oracle build/research/work/bossE/warp-oracle.py):
; cl_player_mode 0B:A228 (Warp player mode: states 0/1/2 of 200/226/60
; ticks, hyperspace 0B:A49D), the trail generator 0B:8B98 and its trails
; 0B:8CD4 (shape BF70), the friends' ships clshipWARPa/b/c 06:BE05/BE53/
; BEA1 (06:BD07/BD85, common 06:BEF0) and psvar_word1/2 $1556/$1558.
M4_WP_W1556 equ M4_SPP+22 ;.w psvar_word1 $1556 (state timer)
M4_WP_W1558 equ M4_SPP+24 ;.w psvar_word2 $1558 (hyperspace speed)
M4_WP_STATE equ M4_SPP+26 ;.b player stratstate $1CDC (Warp)
M4_WP_WHITE equ M4_SPP+27 ;.b gamestart white fade: ticks done (0..40), $FF fading to black
X_W2F equ -$8000+62 ;.w +$2F lateral speed of clshipWARPa/b

; Strategy addresses of this unit (searched after M4LevelStrategies).
M4LevelStrategies2:
        dc.l $06be05,M4StratClshipWarpA
        dc.l $06be53,M4StratClshipWarpB
        dc.l $06bea1,M4StratClshipWarpC
        dc.l $08816e,M4StratBoss1 ;Asteroid Belt 1 boss (level_boss1.asm)
        dc.l 0

; cl_player_mode (map kind $1D): DB=$7E; calcteamdamage 06:BB22; jsl the
; player mode routine (0B:A228 Warp; 0B:9558 ClearDemo has its own kind);
; playerflymode &= $EF. a2 = block record (8 = routine).
M4LvClPlayerMode:
        jsr M4LvCalcTeamDamage
        move.l 8(a2),d0
        move.l a3,-(sp)
        bsr M4LevelFindPlayerMode
        move.l a3,d0
        beq.s M4LvClpmBad
        move.l a3,LV_PLAYER+32
        movea.l (sp)+,a3
        andi.b #$ef,M4_LP_FLYMODE
        moveq #0,d0
        rts
M4LvClpmBad:
        movea.l (sp)+,a3
        moveq #-1,d0 ;player mode not ported
        rts

; d0 = original player strategy address (24-bit) -> a3 = port Istrat or 0.
; Searched like M4LevelFindStrategy: a stage file adds its own table
; (address.l, Istrat.l; 0 ends) to M4LevelPlayerModeTables.
M4LevelFindPlayerMode:
        movem.l d1/a4,-(sp)
        lea M4LevelPlayerModeTables,a4
M4LvPmTable:
        move.l (a4)+,d1
        beq.s M4LvPmNone
        movea.l d1,a3
M4LvPmFind:
        move.l (a3)+,d1
        beq.s M4LvPmTable
        cmp.l d1,d0
        beq.s M4LvPmFound
        addq.l #4,a3
        bra.s M4LvPmFind
M4LvPmFound:
        movea.l (a3),a3
        movem.l (sp)+,d1/a4
        rts
M4LvPmNone:
        suba.l a3,a3
        movem.l (sp)+,d1/a4
        rts
M4LevelPlayerModeTables:
        dc.l M4LevelPlayerModes
        dc.l M4PlayerModesArmada ;level_armada_player.asm
        dc.l M4PlayerModesMeteor ;level_meteor.asm
        dc.l M4PlayerModesVenom ;level_venom.asm
        dc.l 0
M4LevelPlayerModes:
        dc.l $0b9347,M4ClearBridgeI
        dc.l $0b9725,M4ClearEarthI
        dc.l $0b9d61,M4ClearTurnI
        dc.l $0ba228,M4WpIstrat ;Warp: stratptr = A23D
        dc.l $0b9558,M4CdIstrat ;ClearDemo
        dc.l 0

        include 'stages/level_clear_modes.asm'

; Warp 0B:A23D (Istrat) / A296 (every tick). a0 = player.
M4WpIstrat:
        move.l #M4WpStrat,32(a0)
        ori.b #$60,M4_LP_PSF
        ori.b #$09,M4_BOSS_PSTRATF ;novdistC | inseq
        clr.w M4_WP_W1558
        ori.b #1,M4_LP_GAMEFLAGS
        andi.b #$df,M4_LP_GAMEFLAGS
        move.w #200,M4_WP_W1556
        ori.b #$10,M4_LP_FLYMODE ;wobble
        ori.b #8,M4_LP_PSF3
        clr.b M4_WP_STATE
M4WpStrat:
        tst.b M4_WP_STATE
        bne.s M4WpState1
        moveq #3,d0 ;outdist - 1 every 4th gameframe ($15BD & 3)
        and.w M4_LV_GAMEFRAME,d0
        bne.s M4WpS0Dist
        subq.w #1,M4_LP_OUTDIST
M4WpS0Dist:
        bsr M4WpCentre4
        bsr M4WpViewAngles ;0B:AB4F
        subq.w #1,M4_WP_W1556
        bne.s M4WpState1
        addq.b #1,M4_WP_STATE
        move.w #226,M4_WP_W1556
        andi.b #$ef,M4_LP_FLYMODE
M4WpState1:
        cmpi.b #1,M4_WP_STATE
        bne.s M4WpState2
        ;$1556 == 20: music $F1 (not modelled)
        cmpi.w #500,M4_LP_OUTDIST
        bgt.s M4WpS1Dist
        addq.w #5,M4_LP_OUTDIST
M4WpS1Dist:
        addi.w #$100,M4_LP_OUTVY ;the camera turns around the ship
        bsr M4WpCentre4
        subq.w #1,M4_WP_W1556
        bne.s M4WpState2
        addq.b #1,M4_WP_STATE
        bsr M4WpMakeGenerator
        move.w #60,M4_WP_W1556 ;music $08 (not modelled)
M4WpState2:
        cmpi.b #2,M4_WP_STATE
        bne M4SpInSpaceStrat ;jml 0B:B95C
        move.w M4_LP_OUTVY,d0 ;Achase16_4(outvy, 0)
        moveq #0,d1
        moveq #4,d2
        jsr M4LpAchase
        move.w d0,M4_LP_OUTVY
        andi.b #$fe,M4_LP_GAMEFLAGS
        subi.w #9,M4_LP_OUTDIST
        move.w 2(a0),d0
        moveq #20,d1
        moveq #3,d2
        jsr M4LpAchase
        move.w d0,2(a0)
        tst.w M4_WP_W1556
        beq.s M4WpHyperInit
        subq.w #1,M4_WP_W1556
        bra.s M4WpSpeedUp ;brl 0B:A4D1
; A464: music $0E; dupplayer with clshipboost (entry 06:C11B, sbyte2 $13),
; the player invisible; hyperspace A49D; engine off.
M4WpHyperInit:
        jsr M4CdDupPlayer ;copy running M4StratClshipBoost
        move.l M4_LV_LAST,d0
        beq.s M4WpNoCopy
        movea.l d0,a2
        move.b #$13,37(a2)
M4WpNoCopy:
        move.l #M4WpHyper,32(a0)
        move.b #20,M4_SC_P1553
        andi.b #$fd,M4_LP_PSF3
; 0B:A49D hyperspace.
M4WpHyper:
        addq.w #2,M4_WP_W1558
        subq.b #1,M4_SC_P1553
        bne.s M4WpSpeedUp
        move.b #1,M4_SC_P1553
        ori.b #2,M4_BOSS_PSTRATF ;trails every tick
        clr.b M4_SC_DOTS ;dotsflag $16FB = 0, $16FC = 0: no stars
        bra.s M4WpAdvance
M4WpSpeedUp: ;0B:A4D1
        cmpi.w #400,M4_WP_W1558
        bgt.s M4WpAdvance
        addq.w #1,M4_WP_W1558
M4WpAdvance:
        move.w M4_WP_W1558,d0
        add.w d0,M4_LP_PVIEWZ
        add.w d0,4(a0)
        bra M4SpInSpaceStrat

; y = Achase16_4(y, -40), x = Achase16_4(x, 0).
M4WpCentre4:
        move.w 2(a0),d0
        moveq #-40,d1
        moveq #4,d2
        jsr M4LpAchase
        move.w d0,2(a0)
        move.w (a0),d0
        moveq #0,d1
        jsr M4LpAchase
        move.w d0,(a0)
        rts
; 0B:AB4F: outvx, outvy Achase16_3 -> 0.
M4WpViewAngles:
        move.w M4_LP_OUTVX,d0
        moveq #0,d1
        moveq #3,d2
        jsr M4LpAchase
        move.w d0,M4_LP_OUTVX
        move.w M4_LP_OUTVY,d0
        jsr M4LpAchase
        move.w d0,M4_LP_OUTVY
        rts

; 0B:A390: nullshape behind the player running 0B:8B98.
M4WpMakeGenerator:
        movem.l d0/a0,-(sp)
        jsr M4LevelAlloc
        move.l a0,d0
        beq.s M4WpMgDone
        move.l #M4WpGenerator,32(a0)
M4WpMgDone:
        movem.l (sp)+,d0/a0
        rts

; 0B:8B98 / 8BAE: roty $80, z = player.z + 4000; a trail (shape BF70) on
; even gameframes, every tick once $14DF bit1 is set.
M4WpGenerator:
        move.b #$80,13(a0)
        move.w 4(a1),d0
        addi.w #4000,d0
        move.w d0,4(a0)
        btst #1,M4_BOSS_PSTRATF
        bne.s M4WpGenMake
        btst #0,M4_LV_GAMEFRAME+1
        bne M4WpGenDone
M4WpGenMake:
        move.l a0,-(sp)
        movea.l a0,a3
        jsr M4LevelAlloc ;1F:D54B behind the generator
        move.l a0,d0
        beq M4WpGenFail
        move.w #M4_SH_WARP_TRAIL,d0
        jsr M4LevelSetShape
        bset #SF_COLLDISABLE,49(a0)
        move.l #M4WpTrail,32(a0)
        jsr M4IntroRandom ;x = rnd + 256 (rnd & 1) - 256
        move.w d0,d3
        jsr M4IntroRandom
        andi.w #1,d0
        lsl.w #8,d0
        or.w d3,d0
        subi.w #256,d0
        move.w d0,(a0)
        jsr M4IntroRandom ;y likewise
        move.w d0,d3
        jsr M4IntroRandom
        andi.w #1,d0
        lsl.w #8,d0
        or.w d3,d0
        subi.w #256,d0
        move.w d0,2(a0)
        jsr M4IntroRandom
        move.b d0,14(a0) ;rotz
        move.b d0,d5 ;1F:CC78: (0, 50) by rotz (BYTE products)
        moveq #0,d3
        moveq #50,d4
        jsr M4WeaponRotatePair
        ext.w d3
        add.w d3,(a0)
        ext.w d4
        add.w d4,2(a0)
        subi.w #60,2(a0)
        move.w 4(a3),4(a0) ;z = the generator's
        move.b 12(a3),12(a0) ;1F:DAD9 copies the position (rotation unchanged: 0)
        movea.l (sp)+,a0
        bra.s M4WpGenDone
M4WpGenFail:
        movea.l (sp)+,a0
M4WpGenDone:
        moveq #0,d0
        rts
; 0B:8CD4: z -= 80 (atzremove removes it behind the view).
M4WpTrail:
        subi.w #80,4(a0)
        moveq #0,d0
        rts

; clshipWARPa 06:BE05 / BE38: shadow, no zremove, sword1 365, sbyte2 20,
; +$2F 10, rotz $C0; 06:BD07; dZ 100, dY -20; 06:BEF0.
M4StratClshipWarpA:
        bsr M4CwInit
        move.w #365,40(a0)
        move.w #10,X_W2F(a0)
        move.b #$c0,14(a0)
        move.l #M4ClshipWarpATick,32(a0)
M4ClshipWarpATick:
        btst #F2_SFLAG1,48(a0) ;06:BD07
        bne.s M4CwaBack
        cmpi.w #-30,(a0)
        blt.s M4CwaMove
        addq.b #2,14(a0)
        btst #0,M4_LV_GAMEFRAME+1
        bne.s M4CwaMove
        cmpi.w #-5,X_W2F(a0)
        beq.s M4CwaTurned
        subq.w #1,X_W2F(a0)
        bra.s M4CwaMove
M4CwaTurned:
        bset #F2_SFLAG1,48(a0)
M4CwaBack:
        tst.w X_W2F(a0)
        beq.s M4CwaMove
        moveq #7,d0
        and.w M4_LV_GAMEFRAME,d0
        bne.s M4CwaMove
        addq.w #1,X_W2F(a0)
M4CwaMove:
        move.w X_W2F(a0),d0
        add.w d0,(a0)
        moveq #100,d5
        moveq #-20,d6
        bra M4CwBody
; clshipWARPb 06:BE53 / BE86: mirror (06:BD85), sword1 384, +$2F -10, rotz
; $40; dZ 200, dY -20.
M4StratClshipWarpB:
        bsr M4CwInit
        move.w #384,40(a0)
        move.w #-10,X_W2F(a0)
        move.b #$40,14(a0)
        move.l #M4ClshipWarpBTick,32(a0)
M4ClshipWarpBTick:
        btst #F2_SFLAG1,48(a0)
        bne.s M4CwbBack
        cmpi.w #30,(a0)
        bgt.s M4CwbMove
        subq.b #2,14(a0)
        btst #0,M4_LV_GAMEFRAME+1
        bne.s M4CwbMove
        cmpi.w #5,X_W2F(a0)
        beq.s M4CwbTurned
        addq.w #1,X_W2F(a0)
        bra.s M4CwbMove
M4CwbTurned:
        bset #F2_SFLAG1,48(a0)
M4CwbBack:
        tst.w X_W2F(a0)
        beq.s M4CwbMove
        moveq #7,d0
        and.w M4_LV_GAMEFRAME,d0
        bne.s M4CwbMove
        subq.w #1,X_W2F(a0)
M4CwbMove:
        move.w X_W2F(a0),d0
        add.w d0,(a0)
        move.w #200,d5
        moveq #-20,d6
        bra.s M4CwBody
; clshipWARPc 06:BEA1 / BEC7: sword1 313; x = Achase16_4(x, 0); dZ 300, dY -30.
M4StratClshipWarpC:
        bsr.s M4CwInit
        move.w #313,40(a0)
        move.l #M4ClshipWarpCTick,32(a0)
M4ClshipWarpCTick:
        move.w (a0),d0
        moveq #0,d1
        moveq #4,d2
        jsr M4LpAchase
        move.w d0,(a0)
        move.w #300,d5
        moveq #-30,d6
        bra.s M4CwBody
M4CwInit:
        bset #F2_SHADOW,48(a0) ;$1D |= 8
        bclr #3,45(a0) ;no atzremove
        move.b #20,37(a0) ;sbyte2
        rts
; 06:BEF0: sword1 0 -> clshipboost_I 06:C115; sword1 - 1; z =
; Achase16_4(z, player.z + dZ); y = Achase16_4(y, player.y + dY); rotz =
; Achase8_5(rotz, 0); rotx = Achase8_5(rotx, player.rotx); addplayerZ;
; z += $1558.
M4CwBody:
        tst.w 40(a0)
        bne.s M4CwLive
        jmp M4StratClshipBoost
M4CwLive:
        subq.w #1,40(a0)
        lea LV_PLAYER,a2
        move.w 4(a0),d0
        move.w 4(a2),d1
        add.w d5,d1
        moveq #4,d2
        jsr M4LpAchase
        move.w d0,4(a0)
        move.w 2(a0),d0
        move.w 2(a2),d1
        add.w d6,d1
        jsr M4LpAchase
        move.w d0,2(a0)
        move.b 14(a0),d0
        moveq #0,d1
        moveq #5,d2
        jsr M4LpAchase8
        move.b d0,14(a0)
        move.b 12(a0),d0
        move.b 12(a2),d1
        jsr M4LpAchase8
        move.b d0,12(a0)
        jsr M4EnAddPZ
        move.w M4_WP_W1558,d0
        add.w d0,4(a0)
        moveq #0,d0
        rts

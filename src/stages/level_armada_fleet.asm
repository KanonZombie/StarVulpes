; Space Armada: the fleet outside the ships (map 0D:A8A7.., 0D:AB67..,
; 0D:AE09.., 0D:B17C..). Specification: build/research/stage-armada.md,
; annex "estrategias de la flota" (USA rev0); every routine below was re-read
; in the ROM bytes (build/agent-armada/dis-fleet.txt, build/research/
; strat_trace.py) and is compared tick by tick with the ROM, running the
; stage script, by build/agent-armada-fleet/armada-oracle.py (FLEET.md).
; up1man 08:D85A is M4StratUp1man (level_meteor.asm).
; Conventions of level_objects.asm: a0 object, a1 player; d0 = 0 keep /
; nonzero deferred removal (1F:D501 with x == al1pt). "d < K" = N bit of the
; 16-bit (8-bit) difference. Sounds (03:B7E5 and the positional 03:B705/
; B71D) are not ported. ROM sword2 ($28) is the port WORD 42(a0) (the map's
; setalvar $28 writes there).

; ---------------------------------------------------------------------
; ships 0A:B304 (far ships): colldisable, count 70; every tick count-- (0 ->
; deferred removal), x += sword1, y += sword2, z += 60 (no pviewvelz).
M4ArShips:
        bset #SF_COLLDISABLE,49(a0)
        move.b #70,19(a0)
        move.l #M4ArShipsTick,32(a0)
M4ArShipsTick:
        moveq #0,d7
        subq.b #1,19(a0)
        bne M4ArShipsMove
        moveq #1,d7
M4ArShipsMove:
        move.w 40(a0),d0
        add.w d0,(a0)
        move.w 42(a0),d0
        add.w d0,2(a0)
        addi.w #60,4(a0)
        move.l d7,d0
        rts

; ---------------------------------------------------------------------
; szaco5 0A:B34C (zaco_7): normal pointers, HP 2, AP 8, debris DAAC, roty
; $80, enemy1, animframe $80, relexplode, vel 30, engine flame (06:916D).
M4ArSzaco5:
        move.l #M4ArSzaco5Tick,32(a0)
        jsr M4LvNormPtrs
        move.b #2,38(a0)
        move.b #8,39(a0)
        move.w #$daac,X_DEBRIS(a0)
        move.b #$80,13(a0)
        ori.b #CF_ENEMY1,44(a0)
        move.b #$80,16(a0)
        bset #F2_RELEXPLODE,48(a0)
        move.b #30,15(a0)
        jsr M4WpMakeEngine
; 0A:B38E: state 0 chase the player (Achase8_2) until ZD < 1500 -> fire $0C
; at the player, state 1: sbyte1 $20, wings open (anim -> 9), ZD < 200 ->
; vel 40, state 2, roty += (rnd & $1F) - 15; state 2: 32 ticks rotx -= 8,
; then state 3 (1F:DB66: the strategy runs again: banktoplayer).
M4ArSzaco5Tick:
        movea.l a1,a2
        tst.b X_STATE(a0)
        bne M4ArSz5St1
        moveq #2,d2
        bsr M4ArChaseAim
        jsr M4EnZD
        subi.w #1500,d0
        bpl M4ArSz5St1
        moveq #M4_WT_RSE,d0
        moveq #0,d3
        moveq #0,d4
        moveq #0,d5
        moveq #0,d6
        moveq #0,d7
        movea.l a1,a3
        jsr M4EnFire
        movea.l a1,a2
        addq.b #1,X_STATE(a0)
M4ArSz5St1:
        cmpi.b #1,X_STATE(a0)
        bne M4ArSz5St2
        move.b #$20,36(a0)
        move.b 16(a0),d0
        andi.b #$7f,d0
        cmpi.b #9,d0
        beq M4ArSz5Near
        move.b 16(a0),d0
        moveq #1,d1
        moveq #10,d2
        jsr M4WpAddAnim
        move.b d0,16(a0)
M4ArSz5Near:
        jsr M4EnZD
        subi.w #200,d0
        bpl M4ArSz5St2
        move.b #40,15(a0)
        addq.b #1,X_STATE(a0)
        jsr M4IntroRandom
        andi.b #$1f,d0
        subi.b #15,d0
        move.b d0,37(a0)
        add.b d0,13(a0)
M4ArSz5St2:
        cmpi.b #2,X_STATE(a0)
        bne M4ArSz5St3
        tst.b 36(a0)
        bne M4ArSz5Loop
        addq.b #1,X_STATE(a0) ;1F:DB66: state 3, strategy again from the top
        bra M4ArSz5Bank
M4ArSz5Loop:
        subq.b #1,36(a0)
        subq.b #8,12(a0)
M4ArSz5St3:
        cmpi.b #3,X_STATE(a0)
        bne M4ArSz5Move
M4ArSz5Bank:
        bsr M4ArBankToPlayer
M4ArSz5Move:
        jsr M4EnGen3d ;1F:D5A7
        jsr M4EnMove
        jsr M4EnAddPZ
        jsr M4WpUpdateEngine ;06:91DF
        moveq #0,d0
        rts

; ---------------------------------------------------------------------
; winglazerman 08:DB39 (w_l): hitflash / expstrat 08:DDA8, HP 8, AP 16,
; vel 40, shadow, sbyte2 = 2 cycles.
M4ArWingLazer:
        move.l #M4ArWlApproach,32(a0)
        move.l #M4LcHitFlash,X_COLL(a0)
        move.l #M4ArWlExp,X_EXP(a0)
        move.b #8,38(a0)
        move.b #16,39(a0)
        move.b #40,15(a0)
        bset #F2_SHADOW,48(a0)
        move.b #2,37(a0)
; 08:DB76: chase the player (Achase8_2); ZD < 1000 -> cycle.
M4ArWlApproach:
        movea.l a1,a2
        moveq #2,d2
        bsr M4ArChaseAim
        jsr M4EnZD
        subi.w #1000,d0
        bmi M4ArWlCycle
; 08:DBFE: v = gen3d, pos += v, z += pviewvelz.
M4ArWlMove:
        jsr M4EnGen3d
        jsr M4EnMove
        jsr M4EnAddPZ
        moveq #0,d0
        rts
; 08:DC5D: sbyte2 cycles left -> turn (64 ticks), else leave.
M4ArWlCycle:
        tst.b 37(a0)
        beq M4ArWlLeaveInit
        subq.b #1,37(a0)
        move.l #M4ArWlTurn,32(a0)
        move.b #$40,36(a0)
; 08:DC78: speedto(20, 1), roty += 4; sbyte1 ticks, then attack.
M4ArWlTurn:
        moveq #20,d0
        moveq #1,d1
        jsr M4EnSpeedTo
        addq.b #4,13(a0)
        tst.b 36(a0)
        beq M4ArWlAttackInit
        subq.b #1,36(a0)
        bra M4ArWlMove
M4ArWlAttackInit:
        move.l #M4ArWlAttack,32(a0)
        move.b #30,36(a0)
        move.b #5,X_SBYTE3(a0)
; 08:DCAD: speedto(0, 1), chase the player; every 4th gameframe two $0C
; lasers (-7,0,0)/(+6,0,0), rotx + sbyte3, roty +4/-4, no target; sbyte3--.
M4ArWlAttack:
        moveq #0,d0
        moveq #1,d1
        jsr M4EnSpeedTo
        movea.l a1,a2
        moveq #2,d2
        bsr M4ArChaseAim
        moveq #3,d0
        and.w M4_LV_GAMEFRAME,d0
        bne M4ArWlAttackNext
        moveq #M4_WT_RSE,d0
        moveq #-7,d3
        moveq #0,d4
        moveq #0,d5
        move.b X_SBYTE3(a0),d6
        moveq #4,d7
        suba.l a3,a3
        jsr M4EnFire
        moveq #M4_WT_RSE,d0
        moveq #6,d3
        moveq #-4,d7
        jsr M4EnFire
        subq.b #1,X_SBYTE3(a0)
M4ArWlAttackNext:
        tst.b 36(a0)
        beq M4ArWlCycle
        subq.b #1,36(a0)
        bra M4ArWlMove
; 08:DC19: count 100; DC2A: speedto(50, 1), roty Achase8_4 -> 0, rotx ->
; $FB; count-- (0: deferred removal); move.
M4ArWlLeaveInit:
        move.l #M4ArWlLeave,32(a0)
        move.b #100,19(a0)
M4ArWlLeave:
        moveq #50,d0
        moveq #1,d1
        jsr M4EnSpeedTo
        moveq #4,d2
        move.b 13(a0),d0
        moveq #0,d1
        jsr M4EnChase8
        move.b d0,13(a0)
        move.b 12(a0),d0
        moveq #-5,d1
        jsr M4EnChase8
        move.b d0,12(a0)
        moveq #0,d7
        subq.b #1,19(a0)
        bne M4ArWlLeaveMove
        moveq #1,d7
M4ArWlLeaveMove:
        jsr M4EnGen3d
        jsr M4EnMove
        jsr M4EnAddPZ
        move.l d7,d0
        rts
; expstrat 08:DDA8: wing broken ($14D8 & $18) or no beamball (!$14DA & $10)
; -> item7 (C478, 08:DDEC) at the object; then explode_Istrat.
M4ArWlExp:
        move.b M4_LP_PSF,d0
        andi.b #$18,d0
        bne M4ArWlDrop
        btst #4,M4_LP_PSF3
        bne M4ArWlExplode
M4ArWlDrop:
        move.w #$c478,d0
        bsr M4ArCreateHdr
        beq M4ArWlExplode
        move.l #M4StratItem7,32(a2)
        move.l (a0),(a2)
        move.w 4(a0),4(a2)
M4ArWlExplode:
        jmp M4LevelExplode

; ---------------------------------------------------------------------
; ship1a 08:A386 (ship_1): collstrat 08:A4DE, expstrat 08:A4D4, HP 20,
; AP 16, v = gen3d once, enemy1.
M4ArShip1a:
        move.l #M4ArShip1aTick,32(a0)
        move.l #M4ArShip1aColl,X_COLL(a0)
        move.l #M4ArShip1aExp,X_EXP(a0)
        move.b #20,38(a0)
        move.b #16,39(a0)
        jsr M4EnGen3d
        ori.b #CF_ENEMY1,44(a0)
; 08:A3D3: y -= 1; player not behind (N(pz - z) clear) -> move. HP 0:
; burning (even gameframes a large explosion moved by rnd, every 8th
; (gameframe + al1pt) smoke AE29), odd gameframes fall into the fire test;
; HP <= 10 fire every 16th, else every 4th (gameframe + al1pt): $0C at the
; player with rotx/roty offsets (rnd & 7) - 3.
M4ArShip1aTick:
        subq.w #1,2(a0)
        move.w 4(a1),d0
        sub.w 4(a0),d0
        bpl M4ArShip1aMove
        tst.b 38(a0)
        bne M4ArShip1aFireTest
        bset #F2_SFLAG1,48(a0) ;first time: sound $21 (not ported)
        btst #0,M4_LV_GAMEFRAME+1
        bne M4ArShip1aFireTest
        jsr M4FxLarge
        beq M4ArShip1aMove
        jsr M4FxRandomPos
        bset #F2_NOPOLYEXP,48(a2)
        bsr M4ArPhase
        andi.b #7,d0
        bne M4ArShip1aMove
        jsr M4FxSmoke
        beq M4ArShip1aMove
        move.w #$ae29,d0
        bsr M4ArSetShapeA2
        bra M4ArShip1aMove
M4ArShip1aFireTest:
        bsr M4ArPhase
        moveq #15,d1
        cmpi.b #10,38(a0)
        bls M4ArShip1aMask
        moveq #3,d1
M4ArShip1aMask:
        and.b d1,d0
        bne M4ArShip1aMove
        jsr M4IntroRandom
        andi.b #7,d0
        subq.b #3,d0
        move.b d0,d6
        jsr M4IntroRandom
        andi.b #7,d0
        subq.b #3,d0
        move.b d0,d7
        moveq #M4_WT_RSE,d0
        moveq #0,d3
        moveq #0,d4
        moveq #0,d5
        movea.l a1,a3
        jsr M4EnFire
M4ArShip1aMove: ;08:A4CB: addplayerZ, then pos += v
        jsr M4EnAddPZ
        jsr M4EnMove
        moveq #0,d0
        rts
; expstrat 08:A4D4 (every tick with HP 0): nohitaffect, then the strategy.
M4ArShip1aExp:
        bset #SF_NOHITAFFECT,49(a0)
        bra M4ArShip1aTick
; collstrat 08:A4DE: box HF2 (hitflags bit1): large explosion at the
; collider (linked behind it), hitflags 0, sound $24, hitflash; else no
; damage: hitflags 0, collide off, the strategy.
M4ArShip1aColl:
        btst #1,20(a0)
        beq M4ArShip1aNoDamage
        move.w 62(a0),d0
        beq M4ArShip1aCollHit
        movea.w d0,a3
        move.l a0,-(sp)
        move.l M4_LV_CREATOR,-(sp)
        move.l a3,M4_LV_CREATOR
        movea.l a3,a0
        jsr M4FxLarge
        beq M4ArShip1aCollNo
        bset #F2_NOPOLYEXP,48(a2)
M4ArShip1aCollNo:
        move.l (sp)+,M4_LV_CREATOR
        movea.l (sp)+,a0
M4ArShip1aCollHit:
        clr.b 20(a0)
        jmp M4LcHitFlash
M4ArShip1aNoDamage:
        clr.b 20(a0)
        bclr #SF_COLLIDE,49(a0)
        jmp M4LcStrategy

; ---------------------------------------------------------------------
; ship2 08:9E1F (ship_3, entry ship): no pointers, HP $FF, AP 16, roty $80,
; enemy1, vz -40; gameflags stratdone1/2 cleared; sbyte1 39; type |= 1.
M4ArShip2:
        move.l #M4ArShip2Approach,32(a0)
        jsr M4LvZeroPtrs
        move.b #$ff,38(a0)
        move.b #16,39(a0)
        move.b #$80,13(a0)
        ori.b #CF_ENEMY1,44(a0)
        move.w #-40,10(a0)
        andi.b #$e7,M4_LP_GAMEFLAGS
        move.b #39,36(a0)
        bset #0,45(a0)
; 08:9E6B: x = Achase16_5(x, 0), y = Achase16_4(y, viewCY); ZD < 2000 ->
; enter when |px - x| < 120, else fail.
M4ArShip2Approach:
        bsr M4ArShip2Centre
        move.w (a1),d0
        sub.w (a0),d0
        bpl M4ArShip2Dx
        neg.w d0
M4ArShip2Dx:
        subi.w #120,d0
        movea.l a1,a2
        bpl M4ArShip2Far
        jsr M4EnZD
        subi.w #2000,d0
        bmi M4ArShip2EnterInit
        bra M4ArShip2Move
M4ArShip2Far:
        jsr M4EnZD
        subi.w #2000,d0
        bmi M4ArShip2FailInit
M4ArShip2Move: ;08:9EDE: pos += v, z += pviewvelz
        jsr M4EnMove
        jsr M4EnAddPZ
        moveq #0,d0
        rts
; 08:9EE7: stratdone2; 9EFC: moves aside (vx -/+ 5 up to 65).
M4ArShip2FailInit:
        move.l #M4ArShip2Fail,32(a0)
        bset #4,M4_LP_GAMEFLAGS
M4ArShip2Fail:
        btst #AF_LEFTPL,51(a0)
        bne M4ArShip2FailLeft
        cmpi.w #60,6(a0)
        bgt M4ArShip2Move
        addq.w #5,6(a0)
        bra M4ArShip2Move
M4ArShip2FailLeft:
        cmpi.w #-60,6(a0)
        blt M4ArShip2Move
        subq.w #5,6(a0)
        bra M4ArShip2Move
; 08:9F44: notdie; 9F59: player dead -> fail; medium speed forced; centred;
; ZD < 300 -> inside; else colldisable, noctrl|nofire, the player pulled to
; (0, -60), inseq, out of the cockpit.
M4ArShip2EnterInit:
        move.l #M4ArShip2Enter,32(a0)
        bset #5,M4_BOSS_PSTRATF
M4ArShip2Enter:
        tst.b M4_LP_PSF2
        bmi M4ArShip2FailInit
        move.b #65,15(a1)
        move.w #65,M4_LP_PVIEWVZ
        move.b #65,M4_LP_MEDSPEED
        move.b #65,M4_LP_TOSPEED
        bsr M4ArShip2Centre
        movea.l a1,a2
        jsr M4EnZD
        subi.w #300,d0
        bmi M4ArShip2Inside
        bset #SF_COLLDISABLE,49(a0)
        ori.b #$60,M4_LP_PSF
        move.w 2(a1),d0
        moveq #-60,d1
        moveq #3,d2
        jsr M4LpAchase
        move.w d0,2(a1)
        move.w (a1),d0
        moveq #0,d1
        jsr M4LpAchase
        move.w d0,(a1)
        bsr M4ArPullCommon
        bra M4ArShip2Move
; 08:A00C (every tick): stratdone1, $14D8 &= $1F, vz -40.
M4ArShip2Inside:
        move.l #M4ArShip2Inside,32(a0)
        bset #3,M4_LP_GAMEFLAGS
        andi.b #$1f,M4_LP_PSF
        move.w #-40,10(a0)
        bra M4ArShip2Move
M4ArShip2Centre:
        move.w (a0),d0
        moveq #0,d1
        moveq #5,d2
        jsr M4LpAchase
        move.w d0,(a0)
        move.w 2(a0),d0
        move.w M4_LP_VIEWCY,d1
        moveq #4,d2
        jsr M4LpAchase
        move.w d0,2(a0)
        rts
; inseq; cockpit view ($14DD 3) -> 4 and changeviewmode 06:BA91.
M4ArPullCommon:
        bset #3,M4_BOSS_PSTRATF
        cmpi.b #SFM_INSIDE,M4_SPP_FM
        bne M4ArPullDone
        move.b #SFM_TONORM,M4_SPP_FM
        movem.l a0-a1,-(sp)
        jsr M4SpChangeView
        movem.l (sp)+,a0-a1
M4ArPullDone:
        rts

; sdoor1 0A:B50A (s_door_1): colldisable, animframe $80, type |= 1.
; B52A: at the ship (sword1) z - 350, z += pviewvelz; stratdone2 -> close;
; gameflags2 bit0 -> open; player in front and ZD >= 320 -> close; else open.
M4ArSDoor1:
        bset #SF_COLLDISABLE,49(a0)
        move.l #M4ArSDoor1Tick,32(a0)
        move.b #$80,16(a0)
        bset #0,45(a0)
M4ArSDoor1Tick:
        move.w 40(a0),d0
        movea.w d0,a2
        move.l (a2),(a0)
        move.w 4(a2),d0
        subi.w #350,d0
        move.w d0,4(a0)
        jsr M4EnAddPZ
        btst #4,M4_LP_GAMEFLAGS
        bne M4ArSDoorClose
        btst #0,M4_AR_GF2
        bne M4ArSDoorOpen
        move.w 4(a1),d0
        sub.w 4(a0),d0
        bpl M4ArSDoorOpen
        movea.l a1,a2
        jsr M4EnZD
        subi.w #320,d0
        bmi M4ArSDoorOpen
M4ArSDoorClose: ;anim 9: sound 03:B71D; anim != 0: anim - 1
        move.b 16(a0),d0
        andi.b #$7f,d0
        beq M4ArSDoorDone
        move.b 16(a0),d0
        moveq #-1,d1
        moveq #10,d2
        jsr M4WpAddAnim
        move.b d0,16(a0)
        bra M4ArSDoorDone
M4ArSDoorOpen: ;anim 0: sound 03:B705; anim 9: gameflags2 &= ~1; else + 1
        move.b 16(a0),d0
        andi.b #$7f,d0
        cmpi.b #9,d0
        bne M4ArSDoorOpening
        bclr #0,M4_AR_GF2
        bra M4ArSDoorDone
M4ArSDoorOpening:
        move.b 16(a0),d0
        moveq #1,d1
        moveq #10,d2
        jsr M4WpAddAnim
        move.b d0,16(a0)
M4ArSDoorDone:
        moveq #0,d0
        rts
; sdoor2 0A:B5FD (s_door_2): as sdoor1, stratdone2 cleared. B625:
; stratdone2 -> invisible; at the ship z - 40 (no pviewvelz); ZD < 40 ->
; anim + 1 up to 9.
M4ArSDoor2:
        bset #SF_COLLDISABLE,49(a0)
        move.l #M4ArSDoor2Tick,32(a0)
        move.b #$80,16(a0)
        bset #0,45(a0)
        bclr #4,M4_LP_GAMEFLAGS
M4ArSDoor2Tick:
        btst #4,M4_LP_GAMEFLAGS
        beq M4ArSDoor2Pos
        bset #3,X2_FL4(a0)
        bset #SF_INVISIBLE,49(a0)
M4ArSDoor2Pos:
        move.w 40(a0),d0
        movea.w d0,a2
        move.l (a2),(a0)
        move.w 4(a2),d0
        subi.w #40,d0
        move.w d0,4(a0)
        movea.l a1,a2
        jsr M4EnZD
        subi.w #40,d0
        bpl M4ArSDoorDone
        move.b 16(a0),d0
        andi.b #$7f,d0
        cmpi.b #9,d0
        beq M4ArSDoorDone
        bra M4ArSDoorOpening

; ---------------------------------------------------------------------
; ship3 08:A035 (ship_0_c, the mother ship): no pointers, HP $FF, AP 16,
; roty $88, enemy1, vy -40, type |= 1, colldisable, rotz $40.
M4ArShip3:
        move.l #M4ArShip3Tick,32(a0)
        jsr M4LvZeroPtrs
        move.b #$ff,38(a0)
        move.b #16,39(a0)
        move.b #$88,13(a0)
        ori.b #CF_ENEMY1,44(a0)
        move.w #-40,8(a0)
        bset #0,45(a0)
        bset #SF_COLLDISABLE,49(a0)
        move.b #$40,14(a0)
; 08:A077: rotz/roty Achase8_6 -> 0/$80; y < 740: vy += 1 while nonzero;
; else notdie and on even gameframes $0E (0,-120,0) at the player with
; rotx/roty offsets (rnd & 7) - 3, shooter vel 50, shot count 100 vel 120.
; ZD < 1600 -> A162 next tick.
M4ArShip3Tick:
        moveq #6,d2
        move.b 14(a0),d0
        moveq #0,d1
        jsr M4EnChase8
        move.b d0,14(a0)
        move.b 13(a0),d0
        move.b #$80,d1
        jsr M4EnChase8
        move.b d0,13(a0)
        move.w 2(a0),d0
        subi.w #740,d0
        bpl M4ArShip3Fire
        tst.w 8(a0)
        beq M4ArShip3Near
        addq.w #1,8(a0)
        bra M4ArShip3Near
M4ArShip3Fire:
        bset #5,M4_BOSS_PSTRATF
        btst #0,M4_LV_GAMEFRAME+1
        bne M4ArShip3Near
        move.b 15(a0),-(sp)
        move.b #50,15(a0)
        jsr M4IntroRandom
        andi.b #7,d0
        subq.b #3,d0
        move.b d0,d6
        jsr M4IntroRandom
        andi.b #7,d0
        subq.b #3,d0
        move.b d0,d7
        moveq #M4_WT_RELFAST,d0
        moveq #0,d3
        moveq #-120,d4
        moveq #0,d5
        movea.l a1,a3
        jsr M4EnFire
        move.l a2,d0
        beq M4ArShip3NoShot
        move.b #100,19(a2)
        move.b #120,15(a2)
M4ArShip3NoShot:
        move.b (sp)+,15(a0)
M4ArShip3Near:
        movea.l a1,a2
        jsr M4EnZD
        subi.w #1600,d0
        bpl M4ArShip3Common
        move.l #M4ArShip3Close,32(a0)
        bra M4ArShip3Common
; 08:A162: ZD < 600 -> colldisable, noctrl off, stratdone1, then A219.
M4ArShip3Close:
        movea.l a1,a2
        jsr M4EnZD
        subi.w #600,d0
        bpl M4ArShip3Common
        bset #SF_COLLDISABLE,49(a0)
        bclr #5,M4_LP_PSF
        bset #3,M4_LP_GAMEFLAGS
        move.l #M4ArShip3Fixed,32(a0)
        bra M4ArShip3Fixed
; 08:A1AA: player dead -> drift (0,-10,30) for ever; ZD >= 3200 -> A219;
; else the player pulled to (0, -60) (Achase16_3 / _4), noctrl, inseq,
; out of the cockpit.
M4ArShip3Common:
        tst.b M4_LP_PSF2
        bmi M4ArShip3DeadInit
        movea.l a1,a2
        jsr M4EnZD
        subi.w #3200,d0
        bpl M4ArShip3Fixed
        move.w 2(a1),d0
        moveq #-60,d1
        moveq #3,d2
        jsr M4LpAchase
        move.w d0,2(a1)
        move.w (a1),d0
        moveq #0,d1
        moveq #4,d2
        jsr M4LpAchase
        move.w d0,(a1)
        bset #5,M4_LP_PSF
        bsr M4ArPullCommon
; 08:A219: vz = -pviewvelz, pos += v, z += pviewvelz (fixed in the world).
M4ArShip3Fixed:
        move.w M4_LP_PVIEWVZ,d0
        neg.w d0
        move.w d0,10(a0)
        jsr M4EnMove
        jsr M4EnAddPZ
        moveq #0,d0
        rts
M4ArShip3DeadInit:
        move.l #M4ArShip3Dead,32(a0)
        clr.w 6(a0)
        move.w #-10,8(a0)
        move.w #30,10(a0)
M4ArShip3Dead:
        jsr M4EnMove
        jsr M4EnAddPZ
        moveq #0,d0
        rts

; ship3a 0A:CC0D (Sship_0_c): the Istrat runs every tick: colldisable, roty
; $80, z -= 10, y += 8, rotx -> $20 (+1); y >= 10000 -> removed (06:8D12);
; z += pviewvelz.
M4ArShip3a:
        bset #SF_COLLDISABLE,49(a0)
        move.b #$80,13(a0)
        subi.w #10,4(a0)
        addq.w #8,2(a0)
        cmpi.b #$20,12(a0)
        beq M4ArShip3aY
        addq.b #1,12(a0)
M4ArShip3aY:
        move.w 2(a0),d0
        subi.w #10000,d0
        bpl M4ArShip3aGone
        jsr M4EnAddPZ
        moveq #0,d0
        rts
M4ArShip3aGone:
        moveq #1,d0
        rts

; ---------------------------------------------------------------------
; cruiser1 0A:B721 (sflag1: does not fire) / cruiser1F 0A:B727 (ship_4):
; HP 30, AP 8, collstrat hitflashMexp 06:8948, expstrat 0A:B843, vel 20,
; roty $C0, enemy1.
M4ArCruiser1:
        bset #F2_SFLAG1,48(a0)
M4ArCruiser1F:
        move.b #30,38(a0)
        move.b #8,39(a0)
        move.l #M4ArCruiser1Tick,32(a0)
        move.l #M4ArHitFlashMexp,X_COLL(a0)
        move.l #M4ArCruiser1Exp,X_EXP(a0)
        move.b #20,15(a0)
        move.b #$c0,13(a0)
        ori.b #CF_ENEMY1,44(a0)
; 0A:B76A: sbyte1 ticks straight, then roty - 1 every 4th gameframe; unless
; sflag1, 1000 <= ZD < 2000 and (gameframe + al1pt) & 31 == 0 -> two $1A
; (sbyte1 $C0 / $40, sbyte2 0, al_ptr the player).
M4ArCruiser1Tick:
        tst.b 36(a0)
        beq M4ArCr1Turn
        subq.b #1,36(a0)
        bra M4ArCr1Fire
M4ArCr1Turn:
        moveq #3,d0
        and.w M4_LV_GAMEFRAME,d0
        bne M4ArCr1Fire
        subq.b #1,13(a0)
M4ArCr1Fire:
        btst #F2_SFLAG1,48(a0)
        bne M4ArCr1Move
        movea.l a1,a2
        jsr M4EnZD
        subi.w #1000,d0
        bmi M4ArCr1Move
        subi.w #1000,d0
        bpl M4ArCr1Move
        bsr M4ArPhase
        andi.b #31,d0
        bne M4ArCr1Move
        move.b #$c0,d1
        bsr M4ArCr1Missile
        move.b #$40,d1
        bsr M4ArCr1Missile
M4ArCr1Move: ;0A:B828
        jsr M4EnGen3d
        jsr M4EnMove
        jsr M4EnAddPZ
        moveq #0,d0
        rts
M4ArCr1Missile:
        moveq #M4_WT_STB,d0
        moveq #0,d3
        moveq #0,d4
        moveq #0,d5
        moveq #0,d6
        moveq #0,d7
        suba.l a3,a3
        move.b d1,-(sp)
        jsr M4EnFire
        move.b (sp)+,d1
        move.l a2,d0
        beq M4ArCr1MissileNo
        move.b d1,36(a2)
        clr.b 37(a2)
        move.w a1,X_ALPTR(a2)
M4ArCr1MissileNo:
        rts
; expstrat 0A:B843 (cruiser1fall): expstrat B866; large explosion (sflags2
; $08 off), sound $21. B866: rotx -> $20, smoke every 4th (gameframe +
; al1pt), move.
M4ArCruiser1Exp:
        move.l #M4ArCruiser1Fall,X_EXP(a0)
        jsr M4FxLarge
        beq M4ArCruiser1Fall
        bclr #F2_NOEXPSND,48(a2)
M4ArCruiser1Fall:
        cmpi.b #$20,12(a0)
        beq M4ArCr1FallSmoke
        addq.b #1,12(a0)
M4ArCr1FallSmoke:
        bsr M4ArPhase
        andi.b #3,d0
        bne M4ArCr1Move
        jsr M4FxSmoke
        bra M4ArCr1Move
; hitflashMexp 06:8948: medium explosion at the collider (linked behind
; it), sound $24, hitflash 06:89A3.
M4ArHitFlashMexp:
        move.w 62(a0),d0
        beq M4ArHfmDone
        movea.w d0,a3
        move.l a0,-(sp)
        move.l M4_LV_CREATOR,-(sp)
        move.l a3,M4_LV_CREATOR
        movea.l a3,a0
        jsr M4FxMedium
        move.l (sp)+,M4_LV_CREATOR
        movea.l (sp)+,a0
M4ArHfmDone:
        jmp M4LcHitFlash

; cruiser2 0A:B01C (ship_5S / ship_5M): HP $FF, AP 8, rotz $E8, roty $98,
; enemy1, colldisable; B0C6: v = gen3d, pos += v, z += pviewvelz.
M4ArCruiser2:
        move.l #M4ArCruiser2Move,32(a0)
M4ArCruiser2Common:
        move.b #$ff,38(a0)
        move.b #8,39(a0)
        move.b #$e8,14(a0)
        move.b #$98,13(a0)
        ori.b #CF_ENEMY1,44(a0)
        bset #SF_COLLDISABLE,49(a0)
        jmp M4LcStrategy ;1F:DC25
M4ArCruiser2Move:
        jsr M4EnGen3d
        jsr M4EnMove
        jsr M4EnAddPZ
        moveq #0,d0
        rts
; cruiser2fire 0A:AF28 (ship_5): three launchers hou_3 D9E8 (children 1..3,
; Istrat 0A:B0E1, enemy1, z offsets and timers in M4ArLauncherParams).
M4ArCruiser2Fire:
        moveq #1,d1
        lea M4ArLauncherParams,a4
M4ArC2fLauncher:
        move.w #$d9e8,d0
        move.l #M4ArLauncherI,d2
        bsr M4ArMakeChild
        beq M4ArC2fFail
        ori.b #CF_ENEMY1,44(a2)
        move.b #20,X_AR_1CE1(a2)
        move.b #-10,X_RADIUS(a2) ;alx $1CE2
        move.b (a4)+,X_RELPOSZ(a2) ;alx $1CE3
        move.b (a4)+,37(a2)
        addq.b #1,d1
        cmpi.b #4,d1
        bne M4ArC2fLauncher
        bra M4ArC2fOk
M4ArC2fFail:
        move.w #$7d02,M4_LV_BADOP
        move.w #-1,M4_LV_STATUS
M4ArC2fOk:
        move.l #M4ArCruiser2FireTick,32(a0)
        bra M4ArCruiser2Common
M4ArLauncherParams: ;$1CE3, sbyte2
        include '../build/m4-armada-launchers.inc'
        even
; 0A:B04F: no child left -> speedto(50, 1), medium explosion moved by
; 2 * rnd (06:EFA0), smoke on even (gameframe + al1pt), rotx -> $20; move.
M4ArCruiser2FireTick:
        tst.w 40(a0)
        bne M4ArCruiser2Move
        moveq #50,d0
        moveq #1,d1
        jsr M4EnSpeedTo
        jsr M4FxMedium
        beq M4ArC2fSmoke
        ;06:EFA0: x, y, z += 2 * sext(rnd)
        jsr M4IntroRandom
        ext.w d0
        add.w d0,d0
        add.w d0,(a2)
        jsr M4IntroRandom
        ext.w d0
        add.w d0,d0
        add.w d0,2(a2)
        jsr M4IntroRandom
        ext.w d0
        add.w d0,d0
        add.w d0,4(a2)
M4ArC2fSmoke:
        bsr M4ArPhase
        btst #0,d0
        bne M4ArC2fPitch
        jsr M4FxSmoke
M4ArC2fPitch:
        cmpi.b #$20,12(a0)
        beq M4ArCruiser2Move
        addq.b #1,12(a0)
        bra M4ArCruiser2Move
; launcher 0A:B0E1: normal pointers (expstrat with divorcefamily first),
; HP 4, AP 8. B0FA: at the mother + 16 * Ry(Rx(Rz(offset))) with its
; rotations; rotx -= 8, roty -= 64; every 60 ticks: afLeftPl and |dx| >=
; 1000 -> $14 from x = 0, z - 1000 toward +z (roty $80) with offsets (rnd &
; 7) - 3; |dx| < 700 -> $14 from (0,0,5) along its own angles; al_ptr =
; player, enemy1.
M4ArLauncherI:
        move.l #M4ArLauncherTick,32(a0)
        move.l #M4LcHitFlash,X_COLL(a0)
        move.l #M4ArChildExplode,X_EXP(a0)
        move.b #4,38(a0)
        move.b #8,39(a0)
M4ArLauncherTick:
        move.w X_ALPTR(a0),d0
        beq M4ArLnSpin
        movea.w d0,a2
        move.b X_AR_1CE1(a0),d3
        move.b X_RADIUS(a0),d4
        move.b X_RELPOSZ(a0),d5
        jsr M4WeaponOffset ;rotz, rotx, roty of a2; displacement * 4
        asl.w #2,d3
        asl.w #2,d4
        asl.w #2,d5
        add.w (a2),d3
        move.w d3,(a0)
        add.w 2(a2),d4
        move.w d4,2(a0)
        add.w 4(a2),d5
        move.w d5,4(a0)
        move.b 12(a2),12(a0)
        move.b 13(a2),13(a0)
        move.b 14(a2),14(a0)
M4ArLnSpin:
        subq.b #8,12(a0)
        subi.b #$40,13(a0)
        subq.b #1,37(a0)
        bne M4ArLnDone
        move.b #60,37(a0)
        btst #AF_LEFTPL,51(a0)
        beq M4ArLnNear
        move.w (a1),d0
        sub.w (a0),d0
        bpl M4ArLnDx
        neg.w d0
M4ArLnDx:
        subi.w #1000,d0
        bmi M4ArLnNear
        move.l (a0),-(sp) ;x, y
        move.w 4(a0),-(sp)
        move.w 12(a0),-(sp) ;rotx, roty
        move.b #$80,13(a0)
        clr.b 12(a0)
        clr.w (a0)
        subi.w #1000,4(a0)
        jsr M4IntroRandom
        andi.b #7,d0
        subq.b #3,d0
        move.b d0,d6
        jsr M4IntroRandom
        andi.b #7,d0
        subq.b #3,d0
        move.b d0,d7
        moveq #M4_WT_FAKEFAR,d0
        moveq #0,d3
        moveq #0,d4
        moveq #0,d5
        suba.l a3,a3
        jsr M4EnFire
        bsr M4ArLnShot
        move.w (sp)+,12(a0)
        move.w (sp)+,4(a0)
        move.l (sp)+,(a0)
        bra M4ArLnDone
M4ArLnNear:
        move.w (a1),d0
        sub.w (a0),d0
        bpl M4ArLnDx2
        neg.w d0
M4ArLnDx2:
        subi.w #700,d0
        bpl M4ArLnDone
        moveq #M4_WT_FAKEFAR,d0
        moveq #0,d3
        moveq #0,d4
        moveq #5,d5
        moveq #0,d6
        moveq #0,d7
        suba.l a3,a3
        jsr M4EnFire
        bsr M4ArLnShot
M4ArLnDone:
        moveq #0,d0
        rts
M4ArLnShot:
        move.l a2,d0
        beq M4ArLnShotNo
        move.w a1,X_ALPTR(a2)
        ori.b #CF_ENEMY1,44(a2)
M4ArLnShotNo:
        rts
; explode_Istrat 06:F45F of a child: divorcefamily 1F:DBA4 first (the
; mother counts its children at once), then the port explosion.
M4ArChildExplode:
        btst #4,X2_FL4(a0)
        beq M4ArChildExplodeNow
        movea.l a0,a2
        jsr M4PvDivorce
M4ArChildExplodeNow:
        jmp M4LevelExplode

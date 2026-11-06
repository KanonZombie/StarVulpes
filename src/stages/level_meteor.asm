; Stage unit: Meteor (0D:D586, route 1 stage 4). Strategies, player mode and
; palette fade of this stage; its strategy table is searched by
; M4LevelFindStrategy (M4LevelStrategyTables, level_objects.asm).
; Shapes/textures/player mode: tools/stages/meteor.py (boss: meteor_boss.py).
; Specification: build/research/stage-meteor.md sections 1.4, 1.6 and 3; every
; routine was re-read in the ROM bytes (tools/dis65816.py,
; build/agent-meteor/dis/) and is compared with the ROM by
; build/agent-meteor/meteor-compare.py (build/agent-meteor/METEOR.md).
; Conventions of level_objects.asm / level_enemies.asm: a0 object, a1
; player; d0 = 0 keep / nonzero deferred removal. "d < K" comparisons are the
; N bit of the 16-bit difference. Sounds (snd2, 03:B7E5, 03:B705/B71D) are
; not ported. Shapes are referenced by their ROM header (M4LevelShapeIndex).
; RAM: $FF9E00..$FF9E7F (this file), $FF9E80..$FF9EFF (level_meteor_boss.asm).
M4_MT equ $ff9e00
M4_MT_FADEINIT equ M4_MT+0 ;.b SNES shadow below loaded from bg_1_4
M4_MT_SHADOW equ M4_MT+2 ;32 .w CGRAM shadow 7E:178B rows 1 (0..15) and 5 (16..31)
M4_MT_END equ M4_MT+66
X_MTIDX equ -$8000+38 ;.w descriptor index of the real shape (sword1, fog)
X_MTREL equ -$8000+40 ;.b x3 alx $1CE1..$1CE3 relpos (tank2 fighters)

M4StrategiesMeteor:
        dc.l $0a87c4,M4StratHard180YRfog
        dc.l $0a8f35,M4StratHoudai5f ;also path setstrat 1AA9 (Titania)
        dc.l $098bc6,M4StratWalking
        dc.l $0a8972,M4StratTank1a
        dc.l $0a881b,M4StratBase0
        dc.l $0a88ac,M4StratBase1
        dc.l $0ac697,M4StratTank2
        dc.l $08d85a,M4StratUp1man
        include 'stages/level_meteor_boss_strats.asm'
        dc.l 0

; ---------------------------------------------------------------------
; Helpers.

; d0.w = ROM shape header -> new object a2 behind a0 (1F:D54B), X_SHAPEHDR
; set. Z set on failure (a2 = 0).
M4MtCreateHdr:
        move.w d0,-(sp)
        jsr M4LevelShapeIndex
        jsr M4EnCreate
        move.w (sp)+,d0
        cmpa.w #0,a2
        beq M4MtCreateHdrDone
        move.w d0,X_SHAPEHDR(a2)
        cmpa.w #0,a2
M4MtCreateHdrDone:
        rts

; d0.w = ROM header: shape of a0 (sta $04,x).
M4MtSetHdr:
        move.w d0,X_SHAPEHDR(a0)
        jsr M4LevelShapeIndex
        jmp M4LevelSetShape

; 1F:D54B + makechild 1F:D56F: d0.w header, d1.b child number, d2.l Istrat
; -> a2 (Z on failure). sbyte1 = n, al_ptr = mother, sword1 = 0, linked at
; the end of the mother's sword1 chain; mother and child flags. A failed
; creation is the ROM's debug restart 1F:BDEE: fatal in the port.
M4MtMakeChild:
        movem.l d0-d1/a3,-(sp)
        bsr M4MtCreateHdr
        beq M4MtMakeChildFail
        move.l d2,32(a2)
        move.b d1,36(a2)
        move.w a0,X_ALPTR(a2)
        clr.w 40(a2)
        movea.l a0,a3
M4MtMakeChildTail:
        move.w 40(a3),d0
        beq M4MtMakeChildLink
        movea.w d0,a3
        bra M4MtMakeChildTail
M4MtMakeChildLink:
        move.w a2,40(a3)
        bset #6,X2_FL4(a0)
        bset #4,X2_FL4(a2)
        movem.l (sp)+,d0-d1/a3
        cmpa.w #0,a2
        rts
M4MtMakeChildFail:
        move.w #-1,M4_LV_STATUS
        move.w #$7d00,M4_LV_BADOP
        movem.l (sp)+,d0-d1/a3
        cmpa.w #0,a2
        rts

; Offset d3/d4/d5 (BYTEs x/y/z) rotated by the angles of a4 through
; 1F:CC78 (rotz), 1F:CAFB (rotx), 1F:C97B (roty) and doubled (asl): the
; gen_weapon chain of M4WeaponOffset (x4) halved. -> d3/d4/d5 WORDs.
M4MtRotX2:
        move.l a2,-(sp)
        movea.l a4,a2
        jsr M4WeaponOffset
        movea.l (sp)+,a2
        asr.w #1,d3
        asr.w #1,d4
        asr.w #1,d5
        rts

; animframe d0.b: +1 (dec: -1) modulo d1, bit 7 kept (adc / bmi / and $7F /
; cmp / sbc / ora $80 of 0A:8FA7, 0A:8892, 0A:8958, 0A:CAD3).
M4MtAfInc:
        addq.b #1,d0
        bmi M4MtAfMod
        add.b d1,d0
        bra M4MtAfMod
M4MtAfDec:
        subq.b #1,d0
        bmi M4MtAfMod
        add.b d1,d0
M4MtAfMod:
        andi.b #$7f,d0
        cmp.b d1,d0
        blo M4MtAfDone
        sub.b d1,d0
M4MtAfDone:
        ori.b #$80,d0
        rts

; speedto 1F:D60D with step 1 and its carry: d0 = target -> d3 = 1 when vel
; was already the target (C = 1, nothing changed), else 0.
M4MtSpeedToC:
        moveq #0,d3
        cmp.b 15(a0),d0
        bne M4MtSpeedToCGo
        moveq #1,d3
        rts
M4MtSpeedToCGo:
        moveq #1,d1
        jmp M4EnSpeedTo

; dofog 0A:87E6 / 0A:8F73: with infog ($1784), shape = sword1 while
; ZD(x, player) < 2000, else nullshape (the player object $123A).
M4MtFog:
        tst.b M4_MV_1784
        beq M4MtFogDone
        move.w 4(a1),d0
        sub.w 4(a0),d0
        bpl M4MtFogAbs
        neg.w d0
M4MtFogAbs:
        subi.w #2000,d0
        bmi M4MtFogNear
        cmpi.w #$ffff,46(a0)
        beq M4MtFogDone
        move.w #$aca1,X_SHAPEHDR(a0)
        move.w #$ffff,d0
        jmp M4LevelSetShape
M4MtFogNear:
        move.w X_MTIDX(a0),d0
        cmp.w 46(a0),d0
        beq M4MtFogDone
        move.w 40(a0),X_SHAPEHDR(a0)
        jmp M4LevelSetShape
M4MtFogDone:
        rts

; explode_Istrat 06:F45F for the family objects of this stage: divorcefamily
; 1F:DBA4 first (child and/or mother), then the flame (afonfire) and the
; shared explosion (M4WpExplode -> M4LevelExplode).
M4MtExplode:
        btst #4,X2_FL4(a0)
        bne M4MtExplodeFamily
        btst #6,X2_FL4(a0)
        beq M4MtExplodeNow
M4MtExplodeFamily:
        bsr M4MtDivorce
M4MtExplodeNow:
        jmp M4WpExplode
; divorcefamily 1F:DBA4. Child: leaves the mother's chain (M4PvDivorce), Y =
; mother. Mother: Y.motherobj cleared (Y = x when x is not a child, 02:DB10),
; then for k = number of children .. 1: findchild(k): childobj and al_ptr 0.
M4MtDivorce:
        movem.l d0-d2/a2-a3,-(sp)
        movea.l a0,a3
        btst #4,X2_FL4(a0)
        beq M4MtDivorceMother
        movea.l a0,a2
        jsr M4PvDivorce
        move.w X_ALPTR(a0),d0
        beq M4MtDivorceMother
        movea.w d0,a3
M4MtDivorceMother:
        btst #6,X2_FL4(a0)
        beq M4MtDivorceDone
        bclr #6,X2_FL4(a3)
        moveq #0,d2
        movea.l a0,a2
M4MtDivorceCount:
        move.w 40(a2),d0
        beq M4MtDivorceKids
        addq.b #1,d2
        movea.w d0,a2
        bra M4MtDivorceCount
M4MtDivorceKids:
        tst.b d2
        beq M4MtDivorceDone
        movea.l a0,a2
        move.b d2,d0
        jsr M4PvFindChild
        move.l a2,d0
        beq M4MtDivorceNextKid
        bclr #4,X2_FL4(a2)
        clr.w X_ALPTR(a2)
M4MtDivorceNextKid:
        subq.b #1,d2
        bne M4MtDivorceKids
M4MtDivorceDone:
        movem.l (sp)+,d0-d2/a2-a3
        rts

; ---------------------------------------------------------------------
; hard180YRfog 0A:87C4: sword1 = shape, roty $80, HP $FF, AP 8 (no enemy1
; colltype, unlike hard180YR); the Istrat ends with rtl. Tick 0A:87E6: fog.
M4StratHard180YRfog:
        move.w X_SHAPEHDR(a0),40(a0)
        move.w 46(a0),X_MTIDX(a0)
        move.b #$80,13(a0)
        move.b #$ff,38(a0)
        move.b #8,39(a0)
        move.l #M4MtFogTick,32(a0)
        moveq #0,d0
        rts
M4MtFogTick:
        bsr M4MtFog
        moveq #0,d0
        rts

; houdai5f 0A:8F35 (turret hou_5): sword1 = shape, hitflash / smarkexplode,
; HP 4, AP 6, animframe $80, then the tick 0A:8F73: fog, animframe +1 mod 12;
; every 32 gameframes with ZD >= 400: Hplasma $26 from (0,-59,0), roty add
; $80, then al_ptr = player, count 100, vel 100.
M4StratHoudai5f:
        move.w X_SHAPEHDR(a0),40(a0)
        move.w 46(a0),X_MTIDX(a0)
        move.l #M4MtHoudaiTick,32(a0)
        move.l #M4LcHitFlash,X_COLL(a0)
        move.l #M4MtSmarkExplode,X_EXP(a0)
        move.b #4,38(a0)
        move.b #6,39(a0)
        move.b #$80,16(a0)
M4MtHoudaiTick:
        bsr M4MtFog
        move.b 16(a0),d0
        moveq #12,d1
        bsr M4MtAfInc
        move.b d0,16(a0)
        move.w M4_LV_GAMEFRAME,d0
        andi.w #$1f,d0
        bne M4MtHoudaiDone
        movea.l a1,a2
        jsr M4EnZD
        subi.w #400,d0
        bmi M4MtHoudaiDone
        moveq #M4_WT_HPLASMA,d0
        moveq #0,d3
        moveq #-59,d4
        moveq #0,d5
        moveq #0,d6
        moveq #-128,d7
        suba.l a3,a3
        jsr M4EnFire
        move.l a2,d0
        beq M4MtHoudaiDone
        move.w a1,X_ALPTR(a2)
        move.b #100,19(a2)
        move.b #100,15(a2)
M4MtHoudaiDone:
        moveq #0,d0
        rts

; smarkexplode 06:F046: Smark B3A1 at the object with y = 0 (sflags3 realobj
; cleared: no port equivalent), then explode_Istrat. Smark has no strategy
; and HP 0 (no collision; removed by zremove).
M4MtSmarkExplode:
        move.w #$b3a1,d0
        bsr M4MtCreateHdr
        beq M4MtSmarkDone
        move.l (a0),(a2)
        move.w 4(a0),4(a2)
        clr.w 2(a2)
M4MtSmarkDone:
        jmp M4LevelExplode

; ---------------------------------------------------------------------
; walking 09:8BC6 (walker_0): normcoll, HP $C8 (bit 7: indestructible), AP
; 16, roty 4, vel 75, (vx, vz) = gen2d, type 0 (no zremove), sbyte1 200,
; sbyte2/3 = 4 hits per leg, shadow.
M4StratWalking:
        move.l #M4MtWalking,32(a0)
        jsr M4LvNormPtrs
        move.b #$c8,38(a0)
        move.b #16,39(a0)
        move.b #4,13(a0)
        move.b #75,15(a0)
        jsr M4EnGen2d
        clr.b 45(a0)
        move.b #200,36(a0)
        move.b #4,37(a0)
        move.b #4,X_SBYTE3(a0)
        bset #F2_SHADOW,48(a0)
; 8C19: pos += v; sbyte1 counts down, then w2i (type zremove) and walking2
; in the same tick (two moves on that tick).
M4MtWalking:
        jsr M4EnMove
        tst.b 36(a0)
        bne M4MtWalkCount
        move.l #M4MtWalking2,32(a0)
        move.b #8,45(a0)
        bra M4MtWalking2
M4MtWalkCount:
        subq.b #1,36(a0)
        bra M4MtWalkHit
; 8C3B: gen2d, move, roty -4 until $80, vel -4 while >= 10 (unsigned).
M4MtWalking2:
        jsr M4EnGen2d
        jsr M4EnMove
        cmpi.b #$80,13(a0)
        beq M4MtWalkVel
        subq.b #4,13(a0)
M4MtWalkVel:
        cmpi.b #10,15(a0)
        blo M4MtWalkHit
        subq.b #4,15(a0)
; 8C76: hitflags HF1 right leg, HF2 left leg, HF3 head (no effect).
M4MtWalkHit:
        btst #0,20(a0)
        beq M4MtWalkHitL
        bclr #0,20(a0)
        tst.b 37(a0)
        beq M4MtWalkRight
        subq.b #1,37(a0)
M4MtWalkHitL:
        btst #1,20(a0)
        beq M4MtWalkHitH
        bclr #1,20(a0)
        tst.b X_SBYTE3(a0)
        beq M4MtWalkLeft
        subq.b #1,X_SBYTE3(a0)
M4MtWalkHitH:
        bclr #2,20(a0)
        moveq #0,d0
        rts
; 8CC1: right leg gone: sbyte1 $FE, sbyte3 1, walker_r, x += 2R(25,0,0);
; leg explosion B101 at x + 2R(-50,-40,0) (explode_Istrat, colldisable, HP 0).
M4MtWalkRight:
        move.b #$fe,36(a0)
        move.b #1,X_SBYTE3(a0)
        move.w #$b411,d0
        bsr M4MtSetHdr
        moveq #25,d3
        moveq #-50,d6
        move.w #$b101,d2
        bra M4MtWalkLeg
; 8E43: left leg gone: sbyte1 2, sbyte3 $FF, walker_l, x += 2R(-25,0,0);
; nullshape explosion at x + 2R(50,-40,0).
M4MtWalkLeft:
        move.b #2,36(a0)
        move.b #$ff,X_SBYTE3(a0)
        move.w #$b3f5,d0
        bsr M4MtSetHdr
        moveq #-25,d3
        moveq #50,d6
        move.w #$aca1,d2
M4MtWalkLeg:
        moveq #0,d4
        moveq #0,d5
        movea.l a0,a4
        bsr M4MtRotX2
        add.w d3,(a0)
        add.w d5,4(a0)
        add.w d4,2(a0)
        move.w d2,d0
        move.b d6,d3
        moveq #-40,d4
        bsr M4MtWalkBoom
; 8FC1: fall: sbyte2 5, then wobble in the same tick.
        move.l #M4MtWobble,32(a0)
        move.b #5,37(a0)
; 8FD2: rotz -= sbyte3, sbyte3 = -sbyte3; sbyte2 counts, roty -= sbyte1.
M4MtWobble:
        move.b X_SBYTE3(a0),d0
        sub.b d0,14(a0)
        neg.b X_SBYTE3(a0)
        tst.b 37(a0)
        beq M4MtFellIt
        subq.b #1,37(a0)
        move.b 36(a0),d0
        sub.b d0,13(a0)
        moveq #0,d0
        rts
; 8FF4: fallover with sbyte2 7 (same tick).
M4MtFellIt:
        move.l #M4MtFallOver,32(a0)
        move.b #7,37(a0)
; 9005: rotz -= sbyte1; sbyte1 -= sbyte3; sbyte2 counts, then killit.
M4MtFallOver:
        move.b 36(a0),d0
        sub.b d0,14(a0)
        move.b X_SBYTE3(a0),d0
        sub.b d0,36(a0)
        tst.b 37(a0)
        beq M4MtKillIt
        subq.b #1,37(a0)
        moveq #0,d0
        rts
; 9020: explosion B101 at x + 2R(0,-80,0); x colldisable, HP 0 (its
; expstrat, explode_Istrat, runs on the next tick).
M4MtKillIt:
        move.w #$b101,d0
        moveq #0,d3
        moveq #-80,d4
        bsr M4MtWalkBoom
        bset #SF_COLLDISABLE,49(a0)
        clr.b 38(a0)
        moveq #0,d0
        rts
; d0 = header, d3/d4 = offset BYTEs (z 0): object at x + 2R(d3, d4, 0) whose
; strategy, collstrat and expstrat are explode_Istrat 06:F45F, colldisable,
; HP 0. Registers kept except d0-d5/a2/a4.
M4MtWalkBoom:
        bsr M4MtCreateHdr
        beq M4MtWalkBoomDone
        moveq #0,d5
        movea.l a0,a4
        bsr M4MtRotX2
        add.w (a0),d3
        add.w 4(a0),d5
        add.w 2(a0),d4
        move.w d3,(a2)
        move.w d5,4(a2)
        move.w d4,2(a2)
        move.l #M4LevelExplode,32(a2)
        move.l #M4LevelExplode,X_COLL(a2)
        move.l #M4LevelExplode,X_EXP(a2)
        bset #SF_COLLDISABLE,49(a2)
        clr.b 38(a2)
M4MtWalkBoomDone:
        rts

; ---------------------------------------------------------------------
; tank1a 0A:8972 (base tanks, sbyte1 set by the script): the Istrat repeats
; while ZD >= 5000; then normcoll, sbyte2 50, sbyte3 15 and 89CE.
M4StratTank1a:
        move.w X_SHAPEHDR(a0),40(a0)
        move.b #2,38(a0)
        move.b #16,39(a0)
        ori.b #CF_ENEMY1,44(a0)
        move.b #$c0,13(a0)
        movea.l a1,a2
        jsr M4EnZD
        subi.w #5000,d0
        bpl M4MtTankDone
        move.l #M4MtTank1aOut,32(a0)
        jsr M4LvNormPtrs
        move.b #50,37(a0)
        move.b #15,X_SBYTE3(a0)
; 89CE: speedto(30, 2), gen3d, move; sbyte1 counts down (out of the hangar),
; then roty = Achase8_2(roty, 0) and 8A1A once it was already 0.
M4MtTank1aOut:
        moveq #30,d0
        moveq #2,d1
        jsr M4EnSpeedTo
        jsr M4EnGen3d
        jsr M4EnMove
        tst.b 36(a0)
        beq M4MtTank1aTurn
        subq.b #1,36(a0)
        bra M4MtTankDone
M4MtTank1aTurn:
        move.b 13(a0),d0
        moveq #0,d1
        moveq #2,d2
        jsr M4EnChase8
        move.b d0,13(a0)
        tst.b d3
        beq M4MtTankDone
        move.l #M4MtTank1aGo,32(a0)
; 8A1A: ZD >= 3000 -> back (8A77); else lr, fire, speedto(85, 2), gen3d,
; move, z += 17.
M4MtTank1aGo:
        movea.l a1,a2
        jsr M4EnZD
        subi.w #3000,d0
        bpl M4MtTank1aBackSet
        bsr M4MtTankLR
        bsr M4MtTankFire
        moveq #85,d0
        moveq #2,d1
        jsr M4EnSpeedTo
        jsr M4EnGen3d
        jsr M4EnMove
        addi.w #17,4(a0)
        bra M4MtTankDone
M4MtTank1aBackSet:
        move.l #M4MtTank1aBack,32(a0)
M4MtTank1aBack:
        subq.w #7,4(a0)
M4MtTankDone:
        moveq #0,d0
        rts
; lr 0A:8C38: slalom of roty by Achase8_3 towards +-20, sbyte3 counting
; 15 ticks each way.
M4MtTankLR:
        move.b X_SBYTE3(a0),d0
        bpl M4MtTankLRPos
        addq.b #1,d0
        beq M4MtTankLRNegEnd
        move.b d0,X_SBYTE3(a0)
        moveq #-20,d1
        bra M4MtTankLRChase
M4MtTankLRNegEnd:
        move.b #15,X_SBYTE3(a0)
        rts
M4MtTankLRPos:
        subq.b #1,d0
        beq M4MtTankLRPosEnd
        move.b d0,X_SBYTE3(a0)
        moveq #20,d1
M4MtTankLRChase:
        move.b 13(a0),d0
        moveq #3,d2
        jsr M4EnChase8
        move.b d0,13(a0)
        rts
M4MtTankLRPosEnd:
        move.b #$f1,X_SBYTE3(a0)
        rts
; fire 0A:8C6A: sbyte2--, shots at 20, 10 and 0 (then 50 again); only with
; ZD >= 500 and |dx| < 300: Hplasma $26 from (0,-15,0), roty add $80,
; al_ptr = player.
M4MtTankFire:
        subq.b #1,37(a0)
        move.b 37(a0),d0
        cmpi.b #20,d0
        beq M4MtTankShoot
        cmpi.b #10,d0
        beq M4MtTankShoot
        tst.b d0
        bne M4MtTankFireDone
        move.b #50,37(a0)
M4MtTankShoot:
        movea.l a1,a2
        jsr M4EnZD
        subi.w #500,d0
        bmi M4MtTankFireDone
        move.w (a1),d0
        sub.w (a0),d0
        bpl M4MtTankDx
        neg.w d0
M4MtTankDx:
        subi.w #300,d0
        bpl M4MtTankFireDone
        moveq #M4_WT_HPLASMA,d0
        moveq #0,d3
        moveq #-15,d4
        moveq #0,d5
        moveq #0,d6
        moveq #-128,d7
        suba.l a3,a3
        jsr M4EnFire
        move.l a2,d0
        beq M4MtTankFireDone
        move.w a1,X_ALPTR(a2)
M4MtTankFireDone:
        rts

; ---------------------------------------------------------------------
; base0 0A:881B: enemy1, strategy = collstrat = expstrat = 885B (a hit runs
; it instead of hitflash: no damage), HP $FF, AP 2, roty $C0, animframe $80.
M4StratBase0:
        ori.b #CF_ENEMY1,44(a0)
        move.l #M4MtBase0Wait,32(a0)
        move.l #M4MtBase0Wait,X_COLL(a0)
        move.l #M4MtBase0Wait,X_EXP(a0)
        move.b #$ff,38(a0)
        move.b #2,39(a0)
        move.b #$c0,13(a0)
        move.b #$80,16(a0)
; 885B: ZD < 2500 -> 8885: door frames +1 mod 15 until frame 8.
M4MtBase0Wait:
        movea.l a1,a2
        jsr M4EnZD
        subi.w #2500,d0
        bpl M4MtBaseDone
        move.l #M4MtBase0Open,32(a0)
M4MtBase0Open:
        move.b 16(a0),d0
        andi.b #$7f,d0
        cmpi.b #8,d0
        beq M4MtBaseDone
        move.b 16(a0),d0
        moveq #15,d1
        bsr M4MtAfInc
        move.b d0,16(a0)
M4MtBaseDone:
        moveq #0,d0
        rts

; base1 0A:88AC: no coll/exp strategies, HP $FF, AP 2, roty $80,
; animframe $80 (the Istrat ends with rtl).
M4StratBase1:
        move.l #M4MtBase1Wait,32(a0)
        jsr M4LvZeroPtrs
        move.b #$ff,38(a0)
        move.b #2,39(a0)
        move.b #$80,13(a0)
        move.b #$80,16(a0)
        moveq #0,d0
        rts
; 88D1: any HF1 hit (walls too) opens: 88F5 frames +1 mod 15 up to 8, then
; 892D waits sbyte1 = 5 (+1), 894B closes (-1 mod 15) and re-Istrat at 0.
M4MtBase1Wait:
        btst #0,20(a0)
        beq M4MtBaseDone
        bclr #0,20(a0)
        move.l #M4MtBase1Open,32(a0)
M4MtBase1Open:
        move.b 16(a0),d0
        andi.b #$7f,d0
        cmpi.b #8,d0
        beq M4MtBase1HoldSet
        move.b 16(a0),d0
        moveq #15,d1
        bsr M4MtAfInc
        move.b d0,16(a0)
        bra M4MtBaseDone
M4MtBase1HoldSet:
        move.l #M4MtBase1Hold,32(a0)
        move.b #5,36(a0)
M4MtBase1Hold:
        tst.b 36(a0)
        beq M4MtBase1CloseSet
        subq.b #1,36(a0)
        bra M4MtBaseDone
M4MtBase1CloseSet:
        move.l #M4MtBase1Close,32(a0)
M4MtBase1Close:
        move.b 16(a0),d0
        andi.b #$7f,d0
        beq M4StratBase1
        move.b 16(a0),d0
        moveq #15,d1
        bsr M4MtAfDec
        move.b d0,16(a0)
        bra M4MtBaseDone

; ---------------------------------------------------------------------
; tank2 0A:C697: normcoll, colltypes $10|$40, HP 40, AP 32, roty $80, vel 30;
; four fighters DA90 (makechild 1..4, Istrat 0A:C997, enemy1) with relpos
; ($1CE1..3) and sword2. Its explosion releases them (divorcefamily).
M4StratTank2:
        move.l #M4MtTank2Tick,32(a0)
        jsr M4LvNormPtrs
        move.l #M4MtExplode,X_EXP(a0)
        ori.b #CF_ENEMY1|$40,44(a0)
        move.b #40,38(a0)
        move.b #32,39(a0)
        move.b #$80,13(a0)
        move.b #30,15(a0)
        lea M4MtTank2Kids,a3
        moveq #1,d1
M4MtTank2Kid:
        move.w #$da90,d0
        move.l #M4MtFighterI,d2
        bsr M4MtMakeChild
        beq M4MtTank2KidNext
        ori.b #CF_ENEMY1,44(a2)
        move.b (a3),X_MTREL(a2)
        move.b 1(a3),X_MTREL+1(a2)
        move.b 2(a3),X_MTREL+2(a2)
        move.b 3(a3),X_SWORD2(a2)
        move.b 4(a3),X_SWORD2+1(a2)
M4MtTank2KidNext:
        addq.l #5,a3
        addq.b #1,d1
        cmpi.b #5,d1
        bne M4MtTank2Kid
; C80E: stratstate machine; nextstate (1F:DB66) re-runs it from C80E in the
; same tick. E0: sbyte2 = 100, ZD < 1000 -> next. E1/E2: speedto -20 / +20
; step 1 (already there -> next); reversing turns roty. E3: roty -> $A0,
; speedto 30. Then sbyte2 countdown wakes fighter 1..4 at 90/70/50/30;
; (vx, vz) = gen2d, move, z += pviewvelz.
M4MtTank2Tick:
        tst.b X_STATE(a0)
        bne M4MtT2E1
        move.b #100,37(a0)
        movea.l a1,a2
        jsr M4EnZD
        subi.w #1000,d0
        bmi M4MtT2Next
M4MtT2E1:
        cmpi.b #1,X_STATE(a0)
        bne M4MtT2E2
        moveq #-20,d0
        bsr M4MtSpeedToC
        tst.b d3
        bne M4MtT2Next
        bsr M4MtT2Steer
M4MtT2E2:
        cmpi.b #2,X_STATE(a0)
        bne M4MtT2E3
        moveq #20,d0
        bsr M4MtSpeedToC
        tst.b d3
        bne M4MtT2Next
        bsr M4MtT2Steer
M4MtT2E3:
        cmpi.b #3,X_STATE(a0)
        bne M4MtT2Count
        cmpi.b #$a0,13(a0)
        beq M4MtT2Count
        addq.b #1,13(a0)
        moveq #30,d0
        moveq #1,d1
        jsr M4EnSpeedTo
M4MtT2Count:
        tst.b 37(a0)
        beq M4MtT2Move
        subq.b #1,37(a0)
        move.b 37(a0),d0
        moveq #1,d1
        cmpi.b #90,d0
        beq M4MtT2Wake
        moveq #2,d1
        cmpi.b #70,d0
        beq M4MtT2Wake
        moveq #3,d1
        cmpi.b #50,d0
        beq M4MtT2Wake
        moveq #4,d1
        cmpi.b #30,d0
        bne M4MtT2Move
M4MtT2Wake:
        movea.l a0,a2
        move.b d1,d0
        jsr M4PvFindChild
        move.l a2,d0
        beq M4MtT2Move
        move.b #1,X_STATE(a2)
M4MtT2Move:
        jsr M4EnGen2d
        jsr M4EnMove
        jsr M4EnAddPZ
        moveq #0,d0
        rts
M4MtT2Next:
        addq.b #1,X_STATE(a0)
        bra M4MtTank2Tick
; vel < 0: roty -1, and +2 when (gameframe & 31) >= 15.
M4MtT2Steer:
        tst.b 15(a0)
        bpl M4MtT2SteerDone
        subq.b #1,13(a0)
        move.w M4_LV_GAMEFRAME,d0
        andi.w #$1f,d0
        cmpi.w #15,d0
        blt M4MtT2SteerDone
        addq.b #2,13(a0)
M4MtT2SteerDone:
        rts
; relpos x, y, z and sword2 (big-endian here) of fighters 1..4.
M4MtTank2Kids:
        include '../build/m4-meteor-fighter-params.inc'
        even

; Fighter Istrat 0A:C997: normcoll (explode with divorcefamily), HP 4, AP 8,
; animframe $80, colltype $40, engine flame (makeengine 06:916D).
M4MtFighterI:
        move.l #M4MtFighter,32(a0)
        jsr M4LvNormPtrs
        move.l #M4MtExplode,X_EXP(a0)
        move.b #4,38(a0)
        move.b #8,39(a0)
        move.b #$80,16(a0)
        ori.b #$40,44(a0)
        jsr M4WpMakeEngine
; C9C1. E0: without mother (al_ptr 0) the strategy becomes explode_Istrat
; (next tick); else pos = mother + 2R_mother(relpos), rot = mother's.
M4MtFighter:
        move.b X_STATE(a0),d0
        bne M4MtFgE1
        move.w X_ALPTR(a0),d0
        bne M4MtFgRide
        move.l #M4MtExplode,32(a0)
        moveq #0,d0
        rts
M4MtFgRide:
        movea.w d0,a4
        move.b X_MTREL(a0),d3
        move.b X_MTREL+1(a0),d4
        move.b X_MTREL+2(a0),d5
        bsr M4MtRotX2
        add.w (a4),d3
        add.w 4(a4),d5
        add.w 2(a4),d4
        move.w d3,(a0)
        move.w d5,4(a0)
        move.w d4,2(a0)
        move.b 12(a4),12(a0)
        move.b 13(a4),13(a0)
        move.b 14(a4),14(a0)
        moveq #0,d0
        rts
; E1 (CAA1): rise 5 per tick until y < sword2 (then next state), frames +1
; mod 10 up to frame 9; z += pviewvelz, flame.
M4MtFgE1:
        cmpi.b #1,d0
        bne M4MtFgE2
        move.w 2(a0),d0
        sub.w X_SWORD2(a0),d0
        bmi M4MtFgNext
        subq.w #5,2(a0)
        move.b 16(a0),d0
        andi.b #$7f,d0
        cmpi.b #9,d0
        beq M4MtFgTail
        move.b 16(a0),d0
        moveq #10,d1
        bsr M4MtAfInc
        move.b d0,16(a0)
        bra M4MtFgTail
M4MtFgNext:
        addq.b #1,X_STATE(a0)
        bra M4MtFighter
; E2 (CAFA): speedto(30, 1); with ZD >= 500 rotx/roty Achase8_2 toward the
; player and every 4 gameframes RelSlowElaser $0C with pitch/yaw offsets
; (rnd & 7) - 3 (two random_l calls). E3+: straight on. gen3d, move.
M4MtFgE2:
        cmpi.b #2,d0
        bne M4MtFgFly
        moveq #30,d0
        moveq #1,d1
        jsr M4EnSpeedTo
        movea.l a1,a2
        jsr M4EnZD
        subi.w #500,d0
        bmi M4MtFgFly
        jsr M4EnPitchTo
        move.b d0,d1
        move.b 12(a0),d0
        moveq #2,d2
        jsr M4EnChase8
        move.b d0,12(a0)
        jsr M4EnYawTo
        move.b d0,d1
        move.b 13(a0),d0
        moveq #2,d2
        jsr M4EnChase8
        move.b d0,13(a0)
        move.w M4_LV_GAMEFRAME,d0
        andi.w #3,d0
        bne M4MtFgFly
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
M4MtFgFly:
        jsr M4EnGen3d
        jsr M4EnMove
M4MtFgTail:
        jsr M4EnAddPZ
        jsr M4WpUpdateEngine
        moveq #0,d0
        rts

; ---------------------------------------------------------------------
; up1man 08:D85A (1-UP target, nullshape): no coll/exp, colldisable; three
; pieces C504 (makechild 1..3, Istrats D9D7/DA16/DA55, colltype $40);
; sbyte2 = 5 (spin).
M4StratUp1man:
        move.l #M4MtUp1Tick,32(a0)
        jsr M4LvZeroPtrs
        bset #SF_COLLDISABLE,49(a0)
        lea M4MtUp1Kids,a3
        moveq #1,d1
M4MtUp1Kid:
        move.w #$c504,d0
        move.l (a3)+,d2
        bsr M4MtMakeChild
        beq M4MtUp1KidNext
        ori.b #$40,44(a2)
M4MtUp1KidNext:
        addq.b #1,d1
        cmpi.b #4,d1
        bne M4MtUp1Kid
        move.b #5,37(a0)
; D91D: idle until the first hit (sbyte3 = hits); rotz += sbyte2; ZD < 1500
; -> z += 30; at 3 hits (once, sflag1) the 1-UP myship_4 D320 (08:D785).
M4MtUp1Tick:
        tst.b X_SBYTE3(a0)
        beq M4MtUp1Done
        move.b 37(a0),d0
        add.b d0,14(a0)
        movea.l a1,a2
        jsr M4EnZD
        subi.w #1500,d0
        bpl M4MtUp1Far
        addi.w #30,4(a0)
M4MtUp1Far:
        cmpi.b #3,X_SBYTE3(a0)
        bne M4MtUp1Done
        bset #F2_SFLAG1,48(a0)
        bne M4MtUp1Done
        move.w #$d320,d0
        bsr M4MtCreateHdr
        beq M4MtUp1Done
        move.b #$c0,12(a2)
        move.l #M4MtOneUpI,32(a2)
        move.l (a0),(a2)
        move.w 4(a0),4(a2)
        move.w a0,40(a2)
M4MtUp1Done:
        moveq #0,d0
        rts
M4MtUp1Kids:
        dc.l M4MtUp1KidA,M4MtUp1KidB,M4MtUp1KidC
; Piece Istrats: strategy DA94, collstrat D99E, expstrat 0, HP $FF, AP 8,
; (sbyte2, sbyte3, sbyte4) = offset x, y and rotz offset; run DA94 now.
M4MtUp1KidA:
        move.b #$b0,37(a0)
        move.b #$4b,X_SBYTE3(a0)
        move.b #$60,X_SBYTE4(a0)
        bra M4MtUp1KidI
M4MtUp1KidB:
        move.b #$50,37(a0)
        move.b #$4b,X_SBYTE3(a0)
        move.b #$a0,X_SBYTE4(a0)
        bra M4MtUp1KidI
M4MtUp1KidC:
        clr.b 37(a0)
        move.b #$a6,X_SBYTE3(a0)
        clr.b X_SBYTE4(a0)
M4MtUp1KidI:
        move.l #M4MtUp1Piece,32(a0)
        move.l #M4MtUp1Hit,X_COLL(a0)
        clr.l X_EXP(a0)
        move.b #$ff,38(a0)
        move.b #8,39(a0)
; DA94: pos = mother + Rz_mother(s8 sbyte2, s8 sbyte3) (x1, z kept); rotz =
; mother rotz + sbyte4; hit pieces blink ((gameframe + al1pt) & 1 == 0:
; hitflash). The original reads the mother without testing it; the port
; skips a missing mother.
M4MtUp1Piece:
        move.w X_ALPTR(a0),d0
        beq M4MtUp1PieceBlink
        movea.w d0,a2
        move.b 37(a0),d3
        move.b X_SBYTE3(a0),d4
        move.b 14(a2),d5
        jsr M4WeaponRotatePair
        ext.w d3
        ext.w d4
        add.w (a2),d3
        add.w 2(a2),d4
        move.w d3,(a0)
        move.w d4,2(a0)
        move.w 4(a2),4(a0)
        move.b 14(a2),d0
        add.b X_SBYTE4(a0),d0
        move.b d0,14(a0)
M4MtUp1PieceBlink:
        btst #F2_SFLAG1,48(a0)
        beq M4MtUp1PieceDone
        move.w M4_LV_GAMEFRAME,d0
        add.w a0,d0
        btst #0,d0
        bne M4MtUp1PieceDone
        bset #SF_HITFLASH,49(a0)
        bset #2,31(a0)
M4MtUp1PieceDone:
        moveq #0,d0
        rts
; D99E (hit): first hit only: mother sbyte2 += 2, mother sbyte3 += 1;
; sflag1, collide cleared, colldisable; then the strategy (1F:DC25).
M4MtUp1Hit:
        btst #F2_SFLAG1,48(a0)
        bne M4MtUp1Piece
        move.w X_ALPTR(a0),d0
        beq M4MtUp1HitSelf
        movea.w d0,a2
        addq.b #2,37(a2)
        addq.b #1,X_SBYTE3(a2)
M4MtUp1HitSelf:
        bset #F2_SFLAG1,48(a0)
        bclr #SF_COLLIDE,49(a0)
        bset #SF_COLLDISABLE,49(a0)
        bra M4MtUp1Piece

; 1-UP 08:D785 (myship_4, sword1 = up1man): no coll/exp, colldisable, rotx
; $C0. D7A0: player dead -> removed (deferred, the tick goes on); z += 30;
; ZD < 80, |dy| < 120 and |dx| < 80: lives + 1, children 1, 3 and 4 of
; sword1 removed (no child 4: piece 2 and up1man stay, original bug) and
; the 1-UP removed.
M4MtOneUpI:
        move.l #M4MtOneUp,32(a0)
        jsr M4LvZeroPtrs
        bset #SF_COLLDISABLE,49(a0)
        move.b #$c0,12(a0)
M4MtOneUp:
        moveq #0,d7
        btst #7,M4_LP_PSF2
        beq M4MtOneUpMove
        moveq #1,d7
M4MtOneUpMove:
        addi.w #30,4(a0)
        movea.l a1,a2
        jsr M4EnZD
        subi.w #80,d0
        bpl M4MtOneUpDone
        move.w 2(a1),d0
        sub.w 2(a0),d0
        bpl M4MtOneUpDy
        neg.w d0
M4MtOneUpDy:
        subi.w #120,d0
        bpl M4MtOneUpDone
        move.w (a1),d0
        sub.w (a0),d0
        bpl M4MtOneUpDx
        neg.w d0
M4MtOneUpDx:
        subi.w #80,d0
        bpl M4MtOneUpDone
        addq.b #1,M4_LP_LIVES
        moveq #1,d7
        move.w 40(a0),d0
        beq M4MtOneUpDone
        movea.w d0,a3
        moveq #1,d0
        bsr M4MtOneUpKill
        bne M4MtOneUpDone
        moveq #3,d0
        bsr M4MtOneUpKill
        bne M4MtOneUpDone
        moveq #4,d0
        bsr M4MtOneUpKill
M4MtOneUpDone:
        move.l d7,d0
        rts
; findchild d0 of a3 and remove it (1F:D540) -> Z clear when missing.
M4MtOneUpKill:
        movea.l a3,a2
        jsr M4PvFindChild
        move.l a2,d0
        beq M4MtOneUpKillNone
        exg a0,a2
        jsr M4LevelRemove
        exg a0,a2
        moveq #0,d0
        rts
M4MtOneUpKillNone:
        moveq #1,d0
        rts

; ---------------------------------------------------------------------
; playerplanetflyin 0B:84C8 (newplayerstrat of bg_1_4): the limits and
; flags of playeronplanet_Istrat 0B:BB03 but pshipflags |= $60 (no control,
; no fire), no coll/exp (1F:D450), pos (0, -400, 0), novdistC, medium speed
; 65; then 0B:85CA in the same pass. Also restarts the palette shadow
; (the background has just been loaded again).
M4MtFlyinI:
        clr.b M4_MT_FADEINIT
        bclr #SF_INVISIBLE,49(a0) ;initgame's player_Istrat (0B:B541) clears the playercred flag
        move.b M4_LP_PSF,-(sp)
        jsr M4ScOnPlanetIstrat
        move.b (sp)+,d0
        ori.b #$60,d0
        move.b d0,M4_LP_PSF
        jsr M4LvZeroPtrs
        move.l #M4MtFlyin,32(a0)
        clr.w (a0)
        move.w #-400,2(a0)
        clr.w 4(a0)
        ori.b #1,M4_BOSS_PSTRATF
        jsr M4SpMedSpeed
; 0B:85CA: outdist += 3; y = Achase16_3(y, viewCY) (1F:D6AB: C only when
; already equal on entry): not there -> planet body 0B:BBE3 without control;
; there -> novdistC off and playeronplanet_Istrat 0B:BB03 (+ its strategy).
M4MtFlyin:
        addq.w #3,M4_LP_OUTDIST
        move.w 2(a0),d0
        move.w M4_LP_VIEWCY,d1
        cmp.w d1,d0
        beq M4MtFlyinArrived
        moveq #3,d2
        jsr M4LpAchase
        move.w d0,2(a0)
        jmp M4LevelPlayerStrat
M4MtFlyinArrived:
        andi.b #$fe,M4_BOSS_PSTRATF
        jmp M4ScOnPlanetNew

; ---------------------------------------------------------------------
; Palette fade 02:F6EE (main loop, once per tick before transswap): unless
; the player is dead ($14D9 bit 7), while fadepal ($1EF3) > 0: fadepal--,
; then pallen colours of the CGRAM shadow at palto step one unit per
; component (B, G, R; unsigned compare) toward table 02:F831 + palfrom.
; The shadow holds bg_1_4 rows 1 and 5 (palto 32..63 / 160..191 bytes, the
; only ones used: map0d 0D:B809/B822/BA64/BA7D); other destinations are
; unsupported (status -1, M4_LV_BADOP $F6EE). MD: the M4_SPB_CRAM slots used
; by a single SNES entry in the converted bg $51 follow it (md9 = component
; >> 2); entries merged with other colours by the conversion keep their
; colour (build/agent-meteor/METEOR.md, deliberate difference).
M4MtFadePal:
        movem.l d0-d7/a0-a2,-(sp)
        btst #7,M4_LP_PSF2
        bne M4MtFadeDone
        tst.b M4_MV_1EF3
        beq M4MtFadeDone
        subq.b #1,M4_MV_1EF3
        tst.b M4_MT_FADEINIT
        bne M4MtFadeReady
        lea M4MtPalInit,a0
        lea M4_MT_SHADOW,a1
        moveq #31,d0
M4MtFadeCopy:
        move.w (a0)+,(a1)+
        dbra d0,M4MtFadeCopy
        st M4_MT_FADEINIT
M4MtFadeReady:
        moveq #0,d1
        move.b M4_MV_1F17+1,d1 ;palfrom (little-endian WORD)
        lsl.w #8,d1
        move.b M4_MV_1F17,d1
        moveq #0,d2
        move.b M4_MV_1F19+1,d2 ;palto
        lsl.w #8,d2
        move.b M4_MV_1F19,d2
        move.b M4_MV_1F13+1,d3 ;pallen
        lsl.w #8,d3
        move.b M4_MV_1F13,d3
M4MtFadeColour:
        ; shadow address of byte offset d2 (rows 1 and 5 only)
        move.w d2,d0
        subi.w #32,d0
        cmpi.w #32,d0
        blo M4MtFadeRow
        subi.w #160-32,d0
        cmpi.w #32,d0
        bhs M4MtFadeBad
        addi.w #32,d0
M4MtFadeRow:
        lea M4_MT_SHADOW,a0
        adda.w d0,a0
        cmpi.w #128,d1
        bhs M4MtFadeBad
        lea M4MtFadeTab,a1
        move.w (a1,d1.w),d4 ;target
        move.w (a0),d5 ;current
        moveq #0,d7
        move.w #$7c00,d6
        move.w #$0400,d0
        bsr M4MtFadeComp
        move.w #$03e0,d6
        moveq #$20,d0
        bsr M4MtFadeComp
        moveq #$1f,d6
        moveq #1,d0
        bsr M4MtFadeComp
        move.w d7,(a0)
        addq.w #2,d1
        addq.w #2,d2
        subq.w #1,d3
        bne M4MtFadeColour
        ; MD slots of the single-entry SNES colours
        lea M4MtFadeSlots,a0
        lea M4_MT_SHADOW,a1
        lea M4_SPB_CRAM,a2
M4MtFadeSlot:
        move.w (a0)+,d0
        bmi M4MtFadeSlotsDone
        add.w d0,d0
        move.w (a1,d0.w),d4
        move.w (a0)+,d0
        add.w d0,d0
        ; md9: ((r >> 2) << 1) | ((g >> 2) << 5) | ((b >> 2) << 9)
        move.w d4,d5
        andi.w #$1c,d5
        lsr.w #1,d5
        move.w d4,d6
        andi.w #$380,d6
        lsr.w #2,d6
        or.w d6,d5
        andi.w #$7000,d4
        lsr.w #3,d4
        or.w d4,d5
        move.w d5,(a2,d0.w)
        bra M4MtFadeSlot
M4MtFadeSlotsDone:
        st M4_SC_BGSHOWN ;M4ScBgPalette copies M4_SPB_CRAM again
M4MtFadeDone:
        movem.l (sp)+,d0-d7/a0-a2
        rts
M4MtFadeBad:
        move.w #-1,M4_LV_STATUS
        move.w #$f6ee,M4_LV_BADOP
        bra M4MtFadeDone
; One component (mask d6, unit d0) of d5 toward d4, ORed into d7.
M4MtFadeComp:
        move.w d5,-(sp)
        and.w d6,d5
        and.w d6,d4
        cmp.w d5,d4
        beq M4MtFadeCompSet
        bhi M4MtFadeCompUp
        sub.w d0,d5
        bra M4MtFadeCompSet
M4MtFadeCompUp:
        add.w d0,d5
M4MtFadeCompSet:
        or.w d5,d7
        move.w (sp)+,d5
        move.w (a1,d1.w),d4
        rts
; 02:F831: 64 WORDs (the fades read offsets 64..95 and 96..125).
; Generated and checked by build/agent-meteor/meteor-fade-data.py.
M4MtFadeTab:
        incbin '../build/M4MtFadeTab.bin'
; bg_1_4 palette (7F:0B80, collection 17:F21C): CGRAM rows 1 and 5.
M4MtPalInit:
        incbin '../build/M4MtPalInit.bin'
; (shadow index, M4_SPB_CRAM index) pairs, -1 ends: SNES (1,2) -> line 0
; slot 2; (5,1/3/4/6/7) -> line 1 slots 4/6/2/5/3.
M4MtFadeSlots:
        dc.w $0002,$0002,$0011,$0014,$0013,$0016,$0014,$0012,$0016,$0015,$0017,$0013,-1

        include 'stages/level_meteor_boss.asm'

; Player modes of this stage (original pstrat 24-bit address.l, port Istrat.l;
; 0 ends), searched by M4LevelFindPlayerMode (level_warp.asm).
M4PlayerModesMeteor:
        dc.l 0

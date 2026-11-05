; Corneria 1 non-path strategies, enemy weapons and explosions.
; Research: build/research/corneria-enemies.md (USA rev0, [V-ROM] pseudocode);
; correspondence and reductions in src/m4/LEVEL_ORIGIN.md.
; Conventions (level_objects.asm): a0 = object, a1 = player; strategies
; return d0 = 0 keep / nonzero remove (deferred removal of the current
; object). Comparisons "d < K" of the original are the N bit of the 16-bit
; subtraction d - K; angles are BYTEs with wrap. Every state initialiser of
; these strategies falls through into the next state in the same tick (ROM
; checked at 08:AD1F, 0A:81CC, 0A:8375, 08:D480; 06:9A5B for Hplasma).
M4_LV_GATETEMP equ M4_LV+80 ;index.w stack.w calls 8 WORDs (maprestarttemp)

; ---------------------------------------------------------------------
; Helpers. a2 = other object. Registers other than the result are kept.

; ZD(a0,a2) = abs16(a2.z - a0.z) -> d0 ($8000 stays $8000).
M4EnZD:
        move.w 4(a2),d0
        sub.w 4(a0),d0
        bpl M4EnZDDone
        neg.w d0
M4EnZDDone:
        rts

; distXZ 1F:D0AB -> d0: h = asr1|dx|, k = asr1|dz|, s = (k+h)<<1,
; m = N(k-h) ? h : k, t = m+s, d = asr3(asr1(t) + (t<<2)), 16-bit wrap.
M4EnDistXZ:
        movem.l d1-d3,-(sp)
        move.w (a2),d1
        sub.w (a0),d1
        bpl M4EnDxzH
        neg.w d1
M4EnDxzH:
        asr.w #1,d1
        move.w 4(a2),d2
        sub.w 4(a0),d2
        bpl M4EnDxzK
        neg.w d2
M4EnDxzK:
        asr.w #1,d2
        move.w d2,d3
        add.w d1,d3
        add.w d3,d3
        move.w d2,d0
        sub.w d1,d0
        bmi M4EnDxzMaxH
        move.w d2,d0
        bra M4EnDxzT
M4EnDxzMaxH:
        move.w d1,d0
M4EnDxzT:
        add.w d3,d0
        move.w d0,d1
        asr.w #1,d1
        lsl.w #2,d0
        add.w d1,d0
        asr.w #3,d0
        movem.l (sp)+,d1-d3
        rts

; distXY 1F:D115 -> d0 = |dx| + |dy| (16 bits).
M4EnDistXY:
        move.l d1,-(sp)
        move.w (a2),d0
        sub.w (a0),d0
        bpl M4EnDxyX
        neg.w d0
M4EnDxyX:
        move.w 2(a2),d1
        sub.w 2(a0),d1
        bpl M4EnDxyY
        neg.w d1
M4EnDxyY:
        add.w d1,d0
        move.l (sp)+,d1
        rts

; pitchTo = hi(Xanglexy 1F:D03E): atan(X = a2.y-a0.y, Y = distXZ).
M4EnPitchTo:
        move.l d1,-(sp)
        bsr M4EnDistXZ
        move.w d0,d1
        move.w 2(a2),d0
        sub.w 2(a0),d0
        jsr M4IntroWeaponAtan
        lsr.w #8,d0
        move.l (sp)+,d1
        rts
; yawTo = -hi(Yanglexy 1F:D021): atan(X = dx, Y = dz), byte negated.
M4EnYawTo:
        move.l d1,-(sp)
        move.w (a2),d0
        sub.w (a0),d0
        move.w 4(a2),d1
        sub.w 4(a0),d1
        jsr M4IntroWeaponAtan
        lsr.w #8,d0
        neg.b d0
        move.l (sp)+,d1
        rts
; Toward the way point sWP (1F:CF92 / CF43 / D05C): d0 = yaw target
; -hi(atan(dx,dz)), d1 = pitch target hi(atan(dy, |dx|+|dz|)).
M4EnWayAngles:
        movem.l d2-d4,-(sp)
        move.w X_WPX(a0),d2
        sub.w (a0),d2
        move.w X_WPZ(a0),d3
        sub.w 4(a0),d3
        move.w d2,d0
        move.w d3,d1
        jsr M4IntroWeaponAtan
        lsr.w #8,d0
        neg.b d0
        move.w d0,d4
        tst.w d2
        bpl M4EnWayX
        neg.w d2
M4EnWayX:
        tst.w d3
        bpl M4EnWayZ
        neg.w d3
M4EnWayZ:
        add.w d3,d2
        move.w d2,d1
        move.w X_WPY(a0),d0
        sub.w 2(a0),d0
        jsr M4IntroWeaponAtan
        lsr.w #8,d0
        move.w d0,d1
        move.w d4,d0
        movem.l (sp)+,d2-d4
        rts

; Achase8_n (1F:D85E/D88A/D8BD/D8F7): d0.b value, d1.b target, d2 = n.
; d = s8(t-v); 0<|d|<2^n -> |d| = 2^n; v += trunc0(d/2^n). Returns d0.b,
; d3 = 1 when value already equal to the target (C=1), else 0.
M4EnChase8:
        movem.l d1/d4,-(sp)
        moveq #0,d3
        sub.b d0,d1
        bne M4EnChase8Diff
        moveq #1,d3
        bra M4EnChase8Done
M4EnChase8Diff:
        ext.w d1
        moveq #1,d4
        lsl.w d2,d4
        tst.w d1
        bmi M4EnChase8Neg
        cmp.w d4,d1
        bge M4EnChase8Div
        move.w d4,d1
        bra M4EnChase8Div
M4EnChase8Neg:
        neg.w d4
        cmp.w d4,d1
        ble M4EnChase8NegDiv
        move.w d4,d1
M4EnChase8NegDiv:
        neg.w d1
        asr.w d2,d1
        neg.w d1
        bra M4EnChase8Add
M4EnChase8Div:
        asr.w d2,d1
M4EnChase8Add:
        add.b d1,d0
M4EnChase8Done:
        movem.l (sp)+,d1/d4
        rts

; speedto 1F:D60D: d0 = target T, d1 = step a, on vel 15(a0).
; d = s8(vel-T): 0 -> nothing; |d| < a -> vel = T; else vel +/- a.
M4EnSpeedTo:
        movem.l d2,-(sp)
        move.b 15(a0),d2
        sub.b d0,d2
        beq M4EnSpeedDone
        bmi M4EnSpeedBelow
        cmp.b d1,d2
        blt M4EnSpeedSet
        sub.b d1,15(a0)
        bra M4EnSpeedDone
M4EnSpeedBelow:
        neg.b d2
        cmp.b d1,d2
        blt M4EnSpeedSet
        add.b d1,15(a0)
        bra M4EnSpeedDone
M4EnSpeedSet:
        move.b d0,15(a0)
M4EnSpeedDone:
        movem.l (sp)+,d2
        rts

; gen_3dvecs 1F:C41E with the object's own vel/rotx/roty -> v (6/8/10).
M4EnGen3d:
        movem.l d0,-(sp)
        moveq #0,d0
        move.b 15(a0),d0
        ext.w d0
        jsr M4LevelGen3dVecs
        movem.l (sp)+,d0
        rts
; d0 = speed, angles d1.b rotx d2.b roty -> d3/d4/d5 (object untouched).
M4EnVector:
        movem.l d0-d2/d6-d7,-(sp)
        move.l 6(a0),d6
        move.w 10(a0),d7
        move.w 12(a0),-(sp)
        move.b d1,12(a0)
        move.b d2,13(a0)
        jsr M4LevelGen3dVecs
        movem.w 6(a0),d3-d5
        move.w (sp)+,12(a0)
        move.l d6,6(a0)
        move.w d7,10(a0)
        movem.l (sp)+,d0-d2/d6-d7
        rts
; addvecs 1F:C7BB: pos += v.
M4EnMove:
        move.w 6(a0),d0
        add.w d0,(a0)
        move.w 8(a0),d0
        add.w d0,2(a0)
        move.w 10(a0),d0
        add.w d0,4(a0)
        rts
; addplayerZ 1F:DC69: z += pviewvelz.
M4EnAddPZ:
        move.w M4_LP_PVIEWVZ,d0
        add.w d0,4(a0)
        rts
; Sprites toward the camera: roty = -hi(outvy) + $80 + hi(turnrot),
; rotx = hi(outvx) ($18CA, $152D, $18C8).
M4EnFaceCamera:
        move.b M4_LP_OUTVY,d0
        neg.b d0
        addi.b #$80,d0
        add.b M4_LP_TURNROT,d0
        move.b d0,13(a0)
        move.b M4_LP_OUTVX,12(a0)
        rts
; banktoplayer 1F:DA57.
M4EnBankToPlayer:
        movem.l d1,-(sp)
        move.w (a0),d0
        sub.w M4_SC_PPOSX,d0 ;$150F
        move.w d0,d1
        asr.w #6,d1
        add.b d1,14(a0)
        move.w M4_LV_GAMEFRAME,d1
        add.w a0,d1 ;lo8(al1pt): port object address
        andi.w #3,d1
        bne M4EnBankDone
        tst.w d0
        bmi M4EnBankYawNeg
        addq.b #1,13(a0)
        bra M4EnBankPitch
M4EnBankYawNeg:
        subq.b #1,13(a0)
M4EnBankPitch:
        move.w 2(a0),d0
        sub.w M4_SC_PPOSY,d0 ;$1511
        bmi M4EnBankPitchNeg
        addq.b #1,12(a0)
        bra M4EnBankDone
M4EnBankPitchNeg:
        subq.b #1,12(a0)
M4EnBankDone:
        movem.l (sp)+,d1
        rts
; Shield pBody.HP = min(HP + d0, 40) (bit N), only when HP != 0 (callers).
M4EnShieldAdd:
        add.b M4_LP_BODYHP,d0
        move.b d0,d1
        subi.b #40,d1
        bmi M4EnShieldStore
        moveq #40,d0
M4EnShieldStore:
        move.b d0,M4_LP_BODYHP
        rts
; Create an object behind the current one with descriptor d0 -> a2 (or 0).
M4EnCreate:
        movem.l d0/a0,-(sp)
        jsr M4LevelAlloc
        movea.l a0,a2
        cmpa.w #0,a0
        beq M4EnCreateDone
        move.w 2(sp),d0
        jsr M4LevelSetShape
M4EnCreateDone:
        movem.l (sp)+,d0/a0
        cmpa.w #0,a2 ;Z set on failure
        rts
M4EnRemoveSelf:
        moveq #1,d0
        rts
M4EnKeep:
        moveq #0,d0
        rts
; kill 06:8D07: colldisable, HP 0 (the expstrat runs on the next tick).
M4EnKill:
        bset #SF_COLLDISABLE,49(a0)
        clr.b 38(a0)
        rts

; ---------------------------------------------------------------------
; Enemy weapons: M4EnFire and the projectile strategies are in
; level_weapons.asm (included at the end of this file).

; Flash 06:B6E6 (init: sprite, colldisable, colframe $80, z += pviewvelz)
; and 06:B715 (z += pviewvelz; colframe 2 -> remove, else +1 mod 4).
M4WpFlashInit:
        bset #F2_SPRITE,48(a0)
        bset #SF_COLLDISABLE,49(a0)
        move.b #$80,18(a0)
        bsr M4EnAddPZ
        move.l #M4WpFlashTick,32(a0)
        moveq #0,d0
        rts
M4WpFlashTick:
        bsr M4EnAddPZ
        move.b 18(a0),d0
        andi.b #$7f,d0
        cmpi.b #2,d0
        beq M4EnRemoveSelf
        addq.b #1,d0
        andi.b #3,d0
        ori.b #$80,d0
        move.b d0,18(a0)
        moveq #0,d0
        rts

; Laser animframe ($1CE7 = port 16, the drawn geometry frame; the player
; laser keeps it there too): $80 at init, s_add_anim(2, 8) until
; (frame & $7F) == 4 (06:9F23, 06:9EB6, 06:A02C).
M4WpLaserFrame:
        move.b 16(a0),d0
        andi.b #$7f,d0
        cmpi.b #4,d0
        beq M4WpFrameDone
        movem.l d1-d2,-(sp)
        move.b 16(a0),d0
        moveq #2,d1
        moveq #8,d2
        bsr M4WpAddAnim
        move.b d0,16(a0)
        movem.l (sp)+,d1-d2
M4WpFrameDone:
        rts
; RelSlowElaserHome init 06:9EF4: angles from sbyte1/2, v = 2*gen3d,
; frame $80. No movement on the creation tick.
M4WpRsehInit:
        move.l #M4WpRsehTick,32(a0)
        move.b 36(a0),12(a0)
        move.b 37(a0),13(a0)
        bsr M4EnGen3d
        asl.w 6(a0)
        asl.w 8(a0)
        asl.w 10(a0)
        move.b #$80,16(a0)
        moveq #0,d0
        rts
; tick 06:9F23: guided (1/tick) toward the player until ZD < 800.
M4WpRsehTick:
        bsr M4WpLaserFrame
        btst #F2_SFLAG2,48(a0)
        bne M4WpRsehMove
        movea.l a1,a2
        bsr M4EnZD
        subi.w #800,d0
        bpl M4WpRsehGuide
        bset #F2_SFLAG2,48(a0)
M4WpRsehGuide:
        bsr M4EnPitchTo
        move.b d0,d1
        move.b 12(a0),d0
        moveq #1,d2
        bsr M4EnChase8
        move.b d0,12(a0)
        bsr M4EnYawTo
        move.b d0,d1
        move.b 13(a0),d0
        bsr M4EnChase8
        move.b d0,13(a0)
        bsr M4EnGen3d
        asl.w 6(a0)
        asl.w 8(a0)
        asl.w 10(a0)
M4WpRsehMove:
        bra M4WpMoveCommon
; RelSlowElaser init 06:9E5C: v = 2*gen3d(vel) + gen3d(sbyte3).
M4WpRseInit:
        move.l #M4WpRseTick,32(a0)
        move.b 36(a0),12(a0)
        move.b 37(a0),13(a0)
        moveq #0,d0
        move.b X_SBYTE3(a0),d0
        ext.w d0
        move.b 12(a0),d1
        move.b 13(a0),d2
        bsr M4EnVector
        bsr M4EnGen3d
        move.w 6(a0),d0
        add.w d0,d0
        add.w d3,d0
        move.w d0,6(a0)
        move.w 8(a0),d0
        add.w d0,d0
        add.w d4,d0
        move.w d0,8(a0)
        move.w 10(a0),d0
        add.w d0,d0
        add.w d5,d0
        move.w d0,10(a0)
        move.b #$80,16(a0)
        moveq #0,d0
        rts
; relbeamball init 06:9C1E (falls into the tick 06:9C4B): sbyte1/2 = angles,
; v = gen3d(vel); tick: z += pviewvelz, pos += v, count-- -> kill, 06:90DB.
M4WpBeamInit:
        move.l #M4WpBeamTick,32(a0)
        move.b 13(a0),36(a0)
        move.b 12(a0),37(a0)
        bsr M4EnGen3d
M4WpBeamTick:
        bsr M4EnAddPZ
        bsr M4EnMove
        subq.b #1,19(a0)
        bne M4WpFinal
        bsr M4EnKill
        bra M4WpFinal
; tick 06:9EB6.
M4WpRseTick:
        bsr M4WpLaserFrame
M4WpMoveCommon:
        bsr M4EnAddPZ
        bsr M4EnMove
        subq.b #1,19(a0)
        beq M4EnRemoveSelf
; 06:90DB: unless sflag1, Corneria limits ($14D7 = 8): kill when y >= 0.
M4WpFinal:
        btst #2,M4_LP_GAMEFLAGS ;boss dead or dying: enemy weapons killed
        bne.s M4WpFinalKill
        tst.b M4_BOSS_DYING
        bne.s M4WpFinalKill
        btst #F2_SFLAG1,48(a0)
        bne M4WpFinalDone
        bsr.s M4WpLimits ;06:901A
        beq.s M4WpFinalDone
M4WpFinalKill:
        bsr M4EnKill
M4WpFinalDone:
        moveq #0,d0
        rts
; 06:901A limits by pmovelimits $14D7 (M4_SPP_LIMITS) for a0: Z clear = kill.
; "v > K" = cmp, beq/bmi keep (N bit of the 16-bit difference). Bit 1: x >
; $1577; bit 0: x < $1575; bits $64: y > $1579 -> floor test, else bit $40
; and px > $1585 -> floor test, else no bit $20 or px > $1583 -> kill;
; bits $18 (floor): y >= $1581 and (no bit $10 or px > $1587) -> kill.
M4WpLimits:
        movem.l d0-d1,-(sp)
        move.b M4_SPP_LIMITS,d1
        btst #1,d1
        beq.s M4WpLimX0
        move.w (a0),d0
        sub.w M4_PM_1577,d0
        beq.s M4WpLimX0
        bpl M4WpLimKill
M4WpLimX0:
        btst #0,d1
        beq.s M4WpLimWall
        move.w (a0),d0
        sub.w M4_PM_1575,d0
        bmi M4WpLimKill
M4WpLimWall:
        move.b d1,d0
        andi.b #$64,d0
        beq.s M4WpLimFloor
        move.w 2(a0),d0
        sub.w M4_LP_MINY,d0 ;$1579
        beq.s M4WpLimWall2
        bpl.s M4WpLimFloor
M4WpLimWall2:
        btst #6,d1
        beq.s M4WpLimWall3
        move.w LV_PLAYER,d0
        sub.w M4_PM_1585,d0
        beq.s M4WpLimWall3
        bpl.s M4WpLimFloor
M4WpLimWall3:
        btst #5,d1
        beq M4WpLimKill
        move.w LV_PLAYER,d0
        sub.w M4_PM_1583,d0
        beq.s M4WpLimFloor
        bpl M4WpLimKill
M4WpLimFloor:
        move.b d1,d0
        andi.b #$18,d0
        beq.s M4WpLimKeep
        move.w 2(a0),d0
        sub.w M4_PM_1581,d0
        bmi.s M4WpLimKeep
        btst #4,d1
        beq M4WpLimKill
        move.w LV_PLAYER,d0
        sub.w M4_PM_1587,d0
        beq.s M4WpLimKeep
        bpl M4WpLimKill
M4WpLimKeep:
        movem.l (sp)+,d0-d1
        ori.b #4,ccr ;Z: keep
        rts
M4WpLimKill:
        movem.l (sp)+,d0-d1
        andi.b #$fb,ccr ;Z clear: kill
        rts

; Hplasma init 06:9A5B (falls into the tick): sbyte1 = roty, sbyte2 = rotx,
; drawn as a camera-facing sprite. tick 06:9A7E: zremove, out of view ->
; removed (deferred); homing on al_ptr (bomwing: the player) by >>4 while
; ZD >= 500; v = gen3d(60) + gen3d(sbyte3) along (sbyte2, sbyte1).
M4WpPlasmaInit:
        move.l #M4WpPlasmaTick,32(a0)
        move.b 13(a0),36(a0)
        move.b 12(a0),37(a0)
        clr.b 12(a0)
        move.b #$80,13(a0)
M4WpPlasmaTick:
        bset #3,45(a0)
        moveq #0,d7
        btst #AF_INVIEWPL,51(a0)
        bne M4WpPlasmaView
        moveq #1,d7
M4WpPlasmaView:
        bsr M4EnFaceCamera
        move.w X_ALPTR(a0),d0
        beq M4WpPlasmaVec
        movea.w d0,a2
        bsr M4EnZD
        subi.w #500,d0
        bmi M4WpPlasmaVec
        bsr M4EnPitchTo
        move.b d0,d1
        move.b 37(a0),d0
        moveq #4,d2
        bsr M4EnChase8
        move.b d0,37(a0)
        bsr M4EnYawTo
        move.b d0,d1
        move.b 36(a0),d0
        bsr M4EnChase8
        move.b d0,36(a0)
M4WpPlasmaVec:
        move.b 37(a0),d1
        move.b 36(a0),d2
        move.b 15(a0),d0 ;vel: 06:9B52 lda $15,x
        ext.w d0
        bsr M4EnVector
        move.w d3,6(a0)
        move.w d4,8(a0)
        move.w d5,10(a0)
        moveq #0,d0
        move.b X_SBYTE3(a0),d0
        ext.w d0
        bsr M4EnVector
        add.w d3,6(a0)
        add.w d4,8(a0)
        add.w d5,10(a0)
        bsr M4EnAddPZ
        bsr M4EnMove
        subq.b #1,19(a0)
        bne M4WpPlasmaAlive
        moveq #1,d7
M4WpPlasmaAlive:
        bsr M4WpFinal
        move.l d7,d0
        rts

; weapcollide 06:87C7: collider AP 0 -> do_coll(1); collider not a weapon
; -> kill (06:8D07, nothing else this tick); weapon against weapon ->
; do_coll(AP). Then HP 0 -> expstrat now, otherwise the normal strategy.
M4WpCollide:
        bclr #SF_COLLIDE,49(a0)
        jsr M4LcCollider
        move.l a2,d0
        beq M4WpCollKill
        moveq #1,d0
        tst.b 39(a2)
        beq M4WpCollDo
        btst #1,44(a2)
        beq M4WpCollKill
        move.b 39(a2),d0
M4WpCollDo:
        jsr M4LevelDoColl
        bra M4WpCollAfter
M4WpCollKill: ;06:87E9 jml 8D07: kill and end the tick (expstrat on the next one)
        bsr M4EnKill
        moveq #0,d0
        rts
M4WpCollAfter:
        tst.b 38(a0)
        bne M4LcStrategy
        movea.l X_EXP(a0),a2
        jmp (a2)

; Laser explosion 06:A066: spark B2A5 at the laser (camera-facing, no
; collision), then 06:A0B9 every tick: z += pviewvelz (relexplode, unless
; gameflags $14D2 bit1); frame s_add_anim(2, 9) until (frame & $7F) == 8,
; then spark and laser removed.
M4WpLaserExp:
        clr.w X_ALPTR(a0)
        move.l #M4_FX_SPARK,d0 ;descriptor index may exceed 127
        bsr M4EnCreate
        beq M4WpLaserExpNoSpark
        move.l (a0),(a2)
        move.w 4(a0),4(a2)
        move.l #M4FxSparkInit,32(a2)
        move.w a2,X_ALPTR(a0)
M4WpLaserExpNoSpark:
        move.l #M4WpLaserExp2,X_EXP(a0)
M4WpLaserExp2:
        btst #F2_RELEXPLODE,48(a0)
        beq M4WpLaserExpFrame
        btst #1,M4_LP_GAMEFLAGS ;06:A0C3: lda $14D2; and #$02
        bne M4WpLaserExpFrame
        bsr M4EnAddPZ
M4WpLaserExpFrame:
        move.b 16(a0),d0
        andi.b #$7f,d0
        cmpi.b #8,d0
        beq M4WpLaserExpEnd
        move.b 16(a0),d0
        moveq #2,d1
        moveq #9,d2
        bsr M4WpAddAnim
        move.b d0,16(a0)
        moveq #0,d0
        rts
M4WpLaserExpEnd:
        move.w X_ALPTR(a0),d0
        beq M4EnRemoveSelf
        movea.l a0,a3
        movea.w d0,a0
        jsr M4LevelRemove
        movea.l a3,a0
        bra M4EnRemoveSelf
; 06:8D60: camera-facing, colldisable, no strategy.
M4FxSparkInit: ;(no ssprite flag: 06:8D60 only faces the camera)
        bsr M4EnFaceCamera
        bset #SF_COLLDISABLE,49(a0)
        clr.l 32(a0)
        moveq #0,d0
        rts

; ---------------------------------------------------------------------
; explode_Istrat 06:F45F (a0 = destroyed object). divorcefamily and debris
; (debrisshape) are not used by these strategies; sounds are not ported.
M4LevelExplode:
        btst #SF_SPECIAL,49(a0)
        beq M4ExNoGate
        move.l #M4_SH_GATE_2,d0 ;descriptor index may exceed 127
        bsr M4EnCreate
        beq M4ExGateDone
        move.l (a0),(a2)
        move.w 4(a0),4(a2)
        move.l #M4StratGate2,32(a2)
M4ExGateDone:
        jsr M4AstDebris ;06:F4A8: debrisshape -> debris 06:F1DA (level_asteroid.asm)
        addq.w #1,M4_LV_SPECIALDEAD
        bra M4ExView
M4ExNoGate:
        jsr M4AstDebris
        btst #F2_CSPECIAL,48(a0)
        beq M4ExView
        addq.w #1,M4_LV_SPECIALDEAD
M4ExView:
        btst #F2_NOEXPSND,48(a0)
        bne.s M4ExSoundDone
        M4PlaySfxAt $21 ;explode_Istrat 06:F45F, destenemysound
M4ExSoundDone:
        jsr M4WpDropFlame ;afonfire: flame removed after gate_2/debris (06:F4E4 in view, 1F:D50B out of view)
        btst #AF_INVIEWPL,51(a0)
        beq M4EnRemoveSelf ;out of view: no explosion
        bset #0,25(a0) ;afexp
        clr.b 38(a0)
        bclr #F2_SPRITE,48(a0)
        bset #SF_COLLDISABLE,49(a0)
        move.l #M4_FX_EXPLOSION,d0 ;descriptor index may exceed 127 ;replaced below by the size class
        bsr M4EnCreate
        beq M4EnRemoveSelf
        move.b 48(a0),48(a2)
        move.b 49(a0),d0
        andi.b #$ff-(1<<SF_SPECIAL)-(1<<SF_HITFLASH),d0
        move.b d0,49(a2)
        bclr #F2_SHADOW,48(a2)
        bclr #3,X2_FL3(a2) ;06:F54C: the explosion sprite is not realobj
        bset #F2_SPRITE,48(a2)
        ; sh_size of the original shape (unsigned classes)
        move.w 46(a0),d0
        move.w #$bc,d1 ;nullshape 00:ACA1 sh_size
        cmpi.w #$ffff,d0
        beq M4ExSize
        lsl.w #5,d0
        lea M4LevelShapeDescriptors,a3
        move.w 26(a3,d0.w),d1
M4ExSize:
        lea M4ExClasses,a3
        cmpi.w #M4ExLimit1,d1
        blo M4ExClass
        lea 12(a3),a3
        cmpi.w #M4ExLimit2,d1
        blo M4ExClass
        lea 12(a3),a3
        cmpi.w #M4ExLimit3,d1
        blo M4ExClass
        lea 12(a3),a3
M4ExClass:
        ; sprite tx = lo8(((S - limit) & $FFFF) >> sh_shift >> class_shift), class 4: 0
        movem.l d0-d2,-(sp)
        moveq #0,d2
        move.w 46(a0),d0
        cmpi.w #$ffff,d0
        beq.s M4ExShiftNull
        lea M4LevelShapeShift,a4
        move.b (a4,d0.w),d2
M4ExShiftNull:
        moveq #0,d0
        move.b 7(a3),d0 ;>> after the shift (0: class 4, tx 0)
        beq.s M4ExTxStore
        sub.w 8(a3),d1 ;S - limit (16-bit)
        andi.l #$ffff,d1
        lsr.l d2,d1
        lsr.l d0,d1
        move.b d1,d0
        move.b d0,X_TX(a2)
M4ExTxStore:
        movem.l (sp)+,d0-d2
        move.b 1(a3),X_COUNT1(a2)
        move.w 2(a3),d0
        exg a0,a2
        jsr M4LevelSetShape
        exg a0,a2
        move.w 4(a3),d0
        jsr M4LevelSetShape
        move.l #M4FxExplodeTick,X_EXP(a0)
        tst.b 6(a3)
        beq M4ExRandom
        move.l #M4FxLExplodeTick,X_EXP(a0)
M4ExRandom:
        jsr M4IntroRandom
        move.b d0,12(a0)
        jsr M4IntroRandom
        move.b d0,13(a0)
        move.b #12,X_COUNT1(a0)
        clr.b 19(a0)
        clr.b 19(a2)
        move.b #$80,18(a0)
        move.b #$80,18(a2)
        move.l (a0),(a2)
        move.w 4(a0),4(a2)
        exg a0,a2
        bsr M4EnFaceCamera
        exg a0,a2
        move.l #M4FxExplodeTick,32(a2)
        clr.l X_COLL(a2)
        clr.l X_EXP(a2)
        move.b #$ff,38(a2)
        move.b #8,39(a2)
        bset #SF_COLLDISABLE,49(a2)
        move.l 6(a0),6(a2)
        move.w 10(a0),10(a2)
        btst #F2_NOPOLYEXP,48(a0)
        bne M4EnRemoveSelf
        moveq #0,d0
        rts
; size class: count1 (sprite), sprite descriptor, polygon descriptor, L,
; tx shift, tx limit (12 bytes)
        include '../build/m4-explosion-classes.inc'
M4ExClasses:
        dc.b 0,M4ExTicks1
        dc.w M4_FX_EXPLOSION,M4_FX_EXPL4
        dc.b 0,M4ExShift1
        dc.w M4ExLimit1
        dc.w 0
        dc.b 0,M4ExTicks2
        dc.w M4_FX_EXPLOSION2,M4_FX_EXPL6
        dc.b 0,M4ExShift2
        dc.w M4ExLimit2
        dc.w 0
        dc.b 0,M4ExTicks3
        dc.w M4_FX_EXPLOSION3,M4_FX_EXPL8
        dc.b 0,M4ExShift3
        dc.w M4ExLimit3
        dc.w 0
        dc.b 0,M4ExTicks4
        dc.w M4_FX_EXPLOSION4,M4_FX_EXPL8
        dc.b 1,0
        dc.w 0
        dc.w 0

; explode_strat 06:F7AD: colframe +1 mod 8, count++, relexplode z +=
; pviewvelz, pos += v, removed when count >= count1 (bit N).
; Lexplode_strat 06:F783: colframe/count only on even gameframes.
M4FxLExplodeTick:
        btst #0,M4_LV_GAMEFRAME+1
        bne M4FxExplodeMove
M4FxExplodeTick:
        move.b 18(a0),d0
        addq.b #1,d0
        andi.b #7,d0
        ori.b #$80,d0
        move.b d0,18(a0)
        addq.b #1,19(a0)
M4FxExplodeMove:
        btst #F2_RELEXPLODE,48(a0)
        beq M4FxExplodeVec
        bsr M4EnAddPZ
M4FxExplodeVec:
        bsr M4EnMove
        move.b 19(a0),d0
        sub.b X_COUNT1(a0),d0
        bpl M4EnRemoveSelf
        moveq #0,d0
        rts

; makeMEDexpobj 06:EEEE/EF1B: mediumshape ACF5 placeholder at the creator,
; no collision/sound, follows the player, delayexplode. Returns a2 (or 0).
M4FxMedium:
        move.l #M4_FX_MEDIUM,d0 ;descriptor index may exceed 127
        bsr M4EnCreate
        beq M4FxMediumDone
        bset #SF_COLLDISABLE,49(a2)
        bclr #3,X2_FL3(a2) ;06:EF2F: makeexpobj clears realobj
        bset #F2_NOEXPSND,48(a2)
        bset #F2_RELEXPLODE,48(a2)
        move.l #M4FxDelayInit,32(a2)
        move.l (a0),(a2)
        move.w 4(a0),4(a2)
M4FxMediumDone:
        cmpa.w #0,a2
        rts
; delayexplode_Istrat 06:EE09 and 06:EE38: count-- ; was 0 -> colldisable,
; HP 0 and explode now; else relexplode z += pviewvelz.
M4FxDelayInit:
        move.b #$ff,38(a0)
        move.b #8,39(a0)
        move.l #M4FxDelayTick,32(a0)
        clr.l X_COLL(a0)
        move.l #M4LevelExplode,X_EXP(a0)
M4FxDelayTick:
        bset #SF_HITFLASH,49(a0)
        subq.b #1,19(a0)
        bpl M4FxDelayWait
        bset #SF_COLLDISABLE,49(a0)
        clr.b 38(a0)
        bra M4LevelExplode
M4FxDelayWait:
        btst #F2_RELEXPLODE,48(a0)
        beq M4FxDelayDone
        bsr M4EnAddPZ
M4FxDelayDone:
        moveq #0,d0
        rts

; makesmoke 06:8EA8 / 06:8F72 / 06:8FA7: ADD5 at the creator, flat, zremove,
; no collision; colframe 0..7 (removed when it returns to 0), x - 1,
; y - growth (6, one less every 20 ticks), then pos += v. Returns a2.
M4FxSmoke:
        move.l #M4_FX_SMOKE,d0 ;descriptor index may exceed 127
        bsr M4EnCreate
        beq M4FxSmokeDone
        bset #SF_COLLDISABLE,49(a2)
        move.l (a0),(a2)
        move.w 4(a0),4(a2)
        move.b #$80,13(a2)
        move.l #M4FxSmokeInit,32(a2)
M4FxSmokeDone:
        cmpa.w #0,a2
        rts
M4FxSmokeInit:
        move.b #20,36(a0)
        move.w #6,40(a0)
        move.b #$80,18(a0)
        move.l #M4FxSmokeTick,32(a0)
M4FxSmokeTick:
        move.b 18(a0),d0
        addq.b #1,d0
        andi.b #7,d0
        beq M4EnRemoveSelf
        ori.b #$80,d0
        move.b d0,18(a0)
        subq.w #1,(a0)
        move.w 40(a0),d0
        sub.w d0,2(a0)
        subq.b #1,36(a0)
        bne M4FxSmokeMove
        move.b #20,36(a0)
        subq.w #1,40(a0)
        beq M4EnRemoveSelf
M4FxSmokeMove:
        bsr M4EnMove
        moveq #0,d0
        rts

; delayremove 06:8D20/8D45: indestructible, no pointers, colldisable;
; count-- each tick (the first one now), removed at 0.
M4FxDelayRemove:
        bclr #F2_RELEXPLODE,48(a0)
M4FxDelayRemoveKeep: ;06:8D17 entry keeps relexplode
        move.b #$ff,38(a0)
        move.b #8,39(a0)
        move.l #M4FxDelayRemoveTick,32(a0)
        clr.l X_COLL(a0)
        clr.l X_EXP(a0)
        bset #SF_COLLDISABLE,49(a0)
M4FxDelayRemoveTick:
        subq.b #1,19(a0)
        beq M4EnRemoveSelf
        btst #F2_RELEXPLODE,48(a0)
        beq.s M4FxDelayRemoveStay
        bsr M4EnAddPZ
M4FxDelayRemoveStay:
        moveq #0,d0
        rts

; ---------------------------------------------------------------------
; Strategies created by the map.

; rader0_Istrat 08:B19E: normal pointers, HP 8, AP 4, enemy1|Zenemy;
; tick 08:B1C3: roty += 8.
M4StratRader0:
        bsr M4LvNormPtrs
        move.b #8,38(a0)
        move.b #4,39(a0)
        ori.b #CF_ENEMY1|$01,44(a0)
        move.l #M4StratTower0Tick,32(a0)
        bra M4StratTower0Tick
; hard90yr 0A:8790: roty $80, HP $FF, AP 8, no strategy.
M4StratHard90YR:
        move.b #$80,13(a0)
        bra M4StratHard

; zaco1L 08:B1CB / zaco1R 08:B1DB.
M4StratZaco1L:
        move.w #1000,40(a0)
        move.b #6,37(a0)
        bra M4StratZaco1
M4StratZaco1R:
        move.w #-1000,40(a0)
        move.b #-6,37(a0)
M4StratZaco1:
        bset #F2_SHADOW,48(a0)
        move.w M4_SC_PPOSX,d0 ;player_posx $150F
        add.w d0,(a0)
        add.w d0,40(a0)
        bsr M4LvNormPtrs
        move.b #2,38(a0)
        move.b #4,39(a0)
        move.b #60,15(a0)
        bclr #3,45(a0)
        ori.b #$20|$40|$01,44(a0)
        move.w 40(a0),X_WPX(a0)
        move.l #M4Zaco1Strat,32(a0)
; 08:B257: way point (sword1, 0, player z + 1500), chase >>3; ZD >= 1000 ->
; zaco1a.
M4Zaco1Strat:
        move.w M4_LP_POSZ,d0 ;player_posz $1513
        addi.w #1500,d0
        move.w d0,X_WPZ(a0)
        bsr M4EnWayAngles
        move.b d1,d5
        move.b d0,d1
        move.b 13(a0),d0
        moveq #3,d2
        bsr M4EnChase8
        move.b d0,13(a0)
        move.b d5,d1
        move.b 12(a0),d0
        bsr M4EnChase8
        move.b d0,12(a0)
        movea.l a1,a2
        bsr M4EnZD
        subi.w #1000,d0
        bmi M4Zaco1Cont
        ; zaco1a_init 08:B372
        move.l #M4Zaco1aStrat,32(a0)
        bset #3,45(a0)
; 08:B385: roty chases 0 (>>3); already 0 -> zaco1b; else rotx - 1.
M4Zaco1aStrat:
        move.b 13(a0),d0
        moveq #0,d1
        moveq #3,d2
        bsr M4EnChase8
        move.b d0,13(a0)
        tst.w d3
        bne M4Zaco1bInit
        subq.b #1,12(a0)
        bra M4Zaco1Cont
M4Zaco1bInit:
        move.l #M4Zaco1bStrat,32(a0)
; 08:B3AE: ZD < 1400 circle; 1400..1799 fire RSEH every 4th tick (the
; orientation test then uses the new laser); >= 1800 no circle.
M4Zaco1bStrat:
        movea.l a1,a2
        bsr M4EnZD
        move.w d0,d1
        subi.w #1400,d1
        bmi M4Zaco1Circ
        subi.w #400,d1
        bpl M4Zaco1NoCirc
        move.w M4_LV_GAMEFRAME,d0
        andi.w #3,d0
        bne M4Zaco1NoCirc
        moveq #0,d0
        moveq #0,d3
        moveq #0,d4
        moveq #0,d5
        moveq #0,d6
        moveq #0,d7
        movea.l a1,a3
        bsr M4EnFire
        move.l a2,d0
        bne M4Zaco1NoCirc
        movea.l a1,a2 ;dummyobj: port uses the player
        bra M4Zaco1NoCirc
M4Zaco1Circ:
        moveq #45,d0
        moveq #1,d1
        bsr M4EnSpeedTo
        lea M4IntroShipSine,a3
        moveq #0,d0
        move.b 14(a0),d0
        subi.b #$40,d0
        move.b d0,36(a0)
        move.b (a3,d0.w),d1
        ext.w d1
        bpl M4Zaco1SinPos
        addq.w #7,d1
M4Zaco1SinPos:
        asr.w #3,d1
        move.w d1,X_SWORD2(a0)
        move.b 64(a3,d0.w),d1
        ext.w d1
        bpl M4Zaco1CosPos
        addq.w #3,d1
M4Zaco1CosPos:
        asr.w #2,d1
        move.w d1,X_ALPTR(a0)
        move.b 37(a0),d0
        add.b d0,14(a0)
        movea.l a1,a2
; 08:B4A0: ZD(x,Y) >= 700 -> rotx/roty chase pitchTo/yawTo (>>3).
M4Zaco1NoCirc:
        bsr M4EnZD
        subi.w #700,d0
        bmi M4Zaco1Cont
        bsr M4EnPitchTo
        move.b d0,d1
        move.b 12(a0),d0
        moveq #3,d2
        bsr M4EnChase8
        move.b d0,12(a0)
        bsr M4EnYawTo
        move.b d0,d1
        move.b 13(a0),d0
        bsr M4EnChase8
        move.b d0,13(a0)
; 08:B327: v = gen3d; ground clamp before moving; orbit offsets
; (sword2, al_ptr); pos += v; z += pviewvelz.
M4Zaco1Cont:
        bsr M4EnGen3d
        tst.w 2(a0)
        bmi M4Zaco1Air
        clr.w 2(a0)
M4Zaco1Air:
        move.w X_SWORD2(a0),d0
        add.w d0,2(a0)
        move.w X_ALPTR(a0),d0
        add.w d0,(a0)
        bsr M4EnMove
        bsr M4EnAddPZ
        moveq #0,d0
        rts

; zacos 08:AC8B: formation with a loop.
M4StratZacos:
        bsr M4LvNormPtrs
        move.b #2,38(a0)
        move.b #4,39(a0)
        move.b #40,15(a0)
        move.b #$40,12(a0)
        move.b #$80,13(a0)
        move.w M4_SC_PPOSX,d0 ;08:ACB5 player_posx $150F
        add.w d0,(a0)
        bset #F2_SHADOW,48(a0)
        ori.b #$01,44(a0)
        move.l #M4ZacosStrat,32(a0)
; 08:ACCE: dive until <= 800 above the player, then level off (-2/tick).
M4ZacosStrat:
        move.w M4_SC_PPOSY,d0 ;08:ACD0 player_posy $1511
        subi.w #800,d0
        move.w 2(a0),d1
        sub.w d0,d1
        bmi M4ZacosCont
        tst.b 12(a0)
        beq M4Zacos2Init
        subq.b #2,12(a0)
; 08:AD04
M4ZacosCont:
        bsr M4EnGen3d
        bsr M4EnMove
        bsr M4EnAddPZ
        moveq #0,d0
        rts
; 08:AD1F: one RelSlowElaser (0,0,10), then wait for ZD < 2000.
M4Zacos2Init:
        move.l #M4Zacos2Strat,32(a0)
        bsr M4ZacosFire
M4Zacos2Strat:
        movea.l a1,a2
        bsr M4EnZD
        subi.w #2000,d0
        bpl M4ZacosCont
        move.l #M4Zacos3Strat,32(a0)
        subq.b #4,12(a0)
; 08:AD8C: loop -4/tick; fires at rotx 0 and every 4th tick in $01..$3F;
; rotx $FC -> zacos4.
M4Zacos3Strat:
        subq.b #4,12(a0)
        move.b 12(a0),d0
        beq M4Zacos3Fire
        bmi M4Zacos3NoFire
        cmpi.b #$40,d0
        bhs M4Zacos3NoFire
        move.w M4_LV_GAMEFRAME,d0
        andi.w #3,d0
        bne M4Zacos3NoFire
M4Zacos3Fire:
        bsr M4ZacosFire
M4Zacos3NoFire:
        cmpi.b #$fc,12(a0)
        bne M4ZacosCont
        move.l #M4Zacos4Strat,32(a0)
; 08:ADFD: speed to 60, bank toward the player.
M4Zacos4Strat:
        moveq #60,d0
        moveq #1,d1
        bsr M4EnSpeedTo
        bsr M4EnBankToPlayer
        bra M4ZacosCont
M4ZacosFire:
        moveq #1,d0
        moveq #0,d3
        moveq #0,d4
        moveq #10,d5
        moveq #0,d6
        moveq #0,d7
        suba.l a3,a3
        bra M4EnFire

; zaco4 (kamikaze) 0A:8004: retried every tick until a pillar3 is found.
M4StratZaco4:
        move.b #4,X_SBYTE3(a0)
        move.w #M4_SH_PILLAR3,d4
        bsr M4EnFindNear
        move.l a2,d0
        beq M4EnKeep
        move.w a2,X_ALPTR(a0)
        move.l #M4Zaco3Strat,32(a0)
        move.l #M4LcHitFlash,X_COLL(a0)
        move.l #M4Zaco3Die,X_EXP(a0)
        move.b #2,38(a0)
        move.b #8,39(a0)
        move.b #$40,14(a0)
        move.b #2,36(a0)
        move.b #140,37(a0)
        ori.b #CF_ENEMY1,44(a0)
        bra M4EnKeep
; find_nearobj 1F:C870 from the head: descriptor d4, distXZ in [0, 10000),
; first of the list on ties. Returns a2 or 0.
M4EnFindNear:
        move.w #10000,d2
; d2 = maximum (findshape: 7000).
M4EnFindNearMax:
        movem.l d0-d3/a3,-(sp)
        suba.l a3,a3
        move.w M4_LV_HEAD,d3
M4EnFindNext:
        tst.w d3
        beq M4EnFindDone
        movea.w d3,a2
        move.w X_NEXT(a2),d3
        cmpa.l a0,a2
        beq M4EnFindNext
        cmp.w 46(a2),d4
        bne M4EnFindNext
        bsr M4EnDistXZ
        tst.w d0
        bmi M4EnFindNext
        move.w d0,d1
        sub.w d2,d1
        bpl M4EnFindNext
        move.w d0,d2
        movea.l a2,a3
        bra M4EnFindNext
M4EnFindDone:
        movea.l a3,a2
        movem.l (sp)+,d0-d3/a3
        rts
; zaco3_strat 0A:80AB: chase the pillar (>>4); within 1300 fire every 8th
; tick (sbyte1 shots) then circle. No addplayerZ.
M4Zaco3Strat:
        move.w X_ALPTR(a0),d0
        bne M4Zaco3Target
        move.b 12(a0),d0
        move.b #$e0,d1
        moveq #3,d2
        bsr M4EnChase8
        move.b d0,12(a0)
        bra M4Zaco3Mover
M4Zaco3Target:
        movea.w d0,a2
        bsr M4EnPitchTo
        move.b d0,d1
        move.b 12(a0),d0
        moveq #4,d2
        bsr M4EnChase8
        move.b d0,12(a0)
        bsr M4EnYawTo
        move.b d0,d1
        move.b 13(a0),d0
        bsr M4EnChase8
        move.b d0,13(a0)
        bsr M4EnDistXZ
        subi.w #1300,d0
        bpl M4Zaco3Mover
        move.w M4_LV_GAMEFRAME,d0
        andi.w #7,d0
        bne M4Zaco3Mover
        tst.b 36(a0)
        beq M4Zaco3CircleInit
        subq.b #1,36(a0)
        bsr M4ZacosFire
M4Zaco3Mover:
        moveq #40,d0
        moveq #2,d1
        bsr M4EnSpeedTo
        bsr M4EnGen3d
        bsr M4EnMove
        moveq #0,d0
        rts
; 0A:81CC / 81E1: 30 ticks circling the pillar, sinking toward y -200.
; al_ptr 0 (pillar removed) reads DP 0 in the original: the port keeps the
; yaw (documented decision).
M4Zaco3CircleInit:
        move.l #M4Zaco3Circle,32(a0)
        move.b #30,36(a0)
        clr.b 12(a0)
M4Zaco3Circle:
        move.w X_ALPTR(a0),d0
        beq M4Zaco3CircleNoYaw
        movea.w d0,a2
        bsr M4EnYawTo
        move.b d0,d1
        move.b 13(a0),d0
        moveq #4,d2
        bsr M4EnChase8
        move.b d0,13(a0)
M4Zaco3CircleNoYaw:
        move.b 12(a0),d0
        moveq #0,d1
        moveq #2,d2
        bsr M4EnChase8
        move.b d0,12(a0)
        subq.b #1,36(a0)
        beq M4Zaco3FlyInit
        move.w 2(a0),d0
        move.w #-200,d1
        cmpi.b #3,X_SBYTE3(a0)
        bne M4Zaco3Sink
        moveq #-60,d1
M4Zaco3Sink:
        moveq #1,d2
        jsr M4LpAchase
        move.w d0,2(a0)
        moveq #30,d0
        moveq #2,d1
        bsr M4EnSpeedTo
        bsr M4EnGen3d
        bsr M4EnMove
        moveq #0,d0
        rts
; 0A:8287 flyaway: turn away to the side of the player, climb, leave.
M4Zaco3FlyInit:
        move.l #M4Zaco3Fly,32(a0)
M4Zaco3Fly:
        move.b #$1e,d1
        tst.w X_ALPTR(a0)
        beq M4Zaco3FlyYaw
        btst #AF_LEFTPL,51(a0)
        beq M4Zaco3FlyYaw
        move.b #$e2,d1
M4Zaco3FlyYaw:
        move.b 13(a0),d0
        moveq #4,d2
        bsr M4EnChase8
        move.b d0,13(a0)
        move.b 12(a0),d0
        move.b #$e2,d1
        moveq #2,d2
        bsr M4EnChase8
        move.b d0,12(a0)
        moveq #20,d0
        moveq #2,d1
        bsr M4EnSpeedTo
        bsr M4EnGen3d
        bsr M4EnMove
        bsr M4EnAddPZ
        subq.b #1,37(a0)
        beq M4EnRemoveSelf
        moveq #0,d0
        rts
; zaco3die 0A:8304 (HP 0): medium explosion, then falls (expstrat 0A:8319)
; with smoke every 2nd tick until y >= -100.
M4Zaco3Die:
        move.l #M4Zaco3Fall,X_EXP(a0)
        bsr M4FxMedium
M4Zaco3Fall:
        btst #0,M4_LV_GAMEFRAME+1
        bne M4Zaco3FallNoSmoke
        bsr M4FxSmoke
M4Zaco3FallNoSmoke:
        moveq #40,d0
        moveq #1,d1
        bsr M4EnSpeedTo
        move.w 2(a0),d0
        addi.w #100,d0
        bpl M4Zaco3GoInit
        move.b 12(a0),d0
        subi.b #$20,d0
        beq M4Zaco3FallPitch
        bpl M4Zaco3FallVec
M4Zaco3FallPitch:
        addq.b #4,12(a0)
M4Zaco3FallVec:
        bsr M4EnGen3d
        addq.b #4,14(a0)
        bsr M4EnAddPZ
        bsr M4EnAddPZ
        bsr M4EnMove
        moveq #0,d0
        rts
; 0A:8375 / 8397: indestructible, any contact explodes it; flies on.
M4Zaco3GoInit:
        move.l #M4Zaco3Go,32(a0)
        move.l #M4LevelExplode,X_COLL(a0)
        move.b #$ff,38(a0)
M4Zaco3Go:
        moveq #60,d0
        moveq #1,d1
        bsr M4EnSpeedTo
        addq.b #4,14(a0)
        move.w M4_LV_GAMEFRAME,d0
        andi.w #3,d0
        bne M4Zaco3GoAim
        bsr M4FxSmoke
        beq M4Zaco3GoAim
        move.w #40,10(a2)
M4Zaco3GoAim:
        movea.l a1,a2
        bsr M4EnZD
        move.w d0,d1
        subi.w #3000,d1
        bmi M4Zaco3GoNear
        clr.b 12(a0)
        move.b #$80,13(a0)
        bsr M4EnGen3d
        bra M4Zaco3GoMove
M4Zaco3GoNear:
        subi.w #400,d0
        bmi M4Zaco3GoMove
        bsr M4EnPitchTo
        move.b d0,d1
        move.b 12(a0),d0
        moveq #2,d2
        bsr M4EnChase8
        move.b d0,12(a0)
        bsr M4EnYawTo
        move.b d0,d1
        move.b 13(a0),d0
        bsr M4EnChase8
        move.b d0,13(a0)
        bsr M4EnGen3d
M4Zaco3GoMove:
        bsr M4EnAddPZ
        bsr M4EnMove
        moveq #0,d0
        rts

; pillar3 09:8AA4: falls toward the player's side when the player passes
; within 500 (distXZ), HP < 4 or its base (HF2) is hit.
M4StratPillar3:
        move.l #M4Pillar3Tick,32(a0)
        move.l #M4LcHitFlash,X_COLL(a0)
        move.l #M4Pillar3Explode,X_EXP(a0)
        move.b #8,38(a0)
        move.b #8,39(a0)
M4Pillar3Tick:
        movea.l a1,a2
        bsr M4EnDistXZ
        subi.w #500,d0
        bmi M4Pillar3FallInit
        move.b 38(a0),d0
        subq.b #4,d0
        bmi M4Pillar3FallInit
        btst #1,20(a0)
        bne M4Pillar3FallInit
        moveq #0,d0
        rts
M4Pillar3FallInit:
        move.l #M4Pillar3Fall,32(a0)
        bset #SF_NOHITAFFECT,49(a0)
        bset #F2_SHADOW,48(a0)
        move.b #4,36(a0)
        btst #AF_LEFTPL,51(a0)
        beq M4Pillar3Side
        move.b #-4,36(a0)
M4Pillar3Side:
        move.b #16,37(a0)
        move.l #M4_FX_BALL,d0 ;descriptor index may exceed 127 ;bouncyball, exploding now at the base
        bsr M4EnCreate
        beq M4EnKeep
        move.l (a0),(a2)
        move.w 4(a0),d0
        subi.w #10,d0
        move.w d0,4(a2)
        move.l #M4LevelExplode,32(a2)
        move.l #M4LevelExplode,X_COLL(a2)
        move.l #M4LevelExplode,X_EXP(a2)
        bset #SF_COLLDISABLE,49(a2)
        clr.b 38(a2)
        bra M4EnKeep
; 09:8B90: rotz += sbyte1 for 16 ticks, then stays (09:8BA6).
M4Pillar3Fall:
        move.b 36(a0),d0
        add.b d0,14(a0)
        subq.b #1,37(a0)
        bne M4EnKeep
        bclr #SF_NOHITAFFECT,49(a0)
        bclr #F2_SHADOW,48(a0)
        clr.l 32(a0)
        bra M4EnKeep
; pillar3explode_Istrat 06:FAAC: eight staggered sprite-only medium
; explosions along the axis (offset rotate_8(0,-40,rotz) per step), then
; the pillar stays 7 ticks without collision (delayremove).
M4Pillar3Explode:
        clr.w X_SWORD2(a0)
M4Pillar3ExplodeBody: ;06:FAB5 (tow_0 enters with sword2 = 160)
        moveq #0,d3
        moveq #-40,d4
        move.b 14(a0),d5
        jsr M4WeaponRotatePair
        ext.w d3
        ext.w d4
        moveq #0,d6 ;o.x
        moveq #0,d7 ;o.y
        moveq #8,d2
M4Pillar3ExpNext:
        bsr M4FxMedium
        beq M4Pillar3ExpStep
        bclr #F2_RELEXPLODE,48(a2)
        bset #F2_NOPOLYEXP,48(a2)
        add.w d6,(a2)
        add.w d7,2(a2)
        move.w X_SWORD2(a0),d0
        add.w d0,2(a2)
        move.l #M4FxDelayInit,32(a2)
        subi.w #10,4(a2)
        moveq #8,d0
        sub.b d2,d0
        move.b d0,19(a2)
M4Pillar3ExpStep:
        add.w d3,d6
        add.w d4,d7
        subq.w #1,d2
        bne M4Pillar3ExpNext
        move.b #7,19(a0)
        bra M4FxDelayRemove

; gate3 0A:E817: spinning shield ring (+20), collected once.
M4StratGate3:
        move.l #M4Gate3Tick,32(a0)
        bset #SF_COLLDISABLE,49(a0)
        bset #F2_SHADOW,48(a0)
        move.b #$80,18(a0)
M4Gate3Tick:
        addq.b #8,12(a0)
        addq.b #6,13(a0)
        addi.b #12,14(a0)
        movea.l a1,a2
        bsr M4EnZD
        subi.w #200,d0
        bpl M4EnKeep
        bsr M4EnDistXY
        tst.w d0
        bmi M4EnKeep
        subi.w #100,d0
        bpl M4EnKeep
        bset #F2_SFLAG1,48(a0)
        bne M4Gate3Taken
        tst.b M4_LP_BODYHP
        beq M4EnKeep
        moveq #20,d0
        bsr M4EnShieldAdd
        M4PlaySfx $0f
M4Gate3Taken:
        move.b #4|$80,18(a0)
        bra M4EnKeep

; gate 09:97DA: checkpoint ring. The Istrat keeps the map position
; (maprestarttemp); passing it gives +20 shield and makes that position
; the restart point (set_restart_position_l 09:98CB, reduced to the map
; index and call stack).
M4StratGate:
        move.l #M4GateTick,32(a0)
        bsr M4LvZeroPtrs
        move.b #1,38(a0)
        clr.b 39(a0)
        move.b #$80,18(a0)
        bset #SF_COLLDISABLE,49(a0)
        bset #F2_SHADOW,48(a0)
        move.w TEXT_MAP_CONTEXT,d0 ;09:9809 mapptr $16FF -> $1741, mapbank $1FF6 -> $1FF8:
        cmpi.b #5,TEXT_MAP_CONTEXT+19 ;packed as M4LvPackIndex (bank 05 in bit 15;
        bne.s M4GateBank0D ;Macbeth's gate is at 05:BB6C)
        ori.w #$8000,d0
M4GateBank0D:
        move.w d0,M4_LV_GATETEMP
        move.w M4_LV_STACK,M4_LV_GATETEMP+2
        movem.l M4_LV_CALLS,d0-d3
        movem.l d0-d3,M4_LV_GATETEMP+4
        moveq #0,d0 ;Istrat ends with rtl (09:9819): first tick next pass
        rts
M4GateTick:
        movea.l a1,a2
        bsr M4EnZD
        subi.w #200,d0
        bpl M4GateNorm
        bsr M4EnDistXY
        tst.w d0
        bmi M4GateNorm
        subi.w #100,d0
        bpl M4GateNorm
        tst.b M4_LP_BODYHP
        beq M4GateNorm
        moveq #20,d0
        bsr M4EnShieldAdd
        move.l #M4GatePassed,32(a0)
        M4PlaySfx $0f
        move.b #4|$80,18(a0)
        move.w M4_LV_GATETEMP,M4_LV_RESTART
        move.w M4_LV_GATETEMP+2,M4_LV_RSTACK
        movem.l M4_LV_GATETEMP+4,d0-d3
        movem.l d0-d3,M4_LV_RSTACK+2
; 09:9884: spin up and cycle colours 5..15.
M4GatePassed:
        move.b 36(a0),d0
        add.b d0,14(a0)
        addq.b #1,36(a0)
        move.b 18(a0),d0
        andi.b #$7f,d0
        addq.b #1,d0
        cmpi.b #16,d0
        blo M4GateColour
        subi.b #16-5,d0
M4GateColour:
        ori.b #$80,d0
        move.b d0,18(a0)
        bra M4EnKeep
M4GateNorm:
        move.b 18(a0),d0
        addq.b #1,d0
        andi.b #3,d0
        ori.b #$80,d0
        move.b d0,18(a0)
        bra M4EnKeep

; gate2 0A:E8B7: small ring (+5) left by a special enemy; pulled back into
; the flight box, follows the player minus 50 per tick.
M4StratGate2:
        move.l #M4Gate2Tick,32(a0)
        bset #SF_COLLDISABLE,49(a0)
        bset #F2_SHADOW,48(a0)
M4Gate2Tick:
        move.w (a0),d0
        cmp.w M4_LP_MAXX,d0
        bgt M4Gate2Pull
        cmp.w M4_LP_MINX,d0
        blt M4Gate2Pull
        move.w 2(a0),d0
        cmp.w M4_LP_MAXY,d0
        bgt M4Gate2Pull
        cmp.w M4_LP_MINY,d0
        bgt M4Gate2Ground
M4Gate2Pull:
        move.w (a0),d0
        moveq #0,d1
        moveq #4,d2
        jsr M4LpAchase
        move.w d0,(a0)
        move.w 2(a0),d0
        move.w M4_LP_VIEWCY,d1
        jsr M4LpAchase
        move.w d0,2(a0)
M4Gate2Ground:
        btst #3,M4_LP_FLYMODE
        beq M4Gate2Spin
        move.w 2(a0),d0
        addi.w #60,d0
        bmi M4Gate2Spin
        move.w #-60,2(a0)
M4Gate2Spin:
        addq.b #8,12(a0)
        addq.b #6,13(a0)
        addi.b #12,14(a0)
        btst #F2_SFLAG1,48(a0)
        beq M4Gate2Check
        move.b #$80,18(a0)
        bra M4Gate2End
M4Gate2Check:
        move.b #4|$80,18(a0)
        movea.l a1,a2
        bsr M4EnZD
        subi.w #60,d0
        bpl M4Gate2End
        bsr M4EnDistXY
        subi.w #60,d0
        bpl M4Gate2End
        tst.b M4_LP_BODYHP
        beq M4Gate2End
        moveq #5,d0
        bsr M4EnShieldAdd
        M4PlaySfx $0f
        bset #F2_SFLAG1,48(a0)
        move.b #$80,18(a0)
M4Gate2End:
        bsr M4EnAddPZ
        subi.w #50,4(a0)
        bra M4EnKeep

; item5 08:D556: Nova bomb pickup (max 5).
M4StratItem5:
        move.l #M4Item5Tick,32(a0)
        bsr M4LvZeroPtrs
        bset #SF_COLLDISABLE,49(a0)
M4Item5Tick:
        moveq #0,d7
        btst #7,M4_LP_PSF2
        beq M4Item5Alive
        moveq #1,d7
M4Item5Alive:
        tst.b 36(a0)
        bne M4Item5Still
        addi.w #20,4(a0)
M4Item5Still:
        bsr M4ItemNear
        bne M4ItemDone
        move.w M4_LP_SPECWEP,d0
        subq.w #5,d0
        bpl M4Item5Full
        addq.w #1,M4_LP_SPECWEP
        move.b #30,M4_LP_SPECFLASH ;08:D5BC (D6)
M4Item5Full:
        M4PlaySfx $18 ;Nova bomb pickup, 08:D5BC
        bra M4ItemCollected
M4ItemDone:
        move.l d7,d0
        rts
; ZD < 120 and distXY < 60 -> Z set.
M4ItemNear:
        movea.l a1,a2
        bsr M4EnZD
        subi.w #120,d0
        bpl M4ItemFar
        bsr M4EnDistXY
        subi.w #60,d0
        bpl M4ItemFar
        moveq #0,d0
        rts
M4ItemFar:
        moveq #1,d0
        rts
; collected 08:E25B / E27D: follows the player 20 ticks. The ship
; silhouette (player shape table 06:80D5 entries 8..14) is not drawn yet.
M4ItemCollected:
        move.b #20,19(a0)
        bset #SF_COLLDISABLE,49(a0)
        clr.b 21(a0)
        move.l #M4ItemCollectedTick,32(a0)
M4ItemCollectedTick:
        move.l (a1),(a0)
        move.w 4(a1),4(a0)
        move.w 12(a1),12(a0)
        move.b 14(a1),14(a0)
        btst #7,M4_LP_PSF2
        bne M4EnRemoveSelf
        subq.b #1,19(a0)
        beq M4EnRemoveSelf
        moveq #0,d0
        rts

; item7 08:DDEC: double laser, or a repair wing when a wing is broken.
M4StratItem7:
        move.l #M4Item7Tick,32(a0)
        bsr M4LvZeroPtrs
        bset #SF_COLLDISABLE,49(a0)
M4Item7Tick:
        moveq #0,d7
        btst #7,M4_LP_PSF2
        beq M4Item7Alive
        moveq #1,d7
M4Item7Alive:
        tst.b 36(a0)
        bne M4Item7Still
        addi.w #20,4(a0)
M4Item7Still:
        move.w M4_LP_MINY,d0
        addi.w #50,d0
        move.w 2(a0),d1
        sub.w d0,d1
        bpl M4Item7Rise
        addq.w #3,2(a0)
M4Item7Rise:
        addq.b #4,13(a0)
        addq.b #4,14(a0)
        bsr M4ItemNear
        bne M4ItemDone
        move.b M4_LP_PSF,d0
        andi.b #$18,d0
        beq M4Item7Laser
        move.l #M4_SH_ITEM_WING,d0 ;descriptor index may exceed 127
        bsr M4EnCreate
        beq M4ItemCollected
        move.l #M4RepairWingInit,32(a2)
        M4PlaySfx $17
        bra M4ItemCollected
M4Item7Laser:
        bsr M4EnWingsInit
        btst #0,M4_LP_PSF2
        beq M4Item7Double
        bset #4,M4_LP_PSF3 ;beamball
        M4PlaySfx $15
        bra M4ItemCollected
M4Item7Double:
        bset #0,M4_LP_PSF2 ;double laser
        M4PlaySfx $15
        bra M4ItemCollected
; pLWing_Istrat 0B:AFF5 / pRWing_Istrat 0B:B29B: wings HP 5.
M4EnWingsInit:
        move.b #5,M4_LP_LWHP
        move.b #1,M4_LP_LWCC
        move.b #5,M4_LP_RWHP
        move.b #1,M4_LP_RWCC
        rts
; Repair wing 08:E0C7: from (x+500, y, z-200) toward the player; sticks to
; it within ZD 500, repairs both wings when it reaches it.
M4RepairWingInit: ;player_pos $150F/$1511/$1513 (08:E0E0..E10A)
        move.w M4_SC_PPOSX,d0
        addi.w #500,d0
        move.w d0,(a0)
        move.w M4_SC_PPOSY,2(a0)
        move.w M4_LP_POSZ,d0
        subi.w #200,d0
        move.w d0,4(a0)
        clr.l 6(a0)
        move.w #30,10(a0)
        move.b #$40,14(a0)
        bclr #3,45(a0)
        bset #SF_COLLDISABLE,49(a0)
        move.b #30,36(a0)
        move.l #M4RepairWingTick,32(a0)
M4RepairWingTick:
        bsr M4EnAddPZ
        move.w 10(a0),d0
        add.w d0,4(a0)
        moveq #3,d2
        tst.b 36(a0)
        beq M4RepairSlow
        subq.b #1,36(a0)
        bra M4RepairChase
M4RepairSlow:
        moveq #1,d2
M4RepairChase: ;08:E158/E169 player_pos
        move.w (a0),d0
        move.w M4_SC_PPOSX,d1
        jsr M4LpAchase
        move.w d0,(a0)
        move.w 2(a0),d0
        move.w M4_SC_PPOSY,d1
        jsr M4LpAchase
        move.w d0,2(a0)
        tst.b 36(a0)
        bne M4RepairReach
        move.b 14(a0),d0
        move.b 14(a1),d1
        moveq #1,d2
        bsr M4EnChase8
        move.b d0,14(a0)
        movea.l a1,a2
        bsr M4EnZD
        subi.w #500,d0
        bpl M4RepairReach
        move.w M4_SC_PPOSX,(a0) ;08:E186/E197
        move.w M4_SC_PPOSY,2(a0)
        move.b 14(a1),14(a0)
        move.w #-40,10(a0)
        bset #3,45(a0)
M4RepairReach:
        movea.l a1,a2
        bsr M4EnDistXY
        subi.w #20,d0
        bpl M4EnKeep
        move.w 4(a1),d0
        sub.w 4(a0),d0
        bpl M4RepairDone
        bsr M4EnZD
        subi.w #30,d0
        bpl M4EnKeep
M4RepairDone:
        bsr M4EnWingsInit
        andi.b #$e1,M4_LP_PSF
        move.w M4_SC_PPOSX,(a0) ;08:E1CA/E1D3
        move.w M4_SC_PPOSY,2(a0)
        move.w 4(a1),4(a0)
        bra M4ItemCollected

; bomwing 08:D414: flat 2D flight (gen2d), Hplasma at the player.
M4StratBomwing:
        move.b #4,38(a0)
        move.b #8,39(a0)
        move.b #20,15(a0)
        move.b #$20,13(a0)
M4BomwingInit:
        move.l #M4BomwingA,32(a0)
        move.l #M4LcHitFlash,X_COLL(a0)
        move.l #M4BomwingDie,X_EXP(a0)
        move.b #20,36(a0)
; 08:D44F: 20 ticks: (vx, vz) = gen2d(vel, roty), pos += v, z += 35.
M4BomwingA:
        tst.b 36(a0)
        beq M4BomwingBInit
        subq.b #1,36(a0)
        bsr M4EnGen2d
        bra M4BomwingStep
M4BomwingBInit:
        move.l #M4BomwingB,32(a0)
        move.b #42,36(a0)
; 08:D491: turns (+2/tick) and fires every 8th tick with roty in $80..$DF.
M4BomwingB:
        movea.l a1,a2
        bsr M4EnZD
        subi.w #3000,d0
        bpl M4BomwingTurn
        cmpi.b #$80,13(a0)
        blo M4BomwingTurn
        cmpi.b #$df,13(a0)
        bhi M4BomwingTurn
        move.w M4_LV_GAMEFRAME,d0
        andi.w #7,d0
        bne M4BomwingTurn
        moveq #2,d0
        moveq #0,d3
        moveq #0,d4
        moveq #0,d5
        moveq #-16,d6
        moveq #0,d7
        suba.l a3,a3
        bsr M4EnFire
        move.l a2,d0
        beq M4BomwingTurn
        move.w a1,X_ALPTR(a2)
M4BomwingTurn:
        addq.b #2,13(a0)
        tst.b 36(a0)
        beq M4BomwingInit
        subq.b #1,36(a0)
        bra.s M4BomwingZ ;08:D51A brl $D473: state B only adds 35 to z (no pos += v)
M4BomwingStep:
        bsr M4EnMove
M4BomwingZ:
        addi.w #35,4(a0)
        moveq #0,d0
        rts
; gen2d 1F:C177: i = (1 - roty) & 255, vx = mul(vel, sin8[i]), vz =
; mul(vel, cos8[i]) with the 8x8 multiplier rule; vy untouched.
M4EnGen2d:
        movem.l d1-d3/a3,-(sp)
        lea M4IntroShipSine,a3
        moveq #1,d3
        sub.b 13(a0),d3
        andi.w #255,d3
        move.b 15(a0),d0
        move.b (a3,d3.w),d1
        jsr M4WeaponByteMul ;clobbers d1/d2
        ext.w d0
        move.w d0,6(a0)
        move.b 15(a0),d0
        move.b 64(a3,d3.w),d1
        jsr M4WeaponByteMul
        ext.w d0
        move.w d0,10(a0)
        movem.l (sp)+,d1-d3/a3
        rts
; 08:D51D: drops item5 (moving, sbyte1 0) 20 above, then explodes.
M4BomwingDie:
        move.l #M4_SH_ITEM_5,d0 ;descriptor index may exceed 127
        bsr M4EnCreate
        beq M4BomwingDieExplode
        move.l #M4StratItem5,32(a2)
        move.l (a0),(a2)
        move.w 4(a0),4(a2)
        subi.w #20,2(a2)
M4BomwingDieExplode:
        bra M4LevelExplode

; ---------------------------------------------------------------------
; Nova bomb (build/research/corneria-missing.md section 1; oracle
; tools/nuke-oracle.py). fire_weapon($2A) 06:A782 + gen_weapon 06:B552:
; NUKE AF41 (ssprite), HP 2, AP 8, vel 50, count 28, collflags weapon |
; laser | friend, al_type 2, sbyte4 2, mutual immunity with the player;
; position = player + rot(0,0,20)*4, rotation = player's with rotz 0.
; Linked right behind the player: its Istrat runs in this same traversal.
M4LevelFireBomb:
        tst.b M4_LP_BOMBREQ
        beq.w M4NkFireDone
        clr.b M4_LP_BOMBREQ
        M4PlaySfx $31 ;A-button launch, explosion $30 is at nuke Istrat
        movem.l d0-d7/a0-a3,-(sp)
        lea LV_PLAYER,a2
        jsr M4LevelAlloc
        move.l a0,d0
        beq.w M4NkFireFull
        moveq #0,d3
        moveq #0,d4
        moveq #20,d5 ;weaponpos (0,0,$14)
        jsr M4WeaponOffset
        add.w (a2),d3
        add.w 2(a2),d4
        add.w 4(a2),d5
        move.w d3,(a0)
        move.w d4,2(a0)
        move.w d5,4(a0)
        move.b 12(a2),12(a0)
        move.b 13(a2),13(a0)
        clr.b 14(a0)
        move.b 12(a2),36(a0) ;sbyte1/2 = rotx/roty
        move.b 13(a2),37(a0)
        move.b 15(a2),54(a0) ;sbyte3 = player speed
        move.b #2,45(a0) ;al_type: no zremove
        ori.b #CF_LASER|CF_FRIEND|$02,44(a0)
        move.b #2,38(a0)
        move.b #8,39(a0)
        move.b #50,15(a0)
        move.b #28,19(a0)
        move.b #2,X_SBYTE4(a0)
        move.w a0,28(a2) ;immuneptr crossed (+$19)
        move.w a2,28(a0)
        move.l #M4_FX_NUKE,d0 ;descriptor index may exceed 127
        jsr M4LevelSetShape
        bset #F2_SPRITE,48(a0)
        move.l #M4StratNukeInit,32(a0)
M4NkFireFull:
        movem.l (sp)+,d0-d7/a0-a3
M4NkFireDone:
        rts

; nuke_Istrat 06:A23F: weapcollide, expstrat nukeexp; v = 2*gen3d(50) +
; gen3d(sbyte3) along (rotx, roty); then rotx 0, roty $80. No move now.
M4StratNukeInit:
        move.l #M4WpCollide,X_COLL(a0)
        move.l #M4NukeExpInit,X_EXP(a0)
        moveq #0,d0
        move.b 54(a0),d0
        jsr M4LevelGen3dVecs
        movem.w 6(a0),d4-d6
        moveq #0,d0
        move.b 15(a0),d0
        jsr M4LevelGen3dVecs
        movem.w 6(a0),d1-d3
        add.w d1,d1
        add.w d2,d2
        add.w d3,d3
        add.w d4,d1
        add.w d5,d2
        add.w d6,d3
        movem.w d1-d3,6(a0)
        clr.b 12(a0)
        move.b #$80,13(a0)
        move.l #M4StratNukeTick,32(a0)
        moveq #0,d0
        rts

; nuke_strat 06:A2B2: player dead -> removed (deferred, the tick goes on);
; nofire -> removenuke 06:A320 (bomb back, specialdelay 1); pos += v;
; count -> 0 detonates; planet fall vy += 2 (playerflymode bit 0); a new
; A press detonates; missboundchkexp 06:901A (Corneria: y >= 0, without
; the boss-dead cut of 06:90DB).
M4StratNukeTick:
        moveq #0,d7
        btst #7,M4_LP_PSF2
        beq.s M4NkAlive
        moveq #1,d7
M4NkAlive:
        btst #6,M4_LP_PSF
        beq.s M4NkFly
        addq.w #1,M4_LP_SPECWEP
        move.b #1,M4_LP_SPECDELAY
        moveq #1,d0
        rts
M4NkFly:
        bsr M4EnMove
        subq.b #1,19(a0)
        bne.s M4NkCount
        bsr M4EnKill
M4NkCount:
        btst #0,M4_LP_FLYMODE
        beq.s M4NkNoFall
        addq.w #2,8(a0)
M4NkNoFall:
        btst #J_A,M4_LP_JOY+1
        beq.s M4NkNoPress
        btst #J_A,M4_LP_LASTJOY+1
        bne.s M4NkNoPress
        bsr M4EnKill
M4NkNoPress:
        btst #F2_SFLAG1,48(a0)
        bne.s M4NkDone
        tst.w 2(a0)
        bmi.s M4NkDone
        bsr M4EnKill
M4NkDone:
        move.l d7,d0
        rts

; nukeexp_Istrat 06:A330 (HP 0): sword1 200, nullshape, a medium explosion
; that explodes in this same traversal (BE04 debris + B11D sprite), the
; screen circle (circleanim $39 smartbomb, M4NukeCircleStart).
M4NukeExpInit:
        M4PlaySfx $30 ;06:A301 nukeexp_Istrat
        move.w #200,40(a0)
        move.l #M4NukeExpTick,X_EXP(a0)
        move.w #$ffff,d0
        jsr M4LevelSetShape
        bclr #F2_SPRITE,48(a0)
        bsr M4FxMedium
        jsr M4NukeCircleStart
        moveq #0,d0
        rts

; nukeexp_strat 06:A371: sword1 >= 7000 -> removed (D+35); z += pviewvelz;
; player dead: no growth; ring [sword1-200, sword1): every object of allst
; (from the head, not itself) with xzdiffs 1F:D0AB in the ring, not
; nohitaffect/colldisable, afFrontPl and HP < $80 -> HP - 8 (floor 0),
; hitflash, nuked; sword1 += 200. realobj (sflags3 $08) is not modelled:
; every effect object of the port is colldisable.
M4NukeExpTick:
        cmpi.w #7000,40(a0)
        bge M4EnRemoveSelf
        bsr M4EnAddPZ
        btst #7,M4_LP_PSF2
        bne M4EnKeep
        move.w 40(a0),d5 ;hi
        move.w d5,d4
        subi.w #200,d4 ;lo
        move.w M4_LV_HEAD,d6
M4NkRing:
        tst.w d6
        beq.s M4NkRingDone
        movea.w d6,a2
        move.w X_NEXT(a2),d6
        cmpa.l a0,a2
        beq.s M4NkRing
        cmpa.w #LV_PLAYER&$ffff,a2 ;player: HP $FF, parts colldisable
        beq.s M4NkRing
        bsr M4EnDistXZ
        move.w d0,d1
        sub.w d5,d1
        bpl.s M4NkRing ;N(r - hi) must be 1
        sub.w d4,d0
        bmi.s M4NkRing ;N(r - lo) must be 0
        btst #SF_NOHITAFFECT,49(a2)
        bne.s M4NkRing
        btst #SF_COLLDISABLE,49(a2)
        bne.s M4NkRing
        btst #AF_FRONTPL,51(a2)
        beq.s M4NkRing
        move.b 38(a2),d0
        bmi.s M4NkRing
        subq.b #8,d0
        bpl.s M4NkHp
        moveq #0,d0
M4NkHp:
        move.b d0,38(a2)
        bset #SF_HITFLASH,49(a2)
        bset #2,31(a2)
        bset #4,45(a2) ;atnuked
        bra.s M4NkRing
M4NkRingDone:
        addi.w #200,40(a0)
        moveq #0,d0
        rts

; nukeexp_Istrat: circleobj $16AB = the explosion, circleanim $16AD = $39.
; A later circleanim replaces it (02:DD49). Timing only (M4ScWipeTick).
M4NukeCircleStart:
        move.w a0,M4_SC_CIRCLEOBJ
        move.w #$39,M4_SC_CIRCLE
        clr.w M4_SC_WIPETICK
        rts

; ---------------------------------------------------------------------
; Boost flame (corneria-missing.md section B): 0B:D937 / 0B:81D5 / 07:86EE
; / 07:80B5 / 06:C128 boostobj = the boosting object (a0), make_obj(B219)
; with boost_Istrat 06:8671, invisible until its Istrat runs (linked right
; behind its creator: this same traversal). Registers preserved.
M4LevelBoostFlame:
        movem.l d0/a0,-(sp)
        move.w a0,M4_LP_BOOSTOBJ
        jsr M4LevelAlloc
        move.l a0,d0
        beq.s M4BfMakeDone
        move.l #M4_FX_BOOST,d0 ;descriptor index may exceed 127
        jsr M4LevelSetShape
        bset #SF_INVISIBLE,49(a0)
        move.l #M4StratBoostInit,32(a0)
M4BfMakeDone:
        movem.l (sp)+,d0/a0
        rts
; boost_Istrat 06:8671: life 10, colldisable, ssprite, depthoffset 0, tx =
; sbyte1 (0), visible, no zremove; falls into boost_strat 06:86AA: tx - 1;
; pos = boostobj + (0, 0, boostZoff -30) rotated (y,z) by rotx then (x,z)
; by -roty (1F:CAFB, 1F:C97B, no rotz); life - 1, 0 -> removed (deferred).
M4StratBoostInit:
        move.b #10,19(a0)
        bset #SF_COLLDISABLE,49(a0)
        bset #F2_SPRITE,48(a0)
        clr.b X_DEPTHOFF(a0)
        clr.b X_TX(a0)
        bclr #SF_INVISIBLE,49(a0)
        bclr #3,45(a0) ;no zremove
        move.l #M4StratBoostTick,32(a0)
M4StratBoostTick:
        subq.b #1,X_TX(a0)
        move.w M4_LP_BOOSTOBJ,d0 ;every flame follows the last boostobj (06:86AD)
        beq M4EnRemoveSelf
        movea.w d0,a2
        moveq #0,d3 ;y
        moveq #-30,d4 ;z = boostZoff $1570 (playermove_init 0B:D2CE)
        move.b 12(a2),d5
        jsr M4WeaponRotatePair ;(y,z) by rotx
        move.b d3,d6 ;y
        moveq #0,d3 ;x
        move.b 13(a2),d5
        neg.b d5
        jsr M4WeaponRotatePair ;(x,z) by -roty
        ext.w d3
        ext.w d4
        ext.w d6
        add.w (a2),d3
        add.w 2(a2),d6
        add.w 4(a2),d4
        move.w d3,(a0)
        move.w d6,2(a0)
        move.w d4,4(a0)
        subq.b #1,19(a0)
        beq M4EnRemoveSelf
        moveq #0,d0
        rts

        include 'level/level_weapons.asm'

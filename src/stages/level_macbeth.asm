; Stage unit: Macbeth (0D:E81C, route 3 stage 5: interior with the train).
; Strategies (table searched by M4LevelFindStrategy, level_objects.asm),
; helpers and effects of this stage. Stage data: tools/stages/macbeth.py.
; Every routine was re-read in the ROM bytes (tools/dis65816.py,
; build/agent-macbeth/dis/) and is compared tick by tick with the ROM by
; build/agent-macbeth/macbeth-compare.py (build/agent-macbeth/MACBETH.md).
; Conventions of level_objects.asm / level_enemies.asm: a0 object, a1
; player; d0 = 0 keep / nonzero deferred removal (1F:D501). "d < K" is the
; N bit of the 16-bit difference. ROM sflags2 ($1E): sflag1 $10 / sflag2
; $20 = F2_SFLAG1 / F2_SFLAG2 (48(a0)); sflag3 $40 / sflag4 $80 = bits 6/7
; of X2_FL2 (same bits as the ROM byte). Sounds (03:B7E5 trigse,
; set_sound2) are not ported. Shapes are found by ROM header
; (M4LevelShapeIndex).
; RAM: $FF9880..$FF98BF (reserved for this unit).
M4_MACBETH equ $ff9880
M4_MB_CHILDS equ M4_MACBETH+0 ;.b svar_byte5 of boss2 (s_count_childs)
M4_MB_OFF equ M4_MACBETH+2 ;3 .w $151D/$151F/$1521 bossbigoutexplodeoff offset
MB_SF3 equ 6 ;X2_FL2 bit: sflag3 ($1E $40)
MB_SF4 equ 7 ;X2_FL2 bit: sflag4 ($1E $80)

M4StrategiesMacbeth:
        dc.l $0685d9,M4StratMbRockhard ;also Titania (05:807E)
        dc.l $08bf70,M4StratMbTrackcorner
        dc.l $08be2c,M4StratMbTruck
        dc.l $08b7c1,M4StratMbWoods
        dc.l $0ad76b,M4StratMbVolcano
        dc.l $0adac6,M4StratMbFirepillar
        dc.l $06ce18,M4StratMbClshipA ;cl_under friends' ships
        dc.l $06ce75,M4StratMbClshipB
        dc.l $06ced2,M4StratMbClshipC
        dc.l $088bbe,M4StratMbBoss2 ;Spinning top (05:BDE9)
        dc.l 0

; ---------------------------------------------------------------------
; Helpers.

; d1.b = (gameframe + lo8(al1pt)): al1pt = the original-like record address
; $0336 + slot * $36 (M4B1Al1pt, level_boss1.asm), as the other units.
M4MbAl1pt:
        move.l d0,-(sp)
        jsr M4B1Al1pt
        move.w M4_LV_GAMEFRAME,d0
        add.b d0,d1
        move.l (sp)+,d0
        rts

; gen_vecs with the angle d0.b (1F:C177, A = angle, $7E = vel): vx/vz of
; the object's vel at that heading; roty itself is not changed.
M4MbGen2dAngle:
        move.b 13(a0),-(sp)
        move.b d0,13(a0)
        jsr M4EnGen2d
        move.b (sp)+,13(a0)
        rts

; obj2obj_3dangle(a0 -> a2, step 2^d2) 1F:D03E / 1F:D021: rotx =
; Achase8(rotx, pitch toward a2), then roty = Achase8(roty, yaw toward a2).
M4MbFaceObj:
        movem.l d0-d3,-(sp)
        jsr M4EnPitchTo
        move.b d0,d1
        move.b 12(a0),d0
        jsr M4EnChase8
        move.b d0,12(a0)
        jsr M4EnYawTo
        move.b d0,d1
        move.b 13(a0),d0
        jsr M4EnChase8
        move.b d0,13(a0)
        movem.l (sp)+,d0-d3
        rts

; make_obj 1F:D54B (header d0.w) behind a0, Istrat d2.l, at a0's position
; (copy_pos 1F:DAD9) with y += d1.w -> a2 (Z set on failure).
M4MbSpawn:
        movem.l d0-d2,-(sp)
        jsr M4MtCreateHdr
        beq.s M4MbSpawnDone
        move.l d2,32(a2)
        move.l (a0),(a2)
        move.w 4(a0),4(a2)
        add.w d1,2(a2)
        cmpa.w #0,a2
M4MbSpawnDone:
        movem.l (sp)+,d0-d2
        rts

; Vertical bounce (s_falldown_Yvec x,1,#2,#0): vy += 2; y >= 0 -> y = 0
; and vy = -vy / 2 toward zero, 0 when that is -5..-1. d0.w = new vy.
M4MbBounce:
        addq.w #2,8(a0)
        move.w 8(a0),d0
        tst.w 2(a0)
        bmi.s M4MbBounceDone
        clr.w 2(a0)
        neg.w d0
        asr.w #1,d0
        bpl.s M4MbBounceRound
        bcc.s M4MbBounceRound
        addq.w #1,d0
M4MbBounceRound:
        cmpi.w #$fffb,d0
        blo.s M4MbBounceSet
        moveq #0,d0
M4MbBounceSet:
        move.w d0,8(a0)
M4MbBounceDone:
        rts

; ZD(a0, player) -> d0 (abs16, $8000 stays $8000).
M4MbZDPlayer:
        move.l a2,-(sp)
        lea LV_PLAYER,a2
        jsr M4EnZD
        movea.l (sp)+,a2
        rts

; ---------------------------------------------------------------------
; rockhard_Istrat 06:85D9: colltype enemy1, roty $80, HP $FF, AP $14
; (rockhardAP), no strategy (stratptr 0).
M4StratMbRockhard:
        ori.b #CF_ENEMY1,44(a0)
        move.b #$80,13(a0)
        move.b #$ff,38(a0)
        move.b #$14,39(a0)
        clr.l 32(a0)
        moveq #0,d0
        rts

; trackcorner_Istrat 08:BF70: stratptr 0, no coll/exp pointers (1F:D450),
; HP $FF, AP 0. The rail corner the trucks collide with (sbyte1 1 right
; turn, 0 left: map macro tcorner).
M4StratMbTrackcorner:
        clr.l 32(a0)
        jsr M4LvZeroPtrs
        move.b #$ff,38(a0)
        clr.b 39(a0)
        moveq #0,d0
        rts

; truck_Istrat 08:BE2C: strategy BE80, collstrat truckcol 08:BF25, expstrat
; explode 06:F45F, HP 4 AP 8, sbyte1 = roty, vel 30, gen_vecs(sbyte1),
; colltype Zenemy ($01). Returns without running the strategy.
M4StratMbTruck:
        move.l #M4MbTruckTick,32(a0)
        move.l #M4MbTruckColl,X_COLL(a0)
        move.l #M4LevelExplode,X_EXP(a0)
        move.b #4,38(a0)
        move.b #8,39(a0)
        move.b 13(a0),36(a0)
        move.b #30,15(a0)
        move.b 36(a0),d0
        bsr M4MbGen2dAngle
        ori.b #$01,44(a0)
        moveq #0,d0
        rts
; truck_strat 08:BE80: clear sflag1, then truck_norm.
M4MbTruckTick:
        bclr #F2_SFLAG1,48(a0)
        bra.s M4MbTruckNorm
; truck_cont 08:BE89: gen_vecs(sbyte1).
M4MbTruckCont:
        move.b 36(a0),d0
        bsr M4MbGen2dAngle
; truck_norm 08:BE9F: 1000 <= ZD < 3000, gameframe & 15 == 0 and not yet
; sflag2: sflag2, HMISSILE1 ($12) from (0, -27, 25) without angle offsets
; nor target; its al_ptr = the player. Then roty = Achase8_1(roty, sbyte1)
; and pos += v.
M4MbTruckNorm:
        bsr M4MbZDPlayer
        cmpi.w #1000,d0
        bmi.s M4MbTruckTurn
        cmpi.w #3000,d0
        bpl.s M4MbTruckTurn
        moveq #15,d0
        and.w M4_LV_GAMEFRAME,d0
        bne.s M4MbTruckTurn
        btst #F2_SFLAG2,48(a0)
        bne.s M4MbTruckTurn
        bset #F2_SFLAG2,48(a0)
        moveq #M4_WT_HMISSILE1,d0
        moveq #0,d3
        moveq #-27,d4
        moveq #25,d5
        moveq #0,d6
        moveq #0,d7
        suba.l a3,a3
        jsr M4EnFire
        cmpa.w #0,a2
        beq.s M4MbTruckTurn
        move.w #LV_PLAYER&$ffff,X_ALPTR(a2)
M4MbTruckTurn:
        move.b 13(a0),d0
        move.b 36(a0),d1
        moveq #1,d2
        jsr M4EnChase8
        move.b d0,13(a0)
        jsr M4EnMove
        moveq #0,d0
        rts
; truckcol_Istrat 08:BF25: collider not rail_4 (B77C) -> hitflash 06:89A3.
; Else collide = 0; with sflag1 (already turned this pass) -> truck_cont;
; else sflag1, pos = the corner's, sbyte1 -= $40 (corner sbyte1 1: right)
; or += $40, truck_cont. A ground/wall collider (collobj 0) takes the
; hitflash branch (the ROM would read the header of address 0: not
; reached in Macbeth).
M4MbTruckColl:
        jsr M4LcCollider
        move.l a2,d0
        beq.s M4MbTruckHit
        cmpi.w #$ffff,46(a2)
        beq.s M4MbTruckHit
        move.w 46(a2),d0
        lsl.w #5,d0
        lea M4LevelShapeDescriptors,a3
        cmpi.w #$b77c,16(a3,d0.w)
        beq.s M4MbTruckRail
M4MbTruckHit:
        jmp M4LcHitFlash
M4MbTruckRail:
        bclr #SF_COLLIDE,49(a0)
        btst #F2_SFLAG1,48(a0)
        bne M4MbTruckCont
        bset #F2_SFLAG1,48(a0)
        move.l (a2),(a0)
        move.w 4(a2),4(a0)
        cmpi.b #1,36(a2)
        bne.s M4MbTruckLeft
        addi.b #$c0,36(a0)
        bra M4MbTruckCont
M4MbTruckLeft:
        subi.b #$c0,36(a0)
        bra M4MbTruckCont

; ---------------------------------------------------------------------
; woods_Istrat 08:B7C1 (miss_1_2, the missile of the ceiling/floor launcher
; miss_1_1 that the map links through al_ptr): strategy B7F6, collstrat
; hitflash 06:89A3, expstrat woodsexp 08:B935, HP 2 AP 8, colltype Zenemy;
; falls into woods_strat B7F6: waits until ZD(player) < 2100.
M4StratMbWoods:
        move.l #M4MbWoodsWait,32(a0)
        move.l #M4LcHitFlash,X_COLL(a0)
        move.l #M4MbWoodsExp,X_EXP(a0)
        move.b #2,38(a0)
        move.b #8,39(a0)
        ori.b #$01,44(a0)
M4MbWoodsWait:
        bsr M4MbZDPlayer
        cmpi.w #2100,d0
        bmi.s M4MbWoodsGoInit
        moveq #0,d0
        rts
; woodsgo_init 08:B813: strategy B840, expstrat stopexplode 06:F42E, a
; medium explosion (06:EEEE) at it, sbyte1 10 (launch sound $1CE9 = 2 not
; ported). The strategy runs on the next tick.
M4MbWoodsGoInit:
        move.l #M4MbWoodsGo,32(a0)
        move.l #M4WpStopExp,X_EXP(a0)
        jsr M4FxMedium
        move.b #10,36(a0)
        moveq #0,d0
        rts
; woodsgo_strat 08:B840: on (gameframe + al1pt) & 3 == 0 a smoke (06:8EA8)
; with v = (-vx, -vy, -4 vz); rotz += 8; speedto 80 step 1; gen_3dvecs;
; pos += v; addplayerZ. ZD >= 400: --sbyte1 == 0 -> sbyte1 1 and
; obj2obj_3dangle toward the player (step 2^2).
M4MbWoodsGo:
        bsr M4MbAl1pt
        andi.b #3,d1
        bne.s M4MbWoodsNoSmoke
        jsr M4FxSmoke
        beq.s M4MbWoodsNoSmoke
        move.w 6(a0),d0
        neg.w d0
        move.w d0,6(a2)
        move.w 8(a0),d0
        neg.w d0
        move.w d0,8(a2)
        move.w 10(a0),d0
        neg.w d0
        add.w d0,d0
        add.w d0,d0
        move.w d0,10(a2)
M4MbWoodsNoSmoke:
        addq.b #8,14(a0)
        moveq #80,d0
        moveq #1,d1
        jsr M4EnSpeedTo
        jsr M4EnGen3d
        jsr M4EnMove
        jsr M4EnAddPZ
        bsr M4MbZDPlayer
        cmpi.w #400,d0
        bmi.s M4MbWoodsDone
        subq.b #1,36(a0)
        bne.s M4MbWoodsDone
        move.b #1,36(a0)
        lea LV_PLAYER,a2
        moveq #2,d2
        bsr M4MbFaceObj
M4MbWoodsDone:
        moveq #0,d0
        rts
; woodsexp_Istrat 08:B935: remove its launcher (al_ptr, 1F:D540: not the
; running object, so at once), then smarkexplode 06:F046 (level_meteor.asm).
; al_ptr 0 (launcher already gone): nothing to remove.
M4MbWoodsExp:
        move.w X_ALPTR(a0),d0
        beq.s M4MbWoodsExpMark
        movea.w d0,a2
        move.l a0,-(sp)
        movea.l a2,a0
        jsr M4LevelRemove
        movea.l (sp)+,a0
M4MbWoodsExpMark:
        jmp M4MtSmarkExplode

; ---------------------------------------------------------------------
; Volcano and fire pillars (GA2STRAT.ASM). Their particle emitters
; particlefire 06:F96F / particlefiredown 06:F9A6 are drawn by the GSU
; particle code from the partobj flag ($1D $10): not drawn in the port
; (PEND); the objects and their fields are kept.

; volcano_Istrat 0A:D76B: strategy D7C9, no coll/exp pointers, HP $FF AP 8,
; enemy1, roty $80; a particlefire emitter at it, 120 above; sflag1 clear.
M4StratMbVolcano:
        move.l #M4MbVolcanoTick,32(a0)
        jsr M4LvZeroPtrs
        move.b #$ff,38(a0)
        move.b #8,39(a0)
        ori.b #CF_ENEMY1,44(a0)
        move.b #$80,13(a0)
        move.w #$aca1,d0
        move.w #-120,d1
        move.l #M4MbParticleFire,d2
        bsr M4MbSpawn
        bclr #F2_SFLAG1,48(a0)
; volcano_strat 0A:D7C9: with 600 <= ZD < 4000 (sound $9A once: sflag1) and
; (gameframe + al1pt) & 15 == 0 a volplasma fireball; on & 7 == 0 a volrock
; fireball (at any distance). Both 120 above the volcano.
M4MbVolcanoTick:
        bsr M4MbZDPlayer
        cmpi.w #600,d0
        bmi.s M4MbVolcanoRock
        cmpi.w #4000,d0
        bpl.s M4MbVolcanoRock
        bset #F2_SFLAG1,48(a0)
        bsr M4MbAl1pt
        andi.b #15,d1
        bne.s M4MbVolcanoRock
        move.w #$ad9d,d0
        move.w #-120,d1
        move.l #M4MbVolPlasma,d2
        bsr M4MbSpawn
M4MbVolcanoRock:
        bsr M4MbAl1pt
        andi.b #7,d1
        bne.s M4MbVolcanoDone
        move.w #$ad9d,d0
        move.w #-120,d1
        move.l #M4MbVolRock,d2
        bsr M4MbSpawn
M4MbVolcanoDone:
        moveq #0,d0
        rts

; particlefire_Istrat 06:F96F (stratptr stays here): partobj, sbyte3 2,
; sbyte1 2, sbyte2 $19, no shadow, expstrat 06:F9A5 (rtl), colldisable,
; al_type |= 1. HP 0: from the next tick on only the empty expstrat runs.
M4MbParticleFire:
        move.b #2,X_SBYTE3(a0)
        move.b #2,36(a0)
        move.b #$19,37(a0)
M4MbParticleTail:
        bclr #F2_SHADOW,48(a0)
        move.l #M4EnKeep,X_EXP(a0)
        bset #SF_COLLDISABLE,49(a0)
        ori.b #1,45(a0)
        moveq #0,d0
        rts
; particlefiredown_Istrat 06:F9A6: sbyte3 3, sbyte1 4, sbyte2 9, then the
; tail of 06:F987.
M4MbParticleFireDown:
        move.b #3,X_SBYTE3(a0)
        move.b #4,36(a0)
        move.b #9,37(a0)
        bra.s M4MbParticleTail

; Fireball sprite fields (0A:D88B / D9C4 / DBED): ssprite, depthoffset 0,
; tx 0, normcollptrs, HP 2 AP 10, enemy1.
M4MbFireballInit:
        bset #F2_SPRITE,48(a0)
        clr.b X_DEPTHOFF(a0)
        clr.b X_TX(a0)
        jsr M4LvNormPtrs
        move.b #2,38(a0)
        move.b #10,39(a0)
        ori.b #CF_ENEMY1,44(a0)
        rts

; volplasma_Istrat 0A:D88B: sbyte1 $80, sbyte2 $C0, vel 50, v =
; gen_3dvecs(vel, rotx sbyte2, roty sbyte1), shadow; falls into D8DE.
M4MbVolPlasma:
        bsr M4MbFireballInit
        move.l #M4MbVolPlasmaTick,32(a0)
        move.b #$80,36(a0)
        move.b #$c0,37(a0)
        move.b #50,15(a0)
        bsr M4MbVolPlasmaVec
        bset #F2_SHADOW,48(a0)
; volplasma_strat 0A:D8DE: smoke on (gameframe + al1pt) & 3 == 0; ZD >= 500:
; sbyte2/sbyte1 Achase8_2 toward the player's pitch/yaw and v again; pos +=
; v; y >= 0 -> y = 0; addplayerZ; pos += v (twice, as the ROM); faces the
; camera (rots_flat).
M4MbVolPlasmaTick:
        bsr M4MbAl1pt
        andi.b #3,d1
        bne.s M4MbVolPlasmaNoSmoke
        jsr M4FxSmoke
M4MbVolPlasmaNoSmoke:
        bsr M4MbZDPlayer
        cmpi.w #500,d0
        bmi.s M4MbVolPlasmaMove
        lea LV_PLAYER,a2
        jsr M4EnPitchTo
        move.b d0,d1
        move.b 37(a0),d0
        moveq #2,d2
        jsr M4EnChase8
        move.b d0,37(a0)
        jsr M4EnYawTo
        move.b d0,d1
        move.b 36(a0),d0
        moveq #2,d2
        jsr M4EnChase8
        move.b d0,36(a0)
        bsr M4MbVolPlasmaVec
M4MbVolPlasmaMove:
        jsr M4EnMove
        tst.w 2(a0)
        bmi.s M4MbVolPlasmaHigh
        clr.w 2(a0)
M4MbVolPlasmaHigh:
        jsr M4EnAddPZ
        jsr M4EnMove
        jsr M4EnFaceCamera
        moveq #0,d0
        rts
M4MbVolPlasmaVec:
        moveq #0,d0
        move.b 15(a0),d0
        ext.w d0
        move.b 37(a0),d1
        move.b 36(a0),d2
        jsr M4EnVector
        movem.w d3-d5,6(a0)
        rts

; volrock_Istrat 0A:D9C4: shadow; sbyte1 = (rnd & $7F) + $40; vel = (rnd &
; 7) + 15; (vx, vz) = gen_vecs(sbyte1); vy = -(rnd & 15) - 30; falls into
; DA59: smoke on (gameframe + al1pt) & 3 == 0, bounce, pos += v, faces
; the camera.
M4MbVolRock:
        bsr M4MbFireballInit
        move.l #M4MbVolRockTick,32(a0)
        bset #F2_SHADOW,48(a0)
        jsr M4IntroRandom
        andi.b #$7f,d0
        addi.b #$40,d0
        move.b d0,36(a0)
        jsr M4IntroRandom
        andi.b #7,d0
        addi.b #15,d0
        move.b d0,15(a0)
        move.b 36(a0),d0
        bsr M4MbGen2dAngle
        jsr M4IntroRandom
        andi.w #15,d0
        neg.w d0
        subi.w #30,d0
        move.w d0,8(a0)
M4MbVolRockTick:
        bsr M4MbAl1pt
        andi.b #3,d1
        bne.s M4MbVolRockNoSmoke
        jsr M4FxSmoke
M4MbVolRockNoSmoke:
        bsr M4MbBounce
        jsr M4EnMove
        jsr M4EnFaceCamera
        moveq #0,d0
        rts

; firepillar_Istrat 0A:DAC6 (Svolcano, ceiling): strategy DB29, no
; pointers, HP $FF AP 8, enemy1, roty/rotz $80; x = (rnd | (rnd & 3) << 8)
; - 512 + asr1(player x); rnd >= $B2 (30 %): sflag2 (never fires).
M4StratMbFirepillar:
        move.l #M4MbFirepillarTick,32(a0)
        jsr M4LvZeroPtrs
        move.b #$ff,38(a0)
        move.b #8,39(a0)
        ori.b #CF_ENEMY1,44(a0)
        move.b #$80,13(a0)
        move.b #$80,14(a0)
        jsr M4IntroRandom
        move.b d0,1(a0)
        jsr M4IntroRandom
        andi.b #3,d0
        move.b d0,(a0)
        subi.w #$200,(a0)
        move.w M4_SC_PPOSX,d0
        asr.w #1,d0
        add.w d0,(a0)
        jsr M4IntroRandom
        cmpi.b #$b2,d0
        blo.s M4MbFirepillarTick
        bset #F2_SFLAG2,48(a0)
; firepillar_strat 0A:DB29: sflag2 -> nothing. ZD < 1000 once (sflag1): a
; particlefiredown emitter 60 below (sound $49). ZD < 800 and (gameframe +
; al1pt) & 3 == 0: a volrockdown fireball at it.
M4MbFirepillarTick:
        btst #F2_SFLAG2,48(a0)
        bne.s M4MbFirepillarDone
        bsr M4MbZDPlayer
        cmpi.w #1000,d0
        bpl.s M4MbFirepillarRock
        btst #F2_SFLAG1,48(a0)
        bne.s M4MbFirepillarRock
        move.w #$aca1,d0
        moveq #60,d1
        move.l #M4MbParticleFireDown,d2
        bsr M4MbSpawn
        beq.s M4MbFirepillarRock
        bset #F2_SFLAG1,48(a0)
M4MbFirepillarRock:
        bsr M4MbZDPlayer
        cmpi.w #800,d0
        bpl.s M4MbFirepillarDone
        bsr M4MbAl1pt
        andi.b #3,d1
        bne.s M4MbFirepillarDone
        move.w #$ad9d,d0
        moveq #0,d1
        move.l #M4MbVolRockDown,d2
        bsr M4MbSpawn
M4MbFirepillarDone:
        moveq #0,d0
        rts

; volrockdown_Istrat 0A:DBED: v = (0, 80, 0); falls into DC2F: pos += v;
; state 0 and y >= 0: v = ((rnd & 15) - 7, (rnd & 7) - 15, (rnd & 15) - 7),
; state 1, y = 0, pos += v. State 1: bounce; low byte of the new vy 0 ->
; removed (06:8D12). Faces the camera.
M4MbVolRockDown:
        bsr M4MbFireballInit
        move.l #M4MbVolRockDownTick,32(a0)
        clr.w 6(a0)
        move.w #80,8(a0)
        clr.w 10(a0)
M4MbVolRockDownTick:
        jsr M4EnMove
        tst.b X_STATE(a0)
        bne.s M4MbVolRockDownFall
        tst.w 2(a0)
        bmi.s M4MbVolRockDownFall
        jsr M4IntroRandom
        andi.w #15,d0
        subq.w #7,d0
        move.w d0,6(a0)
        jsr M4IntroRandom
        andi.w #7,d0
        subi.w #15,d0
        move.w d0,8(a0)
        jsr M4IntroRandom
        andi.w #15,d0
        subq.w #7,d0
        move.w d0,10(a0)
        addq.b #1,X_STATE(a0)
        clr.w 2(a0)
        jsr M4EnMove
M4MbVolRockDownFall:
        cmpi.b #1,X_STATE(a0)
        bne.s M4MbVolRockDownFace
        tst.w 2(a0) ;in the air: vy += 2 only
        bmi.s M4MbVolRockDownAir
        bsr M4MbBounce
        tst.b d0 ;the ROM tests the low byte (sep #$20; cmp #0)
        bne.s M4MbVolRockDownFace
        moveq #1,d0
        rts
M4MbVolRockDownAir:
        addq.w #2,8(a0)
M4MbVolRockDownFace:
        jsr M4EnFaceCamera
        moveq #0,d0
        rts

; ---------------------------------------------------------------------
; Friends' ships of cl_under (05:DEED, after setvar stageclear and
; mapCLplayermode ClearUnder): clshipUNDERa/b/c 06:CE18 / CE75 / CED2.
; Istrat: shadow, strategy CE4C / CEA9 / CEFA, no zremove; a: rotz $C0,
; roty $20, sword1 145, sbyte1 1, sflag2; b: rotz $40, roty $E0, sword1
; 150, sbyte1 2, sflag2 clear; c: sword1 155, sflag2. (UltraStarFox
; GCSTRATS.ASM writes deg45 for a/b: the ROM values are these.) Every tick
; x = Achase16_4(x, TX) (a -70, b 70, c 0), then the body 06:CF23 with the
; offsets dZ/dY (a -100/20, b -200/20, c -300/30).
M4StratMbClshipA:
        move.l #M4MbClshipATick,32(a0)
        bsr.s M4MbClshipInit
        move.b #$c0,14(a0)
        move.b #$20,13(a0)
        move.w #145,40(a0)
        move.b #1,36(a0)
        bset #F2_SFLAG2,48(a0)
M4MbClshipATick:
        move.w #-70,d1
        move.w #-100,d5
        moveq #20,d6
        bra.s M4MbClshipBody
M4StratMbClshipB:
        move.l #M4MbClshipBTick,32(a0)
        bsr.s M4MbClshipInit
        move.b #$40,14(a0)
        move.b #$e0,13(a0)
        move.w #150,40(a0)
        move.b #2,36(a0)
        bclr #F2_SFLAG2,48(a0)
M4MbClshipBTick:
        moveq #70,d1
        move.w #-200,d5
        moveq #20,d6
        bra.s M4MbClshipBody
M4StratMbClshipC:
        move.l #M4MbClshipCTick,32(a0)
        bsr.s M4MbClshipInit
        move.w #155,40(a0)
        bset #F2_SFLAG2,48(a0)
M4MbClshipCTick:
        moveq #0,d1
        move.w #-300,d5
        moveq #30,d6
        bra.s M4MbClshipBody
M4MbClshipInit:
        bset #F2_SHADOW,48(a0)
        bclr #3,45(a0) ;no atzremove
        rts
; 06:CF23: sword1 0 -> clshipUNDERboost 06:CFCD; sword1 - 1; z =
; Achase16_4(z, player.z + dZ); y = Achase16_5(y, player.y + dY); rotx =
; Achase8_5(rotx, player.rotx); even gameframe: rotz = Achase8_5(rotz,
; player.rotz), roty = Achase8_4(roty, player.roty); addplayerZ; z +=
; psvar_word2 $1558. d1 TX, d5 dZ, d6 dY.
M4MbClshipBody:
        move.w (a0),d0
        moveq #4,d2
        jsr M4LpAchase
        move.w d0,(a0)
        tst.w 40(a0)
        beq M4MbClshipBoostI
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
        moveq #5,d2
        jsr M4LpAchase
        move.w d0,2(a0)
        move.b 12(a0),d0
        move.b 12(a2),d1
        moveq #5,d2
        jsr M4EnChase8
        move.b d0,12(a0)
        btst #0,M4_LV_GAMEFRAME+1
        bne.s M4MbClshipMove
        move.b 14(a0),d0
        move.b 14(a2),d1
        moveq #5,d2
        jsr M4EnChase8
        move.b d0,14(a0)
        move.b 13(a0),d0
        move.b 13(a2),d1
        moveq #4,d2
        jsr M4EnChase8
        move.b d0,13(a0)
M4MbClshipMove:
        jsr M4EnAddPZ
        move.w M4_WP_W1558,d0
        add.w d0,4(a0)
        moveq #0,d0
        rts
; clshipUNDERboost_Istrat 06:CFCD: strategy CFE4 (sounds not ported); then
; every tick speedto 40 step 1, (vx, vz) = gen_vecs(roty), pos += v; sbyte1
; 1: rotz + 1 and on even gameframes roty + 1; sbyte1 2: rotz - 1, roty -
; 1 likewise; sbyte1 0: no turn; addplayerZ.
M4MbClshipBoostI:
        move.l #M4MbClshipBoost,32(a0)
M4MbClshipBoost:
        moveq #40,d0
        moveq #1,d1
        jsr M4EnSpeedTo
        jsr M4EnGen2d
        jsr M4EnMove
        move.b 36(a0),d0
        beq.s M4MbClshipBoostZ
        moveq #1,d1
        cmpi.b #1,d0
        beq.s M4MbClshipBoostTurn
        moveq #-1,d1
M4MbClshipBoostTurn:
        add.b d1,14(a0)
        btst #0,M4_LV_GAMEFRAME+1
        bne.s M4MbClshipBoostZ
        add.b d1,13(a0)
M4MbClshipBoostZ:
        jsr M4EnAddPZ
        moveq #0,d0
        rts

; ---------------------------------------------------------------------
; Boss boss2 08:8BBE (Spinning top, boss_2_2; GBSTRATS.ASM). Children
; (makechild 1F:D56F, enemy1): top boss_2_1 (1, 08:93A8), petals boss_2_5
; (2..5, 08:962B, sbyte2 0/$40/$80/$C0), turrets boss_2_0 (7, 9, 11, 13,
; 08:9500, sbyte2 $20/$60/$A0/$E0). Mother flags read by the children:
; sflag1 (petals open), sflag2 (top weak: petals fall), sflag3 (spinning:
; collisions on, the petals throw their rockbeams), sflag4 (top fires
; BOSSHMISSILE2). Sounds/music not ported.
M4StratMbBoss2:
        move.w #$beac,d0
        moveq #1,d1
        move.l #M4MbTopI,d2
        bsr M4MbChild
        moveq #2,d1
        moveq #0,d3
        moveq #3,d4
M4MbBoss2Petals:
        move.w #M4MbPetalInitial,d0
        move.l #M4MbPetalI,d2
        bsr M4MbChild
        beq.s M4MbBoss2PetalNext
        move.b d3,37(a2)
M4MbBoss2PetalNext:
        addq.b #1,d1
        addi.b #$40,d3
        dbra d4,M4MbBoss2Petals
        moveq #7,d1
        moveq #$20,d3
        moveq #3,d4
M4MbBoss2Turrets:
        move.w #$be90,d0
        move.l #M4MbTurretI,d2
        bsr M4MbChild
        beq.s M4MbBoss2TurretNext
        move.b d3,37(a2)
M4MbBoss2TurretNext:
        addq.b #2,d1
        addi.b #$40,d3
        dbra d4,M4MbBoss2Turrets
        move.l #M4MbBoss2Tick,32(a0)
        clr.l X_COLL(a0)
        move.l #M4MbBoss2Exp,X_EXP(a0)
        move.b #$ff,38(a0)
        move.b #10,39(a0)
        ori.b #CF_ENEMY1|$40,44(a0)
        move.b #50,19(a0)
        clr.b M4_BOSS_MAXHP
        clr.b M4_BOSS_HP
        bset #SF_COLLDISABLE,49(a0)
        bset #F2_SHADOW,48(a0)
        moveq #0,d0
        rts
; makechild (d0 header, d1 id, d2 Istrat) + colltype enemy1 -> a2, Z on
; failure (fatal in M4MtMakeChild, as the ROM's restart 1F:BDEE).
M4MbChild:
        jsr M4MtMakeChild
        beq.s M4MbChildDone
        ori.b #CF_ENEMY1,44(a2)
M4MbChildDone:
        rts

; boss2_strat 08:8E3C. nextstate (1F:DB66) = state + 1 and the strategy
; again from the top (1F:DC25).
M4MbBoss2Next:
        addq.b #1,X_STATE(a0)
M4MbBoss2Tick:
        moveq #0,d0 ;s_count_childs: the sword1 chain
        move.w 40(a0),d1
M4MbBoss2Count:
        tst.w d1
        beq.s M4MbBoss2Counted
        addq.b #1,d0
        movea.w d1,a2
        move.w 40(a2),d1
        bra.s M4MbBoss2Count
M4MbBoss2Counted:
        move.b d0,M4_MB_CHILDS
        move.b X_STATE(a0),d0
        beq.s M4MbBoss2S0
        cmpi.b #1,d0
        beq M4MbBoss2S1
        bra M4MbBoss2S2
; state 0: with <= 7 children: sflag4, roty + 2, sflag1, sbyte3 2 (petals
; half open), with 6 roty + 2 more; with 5 -> state 1. ZD < 1100:
; keeprelto_player + addplayerZ; else two L2smoke (06:8EA8, shape AE0D,
; addrnd2posy, z - 100, y - 280 / - 160).
M4MbBoss2S0:
        move.b M4_MB_CHILDS,d0
        cmpi.b #7,d0
        bgt.s M4MbBoss2S0Five
        bset #MB_SF4,X2_FL2(a0)
        addq.b #2,13(a0)
        bset #F2_SFLAG1,48(a0)
        move.b #2,X_SBYTE3(a0)
        cmpi.b #6,d0
        bne.s M4MbBoss2S0Five
        addq.b #2,13(a0)
M4MbBoss2S0Five:
        cmpi.b #5,M4_MB_CHILDS
        beq.s M4MbBoss2Next
        bsr M4MbZDPlayer
        cmpi.w #1100,d0
        bpl.s M4MbBoss2Smoke
        move.w 10(a1),d0
        sub.w M4_LP_PVIEWVZ,d0
        add.w d0,4(a0)
        jsr M4EnAddPZ
        bra M4MbBoss2End
M4MbBoss2Smoke:
        move.w #-280,d2
        bsr.s M4MbBoss2L2Smoke
        move.w #-160,d2
        bsr.s M4MbBoss2L2Smoke
        bra M4MbBoss2End
M4MbBoss2L2Smoke:
        jsr M4FxSmoke
        beq.s M4MbBoss2L2Done
        move.w #$ae0d,d0
        jsr M4LevelShapeIndex
        exg a0,a2
        jsr M4LevelSetShape
        exg a0,a2
        jsr M4FxRandomPos
        subi.w #100,4(a2)
        add.w d2,2(a2)
M4MbBoss2L2Done:
        rts
; state 1: sflag4 clear, v = (0, -80, 0), sword2 0, state 2; al_ptr = a
; particlefiredown emitter at it (0 when it cannot be made). Then state 2
; in the same pass.
M4MbBoss2S1:
        bclr #MB_SF4,X2_FL2(a0)
        clr.w 6(a0)
        move.w #-80,8(a0)
        clr.w 10(a0)
        clr.w X_SWORD2(a0)
        addq.b #1,X_STATE(a0)
        clr.w X_ALPTR(a0)
        move.w #$aca1,d0
        moveq #0,d1
        move.l #M4MbParticleFireDown,d2
        bsr M4MbSpawn
        beq.s M4MbBoss2S2
        move.w a2,X_ALPTR(a0)
; state 2: the emitter follows; above y -1000: rotz $80, sword2 -480, x =
; Achase16_4(x, player x), z = Achase16_5(z, player z + 200). addplayerZ,
; pos += v, falldown_Yvec(2, floor sword2): vy += 2, at the floor y =
; floor and vy = -vy/4 (toward zero, -5..-1 -> 0; sound $8E); low byte of
; the new vy 0 -> the emitter removed, state 3.
M4MbBoss2S2:
        cmpi.b #2,X_STATE(a0)
        bne M4MbBoss2S3
        move.w X_ALPTR(a0),d0
        beq.s M4MbBoss2S2Pos
        movea.w d0,a2
        move.l (a0),(a2)
        move.w 4(a0),4(a2)
M4MbBoss2S2Pos:
        cmpi.w #-1000,2(a0)
        bpl.s M4MbBoss2S2Low
        move.b #$80,14(a0)
        move.w #-480,X_SWORD2(a0)
        move.w (a0),d0
        move.w M4_SC_PPOSX,d1
        moveq #4,d2
        jsr M4LpAchase
        move.w d0,(a0)
        move.w 4(a0),d0
        move.w M4_LP_POSZ,d1
        addi.w #200,d1
        moveq #5,d2
        jsr M4LpAchase
        move.w d0,4(a0)
M4MbBoss2S2Low:
        jsr M4EnAddPZ
        jsr M4EnMove
        move.w X_SWORD2(a0),d1
        addq.w #2,8(a0)
        move.w 2(a0),d0
        sub.w d1,d0
        bmi.s M4MbBoss2S3
        move.w d1,2(a0)
        move.w 8(a0),d0
        neg.w d0
        asr.w #1,d0
        bpl.s M4MbBoss2S2R1
        bcc.s M4MbBoss2S2R1
        addq.w #1,d0
M4MbBoss2S2R1:
        asr.w #1,d0
        bpl.s M4MbBoss2S2R2
        bcc.s M4MbBoss2S2R2
        addq.w #1,d0
M4MbBoss2S2R2:
        cmpi.w #$fffb,d0
        blo.s M4MbBoss2S2Vy
        moveq #0,d0
M4MbBoss2S2Vy:
        move.w d0,8(a0)
        tst.b d0
        bne.s M4MbBoss2S3
        move.w X_ALPTR(a0),d0
        beq.s M4MbBoss2S2Next
        movea.w d0,a2
        move.l a0,-(sp)
        movea.l a2,a0
        jsr M4LevelRemove
        movea.l (sp)+,a0
M4MbBoss2S2Next:
        addq.b #1,X_STATE(a0)
; state 3: addplayerZ, x = Achase16_3(x, 0), z + 30, sbyte4 25; ZD >= 1100
; -> state 4 (again from the top).
M4MbBoss2S3:
        cmpi.b #3,X_STATE(a0)
        bne.s M4MbBoss2S4
        jsr M4EnAddPZ
        move.w (a0),d0
        moveq #0,d1
        moveq #3,d2
        jsr M4LpAchase
        move.w d0,(a0)
        addi.w #30,4(a0)
        move.b #25,X_SBYTE4(a0)
        bsr M4MbZDPlayer
        cmpi.w #1100,d0
        bpl M4MbBoss2Next
; state 4: addplayerZ; sbyte4 counts 100..1: <= 25 on even gameframes a
; RELFASTELASER ($0E) from (0, -120, 0) aimed at the player with (rnd & 7)
; - 3 on rotx then roty; else pos += v (z - vz when ZD < 500). Then spin:
; roty + 4, sflag1, sbyte3 4 (open), sflag3, collisions on, vx = sin8
; [sbyte2] / 8, vz = cos8[sbyte2] / 2 (toward zero), sbyte2 + 4. No top
; (child 1) -> state 5, v = (0, 10, 30).
M4MbBoss2S4:
        cmpi.b #4,X_STATE(a0)
        bne M4MbBoss2S5
        jsr M4EnAddPZ
        subq.b #1,X_SBYTE4(a0)
        bne.s M4MbBoss2S4Cnt
        move.b #100,X_SBYTE4(a0)
M4MbBoss2S4Cnt:
        cmpi.b #25,X_SBYTE4(a0)
        bgt.s M4MbBoss2S4Move
        btst #0,M4_LV_GAMEFRAME+1
        bne.s M4MbBoss2S4Spin
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
        lea LV_PLAYER,a3
        jsr M4EnFire
        bra.s M4MbBoss2S4Spin
M4MbBoss2S4Move:
        jsr M4EnMove
        bsr M4MbZDPlayer
        cmpi.w #500,d0
        bpl.s M4MbBoss2S4Spin
        move.w 10(a0),d0
        sub.w d0,4(a0)
M4MbBoss2S4Spin:
        addq.b #4,13(a0)
        bset #F2_SFLAG1,48(a0)
        move.b #4,X_SBYTE3(a0)
        bset #MB_SF3,X2_FL2(a0)
        bclr #SF_COLLDISABLE,49(a0)
        lea M4IntroShipSine,a2
        moveq #0,d1
        move.b 37(a0),d1
        move.b (a2,d1.w),d0
        ext.w d0
        moveq #3,d2
        bsr M4MbAsrZero
        move.w d0,6(a0)
        move.b 64(a2,d1.w),d0
        ext.w d0
        moveq #1,d2
        bsr M4MbAsrZero
        move.w d0,10(a0)
        addq.b #4,37(a0)
        moveq #1,d0
        movea.l a0,a2
        jsr M4PvFindChild
        cmpa.w #0,a2
        bne.s M4MbBoss2S5
        addq.b #1,X_STATE(a0)
        clr.w 6(a0)
        move.w #10,8(a0)
        move.w #30,10(a0)
; state 5: player alive -> boss dying (bossflags, notdie, no fire), vy + 1,
; floor y -240 (vy = -vy/2 toward zero, -5..-1 -> 0; low byte 0 ->
; kill_Istrat 06:8D07); a large explosion (nopolyexp, addrnd2posy, y +
; 120, vy -20, lifecnt 1); addplayerZ; pos += v; even gameframe: hitflash.
; Player dead ($14D9 bit 7): only the bounce and addplayerZ.
M4MbBoss2S5:
        cmpi.b #5,X_STATE(a0)
        bne M4MbBoss2End
        btst #7,M4_LP_PSF2
        beq.s M4MbBoss2Die
        addq.w #1,8(a0)
        cmpi.w #-240,2(a0)
        bmi.s M4MbBoss2S5PZ
        bsr M4MbBoss2Floor
M4MbBoss2S5PZ:
        jsr M4EnAddPZ
        bra M4MbBoss2End
M4MbBoss2Die:
        tst.b M4_BOSS_DYING
        bne.s M4MbBoss2Dying
        st M4_BOSS_DYING
        ori.b #$20,M4_BOSS_PSTRATF
        ori.b #$40,M4_LP_PSF
M4MbBoss2Dying:
        addq.w #1,8(a0)
        cmpi.w #-240,2(a0)
        bmi.s M4MbBoss2Expl
        bsr M4MbBoss2Floor
        tst.b d0
        bne.s M4MbBoss2Expl
        jsr M4EnKill
        moveq #0,d0
        rts
M4MbBoss2Expl:
        jsr M4FxLarge
        beq.s M4MbBoss2ExplMove
        bset #F2_NOPOLYEXP,48(a2)
        jsr M4FxRandomPos
        addi.w #120,2(a2)
        move.w #-20,8(a2)
        move.b #1,19(a2)
M4MbBoss2ExplMove:
        jsr M4EnAddPZ
        jsr M4EnMove
        btst #0,M4_LV_GAMEFRAME+1
        bne.s M4MbBoss2End
        bset #SF_HITFLASH,49(a0)
        bset #2,31(a0)
M4MbBoss2End:
        addq.b #2,13(a0)
        moveq #0,d0
        rts
; y = -240, vy = -vy/2 toward zero (-5..-1 -> 0) -> d0.
M4MbBoss2Floor:
        move.w #-240,2(a0)
        move.w 8(a0),d0
        neg.w d0
        moveq #1,d2
        bsr.s M4MbAsrZero
        cmpi.w #$fffb,d0
        blo.s M4MbBoss2FloorSet
        moveq #0,d0
M4MbBoss2FloorSet:
        move.w d0,8(a0)
        rts
; d0.w asr d2 one step at a time, each rounded toward zero (ror + adc).
M4MbAsrZero:
        subq.w #1,d2
M4MbAsrZeroStep:
        asr.w #1,d0
        bpl.s M4MbAsrZeroNext
        bcc.s M4MbAsrZeroNext
        addq.w #1,d0
M4MbAsrZeroNext:
        dbra d2,M4MbAsrZeroStep
        rts

; boss2exp_Istrat 08:9391: v = (0, 120, 0), bossbigoutexplodeoff 06:EC4A.
M4MbBoss2Exp:
        clr.w 6(a0)
        move.w #120,8(a0)
        clr.w 10(a0)
        bra M4MbBigOutOff

; ---------------------------------------------------------------------
; bossbigoutexplodeoff 06:EC4A / bossbigoutexplode 06:EC68 (offset 0):
; offset = v of the boss; gameflags bossdead; a nullshape timer (06:EE72,
; sflags of the boss with colldisable, noexpsnd, sflag1 clear, lifecnt 1)
; and a particle emitter (06:F89C, sflags of the boss, relexplode), both at
; the boss + offset; 10 x [large, huge (relexplode), large (lifecnt + 8),
; huge (relexplode, lifecnt + 8)] (06:ED84: v = gen_3dvecs(speed (rnd &
; 63) + 50, rotx rnd, roty $40) with vz 0, nopolyexp, lifecnt rnd & 15,
; addrnd2posy, + offset); then the boss is the 11-tick relexplode timer
; 06:8D17. The circle flash (circleanim $16AB/$16AD) is not drawn.
M4MbBigOutOff:
        movem.w 6(a0),d0-d2
        movem.w d0-d2,M4_MB_OFF
        bra.s M4MbBigOutGo
; bossbigoutexplode 06:EC68: the same with offset 0 (not used by Macbeth).
M4MbBigOut:
        clr.l M4_MB_OFF
        clr.w M4_MB_OFF+4
M4MbBigOutGo:
        bset #2,M4_LP_GAMEFLAGS
        move.w #$aca1,d0
        moveq #0,d1
        move.l #M4MbBigTimerI,d2
        bsr M4MbSpawn
        beq.s M4MbBigOutPart
        bsr M4MbCopyFlags
        bset #SF_COLLDISABLE,49(a2)
        bset #F2_NOEXPSND,48(a2)
        move.b #1,19(a2)
        bclr #F2_SFLAG1,48(a2)
        bsr M4MbAddOff
M4MbBigOutPart:
        move.w #$aca1,d0
        moveq #0,d1
        move.l #M4MbBigPartI,d2
        bsr M4MbSpawn
        beq.s M4MbBigOutLoop
        bsr M4MbCopyFlags
        bsr M4MbAddOff
        bset #F2_RELEXPLODE,48(a2)
M4MbBigOutLoop:
        moveq #9,d7
M4MbBigOutRound:
        jsr M4FxLarge
        bsr.s M4MbBigOutThrow
        jsr M4FxHuge
        bsr.s M4MbBigOutThrow
        beq.s M4MbBigOutL2
        bset #F2_RELEXPLODE,48(a2)
M4MbBigOutL2:
        jsr M4FxLarge
        bsr.s M4MbBigOutThrow
        beq.s M4MbBigOutH2
        addq.b #8,19(a2)
M4MbBigOutH2:
        jsr M4FxHuge
        bsr.s M4MbBigOutThrow
        beq.s M4MbBigOutNext
        bset #F2_RELEXPLODE,48(a2)
        addq.b #8,19(a2)
M4MbBigOutNext:
        dbra d7,M4MbBigOutRound
        move.b #11,19(a0)
        bset #F2_RELEXPLODE,48(a0)
        move.b #$ff,38(a0)
        move.b #8,39(a0)
        move.l #M4MbBigDelay,32(a0)
        jsr M4LvZeroPtrs
        bset #SF_COLLDISABLE,49(a0)
; 06:8D45: lifecnt - 1, 0 -> removed (deferred); relexplode -> addplayerZ.
M4MbBigDelay:
        moveq #0,d1
        subq.b #1,19(a0)
        bne.s M4MbBigDelayPZ
        moveq #1,d1
M4MbBigDelayPZ:
        btst #F2_RELEXPLODE,48(a0)
        beq.s M4MbBigDelayDone
        jsr M4EnAddPZ
M4MbBigDelayDone:
        move.l d1,d0
        rts
; 06:ED84 on the explosion a2 (Z set: none made, nothing done).
M4MbBigOutThrow:
        beq.s M4MbBigOutThrowNone
        movem.l d6-d7,-(sp)
        jsr M4IntroRandom
        move.b d0,d6
        jsr M4IntroRandom
        andi.w #63,d0
        addi.w #50,d0
        exg a0,a2
        move.b d6,d1
        move.b #$40,d2
        jsr M4EnVector
        move.w d3,6(a0)
        move.w d4,8(a0)
        clr.w 10(a0)
        bset #F2_NOPOLYEXP,48(a0)
        jsr M4IntroRandom
        andi.b #15,d0
        move.b d0,19(a0)
        exg a0,a2
        jsr M4FxRandomPos
        bsr.s M4MbAddOff
        movem.l (sp)+,d6-d7
        cmpa.w #0,a2
M4MbBigOutThrowNone:
        rts
; a2 position += offset (06:EDD0).
M4MbAddOff:
        movem.l d0-d2,-(sp)
        movem.w M4_MB_OFF,d0-d2
        add.w d0,(a2)
        add.w d1,2(a2)
        add.w d2,4(a2)
        movem.l (sp)+,d0-d2
        rts
; sflags $1D..$20 of a0 copied to a2 (port bytes 48, 49, X2_FL2..X2_FL4).
M4MbCopyFlags:
        move.b 48(a0),48(a2)
        move.b 49(a0),49(a2)
        move.b X2_FL2(a0),X2_FL2(a2)
        move.b X2_FL3(a0),X2_FL3(a2)
        move.b X2_FL4(a0),X2_FL4(a2)
        rts
; Timer 06:EE72: HP $FF AP 8, no pointers, colldisable; 06:EE91: lifecnt -
; 1, negative -> 06:EC05 (circle flash object 06:864B at it, $16AD = 1:
; not drawn; with sflag1 also a particle emitter) and removed; addplayerZ.
M4MbBigTimerI:
        move.b #$ff,38(a0)
        move.b #8,39(a0)
        move.l #M4MbBigTimer,32(a0)
        jsr M4LvZeroPtrs
        bset #SF_COLLDISABLE,49(a0)
M4MbBigTimer:
        moveq #0,d1
        subq.b #1,19(a0)
        bpl.s M4MbBigTimerPZ
        move.w #$aca1,d0
        moveq #0,d1
        move.l #M4MbCircle,d2
        bsr M4MbSpawn
        btst #F2_SFLAG1,48(a0)
        beq.s M4MbBigTimerEnd
        move.w #$aca1,d0
        moveq #0,d1
        move.l #M4MbBigPartI,d2
        bsr M4MbSpawn
        beq.s M4MbBigTimerEnd
        bset #F2_RELEXPLODE,48(a2)
M4MbBigTimerEnd:
        moveq #1,d1
M4MbBigTimerPZ:
        jsr M4EnAddPZ
        move.l d1,d0
        rts
; 06:864B: addplayerZ, colldisable (the circleanim anchor).
M4MbCircle:
        jsr M4EnAddPZ
        bset #SF_COLLDISABLE,49(a0)
        moveq #0,d0
        rts
; Particle emitter 06:F89C (stratptr stays): expstrat 06:F8D2, colldisable,
; al_type |= 1, partobj, sbyte3 4, sbyte1 $FF, sbyte2 $64, no shadow.
; 06:F8D2 (HP 0: every tick): sbytes 0, lifecnt + 1 = $6E -> removed;
; relexplode -> addplayerZ. Not drawn (GSU particles PEND).
M4MbBigPartI:
        move.l #M4MbBigPart,X_EXP(a0)
        bset #SF_COLLDISABLE,49(a0)
        ori.b #1,45(a0)
        move.b #4,X_SBYTE3(a0)
        move.b #$ff,36(a0)
        move.b #$64,37(a0)
        bclr #F2_SHADOW,48(a0)
        moveq #0,d0
        rts
M4MbBigPart:
        clr.b X_SBYTE3(a0)
        clr.b 36(a0)
        clr.b 37(a0)
        bclr #F2_SHADOW,48(a0)
        addq.b #1,19(a0)
        cmpi.b #$6e,19(a0)
        beq.s M4MbBigPartGone
        btst #F2_RELEXPLODE,48(a0)
        beq.s M4MbBigPartDone
        jsr M4EnAddPZ
M4MbBigPartDone:
        moveq #0,d0
        rts
M4MbBigPartGone:
        moveq #1,d0
        rts

; ---------------------------------------------------------------------
; Children of boss2. a2 = mother (al_ptr) for all of them.
; Position and rotations of the mother (copy_pos 1F:DAED, copy_rots
; 1F:DB11). d0 = mother (a2), Z when there is none.
M4MbFromMother:
        move.w X_ALPTR(a0),d0
        beq.s M4MbFromMotherNone
        movea.w d0,a2
        move.l (a2),(a0)
        move.w 4(a2),4(a0)
        move.b 12(a2),12(a0)
        move.b 13(a2),13(a0)
        move.b 14(a2),14(a0)
        tst.w d0
M4MbFromMotherNone:
        rts
; addyrot2z_srou 08:8135: r = roty (negative) or roty ^ $FF; z += (sext(r)
; + $40) asr 4 (floor).
M4MbYrot2Z:
        move.b 13(a0),d0
        bmi.s M4MbYrot2ZNeg
        not.b d0
M4MbYrot2ZNeg:
        ext.w d0
        addi.w #$40,d0
        asr.w #4,d0
        add.w d0,4(a0)
        rts
; m_bossHP += HP (s_add_bossHP).
M4MbBossHP:
        move.b 38(a0),d0
        add.b d0,M4_BOSS_HP
        moveq #0,d0
        rts

; boss2top_Istrat 08:93A8: strategy 93EE, collstrat 94D0, expstrat 94F0, HP
; 64 AP 1, m_bossmaxHP + 64, colltype enemyweap, colldisable. 93EE: at the
; mother; mother sflag3 -> collisions on. HP <= 16: mother sflag2 and on
; gameframe & 7 == 0 a RELSLOWELASERHOME ($0A) from (0, -100, 0) at the
; player. Without that shot, with mother sflag4 every 32 gameframes a
; BOSSHMISSILE2 ($3C) from (0, -60, 0), roty 0 + $F0 (rnd >= $7F: $10),
; al_ptr = player. After the shot the ROM tests sflag4 of the shot (Y
; register), never set on a new weapon: no missile on that tick.
M4MbTopI:
        move.l #M4MbTop,32(a0)
        move.l #M4MbTopColl,X_COLL(a0)
        move.l #M4MbTopExp,X_EXP(a0)
        move.b #64,38(a0)
        move.b #1,39(a0)
        addi.b #64,M4_BOSS_MAXHP
        ori.b #$40,44(a0)
        bset #SF_COLLDISABLE,49(a0)
M4MbTop:
        bsr M4MbFromMother
        beq M4MbBossHP
        btst #MB_SF3,X2_FL2(a2)
        beq.s M4MbTopHP
        bclr #SF_COLLDISABLE,49(a0)
M4MbTopHP:
        cmpi.b #16,38(a0)
        bgt.s M4MbTopMissile
        bset #F2_SFLAG2,48(a2)
        moveq #7,d0
        and.w M4_LV_GAMEFRAME,d0
        bne.s M4MbTopMissile
        movem.l a1-a2,-(sp)
        moveq #M4_WT_RSEH,d0
        moveq #0,d3
        moveq #-100,d4
        moveq #0,d5
        moveq #0,d6
        moveq #0,d7
        lea LV_PLAYER,a3
        jsr M4EnFire
        movem.l (sp)+,a1-a2
        bra M4MbBossHP
M4MbTopMissile:
        btst #MB_SF4,X2_FL2(a2)
        beq M4MbBossHP
        moveq #31,d0
        and.w M4_LV_GAMEFRAME,d0
        bne M4MbBossHP
        moveq #-$10,d7
        jsr M4IntroRandom
        cmpi.b #$7f,d0
        blo.s M4MbTopFire
        moveq #$10,d7
M4MbTopFire:
        move.b 13(a0),-(sp)
        clr.b 13(a0)
        moveq #M4_WT_BOSSHM2,d0
        moveq #0,d3
        moveq #-60,d4
        moveq #0,d5
        moveq #0,d6
        suba.l a3,a3
        jsr M4EnFire
        cmpa.w #0,a2
        beq.s M4MbTopFired
        move.w #LV_PLAYER&$ffff,X_ALPTR(a2)
M4MbTopFired:
        move.b (sp)+,13(a0)
        bra M4MbBossHP
; boss2topcol 08:94D0: a medium explosion 480 below with vy -20, hitflash.
M4MbTopColl:
        jsr M4FxMedium
        beq.s M4MbTopCollHit
        addi.w #480,2(a2)
        move.w #-20,8(a2)
M4MbTopCollHit:
        jmp M4LcHitFlash
; boss2topexp 08:94F0: y + 480, explode_Istrat (06:F45F starts with
; divorcefamily 1F:DBA4 for a child: the mother loses child 1).
M4MbTopExp:
        addi.w #480,2(a0)
        btst #4,X2_FL4(a0)
        beq.s M4MbTopExpNow
        movea.l a0,a2
        jsr M4PvDivorce
M4MbTopExpNow:
        jmp M4LevelExplode

; boss2turret_Istrat 08:9500: strategy 9546, hitflash, expstrat 95B0, HP 16
; AP 16, m_bossmaxHP + 16, colltype enemyweap, shadow. 9546: at the mother,
; roty + sbyte2, addyrot2z; roty $80 -> HPLASMA ($26) from (0, -52, 72),
; sflag1 (no floor kill), al_ptr = player.
M4MbTurretI:
        move.l #M4MbTurret,32(a0)
        move.l #M4LcHitFlash,X_COLL(a0)
        move.l #M4MbTurretExp,X_EXP(a0)
        move.b #16,38(a0)
        move.b #16,39(a0)
        addi.b #16,M4_BOSS_MAXHP
        ori.b #$40,44(a0)
        bset #F2_SHADOW,48(a0)
M4MbTurret:
        bsr M4MbFromMother
        move.b 37(a0),d0
        add.b d0,13(a0)
        bsr M4MbYrot2Z
        cmpi.b #$80,13(a0)
        bne M4MbBossHP
        moveq #M4_WT_HPLASMA,d0
        moveq #0,d3
        moveq #-52,d4
        moveq #72,d5
        moveq #0,d6
        moveq #0,d7
        suba.l a3,a3
        jsr M4EnFire
        cmpa.w #0,a2
        beq M4MbBossHP
        bset #F2_SFLAG1,48(a2)
        move.w #LV_PLAYER&$ffff,X_ALPTR(a2)
        bra M4MbBossHP
; boss2turretexp 08:95B0: a large explosion at (0, -25, 35) rotated by roty
; (1F:C97B, x and z only) x 8, then removed (06:8D12).
M4MbTurretExp:
        jsr M4FxLarge
        beq.s M4MbTurretExpGone
        moveq #0,d3
        moveq #35,d4
        move.b 13(a0),d5
        neg.b d5
        jsr M4WeaponRotatePair
        ext.w d3
        ext.w d4
        asl.w #3,d3
        asl.w #3,d4
        add.w (a0),d3
        add.w 4(a0),d4
        move.w d3,(a2)
        move.w d4,4(a2)
        move.w 2(a0),d0
        subi.w #200,d0
        move.w d0,2(a2)
M4MbTurretExpGone:
        moveq #1,d0
        rts

; boss2petal_Istrat 08:962B: strategy 9675, no collstrat, expstrat 9769,
; HP $FF AP 1, state 0, sbyte3 0, colltype enemyweap, shadow. 9675: mother
; sflag2 -> killed (colldisable, HP 0) with sflag2. Else every 4th
; gameframe sbyte3 moves by 2 toward the mother's sbyte3 (sflag1) or 0,
; shape = 08:9793[sbyte3 / 2]; at the mother, roty +
; sbyte2, addyrot2z; mother sflag3 once (sflag1): colldisable and a
; rockbeam B1E1 (boss2plasma 08:9799) with sword1 = the petal.
M4MbPetalI:
        move.l #M4MbPetal,32(a0)
        clr.l X_COLL(a0)
        move.l #M4MbPetalExpI,X_EXP(a0)
        move.b #$ff,38(a0)
        move.b #1,39(a0)
        clr.b X_STATE(a0)
        clr.b X_SBYTE3(a0)
        ori.b #$40,44(a0)
        bset #F2_SHADOW,48(a0)
M4MbPetal:
        move.w X_ALPTR(a0),d0
        beq M4MbPetalDone
        movea.w d0,a2
        btst #F2_SFLAG2,48(a2)
        beq.s M4MbPetalAlive
        bset #SF_COLLDISABLE,49(a0)
        clr.b 38(a0)
        bset #F2_SFLAG2,48(a0)
        bra M4MbPetalDone
M4MbPetalAlive:
        moveq #3,d0
        and.w M4_LV_GAMEFRAME,d0
        bne.s M4MbPetalPlace
        move.b X_SBYTE3(a0),d0
        btst #F2_SFLAG1,48(a2)
        beq.s M4MbPetalClose
        cmp.b X_SBYTE3(a2),d0
        beq.s M4MbPetalPlace
        addq.b #2,d0
        bra.s M4MbPetalShape
M4MbPetalClose:
        tst.b d0
        beq.s M4MbPetalPlace
        subq.b #2,d0
M4MbPetalShape:
        move.b d0,X_SBYTE3(a0)
        andi.w #$fe,d0
        lea M4MbPetalTab,a3
        move.w (a3,d0.w),d0
        move.l a2,-(sp)
        jsr M4MtSetHdr
        movea.l (sp)+,a2
M4MbPetalPlace:
        bsr M4MbFromMother
        move.b 37(a0),d0
        add.b d0,13(a0)
        bsr M4MbYrot2Z
        btst #MB_SF3,X2_FL2(a2)
        beq.s M4MbPetalDone
        btst #F2_SFLAG1,48(a0)
        bne.s M4MbPetalDone
        bset #SF_COLLDISABLE,49(a0)
        bset #F2_SFLAG1,48(a0)
        move.w #$b1e1,d0
        jsr M4MtCreateHdr
        beq.s M4MbPetalDone
        move.l #M4MbPlasmaI,32(a2)
        move.w a0,40(a2)
M4MbPetalDone:
        moveq #0,d0
        rts
M4MbPetalTab:
        include '../build/m4-macbeth-petal-models.inc'
; boss2petalexp_Istrat 08:9769: expstrat 977F, lifecnt 50; 977F: rotx - 4,
; lifecnt - 1, 0 -> removed (deferred).
M4MbPetalExpI:
        move.l #M4MbPetalExp,X_EXP(a0)
        move.b #50,19(a0)
        moveq #0,d0
        rts
M4MbPetalExp:
        subq.b #4,12(a0)
        moveq #0,d0
        subq.b #1,19(a0)
        bne.s M4MbPetalExpDone
        moveq #1,d0
M4MbPetalExpDone:
        rts

; boss2plasma_Istrat 08:9799 (rockbeam): strategy 97E4, HP $FF AP 8,
; enemy1 + enemyweap, sbyte1 = roty of its petal (sword1), roty $80,
; ssprite, depthoffset 0, tx 0, sword2 = the petal's y, no zremove. 97E4:
; petal sflag2 -> removed (06:8D12); (0, 0, sbyte2) rotated by sbyte1
; (1F:C97B): x = petal x + x' << 2, z = petal z + z' << 4, y = petal y;
; roty $80; sbyte1 + 4/3/2 while sbyte2 <= 30/60/90, + 1; sbyte2 + 1
; (120 -> 0); y = sword2; sword2 = Achase16_2(sword2, player y).
M4MbPlasmaI:
        move.l #M4MbPlasma,32(a0)
        move.b #$ff,38(a0)
        move.b #8,39(a0)
        ori.b #CF_ENEMY1|$40,44(a0)
        movea.w 40(a0),a2
        move.b 13(a2),36(a0)
        move.b #$80,13(a0)
        bset #F2_SPRITE,48(a0)
        clr.b X_DEPTHOFF(a0)
        clr.b X_TX(a0)
        move.w 2(a2),X_SWORD2(a0)
        bclr #3,45(a0)
M4MbPlasma:
        movea.w 40(a0),a2
        btst #F2_SFLAG2,48(a2)
        bne M4MbPlasmaGone
        moveq #0,d3
        move.b 37(a0),d4
        move.b 36(a0),d5
        neg.b d5
        jsr M4WeaponRotatePair
        ext.w d3
        ext.w d4
        asl.w #2,d3
        asl.w #4,d4
        add.w (a2),d3
        add.w 4(a2),d4
        move.w d3,(a0)
        move.w d4,4(a0)
        move.w 2(a2),2(a0)
        move.b #$80,13(a0)
        move.b 37(a0),d0
        cmpi.b #30,d0
        bgt.s M4MbPlasma60
        addq.b #4,36(a0)
M4MbPlasma60:
        cmpi.b #60,d0
        bgt.s M4MbPlasma90
        addq.b #3,36(a0)
M4MbPlasma90:
        cmpi.b #90,d0
        bgt.s M4MbPlasmaStep
        addq.b #2,36(a0)
M4MbPlasmaStep:
        addq.b #1,36(a0)
        addq.b #1,d0
        cmpi.b #120,d0
        bmi.s M4MbPlasmaDist
        moveq #0,d0
M4MbPlasmaDist:
        move.b d0,37(a0)
        move.w X_SWORD2(a0),d0
        move.w d0,2(a0)
        move.w M4_SC_PPOSY,d1
        moveq #2,d2
        jsr M4LpAchase
        move.w d0,X_SWORD2(a0)
        moveq #0,d0
        rts
M4MbPlasmaGone:
        moveq #1,d0
        rts

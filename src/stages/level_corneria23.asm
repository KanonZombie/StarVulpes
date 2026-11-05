; Stage unit: Corneria 2 (0D:DD66), Corneria 3 (0D:E3CF) and Training (0D:EE9A).
; Strategies (table searched by M4LevelFindStrategy, level_objects.asm),
; helpers and effects of these stages. Stage data: tools/stages/corneria23.py.
; Every routine was re-read in the ROM bytes (tools/dis65816.py,
; build/agent-corneria23/dis/) and is compared with the ROM tick by tick by
; build/agent-corneria23/c23-compare.py (build/agent-corneria23/CORNERIA23.md).
; Conventions of level_objects.asm / level_enemies.asm: a0 object, a1
; player; d0 = 0 keep / nonzero deferred removal. "d < K" comparisons are the
; N bit of the 16-bit difference. Sounds (03:B705/B71D/B7E5, set_sound2) are
; not ported. Shapes are referenced by their ROM header (M4LevelShapeIndex).
; RAM: $FF9800..$FF983F (reserved for this unit).
M4_CORNERIA23 equ $ff9800
; Extended object fields of this unit's objects (free X offsets).
X_CNFL equ -$8000+46 ;.b bit0 = sflags2 $04 of para2 (face_player started)

M4StrategiesCorneria2:
        dc.l $0685f9,M4StratHardRot
        dc.l $08b539,M4StratHoudaiNS
        dc.l $08b56f,M4StratHoudai
        dc.l $0a8035,M4StratZaco3
        dc.l $0a8489,M4StratZaco0
        dc.l $0a8631,M4StratCarrier
        dc.l $04f667,M4StratPara
        dc.l $00f99f,M4StratBase1Door
        dc.l $079b0f,M4StratBossA
        dc.l 0

; ---------------------------------------------------------------------
; Helpers.

; d1.b = low byte of al1pt for the (gameframe + al1pt) phases: the
; original-like record address of M4B1Al1pt (level_boss1.asm). Separate
; label so the oracle can feed the paired ROM address.
M4CnAl1pt:
        jmp M4B1Al1pt

; find_anynearobject 1F:C8B9 (find_nearobj with shape 0) from the head of
; allst: the nearest object with realobj (sflags3 $08), not a0, with
; distXZ in [0, d2) (strictly nearer replaces: the first on ties) -> a2 or
; 0. realobj is set by every allocation (1F:D36E) and cleared by the
; creators of non-real objects (USF GSTRATS/EXPSTRAT s_clr_alsflag realobj;
; ROM sites 06:8081..80C7, 06:8C45..F54C, 0B:E63F/EA4F). The port has no
; such flag: non-real = the player (playpt, GSTRATS.ASM:110) and the
; objects of the port routines that replace those creators: explosion
; sprite (06:F7AD/F783), smoke (06:8F72..8FA7), makeexpobj delay object
; (06:EE09) and the ground marks (Smark/Mmark/Lmark).
M4CnFindReal:
        movem.l d0-d1/d3/a3,-(sp)
        suba.l a3,a3
        move.w M4_LV_HEAD,d3
M4CnFindNext:
        tst.w d3
        beq M4CnFindDone
        movea.w d3,a2
        move.w X_NEXT(a2),d3
        cmpa.l a0,a2
        beq M4CnFindNext
        bsr M4CnRealObj
        bne M4CnFindNext
        jsr M4EnDistXZ
        tst.w d0
        bmi M4CnFindNext
        move.w d0,d1
        sub.w d2,d1
        bpl M4CnFindNext
        move.w d0,d2
        movea.l a2,a3
        bra M4CnFindNext
M4CnFindDone:
        movea.l a3,a2
        movem.l (sp)+,d0-d1/d3/a3
        rts
; a2 -> Z set when a2 is a real object (realobj).
M4CnRealObj:
        movem.l d0/a3,-(sp)
        cmpa.l #M4_LV_OBJ,a2
        beq M4CnNotReal
        move.l 32(a2),d0
        lea M4CnNonRealStrats,a3
M4CnRealStrat:
        tst.l (a3)
        beq M4CnRealShape
        cmp.l (a3)+,d0
        beq M4CnNotReal
        bra M4CnRealStrat
M4CnRealShape:
        move.w X_SHAPEHDR(a2),d0
        cmpi.w #$b3a1,d0 ;Smark (06:F068)
        beq M4CnNotReal
        cmpi.w #$b3bd,d0 ;Mmark (06:F096)
        beq M4CnNotReal
        cmpi.w #$b3d9,d0 ;Lmark (06:F0C4)
        beq M4CnNotReal
        moveq #0,d0 ;Z: real
        movem.l (sp)+,d0/a3
        rts
M4CnNotReal:
        moveq #1,d0 ;NZ
        movem.l (sp)+,d0/a3
        rts
M4CnNonRealStrats:
        dc.l M4FxExplodeTick,M4FxLExplodeTick,M4FxSmokeInit,M4FxSmokeTick
        dc.l M4FxDelayInit,M4FxDelayTick,0

; ---------------------------------------------------------------------
; hardrot_Istrat 06:85F9: colltype enemy1, HP $FF, AP 8 (hardvars), then
; hardrot_strat 06:8614 in the same tick: rotx/roty/rotz += sbyte1/2/3 (set
; by the map, setalvar after the creation).
M4StratHardRot:
        ori.b #CF_ENEMY1,44(a0)
        move.b #$ff,38(a0)
        move.b #8,39(a0)
        move.l #M4CnHardRotTick,32(a0)
M4CnHardRotTick:
        move.b 36(a0),d0
        add.b d0,12(a0)
        move.b 37(a0),d0
        add.b d0,13(a0)
        move.b X_SBYTE3(a0),d0
        add.b d0,14(a0)
        moveq #0,d0
        rts

; houdaiNS_Istrat 08:B539: no strategy (stratptr 00:0000), hitflash /
; smarkexplode 06:F046, HP 8, AP 8, colltype enemy1; rtl.
M4StratHoudaiNS:
        bsr M4CnHoudaiVars
        clr.l 32(a0)
        moveq #0,d0
        rts
M4CnHoudaiVars:
        move.l #M4LcHitFlash,X_COLL(a0)
        move.l #M4MtSmarkExplode,X_EXP(a0)
        move.b #8,38(a0)
        move.b #8,39(a0)
        ori.b #CF_ENEMY1,44(a0)
        rts
; houdai_Istrat 08:B56F: as houdaiNS with houdai_strat 08:B5A4, same tick.
M4StratHoudai:
        bsr M4CnHoudaiVars
        move.l #M4CnHoudaiTick,32(a0)
; 08:B5A4: the nearest real object within distXZ [0, 2000) becomes the
; target (sword1 $26) when it is enemy2 (colltype $20: zaco1L/R); the second
; search from $14CC finds nothing. Target set and |dz| >= 200: roty chases
; its yaw (Achase8 n 1). Then (also without target) player distXZ >= 800 and
; (gameframe + al1pt) & 15 == 0: SHORTPLASMA ($24) at (0, -16, 10) with
; rotx $F0. |dz| < 200 ends the strategy (no fire). sword1 is a raw pointer
; that the original never clears (removedeadal 1F:BFDC does not).
M4CnHoudaiTick:
        move.w #2000,d2
        bsr M4CnFindReal
        move.l a2,d0
        beq M4CnHoudaiTarget
        btst #5,44(a2) ;colltype enemy2
        beq M4CnHoudaiTarget
        move.w a2,40(a0)
M4CnHoudaiTarget:
        move.w 40(a0),d0
        beq M4CnHoudaiPlayer
        movea.w d0,a2
        jsr M4EnZD
        subi.w #200,d0
        bmi M4CnHoudaiDone
        jsr M4EnYawTo
        move.b d0,d1
        move.b 13(a0),d0
        moveq #1,d2
        jsr M4EnChase8
        move.b d0,13(a0)
M4CnHoudaiPlayer:
        movea.l a1,a2
        jsr M4EnDistXZ
        subi.w #800,d0
        bmi M4CnHoudaiDone
        bsr M4CnAl1pt
        move.w M4_LV_GAMEFRAME,d0
        add.b d1,d0
        andi.b #15,d0
        bne M4CnHoudaiDone
        moveq #M4_WT_SHORTPLASMA,d0
        moveq #0,d3
        moveq #-16,d4
        moveq #10,d5
        moveq #-16,d6
        moveq #0,d7
        suba.l a3,a3
        jsr M4EnFire
M4CnHoudaiDone:
        moveq #0,d0
        rts

; zaco3_Istrat 0A:8035: sbyte3 = 3, find_nearobj houdai_0 (C1F4) within
; 10000 from the head; none: rtl, retried every tick. Found: zaco34_Istrat
; 0A:8061 shared with zaco4 (level_enemies.asm M4StratZaco4: alx $1CE9 =
; DP $01, not read, is not modelled).
M4StratZaco3:
        move.b #3,X_SBYTE3(a0)
        move.w #$c1f4,d0
        jsr M4LevelShapeIndex
        move.w d0,d4
        cmpi.w #$ffff,d4
        beq M4CnZaco3None
        jsr M4EnFindNear
        move.l a2,d0
        beq M4CnZaco3None
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
M4CnZaco3None:
        moveq #0,d0
        rts

; zaco0_istrat 0A:8489: normal pointers, HP 2, AP 8, roty $C0, rotx $40,
; sbyte1 10, colltype enemy1 (alx $1CE9 = DP $03, not read: not modelled);
; zaco0_strat 0A:84BA in the same tick.
M4StratZaco0:
        jsr M4LvNormPtrs
        move.b #2,38(a0)
        move.b #8,39(a0)
        move.b #$c0,13(a0)
        move.b #$40,12(a0)
        move.b #10,36(a0)
        ori.b #CF_ENEMY1,44(a0)
        move.l #M4CnZaco0Tick,32(a0)
; 0A:84BA: y < player y (unsigned) -> y += 20, then y >= $FFE2 (unsigned)
; -> y = -30; x += 43; x - player x >= 0 (N clear) -> zaco0b.
M4CnZaco0Tick:
        move.w 2(a0),d0
        cmp.w 2(a1),d0
        bhs M4CnZaco0X
        addi.w #20,d0
        cmpi.w #$ffe2,d0
        blo M4CnZaco0Y
        move.w #$ffe2,d0
M4CnZaco0Y:
        move.w d0,2(a0)
M4CnZaco0X:
        addi.w #43,(a0)
        move.w (a0),d0
        sub.w (a1),d0
        bmi M4CnZaco0Done
        move.l #M4CnZaco0B,32(a0)
; 0A:8511 zaco0b: rotx -= 8, roty -= 8; roty == $80 -> zaco0c (same tick).
M4CnZaco0B:
        subq.b #8,12(a0)
        subq.b #8,13(a0)
        cmpi.b #$80,13(a0)
        bne M4CnZaco0Done
        move.l #M4CnZaco0C,32(a0)
; 0A:852A zaco0c: (gameframe + al1pt) & 3 == 0 -> RelSlowElaser ($0C) at
; the player from (0, 0, 0) with rotx += (rnd & 3) - 1, roty += (rnd & 3) - 1
; (two random_l, rotx first). Then sbyte1-- == 0 or ZD(player) < 300 ->
; zaco0c2.
M4CnZaco0C:
        bsr M4CnAl1pt
        move.w M4_LV_GAMEFRAME,d0
        add.b d1,d0
        andi.b #3,d0
        bne M4CnZaco0Count
        jsr M4IntroRandom
        andi.b #3,d0
        subq.b #1,d0
        move.b d0,d6
        jsr M4IntroRandom
        andi.b #3,d0
        subq.b #1,d0
        move.b d0,d7
        moveq #M4_WT_RSE,d0
        moveq #0,d3
        moveq #0,d4
        moveq #0,d5
        movea.l a1,a3
        jsr M4EnFire
M4CnZaco0Count:
        subq.b #1,36(a0)
        beq M4CnZaco0C2Init
        movea.l a1,a2
        jsr M4EnZD
        subi.w #300,d0
        bpl M4CnZaco0Done
M4CnZaco0C2Init:
        move.l #M4CnZaco0C2,32(a0)
; 0A:85D1 zaco0c2: rotx += 8, roty += 8; roty == $C0 -> zaco0d.
M4CnZaco0C2:
        addq.b #8,12(a0)
        addq.b #8,13(a0)
        cmpi.b #$c0,13(a0)
        bne M4CnZaco0Done
        move.l #M4CnZaco0D,32(a0)
; 0A:85F7 zaco0d: y -= 19, x += 40, speedto 50 step 2, gen_3dvecs, addvecs.
M4CnZaco0D:
        subi.w #19,2(a0)
        addi.w #40,(a0)
        moveq #50,d0
        moveq #2,d1
        jsr M4EnSpeedTo
        jsr M4EnGen3d
        jsr M4EnMove
M4CnZaco0Done:
        moveq #0,d0
        rts

; carrier_istrat 0A:8631: normal pointers, HP 16, AP 10 (alx $1CE9 = DP
; $0E, not read: not modelled); carrier_strat 0A:8650 in the same tick:
; roty += 3, y += 2, z += 30; ZD(player) < 3000 -> addplayerZ, else
; carrierb (same tick).
M4StratCarrier:
        jsr M4LvNormPtrs
        move.b #16,38(a0)
        move.b #10,39(a0)
        move.l #M4CnCarrierTick,32(a0)
M4CnCarrierTick:
        addq.b #3,13(a0)
        addq.w #2,2(a0)
        addi.w #30,4(a0)
        movea.l a1,a2
        jsr M4EnZD
        subi.w #3000,d0
        bpl M4CnCarrierBInit
        jsr M4EnAddPZ
        moveq #0,d0
        rts
M4CnCarrierBInit:
        move.l #M4CnCarrierB,32(a0)
        move.b #32,36(a0)
        move.b #1,37(a0)
; 0A:86A8 carrierb: sbyte2-- == 0 -> sbyte2 = 30 and para_0 (B481) behind
; it (1F:D54B) with para_istrat 04:F667, copy_pos, y += 90, immune pointers
; crossed. x Achase16 the player x (n 3), rotx Achase8 0 (n 4), y Achase16
; -320 (n 5), roty += 4, speedto 30 step 1, gen_3dvecs, addvecs,
; addplayerZ, z -= 15; sbyte1-- == 0 -> carrierc (same tick).
M4CnCarrierB:
        subq.b #1,37(a0)
        bne M4CnCarrierChase
        move.b #30,37(a0)
        move.w #$b481,d0
        jsr M4MtCreateHdr
        beq M4CnCarrierChase
        move.l #M4StratPara,32(a2)
        move.l (a0),(a2)
        move.w 4(a0),4(a2)
        addi.w #90,2(a2)
        move.w a2,28(a0)
        move.w a0,28(a2)
M4CnCarrierChase:
        move.w (a0),d0
        move.w (a1),d1
        moveq #3,d2
        jsr M4LpAchase
        move.w d0,(a0)
        move.b 12(a0),d0
        moveq #0,d1
        moveq #4,d2
        jsr M4EnChase8
        move.b d0,12(a0)
        move.w 2(a0),d0
        move.w #-320,d1
        moveq #5,d2
        jsr M4LpAchase
        move.w d0,2(a0)
        addq.b #4,13(a0)
        moveq #30,d0
        moveq #1,d1
        jsr M4EnSpeedTo
        jsr M4EnGen3d
        jsr M4EnMove
        jsr M4EnAddPZ
        subi.w #15,4(a0)
        subq.b #1,36(a0)
        bne M4CnCarrierDone
        move.l #M4CnCarrierC,32(a0)
; 0A:876C carrierc: z -= 10, y -= 3, roty += 4, addplayerZ.
M4CnCarrierC:
        subi.w #10,4(a0)
        subq.w #3,2(a0)
        addq.b #4,13(a0)
        jsr M4EnAddPZ
M4CnCarrierDone:
        moveq #0,d0
        rts

; para_istrat 04:F667: normal pointers, HP 2, AP 4, sbyte1 = -15, shadow;
; para_strat 04:F68A in the same tick: addplayerZ, y += 10; the swing
; sbyte1 moves by 5 toward -15 (rotz < $80) or +15 (rotz >= $80), rotz +=
; sbyte1; y >= 0 -> para2 init 04:F6E5 (ends the tick): y = 0, rotz = 0,
; shape para_1 (B4A2), vel 10, face_player not started ($1E &= ~$04).
M4StratPara:
        jsr M4LvNormPtrs
        move.b #2,38(a0)
        move.b #4,39(a0)
        move.b #$f1,36(a0)
        bset #F2_SHADOW,48(a0)
        move.l #M4CnParaTick,32(a0)
M4CnParaTick:
        jsr M4EnAddPZ
        addi.w #10,2(a0)
        move.b 36(a0),d0
        cmpi.b #$80,14(a0)
        bhs M4CnParaRight
        cmpi.b #$f1,d0
        beq M4CnParaSwing
        subq.b #5,d0
        bra M4CnParaSwing
M4CnParaRight:
        cmpi.b #$0f,d0
        beq M4CnParaSwing
        addq.b #5,d0
M4CnParaSwing:
        move.b d0,36(a0)
        add.b d0,14(a0)
        tst.w 2(a0)
        bmi M4CnParaDone
        move.l #M4CnPara2,32(a0)
        clr.w 2(a0)
        clr.b 14(a0)
        move.w #$b4a2,d0
        jsr M4MtSetHdr
        move.b #10,15(a0)
        bclr #0,X_CNFL(a0)
M4CnParaDone:
        moveq #0,d0
        rts
; 04:F713 para2: face_player (rate 1): first tick (or while one angle still
; moves) the targets sbyte4 = pitch, sbyte3 = yaw to the player are taken
; and (vx, vz) = gen2d(vel, roty); later ticks roty/rotx Achase8 n 1 toward
; them and, both already there, no new vectors. addvecs; player distXZ <
; 400 -> parajump; else every (gameframe + al1pt) & 15 == 0 vy = -15,
; addvecs again, vy += 3, landing (y >= 0): y = 0, vy = trunc(-vy / 2),
; -5..-1 -> 0.
M4CnPara2:
        btst #0,X_CNFL(a0)
        beq M4CnParaFace
        moveq #0,d4
        move.b X_SBYTE3(a0),d1
        move.b 13(a0),d0
        moveq #1,d2
        jsr M4EnChase8
        move.b d0,13(a0)
        add.b d3,d4
        move.b X_SBYTE4(a0),d1
        move.b 12(a0),d0
        jsr M4EnChase8
        move.b d0,12(a0)
        add.b d3,d4
        cmpi.b #2,d4
        beq M4CnParaVecs
M4CnParaFace:
        bset #0,X_CNFL(a0)
        movea.l a1,a2
        jsr M4EnPitchTo
        move.b d0,X_SBYTE4(a0)
        jsr M4EnYawTo
        move.b d0,X_SBYTE3(a0)
        jsr M4EnGen2d
M4CnParaVecs:
        jsr M4EnMove
        movea.l a1,a2
        jsr M4EnDistXZ
        subi.w #400,d0
        bmi M4CnParaJumpInit
        bsr M4CnAl1pt
        move.w M4_LV_GAMEFRAME,d0
        add.b d1,d0
        andi.b #15,d0
        bne M4CnParaFall
        move.w #-15,8(a0)
M4CnParaFall:
        jsr M4EnMove
        addq.w #3,8(a0)
        tst.w 2(a0)
        bmi M4CnParaDone
        clr.w 2(a0)
        move.w 8(a0),d0
        neg.w d0
        asr.w #1,d0
        bpl M4CnParaBounce
        bcc M4CnParaBounce
        addq.w #1,d0 ;ror then adc #0 when negative: toward zero
M4CnParaBounce:
        cmpi.w #$fffb,d0
        blo M4CnParaVy
        moveq #0,d0
M4CnParaVy:
        move.w d0,8(a0)
        moveq #0,d0
        rts
; 04:F824 parajump: y Achase16 the player y ($1511, n 2); ZD(player) < 200
; -> x Achase16 the player x ($150F, n 3).
M4CnParaJumpInit:
        move.l #M4CnParaJump,32(a0)
M4CnParaJump:
        move.w 2(a0),d0
        move.w M4_SC_PPOSY,d1
        moveq #2,d2
        jsr M4LpAchase
        move.w d0,2(a0)
        movea.l a1,a2
        jsr M4EnZD
        subi.w #200,d0
        bpl M4CnParaDone
        move.w (a0),d0
        move.w M4_SC_PPOSX,d1
        moveq #3,d2
        jsr M4LpAchase
        move.w d0,(a0)
        moveq #0,d0
        rts

; base_1_istrat 00:F99F (hangar door): normal pointers, HP $FF, AP 8,
; nohitaffect, animframe 0|$80; base_1 strategy 00:F9C5 in the same tick.
; Collision: the mixed colbox list (3 fixed + 1 animated x8) is pending
; (INTEGRATION.md section 2): until then the effect descriptor C23_BASE_1
; has only the header box, which would close the door, so the object is
; colldisable (documented difference; M4_CN_BASE1_COLBOX = 1 once the
; shared change gives the descriptor its colbox list).
M4_CN_BASE1_COLBOX equ 0
M4StratBase1Door:
        jsr M4LvNormPtrs
        move.b #$ff,38(a0)
        move.b #8,39(a0)
        bset #SF_NOHITAFFECT,49(a0)
        move.b #$80,16(a0)
        if M4_CN_BASE1_COLBOX=0
        bset #SF_COLLDISABLE,49(a0)
        endif
        move.l #M4CnBase1Tick,32(a0)
; 00:F9C5: sflag1 clear = closing: frame +1 up to 7 (sound $52 at frame 0
; not ported); at 8 it stays 7 and sbyte1 counts 10 ticks, then sflag1.
; sflag1 set = opening: frame -1 (sound at 7) down to 0, where sbyte1 counts
; 10 ticks, then sflag1 cleared and the closing step runs in the same tick.
M4CnBase1Tick:
        btst #F2_SFLAG1,48(a0)
        bne M4CnBase1Open
M4CnBase1Close:
        bclr #F2_SFLAG1,48(a0)
        move.b 16(a0),d0
        addq.b #1,d0
        bmi M4CnBase1CloseM
        addq.b #8,d0
M4CnBase1CloseM:
        andi.b #$7f,d0
        cmpi.b #8,d0
        bhs M4CnBase1Shut
        ori.b #$80,d0
        move.b d0,16(a0)
        moveq #0,d0
        rts
M4CnBase1Shut:
        move.b #7|$80,16(a0)
        addq.b #1,36(a0)
        cmpi.b #10,36(a0)
        bne M4CnBase1Done
        clr.b 36(a0)
        bset #F2_SFLAG1,48(a0)
M4CnBase1Done:
        moveq #0,d0
        rts
M4CnBase1Open:
        move.b 16(a0),d0
        andi.b #$7f,d0
        beq M4CnBase1Wait
        move.b 16(a0),d0
        subq.b #1,d0
        bmi M4CnBase1OpenM
        addq.b #8,d0
M4CnBase1OpenM:
        andi.b #$7f,d0
        cmpi.b #8,d0
        blo M4CnBase1OpenSet
        subq.b #8,d0
M4CnBase1OpenSet:
        ori.b #$80,d0
        move.b d0,16(a0)
        moveq #0,d0
        rts
M4CnBase1Wait:
        addq.b #1,36(a0)
        cmpi.b #10,36(a0)
        bne M4CnBase1Done
        clr.b 36(a0)
        bra M4CnBase1Close

; ---------------------------------------------------------------------
; Corneria 3 boss: bossA_Istrat 07:9B0F (tank boss_A_2 C6C4, map 05:EEC0),
; turrets boss_A_1 C6A8 (children 1..3, 07:A8B5/A8D2/A8F3) and cups C68C
; (children 4..6, 07:A35E/A365/A36C). Body flags: sflag1 $10 -> F2_SFLAG1,
; sflag2 $20 (cup strategy finished) -> F2_SFLAG2, sflag3 $40 (every cup
; gone) -> X_CNFL bit1; stratstate $1CDC (cup state) -> X_STATE; cup sword2
; ($28 low byte) -> X_CNSW; invisible ($20 $08) -> 49 bit1 + X2_FL4 bit3.
X_CNSW equ -$8000+47 ;.b $28 (cup counter, body turret-table index)
CN_BA_SFLAG3 equ 1 ;X_CNFL bit: body sflags2 $40
CN_BA_UP equ 1 ;cup states (USF bossAcup*_state)
CN_BA_GO equ 2
CN_BA_RETURN equ 3
CN_BA_DOWN equ 4
CN_BA_IROTATE equ 5
CN_BA_ROTATE equ 6

; 07:9B0F: HP $FF, AP 8, strategy 9CC0, no collision strategy, expstrat
; A18B; boss bar maximum 108 (70:019A), 70:019C = 0; three turrets and three
; cups made (link_child 1F:D56F) with colltype enemy2; body colltype enemy2
; and $40, roty 8, vx -20, shadow; sound $83 (not ported). rtl.
M4StratBossA:
        move.b #$ff,38(a0)
        move.b #8,39(a0)
        move.l #M4CnBaTick,32(a0)
        clr.l X_COLL(a0)
        move.l #M4CnBaExp,X_EXP(a0)
        move.b #108,M4_BOSS_MAXHP
        clr.b M4_BOSS_HP
        lea M4CnBaKids,a3
        moveq #1,d1
M4CnBaKid:
        move.w (a3)+,d0
        move.l (a3)+,d2
        jsr M4MtMakeChild
        beq M4CnBaKidNext
        ori.b #$20,44(a2)
M4CnBaKidNext:
        addq.b #1,d1
        cmpi.b #7,d1
        bne M4CnBaKid
        ori.b #$20|$40,44(a0)
        move.b #8,13(a0)
        move.w #-20,6(a0)
        bset #F2_SHADOW,48(a0)
        moveq #0,d0
        rts
M4CnBaKids:
        dc.w $c6a8
        dc.l M4StratBaTurretL
        dc.w $c6a8
        dc.l M4StratBaTurretM
        dc.w $c6a8
        dc.l M4StratBaTurretR
        dc.w $c68c
        dc.l M4StratBaCupL
        dc.w $c68c
        dc.l M4StratBaCupM
        dc.w $c68c
        dc.l M4StratBaCupR

; d0.b child id, d1.b state: X_STATE of that child when it exists (1F:DC40).
M4CnBaSetState:
        movem.l d1/a2,-(sp)
        jsr M4BsChild ;(clobbers d1)
        beq M4CnBaSetStateNo
        move.b 3(sp),X_STATE(a2)
M4CnBaSetStateNo:
        movem.l (sp)+,d1/a2
        rts
; d1.b state of the three cups (children 4, 5, 6).
M4CnBaCupsState:
        moveq #4,d0
        bsr M4CnBaSetState
        moveq #5,d0
        bsr M4CnBaSetState
        moveq #6,d0
        bra M4CnBaSetState

; 07:9CC0: x <= 210 and vx != 0 -> vx += 1; roty == $80 -> up; else roty +1
; on even gameframes.
M4CnBaTick:
        cmpi.w #210,(a0)
        bgt M4CnBaRoty
        tst.w 6(a0)
        beq M4CnBaRoty
        addq.w #1,6(a0)
M4CnBaRoty:
        cmpi.b #$80,13(a0)
        beq M4CnBaUpInit
        btst #0,M4_LV_GAMEFRAME+1
        bne M4CnBaCont
        addq.b #1,13(a0)
        bra M4CnBaCont
; 07:9CFD up init: sbyte2 = 30 (sound $73 without sflag3, not ported).
M4CnBaUpInit:
        move.l #M4CnBaUp,32(a0)
        move.b #30,37(a0)
; 07:9D1E up: sbyte2 == 0 -> attack; else sbyte2-- and every cup UP.
M4CnBaUp:
        tst.b 37(a0)
        beq M4CnBaAttackInit
        subq.b #1,37(a0)
        moveq #CN_BA_UP,d1
        bsr M4CnBaCupsState
        bra M4CnBaCont
; 07:9D79 cover init: sbyte2 = 50; with sflag3 the ROM jumps into the up
; strategy body (jml 07:9D1E, the strategy pointer stays 9D9A).
M4CnBaCoverInit:
        move.l #M4CnBaCover,32(a0)
        move.b #50,37(a0)
        btst #CN_BA_SFLAG3,X_CNFL(a0)
        bne M4CnBaUp
; 07:9D9A cover: sbyte2 == 0 -> attack; sbyte2--; >= 20 (N clear): cups
; DOWN; else (at 19 sound $73, or with sflag3 the up body 9D1E) cups UP.
M4CnBaCover:
        tst.b 37(a0)
        beq M4CnBaAttackInit
        subq.b #1,37(a0)
        move.b 37(a0),d0
        subi.b #20,d0
        bmi M4CnBaCoverUp
        moveq #CN_BA_DOWN,d1
        bsr M4CnBaCupsState
        bra M4CnBaCont
M4CnBaCoverUp:
        cmpi.b #19,37(a0)
        bne M4CnBaCoverUpSet
        btst #CN_BA_SFLAG3,X_CNFL(a0)
        bne M4CnBaUp
M4CnBaCoverUpSet:
        moveq #CN_BA_UP,d1
        bsr M4CnBaCupsState
        bra M4CnBaCont
; 07:9E6A attack init: sflag2 (cup strategy finished), sbyte2 = 3.
M4CnBaAttackInit:
        move.l #M4CnBaAttack,32(a0)
        bset #F2_SFLAG2,48(a0)
        move.b #3,37(a0)
; 07:9E81 attack: with sflag2: clear it; sbyte2 == 0 -> cover; sbyte2--;
; svar = random_l & 3 (3 retried) + 4; every cup UP; cup svar or, when it
; is gone, the next one (6 wraps to 4; four tries); the chosen cup goes to
; GO when two cups are dead, else to IROTATE.
M4CnBaAttack:
        bclr #F2_SFLAG2,48(a0)
        beq M4CnBaFire
        tst.b 37(a0)
        beq M4CnBaCoverInit
        subq.b #1,37(a0)
M4CnBaRnd:
        jsr M4IntroRandom
        andi.b #3,d0
        cmpi.b #3,d0
        beq M4CnBaRnd
        addq.b #4,d0
        move.b d0,d5
        moveq #CN_BA_UP,d1
        bsr M4CnBaCupsState
        moveq #4,d6 ;tries
M4CnBaPick:
        move.b d5,d0
        jsr M4BsChild
        bne M4CnBaPicked
        subq.b #1,d6
        beq M4CnBaFire
        addq.b #1,d5
        cmpi.b #6,d5
        ble M4CnBaPick
        moveq #4,d5
        bra M4CnBaPick
M4CnBaPicked:
        movea.l a2,a3
        moveq #0,d2 ;dead cups
        moveq #4,d0
M4CnBaDead:
        jsr M4BsChild
        bne M4CnBaDeadNext
        addq.b #1,d2
M4CnBaDeadNext:
        addq.b #1,d0
        cmpi.b #7,d0
        bne M4CnBaDead
        move.b #CN_BA_IROTATE,d1
        cmpi.b #2,d2
        bne M4CnBaPickState
        move.b #CN_BA_GO,d1
M4CnBaPickState:
        move.b d1,X_STATE(a3)
; 07:9FAF: sbyte3 == 3 (turrets down): with three children left (the
; turrets) the body is killed; sbyte3 == 2: STBhmissile1 at gameframe & 63 =
; 20/25/30 (roty -16/0/+16) from (0, -25, 0), missile sbyte1 $80, sbyte2
; $10, al_ptr player; else every 32 gameframes the turret targets advance
; in bossATY_tab 07:A182.
M4CnBaFire:
        move.b X_SBYTE3(a0),d0
        cmpi.b #3,d0
        bne M4CnBaMissiles
        jsr M4BsCount
        cmpi.w #3,d0
        bne M4CnBaCont
        jsr M4EnKill
        bra M4CnBaCont
M4CnBaMissiles:
        cmpi.b #2,d0
        bne M4CnBaTable
        move.w M4_LV_GAMEFRAME,d0
        andi.w #63,d0
        moveq #-16,d7
        cmpi.w #20,d0
        beq M4CnBaMissile
        moveq #0,d7
        cmpi.w #25,d0
        beq M4CnBaMissile
        moveq #16,d7
        cmpi.w #30,d0
        bne M4CnBaCont
M4CnBaMissile:
        moveq #M4_WT_STB,d0
        moveq #0,d3
        moveq #-25,d4
        moveq #0,d5
        moveq #0,d6
        suba.l a3,a3
        jsr M4EnFire
        cmpa.w #0,a2
        beq M4CnBaCont
        move.b #$80,36(a2)
        move.b #$10,37(a2)
        move.w a1,X_ALPTR(a2)
        bra M4CnBaCont
M4CnBaTable:
        move.w M4_LV_GAMEFRAME,d0
        andi.w #31,d0
        bne M4CnBaCont
        moveq #0,d4
        move.b X_CNSW(a0),d4
        move.b d4,d0
        addq.b #3,d0
        cmpi.b #9,d0
        bne M4CnBaTableIdx
        moveq #0,d0
M4CnBaTableIdx:
        move.b d0,X_CNSW(a0)
        lea M4CnBaTyTab,a3
        adda.w d4,a3
        moveq #1,d0
M4CnBaTableKid:
        jsr M4BsChild
        beq M4CnBaTableNext
        move.b (a3),X_SBYTE3(a2)
M4CnBaTableNext:
        addq.l #1,a3
        addq.b #1,d0
        cmpi.b #4,d0
        bne M4CnBaTableKid
; 07:A13C: keeprelto_player 1F:DB21 (z += $14EC - pviewvelz), sflag3 =
; no cup left, addvecs, addplayerZ.
M4CnBaCont:
        move.w 10(a1),d0
        sub.w M4_LP_PVIEWVZ,d0
        add.w d0,4(a0)
        bclr #CN_BA_SFLAG3,X_CNFL(a0)
        moveq #4,d0
        jsr M4BsChild
        bne M4CnBaContMove
        moveq #5,d0
        jsr M4BsChild
        bne M4CnBaContMove
        moveq #6,d0
        jsr M4BsChild
        bne M4CnBaContMove
        bset #CN_BA_SFLAG3,X_CNFL(a0)
M4CnBaContMove:
        jsr M4EnMove
        jsr M4EnAddPZ
        moveq #0,d0
        rts
M4CnBaTyTab: ;bossATY_tab 07:A182
        incbin '../build/M4CnBaTyTab.bin'
        even

; 07:A18B bossAexp: boss_dying (first time: $14D5 $10, $14DF $20, $14D8
; $40; sound and music $F1 not ported), sbyte2 = 30, expstrat A1D1: every
; even gameframe a large explosion at x + 4*sext(rnd), y - 4*(rnd & 31);
; addplayerZ; at 0 -> A225.
M4CnBaExp:
        tst.b M4_BOSS_DYING
        bne M4CnBaExpSet
        st M4_BOSS_DYING
        bset #5,M4_BOSS_PSTRATF
        bset #6,M4_LP_PSF
M4CnBaExpSet:
        move.b #30,37(a0)
        move.l #M4CnBaExpTick,X_EXP(a0)
M4CnBaExpTick:
        tst.b 37(a0)
        beq M4CnBaExp2
        subq.b #1,37(a0)
        btst #0,M4_LV_GAMEFRAME+1
        bne M4CnBaExpPZ
        jsr M4FxLarge
        beq M4CnBaExpPZ
        jsr M4IntroRandom
        ext.w d0
        asl.w #2,d0
        add.w d0,(a2)
        jsr M4IntroRandom
        andi.w #31,d0
        asl.w #2,d0
        sub.w d0,2(a2)
M4CnBaExpPZ:
        jsr M4EnAddPZ
        moveq #0,d0
        rts
; 07:A225: body shape boss_a_3 C734, expstrat A2D4; boss_a_4 C750 (strategy
; A31C) and boss_a_5 C76C (A292) at its position; addplayerZ.
M4CnBaExp2:
        move.w #$c734,d0
        jsr M4MtSetHdr
        move.l #M4CnBaExpM,X_EXP(a0)
        move.w #$c750,d0
        jsr M4MtCreateHdr
        beq M4CnBaExp2L
        move.l (a0),(a2)
        move.w 4(a0),4(a2)
        move.l #M4CnBaExpR,32(a2)
M4CnBaExp2L:
        move.w #$c76c,d0
        jsr M4MtCreateHdr
        beq M4CnBaExpPZ
        move.l (a0),(a2)
        move.w 4(a0),4(a2)
        move.l #M4CnBaExpL,32(a2)
        bra M4CnBaExpPZ
; 07:A2D4 (expstrat): v = (0, -10, 0), then A2F8: addvecs, addplayerZ; y >=
; 60 -> bossbigoutexplode 06:EC68; else vy += 1.
M4CnBaExpM:
        clr.w 6(a0)
        move.w #-10,8(a0)
        clr.w 10(a0)
        move.l #M4CnBaExpMTick,X_EXP(a0)
M4CnBaExpMTick:
        jsr M4EnMove
        jsr M4EnAddPZ
        cmpi.w #60,2(a0)
        blt.s *+8
        jmp M4BossBigOut ;far label (level_boss.asm)
        addq.w #1,8(a0)
        moveq #0,d0
        rts
; 07:A292 / 07:A31C: v = (-10 / +10, 0, 20), sbyte2 60 / 65, roty $80;
; then addvecs, addplayerZ, sbyte2 == 0 -> bigexplode 06:F0D0, else
; sbyte2-- and roty +1 / -1.
M4CnBaExpL:
        move.w #-10,6(a0)
        moveq #60,d1
        move.l #M4CnBaExpLTick,d3
        bra M4CnBaExpSide
M4CnBaExpR:
        move.w #10,6(a0)
        moveq #65,d1
        move.l #M4CnBaExpRTick,d3
M4CnBaExpSide:
        clr.w 8(a0)
        move.w #20,10(a0)
        move.l d3,32(a0)
        move.b d1,37(a0)
        move.b #$80,13(a0)
        movea.l d3,a2
        jmp (a2)
M4CnBaExpLTick:
        moveq #1,d2
        bra M4CnBaExpSideTick
M4CnBaExpRTick:
        moveq #-1,d2
M4CnBaExpSideTick:
        jsr M4EnMove
        jsr M4EnAddPZ
        tst.b 37(a0)
        bne.s *+8
        jmp M4FxBigExplode ;far label
        subq.b #1,37(a0)
        add.b d2,13(a0)
        moveq #0,d0
        rts

; ---------------------------------------------------------------------
; Cups 07:A35E/A365/A36C: sbyte2 = 1/2/3 (the turret under it), invisible,
; animframe 0|$80, colltype $40, no zremove, rotx $C0, roty $80, strategy
; A3D0, hitflash, expstrat A60F, HP 24, AP 16, nohitaffect, shadow;
; initpos A87C. rtl.
M4StratBaCupL:
        moveq #1,d1
        bra M4CnBaCupInit
M4StratBaCupM:
        moveq #2,d1
        bra M4CnBaCupInit
M4StratBaCupR:
        moveq #3,d1
M4CnBaCupInit:
        move.b d1,37(a0)
        bset #1,49(a0)
        bset #3,X2_FL4(a0)
        move.b #$80,16(a0)
        ori.b #$40,44(a0)
        bclr #3,45(a0)
        move.b #$c0,12(a0)
        move.b #$80,13(a0)
        move.l #M4CnBaCupTick,32(a0)
        move.l #M4LcHitFlash,X_COLL(a0)
        move.l #M4CnBaCupDie,X_EXP(a0)
        move.b #24,38(a0)
        move.b #16,39(a0)
        bset #SF_NOHITAFFECT,49(a0)
        bset #F2_SHADOW,48(a0)
        bsr M4CnBaCupPos
        moveq #0,d0
        rts
; A87C: rotz = mother roty, position = its turret's + (0, -60, -8).
M4CnBaCupPos:
        move.w X_ALPTR(a0),d0
        beq M4CnBaCupPosDone
        movea.w d0,a2
        move.b 13(a2),14(a0)
        bsr M4CnBaTurret
        beq M4CnBaCupPosDone
        move.l (a2),(a0)
        move.w 4(a2),4(a0)
        subi.w #60,2(a0)
        subq.w #8,4(a0)
M4CnBaCupPosDone:
        rts
; A8A3: a2 = child sbyte2 of the mother (the turret), Z when none.
M4CnBaTurret:
        move.w X_ALPTR(a0),d0
        beq M4CnBaTurretNone
        movea.w d0,a2
        move.l d1,-(sp)
        move.b 37(a0),d0
        jsr M4PvFindChild ;a2 = mother -> child d0 (find_child 1F:DC40)
        move.l (sp)+,d1
        cmpa.w #0,a2
        rts
M4CnBaTurretNone:
        suba.l a2,a2
        rts
; A60F: the mother's sflag2 (cup strategy finished), then explode_Istrat.
M4CnBaCupDie:
        bsr M4CnBaCupDone
        jmp M4LevelExplode
; Mother sflag2 (cup strategy finished).
M4CnBaCupDone:
        move.w X_ALPTR(a0),d0
        beq M4CnBaCupDoneX
        movea.w d0,a2
        bset #F2_SFLAG2,48(a2)
M4CnBaCupDoneX:
        rts
; A6A3 / A706 / A769: x Achase16 n 2 the turret x, y Achase16 n 3 the turret
; y + d6, z Achase16 n 2 the turret z. d6 = -440 / -280 / -60. Z when the
; turret is gone (positions untouched).
M4CnBaCupGoto:
        bsr M4CnBaTurret
        beq M4CnBaCupGotoNone
        move.l a2,-(sp)
        move.w (a0),d0
        move.w (a2),d1
        moveq #2,d2
        jsr M4LpAchase
        move.w d0,(a0)
        movea.l (sp),a2
        move.w 2(a0),d0
        move.w 2(a2),d1
        add.w d6,d1
        moveq #3,d2
        jsr M4LpAchase
        move.w d0,2(a0)
        movea.l (sp),a2
        move.w 4(a0),d0
        move.w 4(a2),d1
        moveq #2,d2
        jsr M4LpAchase
        move.w d0,4(a0)
        movea.l (sp)+,a2
        moveq #1,d0 ;NZ
M4CnBaCupGotoNone:
        rts
; d1.b target, d2 n: rotx Achase8.
M4CnBaCupRotx:
        move.b 12(a0),d0
        jsr M4EnChase8
        move.b d0,12(a0)
        rts
; 07:A3D0 cup strategy: visible; then each state block in order (a block
; may change the state for the next ones in the same tick).
M4CnBaCupTick:
        bclr #1,49(a0)
        bclr #3,X2_FL4(a0)
        tst.b X_STATE(a0)
        bne M4CnBaCupS1
        bsr M4CnBaCupPos
M4CnBaCupS1: ;UP: vel 0, open, toward turret - 440, rotz += 20, rotx -> $C0
        cmpi.b #CN_BA_UP,X_STATE(a0)
        bne M4CnBaCupS5
        clr.b 15(a0)
        bsr M4CnBaCupOpen
        move.w #-440,d6
        bsr M4CnBaCupGoto
        addi.b #20,14(a0)
        move.b #$c0,d1
        moveq #3,d2
        bsr M4CnBaCupRotx
        bsr M4CnBaTurret ;the turret can be hit (nohitaffect cleared)
        beq M4CnBaCupS5
        bclr #SF_NOHITAFFECT,49(a2)
M4CnBaCupS5: ;IROTATE
        cmpi.b #CN_BA_IROTATE,X_STATE(a0)
        bne M4CnBaCupS6
        move.b #CN_BA_ROTATE,X_STATE(a0)
        move.b #40,X_CNSW(a0)
        bclr #SF_NOHITAFFECT,49(a0)
M4CnBaCupS6: ;ROTATE: toward turret - 280, rotx -> 0, rotz += 28, 40 ticks
        cmpi.b #CN_BA_ROTATE,X_STATE(a0)
        bne M4CnBaCupS2
        move.w #-280,d6
        bsr M4CnBaCupGoto
        moveq #0,d1
        moveq #3,d2
        bsr M4CnBaCupRotx
        addi.b #28,14(a0)
        subq.b #1,X_CNSW(a0)
        bne M4CnBaCupS2
        bsr M4CnBaCupDone
        move.b #CN_BA_UP,X_STATE(a0)
        bset #SF_NOHITAFFECT,49(a0)
M4CnBaCupS2: ;GO: at the player
        cmpi.b #CN_BA_GO,X_STATE(a0)
        bne M4CnBaCupS3
        bclr #SF_NOHITAFFECT,49(a0) ;(sound $66 when it was set: not ported)
        moveq #45,d0
        moveq #1,d1
        jsr M4EnSpeedTo
        movea.l a1,a2
        jsr M4EnZD
        subi.w #1000,d0
        bmi M4CnBaCupGoRot
        jsr M4EnPitchTo
        move.b d0,d1
        move.b X_SBYTE4(a0),d0
        moveq #3,d2
        jsr M4EnChase8
        move.b d0,X_SBYTE4(a0)
        jsr M4EnYawTo
        move.b d0,d1
        move.b X_SBYTE3(a0),d0
        moveq #3,d2
        jsr M4EnChase8
        move.b d0,X_SBYTE3(a0)
M4CnBaCupGoRot:
        moveq #0,d1
        moveq #2,d2
        bsr M4CnBaCupRotx
        addi.b #28,14(a0)
        move.w 4(a0),d0
        sub.w 4(a1),d0
        bpl M4CnBaCupS3
        movea.l a1,a2
        jsr M4EnZD
        subi.w #200,d0
        bmi M4CnBaCupS3
        move.w #-400,2(a0)
        move.b #CN_BA_RETURN,X_STATE(a0)
        move.b #30,X_CNSW(a0)
M4CnBaCupS3: ;RETURN: as UP, 30 ticks, then the mother's sflag2 and UP
        cmpi.b #CN_BA_RETURN,X_STATE(a0)
        bne M4CnBaCupS4
        bset #SF_NOHITAFFECT,49(a0)
        clr.b 15(a0)
        move.w #-440,d6
        bsr M4CnBaCupGoto
        addi.b #20,14(a0)
        move.b #$c0,d1
        moveq #3,d2
        bsr M4CnBaCupRotx
        subq.b #1,X_CNSW(a0)
        bne M4CnBaCupS4
        bsr M4CnBaCupDone
        move.b #CN_BA_UP,X_STATE(a0)
M4CnBaCupS4: ;DOWN: close, toward turret - 60, rotz -> 0, rotx -> $C0
        cmpi.b #CN_BA_DOWN,X_STATE(a0)
        bne M4CnBaCupMove
        bsr M4CnBaCupClose
        bsr M4CnBaCupDown
        move.b 14(a0),d0
        moveq #0,d1
        moveq #3,d2
        jsr M4EnChase8
        move.b d0,14(a0)
        move.b #$c0,d1
        moveq #3,d2
        bsr M4CnBaCupRotx
; A5E9: boss bar += HP; gen_3dvecs (vel, sbyte3, sbyte4); addvecs;
; addplayerZ.
M4CnBaCupMove:
        move.b 38(a0),d0
        add.b d0,M4_BOSS_HP
        moveq #0,d0
        move.b 15(a0),d0
        ext.w d0
        move.b X_SBYTE4(a0),d1
        move.b X_SBYTE3(a0),d2
        jsr M4EnVector
        move.w d3,6(a0)
        move.w d4,8(a0)
        move.w d5,10(a0)
        jsr M4EnMove
        jsr M4EnAddPZ
        moveq #0,d0
        rts
; A769 DOWN: as A6A3 with -60; then y >= turret y - 80 (N clear): the turret
; is nohitaffect again with HP 12 and, when it was invisible (destroyed),
; visible again and the mother's sbyte3 (turrets down) - 1.
M4CnBaCupDown:
        move.w #-60,d6
        bsr M4CnBaCupGoto
        beq M4CnBaCupDownDone
        move.w 2(a2),d0
        subi.w #80,d0
        move.w 2(a0),d1
        sub.w d0,d1
        bmi M4CnBaCupDownDone
        bset #SF_NOHITAFFECT,49(a2)
        move.b #12,38(a2)
        btst #3,X2_FL4(a2)
        beq M4CnBaCupDownDone
        bclr #3,X2_FL4(a2)
        bclr #1,49(a2)
        move.w X_ALPTR(a0),d0
        beq M4CnBaCupDownDone
        movea.w d0,a2
        subq.b #1,X_SBYTE3(a2)
M4CnBaCupDownDone:
        rts
; A816 open / A848 close: on even gameframes animframe +1 up to 6 / -1 down
; to 0 (mod 7 arithmetic of the original).
M4CnBaCupOpen:
        moveq #$7f,d0
        and.b 16(a0),d0
        cmpi.b #6,d0
        beq M4CnBaCupAnimDone
        btst #0,M4_LV_GAMEFRAME+1
        bne M4CnBaCupAnimDone
        move.b 16(a0),d0
        addq.b #1,d0
        bmi M4CnBaCupAnimM
        addq.b #7,d0
        bra M4CnBaCupAnimM
M4CnBaCupClose:
        moveq #$7f,d0
        and.b 16(a0),d0
        beq M4CnBaCupAnimDone
        btst #0,M4_LV_GAMEFRAME+1
        bne M4CnBaCupAnimDone
        move.b 16(a0),d0
        subq.b #1,d0
        bmi M4CnBaCupAnimM
        addq.b #7,d0
M4CnBaCupAnimM:
        andi.b #$7f,d0
        cmpi.b #7,d0
        blo M4CnBaCupAnimSet
        subq.b #7,d0
M4CnBaCupAnimSet:
        ori.b #$80,d0
        move.b d0,16(a0)
M4CnBaCupAnimDone:
        rts

; ---------------------------------------------------------------------
; Turrets 07:A8B5 (L: offsets -85, -50), A8D2 (M: 0, -40), A8F3 (R: 85,
; -50); Icont A900: hitflash, expstrat AAAA, HP 12, AP 16, sbyte3 0, sbyte2
; 60, colldisable, nohitaffect, colltype $40; the strategy runs at once
; (1F:DC25).
M4StratBaTurretL:
        move.l #M4CnBaTurretLTick,32(a0)
        bra M4CnBaTurretInit
M4StratBaTurretM:
        move.l #M4CnBaTurretMTick,32(a0)
        bra M4CnBaTurretInit
M4StratBaTurretR:
        move.l #M4CnBaTurretRTick,32(a0)
M4CnBaTurretInit:
        move.l #M4LcHitFlash,X_COLL(a0)
        move.l #M4CnBaTurretDie,X_EXP(a0)
        move.b #12,38(a0)
        move.b #16,39(a0)
        clr.b X_SBYTE3(a0)
        move.b #60,37(a0)
        bset #SF_COLLDISABLE,49(a0)
        bset #SF_NOHITAFFECT,49(a0)
        ori.b #$40,44(a0)
        movea.l 32(a0),a2
        jmp (a2)
M4CnBaTurretLTick:
        moveq #-85,d3
        moveq #-50,d4
        bra M4CnBaTurretTick
M4CnBaTurretMTick:
        moveq #0,d3
        moveq #-40,d4
        bra M4CnBaTurretTick
M4CnBaTurretRTick:
        moveq #85,d3
        moveq #-50,d4
; A952: visible and hittable: boss bar += HP; roty in [$60, $A0] (signed
; byte differences): colldisable and Hplasma from (0, -10, 0) with roty
; -8 at gameframe & 31 = 15 / +8 at 30 (al_ptr player); otherwise
; colldisable cleared. Then roty Achase8 n 3 toward sbyte3; with the
; mother's sbyte3 == 2, every sbyte2 ticks sflag1 toggles the target
; ($80 for 60 ticks / 0 for 20). Position: mother + 4*(rot_y8(dx, 0, mother
; roty), dy) (1F:C97B).
M4CnBaTurretTick:
        move.w X_ALPTR(a0),d0
        beq M4CnBaTurretDone
        movea.w d0,a4
        btst #3,X2_FL4(a0)
        bne M4CnBaTurretAim
        move.b 38(a0),d0
        add.b d0,M4_BOSS_HP
        btst #SF_NOHITAFFECT,49(a0)
        bne M4CnBaTurretAim
        move.b 13(a0),d0
        subi.b #$60,d0
        bmi M4CnBaTurretOff
        move.b 13(a0),d0
        cmpi.b #$a0,d0
        beq M4CnBaTurretOn
        subi.b #$a0,d0
        bpl M4CnBaTurretOff
M4CnBaTurretOn:
        bset #SF_COLLDISABLE,49(a0)
        move.w M4_LV_GAMEFRAME,d0
        andi.w #31,d0
        moveq #-8,d7
        cmpi.w #15,d0
        beq M4CnBaTurretFire
        moveq #8,d7
        cmpi.w #30,d0
        bne M4CnBaTurretAim
M4CnBaTurretFire:
        movem.l d3-d4/a4,-(sp)
        moveq #M4_WT_HPLASMA,d0
        moveq #0,d3
        moveq #-10,d4
        moveq #0,d5
        moveq #0,d6
        suba.l a3,a3
        jsr M4EnFire
        cmpa.w #0,a2
        beq M4CnBaTurretFired
        move.w a1,X_ALPTR(a2)
M4CnBaTurretFired:
        movem.l (sp)+,d3-d4/a4
        bra M4CnBaTurretAim
M4CnBaTurretOff:
        bclr #SF_COLLDISABLE,49(a0)
M4CnBaTurretAim:
        movem.l d3-d4,-(sp)
        move.b 13(a0),d0
        move.b X_SBYTE3(a0),d1
        moveq #3,d2
        jsr M4EnChase8
        move.b d0,13(a0)
        movem.l (sp)+,d3-d4
        cmpi.b #2,X_SBYTE3(a4)
        bne M4CnBaTurretPlace
        subq.b #1,37(a0)
        bne M4CnBaTurretPlace
        bchg #F2_SFLAG1,48(a0)
        beq M4CnBaTurretTo0 ;was clear: now set
        clr.b X_SBYTE3(a0)
        move.b #20,37(a0)
        bra M4CnBaTurretPlace
M4CnBaTurretTo0:
        move.b #$80,X_SBYTE3(a0)
        move.b #60,37(a0)
M4CnBaTurretPlace:
        move.b d4,d6 ;dy
        moveq #0,d4 ;z offset 0
        move.b 13(a4),d5
        neg.b d5
        jsr M4WeaponRotatePair
        ext.w d3
        ext.w d4
        asl.w #2,d3
        asl.w #2,d4
        ext.w d6
        asl.w #2,d6
        add.w (a4),d3
        add.w 2(a4),d6
        add.w 4(a4),d4
        move.w d3,(a0)
        move.w d6,2(a0)
        move.w d4,4(a0)
M4CnBaTurretDone:
        moveq #0,d0
        rts
; 07:AAAA: invisible, a large explosion (sound flag cleared), HP $FF,
; colldisable, the mother's sbyte3 (turrets down) + 1. No strategy change:
; the turret stays (invisible) as a child.
M4CnBaTurretDie:
        bset #1,49(a0)
        bset #3,X2_FL4(a0)
        jsr M4FxLarge
        beq M4CnBaTurretDie2
        bclr #F2_NOEXPSND,48(a2)
M4CnBaTurretDie2:
        move.b #$ff,38(a0)
        bset #SF_COLLDISABLE,49(a0)
        move.w X_ALPTR(a0),d0
        beq M4CnBaTurretDie3
        movea.w d0,a2
        addq.b #1,X_SBYTE3(a2)
M4CnBaTurretDie3:
        moveq #0,d0
        rts

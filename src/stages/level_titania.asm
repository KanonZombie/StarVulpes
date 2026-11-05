; Stage unit: Titania (0D:DFA7, route 2 stage 3) and Fortuna (0D:E651, route
; 3 stage 3). Strategies (table searched by M4LevelFindStrategy,
; level_objects.asm), helpers and effects of these stages. Stage data:
; tools/stages/titania.py. Every routine was re-read in the ROM bytes
; (tools/dis65816.py, build/agent-titania/dis/) and is compared tick by tick
; with the ROM by build/agent-titania/titania-compare.py
; (build/agent-titania/TITANIA.md).
; Conventions of level_objects.asm / level_enemies.asm: a0 object, a1
; player; d0 = 0 keep / nonzero deferred removal (1F:D501). "d < K" is the N
; bit of the 16-bit difference. ROM sflags2 ($1E): colldisable $01 = bit 0 of
; 49(a0); sflag1 $10 / sflag2 $20 = F2_SFLAG1 / F2_SFLAG2 (48(a0)). Sounds
; (03:B7E5 trigse, 03:B705/B71D door sounds, set_sound2 $1CE9) are not
; ported. Shapes are found by ROM header (M4LevelShapeIndex); every shape
; change also writes X_SHAPEHDR (find_y_l 09:B1FF compares it).
; Shared helpers reused from other stage units: M4MtFog, M4MtTankLR,
; M4MtTankFire, M4MtCreateHdr, M4MtSetHdr, M4MtSmarkExplode
; (level_meteor.asm), M4MbWoodsGo (woodsgo_strat 08:B840, level_macbeth.asm).
; RAM: $FF9840..$FF987F (reserved for this unit).
M4_TITANIA equ $ff9840
M4_TI_SPHEAD equ M4_TITANIA+0 ;.w sprouthead $1FEA (shape header)
M4_TI_SPBODY equ M4_TITANIA+2 ;.w sproutbody $1FEC
M4_TI_SPTAIL equ M4_TITANIA+4 ;.w sprouttail $1FEE (set only by lochness)
M4_TI_SPIHP equ M4_TITANIA+6 ;.b sproutiHP $1FF0
M4_TI_SPSTRAT equ M4_TITANIA+8 ;.l sproutstrat $1FF1 (port routine of the Istrat2)
X_MTIDX_TI equ -$8000+38 ;.w = X_MTIDX of level_meteor.asm (M4MtFog)
X_TISF3 equ -$8000+52 ;.b ROM sflags3 $1F bits sflag5 $01, sflag6 $02, sflag7 $04
; Other ROM sprout flags: sflag1/2 = F2_SFLAG1/2 (48), sflag3/4 = X2_FL2 bits
; 6/7 (as level_macbeth.asm), sflag8 = X2_FL4 bit 5, nohitaffect = 49 bit 5.
TI_SF3 equ 6 ;X2_FL2 bit (sflags2 $40)
TI_SF4 equ 7 ;X2_FL2 bit (sflags2 $80)
TI_SF8 equ 5 ;X2_FL4 bit (sflags4 $20)

M4StrategiesTitania:
        dc.l $08b69f,M4StratTiMisstank
        dc.l $0a8cfc,M4StratTiTank3
        dc.l $04f870,M4StratTiMassiveBase
        dc.l $04f8f9,M4StratTiKdoor2
        dc.l $04f8ff,M4StratTiKdoor
        dc.l $04f9c0,M4StratNoColl ;kichi2 04:F9C0: jml nocoll_Istrat 06:873F
        dc.l $06c70a,M4StratTiClBridgeA ;cl_bridge friends' ships
        dc.l $06c75d,M4StratTiClBridgeB
        dc.l $06c7b0,M4StratTiClBridgeC
        dc.l $08c777,M4StratTiTorpedo ;Titania and Fortuna
        dc.l $0af2b3,M4StratTiSeaMon
        dc.l $04ee15,M4StratTiBossG
        dc.l $099997,M4StratTiLochNess ;Fortuna sprouts
        dc.l $0999a9,M4StratTiSeaDragon2
        dc.l $0999ad,M4StratTiSeaDragon ;child of the mapmother 05:9CBC (05:D7EE)
        dc.l $099a70,M4StratTiTree3
        dc.l $099a78,M4StratTiTree2
        dc.l $099b37,M4StratTiTree1
        dc.l 0

; ---------------------------------------------------------------------
; Helpers.

; d1.w = gameframe + al1pt ($15BD + $123C; the caller masks the low byte):
; al1pt is the original-like record address of M4B1Al1pt (level_boss1.asm).
M4TiPhase:
        jsr M4B1Al1pt
        add.w M4_LV_GAMEFRAME,d1
        rts

; makeSsplash 06:8C1A (AEB5) / makesplash 06:8C31 (AED1): a camera-facing
; ssprite at the object (z - 5), depthoffset 0, tx 0 (sflags3 realobj
; cleared: no port equivalent), strategy 06:8C97 (it runs in this same
; traversal, linked behind its creator). Returns a2 (Z on failure).
; Registers kept except d0/a2.
M4TiSsplash:
        move.w #$aeb5,d0
        bra.s M4TiSplashMake
M4TiSplash:
        move.w #$aed1,d0
M4TiSplashMake:
        jsr M4MtCreateHdr
        beq.s M4TiSplashDone
        move.l a0,-(sp)
        movea.l a2,a0
        jsr M4EnFaceCamera
        movea.l (sp)+,a0
        move.l (a0),(a2)
        move.w 4(a0),4(a2)
        subq.w #5,4(a2)
        move.l #M4TiSplashInit,32(a2)
        bset #F2_SPRITE,48(a2)
        clr.b X_DEPTHOFF(a2)
        clr.b X_TX(a2)
        cmpa.w #0,a2
M4TiSplashDone:
        rts
; 06:8C97: colldisable, colframe $80, strategy 8CB6, addplayerZ. 8CB6:
; addplayerZ; colframe + 1 mod 7; reaching 7 it stays 6 and is removed.
M4TiSplashInit:
        bset #SF_COLLDISABLE,49(a0)
        move.b #$80,18(a0)
        move.l #M4TiSplashTick,32(a0)
        jsr M4EnAddPZ
        moveq #0,d0
        rts
M4TiSplashTick:
        jsr M4EnAddPZ
        move.b 18(a0),d0
        addq.b #1,d0
        bmi.s M4TiSplashMod
        addq.b #7,d0
M4TiSplashMod:
        andi.b #$7f,d0
        cmpi.b #7,d0
        bhs.s M4TiSplashEnd
        ori.b #$80,d0
        move.b d0,18(a0)
        moveq #0,d0
        rts
M4TiSplashEnd:
        move.b #$86,18(a0)
        moveq #1,d0
        rts

; d0 = ZD(player a1, a0) (09:80A7 dzdistless: C = N(ZD - K)).
M4TiZD:
        move.l a2,-(sp)
        movea.l a1,a2
        jsr M4EnZD
        movea.l (sp)+,a2
        rts

; ---------------------------------------------------------------------
; misstank 08:B69F (m_tank, the missile launcher truck): strategy B728,
; hitflash 06:89A3 / misstankexp B682, HP 4 AP 8; small_m B4BE (make_obj
; 1F:D54B) as al_ptr: rotx $F8, enemy1, no strategy, normcollptrs (1F:D435),
; HP 4 AP 4; the truck Zenemy ($01). Then enemy1, vel 30, sbyte1 20 and the
; tick in the same call.
M4StratTiMisstank:
        move.l #M4TiMisstankTick,32(a0)
        move.l #M4LcHitFlash,X_COLL(a0)
        move.l #M4TiMisstankExp,X_EXP(a0)
        move.b #4,38(a0)
        move.b #8,39(a0)
        move.w #$b4be,d0
        jsr M4MtCreateHdr
        beq.s M4TiMisstankNoMiss
        move.w a2,X_ALPTR(a0)
        move.b #$f8,12(a2)
        ori.b #CF_ENEMY1,44(a2)
        ori.b #$01,44(a0)
        clr.l 32(a2)
        move.l #M4LcHitFlash,X_COLL(a2)
        move.l #M4LevelExplode,X_EXP(a2)
        move.b #4,38(a2)
        move.b #4,39(a2)
M4TiMisstankNoMiss:
        ori.b #CF_ENEMY1,44(a0)
        move.b #30,15(a0)
        move.b #20,36(a0)
; B728: sbyte1 counts down; at 0 roty = Achase8_3(roty, $80) and
; addplayerZ every tick. Until sflag1: the missile (al_ptr) takes roty and
; the position, y - 85; ZD < 1000 -> missile strategy woodsgo B840, sbyte2
; 40, vel 60, sflag1. Then (vx, vz) = gen2d(vel, roty), pos += v.
M4TiMisstankTick:
        tst.b 36(a0)
        beq.s M4TiMisstankFace
        subq.b #1,36(a0)
        bra.s M4TiMisstankMiss
M4TiMisstankFace:
        move.b 13(a0),d0
        move.b #$80,d1
        moveq #3,d2
        jsr M4EnChase8
        move.b d0,13(a0)
        jsr M4EnAddPZ
M4TiMisstankMiss:
        btst #F2_SFLAG1,48(a0)
        bne.s M4TiMisstankMove
        movea.w X_ALPTR(a0),a2
        move.b 13(a0),13(a2)
        move.l (a0),(a2)
        move.w 4(a0),4(a2)
        addi.w #-85,2(a2)
        bsr M4TiZD
        cmpi.w #1000,d0
        bpl.s M4TiMisstankMove
        movea.w X_ALPTR(a0),a2
        move.l #M4MbWoodsGo,32(a2)
        move.b #40,37(a2)
        move.b #60,15(a2)
        bset #F2_SFLAG1,48(a0)
M4TiMisstankMove:
        jsr M4EnGen2d
        jsr M4EnMove
        moveq #0,d0
        rts
; misstankexp B682: unless sflag1 (missile launched), the missile is killed
; (colldisable, HP 0); then smarkexplode 06:F046.
M4TiMisstankExp:
        btst #F2_SFLAG1,48(a0)
        bne.s M4TiMisstankExpMark
        movea.w X_ALPTR(a0),a2
        bset #SF_COLLDISABLE,49(a2)
        clr.b 38(a2)
M4TiMisstankExpMark:
        jmp M4MtSmarkExplode

; ---------------------------------------------------------------------
; tank3 0A:8CFC (s_tank_0 with fog): the Istrat (sword1 = shape, strategy
; = itself, normcollptrs, HP 2 AP 16, roty 0) repeats while ZD >= 1800
; with sbyte2 11, sbyte3 15; then 8D59 in the same call.
M4StratTiTank3:
        move.w X_SHAPEHDR(a0),40(a0)
        move.w 46(a0),X_MTIDX_TI(a0)
        move.l #M4StratTiTank3,32(a0)
        jsr M4LvNormPtrs
        move.b #2,38(a0)
        move.b #16,39(a0)
        clr.b 13(a0)
        bsr M4TiZD
        cmpi.w #1800,d0
        bmi.s M4TiTank3FwdSet
        move.b #11,37(a0)
        move.b #15,X_SBYTE3(a0)
        moveq #0,d0
        rts
M4TiTank3FwdSet:
        move.l #M4TiTank3Fwd,32(a0)
; 8D59 / 8E6F (forward, forward b): ZD >= 2100 -> back; else lr 8C38, fog,
; fire 8C6A, speedto(85, 2), gen3d, move, z += 25.
M4TiTank3Fwd:
        lea M4TiTank3Back,a2
        bra.s M4TiTank3Forward
M4TiTank3FwdB:
        lea M4TiTank3BackB,a2
M4TiTank3Forward:
        bsr M4TiZD
        cmpi.w #2100,d0
        bmi.s M4TiTank3Go
        move.l a2,32(a0)
        jmp (a2)
M4TiTank3Go:
        jsr M4MtTankLR
        jsr M4MtFog
        jsr M4MtTankFire
        moveq #85,d0
        bsr.s M4TiTank3Move
        addi.w #25,4(a0)
        moveq #0,d0
        rts
; 8DEA (back): lr, fog, fire, speedto(45, 2), gen3d, move; ZD < 1960 ->
; forward b 8E62, which runs at once (8E6F in the same call).
M4TiTank3Back:
        jsr M4MtTankLR
        jsr M4MtFog
        jsr M4MtTankFire
        moveq #45,d0
        bsr.s M4TiTank3Move
        bsr M4TiZD
        cmpi.w #1960,d0
        bpl.s M4TiTank3Done
        move.l #M4TiTank3FwdB,32(a0)
        bra M4TiTank3FwdB
M4TiTank3Done:
        moveq #0,d0
        rts
; 8F00 (back b): fog only.
M4TiTank3BackB:
        jsr M4MtFog
        moveq #0,d0
        rts
; speedto(d0, 2) 1F:D60D, gen_3dvecs 1F:D5A7, addvecs 1F:C7BB.
M4TiTank3Move:
        moveq #2,d1
        jsr M4EnSpeedTo
        jsr M4EnGen3d
        jmp M4EnMove

; ---------------------------------------------------------------------
; massivebase 04:F870 (kichi_0, the base entrance): strategy F89E, no
; coll/exp pointers (1F:D450), colldisable, HP $FF AP 8, roty $80,
; maptrigger $176F = 0, no zremove.
M4StratTiMassiveBase:
        move.l #M4TiMassiveTick,32(a0)
        jsr M4LvZeroPtrs
        bset #SF_COLLDISABLE,49(a0)
        move.b #$ff,38(a0)
        move.b #8,39(a0)
        move.b #$80,13(a0)
        clr.b M4_MV_176F
        bclr #3,45(a0)
; F89E: ZD < 3000: player control off (pshipflags $14D8 |= $60), player x =
; Achase16_4(x, 0), y = Achase16_4(y, viewCY $158B). Shape kichi_0 CB24
; while ZD < $3500, else kichi_1 CB40.
M4TiMassiveTick:
        bsr M4TiZD
        cmpi.w #3000,d0
        bpl.s M4TiMassiveShape
        ori.b #$60,M4_LP_PSF
        move.w (a1),d0
        moveq #0,d1
        moveq #4,d2
        jsr M4LpAchase
        move.w d0,(a1)
        move.w 2(a1),d0
        move.w M4_LP_VIEWCY,d1
        moveq #4,d2
        jsr M4LpAchase
        move.w d0,2(a1)
M4TiMassiveShape:
        bsr M4TiZD
        move.w #$cb24,d1
        cmpi.w #$3500,d0
        bmi.s M4TiMassiveSet
        move.w #$cb40,d1
M4TiMassiveSet:
        cmp.w X_SHAPEHDR(a0),d1
        beq.s M4TiMassiveDone
        move.w d1,d0
        jsr M4MtSetHdr
M4TiMassiveDone:
        moveq #0,d0
        rts

; ---------------------------------------------------------------------
; kdoor2 04:F8F9: sflag1, then kdoor 04:F8FF: strategy F925, normcollptrs,
; HP $FF AP 8, colldisable, animframe $80.
M4StratTiKdoor2:
        bset #F2_SFLAG1,48(a0)
M4StratTiKdoor:
        move.l #M4TiKdoorTick,32(a0)
        jsr M4LvNormPtrs
        move.b #$ff,38(a0)
        move.b #8,39(a0)
        bset #SF_COLLDISABLE,49(a0)
        move.b #$80,16(a0)
; F925: ZD >= 600: close (frame 7 -> sound; frame 0 -> nothing; else frame
; - 1 mod 8). ZD < 600: open (frame 0 -> sound), frame + 1; reaching 8 it
; stays 7 and F99D: kdoor2 gives the control back ($14D8 &= $1F) and removes
; the first kichi_0 CB24 of allst (find_y_l 09:B1FF, remove_obj 1F:D540).
M4TiKdoorTick:
        bsr M4TiZD
        cmpi.w #600,d0
        bmi.s M4TiKdoorOpen
        move.b 16(a0),d0
        andi.b #$7f,d0
        beq.s M4TiKdoorDone
        move.b 16(a0),d0
        moveq #8,d1
        jsr M4MtAfDec
        move.b d0,16(a0)
        bra.s M4TiKdoorDone
M4TiKdoorOpen:
        move.b 16(a0),d0
        addq.b #1,d0
        bmi.s M4TiKdoorMod
        addq.b #8,d0
M4TiKdoorMod:
        andi.b #$7f,d0
        cmpi.b #8,d0
        bhs.s M4TiKdoorEnd
        ori.b #$80,d0
        move.b d0,16(a0)
        bra.s M4TiKdoorDone
M4TiKdoorEnd:
        move.b #$87,16(a0)
        btst #F2_SFLAG1,48(a0)
        beq.s M4TiKdoorDone
        andi.b #$1f,M4_LP_PSF
        move.w #$cb24,d1
        bsr M4TiFindHdr
        beq.s M4TiKdoorDone
        move.l a0,-(sp)
        movea.l a2,a0
        jsr M4LevelRemove
        movea.l (sp)+,a0
M4TiKdoorDone:
        moveq #0,d0
        rts

; ---------------------------------------------------------------------
; Friends' ships of cl_bridge (0D:EB76). Istrats 06:C70A (a), 06:C75D (b),
; 06:C7B0 (c): shadow, no zremove; a: rotz $C0, roty $20, sword1 70; b: rotz
; $40, roty $E0, sword1 110; c: sword1 60. Every tick x = Achase16_4(x, TX)
; (-70 / 70 / 0) and the common body 06:C7FB with dZ -100/-200/-300 and dY
; 20/20/30 (svar_word2/3 $151F/$1521).
M4StratTiClBridgeA:
        move.b #$c0,14(a0)
        move.b #$20,13(a0)
        move.w #70,40(a0)
        bsr.s M4TiClBridgeInit
        move.l #M4TiClBridgeATick,32(a0)
M4TiClBridgeATick:
        moveq #-70,d1
        moveq #-100,d5
        moveq #20,d6
        bra.s M4TiClBridgeBody
M4StratTiClBridgeB:
        move.b #$40,14(a0)
        move.b #$e0,13(a0)
        move.w #110,40(a0)
        bsr.s M4TiClBridgeInit
        move.l #M4TiClBridgeBTick,32(a0)
M4TiClBridgeBTick:
        moveq #70,d1
        move.w #-200,d5
        moveq #20,d6
        bra.s M4TiClBridgeBody
M4StratTiClBridgeC:
        move.w #60,40(a0)
        bsr.s M4TiClBridgeInit
        move.l #M4TiClBridgeCTick,32(a0)
M4TiClBridgeCTick:
        moveq #0,d1
        move.w #-300,d5
        moveq #30,d6
        bra.s M4TiClBridgeBody
M4TiClBridgeInit:
        bset #F2_SHADOW,48(a0)
        bclr #3,45(a0) ;no atzremove
        rts
; 06:C7FB: sword1 0 -> clshipbridgeboost C8A5; sword1 - 1; z = Achase16_4(z,
; player.z + dZ); y = Achase16_5(y, player.y + dY); rotx = Achase8_5(rotx,
; player.rotx); even gameframe: rotz = Achase8_5(rotz, player.rotz), roty =
; Achase8_4(roty, player.roty); addplayerZ; z += psvar_word2 $1558.
M4TiClBridgeBody:
        move.w (a0),d0
        moveq #4,d2
        jsr M4LpAchase
        move.w d0,(a0)
        tst.w 40(a0)
        beq M4TiClBoostInit
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
        bne.s M4TiClBridgeOdd
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
M4TiClBridgeOdd:
        jsr M4EnAddPZ
        move.w M4_WP_W1558,d0
        add.w d0,4(a0)
        moveq #0,d0
        rts
; clshipbridgeboost 06:C8A5: strategy C8BA, sbyte1 50, vel 20. C8BA: (vx,
; vz) = gen2d(vel, roty), then vz = 0; pos += v; even gameframe: rotz - 1;
; gameframe & 7 == 0: roty - 1, rotx - 1; --sbyte1 == 0 -> engine sound off
; (pshipflags3 $14DA &= $FD) and clshipboost_I 06:C115; else addplayerZ.
M4TiClBoostInit:
        move.l #M4TiClBoostTick,32(a0)
        move.b #50,36(a0)
        move.b #20,15(a0)
M4TiClBoostTick:
        jsr M4EnGen2d
        clr.w 10(a0)
        jsr M4EnMove
        btst #0,M4_LV_GAMEFRAME+1
        bne.s M4TiClBoostRoll
        subq.b #1,14(a0)
M4TiClBoostRoll:
        moveq #7,d0
        and.w M4_LV_GAMEFRAME,d0
        bne.s M4TiClBoostCount
        subq.b #1,13(a0)
        subq.b #1,12(a0)
M4TiClBoostCount:
        subq.b #1,36(a0)
        bne.s M4TiClBoostPZ
        andi.b #$fd,M4_LP_PSF3
        jmp M4StratClshipBoost
M4TiClBoostPZ:
        jsr M4EnAddPZ
        moveq #0,d0
        rts

; ---------------------------------------------------------------------
; torpedo 08:C777 (the submerged flying fish): strategy C7A9, normcollptrs,
; HP 4 AP 4, nullshape, vel 30, colldisable, Zenemy.
M4StratTiTorpedo:
        move.l #M4TiTorpedoTick,32(a0)
        jsr M4LvNormPtrs
        move.b #4,38(a0)
        move.b #4,39(a0)
        move.w #$aca1,d0
        jsr M4MtSetHdr
        move.b #30,15(a0)
        bset #SF_COLLDISABLE,49(a0)
        ori.b #$01,44(a0)
; C7A9: small splash (8C1A) every tick; ZD < 800 -> torpedoa C821; else roty
; = Achase8_3(roty, yawTo(player)) (obj2obj_angle 1F:D021), then C806:
; gen_3dvecs, addplayerZ, addvecs.
M4TiTorpedoTick:
        bsr M4TiSsplash
        bsr M4TiZD
        cmpi.w #800,d0
        bmi.s M4TiTorpedoJump
        movea.l a1,a2
        jsr M4EnYawTo
        move.b d0,d1
        move.b 13(a0),d0
        moveq #3,d2
        jsr M4EnChase8
        move.b d0,13(a0)
M4TiTorpedoMove:
        jsr M4EnGen3d
        jsr M4EnAddPZ
        jsr M4EnMove
        moveq #0,d0
        rts
; C821: strategy C849, rotx $E0, shape f_fish CE50, a splash (8C31),
; collisions on (sound 03:B735 not ported). C849: rotx = Achase8_2(rotx, 0),
; then C806.
M4TiTorpedoJump:
        move.l #M4TiTorpedoA,32(a0)
        move.b #$e0,12(a0)
        move.w #$ce50,d0
        jsr M4MtSetHdr
        bsr M4TiSplash
        bclr #SF_COLLDISABLE,49(a0)
M4TiTorpedoA:
        move.b 12(a0),d0
        moveq #0,d1
        moveq #2,d2
        jsr M4EnChase8
        move.b d0,12(a0)
        bra.s M4TiTorpedoMove

; ---------------------------------------------------------------------
; Sea monster 0A:F2B3 (sea_0_0, the 2_3b waves around bossg): strategy
; F300, hitflash 06:89A3 / expstrat F657, HP 2 AP 4, sbyte2 = random_l,
; roty $80, colltype $40, no zremove, sbyte3 60, sbyte4 3. F300 is a
; stratstate machine ($1CDC = X_STATE) whose states run one after another
; in the same call; 1F:DB80 / 1F:DB98 set state 2 / 5 and re-run F300
; (1F:DC25). Sounds 03:B751 not ported.
M4StratTiSeaMon:
        move.l #M4TiSeaMonTick,32(a0)
        move.l #M4LcHitFlash,X_COLL(a0)
        move.l #M4TiSeaMonExp,X_EXP(a0)
        move.b #2,38(a0)
        move.b #4,39(a0)
        jsr M4IntroRandom
        move.b d0,37(a0)
        move.b #$80,13(a0)
        ori.b #$40,44(a0)
        bclr #3,45(a0)
        move.b #60,X_SBYTE3(a0)
        move.b #3,X_SBYTE4(a0)
M4TiSeaMonTick:
        tst.b X_STATE(a0)
        bne.s M4TiSmS1
; 0: colldisable; sbyte3 = 0 -> state 2 (re-run); sbyte3 - 1; speedto(20,
; 1); (vx, vz) = gen2d(vel, sbyte2), vz = -40; sbyte2 + 4; on (gameframe +
; al1pt) & 31 == 0 a splash, sbyte1 10, shape B69C, state 1.
        bset #SF_COLLDISABLE,49(a0)
        tst.b X_SBYTE3(a0)
        bne.s M4TiSm0
        move.b #2,X_STATE(a0)
        bra.s M4TiSeaMonTick
M4TiSm0:
        subq.b #1,X_SBYTE3(a0)
        moveq #20,d0
        moveq #1,d1
        jsr M4EnSpeedTo
        bsr M4TiGen2dSb2
        move.w #-40,10(a0)
        addq.b #4,37(a0)
        bsr M4TiPhase
        andi.b #$1f,d1
        bne.s M4TiSmS1
        bsr M4TiSplash
        move.b #10,36(a0)
        move.w #$b69c,d0
        jsr M4MtSetHdr
        addq.b #1,X_STATE(a0)
; 1: v = 0; --sbyte1 == 0 -> state 0, shape B680, a splash.
M4TiSmS1:
        cmpi.b #1,X_STATE(a0)
        bne.s M4TiSmS2
        clr.l 6(a0)
        clr.w 10(a0)
        subq.b #1,36(a0)
        bne.s M4TiSmS2
        clr.b X_STATE(a0)
        move.w #$b680,d0
        jsr M4MtSetHdr
        bsr M4TiSplash
; 2: collisions on, vz 0, vx = -vx, vy -15, shape B65F, a splash, pos += v;
; sbyte4 = 0 -> state 5 (re-run); sbyte4 - 1, state 3.
M4TiSmS2:
        cmpi.b #2,X_STATE(a0)
        bne.s M4TiSmS3
        bclr #SF_COLLDISABLE,49(a0)
        clr.w 10(a0)
        neg.w 6(a0)
        move.w #-15,8(a0)
        move.w #$b65f,d0
        jsr M4MtSetHdr
        bsr M4TiSplash
        jsr M4EnMove
        tst.b X_SBYTE4(a0)
        bne.s M4TiSm2
        move.b #5,X_STATE(a0)
        bra M4TiSeaMonTick
M4TiSm2:
        subq.b #1,X_SBYTE4(a0)
        addq.b #1,X_STATE(a0)
; 3: while vy >= 0, on (gameframe + al1pt) & 7 == 0 a RelSlowElaser at the
; player (fire_weapon $0C, offset 0); vy + 1; y >= 0 -> vy 0, a splash,
; shape B680, vel 0, sbyte3 30, state 4.
M4TiSmS3:
        cmpi.b #3,X_STATE(a0)
        bne.s M4TiSmS4
        tst.w 8(a0)
        bmi.s M4TiSm3Fall
        bsr M4TiPhase
        andi.b #7,d1
        bne.s M4TiSm3Fall
        moveq #M4_WT_RSE,d0
        moveq #0,d3
        moveq #0,d4
        moveq #0,d5
        moveq #0,d6
        moveq #0,d7
        movea.l a1,a3
        jsr M4EnFire
M4TiSm3Fall:
        addq.w #1,8(a0)
        tst.w 2(a0)
        bmi.s M4TiSmS4
        clr.w 8(a0)
        bsr M4TiSplash
        move.w #$b680,d0
        jsr M4MtSetHdr
        clr.b 15(a0)
        move.b #30,X_SBYTE3(a0)
        addq.b #1,X_STATE(a0)
; 4: colldisable; sbyte3 = 0 -> state 2 (re-run); sbyte3 - 1.
M4TiSmS4:
        cmpi.b #4,X_STATE(a0)
        bne.s M4TiSmS5
        bset #SF_COLLDISABLE,49(a0)
        tst.b X_SBYTE3(a0)
        bne.s M4TiSm4
        move.b #2,X_STATE(a0)
        bra M4TiSeaMonTick
M4TiSm4:
        subq.b #1,X_SBYTE3(a0)
; 5: a splash, vy -20, shape B65F, pos += v, state 6.
M4TiSmS5:
        cmpi.b #5,X_STATE(a0)
        bne.s M4TiSmS6
        bsr M4TiSplash
        move.w #-20,8(a0)
        move.w #$b65f,d0
        jsr M4MtSetHdr
        jsr M4EnMove
        addq.b #1,X_STATE(a0)
; 6: vy + 2; y >= 0 -> vy 0, a splash, shape B69C, state 7.
M4TiSmS6:
        cmpi.b #6,X_STATE(a0)
        bne.s M4TiSmS7
        addq.w #2,8(a0)
        tst.w 2(a0)
        bmi.s M4TiSmS7
        clr.w 8(a0)
        bsr M4TiSplash
        move.w #$b69c,d0
        jsr M4MtSetHdr
        addq.b #1,X_STATE(a0)
; 7: ZD < 200 with z < player z -> state 8, v = (0, 0, 50), y -150, shape
; B65F; else sbyte2 = yawTo(player), vel 20, (vx, vz) = gen2d(20, sbyte2),
; state 5.
M4TiSmS7:
        cmpi.b #7,X_STATE(a0)
        bne.s M4TiSmS8
        bsr M4TiZD
        cmpi.w #200,d0
        bpl.s M4TiSm7Turn
        move.w 4(a0),d0
        cmp.w 4(a1),d0
        bpl.s M4TiSm7Turn
        move.b #8,X_STATE(a0)
        clr.l 6(a0)
        move.w #50,10(a0)
        move.w #-150,2(a0)
        move.w #$b65f,d0
        jsr M4MtSetHdr
        bra.s M4TiSmS8
M4TiSm7Turn:
        movea.l a1,a2
        jsr M4EnYawTo
        move.b d0,37(a0)
        move.b #20,15(a0)
        bsr M4TiGen2dSb2
        move.b #5,X_STATE(a0)
; 8: vy + 2; y >= 0 -> sbyte4 2, state 2, vy 0, vx = (random & 7) + 5,
; negated when a second random >= $7F (unsigned), shape B680.
M4TiSmS8:
        cmpi.b #8,X_STATE(a0)
        bne.s M4TiSmEnd
        addq.w #2,8(a0)
        tst.w 2(a0)
        bmi.s M4TiSmEnd
        move.b #2,X_SBYTE4(a0)
        move.b #2,X_STATE(a0)
        clr.w 8(a0)
        jsr M4IntroRandom
        andi.w #7,d0
        addq.w #5,d0
        move.w d0,6(a0)
        jsr M4IntroRandom
        cmpi.b #$7f,d0
        blo.s M4TiSm8Shape
        neg.w 6(a0)
M4TiSm8Shape:
        move.w #$b680,d0
        jsr M4MtSetHdr
; Every state: x clamped to [-400, 400], pos += v, addplayerZ.
M4TiSmEnd:
        move.w (a0),d0
        bmi.s M4TiSmClampNeg
        cmpi.w #400,d0
        bmi.s M4TiSmClamped
        move.w #400,d0
        bra.s M4TiSmClamped
M4TiSmClampNeg:
        cmpi.w #-400,d0
        bpl.s M4TiSmClamped
        move.w #-400,d0
M4TiSmClamped:
        move.w d0,(a0)
        jsr M4EnMove
        jsr M4EnAddPZ
        moveq #0,d0
        rts
; (vx, vz) = gen2d(vel, sbyte2) 1F:C177 (angle from sbyte2, not roty).
M4TiGen2dSb2:
        move.b 13(a0),-(sp)
        move.b 37(a0),13(a0)
        jsr M4EnGen2d
        move.b (sp)+,13(a0)
        rts
; F657: psvar $1551 - 1 (the wave counter of 2_3b, 05:8721), then
; explode_Istrat 06:F45F.
M4TiSeaMonExp:
        subq.b #1,M4_MV_1551
        jmp M4LevelExplode

; ---------------------------------------------------------------------
; bossg 04:EE15 (boss_g_0 CB94, the Titania boss): maptrigger $176F = 0,
; strategy EE65, hitflash 06:89A3 / expstrat bossgexplode F306, HP $FF AP
; 8, animframe $80, shadow, enemy1, stratstate 0 (trigse $9D not ported).
; EE65 dispatches the mode table 04:EE76 by stratstate (09:C027); nxtmode
; F171 adds 1 to stratstate and re-runs EE65 in the same call; znxtmode F16F
; also clears sbyte1. Boss HP bar: m_bossmaxHP 70:019A = M4_BOSS_MAXHP,
; 70:019C = M4_BOSS_HP.
M4StratTiBossG:
        clr.b M4_MV_176F
        move.l #M4TiBossGTick,32(a0)
        move.l #M4LcHitFlash,X_COLL(a0)
        move.l #M4TiBossGExp,X_EXP(a0)
        move.b #$ff,38(a0)
        move.b #8,39(a0)
        move.b #$80,16(a0)
        bset #F2_SHADOW,48(a0)
        ori.b #CF_ENEMY1,44(a0)
        clr.b X_STATE(a0)
M4TiBossGTick:
        moveq #0,d0
        move.b X_STATE(a0),d0
        add.w d0,d0
        add.w d0,d0
        movea.l M4TiBossGModes(pc,d0.w),a2
        jmp (a2)
M4TiBossGModes: ;04:EE76
        dc.l M4TiBgWait,M4TiBgScroll,M4TiBgNext,M4TiBgRunaway,M4TiBgDisappear
        dc.l M4TiBgWaitSome,M4TiBgAppear,M4TiBgTo600
        dc.l M4TiBgOpen,M4TiBgFishL,M4TiBgFishR,M4TiBgWait10,M4TiBgClose,M4TiBgWait10
        dc.l M4TiBgOpen,M4TiBgFishL,M4TiBgFishR,M4TiBgWait10,M4TiBgClose,M4TiBgWait10
        dc.l M4TiBgOpen,M4TiBgFishL,M4TiBgFishR,M4TiBgWait10,M4TiBgClose,M4TiBgWait10
        dc.l M4TiBgOpen,M4TiBgFishL,M4TiBgFishR,M4TiBgWait10,M4TiBgClose
        dc.l M4TiBgShadows,M4TiBgWait70,M4TiBgNext,M4TiBgRunaway,M4TiBgLoop
; F16F / F171.
M4TiBgZNext:
        clr.b 36(a0)
M4TiBgNext:
        addq.b #1,X_STATE(a0)
        bra M4TiBossGTick
; EF18 loopback: stratstate 3 (runaway), re-run.
M4TiBgLoop:
        move.b #3,X_STATE(a0)
        bra M4TiBossGTick
; F1B6: z - 40; ZD < 150 -> next; else end (no addplayerZ).
M4TiBgWait:
        subi.w #40,4(a0)
        bsr M4TiZD
        cmpi.w #150,d0
        bmi.s M4TiBgNext
        moveq #0,d0
        rts
; F1D5 scrollmsg: dzdistless with an 8-bit A = $8C (the threshold's high
; byte is DP $03, never written by this path: 0 in the ROM oracle; [H] in the
; game the player strategy runs before and could leave another value):
; ZD < 140 -> z + 40; tx + 4 ($1CF4); tx & $7F == 0 -> next; else move.
M4TiBgScroll:
        bsr M4TiZD
        cmpi.w #140,d0
        bpl.s M4TiBgScrollTx
        addi.w #40,4(a0)
M4TiBgScrollTx:
        addq.b #4,X_TX(a0)
        moveq #$7f,d0
        and.b X_TX(a0),d0
        beq.s M4TiBgNext
        bra M4TiBgMove
; F17B runaway: ZD < 1000 -> genspark; z + 70; ZD >= 4000 -> next; else
; move (maxHP 0) / move2.
M4TiBgRunaway:
        bsr M4TiZD
        cmpi.w #1000,d0
        bpl.s M4TiBgRunZ
        bsr M4TiBgGenSpark
M4TiBgRunZ:
        addi.w #70,4(a0)
        bsr M4TiZD
        cmpi.w #4000,d0
        bpl.s M4TiBgNext
M4TiBgMoveHP:
        tst.b M4_BOSS_MAXHP
        beq M4TiBgMove
        bra M4TiBgMove2
; F133: nullshape, maptrigger |= 1 (2_3b sends the sea monsters), next.
M4TiBgDisappear:
        move.w #$aca1,d0
        jsr M4MtSetHdr
        ori.b #1,M4_MV_176F
        bra M4TiBgNext
; F0CD: with a boss bar, every 4th gameframe HP + 1 up to 120; maptrigger
; bit 0 or any sea monster (B65F / B680 / B69C, find_y_l) -> wait (move /
; move2); else znext.
M4TiBgWaitSome:
        tst.b M4_BOSS_MAXHP
        beq.s M4TiBgWsFlag
        moveq #3,d0
        and.w M4_LV_GAMEFRAME,d0
        bne.s M4TiBgWsFlag
        cmpi.b #120,38(a0)
        beq.s M4TiBgWsFlag
        addq.b #1,38(a0)
M4TiBgWsFlag:
        btst #0,M4_MV_176F
        bne.s M4TiBgMoveHP
        move.w #$b65f,d1
        bsr M4TiFindHdr
        bne.s M4TiBgMoveHP
        move.w #$b680,d1
        bsr M4TiFindHdr
        bne.s M4TiBgMoveHP
        move.w #$b69c,d1
        bsr M4TiFindHdr
        bne.s M4TiBgMoveHP
        bra M4TiBgZNext
; F148: shape boss_g_0; first time (maxHP 0): HP 120, AP 8, maxHP = 120,
; bar HP 0. next.
M4TiBgAppear:
        move.w #$cb94,d0
        jsr M4MtSetHdr
        tst.b M4_BOSS_MAXHP
        bne M4TiBgNext
        move.b #120,38(a0)
        move.b #8,39(a0)
        move.b #120,M4_BOSS_MAXHP
        clr.b M4_BOSS_HP
        bra M4TiBgNext
; F205 moveto600h: until sflag8 (sflags4 $20 = X2_FL4 bit 5) ZD < 1500 sets
; it (trigse $9D); ZD < 600 -> sflag8 cleared, next; else z - 40, move2.
M4TiBgTo600:
        btst #5,X2_FL4(a0)
        bne.s M4TiBgTo600Near
        bsr M4TiZD
        cmpi.w #1500,d0
        bpl.s M4TiBgTo600Near
        bset #5,X2_FL4(a0)
M4TiBgTo600Near:
        bsr M4TiZD
        cmpi.w #600,d0
        bmi.s M4TiBgTo600Done
        subi.w #40,4(a0)
        bra M4TiBgMove2
M4TiBgTo600Done:
        bclr #5,X2_FL4(a0)
        bra M4TiBgNext
; EF21 opentrunk: animframe + 1 (sound at 0); reaching 10 it stays 9 and
; next; else move2.
M4TiBgOpen:
        move.b 16(a0),d0
        addq.b #1,d0
        bmi.s M4TiBgOpenMod
        addi.b #10,d0
M4TiBgOpenMod:
        andi.b #$7f,d0
        cmpi.b #10,d0
        bhs.s M4TiBgOpenEnd
        ori.b #$80,d0
        move.b d0,16(a0)
        bra M4TiBgMove2
M4TiBgOpenEnd:
        move.b #$89,16(a0)
        bra M4TiBgNext
; EF55 closetrunk: frame 0 -> next; else frame - 1 mod 10, move2.
M4TiBgClose:
        moveq #$7f,d0
        and.b 16(a0),d0
        beq M4TiBgNext
        move.b 16(a0),d0
        moveq #10,d1
        jsr M4MtAfDec
        move.b d0,16(a0)
        bra M4TiBgMove2
; EF8E / EF9E waitabit (70) / waitabit2 (10): sbyte1 + 1; reaching it ->
; znext; else move2.
M4TiBgWait70:
        moveq #70,d1
        bra.s M4TiBgWaitN
M4TiBgWait10:
        moveq #10,d1
M4TiBgWaitN:
        addq.b #1,36(a0)
        cmp.b 36(a0),d1
        beq M4TiBgZNext
        bra M4TiBgMove2
; F0A5 / F0AC: a flying fish (launchfish F269); the right one gets sflag3
; (sflags2 $40 = X2_FL2 bit 6, as level_macbeth.asm). next.
M4TiBgFishL:
        bsr.s M4TiBgFish
        bra M4TiBossGNext2
M4TiBgFishR:
        bsr.s M4TiBgFish
        beq.s M4TiBossGNext2
        bset #6,X2_FL2(a2)
M4TiBossGNext2:
        bra M4TiBgNext
; F269: f_fish CE50 with Istrat 00:FAD6 at the boss (y + 30), its angles.
M4TiBgFish:
        move.w #$ce50,d0
        jsr M4MtCreateHdr
        beq.s M4TiBgFishDone
        move.l #M4StratTiFlyFish,32(a2)
        move.l (a0),(a2)
        move.w 4(a0),4(a2)
        addi.w #30,2(a2)
        move.b 12(a0),12(a2)
        move.b 13(a0),13(a2)
        move.b 14(a0),14(a2)
        cmpa.w #0,a2
M4TiBgFishDone:
        rts
; EFAE generateshadows (trigse $2D): three boss_g_s D17C at the boss (z - 50)
; with Istrat F53E, sword1 -100 / 0 / 100; a failed creation -> next.
M4TiBgShadows:
        move.w #-100,d6
M4TiBgShadow:
        move.w #$d17c,d0
        jsr M4MtCreateHdr
        beq M4TiBgNext
        move.l (a0),(a2)
        move.w 4(a0),4(a2)
        subi.w #50,4(a2)
        move.b 12(a0),12(a2)
        move.b 13(a0),13(a2)
        move.b 14(a0),14(a2)
        move.w d6,40(a2)
        move.l #M4StratTiBossGs,32(a2)
        addi.w #100,d6
        cmpi.w #200,d6
        bne.s M4TiBgShadow
        bra M4TiBgNext
; F2A1 move2: bar HP += HP; addplayerZ; on even gameframes a small splash
; 30 behind the boss with y 0 (allst head = the boss during the creation:
; linked right behind it, as the port links behind the running object).
M4TiBgMove2:
        move.b 38(a0),d0
        add.b d0,M4_BOSS_HP
        jsr M4EnAddPZ
        btst #0,M4_LV_GAMEFRAME+1
        bne.s M4TiBgEnd
        addi.w #30,4(a0)
        bsr M4TiSsplash
        beq.s M4TiBgMove2Back
        clr.w 2(a2)
M4TiBgMove2Back:
        subi.w #30,4(a0)
        bra.s M4TiBgEnd
; F301 move: addplayerZ.
M4TiBgMove:
        jsr M4EnAddPZ
M4TiBgEnd:
        moveq #0,d0
        rts
; genspark F24E: sgenspark 0B:AC5E at the boss's position 60 higher (dummyobj
; holds the position and is the creator X: the spark is linked behind it; the
; port links it in front of the sparks already in allst, else at the tail,
; where dummyobj sits [H for the game: allocated at level start, every later
; object goes in front of it]): unless the player is dead ($14D9 $04), spark B2C1 with
; Istrat 0B:AC1B, colldisable, camera-facing, rotz = random_l, count 5, vel
; 15, (vx, vy) = gen2d(15, rotz) (the second gen2d result goes to vy).
M4TiBgGenSpark:
        btst #2,M4_LP_PSF2
        bne M4TiBgSparkDone
        move.l M4_LV_CREATOR,-(sp) ;make_obj with X = dummyobj: linked behind it
        move.w M4_LV_HEAD,d0 ;(before the sparks already there, after the rest)
M4TiBgSparkTail:
        movea.w d0,a3
        move.w X_NEXT(a3),d0
        beq.s M4TiBgSparkHere
        movea.w d0,a2
        move.l 32(a2),d1
        cmpi.l #M4TiSparkInit,d1
        beq.s M4TiBgSparkHere
        cmpi.l #M4TiSparkTick,d1
        bne.s M4TiBgSparkTail
M4TiBgSparkHere:
        move.l a3,M4_LV_CREATOR
        move.w #$b2c1,d0
        jsr M4MtCreateHdr
        move.l (sp)+,M4_LV_CREATOR
        cmpa.w #0,a2
        beq.s M4TiBgSparkDone
        move.l #M4TiSparkInit,32(a2)
        bset #SF_COLLDISABLE,49(a2)
        move.l a0,-(sp)
        movea.l a2,a0
        jsr M4EnFaceCamera
        movea.l (sp),a3
        move.l (a3),(a0)
        move.w 4(a3),4(a0)
        subi.w #60,2(a0)
        jsr M4IntroRandom
        move.b d0,14(a0)
        move.b #5,19(a0)
        move.b #15,15(a0)
        move.b 13(a0),-(sp)
        move.b 14(a0),13(a0)
        jsr M4EnGen2d
        move.b (sp)+,13(a0)
        move.w 10(a0),8(a0)
        clr.w 10(a0)
        movea.l (sp)+,a0
M4TiBgSparkDone:
        rts
; 0B:AC1B: colframe $80, strategy AC30. AC30: colframe + 2 mod 16,
; addplayerZ, pos += v, count - 1 = 0 -> removed.
M4TiSparkInit:
        move.b #$80,18(a0)
        move.l #M4TiSparkTick,32(a0)
        moveq #0,d0
        rts
M4TiSparkTick:
        move.b 18(a0),d0
        addq.b #2,d0
        bmi.s M4TiSparkMod
        addi.b #16,d0
M4TiSparkMod:
        andi.b #$7f,d0
        cmpi.b #16,d0
        blo.s M4TiSparkSet
        subi.b #16,d0
M4TiSparkSet:
        ori.b #$80,d0
        move.b d0,18(a0)
        jsr M4EnAddPZ
        jsr M4EnMove
        moveq #0,d0
        subq.b #1,19(a0)
        bne.s M4TiSparkKeep
        moveq #1,d0
M4TiSparkKeep:
        rts

; d1.w = shape header -> Z clear (bne) when an object of allst has it
; (find_y_l 09:B1FF from the head), a2 = that object. The current shape is
; the descriptor index (46): explosions change it without X_SHAPEHDR; for a
; header outside the catalog (index $FFFF) X_SHAPEHDR decides. d0/d4 used.
M4TiFindHdr:
        move.w d1,d0
        jsr M4LevelShapeIndex
        move.w d0,d4
        move.w M4_LV_HEAD,d0
M4TiFindHdrNext:
        beq.s M4TiFindHdrNone
        movea.w d0,a2
        cmp.w 46(a2),d4
        bne.s M4TiFindHdrSkip
        cmpi.w #$ffff,d4
        bne.s M4TiFindHdrFound
        cmp.w X_SHAPEHDR(a2),d1
        beq.s M4TiFindHdrFound
M4TiFindHdrSkip:
        move.w X_NEXT(a2),d0
        bra.s M4TiFindHdrNext
M4TiFindHdrFound:
        moveq #1,d0
        rts
M4TiFindHdrNone:
        moveq #0,d0
        rts

; bossgexplode F306 (expstrat, HP 0): every boss_g_s D17C of allst removed
; (1F:D540), then expstrat F32E, run now and every tick: three small
; explosions (06:EEFD) nopolyexp, 60 higher, each axis + (random & 15) - 7,
; shape explosion5 B171; animframe + 1 (stays 9); ZD < 350 -> toppleoff:
; maptrigger |= 2 and bossexplode 06:EAAE (M4B1Explode, level_boss1.asm);
; else a small splash with y 0.
M4TiBossGExp:
        move.w #$d17c,d1
        bsr M4TiFindHdr
        beq.s M4TiBgExpSet
        move.l a0,-(sp)
        movea.l a2,a0
        jsr M4LevelRemove
        movea.l (sp)+,a0
        bra.s M4TiBossGExp
M4TiBgExpSet:
        move.l #M4TiBgExpTick,X_EXP(a0)
M4TiBgExpTick:
        moveq #2,d6
M4TiBgExpOne:
        moveq #0,d0
        jsr M4B1Expl
        beq.s M4TiBgExpNoObj
        bset #F2_NOPOLYEXP,48(a2)
        subi.w #60,2(a2)
        moveq #0,d5
M4TiBgExpRnd:
        jsr M4IntroRandom
        andi.w #15,d0
        subq.w #7,d0
        add.w d0,(a2,d5.w)
        addq.w #2,d5
        cmpi.w #6,d5
        bne.s M4TiBgExpRnd
        move.l a0,-(sp)
        movea.l a2,a0
        move.w #$b171,d0
        jsr M4MtSetHdr
        movea.l (sp)+,a0
        bra.s M4TiBgExpLoop
M4TiBgExpNoObj: ;dummyobj in the original: the three random_l still run
        jsr M4IntroRandom
        jsr M4IntroRandom
        jsr M4IntroRandom
M4TiBgExpLoop:
        dbra d6,M4TiBgExpOne
        move.b 16(a0),d0
        addq.b #1,d0
        bmi.s M4TiBgExpMod
        addi.b #10,d0
M4TiBgExpMod:
        andi.b #$7f,d0
        cmpi.b #10,d0
        blo.s M4TiBgExpAnim
        moveq #9,d0
M4TiBgExpAnim:
        ori.b #$80,d0
        move.b d0,16(a0)
        bsr M4TiZD
        cmpi.w #350,d0
        bmi.s M4TiBgTopple
        bsr M4TiSsplash
        beq.s M4TiBgExpDone
        clr.w 2(a2)
M4TiBgExpDone:
        moveq #0,d0
        rts
M4TiBgTopple:
        ori.b #2,M4_MV_176F
        jmp M4B1Explode

; boss_g_s 04:F53E (the three shadows): enemy1, strategy F561,
; normcollptrs, HP $FF AP 8, sbyte1 40. F561: coltab BLACK_C $807C on odd
; gameframes, 0 on even; x steps 5 toward sword1 (fchase, may overshoot);
; sbyte1 counts down with addplayerZ, then z - 50 every tick.
M4StratTiBossGs:
        ori.b #CF_ENEMY1,44(a0)
        move.l #M4TiBossGsTick,32(a0)
        jsr M4LvNormPtrs
        move.b #$ff,38(a0)
        move.b #8,39(a0)
        move.b #40,36(a0)
M4TiBossGsTick:
        move.w #$807c,d0
        btst #0,M4_LV_GAMEFRAME+1
        bne.s M4TiBgsCol
        moveq #0,d0
M4TiBgsCol:
        move.w d0,X_COLTAB(a0)
        move.w (a0),d0
        cmp.w 40(a0),d0
        beq.s M4TiBgsX
        bmi.s M4TiBgsXUp
        subq.w #5,d0
        bra.s M4TiBgsX
M4TiBgsXUp:
        addq.w #5,d0
M4TiBgsX:
        move.w d0,(a0)
        tst.b 36(a0)
        beq.s M4TiBgsDash
        subq.b #1,36(a0)
        jsr M4EnAddPZ
        moveq #0,d0
        rts
M4TiBgsDash:
        subi.w #50,4(a0)
        moveq #0,d0
        rts

; flyingfish 00:FAD6 (f_fish launched by bossg): enemy1, strategy FB03,
; normcollptrs, roty + $80, HP 4 AP 8, animframe $80.
M4StratTiFlyFish:
        ori.b #CF_ENEMY1,44(a0)
        move.l #M4TiFlyFishTick,32(a0)
        jsr M4LvNormPtrs
        addi.b #$80,13(a0)
        move.b #4,38(a0)
        move.b #8,39(a0)
        move.b #$80,16(a0)
; FB03: sflag2 (landed) -> nothing. Even gameframe: a small splash, y 0.
; In the air (y < 0): vy + 2, y + vy, clamped to 0. addplayerZ. Left fish:
; x = Achase16_3(x, -200), already there or x < -150 -> jump; right fish
; (sflag3): toward 200, already there or x >= 150 -> jump.
M4TiFlyFishTick:
        btst #F2_SFLAG2,48(a0)
        bne M4TiFfDone
        btst #0,M4_LV_GAMEFRAME+1
        bne.s M4TiFfAir
        bsr M4TiSsplash
        beq.s M4TiFfAir
        clr.w 2(a2)
M4TiFfAir:
        tst.w 2(a0)
        bpl.s M4TiFfPZ
        addq.w #2,8(a0)
        move.w 8(a0),d0
        add.w d0,2(a0)
        bmi.s M4TiFfPZ
        clr.w 2(a0)
M4TiFfPZ:
        jsr M4EnAddPZ
        move.w #-200,d1
        btst #6,X2_FL2(a0)
        beq.s M4TiFfChase
        move.w #200,d1
M4TiFfChase:
        move.w (a0),d0
        cmp.w d0,d1
        beq.s M4TiFfJump
        moveq #3,d2
        jsr M4LpAchase
        move.w d0,(a0)
        btst #6,X2_FL2(a0)
        bne.s M4TiFfRight
        cmpi.w #-150,d0
        bmi.s M4TiFfJump
        bra.s M4TiFfDone
M4TiFfRight:
        cmpi.w #150,d0
        bpl.s M4TiFfJump
M4TiFfDone:
        moveq #0,d0
        rts
; FBC6: roty = yawTo(player), animframe 0, strategy FC29, vel 70, (vx, vz) =
; gen2d(70, roty), vy -15, a splash (8C31) with y 0 (sound 03:B735 not
; ported). FC29: vy + 2, pos += v, addplayerZ; y >= 0 -> a splash with y 0
; and sflag2.
M4TiFfJump:
        movea.l a1,a2
        jsr M4EnYawTo
        move.b d0,13(a0)
        clr.b 16(a0)
        move.l #M4TiFlyFishJump,32(a0)
        move.b #70,15(a0)
        jsr M4EnGen2d
        move.w #-15,8(a0)
        bsr M4TiSplash
        beq.s M4TiFlyFishJump
        clr.w 2(a2)
M4TiFlyFishJump:
        addq.w #2,8(a0)
        jsr M4EnMove
        jsr M4EnAddPZ
        tst.w 2(a0)
        bmi.s M4TiFfJumpDone
        bsr M4TiSplash
        beq.s M4TiFfLanded
        clr.w 2(a2)
M4TiFfLanded:
        bset #F2_SFLAG2,48(a0)
M4TiFfJumpDone:
        moveq #0,d0
        rts

; ---------------------------------------------------------------------
; Inline 65816 blocks (start65816 04:9DB4) of the Titania / Fortuna paths,
; reached from M4PvOp_start65816 (level_paths.asm) with a0 = path object:
; the splash sounds of e_spla_dw/e_spla_up (path 0892: jsl enemydownsea_l
; 03:B751; 08A0: jsl enemyupsea_l 03:B735; both
; makesnd 03:B785) and the Fortuna flower (path 0026: jsl makepollen
; 06:F9C2). Each sets the path pointer to the continuation and returns.
M4TiPath65Snd1:
        move.l a1,-(sp)
        lea M4TiSplashDw(pc),a1
        jsr M4SfxAt5
        movea.l (sp)+,a1
        move.w #$089d,42(a0)
        rts
M4TiPath65Snd2:
        move.l a1,-(sp)
        lea M4TiSplashUp(pc),a1
        jsr M4SfxAt5
        movea.l (sp)+,a1
        move.w #$08ab,42(a0)
        rts
M4TiSplashDw: ;lsnd, csnd, rsnd, msnd, fsnd
        include '../build/m4-titania-splash-down.inc'
M4TiSplashUp:
        include '../build/m4-titania-splash-up.inc'
        even
M4TiPath65Pollen:
        bsr.s M4TiMakePollen
        move.w #$0031,42(a0)
        rts

; makepollen 06:F9C2: a nullshape object at a0, 120 higher, Istrat F9F8.
M4TiMakePollen:
        move.l a2,-(sp)
        move.w #$aca1,d0
        jsr M4MtCreateHdr
        beq.s M4TiMakePollenDone
        move.l (a0),(a2)
        move.w 4(a0),4(a2)
        subi.w #120,2(a2)
        move.l #M4TiPollenI,32(a2)
M4TiMakePollenDone:
        movea.l (sp)+,a2
        rts
; F9F8 (the stratptr stays here; HP 0 from creation, so from the next tick
; on only the expstrat FA2E runs): expstrat FA2E, colldisable, al_type |= 1,
; partobj (sflags $10: a GSU particle emitter, drawn by the GSU particle
; code: not drawn by the port, PEND), sbyte3 6, sbyte1 60, sbyte2 $FA, no
; shadow. FA2E: partobj, sbyte3/1/2 = 0, no shadow, count + 1; at $FA the
; object is removed (06:8D12).
M4TiPollenI:
        move.l #M4TiPollenExp,X_EXP(a0)
        bset #SF_COLLDISABLE,49(a0)
        ori.b #1,45(a0)
        move.b #6,X_SBYTE3(a0)
        move.b #60,36(a0)
        move.b #$fa,37(a0)
        bclr #F2_SHADOW,48(a0)
        moveq #0,d0
        rts
M4TiPollenExp:
        clr.b X_SBYTE3(a0)
        clr.b 36(a0)
        clr.b 37(a0)
        bclr #F2_SHADOW,48(a0)
        addq.b #1,19(a0)
        moveq #0,d0
        cmpi.b #$fa,19(a0)
        bne.s M4TiPollenKeep
        moveq #1,d0
M4TiPollenKeep:
        rts

; ---------------------------------------------------------------------
; Sprouting stalks of Fortuna (DSTRATS.ASM sprouty; ROM 09:9997..09:A3FA,
; build/agent-titania/dis/09_9997.txt, 09_9CF9.txt, 09_A29F.txt): a base
; object grows a chain of segments (sprouthead / sproutbody / sprouttail
; shapes of the globals $1FEA/$1FEC/$1FEE, HP sproutiHP $1FF0, next
; segment Istrat sproutstrat $1FF1), linked through al_ptr (the base points
; at the newest segment; $FFFF = the chain left the ground and stopped).
; Flags: sflag2 sea dragon, sflag8 Loch Ness, sflag6 flower, sflag5 kinky
; tree / withdraw, sflag4 leaves, sflag3 (tree1 alternates the leaf side).

; lochnessmonster 09:9997: sflag8, sprouttail CF84, then missheight.
M4StratTiLochNess:
        bset #TI_SF8,X2_FL4(a0)
        move.w #$cf84,M4_TI_SPTAIL
        bra.s M4TiSeaMiss
; seadragon2 09:99A9: sbyte2 15, sbyte1 = (random & 3) + 2, sword1 hi $FF.
M4StratTiSeaDragon2:
        move.b #15,37(a0)
; seadragon 09:99AD (the dragons of the Fortuna generator, mother script
; 05:D7EE): the same without sbyte2.
M4StratTiSeaDragon:
        jsr M4IntroRandom
        andi.b #3,d0
        addq.b #2,d0
        move.b d0,36(a0)
        move.b #$ff,40(a0)
; 99C0 missheight: sflag2, sflag4; head snake_1 CEDC, body CFA0, iHP $FF;
; y - 40; sword1 lo 4 (animation speed); colldisable.
M4TiSeaMiss:
        bset #F2_SFLAG2,48(a0)
        bset #TI_SF4,X2_FL2(a0)
        move.w #$cedc,M4_TI_SPHEAD
        move.w #$cfa0,M4_TI_SPBODY
        st M4_TI_SPIHP
        subi.w #40,2(a0)
        move.b #4,41(a0)
        bset #SF_COLLDISABLE,49(a0)
; 99FB sead (sproutstrat): strategy 9CC8, normcollptrs, HP iHP, AP 16,
; nohitaffect, enemy1, animframe $80; Loch Ness -> 9CC8; sbyte1 = 0 ->
; stopstrat 9A5B; else sbyte1 - 1 and 9CC8.
M4TiSeaI2:
        move.l #M4TiSeaI2,M4_TI_SPSTRAT
        bsr M4TiSpInit
        move.b #16,39(a0)
        btst #TI_SF8,X2_FL4(a0)
        bne M4TiSpStrat
        tst.b 36(a0)
        beq.s M4TiSeaStopSet
        subq.b #1,36(a0)
        bra M4TiSpStrat
M4TiSeaStopSet:
        move.l #M4TiSeaStop,32(a0)
; 9A5B stopstrat: a dragon (sflag2) with sflag5 -> withdraw_i.
M4TiSeaStop:
        btst #F2_SFLAG2,48(a0)
        beq.s M4TiSpRts
        btst #0,X_TISF3(a0)
        bne M4TiSpWithdrawI
M4TiSpRts:
        moveq #0,d0
        rts
; Common part of the Istrat2: strategy 9CC8, normcollptrs, HP = iHP,
; nohitaffect, enemy1, animframe $80 (the caller sets AP).
M4TiSpInit:
        move.l #M4TiSpStrat,32(a0)
        jsr M4LvNormPtrs
        move.b M4_TI_SPIHP,38(a0)
        bset #SF_NOHITAFFECT,49(a0)
        ori.b #CF_ENEMY1,44(a0)
        move.b #$80,16(a0)
        rts

; tree3 09:9A70: sbyte1 $FF (no bloom), then 9A86. tree2 09:9A78: sbyte1 =
; (random & 3) + 1, sbyte2 $10.
M4StratTiTree3:
        st 36(a0)
        bra.s M4TiTree2Forced
M4StratTiTree2:
        jsr M4IntroRandom
        andi.b #3,d0
        addq.b #1,d0
        move.b d0,36(a0)
        move.b #$10,37(a0)
; 9A86: sflag6, sflag5; head stalk CEA4, body CEF8, iHP $FF; y - 40;
; sword1 $FF02 (tail timer $FF, animation speed 2); x >= player x: roty
; + $E0, else sbyte2 negated and roty + $20.
M4TiTree2Forced:
        ori.b #3,X_TISF3(a0)
        bsr M4TiTreeVars
        move.w (a0),d0
        cmp.w (a1),d0
        bmi.s M4TiTree2Other
        addi.b #$e0,13(a0)
        bra.s M4TiTree2I2
M4TiTree2Other:
        neg.b 37(a0)
        addi.b #$20,13(a0)
; 9AE8 (sproutstrat): shadow; AP 8; sbyte1 = 0 -> bloom 9BC9; else sbyte1 -
; 1 and 9CC8.
M4TiTree2I2:
        bset #F2_SHADOW,48(a0)
        move.l #M4TiTree2I2,M4_TI_SPSTRAT
        bsr M4TiSpInit
        move.b #8,39(a0)
        tst.b 36(a0)
        beq.s M4TiTreeBloom
        subq.b #1,36(a0)
        bra M4TiSpStrat
; head stalk CEA4, body CEF8, iHP $FF, y - 40, sword1 $FF02.
M4TiTreeVars:
        move.w #$cea4,M4_TI_SPHEAD
        move.w #$cef8,M4_TI_SPBODY
        st M4_TI_SPIHP
        subi.w #40,2(a0)
        move.w #$ff02,40(a0)
        rts

; tree1 09:9B37: sflag6, sflag4, sbyte1 = (random & 3) + 1, tree vars.
M4StratTiTree1:
        bset #1,X_TISF3(a0)
        bset #TI_SF4,X2_FL2(a0)
        jsr M4IntroRandom
        andi.b #3,d0
        addq.b #1,d0
        move.b d0,36(a0)
        bsr.s M4TiTreeVars
; 9B7A (sproutstrat): AP 8; sbyte1 = 0 -> bloom; else sbyte1 - 1, sflag3
; toggled (the leaf side) and 9CC8.
M4TiTree1I2:
        move.l #M4TiTree1I2,M4_TI_SPSTRAT
        bsr M4TiSpInit
        move.b #8,39(a0)
        tst.b 36(a0)
        beq.s M4TiTreeBloom
        subq.b #1,36(a0)
        bchg #TI_SF3,X2_FL2(a0)
        bra M4TiSpStrat
; 9BC9 bloom: sflag5 (kinky tree) -> cleared, sbyte1 = (random & 1) + 1,
; 9CC8; else flower: no shadow, strategy 9C02, shape flower CE88.
M4TiTreeBloom:
        bclr #0,X_TISF3(a0)
        beq.s M4TiTreeFlower
        jsr M4IntroRandom
        andi.b #1,d0
        addq.b #1,d0
        move.b d0,36(a0)
        bra M4TiSpStrat
M4TiTreeFlower:
        bclr #F2_SHADOW,48(a0)
        move.l #M4TiFlowerUp,32(a0)
        move.w #$ce88,d0
        jsr M4MtSetHdr
; 9C02 flowerup: at frame 10 a pollen emitter (makepollen 06:F9C2); frame + 1
; up to 12.
M4TiFlowerUp:
        moveq #$7f,d0
        and.b 16(a0),d0
        cmpi.b #10,d0
        bne.s M4TiFlowerAnim
        bsr M4TiMakePollen
M4TiFlowerAnim:
        moveq #13,d1
        bsr M4TiAnimClamp
        moveq #0,d0
        rts
; Frame + 1 with the clamp form (09:8064): reaching the count d1 it stays
; count - 1 and Z is clear (bne). d0/d1 used.
M4TiAnimClamp:
        move.b 16(a0),d0
        addq.b #1,d0
        bmi.s M4TiAnimClampMod
        add.b d1,d0
M4TiAnimClampMod:
        andi.b #$7f,d0
        cmp.b d1,d0
        bhs.s M4TiAnimClampEnd
        ori.b #$80,d0
        move.b d0,16(a0)
        moveq #0,d0
        rts
M4TiAnimClampEnd:
        move.b d1,d0
        subq.b #1,d0
        ori.b #$80,d0
        move.b d0,16(a0)
        moveq #1,d0
        rts

; ---------------------------------------------------------------------
; 9CC8 sprouty.strat (growing). A dragon checks ZD < 1000 (Loch Ness or a
; sbyte2 dragon skip the check: rising), a tree ZD < 2000; far: chksnake.
M4TiSpStrat:
        btst #F2_SFLAG2,48(a0)
        beq.s M4TiSpTree
        btst #TI_SF8,X2_FL4(a0)
        bne.s M4TiSpLoch
        tst.b 37(a0)
        bne.s M4TiSpLoch
        move.w #1000,d1
        bra.s M4TiSpDist
M4TiSpTree:
        move.w #2000,d1
M4TiSpDist:
        bsr M4TiZD
        sub.w d1,d0
        bpl M4TiSpChkSnake
        btst #F2_SFLAG2,48(a0)
        beq M4TiSpNotSnake
; 9D03 lochness: sflag3 (head made) -> notsnake; Loch Ness or sbyte2 ->
; nobluff; else random >= $7F (sound 03:B735) -> nobluff, else bluff.
M4TiSpLoch:
        btst #TI_SF3,X2_FL2(a0)
        bne M4TiSpNotSnake
        btst #TI_SF8,X2_FL4(a0)
        bne.s M4TiSpNoBluff
        tst.b 37(a0)
        bne.s M4TiSpNoBluff
        jsr M4IntroRandom
        cmpi.b #$7f,d0
        blo M4TiSpBluffSet
; 9D2F nobluff: sflag3; the head snake_0 CEC0 (copypos, copyrots, Istrat
; snake 04:F9C4, al_ptr = base, enemy1, sbyte2 = base sbyte2, sbyte3 = base
; sword1 hi; Loch Ness: head sflag1); base sflag1 (always splash). 9D8A
; (also on a failed creation): shape snake_1 CEDC, collisions on.
M4TiSpNoBluff:
        bset #TI_SF3,X2_FL2(a0)
        move.w #$cec0,d0
        jsr M4MtCreateHdr
        beq.s M4TiSpHeadFailed
        bsr M4TiCopyPosRots
        move.l #M4StratTiSnake,32(a2)
        move.w a0,X_ALPTR(a2)
        ori.b #CF_ENEMY1,44(a2)
        move.b 37(a0),37(a2)
        move.b 40(a0),X_SBYTE3(a2)
        btst #TI_SF8,X2_FL4(a0)
        beq.s M4TiSpHeadNess
        bset #F2_SFLAG1,48(a2)
M4TiSpHeadNess:
        bset #F2_SFLAG1,48(a0)
M4TiSpHeadFailed:
        move.w #$cedc,d0
        jsr M4MtSetHdr
        bclr #SF_COLLDISABLE,49(a0)
; 9D99 notsnake: frame + sword1 lo (clamp 8); reaching it -> 9DC1.
M4TiSpNotSnake:
        move.b 16(a0),d0
        add.b 41(a0),d0
        bmi.s M4TiSpGrowMod
        addq.b #8,d0
M4TiSpGrowMod:
        andi.b #$7f,d0
        cmpi.b #8,d0
        bhs.s M4TiSpGrown
        ori.b #$80,d0
        move.b d0,16(a0)
        moveq #0,d0
        rts
; 9DC1 finished: a dragon with sflag5 -> withdraw_i; else strategy strat2
; 9E60 (next tick).
M4TiSpGrown:
        move.b #$87,16(a0)
        btst #F2_SFLAG2,48(a0)
        beq.s M4TiSpStrat2Set
        btst #0,X_TISF3(a0)
        bne M4TiSpWithdrawI
M4TiSpStrat2Set:
        move.l #M4TiSpStrat2,32(a0)
        moveq #0,d0
        rts
; 9DE4 chksnake: a dragon far away splashes every 8th gameframe (small
; splash, y 0, z - 10).
M4TiSpChkSnake:
        btst #F2_SFLAG2,48(a0)
        beq.s M4TiSpDone
M4TiSpSplash8:
        moveq #7,d0
        and.w M4_LV_GAMEFRAME,d0
        bne.s M4TiSpDone
        bsr M4TiSsplash
        beq.s M4TiSpDone
        clr.w 2(a2)
        subi.w #10,4(a2)
M4TiSpDone:
        moveq #0,d0
        rts
; 9E22 bluff: strategy 9E2F (the splashes only).
M4TiSpBluffSet:
        move.l #M4TiSpBluff,32(a0)
M4TiSpBluff:
        bra.s M4TiSpSplash8

; 9E60 strat2: frame 8|$80; a new segment of shape sprouthead (copypos,
; copyrots, sbyte1..3, sword1 and the four sflags bytes of the base),
; offset (0, -37, 0) rotated by its angles (9F52); its rotation: flower ->
; kinky: rotz + sbyte2; dragon: Loch Ness rotx - 22 (sflag1 cleared), else
; rotx - 11; else rotz/roty/rotx + sbyte1/2/3; offset again; Istrat =
; sproutstrat; base al_ptr = segment; out of bounds (9FDB) -> al_ptr $FFFF,
; the segment removed. Then strat3_i A078 (on a failed creation: rtl).
M4TiSpStrat2:
        move.b #$88,16(a0)
        move.w M4_TI_SPHEAD,d0
        jsr M4MtCreateHdr
        beq M4TiSpDone
        bsr M4TiCopyPosRots
        move.b 36(a0),36(a2)
        move.b 37(a0),37(a2)
        move.b X_SBYTE3(a0),X_SBYTE3(a2)
        move.w 40(a0),40(a2)
        bsr M4TiCopySflags
        bsr M4TiSpOffset
        btst #1,X_TISF3(a0)
        bne.s M4TiSpRotTree
        btst #F2_SFLAG2,48(a0)
        bne.s M4TiSpRotSnake
        move.b 36(a2),d0
        add.b d0,14(a2)
        move.b 37(a2),d0
        add.b d0,13(a2)
        move.b X_SBYTE3(a2),d0
        add.b d0,12(a2)
        bra.s M4TiSpRotDone
M4TiSpRotTree:
        btst #0,X_TISF3(a0)
        beq.s M4TiSpRotDone
        move.b 37(a2),d0
        add.b d0,14(a2)
        bra.s M4TiSpRotDone
M4TiSpRotSnake:
        btst #TI_SF8,X2_FL4(a0)
        beq.s M4TiSpRotNotNess
        addi.b #$f0,12(a2)
        bclr #F2_SFLAG1,48(a2)
        bra.s M4TiSpRotDone
M4TiSpRotNotNess:
        addi.b #$f8,12(a2)
M4TiSpRotDone:
        bsr M4TiSpOffset
        move.l M4_TI_SPSTRAT,32(a2)
        move.w a2,X_ALPTR(a0)
        bsr M4TiSpBounds
        beq.s M4TiSpStrat3I
        move.w #$ffff,X_ALPTR(a0)
        move.l a0,-(sp)
        movea.l a2,a0
        jsr M4LevelRemove
        movea.l (sp)+,a0
; A078 strat3_i: HP iHP, shape sproutbody, strategy A093 (and A093 now).
M4TiSpStrat3I:
        move.b M4_TI_SPIHP,38(a0)
        move.w M4_TI_SPBODY,d0
        jsr M4MtSetHdr
        move.l #M4TiSpStrat3,32(a0)
; A093 strat3: a dragon: sflag5 -> withdraw_i; al_ptr $FFFF or sflag1:
; splash every 8th gameframe (y 0, z - 10). al_ptr 0 -> killme (fall). The
; tail timer sword1 hi counts down (then animate); a leafy flower makes a
; leaf when it reaches $FA.
M4TiSpStrat3:
        btst #F2_SFLAG2,48(a0)
        beq.s M4TiSp3NotSnake
        btst #0,X_TISF3(a0)
        bne M4TiSpWithdrawI
        cmpi.w #$ffff,X_ALPTR(a0)
        beq.s M4TiSp3Splash
        btst #F2_SFLAG1,48(a0)
        beq.s M4TiSp3NotSnake
M4TiSp3Splash:
        moveq #7,d0
        and.w M4_LV_GAMEFRAME,d0
        bne.s M4TiSp3NotSnake
        bsr M4TiSsplash
        beq.s M4TiSp3NotSnake
        clr.w 2(a2)
        subi.w #10,4(a2)
M4TiSp3NotSnake:
        tst.w X_ALPTR(a0)
        beq M4TiSpKillMe
        tst.b 40(a0)
        beq.s M4TiSpAnimate
        subq.b #1,40(a0)
        btst #1,X_TISF3(a0)
        beq M4TiSpDone
        btst #TI_SF4,X2_FL2(a0)
        beq M4TiSpDone
        cmpi.b #$fa,40(a0)
        bne M4TiSpDone
        bsr M4TiSpLeaf
        bra M4TiSpDone
; A214 animate: strategy finishup A28C; frame = $80 - sword1 lo; Loch Ness:
; with al_ptr $FFFF or sflag1 a splash (8C31, y 0, z - 10); not Loch Ness:
; HP 1. Then finishup now.
M4TiSpAnimate:
        move.l #M4TiSpFinish,32(a0)
        move.b #$80,d0
        sub.b 41(a0),d0
        move.b d0,16(a0)
        btst #TI_SF8,X2_FL4(a0)
        beq.s M4TiSpAnimHp
        cmpi.w #$ffff,X_ALPTR(a0)
        beq.s M4TiSpAnimSplash
        btst #F2_SFLAG1,48(a0)
        beq.s M4TiSpFinish
M4TiSpAnimSplash:
        bsr M4TiSplash
        beq.s M4TiSpFinish
        clr.w 2(a2)
        subi.w #10,4(a2)
        bra.s M4TiSpFinish
M4TiSpAnimHp:
        move.b #1,38(a0)
; A28C finishup: al_ptr 0 -> killme; shape sprouttail; frame + sword1 lo (a
; plain add); frame & $7F == 8 -> removed.
M4TiSpFinish:
        tst.w X_ALPTR(a0)
        beq.s M4TiSpKillMe
        move.w M4_TI_SPTAIL,d0
        cmp.w X_SHAPEHDR(a0),d0
        beq.s M4TiSpFinishShape
        jsr M4MtSetHdr
M4TiSpFinishShape:
        move.b 41(a0),d0
        add.b d0,16(a0)
        moveq #$7f,d0
        and.b 16(a0),d0
        cmpi.b #8,d0
        bne M4TiSpDone
        moveq #1,d0
        rts
; A029 killme: strategy fall_istrat A2E3 (next tick).
M4TiSpKillMe:
        move.l #M4TiSpFallI,32(a0)
        moveq #0,d0
        rts

; A03A withdraw_i: strategy A050, shape sprouthead. A050: frame & $7F = 0 ->
; the first object whose al_ptr is this one (find_alptr_l 09:B1C7) gets
; sflag5 and this one is removed; else frame - 4 (plain).
M4TiSpWithdrawI:
        move.l #M4TiSpWithdraw,32(a0)
        move.w M4_TI_SPHEAD,d0
        jsr M4MtSetHdr
M4TiSpWithdraw:
        moveq #$7f,d0
        and.b 16(a0),d0
        beq.s M4TiSpWithdrawn
        subq.b #4,16(a0)
        moveq #0,d0
        rts
M4TiSpWithdrawn:
        move.w M4_LV_HEAD,d0
M4TiSpFindPtr:
        beq.s M4TiSpWithdrawGone ;none: dummyobj in the original (flag written there)
        movea.w d0,a2
        cmpa.w X_ALPTR(a2),a0
        beq.s M4TiSpWithdrawFound
        move.w X_NEXT(a2),d0
        bra.s M4TiSpFindPtr
M4TiSpWithdrawFound:
        bset #0,X_TISF3(a2)
M4TiSpWithdrawGone:
        moveq #1,d0
        rts

; A138 createleaf: a sprouthead object with the base's angles at x +
; rot(x1, 0, -10) (x1 = -20, or 20 with sflag3: roty + $80), Istrat leaf
; A3A3, shape leaf CE6C, rotz + $20, sbyte1 = base sbyte1.
M4TiSpLeaf:
        move.w M4_TI_SPHEAD,d0
        jsr M4MtCreateHdr
        beq.s M4TiSpLeafDone
        move.b 12(a0),12(a2)
        move.b 13(a0),13(a2)
        move.b 14(a0),14(a2)
        moveq #-20,d3
        btst #TI_SF3,X2_FL2(a0)
        beq.s M4TiSpLeafSide
        moveq #20,d3
        addi.b #$80,13(a2)
M4TiSpLeafSide:
        move.l a2,-(sp)
        moveq #0,d4
        moveq #-10,d5
        movea.l a0,a2
        jsr M4WeaponOffset
        movea.l (sp)+,a2
        asr.w #2,d3
        asr.w #2,d4
        asr.w #2,d5
        add.w (a0),d3
        add.w 2(a0),d4
        add.w 4(a0),d5
        move.w d3,(a2)
        move.w d4,2(a2)
        move.w d5,4(a2)
        move.l #M4TiLeafI,32(a2)
        move.l a0,-(sp)
        movea.l a2,a0
        move.w #$ce6c,d0
        jsr M4MtSetHdr
        movea.l (sp)+,a0
        addi.b #$20,14(a2)
        move.b 36(a0),36(a2)
M4TiSpLeafDone:
        rts
; leaf A3A3: strategy A3DC, normcollptrs, HP $FF AP 8, enemy1, nohitaffect,
; colldisable, frame $80, sbyte1 = 4 - sbyte1. A3DC: frame + 1 up to
; 7 - sbyte1 (09:8064).
M4TiLeafI:
        move.l #M4TiLeaf,32(a0)
        jsr M4LvNormPtrs
        move.b #$ff,38(a0)
        move.b #8,39(a0)
        ori.b #CF_ENEMY1,44(a0)
        bset #SF_NOHITAFFECT,49(a0)
        bset #SF_COLLDISABLE,49(a0)
        move.b #$80,16(a0)
        moveq #4,d0
        sub.b 36(a0),d0
        move.b d0,36(a0)
M4TiLeaf:
        moveq #7,d1
        sub.b 36(a0),d1
        bsr M4TiAnimClamp
        moveq #0,d0
        rts

; 09:A3E5 remove_alptrs: al_ptr of every object of allst equal to a0 -> 0.
M4TiClearPtrs:
        move.w M4_LV_HEAD,d0
M4TiClearPtrsNext:
        beq.s M4TiClearPtrsDone
        movea.w d0,a3
        cmpa.w X_ALPTR(a3),a0
        bne.s M4TiClearPtrsSkip
        clr.w X_ALPTR(a3)
M4TiClearPtrsSkip:
        move.w X_NEXT(a3),d0
        bra.s M4TiClearPtrsNext
M4TiClearPtrsDone:
        rts

; A2E3 fall_istrat: strategy A30A, vel 30, roty = random, v = gen3d, vy
; -10, al_ptr references cleared. A30A: rotz + 5, rotx + 2, vy + 3; on the
; ground (y >= 0): y 0, vy = trunc(-vy / 4) (two rounded halvings), $FFFB..
; $FFFF -> 0; the low byte of vy 0 -> le_fin; otherwise (and in the air)
; pos += v and out of bounds (9FDB) -> le_fin. le_fin: expstrat explode,
; colldisable, HP 0.
M4TiSpFallI:
        move.l #M4TiSpFall,32(a0)
        move.b #30,15(a0)
        jsr M4IntroRandom
        move.b d0,13(a0)
        jsr M4EnGen3d
        move.w #-10,8(a0)
        bsr M4TiClearPtrs
M4TiSpFall:
        addq.b #5,14(a0)
        addq.b #2,12(a0)
        addq.w #3,8(a0)
        tst.w 2(a0)
        bmi.s M4TiSpFallMove
        clr.w 2(a0)
        move.w 8(a0),d0
        neg.w d0
        ext.l d0
        divs.w #4,d0
        cmpi.w #$fffb,d0
        blo.s M4TiSpFallVy
        moveq #0,d0
M4TiSpFallVy:
        move.w d0,8(a0)
        tst.b d0
        beq.s M4TiSpFallFin
M4TiSpFallMove:
        jsr M4EnMove
        movea.l a0,a2
        bsr M4TiSpBounds
        bne.s M4TiSpFallFin
        moveq #0,d0
        rts
M4TiSpFallFin:
        move.l #M4LevelExplode,X_EXP(a0)
        bset #SF_COLLDISABLE,49(a0)
        clr.b 38(a0)
        moveq #0,d0
        rts

; 9FDB boundscheck of a2 (Z clear = out): sflag7 of a0 (tunnel sprouts):
; outside [minpmoveX, maxpmoveX) or [minpmoveY, maxpmoveY) (unsigned); else
; y >= 0 (the ground).
M4TiSpBounds:
        btst #2,X_TISF3(a0)
        beq.s M4TiSpBoundsGround
        move.w M4_LP_MAXX,d0
        sub.w M4_LP_MINX,d0
        move.w (a2),d1
        sub.w M4_LP_MINX,d1
        cmp.w d0,d1
        bhs.s M4TiSpBoundsOut
        move.w M4_LP_MAXY,d0
        sub.w M4_LP_MINY,d0
        move.w 2(a2),d1
        sub.w M4_LP_MINY,d1
        cmp.w d0,d1
        bhs.s M4TiSpBoundsOut
        moveq #0,d0
        rts
M4TiSpBoundsGround:
        tst.w 2(a2)
        bpl.s M4TiSpBoundsOut
        moveq #0,d0
        rts
M4TiSpBoundsOut:
        moveq #1,d0
        rts

; 9F52 roffs: a2 pos += offset (0, -37, 0) rotated by a2's rotz, rotx,
; roty (1F:CC78, CAFB, C97B; BYTE results, no scaling).
M4TiSpOffset:
        movem.l d3-d5,-(sp)
        moveq #0,d3
        moveq #-37,d4
        moveq #0,d5
        jsr M4WeaponOffset
        asr.w #2,d3
        asr.w #2,d4
        asr.w #2,d5
        add.w d3,(a2)
        add.w d4,2(a2)
        add.w d5,4(a2)
        movem.l (sp)+,d3-d5
        rts
; copypos (09:8004) and copyrots (09:AF6B): a0 -> a2.
M4TiCopyPosRots:
        move.l (a0),(a2)
        move.w 4(a0),4(a2)
        move.b 12(a0),12(a2)
        move.b 13(a0),13(a2)
        move.b 14(a0),14(a2)
        rts
; copy_sflags (9E99..9EAA): ROM bytes $1D..$20 a0 -> a2 = the port bytes
; 48, 49, X2_FL2, X2_FL4 and X_TISF3.
M4TiCopySflags:
        move.b 48(a0),48(a2)
        move.b 49(a0),49(a2)
        move.b X2_FL2(a0),X2_FL2(a2)
        move.b X2_FL4(a0),X2_FL4(a2)
        move.b X_TISF3(a0),X_TISF3(a2)
        rts

; ---------------------------------------------------------------------
; snake head 04:F9C4 (snake_0 CEC0, made by the dragon base 9D2F; ROM
; build/agent-titania/dis/04_F9C4.txt): strategy FA32, hitflash 06:89A3 /
; expstrat FBC1, HP 4 AP 6, enemy1; a splash (8C31) with y 0; x >= player
; x: roty + $C0, else roty + $40.
M4StratTiSnake:
        move.l #M4TiSnakeTick,32(a0)
        move.l #M4LcHitFlash,X_COLL(a0)
        move.l #M4TiSnakeExp,X_EXP(a0)
        move.b #4,38(a0)
        move.b #6,39(a0)
        ori.b #CF_ENEMY1,44(a0)
        bsr M4TiSplash
        beq.s M4TiSnakeSide
        clr.w 2(a2)
M4TiSnakeSide:
        move.w (a0),d0
        cmp.w (a1),d0
        bmi.s M4TiSnakeLeft
        addi.b #$c0,13(a0)
        bra.s M4TiSnakeTick
M4TiSnakeLeft:
        addi.b #$40,13(a0)
; FA32: al_ptr's al_ptr $FFFF (the neck stopped) -> underwater FBE7. No
; sflag1: rotx / roty chase pitchTo / yawTo (player) by Achase8_1;
; sflag1 (Loch Ness head): getneck, its angles, roty + $80, rotx = $B0 -
; rotx. Then getneck again: position = neck + rot(0, y1, -10) by the
; neck's angles, y1 = -(frame * 10 - 40) (8-bit with the ROM's carries).
; sbyte2 1: every 16th gameframe a firebreath AD2D (09:BE9B, vel 120,
; trigse $2E not ported); sbyte2 > 1: sbyte2 - 1.
M4TiSnakeTick:
        movea.w X_ALPTR(a0),a2
        cmpi.w #$ffff,X_ALPTR(a2)
        beq M4TiSnakeUnder
        btst #F2_SFLAG1,48(a0)
        bne.s M4TiSnakeNess
        movea.l a1,a2
        jsr M4EnPitchTo
        move.b d0,d1
        move.b 12(a0),d0
        moveq #1,d2
        jsr M4EnChase8
        move.b d0,12(a0)
        movea.l a1,a2
        jsr M4EnYawTo
        move.b d0,d1
        move.b 13(a0),d0
        moveq #1,d2
        jsr M4EnChase8
        move.b d0,13(a0)
        bra.s M4TiSnakePlace
M4TiSnakeNess:
        bsr M4TiGetNeck
        beq M4TiSnakeRemove
        cmpa.w #$ffff,a2
        beq.s M4TiSnakePlace
        move.b 12(a2),d0
        neg.b d0
        addi.b #$b0,d0
        move.b d0,12(a0)
        move.b 13(a2),d0
        addi.b #$80,d0
        move.b d0,13(a0)
        move.b 14(a2),14(a0)
M4TiSnakePlace:
        bsr M4TiGetNeck
        beq M4TiSnakeRemove
        moveq #$7f,d4 ;y1: a = frame & $7F; t = 2a; u = 2t, v = 2u (carry
        and.b 16(a2),d4 ;of u's shift kept); w = v + t + c; r = w + $D8 + c
        add.b d4,d4
        move.b d4,d1 ;t
        add.b d4,d4 ;u (X = bit 7 of t)
        add.b d4,d4 ;v, X = bit 7 of u
        addx.b d1,d4 ;w = v + t + X
        moveq #-40,d1
        addx.b d1,d4 ;r = w + $D8 + carry of w
        neg.b d4
        ext.w d4
        movem.l d3-d5,-(sp)
        moveq #0,d3
        moveq #-10,d5
        jsr M4WeaponOffset
        asr.w #2,d3
        asr.w #2,d4
        asr.w #2,d5
        add.w (a2),d3
        add.w 2(a2),d4
        add.w 4(a2),d5
        move.w d3,(a0)
        move.w d4,2(a0)
        move.w d5,4(a0)
        movem.l (sp)+,d3-d5
        move.b 37(a0),d0
        beq.s M4TiSnakeDone
        cmpi.b #1,d0
        bne.s M4TiSnakeBreathWait
        moveq #15,d0
        and.w M4_LV_GAMEFRAME,d0
        bne.s M4TiSnakeDone
        move.w #$ad2d,d0
        jsr M4MtCreateHdr
        beq.s M4TiSnakeDone
        bsr M4TiCopyPosRots
        move.l #M4TiFireBreathI,32(a2)
        move.b #120,15(a2)
        bra.s M4TiSnakeDone
M4TiSnakeBreathWait:
        subq.b #1,37(a0)
M4TiSnakeDone:
        moveq #0,d0
        rts
M4TiSnakeRemove:
        moveq #1,d0
        rts
; FCB6 getneck: a2 = al_ptr (0: Z set, the caller removes itself: FBBA);
; when that object has an al_ptr, a2 = it and al_ptr = it (the head walks up
; the chain).
M4TiGetNeck:
        move.w X_ALPTR(a0),d0
        beq.s M4TiGetNeckNone
        movea.w d0,a2
        move.w X_ALPTR(a2),d0
        beq.s M4TiGetNeckOk
        movea.w d0,a2
        move.w d0,X_ALPTR(a0)
M4TiGetNeckOk:
        moveq #1,d0
        rts
M4TiGetNeckNone:
        rts
; FBC1 (expstrat): not Loch Ness: the neck gets sflag5 (getneck: no neck ->
; removed); al_ptr 0; explode_Istrat 06:F45F.
M4TiSnakeExp:
        btst #F2_SFLAG1,48(a0)
        bne.s M4TiSnakeExpNow
        bsr M4TiGetNeck
        beq.s M4TiSnakeRemove
        bset #0,X_TISF3(a2)
M4TiSnakeExpNow:
        clr.w X_ALPTR(a0)
        move.l #M4LevelExplode,X_EXP(a0)
        jmp M4LevelExplode
; FBE7 underwater: strategy FC27, nullshape, the base's angles, vel -20,
; sbyte1 10, rotx 0, (vx, vz) = gen2d. FC27: pos += v; sbyte1 counts down;
; then roty + $80, Achase8_1 toward yawTo(player), roty + $80, a new Loch
; Ness (09:9997) nullshape object here (y 0, sword1 hi = sbyte3; sound
; 03:B735 not ported) and the head is removed.
M4TiSnakeUnder:
        move.l #M4TiSnakeDive,32(a0)
        move.w #$aca1,d0
        jsr M4MtSetHdr
        move.b 12(a2),12(a0)
        move.b 13(a2),13(a0)
        move.b 14(a2),14(a0)
        move.b #$ec,15(a0)
        move.b #10,36(a0)
        clr.b 12(a0)
        jsr M4EnGen2d
M4TiSnakeDive:
        jsr M4EnMove
        tst.b 36(a0)
        beq.s M4TiSnakeRise
        subq.b #1,36(a0)
        moveq #0,d0
        rts
M4TiSnakeRise:
        addi.b #$80,13(a0)
        movea.l a1,a2
        jsr M4EnYawTo
        move.b d0,d1
        move.b 13(a0),d0
        moveq #1,d2
        jsr M4EnChase8
        addi.b #$80,d0
        move.b d0,13(a0)
        move.w #$aca1,d0
        jsr M4MtCreateHdr
        beq M4TiSnakeRemove
        bsr M4TiCopyPosRots
        move.l #M4StratTiLochNess,32(a2)
        clr.w 2(a2)
        move.b X_SBYTE3(a0),40(a2)
        moveq #1,d0
        rts

; firebreathe2 09:BE9B (AD2D sprite of the sea dragon): colframe $80,
; nohitaffect, HP $FF AP 8, enemy1, sbyte1 2, ssprite, depthoffset 0, tx 0.
; BECA: strategy BEE1, normcollptrs, v = gen3d (its vel and angles), then
; it faces the camera (09:802A).
M4TiFireBreathI:
        move.b #$80,18(a0)
        bset #SF_NOHITAFFECT,49(a0)
        move.b #$ff,38(a0)
        move.b #8,39(a0)
        ori.b #CF_ENEMY1,44(a0)
        move.b #2,36(a0)
        bset #F2_SPRITE,48(a0)
        clr.b X_DEPTHOFF(a0)
        clr.b X_TX(a0)
M4TiFireBreathI2:
        move.l #M4TiFireBreath,32(a0)
        jsr M4LvNormPtrs
        jsr M4EnGen3d
        jsr M4EnFaceCamera
; BEE1: colframe + 1 mod 2; a trail AD2D behind it (allst head = it during
; the creation; Istrat BFA4, its position and angles, sbyte1); addplayerZ;
; pos += v; in the water (y >= 0): y 0, sbyte1 2, vel 80, it faces the
; player (09:8009) and BECA runs on the next tick; in the air: |x + 1000|
; >= 2000 (unsigned, |x| >= 1000) or ZD >= 4000 -> it becomes a trail
; (BFA4 now).
M4TiFireBreath:
        move.b 18(a0),d0
        addq.b #1,d0
        bmi.s M4TiFbMod
        addq.b #2,d0
M4TiFbMod:
        andi.b #$7f,d0
        cmpi.b #2,d0
        blo.s M4TiFbSet
        subq.b #2,d0
M4TiFbSet:
        ori.b #$80,d0
        move.b d0,18(a0)
        move.w #$ad2d,d0
        jsr M4MtCreateHdr
        beq.s M4TiFbMove
        bsr M4TiCopyPosRots
        move.l #M4TiFbTrailI,32(a2)
        move.b 36(a0),36(a2)
M4TiFbMove:
        jsr M4EnAddPZ
        jsr M4EnMove
        tst.w 2(a0)
        bmi.s M4TiFbAir
        clr.w 2(a0)
        move.b #2,36(a0)
        move.b #$50,15(a0)
        movea.l a1,a2
        jsr M4EnPitchTo
        move.b d0,12(a0)
        movea.l a1,a2
        jsr M4EnYawTo
        move.b d0,13(a0)
        move.l #M4TiFireBreathI2,32(a0)
        moveq #0,d0
        rts
M4TiFbAir:
        move.w (a0),d0
        addi.w #1000,d0
        cmpi.w #2000,d0
        bhs.s M4TiFbTrailI
        bsr M4TiZD
        cmpi.w #4000,d0
        bpl.s M4TiFbTrailI
        moveq #0,d0
        rts
; BFA4 trail: enemy1, addplayerZ, faces the camera, colframe $80, strategy
; BFE7, normcollptrs, nohitaffect, HP $FF AP 8, ssprite, depthoffset 0,
; tx 0. BFE7: colframe + sbyte1 (clamp 8); reaching it -> removed.
M4TiFbTrailI:
        ori.b #CF_ENEMY1,44(a0)
        jsr M4EnAddPZ
        jsr M4EnFaceCamera
        move.b #$80,18(a0)
        move.l #M4TiFbTrail,32(a0)
        jsr M4LvNormPtrs
        bset #SF_NOHITAFFECT,49(a0)
        move.b #$ff,38(a0)
        move.b #8,39(a0)
        bset #F2_SPRITE,48(a0)
        clr.b X_DEPTHOFF(a0)
        clr.b X_TX(a0)
M4TiFbTrail:
        move.b 18(a0),d0
        add.b 36(a0),d0
        bmi.s M4TiFbTrailMod
        addq.b #8,d0
M4TiFbTrailMod:
        andi.b #$7f,d0
        cmpi.b #8,d0
        bhs.s M4TiFbTrailEnd
        ori.b #$80,d0
        move.b d0,18(a0)
        moveq #0,d0
        rts
M4TiFbTrailEnd:
        move.b #$87,18(a0)
        moveq #1,d0
        rts

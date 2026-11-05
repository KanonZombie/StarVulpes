; Enemy weapons: fire_weapon 1F:D146 (table 1F:D17C, 3 bytes per even id x:
; routine WORD, bank at 1F:D17C+3x) and the strategies of their projectiles.
; Inventory, ROM addresses and correspondence: build/agent-weapons/WEAPONS.md
; (oracle tools/weapons-oracle.py: ROM 65816 executed vs this 68000 code).
; Authority: ref/Star Fox (USA).sfc (rev0, SHA-256 3857b529...a84d).
; fire_weapon's nofiring test ($14D4 bit0) is not modelled: the USA ROM only
; clears $14D4 (06:8026 stz every frame; the set is a debug ENEMY_FIRING
; build switch), so the test never stops a shot. Sounds (03:B6xx, snd2
; $1CE9) are not ported; their ids are listed in WEAPONS.md.
X_FIREOBJ equ -$8000+32 ;.w alx fireobjptr ($1CDD): engine flame of a missile
X_FIREOWNER equ -$8000+34 ;.w port: missile whose X_FIREOBJ is this flame
X_RELPOSZ equ -$8000+36 ;.b alx $1CE3: flame z offset lo8(-sh_zmax)
X_WFLAGS equ -$8000+37 ;.b bit0 = sflags2 $40 (sflag3, FakeFarHmissile1)
AF_ONFIRE equ 6 ;al_flags $40 (afonfire) in 51(a0)

; M4EnFire types (d0). Ids: fire_weapon numbers (M4PvWeaponTypes).
M4_WT_RSEH equ 0 ;$0A RelSlowElaserHome 06:AEE1
M4_WT_RSE equ 1 ;$0C RelSlowElaser 06:AE61
M4_WT_HPLASMA equ 2 ;$26 Hplasma 06:AD53
M4_WT_FRIEND equ 3 ;$06 FriendElaser 06:A8BF
M4_WT_RELBEAMBALL equ 4 ;$38 relbeamball / $22 plasma 06:A9BE
M4_WT_HMISSILE1 equ 5 ;$12 hmissile1 06:B0DE
M4_WT_REBELASER equ 6 ;$02 RebElaser 06:A937
M4_WT_ELASER equ 7 ;$04 Elaser 06:A7E3
M4_WT_SLOWELASER equ 8 ;$08 SlowElaser 06:AFE3
M4_WT_RELFAST equ 9 ;$0E RelFastElaser 06:AF61
M4_WT_FAKEFAR equ 10 ;$14 FakeFarHmissile1 06:B05D
M4_WT_KAMI equ 11 ;$16 kamiHmissile1 06:B240
M4_WT_CHICK equ 12 ;$18 chickhmissile1 06:B2B2
M4_WT_STB equ 13 ;$1A STBhmissile1 06:B324
M4_WT_HMISSILE2 equ 14 ;$1C hmissile2 06:B184
M4_WT_MISSILE2 equ 15 ;$20 missile2 06:B40B
M4_WT_SHORTPLASMA equ 16 ;$24 shortplasma 06:ACD0
M4_WT_OVALBEAM equ 17 ;$2E ovalbeam 06:ABCA
M4_WT_RINGLASER equ 18 ;$30 ringlaser 06:AC4D
M4_WT_RELOVALBEAM equ 19 ;$32 relovalbeam 06:AAC4
M4_WT_BOSSHM1 equ 20 ;$3A bosshmissile1 06:B1F6
M4_WT_BOSSHM2 equ 21 ;$3C bosshmissile2 06:B21B
M4_WT_PLAYERBEAM equ 22 ;$3E playerbeam 06:A848
M4_WT_COUNT equ 23

; Type record (fire routine 06:xxxx): make_obj shape, aldata HP/AP,
; alptrs Istrat/coll/exp, set_speed ($FF: doelaserspeed 06:B53C), lifecnt,
; collflags OR, port flags2 OR (relexplode/sprite), svar_weapZ add, options.
WT_SHAPE equ 0 ;.w descriptor
WT_HP equ 2
WT_AP equ 3
WT_INIT equ 4 ;.l Istrat
WT_COLL equ 8 ;.l collstrat ($1CD3)
WT_EXP equ 12 ;.l expstrat ($1CD0)
WT_SPEED equ 16
WT_LIFE equ 17
WT_CF equ 18
WT_F2 equ 19
WT_ZADD equ 20
WT_OPT equ 21
WT_SIZE equ 22
WO_FLASH equ 0 ;laserflash 06:B662
WO_PTR equ 1 ;al_ptr = shooter's al_ptr
WO_SFLAG3 equ 2 ;sflags2 |= $40, animframe = $80 (06:B05D)
WO_PUFF equ 3 ;exhaust puff 06:B14F
WO_FRIENDPOS equ 4 ;weaponpos (0,0,$50) (06:A8BF)
WF2_REL equ 1<<F2_RELEXPLODE
WF2_SPR equ 1<<F2_SPRITE
WF2_RS equ WF2_REL|WF2_SPR

        include '../build/m4-weapon-parameters.inc'
M4WpTypes:
        ; 0 RelSlowElaserHome 06:AEE1: Istrat 06:9EF4, flash
        dc.w M4_FX_ELASER2
        dc.b M4WpCfg00HP,M4WpCfg00AP
        dc.l M4WpRsehInit,M4WpCollide,M4WpLaserExp
        dc.b M4WpCfg00Speed,M4WpCfg00Life,M4WpCfg00Coll,WF2_REL,M4WpCfg00Z,1<<WO_FLASH
        ; 1 RelSlowElaser 06:AE61: Istrat 06:9E5C
        dc.w M4_FX_ELASER2
        dc.b M4WpCfg01HP,M4WpCfg01AP
        dc.l M4WpRseInit,M4WpCollide,M4WpLaserExp
        dc.b M4WpCfg01Speed,M4WpCfg01Life,M4WpCfg01Coll,WF2_REL,M4WpCfg01Z,1<<WO_FLASH
        ; 2 Hplasma 06:AD53: bouncyball AEED, Istrat 06:9A5B, exp remove
        dc.w M4_FX_BALL
        dc.b M4WpCfg02HP,M4WpCfg02AP
        dc.l M4WpPlasmaInit,M4WpCollide,M4EnRemoveSelf
        dc.b M4WpCfg02Speed,M4WpCfg02Life,M4WpCfg02Coll,WF2_RS,M4WpCfg02Z,0
        ; 3 FriendElaser 06:A8BF: elaser B369, weaponpos (0,0,$50)
        dc.w LV_PLASER_SHAPE
        dc.b M4WpCfg03HP,M4WpCfg03AP
        dc.l M4WpRseInit,M4WpCollide,M4WpLaserExp
        dc.b M4WpCfg03Speed,M4WpCfg03Life,M4WpCfg03Coll,0,M4WpCfg03Z,1<<WO_FRIENDPOS
        ; 4 relbeamball / plasma 06:A9BE: Istrat 06:9C1E
        dc.w M4_FX_BALL
        dc.b M4WpCfg04HP,M4WpCfg04AP
        dc.l M4WpBeamInit,M4WpCollide,M4EnRemoveSelf
        dc.b M4WpCfg04Speed,M4WpCfg04Life,M4WpCfg04Coll,WF2_RS,M4WpCfg04Z,0
        ; 5 hmissile1 06:B0DE: missile BABC, Istrat 06:926A, exp 06:F42E, puff
        dc.w M4_SH_HMISSILE
        dc.b M4WpCfg05HP,M4WpCfg05AP
        dc.l M4WpHm1Init,M4WpCollide,M4WpStopExp
        dc.b M4WpCfg05Speed,M4WpCfg05Life,M4WpCfg05Coll,WF2_REL,M4WpCfg05Z,(1<<WO_PTR)|(1<<WO_PUFF)
        ; 6 RebElaser 06:A937: B369, Istrat 06:9E5C
        dc.w LV_PLASER_SHAPE
        dc.b M4WpCfg06HP,M4WpCfg06AP
        dc.l M4WpRseInit,M4WpCollide,M4WpLaserExp
        dc.b M4WpCfg06Speed,M4WpCfg06Life,M4WpCfg06Coll,0,M4WpCfg06Z,0
        ; 7 Elaser 06:A7E3: B369, Pelaser 06:A18A, pelasercollide 06:8783,
        ; pelaser2die 06:A21D
        dc.w LV_PLASER_SHAPE
        dc.b M4WpCfg07HP,M4WpCfg07AP
        dc.l M4WpPelaserInit,M4WpPLaserColl,M4LcPLaserDeath
        dc.b M4WpCfg07Speed,M4WpCfg07Life,M4WpCfg07Coll,0,M4WpCfg07Z,0
        ; 8 SlowElaser 06:AFE3: elaser_Istrat 06:9FFD, flash
        dc.w M4_FX_ELASER2
        dc.b M4WpCfg08HP,M4WpCfg08AP
        dc.l M4WpElaserInit,M4WpCollide,M4WpLaserExp
        dc.b M4WpCfg08Speed,M4WpCfg08Life,M4WpCfg08Coll,0,M4WpCfg08Z,1<<WO_FLASH
        ; 9 RelFastElaser 06:AF61: Istrat 06:9E5C, flash
        dc.w M4_FX_ELASER2
        dc.b M4WpCfg09HP,M4WpCfg09AP
        dc.l M4WpRseInit,M4WpCollide,M4WpLaserExp
        dc.b M4WpCfg09Speed,M4WpCfg09Life,M4WpCfg09Coll,WF2_REL,M4WpCfg09Z,1<<WO_FLASH
        ; 10 FakeFarHmissile1 06:B05D: as hmissile1 + sflag3/anim, no puff
        dc.w M4_SH_HMISSILE
        dc.b M4WpCfg10HP,M4WpCfg10AP
        dc.l M4WpHm1Init,M4WpCollide,M4WpStopExp
        dc.b M4WpCfg10Speed,M4WpCfg10Life,M4WpCfg10Coll,WF2_REL,M4WpCfg10Z,(1<<WO_PTR)|(1<<WO_SFLAG3)
        ; 11 kamiHmissile1 06:B240: zaco_9 C7DC, Istrat 06:9590, explode 06:F45F
        dc.w M4_SH_ZACO_9
        dc.b M4WpCfg11HP,M4WpCfg11AP
        dc.l M4WpKamiInit,M4WpCollide,M4WpExplode
        dc.b M4WpCfg11Speed,M4WpCfg11Life,M4WpCfg11Coll,WF2_REL,M4WpCfg11Z,1<<WO_PTR
        ; 12 chickhmissile1 06:B2B2: c_miss E334, Istrat 06:975A, explode
        dc.w M4_SH_C_MISS
        dc.b M4WpCfg12HP,M4WpCfg12AP
        dc.l M4WpChickInit,M4WpCollide,M4WpExplode
        dc.b M4WpCfg12Speed,M4WpCfg12Life,M4WpCfg12Coll,WF2_REL,M4WpCfg12Z,1<<WO_PTR
        ; 13 STBhmissile1 06:B324: Istrat 06:9864 (speed set there)
        dc.w M4_SH_HMISSILE
        dc.b M4WpCfg13HP,M4WpCfg13AP
        dc.l M4WpStbInit,M4WpCollide,M4WpStopExp
        dc.b M4WpCfg13Speed,M4WpCfg13Life,M4WpCfg13Coll,WF2_REL,M4WpCfg13Z,1<<WO_PTR
        ; 14 hmissile2 06:B184: Istrat 06:941B
        dc.w M4_SH_HMISSILE
        dc.b M4WpCfg14HP,M4WpCfg14AP
        dc.l M4WpHm2Init,M4WpCollide,M4WpStopExp
        dc.b M4WpCfg14Speed,M4WpCfg14Life,M4WpCfg14Coll,WF2_REL,M4WpCfg14Z,1<<WO_PTR
        ; 15 missile2 06:B40B: Istrat 06:9D66
        dc.w M4_SH_HMISSILE
        dc.b M4WpCfg15HP,M4WpCfg15AP
        dc.l M4WpMis2Init,M4WpCollide,M4WpStopExp
        dc.b M4WpCfg15Speed,M4WpCfg15Life,M4WpCfg15Coll,WF2_REL,M4WpCfg15Z,1<<WO_PTR
        ; 16 shortplasma 06:ACD0: Istrat 06:9C1E
        dc.w M4_FX_BALL
        dc.b M4WpCfg16HP,M4WpCfg16AP
        dc.l M4WpBeamInit,M4WpCollide,M4EnRemoveSelf
        dc.b M4WpCfg16Speed,M4WpCfg16Life,M4WpCfg16Coll,WF2_RS,M4WpCfg16Z,0
        ; 17 ovalbeam 06:ABCA: B021, flatmiss 06:9C68
        dc.w M4_FX_OVALBEAM
        dc.b M4WpCfg17HP,M4WpCfg17AP
        dc.l M4WpFlatInit,M4WpCollide,M4EnRemoveSelf
        dc.b M4WpCfg17Speed,M4WpCfg17Life,M4WpCfg17Coll,WF2_RS,M4WpCfg17Z,0
        ; 18 ringlaser 06:AC4D: AD65, flatmiss 06:9C68
        dc.w M4_FX_RINGLASER
        dc.b M4WpCfg18HP,M4WpCfg18AP
        dc.l M4WpFlatInit,M4WpCollide,M4EnRemoveSelf
        dc.b M4WpCfg18Speed,M4WpCfg18Life,M4WpCfg18Coll,WF2_RS,M4WpCfg18Z,0
        ; 19 relovalbeam 06:AAC4: B021, Istrat 06:9C1E
        dc.w M4_FX_OVALBEAM
        dc.b M4WpCfg19HP,M4WpCfg19AP
        dc.l M4WpBeamInit,M4WpCollide,M4EnRemoveSelf
        dc.b M4WpCfg19Speed,M4WpCfg19Life,M4WpCfg19Coll,WF2_RS,M4WpCfg19Z,0
        ; 20 bosshmissile1 06:B1F6 = fire_hmissile1 + expstrat 06:FA53
        dc.w M4_SH_HMISSILE
        dc.b M4WpCfg20HP,M4WpCfg20AP
        dc.l M4WpHm1Init,M4WpCollide,M4WpGate2Exp
        dc.b M4WpCfg20Speed,M4WpCfg20Life,M4WpCfg20Coll,WF2_REL,M4WpCfg20Z,(1<<WO_PTR)|(1<<WO_PUFF)
        ; 21 bosshmissile2 06:B21B = fire_hmissile2 + expstrat 06:FA53
        dc.w M4_SH_HMISSILE
        dc.b M4WpCfg21HP,M4WpCfg21AP
        dc.l M4WpHm2Init,M4WpCollide,M4WpGate2Exp
        dc.b M4WpCfg21Speed,M4WpCfg21Life,M4WpCfg21Coll,WF2_REL,M4WpCfg21Z,1<<WO_PTR
        ; 22 playerbeam 06:A848: B1FD sprite, Pbeam 06:A10D, playerbeamdie 06:A22A
        dc.w M4_FX_PBEAM
        dc.b M4WpCfg22HP,M4WpCfg22AP
        dc.l M4WpPbeamInit,M4WpPLaserColl,M4WpPbeamDie
        dc.b M4WpCfg22Speed,M4WpCfg22Life,M4WpCfg22Coll,WF2_SPR,M4WpCfg22Z,0

; ---------------------------------------------------------------------
; fire_weapon 1F:D146 -> fire routine 06:xxxx + gen_weapon 06:B552.
; d0 = type (M4_WT_*), a0 = shooter (X), d3/d4/d5 offset BYTEs
; ($1547/49/4B), d6 rotx add ($154E), d7 roty add ($154D), a3 target or 0
; ($154F). Returns a2 = weapon or 0. The weapon (and the muzzle flash /
; exhaust puff, created with X = the weapon) is linked right behind X
; (1F:D3A9), so its Istrat runs in this same traversal.
M4EnFire:
        ; $154E/$154D/$154F stay set after every fire_weapon (gen_weapon
        ; 06:B552 reads them; nobody clears them): warp 0A:C543 reuses them.
        move.b d6,M4_VO_WROTX ;level_venom_orbital.asm RAM
        move.b d7,M4_VO_WROTY
        move.l a3,M4_VO_WTGT
        movem.l d0-d7/a0-a1/a3-a4,-(sp)
        movea.l a0,a4
        cmpi.w #M4_WT_COUNT,d0
        bhs M4EnFireBad
        move.w d0,d2
        bsr M4WpTypeRec
        btst #WO_FRIENDPOS,WT_OPT(a1)
        beq.s M4EnFirePos
        moveq #0,d3
        moveq #0,d4
        moveq #$50,d5
M4EnFirePos:
        move.l M4_LV_CREATOR,-(sp)
        move.l a4,M4_LV_CREATOR
        jsr M4LevelAlloc
        move.l (sp)+,M4_LV_CREATOR
        move.l a0,d1
        beq M4EnFireFail
        move.w WT_SHAPE(a1),d0
        jsr M4LevelSetShape
        move.b WT_HP(a1),38(a0)
        move.b WT_AP(a1),39(a0)
        move.l WT_COLL(a1),X_COLL(a0)
        move.l WT_EXP(a1),X_EXP(a0)
        move.l WT_INIT(a1),32(a0)
        move.b WT_SPEED(a1),d0
        cmpi.b #$ff,d0
        bne.s M4EnFireSpeed
        moveq #48,d0 ;doelaserspeed 06:B53C: 48 if currentlevel 0, else 60
        tst.b M4_GS_CURLEVEL
        beq.s M4EnFireSpeed
        moveq #60,d0
M4EnFireSpeed:
        move.b d0,15(a0)
        move.b WT_LIFE(a1),19(a0)
        move.b WT_CF(a1),d0
        or.b d0,44(a0)
        move.b WT_F2(a1),d0
        or.b d0,48(a0)
        add.b WT_ZADD(a1),d5 ;svar_weapZ += 20 (gen_weapon reads its BYTE)
        btst #WO_PTR,WT_OPT(a1)
        beq.s M4EnFireNoPtr
        move.w X_ALPTR(a4),X_ALPTR(a0)
M4EnFireNoPtr:
        btst #WO_SFLAG3,WT_OPT(a1)
        beq.s M4EnFireGen
        bset #0,X_WFLAGS(a0)
        move.b #$80,16(a0)
M4EnFireGen:
        ; gen_weapon: type atmissile, collflags weapon, shooter angles,
        ; rotz 0, position = shooter + 4*rot(offset)
        move.b #2,45(a0)
        ori.b #$02,44(a0)
        move.b 12(a4),12(a0)
        move.b 13(a4),13(a0)
        clr.b 14(a0)
        movea.l a4,a2
        jsr M4WeaponOffset
        add.w (a4),d3
        add.w 2(a4),d4
        add.w 4(a4),d5
        move.w d3,(a0)
        move.w d4,2(a0)
        move.w d5,4(a0)
        move.l a3,d0
        beq.s M4EnFireNoTarget
        movea.l a3,a1
        jsr M4IntroWeaponAim
M4EnFireNoTarget:
        add.b d6,12(a0)
        add.b d7,13(a0)
        move.b 12(a0),36(a0)
        move.b 13(a0),37(a0)
        move.b 15(a4),X_SBYTE3(a0)
        move.w a0,28(a4) ;make_immune: immuneptr crossed
        move.w a4,28(a0)
        movea.l a0,a2
        bsr M4WpTypeRec
        jsr M4SoundWeapon
        btst #WO_FLASH,WT_OPT(a1)
        beq.s M4EnFireNoFlash
        bsr M4WpLaserFlash
M4EnFireNoFlash:
        btst #WO_PUFF,WT_OPT(a1)
        beq.s M4EnFireDone
        bsr M4WpPuff
        bra.s M4EnFireDone
M4EnFireBad:
        move.w d0,M4_LV_BADOP ;unknown type: the level stops (M4_LV_STATUS)
        move.w #$ffff,M4_LV_STATUS
M4EnFireFail:
        suba.l a2,a2
M4EnFireDone:
        movem.l (sp)+,d0-d7/a0-a1/a3-a4
        rts
; d2 = type -> a1 = its M4WpTypes record.
M4WpTypeRec:
        move.l d2,-(sp)
        andi.l #$ffff,d2
        mulu.w #WT_SIZE,d2
        lea M4WpTypes,a1
        adda.l d2,a1
        move.l (sp)+,d2
        rts

; M4EnFire with a fire_weapon id in d0 (M4PvWeaponTypes); an id without a
; port stops the level like an unknown path id ($7044+). Returns a2.
M4EnFireId:
        movem.l d1-d2/a1,-(sp)
        lea M4PvWeaponTypes,a1
M4EnFireIdFind:
        move.b (a1)+,d1
        bmi.s M4EnFireIdBad
        move.b (a1)+,d2
        cmp.b d1,d0
        bne.s M4EnFireIdFind
        moveq #0,d0
        move.b d2,d0
        movem.l (sp)+,d1-d2/a1
        bra M4EnFire
M4EnFireIdBad:
        andi.w #$ff,d0
        addi.w #$7000,d0
        move.w d0,M4_LV_BADOP
        move.w #$ffff,M4_LV_STATUS
        suba.l a2,a2
        movem.l (sp)+,d1-d2/a1
        rts

; laserflash 06:B662 (a2 = laser): Sflash/Mflash/Lflash by ZD(laser,
; player) < 500 / < 1000, at the laser, roty $80, flash_Istrat 06:B6E6;
; created with X = the laser (linked behind it).
M4WpLaserFlash:
        movem.l d0-d1/a0,-(sp)
        move.l M4_LV_CREATOR,-(sp)
        move.l a2,M4_LV_CREATOR
        lea LV_PLAYER,a0
        move.w 4(a0),d0
        sub.w 4(a2),d0
        bpl.s M4WpFlashAbs
        neg.w d0
M4WpFlashAbs:
        move.w d0,d1
        move.l #M4_FX_FLASH16,d0 ;descriptor index may exceed 127
        subi.w #500,d1
        bmi.s M4WpFlashShape
        move.l #M4_FX_FLASH32,d0 ;descriptor index may exceed 127
        subi.w #500,d1
        bmi.s M4WpFlashShape
        move.l #M4_FX_FLASH64,d0 ;descriptor index may exceed 127
M4WpFlashShape:
        move.w d0,d1
        jsr M4LevelAlloc
        move.l a0,d0
        beq.s M4WpFlashFail
        move.w d1,d0
        jsr M4LevelSetShape
        move.l (a2),(a0)
        move.w 4(a2),4(a0)
        move.b #$80,13(a0)
        move.l #M4WpFlashInit,32(a0)
M4WpFlashFail:
        move.l (sp)+,M4_LV_CREATOR
        movem.l (sp)+,d0-d1/a0
        rts

; Exhaust puff of fire_hmissile1 06:B14F (a2 = missile): smoke ADD5 created
; with X = the missile, copy_pos, realobj cleared (not modelled), puff
; Istrat 06:8F01.
M4WpPuff:
        movem.l d0/a0,-(sp)
        move.l M4_LV_CREATOR,-(sp)
        move.l a2,M4_LV_CREATOR
        jsr M4LevelAlloc
        move.l (sp)+,M4_LV_CREATOR
        move.l a0,d0
        beq.s M4WpPuffFail
        move.l #M4_FX_SMOKE,d0 ;descriptor index may exceed 127
        jsr M4LevelSetShape
        move.l (a2),(a0)
        move.w 4(a2),4(a0)
        move.l #M4WpPuffInit,32(a0)
M4WpPuffFail:
        movem.l (sp)+,d0/a0
        rts
; 06:8F01: no coll/exp strategies, colldisable, colframe $80, ssprite,
; depthoffset 0, tx 0; falls into 06:8F2F: facing the camera, colframe
; (c+1) mod 9, removed (deferred) at 8, z += pviewvelz.
M4WpPuffInit:
        move.l #M4WpPuffTick,32(a0)
        clr.l X_COLL(a0)
        clr.l X_EXP(a0)
        bset #SF_COLLDISABLE,49(a0)
        move.b #$80,18(a0)
        bset #F2_SPRITE,48(a0)
        clr.b X_DEPTHOFF(a0)
        clr.b X_TX(a0)
M4WpPuffTick:
        moveq #0,d7
        bsr M4EnFaceCamera
        move.b 18(a0),d0
        moveq #1,d1
        moveq #9,d2
        bsr M4WpAddAnim
        move.b d0,18(a0)
        andi.b #$7f,d0
        cmpi.b #8,d0
        bne.s M4WpPuffMove
        moveq #1,d7
M4WpPuffMove:
        bsr M4EnAddPZ
        move.l d7,d0
        rts

; s_add_anim / s_add_COLanim (n, mod): t = c + n; t >= 0 -> t += mod;
; t &= $7F; t >= mod -> t -= mod; | $80. d0.b value, d1 n, d2 mod.
M4WpAddAnim:
        add.b d1,d0
        bmi.s M4WpAddAnimMask
        add.b d2,d0
M4WpAddAnimMask:
        andi.b #$7f,d0
        cmp.b d2,d0
        blo.s M4WpAddAnimDone
        sub.b d2,d0
M4WpAddAnimDone:
        ori.b #$80,d0
        rts

; ---------------------------------------------------------------------
; Missile engine flame. makeengine 06:916D (a0 = missile): boostshape
; B219 created with X = the missile; relposz = lo8(-sh_zmax), tx =
; lo8(sh_ymax - 24), ssprite, depthoffset 0, colldisable, fireobjptr;
; placed now (06:91DF) and then invisible until the next placement;
; afonfire. The flame has no strategy (it stays until zremove or the
; missile's explosion removes it, 06:F4EE).
M4WpMakeEngine:
        movem.l d0-d1/a2-a3,-(sp)
        move.l M4_LV_CREATOR,-(sp)
        move.l a0,M4_LV_CREATOR
        move.l #M4_FX_BOOST,d0 ;descriptor index may exceed 127
        bsr M4EnCreate
        move.l (sp)+,M4_LV_CREATOR
        cmpa.w #0,a2
        beq.s M4WpMakeEngineDone
        move.w #$88,d1 ;nullshape 00:ACA1: ymax 136, zmax 144
        move.w 46(a0),d0
        cmpi.w #$ffff,d0
        beq.s M4WpMakeEngineNull
        lsl.w #5,d0
        lea M4LevelShapeDescriptors,a3
        move.w 22(a3,d0.w),d1 ;sh_ymax
        move.w 24(a3,d0.w),d0 ;sh_zmax
        bra.s M4WpMakeEngineSet
M4WpMakeEngineNull:
        move.w #$90,d0
M4WpMakeEngineSet:
        neg.w d0
        move.b d0,X_RELPOSZ(a2)
        subi.w #24,d1
        move.b d1,X_TX(a2)
        bset #F2_SPRITE,48(a2)
        clr.b X_DEPTHOFF(a2)
        move.w a2,X_FIREOBJ(a0)
        move.w a0,X_FIREOWNER(a2)
        bset #SF_COLLDISABLE,49(a2)
        bsr M4WpUpdateEngine
        bset #3,X2_FL4(a2) ;sflags4 invisible
        bset #SF_INVISIBLE,49(a2)
        bset #AF_ONFIRE,51(a0)
M4WpMakeEngineDone:
        movem.l (sp)+,d0-d1/a2-a3
        rts
; updateengine 06:91DF: flame visible at missile + Ry(Rx(0, 0, relposz))
; (1F:CAFB by rotx, 1F:C97B by roty; BYTE products as boost_strat). The
; ROM clears fireobjptr when the flame is removed (1F:BFFA); the port keeps
; the pointer and checks that the slot is still this missile's flame.
M4WpUpdateEngine:
        movem.l d0-d6/a2,-(sp)
        bsr M4WpFlameOf
        beq.s M4WpUpdEngineDone
        bclr #3,X2_FL4(a2)
        bclr #SF_INVISIBLE,49(a2)
        moveq #0,d3 ;y
        move.b X_RELPOSZ(a2),d4 ;z
        move.b 12(a0),d5
        jsr M4WeaponRotatePair ;(y,z) by rotx
        move.b d3,d6 ;y
        moveq #0,d3 ;x
        move.b 13(a0),d5
        neg.b d5
        jsr M4WeaponRotatePair ;(x,z) by roty
        ext.w d3
        ext.w d4
        ext.w d6
        add.w (a0),d3
        add.w 2(a0),d6
        add.w 4(a0),d4
        move.w d3,(a2)
        move.w d6,2(a2)
        move.w d4,4(a2)
M4WpUpdEngineDone:
        movem.l (sp)+,d0-d6/a2
        rts
; a0 = missile -> a2 = its live flame, Z clear; or Z set (none).
M4WpFlameOf:
        move.w X_FIREOBJ(a0),d0
        beq.s M4WpFlameNone
        movea.w d0,a2
        tst.w 22(a2)
        beq.s M4WpFlameNone
        move.w X_FIREOWNER(a2),d0
        cmp.w a0,d0
        bne.s M4WpFlameNone
        moveq #1,d0
        rts
M4WpFlameNone:
        moveq #0,d0
        rts

; remove_obj 1F:D501 on a missile (d7 = 1: deferred removal of a0): with
; afonfire the flame is removed at once (flag and fireobjptr cleared).
M4WpDoomed:
        moveq #1,d7
; 1F:D50B: afonfire -> flame removed now. Registers kept.
M4WpDropFlame:
        bclr #AF_ONFIRE,51(a0)
        beq.s M4WpDropFlameDone
        movem.l d0/a0/a2,-(sp)
        bsr M4WpFlameOf
        clr.w X_FIREOBJ(a0)
        tst.w d0
        beq.s M4WpDropFlameRest
        movea.l a2,a0
        jsr M4LevelRemove
M4WpDropFlameRest:
        movem.l (sp)+,d0/a0/a2
M4WpDropFlameDone:
        rts
; explode_Istrat 06:F45F for the missiles: afonfire -> the flame is removed
; (in view: 06:F4EE, before the explosion is created; out of view: 06:8D12
; -> 1F:D501), then the shared M4LevelExplode. Its earlier steps (special
; gate, debris) do not apply to weapons (no special flag, debrisshape 0).
M4WpExplode:
        bsr M4WpDropFlame
        jmp M4LevelExplode
; stopexplode_Istrat 06:F42E: relexplode, back one step, v and vel 0
; (1F:DB45), explode_Istrat.
M4WpStopExp:
        bset #F2_RELEXPLODE,48(a0)
        move.w 6(a0),d0
        sub.w d0,(a0)
        move.w 8(a0),d0
        sub.w d0,2(a0)
        move.w 10(a0),d0
        sub.w d0,4(a0)
        clr.l 6(a0)
        clr.w 10(a0)
        clr.b 15(a0)
        bra.s M4WpExplode
; explodegate2_Istrat 06:FA53 (boss missiles): random_l >= $CC and (no
; collobj or a laser collobj) -> gate_2 E4D8 at the missile (strategy
; 0A:E8B7), then stopexplode.
M4WpGate2Exp:
        jsr M4IntroRandom
        cmpi.b #$cc,d0
        blo.s M4WpStopExp
        jsr M4LcCollider
        move.l a2,d0
        beq.s M4WpGate2Make
        btst #3,44(a2)
        beq.s M4WpStopExp
M4WpGate2Make:
        move.l #M4_SH_GATE_2,d0 ;descriptor index may exceed 127
        bsr M4EnCreate
        beq.s M4WpStopExp
        move.l (a0),(a2)
        move.w 4(a0),4(a2)
        move.l #M4StratGate2,32(a2)
        bra.s M4WpStopExp

; ---------------------------------------------------------------------
; v = gen3d(vel) + gen3d(sbyte3) along (rotx, roty) (1F:D5A7 + 1F:C41E).
M4WpMisVec:
        bsr M4EnGen3d
        moveq #0,d0
        move.b X_SBYTE3(a0),d0
        ext.w d0
        move.b 12(a0),d1
        move.b 13(a0),d2
        bsr M4EnVector
        add.w d3,6(a0)
        add.w d4,8(a0)
        add.w d5,10(a0)
        rts
; rotx/roty chased toward the pitch/yaw of a2 by Achase8_n (d2 = n).
M4WpChaseTo:
        move.w d2,-(sp)
        bsr M4EnPitchTo
        move.b d0,d1
        move.b 12(a0),d0
        move.w (sp),d2
        bsr M4EnChase8
        move.b d0,12(a0)
        bsr M4EnYawTo
        move.b d0,d1
        move.b 13(a0),d0
        move.w (sp)+,d2
        bsr M4EnChase8
        move.b d0,13(a0)
        rts
; Common missile end: z += pviewvelz, pos += v; count-- (0: removed,
; deferred); 06:91DF; s_remove_offscn (type |= zremove, out of view:
; removed); miss_end 06:90DB. d7 = remove flag.
M4WpMisEnd:
        bsr M4EnAddPZ
        bsr M4EnMove
        subq.b #1,19(a0)
        bne.s M4WpMisEndEngine
        bsr M4WpDoomed
M4WpMisEndEngine:
        bsr M4WpUpdateEngine
M4WpMisEndView:
        bset #3,45(a0)
        btst #AF_INVIEWPL,51(a0)
        bne.s M4WpMisEndFinal
        bsr M4WpDoomed
M4WpMisEndFinal:
        bsr M4WpFinal
        move.l d7,d0
        rts

; hmissile1_Istrat 06:926A (hmissile1, FakeFar, bosshmissile1): snd2 2,
; shadow, Zenemy, v = gen3d(vel) + gen3d(sbyte3), makeengine. No move now.
M4WpHm1Init:
        move.l #M4WpHm1Tick,32(a0)
        bset #F2_SHADOW,48(a0)
        ori.b #$01,44(a0)
        bsr M4WpMisVec
        bsr M4WpMakeEngine
        moveq #0,d0
        rts
; 06:92CB: sflag3 -> animframe +1 mod 16 until 15; rotz += 10; unless
; sflag2: distXZ(al_ptr) < 300 -> sflag2, else rotx/roty Achase8_3 toward
; it and v recomputed. al_ptr 0: the ROM measures against WRAM 0 (not
; modelled: no distance test, v recomputed with the same angles).
M4WpHm1Tick:
        moveq #0,d7
        btst #0,X_WFLAGS(a0)
        beq.s M4WpHm1Spin
        move.b 16(a0),d0
        andi.b #$7f,d0
        cmpi.b #15,d0
        beq.s M4WpHm1Spin
        move.b 16(a0),d0
        moveq #1,d1
        moveq #16,d2
        bsr M4WpAddAnim
        move.b d0,16(a0)
M4WpHm1Spin:
        addi.b #10,14(a0)
        btst #F2_SFLAG2,48(a0)
        bne.s M4WpHm1End
        move.w X_ALPTR(a0),d0
        beq.s M4WpHm1Vec
        movea.w d0,a2
        bsr M4EnDistXZ
        subi.w #300,d0
        bpl.s M4WpHm1Guide
        bset #F2_SFLAG2,48(a0)
        bra.s M4WpHm1End
M4WpHm1Guide:
        moveq #3,d2
        bsr M4WpChaseTo
M4WpHm1Vec:
        bsr M4WpMisVec
M4WpHm1End:
        bra M4WpMisEnd

; hmissile2_Istrat 06:941B: as 06:926A with sbyte1 = 25.
M4WpHm2Init:
        move.l #M4WpHm2Tick,32(a0)
        bset #F2_SHADOW,48(a0)
        ori.b #$01,44(a0)
        move.b #25,36(a0)
        bsr M4WpMisVec
        bsr M4WpMakeEngine
        moveq #0,d0
        rts
; 06:9480: rotz += 10; --sbyte1 != 0 -> straight; sbyte1 = 1; unless sflag2:
; distXZ < 300 -> sflag2, else Achase8_1 toward al_ptr, v recomputed.
M4WpHm2Tick:
        moveq #0,d7
        addi.b #10,14(a0)
        subq.b #1,36(a0)
        bne.s M4WpHm2End
        move.b #1,36(a0)
        btst #F2_SFLAG2,48(a0)
        bne.s M4WpHm2End
        move.w X_ALPTR(a0),d0
        beq.s M4WpHm2Vec
        movea.w d0,a2
        bsr M4EnDistXZ
        subi.w #300,d0
        bpl.s M4WpHm2Guide
        bset #F2_SFLAG2,48(a0)
        bra.s M4WpHm2End
M4WpHm2Guide:
        moveq #1,d2
        bsr M4WpChaseTo
M4WpHm2Vec:
        bsr M4WpMisVec
M4WpHm2End:
        bra M4WpMisEnd

; hmissile3_Istrat 06:9590 (kamiHmissile1, zaco_9): as 06:926A.
M4WpKamiInit:
        move.l #M4WpKamiTick,32(a0)
        bset #F2_SHADOW,48(a0)
        ori.b #$01,44(a0)
        bsr M4WpMisVec
        bsr M4WpMakeEngine
        moveq #0,d0
        rts
; 06:95F1: unless sflag2: d = |al_ptr.z - z| (signed compares);
; 1000 <= d < 2000 and gameframe & 7 == 0 -> two RelSlowElaser, offsets
; (-1,7,0) and rot adds (0,+4) / (0,-4), no target (06:9628); then
; d < 500 -> sflag2; d < 2000 -> rotx/roty = pitch/yaw toward al_ptr (no
; chase) and v recomputed. Then 06:972B (91DF before count--).
; al_ptr 0 reads WRAM 0 in the ROM: not modelled (no shot, no homing).
M4WpKamiTick:
        moveq #0,d7
        btst #F2_SFLAG2,48(a0)
        bne.s M4WpKamiEnd
        move.w X_ALPTR(a0),d0
        beq.s M4WpKamiEnd
        movea.w d0,a2
        bsr M4EnZD
        move.w d0,d1
        subi.w #1000,d1 ;N-flag compares (cmp/bmi of the ROM)
        bmi.s M4WpKamiHome
        subi.w #1000,d1
        bpl.s M4WpKamiHome
        move.w M4_LV_GAMEFRAME,d0
        andi.w #7,d0
        bne.s M4WpKamiHome
        movem.l d7/a2,-(sp)
        moveq #M4_WT_RSE,d0
        moveq #-1,d3
        moveq #7,d4
        moveq #0,d5
        moveq #0,d6
        moveq #4,d7
        suba.l a3,a3
        bsr M4EnFire
        moveq #M4_WT_RSE,d0
        moveq #-1,d3
        moveq #7,d4
        moveq #0,d5
        moveq #0,d6
        moveq #-4,d7
        bsr M4EnFire
        movem.l (sp)+,d7/a2
M4WpKamiHome:
        bsr M4EnZD
        move.w d0,d1
        subi.w #500,d1
        bpl.s M4WpKamiFar
        bset #F2_SFLAG2,48(a0)
        bra.s M4WpKamiEnd
M4WpKamiFar:
        subi.w #1500,d1
        bpl.s M4WpKamiEnd
        bsr M4EnPitchTo
        move.b d0,12(a0)
        bsr M4EnYawTo
        move.b d0,13(a0)
        bsr M4WpMisVec
M4WpKamiEnd:
        bsr M4EnAddPZ
        bsr M4EnMove
        bsr M4WpUpdateEngine
        subq.b #1,19(a0)
        bne.s M4WpKamiView
        bsr M4WpDoomed
M4WpKamiView:
        bra M4WpMisEndView

; chickhmissile1_Istrat 06:975A: snd2 2, shadow, Zenemy, rotz $80.
M4WpChickInit:
        move.l #M4WpChickTick,32(a0)
        bset #F2_SHADOW,48(a0)
        ori.b #$01,44(a0)
        move.b #$80,14(a0)
        moveq #0,d0
        rts
; 06:977E: x/y Achase16_3 toward player_posx/y ($150F/$1511, 1F:D6AB);
; near (sflag2, or distXZ(player) < 400 with no direction held, $1202 &
; $0F): sflag2, colldisable, count-- (0: removed, deferred), rotx +2 when
; player.y < viewCY else -2; far: rotx/roty = pitch/yaw toward the player.
; v = gen3d(vel); z += pviewvelz, pos += v; offscreen; 06:90DB.
M4WpChickTick:
        moveq #0,d7
        move.w (a0),d0
        move.w M4_SC_PPOSX,d1
        moveq #3,d2
        jsr M4LpAchase
        move.w d0,(a0)
        move.w 2(a0),d0
        move.w M4_SC_PPOSY,d1
        moveq #3,d2
        jsr M4LpAchase
        move.w d0,2(a0)
        btst #F2_SFLAG2,48(a0)
        bne.s M4WpChickNear
        movea.l a1,a2
        bsr M4EnDistXZ
        subi.w #400,d0
        bpl.s M4WpChickFar
        move.b M4_LP_JOY,d0 ;$1202 (B Y Sel St U D L R)
        andi.b #$0f,d0
        bne.s M4WpChickFar
        bset #F2_SFLAG2,48(a0)
M4WpChickNear:
        bset #SF_COLLDISABLE,49(a0)
        subq.b #1,19(a0)
        bne.s M4WpChickTurn
        bsr M4WpDoomed
M4WpChickTurn:
        move.w 2(a1),d0
        sub.w M4_LP_VIEWCY,d0
        bmi.s M4WpChickUp
        subq.b #2,12(a0)
        bra.s M4WpChickVec
M4WpChickUp:
        addq.b #2,12(a0)
        bra.s M4WpChickVec
M4WpChickFar:
        movea.l a1,a2
        bsr M4EnPitchTo
        move.b d0,12(a0)
        bsr M4EnYawTo
        move.b d0,13(a0)
M4WpChickVec:
        bsr M4EnGen3d
        bsr M4EnAddPZ
        bsr M4EnMove
        bra M4WpMisEndView

; STBhmissile1_Istrat 06:9864: snd2 2, shadow, Zenemy, vel 10, sbyte3 20,
; makeengine; falls into 06:988F: speedto(60, 2); rotz += 10; unless
; sflag2: distXZ(al_ptr) < 600 -> sflag2; else (al_ptr != 0 and --sbyte3
; == 0: sbyte3 = 1, rotx/roty Achase8_4 toward al_ptr); sbyte1/sbyte2
; Achase8_3 toward roty/rotx; v = gen3d(vel, rotx = sbyte2, roty = sbyte1).
M4WpStbInit:
        move.l #M4WpStbTick,32(a0)
        bset #F2_SHADOW,48(a0)
        ori.b #$01,44(a0)
        move.b #10,15(a0)
        move.b #20,X_SBYTE3(a0)
        bsr M4WpMakeEngine
M4WpStbTick:
        moveq #0,d7
        moveq #60,d0
        moveq #2,d1
        bsr M4EnSpeedTo
        addi.b #10,14(a0)
        btst #F2_SFLAG2,48(a0)
        bne.s M4WpStbEnd
        move.w X_ALPTR(a0),d0
        beq.s M4WpStbChase
        movea.w d0,a2
        bsr M4EnDistXZ
        subi.w #600,d0
        bpl.s M4WpStbGuide
        bset #F2_SFLAG2,48(a0)
        bra.s M4WpStbEnd
M4WpStbGuide:
        subq.b #1,X_SBYTE3(a0)
        bne.s M4WpStbChase
        move.b #1,X_SBYTE3(a0)
        moveq #4,d2
        bsr M4WpChaseTo
M4WpStbChase:
        move.b 36(a0),d0
        move.b 13(a0),d1
        moveq #3,d2
        bsr M4EnChase8
        move.b d0,36(a0)
        move.b 37(a0),d0
        move.b 12(a0),d1
        moveq #3,d2
        bsr M4EnChase8
        move.b d0,37(a0)
        moveq #0,d0
        move.b 15(a0),d0
        ext.w d0
        move.b 37(a0),d1
        move.b 36(a0),d2
        bsr M4EnVector
        move.w d3,6(a0)
        move.w d4,8(a0)
        move.w d5,10(a0)
M4WpStbEnd:
        bra M4WpMisEnd

; missile2_Istrat 06:9D66: rotx/roty = sbyte1/sbyte2, type |= zremove,
; snd2 2, shadow, Zenemy, makeengine (v stays 0 until the first tick).
M4WpMis2Init:
        move.b 36(a0),12(a0)
        move.b 37(a0),13(a0)
        move.l #M4WpMis2Tick,32(a0)
        bset #3,45(a0)
        bset #F2_SHADOW,48(a0)
        ori.b #$01,44(a0)
        bsr M4WpMakeEngine
        moveq #0,d0
        rts
; 06:9D98: unless sflag2, ZD(player) < 600 -> speedto(100, 5); v =
; gen3d(vel); z += pviewvelz, pos += v; count-- (0: removed, deferred);
; rotx Achase8_2 toward 0, roty toward $80; rotz += 10; 91DF; 90DB.
M4WpMis2Tick:
        moveq #0,d7
        btst #F2_SFLAG2,48(a0)
        bne.s M4WpMis2Vec
        movea.l a1,a2
        bsr M4EnZD
        subi.w #600,d0
        bpl.s M4WpMis2Vec
        moveq #100,d0
        moveq #5,d1
        bsr M4EnSpeedTo
M4WpMis2Vec:
        bsr M4EnGen3d
        bsr M4EnAddPZ
        bsr M4EnMove
        subq.b #1,19(a0)
        bne.s M4WpMis2Turn
        bsr M4WpDoomed
M4WpMis2Turn:
        move.b 12(a0),d0
        moveq #0,d1
        moveq #2,d2
        bsr M4EnChase8
        move.b d0,12(a0)
        move.b 13(a0),d0
        move.b #$80,d1
        moveq #2,d2
        bsr M4EnChase8
        move.b d0,13(a0)
        addi.b #10,14(a0)
        bsr M4WpUpdateEngine
        bsr M4WpFinal
        move.l d7,d0
        rts

; elaser_Istrat 06:9FFD (SlowElaser): angles from sbyte1/2, v =
; 2*gen3d(vel) (1F:D5BC), frame $80. No move now.
M4WpElaserInit:
        move.l #M4WpElaserTick,32(a0)
        move.b 36(a0),12(a0)
        move.b 37(a0),13(a0)
        bsr M4EnGen3d
        asl.w 6(a0)
        asl.w 8(a0)
        asl.w 10(a0)
        move.b #$80,16(a0)
        moveq #0,d0
        rts
; 06:A02C: frame +2 mod 8 until 4; pos += v (no pviewvelz); count-- ->
; removed (no 90DB); else 90DB.
M4WpElaserTick:
        bsr M4WpLaserFrame
        bsr M4EnMove
        subq.b #1,19(a0)
        beq M4EnRemoveSelf
        bra M4WpFinal

; flatmiss_Istrat 06:9C68 (ovalbeam, ringlaser): sbyte1/2 = roty/rotx, v =
; gen3d(vel), snd2 6; falls into 06:9C95: facing the camera, pos += v (no
; pviewvelz), count-- -> colldisable, HP 0; 90DB.
M4WpFlatInit:
        move.l #M4WpFlatTick,32(a0)
        move.b 13(a0),36(a0)
        move.b 12(a0),37(a0)
        bsr M4EnGen3d
M4WpFlatTick:
        bsr M4EnFaceCamera
        bsr M4EnMove
        subq.b #1,19(a0)
        bne M4WpFinal
        bsr M4EnKill
        bra M4WpFinal

; Pelaser_Istrat 06:A18A (Elaser $04 fired by an enemy): angles from
; sbyte1/2, v = 4*gen3d(vel) + gen3d(sbyte3), animframe $84, colldisable
; unless pstratflags $10 (firstframeLcol). No move now.
M4WpPelaserInit:
        move.l #M4WpPelaserTick,32(a0)
M4WpPelaserVec:
        move.b 36(a0),12(a0)
        move.b 37(a0),13(a0)
        bsr M4EnGen3d
        movem.w 6(a0),d0-d2
        asl.w #2,d0
        asl.w #2,d1
        asl.w #2,d2
        movem.w d0-d2,6(a0)
        moveq #0,d0
        move.b X_SBYTE3(a0),d0
        ext.w d0
        move.b 12(a0),d1
        move.b 13(a0),d2
        bsr M4EnVector
        add.w d3,6(a0)
        add.w d4,8(a0)
        add.w d5,10(a0)
        move.b #$84,16(a0)
        btst #4,M4_BOSS_PSTRATF
        bne.s M4WpPelaserFf
        bset #SF_COLLDISABLE,49(a0)
M4WpPelaserFf:
        moveq #0,d0
        rts
; Pbeam_Istrat 06:A10D (playerbeam $3E): as Pelaser, tick 06:A178.
M4WpPbeamInit:
        move.l #M4WpPbeamTick,32(a0)
        bra.s M4WpPelaserVec
; 06:A178: rotx = roty = 0, rotz += $18, then 06:A1F5.
M4WpPbeamTick:
        clr.b 12(a0)
        clr.b 13(a0)
        addi.b #$18,14(a0)
; 06:A1F5: player dead ($14D9 bit7) -> removed (deferred); colldisable
; cleared; pos += v; count-- -> removed, numplasers-- (no 90DB); else 90DB.
M4WpPelaserTick:
        moveq #0,d7
        btst #7,M4_LP_PSF2
        beq.s M4WpPelaserLive
        moveq #1,d7
M4WpPelaserLive:
        bclr #SF_COLLDISABLE,49(a0)
        bsr M4EnMove
        subq.b #1,19(a0)
        bne.s M4WpPelaserFinal
        subq.b #1,M4_LP_NUMLASERS
        moveq #1,d0
        rts
M4WpPelaserFinal:
        bsr M4WpFinal
        move.l d7,d0
        rts
; pelasercollide 06:8783 (Elaser, playerbeam): hitwall sound when the
; collider is nohitaffect/indestructible/without collstrat (not ported);
; colldisable, HP 0, then the object's own expstrat now (A21D or A22A).
M4WpPLaserColl:
        bclr #SF_COLLIDE,49(a0)
        bset #SF_COLLDISABLE,49(a0)
        clr.b 38(a0)
        move.l X_EXP(a0),d0
        beq M4EnKeep
        movea.l d0,a2
        jmp (a2)
; playerbeamdie_Istrat 06:A22A: numplasers--, expstrat = remove (06:8D12).
M4WpPbeamDie:
        subq.b #1,M4_LP_NUMLASERS
        move.l #M4EnRemoveSelf,X_EXP(a0)
        moveq #0,d0
        rts

; Selected USA ROM gen_weapon06:B552, atan GSU01:81AA, relelaser06:9E5C.
; Scope: zero-angle/speed intro controller, weapon14, first eight pairs through106.
; WORD xyz/velocity, BYTE angles/animation/life. No captured pose tables.
M4_WEAPONS equ $ffd000 ;32 contexts32B: controller pairs plus zaco2intro shots
M4_WEAPON_SLOTS equ 32
M4_ZFLASHES equ $ffd400 ;8 zaco2intro muzzle flashes (06:B662), drawn
M4_ZFLASH_SLOTS equ 8
M4_ZACO2_TARGET equ $ffd500 ;player pose(0,0,worldZ) for gen_weapon aim
M4_WEAPON_COUNT equ $ff9290
M4_FLASH_IDS equ $ff9292
M4_FLASH_COUNT equ $ff9296
M4_WEAPON_FIRES equ $ff9298
M4_FLASHES equ $ffba40 ;two temporary contexts, removed by native behind policy

M4IntroWeaponsInit:
        lea M4_WEAPONS,a0
        move.w #(M4_WEAPON_SLOTS*32+M4_ZFLASH_SLOTS*32)/4-1,d0
M4WeaponsClear:
        clr.l (a0)+
        dbra d0,M4WeaponsClear
        lea M4_FLASHES,a0
        moveq #15,d0
M4WeaponsClearFlash:
        clr.l (a0)+
        dbra d0,M4WeaponsClearFlash
        clr.l M4_WEAPON_COUNT
        clr.l M4_FLASH_IDS+2
        clr.w M4_WEAPON_FIRES
        rts

; a0=dest,a1=target previous pose,a2=zero-angle controller,d0=offset +/-50.
M4IntroWeaponPrepare:
        move.w #127,d1
        bsr M4IntroShipMul
        move.w #127,d1
        bsr M4IntroShipMul
        lsl.w #2,d0
        add.w (a2),d0
        move.w d0,(a0)
        move.w 2(a2),2(a0)
        move.w 4(a2),d0
        addi.w #72,d0 ; native20 ->19 ->18 under two BYTE rotations, scale2
        move.w d0,4(a0)
        bsr M4IntroWeaponAim
        bsr M4IntroWeaponVectors
        rts

M4IntroWeaponAim:
        movem.l d1-d4/a1,-(sp)
        move.w (a1),d2
        sub.w (a0),d2
        bpl.s M4WeaponAimX
        neg.w d2
M4WeaponAimX:
        move.w 4(a1),d1
        sub.w 4(a0),d1
        bpl.s M4WeaponAimZ
        neg.w d1
M4WeaponAimZ:
        add.w d2,d1 ; original CF92 Manhattan distance, not Euclidean
        move.w 2(a1),d0
        sub.w 2(a0),d0
        bsr M4IntroWeaponAtan
        lsr.w #8,d0
        move.b d0,12(a0)
        move.w (a1),d0
        sub.w (a0),d0
        move.w 4(a1),d1
        sub.w 4(a0),d1
        bsr M4IntroWeaponAtan
        lsr.w #8,d0
        neg.b d0
        move.b d0,13(a0)
        clr.b 14(a0)
        movem.l (sp)+,d1-d4/a1
        rts

; d0=X signedWORD,d1=Y signedWORD => d0=angleWORD. |X/Y|<32768.
; Native GSU min/max division and original256-WORD arctan table.
M4IntroWeaponAtan:
        movem.l d1-d6/a2,-(sp)
        move.w d0,d4
        move.w d1,d5
        tst.w d0
        bpl.s M4WeaponAtanX
        neg.w d0
M4WeaponAtanX:
        tst.w d1
        bpl.s M4WeaponAtanY
        neg.w d1
M4WeaponAtanY:
        move.w d0,d2
        move.w d1,d3
        tst.w d1
        beq.s M4WeaponAtan90
        cmp.w d0,d1
        beq.s M4WeaponAtan45
        bhi.s M4WeaponAtanDivide
        exg d0,d1
M4WeaponAtanDivide:
        andi.l #$ffff,d0
        lsl.l #8,d0
        lsl.l #6,d0
        divu.w d1,d0
        lsr.w #5,d0
        andi.w #$fffe,d0
        lea M4IntroWeaponAtanTable,a2
        move.w (a2,d0.w),d0
        cmp.w d2,d3
        bhi.s M4WeaponAtanQuadrant
        neg.w d0
        addi.w #$4000,d0
        bra.s M4WeaponAtanQuadrant
M4WeaponAtan90:
        move.w #$4000,d0
        bra.s M4WeaponAtanQuadrant
M4WeaponAtan45:
        move.w #$2000,d0
M4WeaponAtanQuadrant:
        move.w d4,d6
        eor.w d5,d6
        bpl.s M4WeaponAtanSignY
        neg.w d0
M4WeaponAtanSignY:
        tst.w d5
        bpl.s M4WeaponAtanDone
        addi.w #$8000,d0
M4WeaponAtanDone:
        movem.l (sp)+,d1-d6/a2
        rts

M4IntroWeaponVectors:
        movem.l d1-d5/a1,-(sp)
        lea M4IntroShipSine,a1
        moveq #0,d0
        move.b 12(a0),d0
        move.b 64(a1,d0.w),d4
        ext.w d4
        move.b (a1,d0.w),d5
        ext.w d5
        moveq #0,d2
        move.b 13(a0),d2
        neg.b d2
        move.b (a1,d2.w),d1
        ext.w d1
        moveq #90,d0
        bsr M4IntroShipMul
        move.w d4,d1
        bsr M4IntroShipMul
        add.w d0,d0
        move.w d0,6(a0)
        move.b 64(a1,d2.w),d1
        ext.w d1
        moveq #90,d0
        bsr M4IntroShipMul
        move.w d4,d1
        bsr M4IntroShipMul
        add.w d0,d0
        move.w d0,10(a0)
        moveq #90,d0
        move.w d5,d1
        bsr M4IntroShipMul
        add.w d0,d0
        move.w d0,8(a0)
        movem.l (sp)+,d1-d5/a1
        rts

; relelaser init 06:9E83..9EAA: velocity += 1F:C41E(speed $24, same pitch/yaw).
; d0=shooter speed BYTE. Combined with the speed90 vector it matches the ROM
; oracle on 4096 pitch/yaw pairs (speed45).
M4IntroWeaponShooterVector:
        movem.l d1-d6/a1,-(sp)
        move.w d0,d6
        lea M4IntroShipSine,a1
        moveq #0,d0
        move.b 12(a0),d0
        move.b 64(a1,d0.w),d4
        ext.w d4
        move.b (a1,d0.w),d5
        ext.w d5
        moveq #0,d2
        move.b 13(a0),d2
        neg.b d2
        move.b (a1,d2.w),d1
        ext.w d1
        move.w d6,d0
        bsr M4IntroShipMul
        move.w d4,d1
        bsr M4IntroShipMul
        add.w d0,6(a0)
        move.b 64(a1,d2.w),d1
        ext.w d1
        move.w d6,d0
        bsr M4IntroShipMul
        move.w d4,d1
        bsr M4IntroShipMul
        add.w d0,10(a0)
        move.w d6,d0
        move.w d5,d1
        bsr M4IntroShipMul
        add.w d0,8(a0)
        movem.l (sp)+,d1-d6/a1
        rts

M4IntroWeaponsFire:
        movem.l d1-d7/a0-a6,-(sp)
        cmpi.w #M4_WEAPON_SLOTS-2,M4_WEAPON_COUNT
        bhi M4WeaponsBad
        moveq #0,d7
        moveq #-50,d5
M4WeaponsFireSide:
        move.w M4_WEAPON_COUNT,d6
        move.w d6,d0
        lsl.w #5,d0
        lea M4_WEAPONS,a0
        adda.w d0,a0
        movea.l M4_MAPVAR1_CONTEXT,a1
        lea M4_FIRE_OBJECT,a2
        move.w d5,d0
        bsr M4IntroWeaponPrepare
        move.b #90,15(a0)
        move.b #60,19(a0)
        move.b #3,21(a0)
        move.w #1,22(a0)
        bsr M4IntroNativeAllocate
        move.w d0,24(a0)
        move.w d0,-(sp)
        moveq #$45,d0
        jsr M4SoundIntroAt
        move.w (sp)+,d0
        move.w M4_SCENE_TICK,26(a0)
        move.w M4_NATIVE_FIRE,28(a0)
        move.w #2,30(a0)
        bsr M4IntroNativeAllocate ; flash follows laser, BEFORE lateral350
        move.w d7,d1
        add.w d1,d1
        lea M4_FLASH_IDS,a3
        move.w d0,(a3,d1.w)
        move.w d7,d1
        lsl.w #5,d1
        lea M4_FLASHES,a3
        adda.w d1,a3
        move.l (a0),(a3)
        move.w 4(a0),d1
        add.w INTRO_CAMERA+6,d1 ; native flash initializer addplayerZ
        move.w d1,4(a3)
        move.w d0,24(a3)
        move.w #1,22(a3)
        move.w #$0080,12(a3)
        move.w #2,M4_FLASH_COUNT
        move.w #-350,d0
        tst.w d7
        beq.s M4WeaponsLateral
        move.w #350,d0
M4WeaponsLateral:
        add.w d0,(a0)
        addq.w #1,M4_WEAPON_COUNT
        moveq #50,d5
        addq.w #1,d7
        cmpi.w #2,d7
        bne M4WeaponsFireSide
        addq.w #1,M4_WEAPON_FIRES
        moveq #0,d0
        bra M4WeaponsReturn
M4WeaponsBad:
        moveq #-10,d0 ;error code
M4WeaponsReturn:
        movem.l (sp)+,d1-d7/a0-a6
        rts

; 1F:CC78/CAFB/C97B BYTE product: |v|*2 (8-bit ASL) times |t|, high BYTE,
; sign applied afterwards (toward zero). d0.b=v,d1.b=t -> d0.b. d2 clobbered.
M4WeaponByteMul:
        move.b d0,d2
        eor.b d1,d2
        tst.b d0
        bpl.s M4ByteMulV
        neg.b d0
M4ByteMulV:
        add.b d0,d0
        andi.w #255,d0
        tst.b d1
        bpl.s M4ByteMulT
        neg.b d1
M4ByteMulT:
        andi.w #255,d1
        mulu.w d1,d0
        lsr.w #8,d0
        tst.b d2
        bpl.s M4ByteMulDone
        neg.b d0
M4ByteMulDone:
        rts

; d3.b=u,d4.b=v,d5.b=angle -> d3=u*cos+v*sin, d4=-u*sin+v*cos (BYTE sums).
M4WeaponRotatePair:
        movem.l d0-d2/d6-d7/a1,-(sp)
        lea M4IntroShipSine,a1
        andi.w #255,d5
        move.b (a1,d5.w),d6 ;sin
        move.b 64(a1,d5.w),d7 ;cos
        move.b d3,d0
        move.b d7,d1
        bsr.s M4WeaponByteMul
        move.b d0,-(sp)
        move.b d4,d0
        move.b d6,d1
        bsr.s M4WeaponByteMul
        add.b (sp)+,d0
        move.b d0,-(sp) ;new u
        move.b d3,d0
        move.b d6,d1
        bsr.s M4WeaponByteMul
        neg.b d0
        move.b d0,-(sp)
        move.b d4,d0
        move.b d7,d1
        bsr.s M4WeaponByteMul
        add.b (sp)+,d0
        move.b d0,d4
        move.b (sp)+,d3
        movem.l (sp)+,d0-d2/d6-d7/a1
        rts

; gen_weapon06:B552 offset part for any mother angles: roll(rotZ),
; pitch(rotX), yaw(-rotY), then ASL2. d3/d4/d5 offset BYTEs x/y/z,
; a2 mother -> d3/d4/d5 WORD displacement.
M4WeaponOffset:
        move.l d6,-(sp)
        move.b d5,d6 ;z
        move.b 14(a2),d5
        bsr.s M4WeaponRotatePair ;(x,y) by roll
        exg d4,d6 ;d4=z,d6=y
        exg d3,d6 ;d3=y,d6=x
        move.b 12(a2),d5
        bsr.s M4WeaponRotatePair ;(y,z) by pitch
        exg d3,d6 ;d3=x,d6=y
        move.b 13(a2),d5
        neg.b d5
        bsr.s M4WeaponRotatePair ;(x,z) by yaw
        move.b d4,d5 ;z
        move.b d6,d4 ;y
        ext.w d3
        ext.w d4
        ext.w d5
        asl.w #2,d3
        asl.w #2,d4
        asl.w #2,d5
        move.l (sp)+,d6
        rts

; fire_relfastElaser06:AF61 from zaco2intro: offset(0,0,0)+Z20, aim at the
; player (0,0,d2) with gen_weapon random offsets d4 pitch/d5 yaw, relelaser
; speed90 and life40. a0=mother. Native flash B662 is created at the laser.
M4IntroZaco2Fire:
        movem.l d0-d7/a0-a3,-(sp)
        movea.l a0,a2
        move.w M4_WEAPON_COUNT,d0
        cmpi.w #M4_WEAPON_SLOTS,d0
        bhs M4Zaco2FireBad
        lsl.w #5,d0
        lea M4_WEAPONS,a0
        adda.w d0,a0
        move.b d4,-(sp)
        move.b d5,-(sp)
        lea M4_ZACO2_TARGET,a1
        clr.l (a1)
        move.w d2,4(a1)
        moveq #0,d3
        moveq #0,d4
        moveq #20,d5
        bsr M4WeaponOffset
        add.w (a2),d3
        add.w 2(a2),d4
        add.w 4(a2),d5
        move.w d3,(a0)
        move.w d4,2(a0)
        move.w d5,4(a0)
        bsr M4IntroWeaponAim
        move.b (sp)+,d5
        move.b (sp)+,d4
        add.b d4,12(a0)
        add.b d5,13(a0)
        bsr M4IntroWeaponVectors
        moveq #0,d0
        move.b 15(a2),d0 ; 06:B658 laser $24 = shooter $15
        bsr M4IntroWeaponShooterVector
        move.b #90,15(a0)
        clr.b 18(a0)
        move.b #40,19(a0)
        move.b #3,21(a0)
        move.w #1,22(a0)
        bsr M4IntroNativeAllocate
        move.w d0,24(a0)
        move.w M4_SCENE_TICK,26(a0)
        move.w 24(a2),28(a0)
        move.w #2,30(a0)
        moveq #$45,d0
        jsr M4SoundIntroAt
        addq.w #1,M4_WEAPON_COUNT
        movea.l a0,a1
        bsr M4IntroFlashCreate
        moveq #0,d0
        bra.s M4Zaco2FireReturn
M4Zaco2FireBad:
        move.w #$E401,M4_MESH_ERROR ;error site 1
M4Zaco2FireReturn:
        movem.l (sp)+,d0-d7/a0-a3
        rts

; 06:B662: flash model by |playerZ-laserZ| (<500 B0AD,<1000 B091,else B075),
; position copied from the laser, yaw128, init adds pviewVelZ. a1=laser.
M4IntroFlashCreate:
        movem.l d0-d2/a0,-(sp)
        lea M4_ZFLASHES,a0
        moveq #M4_ZFLASH_SLOTS-1,d1
M4FlashFind:
        tst.w 22(a0)
        beq.s M4FlashFree
        lea 32(a0),a0
        dbra d1,M4FlashFind
        move.w #$E402,M4_MESH_ERROR ;error site 2
        bra.s M4FlashReturn
M4FlashFree:
        move.w M4_ZACO2_TARGET+4,d0
        sub.w 4(a1),d0
        bpl.s M4FlashAbs
        neg.w d0
M4FlashAbs:
        moveq #2,d2 ;B0AD
        cmpi.w #500,d0
        blt.s M4FlashModel
        moveq #1,d2 ;B091
        cmpi.w #1000,d0
        blt.s M4FlashModel
        moveq #0,d2 ;B075
M4FlashModel:
        move.b d2,20(a0)
        move.l (a1),(a0)
        move.w 4(a1),d0
        add.w INTRO_CAMERA+6,d0
        move.w d0,4(a0)
        clr.l 6(a0)
        clr.w 10(a0)
        clr.b 12(a0)
        move.b #128,13(a0)
        clr.b 14(a0)
        move.b #128,18(a0)
        addi.b #16,d2
        move.b d2,21(a0) ;draw kinds16..18 -> SVP models14..16 Flash0..2
        move.w #1,22(a0)
        move.w M4_SCENE_TICK,26(a0)
        bsr M4IntroNativeAllocate
        move.w d0,24(a0)
M4FlashReturn:
        movem.l (sp)+,d0-d2/a0
        rts

; showview (MAIN.ASM .dontkill, alienflags): al_type&atzremove(8) objects are
; removed when sh_zmax+(worldZ-viewZ)<0, except in their first frame
; (acf_firstframe). Flashes B075/B091/B0AD have type8 and zmax64/32/16.
M4IntroFlashesZRemove:
        movem.l d0-d7/a0,-(sp)
        lea M4_ZFLASHES,a0
        moveq #M4_ZFLASH_SLOTS-1,d7
M4FlashZNext:
        tst.w 22(a0)
        beq.s M4FlashZSkip
        move.w M4_SCENE_TICK,d0
        cmp.w 26(a0),d0
        beq.s M4FlashZSkip
        moveq #64,d1
        move.b 20(a0),d0
        lsr.w d0,d1
        move.w 4(a0),d0
        sub.w INTRO_CAMERA+8,d0
        add.w d1,d0
        bpl.s M4FlashZSkip
        move.w 24(a0),d0
        bsr M4IntroNativeRemove
        clr.w 22(a0)
M4FlashZSkip:
        lea 32(a0),a0
        dbra d7,M4FlashZNext
        movem.l (sp)+,d0-d7/a0
        rts

; 06:B715 each later tick: add pviewVelZ; anim2 removes, else anim cycles4.
M4IntroFlashesTick:
        movem.l d0-d7/a0,-(sp)
        lea M4_ZFLASHES,a0
        moveq #M4_ZFLASH_SLOTS-1,d7
M4FlashTickNext:
        tst.w 22(a0)
        beq.s M4FlashTickSkip
        move.w M4_SCENE_TICK,d0
        cmp.w 26(a0),d0
        beq.s M4FlashTickSkip
        move.w INTRO_CAMERA+6,d0
        add.w d0,4(a0)
        move.b 18(a0),d0
        andi.b #127,d0
        cmpi.b #2,d0
        bne.s M4FlashAnimate
        move.w 24(a0),d0
        bsr M4IntroNativeRemove
        clr.w 22(a0)
        bra.s M4FlashTickSkip
M4FlashAnimate:
        move.b 18(a0),d0
        addq.b #1,d0
        bmi.s M4FlashAnimMasked
        addq.b #4,d0
M4FlashAnimMasked:
        andi.b #127,d0
        cmpi.b #4,d0
        blo.s M4FlashAnimReady
        subq.b #4,d0
M4FlashAnimReady:
        ori.b #128,d0
        move.b d0,18(a0)
M4FlashTickSkip:
        lea 32(a0),a0
        dbra d7,M4FlashTickNext
        movem.l (sp)+,d0-d7/a0
        rts

M4IntroWeaponsTick:
        movem.l d1-d7/a0-a6,-(sp)
        move.w M4_WEAPON_COUNT,d7
        beq.s M4WeaponsTickDone
        subq.w #1,d7
M4WeaponsTickNext:
        move.w d7,d0
        lsl.w #5,d0
        lea M4_WEAPONS,a0
        adda.w d0,a0
        tst.w 22(a0)
        beq.s M4WeaponsTickSkip
        move.w M4_SCENE_TICK,d0
        cmp.w 26(a0),d0
        beq.s M4WeaponsTickSkip ; initializer returns without moving/life DEC
        cmpi.b #4,18(a0)
        beq.s M4WeaponsTickPosition
        addq.b #2,18(a0)
        andi.b #7,18(a0)
M4WeaponsTickPosition:
        move.w 6(a0),d0
        add.w d0,(a0)
        move.w 8(a0),d0
        add.w d0,2(a0)
        move.w 10(a0),d0
        add.w INTRO_CAMERA+6,d0
        add.w d0,4(a0)
        subq.b #1,19(a0)
        bne.s M4WeaponsTickSkip
        move.w 24(a0),d0
        bsr M4IntroNativeRemove
        clr.w 22(a0)
M4WeaponsTickSkip:
        dbra d7,M4WeaponsTickNext
M4WeaponsTickDone:
        moveq #0,d0
        movem.l (sp)+,d1-d7/a0-a6
        rts

; Original alienflags: headerzmax32 + (worldZ-viewZ) negative, flag9&8.
; New flash has no acf_firstframe exemption. Traversal second then first.
; This bounded consumer fails if a flash could be visible: no fake sprite.
M4IntroWeaponsDiscardFlashes:
        movem.l d1-d7/a0-a6,-(sp)
        tst.w M4_FLASH_COUNT
        beq.s M4WeaponsFlashDone
        moveq #1,d7
M4WeaponsFlashNext:
        move.w d7,d0
        lsl.w #5,d0
        lea M4_FLASHES,a0
        adda.w d0,a0
        move.w 4(a0),d0
        sub.w INTRO_CAMERA+8,d0
        addi.w #32,d0
        bpl.s M4WeaponsFlashBad
        move.w 24(a0),d0
        bsr M4IntroNativeRemove
        clr.w 22(a0)
        dbra d7,M4WeaponsFlashNext
        clr.w M4_FLASH_COUNT
M4WeaponsFlashDone:
        moveq #0,d0
        bra.s M4WeaponsFlashReturn
M4WeaponsFlashBad:
        moveq #-11,d0 ;error code
M4WeaponsFlashReturn:
        movem.l (sp)+,d1-d7/a0-a6
        rts

M4IntroWeaponTest:
        movem.l d0-d7/a0-a6,-(sp)
        move.l #'M4WP',$ff4530
        clr.l $ff4534
        lea M4IntroWeaponAtanCases,a4
        move.w #M4_WEAPON_ATAN_CASES-1,d7
M4WeaponTestAtan:
        move.w (a4),d0
        move.w 2(a4),d1
        bsr M4IntroWeaponAtan
        cmp.w 4(a4),d0
        bne.s M4WeaponTestBad
        addq.w #1,$ff4536
        lea 6(a4),a4
        dbra d7,M4WeaponTestAtan
        lea M4IntroWeaponShotCases,a4
        move.w #M4_WEAPON_SHOT_CASES-1,d7
M4WeaponTestShot:
        lea $ff9580,a0
        lea 6(a4),a1
        movea.l a4,a2
        move.w 12(a4),d0
        bsr M4IntroWeaponPrepare
        moveq #0,d2
M4WeaponTestCoord:
        move.w (a0,d2.w),d0
        cmp.w 14(a4,d2.w),d0
        bne.s M4WeaponTestBad
        addq.w #2,d2
        cmpi.w #6,d2
        bne.s M4WeaponTestCoord
        moveq #0,d0
        move.b 12(a0),d0
        cmp.w 20(a4),d0
        bne.s M4WeaponTestBad
        move.b 13(a0),d0
        cmp.w 22(a4),d0
        bne.s M4WeaponTestBad
        addq.w #1,$ff4536
        lea 24(a4),a4
        dbra d7,M4WeaponTestShot
        move.w #1,$ff4534
        bra.s M4WeaponTestDone
M4WeaponTestBad:
        move.w #-1,$ff4534
M4WeaponTestDone:
        movem.l (sp)+,d0-d7/a0-a6
        rts

M4IntroWeaponAtanTable:
        incbin '../build/intro-weapon-atan.bin'
        even

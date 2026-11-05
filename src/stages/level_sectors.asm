; Stage unit: Sector X (0D:DF4C), Sector Y (0D:E02A) and Sector Z (0D:E6D8).
; Strategies (table searched by M4LevelFindStrategy, level_objects.asm),
; helpers and effects of these stages. Stage data: tools/stages/sectors.py.
; RAM: $FF98C0..$FF98FF (reserved for this unit).
; Authority: ref/Star Fox (USA).sfc (rev0); every routine re-read in the ROM
; bytes (build/agent-sectors/dis/, flow disassembly dis-sectors.py), names
; from UltraStarFox only. Documentation and oracle: build/agent-sectors/
; (SECTORS.md, sectors-oracle.py). Conventions (level_objects.asm): a0
; object, a1 player; d0 = 0 keep / nonzero deferred removal (1F:D501).
; "d < K" of the original is the N bit of the 16-bit subtraction. Sounds
; (trigse 03:B7E5, sound2 $1CE9) are not ported.
M4_SECTORS equ $ff98c0
M4_SX_1534 equ M4_SECTORS+0 ;.b $1534 smvar_byte1 (last spacemist colframe)

M4StrategiesSectors:
        dc.l $0acf37,M4SxBar ;spacebar (Sector X/Z)
        dc.l $0acf7b,M4SxSpinBar ;SPINspacebar (also colony0's children)
        dc.l $0acfd3,M4SxBar1 ;spacebar1 (also Venom 3)
        dc.l $0ad189,M4SxBar3 ;spacebar3 (also Venom 3)
        dc.l $0ad4d0,M4SxWalker ;spacebarwalker (also Venom 3)
        dc.l $0af6d5,M4SxPole ;pole0 (Sector Z, Out of This Dimension)
        dc.l $0ad251,M4SxColony0 ;colony0 (Sector Z)
        dc.l $0ad417,M4SxColony1 ;colony1
        dc.l $0ad44b,M4SxColony2 ;colony2
        dc.l $0ae9e8,M4SxFish ;sfish (Sector Y)
        dc.l $06c196,M4SxEarthA ;clshipEARTHa (Sector X ending)
        dc.l $06c1fa,M4SxEarthB ;clshipEARTHb
        dc.l $06c25e,M4SxEarthC ;clshipEARTHc
        dc.l $06c4ce,M4SxTurnA ;clshipTURNa (Sector Y ending)
        dc.l $06c52d,M4SxTurnB ;clshipTURNb
        dc.l $06c58c,M4SxTurnC ;clshipTURNc
        dc.l $09aa4f,M4SxFling ;flingboss (Sector Y boss)
        dc.l $09b31d,M4CkChicken ;chicken (Fortuna boss, level_fortuna_boss.asm)
        dc.l 0

; ---------------------------------------------------------------------
; Helpers.

; spacemist (inline in 0A:CF56..CF7A and its copies): b = hi8(asr1(z -
; viewposz $14FC + 500)); N(b - 8) clear (8 bits) -> 7; $1534 = b; colframe
; ($1CE6) = b | $80.
M4SxMist:
        move.w 4(a0),d0
        sub.w M4_LP_PVIEWZ,d0
        addi.w #500,d0
        asr.w #1,d0
        lsr.w #8,d0
        move.b d0,d1
        subq.b #8,d1
        bmi.s M4SxMistKeep
        moveq #7,d0
M4SxMistKeep:
        move.b d0,M4_SX_1534
        ori.b #$80,d0
        move.b d0,18(a0)
        rts

; Common Istrat of the spacebars: set_zerocollptrs 1F:D450, hardvars (HP
; $FF, AP 8), colltype enemy1 ($2E |= $10).
M4SxBarInit:
        jsr M4LvZeroPtrs
        move.b #$ff,38(a0)
        move.b #8,39(a0)
        ori.b #CF_ENEMY1,44(a0)
        rts

; rotate_16xz 1F:CDF0: d0.b angle, d1 = x1 ($02), d2 = z1 ($90) -> d1 = x2
; ($04) = x*c - z*s, d2 = z2 ($15C4) = x*s + z*c; s/c bytes of 00:98A5/98E5,
; each product 02:FC62 (M4PvFc62, level_paths.asm). Keeps d0/d3-d7/a0-a2.
M4SxRot16xz:
        movem.l d0/d3-d6/a3,-(sp)
        lea M4IntroShipSine,a3
        andi.w #$ff,d0
        move.b (a3,d0.w),d5
        ext.w d5 ;s
        move.b 64(a3,d0.w),d6
        ext.w d6 ;c
        move.w d1,d3 ;x
        move.w d2,d0 ;z
        move.w d5,d4
        jsr M4PvFc62
        move.w d0,-(sp) ;z*s
        move.w d3,d0
        move.w d6,d4
        jsr M4PvFc62
        sub.w (sp)+,d0 ;x*c - z*s
        move.w d0,-(sp)
        move.w d3,d0
        move.w d5,d4
        jsr M4PvFc62
        move.w d0,d3 ;x*s
        move.w d2,d0
        move.w d6,d4
        jsr M4PvFc62
        add.w d3,d0 ;x*s + z*c
        move.w d0,d2
        move.w (sp)+,d1
        movem.l (sp)+,d0/d3-d6/a3
        rts

; ---------------------------------------------------------------------
; spacebar_Istrat 0A:CF37 (bars Xsolid/Ysolid/.. and wire variants):
; common Istrat; strategy 0A:CF56 = spacemist only.
M4SxBar:
        move.l #M4SxBarTick,32(a0)
        bsr M4SxBarInit
M4SxBarTick:
        bsr M4SxMist
        moveq #0,d0
        rts

; SPINspacebar_Istrat 0A:CF7B: common Istrat; 0A:CF9A: spacemist, rotz +=
; sbyte1, roty = Achase8_3(roty, 0) (1F:D8BD).
M4SxSpinBar:
        move.l #M4SxSpinBarTick,32(a0)
        bsr M4SxBarInit
M4SxSpinBarTick:
        bsr M4SxMist
        move.b 36(a0),d0
        add.b d0,14(a0)
        move.b 13(a0),d0
        moveq #0,d1
        moveq #3,d2
        jsr M4EnChase8
        move.b d0,13(a0)
        moveq #0,d0
        rts

; spacebar1_Istrat 0A:CFD3: common Istrat; sbyte2 != 0 -> colldisable.
; 0A:D000: rotz += sbyte1, spacemist.
M4SxBar1:
        move.l #M4SxBar1Tick,32(a0)
        bsr M4SxBarInit
        tst.b 37(a0)
        beq.s M4SxBar1Tick
        bset #SF_COLLDISABLE,49(a0)
M4SxBar1Tick:
        move.b 36(a0),d0
        add.b d0,14(a0)
        bsr M4SxMist
        moveq #0,d0
        rts

; spacebar3_Istrat 0A:D189: zero pointers, HP $FF, AP 8; offsets to the
; parent (al_ptr, set by the map's setalvarptr): sword1 = x - p.x, sword2
; ($28, port 42) = y - p.y, immuneptr ($19, port 28) = z - p.z; enemy1.
; The ROM reads the parent without checking it (ldy $06,x): a null al_ptr
; would read WRAM 7E:000C..; the port leaves the offsets 0 then [H, not
; reached by the scripts: setalvarptr follows every creation].
; 0A:D1E6: parent alive -> (x2, z2) = rotate_16xz(-p.rotz, sword1, sword2),
; x = x2 + p.x, y = z2 + p.y, z = p.z + immuneptr, rotz += p.sbyte1; then
; spacemist (also without parent).
M4SxBar3:
        move.l #M4SxBar3Tick,32(a0)
        jsr M4LvZeroPtrs
        move.b #$ff,38(a0)
        move.b #8,39(a0)
        move.w X_ALPTR(a0),d0
        beq.s M4SxBar3NoParent
        movea.w d0,a2
        move.w (a0),d0
        sub.w (a2),d0
        move.w d0,40(a0)
        move.w 2(a0),d0
        sub.w 2(a2),d0
        move.w d0,42(a0)
        move.w 4(a0),d0
        sub.w 4(a2),d0
        move.w d0,28(a0)
M4SxBar3NoParent:
        ori.b #CF_ENEMY1,44(a0)
M4SxBar3Tick:
        move.w X_ALPTR(a0),d0
        beq.s M4SxBar3Mist
        movea.w d0,a2
        move.b 14(a2),d0
        neg.b d0
        move.w 40(a0),d1
        move.w 42(a0),d2
        bsr M4SxRot16xz
        add.w (a2),d1
        move.w d1,(a0)
        add.w 2(a2),d2
        move.w d2,2(a0)
        move.w 4(a2),d0
        add.w 28(a0),d0
        move.w d0,4(a0)
        move.b 36(a2),d0
        add.b d0,14(a0)
M4SxBar3Mist:
        bsr M4SxMist
        moveq #0,d0
        rts

; spacebarwalker_Istrat 0A:D4D0: normal pointers (hitflash / explode), HP 4,
; AP 4, enemy1. 0A:D4EF: roty = Achase8_1(roty, -hi(Yanglexy(player)))
; (inline 0A:D4F6..D51F, min step 2); N(player.z - z) and (gameframe +
; al1pt) & 15 == 0 -> RelSlowElaser ($0C) at the player, offset (0, -20,
; 0), no rotation adds.
M4SxWalker:
        move.l #M4SxWalkerTick,32(a0)
        jsr M4LvNormPtrs
        move.b #4,38(a0)
        move.b #4,39(a0)
        ori.b #CF_ENEMY1,44(a0)
M4SxWalkerTick:
        movea.l a1,a2
        jsr M4EnYawTo
        move.b d0,d1
        move.b 13(a0),d0
        moveq #1,d2
        jsr M4EnChase8
        move.b d0,13(a0)
        move.w 4(a1),d0
        sub.w 4(a0),d0
        bpl.s M4SxWalkerDone
        jsr M4ArPhase
        andi.b #15,d0
        bne.s M4SxWalkerDone
        moveq #0,d3
        moveq #-20,d4
        moveq #0,d5
        moveq #0,d6
        moveq #0,d7
        movea.l a1,a3
        moveq #M4_WT_RSE,d0
        jsr M4EnFire
M4SxWalkerDone:
        moveq #0,d0
        rts

; pole0_Istrat 0A:F6D5: strategy F718, collstrat 0A:F737, no expstrat, HP
; $FF, AP 8 (no colltype), sbyte1 3, random_l >= $7F -> -3. 0A:F718: z +=
; 30, rotz += sbyte1, sbyte2 != 0 -> sbyte2 - 1.
M4SxPole:
        move.l #M4SxPoleTick,32(a0)
        move.l #M4SxPoleColl,X_COLL(a0)
        clr.l X_EXP(a0)
        move.b #$ff,38(a0)
        move.b #8,39(a0)
        move.b #3,36(a0)
        jsr M4IntroRandom
        cmpi.b #$7f,d0
        blo.s M4SxPoleTick
        move.b #$fd,36(a0)
M4SxPoleTick:
        addi.w #30,4(a0)
        move.b 36(a0),d0
        add.b d0,14(a0)
        tst.b 37(a0)
        beq.s M4SxPoleDone
        subq.b #1,37(a0)
M4SxPoleDone:
        moveq #0,d0
        rts
; pole0col 0A:F737: hitflags ($35, port 20) HF1 or sbyte2 != 0 -> nothing;
; else sbyte2 = 6 (sound $57) and HF2: sbyte1 < 0 -> 0, else + 2; or HF3:
; sbyte1 <= 0 -> - 2, else 0. Then hitflags 0, collide off, the strategy.
M4SxPoleColl:
        btst #0,20(a0)
        bne.s M4SxPoleCollEnd
        tst.b 37(a0)
        bne.s M4SxPoleCollEnd
        move.b #6,37(a0)
        btst #1,20(a0)
        beq.s M4SxPoleHf3
        tst.b 36(a0)
        bpl.s M4SxPoleUp
        clr.b 36(a0)
        bra.s M4SxPoleCollEnd
M4SxPoleUp:
        addq.b #2,36(a0)
        bra.s M4SxPoleCollEnd
M4SxPoleHf3:
        btst #2,20(a0)
        beq.s M4SxPoleCollEnd
        tst.b 36(a0)
        beq.s M4SxPoleDown
        bmi.s M4SxPoleDown
        clr.b 36(a0)
        bra.s M4SxPoleCollEnd
M4SxPoleDown:
        subq.b #2,36(a0)
M4SxPoleCollEnd:
        clr.b 20(a0)
        bclr #SF_COLLIDE,49(a0)
        jmp M4LcStrategy

; ---------------------------------------------------------------------
; colony0_Istrat 0A:D251 (colony_0 E1AC, Sector Z): HP 10, AP 10,
; gameflags &= ~stratdone1 ($08), enemy1, al_type |= gnd. 0A:D280:
;  sflag1 -> common tail;
;  |pz - z| < 800: colldisable; player not dead ($14D9 bit7): inseq
;   ($14DF |= 8), cockpit ($14DD 3) -> 4 and changeviewmode 06:BA91,
;   pshipflags |= $60 (noctrl, nofire), player x = Achase16_4(x, 0), y =
;   Achase16_4(y, viewCY); colony behind the player (N(z - pz)) ->
;   gameflags |= stratdone1, sflag1;
;  else |pz - z| >= 1500 and gameframe & 15 == 0: make_obj XPwirespacebar
;   (DFB4) at the colony, rotz = rnd, sbyte1 = (rnd & 15) - 7, Istrat
;   SPINspacebar 0A:CF7B, x/y += (rnd & 255) - 127, z += (rnd & 0) - 0 (a
;   random_l call), roty $40.
; Tail 0A:D406: z -= 20, z += pviewvelz.
M4SxColony0:
        move.l #M4SxColony0Tick,32(a0)
        move.b #10,38(a0)
        move.b #10,39(a0)
        bclr #3,M4_LP_GAMEFLAGS
        ori.b #CF_ENEMY1,44(a0)
        bset #0,45(a0)
M4SxColony0Tick:
        btst #F2_SFLAG1,48(a0)
        bne M4SxColonyTail
        movea.l a1,a2
        jsr M4EnZD
        cmpi.w #800,d0
        bpl M4SxColony0Far
        bset #SF_COLLDISABLE,49(a0)
        tst.b M4_LP_PSF2
        bmi M4SxColonyTail
        bset #3,M4_BOSS_PSTRATF ;inseq
        cmpi.b #SFM_INSIDE,M4_SPP_FM
        bne.s M4SxColony0View
        move.b #SFM_TONORM,M4_SPP_FM
        movem.l a0-a1,-(sp)
        jsr M4SpChangeView
        movem.l (sp)+,a0-a1
M4SxColony0View:
        ori.b #$60,M4_LP_PSF
        move.w (a1),d0
        moveq #0,d1
        moveq #4,d2
        jsr M4LpAchase
        move.w d0,(a1)
        move.w 2(a1),d0
        move.w M4_LP_VIEWCY,d1
        jsr M4LpAchase
        move.w d0,2(a1)
        move.w 4(a0),d0
        sub.w 4(a1),d0
        bpl M4SxColonyTail
        bset #3,M4_LP_GAMEFLAGS ;stratdone1
        bset #F2_SFLAG1,48(a0)
        bra M4SxColonyTail
M4SxColony0Far:
        cmpi.w #1500,d0
        bmi M4SxColonyTail
        moveq #15,d0
        and.w M4_LV_GAMEFRAME,d0
        bne M4SxColonyTail
        move.w #$dfb4,d0
        jsr M4ArCreateHdr
        beq M4SxColonyTail
        move.l (a0),(a2)
        move.w 4(a0),4(a2)
        jsr M4IntroRandom
        move.b d0,14(a2)
        jsr M4IntroRandom
        andi.b #15,d0
        subq.b #7,d0
        move.b d0,36(a2)
        move.l #M4SxSpinBar,32(a2)
        jsr M4IntroRandom
        andi.w #$ff,d0
        subi.w #$7f,d0
        add.w d0,(a2)
        jsr M4IntroRandom
        andi.w #$ff,d0
        subi.w #$7f,d0
        add.w d0,2(a2)
        jsr M4IntroRandom ;and #$00: z += 0
        move.b #$40,13(a2)
M4SxColonyTail:
        subi.w #20,4(a0)
        jsr M4EnAddPZ
        moveq #0,d0
        rts

; colony1_Istrat 0A:D417 (colony_1 E1C8): colldisable, al_type |= gnd.
; 0A:D430: y = -(viewposy $C3 - viewCY) + viewCY + 50; tail 0A:D406.
M4SxColony1:
        move.l #M4SxColony1Tick,32(a0)
        bset #SF_COLLDISABLE,49(a0)
        bset #0,45(a0)
M4SxColony1Tick:
        move.w M4_LP_VIEWCY,d0
        sub.w M4_LVW_POS+2,d0
        add.w M4_LP_VIEWCY,d0
        addi.w #50,d0
        move.w d0,2(a0)
        bra M4SxColonyTail

; colony2_Istrat 0A:D44B (colony_2 E2A8, 10 frames): colldisable, animframe
; $80, al_type |= gnd. 0A:D46B: pos = al_ptr's (1F:DAED; the ROM reads a
; null al_ptr from WRAM 7E:000C..: the port keeps its position then [H]),
; z += 280; player in front (!N(pz - z)) or |pz - z| < 40 -> animframe
; (& $7F) up to 9 (add_anim +1 mod 10). No playerZ.
M4SxColony2:
        bset #SF_COLLDISABLE,49(a0)
        move.l #M4SxColony2Tick,32(a0)
        move.b #$80,16(a0)
        bset #0,45(a0)
M4SxColony2Tick:
        move.w X_ALPTR(a0),d0
        beq.s M4SxColony2Pos
        movea.w d0,a2
        move.l (a2),(a0)
        move.w 4(a2),4(a0)
M4SxColony2Pos:
        addi.w #280,4(a0)
        move.w 4(a1),d0
        sub.w 4(a0),d0
        bpl.s M4SxColony2Open
        movea.l a1,a2
        jsr M4EnZD
        cmpi.w #40,d0
        bpl.s M4SxColony2Done
M4SxColony2Open:
        moveq #$7f,d0
        and.b 16(a0),d0
        cmpi.b #9,d0
        beq.s M4SxColony2Done
        move.b 16(a0),d0
        moveq #1,d1
        moveq #10,d2
        jsr M4WpAddAnim
        move.b d0,16(a0)
M4SxColony2Done:
        moveq #0,d0
        rts

; ---------------------------------------------------------------------
; Shape header of a3 -> d0 (descriptor header; uncatalogued: X_SHAPEHDR;
; none: nullshape ACA1).
M4SxHeader:
        move.w 46(a3),d0
        cmpi.w #$ffff,d0
        beq.s M4SxHeaderHdr
        lsl.w #5,d0
        move.l a4,-(sp)
        lea M4LevelShapeDescriptors,a4
        move.w 16(a4,d0.w),d0
        movea.l (sp)+,a4
        rts
M4SxHeaderHdr:
        move.w X_SHAPEHDR(a3),d0
        bne.s M4SxHeaderDone
        move.w #$aca1,d0
M4SxHeaderDone:
        rts

; find_obj 1F:C7D5 with $14CC = $121F (allst head): the first object other
; than a0 whose shape header is d1 -> a3 (Z set when none).
M4SxFindObj:
        move.w M4_LV_HEAD,d2
M4SxFindNext:
        tst.w d2
        beq.s M4SxFindNone
        movea.w d2,a3
        move.w X_NEXT(a3),d2
        cmpa.w a0,a3
        beq.s M4SxFindNext
        bsr M4SxHeader
        cmp.w d1,d0
        bne.s M4SxFindNext
        move.l a3,d0 ;Z clear
        rts
M4SxFindNone:
        suba.l a3,a3
        move.l a3,d0 ;Z set
        rts

; find_radiusobj 1F:C8EA with $14CC = $121F, $3E = 0: the first object
; other than a0 whose shape header is d1 and with N(distXZ - d3) and
; !N(distXZ) (1F:D0AB, $1252) -> a3 (Z set when none).
M4SxFindRadius:
        move.w M4_LV_HEAD,d2
M4SxFindRNext:
        tst.w d2
        beq.s M4SxFindNone
        movea.w d2,a3
        move.w X_NEXT(a3),d2
        cmpa.w a0,a3
        beq.s M4SxFindRNext
        bsr M4SxHeader
        cmp.w d1,d0
        bne.s M4SxFindRNext
        movea.l a3,a2
        jsr M4EnDistXZ
        cmp.w d3,d0
        bpl.s M4SxFindRNext
        tst.w d0
        bmi.s M4SxFindRNext
        move.l a3,d0
        rts

; ---------------------------------------------------------------------
; sfish_Istrat 0A:E9E8 (s_fish E4F4, Sector Y schools: the first of each
; school alone, the others with al_ptr = the first by setalvarptr):
; colldisable, HP 100, AP 8, rotz = rnd. With a leader: v = (rnd - 128) on
; each axis (BYTE store, high byte 0). Alone: no zremove, count 200, sbyte1
; 200, v = (20, 10, -10). 0A:EA76: rotz += 8, then
;  follower (leader alive): leader sword1 (nuke) -> 4-chase to the nuke and
;   face away from the last position; leader sword2 (laser near) -> sbyte1 =
;   (rnd & 7) + 5 and offset 4v; sbyte1 != 0 -> sbyte1 - 1 and offset 4v;
;   else offset v: x/y/z = Achase16_3(pos, leader + offset), rotx/roty =
;   Achase8_4(own, leader's);
;  alone: sword1 = find_obj(nuke AF41), sword2 = find_radiusobj(player laser
;   B369, 200); old pos -> sWP; pos += v; roty = yaw to sWP + $80, rotx =
;   -pitch to sWP; x or y outside -400..399 -> negate vx/vy; sbyte1 - 1 = 0
;   -> sbyte1 1, vz -20, count - 1 (0: removed, deferred); else z - pz < 700
;   or >= 1500 -> negate vz;
;  z += pviewvelz.
M4SxFish:
        move.l #M4SxFishTick,32(a0)
        bset #SF_COLLDISABLE,49(a0)
        move.b #100,38(a0)
        move.b #8,39(a0)
        jsr M4IntroRandom
        move.b d0,14(a0)
        tst.w X_ALPTR(a0)
        beq.s M4SxFishAloneI
        moveq #2,d2
        lea 6(a0),a2
M4SxFishRndV:
        jsr M4IntroRandom
        andi.w #$ff,d0
        subi.w #$80,d0
        move.w d0,(a2)+
        dbra d2,M4SxFishRndV
        bra.s M4SxFishTick
M4SxFishAloneI:
        bclr #3,45(a0)
        move.b #200,19(a0)
        move.b #200,36(a0)
        move.w #20,6(a0)
        move.w #10,8(a0)
        move.w #-10,10(a0)
M4SxFishTick:
        addq.b #8,14(a0)
        move.w X_ALPTR(a0),d0
        beq M4SxFishAlone
        movea.w d0,a2 ;leader
        tst.w 40(a2)
        bne M4SxFishNuke
        tst.w 42(a2)
        bne.s M4SxFishLaser
        tst.b 36(a0)
        beq.s M4SxFishV1
        subq.b #1,36(a0)
        bra.s M4SxFishV4
M4SxFishLaser:
        jsr M4IntroRandom
        andi.b #7,d0
        addq.b #5,d0
        move.b d0,36(a0)
M4SxFishV4:
        movem.w 6(a0),d3-d5
        add.w d3,d3
        add.w d3,d3
        add.w d4,d4
        add.w d4,d4
        add.w d5,d5
        add.w d5,d5
        bra.s M4SxFishTog
M4SxFishV1:
        movem.w 6(a0),d3-d5
M4SxFishTog:
        moveq #3,d2
        move.w (a0),d0
        move.w (a2),d1
        add.w d3,d1
        jsr M4LpAchase
        move.w d0,(a0)
        move.w 2(a0),d0
        move.w 2(a2),d1
        add.w d4,d1
        jsr M4LpAchase
        move.w d0,2(a0)
        move.w 4(a0),d0
        move.w 4(a2),d1
        add.w d5,d1
        jsr M4LpAchase
        move.w d0,4(a0)
        moveq #4,d2
        move.b 12(a0),d0
        move.b 12(a2),d1
        jsr M4EnChase8
        move.b d0,12(a0)
        move.b 13(a0),d0
        move.b 13(a2),d1
        jsr M4EnChase8
        move.b d0,13(a0)
        bra M4SxFishCont
M4SxFishNuke:
        movea.w 40(a2),a2 ;the nuke
        move.w (a0),X_WPX(a0)
        move.w 2(a0),X_WPY(a0)
        move.w 4(a0),X_WPZ(a0)
        moveq #4,d2
        move.w (a0),d0
        move.w (a2),d1
        jsr M4LpAchase
        move.w d0,(a0)
        move.w 2(a0),d0
        move.w 2(a2),d1
        jsr M4LpAchase
        move.w d0,2(a0)
        move.w 4(a0),d0
        move.w 4(a2),d1
        jsr M4LpAchase
        move.w d0,4(a0)
        bsr M4SxFishFace
        bra M4SxFishCont
M4SxFishAlone:
        clr.w 40(a0)
        move.w #$af41,d1
        bsr M4SxFindObj
        beq.s M4SxFishNoNuke
        move.w a3,40(a0)
M4SxFishNoNuke:
        clr.w 42(a0)
        move.w #$b369,d1
        move.w #200,d3
        bsr M4SxFindRadius
        beq.s M4SxFishNoLaser
        move.w a3,42(a0)
M4SxFishNoLaser:
        move.w (a0),X_WPX(a0)
        move.w 2(a0),X_WPY(a0)
        move.w 4(a0),X_WPZ(a0)
        jsr M4EnMove
        bsr M4SxFishFace
        move.w (a0),d0
        cmpi.w #-400,d0
        bmi.s M4SxFishTurnX
        cmpi.w #400,d0
        bmi.s M4SxFishX
M4SxFishTurnX:
        neg.w 6(a0)
M4SxFishX:
        move.w 2(a0),d0
        cmpi.w #-400,d0
        bmi.s M4SxFishTurnY
        cmpi.w #400,d0
        bmi.s M4SxFishY
M4SxFishTurnY:
        neg.w 8(a0)
M4SxFishY:
        subq.b #1,36(a0)
        bne.s M4SxFishSwim
        move.b #1,36(a0)
        move.w #-20,10(a0)
        subq.b #1,19(a0)
        bne.s M4SxFishCont
        jsr M4EnAddPZ
        moveq #1,d0 ;1F:D501, then the tail
        rts
M4SxFishSwim:
        move.w 4(a0),d0
        sub.w M4_LP_POSZ,d0
        cmpi.w #700,d0
        bmi.s M4SxFishTurnZ
        cmpi.w #1500,d0
        bmi.s M4SxFishCont
M4SxFishTurnZ:
        neg.w 10(a0)
M4SxFishCont:
        jsr M4EnAddPZ
        moveq #0,d0
        rts
; roty = yaw to sWP (1F:CF43 negated) + $80, rotx = -(pitch to sWP, 1F:D05C).
M4SxFishFace:
        jsr M4EnWayAngles
        addi.b #$80,d0
        move.b d0,13(a0)
        neg.b d1
        move.b d1,12(a0)
        rts

; ---------------------------------------------------------------------
; Friends' ships of the Sector X and Y endings. Player sflag4 ($1E bit7, set
; by the ending player modes when the player boosts, e.g. 0B:997B) is the
; player's X_WFLAGS bit7 here (build/agent-sectors/INTEGRATION.md section 5).
M4_SX_PSFLAG4 equ 7

; floatCLship2_l 06:E975: sbyte3 = (sbyte3 + 1) mod 28, rotz += asr2(0B:EB8F
; [sbyte3]) (BYTE, toward zero); sbyte4 = (sbyte4 + 1) mod 36 (as 2*(s+1)
; compared with 72, then asr1), y += asr2(sext(06:BADA[2*sbyte4])).
M4SxFloat:
        movem.l d0-d1/a2,-(sp)
        addq.b #1,X_SBYTE3(a0)
        cmpi.b #28,X_SBYTE3(a0)
        bne.s M4SxFloatZ
        clr.b X_SBYTE3(a0)
M4SxFloatZ:
        moveq #0,d0
        move.b X_SBYTE3(a0),d0
        lea M4SxFloatRot,a2
        move.b (a2,d0.w),d0
        bpl.s M4SxFloatZp
        addq.b #3,d0 ;two asr steps toward zero
M4SxFloatZp:
        asr.b #2,d0
        add.b d0,14(a0)
        move.b X_SBYTE4(a0),d0
        addq.b #1,d0
        add.b d0,d0
        cmpi.b #72,d0
        bne.s M4SxFloatY
        moveq #0,d0
M4SxFloatY:
        moveq #0,d1
        move.b d0,d1
        asr.b #1,d0
        move.b d0,X_SBYTE4(a0)
        lea M4SxFloatBob,a2
        move.b (a2,d1.w),d0 ;low byte of the WORD 06:BADA+2s, sign-extended
        ext.w d0
        bpl.s M4SxFloatYp
        addq.w #3,d0
M4SxFloatYp:
        asr.w #2,d0
        add.w d0,2(a0)
        movem.l (sp)+,d0-d1/a2
        rts
; 0B:EB8F (28 bytes) and the 36 WORDs 06:BADA as bytes (low, high).
M4SxFloatRot:
        incbin '../build/M4SxFloatRot.bin'
M4SxFloatBob:
        incbin '../build/M4SxFloatBob.bin'
        even

; clshipEARTHa/b/c 06:C196/C1FA/C25E (myship_4 D320, Sector X ending): sflag1,
; sbyte1 10/20/30, shadow, rotz $C0/$60/-, no zremove, sbyte3 = rnd & 15,
; sbyte4 = rnd & 7. Every tick x = Achase16_4(x, -50/50/0), dZ 100/200/300,
; dY 20/50/50, floatCLship2, then clship_cont 06:C3AA.
M4SxEarthA:
        move.l #M4SxEarthATick,32(a0)
        move.b #10,36(a0)
        move.b #$c0,14(a0)
        bsr M4SxEarthInit
M4SxEarthATick:
        move.w #-50,d1
        moveq #100,d5
        moveq #20,d6
        bra.s M4SxEarthBody
M4SxEarthB:
        move.l #M4SxEarthBTick,32(a0)
        move.b #20,36(a0)
        move.b #$60,14(a0)
        bsr M4SxEarthInit
M4SxEarthBTick:
        moveq #50,d1
        move.w #200,d5
        moveq #50,d6
        bra.s M4SxEarthBody
M4SxEarthC:
        move.l #M4SxEarthCTick,32(a0)
        move.b #30,36(a0)
        bsr M4SxEarthInit
M4SxEarthCTick:
        moveq #0,d1
        move.w #300,d5
        moveq #50,d6
M4SxEarthBody:
        move.w (a0),d0
        moveq #4,d2
        jsr M4LpAchase
        move.w d0,(a0)
        bsr M4SxFloat
        bra M4SxClshipCont
M4SxEarthInit:
        bset #F2_SFLAG1,48(a0)
        bset #F2_SHADOW,48(a0)
        bclr #3,45(a0) ;no zremove
M4SxRndS34:
        jsr M4IntroRandom
        andi.b #15,d0
        move.b d0,X_SBYTE3(a0)
        jsr M4IntroRandom
        andi.b #7,d0
        move.b d0,X_SBYTE4(a0)
        rts

; clship_cont 06:C3AA (d5 = dZ $151F, d6 = dY $1521): |z - viewposZ $C5| >=
; 4000 -> removed (deferred, the tail still runs). sflag1 and player sflag4:
; sbyte1 - 1 != 0 -> tail; else sbyte1 1, z += 100, y -= 10 and, the first
; time (sflag2), boostobj = this ship and its boost flame (06:8671). Else z
; = Achase16_4(z, pz - dZ), y = Achase16_4(y, py + dY), gameframe even ->
; rotz = Achase8_4(rotz, p.rotz), gameframe & 3 == 0 -> rotx = Achase8_5(
; rotx, p.rotx). Tail: z += pviewvelz.
M4SxClshipCont:
        moveq #0,d7
        move.w 4(a0),d0
        sub.w M4_LVW_POS+4,d0
        bpl.s M4SxClDz
        neg.w d0
M4SxClDz:
        cmpi.w #4000,d0
        bmi.s M4SxClKeep
        moveq #1,d7 ;1F:D501
M4SxClKeep:
        btst #F2_SFLAG1,48(a0)
        beq.s M4SxClChase
        btst #M4_SX_PSFLAG4,X_WFLAGS(a1)
        beq.s M4SxClChase
        subq.b #1,36(a0)
        bne M4SxClTail
        move.b #1,36(a0)
        addi.w #100,4(a0)
        subi.w #10,2(a0)
        bset #F2_SFLAG2,48(a0)
        bne M4SxClTail
        jsr M4LevelBoostFlame ;boostobj = a0 (sound $32 not ported)
        bra M4SxClTail
M4SxClChase:
        move.w 4(a0),d0
        move.w 4(a1),d1
        sub.w d5,d1
        moveq #4,d2
        jsr M4LpAchase
        move.w d0,4(a0)
        move.w 2(a0),d0
        move.w 2(a1),d1
        add.w d6,d1
        jsr M4LpAchase
        move.w d0,2(a0)
        btst #0,M4_LV_GAMEFRAME+1
        bne.s M4SxClRotx
        move.b 14(a0),d0
        move.b 14(a1),d1
        moveq #4,d2
        jsr M4EnChase8
        move.b d0,14(a0)
M4SxClRotx:
        moveq #3,d0
        and.w M4_LV_GAMEFRAME,d0
        bne.s M4SxClTail
        move.b 12(a0),d0
        move.b 12(a1),d1
        moveq #5,d2
        jsr M4EnChase8
        move.b d0,12(a0)
M4SxClTail:
        jsr M4EnAddPZ
        move.l d7,d0
        rts

; clshipTURNa/b/c 06:C4CE/C52D/C58C (myship_4 D320, Sector Y ending):
; shadow, no zremove; a: vx 10, rotz $C0, sword1 180 (BYTE store), sflag2;
; b: vx -10, rotz $40, sword1 200, no sflag2; c: sword1 120, sflag2; all
; sbyte1 $2C, sbyte3/4 random. Tick: a flyinleft 06:BD07, b flyinright
; 06:BD85, c x = Achase16_4(x, 0); dZ 100/200/300, dY -20/-20/-30; then
; clshipTURN_cont 06:C5EC.
M4SxTurnA:
        move.l #M4SxTurnATick,32(a0)
        bsr M4SxTurnInit
        move.w #10,6(a0)
        move.b #$c0,14(a0)
        move.w #180,40(a0)
        bset #F2_SFLAG2,48(a0)
        bsr M4SxRndS34
M4SxTurnATick:
        bsr M4SxFlyLeft
        moveq #100,d5
        moveq #-20,d6
        bra M4SxTurnCont
M4SxTurnB:
        move.l #M4SxTurnBTick,32(a0)
        bsr M4SxTurnInit
        move.w #-10,6(a0)
        move.b #$40,14(a0)
        move.w #200,40(a0)
        bclr #F2_SFLAG2,48(a0)
        bsr M4SxRndS34
M4SxTurnBTick:
        bsr M4SxFlyRight
        move.w #200,d5
        moveq #-20,d6
        bra M4SxTurnCont
M4SxTurnC:
        move.l #M4SxTurnCTick,32(a0)
        bsr M4SxTurnInit
        move.w #120,40(a0)
        bset #F2_SFLAG2,48(a0)
        bsr M4SxRndS34
M4SxTurnCTick:
        move.w (a0),d0
        moveq #0,d1
        moveq #4,d2
        jsr M4LpAchase
        move.w d0,(a0)
        move.w #300,d5
        moveq #-30,d6
        bra M4SxTurnCont
M4SxTurnInit:
        bset #F2_SHADOW,48(a0)
        bclr #3,45(a0)
        move.b #$2c,36(a0)
        rts

; flyinleft_srou 06:BD07 (vx = $2F, port 6): sflag1 -> back; x >= -30:
; rotz += 2 and, gameframe even, vx == -5 -> sflag1 (back), else vx - 1;
; back: vx != 0 and gameframe & 7 == 0 -> vx + 1. Then x += vx.
M4SxFlyLeft:
        btst #F2_SFLAG1,48(a0)
        bne.s M4SxFlBack
        move.w (a0),d0
        addi.w #30,d0
        bmi.s M4SxFlMove
        addq.b #2,14(a0)
        btst #0,M4_LV_GAMEFRAME+1
        bne.s M4SxFlMove
        cmpi.w #-5,6(a0)
        beq.s M4SxFlTurn
        subq.w #1,6(a0)
        bra.s M4SxFlMove
M4SxFlTurn:
        bset #F2_SFLAG1,48(a0)
M4SxFlBack:
        tst.w 6(a0)
        beq.s M4SxFlMove
        moveq #7,d0
        and.w M4_LV_GAMEFRAME,d0
        bne.s M4SxFlMove
        addq.w #1,6(a0)
M4SxFlMove:
        move.w 6(a0),d0
        add.w d0,(a0)
        rts
; flyinright_srou 06:BD85: mirror (x <= 30, rotz - 2, vx up to 5, back
; vx - 1).
M4SxFlyRight:
        btst #F2_SFLAG1,48(a0)
        bne.s M4SxFrBack
        move.w (a0),d0
        subi.w #30,d0
        beq.s M4SxFrNear
        bpl.s M4SxFlMove
M4SxFrNear:
        subq.b #2,14(a0)
        btst #0,M4_LV_GAMEFRAME+1
        bne.s M4SxFlMove
        cmpi.w #5,6(a0)
        beq.s M4SxFrTurn
        addq.w #1,6(a0)
        bra.s M4SxFlMove
M4SxFrTurn:
        bset #F2_SFLAG1,48(a0)
M4SxFrBack:
        tst.w 6(a0)
        beq.s M4SxFlMove
        moveq #7,d0
        and.w M4_LV_GAMEFRAME,d0
        bne.s M4SxFlMove
        subq.w #1,6(a0)
        bra.s M4SxFlMove

; clshipTURN_cont 06:C5EC: sword1 0 -> clshipTURN_Istrat; else sword1 - 1,
; z = Achase16_4(z, pz + dZ), y = Achase16_5(y, py + dY), rotz =
; Achase8_5(rotz, 0), floatCLship2, rotx = Achase8_5(rotx, p.rotx), z +=
; pviewvelz.
M4SxTurnCont:
        tst.w 40(a0)
        beq.s M4SxTurn1
        subq.w #1,40(a0)
        move.w 4(a0),d0
        move.w 4(a1),d1
        add.w d5,d1
        moveq #4,d2
        jsr M4LpAchase
        move.w d0,4(a0)
        move.w 2(a0),d0
        move.w 2(a1),d1
        add.w d6,d1
        moveq #5,d2
        jsr M4LpAchase
        move.w d0,2(a0)
        move.b 14(a0),d0
        moveq #0,d1
        jsr M4EnChase8
        move.b d0,14(a0)
        bsr M4SxFloat
        move.b 12(a0),d0
        move.b 12(a1),d1
        moveq #5,d2
        jsr M4EnChase8
        move.b d0,12(a0)
        jsr M4EnAddPZ
        moveq #0,d0
        rts
; clshipTURN_Istrat 06:C675: sbyte2 42; 06:C686: sbyte2 0 -> TURN2; else
; sbyte2 - 1, speedto(32, 1), roty - 1, rotz - 1.
M4SxTurn1:
        move.l #M4SxTurn1Tick,32(a0)
        move.b #42,37(a0)
M4SxTurn1Tick:
        tst.b 37(a0)
        beq.s M4SxTurn2
        subq.b #1,37(a0)
        moveq #32,d0
        moveq #1,d1
        jsr M4EnSpeedTo
        subq.b #1,13(a0)
        subq.b #1,14(a0)
        bra.s M4SxTurnMove
; clshipTURN2_Istrat 06:C6AC: sbyte1 42, zremove on (sounds not ported);
; 06:C6CD: sbyte1 != 0 -> sbyte1 - 1, rotz + 2, roty + 4; else rotz - 2.
M4SxTurn2:
        move.l #M4SxTurn2Tick,32(a0)
        move.b #42,36(a0)
        bset #3,45(a0)
M4SxTurn2Tick:
        tst.b 36(a0)
        beq.s M4SxTurn2Out
        subq.b #1,36(a0)
        addq.b #2,14(a0)
        addq.b #4,13(a0)
        bra.s M4SxTurnMove
M4SxTurn2Out:
        subq.b #2,14(a0)
; clshipTURN2_cont 06:C6EF: pos += gen_3dvecs(vel, roty, rotx), z +=
; pviewvelz.
M4SxTurnMove:
        jsr M4EnGen3d
        jsr M4EnMove
        jsr M4EnAddPZ
        moveq #0,d0
        rts

; ---------------------------------------------------------------------
; flingboss 09:AA4F (flingboss B92F, Sector Y boss) and the arm engine
; arm_istrat 09:A3FB for the shapes it builds (segments B8F7 / B913, grabber
; B94B, phase-2 tail end AF25). The chicken branches of the engine (shapes
; B9BB / B983 / B967, armmode $176D != 0: Fortuna's boss 09:B31D, routines in
; level_fortuna_boss.asm) are marked 09:A460 / A4B5 / A57B / A8C4 / A912;
; flingboss keeps armmode 0. Extra sflags (X_WFLAGS bits, as
; level_venom_bossb.asm): sflag3 $1E $40 bit0, sflag5 $1F $01 bit1, $1F $02
; bit2 (tail), $1F $04 bit3 (bounded debris), sflag4 $1E $80 bit7. sflag1/2
; ($1E $10/$20) = port 48 bit0/1. sword2 ($28 low, $29 high) = port 43/42.
; Sounds ($39, $2E, $49) not ported. When the ROM writes through a null
; pointer (0 or the dummy $156D of a failed find/creation) the port skips
; the write [H, not reached in the oracle runs].
SXF_S3 equ 0
SXF_S5 equ 1
SXF_TAIL equ 2
SXF_BOUND equ 3
M4_SX_ARMMODE equ M4_SECTORS+1 ;.b $176D armmode

; dzdistless 09:80AB: d0 = K -> Z clear (bne) when N(|pz - z| - K).
M4SxDzLess:
        move.w d0,d1
        movea.l a1,a2
        jsr M4EnZD
        sub.w d1,d0
        smi d0
        tst.b d0
        rts

; a0 reference, a3 target, d3/d4/d5 offset BYTEs: a3 pos = a0 pos +
; 4 * rot(offset) by a0's rotz, rotx, roty (09:AED4: 1F:CC78, CAFB, C97B).
M4SxPlace:
        movem.l d3-d5/a2,-(sp)
        movea.l a0,a2
        jsr M4WeaponOffset
        add.w (a0),d3
        move.w d3,(a3)
        add.w 2(a0),d4
        move.w d4,2(a3)
        add.w 4(a0),d5
        move.w d5,4(a3)
        movem.l (sp)+,d3-d5/a2
        rts

; 1F:DB01: a3 rotations = a0 rotations.
M4SxCopyRots:
        move.b 12(a0),12(a3)
        move.b 13(a0),13(a3)
        move.b 14(a0),14(a3)
        rts

; Shape header of a3 = d0 (sta $04,y): descriptor and X_SHAPEHDR.
M4SxSetHdr:
        movem.l d0-d1/a0,-(sp)
        movea.l a3,a0
        move.w d0,X_SHAPEHDR(a0)
        jsr M4LevelShapeIndex
        jsr M4LevelSetShape
        movem.l (sp)+,d0-d1/a0
        rts

; 09:A3E5: every object of allst whose al_ptr is a0 gets al_ptr 0.
M4SxUnlinkMe:
        movem.l d0-d1/a3,-(sp)
        move.w a0,d1
        move.w M4_LV_HEAD,d0
M4SxUnlinkNext:
        tst.w d0
        beq.s M4SxUnlinkDone
        movea.w d0,a3
        cmp.w X_ALPTR(a3),d1
        bne.s M4SxUnlinkKeep
        clr.w X_ALPTR(a3)
M4SxUnlinkKeep:
        move.w X_NEXT(a3),d0
        bra.s M4SxUnlinkNext
M4SxUnlinkDone:
        movem.l (sp)+,d0-d1/a3
        rts

; 09:B1FF (d1 = header) / 09:B1C7 (al_ptr == a0): first object of allst ->
; a3 (Z set when none: the ROM then takes the dummy $156D).
M4SxFindHdr:
        move.w M4_LV_HEAD,d2
M4SxFindHdrNext:
        tst.w d2
        beq.s M4SxFindHdrNone
        movea.w d2,a3
        move.w X_NEXT(a3),d2
        bsr M4SxHeader
        cmp.w d1,d0
        bne.s M4SxFindHdrNext
        move.l a3,d0
        rts
M4SxFindHdrNone:
        suba.l a3,a3
        move.l a3,d0
        rts
M4SxFindParent:
        move.w a0,d1
        move.w M4_LV_HEAD,d2
M4SxFindParNext:
        tst.w d2
        beq.s M4SxFindHdrNone
        movea.w d2,a3
        move.w X_NEXT(a3),d2
        cmp.w X_ALPTR(a3),d1
        bne.s M4SxFindParNext
        move.l a3,d0
        rts

; Animation steps on animframe (16): 09:8048 +1 mod d2, 09:808B -1 mod d2
; (M4WpAddAnim), 09:8064 +1 clamped to d2 - 1.
M4SxAnimClamp:
        move.b 16(a0),d0
        addq.b #1,d0
        bmi.s M4SxAnimClampM
        add.b d2,d0
M4SxAnimClampM:
        andi.b #$7f,d0
        cmp.b d2,d0
        blo.s M4SxAnimClampS
        move.b d2,d0
        subq.b #1,d0
M4SxAnimClampS:
        ori.b #$80,d0
        move.b d0,16(a0)
        rts

; ---------------------------------------------------------------------
; flingboss_istrat 09:AA4F: m_bossmaxHP $68, m_bossHP 0, armmode 0,
; animframe/colframe $80, normal pointers, nohitaffect, HP $FF, AP $20,
; sbyte4 24, roty $80, sword2 low 0, enemy1, z += 4000; both arms (09:ADEB).
; A failed creation keeps this Istrat for the next tick (all of it again).
M4SxFling:
        move.b #$68,M4_BOSS_MAXHP
        clr.b M4_BOSS_HP
        clr.b M4_SX_ARMMODE
        move.b #$80,16(a0)
        move.b #$80,18(a0)
        jsr M4LvNormPtrs
        bset #SF_NOHITAFFECT,49(a0)
        move.b #$ff,38(a0)
        move.b #$20,39(a0)
        move.b #24,X_SBYTE4(a0)
        move.b #$80,13(a0)
        clr.b 43(a0)
        ori.b #CF_ENEMY1,44(a0)
        addi.w #4000,4(a0)
        bsr M4SxFbGenerate
        beq.s M4SxFlingOk
        move.l #M4SxFling,32(a0)
        moveq #0,d0
        rts
M4SxFlingOk:
        move.l #M4SxFlingTick,32(a0)
; 09:AACE: rotx += $10, z -= 50; |pz - z| < 2000 and rotx 0 -> main; else
; z += pviewvelz, wavex and the arms placed.
M4SxFlingTick:
        addi.b #$10,12(a0)
        subi.w #50,4(a0)
        move.w #2000,d0
        bsr M4SxDzLess
        beq.s M4SxFlFar
        tst.b 12(a0)
        beq.s M4SxFbInitMain
M4SxFlFar:
        jsr M4EnAddPZ
        bsr M4SxFbWaveX
        bra M4SxFbLinked
; 09:AB0F / AB20: sbyte1 80 ticks of main, then the spin.
M4SxFbInitMain:
        move.l #M4SxFbMain,32(a0)
        move.b #$50,36(a0)
M4SxFbMain:
        tst.b 36(a0)
        beq M4SxFbSpin0
        subq.b #1,36(a0)
; .fin 09:AB2A: colframe +1 mod 4; sflag5 (an arm was hit): hitflash, sflag5
; off, sbyte4 - 2 (reaching 0 -> phase 2 09:B0A2); z += pviewvelz, movement,
; missile triggers; then the arms placed and m_bossHP += sbyte4 + $50.
M4SxFbFin:
        move.b 18(a0),d0
        moveq #1,d1
        moveq #4,d2
        jsr M4WpAddAnim
        move.b d0,18(a0)
        btst #SXF_S5,X_WFLAGS(a0)
        beq.s M4SxFbNoFlash
        bset #SF_HITFLASH,49(a0)
        bset #2,31(a0)
        bclr #SXF_S5,X_WFLAGS(a0)
        tst.b X_SBYTE4(a0)
        beq M4SxFbPhase2
        subq.b #1,X_SBYTE4(a0)
        beq M4SxFbPhase2
        subq.b #1,X_SBYTE4(a0)
M4SxFbNoFlash:
        jsr M4EnAddPZ
        bsr M4SxFbMoveBF
        bsr M4SxFbTrigM
        bsr M4SxFbTrigM2
M4SxFbLinked:
        move.w X_ALPTR(a0),d0
        beq.s M4SxFbLinked2
        movea.w d0,a3
        bsr M4SxFbPos1
M4SxFbLinked2:
        move.w 40(a0),d0
        beq.s M4SxFbLinkedHp
        movea.w d0,a3
        bsr M4SxFbPos2
M4SxFbLinkedHp:
        move.b X_SBYTE4(a0),d0
        addi.b #$50,d0
        add.b d0,M4_BOSS_HP
        moveq #0,d0
        rts
; .spinlikecrazy 09:AB99: sflag2 and sflag1 toggle, sbyte1 100; 09:ABB6:
; roty +/- 8 by sflag1; sbyte1 0 and roty $80 -> wave.
M4SxFbSpin0:
        bchg #F2_SFLAG2,48(a0)
        move.b #100,36(a0)
        move.l #M4SxFbSpin,32(a0)
        bchg #F2_SFLAG1,48(a0)
M4SxFbSpin:
        btst #F2_SFLAG1,48(a0)
        beq.s M4SxFbSpinSub
        addq.b #8,13(a0)
        bra.s M4SxFbSpinCnt
M4SxFbSpinSub:
        subq.b #8,13(a0)
M4SxFbSpinCnt:
        tst.b 36(a0)
        beq.s M4SxFbSpinEnd
        subq.b #1,36(a0)
        bra M4SxFbFin
M4SxFbSpinEnd:
        cmpi.b #$80,13(a0)
        bne M4SxFbFin
; 09:AC06 / AC17: 50 ticks sbyte2 = asr2(sin8[2 gameframe]); then until
; sbyte2 0.
        move.l #M4SxFbWave,32(a0)
        move.b #50,36(a0)
M4SxFbWave:
        move.w M4_LV_GAMEFRAME,d0
        add.b d0,d0
        bsr M4SxFbSinQ
        move.b d0,37(a0)
        tst.b 36(a0)
        beq.s M4SxFbWaveEnd
        subq.b #1,36(a0)
        bra M4SxFbFin
M4SxFbWaveEnd:
        tst.b 37(a0)
        bne M4SxFbFin
; 09:AC62 / AC73: 140 ticks sbyte3 - 4 down to -52 ($CC).
        move.l #M4SxFbWave2,32(a0)
        move.b #$8c,36(a0)
M4SxFbWave2:
        cmpi.b #$cc,X_SBYTE3(a0)
        beq.s M4SxFbWave2Cnt
        subq.b #4,X_SBYTE3(a0)
M4SxFbWave2Cnt:
        tst.b 36(a0)
        beq.s M4SxFbSide0
        subq.b #1,36(a0)
        bra M4SxFbFin
; 09:ACA2 / ACB3: 180 ticks roty = asr1(sinQ(2 gameframe)) + $80; then
; sbyte3 0, roty $80 and main again.
M4SxFbSide0:
        move.l #M4SxFbSide,32(a0)
        move.b #$b4,36(a0)
M4SxFbSide:
        tst.b 36(a0)
        beq.s M4SxFbSideEnd
        subq.b #1,36(a0)
        move.w M4_LV_GAMEFRAME,d0
        add.b d0,d0
        bsr M4SxFbSinQ
        tst.b d0
        bpl.s M4SxFbSideP
        addq.b #1,d0
M4SxFbSideP:
        asr.b #1,d0
        addi.b #$80,d0
        move.b d0,13(a0)
        bra M4SxFbFin
M4SxFbSideEnd:
        clr.b X_SBYTE3(a0)
        move.b #$80,13(a0)
        bra M4SxFbInitMain
; 09:AC40: d0.b index -> asr2(sin8[index]) toward zero (00:98A5).
M4SxFbSinQ:
        move.l a2,-(sp)
        andi.w #$ff,d0
        lea M4IntroShipSine,a2
        move.b (a2,d0.w),d0
        bpl.s M4SxFbSinQp
        addq.b #3,d0
M4SxFbSinQp:
        asr.b #2,d0
        movea.l (sp)+,a2
        rts
; .wavex 09:AD89: x = 2 * sin8[gameframe & 255].
M4SxFbWaveX:
        move.l a2,-(sp)
        moveq #0,d0
        move.b M4_LV_GAMEFRAME+1,d0
        lea M4IntroShipSine,a2
        move.b (a2,d0.w),d0
        ext.w d0
        add.w d0,d0
        move.w d0,(a0)
        movea.l (sp)+,a2
        rts
; .movebackandforth 09:AD12: wavex; sflag3: z += 20, rotx -> 0 (step 1),
; y = Achase16_4(y, py + 100), |pz - z| >= 2000 -> sflag3 off; else z -= 40,
; rotx -> 20, y = Achase16_4(y, py - 250), |pz - z| < 500 -> sflag3 on.
M4SxFbMoveBF:
        bsr M4SxFbWaveX
        btst #SXF_S3,X_WFLAGS(a0)
        beq.s M4SxFbForward
        addi.w #20,4(a0)
        move.b 12(a0),d0
        beq.s M4SxFbBackR
        bmi.s M4SxFbBackI
        subq.b #1,d0
        bra.s M4SxFbBackR
M4SxFbBackI:
        addq.b #1,d0
M4SxFbBackR:
        move.b d0,12(a0)
        move.w 2(a1),d1
        addi.w #100,d1
        bsr M4SxFbChaseY
        move.w #2000,d0
        bsr M4SxDzLess
        bne.s M4SxFbBfDone
        bra.s M4SxFbBfToggle
M4SxFbForward:
        subi.w #40,4(a0)
        move.b 12(a0),d0
        cmpi.b #20,d0
        beq.s M4SxFbFwdR
        bmi.s M4SxFbFwdI
        subq.b #1,d0
        bra.s M4SxFbFwdR
M4SxFbFwdI:
        addq.b #1,d0
M4SxFbFwdR:
        move.b d0,12(a0)
        move.w 2(a1),d1
        subi.w #250,d1
        bsr M4SxFbChaseY
        move.w #500,d0
        bsr M4SxDzLess
        beq.s M4SxFbBfDone
M4SxFbBfToggle:
        bchg #SXF_S3,X_WFLAGS(a0)
M4SxFbBfDone:
        rts
M4SxFbChaseY:
        move.w 2(a0),d0
        moveq #4,d2
        jsr M4LpAchase
        move.w d0,2(a0)
        rts
; .triggermissile 09:AF70: sword2 high != 0 -> - 1; else sword2 low != 0 ->
; - 1, the arm (sflag4 ? sword1 : al_ptr) gets sflag2 (fires), high 4; else
; random_l >= $FC -> low 3, sflag4 toggles.
M4SxFbTrigM:
        tst.b 42(a0)
        beq.s M4SxFbTrigLo
        subq.b #1,42(a0)
        rts
M4SxFbTrigLo:
        tst.b 43(a0)
        beq.s M4SxFbTrigRnd
        subq.b #1,43(a0)
        move.w X_ALPTR(a0),d0
        btst #7,X_WFLAGS(a0)
        beq.s M4SxFbTrigArm
        move.w 40(a0),d0
M4SxFbTrigArm:
        tst.w d0
        beq.s M4SxFbTrigHi
        movea.w d0,a3
        bset #F2_SFLAG2,48(a3)
M4SxFbTrigHi:
        move.b #4,42(a0)
        rts
M4SxFbTrigRnd:
        jsr M4IntroRandom
        cmpi.b #$fc,d0
        blo.s M4SxFbTrigDone
        move.b #3,43(a0)
        bchg #7,X_WFLAGS(a0)
M4SxFbTrigDone:
        rts
; .triggermissile2 09:AFB9: (gameframe & $3F) == 0 -> one bosshmissile1
; (rotx add 8). 09:B061: offset (0, 5, 0), no target; the missile al_ptr =
; player, enemy1.
M4SxFbTrigM2:
        moveq #$3f,d0
        and.w M4_LV_GAMEFRAME,d0
        bne.s M4SxFbTrigDone
        moveq #8,d6
        moveq #0,d7
M4SxFbMissile:
        moveq #0,d3
        moveq #5,d4
        moveq #0,d5
        suba.l a3,a3
        moveq #M4_WT_BOSSHM1,d0
        jsr M4EnFire
        cmpa.w #0,a2
        beq.s M4SxFbMisDone
        move.w a1,X_ALPTR(a2)
        ori.b #CF_ENEMY1,44(a2)
M4SxFbMisDone:
        rts
; .triggermissile3 09:AFD8 (phase 2): every 64 ticks, HP >= 40: (8, $30)
; and (8, $D0); else (8, $20), (8, $E0), (0, 0), (16, 0).
M4SxFbTrigM3:
        moveq #$3f,d0
        and.w M4_LV_GAMEFRAME,d0
        bne.s M4SxFbTrigDone
        cmpi.b #$28,38(a0)
        bmi.s M4SxFbHarder
        moveq #8,d6
        moveq #$30,d7
        bsr.s M4SxFbMissile
        moveq #8,d6
        move.b #$d0,d7
        bra.s M4SxFbMissile
M4SxFbHarder:
        moveq #8,d6
        moveq #$20,d7
        bsr.s M4SxFbMissile
        moveq #8,d6
        move.b #$e0,d7
        bsr.s M4SxFbMissile
        moveq #0,d6
        moveq #0,d7
        bsr.s M4SxFbMissile
        moveq #16,d6
        moveq #0,d7
        bra.s M4SxFbMissile

; .generate 09:ADEB: arm 1 (al_ptr, unless already made) and arm 2 (sword1):
; make_obj B8F7, Istrat arm 09:A3FB, sword1 5, placed. d0 = 0 / Z set when
; both exist, else nonzero.
M4SxFbGenerate:
        tst.w X_ALPTR(a0)
        bne.s M4SxFbGen2
        move.w #$b8f7,d0
        jsr M4ArCreateHdr
        beq.s M4SxFbGenFail
        move.l #M4SxArm,32(a2)
        move.b #5,41(a2)
        move.w a2,X_ALPTR(a0)
        movea.l a2,a3
        bsr M4SxFbPos1
M4SxFbGen2:
        move.w #$b8f7,d0
        jsr M4ArCreateHdr
        beq.s M4SxFbGenFail
        move.l #M4SxArm,32(a2)
        move.b #5,41(a2)
        move.w a2,40(a0)
        movea.l a2,a3
        bsr M4SxFbPos2
        moveq #0,d0
        rts
M4SxFbGenFail:
        moveq #1,d0
        rts
; .position1/2 09:AE4D / AE78 and position5 09:AEA4 (a3 = arm): the boss
; rotations plus the arm offsets; offsets (-30, 0, 2) / (30, 0, 2) /
; (0, 10, 20) rotated by the boss.
M4SxFbPos1:
        bsr M4SxCopyRots
        move.b 13(a3),d0
        addi.b #$40,d0
        add.b X_SBYTE3(a0),d0
        move.b d0,13(a3)
        move.b 12(a3),d0
        add.b 37(a0),d0
        add.b 14(a0),d0
        move.b d0,12(a3)
        moveq #-30,d3
        bra.s M4SxFbPosXY
M4SxFbPos2:
        bsr M4SxCopyRots
        move.b 13(a3),d0
        addi.b #$c0,d0
        sub.b X_SBYTE3(a0),d0
        move.b d0,13(a3)
        move.b 12(a3),d0
        add.b 37(a0),d0
        sub.b 14(a0),d0
        move.b d0,12(a3)
        moveq #30,d3
M4SxFbPosXY:
        moveq #0,d4
        moveq #2,d5
        bra M4SxPlace
M4SxFbPos5:
        bsr M4SxCopyRots
        move.b 12(a3),d0
        sub.b 37(a0),d0
        addq.b #8,d0
        sub.b 14(a0),d0
        move.b d0,12(a3)
        move.b 13(a3),d0
        sub.b X_SBYTE3(a0),d0
        move.b d0,13(a3)
        subi.b #$40,14(a3)
        moveq #0,d3
        moveq #10,d4
        moveq #20,d5
        bra M4SxPlace

; Phase 2 09:B0A2: both arms destroyed (09:B091 -> 09:A2CD); 09:B0A5:
; strategy B0FD, collstrat hitflash, expstrat 09:B271, nohitaffect off, HP
; $50, AP $20, sword1 $50, sbyte2/3 0, the tail (09:B19F; failure: B0A5
; again on the next tick).
M4SxFbPhase2:
        move.w X_ALPTR(a0),d0
        beq.s M4SxFbP2Arm2
        movea.w d0,a3
        bsr M4SxArmDestroy
M4SxFbP2Arm2:
        move.w 40(a0),d0
        beq.s M4SxFbP2Init
        movea.w d0,a3
        bsr M4SxArmDestroy
M4SxFbP2Init:
        move.l #M4SxFbP2,32(a0)
        move.l #M4LcHitFlash,X_COLL(a0)
        move.l #M4SxFbDeath,X_EXP(a0)
        bclr #SF_NOHITAFFECT,49(a0)
        move.b #$50,38(a0)
        move.b #$20,39(a0)
        move.w #$50,40(a0)
        clr.b 37(a0)
        clr.b X_SBYTE3(a0)
        move.w #$b8f7,d0 ;09:B19F: the tail (sword1 6, tail flag, position5)
        jsr M4ArCreateHdr
        bne.s M4SxFbTailOk
        move.l #M4SxFbP2Init,32(a0)
        moveq #0,d0
        rts
M4SxFbTailOk:
        move.l #M4SxArm,32(a2)
        move.b #6,41(a2)
        move.w a2,X_ALPTR(a0)
        bset #SXF_TAIL,X_WFLAGS(a2)
        movea.l a2,a3
        bsr M4SxFbPos5
; 09:B0FD: colframe cycles 4..7 (exact byte steps), animframe up to 8
; (09:8064 n 9), z += pviewvelz + sword1 (sword1 - 2 while nonzero, with
; wavex; at 0 movebackandforth), roty += ~((HP >> 2) & $F8) + $13 + carry
; (bit 1 of HP), the tail placed, triggermissile3, m_bossHP += HP.
M4SxFbP2:
        move.b 18(a0),d0
        addq.b #1,d0
        cmpi.b #4,d0
        bmi.s M4SxFbP2C1
        addq.b #4,d0
M4SxFbP2C1:
        andi.b #$7f,d0
        cmpi.b #8,d0
        blo.s M4SxFbP2C2
        subq.b #4,d0
M4SxFbP2C2:
        ori.b #$80,d0
        move.b d0,18(a0)
        moveq #9,d2
        bsr M4SxAnimClamp
        jsr M4EnAddPZ
        move.w 40(a0),d0
        add.w d0,4(a0)
        tst.w 40(a0)
        beq.s M4SxFbP2Move
        subq.w #2,40(a0)
        bsr M4SxFbWaveX
        bra.s M4SxFbP2Rot
M4SxFbP2Move:
        bsr M4SxFbMoveBF
M4SxFbP2Rot:
        moveq #0,d0
        move.b 38(a0),d0
        move.w d0,d1
        lsr.w #1,d1
        andi.w #1,d1 ;carry of the second lsr
        lsr.b #2,d0
        andi.b #$f8,d0
        not.b d0
        addi.b #$13,d0
        add.b d1,d0
        add.b d0,13(a0)
        move.w X_ALPTR(a0),d0
        beq.s M4SxFbP2Fire
        movea.w d0,a3
        bsr M4SxFbPos5
M4SxFbP2Fire:
        bsr M4SxFbTrigM3
        move.b 38(a0),d0
        add.b d0,M4_BOSS_HP
        moveq #0,d0
        rts
; Death 09:B271 (expstrat at HP 0): the tail destroyed, roty $80, HP $FF,
; AP 8, expstrat bossexplode 06:EAAE (M4B1Explode, level_boss1.asm), sword1
; $A1; 09:B2AC: waits for |pz - z| < 100; 09:B2CA: z += pviewvelz, sword1 -
; 4, below 40 -> (gameflags & $42 == 0) colldisable and HP 0 (bossexplode
; next tick); else z += sword1, rotx - 20.
M4SxFbDeath:
        move.w X_ALPTR(a0),d0
        beq.s M4SxFbDeath1
        movea.w d0,a3
        bsr M4SxArmDestroy
M4SxFbDeath1:
        move.b #$80,13(a0)
        move.b #$ff,38(a0)
        move.b #8,39(a0)
        move.l #M4SxFbDeathWait,32(a0)
        move.l #M4B1Explode,X_EXP(a0)
        move.w #$a1,40(a0)
M4SxFbDeathWait:
        move.w #100,d0
        bsr M4SxDzLess
        beq.s M4SxFbDeathKeep
        move.l #M4SxFbDeathRise,32(a0)
M4SxFbDeathRise:
        jsr M4EnAddPZ
        subq.w #4,40(a0)
        move.w 40(a0),d0
        cmpi.w #40,d0
        bmi.s M4SxFbDeathEnd
        add.w d0,4(a0)
        subi.b #20,12(a0)
M4SxFbDeathKeep:
        moveq #0,d0
        rts
M4SxFbDeathEnd:
        move.b M4_LP_GAMEFLAGS,d0
        andi.b #$42,d0
        bne.s M4SxFbDeathKeep
        bset #SF_COLLDISABLE,49(a0)
        clr.b 38(a0)
        bra.s M4SxFbDeathKeep

; ---------------------------------------------------------------------
; Arm engine. 09:A2CD (a3 = segment): it and its descendants (al_ptr chain)
; become debris 09:A2E3; its expstrat explode 06:F45F (1F:DA2D); pointers to
; it cleared (09:A3E5); colldisable, HP 0.
M4SxArmDestroy:
        movem.l d0/a0,-(sp)
        movea.l a3,a0
M4SxArmDestroyChain:
        move.l #M4SxDebris,32(a0)
        move.w X_ALPTR(a0),d0
        beq.s M4SxArmDestroyEnd
        movea.w d0,a0
        bra.s M4SxArmDestroyChain
M4SxArmDestroyEnd:
        movea.l a3,a0
        move.l #M4LevelExplode,X_EXP(a0)
        bsr M4SxUnlinkMe
        bset #SF_COLLDISABLE,49(a0)
        clr.b 38(a0)
        movem.l (sp)+,d0/a0
        rts
; Debris 09:A2E3: vel 30, roty = rnd, v = gen_3dvecs, vy -10, pointers to it
; cleared. 09:A30A: rotz + 5, rotx + 2, vy + 3; y >= 0: y = 0, vy =
; asr2(-vy) (-5..-1 -> 0), low byte 0 -> explodes; else pos += v and out
; (09:9FDB) -> explodes (expstrat explode, colldisable, HP 0).
M4SxDebris:
        move.l #M4SxDebrisTick,32(a0)
        move.b #30,15(a0)
        jsr M4IntroRandom
        move.b d0,13(a0)
        jsr M4EnGen3d
        move.w #-10,8(a0)
        bsr M4SxUnlinkMe
M4SxDebrisTick:
        addq.b #5,14(a0)
        addq.b #2,12(a0)
        addq.w #3,8(a0)
        tst.w 2(a0)
        bmi.s M4SxDebrisMove
        clr.w 2(a0)
        move.w 8(a0),d0
        neg.w d0
        bpl.s M4SxDebrisB
        addq.w #3,d0
M4SxDebrisB:
        asr.w #2,d0
        cmpi.w #$fffb,d0
        blo.s M4SxDebrisB2
        moveq #0,d0
M4SxDebrisB2:
        move.w d0,8(a0)
        tst.b d0
        beq.s M4SxDebrisBoom
M4SxDebrisMove:
        jsr M4EnMove
        btst #SXF_BOUND,X_WFLAGS(a0) ;09:9FDB
        beq.s M4SxDebrisGnd
        move.w (a0),d0
        sub.w M4_LP_MINX,d0
        move.w M4_LP_MAXX,d1
        sub.w M4_LP_MINX,d1
        cmp.w d1,d0
        bhs.s M4SxDebrisBoom
        move.w 2(a0),d0
        sub.w M4_LP_MINY,d0
        move.w M4_LP_MAXY,d1
        sub.w M4_LP_MINY,d1
        cmp.w d1,d0
        bhs.s M4SxDebrisBoom
        bra.s M4SxDebrisKeep
M4SxDebrisGnd:
        tst.w 2(a0)
        bpl.s M4SxDebrisBoom
M4SxDebrisKeep:
        moveq #0,d0
        rts
M4SxDebrisBoom:
        move.l #M4LevelExplode,X_EXP(a0)
        bset #SF_COLLDISABLE,49(a0)
        clr.b 38(a0)
        moveq #0,d0
        rts

; arm_istrat 09:A3FB: strategy A497, expstrat explode 06:F45F, no collstrat
; (grabber B94B: 09:A7F0), HP $FF, AP 10, sbyte1-3 0, sbyte4 32, enemy1, no
; zremove. 09:A497 -> A546 for the shapes of flingboss.
M4SxArm:
        move.l #M4SxArmTick,32(a0)
        clr.l X_COLL(a0)
        move.l #M4LevelExplode,X_EXP(a0)
        move.b #$ff,38(a0)
        move.b #10,39(a0)
        clr.b 36(a0)
        clr.b 37(a0)
        clr.b X_SBYTE3(a0)
        move.b #32,X_SBYTE4(a0)
        ori.b #CF_ENEMY1,44(a0)
        bclr #3,45(a0)
        movea.l a0,a3
        bsr M4SxHeader
        cmpi.w #$b94b,d0
        bne.s M4SxArmChick
        move.l #M4SxGrabColl,X_COLL(a0)
; 09:A460: Fortuna's tail end B9BB HP $42, head B983 HP $44, AP 10,
; collstrat 09:A704 (level_fortuna_boss.asm).
M4SxArmChick:
        cmpi.w #$b9bb,d0
        beq.s M4SxArmTailI
        cmpi.w #$b983,d0
        bne.s M4SxArmTick
        move.b #$44,38(a0)
        bra.s M4SxArmHeadI
M4SxArmTailI:
        move.b #$42,38(a0)
M4SxArmHeadI:
        move.b #10,39(a0)
        move.l #M4CkHeadColl,X_COLL(a0)
; 09:A546: the head (no sflag1) moves its chain (09:A86F); with sflag2 the
; segment fires: grabber at once (Hplasma, offset (0, 0, 4)); a segment opens
; (B913, animframe +1 mod 5) and at frame 4 closes (B8F7) and passes sflag2
; down its chain, the last one firing Hplasma at offset (0, 0, $24); with
; sflag5 and sflag1 instead it breaks off (09:A2CD). sflag5: animframe -1
; mod 8, at 7 B8F7 again, sflag5 off and the hit goes up (09:A813). Every 32
; ticks (sbyte4, armmode 0) the end of a chain grows (09:A87E). Tail end AF25:
; rotations $80/0/0.
M4SxArmTick:
        movea.l a0,a3
        bsr M4SxHeader
        cmpi.w #$b9bb,d0 ;09:A497: Fortuna's head / tail end first (09:A4B5)
        beq.s M4SxArmCk
        cmpi.w #$b983,d0
        bne.s M4SxArmChk1
M4SxArmCk:
        jsr M4CkArmHead
M4SxArmChk1:
        btst #F2_SFLAG1,48(a0)
        bne.s M4SxArmFire
        bsr M4SxArmChain
M4SxArmFire:
        movea.l a0,a3
        bsr M4SxHeader
        move.w d0,d7 ;own header
        btst #F2_SFLAG2,48(a0)
        beq M4SxArmHit
        cmpi.w #$b94b,d7
        beq M4SxArmGrabFire
        cmpi.w #$b9bb,d7
        beq M4SxArmEgg
        btst #SXF_S5,X_WFLAGS(a0)
        beq.s M4SxArmOpen
        btst #F2_SFLAG1,48(a0)
        beq.s M4SxArmOpen
        movea.l a0,a3
        bsr M4SxArmDestroy
        moveq #0,d0
        rts
M4SxArmOpen:
        btst #SXF_S3,X_WFLAGS(a0)
        bne.s M4SxArmOpening
        move.b #$80,16(a0)
        movea.l a0,a3
        move.w #$b913,d0
        bsr M4SxSetHdr
        bset #SXF_S3,X_WFLAGS(a0)
        bra.s M4SxArmHit
M4SxArmOpening:
        move.b 16(a0),d0
        moveq #1,d1
        moveq #5,d2
        jsr M4WpAddAnim
        move.b d0,16(a0)
        andi.b #$7f,d0
        cmpi.b #4,d0
        bne.s M4SxArmHit
        bclr #F2_SFLAG2,48(a0)
        bclr #SXF_S3,X_WFLAGS(a0)
        movea.l a0,a3
        move.w #$b8f7,d0
        bsr M4SxSetHdr
        move.w X_ALPTR(a0),d0
        beq.s M4SxArmEndFire
        movea.w d0,a3
        bset #F2_SFLAG2,48(a3)
        bra.s M4SxArmHit
M4SxArmEndFire:
        moveq #$24,d5
        bra.s M4SxArmShoot
M4SxArmGrabFire:
        moveq #4,d5
M4SxArmShoot:
        bclr #F2_SFLAG2,48(a0)
        moveq #0,d3
        moveq #0,d4
        moveq #0,d6
        moveq #0,d7
        suba.l a3,a3
        moveq #M4_WT_HPLASMA,d0
        jsr M4EnFire
        cmpa.w #0,a2
        beq.s M4SxArmHitRd
        move.w a1,X_ALPTR(a2)
M4SxArmHitRd:
        movea.l a0,a3
        bsr M4SxHeader
        move.w d0,d7
M4SxArmHit:
        btst #SXF_S5,X_WFLAGS(a0)
        beq.s M4SxArmGrow
        move.b 16(a0),d0
        moveq #-1,d1
        moveq #8,d2
        jsr M4WpAddAnim
        move.b d0,16(a0)
        andi.b #$7f,d0
        cmpi.b #7,d0
        bne.s M4SxArmGrow
        movea.l a0,a3
        move.w #$b8f7,d0
        bsr M4SxSetHdr
        move.w d0,d7
        bclr #SXF_S5,X_WFLAGS(a0)
        bsr M4SxArmHitUp
M4SxArmGrow:
        tst.b M4_SX_ARMMODE
        bne.s M4SxArmMode
        subq.b #1,X_SBYTE4(a0)
        bne.s M4SxArmTail
        move.b #32,X_SBYTE4(a0)
M4SxArmMode:
        moveq #6,d0
        and.b M4_SX_ARMMODE,d0
        cmpi.b #6,d0
        beq.s M4SxArmDone
        tst.w X_ALPTR(a0)
        bne.s M4SxArmTail
        cmpi.w #$af25,d7
        beq.s M4SxArmTail
        cmpi.w #$b9bb,d7
        beq.s M4SxArmDone
        cmpi.w #$b983,d7
        beq.s M4SxArmDone
        cmpi.w #$b94b,d7
        beq.s M4SxArmTail
        bra M4SxArmAdd
M4SxArmTail:
        cmpi.w #$af25,d7
        bne.s M4SxArmDone
        move.b #$80,13(a0)
        clr.b 12(a0)
        clr.b 14(a0)
M4SxArmDone:
        moveq #0,d0
        rts
; 09:A57B: the tail end B9BB lays an egg: make_obj, B059, its position and
; rotations, Istrat egg 09:BCD9, sflag2 off (kept on a failed creation).
M4SxArmEgg:
        move.w #$b8f7,d0
        jsr M4ArCreateHdr
        beq M4SxArmHit
        movea.l a2,a3
        move.w #$b059,d0
        bsr M4SxSetHdr
        jsr M4TiCopyPosRots
        move.l #M4CkEgg,32(a2)
        bclr #F2_SFLAG2,48(a0)
        bra M4SxArmHit
; 09:A813 (a0 = hit segment): the head marks the flingboss (09:B1FF, shape
; B92F) with sflag5; a child marks its parent (09:B1C7), which if it is a
; closed or open segment (B8F7/B913) without sflag5 also opens (animframe
; $83, B913).
M4SxArmHitUp:
        movem.l d0-d2/a3,-(sp)
        btst #F2_SFLAG1,48(a0)
        bne.s M4SxArmHitPar
        move.w #$b92f,d1
        bsr M4SxFindHdr
        beq.s M4SxArmHitDone
        bra.s M4SxArmHitMark
M4SxArmHitPar:
        bsr M4SxFindParent
        beq.s M4SxArmHitDone
        bsr M4SxHeader
        cmpi.w #$b8f7,d0
        beq.s M4SxArmHitSeg
        cmpi.w #$b913,d0
        bne.s M4SxArmHitMark
M4SxArmHitSeg:
        btst #SXF_S5,X_WFLAGS(a3)
        bne.s M4SxArmHitDone
        move.b #$83,16(a3)
        move.w #$b913,d0
        bsr M4SxSetHdr
M4SxArmHitMark:
        bset #SXF_S5,X_WFLAGS(a3)
M4SxArmHitDone:
        movem.l (sp)+,d0-d2/a3
        rts
; Grabber collstrat 09:A7F0: within 45 degrees of facing in yaw ((roty +
; $AD) < $5A) and pitch ((rotx + $2D) < $5A) and hit by a laser (collider
; collflags & 8) -> 09:A813. It ends in rtl: no strategy this tick, collide
; kept (cleared by the next collision pass).
M4SxGrabColl:
        move.b 13(a0),d0
        addi.b #$ad,d0
        cmpi.b #$5a,d0
        bhs.s M4SxGrabDone
        move.b 12(a0),d0
        addi.b #$2d,d0
        cmpi.b #$5a,d0
        bhs.s M4SxGrabDone
        move.w 62(a0),d0
        beq.s M4SxGrabDone
        movea.w d0,a3
        btst #3,44(a3)
        beq.s M4SxGrabDone
        bsr M4SxArmHitUp
M4SxGrabDone:
        moveq #0,d0
        rts
; 09:A86F: from the head along al_ptr, each pair (parent a0, child a3) by
; 09:A96F.
M4SxArmChain:
        movem.l d0-d7/a0/a3,-(sp)
M4SxArmChainNext:
        move.w X_ALPTR(a0),d0
        beq.s M4SxArmChainDone
        movea.w d0,a3
        bsr M4SxArmLink
        movea.l a3,a0
        bra.s M4SxArmChainNext
M4SxArmChainDone:
        movem.l (sp)+,d0-d7/a0/a3
        rts
; 09:A96F (a0 parent, a3 child): parent AF25 -> only placed. Else for rotx/
; roty/rotz with the child's sbyte1/2/3: d = asr1(p - c) toward zero, c = c
; - d - 1 (clc; sbc), still different -> sbyte += d; then c += sbyte, sbyte =
; asr1(sbyte) toward zero; placed at the parent + 4 * rot(0, 0, $27).
M4SxArmLink:
        exg a0,a3
        bsr M4SxHeader ;header of the parent
        exg a0,a3
        cmpi.w #$af25,d0
        beq.s M4SxArmLinkPlace
        moveq #12,d4 ;rotx / sbyte1
        moveq #36,d5
        bsr.s M4SxArmLag
        moveq #13,d4 ;roty / sbyte2
        moveq #37,d5
        bsr.s M4SxArmLag
        moveq #14,d4 ;rotz / sbyte3
        move.w #X_SBYTE3,d5
        bsr.s M4SxArmLag
        move.b 36(a3),d0
        add.b d0,12(a3)
        move.b 37(a3),d0
        add.b d0,13(a3)
        move.b X_SBYTE3(a3),d0
        add.b d0,14(a3)
        lea 36(a3),a2
        bsr.s M4SxArmHalf
        lea 37(a3),a2
        bsr.s M4SxArmHalf
        lea X_SBYTE3(a3),a2
        bsr.s M4SxArmHalf
M4SxArmLinkPlace:
        moveq #0,d3
        moveq #0,d4
        moveq #$27,d5
        bra M4SxPlace
M4SxArmLag:
        move.b (a0,d4.w),d0
        sub.b (a3,d4.w),d0
        bpl.s M4SxArmLagP
        addq.b #1,d0
M4SxArmLagP:
        asr.b #1,d0 ;d
        move.b (a3,d4.w),d1
        sub.b d0,d1
        subq.b #1,d1
        move.b d1,(a3,d4.w)
        cmp.b (a0,d4.w),d1
        beq.s M4SxArmLagDone
        add.b d0,(a3,d5.w)
M4SxArmLagDone:
        rts
M4SxArmHalf:
        move.b (a2),d0
        bpl.s M4SxArmHalfP
        addq.b #1,d0
M4SxArmHalfP:
        asr.b #1,d0
        move.b d0,(a2)
        rts
; 09:A87E (a0 = end of a chain, d7 = its header): make_obj B8F7; sword1 1 ->
; tail flag: AF25 (ssprite, depthoffset 0, tx 0, animframe $80); armmode 0:
; grabber B94B. Then Istrat arm, child sword1 = sword1 - 1, own sword1 - 1 if
; >= 3, child rotations = own, tail flag and sflag1, al_ptr = child, placed at
; + 4 * rot(0, 0, $27).
M4SxArmAdd:
        move.w #$b8f7,d0
        jsr M4ArCreateHdr
        beq M4SxArmDone
        movea.l a2,a3
        cmpi.b #1,41(a0)
        bne.s M4SxArmAddNeck
        btst #SXF_TAIL,X_WFLAGS(a0)
        beq.s M4SxArmAddGrab
        move.w #$af25,d0
        bsr M4SxSetHdr
        bset #F2_SPRITE,48(a3)
        clr.b X_DEPTHOFF(a3)
        clr.b X_TX(a3)
        move.b #$80,16(a3)
        bra.s M4SxArmAddNeck
M4SxArmAddGrab:
        move.w #$b94b,d0
        tst.b M4_SX_ARMMODE ;09:A8C4: armmode != 0 (Fortuna): a neck ends
        beq.s M4SxArmAddSet ;in a head B983, the tail in B9BB; armmode + 2
        move.w #$b9bb,d0
        cmpi.w #$b967,d7
        bne.s M4SxArmAddEnd
        move.w #$b983,d0
M4SxArmAddEnd:
        addq.b #2,M4_SX_ARMMODE
M4SxArmAddSet:
        bsr M4SxSetHdr
        bra.s M4SxArmAddLink
M4SxArmAddNeck: ;09:A912: a neck B967 grows necks
        cmpi.w #$b967,d7
        bne.s M4SxArmAddLink
        move.w d7,d0
        bsr M4SxSetHdr
M4SxArmAddLink:
        move.l #M4SxArm,32(a3)
        move.b 41(a0),d0
        subq.b #1,d0
        move.b d0,41(a3)
        move.b 41(a0),d0
        subq.b #3,d0
        bmi.s M4SxArmAddRot
        subq.b #1,41(a0)
M4SxArmAddRot:
        bsr M4SxCopyRots
        btst #SXF_TAIL,X_WFLAGS(a0)
        beq.s M4SxArmAddFl
        bset #SXF_TAIL,X_WFLAGS(a3)
M4SxArmAddFl:
        bset #F2_SFLAG1,48(a3)
        move.w a3,X_ALPTR(a0)
        moveq #0,d3
        moveq #0,d4
        moveq #$27,d5
        bsr M4SxPlace
        moveq #0,d0
        rts

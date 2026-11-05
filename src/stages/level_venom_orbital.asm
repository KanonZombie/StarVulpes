; Venom 1 unit (orbital): code. Included from level_venom.asm. Documentation:
; build/agent-venom/orbital/ORBITAL.md (Spanish). Field conventions: level_objects.asm.
; Strategies of the orbital script 05:E1F1.. (map 0D:D602) and their closure.
; Authority: ref/Star Fox (USA).sfc (rev0); every routine re-read in the ROM
; bytes (build/agent-venom/orbital/dis/). Conventions: a0 object, a1 player,
; d0 = 0 keep / nonzero deferred removal (1F:D501). "d < K" of the original
; is the N bit of the 16-bit subtraction (sub + bmi/bpl here). Sounds and
; snd2 ($1CE9) are not ported. stratstate $1CDC = X_STATE; nextstate 1F:DB66
; = state + 1 and the strategy again from the top in the same tick.
M4_VO equ $ff9f80 ;unit RAM $FF9F80..$FF9F9F
M4_VO_WROTX equ M4_VO+0 ;.b $154E weapon rotx add (global, kept between fires)
M4_VO_WROTY equ M4_VO+1 ;.b $154D weapon roty add
M4_VO_WTGT equ M4_VO+2 ;.l $154F weapon target (object) or 0
; Shapes (effect descriptors of tools/stages/venom_orbital.py; change here
; to drawn M4_SH_* shapes). Map-created objects find them by ROM header.
M4VoShWarp equ M4_FX_VO_WARP ;DEB8
M4VoShWarp1 equ M4_FX_VO_WARP_1 ;DED4
M4VoShWarp2 equ M4_FX_VO_WARP_2 ;DEF0
M4VoShWarp3 equ M4_FX_VO_WARP_3 ;DF0C

; ---------------------------------------------------------------------
; Helpers.
; M4EnFire (d0 type, d3-d5 offset BYTEs, d6 rotx add, d7 roty add, a3
; target) that also leaves d6/d7/a3 in the fire_weapon globals $154E/$154D/
; $154F (the ROM never clears them: a later fire without its own setup
; reuses them). Returns a2 (0 on failure).
M4VoFire:
        move.b d6,M4_VO_WROTX
        move.b d7,M4_VO_WROTY
        move.l a3,M4_VO_WTGT
        jmp M4EnFire
; Fire with the current globals (no weapon_rot/target setup in the ROM).
M4VoFireStale:
        move.b M4_VO_WROTX,d6
        move.b M4_VO_WROTY,d7
        movea.l M4_VO_WTGT,a3
        jmp M4EnFire

; Common tail: v = gen_3dvecs(vel, roty, rotx) (1F:D5A7), pos += v
; (1F:C7BB), z += pviewvelz (1F:DC69).
M4VoMovePZ:
        jsr M4EnGen3d
        jsr M4EnMove
        jsr M4EnAddPZ
        moveq #0,d0
        rts

; ---------------------------------------------------------------------
; Generator 04:F60D (mother2): as 04:F5B3 (M4StratMother, level_space.asm)
; but the script interpreter 03:FB40 runs with $121F = the player ($123A)
; instead of the generator: children are linked right after the player (the
; list head), so they run their Istrat on the next traversal. Script 05:570D:
; motherrnd (1500, rx 4: x + (rnd & 3) - 2) uperM, goto 570D. (mothercnt
; would count from the player; not used by 570D, M4MotherCnt counts from the
; generator.)
M4VoMother2:
        move.w 4(a0),d0
        sub.w 4(a1),d0
        move.w d0,X_SWORD2(a0)
        move.l #M4VoMother2Tick,32(a0)
M4VoMother2Tick:
        move.w 4(a1),d0
        add.w X_SWORD2(a0),d0
        move.w d0,4(a0)
        move.l M4_LV_CREATOR,-(sp)
        clr.l M4_LV_CREATOR ;M4LevelAlloc: right after the head (player)
        jsr M4MotherRun
        move.l (sp)+,M4_LV_CREATOR
        rts ;d0 from the interpreter: 1 = removed by `end`

; ---------------------------------------------------------------------
; uperM 0A:C24B (uper_m DE9C): hitflash / explodegate2 06:FA53, collflags
; enemy1|enemyweap, HP 2 AP 8, roty $80, rotx $C0, vel 70, sword1 =
; player_posy ($1511). Tick 0A:C2A1: if N(y - (sword1 + 756)): rotx
; Achase8_3 -> 0 and, when 400 <= |pz - z| < 1300 (N bits): speedto(80, 2),
; rotz + 10, roty Achase8_1 -> yaw to the player. Always rotz + 8, move, PZ.
M4VoUperM:
        move.l #M4VoUperMTick,32(a0)
        move.l #M4LcHitFlash,X_COLL(a0)
        move.l #M4WpGate2Exp,X_EXP(a0)
        ori.b #$50,44(a0)
        move.b #2,38(a0)
        move.b #8,39(a0)
        move.b #$80,13(a0)
        move.b #$c0,12(a0)
        move.b #70,15(a0)
        move.w M4_SC_PPOSY,40(a0)
M4VoUperMTick:
        move.w 40(a0),d0
        addi.w #756,d0
        move.w 2(a0),d1
        sub.w d0,d1
        bpl.s M4VoUpSpin
        move.b 12(a0),d0
        moveq #0,d1
        moveq #3,d2
        jsr M4EnChase8
        move.b d0,12(a0)
        movea.l a1,a2
        jsr M4EnZD
        move.w d0,d1
        subi.w #400,d1
        bmi.s M4VoUpSpin
        subi.w #1300,d0
        bpl.s M4VoUpSpin
        moveq #80,d0
        moveq #2,d1
        jsr M4EnSpeedTo
        addi.b #10,14(a0)
        jsr M4EnYawTo
        move.b d0,d1
        move.b 13(a0),d0
        moveq #1,d2
        jsr M4EnChase8
        move.b d0,13(a0)
M4VoUpSpin:
        addq.b #8,14(a0)
        bra M4VoMovePZ

; ---------------------------------------------------------------------
; warp 0A:C359 (warp DEB8): normal pointers, collflags $50, HP 4 AP 8, rotx
; $40, sbyte1 = (rnd & 7) * 4 (index of 0A:C677), sbyte2 1, sbyte3 0 (shape
; index of 0A:C66F), sbyte4 4 (rounds). Tick 0A:C39C, states:
; 0 rotz + 12; x, y Achase16_2 -> table (both equal: nextstate), else z
;   Achase16_2 -> sword1 + player_posz + 1500;
; 1 rotz Achase8_2 -> 0, sbyte2 = 20; gameframe & 3 == 0: sbyte3 == 6 ->
;   nextstate (sound $2B), else sbyte3 + 2;
; 2 rotx, rotz Achase8_2 -> 0, collision on; sbyte2 == 0 -> nextstate, else
;   sbyte2 - 1 and on (gameframe + al1pt) & 7 == 0 a laser from (0,0,-20):
;   rnd >= $B2 RelSlowElaserHome $0A with the previous weapon globals, else
;   RelSlowElaser $0C at the player with rotx/roty adds (rnd & 7) - 3;
; 3 rotx Achase8_2 -> $40, rotz + 12, colldisable; gameframe & 3 == 0:
;   sword1 = 2 * sext(rnd), sbyte3 - 2; 0 -> state 0, sbyte4 - 1 (0: state
;   4), sbyte1 + 4 (32 -> 0);
; 4 v = make_xyvec(rnd, 40) (1F:DAB8), vz = -30, state 5; 5 pos += v.
; Then shape = 0A:C66F[sbyte3] and z += pviewvelz.
M4VoWarp:
        move.l #M4VoWarpTick,32(a0)
        jsr M4LvNormPtrs
        ori.b #$50,44(a0)
        move.b #4,38(a0)
        move.b #8,39(a0)
        move.b #$40,12(a0)
        jsr M4IntroRandom
        andi.b #7,d0
        add.b d0,d0
        add.b d0,d0
        move.b d0,36(a0)
        move.b #1,37(a0)
        clr.b X_SBYTE3(a0)
        move.b #4,X_SBYTE4(a0)
M4VoWarpTick:
        tst.b X_STATE(a0)
        bne M4VoWarpS1
        addi.b #12,14(a0)
        lea M4VoWarpPos,a2
        moveq #0,d0
        move.b 36(a0),d0
        adda.w d0,a2
        moveq #0,d5 ;$153A: coordinates already on target
        move.w (a0),d0
        move.w (a2),d1
        cmp.w d0,d1
        bne.s M4VoWarpX
        addq.b #1,d5
        bra.s M4VoWarpY
M4VoWarpX:
        moveq #2,d2
        jsr M4LpAchase
        move.w d0,(a0)
M4VoWarpY:
        move.w 2(a0),d0
        move.w 2(a2),d1
        cmp.w d0,d1
        bne.s M4VoWarpY2
        addq.b #1,d5
        bra.s M4VoWarpArrived
M4VoWarpY2:
        moveq #2,d2
        jsr M4LpAchase
        move.w d0,2(a0)
M4VoWarpArrived:
        cmpi.b #2,d5
        bne.s M4VoWarpZ
        addq.b #1,X_STATE(a0)
        bra M4VoWarpTick
M4VoWarpZ:
        move.w 40(a0),d1
        add.w M4_LP_POSZ,d1
        addi.w #1500,d1
        move.w 4(a0),d0
        moveq #2,d2
        jsr M4LpAchase
        move.w d0,4(a0)
M4VoWarpS1:
        cmpi.b #1,X_STATE(a0)
        bne.s M4VoWarpS2
        move.b 14(a0),d0
        moveq #0,d1
        moveq #2,d2
        jsr M4EnChase8
        move.b d0,14(a0)
        move.b #20,37(a0)
        moveq #3,d0
        and.w M4_LV_GAMEFRAME,d0
        bne.s M4VoWarpS2
        cmpi.b #6,X_SBYTE3(a0)
        bne.s M4VoWarpOpen
        addq.b #1,X_STATE(a0)
        bra M4VoWarpTick
M4VoWarpOpen:
        addq.b #2,X_SBYTE3(a0)
M4VoWarpS2:
        cmpi.b #2,X_STATE(a0)
        bne M4VoWarpS3
        move.b 12(a0),d0
        moveq #0,d1
        moveq #2,d2
        jsr M4EnChase8
        move.b d0,12(a0)
        move.b 14(a0),d0
        moveq #0,d1
        jsr M4EnChase8
        move.b d0,14(a0)
        bclr #SF_COLLDISABLE,49(a0)
        tst.b 37(a0)
        bne.s M4VoWarpFireWait
        addq.b #1,X_STATE(a0)
        bra M4VoWarpTick
M4VoWarpFireWait:
        subq.b #1,37(a0)
        jsr M4ArPhase ;d0.b = gameframe + lo8(al1pt)
        andi.b #7,d0
        bne M4VoWarpS3
        moveq #0,d3
        moveq #0,d4
        moveq #-20,d5
        jsr M4IntroRandom
        cmpi.b #$b2,d0
        blo.s M4VoWarpAim
        moveq #M4_WT_RSEH,d0
        jsr M4VoFireStale
        bra.s M4VoWarpS3
M4VoWarpAim:
        jsr M4IntroRandom
        andi.b #7,d0
        subq.b #3,d0
        move.b d0,d6
        jsr M4IntroRandom
        andi.b #7,d0
        subq.b #3,d0
        move.b d0,d7
        movea.l a1,a3
        moveq #M4_WT_RSE,d0
        jsr M4VoFire
M4VoWarpS3:
        cmpi.b #3,X_STATE(a0)
        bne.s M4VoWarpS4
        move.b 12(a0),d0
        moveq #$40,d1
        moveq #2,d2
        jsr M4EnChase8
        move.b d0,12(a0)
        addi.b #12,14(a0)
        bset #SF_COLLDISABLE,49(a0)
        moveq #3,d0
        and.w M4_LV_GAMEFRAME,d0
        bne.s M4VoWarpS4
        jsr M4IntroRandom
        ext.w d0
        add.w d0,d0
        move.w d0,40(a0)
        subq.b #2,X_SBYTE3(a0)
        bne.s M4VoWarpS4
        clr.b X_STATE(a0)
        subq.b #1,X_SBYTE4(a0)
        bne.s M4VoWarpNext
        move.b #4,X_STATE(a0)
M4VoWarpNext:
        addq.b #4,36(a0)
        cmpi.b #32,36(a0)
        bne.s M4VoWarpS4
        clr.b 36(a0)
M4VoWarpS4:
        cmpi.b #4,X_STATE(a0)
        bne.s M4VoWarpS5
        jsr M4IntroRandom
        move.b d0,d1
        moveq #40,d0
        moveq #$40,d2
        jsr M4EnVector ;make_xyvec 1F:DAB8
        move.w d3,6(a0)
        move.w d4,8(a0)
        move.w #-30,10(a0)
        move.b #5,X_STATE(a0)
M4VoWarpS5:
        cmpi.b #5,X_STATE(a0)
        bne.s M4VoWarpShape
        jsr M4EnMove
M4VoWarpShape:
        moveq #0,d0
        move.b X_SBYTE3(a0),d0
        lea M4VoWarpShapes,a2
        move.w 8(a2,d0.w),X_SHAPEHDR(a0)
        move.w (a2,d0.w),d0
        jsr M4LevelSetShape
        jsr M4EnAddPZ
        moveq #0,d0
        rts
; 0A:C66F (by sbyte3 0/2/4/6): warp_3, warp_2, warp_1, warp; headers after.
M4VoWarpShapes:
        dc.w M4VoShWarp3,M4VoShWarp2,M4VoShWarp1,M4VoShWarp
        include '../build/m4-orbital-warp-shapes.inc'
; 0A:C677 (by sbyte1): x, y (space_viewCY -60 included).
M4VoWarpPos:
        incbin '../build/M4VoWarpPos.bin'

; ---------------------------------------------------------------------
; misspod 08:E602 (big_m B4DA): normal pointers, HP 2 AP 16, v = (0,0,-10),
; roty $80, sbyte1 = rnd & 3 (formation; the map value is overwritten); the
; Istrat ends there. Tick 08:E641: distXZ to the player (1F:D0AB) >= 1000 ->
; pos += v, rotz + 5. Else (08:E666, sound $49) 08:E679: weapon rot/target 0,
; rotz saved and 0, five missile2 ($20) of the formation (sbyte1 3/0 X, 1 H,
; 2 V: absolute offsets and angles below), the last missile (if any) gets
; expstrat explodegate2 06:FA53, rotz restored, colldisable, HP 0 (explodes
; next tick through explode_Istrat).
M4VoMisspod:
        move.l #M4VoMisspodTick,32(a0)
        jsr M4LvNormPtrs
        move.b #2,38(a0)
        move.b #16,39(a0)
        clr.l 6(a0)
        move.w #-10,10(a0)
        move.b #$80,13(a0)
        jsr M4IntroRandom
        andi.b #3,d0
        move.b d0,36(a0)
        moveq #0,d0
        rts
M4VoMisspodTick:
        movea.l a1,a2
        jsr M4EnDistXZ
        subi.w #1000,d0
        bmi.s M4VoMpFire
        jsr M4EnMove
        addq.b #5,14(a0)
        moveq #0,d0
        rts
M4VoMpFire:
        move.l #M4VoMpFire,32(a0)
        clr.b M4_VO_WROTX
        clr.b M4_VO_WROTY
        clr.l M4_VO_WTGT
        lea M4VoMpX,a4
        move.b 36(a0),d0
        beq.s M4VoMpGo
        cmpi.b #3,d0
        beq.s M4VoMpGo
        lea M4VoMpH,a4
        cmpi.b #1,d0
        beq.s M4VoMpGo
        lea M4VoMpV,a4
M4VoMpGo:
        move.b 14(a0),-(sp)
        clr.b 14(a0)
        moveq #4,d1
        moveq #0,d2 ;last missile
        moveq #0,d6
        moveq #0,d7
        suba.l a3,a3
M4VoMpLoop:
        move.b (a4)+,d3
        move.b (a4)+,d4
        move.b (a4)+,d5
        move.b (a4)+,12(a0)
        move.b (a4)+,13(a0)
        ext.w d3
        ext.w d4
        ext.w d5
        moveq #M4_WT_MISSILE2,d0
        jsr M4EnFire ;keeps d0-d7/a0-a1/a3-a4
        move.l a2,d0
        beq.s M4VoMpNext
        move.l a2,d2
M4VoMpNext:
        dbra d1,M4VoMpLoop
        tst.l d2
        beq.s M4VoMpDone
        movea.l d2,a2
        move.l #M4WpGate2Exp,X_EXP(a2)
M4VoMpDone:
        move.b (sp)+,14(a0)
        bset #SF_COLLDISABLE,49(a0)
        clr.b 38(a0)
        moveq #0,d0
        rts
; x, y, z offsets ($1547/49/4B), rotx, roty per missile (08:E80D, E75A, E6A7).
        include '../build/m4-venom-missile-pods.inc'
        even

; ---------------------------------------------------------------------
; windmill 08:EBB2 (round_0 BDCC): hitflash / windexp 08:ECFC, HP 6 AP 4,
; vel 50 (the map sets vel/rotx/roty/sword1 with setalvar). Tick 08:EBEB:
; when 500 <= |pz - z| < 2000 (N bits) and gameframe even: roty +=
; lo8(sword1); z += pviewvelz; v = gen3d(vel, roty, rotx); pos += v; rotz
; + 4; weapon rot/target 0; SlowElaser $08 uses M4VoWindGuns when
; (gameframe + the gun's phase) & 15 == 0.
M4VoWindmill:
        move.l #M4VoWindTick,32(a0)
        move.l #M4LcHitFlash,X_COLL(a0)
        move.l #M4VoWindExp,X_EXP(a0)
        move.b #6,38(a0)
        move.b #4,39(a0)
        move.b #50,15(a0)
M4VoWindTick:
        movea.l a1,a2
        jsr M4EnZD
        move.w d0,d1
        subi.w #500,d1
        bmi.s M4VoWindNoRot
        subi.w #2000,d0
        bpl.s M4VoWindNoRot
        btst #0,M4_LV_GAMEFRAME+1
        bne.s M4VoWindNoRot
        move.b 41(a0),d0 ;lo8(sword1)
        add.b d0,13(a0)
M4VoWindNoRot:
        jsr M4EnAddPZ
        jsr M4EnGen3d
        jsr M4EnMove
        addq.b #4,14(a0)
        clr.b M4_VO_WROTX
        clr.b M4_VO_WROTY
        clr.l M4_VO_WTGT
        lea M4VoWindGuns,a4
        moveq #0,d1
M4VoWindGun:
        move.w M4_LV_GAMEFRAME,d0
        add.w d1,d0
        andi.w #15,d0
        bne.s M4VoWindGunNext
        move.b (a4),d3
        move.b 1(a4),d4
        move.b 2(a4),d5
        ext.w d3
        ext.w d4
        ext.w d5
        moveq #0,d6
        moveq #0,d7
        suba.l a3,a3
        moveq #M4_WT_SLOWELASER,d0
        movem.l d1/a4,-(sp)
        jsr M4EnFire
        movem.l (sp)+,d1/a4
M4VoWindGunNext:
        addq.l #3,a4
        addq.w #4,d1
        cmpi.w #16,d1
        bne.s M4VoWindGun
        moveq #0,d0
        rts
M4VoWindGuns:
        include '../build/m4-orbital-wind-guns.inc'
        even
; windexp 08:ECFC: four round0p E4BC (1F:D54B behind the windmill; a failed
; one is skipped) with its rotations and position + rot(offset) by rotz,
; rotx, roty (1F:CC78, CAFB, C97B; offsets and roll in M4VoWindPieces), strategy
; windspin 08:EFF6; then a nullshape particle helper 06:F7E6 at the
; windmill and escapee-explode 06:F18F.
M4VoWindExp:
        lea M4VoWindPieces,a4
        moveq #3,d1
M4VoWindPiece:
        move.w #$e4bc,d0
        jsr M4ArCreateHdr
        beq.s M4VoWindPieceNext
        movea.l a2,a3
        move.w 12(a0),12(a3)
        move.b 14(a0),14(a3)
        movem.l d1/a2-a4,-(sp)
        move.b (a4),d3
        move.b 1(a4),d4
        moveq #0,d5
        movea.l a0,a2
        jsr M4WeaponOffset ;4 * rot(offset): the ROM adds rot(offset)
        movem.l (sp)+,d1/a2-a4
        asr.w #2,d3
        asr.w #2,d4
        asr.w #2,d5
        add.w (a0),d3
        add.w 2(a0),d4
        add.w 4(a0),d5
        move.w d3,(a3)
        move.w d4,2(a3)
        move.w d5,4(a3)
        move.b 2(a4),d0
        add.b d0,14(a3)
        move.l #M4VoWindSpin,32(a3)
M4VoWindPieceNext:
        addq.l #3,a4
        dbra d1,M4VoWindPiece
        move.w #$ffff,d0
        jsr M4EnCreate
        beq.s M4VoWindExpDone
        move.l #M4StratParticles,32(a2)
        move.l (a0),(a2)
        move.w 4(a0),4(a2)
M4VoWindExpDone:
        bra M4VoEscExp
M4VoWindPieces: ;x, y offset BYTEs, rotz add
        include '../build/m4-orbital-wind-pieces.inc'
        even
; windspin 08:EFF6: colldisable, no collstrat, expstrat explode 06:F45F,
; v = make_xyvec(rotz, 30), count 40, sbyte1 = (rnd & 15) + 7, HP $FF AP 8.
; Tick 08:F050: rotz + sbyte1; count - 1 = 0 -> colldisable, HP 0; pos += v.
M4VoWindSpin:
        bset #SF_COLLDISABLE,49(a0)
        move.l #M4VoWindSpinTick,32(a0)
        clr.l X_COLL(a0)
        move.l #M4LevelExplode,X_EXP(a0)
        moveq #30,d0
        move.b 14(a0),d1
        moveq #$40,d2
        jsr M4EnVector
        move.w d3,6(a0)
        move.w d4,8(a0)
        clr.w 10(a0)
        move.b #40,19(a0)
        jsr M4IntroRandom
        andi.b #15,d0
        addq.b #7,d0
        move.b d0,36(a0)
        move.b #$ff,38(a0)
        move.b #8,39(a0)
M4VoWindSpinTick:
        move.b 36(a0),d0
        add.b d0,14(a0)
        subq.b #1,19(a0)
        bne.s M4VoWindSpinMove
        bset #SF_COLLDISABLE,49(a0)
        clr.b 38(a0)
M4VoWindSpinMove:
        jsr M4EnMove
        moveq #0,d0
        rts

; escapeeexplode 06:F18F (variant of 06:F181 with $CC): rnd >= $CC ->
; escapee B26D (strategy 06:F1D2) at the position and z + 40; then
; explode_Istrat 06:F45F.
M4VoEscExp:
        jsr M4IntroRandom
        cmpi.b #$cc,d0
        blo.s M4VoEscExpGo
        move.w #$b26d,d0
        jsr M4ArCreateHdr
        beq.s M4VoEscExpGo
        move.l #M4StratEscapee,32(a2)
        move.l (a0),(a2)
        move.w 4(a0),4(a2)
        addi.w #40,4(a0)
M4VoEscExpGo:
        jmp M4LevelExplode

; ---------------------------------------------------------------------
; bazookaL 0A:BF4D (sflags2 $10 = F2_SFLAG1) / bazookaR 0A:BF53 (bazooka
; DE48): debrisshape DE64, sword1 = DE80 (falling part), hitflash / bazexp
; 0A:C1C1, collflags enemy1, HP 8 AP 16, animframe $80, vy -15, rotx $C0,
; roty $80, vel 80. Tick 0A:BFBD: states 1, 2: y Achase16_2 -> player_posy;
; 0 while N(y - 440): speedto(0, 1), rotx Achase8_3 -> 0 (equal: nextstate);
; 1 speedto(0, 1), sbyte1 = $40; roty -= off (L -16, R +16), roty
;   Achase8_2 -> yaw to the player (equal: roty += off, nextstate), roty +=
;   off;
; 2 speedto(0, 2); sbyte1 == 0 -> nextstate; sbyte1 - 1, roty +2 (L) / -2
;   (R); animframe +1 mod 3; frame 1/2: RelSlowElaser $0C from (30,0,0) /
;   (-30,0,0), rotx add (rnd & 3) - 1, roty add rnd & 0 (one rnd), no target;
; 3 speedto(80, 4), roty Achase8_3 -> 0, rotx Achase8_3 -> $20.
; Then v = gen3d, pos += v, z += pviewvelz.
M4VoBazookaL:
        bset #F2_SFLAG1,48(a0)
M4VoBazookaR:
        move.w #$de64,X_DEBRIS(a0)
        move.w #$de80,40(a0)
        move.l #M4VoBazTick,32(a0)
        move.l #M4LcHitFlash,X_COLL(a0)
        move.l #M4VoBazExp,X_EXP(a0)
        ori.b #$10,44(a0)
        move.b #8,38(a0)
        move.b #16,39(a0)
        move.b #$80,16(a0)
        move.w #-15,8(a0)
        move.b #$c0,12(a0)
        move.b #$80,13(a0)
        move.b #80,15(a0)
M4VoBazTick:
        move.b X_STATE(a0),d0
        beq.s M4VoBazS0
        cmpi.b #3,d0
        beq.s M4VoBazS0
        move.w 2(a0),d0
        move.w M4_SC_PPOSY,d1
        moveq #2,d2
        jsr M4LpAchase
        move.w d0,2(a0)
M4VoBazS0:
        tst.b X_STATE(a0)
        bne.s M4VoBazS1
        move.w 2(a0),d0
        subi.w #440,d0
        bpl.s M4VoBazS1
        moveq #0,d0
        moveq #1,d1
        jsr M4EnSpeedTo
        move.b 12(a0),d0
        moveq #0,d1
        moveq #3,d2
        jsr M4EnChase8
        move.b d0,12(a0)
        tst.b d3
        beq.s M4VoBazS1
        addq.b #1,X_STATE(a0)
        bra M4VoBazTick
M4VoBazS1:
        cmpi.b #1,X_STATE(a0)
        bne.s M4VoBazS2
        moveq #0,d0
        moveq #1,d1
        jsr M4EnSpeedTo
        move.b #$40,36(a0)
        moveq #-16,d4 ;$152E
        btst #F2_SFLAG1,48(a0)
        bne.s M4VoBazOff
        moveq #16,d4
M4VoBazOff:
        sub.b d4,13(a0)
        movea.l a1,a2
        jsr M4EnYawTo
        cmp.b 13(a0),d0
        bne.s M4VoBazAim
        add.b d4,13(a0)
        addq.b #1,X_STATE(a0)
        bra M4VoBazTick
M4VoBazAim:
        move.b d0,d1
        move.b 13(a0),d0
        moveq #2,d2
        jsr M4EnChase8
        add.b d4,d0
        move.b d0,13(a0)
M4VoBazS2:
        cmpi.b #2,X_STATE(a0)
        bne M4VoBazS3
        moveq #0,d0
        moveq #2,d1
        jsr M4EnSpeedTo
        tst.b 36(a0)
        bne.s M4VoBazTurn
        addq.b #1,X_STATE(a0)
        bra M4VoBazTick
M4VoBazTurn:
        subq.b #1,36(a0)
        btst #F2_SFLAG1,48(a0)
        bne.s M4VoBazTurnL
        subq.b #2,13(a0)
        bra.s M4VoBazAnim
M4VoBazTurnL:
        addq.b #2,13(a0)
M4VoBazAnim:
        move.b 16(a0),d0
        moveq #3,d1
        jsr M4MtAfInc
        move.b d0,16(a0)
        andi.b #$7f,d0
        beq.s M4VoBazS3
        moveq #30,d3
        cmpi.b #2,d0
        bne.s M4VoBazGun
        moveq #-30,d3
M4VoBazGun:
        moveq #0,d4
        moveq #0,d5
        jsr M4IntroRandom
        andi.b #3,d0
        subq.b #1,d0
        move.b d0,d6
        jsr M4IntroRandom ;and #0: roty add 0
        moveq #0,d7
        suba.l a3,a3
        moveq #M4_WT_RSE,d0
        jsr M4VoFire
M4VoBazS3:
        cmpi.b #3,X_STATE(a0)
        bne.s M4VoBazMove
        moveq #80,d0
        moveq #4,d1
        jsr M4EnSpeedTo
        move.b 13(a0),d0
        moveq #0,d1
        moveq #3,d2
        jsr M4EnChase8
        move.b d0,13(a0)
        move.b 12(a0),d0
        moveq #$20,d1
        jsr M4EnChase8
        move.b d0,12(a0)
M4VoBazMove:
        bra M4VoMovePZ
; bazexp 0A:C1C1: the part sword1 (DE80) at the bazooka's position and
; rotations with strategy bazfall 0A:C1F9 (skipped when the pool is full);
; then escapee-explode 06:F18F (explode_Istrat leaves the DE64 debris).
M4VoBazExp:
        move.w 40(a0),d0
        jsr M4ArCreateHdr
        beq.s M4VoBazExpGo
        move.l (a0),(a2)
        move.w 4(a0),4(a2)
        move.w 12(a0),12(a2)
        move.b 14(a0),14(a2)
        move.l #M4VoBazFall,32(a2)
M4VoBazExpGo:
        bra M4VoEscExp
; bazfall 0A:C1F9: count 30, colldisable. Tick 0A:C210: roty + 16, vy + 2,
; smoke (06:8EA8) on even (gameframe + al1pt), pos += v, z += pviewvelz,
; count - 1 = 0 -> removed (1F:D501).
M4VoBazFall:
        move.b #30,19(a0)
        move.l #M4VoBazFallTick,32(a0)
        bset #SF_COLLDISABLE,49(a0)
M4VoBazFallTick:
        addi.b #16,13(a0)
        addq.w #2,8(a0)
        jsr M4ArPhase
        btst #0,d0
        bne.s M4VoBazFallMove
        jsr M4FxSmoke
M4VoBazFallMove:
        jsr M4EnMove
        jsr M4EnAddPZ
        moveq #0,d0
        subq.b #1,19(a0)
        bne.s M4VoBazFallKeep
        moveq #1,d0
M4VoBazFallKeep:
        rts

; ---------------------------------------------------------------------
; mine 09:9660 (B80D, eight nobj of 05:E412..E474 around skillfly): strategy
; 09:9685 (rtl: does nothing, not even addplayerZ), normal pointers, HP 2
; AP 10, collflags enemy1, rotz = rnd.
M4VoMine:
        move.l #M4VoMineTick,32(a0)
        jsr M4LvNormPtrs
        move.b #2,38(a0)
        move.b #10,39(a0)
        ori.b #$10,44(a0)
        jsr M4IntroRandom
        move.b d0,14(a0)
M4VoMineTick:
        moveq #0,d0
        rts

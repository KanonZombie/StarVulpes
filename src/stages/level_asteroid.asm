; Asteroid Belt 1 (map 0D:D268, 0D:90AD, 05:D885) object strategies, except
; boss1 and the Warp ending. Specification: build/research/stage-asteroid1.md
; section 3 (USA rev0); every routine below was re-read in the ROM bytes
; (tools/dis65816.py) and is checked tick by tick against the ROM by
; tools/asteroid-strats-oracle.py (build/agent-asteroid/ASTEROID_STRATS.md).
; Conventions of level_objects.asm / level_enemies.asm: a0 object, a1
; player; d0 = 0 keep / nonzero deferred removal (1F:D501, x == al1pt).
; Comparisons "d < K" are the N bit of the 16-bit (or 8-bit) difference.
; (gameframe + al1pt) uses the port object address (as M4EnBankToPlayer).
; Sounds (03:B7E5) and music ($1F49) are not ported.
M4_AST equ $fff8e0
M4_AST_1544 equ M4_AST+0 ;.w $1544 szaco0 way point z base (global, as in the ROM)
M4_AST_WORM equ M4_AST+2 ;.b $14F3 worm: bit0 head dead, bit1 a segment dead
; X_DEBRIS (-$8000+56, debrisshape $1CE4, ROM header) is defined in level_paths.asm.
X_B21 equ -$8000+58 ;.b alien byte $21 (szaco0 delayed heading)
X_RADIUS equ -$8000+59 ;.b alx $1CE2 (space pylon petal radius)

; ---------------------------------------------------------------------
; big_meteor 00:FA62: stratptr 00:FAA4 (rtl), set_normcollptrs, nohitaffect,
; HP $FF, AP 12, faces the camera once, sbyte1 = (rnd & 15) - 8 (unused).
; Shape AFCD: textured quad t53 (SVP texpoly).
M4StratBigMeteor:
        move.l #M4EnKeep,32(a0)
        jsr M4LvNormPtrs
        bset #SF_NOHITAFFECT,49(a0)
        move.b #$ff,38(a0)
        move.b #12,39(a0)
        jsr M4EnFaceCamera
        jsr M4IntroRandom
        andi.b #15,d0
        subq.b #8,d0
        move.b d0,36(a0)
        moveq #0,d0
        rts

; break_meteor 00:FAA5 / break_meteort 00:FABA: path PC ($28) 4594 / 4590,
; HP 2, AP 12, path_istrat 04:8022 (ops particle/setstrat/setw coltab of
; those paths: level_paths.asm).
M4StratBreakMeteor:
        move.w #$4594,42(a0)
        bra.s M4BreakMeteor
M4StratBreakMeteorT:
        move.w #$4590,42(a0)
M4BreakMeteor:
        move.b #2,38(a0)
        move.b #12,39(a0)
        jmp M4PathIstrat

; ---------------------------------------------------------------------
; shou0a 0A:D5F1 (sflags2 $10: cadence 32) / shou0 0A:D5F7: turrets r_hou_0
; / s_hou_0. sbyte1 = rnd & 3, drawn again while 3. D628: 500 <= |pz - z| <
; 2500 -> spin by sbyte1 and every 16 (32) ticks relbeamball $22 at the player.
M4StratShou0a:
        bset #F2_SFLAG1,48(a0)
M4StratShou0:
        move.l #M4Shou0Tick,32(a0)
        jsr M4LvNormPtrs
        move.b #2,38(a0)
        move.b #12,39(a0)
        ori.b #$10,44(a0)
M4Shou0Rnd:
        jsr M4IntroRandom
        andi.b #3,d0
        move.b d0,36(a0)
        cmpi.b #3,d0
        beq.s M4Shou0Rnd
M4Shou0Tick:
        movea.l a1,a2
        jsr M4EnZD
        subi.w #500,d0
        bmi.s M4Shou0Done
        subi.w #2000,d0
        bpl.s M4Shou0Done
        move.b 36(a0),d0
        bne.s M4Shou0Spin1
        addq.b #6,13(a0)
        addq.b #6,12(a0)
        bra.s M4Shou0Fire
M4Shou0Spin1:
        cmpi.b #1,d0
        bne.s M4Shou0Spin2
        addq.b #6,13(a0)
        addq.b #6,14(a0)
        bra.s M4Shou0Fire
M4Shou0Spin2:
        addq.b #6,12(a0)
        addq.b #6,14(a0)
M4Shou0Fire:
        moveq #15,d1
        btst #F2_SFLAG1,48(a0)
        beq.s M4Shou0Mask
        moveq #31,d1
M4Shou0Mask: ;0A:D699: (gameframe + lo8(al1pt)) & 15 / 31
        jsr M4ArPhase ;d0.b (level_armada.asm: al1pt of the ROM record of this slot)
        and.w d1,d0
        bne.s M4Shou0Done
        moveq #4,d0 ;weapon $22 = 06:A9BE relbeamball
        movea.l a1,a3
        bsr M4AstFireZero
M4Shou0Done:
        moveq #0,d0
        rts

; Weapon d0 from (0,0,0), no angle offsets, target a3 (or 0).
M4AstFireZero:
        moveq #0,d3
        moveq #0,d4
        moveq #0,d5
        moveq #0,d6
        moveq #0,d7
        jmp M4EnFire

; ---------------------------------------------------------------------
; szaco0 0A:A4EF (zaco_4): HP 4, AP 8, debris D940, variant k = rnd & 3,
; relexplode, sword1 340. Four copies of the code (A545/A7B8/AA2B/AC9E)
; differ only in the way point table T_k (0A:A44F + 40k: 5 x (x, y, z,
; flags)). Way points: x, y absolute, z + $1544 (player_posz unless flags
; bit1). Expstrat 06:F181.
M4StratSzaco0:
        move.l #M4Szaco0Tick,32(a0)
        move.l #M4LcHitFlash,X_COLL(a0)
        move.l #M4Szaco0Exp,X_EXP(a0)
        move.b #4,38(a0)
        move.b #8,39(a0)
        move.w #$d940,X_DEBRIS(a0)
        jsr M4IntroRandom
        andi.b #3,d0
        move.b d0,36(a0)
        bset #F2_RELEXPLODE,48(a0)
        move.w #340,40(a0)
M4Szaco0Tick:
        moveq #0,d0
        move.b X_STATE(a0),d0
        cmpi.b #5,d0
        bne.s M4Sz0Entry
        jsr M4EnMove
        bra M4Sz0Final
M4Sz0Entry:
        moveq #0,d1
        move.b 36(a0),d1
        cmpi.b #3,d1 ;the four blocks test sbyte1 = 0..3
        bhi M4Sz0Final
        mulu.w #40,d1
        lea M4Szaco0Tables,a2
        adda.w d1,a2
        lsl.w #3,d0
        adda.w d0,a2
        move.w 6(a2),d2 ;flags
        btst #2,d2
        beq.s M4Sz0NoByte
        move.b 1(a2),37(a0) ;sbyte2 = lo8(e.x) (no table uses it)
        bra M4Sz0Next
M4Sz0NoByte:
        btst #0,d2
        beq.s M4Sz0NoFire
        jsr M4ArPhase ;original 54-byte slot phase
        andi.w #3,d0
        bne.s M4Sz0NoFire
        movem.l d2/a2,-(sp)
        jsr M4IntroRandom
        andi.b #7,d0
        subq.b #3,d0
        move.b d0,d6 ;$154E rotx offset
        jsr M4IntroRandom
        andi.b #7,d0
        subq.b #3,d0
        move.b d0,d7 ;$154D roty offset
        moveq #1,d0 ;$0C RelSlowElaser at the player
        moveq #0,d3
        moveq #0,d4
        moveq #0,d5
        movea.l a1,a3
        jsr M4EnFire
        movem.l (sp)+,d2/a2
M4Sz0NoFire:
        btst #1,d2
        bne.s M4Sz0KeepZ
        move.w M4_LP_POSZ,M4_AST_1544
M4Sz0KeepZ:
        move.w (a2),X_WPX(a0)
        move.w 2(a2),X_WPY(a0)
        move.w 4(a2),d0
        add.w M4_AST_1544,d0
        move.w d0,X_WPZ(a0)
        jsr M4EnMove
        ; ManhattanXZ 1F:CF92 < 300 (N) and |y - WPy| < 300 (unsigned)
        move.w X_WPX(a0),d0
        sub.w (a0),d0
        bpl.s M4Sz0Dx
        neg.w d0
M4Sz0Dx:
        move.w X_WPZ(a0),d1
        sub.w 4(a0),d1
        bmi.s M4Sz0DzNeg
        add.w d1,d0
        bra.s M4Sz0Dxz
M4Sz0DzNeg:
        sub.w d1,d0
M4Sz0Dxz:
        subi.w #300,d0
        bpl.s M4Sz0Far
        move.w 2(a0),d0
        sub.w X_WPY(a0),d0
        bpl.s M4Sz0Dy
        neg.w d0
M4Sz0Dy:
        cmpi.w #300,d0
        bhs.s M4Sz0Far
        cmpi.b #40,15(a0) ;speedto C = 1 (already 40): next way point
        beq.s M4Sz0Next
        moveq #40,d0
        moveq #2,d1
        jsr M4EnSpeedTo
        bra.s M4Sz0Steer
M4Sz0Far:
        moveq #40,d0
        moveq #1,d1
        jsr M4EnSpeedTo
M4Sz0Steer:
        jsr M4EnWayAngles ;d0 yaw, d1 pitch toward sWP
        move.w d1,-(sp)
        move.b d0,d1
        move.b 13(a0),d0
        moveq #2,d2
        jsr M4EnChase8
        move.b d0,13(a0)
        move.w (sp)+,d1
        move.b 12(a0),d0
        jsr M4EnChase8
        move.b d0,12(a0)
        move.b 13(a0),d1 ;b21 = Achase8_3(b21, roty) 1F:D8BD
        move.b X_B21(a0),d0
        moveq #3,d2
        jsr M4EnChase8
        move.b d0,X_B21(a0)
        move.b d0,d2
        move.b 12(a0),d1
        move.b 15(a0),d0
        ext.w d0
        jsr M4EnVector ;v = gen3d(vel, rotx, b21)
        movem.w d3-d5,6(a0)
        bra.s M4Sz0Final
M4Sz0Next: ;0A:A7A9: state + 1, 1 after 5
        move.b X_STATE(a0),d0
        addq.b #1,d0
        cmpi.b #5,d0
        ble.s M4Sz0Store
        moveq #1,d0
M4Sz0Store:
        move.b d0,X_STATE(a0)
M4Sz0Final: ;0A:AF11: follows the player while sword1 counts down
        tst.w 40(a0)
        beq.s M4Sz0Done
        subq.w #1,40(a0)
        jsr M4EnAddPZ
M4Sz0Done:
        moveq #0,d0
        rts
; 0A:A44F/A477/A49F/A4C7 (x, y, z, flags), checked against the ROM bytes.
M4Szaco0Tables:
        incbin '../build/M4Szaco0Tables.bin'

; expstrat 06:F181: rnd >= $E5 -> escapee B26D (strategy 06:F1D2) at the
; position and the szaco0 40 further; then explode_Istrat.
M4Szaco0Exp:
        jsr M4IntroRandom
        cmpi.b #$e5,d0
        blo.s M4Sz0ExpGo
        move.l #M4_SH_ESCAPEE,d0 ;descriptor index may exceed 127
        jsr M4EnCreate
        beq.s M4Sz0ExpGo
        move.l #M4StratEscapee,32(a2)
        move.l (a0),(a2)
        move.w 4(a0),4(a2)
        addi.w #40,4(a0)
M4Sz0ExpGo:
        jmp M4LevelExplode
; 06:F1D2: rotz += 8 (no HP, no movement).
M4StratEscapee:
        addq.b #8,14(a0)
        moveq #0,d0
        rts

; ---------------------------------------------------------------------
; szaco2 0A:A197 (zaco_8): HP 2, AP 8, vel 40, sWPy1 += 150 + player_posy
; (the map set sWPx1/sWPy1, rotx, roty), debris C344, animframe $83,
; relexplode, collflags $40. States fall through in the same tick.
M4StratSzaco2:
        move.b #2,38(a0)
        move.b #8,39(a0)
        move.l #M4Szaco2Tick,32(a0)
        jsr M4LvNormPtrs
        move.b #40,15(a0)
        move.w X_WPY(a0),d0
        addi.w #150,d0
        add.w M4_SC_PPOSY,d0
        move.w d0,X_WPY(a0)
        move.w #$c344,X_DEBRIS(a0)
        move.b #$83,16(a0)
        bset #F2_RELEXPLODE,48(a0)
        ori.b #$40,44(a0)
M4Szaco2Tick:
        tst.b X_STATE(a0)
        bne.s M4Sz2St1
        ; 0: sWPz1 = z - 10; turn (Achase8_3) toward sWP; level when y < sWPy1
        move.w 4(a0),d0
        subi.w #10,d0
        move.w d0,X_WPZ(a0)
        jsr M4EnWayAngles
        move.w d1,-(sp)
        move.b d0,d1
        move.b 13(a0),d0
        moveq #3,d2
        jsr M4EnChase8
        move.b d0,13(a0)
        move.w (sp)+,d1
        move.b 12(a0),d0
        jsr M4EnChase8
        move.b d0,12(a0)
        move.w 2(a0),d0
        sub.w X_WPY(a0),d0
        bpl.s M4Sz2St1
        bsr M4Sz2Next
M4Sz2St1: ;1: rotx -> 0, roty -> $80 (Achase8_2); both already there -> 2
        cmpi.b #1,X_STATE(a0)
        bne.s M4Sz2St2
        moveq #0,d6
        moveq #2,d2
        move.b 12(a0),d0
        bne.s M4Sz2ChaseX
        addq.w #1,d6
        bra.s M4Sz2Yaw
M4Sz2ChaseX:
        moveq #0,d1
        jsr M4EnChase8
        move.b d0,12(a0)
M4Sz2Yaw:
        move.b 13(a0),d0
        cmpi.b #$80,d0
        bne.s M4Sz2ChaseY
        addq.w #1,d6
        bra.s M4Sz2Count
M4Sz2ChaseY:
        move.b #$80,d1
        jsr M4EnChase8
        move.b d0,13(a0)
M4Sz2Count:
        cmpi.w #2,d6
        bne.s M4Sz2St2
        bsr M4Sz2Next
M4Sz2St2: ;2: |pz - z| < 1000: banktoplayer; < 600: 3
        cmpi.b #2,X_STATE(a0)
        bne.s M4Sz2St3
        movea.l a1,a2
        jsr M4EnZD
        subi.w #1000,d0
        bpl.s M4Sz2St3
        jsr M4EnBankToPlayer
        jsr M4EnZD
        subi.w #600,d0
        bpl.s M4Sz2St3
        bsr M4Sz2Next
M4Sz2St3: ;3: roty -> $80 (Achase8_2 1F:D88A)
        cmpi.b #3,X_STATE(a0)
        bne.s M4Sz2Fire
        move.b 13(a0),d0
        move.b #$80,d1
        moveq #2,d2
        jsr M4EnChase8
        move.b d0,13(a0)
M4Sz2Fire: ;400 <= |pz - z| < 1500, every 8 ticks: $0C straight ahead
        movea.l a1,a2
        jsr M4EnZD
        move.w d0,d1
        subi.w #400,d1
        bmi.s M4Sz2Move
        subi.w #1500,d0
        bpl.s M4Sz2Move
        jsr M4ArPhase ;original 54-byte slot phase
        andi.w #7,d0
        bne.s M4Sz2Move
        moveq #1,d0
        suba.l a3,a3
        bsr M4AstFireZero
M4Sz2Move:
        jsr M4EnGen3d
        jsr M4EnMove
        jsr M4EnAddPZ
        moveq #0,d0
        rts
M4Sz2Next: ;state + 1, 1 after 3
        move.b X_STATE(a0),d0
        addq.b #1,d0
        cmpi.b #3,d0
        ble.s M4Sz2Store
        moveq #1,d0
M4Sz2Store:
        move.b d0,X_STATE(a0)
        rts

; ---------------------------------------------------------------------
; wormhead 08:CAD1 (expstrat 08:CC2C, clears $14F3 bits 0-1) / worm 08:CB12
; (expstrat 08:CC19). Init 08:CB39 (no tick on the creation call): roty
; $80, HP 2, AP 4, collflags $10, vz -10. sword1 = predecessor (map 48/4A,
; low WORD; never cleared on removal, as in the ROM).
M4StratWormHead:
        move.l #M4WormHeadExp,X_EXP(a0)
        andi.b #$fc,M4_AST_WORM
        bra.s M4WormInit
M4StratWorm:
        move.l #M4WormExp,X_EXP(a0)
M4WormInit:
        move.l #M4WormTick,32(a0)
        move.l #M4LcHitFlash,X_COLL(a0)
        move.b #$80,13(a0)
        move.b #2,38(a0)
        move.b #4,39(a0)
        ori.b #$10,44(a0)
        move.w #-10,10(a0)
        moveq #0,d0
        rts
; 08:CB55: v = (trunc0(sin8[sbyte2]/16), trunc0(cos8[sbyte2]/16)), sbyte2 += 4.
M4WormTick:
        lea M4IntroShipSine,a2 ;00:98A5 (cos = +64)
        moveq #0,d0
        move.b 37(a0),d0
        move.b (a2,d0.w),d1
        bsr M4WormDiv16
        move.w d1,6(a0)
        move.b 64(a2,d0.w),d1
        bsr M4WormDiv16
        move.w d1,8(a0)
        addq.b #4,37(a0)
        move.w 40(a0),d0
        beq.s M4WormNoPred
        movea.w d0,a2
        tst.b 38(a2)
        bne.s M4WormNoPred
        btst #0,M4_AST_WORM ;dead predecessor
        beq.s M4WormMove
        jsr M4EnKill ;06:8D07: head dead -> chain of explosions
        moveq #0,d0
        rts
M4WormNoPred:
        btst #1,M4_AST_WORM
        bne.s M4WormScatter
M4WormMove:
        jsr M4EnMove
        jsr M4EnAddPZ
        moveq #0,d0
        rts
M4WormDiv16: ;d1.b signed -> d1.w = trunc toward zero (d1 / 16)
        ext.w d1
        bpl.s M4WormDivPos
        neg.w d1
        asr.w #4,d1
        neg.w d1
        rts
M4WormDivPos:
        asr.w #4,d1
        rts
; 08:CC38: v = ((rnd & 63) - 32, (rnd & 63) - 32, 0), sbyte2 = 18.
M4WormScatter:
        jsr M4IntroRandom
        andi.w #63,d0
        subi.w #32,d0
        move.w d0,6(a0)
        jsr M4IntroRandom
        andi.w #63,d0
        subi.w #32,d0
        move.w d0,8(a0)
        clr.w 10(a0)
        move.b #18,37(a0)
        move.l #M4WormScatterTick,32(a0)
        moveq #0,d0
        rts
M4WormScatterTick: ;08:CC83
        tst.b 37(a0)
        beq.s M4WormDriftInit
        subq.b #1,37(a0)
        bra.s M4WormMove
M4WormDriftInit: ;08:CC96: v = vel = 0 (1F:DB45), vz = -10
        move.l #M4WormDrift,32(a0)
        clr.l 6(a0)
        clr.b 15(a0)
        move.w #-10,10(a0)
M4WormDrift: ;08:CCB0: afLeftPl -> vx + 1, else vx - 1; no addplayerZ
        btst #AF_LEFTPL,51(a0)
        beq.s M4WormDriftDec
        addq.w #1,6(a0)
        bra.s M4WormDriftMove
M4WormDriftDec:
        subq.w #1,6(a0)
M4WormDriftMove:
        jsr M4EnMove
        moveq #0,d0
        rts
M4WormHeadExp: ;08:CC2C
        ori.b #1,M4_AST_WORM
        jmp M4LevelExplode
M4WormExp: ;08:CC19
        btst #0,M4_AST_WORM
        bne.s M4WormExpGo
        ori.b #2,M4_AST_WORM
M4WormExpGo:
        jmp M4LevelExplode

; ---------------------------------------------------------------------
; cameleon 09:95A1: HP 2, AP 8, sbyte1 20. rotx += 16 to $80, rotz += 4 to
; $40, 20 ticks firing $0C at the player every 16, roty += 16 to $80, gone.
M4StratCameleon:
        move.l #M4CameleonTick,32(a0)
        jsr M4LvNormPtrs
        move.b #2,38(a0)
        move.b #8,39(a0)
        move.b #20,36(a0)
M4CameleonTick:
        cmpi.b #$80,12(a0)
        beq.s M4CamRotz
        addi.b #16,12(a0)
        bra.s M4CamFin
M4CamRotz:
        cmpi.b #$40,14(a0)
        beq.s M4CamShoot
        addq.b #4,14(a0)
        bra.s M4CamFin
M4CamShoot:
        tst.b 36(a0)
        beq.s M4CamLeaveInit
        subq.b #1,36(a0)
        jsr M4ArPhase ;original 54-byte slot phase
        andi.w #15,d0
        bne.s M4CamFin
        moveq #1,d0
        movea.l a1,a3
        bsr M4AstFireZero
        bra.s M4CamFin
M4CamLeaveInit:
        move.l #M4CameleonLeave,32(a0)
M4CameleonLeave: ;09:9641
        cmpi.b #$80,13(a0)
        beq.s M4CamGone
        addi.b #16,13(a0)
M4CamFin:
        jsr M4EnAddPZ
        moveq #0,d0
        rts
M4CamGone:
        moveq #1,d0
        rts

; cameleon2 08:B93F: HP 2, AP 8, collflags |= 1; six teleport positions
; (08:BAEA/BAF6, index sbyte1 += 2) with one $0C shot each, then rams.
M4StratCameleon2:
        jsr M4LvNormPtrs
        move.b #2,38(a0)
        move.b #8,39(a0)
        ori.b #1,44(a0)
M4Cam2Place: ;08:B9E0, then the strategy B961 at once (1F:DC25)
        moveq #0,d0
        move.b 36(a0),d0
        lea M4Cam2X,a2
        move.w (a2,d0.w),(a0)
        lea M4Cam2Y,a2
        move.w (a2,d0.w),2(a0)
        move.l #M4Cam2Turn,32(a0)
M4Cam2Turn: ;08:B961: rotx -> $80 (Achase8_2); already there: shoot
        move.b 12(a0),d0
        move.b #$80,d1
        moveq #2,d2
        jsr M4EnChase8
        move.b d0,12(a0)
        tst.w d3
        beq.s M4Cam2Fin
        moveq #1,d0
        movea.l a1,a3
        bsr M4AstFireZero
        addq.b #2,36(a0)
        cmpi.b #12,36(a0)
        beq.s M4Cam2AttackInit
        move.l #M4Cam2Back,32(a0)
M4Cam2Back: ;08:B9CB: rotx -> 0 (Achase8_4); there: next position
        move.b 12(a0),d0
        moveq #0,d1
        moveq #4,d2
        jsr M4EnChase8
        move.b d0,12(a0)
        tst.w d3
        bne.s M4Cam2Place
M4Cam2Fin:
        jsr M4EnAddPZ
        moveq #0,d0
        rts
M4Cam2AttackInit: ;08:BA15
        move.l #M4Cam2Attack,32(a0)
M4Cam2Attack: ;08:BA22
        move.b 12(a0),d0
        move.b #$80,d1
        moveq #2,d2
        jsr M4EnChase8
        move.b d0,12(a0)
        tst.w d3
        beq.s M4Cam2Fin
        addq.b #4,14(a0)
        moveq #30,d0
        moveq #1,d1
        jsr M4EnSpeedTo
        movea.l a1,a2
        jsr M4EnZD
        subi.w #300,d0
        bmi.s M4Cam2Move
        jsr M4EnPitchTo ;sbyte2 = Achase8_2(sbyte2, pitchTo)
        move.b d0,d1
        move.b 37(a0),d0
        moveq #2,d2
        jsr M4EnChase8
        move.b d0,37(a0)
        jsr M4EnYawTo ;sbyte1 = Achase8_2(sbyte1, yawTo)
        move.b d0,d1
        move.b 36(a0),d0
        jsr M4EnChase8
        move.b d0,36(a0)
        move.b 15(a0),d0
        ext.w d0
        move.b 37(a0),d1
        move.b 36(a0),d2
        jsr M4EnVector
        movem.w d3-d5,6(a0)
M4Cam2Move:
        jsr M4EnMove
        bra M4Cam2Fin
M4Cam2X: ;08:BAEA
        incbin '../build/M4Cam2X.bin'
M4Cam2Y: ;08:BAF6
        incbin '../build/M4Cam2Y.bin'

; ---------------------------------------------------------------------
; tadpole 0A:EEDE (also setstrat target of path 45AB): HP 4, AP 10, vel 30,
; count 60, sflags2 $10 when x >= 0, sbyte1 40, then 0A:EF15 at once.
; 1F:DB66 = state + 1 and the strategy again from the top.
M4StratTadpole:
        move.l #M4TadpoleTick,32(a0)
        jsr M4LvNormPtrs
        move.b #4,38(a0)
        move.b #10,39(a0)
        move.b #30,15(a0)
        move.b #60,19(a0)
        tst.w (a0)
        bmi.s M4TadLeft
        bset #F2_SFLAG1,48(a0)
M4TadLeft:
        move.b #40,36(a0)
M4TadpoleTick:
        moveq #0,d7 ;deferred removal (1F:D501 at count 0)
M4TadRestart:
        tst.b X_STATE(a0)
        bne.s M4TadSt1
        move.b 13(a0),d0
        moveq #4,d2
        btst #F2_SFLAG1,48(a0)
        beq.s M4TadSt0Left
        move.b #$40,d1
        jsr M4EnChase8
        move.b d0,13(a0)
        subq.b #2,12(a0)
        bra.s M4TadSt0Count
M4TadSt0Left:
        move.b #$c0,d1
        jsr M4EnChase8
        move.b d0,13(a0)
        addq.b #2,12(a0)
M4TadSt0Count:
        tst.b 36(a0)
        bne.s M4TadSt0Dec
        addq.b #1,X_STATE(a0)
        bra.s M4TadRestart
M4TadSt0Dec:
        subq.b #1,36(a0)
M4TadSt1: ;aim (Achase8_3), fire $0A once within 1500
        cmpi.b #1,X_STATE(a0)
        bne.s M4TadSt2
        move.b #20,36(a0)
        movea.l a1,a2
        jsr M4EnPitchTo
        move.b d0,d1
        move.b 12(a0),d0
        moveq #3,d2
        jsr M4EnChase8
        move.b d0,12(a0)
        jsr M4EnYawTo
        move.b d0,d1
        move.b 13(a0),d0
        jsr M4EnChase8
        move.b d0,13(a0)
        jsr M4EnZD
        subi.w #1500,d0
        bpl.s M4TadSt2
        moveq #0,d0 ;$0A RelSlowElaserHome along its own rotation
        suba.l a3,a3
        move.l d7,-(sp)
        bsr M4AstFireZero
        move.l (sp)+,d7
        addq.b #1,X_STATE(a0)
M4TadSt2:
        cmpi.b #2,X_STATE(a0)
        bne.s M4TadSt3
        addq.b #2,14(a0)
        addq.b #2,12(a0)
        subq.b #1,36(a0)
        bne.s M4TadSt3
        addq.b #1,X_STATE(a0)
        move.b #40,36(a0)
M4TadSt3:
        cmpi.b #3,X_STATE(a0)
        bne.s M4TadSt4
        tst.b 36(a0)
        bne.s M4TadSt3Dec
        addq.b #1,X_STATE(a0)
        bra M4TadRestart
M4TadSt3Dec:
        subq.b #1,36(a0)
        addq.b #8,14(a0)
        subq.b #4,12(a0)
M4TadSt4:
        cmpi.b #4,X_STATE(a0)
        bne.s M4TadMove
        addq.b #8,14(a0)
        subq.b #1,12(a0)
        subq.b #1,19(a0)
        bne.s M4TadSt4Speed
        moveq #1,d7
M4TadSt4Speed:
        moveq #60,d0
        moveq #1,d1
        jsr M4EnSpeedTo
        subq.b #2,13(a0)
        btst #F2_SFLAG1,48(a0)
        beq.s M4TadMove
        addq.b #4,13(a0)
M4TadMove:
        jsr M4EnGen3d
        jsr M4EnMove
        jsr M4EnAddPZ
        move.l d7,d0
        rts

; ---------------------------------------------------------------------
; Space pylon 09:F967 (core DD14, no geometry; 3 petals DD30 = pilon,
; strategy 09:FCC8, link_child ids 1..3, petal sbyte2 $55/$AB/0). The ROM
; keeps the children in a sword1 chain unlinked by divorcefamily; the port
; finds a child by (al_ptr = mother, sbyte1 = id) over allst (same result).
; A failed creation locks the SNES (1F:BDEE); the port goes on.
M4StratSpacePilon:
        moveq #1,d4
M4PilonChild:
        move.l #M4_SH_PILON,d0 ;descriptor index may exceed 127
        jsr M4EnCreate
        beq.s M4PilonChildNext
        move.b d4,36(a2) ;link_child 1F:D56F
        move.w a0,X_ALPTR(a2)
        clr.w 40(a2) ;sword1 chain: appended to the mother's
        movea.l a0,a3
M4PilonChainNext:
        move.w 40(a3),d0
        beq.s M4PilonChainEnd
        movea.w d0,a3
        bra.s M4PilonChainNext
M4PilonChainEnd:
        move.w a2,40(a3)
        bset #6,X2_FL4(a0) ;motherobj
        bset #4,X2_FL4(a2) ;childobj
        move.l #M4StratPilonPetal,32(a2)
        ori.b #$40,44(a2)
        cmpi.b #1,d4
        bne.s M4PilonChild2
        move.b #$55,37(a2)
M4PilonChild2:
        cmpi.b #2,d4
        bne.s M4PilonChildNext
        move.b #$ab,37(a2)
M4PilonChildNext:
        addq.b #1,d4
        cmpi.b #4,d4
        bne.s M4PilonChild
        bclr #3,45(a0) ;type &= ~8
        ; destination = pos + ((rnd - 127) * 4, (rnd - 127) * 4, (rnd - 127) * 2)
        jsr M4IntroRandom
        andi.w #255,d0
        subi.w #127,d0
        add.w d0,d0
        add.w d0,d0
        add.w d0,(a0)
        jsr M4IntroRandom
        andi.w #255,d0
        subi.w #127,d0
        add.w d0,d0
        add.w d0,d0
        add.w d0,2(a0)
        jsr M4IntroRandom
        andi.w #255,d0
        subi.w #127,d0
        add.w d0,d0
        add.w d0,4(a0)
        move.l (a0),6(a0) ;v = destination
        move.w 4(a0),10(a0)
        move.w M4_SC_PPOSX,(a0) ;starts at player_pos, 500 behind
        move.w M4_SC_PPOSY,2(a0)
        move.w M4_LP_POSZ,d0
        subi.w #500,d0
        move.w d0,4(a0)
        move.l #M4PilonTick,32(a0)
        move.l #M4PilonColl,X_COLL(a0)
        move.l #M4PilonExp,X_EXP(a0)
        move.b #40,37(a0)
        move.b #6,38(a0)
        clr.b 39(a0)
        move.b #150,X_SBYTE4(a0)
        ori.b #$40,44(a0)
M4PilonTick: ;09:FB3C
        tst.b X_STATE(a0)
        bne.s M4PilonSt1
        ; 0: no collision, pos = Achase16_4(pos, destination) per axis
        bset #SF_COLLDISABLE,49(a0)
        moveq #4,d2
        move.w (a0),d0
        move.w 6(a0),d1
        jsr M4LpAchase
        move.w d0,(a0)
        move.w 2(a0),d0
        move.w 8(a0),d1
        jsr M4LpAchase
        move.w d0,2(a0)
        move.w 4(a0),d0
        move.w 10(a0),d1
        jsr M4LpAchase
        move.w d0,4(a0)
        subq.b #1,37(a0)
        bne.s M4PilonSt1
        bclr #SF_COLLDISABLE,49(a0)
        addq.b #1,X_STATE(a0)
        move.b #1,37(a0)
M4PilonSt1: ;1: sbyte2 delay; rotz += 8; every 32 ticks Hplasma $26 at the player
        cmpi.b #1,X_STATE(a0)
        bne.s M4PilonTail
        subq.b #1,37(a0)
        bne.s M4PilonTail
        move.b #1,37(a0)
        addq.b #8,14(a0)
        move.w M4_LV_GAMEFRAME,d0
        andi.w #31,d0
        bne.s M4PilonTail
        moveq #2,d0
        movea.l a1,a3
        bsr M4AstFireZero
        move.l a2,d0
        beq.s M4PilonTail
        move.w a1,X_ALPTR(a2) ;munition al_ptr = player
M4PilonTail: ;sbyte4 ticks following the player (destination too)
        tst.b X_SBYTE4(a0)
        beq.s M4PilonZr
        subq.b #1,X_SBYTE4(a0)
        jsr M4EnAddPZ
        move.w M4_LP_PVIEWVZ,d0
        add.w d0,10(a0)
        moveq #0,d0
        rts
M4PilonZr: ;then zremove on the core and its petals
        bset #3,45(a0)
        moveq #1,d4
M4PilonZrChild:
        bsr M4PilonFindChild
        beq.s M4PilonZrNext
        bset #3,45(a2)
M4PilonZrNext:
        addq.b #1,d4
        cmpi.b #4,d4
        bne.s M4PilonZrChild
        moveq #0,d0
        rts
; find_child 1F:DC40: d4 = id -> a2 (Z set when none).
M4PilonFindChild:
        move.w M4_LV_HEAD,d0
M4PilonFindNext:
        beq.s M4PilonFindNone
        movea.w d0,a2
        move.w a0,d0
        cmp.w X_ALPTR(a2),d0
        bne.s M4PilonFindSkip
        cmp.b 36(a2),d4
        bne.s M4PilonFindSkip
        move.l 32(a2),d0
        cmpi.l #M4StratPilonPetal,d0
        beq.s M4SpPilonFound
        cmpi.l #M4PilonPetalTick,d0
        beq.s M4SpPilonFound
M4PilonFindSkip:
        move.w X_NEXT(a2),d0
        bra.s M4PilonFindNext
M4PilonFindNone:
        suba.l a2,a2
        moveq #0,d0
        rts
M4SpPilonFound:
        moveq #1,d0
        rts
; collstrat 09:FC3E: petals to state 1, sbyte2 = 10 (rotation pause), large
; explosion (06:EEDF, no sound), then hitflash 06:897B.
M4PilonColl:
        moveq #1,d4
M4PilonCollChild:
        bsr M4PilonFindChild
        beq.s M4PilonCollNext
        move.b #1,X_STATE(a2)
M4PilonCollNext:
        addq.b #1,d4
        cmpi.b #4,d4
        bne.s M4PilonCollChild
        move.b #10,37(a0)
        jsr M4FxMedium
        beq.s M4PilonCollHit
        exg a0,a2
        move.w #M4_FX_LARGE,d0
        jsr M4LevelSetShape
        exg a0,a2
M4PilonCollHit:
        jmp M4LcHitFlash
; expstrat 09:FCA6: petals removed (1F:D540), explode_Istrat.
M4PilonExp:
        moveq #1,d4
M4PilonExpChild:
        bsr M4PilonFindChild
        beq.s M4PilonExpNext
        move.l a0,-(sp)
        movea.l a2,a0
        jsr M4LevelRemove
        movea.l (sp)+,a0
M4PilonExpNext:
        addq.b #1,d4
        cmpi.b #4,d4
        bne.s M4PilonExpChild
        jmp M4LevelExplode
; petal 09:FCC8 / FCEC: HP $FF, AP 8, radius $C2, sbyte3 10; position =
; core + 8 * rot_z(0, r, 0) (1F:CC78), rotz = core rotz + sbyte2.
M4StratPilonPetal:
        move.l #M4PilonPetalTick,32(a0)
        bclr #3,45(a0)
        move.b #10,X_SBYTE3(a0)
        move.b #$ff,38(a0)
        move.b #8,39(a0)
        move.b #$c2,X_RADIUS(a0)
M4PilonPetalTick:
        move.w X_ALPTR(a0),d0
        beq M4PetalDone ;core removed: the ROM reads page 0 (not reproduced)
        movea.w d0,a2
        move.b 14(a2),d0
        add.b 37(a0),d0
        move.b d0,14(a0)
        lea M4IntroShipSine,a3
        andi.w #255,d0
        move.b (a3,d0.w),d2 ;sin
        move.b 64(a3,d0.w),d3 ;cos
        move.b X_RADIUS(a0),d0
        bsr M4AstRotMul ;x' = m(r, sin)
        ext.w d4
        asl.w #3,d4
        add.w (a2),d4
        move.w d4,(a0)
        move.b d3,d2
        bsr M4AstRotMul ;y' = m(r, cos)
        ext.w d4
        asl.w #3,d4
        add.w 2(a2),d4
        move.w d4,2(a0)
        move.w 4(a2),4(a0)
        tst.b X_STATE(a0)
        bne.s M4PetalSt1
        move.b X_RADIUS(a0),d0 ;0: r -> -12 (Achase8_3)
        move.b #$f4,d1
        moveq #3,d2
        jsr M4EnChase8
        move.b d0,X_RADIUS(a0)
M4PetalSt1: ;1: core invulnerable, r -= 10 for 10 ticks
        cmpi.b #1,X_STATE(a0)
        bne.s M4PetalSt2
        bset #SF_COLLDISABLE,49(a2)
        addi.b #$f6,X_RADIUS(a0)
        subq.b #1,X_SBYTE3(a0)
        bne.s M4PetalSt2
        move.b #2,X_STATE(a0)
        move.b #10,X_SBYTE3(a0)
M4PetalSt2: ;2: r += 10 for 10 ticks, core vulnerable again
        cmpi.b #2,X_STATE(a0)
        bne.s M4PetalDone
        subi.b #$f6,X_RADIUS(a0)
        subq.b #1,X_SBYTE3(a0)
        bne.s M4PetalDone
        clr.b X_STATE(a0)
        move.b #10,X_SBYTE3(a0)
        bclr #SF_COLLDISABLE,49(a2)
M4PetalDone:
        moveq #0,d0
        rts
; 1F:CC78 product: d0.b coordinate a, d2.b sin/cos b -> d4.b =
; +-hi(lo8(2|a|) * |b|), negative when a and b differ in sign.
M4AstRotMul:
        movem.l d5-d6,-(sp)
        move.b d0,d5
        bpl.s M4RotMulA
        neg.b d5
M4RotMulA:
        add.b d5,d5
        andi.w #255,d5
        move.b d2,d6
        bpl.s M4RotMulB
        neg.b d6
M4RotMulB:
        andi.w #255,d6
        mulu.w d6,d5
        lsr.w #8,d5
        move.b d0,d6
        eor.b d2,d6
        bpl.s M4RotMulPos
        neg.b d5
M4RotMulPos:
        move.b d5,d4
        movem.l (sp)+,d5-d6
        rts

; ---------------------------------------------------------------------
; blackhole 0A:DE06 (asteroid2 AF79 sprite): HP 20, AP 12, roty $80, sword1
; 100, sbyte1 70; tick 0A:E01D: z += pviewvelz - 30. expstrat 0A:E02E (every
; tick while HP 0): shape B005, colldisable, then the hole 0A:DE57.
M4StratBlackhole:
        move.l #M4BhApproach,32(a0)
        move.l #M4LcHitFlash,X_COLL(a0)
        move.l #M4BhExp,X_EXP(a0)
        bset #F2_SPRITE,48(a0)
        clr.b X_DEPTHOFF(a0)
        clr.b X_TX(a0)
        move.b #20,38(a0)
        move.b #12,39(a0)
        move.b #$80,13(a0)
        move.w #100,40(a0)
        move.b #70,36(a0)
        moveq #0,d0
        rts
M4BhExp:
        move.w #M4_FX_BLACKHOLE,d0
        jsr M4LevelSetShape
        move.w #$b005,X_SHAPEHDR(a0)
        bset #SF_COLLDISABLE,49(a0)
        move.l #M4BhHole,32(a0)
M4BhHole:
        btst #7,M4_LP_PSF2 ;player dead
        bne M4BhApproach
        addi.b #12,14(a0)
        btst #F2_SFLAG1,48(a0)
        bne.s M4BhCaptured
        movea.l a1,a2
        jsr M4EnDistXZ
        subi.w #100,d0
        bpl M4BhApproach
        bclr #3,45(a0) ;no zremove
        bset #F2_SFLAG1,48(a0)
M4BhCaptured:
        cmpi.b #70,36(a0)
        bne.s M4BhNot70
        bclr #1,M4_LP_PSF3 ;engine off (music $F4 not ported)
M4BhNot70:
        cmpi.b #31,36(a0)
        bne.s M4BhNot31
        move.b #$ff,M4_FADE ;fadedir $FF (music $F1 not ported)
M4BhNot31:
        subq.b #1,36(a0)
        bne.s M4BhPull
        move.w #M4RouteChange2,M4_GS_ROUTES+2 ;routechange2 03:D0D1
        move.b #15,M4_GS_LEVELFIN ;levelfinished = 15
M4BhPull:
        ori.b #$60,M4_LP_PSF
        ori.b #8,M4_LP_PSF3
        moveq #2,d2 ;Achase16_2 1F:D66F
        move.w 2(a1),d0
        move.w M4_LP_VIEWCY,d1
        jsr M4LpAchase
        move.w d0,2(a1)
        move.w (a1),d0
        moveq #0,d1
        jsr M4LpAchase
        move.w d0,(a1)
        addq.w #8,M4_LP_VIEWDIST
        addi.b #12,M4_LP_ZSTRATADD
        move.b #2,M4_LP_FLASHCNT
        move.b #1,M4_LP_FLASHTYPE
        move.w 2(a0),d0
        move.w M4_SC_PPOSY,d1
        jsr M4LpAchase
        move.w d0,2(a0)
        move.w (a0),d0
        move.w M4_SC_PPOSX,d1
        jsr M4LpAchase
        move.w d0,(a0)
        subi.w #20,4(a0)
        move.w M4_LV_GAMEFRAME,d0
        andi.w #3,d0
        bne.s M4BhApproach
        ; ring B005 at player_pos + (0, 0, sword1); sword1 <= 600 -> += 300
        move.w #M4_FX_BLACKHOLE,d0
        jsr M4EnCreate
        beq.s M4BhApproach
        bset #F2_SPRITE,48(a2)
        clr.b X_DEPTHOFF(a2)
        clr.b X_TX(a2)
        bset #SF_COLLDISABLE,49(a2)
        move.w #$b005,X_SHAPEHDR(a2)
        move.w M4_SC_PPOSX,(a2)
        move.w M4_SC_PPOSY,2(a2)
        move.w M4_LP_POSZ,d0
        add.w 40(a0),d0
        move.w d0,4(a2)
        move.w 40(a0),d0
        subi.w #600,d0
        beq.s M4BhGrow
        bpl.s M4BhRingStrat
M4BhGrow:
        addi.w #300,40(a0)
M4BhRingStrat:
        move.l #M4BhRing,32(a2)
M4BhApproach: ;0A:E01D
        jsr M4EnAddPZ
        subi.w #30,4(a0)
        moveq #0,d0
        rts
; 0A:E04E (rings): rotz += 12, roty $80, x, y -> player_pos (Achase16_2),
; z -= 20, then E01D.
M4BhRing:
        addi.b #12,14(a0)
        move.b #$80,13(a0)
        moveq #2,d2
        move.w 2(a0),d0
        move.w M4_SC_PPOSY,d1
        jsr M4LpAchase
        move.w d0,2(a0)
        move.w (a0),d0
        move.w M4_SC_PPOSX,d1
        jsr M4LpAchase
        move.w d0,(a0)
        subi.w #20,4(a0)
        bra.s M4BhApproach

; ---------------------------------------------------------------------
; Particle helper 06:F7E6 (nullshape; explode_Istrat debris and the path op
; particle 04:9DE4): expstrat 06:F81C, colldisable, afexp, sbyte3 6, sbyte1
; $3C, sbyte2 $1E. With HP 0 the expstrat runs every tick: sbyte1..3 = 0,
; count++, removed at 40, else z += 35.
M4StratParticles:
        move.l #M4ParticlesExp,X_EXP(a0)
        bset #SF_COLLDISABLE,49(a0)
        bset #0,25(a0)
        move.b #6,X_SBYTE3(a0)
        move.b #$3c,36(a0)
        move.b #$1e,37(a0)
        moveq #0,d0
        rts
M4ParticlesExp:
        clr.b X_SBYTE3(a0)
        clr.b 36(a0)
        clr.b 37(a0)
        addq.b #1,19(a0)
        cmpi.b #40,19(a0)
        beq.s M4ParticlesGone
        addi.w #35,4(a0)
        moveq #0,d0
        rts
M4ParticlesGone:
        moveq #1,d0
        rts

; Debris 06:F1DA, called by M4LevelExplode at 06:F4A8 when debrisshape != 0
; (a0 = exploding object; registers kept). Particle helper, then two pieces
; of the debris shape with v = (gen3d(k, ang, $40).x, .y, 0), ang = rnd +
; $10 and + $55; k = 15/30/35/15 by sh_size < $40/$80/$100/else.
M4AstDebris:
        tst.w X_DEBRIS(a0)
        bne.s M4DebrisGo
        rts
M4DebrisGo:
        movem.l d0-d7/a2-a4,-(sp)
        move.w #$ffff,d0
        jsr M4EnCreate
        beq.s M4DebrisNoAux
        move.l #M4StratParticles,32(a2)
        move.l (a0),(a2)
        move.w 4(a0),4(a2)
M4DebrisNoAux:
        move.w X_DEBRIS(a0),d0
        jsr M4LevelShapeIndex
        move.w d0,d6 ;descriptor of the pieces
        moveq #15,d7
        cmpi.w #$ffff,d0
        beq.s M4DebrisK
        lsl.w #5,d0
        lea M4LevelShapeDescriptors,a3
        move.w 26(a3,d0.w),d0 ;sh_size
        cmpi.w #$40,d0
        blo.s M4DebrisK
        moveq #30,d7
        cmpi.w #$80,d0
        blo.s M4DebrisK
        moveq #35,d7
        cmpi.w #$100,d0
        blo.s M4DebrisK
        moveq #15,d7
M4DebrisK:
        jsr M4IntroRandom
        addi.b #$10,d0
        move.b d0,d5 ;ang
        bsr.s M4DebrisPiece
        addi.b #$55,d5
        bsr.s M4DebrisPiece
        movem.l (sp)+,d0-d7/a2-a4
        rts
M4DebrisPiece:
        move.w d6,d0
        jsr M4EnCreate
        beq.s M4DebrisPieceDone
        move.l #M4StratDebris,32(a2)
        move.l (a0),(a2)
        move.w 4(a0),4(a2)
        move.w 12(a0),12(a2)
        move.b 14(a0),14(a2)
        move.b 48(a0),48(a2) ;sflags..sflags4 copied
        move.b 49(a0),49(a2)
        exg a0,a2
        move.w d5,-(sp)
        move.w d7,d0
        move.b d5,d1
        move.b #$40,d2
        jsr M4EnVector ;1F:DAB8 (returns d3-d5)
        move.w d3,6(a0)
        move.w d4,8(a0)
        clr.w 10(a0)
        move.w (sp)+,d5
        exg a0,a2
M4DebrisPieceDone:
        rts
; 06:F360: no collstrat, expstrat 06:F3F5, HP $FF, AP 8, colldisable, count
; = (rnd & 7) + 10, pos += v, then 06:F3B6 in the same call.
M4StratDebris:
        move.l #M4DebrisTick,32(a0)
        clr.l X_COLL(a0)
        move.l #M4DebrisExp,X_EXP(a0)
        move.b #$ff,38(a0)
        move.b #8,39(a0)
        bset #SF_COLLDISABLE,49(a0)
        jsr M4IntroRandom
        andi.b #7,d0
        addi.b #10,d0
        move.b d0,19(a0)
        jsr M4EnMove
M4DebrisTick: ;06:F3B6
        addq.b #8,12(a0)
        addq.b #4,14(a0)
        subq.b #1,19(a0)
        bne.s M4DebrisMove
        bset #SF_COLLDISABLE,49(a0)
        clr.b 38(a0)
M4DebrisMove:
        jsr M4EnMove
        btst #F2_RELEXPLODE,48(a0)
        beq.s M4DebrisDone
        jsr M4EnAddPZ
        subi.w #32,4(a0)
M4DebrisDone:
        moveq #0,d0
        rts
M4DebrisExp: ;06:F3F5: special and Cspecial cleared, explode_Istrat
        bclr #SF_SPECIAL,49(a0)
        bclr #F2_CSPECIAL,48(a0)
        jmp M4LevelExplode

; Space Armada unit (tunnel): ship interiors, tunnel exits and the corridor
; (map 0D:ACE5, AF49, B2B3, CC27, D34C..D576). Owner files: this file and
; level_armada_tunnel_strats.asm. Generic: the same strategies are reused by
; Sector X/Z, Fortuna, Macbeth and Venom 3 (no Armada-only assumptions).
; Specification: build/agent-armada/research/tunnel/SPEC.md (USA rev0,
; SHA-256 3857b529...a84d); routines re-read in the ROM bytes (rerun/
; strat_trace_all.txt). Oracle: build/agent-armada-fleet/armada-oracle.py
; (ROM 65816 vs this 68000 code, tick by tick; FLEET.md).
; Conventions of level_objects.asm: a0 object, a1 player; d0 = 0 keep /
; nonzero deferred removal (1F:D501). "d < K" = N bit of the 16-bit
; difference. Sounds (03:B7E5, positional 03:B705) are not ported.
; Already ported elsewhere and only referenced here: tunnel pieces
; 09:F72B.., exit 08:F145, exitlight3..6, exitopen/exitopensnd
; (level_venom_planet.asm), nocoll, gnd, hard180YR, skillfly, item5, path.
; RAM (Space Armada block): M4_AR+$40..$4F.
M4_TN equ M4_AR+$40
M4_TN_PNUMHITS equ M4_TN+0 ;.b $14F5 pnumhits (wireship hits, player side)
M4_TN_CURRSHIP equ M4_TN+1 ;.b $15A2 curr_ship (1 = wireship)
M4_TN_SHIELDUP equ M4_TN+2 ;.b $16CF shieldup
M4_TN_WIRECNT equ M4_TN+3 ;.b $14F4 wireship blink timer (0B:D33A, level_player.asm)
M4_TN_GASFLAGS equ M4_AST_WORM ;.b $14F3 (bit3: core1 hit -> core0 flash)

; ---------------------------------------------------------------------
; coll_Istrat 06:897B: hitflash 06:89A3 without the white flash (sflags $02):
; collide = 0; unless nohitaffect, do_coll(self, AP of the collider).
M4TnCollIstrat:
        bclr #SF_COLLIDE,49(a0)
        btst #SF_NOHITAFFECT,49(a0)
        bne.s M4TnCollStrat
        jsr M4LcCollider
        move.l a2,d0
        beq.s M4TnCollStrat
        moveq #0,d0
        move.b 39(a2),d0
        jsr M4LevelDoColl
M4TnCollStrat:
        jmp M4LcStrategy

; anim++ mod d2 (adc #1 / bmi / adc mod / and $7F / sbc mod / ora $80).
M4TnAnimInc:
        move.b 16(a0),d0
        moveq #1,d1
        jsr M4WpAddAnim
        move.b d0,16(a0)
        rts

; ---------------------------------------------------------------------
; openlr 0A:F0EC (open_l): collstrat 0A:F16D, no expstrat, HP $FF, AP 8.
; 0A:F11B: closed (no sflag1) -> animframe 0; open: colldisable, animframe
; + 1 mod 10 up to 9 (stays). Collision: sflag1, then hitflash.
M4TnOpenLR:
        move.l #M4TnOpenLRTick,32(a0)
        move.l #M4TnOpenLRColl,X_COLL(a0)
        clr.l X_EXP(a0)
        move.b #$ff,38(a0)
        move.b #8,39(a0)
M4TnOpenLRTick:
        btst #F2_SFLAG1,48(a0)
        bne.s M4TnOpenLROpen
        move.b #$80,16(a0)
        bra.s M4TnKeep
M4TnOpenLROpen:
        bset #SF_COLLDISABLE,49(a0)
        move.b 16(a0),d0
        andi.b #$7f,d0
        cmpi.b #9,d0
        beq.s M4TnKeep
        moveq #10,d2
        bsr M4TnAnimInc
M4TnKeep:
        moveq #0,d0
        rts
M4TnOpenLRColl: ;0A:F16D: sound $57, sflag1, hitflash
        bset #F2_SFLAG1,48(a0)
        jmp M4LcHitFlash

; ---------------------------------------------------------------------
; updoor 0A:F17D (up_door): collstrat 0A:F218, no expstrat, HP $FF, AP 8.
; 0A:F1AC: ZD < 700 -> sbyte1 100, animframe + 1 mod 10 up to 8 (stays);
; else animframe 0; then sbyte1-- while nonzero.
M4TnUpDoor:
        move.l #M4TnUpDoorTick,32(a0)
        move.l #M4TnUpDoorColl,X_COLL(a0)
        clr.l X_EXP(a0)
        move.b #$ff,38(a0)
        move.b #8,39(a0)
M4TnUpDoorTick:
        movea.l a1,a2
        jsr M4EnZD
        subi.w #700,d0
        bmi.s M4TnUpDoorNear
        move.b #$80,16(a0)
        bra.s M4TnUpDoorCount
M4TnUpDoorNear:
        move.b #100,36(a0)
        move.b 16(a0),d0
        andi.b #$7f,d0
        cmpi.b #8,d0
        beq.s M4TnUpDoorCount
        moveq #10,d2
        bsr M4TnAnimInc
M4TnUpDoorCount:
        tst.b 36(a0)
        beq.s M4TnKeep
        subq.b #1,36(a0)
        bra.s M4TnKeep
; 0A:F218: sound $57; sbyte1 nonzero (near or just flipped) -> coll_Istrat;
; else sbyte1 = 5, rotz += $80 (the door flips), hitflash.
M4TnUpDoorColl:
        tst.b 36(a0)
        bne M4TnCollIstrat
        move.b #5,36(a0)
        addi.b #$80,14(a0)
        jmp M4LcHitFlash

; ---------------------------------------------------------------------
; twall0 0A:BB1F (bou_0): HP $FF, AP 8, roty $80, shadow; no pointers.
; 0A:BB44: state 0: y -= 5, y == -100 -> state 1 and again (1F:DB78);
; state 1: y += 5, y == -20 -> state 0 and again (1F:DB70).
M4TnTwall0:
        move.b #$ff,38(a0)
        move.b #8,39(a0)
        move.l #M4TnTwall0Tick,32(a0)
        move.b #$80,13(a0)
        bset #F2_SHADOW,48(a0)
M4TnTwall0Tick:
        tst.b X_STATE(a0)
        bne.s M4TnTwall0Up
        subq.w #5,2(a0)
        cmpi.w #-100,2(a0)
        bne.s M4TnTwall0Up
        move.b #1,X_STATE(a0)
        bra.s M4TnTwall0Tick
M4TnTwall0Up:
        cmpi.b #1,X_STATE(a0)
        bne M4TnKeep
        addq.w #5,2(a0)
        cmpi.w #-20,2(a0)
        bne M4TnKeep
        clr.b X_STATE(a0)
        bra.s M4TnTwall0Tick

; ---------------------------------------------------------------------
; warker3 0A:BBFA (warker_3 / s_wark_0): normal pointers, HP 8, AP 4, roty
; $80, animframe 0, enemyweap ($40).
M4TnWarker3:
        move.l #M4TnWarker3Tick,32(a0)
        jsr M4LvNormPtrs
        move.b #8,38(a0)
        move.b #4,39(a0)
        move.b #$80,13(a0)
        move.b #$80,16(a0)
        ori.b #$40,44(a0)
; 0A:BC24 (cascade of states in one tick): 0: ZD < 700 -> state 1, vz 50,
; vy -10, move; 1: x = Achase16_2(x, 0), vy + 1, y >= 0 -> vy 0, state 2;
; 2: sflag1, vz 75, ZD >= 1000 -> $0C at the player from (0,-10,0), state
; 3, sbyte1 = rnd & 3; 3: vy 0, ZD >= 1000 -> vz 0; by sbyte1 climb to the
; roof (0/1) or a wall (2: minX, 3: maxX); sflag1 -> animframe + 1 mod 11;
; pos += v (1F:C7BB).
M4TnWarker3Tick:
        movea.l a1,a2
        tst.b X_STATE(a0)
        bne.s M4TnWk1
        jsr M4EnZD
        subi.w #700,d0
        bpl.s M4TnWk1
        addq.b #1,X_STATE(a0)
        move.w #50,10(a0)
        move.w #-10,8(a0)
        bra M4TnWkMove
M4TnWk1:
        cmpi.b #1,X_STATE(a0)
        bne.s M4TnWk2
        move.w (a0),d0
        moveq #0,d1
        moveq #2,d2
        jsr M4LpAchase
        move.w d0,(a0)
        addq.w #1,8(a0)
        tst.w 2(a0)
        bmi.s M4TnWk2
        clr.w 8(a0)
        addq.b #1,X_STATE(a0)
M4TnWk2:
        cmpi.b #2,X_STATE(a0)
        bne.s M4TnWk3
        bset #F2_SFLAG1,48(a0)
        move.w #75,10(a0)
        jsr M4EnZD
        subi.w #1000,d0
        bmi.s M4TnWk3
        moveq #M4_WT_RSE,d0
        moveq #0,d3
        moveq #-10,d4
        moveq #0,d5
        moveq #0,d6
        moveq #0,d7
        movea.l a1,a3
        jsr M4EnFire
        movea.l a1,a2
        addq.b #1,X_STATE(a0)
        jsr M4IntroRandom
        andi.b #3,d0
        move.b d0,36(a0)
M4TnWk3:
        cmpi.b #3,X_STATE(a0)
        bne M4TnWkAnim
        clr.w 8(a0)
        jsr M4EnZD
        subi.w #1000,d0
        bmi.s M4TnWkSide
        clr.w 10(a0)
M4TnWkSide:
        move.b 36(a0),d0
        cmpi.b #2,d0
        beq.s M4TnWkLeft
        cmpi.b #3,d0
        beq.s M4TnWkRight
        cmpi.b #1,d0
        bhi.s M4TnWkAnim
        move.b #$80,d1 ;0, 1: the roof
        move.w #-120,d3
        move.w M4_SC_PPOSX,d4
        bra.s M4TnWkClimb
M4TnWkLeft:
        moveq #$40,d1
        move.w M4_SC_PPOSY,d3
        move.w M4_LP_MINX,d4
        bra.s M4TnWkClimb
M4TnWkRight:
        move.b #$c0,d1
        move.w M4_SC_PPOSY,d3
        move.w M4_LP_MAXX,d4
M4TnWkClimb: ;rotz = Achase8_1(rotz, d1), y = Achase16_2(y, d3), x = Achase16_2(x, d4)
        move.w d3,d5 ;M4EnChase8 returns its flag in d3
        move.b 14(a0),d0
        moveq #1,d2
        jsr M4EnChase8
        move.b d0,14(a0)
        move.w d5,d3
        moveq #2,d2
        move.w 2(a0),d0
        move.w d3,d1
        jsr M4LpAchase
        move.w d0,2(a0)
        move.w (a0),d0
        move.w d4,d1
        jsr M4LpAchase
        move.w d0,(a0)
M4TnWkAnim:
        btst #F2_SFLAG1,48(a0)
        beq.s M4TnWkMove
        moveq #11,d2
        bsr M4TnAnimInc
M4TnWkMove:
        jsr M4EnMove
        moveq #0,d0
        rts

; ---------------------------------------------------------------------
; leng0 0A:B69C (leng_0): no pointers, HP $FF, AP 8, animframe 0,
; colldisable. 0A:B6C2: ZD >= 1300 -> nothing; animframe 10 -> collidable
; (colldisable cleared); else animframe + 1 mod 11.
M4TnLeng0:
        move.l #M4TnLeng0Tick,32(a0)
        jsr M4LvZeroPtrs
        move.b #$ff,38(a0)
        move.b #8,39(a0)
        move.b #$80,16(a0)
        bset #SF_COLLDISABLE,49(a0)
M4TnLeng0Tick:
        movea.l a1,a2
        jsr M4EnZD
        subi.w #1300,d0
        bpl M4TnKeep
        move.b 16(a0),d0
        andi.b #$7f,d0
        cmpi.b #10,d0
        bne.s M4TnLeng0Close
        bclr #SF_COLLDISABLE,49(a0)
        bra M4TnKeep
M4TnLeng0Close:
        moveq #11,d2
        bsr M4TnAnimInc
        bra M4TnKeep

; ---------------------------------------------------------------------
; iris 09:9529: child created behind it (09:AE35: 1F:D54B with B8F7) at its
; position and rotations, shape C8BC, strategy 00:FACF, z + 100; then roty
; $80, normal pointers, HP $7F, AP 8, animframe 0.
M4TnIris:
        move.w #$b8f7,d0
        jsr M4ArCreateHdr
        beq.s M4TnIrisNoChild
        move.l (a0),(a2)
        move.w 4(a0),4(a2)
        move.b 12(a0),12(a2)
        move.b 13(a0),13(a2)
        move.b 14(a0),14(a2)
        move.w #$c8bc,d0
        jsr M4ArSetShapeA2
        move.l #M4TnIrisChild,32(a2)
        addi.w #100,4(a2)
M4TnIrisNoChild:
        move.b #$80,13(a0)
        move.l #M4TnIrisTick,32(a0)
        jsr M4LvNormPtrs
        move.b #$7f,38(a0)
        move.b #8,39(a0)
        move.b #$80,16(a0)
; 09:957F: HP >= $7D (unsigned) -> closed; else 09:8064(8): animframe + 1
; saturated at 7.
M4TnIrisTick:
        cmpi.b #$7d,38(a0)
        bhs M4TnKeep
        move.b 16(a0),d0
        andi.b #$7f,d0
        addq.b #1,d0
        cmpi.b #8,d0
        blo.s M4TnIrisStore
        moveq #7,d0
M4TnIrisStore:
        ori.b #$80,d0
        move.b d0,16(a0)
        bra M4TnKeep
; 00:FACF (no stratptr of its own: every tick): colldisable.
M4TnIrisChild:
        bset #SF_COLLDISABLE,49(a0)
        bra M4TnKeep

; ---------------------------------------------------------------------
; item6 08:D5F0 (item_6, wireship): no pointers, colldisable. 08:D607:
; player dead -> deferred removal; sbyte1 0 -> z += 20; roty += 4; ZD < 120
; and distXY < 60 -> pnumhits 0, curr_ship 1, $14D9 |= 2 (wireship),
; shieldup 1, removed. select_ship_l(1) 06:818D and the end of the
; wireship 0B:D33A: M4LpMove / M4LpShapeSet (level_player.asm).
M4TnItem6:
        move.l #M4TnItem6Tick,32(a0)
        jsr M4LvZeroPtrs
        bset #SF_COLLDISABLE,49(a0)
M4TnItem6Tick:
        moveq #0,d7
        tst.b M4_LP_PSF2
        bpl.s M4TnItem6Alive
        moveq #1,d7
M4TnItem6Alive:
        tst.b 36(a0)
        bne.s M4TnItem6Still
        addi.w #20,4(a0)
M4TnItem6Still:
        addq.b #4,13(a0)
        movea.l a1,a2
        jsr M4EnZD
        subi.w #120,d0
        bpl.s M4TnItem6Done
        jsr M4EnDistXY
        subi.w #60,d0
        bpl.s M4TnItem6Done
        clr.b M4_TN_PNUMHITS
        move.b #1,M4_TN_CURRSHIP
        bset #1,M4_LP_PSF2
        move.b #1,M4_TN_SHIELDUP
        moveq #1,d7
M4TnItem6Done:
        move.l d7,d0
        rts

; ---------------------------------------------------------------------
; core0 08:A258 (core_1_0): enemy1, roty $80, HP $FF, AP 0, gasflags bit3
; cleared. 08:A27F: gasflags bit3 (core1 was hit) -> cleared, white flash.
M4TnCore0:
        ori.b #CF_ENEMY1,44(a0)
        move.b #$80,13(a0)
        move.b #$ff,38(a0)
        clr.b 39(a0)
        move.l #M4TnCore0Tick,32(a0)
        bclr #3,M4_TN_GASFLAGS
M4TnCore0Tick:
        bclr #3,M4_TN_GASFLAGS
        beq M4TnKeep
        bset #SF_HITFLASH,49(a0)
        bset #2,31(a0)
        bra M4TnKeep

; core1 08:A299 (core_1_1): collstrat 08:A37A, expstrat 08:A30A, HP 6, AP 8,
; roty $80, stratdone1 cleared, enemy1, nohitaffect. 08:A2E0: ZD < 1000 ->
; nohitaffect off; roty += 8.
M4TnCore1:
        move.l #M4TnCore1Tick,32(a0)
        move.l #M4TnCore1Coll,X_COLL(a0)
        move.l #M4TnCore1Exp,X_EXP(a0)
        move.b #6,38(a0)
        move.b #8,39(a0)
        move.b #$80,13(a0)
        bclr #3,M4_LP_GAMEFLAGS
        ori.b #CF_ENEMY1,44(a0)
        bset #SF_NOHITAFFECT,49(a0)
M4TnCore1Tick:
        movea.l a1,a2
        jsr M4EnZD
        subi.w #1000,d0
        bpl.s M4TnCore1Spin
        bclr #SF_NOHITAFFECT,49(a0)
M4TnCore1Spin:
        addq.b #8,13(a0)
        bra M4TnKeep
M4TnCore1Coll: ;08:A37A: gasflags bit3 (core0 flashes), hitflash
        bset #3,M4_TN_GASFLAGS
        jmp M4LcHitFlash
; expstrat 08:A30A: large explosion (no sound) 60 above; expstrat 08:A353;
; stratdone1; invisible; count 20; no zremove; sound $70.
M4TnCore1Exp:
        jsr M4FxLarge
        beq.s M4TnCore1ExpNo
        bset #F2_NOEXPSND,48(a2)
        subi.w #60,2(a2)
M4TnCore1ExpNo:
        move.l #M4TnCore1Dead,X_EXP(a0)
        bset #3,M4_LP_GAMEFLAGS
        bset #3,X2_FL4(a0)
        bset #SF_INVISIBLE,49(a0)
        move.b #20,19(a0)
        bclr #3,45(a0)
; 08:A353 (every tick): at the player (1F:DAED), shrapnel_srou_l 0B:A7DA
; (= M4VeShrapnel 0B:A7DE, level_venom_escape.asm), z += pviewvelz; outside
; the tunnel ($14DA bit0 clear) count--, 0 -> removed.
M4TnCore1Dead:
        move.l (a1),(a0)
        move.w 4(a1),4(a0)
        jsr M4VeShrapnel
        jsr M4EnAddPZ
        btst #0,M4_LP_PSF3
        bne M4TnKeep
        subq.b #1,19(a0)
        bne M4TnKeep
        moveq #1,d0
        rts

; ---------------------------------------------------------------------
; exitopensnd2 08:F1F7 (bshipexitface): sflag1 (sound when opening), then
; exitopen 08:F206 (M4VpStratExitOpen, level_venom_planet.asm).
M4TnExitOpenSnd2:
        bset #F2_SFLAG1,48(a0)
        jmp M4VpStratExitOpen

; ---------------------------------------------------------------------
; colonyexit 0A:F235 (E5D4; no stratptr: every tick): depthoffset 1,
; colldisable, atgnd; in front of or level with the player, or ZD < 75 ->
; animframe 0; else animframe + 1 mod 10 up to 9 (stays).
M4TnColonyExit:
        move.b #1,X_DEPTHOFF(a0)
        bset #SF_COLLDISABLE,49(a0)
        bset #0,45(a0)
        move.w 4(a0),d0
        sub.w 4(a1),d0
        bpl.s M4TnColonyClosed
        movea.l a1,a2
        jsr M4EnZD
        subi.w #75,d0
        bmi.s M4TnColonyClosed
        move.b 16(a0),d0
        andi.b #$7f,d0
        cmpi.b #9,d0
        beq M4TnKeep
        moveq #10,d2
        bsr M4TnAnimInc
        bra M4TnKeep
M4TnColonyClosed:
        move.b #$80,16(a0)
        bra M4TnKeep

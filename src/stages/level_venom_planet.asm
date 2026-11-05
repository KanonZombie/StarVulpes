; Venom 1 unit (planet): code. Included from level_venom.asm. Documentation:
; build/agent-venom/planet/PLANET.md (Spanish). Field conventions: level_objects.asm.
; Venom 1 surface (0D:BC57..) and final tunnel (0D:D726..DAB4, exit 0D:CDA3)
; object strategies, read from the selected ROM (USA rev0, SHA-256 3857b529...
; a84d) with tools/dis65816.py / build/research/strat_trace.py; dumps in
; build/agent-venom/planet/rom/. Oracle: build/agent-venom/planet/planet-compare.py.
; Original fields: animframe $1CE7 = 16(a0), colframe $1CE6 = 18(a0), count $0A =
; 19(a0), hitflags $35 = 20(a0), sbyte1/2 $22/$23 = 36/37(a0), sbyte4 $25 =
; X_SBYTE4, sword1 $26 = 40(a0).w, sword2 $28 = 42(a0).w (map setalvar.w $28
; lands there, M4LvAlvarMap). Comparisons "d < K" are the N bit of d - K.
; Sounds (03:B7E5, 03:B705, movewallsound 03:B69D, set_sound2 $1CE9) are not
; ported (audio only).
M4_VP equ $ff9fa0
M4_VP_1534 equ M4_VP+0 ;.b $1534 (smvar_byte1: last spacemist colframe)
; Shape headers set by these strategies (descriptors found by header, so a
; drawn shape with the same header replaces the M4_FX_VP_* effect).
M4VpHdrWallL equ $b533 ;wall_l
M4VpHdrWallR equ $b54f ;wall_r

; d0.w = ROM shape header -> shape of a0 (sta $04,x).
M4VpSetHdr:
        move.w d0,X_SHAPEHDR(a0)
        jsr M4LevelShapeIndex
        jmp M4LevelSetShape

; ---------------------------------------------------------------------
; spacebarshoot_Istrat 0A:D567: hitflash / no expstrat, hardvars (HP $FF,
; AP 8), colltype enemy1, lifecnt ($0A) 80.
M4VpStratSpacebar:
        move.l #M4VpSpacebarTick,32(a0)
        move.l #M4LcHitFlash,X_COLL(a0)
        clr.l X_EXP(a0)
        move.b #$ff,38(a0)
        move.b #8,39(a0)
        ori.b #CF_ENEMY1,44(a0)
        move.b #$50,19(a0)
; 0A:D5A0: rotz += sbyte1, x += sword1, y += sword2; spacemist: b = hi8(asr1(
; z - pviewposz + 500)), N(b - 8) clear (8 bits) -> 7; $1534 = b, colframe
; b | $80; lifecnt-- reaching 0 -> removed (1F:D501).
M4VpSpacebarTick:
        move.b 36(a0),d0
        add.b d0,14(a0)
        move.w 40(a0),d0
        add.w d0,(a0)
        move.w 42(a0),d0
        add.w d0,2(a0)
        move.w 4(a0),d0
        sub.w M4_LP_PVIEWZ,d0
        addi.w #500,d0
        asr.w #1,d0
        lsr.w #8,d0
        move.b d0,d1
        subq.b #8,d1
        bmi.s M4VpSpacebarMist
        moveq #7,d0
M4VpSpacebarMist:
        move.b d0,M4_VP_1534
        ori.b #$80,d0
        move.b d0,18(a0)
        subq.b #1,19(a0)
        beq.s M4VpRemove
M4VpKeep:
        moveq #0,d0
        rts
M4VpRemove:
        moveq #1,d0
        rts

; ---------------------------------------------------------------------
; walll_Istrat 09:9171 (animframe 1) / wallr_Istrat 09:917A (animframe 0):
; wall1_strat, normal pointers (hitflash, explode), HP $FF, AP $10, roty
; $80, colframe 4, nohitaffect.
M4VpStratWallL:
        move.b #$81,16(a0)
        bra.s M4VpWallInit
M4VpStratWallR:
        move.b #$80,16(a0)
M4VpWallInit:
        move.l #M4VpWallTick,32(a0)
        jsr M4LvNormPtrs
        move.b #$ff,38(a0)
        move.b #$10,39(a0)
        move.b #$80,13(a0)
        move.b #$84,18(a0)
        bset #SF_NOHITAFFECT,49(a0)
; wall1_strat 09:91AB: sbyte4 nonzero -> sbyte4--; colframe = (colframe+1)
; mod 8, below 4 -> 4; HF1: cleared, and with sbyte4 = 0: sbyte4 = 10,
; animframe ^= 1 (opening side). distXZ(player) < 600 (1F:D0AB) -> open.
M4VpWallTick:
        tst.b X_SBYTE4(a0)
        beq.s M4VpWallColanim
        subq.b #1,X_SBYTE4(a0)
M4VpWallColanim:
        move.b 18(a0),d0
        moveq #8,d1
        jsr M4MtAfInc
        move.b d0,18(a0)
        andi.b #$7f,d0
        cmpi.b #4,d0
        bhs.s M4VpWallHit
        move.b #$84,18(a0)
M4VpWallHit:
        btst #0,20(a0)
        beq.s M4VpWallDist
        bclr #0,20(a0)
        tst.b X_SBYTE4(a0)
        bne.s M4VpWallDist
        move.b #10,X_SBYTE4(a0)
        eori.b #1,16(a0)
M4VpWallDist:
        movea.l a1,a2
        jsr M4EnDistXZ
        subi.w #600,d0
        bmi.s M4VpWallOpen
        moveq #0,d0
        rts
; 09:9224: animframe & $7F = 0 -> wallright (shape wall_r, roty -> $40 by
; -16), else wallleft (wall_l, roty -> $C0 by +16); the new strategy runs now.
M4VpWallOpen:
        move.b 16(a0),d0
        andi.b #$7f,d0
        beq.s M4VpWallOpenR
        move.l #M4VpWallLeftTick,32(a0)
        move.w #M4VpHdrWallL,d0
        bsr M4VpSetHdr
M4VpWallLeftTick: ;09:924B
        cmpi.b #$c0,13(a0)
        beq M4VpKeep
        addi.b #$10,13(a0)
        bra M4VpKeep
M4VpWallOpenR:
        move.l #M4VpWallRightTick,32(a0)
        move.w #M4VpHdrWallR,d0
        bsr M4VpSetHdr
M4VpWallRightTick: ;09:9277
        cmpi.b #$40,13(a0)
        beq M4VpKeep
        subi.b #$10,13(a0)
        bra M4VpKeep

; ---------------------------------------------------------------------
; flypillarS_Istrat 08:D075: HP 12, AP 16, no strategy; hitflash /
; pillar3explode 06:FAAC.
M4VpStratFlyPillarS:
        move.b #12,38(a0)
        move.b #16,39(a0)
        clr.l 32(a0)
        move.l #M4LcHitFlash,X_COLL(a0)
        move.l #M4Pillar3Explode,X_EXP(a0)
        bra M4VpKeep

; flypillar_Istrat 08:D0A5 (mother 05:53B5): hitflash / pillar3explode, HP
; 12, AP 16, not z-removable, rotx $C0, vz 60; random_l: sword1 low byte,
; then +200; x low byte, x high byte & 1; x = x - 256 + player_posx ($150F).
M4VpStratFlyPillar:
        move.l #M4VpFlyPillarTick,32(a0)
        move.l #M4LcHitFlash,X_COLL(a0)
        move.l #M4Pillar3Explode,X_EXP(a0)
        move.b #12,38(a0)
        move.b #16,39(a0)
        bclr #3,45(a0)
        move.b #$c0,12(a0)
        move.w #60,10(a0)
        jsr M4IntroRandom
        move.b d0,41(a0)
        addi.w #200,40(a0)
        jsr M4IntroRandom
        move.b d0,1(a0)
        jsr M4IntroRandom
        andi.b #1,d0
        move.b d0,(a0)
        subi.w #256,(a0)
        move.w M4_SC_PPOSX,d0
        add.w d0,(a0)
; flypillar_strat 08:D125: z += pviewvelz; |pz - z| < sword1 -> move only;
; else rotx Achase8_2 -> 0 and, while y < 0, y += 20 (y >= 0: end 08:D180).
; Then pos += v and shadow.
M4VpFlyPillarTick:
        jsr M4EnAddPZ
        movea.l a1,a2
        jsr M4EnZD
        sub.w 40(a0),d0
        bmi.s M4VpFlyPillarMove
        move.b 12(a0),d0
        moveq #0,d1
        moveq #2,d2
        jsr M4EnChase8
        move.b d0,12(a0)
        tst.w 2(a0)
        bpl.s M4VpFlyPillarEnd
        addi.w #20,2(a0)
M4VpFlyPillarMove:
        jsr M4EnMove
        bset #F2_SHADOW,48(a0)
        bra M4VpKeep
; 08:D180: no strategy, rotx 0, z-removable again, no shadow.
M4VpFlyPillarEnd:
        clr.l 32(a0)
        clr.b 12(a0)
        bset #3,45(a0)
        bclr #F2_SHADOW,48(a0)
        bra M4VpKeep

; pillar2 09:97B7 (mother 05:533B): HP $FF, AP 8, animframe 0 (the Istrat
; returns); 09:97D4: animframe = (animframe + 1) mod 32 (09:8048).
M4VpStratPillar2:
        move.b #$ff,38(a0)
        move.b #8,39(a0)
        move.l #M4VpPillar2Tick,32(a0)
        move.b #$80,16(a0)
        bra M4VpKeep
M4VpPillar2Tick:
        move.b 16(a0),d0
        moveq #$20,d1
        jsr M4MtAfInc
        move.b d0,16(a0)
        bra M4VpKeep

; ---------------------------------------------------------------------
; Tunnel pieces 09:F72B/F737/F743/F74F: roty $80, rotz $80/$40/$00/$C0,
; then nocoll_Istrat 06:873F.
M4VpStratTopRight1:
        move.b #$80,d0
        bra.s M4VpTunnelPiece
M4VpStratTopLeft1:
        moveq #$40,d0
        bra.s M4VpTunnelPiece
M4VpStratBotLeft1:
        moveq #0,d0
        bra.s M4VpTunnelPiece
M4VpStratBotRight1:
        move.b #$c0,d0
M4VpTunnelPiece:
        move.b #$80,13(a0)
        move.b d0,14(a0)
        jmp M4StratNoColl

; Tunnel pillars 0A:F65E: zero pointers, HP $FF, AP 8; 0A:F677: |pz - z| <
; 700 -> animframe + 1 mod 10 until 9 (stays); else animframe 0.
M4VpStratTunPillar:
        move.l #M4VpTunPillarTick,32(a0)
        jsr M4LvZeroPtrs
        move.b #$ff,38(a0)
        move.b #8,39(a0)
M4VpTunPillarTick:
        movea.l a1,a2
        jsr M4EnZD
        subi.w #700,d0
        bmi.s M4VpTunPillarNear
        move.b #$80,16(a0)
        bra M4VpKeep
M4VpTunPillarNear:
        move.b 16(a0),d0
        andi.b #$7f,d0
        cmpi.b #9,d0
        beq M4VpKeep
        move.b 16(a0),d0
        moveq #10,d1
        jsr M4MtAfInc
        move.b d0,16(a0)
        bra M4VpKeep

; ---------------------------------------------------------------------
; exit_Istrat 08:F145: no pointers, colldisable.
M4VpStratExit:
        clr.l 32(a0)
        jsr M4LvZeroPtrs
        bset #SF_COLLDISABLE,49(a0)
        bra M4VpKeep

; exitlight3..6_Istrat 08:F18B/F193/F19B/F1A3: sbyte2 = 6/8/10/12,
; colldisable; A (08:F1BA): sbyte2-- -> colframe 1; at 0: B (08:F1CC) sbyte1
; = 3, colframe 0; B: sbyte1-- ; at 0: sbyte2 = 12 and A again (same tick).
M4VpStratExitLight3:
        moveq #6,d0
        bra.s M4VpExitLight
M4VpStratExitLight4:
        moveq #8,d0
        bra.s M4VpExitLight
M4VpStratExitLight5:
        moveq #10,d0
        bra.s M4VpExitLight
M4VpStratExitLight6:
        moveq #12,d0
M4VpExitLight:
        move.b d0,37(a0)
        bset #SF_COLLDISABLE,49(a0)
M4VpExitLightAInit: ;08:F1AD
        move.l #M4VpExitLightA,32(a0)
M4VpExitLightA:
        tst.b 37(a0)
        beq.s M4VpExitLightBInit
        subq.b #1,37(a0)
        move.b #$81,18(a0)
        bra M4VpKeep
M4VpExitLightBInit:
        move.l #M4VpExitLightB,32(a0)
        move.b #3,36(a0)
        move.b #$80,18(a0)
M4VpExitLightB: ;08:F1E4
        tst.b 36(a0)
        beq.s M4VpExitLightBDone
        subq.b #1,36(a0)
        bra M4VpKeep
M4VpExitLightBDone:
        move.b #12,37(a0)
        bra.s M4VpExitLightAInit

; exitopen_Istrat 08:F206 (exitopensnd 08:F200: + set_sound2 5): type gnd,
; donesnd (sflags4 $02 -> X2_FL4 bit1), HP 127, AP 0, colltype enemy1.
M4VpStratExitOpen:
        bset #0,45(a0)
        bset #1,X2_FL4(a0)
        move.b #127,38(a0)
        clr.b 39(a0)
        ori.b #CF_ENEMY1,44(a0)
        move.l #M4VpExitOpenTick,32(a0)
; exitopen_strat 08:F22D: sword2 nonzero (object; 0 for both Venom doors,
; 0D:CEF6/CF0A) -> copy its v and z += pviewvelz; pos += v; |pz - z| <
; sword1 -> colldisable, y += sbyte1 (signed); sflag1 -> cleared (sound).
M4VpExitOpenTick:
        move.w 42(a0),d0
        beq.s M4VpExitOpenMove
        movea.w d0,a2
        move.w 6(a2),6(a0)
        move.w 8(a2),8(a0)
        move.w 10(a2),10(a0)
        jsr M4EnAddPZ
M4VpExitOpenMove:
        jsr M4EnMove
        movea.l a1,a2
        jsr M4EnZD
        sub.w 40(a0),d0
        bpl M4VpKeep
        bset #SF_COLLDISABLE,49(a0)
        move.b 36(a0),d0
        ext.w d0
        add.w d0,2(a0)
        bclr #F2_SFLAG1,48(a0)
        bra M4VpKeep

; nocollanim0_Istrat 06:8738: animframe 0, then nocoll_Istrat 06:873F.
M4VpStratNoCollAnim0:
        move.b #$80,16(a0)
        jmp M4StratNoColl
        even

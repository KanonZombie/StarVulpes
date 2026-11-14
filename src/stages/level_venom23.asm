; Stage unit: Venom 2 (0D:E085/E0F5) and Venom 3 (0D:E8B9/E929).
; Strategies (table searched by M4LevelFindStrategy, level_objects.asm),
; helpers and effects of these stages. Stage data: tools/stages/venom23.py.
; RAM: $FF9940..$FF997F (reserved for this unit).
; Documentation (Spanish): build/agent-venom23/VENOM23.md. Oracle:
; build/agent-venom23/venom23-compare.py (ROM 65816 executed vs this code).
; Authority: ref/Star Fox (USA).sfc (rev0, SHA-256 3857b529...a84d); every
; routine re-read in the ROM bytes (build/agent-venom23/rom/*.txt,
; build/research/strat_trace.py). UltraStarFox names are labels only (its
; wireman, for one, differs from the ROM).
; Conventions: a0 object, a1 player; d0 = 0 keep / nonzero deferred removal
; (1F:D501: the rest of the strategy still runs). "d < K" of the original is
; the N bit of the 16-bit subtraction. Sounds (03:B7E5, 03:B69D) and snd2
; ($1CE9) are not ported (audio only). Fields: animframe $1CE7 = 16(a0),
; colframe $1CE6 = 18(a0), count $0A = 19(a0), hitflags $35 = 20(a0),
; sbyte1/2 = 36/37(a0), sword1 = 40(a0), stratstate $1CDC = X_STATE,
; immune $19 = 28(a0), skidy $21 = V3_SKIDY (50(a0), byte free in the
; object block for this unit's objects).
M4_VENOM23 equ $ff9940
M4_V3_1770 equ M4_VENOM23+0 ;.b $1770 powerbuild (castanet / airship)
M4_V3_1771 equ M4_VENOM23+1 ;.b $1771 (castanet: halves' state for their strategies)
V3_SKIDY equ 50

; ---------------------------------------------------------------------
; Helpers.
; make_obj 1F:D54B with header d0.w ($14C7) behind a0 -> a2 (Z on failure:
; the ROM then writes into dummyobj, i.e. nothing visible here).
M4V3Make:
        move.w d0,-(sp)
        jsr M4LevelShapeIndex
        jsr M4EnCreate
        move.w (sp)+,d0
        cmpa.w #0,a2
        beq M4V3MakeFail
        move.w d0,X_SHAPEHDR(a2)
M4V3MakeFail:
        rts

; Achase8 on 13/14(a0)-style bytes: d0 value, d1 target, d2 n -> d0.
; (M4EnChase8.) WORD achase toward player_posx/y: M4LpAchase.
; speedto 1F:D60D with target d0, step d1 -> d3 = 1 when vel was already
; the target (C = 1: nothing changed), else 0 (and vel moved).
M4V3SpeedToC:
        moveq #0,d3
        cmp.b 15(a0),d0
        bne M4V3SpeedMove
        moveq #1,d3
        rts
M4V3SpeedMove:
        jmp M4EnSpeedTo

; d0.b index -> d0.b = s8(SINtab 00:98A5[index]) shifted right d1 times,
; each step rounded toward zero (cmp #$80 / ror / bpl / adc #0).
M4V3SinShift:
        andi.w #$ff,d0
        lea M4IntroShipSine,a2
        move.b (a2,d0.w),d0
M4V3SinStep:
        asr.b #1,d0
        bpl M4V3SinNext
        bcc M4V3SinNext
        addq.b #1,d0
M4V3SinNext:
        subq.b #1,d1
        bne M4V3SinStep
        rts

; Shared tail: v = gen_3dvecs(vel, rotx, skidy) (1F:D5A7 with $15A9 =
; skidy), skidy first chased toward roty (Achase8_3 1F:D8BD).
M4V3SkidVec:
        move.b V3_SKIDY(a0),d0
        move.b 13(a0),d1
        moveq #3,d2
        jsr M4EnChase8
        move.b d0,V3_SKIDY(a0)
        move.b d0,d2
        move.b 12(a0),d1
        moveq #0,d0
        move.b 15(a0),d0
        ext.w d0
        jsr M4EnVector
        movem.w d3-d5,6(a0)
        rts

; Common Istrat part of the colony cars/trucks: hitflash / explode, HP d0,
; AP d1, collflags enemy1.
M4V3CarInit:
        jsr M4LvNormPtrs
        move.b d0,38(a0)
        move.b d1,39(a0)
        ori.b #CF_ENEMY1,44(a0)
        rts

; ---------------------------------------------------------------------
; aircar1_Istrat 0A:E08A: HP 10 AP 10, rotz $C0, sbyte1 25, roty 1,
; enemy1, colframe $80. Tick 0A:E0C2: sbyte1 0 -> colframe $81 and rotz
; Achase8_3 -> 0 (stop); else sbyte1 - 1, N/Z of (sbyte1 - 15): shadow and
; rotz + 1, otherwise rotz Achase8_3 -> 0; then x, y Achase16_3 toward
; player_posx/y (1F:D6AB) and z += pviewvelz.
M4V3StratAircar1:
        move.l #M4V3Aircar1Tick,32(a0)
        moveq #10,d0
        moveq #10,d1
        bsr M4V3CarInit
        move.b #$c0,14(a0)
        move.b #25,36(a0)
        move.b #1,13(a0)
        move.b #$80,18(a0)
M4V3Aircar1Tick:
        tst.b 36(a0)
        beq M4V3Aircar1Stop
        subq.b #1,36(a0)
        cmpi.b #15,36(a0)
        beq M4V3Aircar1Near
        bmi M4V3Aircar1Near
        bsr M4V3RotzHome3
        bra M4V3Aircar1XY
M4V3Aircar1Near:
        bset #F2_SHADOW,48(a0)
        addq.b #1,14(a0)
M4V3Aircar1XY:
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
        jsr M4EnAddPZ
        bra M4V3Keep
M4V3Aircar1Stop:
        move.b #$81,18(a0)
        bsr M4V3RotzHome3
        bra M4V3Keep
M4V3RotzHome3: ;rotz Achase8_3 -> 0 (1F:D8BD)
        moveq #3,d2
M4V3RotzHome:
        move.b 14(a0),d0
        moveq #0,d1
        jsr M4EnChase8
        move.b d0,14(a0)
        rts

; ---------------------------------------------------------------------
; aircar2_Istrat 0A:E131: HP 10 AP 10, rotz $C0, sbyte1 50, enemy1, colframe
; $80. Tick 0A:E165, state 0: rotz Achase8_4 -> 0, x Achase16_4 -> player_posx
; (1F:D6F0), z + 20, z += pviewvelz; sbyte1 - 1 reaching 0: barrier C9B8
; (make_obj; enemy1, copy_pos, copy_rots, strategy 09:CB7F, immune pointers
; both ways), then state 1 and v = (0, 0, -30). State 1: rotz + 1, roty + 1,
; z += pviewvelz, pos += v, vx - 1 until -10.
M4V3StratAircar2:
        move.l #M4V3Aircar2Tick,32(a0)
        moveq #10,d0
        moveq #10,d1
        bsr M4V3CarInit
        move.b #$c0,14(a0)
        move.b #50,36(a0)
        move.b #$80,18(a0)
M4V3Aircar2Tick:
        tst.b X_STATE(a0)
        bne M4V3Aircar2S1
        moveq #4,d2
        bsr M4V3RotzHome
        move.w (a0),d0
        move.w M4_SC_PPOSX,d1
        moveq #4,d2
        jsr M4LpAchase
        move.w d0,(a0)
        addi.w #20,4(a0)
        jsr M4EnAddPZ
        subq.b #1,36(a0)
        bne M4V3Aircar2S1
        move.w #$c9b8,d0
        bsr M4V3Make
        beq M4V3Aircar2Next
        ori.b #CF_ENEMY1,44(a2)
        move.l (a0),(a2)
        move.w 4(a0),4(a2)
        move.w 12(a0),12(a2)
        move.b 14(a0),14(a2)
        move.l #M4V3StratBarrier,32(a2)
        move.w a0,28(a2)
        move.w a2,28(a0)
M4V3Aircar2Next:
        addq.b #1,X_STATE(a0)
        clr.l 6(a0)
        move.w #-30,10(a0)
M4V3Aircar2S1:
        cmpi.b #1,X_STATE(a0)
        bne M4V3Keep
        addq.b #1,14(a0)
        addq.b #1,13(a0)
        jsr M4EnAddPZ
        jsr M4EnMove
        cmpi.w #-10,6(a0)
        beq M4V3Keep
        subq.w #1,6(a0)
        bra M4V3Keep

; ---------------------------------------------------------------------
; aircar3_Istrat 0A:E233: HP 10 AP 10, vel 40, sbyte1 50, shadow, rotz $C0,
; enemy1, colframe $80. Tick 0A:E271: state 0: rotz Achase8_4 -> 0, x
; Achase16_4 -> 0, sbyte1 - 1 reaching 0 -> state 1, sbyte1 0. State 1
; (same tick): roty = sin(sbyte1)/4, sbyte1 + 5, rotz = sin(sbyte1)/8
; (SINtab 00:98A5, shifts rounded toward zero), sword1 + 5, not N(sword1 -
; 320) -> state 2, count 40. State 2: speedto(50, 1), count - 1 reaching 0
; -> removed (deferred), even gameframe: rotx - 1. Always: skidy Achase8_3
; -> roty, v = gen_3dvecs(vel, rotx, skidy), vz = 12, pos += v, z +=
; pviewvelz.
M4V3StratAircar3:
        move.l #M4V3Aircar3Tick,32(a0)
        moveq #10,d0
        moveq #10,d1
        bsr M4V3CarInit
        move.b #40,15(a0)
        move.b #50,36(a0)
        bset #F2_SHADOW,48(a0)
        move.b #$c0,14(a0)
        move.b #$80,18(a0)
M4V3Aircar3Tick:
        moveq #0,d7
        tst.b X_STATE(a0)
        bne M4V3Aircar3S1
        moveq #4,d2
        bsr M4V3RotzHome
        move.w (a0),d0
        moveq #0,d1
        moveq #4,d2
        jsr M4LpAchase
        move.w d0,(a0)
        subq.b #1,36(a0)
        bne M4V3Aircar3S1
        addq.b #1,X_STATE(a0)
        clr.b 36(a0)
M4V3Aircar3S1:
        cmpi.b #1,X_STATE(a0)
        bne M4V3Aircar3S2
        move.b 36(a0),d0
        moveq #2,d1
        bsr M4V3SinShift
        move.b d0,13(a0)
        addq.b #5,36(a0)
        move.b 36(a0),d0
        moveq #3,d1
        bsr M4V3SinShift
        move.b d0,14(a0)
        addq.w #5,40(a0)
        move.w 40(a0),d0
        subi.w #320,d0
        bmi M4V3Aircar3S2
        addq.b #1,X_STATE(a0)
        move.b #40,19(a0)
M4V3Aircar3S2:
        cmpi.b #2,X_STATE(a0)
        bne M4V3Aircar3Move
        moveq #50,d0
        moveq #1,d1
        jsr M4EnSpeedTo
        subq.b #1,19(a0)
        bne M4V3Aircar3Frame
        moveq #1,d7
M4V3Aircar3Frame:
        btst #0,M4_LV_GAMEFRAME+1
        bne M4V3Aircar3Move
        subq.b #1,12(a0)
M4V3Aircar3Move:
        bsr M4V3SkidVec
        move.w #12,10(a0)
        jsr M4EnMove
        jsr M4EnAddPZ
        move.l d7,d0
        rts

; ---------------------------------------------------------------------
; aircar4_Istrat 0A:E38F: HP 10 AP 10, shadow, enemy1, colframe $81, count
; 60. Tick 0A:E3C5: x Achase16_4 -> player_posx; |pz - z| >= 600 -> y
; Achase16_4 -> player_posy; sflag1 set, or |pz - z| < 400 (then colframe
; $80, sflag1): speedto(80, 5); vel already 80 (C) -> roty + 1, rotz + 1,
; count - 1 reaching 0 -> removed (deferred). Always v = gen_3dvecs(vel,
; rotx, roty), pos += v (no pviewvelz).
M4V3StratAircar4:
        move.l #M4V3Aircar4Tick,32(a0)
        moveq #10,d0
        moveq #10,d1
        bsr M4V3CarInit
        bset #F2_SHADOW,48(a0)
        move.b #$81,18(a0)
        move.b #60,19(a0)
M4V3Aircar4Tick:
        moveq #0,d7
        move.w (a0),d0
        move.w M4_SC_PPOSX,d1
        moveq #4,d2
        jsr M4LpAchase
        move.w d0,(a0)
        bsr M4V3PlayerZD
        subi.w #600,d0
        bmi M4V3Aircar4Flag
        move.w 2(a0),d0
        move.w M4_SC_PPOSY,d1
        moveq #4,d2
        jsr M4LpAchase
        move.w d0,2(a0)
M4V3Aircar4Flag:
        btst #F2_SFLAG1,48(a0)
        bne M4V3Aircar4Speed
        bsr M4V3PlayerZD
        subi.w #400,d0
        bpl M4V3Aircar4Move
        move.b #$80,18(a0)
        bset #F2_SFLAG1,48(a0)
M4V3Aircar4Speed:
        moveq #80,d0
        moveq #5,d1
        bsr M4V3SpeedToC
        tst.b d3
        beq M4V3Aircar4Move
        addq.b #1,13(a0)
        addq.b #1,14(a0)
        subq.b #1,19(a0)
        bne M4V3Aircar4Move
        moveq #1,d7
M4V3Aircar4Move:
        jsr M4EnGen3d
        jsr M4EnMove
        move.l d7,d0
        rts
; d0 = |player.z - z| (16-bit abs: eor/inc, $8000 stays $8000).
M4V3PlayerZD:
        move.w 4(a1),d0
        sub.w 4(a0),d0
        bpl M4V3PlayerZDDone
        neg.w d0
M4V3PlayerZDDone:
        rts

; ---------------------------------------------------------------------
; aircar5_Istrat 0A:E478: HP 10 AP 10, vel 40, sbyte1 50, shadow, rotz $40,
; roty $F0, enemy1, colframe $80. Tick 0A:E4BA, state 0: rotz Achase8_4 ->
; 0; not N(x - 100) -> state 1, v = (-5, -10, -20), rotz 8, sbyte1 16, a
; small explosion (06:EEFD) at x 120. State 1 (same tick): odd gameframe,
; or sbyte1 nonzero (then - 1): roty Achase8_2 -> $10, rotz += sbyte1; then
; vy + 2 and on the ground (not N(y + 25)): y = -25, vy = trunc0(-vy / 2),
; -5..-1 -> 0. Other states: v = gen_3dvecs(vel, rotx, roty), vx << 1, vz =
; 20. Always pos += v, z += pviewvelz.
M4V3StratAircar5:
        move.l #M4V3Aircar5Tick,32(a0)
        moveq #10,d0
        moveq #10,d1
        bsr M4V3CarInit
        move.b #40,15(a0)
        move.b #50,36(a0)
        bset #F2_SHADOW,48(a0)
        move.b #$40,14(a0)
        move.b #$f0,13(a0)
        move.b #$80,18(a0)
M4V3Aircar5Tick:
        tst.b X_STATE(a0)
        bne M4V3Aircar5S1
        moveq #4,d2
        bsr M4V3RotzHome
        move.w (a0),d0
        subi.w #100,d0
        bmi M4V3Aircar5S1
        addq.b #1,X_STATE(a0)
        move.w #-5,6(a0)
        move.w #-10,8(a0)
        move.w #-20,10(a0)
        move.b #8,14(a0)
        move.b #16,36(a0)
        bsr M4V3FxSmall
        beq M4V3Aircar5S1
        move.w #120,(a2)
M4V3Aircar5S1:
        cmpi.b #1,X_STATE(a0)
        bne M4V3Aircar5Vec
        btst #0,M4_LV_GAMEFRAME+1
        bne M4V3Aircar5Turn
        tst.b 36(a0)
        beq M4V3Aircar5Fall
        subq.b #1,36(a0)
M4V3Aircar5Turn:
        move.b 13(a0),d0
        moveq #$10,d1
        moveq #2,d2
        jsr M4EnChase8
        move.b d0,13(a0)
        move.b 36(a0),d0
        add.b d0,14(a0)
M4V3Aircar5Fall:
        addq.w #2,8(a0)
        move.w 2(a0),d0
        addi.w #25,d0
        bmi M4V3Aircar5Move
        move.w #-25,2(a0)
        move.w 8(a0),d0
        neg.w d0
        bsr M4V3Div2
        cmpi.w #$fffb,d0
        blo M4V3Aircar5Vy
        moveq #0,d0
M4V3Aircar5Vy:
        move.w d0,8(a0)
        bra M4V3Aircar5Move
M4V3Aircar5Vec:
        jsr M4EnGen3d
        asl.w 6(a0)
        move.w #20,10(a0)
M4V3Aircar5Move:
        jsr M4EnMove
        jsr M4EnAddPZ
        bra M4V3Keep
; d0.w = trunc0(d0 / 2) (cmp #$8000 / ror / bpl / adc #0).
M4V3Div2:
        asr.w #1,d0
        bpl M4V3Div2Done
        bcc M4V3Div2Done
        addq.w #1,d0
M4V3Div2Done:
        rts

; makeSMLexpobj 06:EEFD at a0 (06:EF1B medium explosion, shape smallshape
; AD11) -> a2, Z on failure.
M4V3FxSmall:
        jsr M4FxMedium
        cmpa.w #0,a2
        beq M4V3FxSmallDone
        exg a0,a2
        move.w #M4_FX_SMALL,d0
        jsr M4LevelSetShape
        exg a0,a2
        cmpa.w #0,a2
M4V3FxSmallDone:
        rts

; ---------------------------------------------------------------------
; truck1_Istrat 0A:E5B5: HP 16 AP 8, shadow, enemy1, count 60 (never
; counted). Tick 0A:E5E4: z += pviewvelz, z - 35.
M4V3StratTruck1:
        move.l #M4V3Truck1Tick,32(a0)
        moveq #16,d0
        moveq #8,d1
        bsr M4V3CarInit
        bset #F2_SHADOW,48(a0)
        move.b #60,19(a0)
M4V3Truck1Tick:
        jsr M4EnAddPZ
        subi.w #35,4(a0)
        bra M4V3Keep

; truck2_Istrat 0A:E5F5: HP 16 AP 8, vel 60, sbyte1 50, shadow, enemy1.
; Tick 0A:E628: roty = sin(sbyte1)/4, sbyte1 + 6, skidy Achase8_3 -> roty,
; v = gen_3dvecs(vel, rotx, skidy), vz = -35, pos += v, z += pviewvelz.
M4V3StratTruck2:
        move.l #M4V3Truck2Tick,32(a0)
        moveq #16,d0
        moveq #8,d1
        bsr M4V3CarInit
        move.b #60,15(a0)
        move.b #50,36(a0)
        bset #F2_SHADOW,48(a0)
M4V3Truck2Tick:
        move.b 36(a0),d0
        moveq #2,d1
        bsr M4V3SinShift
        move.b d0,13(a0)
        addq.b #6,36(a0)
        bsr M4V3SkidVec
        move.w #-35,10(a0)
        jsr M4EnMove
        jsr M4EnAddPZ
        bra M4V3Keep

; ---------------------------------------------------------------------
; roadline_istrat 09:C54F: colldisable, shadowshape ($1D bit 2: drawn as a
; flat shadow; visual flag not modelled by the port), al_type gnd. Keeps
; its strategy pointer (re-run each tick, idempotent).
M4V3StratRoadline:
        bset #SF_COLLDISABLE,49(a0)
        ori.b #1,45(a0)
        bra M4V3Keep

; colonyexit_Istrat 0A:F235 (map 0D:E188) is already ported as M4TnColonyExit
; (level_armada_tunnel.asm, also used by Space Armada): not duplicated.

; ---------------------------------------------------------------------
; wallleftright_istrat 09:9108: animframe $80, hitflash / explode, HP $FF AP
; $10, roty $80, colframe $80. Tick 09:9133: HF1 not set -> colframe + 1
; modulo 4 and every 16 gameframes animframe ^= 1 (opening side); then as
; walll/wallr: distXZ(player) < 600 -> open (09:9224, M4VpWallDist,
; level_venom_planet.asm). HF1 is never cleared here.
M4V3StratWallLR:
        move.b #$80,16(a0)
        move.l #M4V3WallLRTick,32(a0)
        jsr M4LvNormPtrs
        move.b #$ff,38(a0)
        move.b #$10,39(a0)
        move.b #$80,13(a0)
        move.b #$80,18(a0)
M4V3WallLRTick:
        btst #0,20(a0)
        bne M4V3WallLRDist
        move.b 18(a0),d0
        moveq #4,d1
        jsr M4MtAfInc
        move.b d0,18(a0)
        move.b M4_LV_GAMEFRAME+1,d0
        andi.b #$0f,d0
        bne M4V3WallLRDist
        eori.b #1,16(a0)
M4V3WallLRDist:
        jmp M4VpWallDist

; ---------------------------------------------------------------------
; wireman 08:D249: HP 4 AP $10. 08:D257 (wireman_init, also re-entered):
; shadow, strategy D282, hitflash / expstrat D3E9, vel 40. D282: $1534 = 0;
; rotx, roty toward the player (Xanglexy 1F:D03E / -Yanglexy 1F:D021, inline
; Achase8_2); distXZ < 1500 -> D331; D307: y < 0 -> move (gen_3dvecs, pos +=
; v, z += pviewvelz), else D3BE: strategy D3DC, y 0, rotx $F0, sbyte1 30;
; D3DC: sbyte1 0 -> D257, else - 1 and move. D331: sbyte1 $20, strategy
; D3AA; random_l >= $7F -> strategy D38F and a second random_l >= $7F ->
; strategy D374 (below $7F: this tick runs D374 but the pointer stays
; D38F). D374: roty, rotz + 4; D38F: roty, rotz - 4; D3AA: rotx - 4; each
; then sbyte1 0 -> D257, else - 1 and D307.
M4V3StratWireman:
        move.b #4,38(a0)
        move.b #$10,39(a0)
M4V3WireInit:
        bset #F2_SHADOW,48(a0)
        move.l #M4V3WireTick,32(a0)
        move.l #M4LcHitFlash,X_COLL(a0)
        move.l #M4V3WireDie,X_EXP(a0)
        move.b #40,15(a0)
M4V3WireTick:
        clr.b M4_VP_1534
        movea.l a1,a2
        jsr M4EnPitchTo
        move.b d0,d1
        move.b 12(a0),d0
        moveq #2,d2
        jsr M4EnChase8
        move.b d0,12(a0)
        jsr M4EnYawTo
        move.b d0,d1
        move.b 13(a0),d0
        moveq #2,d2
        jsr M4EnChase8
        move.b d0,13(a0)
        jsr M4EnDistXZ
        subi.w #1500,d0
        bmi M4V3WireTurn
M4V3WireCont:
        tst.w 2(a0)
        bmi M4V3WireMove
        move.l #M4V3WireUp,32(a0)
        clr.w 2(a0)
        move.b #$f0,12(a0)
        move.b #30,36(a0)
M4V3WireUp:
        tst.b 36(a0)
        beq M4V3WireInit
        subq.b #1,36(a0)
M4V3WireMove:
        jsr M4EnGen3d
        jsr M4EnMove
        jsr M4EnAddPZ
        bra M4V3Keep
M4V3WireTurn:
        move.b #$20,36(a0)
        move.l #M4V3WireX,32(a0)
        jsr M4IntroRandom
        cmpi.b #$7f,d0
        blo M4V3WireX
        move.l #M4V3WireYR,32(a0)
        jsr M4IntroRandom
        cmpi.b #$7f,d0
        blo M4V3WireYL
        move.l #M4V3WireYL,32(a0)
M4V3WireYL: ;08:D374
        addq.b #4,13(a0)
        addq.b #4,14(a0)
        bra M4V3WireCount
M4V3WireYR: ;08:D38F
        subq.b #4,13(a0)
        subq.b #4,14(a0)
        bra M4V3WireCount
M4V3WireX: ;08:D3AA
        subq.b #4,12(a0)
M4V3WireCount:
        tst.b 36(a0)
        beq M4V3WireInit
        subq.b #1,36(a0)
        bra M4V3WireCont
; Expstrat 08:D3E9: item_6 C4B0 (make_obj) with strategy item6 08:D5F0 at
; this position, then explode 06:F45F. item6 is ported by another unit:
; found through M4LevelFindStrategy (none yet: the item has no strategy).
M4V3WireDie:
        move.w #$c4b0,d0
        bsr M4V3Make
        beq M4V3WireExplode
        move.l a2,-(sp)
        move.l #$08d5f0,d0
        jsr M4LevelFindStrategy
        move.l a2,d0
        movea.l (sp)+,a2
        move.l d0,32(a2)
        move.l (a0),(a2)
        move.w 4(a0),4(a2)
M4V3WireExplode:
        jmp M4LevelExplode

; ---------------------------------------------------------------------
; barrier_istrat 09:CB7F (shape barrier C9B8; created by aircar2 and the
; madtrucker): collstrat 09:CC3A, expstrat explode, HP 6 AP 12, roty $80,
; animframe $80, vy 0. Tick CBC8: dfallyvec 09:80CF: vy + 4; y >= 0 -> y 0,
; vy = trunc0(-vy / 4) (-5..-1 -> 0), C when it is 0 then; no C: y += vy.
; C: strategy CBE7: animframe + 1 modulo 16, at 15 -> strategy CC19:
; animframe + 1 (13 when not N(f - 13)), & $7F, >= 16 -> - 16 + 13.
; Collstrat CC3A: hitflags & DP $01 (x1fract: "s_test_hitflags x,HF1"
; without '#', read as a direct-page byte; the game code never writes it
; [H]: taken as 0, so the barrier is always nohitaffect) -> hitflash.
M4V3StratBarrier:
        move.l #M4V3BarrierTick,32(a0)
        move.l #M4V3BarrierHit,X_COLL(a0)
        move.l #M4LevelExplode,X_EXP(a0)
        move.b #6,38(a0)
        move.b #12,39(a0)
        move.b #$80,13(a0)
        move.b #$80,16(a0)
        clr.w 8(a0)
M4V3BarrierTick:
        bsr M4V3FallYVec
        bcs M4V3BarrierLand
        move.w 8(a0),d0
        add.w d0,2(a0)
        bra M4V3Keep
M4V3BarrierLand:
        move.l #M4V3BarrierOpen,32(a0)
M4V3BarrierOpen:
        move.b 16(a0),d0
        moveq #16,d1
        jsr M4MtAfInc
        move.b d0,d1
        andi.b #$7f,d1
        cmpi.b #15,d1
        beq M4V3BarrierOpened
        move.b d0,16(a0)
        bra M4V3Keep
M4V3BarrierOpened:
        move.b #$8f,16(a0)
        move.l #M4V3BarrierLoop,32(a0)
M4V3BarrierLoop:
        move.b 16(a0),d0
        addq.b #1,d0
        cmpi.b #13,d0
        bmi M4V3BarrierLoop1
        moveq #13,d0
M4V3BarrierLoop1:
        andi.b #$7f,d0
        cmpi.b #16,d0
        blo M4V3BarrierLoop2
        subi.b #16-13,d0
M4V3BarrierLoop2:
        ori.b #$80,d0
        move.b d0,16(a0)
        bra M4V3Keep
M4V3BarrierHit:
        bset #SF_NOHITAFFECT,49(a0) ;hitflags & DP $01 (0) = 0
        jmp M4LcHitFlash
; dfallyvec_x 09:80CF: C set (and vy 0) when landed with no bounce left.
M4V3FallYVec:
        addq.w #4,8(a0)
        tst.w 2(a0)
        bmi M4V3FallAir
        clr.w 2(a0)
        move.w 8(a0),d0
        neg.w d0
        bsr M4V3Div2
        bsr M4V3Div2
        cmpi.w #$fffb,d0
        blo M4V3FallVy
        moveq #0,d0
M4V3FallVy:
        move.w d0,8(a0)
        tst.b d0
        bne M4V3FallAir
        ori.b #1,ccr
        rts
M4V3FallAir:
        andi.b #$fe,ccr
        rts

M4V3Keep:
        moveq #0,d0
        rts

; ---------------------------------------------------------------------
; Helpers of the colony bikes and the trucker (bank 09).
; truck_accel 09:8127: d0.w = (z +/- K) - player.z (N of the ROM cmp):
; N -> sword1 + 1 (kept when negative, else at most 10); else sword1 - 2
; (kept when >= 0 or >= -20 unsigned, else -20); z += sword1.
M4V3TruckAccel:
        tst.w d0
        bpl M4V3TaSlow
        move.w 40(a0),d0
        addq.w #1,d0
        bmi M4V3TaStore
        cmpi.w #10,d0
        blo M4V3TaStore
        moveq #10,d0
        bra M4V3TaStore
M4V3TaSlow:
        move.w 40(a0),d0
        subq.w #2,d0
        bpl M4V3TaStore
        cmpi.w #$ffec,d0
        bhs M4V3TaStore
        move.w #-20,d0
M4V3TaStore:
        move.w d0,40(a0)
        add.w d0,4(a0)
        rts

; s_float x,64 06:B802 (y part; the x part is undone by the caller's
; push/pull): y += trunc0(s8(SINtab[$156C + lo8(al1pt)]) / 8). $156C
; (06:82B0, + 8 per frame while playerflymode bit 4) is M4_PM_156B+1.
M4V3FloatY:
        jsr M4B1Al1pt
        add.b M4_PM_156B+1,d1
        move.b d1,d0
        moveq #3,d1
        bsr M4V3SinShift
        ext.w d0
        add.w d0,2(a0)
        rts

; Allocation "behind dummyobj" ($156D): the ROM links such objects right
; after the dummy, which sits after every map object (oracle allst). The
; port has no dummy: before the oldest object made this way (X_V3FL bit 7),
; or at the tail. -> a2 (Z on failure), ROM shape header d0.w.
X_V3FL equ -$8000+50 ;.b unit flags: bit1 = ROM $1F sflag6; bit7 = dummy child
X_V3F1E equ -$8000+51 ;.b ROM $1E sflags2 bits without port copy (sflag8 $80)
M4V3MakeDummy:
        movem.l d1/a0/a3,-(sp)
        move.w d0,-(sp)
        lea M4_LV_HEAD-X_NEXT,a3
M4V3MdNext:
        move.w X_NEXT(a3),d1
        beq M4V3MdAt
        movea.w d1,a0
        btst #7,X_V3FL(a0)
        bne M4V3MdAt
        movea.l a0,a3
        bra M4V3MdNext
M4V3MdAt:
        move.l M4_LV_CREATOR,-(sp)
        move.l a3,M4_LV_CREATOR
        cmpa.l #M4_LV_HEAD-X_NEXT,a3
        bne M4V3MdLink
        clr.l M4_LV_CREATOR
M4V3MdLink:
        movea.l (sp)+,a3 ;old creator
        move.w (sp)+,d0
        bsr M4V3Make
        move.l a3,M4_LV_CREATOR
        cmpa.w #0,a2
        beq M4V3MdDone
        bset #7,X_V3FL(a2)
M4V3MdDone:
        movem.l (sp)+,d1/a0/a3
        cmpa.w #0,a2
        rts

; sgenspark 0B:AC5E at (d3, d4, d5), made behind dummyobj: unless pshipflags2
; ($14D9) bit 2, spark B2C1, strategy 0B:AC1B, colldisable, facing the camera
; (roty = -outvy + $80 + turnrot, rotx = outvx), rotz = random_l, count 5,
; vel 15, (vx, vy) = gen2d(15, rotz) (1F:C177 results $02/$90). Its Istrat
; AC1B (next pass: linked after the dummy): colframe $80, strategy AC30:
; colframe + 2 modulo 16, z += pviewvelz, pos += v, count - 1 -> removed.
M4V3GenSpark:
        btst #2,M4_LP_PSF2
        bne M4V3GsDone
        move.l a2,-(sp)
        move.w #$b2c1,d0
        bsr M4V3MakeDummy
        beq M4V3GsFail
        move.l #M4V3SparkI,32(a2)
        bset #SF_COLLDISABLE,49(a2)
        exg a0,a2
        jsr M4EnFaceCamera
        movem.w d3-d5,(a0)
        jsr M4IntroRandom
        move.b d0,14(a0)
        move.b #5,19(a0)
        move.b #15,15(a0)
        move.b 13(a0),-(sp)
        move.w 10(a0),-(sp)
        move.b d0,13(a0)
        jsr M4EnGen2d
        move.w 10(a0),8(a0)
        move.w (sp)+,10(a0)
        move.b (sp)+,13(a0)
        exg a0,a2
M4V3GsFail:
        movea.l (sp)+,a2
M4V3GsDone:
        rts
M4V3SparkI:
        move.b #$80,18(a0)
        move.l #M4V3SparkTick,32(a0)
        bra M4V3Keep
M4V3SparkTick: ;add_anim(2, 16) on colframe
        move.b 18(a0),d0
        addq.b #2,d0
        bmi M4V3SparkMod
        addi.b #16,d0
M4V3SparkMod:
        andi.b #$7f,d0
        cmpi.b #16,d0
        blo M4V3SparkSet
        subi.b #16,d0
M4V3SparkSet:
        ori.b #$80,d0
        move.b d0,18(a0)
        jsr M4EnAddPZ
        jsr M4EnMove
        subq.b #1,19(a0)
        bne M4V3Keep
        moveq #1,d0
        rts

; ---------------------------------------------------------------------
; madbiker_istrat 09:C160 (air_1 BA84): collstrat C3B3, expstrat C3D6, HP 10
; AP 4, no zremove, animframe $87, enemy2, shadow, sword2 = y; engine flame
; (makeengine 06:916D) without zremove, tx -10, relposz -10 (relposy -5 is
; written to $1CE2 but 06:91DF only reads relposz); state 0. Strategy C1E0:
; mode table 09:C1F1 (dispatcher 09:C027: one handler per stratstate; "+1"
; 09:C017 does not dispatch again, the handler then runs .move C4EA).
M4V3StratMadbiker:
        move.l #M4V3BikeStrat,32(a0)
        move.l #M4V3BikeHit,X_COLL(a0)
        move.l #M4V3BikeExplode,X_EXP(a0)
        move.b #10,38(a0)
        move.b #4,39(a0)
        bclr #3,45(a0)
        move.b #$87,16(a0)
        ori.b #$20,44(a0)
        bset #F2_SHADOW,48(a0)
        move.w 2(a0),X_SWORD2(a0)
        jsr M4WpMakeEngine
        jsr M4WpFlameOf
        beq M4V3BikeNoEngine
        bclr #3,45(a2)
        move.b #$f6,X_TX(a2)
        move.b #$f6,X_RELPOSZ(a2)
M4V3BikeNoEngine:
        clr.b X_STATE(a0)
M4V3BikeStrat:
        moveq #0,d0
        move.b X_STATE(a0),d0
        cmpi.b #11,d0
        bhi M4V3BikeMove ;outside the table (not reached)
        add.w d0,d0
        move.w M4V3BikeModes(pc,d0.w),d0
        jmp M4V3BikeModes(pc,d0.w)
M4V3BikeModes:
        dc.w M4V3BikeAlong-M4V3BikeModes,M4V3BikeShunt-M4V3BikeModes
        dc.w M4V3BikeUp-M4V3BikeModes,M4V3BikeInitBoost-M4V3BikeModes
        dc.w M4V3BikeBoost-M4V3BikeModes,M4V3BikeAway-M4V3BikeModes
        dc.w M4V3BikeAlong-M4V3BikeModes,M4V3BikeShunt-M4V3BikeModes
        dc.w M4V3BikeWait-M4V3BikeModes,M4V3BikeAway-M4V3BikeModes
        dc.w M4V3BikeUp-M4V3BikeModes,M4V3BikeRandom-M4V3BikeModes
; 11 randomjump C22A: random_l < $E5 -> state 6, else 2; dispatched again.
M4V3BikeRandom:
        jsr M4IntroRandom
        moveq #6,d1
        cmpi.b #$e5,d0
        blo M4V3BikeRandomSet
        moveq #2,d1
M4V3BikeRandomSet:
        move.b d1,X_STATE(a0)
        bra M4V3BikeStrat
; 0/6 movealongside C23F: sflag1 -> sbyte1 7, state 9; else truck_accel
; (z - 120), sbyte2 + 1, 30 -> 0 and state + 1.
M4V3BikeAlong:
        btst #F2_SFLAG1,48(a0)
        beq M4V3BikeAlong1
        move.b #7,36(a0)
        move.b #9,X_STATE(a0)
        bra M4V3BikeMove
M4V3BikeAlong1:
        move.w 4(a0),d0
        subi.w #120,d0
        moveq #30,d1
M4V3BikeCount:
        sub.w 4(a1),d0
        bsr M4V3TruckAccel
        addq.b #1,37(a0)
        cmp.b 37(a0),d1
        bne M4V3BikeMove
        clr.b 37(a0)
        bra M4V3BikeNext
; 8 waittwosecs C280: truck_accel (z + 10), sbyte2 + 1, 8 -> 0, state + 1.
M4V3BikeWait:
        move.w 4(a0),d0
        addi.w #10,d0
        moveq #8,d1
        bra M4V3BikeCount
; 1/7 shuntplayer C2AA: sbyte1 5; sflag1 -> state + 1; else z - 15, rotz -
; 4, + 8 unless N(x - player.x); rotz 0 or (rotz + $20) >= $40 (unsigned)
; -> state + 1 and sflag2.
M4V3BikeShunt:
        move.b #5,36(a0)
        btst #F2_SFLAG1,48(a0)
        bne M4V3BikeNext
        subi.w #15,4(a0)
        subq.b #4,14(a0)
        move.w (a0),d0
        cmp.w (a1),d0
        bmi M4V3BikeShunt1
        addq.b #8,14(a0)
M4V3BikeShunt1:
        move.b 14(a0),d0
        beq M4V3BikeShunt2
        addi.b #$20,d0
        cmpi.b #$40,d0
        blo M4V3BikeMove
M4V3BikeShunt2:
        bset #F2_SFLAG2,48(a0)
        bra M4V3BikeNext
; 5/9 awayfromplayer C30F: sflag2 -> cleared, state + 1; else z + 10,
; sbyte4 = 8 (-8 unless N(x - player.x)), rotz += sbyte4, sbyte1 - 1 -> 0:
; state + 1.
M4V3BikeAway:
        btst #F2_SFLAG2,48(a0)
        beq M4V3BikeAway1
        bclr #F2_SFLAG2,48(a0)
        bra M4V3BikeNext
M4V3BikeAway1:
        addi.w #10,4(a0)
        move.b #8,X_SBYTE4(a0)
        move.w (a0),d0
        cmp.w (a1),d0
        bmi M4V3BikeAway2
        move.b #$f8,X_SBYTE4(a0)
M4V3BikeAway2:
        move.b X_SBYTE4(a0),d0
        add.b d0,14(a0)
        subq.b #1,36(a0)
        bne M4V3BikeMove
        bra M4V3BikeNext
; 2/10 rightwayup C363: rotz 0 -> state + 1; negative + 4, else - 4.
M4V3BikeUp:
        move.b 14(a0),d0
        beq M4V3BikeNext
        bmi M4V3BikeUpNeg
        subq.b #8,d0
M4V3BikeUpNeg:
        addq.b #4,d0
        move.b d0,14(a0)
        bra M4V3BikeMove
; 3 initboost C379: state + 1 and the doboost code now.
M4V3BikeInitBoost:
        addq.b #1,X_STATE(a0)
; 4 doboost C37F: sflag1 -> sbyte1 7, state + 1; else z + 20, sbyte1 0 ->
; sflag2 and state + 1, else sbyte1 - 1.
M4V3BikeBoost:
        btst #F2_SFLAG1,48(a0)
        beq M4V3BikeBoost1
        move.b #7,36(a0)
        bra M4V3BikeNext
M4V3BikeBoost1:
        addi.w #20,4(a0)
        tst.b 36(a0)
        beq M4V3BikeBoost2
        subq.b #1,36(a0)
        bra M4V3BikeMove
M4V3BikeBoost2:
        bset #F2_SFLAG2,48(a0)
M4V3BikeNext:
        addq.b #1,X_STATE(a0)
; .move C4EA: x += asr2(-rotz) (8-bit floor shifts, sign-extended); sword2
; Fchase 1 toward player.y, y = sword2, float (y part); z += pviewvelz;
; boundscheck C4AD: not N(x + 15 - maxpmoveX $1573) -> x = $1573 - 16, a
; spark at (x + 15, y, z) (dummyobj, sgenspark 0B:AC5E), rotz + 8; sflag1
; cleared; updateengine 06:91DF.
M4V3BikeMove:
        move.b 14(a0),d0
        neg.b d0
        asr.b #2,d0
        ext.w d0
        add.w d0,(a0)
        move.w X_SWORD2(a0),d0
        move.w 2(a1),d1
        cmp.w d1,d0
        beq M4V3BikeFloat
        bmi M4V3BikeUpY
        subq.w #2,d0
M4V3BikeUpY:
        addq.w #1,d0
M4V3BikeFloat:
        move.w d0,X_SWORD2(a0)
        move.w d0,2(a0)
        bsr M4V3FloatY
        jsr M4EnAddPZ
        move.w (a0),d0
        addi.w #15,d0
        sub.w M4_LP_MAXX,d0
        bmi M4V3BikeInBounds
        move.w M4_LP_MAXX,d3
        subi.w #16,d3
        move.w d3,(a0)
        addi.w #15,d3
        move.w 2(a0),d4
        move.w 4(a0),d5
        bsr M4V3GenSpark
        addq.b #8,14(a0)
M4V3BikeInBounds:
        bclr #F2_SFLAG1,48(a0)
        jsr M4WpUpdateEngine
        bra M4V3Keep

; .hit C3B3: sflag1; nohitaffect unless the collider ($1B) has collflag
; weapon ($02, gen_weapon 06:B55A: player lasers, bombs); then hitflash.
M4V3BikeHit:
        bset #F2_SFLAG1,48(a0)
        bclr #SF_NOHITAFFECT,49(a0)
        jsr M4LcCollider
        move.l a2,d0
        beq M4V3BikeNoWeapon ;no collider: the ROM reads DP $2E [H]
        btst #1,44(a2)
        bne M4V3BikeHitDo
M4V3BikeNoWeapon:
        bset #SF_NOHITAFFECT,49(a0)
M4V3BikeHitDo:
        jmp M4LcHitFlash

; .explode C3D6: strategy C3FA, hitflash / explode, sword2 0, HP 1, enemy2
; cleared. C3FA: z -= sword2, sword2 + 3, vy + 4; on the ground (not N(y +
; 25)): y = -25, vy = trunc0(-vy / 2) (-5..-1 -> 0), low byte 0 -> explode
; 06:F45F now; then z += pviewvelz, y += vy, rotx + 4; sflag6 ($1F bit 1):
; rotx + $18, below $18 (unsigned) -> colldisable and HP 0 (expstrat next
; tick); not N(y + 25) -> sflag6. explode_Istrat 06:F45F removes the
; engine flame first (afonfire, 06:F4EE): M4WpExplode.
M4V3BikeExplode:
        move.l #M4V3BikeWreck,32(a0)
        jsr M4LvNormPtrs
        move.l #M4WpExplode,X_EXP(a0) ;06:F45F with afonfire: the flame goes first (06:F4EE)
        clr.w X_SWORD2(a0)
        move.b #1,38(a0)
        andi.b #$df,44(a0)
M4V3BikeWreck:
        move.w X_SWORD2(a0),d0
        sub.w d0,4(a0)
        addq.w #3,X_SWORD2(a0)
        addq.w #4,8(a0)
        move.w 2(a0),d0
        addi.w #25,d0
        bmi M4V3BikeWreckAir
        move.w #-25,2(a0)
        move.w 8(a0),d0
        neg.w d0
        bsr M4V3Div2
        cmpi.w #$fffb,d0
        blo M4V3BikeWreckVy
        moveq #0,d0
M4V3BikeWreckVy:
        move.w d0,8(a0)
        tst.b d0
        bne M4V3BikeWreckAir
        jmp M4WpExplode
M4V3BikeWreckAir:
        jsr M4EnAddPZ
        move.w 8(a0),d0
        add.w d0,2(a0)
        addq.b #4,12(a0)
        btst #1,X_V3FL(a0)
        beq M4V3BikeNoFlip
        addi.b #$18,12(a0)
        cmpi.b #$18,12(a0)
        bhs M4V3BikeNoFlip
        bset #SF_COLLDISABLE,49(a0)
        clr.b 38(a0)
        bra M4V3Keep
M4V3BikeNoFlip:
        move.w 2(a0),d0
        addi.w #25,d0
        bmi M4V3Keep
        bset #1,X_V3FL(a0)
        bra M4V3Keep

; ---------------------------------------------------------------------
; Helpers of the madtrucker (09:AE35.. "fling" routines).
; fling.positional 09:AED4 on a2: pos = a0.pos + 4 * rot(d3, d4, d5) (BYTE
; offsets x/y/z, a0's rotz 1F:CC78, rotx 1F:CAFB, roty 1F:C97B, x4: the
; gen_weapon chain M4WeaponOffset).
M4V3Positional:
        move.l a2,-(sp)
        movea.l a0,a2
        jsr M4WeaponOffset
        movea.l (sp)+,a2
        add.w (a0),d3
        add.w 2(a0),d4
        add.w 4(a0),d5
        movem.w d3-d5,(a2)
        rts
; fling.copyrots_yx 09:AF6B (1F:DB01): a2.rot = a0.rot.
M4V3CopyRots:
        move.w 12(a0),12(a2)
        move.b 14(a0),14(a2)
        rts
; find_y_l 09:B1FF: first object of allst (from the head) whose shape is the
; header d1.w -> a2, or 0 (the ROM returns dummyobj). The port header is the
; descriptor's (X_SHAPEHDR is stale once the shape changes), else X_SHAPEHDR.
M4V3FindShape:
        move.w M4_LV_HEAD,d0
M4V3FsNext:
        beq M4V3FsNone
        movea.w d0,a2
        move.w 46(a2),d0
        cmpi.w #$ffff,d0
        bne M4V3FsDesc
        move.w X_SHAPEHDR(a2),d0 ;not catalogued: original header (0: nullshape/none)
        bra M4V3FsCmp
M4V3FsDesc:
        lsl.w #5,d0
        move.l a3,-(sp)
        lea M4LevelShapeDescriptors,a3
        move.w 16(a3,d0.w),d0
        movea.l (sp)+,a3
M4V3FsCmp:
        cmp.w d0,d1
        beq M4V3FsFound
        move.w X_NEXT(a2),d0
        bra M4V3FsNext
M4V3FsNone:
        suba.l a2,a2
M4V3FsFound:
        cmpa.w #0,a2
        rts

; d0.w = original shape header of a0 (descriptor's, else X_SHAPEHDR).
M4V3HeaderOf:
        move.w 46(a0),d0
        cmpi.w #$ffff,d0
        bne M4V3HoDesc
        move.w X_SHAPEHDR(a0),d0
        rts
M4V3HoDesc:
        move.l a3,-(sp)
        lsl.w #5,d0
        lea M4LevelShapeDescriptors,a3
        move.w 16(a3,d0.w),d0
        movea.l (sp)+,a3
        rts

; ---------------------------------------------------------------------
; madtrucker_istrat 09:C562 (boss_9_5 C99C, map 05:98EC): maptrigger $176F =
; 0, HP $40 AP 2, no zremove, animframe $80, enemy1, shadow; .generate C8BC:
; trailer boss_9_0 C980 (make_obj; failure: the Istrat returns and runs
; again next tick) with strategy hard 06:8599, animframe $80, no zremove,
; enemy1, al_ptr = trailer, placed by .position1 C8FA (copy_rots, offset (0,
; 0, -19) x4); strategy C5CF, collstrat C96A, expstrat C9D9, state 0, boss
; bar maximum $40 and m_bossHP 0. C5CF: mode table 09:C5E0 (17 states; the
; ".nxtmode" C68F is state + 1 and a new dispatch in the same tick).
M4V3StratTrucker:
        clr.b M4_MV_176F
        move.b #$40,38(a0)
        move.b #2,39(a0)
        bclr #3,45(a0)
        move.b #$80,16(a0)
        ori.b #CF_ENEMY1,44(a0)
        bset #F2_SHADOW,48(a0)
        move.w #$c980,d0
        bsr M4V3Make
        beq M4V3Keep
        move.l #M4StratHard,32(a2)
        move.b #$80,16(a2)
        bclr #3,45(a2)
        ori.b #CF_ENEMY1,44(a2)
        move.w a2,X_ALPTR(a0)
        bsr M4V3TrailerPos
        move.l #M4V3TruckStrat,32(a0)
        move.l #M4V3TruckHit,X_COLL(a0)
        move.l #M4V3TruckExplode,X_EXP(a0)
        clr.b X_STATE(a0)
        move.b #$40,M4_BOSS_MAXHP
        clr.b M4_BOSS_HP
M4V3TruckStrat:
        moveq #0,d0
        move.b X_STATE(a0),d0
        cmpi.b #16,d0
        bhi M4V3TruckMove ;outside the table (not reached)
        add.w d0,d0
        move.w M4V3TruckModes(pc,d0.w),d0
        jmp M4V3TruckModes(pc,d0.w)
M4V3TruckModes:
        dc.w M4V3TkBarge-M4V3TruckModes,M4V3TkBikes-M4V3TruckModes
        dc.w M4V3TkOpen-M4V3TruckModes,M4V3TkLeft-M4V3TruckModes
        dc.w M4V3TkClose-M4V3TruckModes,M4V3TkFarLeft-M4V3TruckModes
        dc.w M4V3TkWaitBikes-M4V3TruckModes,M4V3TkForward-M4V3TruckModes
        dc.w M4V3TkBumpUp-M4V3TruckModes,M4V3TkMines-M4V3TruckModes
        dc.w M4V3TkWait4-M4V3TruckModes,M4V3TkBumpDown-M4V3TruckModes
        dc.w M4V3TkChkBikes-M4V3TruckModes,M4V3TkHangBack-M4V3TruckModes
        dc.w M4V3TkWait3-M4V3TruckModes,M4V3TkFarLeft3-M4V3TruckModes
        dc.w M4V3TkRepeat-M4V3TruckModes
M4V3TkNext: ;C68F
        addq.b #1,X_STATE(a0)
        bra M4V3TruckStrat
; 0 bargeforward C876: rightlane C69F (x < 30 or negative: x + 2) -> move2;
; already there -> next.
M4V3TkBarge:
        bsr M4V3RightLane
        bcs M4V3TkNext
        bra M4V3TkMove2
; 1 maketwobikes C80E: two air_1 BA84 (make_obj, copy_rots) with strategy
; bike2 09:C127 at offsets (7, 10, 0) and (-7, 10, 0); a failure skips the
; rest; then next.
M4V3TkBikes:
        moveq #7,d3
        bsr M4V3TkBike
        beq M4V3TkNext
        moveq #-7,d3
        bsr M4V3TkBike
        bra M4V3TkNext
M4V3TkBike:
        move.w d3,-(sp)
        move.w #$ba84,d0
        bsr M4V3Make
        move.w (sp)+,d3
        cmpa.w #0,a2
        beq M4V3TkBikeFail
        bsr M4V3CopyRots
        move.l #M4V3StratBike2,32(a2)
        moveq #10,d4
        moveq #0,d5
        bsr M4V3Positional
        moveq #1,d0 ;Z clear
M4V3TkBikeFail:
        rts
; 2 openup C6D1: openback C6DE -> next when done, else move.
M4V3TkOpen:
        bsr M4V3OpenBack
        bcs M4V3TkNext
        bra M4V3TruckMove
; 3 moveleftlane C775: leftlane C6B8 -> next when done, else move2.
M4V3TkLeft:
        bsr M4V3LeftLane
        bcs M4V3TkNext
        bra M4V3TkMove2
; 4 close C714: closeback C721 -> next when closed, else move.
M4V3TkClose:
        bsr M4V3CloseBack
        bcs M4V3TkNext
        bra M4V3TruckMove
; 5 movefarleft C75B: farleftlane C782 -> next, else move2.
M4V3TkFarLeft:
        bsr M4V3FarLeft
        bcs M4V3TkNext
        bra M4V3TkMove2
; 6 waitforbikes C7A2: random_l < 2 -> next; an air_1 left -> move2; none ->
; state 13 (madbikesdead) and dispatch.
M4V3TkWaitBikes:
        jsr M4IntroRandom
        cmpi.b #2,d0
        blo M4V3TkNext
        move.w #$ba84,d1
        bsr M4V3FindShape
        bne M4V3TkMove2
        move.b #13,X_STATE(a0)
        bra M4V3TruckStrat
; 7 movefarforward C624: |pz - z| >= 1200 -> sflag1 toggled, next; else
; rightlane (sflag1: leftlane) and move4.
M4V3TkForward:
        bsr M4V3PlayerZD
        cmpi.w #1200,d0
        bpl M4V3TkForwardNext
        btst #F2_SFLAG1,48(a0)
        bne M4V3TkForwardL
        bsr M4V3RightLane
        bra M4V3TkMove4
M4V3TkForwardL:
        bsr M4V3LeftLane
        bra M4V3TkMove4
M4V3TkForwardNext:
        bchg #F2_SFLAG1,48(a0)
        bra M4V3TkNext
; 8 bumpitup C7D0: y - 2, openback three times (carry of the last) -> next,
; else move.
M4V3TkBumpUp:
        subq.w #2,2(a0)
        bsr M4V3OpenBack
        bsr M4V3OpenBack
        bsr M4V3OpenBack
        bcs M4V3TkNext
        bra M4V3TruckMove
; 9 dropmines C652: barrier C9B8 (make_obj, copy_rots, strategy 09:CB7F) at
; offset (0, 0, -40); next.
M4V3TkMines:
        move.w #$c9b8,d0
        bsr M4V3Make
        beq M4V3TkNext
        bsr M4V3CopyRots
        move.l #M4V3StratBarrier,32(a2)
        moveq #0,d3
        moveq #0,d4
        moveq #-40,d5
        bsr M4V3Positional
        bra M4V3TkNext
; 10 waitabit4 C8AA: sbyte1 + 1; 15 -> 0 and next; else move4.
M4V3TkWait4:
        addq.b #1,36(a0)
        cmpi.b #15,36(a0)
        bne M4V3TkMove4
        clr.b 36(a0)
        bra M4V3TkNext
; 11 bumpitdown C7EF: y + 2, closeback three times -> next, else move.
M4V3TkBumpDown:
        addq.w #2,2(a0)
        bsr M4V3CloseBack
        bsr M4V3CloseBack
        bsr M4V3CloseBack
        bcs M4V3TkNext
        bra M4V3TruckMove
; 12 chkbikesagain C7C7: state 6 and dispatch.
M4V3TkChkBikes:
        move.b #6,X_STATE(a0)
        bra M4V3TruckStrat
; 13 hangback C882: rightlane; there -> maptrigger | 1 and next; else move3.
M4V3TkHangBack:
        bsr M4V3RightLane
        bcc M4V3TkMove3
        bset #0,M4_MV_176F
        bra M4V3TkNext
; 14 waitabit3 C897: sbyte1 + 1; 55 -> 0 and next; else move3.
M4V3TkWait3:
        addq.b #1,36(a0)
        cmpi.b #55,36(a0)
        bne M4V3TkMove3
        clr.b 36(a0)
        bra M4V3TkNext
; 15 movefarleft3 C768: farleftlane -> next, else move3.
M4V3TkFarLeft3:
        bsr M4V3FarLeft
        bcs M4V3TkNext
        bra M4V3TkMove3
; 16 repeat C686: state 0 and dispatch.
M4V3TkRepeat:
        clr.b X_STATE(a0)
        bra M4V3TruckStrat

; .move3 C921: truck_accel(z - 120); N(z - 50 - pz) -> z = pz + 50.
M4V3TkMove3:
        move.w 4(a0),d0
        subi.w #120,d0
        sub.w 4(a1),d0
        bsr M4V3TruckAccel
        move.w 4(a0),d0
        subi.w #50,d0
        sub.w 4(a1),d0
        bpl M4V3TruckMove
        move.w 4(a1),d0
        addi.w #50,d0
        move.w d0,4(a0)
        bra M4V3TruckMove
; .move2 C956 / .move4 C90D: truck_accel(z - 600 / z - 1200).
M4V3TkMove2:
        move.w #600,d1
        bra M4V3TkAccel
M4V3TkMove4:
        move.w #1200,d1
M4V3TkAccel:
        move.w 4(a0),d0
        sub.w d1,d0
        sub.w 4(a1),d0
        bsr M4V3TruckAccel
; .move C9C4: z += pviewvelz; .nomove C9C8: trailer placed (.position1),
; m_bossHP += HP.
M4V3TruckMove:
        jsr M4EnAddPZ
M4V3TruckNoMove:
        bsr M4V3TrailerPos
        move.b 38(a0),d0
        add.b d0,M4_BOSS_HP
        bra M4V3Keep
; .position1 C8FA on the trailer (al_ptr): copy_rots, offset (0, 0, -19).
M4V3TrailerPos:
        move.w X_ALPTR(a0),d0
        beq M4V3TrailerNone ;the ROM writes object 0 [not reproduced]
        movea.w d0,a2
        bsr M4V3CopyRots
        moveq #0,d3
        moveq #0,d4
        moveq #-19,d5
        bra M4V3Positional
M4V3TrailerNone:
        rts

; Lanes. rightlane C69F: x < 0 or x < 30: x + 2, C clear; else C set.
M4V3RightLane:
        move.w (a0),d0
        bmi M4V3RlMove
        cmpi.w #30,d0
        bhs M4V3LaneSet
M4V3RlMove:
        addq.w #2,(a0)
        bra M4V3LaneClr
; leftlane C6B8: x >= 0, or x >= -70 (unsigned $FFBA): x - 4, C clear; else
; C set.
M4V3LeftLane:
        move.w (a0),d0
        bpl M4V3LlMove
        cmpi.w #$ffba,d0
        blo M4V3LaneSet
M4V3LlMove:
        subq.w #4,(a0)
        bra M4V3LaneClr
; farleftlane C782: x < -160 (negative, below $FF60 unsigned): maptrigger | 1,
; C set; else x - 5, C clear.
M4V3FarLeft:
        move.w (a0),d0
        bpl M4V3FlMove
        cmpi.w #$ff60,d0
        bhs M4V3FlMove
        bset #0,M4_MV_176F
        bra M4V3LaneSet
M4V3FlMove:
        subq.w #5,(a0)
M4V3LaneClr:
        andi.b #$fe,ccr
        rts
M4V3LaneSet:
        ori.b #1,ccr
        rts
; openback C6DE (trailer animframe; sound at 1 not ported): + 1, at 13 ->
; animframe 12 and C set; else C clear.
M4V3OpenBack:
        move.w X_ALPTR(a0),d0
        beq M4V3LaneClr ;[not reproduced: the ROM uses object 0]
        movea.w d0,a2
        move.b 16(a2),d0
        addq.b #1,d0
        bmi M4V3ObMod
        addi.b #13,d0
M4V3ObMod:
        andi.b #$7f,d0
        cmpi.b #13,d0
        bhs M4V3ObDone
        ori.b #$80,d0
        move.b d0,16(a2)
        bra M4V3LaneClr
M4V3ObDone:
        move.b #$8c,16(a2)
        bra M4V3LaneSet
; closeback C721 (sound at 10 not ported): animframe & $7F 0 -> C set; else
; - 1 modulo 16 (C from the final cmp/sbc: set only when >= 16).
M4V3CloseBack:
        move.w X_ALPTR(a0),d0
        beq M4V3LaneClr
        movea.w d0,a2
        move.b 16(a2),d0
        andi.b #$7f,d0
        beq M4V3LaneSet
        move.b 16(a2),d0
        subq.b #1,d0
        bmi M4V3CbMod
        addi.b #16,d0
M4V3CbMod:
        andi.b #$7f,d0
        cmpi.b #16,d0
        blo M4V3CbStore
        subi.b #16,d0
        ori.b #$80,d0
        move.b d0,16(a2)
        bra M4V3LaneSet
M4V3CbStore:
        ori.b #$80,d0
        move.b d0,16(a2)
        bra M4V3LaneClr

; .hit C96A: trailer animframe & $7F = 0 -> nohitaffect; else trailer HF1
; -> cleared on the trailer, nohitaffect; else own HF2 -> cleared, damage
; (nohitaffect off); else nohitaffect. Then hitflash 06:89A3.
M4V3TruckHit:
        move.w X_ALPTR(a0),d0
        beq M4V3ThNoHit ;[ROM: object 0]
        movea.w d0,a2
        move.b 16(a2),d0
        andi.b #$7f,d0
        beq M4V3ThNoHit
        bclr #0,20(a2)
        bne M4V3ThNoHit
        bclr #1,20(a0)
        beq M4V3ThNoHit
        bclr #SF_NOHITAFFECT,49(a0)
        jmp M4LcHitFlash
M4V3ThNoHit:
        bset #SF_NOHITAFFECT,49(a0)
        jmp M4LcHitFlash

; .explode C9D9 (expstrat, HP 0): trailer zremove; expstrat CA0C, sbyte1 35
; (sounds and music $F1 not ported). CA0C each tick: sbyte1 - 1 -> 0:
; expstrat CA84, maptrigger | 2, sword1 20, bigwhiteFOsprite 06:EDFB
; (circleanim $83, circleobj 0) then circleobj = this object, and CA84 now;
; else roty = sin(gameframe << 4) / 8, farleftlane, destroybikes CB10,
; genspark CB25, .move.
M4V3TruckExplode:
        move.w X_ALPTR(a0),d0
        beq M4V3TeNoTrailer
        movea.w d0,a2
        bset #3,45(a2)
M4V3TeNoTrailer:
        move.l #M4V3TruckSwerve,X_EXP(a0)
        move.b #35,36(a0)
M4V3TruckSwerve:
        subq.b #1,36(a0)
        bne M4V3TsSwerve
        move.l #M4V3TruckSkid,X_EXP(a0)
        bset #1,M4_MV_176F
        move.w #20,40(a0)
        move.w #$83,M4_SC_CIRCLE
        move.w a0,M4_SC_CIRCLEOBJ
        bra M4V3TruckSkid
M4V3TsSwerve:
        move.b M4_LV_GAMEFRAME+1,d0
        lsl.b #4,d0
        moveq #3,d1
        bsr M4V3SinShift
        move.b d0,13(a0)
        bsr M4V3FarLeft
        bsr M4V3DestroyBike
        moveq #0,d3
        moveq #60,d4
        moveq #-30,d5
        bsr M4V3TruckSpark
        bra M4V3TruckMove
; .skid CA84: player not behind (not N(pz - z)) -> circleanim and circleobj
; 0, removed; else maptrigger | 2, roty Achase8_2 -> $D0 (not there: sword1
; 40); .flippul CAC2: x - 4, rotz + 8 until $40, z += sword1, sword1 - 15
; while not negative, destroybikes, genspark, genspark2, .nomove.
M4V3TruckSkid:
        move.w 4(a1),d0
        sub.w 4(a0),d0
        bmi M4V3TkSkid1
        clr.w M4_SC_CIRCLE
        clr.w M4_SC_CIRCLEOBJ
        moveq #1,d0
        rts
M4V3TkSkid1:
        bset #1,M4_MV_176F
        move.b 13(a0),d0
        move.b #$d0,d1
        moveq #2,d2
        jsr M4EnChase8
        move.b d0,13(a0)
        tst.b d3
        bne M4V3TkFlip
        move.w #40,40(a0)
M4V3TkFlip:
        subq.w #4,(a0)
        cmpi.b #$40,14(a0)
        beq M4V3TkFlip1
        addq.b #8,14(a0)
M4V3TkFlip1:
        move.w 40(a0),d0
        add.w d0,4(a0)
        tst.w 40(a0)
        bmi M4V3TkFlip2
        subi.w #15,40(a0)
M4V3TkFlip2:
        bsr M4V3DestroyBike
        moveq #0,d3
        moveq #60,d4
        moveq #-30,d5
        bsr M4V3TruckSpark
        moveq #50,d3
        moveq #60,d4
        moveq #-10,d5
        bsr M4V3TruckSpark
        bra M4V3TruckNoMove
; destroybikes CB10: the first air_1 of allst (find_y_l) -> colldisable, HP
; 0 (none: the ROM does it to dummyobj).
M4V3DestroyBike:
        move.w #$ba84,d1
        bsr M4V3FindShape
        beq M4V3DbNone
        bset #SF_COLLDISABLE,49(a2)
        clr.b 38(a2)
M4V3DbNone:
        rts
; genspark CB25 / CB4C: sgenspark at this object + (d3, d4, d5).
M4V3TruckSpark:
        add.w (a0),d3
        add.w 2(a0),d4
        add.w 4(a0),d5
        bra M4V3GenSpark

; bike2_istrat 09:C127 (madtrucker's bikes): every tick enemy1, animframe
; $87, z += pviewvelz, sbyte1 < 5 -> sword1 -20; z - 5; sbyte1 + 1 reaching
; 11 -> madbiker_istrat 09:C160 now.
M4V3StratBike2:
        ori.b #CF_ENEMY1,44(a0)
        move.b #$87,16(a0)
        jsr M4EnAddPZ
        cmpi.b #5,36(a0)
        bhs M4V3Bike2Z
        move.w #-20,40(a0)
M4V3Bike2Z:
        subq.w #5,4(a0)
        addq.b #1,36(a0)
        cmpi.b #11,36(a0)
        bne M4V3Keep
        bra M4V3StratMadbiker

; ---------------------------------------------------------------------
; castanet_istrat 09:CC60 (Venom 2 orbital boss, map 05:932C, nullshape
; controller): colldisable, HP $FF AP 8, enemy1, animframe $80, no
; zremove, boss bar maximum $F0 and m_bossHP 0; .generate D16F: half 1
; C9D4 (al_ptr; depthoffset 1; placed by D1DA) unless al_ptr is already
; set, half 2 C9F0 (sword1; HP 1 until its Istrat; depthoffset 2; D21B),
; both with strategy castbit 09:D281; a failure ends the Istrat (it runs
; again next tick). Then strategy CCC8, collstrat hitflash, no expstrat,
; nohitaffect, state 0. CCC8: mode table 09:CCD9 (27 states; "+1" CF07 is
; state + 1 and a new dispatch in the same tick). Fields: sbyte1 counter,
; sbyte2 half distance, sbyte3 half tilt, sflag1 vertical mode, sflags4
; $20 (X2_FL4 bit 5) rolling in. Sounds not ported.
M4V3StratCastanet:
        bset #SF_COLLDISABLE,49(a0)
        move.b #$ff,38(a0)
        move.b #8,39(a0)
        ori.b #CF_ENEMY1,44(a0)
        move.b #$80,16(a0)
        bclr #3,45(a0)
        move.b #$f0,M4_BOSS_MAXHP
        clr.b M4_BOSS_HP
        tst.w X_ALPTR(a0)
        bne M4V3CaGen2
        move.w #$c9d4,d0
        bsr M4V3Make
        beq M4V3Keep
        move.l #M4V3StratCastBit,32(a2)
        move.w a2,X_ALPTR(a0)
        move.b #1,X_DEPTHOFF(a2)
        bsr M4V3CaPlace1
M4V3CaGen2:
        move.w #$c9f0,d0
        bsr M4V3Make
        beq M4V3Keep
        move.l #M4V3StratCastBit,32(a2)
        move.w a2,40(a0)
        move.b #1,38(a2)
        move.b #2,X_DEPTHOFF(a2)
        bsr M4V3CaPlace2
        move.l #M4V3CaStrat,32(a0)
        move.l #M4LcHitFlash,X_COLL(a0)
        clr.l X_EXP(a0)
        bset #SF_NOHITAFFECT,49(a0)
        clr.b X_STATE(a0)
M4V3CaStrat:
        moveq #0,d0
        move.b X_STATE(a0),d0
        cmpi.b #26,d0
        bhi M4V3CaMove ;outside the table (not reached)
        add.w d0,d0
        move.w M4V3CaModes(pc,d0.w),d0
        jmp M4V3CaModes(pc,d0.w)
M4V3CaModes:
        dc.w M4V3CaRollInit-M4V3CaModes,M4V3CaRollOn-M4V3CaModes,M4V3CaAway-M4V3CaModes
        dc.w M4V3CaMinis-M4V3CaModes,M4V3CaApart-M4V3CaModes,M4V3CaToPlayer-M4V3CaModes
        dc.w M4V3CaSmash-M4V3CaModes,M4V3CaAway-M4V3CaModes,M4V3CaRotR-M4V3CaModes
        dc.w M4V3CaMinis-M4V3CaModes,M4V3CaApart-M4V3CaModes,M4V3CaToPlayer-M4V3CaModes
        dc.w M4V3CaSmash-M4V3CaModes,M4V3CaAway-M4V3CaModes,M4V3CaRotL-M4V3CaModes
        dc.w M4V3CaCheckHp-M4V3CaModes,M4V3CaApart-M4V3CaModes,M4V3CaAim-M4V3CaModes
        dc.w M4V3CaFire-M4V3CaModes,M4V3CaSmash-M4V3CaModes,M4V3CaRotR-M4V3CaModes
        dc.w M4V3CaApart-M4V3CaModes,M4V3CaAim-M4V3CaModes,M4V3CaFire-M4V3CaModes
        dc.w M4V3CaSmash-M4V3CaModes,M4V3CaRotL-M4V3CaModes,M4V3CaRepeat-M4V3CaModes
M4V3CaNextZ: ;CF05
        clr.b 36(a0)
M4V3CaNext: ;CF07
        addq.b #1,X_STATE(a0)
        bra M4V3CaStrat
; 26 repeat CDA4: state 2 and dispatch.
M4V3CaRepeat:
        move.b #2,X_STATE(a0)
        bra M4V3CaStrat
; 0 rolloninit CD45: z + 6000, y + 4000, sword2 -500, sflags4 $20; next.
M4V3CaRollInit:
        addi.w #6000,4(a0)
        addi.w #4000,2(a0)
        move.w #-500,X_SWORD2(a0)
        bset #5,X2_FL4(a0)
        bra M4V3CaNext
; 1 rollon CD6F: y += sword2, sword2 + 20, z - 150; |pz - z| < 2000 ->
; next, else move.
M4V3CaRollOn:
        move.w X_SWORD2(a0),d0
        add.w d0,2(a0)
        addi.w #20,X_SWORD2(a0)
        subi.w #150,4(a0)
        bsr M4V3PlayerZD
        cmpi.w #2000,d0
        bmi M4V3CaNext
        bra M4V3CaMove
; 2/7/13 moveaway D02D: sflags4 $20 off; |pz - z| >= 2000 -> next; else z +
; 60, move.
M4V3CaAway:
        bclr #5,X2_FL4(a0)
        bsr M4V3PlayerZD
        cmpi.w #2000,d0
        bpl M4V3CaNext
        addi.w #60,4(a0)
        bra M4V3CaMove
; 3/9 generateminis CE4F: four minicastanets (CE5F); next.
M4V3CaMinis:
        moveq #3,d7
M4V3CaMinisLoop:
        bsr M4V3CaMini
        dbra d7,M4V3CaMinisLoop
        bra M4V3CaNext
; CE5F: boss_e_4 CDE0 (make_obj) with strategy path_istrat 04:8022, path
; $467E (sflag1: $46D1), enemy1, HP 2 AP 8, at this position (copy_pos)
; and angles, x/y + sext(random_l), z + 20, sbyte1 = (random_l & 7) * 4.
M4V3CaMini:
        move.w #$cde0,d0
        bsr M4V3Make
        beq M4V3CaMiniDone
        move.l #M4PathIstrat,32(a2)
        move.w #$467e,42(a2)
        btst #F2_SFLAG1,48(a0)
        beq M4V3CaMiniPath
        move.w #$46d1,42(a2)
M4V3CaMiniPath:
        ori.b #CF_ENEMY1,44(a2)
        move.b #2,38(a2)
        move.b #8,39(a2)
        move.l (a0),(a2)
        move.w 4(a0),4(a2)
        bsr M4V3CopyRots
        jsr M4IntroRandom
        ext.w d0
        add.w d0,(a2)
        jsr M4IntroRandom
        ext.w d0
        add.w d0,2(a2)
        addi.w #20,4(a2)
        jsr M4IntroRandom
        andi.b #7,d0
        add.b d0,d0
        add.b d0,d0
        move.b d0,36(a2)
M4V3CaMiniDone:
        rts
; 4/10/16/21 moveapart CF11: both halves collstrat D309; sbyte2 + 2; >= 40
; (unsigned) -> next, else move.
M4V3CaApart:
        move.l #M4V3CastBitHit,d1
        bsr M4V3CaHalvesColl
        addq.b #2,37(a0)
        cmpi.b #40,37(a0)
        bhs M4V3CaNext
        bra M4V3CaMove
M4V3CaHalvesColl: ;d1 -> X_COLL of both halves (the ROM writes the pointer of a missing half to object 0)
        move.w X_ALPTR(a0),d0
        beq M4V3CaHc2
        movea.w d0,a2
        move.l d1,X_COLL(a2)
M4V3CaHc2:
        move.w 40(a0),d0
        beq M4V3CaHcDone
        movea.w d0,a2
        move.l d1,X_COLL(a2)
M4V3CaHcDone:
        rts
; 5/11 movetoplayer CF93: sbyte3 Achase8_2 -> $20, z - 20, sbyte1 + 1;
; >= 100 -> sbyte1 0, next; else move.
M4V3CaToPlayer:
        move.b X_SBYTE3(a0),d0
        moveq #$20,d1
        moveq #2,d2
        jsr M4EnChase8
        move.b d0,X_SBYTE3(a0)
        subi.w #20,4(a0)
        addq.b #1,36(a0)
        cmpi.b #100,36(a0)
        bhs M4V3CaNextZ
        bra M4V3CaMove
; 6/12/19/24 smashtogether CFBB: sbyte3 Achase8_1 -> 0; sbyte2 0 -> next;
; - 1; 0 -> next; - 1; then both halves lose their collstrat; move.
M4V3CaSmash:
        move.b X_SBYTE3(a0),d0
        moveq #0,d1
        moveq #1,d2
        jsr M4EnChase8
        move.b d0,X_SBYTE3(a0)
        tst.b 37(a0)
        beq M4V3CaNext
        subq.b #1,37(a0)
        beq M4V3CaNext
        subq.b #1,37(a0)
        moveq #0,d1
        bsr M4V3CaHalvesColl
        bra M4V3CaMove
; 8/20 rotate90r CF55: sflag1, rotz + 8, sbyte1 + 1; 8 -> sbyte1 0, next.
M4V3CaRotR:
        bset #F2_SFLAG1,48(a0)
        addq.b #8,14(a0)
        addq.b #1,36(a0)
        cmpi.b #8,36(a0)
        bne M4V3CaMove
        bra M4V3CaNextZ
; 14/25 rotate90l CF72: rotz - 8, sbyte1 + 1; 8 -> sflag1 off, sbyte1 0,
; next.
M4V3CaRotL:
        subq.b #8,14(a0)
        addq.b #1,36(a0)
        cmpi.b #8,36(a0)
        bne M4V3CaMove
        bclr #F2_SFLAG1,48(a0)
        bra M4V3CaNextZ
; 15 checkhp CDAC: HP(half 1) + HP(half 2) (8 bits) >= 180 -> repeat
; (state 2), else next.
M4V3CaCheckHp:
        bsr M4V3CaHp
        cmpi.b #180,d0
        bhs M4V3CaRepeat
        bra M4V3CaNext
; gethp CDBB: lo8(half1.HP + half2.HP) (a missing half reads object 0 in
; the ROM: taken as 0 [not reproduced]).
M4V3CaHp:
        moveq #0,d0
        move.w X_ALPTR(a0),d1
        beq M4V3CaHp2
        movea.w d1,a2
        move.b 38(a2),d0
M4V3CaHp2:
        move.w 40(a0),d1
        beq M4V3CaHpDone
        movea.w d1,a2
        add.b 38(a2),d0
M4V3CaHpDone:
        rts
; 17/22 aim CDCB: sbyte3 Achase8_2 -> $10; there -> next; else powerbuild
; ($1770) 0, move.
M4V3CaAim:
        move.b X_SBYTE3(a0),d0
        moveq #$10,d1
        moveq #2,d2
        jsr M4EnChase8
        move.b d0,X_SBYTE3(a0)
        tst.b d3
        bne M4V3CaNext
        clr.b M4_V3_1770
        bra M4V3CaMove
; 18/23 fire CDE6: animframe + (sbyte1 >> 3) modulo 8; both halves sflag1
; (they fire); sbyte1 + 1; < 40 -> move; powerbuild 1, halves' sflag1 off;
; < 60 -> move; else sbyte1 0, next.
M4V3CaFire:
        move.b 36(a0),d1
        lsr.b #3,d1
        move.b 16(a0),d0
        add.b d1,d0
        bmi M4V3CaFireMod
        addq.b #8,d0
M4V3CaFireMod:
        andi.b #$7f,d0
        cmpi.b #8,d0
        blo M4V3CaFireSet
        subq.b #8,d0
M4V3CaFireSet:
        ori.b #$80,d0
        move.b d0,16(a0)
        moveq #1,d1
        bsr M4V3CaHalvesFlag
        addq.b #1,36(a0)
        cmpi.b #40,36(a0)
        blo M4V3CaMove
        move.b #1,M4_V3_1770
        moveq #0,d1
        bsr M4V3CaHalvesFlag
        cmpi.b #60,36(a0)
        blo M4V3CaMove
        bra M4V3CaNextZ
M4V3CaHalvesFlag: ;d1 = 1 set / 0 clear sflag1 of both halves
        move.w X_ALPTR(a0),d0
        bsr M4V3CaHalfFlag
        move.w 40(a0),d0
M4V3CaHalfFlag:
        beq M4V3CaHfDone
        movea.w d0,a2
        bclr #F2_SFLAG1,48(a2)
        tst.b d1
        beq M4V3CaHfDone
        bset #F2_SFLAG1,48(a2)
M4V3CaHfDone:
        rts

; .move D0B8: half 2 HP 0 -> half 1 survives; else half 1 gone -> half 2
; survives: survivor strategy trucklaunch D32F, controller removed. Both
; alive: $1771 = (gethp < 60 ? 2 : 0) | (sflag1 ? 0 : 1); z += pviewvelz;
; unless sflags4 $20, x, y Achase16_4 toward the player; m_bossHP += HP of
; each half and the halves are placed (D1DA / D21B).
M4V3CaMove:
        move.w 40(a0),d0
        beq M4V3CaMv1 ;[ROM: object 0 HP]
        movea.w d0,a2
        tst.b 38(a2)
        bne M4V3CaMvBoth
M4V3CaMv1:
        move.w X_ALPTR(a0),d0
        bra M4V3CaSurvive
M4V3CaMvBoth:
        tst.w X_ALPTR(a0)
        bne M4V3CaMvAlive
        move.w 40(a0),d0
M4V3CaSurvive:
        beq M4V3CaSurviveNone ;[ROM: object 0]
        movea.w d0,a2
        move.l #M4V3StratTruckLaunch,32(a2)
M4V3CaSurviveNone:
        moveq #1,d0
        rts
M4V3CaMvAlive:
        bsr M4V3CaHp
        moveq #0,d1
        cmpi.b #60,d0
        bhs M4V3CaMvFlag
        moveq #2,d1
M4V3CaMvFlag:
        btst #F2_SFLAG1,48(a0)
        bne M4V3CaMvFlag1
        ori.b #1,d1
M4V3CaMvFlag1:
        move.b d1,M4_V3_1771
        jsr M4EnAddPZ
        btst #5,X2_FL4(a0)
        bne M4V3CaMvHalves
        move.w (a0),d0
        move.w (a1),d1
        moveq #4,d2
        jsr M4LpAchase
        move.w d0,(a0)
        move.w 2(a0),d0
        move.w 2(a1),d1
        moveq #4,d2
        jsr M4LpAchase
        move.w d0,2(a0)
M4V3CaMvHalves:
        move.w X_ALPTR(a0),d0
        beq M4V3CaMvH2
        movea.w d0,a2
        move.b 38(a2),d0
        add.b d0,M4_BOSS_HP
        bsr M4V3CaPlace1
M4V3CaMvH2:
        move.w 40(a0),d0
        beq M4V3Keep
        movea.w d0,a2
        move.b 38(a2),d0
        add.b d0,M4_BOSS_HP
        bsr M4V3CaPlace2
        bra M4V3Keep
; D1DA (half 1 = a2): copy_rots, animframe = ours, roty (sflag1: rotx) -
; sbyte3, offset (-42 - sbyte2, 0, 0) x4.
M4V3CaPlace1:
        bsr M4V3CopyRots
        move.b 16(a0),16(a2)
        move.b X_SBYTE3(a0),d0
        lea 13(a2),a3
        btst #F2_SFLAG1,48(a0)
        beq M4V3CaP1
        lea 12(a2),a3
M4V3CaP1:
        sub.b d0,(a3)
        moveq #-42,d3
        sub.b 37(a0),d3
M4V3CaPlace:
        moveq #0,d4
        moveq #0,d5
        bra M4V3Positional
; D21B (half 2 = a2): copy_rots, animframe = (ours ^ 7) - 1 modulo 8, rotz
; + $80, roty (sflag1: rotx) + sbyte3, offset (42 + sbyte2, 0, 0) x4.
M4V3CaPlace2:
        bsr M4V3CopyRots
        move.b 16(a0),d0
        eori.b #7,d0
        subq.b #1,d0
        bmi M4V3CaP2Mod
        addq.b #8,d0
M4V3CaP2Mod:
        andi.b #$7f,d0
        cmpi.b #8,d0
        blo M4V3CaP2Set
        subq.b #8,d0
M4V3CaP2Set:
        ori.b #$80,d0
        move.b d0,16(a2)
        addi.b #$80,14(a2)
        move.b X_SBYTE3(a0),d0
        lea 13(a2),a3
        btst #F2_SFLAG1,48(a0)
        beq M4V3CaP2
        lea 12(a2),a3
M4V3CaP2:
        add.b d0,(a3)
        moveq #42,d3
        add.b 37(a0),d3
        bra M4V3CaPlace

; castbit_istrat 09:D281 (halves): collstrat D309, explode, HP 120 AP 10, no
; zremove, enemy1 | enemyweap. Tick D2C2: a half 2 (not C9D4) takes shape
; C9F0 with rotz $80, else CA0C; sflag1 and even gameframe -> ring laser
; (09:D522).
M4V3StratCastBit:
        move.l #M4V3CastBitTick,32(a0)
        move.l #M4V3CastBitHit,X_COLL(a0)
        move.l #M4LevelExplode,X_EXP(a0)
        move.b #120,38(a0)
        move.b #10,39(a0)
        bclr #3,45(a0)
        ori.b #CF_ENEMY1|$40,44(a0)
M4V3CastBitTick:
        cmpi.w #$c9d4,X_SHAPEHDR(a0)
        beq M4V3CbFire
        move.w #$ca0c,d0
        cmpi.b #$80,14(a0)
        bne M4V3CbShape
        move.w #$c9f0,d0
M4V3CbShape:
        cmp.w X_SHAPEHDR(a0),d0
        beq M4V3CbFire
        move.w d0,X_SHAPEHDR(a0)
        jsr M4LevelShapeIndex
        jsr M4LevelSetShape
M4V3CbFire:
        btst #F2_SFLAG1,48(a0)
        beq M4V3Keep
        btst #0,M4_LV_GAMEFRAME+1
        bne M4V3Keep
        bsr M4V3RingFire
        bra M4V3Keep
; collstrat D309: HF2 -> cleared, damage; else nohitaffect. hitflash.
M4V3CastBitHit:
        bclr #1,20(a0)
        beq M4V3CbNoHit
        bclr #SF_NOHITAFFECT,49(a0)
        jmp M4LcHitFlash
M4V3CbNoHit:
        bset #SF_NOHITAFFECT,49(a0)
        jmp M4LcHitFlash

; 09:D522: ring laser AD65 (make_obj) at the half (copy_pos, copy_rots),
; strategy ringlaser D59F, vel 60, immune both ways; $1771 bit 0: roty +=
; $40 if rotz is negative, else $C0; otherwise rotx += $C0 when not N(rotz -
; $40), else $40, and rotz = roty = 0.
M4V3RingFire:
        move.w #$ad65,d0
        bsr M4V3Make
        beq M4V3RfDone
        move.l (a0),(a2)
        move.w 4(a0),4(a2)
        bsr M4V3CopyRots
        move.l #M4V3StratRing,32(a2)
        move.b #60,15(a2)
        move.w a0,28(a2)
        move.w a2,28(a0)
        btst #0,M4_V3_1771
        bne M4V3RfY
        move.b 14(a2),d0
        subi.b #$40,d0
        bpl M4V3RfXc
        addi.b #$40,12(a2)
        bra M4V3RfZero
M4V3RfXc:
        addi.b #$c0,12(a2)
M4V3RfZero:
        clr.b 14(a2)
        clr.b 13(a2)
        rts
M4V3RfY:
        tst.b 14(a2)
        bmi M4V3RfY40
        addi.b #$c0,13(a2)
        rts
M4V3RfY40:
        addi.b #$40,13(a2)
M4V3RfDone:
        rts

; ringlaser D59F: collstrat D733, no expstrat, HP $FF AP 7, colframe $80,
; hitflash flag ($1F $80), ssprite, depthoffset 0, tx 0; v = gen_3dvecs
; (vel, rotx, roty), then facing the camera (09:802A). Tick D5F7: pos += v;
; D5FA: z += pviewvelz, colframe + 1 modulo 5.
M4V3StratRing:
        move.l #M4V3RingTick,32(a0)
        move.l #M4V3RingHit,X_COLL(a0)
        clr.l X_EXP(a0)
        move.b #$ff,38(a0)
        move.b #7,39(a0)
        move.b #$80,18(a0)
        bset #SF_HITFLASH,49(a0)
        bset #F2_SPRITE,48(a0)
        clr.b X_DEPTHOFF(a0)
        clr.b X_TX(a0)
        jsr M4EnGen3d
        jsr M4EnFaceCamera
M4V3RingTick:
        jsr M4EnMove
M4V3RingAnim: ;D5FA
        jsr M4EnAddPZ
        move.b 18(a0),d0
        moveq #5,d1
        jsr M4MtAfInc
        move.b d0,18(a0)
        bra M4V3Keep
; collstrat D733: a collider with the same shape (another ring) -> both at
; the mean x (trunc0 of the 16-bit sum / 2), strategy D618, hitflash flag
; off; always nohitaffect, then hitflash.
M4V3RingHit:
        jsr M4LcCollider
        move.l a2,d0
        beq M4V3RhDone
        bsr M4V3HeaderOf
        move.w d0,d1
        exg a0,a2
        bsr M4V3HeaderOf
        exg a0,a2
        cmp.w d0,d1
        bne M4V3RhDone
        move.l #M4V3RingMerge,32(a0)
        move.w (a0),d0
        add.w (a2),d0
        bsr M4V3Div2
        move.w d0,(a0)
        move.w d0,(a2)
        bclr #SF_HITFLASH,49(a0)
M4V3RhDone:
        bset #SF_NOHITAFFECT,49(a0)
        jmp M4LcHitFlash
; D618 (merged): collstrat hitflash, strategy D641, vel 120, facing the
; camera, sbyte1 4. D641: powerbuild 0 -> sbyte1 - 1 (0: removed), no move,
; D5FA; powerbuild set -> D65A: strategy D70A, rotx/roty straight at the
; player (09:8009, $1534 0), sbyte1 = rotx, sbyte3 = roty, v = gen_3dvecs,
; facing the camera; then the spread by $1771: 0 -> Y pair, 1 -> X pair, 2
; -> random_l < $7F (Y) / X; each pair picks a side with random_l < $7F.
M4V3RingMerge:
        move.l #M4LcHitFlash,X_COLL(a0)
        move.l #M4V3RingWait,32(a0)
        move.b #120,15(a0)
        jsr M4EnFaceCamera
        move.b #4,36(a0)
M4V3RingWait:
        tst.b M4_V3_1770
        bne M4V3RingLaunch
        subq.b #1,36(a0)
        bne M4V3RingAnim
        moveq #1,d0
        rts
M4V3RingLaunch:
        move.l #M4V3RingSpread,32(a0)
        clr.b M4_VP_1534
        movea.l a1,a2
        jsr M4EnPitchTo
        move.b d0,12(a0)
        jsr M4EnYawTo
        move.b d0,13(a0)
        move.b 12(a0),36(a0)
        move.b 13(a0),X_SBYTE3(a0)
        jsr M4EnGen3d
        jsr M4EnFaceCamera
        move.b M4_V3_1771,d0
        beq M4V3RlY
        cmpi.b #1,d0
        beq M4V3RlX
        jsr M4IntroRandom
        cmpi.b #$7f,d0
        blo M4V3RlY
M4V3RlX: ;D6A8
        jsr M4IntroRandom
        cmpi.b #$7f,d0
        blo M4V3RlXb
        addi.b #$1e,36(a0)
        move.b #$fa,37(a0)
        bra M4V3RlXc
M4V3RlXb: ;D6F9
        subi.b #$1e,36(a0)
        move.b #6,37(a0)
M4V3RlXc:
        clr.b X_SBYTE4(a0)
        move.b #$a0,13(a0)
        bra M4V3RingSpread
M4V3RlY: ;D6C7
        jsr M4IntroRandom
        cmpi.b #$7f,d0
        blo M4V3RlYb
        addi.b #$1e,X_SBYTE3(a0)
        move.b #$fa,X_SBYTE4(a0)
        bra M4V3RlYc
M4V3RlYb: ;D6E6
        subi.b #$1e,X_SBYTE3(a0)
        move.b #6,X_SBYTE4(a0)
M4V3RlYc:
        clr.b 37(a0)
        move.b #$20,12(a0)
; D70A: sbyte1 += sbyte2, sbyte3 += sbyte4, v = gen_3dvecs(vel, sbyte1,
; sbyte3), pos += v, then D5F7 (pos += v again, D5FA).
M4V3RingSpread:
        move.b 37(a0),d0
        add.b d0,36(a0)
        move.b X_SBYTE4(a0),d0
        add.b d0,X_SBYTE3(a0)
        moveq #0,d0
        move.b 15(a0),d0
        ext.w d0
        move.b 36(a0),d1
        move.b X_SBYTE3(a0),d2
        jsr M4EnVector
        movem.w d3-d5,6(a0)
        jsr M4EnMove
        bra M4V3RingTick

; trucklaunch D32F (the surviving half): strategy D36C, hitflash /
; bossexplode 06:EAAE, sbyte4 = HP, HP $FF AP 8, colldisable, sbyte1 70.
; D36C: x toward -150 and y toward -200 by 8 (equal: kept; N(v - t): + 8,
; else - 8); |pz - z| < 2000 -> z + 30; sbyte1 0 -> D3D2 (strategy D3E3,
; sbyte1 40); else - 1; D3C2: z += pviewvelz, m_bossHP += sbyte4.
M4V3StratTruckLaunch:
        move.l #M4V3TlTick,32(a0)
        move.l #M4LcHitFlash,X_COLL(a0)
        move.l #M4V3BossExplode,X_EXP(a0)
        move.b 38(a0),X_SBYTE4(a0)
        move.b #$ff,38(a0)
        move.b #8,39(a0)
        bset #SF_COLLDISABLE,49(a0)
        move.b #70,36(a0)
M4V3TlTick:
        move.w (a0),d0
        move.w #-150,d1
        bsr M4V3Toward8
        move.w d0,(a0)
        move.w 2(a0),d0
        move.w #-200,d1
        bsr M4V3Toward8
        move.w d0,2(a0)
        bsr M4V3PlayerZD
        cmpi.w #2000,d0
        bpl M4V3TlCount
        addi.w #30,4(a0)
M4V3TlCount:
        tst.b 36(a0)
        beq M4V3TlTurnInit
        subq.b #1,36(a0)
M4V3TlTail: ;D3C2
        jsr M4EnAddPZ
        move.b X_SBYTE4(a0),d0
        add.b d0,M4_BOSS_HP
        bra M4V3Keep
M4V3Toward8: ;d0 value, d1 target -> d0
        cmp.w d1,d0
        beq M4V3T8Done
        bmi M4V3T8Up
        subq.w #8,d0
        rts
M4V3T8Up:
        addq.w #8,d0
M4V3T8Done:
        rts
M4V3TlTurnInit:
        move.l #M4V3TlTurn,32(a0)
        move.b #40,36(a0)
; D3E3: roty -> $D0, rotz -> $E8, rotx -> 0 (Achase8_4); sbyte1 nonzero ->
; - 1, D3C2; else sbyte1 1, fallingtruck CA28 (make_obj at this position
; and angles; failure: rtl) with roty + $C0, rotx = -rotz, rotz 0; strategy
; D46B: sbyte1 - 1 -> 0: boss bar off (maximum and m_bossHP 0), colldisable,
; HP 0 (bossexplode next tick); else D3C2.
M4V3TlTurn:
        moveq #4,d2
        move.b 13(a0),d0
        move.b #$d0,d1
        jsr M4EnChase8
        move.b d0,13(a0)
        move.b 14(a0),d0
        move.b #$e8,d1
        jsr M4EnChase8
        move.b d0,14(a0)
        move.b 12(a0),d0
        moveq #0,d1
        jsr M4EnChase8
        move.b d0,12(a0)
        tst.b 36(a0)
        beq M4V3TlDrop
        subq.b #1,36(a0)
        bra M4V3TlTail
M4V3TlDrop:
        move.b #1,36(a0)
        move.w #$ca28,d0
        bsr M4V3Make
        beq M4V3Keep
        move.l (a0),(a2)
        move.w 4(a0),4(a2)
        bsr M4V3CopyRots
        move.l #M4V3StratFallTruck,32(a2)
        addi.b #$c0,13(a2)
        move.b 14(a2),d0
        neg.b d0
        move.b d0,12(a2)
        clr.b 14(a2)
        move.l #M4V3TlEnd,32(a0)
M4V3TlEnd:
        subq.b #1,36(a0)
        bne M4V3TlTail
        clr.b M4_BOSS_MAXHP
        clr.b M4_BOSS_HP
        bset #SF_COLLDISABLE,49(a0)
        clr.b 38(a0)
        bra M4V3Keep

; bossexplode 06:EAAE (M4B1Explode, level_boss1.asm) for an object without
; stratptr2 ($1CD9 = 0): the dying tick 06:EA38 then only adds pviewvelz
; (M4B1Dying also runs boss1's stratptr2 08:8166, rotz + 2).
; M4B1Explode falls into M4B1Dying for its first tick (06:EAAE -> EA38 in
; the same tick): its stratptr2 step (rotz + 2) is undone here.
M4V3BossExplode:
        jsr M4B1Explode
        subq.b #2,14(a0)
        move.l #M4V3BossDying,32(a0)
        rts
M4V3BossDying: ;06:EA38: hitflash; count - 1; below 0: colldisable, HP 0, huge explosion, bossdead, explode now
        bset #SF_HITFLASH,49(a0)
        subq.b #1,19(a0)
        bpl M4V3BdWait
        bset #SF_COLLDISABLE,49(a0)
        clr.b 38(a0)
        move.l #M4_FX_HUGE,d0
        jsr M4B1Expl
        bset #2,M4_LP_GAMEFLAGS
        jmp M4LevelExplode
M4V3BdWait:
        jsr M4EnAddPZ
        bra M4V3Keep

; fallingtruck D48D: strategy D4CA, hitflash, no expstrat, HP $FF AP 8,
; colldisable, vel 50, sbyte1 10. D4CA: v = gen_3dvecs, pos += v; sbyte1
; nonzero -> - 1; else rotx - 8 while (rotx - $50) >= $10 (unsigned); z +=
; pviewvelz.
M4V3StratFallTruck:
        move.l #M4V3FtTick,32(a0)
        move.l #M4LcHitFlash,X_COLL(a0)
        clr.l X_EXP(a0)
        move.b #$ff,38(a0)
        move.b #8,39(a0)
        bset #SF_COLLDISABLE,49(a0)
        move.b #50,15(a0)
        move.b #10,36(a0)
M4V3FtTick:
        jsr M4EnGen3d
        jsr M4EnMove
        tst.b 36(a0)
        beq M4V3FtPitch
        subq.b #1,36(a0)
        bra M4V3FtDone
M4V3FtPitch:
        move.b 12(a0),d0
        subi.b #$50,d0
        cmpi.b #$10,d0
        blo M4V3FtDone
        subq.b #8,12(a0)
M4V3FtDone:
        jsr M4EnAddPZ
        bra M4V3Keep

; ---------------------------------------------------------------------
; Strategy table (original 24-bit address, Istrat).
; mine2 0A:E67F / E6C9, selected USA ROM. vy -45..15 then five aimed
; relovalbeam shots. Destruction by a hit uses the no-fire branch.
M4V3Mine2:
        move.l #M4V3Mine2Tick,32(a0)
        move.l #M4LcHitFlash,X_COLL(a0)
        move.l #M4V3Mine2NoFire,X_EXP(a0)
        move.b #2,38(a0)
        move.b #8,39(a0)
        move.w #-45,8(a0)
        jsr M4IntroRandom
        move.b d0,13(a0)
        bset #F2_RELEXPLODE,48(a0)
        ori.b #$40,44(a0) ;enemyweap, selected USA mine2
M4V3Mine2Tick:
        jsr M4EnMove
        jsr M4EnAddPZ
        cmpi.w #15,8(a0)
        beq.s M4V3Mine2Fire
        tst.w 8(a0)
        bmi.s M4V3Mine2Fall
        addq.b #2,12(a0)
        bra.s M4V3Mine2Next
M4V3Mine2Fall:
        addi.b #12,13(a0)
M4V3Mine2Next:
        addq.w #1,8(a0)
        moveq #0,d0
        rts
M4V3Mine2Fire:
        lea M4V3Mine2Angles,a4
        moveq #4,d2
M4V3Mine2Shot:
        moveq #M4_WT_RELOVALBEAM,d0
        moveq #0,d3
        moveq #0,d4
        moveq #0,d5
        move.b (a4)+,d6
        move.b (a4)+,d7
        lea LV_PLAYER,a3
        movem.l d2/a4,-(sp)
        jsr M4EnFire
        jsr M4IntroRandom
        andi.b #31,d0
        cmpa.w #0,a2
        beq.s M4V3Mine2ShotDone
        add.b d0,15(a2)
M4V3Mine2ShotDone:
        movem.l (sp)+,d2/a4
        dbra d2,M4V3Mine2Shot
M4V3Mine2NoFire:
        moveq #-1,d0
        jsr M4EnCreate
        beq.s M4V3Mine2Explode
        move.l (a0),(a2)
        move.w 4(a0),4(a2)
        move.l #M4StratParticles,32(a2)
M4V3Mine2Explode:
        jmp M4LevelExplode
M4V3Mine2Angles:
        include '../build/m4-mine2-angles.inc'
        even

M4StrategiesVenom23:
        dc.l $0ae67f,M4V3Mine2
        dc.l $0ae08a,M4V3StratAircar1
        dc.l $0ae131,M4V3StratAircar2
        dc.l $0ae233,M4V3StratAircar3
        dc.l $0ae38f,M4V3StratAircar4
        dc.l $0ae478,M4V3StratAircar5
        dc.l $0ae5b5,M4V3StratTruck1
        dc.l $0ae5f5,M4V3StratTruck2
        dc.l $09c54f,M4V3StratRoadline
        dc.l $099108,M4V3StratWallLR
        dc.l $08d249,M4V3StratWireman
        dc.l $09cb7f,M4V3StratBarrier
        dc.l $09c160,M4V3StratMadbiker
        dc.l $09c562,M4V3StratTrucker
        dc.l $09c127,M4V3StratBike2
        dc.l $09cc60,M4V3StratCastanet
        dc.l $09d281,M4V3StratCastBit
        dc.l 0

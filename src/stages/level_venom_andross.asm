; Venom unit `andross`: Andross (monolith 07:DEAB, shape face_b 00:D0B8,
; map 0D:DAFE), its 16 panels, core, shots, suck bits/cubes and explosions.
; Included from level_venom.asm. Documentation (Spanish), traces and the
; ROM-versus-68000 oracle: build/agent-venom/andross/ (ANDROSS.md,
; monolith_trace.txt = strat_trace 07:DEAB, andross-oracle.py).
; Authority: ref/Star Fox (USA).sfc rev0 bank 07 DEAB..FBFE; UltraStarFox
; SF/STRAT/GB3STRAT.ASM 3847..4939 only supplies the names (it differs from
; the ROM: HP $FF/AP 40, collflags $10 and nohitaffect in the Istrat; panel
; Istrat colldisable/noremove; mfire1a angle 4, not deg5).
; Fields (level_objects.asm): stratstate $1CDC = X_STATE, animframe $1CE7 =
; 16, colframe $1CE6 = 18, count $0A = 19, hitflags $35 = 20, sbyte1..4 =
; 36/37/X_SBYTE3/X_SBYTE4, sword1 $26 = 40.w (BYTE ops on its low byte 41),
; sword2 $28 = X_SWORD2 (BYTE: X_SWORD2+1), al_ptr $06 = X_ALPTR, tx $1CF4 =
; X_TX, al_flags $08 bit0 afexp = 25 bit0, sflags2 $01 colldisable = 49
; bit0, $10 sflag1 = F2_SFLAG1, sflags3 $20 nohitaffect = 49 bit5, $40
; nopolyexp = F2_NOPOLYEXP, sflags4 $04 relexplode = F2_RELEXPLODE, $08
; invisible = X2_FL4 bit3 + 49 bit1 (draw), sflags $02 hitflash = 49 bit7 +
; 31 bit2. $1FFF = M4_GS_CURLEVEL (Venom 1: 0; 03:CCAD copies byte 8 of the
; course record 03:D749/D8D3). $14EC (playervelZ) = player vz 10(a1) as
; boss7's keeprelto_player (level_boss.asm). viewposz $C5 = M4_LVW_POS+4.
; Sounds (trigse $9F/$99/$A0/$87/$88/$86/$A1, snd2 $0D) and the music cut of
; the core explosion ($1F49 = $F0) are not ported.
M4_VA equ $ff9f60
M4_VA_BFLAGS equ M4_VA+0 ;.b bossflags $14D5 bits 0..2 (BF_flag1/2/3)
M4_VA_PSVW1 equ M4_VA+2 ;.w psvar_word1 $1556: z of the last panel
M4_VA_SVW1 equ M4_VA+4 ;.w svar_word1 $151D (temporary)
M4_VA_LAST equ M4_VA+6 ;.l last panel created (temporary, 07:F962)

; Original polygon models from tools/stages/venom_andross.py. Shyper is
; shared with Armada; collision chains remain those of the selected ROM.
M4VaShFaceB equ M4_SH_FACE_B ;00:D0B8 face_b
M4VaShFace0 equ M4_SH_FACE_0 ;00:D144 face_0
M4VaShFace01 equ M4_SH_FACE_0_1 ;00:D160 face_0_1
M4VaShFace1 equ M4_FX_VA_FACE_1 ;00:E6B4 face_1 (route 3, not yet drawn)
M4VaShPanel equ M4_SH_SFACE2_B ;00:D0F0 sface2_b
M4VaShPanelS equ M4_SH_SFACE_B ;00:D0D4 sface_b
M4VaShCube equ M4_SH_ANDROSSCUBE ;00:AC85 androsscube
M4VaShFaceBox equ M4_FX_VA_FACE_BOX ;00:BD5C face_box (routes 2/3)
M4VaShFire1 equ M4_SH_FIREFACE1_B ;00:D128 fireface1_b
M4VaShFireB equ M4_SH_FIREFACE_B ;00:D10C fireface_b
M4VaShHyper equ M4_SH_SHYPER ;00:BF8C Shyper
M4VaShAndross equ M4_SH_ANDROSS ;00:AC4D andross

; ---------------------------------------------------------------------
; monolith_Istrat 07:DEAB: strategy DF16, collstrat F172, expstrat F1E8
; (remove); HP $FF / AP 40, enemy1, never zremoved, nohitaffect,
; colldisable, state 0; eyes sbyte1/sbyte2 = 18 (16 when $1FFF = 0).
M4StratVaMonolith:
        move.l #M4VaMonolith,32(a0)
        move.l #M4VaMonoColl,X_COLL(a0)
        move.l #M4VaRemove,X_EXP(a0)
        move.b #$ff,38(a0)
        move.b #40,39(a0)
        move.b #50,36(a0)
        ori.b #CF_ENEMY1,44(a0)
        bclr #3,45(a0)
        bset #SF_NOHITAFFECT,49(a0)
        bset #SF_COLLDISABLE,49(a0)
        clr.b X_STATE(a0)
        move.b #18,36(a0)
        move.b #18,37(a0)
        tst.b M4_GS_CURLEVEL
        bne.s M4VaMonolith
        move.b #16,36(a0)
        move.b #16,37(a0)
; monolith_strat 07:DF16: one block per state, tested in order (a block may
; change the state for the following ones); nextstate (1F:DB66) = state + 1
; and the strategy again from here (jmpto_strat 1F:DC25).
M4VaMonolith:
        ; 0 mpartoutI DF21: bossflags = 0, 16 panels (svar_word1 = 200), invisible
        tst.b X_STATE(a0)
        bne.s M4VaS1
        clr.b M4_VA_BFLAGS
        clr.b M4_BOSS_DYING ;bossflags bit4 (cleared by the same write)
        move.w #200,M4_VA_SVW1
        bsr M4VaParts
        bsr M4VaInvisOn
        addq.b #1,X_STATE(a0)
M4VaS1: ; 1 mpartoutE DF4B: last panel stopped (BF_flag1) -> visible at its z
        cmpi.b #1,X_STATE(a0)
        bne.s M4VaS2
        btst #0,M4_VA_BFLAGS
        beq.s M4VaS2
        bsr M4VaInvisOff
        move.w M4_VA_PSVW1,4(a0)
        bset #1,M4_VA_BFLAGS
        move.b #2,X_STATE(a0)
M4VaS2: ; 2 mchgfaceI DF7D: z - 320, y + 240, face_0, anim 0, colanim 0
        cmpi.b #2,X_STATE(a0)
        bne.s M4VaS3
        subi.w #320,4(a0)
        addi.w #240,2(a0)
        move.w #M4VaShFace0,d0
        jsr M4LevelSetShape
        move.b #$80,16(a0)
        move.b #$80,18(a0)
        addq.b #1,X_STATE(a0)
M4VaS3: ; 3 mchgface DFBE: colanim -> 9, anim +1 mod 21; at 10 the core
        cmpi.b #3,X_STATE(a0)
        bne M4VaS4
        move.b 18(a0),d0
        andi.b #$7f,d0
        cmpi.b #9,d0
        beq.s M4VaS3Anim
        move.b 18(a0),d0
        moveq #1,d1
        moveq #10,d2
        bsr M4VaAnimAdd
        move.b d0,18(a0)
M4VaS3Anim:
        move.b 16(a0),d0
        moveq #1,d1
        moveq #21,d2
        bsr M4VaAnimAdd
        move.b d0,16(a0)
        andi.b #$7f,d0
        cmpi.b #10,d0
        bne M4VaS4
        addq.b #1,X_STATE(a0)
        ; core androsscube AC85 (E011): at the face, y - 240, mcore1_Istrat,
        ; al_ptr = core, invisible, colldisable; then the end block (EA1B)
        move.w #M4VaShCube,d0
        jsr M4EnCreate
        beq M4VaEnd
        move.l (a0),(a2)
        move.w 4(a0),4(a2)
        move.l #M4VaCoreI,32(a2)
        subi.w #240,2(a2)
        move.w a2,X_ALPTR(a0)
        bset #3,X2_FL4(a2)
        bset #SF_INVISIBLE,49(a2)
        bset #SF_COLLDISABLE,49(a2)
        bra M4VaEnd
M4VaS4: ; 4 minitfire E066: afexp off, collisions on, sbyte4 100, sflag1 off
        cmpi.b #4,X_STATE(a0)
        bne.s M4VaS5
        bclr #0,25(a0)
        bclr #SF_COLLDISABLE,49(a0)
        move.b #100,X_SBYTE4(a0)
        addq.b #1,X_STATE(a0)
        bclr #F2_SFLAG1,48(a0)
M4VaS5: ; 5 mfire1 E08E
        cmpi.b #5,X_STATE(a0)
        bne M4VaS6
        bsr M4VaKeepRel
        bsr M4VaAnimFire
        tst.b X_SBYTE4(a0)
        beq M4VaNextState
        subq.b #1,X_SBYTE4(a0)
        move.b #30,X_SBYTE3(a0)
        tst.b 36(a0)
        bne.s M4VaS5Fire
        tst.b 37(a0)
        bne.s M4VaS5Fire
        move.b #15,X_STATE(a0) ;both eyes gone: mIexp1 (this same tick)
M4VaS5Fire:
        ; left eye (gameframe & 31) = 15, right eye = 20: fireface1_b at
        ; (-/+320, -480), mfire1_Istrat F98E
        move.w M4_LV_GAMEFRAME,d0
        andi.w #31,d0
        cmpi.w #15,d0
        bne.s M4VaS5Right
        tst.b 36(a0)
        beq.s M4VaS5Right
        move.w #-320,d3
        bsr M4VaEyeShot
M4VaS5Right:
        tst.b 37(a0)
        beq.s M4VaS6
        move.w M4_LV_GAMEFRAME,d0
        andi.w #31,d0
        cmpi.w #20,d0
        bne.s M4VaS6
        move.w #320,d3
        bsr M4VaEyeShot
M4VaS6: ; 6 msuckI E19D: sbyte4 60, face_0_1, anim 0, sflag1
        cmpi.b #6,X_STATE(a0)
        bne.s M4VaS7
        move.b #60,X_SBYTE4(a0)
        move.w #M4VaShFace01,d0
        jsr M4LevelSetShape
        move.b #$80,16(a0)
        bset #F2_SFLAG1,48(a0)
        addq.b #1,X_STATE(a0)
M4VaS7: ; 7 msuck E1CF
        cmpi.b #7,X_STATE(a0)
        bne M4VaS8
        move.b 16(a0),d0
        andi.b #$7f,d0
        cmpi.b #4,d0
        beq.s M4VaSuck
        move.b 16(a0),d0
        moveq #1,d1
        moveq #18,d2
        bsr M4VaAnimAdd
        move.b d0,16(a0)
        bra M4VaS8
M4VaSuck:
        bsr M4VaSuckTick
        subq.b #1,X_SBYTE4(a0)
        bne.s M4VaS8
        addq.b #1,X_STATE(a0)
        move.b #20,X_SBYTE4(a0)
M4VaS8: ; 8 msuckstop E4AE: z + 100 for 20 ticks, anim -> 9
        cmpi.b #8,X_STATE(a0)
        bne.s M4VaS9
        addi.w #100,4(a0)
        subq.b #1,X_SBYTE4(a0)
        bne.s M4VaS8Anim
        clr.w 40(a0)
        bra M4VaNextState
M4VaS8Anim:
        move.b 16(a0),d0
        andi.b #$7f,d0
        cmpi.b #9,d0
        beq.s M4VaS9
        move.b 16(a0),d0
        moveq #1,d1
        moveq #18,d2
        bsr M4VaAnimAdd
        move.b d0,16(a0)
M4VaS9: ; 9..12 mgag1..4 E500..E56D: rotx += sword1 (BYTE), sword1 -/+ 1
        cmpi.b #9,X_STATE(a0)
        bne.s M4VaS10
        move.b 41(a0),d0
        add.b d0,12(a0)
        subq.b #1,41(a0)
        cmpi.b #-3,41(a0)
        beq M4VaNextState
M4VaS10:
        cmpi.b #10,X_STATE(a0)
        bne.s M4VaS11
        move.b 41(a0),d0
        add.b d0,12(a0)
        addq.b #1,41(a0)
        cmpi.b #3,41(a0)
        beq M4VaNextState
M4VaS11:
        cmpi.b #11,X_STATE(a0)
        bne.s M4VaS12
        move.b 41(a0),d0
        add.b d0,12(a0)
        subq.b #1,41(a0)
        cmpi.b #-3,41(a0)
        beq M4VaNextState
M4VaS12:
        cmpi.b #12,X_STATE(a0)
        bne.s M4VaS13
        move.b 41(a0),d0
        add.b d0,12(a0)
        addq.b #1,41(a0)
        cmpi.b #10,41(a0)
        beq M4VaNextState
M4VaS13: ; 13 mblowI E57C: rotx - 2, anim +1 mod 18; at 13: sbyte4 50
        cmpi.b #13,X_STATE(a0)
        bne.s M4VaS14
        subq.b #2,12(a0)
        move.b 16(a0),d0
        moveq #1,d1
        moveq #18,d2
        bsr M4VaAnimAdd
        move.b d0,16(a0)
        andi.b #$7f,d0
        cmpi.b #13,d0
        bne.s M4VaS14
        move.b #50,X_SBYTE4(a0)
        addq.b #1,X_STATE(a0)
M4VaS14: ; 14 mblow E5C5: rotx -> 0 (Achase8 n=1), roty (rnd & 7) - 3, a
        ; blowcube (fireface_b at y + 160, EC4A) each tick; after 50: minitfire
        cmpi.b #14,X_STATE(a0)
        bne M4VaS15
        move.b 12(a0),d0
        moveq #0,d1
        moveq #1,d2
        jsr M4EnChase8
        move.b d0,12(a0)
        jsr M4IntroRandom
        andi.b #7,d0
        subq.b #3,d0
        move.b d0,13(a0)
        move.w #M4VaShFireB,d0
        jsr M4EnCreate
        beq.s M4VaS14Count
        move.l (a0),(a2)
        move.w 4(a0),4(a2)
        addi.w #160,2(a2)
        move.l #M4VaBlowCubeI,32(a2)
M4VaS14Count:
        subq.b #1,X_SBYTE4(a0)
        bne.s M4VaS15
        move.b #4,X_STATE(a0)
        clr.b 13(a0)
        move.w #M4VaShFace0,d0
        jsr M4LevelSetShape
M4VaS15: ; 15 mIexp1 E63A
        cmpi.b #15,X_STATE(a0)
        bne M4VaS16
        bsr M4VaIexp
M4VaS16: ; 16 mexp1 E728: colldisable, afexp, count + 2 to 60, sword1 130
        cmpi.b #16,X_STATE(a0)
        bne.s M4VaS17
        bset #SF_COLLDISABLE,49(a0)
        bset #0,25(a0)
        addq.b #2,19(a0)
        move.w #130,40(a0)
        cmpi.b #60,19(a0)
        beq M4VaNextState
M4VaS17: ; 17 mcore1wait E759: no core or bossdead -> kill; invisible
        cmpi.b #17,X_STATE(a0)
        bne.s M4VaS18
        tst.w X_ALPTR(a0)
        beq M4VaKill
        btst #2,M4_LP_GAMEFLAGS
        bne M4VaKill
        bsr M4VaInvisOn
        tst.w 40(a0)
        beq M4VaNextState
        subq.w #1,40(a0)
M4VaS18: ; 18 mimp1 E792
        cmpi.b #18,X_STATE(a0)
        bne.s M4VaS19
        bsr M4VaImp
        tst.w d0
        bne M4VaKill
M4VaS19: ; 19 mlion1 E82A (route 3): colanim -> 0, anim -1 mod 21 to 0
        cmpi.b #19,X_STATE(a0)
        bne.s M4VaS20
        move.b 18(a0),d0
        andi.b #$7f,d0
        beq.s M4VaS19Anim
        move.b 18(a0),d0
        moveq #-1,d1
        moveq #10,d2
        bsr M4VaAnimAdd
        move.b d0,18(a0)
M4VaS19Anim:
        move.b 16(a0),d0
        moveq #-1,d1
        moveq #21,d2
        bsr M4VaAnimAdd
        move.b d0,16(a0)
        andi.b #$7f,d0
        bne.s M4VaS20
        addq.b #1,X_STATE(a0)
        bra M4VaEnd
M4VaS20: ; 20 mlion2 E88B: face_1, colanim -> 9, anim +1 mod 21 to 10
        cmpi.b #20,X_STATE(a0)
        bne.s M4VaS21
        move.w #M4VaShFace1,d0
        jsr M4LevelSetShape
        move.b 18(a0),d0
        andi.b #$7f,d0
        cmpi.b #9,d0
        beq.s M4VaS20Anim
        move.b 18(a0),d0
        moveq #1,d1
        moveq #10,d2
        bsr M4VaAnimAdd
        move.b d0,18(a0)
M4VaS20Anim:
        move.b 16(a0),d0
        moveq #1,d1
        moveq #21,d2
        bsr M4VaAnimAdd
        move.b d0,16(a0)
        andi.b #$7f,d0
        cmpi.b #10,d0
        bne.s M4VaS21
        addq.b #1,X_STATE(a0)
        bra M4VaEnd
M4VaS21: ; 21 mlion3 E8F5 (route 3)
        cmpi.b #21,X_STATE(a0)
        bne.s M4VaEnd
        bsr M4VaLion3
; End block 07:EA1B: eye colours (colanim) except in states 0..3, 19, 20;
; then add_vecs2pos and add_playerZ.
M4VaEnd:
        move.b X_STATE(a0),d0
        cmpi.b #3,d0
        bls M4VaMove
        cmpi.b #19,d0
        beq M4VaMove
        cmpi.b #20,d0
        beq M4VaMove
        tst.b 36(a0)
        bne.s M4VaEndLeft
        btst #F2_SFLAG1,48(a0)
        bne.s M4VaEnd17
        tst.b 37(a0)
        beq.s M4VaEnd16
        moveq #14,d3
        moveq #12,d4
        bra.s M4VaEndCycle
M4VaEnd17:
        move.b #$80|17,18(a0)
        bra.s M4VaMove
M4VaEnd16:
        move.b #$80|16,18(a0)
        bra.s M4VaMove
M4VaEndLeft:
        tst.b 37(a0)
        bne.s M4VaEndBoth
        btst #F2_SFLAG1,48(a0)
        bne.s M4VaEnd18
        moveq #16,d3
        moveq #14,d4
        bra.s M4VaEndCycle
M4VaEnd18:
        move.b #$80|18,18(a0)
        bra.s M4VaMove
M4VaEndBoth:
        btst #F2_SFLAG1,48(a0)
        bne.s M4VaEnd19
        moveq #12,d3
        moveq #10,d4
; colanim +1 mod 21; at >= d3 -> d4.
M4VaEndCycle:
        move.b 18(a0),d0
        moveq #1,d1
        moveq #21,d2
        bsr M4VaAnimAdd
        move.b d0,18(a0)
        andi.b #$7f,d0
        cmp.b d3,d0
        blo.s M4VaMove
        ori.b #$80,d4
        move.b d4,18(a0)
        bra.s M4VaMove
M4VaEnd19:
        move.b #$80|19,18(a0)
M4VaMove:
        jsr M4EnMove
        jsr M4EnAddPZ
        moveq #0,d0
        rts
M4VaNextState:
        addq.b #1,X_STATE(a0)
        bra M4VaMonolith
; kill_Istrat 06:8D07: colldisable, HP 0, nothing else this tick.
M4VaKill:
        jsr M4EnKill
        moveq #0,d0
        rts
; remove_Istrat 06:8D12 (monolithexp F1E8; panels).
M4VaRemove:
        moveq #1,d0
        rts

; d0.b value with bit7 (anim/colanim), d1 delta, d2 modulus -> d0.b
; (s_add_anim 07:DFE4: adc; bmi skip; adc N; and $7F; >= N: - N; ora $80).
M4VaAnimAdd:
        add.b d1,d0
        bmi.s M4VaAnimMod
        add.b d2,d0
M4VaAnimMod:
        andi.b #$7f,d0
        cmp.b d2,d0
        blo.s M4VaAnimOk
        sub.b d2,d0
M4VaAnimOk:
        ori.b #$80,d0
        rts
; mfire1/mlion3 E092: anim +1 mod 21; 20 -> 11.
M4VaAnimFire:
        move.b 16(a0),d0
        moveq #1,d1
        moveq #21,d2
        bsr M4VaAnimAdd
        move.b d0,16(a0)
        andi.b #$7f,d0
        cmpi.b #20,d0
        bne.s M4VaAnimFireDone
        move.b #$80|11,16(a0)
M4VaAnimFireDone:
        rts
; keeprelto_player 1F:DB21: z += playervelZ ($14EC) - pviewvelz ($14F6).
M4VaKeepRel:
        move.w 10(a1),d0
        sub.w M4_LP_PVIEWVZ,d0
        add.w d0,4(a0)
        rts
M4VaInvisOn:
        bset #3,X2_FL4(a0)
        bset #SF_INVISIBLE,49(a0)
        rts
M4VaInvisOff:
        bclr #3,X2_FL4(a0)
        bclr #SF_INVISIBLE,49(a0)
        rts
; d3 = x offset: fireface1_b at the face + (d3, -480), mfire1_Istrat F98E.
M4VaEyeShot:
        move.w #M4VaShFire1,d0
        jsr M4EnCreate
        beq.s M4VaEyeShotDone
        move.l (a0),(a2)
        move.w 4(a0),4(a2)
        add.w d3,(a2)
        subi.w #480,2(a2)
        move.l #M4VaFire1I,32(a2)
M4VaEyeShotDone:
        rts
; d0 = descriptor: makeexpobj 06:EF1B (delayexplode at the creator, relexplode,
; no collision/sound) with that shape -> a2 or 0 (Z).
M4VaExpl:
        move.w d0,-(sp)
        jsr M4FxMedium
        move.w (sp)+,d0
        cmpa.w #0,a2
        beq.s M4VaExplDone
        exg a0,a2
        jsr M4LevelSetShape
        exg a0,a2
        cmpa.w #0,a2
M4VaExplDone:
        rts
; add_rnd2pos 255,255,255,2,2,2 (07:E22A): a2.x/y/z += ((rnd & $FF) - 127) * 4.
M4VaRnd2Pos4:
        move.l a2,-(sp)
        moveq #2,d1
M4VaRnd2Pos4Next:
        jsr M4IntroRandom
        subi.w #127,d0
        add.w d0,d0
        add.w d0,d0
        add.w d0,(a2)+
        dbra d1,M4VaRnd2Pos4Next
        movea.l (sp)+,a2
        rts
; addrnd2posxyz2 06:EFA0: a2.x/y/z += 2 * sext(rnd).
M4VaRnd2PosXyz2:
        move.l a2,-(sp)
        moveq #2,d1
M4VaRnd2PosXyz2Next:
        jsr M4IntroRandom
        ext.w d0
        add.w d0,d0
        add.w d0,(a2)+
        dbra d1,M4VaRnd2PosXyz2Next
        movea.l (sp)+,a2
        rts

; ---------------------------------------------------------------------
; msuck 07:E1F8 (anim at 4): two suck bits (Shyper BF8C at player_pos +
; rnd*4, rotz rnd, z = viewposz + 200, angles from the face raised by 280
; to the bit, suckbits EBEE); every 4th tick while sbyte4 >= 15 a suck cube
; (fireface_b, y - 1000, suckcube EBC7); player lasers (collflags laser and
; friend) pulled (suckobjfast EB8A, colldisable); the player pulled
; (suckobj EB51: x -> 0, y -> 280 Achase n=4, z -> face z n=5).
M4VaSuckTick:
        moveq #1,d7
M4VaSuckBit:
        move.w #M4VaShHyper,d0
        jsr M4EnCreate
        beq.s M4VaSuckBitNext
        move.w M4_SC_PPOSX,(a2)
        move.w M4_SC_PPOSY,2(a2)
        jsr M4IntroRandom
        move.b d0,14(a2)
        bsr M4VaRnd2Pos4
        move.w M4_LVW_POS+4,d0
        addi.w #200,d0
        move.w d0,4(a2)
        move.l #M4VaSuckBitsI,32(a2)
        addi.w #280,2(a0)
        jsr M4EnPitchTo
        move.b d0,12(a2)
        jsr M4EnYawTo
        move.b d0,13(a2)
        subi.w #280,2(a0)
M4VaSuckBitNext:
        dbra d7,M4VaSuckBit
        move.b X_SBYTE4(a0),d0
        cmpi.b #15,d0
        bmi.s M4VaSuckLasers
        move.w M4_LV_GAMEFRAME,d0
        andi.w #3,d0
        bne.s M4VaSuckLasers
        move.w #M4VaShFireB,d0
        jsr M4EnCreate
        beq.s M4VaSuckLasers
        move.w M4_SC_PPOSX,(a2)
        move.w M4_SC_PPOSY,2(a2)
        bsr M4VaRnd2Pos4
        move.w M4_LVW_POS+4,d0
        addi.w #200,d0
        move.w d0,4(a2)
        subi.w #1000,2(a2)
        move.l #M4VaSuckCubeI,32(a2)
M4VaSuckLasers:
        ; find_obj 1F:C7D5/C801 from allst head + 1 (realobj: not the player)
        move.w M4_LV_HEAD,d6
M4VaSuckFind:
        movea.w d6,a2
        move.w X_NEXT(a2),d6
        beq.s M4VaSuckPlayer
        movea.w d6,a2
        cmp.w a0,d6 ;low WORD addresses (lea/movea.w forms differ in bits 24..31)
        beq.s M4VaSuckFind
        cmp.w a1,d6
        beq.s M4VaSuckFind
        move.b 44(a2),d0
        andi.b #CF_LASER|CF_FRIEND,d0
        cmpi.b #CF_LASER|CF_FRIEND,d0
        bne.s M4VaSuckFind
        clr.l 6(a2)
        clr.w 10(a2)
        clr.b 15(a2)
        moveq #4,d2
        bsr M4VaPullXY
        addi.w #50,4(a2)
        move.w M4_LP_PVIEWVZ,d0
        add.w d0,4(a2)
        bset #SF_COLLDISABLE,49(a2)
        bra.s M4VaSuckFind
M4VaSuckPlayer:
        movea.l a1,a2
        moveq #4,d2
        bsr M4VaPullXY
        move.w 4(a2),d0
        move.w 4(a0),d1
        moveq #5,d2
        jsr M4LpAchase
        move.w d0,4(a2)
        rts
; a2.x -> 0, a2.y -> 280 ((10<<4) + 180 + space_viewCY), Achase16 n = d2.
M4VaPullXY:
        move.w (a2),d0
        moveq #0,d1
        jsr M4LpAchase
        move.w d0,(a2)
        move.w 2(a2),d0
        move.w #280,d1
        jsr M4LpAchase
        move.w d0,2(a2)
        rts

; mIexp1 07:E63A: two large explosions (nopolyexp, y - 240, addrnd2posxyz2)
; per tick for sbyte3 ticks; then four huge ones (y - 240; the last three
; addrnd2posy with delays 2, 4, 6), the core appears at the face (y - 240,
; visible, collisions on, state 0) and mexp1.
M4VaIexp:
        moveq #1,d6
M4VaIexpPair:
        move.w #M4_FX_LARGE,d0
        bsr M4VaExpl
        beq.s M4VaIexpPairFail
        bset #F2_NOPOLYEXP,48(a2)
        subi.w #240,2(a2)
        bsr M4VaRnd2PosXyz2
        bra.s M4VaIexpPairNext
M4VaIexpPairFail: ;dummyobj in the original: the random numbers are still drawn
        jsr M4IntroRandom
        jsr M4IntroRandom
        jsr M4IntroRandom
M4VaIexpPairNext:
        dbra d6,M4VaIexpPair
        subq.b #1,X_SBYTE3(a0)
        bne M4VaIexpDone
        move.w #M4_FX_HUGE,d0
        bsr M4VaExpl
        beq.s M4VaIexpHuge
        subi.w #240,2(a2)
M4VaIexpHuge:
        moveq #2,d6
M4VaIexpHugeNext:
        move.w #M4_FX_HUGE,d0
        bsr M4VaExpl
        beq.s M4VaIexpHugeFail
        subi.w #240,2(a2)
        jsr M4FxRandomPos
        move.b d6,19(a2)
        bra.s M4VaIexpHugeLoop
M4VaIexpHugeFail:
        jsr M4IntroRandom
        jsr M4IntroRandom
M4VaIexpHugeLoop:
        addq.b #2,d6
        cmpi.b #8,d6
        bne.s M4VaIexpHugeNext
        move.w X_ALPTR(a0),d0
        beq.s M4VaIexpNoCore
        movea.w d0,a2
        bclr #3,X2_FL4(a2)
        bclr #SF_INVISIBLE,49(a2)
        bclr #SF_COLLDISABLE,49(a2)
        move.l (a0),(a2)
        move.w 4(a0),4(a2)
        subi.w #240,2(a2)
        clr.b X_STATE(a2)
M4VaIexpNoCore:
        addq.b #1,X_STATE(a0)
M4VaIexpDone:
        rts
; mimp1 07:E792 -> d0 = 1: kill (no core). Core state 6 (centre), visible;
; count - 2 (implosion); at 0 the core hides (invisible, colldisable) and
; the eyes come back: minitfire with 8/8, or on route 3 ($1FFF = 2) mlion3
; (10/10, face_1 already) or mlion1 (20/20).
M4VaImp:
        move.w X_ALPTR(a0),d0
        beq.s M4VaImpKill
        movea.w d0,a2
        move.b #6,X_STATE(a2)
        bsr M4VaInvisOff
        subq.b #2,19(a0)
        bne.s M4VaImpDone
        bset #3,X2_FL4(a2)
        bset #SF_INVISIBLE,49(a2)
        bset #SF_COLLDISABLE,49(a2)
        cmpi.b #2,M4_GS_CURLEVEL
        beq.s M4VaImpLion
        move.b #4,X_STATE(a0)
        move.b #8,36(a0)
        move.b #8,37(a0)
        bra.s M4VaImpDone
M4VaImpLion:
        bclr #0,25(a0)
        move.b #10,36(a0)
        move.b #10,37(a0)
        move.b #21,X_STATE(a0)
        cmpi.w #M4VaShFace1,46(a0)
        beq.s M4VaImpDone
        move.b #19,X_STATE(a0)
        move.b #20,36(a0)
        move.b #20,37(a0)
M4VaImpDone:
        moveq #0,d0
        rts
M4VaImpKill:
        moveq #1,d0
        rts
; mlion3 07:E8F5 (route 3): keeprelto_player; Hplasma ($26) from (-/+60,
; -60, 0) aimed at the player on (gameframe & 31) = 15 / 20 while that eye
; lives (al_ptr = player); on even ticks a blowcube; anim as mfire1;
; collisions on, sflag1 off, sbyte3 30; both eyes gone -> mIexp1.
M4VaLion3:
        bsr M4VaKeepRel
        move.w M4_LV_GAMEFRAME,d0
        andi.w #31,d0
        cmpi.w #15,d0
        bne.s M4VaLion3Right
        tst.b 36(a0)
        beq.s M4VaLion3Right
        moveq #-60,d3
        bsr M4VaLionShot
M4VaLion3Right:
        tst.b 37(a0)
        beq.s M4VaLion3Cube
        move.w M4_LV_GAMEFRAME,d0
        andi.w #31,d0
        cmpi.w #20,d0
        bne.s M4VaLion3Cube
        moveq #60,d3
        bsr M4VaLionShot
M4VaLion3Cube:
        btst #0,M4_LV_GAMEFRAME+1
        bne.s M4VaLion3Anim
        move.w #M4VaShFireB,d0
        jsr M4EnCreate
        beq.s M4VaLion3Anim
        move.l (a0),(a2)
        move.w 4(a0),4(a2)
        addi.w #160,2(a2)
        move.l #M4VaBlowCubeI,32(a2)
M4VaLion3Anim:
        bsr M4VaAnimFire
        bclr #SF_COLLDISABLE,49(a0)
        bclr #F2_SFLAG1,48(a0)
        move.b #30,X_SBYTE3(a0)
        tst.b 36(a0)
        bne.s M4VaLion3Done
        tst.b 37(a0)
        bne.s M4VaLion3Done
        move.b #15,X_STATE(a0)
M4VaLion3Done:
        rts
; d3.b = x offset BYTE; weapon_pos (d3, -60, 0), no rotation added.
M4VaLionShot:
        moveq #M4_WT_HPLASMA,d0
        moveq #-60,d4
        moveq #0,d5
        moveq #0,d6
        moveq #0,d7
        movea.l a1,a3
        jsr M4EnFire
        cmpa.w #0,a2
        beq.s M4VaLionShotDone
        move.w a1,X_ALPTR(a2)
M4VaLionShotDone:
        rts

; ---------------------------------------------------------------------
; monolithcol 07:F172: nothing while sflag1; hitflags HF1 (face box) ->
; rebelasercol 06:8820; HF2/HF4 (left/right eye box) while the eye lives:
; hitflash, eye - 1, at 0 its explosions; hitflags 0, collide off, strategy.
M4VaMonoColl:
        btst #F2_SFLAG1,48(a0)
        bne.s M4VaMonoCollEnd
        btst #0,20(a0)
        beq.s M4VaMonoCollL
        clr.b 20(a0)
        bra M4VaRebLaser
M4VaMonoCollL:
        tst.b 36(a0)
        beq.s M4VaMonoCollR
        btst #1,20(a0)
        beq.s M4VaMonoCollR
        bsr M4VaHitFlash
        subq.b #1,36(a0)
        bne.s M4VaMonoCollR
        moveq #-1,d4
        bsr M4VaEyeExp
M4VaMonoCollR:
        tst.b 37(a0)
        beq.s M4VaMonoCollEnd
        btst #2,20(a0)
        beq.s M4VaMonoCollEnd
        bsr M4VaHitFlash
        subq.b #1,37(a0)
        bne.s M4VaMonoCollEnd
        moveq #1,d4
        bsr M4VaEyeExp
M4VaMonoCollEnd:
        clr.b 20(a0)
        bclr #SF_COLLIDE,49(a0)
        jmp M4LcStrategy
M4VaHitFlash:
        bset #SF_HITFLASH,49(a0)
        bset #2,31(a0)
        rts
; rebelasercol 06:8820: a player laser (B369) fires RebElaser (id 2) from
; itself with speed 0, roty + $80, rotx negated, offsets 0, no target; its
; roty, rotx, speed and immuneptr restored; then the strategy.
M4VaRebLaser:
        bclr #SF_COLLIDE,49(a0)
        jsr M4LcCollider
        move.l a2,d0
        beq.s M4VaRebLaserDone
        cmpi.w #M4_SH_P_LASER,46(a2)
        bne.s M4VaRebLaserDone
        move.l a0,-(sp)
        movea.l a2,a0
        move.w 28(a0),-(sp)
        move.w 12(a0),-(sp)
        move.b 15(a0),-(sp)
        clr.b 15(a0)
        addi.b #$80,13(a0)
        neg.b 12(a0)
        moveq #M4_WT_REBELASER,d0
        moveq #0,d3
        moveq #0,d4
        moveq #0,d5
        moveq #0,d6
        moveq #0,d7
        suba.l a3,a3
        jsr M4EnFire
        move.b (sp)+,15(a0)
        move.w (sp)+,12(a0)
        move.w (sp)+,28(a0)
        movea.l (sp)+,a0
M4VaRebLaserDone:
        jmp M4LcStrategy
; makelefteyeexp/makerighteyeexp 07:F1EC/F2EF (d4 = -1 left, +1 right):
; 15 large explosions (relexplode, nopolyexp) at the face + (rnd - 127,
; rnd - 127, 0), z - 20, at the eye (+-320, -480; +-240, -240 when the
; face is not face_0), delay rnd & 15.
M4VaEyeExp:
        moveq #14,d6
M4VaEyeExpNext:
        move.w #M4_FX_LARGE,d0
        bsr M4VaExpl
        beq.s M4VaEyeExpFail
        bset #F2_RELEXPLODE,48(a2)
        bset #F2_NOPOLYEXP,48(a2)
        jsr M4IntroRandom
        subi.w #127,d0
        add.w d0,(a2)
        jsr M4IntroRandom
        subi.w #127,d0
        add.w d0,2(a2)
        jsr M4IntroRandom ;z: (rnd & 0) - 0
        subi.w #20,4(a2)
        move.w #320,d1
        move.w #-480,d2
        cmpi.w #M4VaShFace0,46(a0)
        beq.s M4VaEyeExpAt
        move.w #240,d1
        move.w #-240,d2
M4VaEyeExpAt:
        tst.b d4
        bpl.s M4VaEyeExpX
        neg.w d1
M4VaEyeExpX:
        add.w d1,(a2)
        add.w d2,2(a2)
        jsr M4IntroRandom
        andi.b #15,d0
        move.b d0,19(a2)
        bra.s M4VaEyeExpLoop
M4VaEyeExpFail: ;dummyobj: four random numbers drawn
        jsr M4IntroRandom
        jsr M4IntroRandom
        jsr M4IntroRandom
        jsr M4IntroRandom
M4VaEyeExpLoop:
        dbra d6,M4VaEyeExpNext
        rts

; ---------------------------------------------------------------------
; monolithpart_srou 07:F3F2: 16 panels sface2_b D0F0 at the face + offset,
; sbyte1 = start delay, vz = svar_word1, sword2 BYTE = flash delay,
; monolithpart_Istrat FAA3; the last one gets monolithpartL_Istrat FA99.
M4VaParts:
        clr.l M4_VA_LAST
        lea M4VaPartTable,a3
        moveq #15,d7
M4VaPartsNext:
        move.w #M4VaShPanel,d0
        jsr M4EnCreate
        bne.s M4VaPartsMade
        clr.l M4_VA_LAST
        bra.s M4VaPartsSkip
M4VaPartsMade:
        move.l #M4VaPartI,32(a2)
        move.l (a0),(a2)
        move.w 4(a0),4(a2)
        move.w (a3),d0
        add.w d0,(a2)
        move.w 2(a3),d0
        add.w d0,2(a2)
        move.b 4(a3),36(a2)
        move.w M4_VA_SVW1,10(a2)
        move.b 5(a3),X_SWORD2+1(a2)
        move.l a2,M4_VA_LAST
M4VaPartsSkip:
        addq.l #6,a3
        dbra d7,M4VaPartsNext
        move.l M4_VA_LAST,d0 ;the original writes Y = 0 (DP) when the last failed
        beq.s M4VaPartsDone
        movea.l d0,a2
        move.l #M4VaPartLI,32(a2)
M4VaPartsDone:
        rts
; x, y (monolithpart x*120, y*200), sbyte1, sword2 (07:F3F2..F95F).
M4VaPartTable:
        include '../build/m4-andross-panels.inc'
; monolithpartL_Istrat 07:FA99: sflag1, sbyte2 10, then FAA3.
M4VaPartLI:
        bset #F2_SFLAG1,48(a0)
        move.b #10,37(a0)
; monolithpart_Istrat 07:FAA3: strategy FB42, collstrat hitflash, no
; expstrat; HP $FF / AP 8, enemy1, colldisable, never zremoved; spin
; (sbyte3, sbyte4) = (+-8, +-8) by rnd & 3 (1: ++, 2: -+, 3: +-, 0: --);
; sword1 BYTE 15, colanim 0.
M4VaPartI:
        move.l #M4VaPart,32(a0)
        move.l #M4LcHitFlash,X_COLL(a0)
        clr.l X_EXP(a0)
        move.b #$ff,38(a0)
        move.b #8,39(a0)
        ori.b #CF_ENEMY1,44(a0)
        bset #SF_COLLDISABLE,49(a0)
        bclr #3,45(a0)
        jsr M4IntroRandom
        andi.b #3,d0
        moveq #8,d1
        moveq #8,d2
        cmpi.b #1,d0
        beq.s M4VaPartSpin
        moveq #-8,d1
        cmpi.b #2,d0
        beq.s M4VaPartSpin
        moveq #8,d1
        moveq #-8,d2
        cmpi.b #3,d0
        beq.s M4VaPartSpin
        moveq #-8,d1
M4VaPartSpin:
        move.b d1,X_SBYTE3(a0)
        move.b d2,X_SBYTE4(a0)
        move.b #15,41(a0)
        move.b #$80,18(a0)
; monolithpart_strat 07:FB42: removed once the face shows (BF_flag2); every
; sbyte1 ticks (then every tick): 15 moves (z += vz, rotx += sbyte3, roty +=
; sbyte4); then sface_b, rots 0; the last panel sets BF_flag3 and after 10
; more ticks BF_flag1 and psvar_word1 = its z. With BF_flag3 each panel
; flashes when its sword2 BYTE reaches 0. add_playerZ.
M4VaPart:
        btst #1,M4_VA_BFLAGS
        bne M4VaRemove
        subq.b #1,36(a0)
        bne.s M4VaPartEnd
        move.b #1,36(a0)
        tst.b 41(a0)
        beq.s M4VaPartStop
        subq.b #1,41(a0)
        move.w 10(a0),d0
        add.w d0,4(a0)
        move.b X_SBYTE3(a0),d0
        add.b d0,12(a0)
        move.b X_SBYTE4(a0),d0
        add.b d0,13(a0)
        bra.s M4VaPartEnd
M4VaPartStop:
        move.w #M4VaShPanelS,d0
        jsr M4LevelSetShape
        clr.b 13(a0)
        clr.b 12(a0)
        btst #F2_SFLAG1,48(a0)
        beq.s M4VaPartEnd
        bset #2,M4_VA_BFLAGS
        subq.b #1,37(a0)
        bne.s M4VaPartEnd
        bset #0,M4_VA_BFLAGS
        move.w 4(a0),M4_VA_PSVW1
M4VaPartEnd:
        btst #2,M4_VA_BFLAGS
        beq.s M4VaPartMove
        subq.b #1,X_SWORD2+1(a0)
        bne.s M4VaPartMove
        bsr M4VaHitFlash
M4VaPartMove:
        jsr M4EnAddPZ
        moveq #0,d0
        rts

; ---------------------------------------------------------------------
; mfire1a_Istrat 07:F972 (split shot): HP $FF / AP 8, no pointers.
M4VaFire1aI:
        move.b #$ff,38(a0)
        move.b #8,39(a0)
        move.l #M4VaFire1,32(a0)
        clr.l X_COLL(a0)
        clr.l X_EXP(a0)
        bra.s M4VaFire1Cont
; mfire1_Istrat 07:F98E (eye shot fireface1_b): HP 2 / AP 8, hitflash,
; expstrat FA2A.
M4VaFire1I:
        move.b #2,38(a0)
        move.b #8,39(a0)
        move.l #M4VaFire1,32(a0)
        move.l #M4LcHitFlash,X_COLL(a0)
        move.l #M4VaFire1Exp,X_EXP(a0)
; 07:F9BD: speed 80, enemy1, aimed at the player (obj2obj_3dangle), roty +=
; sbyte1, gen_3dvecs, sbyte1 = $80, relexplode, rotx = rnd.
M4VaFire1Cont:
        move.b #80,15(a0)
        ori.b #CF_ENEMY1,44(a0)
        movea.l a1,a2
        jsr M4EnPitchTo
        move.b d0,12(a0)
        jsr M4EnYawTo
        move.b d0,13(a0)
        move.b 36(a0),d0
        add.b d0,13(a0)
        jsr M4EnGen3d
        move.b #$80,36(a0)
        bset #F2_RELEXPLODE,48(a0)
        jsr M4IntroRandom
        move.b d0,12(a0)
; mfire1_strat 07:FA1A: rotx + 12, add_vecs2pos, add_playerZ.
M4VaFire1:
        addi.b #12,12(a0)
        jsr M4EnMove
        jsr M4EnAddPZ
        moveq #0,d0
        rts
; mfire1exp 07:FA2A: behind the player (!N(pz - z)) it just explodes;
; else it splits into two fireface_b (mfire1a, sbyte1 +4 / -4) first.
M4VaFire1Exp:
        move.w 4(a1),d0
        sub.w 4(a0),d0
        bpl.s M4VaFire1ExpNow
        moveq #4,d3
        bsr M4VaFire1Split
        moveq #-4,d3
        bsr M4VaFire1Split
M4VaFire1ExpNow:
        jmp M4LevelExplode
M4VaFire1Split:
        move.w #M4VaShFireB,d0
        jsr M4EnCreate
        beq.s M4VaFire1SplitDone
        move.l (a0),(a2)
        move.w 4(a0),4(a2)
        move.l #M4VaFire1aI,32(a2)
        move.b d3,36(a2)
M4VaFire1SplitDone:
        rts

; suckcube_Istrat 07:EBC7: count 20, never zremoved, colldisable; strat
; EBE4: rotx + 12, then suckbits_cont.
M4VaSuckCubeI:
        move.b #20,19(a0)
        bclr #3,45(a0)
        move.l #M4VaSuckCube,32(a0)
        bset #SF_COLLDISABLE,49(a0)
M4VaSuckCube:
        addi.b #12,12(a0)
        bra.s M4VaSuckBits
; suckbits_Istrat 07:EBEE: count 6, never zremoved, colldisable; strat
; EC0B: z + 60, x -> 0, y -> 280 (Achase16 n=2), add_playerZ, count - 1:
; removed at 0.
M4VaSuckBitsI:
        move.b #6,19(a0)
        bclr #3,45(a0)
        move.l #M4VaSuckBits,32(a0)
        bset #SF_COLLDISABLE,49(a0)
M4VaSuckBits:
        addi.w #60,4(a0)
        movea.l a0,a2
        moveq #2,d2
        bsr M4VaPullXY
        jsr M4EnAddPZ
        subq.b #1,19(a0)
        beq M4VaRemove
        moveq #0,d0
        rts
; blowcube_Istrat 07:EC4A: HP $FF / AP 4; aimed at the player with
; offsets (rnd & 15) - 7 on roty and rotx, speed 80, gen_3dvecs, then
; random rotations, collflags $40. Strat ECEE: roty + 4, rotx + 8, move,
; add_playerZ.
M4VaBlowCubeI:
        move.l #M4VaBlowCube,32(a0)
        move.b #$ff,38(a0)
        move.b #4,39(a0)
        jsr M4IntroRandom
        andi.b #15,d0
        subq.b #7,d0
        move.b d0,d3
        jsr M4IntroRandom
        andi.b #15,d0
        subq.b #7,d0
        move.b d0,d4
        movea.l a1,a2
        jsr M4EnPitchTo
        move.b d0,12(a0)
        jsr M4EnYawTo
        move.b d0,13(a0)
        add.b d3,13(a0)
        add.b d4,12(a0)
        move.b #80,15(a0)
        jsr M4EnGen3d
        jsr M4IntroRandom
        move.b d0,13(a0)
        jsr M4IntroRandom
        move.b d0,12(a0)
        ori.b #$40,44(a0)
M4VaBlowCube:
        addq.b #4,13(a0)
        addq.b #8,12(a0)
        jsr M4EnMove
        jsr M4EnAddPZ
        moveq #0,d0
        rts

; ---------------------------------------------------------------------
; mcore1_Istrat 07:ED05: strategy ED92, collstrat F08D, expstrat F09C; HP
; 30 / 50 / 100 (AP 40) for $1FFF = 0 / 1 / 2; routes 2/3: face_box and
; colanim 0; rots ($80, $E0, 0), relexplode.
M4VaCoreI:
        move.l #M4VaCore,32(a0)
        move.l #M4VaCoreColl,X_COLL(a0)
        move.l #M4VaCoreExpI,X_EXP(a0)
        move.b M4_GS_CURLEVEL,d0
        moveq #30,d1
        tst.b d0
        beq.s M4VaCoreHp
        moveq #50,d1
        cmpi.b #1,d0
        beq.s M4VaCoreHp
        moveq #100,d1
        cmpi.b #2,d0
        bne.s M4VaCoreNoHp
M4VaCoreHp:
        move.b d1,38(a0)
        move.b #40,39(a0)
M4VaCoreNoHp:
        tst.b M4_GS_CURLEVEL
        beq.s M4VaCoreRots
        move.w #M4VaShFaceBox,d0
        jsr M4LevelSetShape
        move.b #$80,18(a0)
M4VaCoreRots:
        move.b #$80,12(a0)
        move.b #$e0,13(a0)
        clr.b 14(a0)
        bset #F2_RELEXPLODE,48(a0)
; mcore1_strat 07:ED92. Routes 2/3: colanim 0/1/2 by HP (<= 60, <= 30).
; Invisible: add_playerZ only.
M4VaCore:
        tst.b M4_GS_CURLEVEL
        beq.s M4VaCoreVis
        move.b #$80,18(a0)
        move.b 38(a0),d0
        subi.b #60,d0
        beq.s M4VaCoreCol1
        bpl.s M4VaCoreVis
M4VaCoreCol1:
        move.b #$81,18(a0)
        move.b 38(a0),d0
        subi.b #30,d0
        beq.s M4VaCoreCol2
        bpl.s M4VaCoreVis
M4VaCoreCol2:
        move.b #$82,18(a0)
M4VaCoreVis:
        btst #3,X2_FL4(a0)
        bne M4VaCoreNoMove
        ; 0 EDE2: nohitaffect, sbyte1 20
        tst.b X_STATE(a0)
        bne.s M4VaC1
        bset #SF_NOHITAFFECT,49(a0)
        move.b #20,36(a0)
        addq.b #1,X_STATE(a0)
M4VaC1: ; 1 EDFE: wait sbyte1
        cmpi.b #1,X_STATE(a0)
        bne.s M4VaC2
        tst.b 36(a0)
        beq M4VaCoreNext
        subq.b #1,36(a0)
M4VaC2: ; 2 EE13 zoomup: circle (sbyte2 + 8), toward the player; within
        ; 1500 -> 3; vz -> -80 by 10
        cmpi.b #2,X_STATE(a0)
        bne.s M4VaC3
        bset #SF_NOHITAFFECT,49(a0)
        bsr M4VaCoreCircle
        movea.l a1,a2
        jsr M4EnZD
        subi.w #1500,d0
        bmi M4VaCoreNext
        bsr M4VaCoreZrot
        cmpi.w #-80,10(a0)
        beq.s M4VaC3
        subi.w #10,10(a0)
M4VaC3: ; 3 EEB2 zoomaway: beyond 6000 -> 2; vz -> 100 by 10, x -> 0,
        ; y -> -60 (Achase n=3); vz 0 -> 4
        cmpi.b #3,X_STATE(a0)
        bne.s M4VaC4
        bsr M4VaCoreCircle
        movea.l a1,a2
        jsr M4EnZD
        cmpi.w #6000,d0
        bpl M4VaCoreSet2
        bsr M4VaCoreZrot
        cmpi.w #100,10(a0)
        beq.s M4VaC4
        addi.w #10,10(a0)
        move.w (a0),d0
        moveq #0,d1
        moveq #3,d2
        jsr M4LpAchase
        move.w d0,(a0)
        move.w 2(a0),d0
        moveq #-60,d1
        moveq #3,d2
        jsr M4LpAchase
        move.w d0,2(a0)
        tst.w 10(a0)
        beq M4VaCoreSet4
M4VaC4: ; 4 EF79 flipI: vulnerable, sbyte1 32 (route 3: 64), stopped
        cmpi.b #4,X_STATE(a0)
        bne.s M4VaC5
        bclr #SF_NOHITAFFECT,49(a0)
        move.b #32,36(a0)
        cmpi.b #2,M4_GS_CURLEVEL
        bne.s M4VaC4Stop
        move.b #64,36(a0)
M4VaC4Stop:
        clr.w 6(a0)
        clr.l 8(a0)
        clr.b 15(a0)
        addq.b #1,X_STATE(a0)
M4VaC5: ; 5 EFA8 flip: sbyte1 ticks -> 2; rotx + 4 (route 3: z - 10,
        ; rots -> ($80, $E0, 0) Achase8 n=3, tx + 2)
        cmpi.b #5,X_STATE(a0)
        bne.s M4VaC6
        tst.b 36(a0)
        beq M4VaCoreSet2
        subq.b #1,36(a0)
        cmpi.b #2,M4_GS_CURLEVEL
        beq.s M4VaC5Lion
        addq.b #4,12(a0)
        bra.s M4VaC6
M4VaC5Lion:
        subi.w #10,4(a0)
        bsr M4VaCoreRotHome
        addq.b #2,X_TX(a0)
M4VaC6: ; 6 F00B centre (set by mimp1): rots home, x -> 0, y -> viewCY,
        ; z -> player_posz + 2500 (Achase n=3), nohitaffect, stopped
        cmpi.b #6,X_STATE(a0)
        bne.s M4VaCoreMove
        bsr M4VaCoreRotHome
        bset #SF_NOHITAFFECT,49(a0)
        move.w (a0),d0
        moveq #0,d1
        moveq #3,d2
        jsr M4LpAchase
        move.w d0,(a0)
        move.w 2(a0),d0
        move.w M4_LP_VIEWCY,d1
        jsr M4LpAchase
        move.w d0,2(a0)
        move.w M4_LP_POSZ,d1
        addi.w #2500,d1
        move.w 4(a0),d0
        jsr M4LpAchase
        move.w d0,4(a0)
        clr.w 6(a0)
        clr.l 8(a0)
        clr.b 15(a0)
M4VaCoreMove:
        jsr M4EnMove
M4VaCoreNoMove:
        jsr M4EnAddPZ
        moveq #0,d0
        rts
M4VaCoreNext:
        addq.b #1,X_STATE(a0)
        bra M4VaCore
M4VaCoreSet2:
        move.b #2,X_STATE(a0)
        bra M4VaCore
M4VaCoreSet4:
        move.b #4,X_STATE(a0)
        bra M4VaCore
; sbyte2 += 8; vx = sin8(sbyte2) / 2, vy = cos8(sbyte2) / 2 (toward zero).
M4VaCoreCircle:
        addq.b #8,37(a0)
        lea M4IntroShipSine,a2
        moveq #0,d1
        move.b 37(a0),d1
        move.b (a2,d1.w),d0
        ext.w d0
        bpl.s M4VaCoreSin
        addq.w #1,d0
M4VaCoreSin:
        asr.w #1,d0
        move.w d0,6(a0)
        move.b 64(a2,d1.w),d0
        ext.w d0
        bpl.s M4VaCoreCos
        addq.w #1,d0
M4VaCoreCos:
        asr.w #1,d0
        move.w d0,8(a0)
        rts
; mcoreZrot_srou 07:F161: rotz += asr3(lo8(vz)).
M4VaCoreZrot:
        move.b 11(a0),d0
        asr.b #3,d0
        add.b d0,14(a0)
        rts
; rotx -> $80, roty -> $E0, rotz -> 0 (Achase8 n=3, 1F:D8BD).
M4VaCoreRotHome:
        moveq #3,d2
        move.b 12(a0),d0
        move.b #$80,d1
        jsr M4EnChase8
        move.b d0,12(a0)
        move.b 13(a0),d0
        move.b #$e0,d1
        jsr M4EnChase8
        move.b d0,13(a0)
        move.b 14(a0),d0
        moveq #0,d1
        jsr M4EnChase8
        move.b d0,14(a0)
        rts
; mcore1col 07:F08D: state 5 hitflash (damage), else ricochet 06:889E.
M4VaCoreColl:
        cmpi.b #5,X_STATE(a0)
        beq.s M4VaCoreFlash
        jmp M4B1Ricochet
M4VaCoreFlash:
        jmp M4LcHitFlash
; mcore1exp_Istrat 07:F09C (HP 0; music cut and trigse $A1 not ported):
; expstrat F0BB from now on.
M4VaCoreExpI:
        move.l #M4VaCoreExp,X_EXP(a0)
; 07:F0BB: z + 60, rotz + 12, rotx + 12, add_playerZ; once |pz - z| >= 3000:
; huge explosion, six andross cubes (blowcube, colldisable) at z + 0, 100,
; ..., 500, then qbossexplode 06:EA92.
M4VaCoreExp:
        addi.w #60,4(a0)
        addi.b #12,14(a0)
        addi.b #12,12(a0)
        jsr M4EnAddPZ
        movea.l a1,a2
        jsr M4EnZD
        subi.w #3000,d0
        bmi.s M4VaCoreExpWait
        move.w #M4_FX_HUGE,d0
        bsr M4VaExpl
        moveq #0,d3
        moveq #5,d7
M4VaCoreExpCube:
        move.w #M4VaShAndross,d0
        jsr M4EnCreate
        beq.s M4VaCoreExpCubeNext
        move.l (a0),(a2)
        move.w 4(a0),4(a2)
        move.l #M4VaBlowCubeI,32(a2)
        bset #SF_COLLDISABLE,49(a2)
        add.w d3,4(a2)
        addi.w #100,d3
M4VaCoreExpCubeNext:
        dbra d7,M4VaCoreExpCube
; qbossexplode 06:EA92: count 0, gameflags bossdead, relexplode, sflags2
; $10, then the flash timer 06:EE72 (level_boss1.asm M4B1FlashInit: circle
; object and BIGParticleexplode at once, then removed).
        clr.b 19(a0)
        bset #2,M4_LP_GAMEFLAGS
        bset #F2_RELEXPLODE,48(a0)
        bset #F2_SFLAG1,48(a0)
        jmp M4B1FlashInit
M4VaCoreExpWait:
        moveq #0,d0
        rts

; Corneria 1 boss "Attack Carrier" (boss7 07:CF7C) and its parts, zaco_6
; (zaco2_Istrat 08:AF57), HMISSILE (06:B0DE) and the large explosions.
; Specification: build/research/corneria-boss.md (oracle tools/boss-oracle.py);
; correspondence in LEVEL_ORIGIN.md. Mother/child links as the path
; interpreter: child id in sbyte1 (36), mother in X_ALPTR, chain in sword1
; (40), X2_FL4 bit6 mother / bit4 child. Mother flags read by the parts:
; F2_SFLAG1 (sflags2 $10, hatch open), F2_SFLAG2 (sflags2 $20, launchers).
M4_BOSS equ M4_LV+120
M4_BOSS_MAXHP equ M4_BOSS+0 ;.b 70:019A m_bossmaxHP
M4_BOSS_HP equ M4_BOSS+1 ;.b 70:019C m_bossHP (rebuilt every tick)
M4_BOSS_DYING equ M4_BOSS+2 ;.b bossflags $14D5 bit4
M4_BOSS_STAGECLEAR equ M4_BOSS+3 ;.b $15BA
M4_BOSS_PSTRATF equ M4_BOSS+6 ;.b $14DF pstratflags ($20 notdie)
M4_BOSS_HUDHP equ M4_BOSS+7 ;.b bar value shown (mdrawbossHP 01:AFEB)

M4BossLevelInit:
        clr.l M4_BOSS
        clr.l M4_BOSS+4
        rts

; ---------------------------------------------------------------------
; Family helpers.
; d0 = id -> a2 child of a0 (find_child 1F:DC40) or 0. Z set when none.
M4BsChild:
        movea.l a0,a2
        jsr M4PvFindChild
        cmpa.w #0,a2
        rts
; d0 = number of children in the chain (07:D1C6).
M4BsCount:
        move.l a2,-(sp)
        moveq #0,d0
        move.w 40(a0),d1
M4BsCountNext:
        tst.w d1
        beq M4BsCountDone
        addq.w #1,d0
        movea.w d1,a2
        move.w 40(a2),d1
        bra M4BsCountNext
M4BsCountDone:
        movea.l (sp)+,a2
        rts
; Create a part: d0 descriptor, d1 id, d2.l Istrat -> linked at the end of
; the chain of a0 (link_child 1F:D56F), collflags enemy1.
M4BsMakePart:
        movem.l d0-d2/a3,-(sp)
        jsr M4EnCreate
        beq M4BsMakeFail
        move.l d2,32(a2)
        ori.b #CF_ENEMY1,44(a2)
        move.b d1,36(a2)
        move.w a0,X_ALPTR(a2)
        clr.w 40(a2)
        movea.l a0,a3
M4BsMakeTail:
        move.w 40(a3),d0
        beq M4BsMakeLink
        movea.w d0,a3
        bra M4BsMakeTail
M4BsMakeLink:
        move.w a2,40(a3)
        bset #6,X2_FL4(a0)
        bset #4,X2_FL4(a2)
        movem.l (sp)+,d0-d2/a3
        rts
M4BsMakeFail: ;1F:BDEE debug restart in the original: fatal in the port
        move.w #-1,M4_LV_STATUS
        move.w #$7d00,M4_LV_BADOP
        movem.l (sp)+,d0-d2/a3
        rts
; Child placement (07:D905/DC1B/DD3A): rots copied from the mother, then
; pos = mother + 8*(rot_y8(dx, 0, roty).x, dy, rot_y8.z). d3.b dx, d4.b dy.
M4BsPlace:
        movem.l d0-d5/a2,-(sp)
        move.w X_ALPTR(a0),d0
        beq M4BsPlaceDone
        movea.w d0,a2
        move.w 12(a2),12(a0)
        move.b 14(a2),14(a0)
        move.b d4,d0
        moveq #0,d4 ;z offset 0
        move.b 13(a0),d5
        neg.b d5
        jsr M4WeaponRotatePair ;rot_y8 1F:C97B: (x, z) by -roty
        ext.w d3
        ext.w d4
        asl.w #3,d3
        asl.w #3,d4
        ext.w d0
        asl.w #3,d0
        add.w (a2),d3
        add.w 2(a2),d0
        add.w 4(a2),d4
        move.w d3,(a0)
        move.w d0,2(a0)
        move.w d4,4(a0)
M4BsPlaceDone:
        movem.l (sp)+,d0-d5/a2
        rts
; colframe = ((colframe & $7F) + 1) mod 4 | $80
M4BsColCycle:
        move.b 18(a0),d0
        addq.b #1,d0
        andi.b #3,d0
        ori.b #$80,d0
        move.b d0,18(a0)
        rts
; Mother flags of a part -> d0.b (port flags2 byte of the mother).
M4BsMotherFlags:
        moveq #0,d0
        move.w X_ALPTR(a0),d1
        beq M4BsMotherNone
        movea.w d1,a2
        move.b 48(a2),d0
M4BsMotherNone:
        rts

; ---------------------------------------------------------------------
; Body. Istrat 07:CF7C: HP 40 / AP 20 (route 1: $1FFF = 0), bar maximum,
; never zremoved, the four parts (hatch 1, shield 2, launchers 3/4) created
; and linked; speed 20; immune until every part is gone. D0F5 next tick.
M4StratBoss7:
        move.l #M4Boss7A,32(a0)
        clr.l X_COLL(a0)
        move.l #M4Boss7Die,X_EXP(a0)
        move.b #40,38(a0)
        move.b #20,39(a0)
        move.b #40,M4_BOSS_MAXHP
        clr.b M4_BOSS_HP
        ori.b #CF_ENEMY1,44(a0)
        bclr #3,45(a0)
        bset #F2_SHADOW,48(a0)
        move.l #M4_SH_BOSS_7_0,d0 ;descriptor index may exceed 127
        moveq #1,d1
        move.l #M4StratHatch,d2
        bsr M4BsMakePart
        move.l #M4_SH_BOSS_7_2,d0 ;descriptor index may exceed 127
        moveq #2,d1
        move.l #M4StratShield,d2
        bsr M4BsMakePart
        move.l #M4_SH_BOSS_7_3,d0 ;descriptor index may exceed 127
        moveq #3,d1
        move.l #M4StratLauncherT,d2
        bsr M4BsMakePart
        move.l #M4_SH_BOSS_7_4,d0 ;descriptor index may exceed 127
        moveq #4,d1
        move.l #M4StratLauncherB,d2
        bsr M4BsMakePart
        move.b #20,15(a0)
        bset #SF_NOHITAFFECT,49(a0)
        moveq #0,d0
        rts

; boss7_cont 07:D17A: keeprelto_player (z += player vz - pviewvelz), move
; along (rotx, sbyte2), the body kills the shield when both launchers are
; gone, no parts left -> alldead.
M4Boss7Cont:
        move.w 10(a1),d0
        sub.w M4_LP_PVIEWVZ,d0
        add.w d0,4(a0)
        moveq #0,d0
        move.b 15(a0),d0
        ext.w d0
        move.b 12(a0),d1
        move.b 37(a0),d2
        jsr M4EnVector
        movem.w d3-d5,6(a0)
        jsr M4EnMove
        moveq #3,d0
        bsr M4BsChild
        bne M4Boss7ContCount
        moveq #4,d0
        bsr M4BsChild
        bne M4Boss7ContCount
        moveq #2,d0
        bsr M4BsChild
        beq M4Boss7ContCount
        bset #SF_COLLDISABLE,49(a2)
        clr.b 38(a2)
M4Boss7ContCount:
        bsr M4BsCount
        tst.w d0
        beq M4Boss7AllDeadInit
; boss7_cont2 07:D1E0
M4Boss7Cont2:
        jsr M4EnAddPZ
        move.b 38(a0),d0
        add.b d0,M4_BOSS_HP
        moveq #0,d0
        rts

; a 07:D0F5: approach; ahead of the player by 1360: brake (every 4th tick),
; turn round (+1/tick, open shape at $40) and descend to -320, then b.
M4Boss7A:
        movea.l a1,a2
        jsr M4EnZD
        subi.w #1360,d0
        bmi M4Boss7Cont
        move.w M4_LV_GAMEFRAME,d0
        andi.w #3,d0
        bne M4Boss7ATurn
        moveq #0,d0
        moveq #1,d1
        jsr M4EnSpeedTo
M4Boss7ATurn:
        cmpi.b #$80,13(a0)
        beq M4Boss7ADown
        bsr M4BsColCycle
        addq.b #1,13(a0)
        cmpi.b #$40,13(a0)
        bne M4Boss7ADown
        move.l #M4_SH_BOSS_7_1O,d0 ;descriptor index may exceed 127
        jsr M4LevelSetShape
M4Boss7ADown:
        move.w 2(a0),d0
        addi.w #320,d0
        bpl M4Boss7BInit
        addq.w #2,2(a0)
        bra M4Boss7Cont

; b 07:D4DC/D508: hatch open (sflag1) while turning to $70 and 30 ticks.
M4Boss7BInit:
        moveq #1,d0
        bsr M4BsChild
        beq M4Boss7C2Init
        move.l #M4Boss7B,32(a0)
        bset #F2_SFLAG1,48(a0)
        bclr #F2_SFLAG2,48(a0)
        move.b #30,X_SBYTE4(a0)
M4Boss7B:
        move.b #$70,d1
        bsr M4Boss7Turn4
        beq M4Boss7Cont
        tst.b X_SBYTE4(a0)
        beq M4Boss7DInit
        subq.b #1,X_SBYTE4(a0)
        bra M4Boss7Cont
; (roty, C) = Achase8_4(roty, d1): Z clear when it was already there.
M4Boss7Turn4:
        move.b 13(a0),d0
        moveq #4,d2
        jsr M4EnChase8
        move.b d0,13(a0)
        tst.w d3
        rts

; d 07:D626/D643 (loop 1, 48 ticks) and e 07:D6DF/D70B (loop 2, 16 ticks):
; y -= trunc0(sin/8), z -= trunc0(cos/2) of sbyte3, roty -> $80, sbyte3 += 4.
M4Boss7DInit:
        move.l #M4Boss7D,32(a0)
        bclr #F2_SFLAG1,48(a0)
        bclr #F2_SFLAG2,48(a0)
        clr.b X_SBYTE3(a0)
M4Boss7D:
        bsr M4Boss7Loop
        cmpi.b #$c0,X_SBYTE3(a0)
        bne M4Boss7Cont
        bra M4Boss7CInit
M4Boss7EInit:
        moveq #1,d0
        bsr M4BsChild
        beq M4Boss7C2Init
        move.l #M4Boss7E,32(a0)
        bclr #F2_SFLAG1,48(a0)
        bclr #F2_SFLAG2,48(a0)
        move.b #$c0,X_SBYTE3(a0)
M4Boss7E:
        bsr M4Boss7Loop
        tst.b X_SBYTE3(a0)
        bne M4Boss7Cont
        bra M4Boss7BInit
M4Boss7Loop:
        lea M4IntroShipSine,a3
        moveq #0,d0
        move.b X_SBYTE3(a0),d0
        move.b (a3,d0.w),d1
        ext.w d1
        bpl M4Boss7LoopSin
        addq.w #7,d1
M4Boss7LoopSin:
        asr.w #3,d1
        sub.w d1,2(a0)
        move.b 64(a3,d0.w),d1
        ext.w d1
        bpl M4Boss7LoopCos
        addq.w #1,d1
M4Boss7LoopCos:
        asr.w #1,d1
        sub.w d1,4(a0)
        move.b #$80,d1
        bsr M4Boss7Turn4
        addq.b #4,X_SBYTE3(a0)
        rts

; c 07:D563/D58F: launchers open (sflag2), roty -> $90, 50 ticks;
; c2 07:D5B1/D5C8: launchers hidden, roty -> $B0, 15 ticks, then c.
M4Boss7CInit:
        moveq #2,d0
        bsr M4BsChild
        beq M4Boss7EInit
        move.l #M4Boss7C,32(a0)
        bclr #F2_SFLAG1,48(a0)
        bset #F2_SFLAG2,48(a0)
        move.b #50,X_SBYTE4(a0)
M4Boss7C:
        move.b #$90,d1
        bsr M4Boss7Turn4
        beq M4Boss7Launch
        tst.b X_SBYTE4(a0)
        beq M4Boss7EInit
        subq.b #1,X_SBYTE4(a0)
        bra M4Boss7Launch
M4Boss7C2Init:
        move.l #M4Boss7C2,32(a0)
        bclr #F2_SFLAG2,48(a0)
        move.b #15,X_SBYTE4(a0)
M4Boss7C2:
        move.b #$b0,d1
        bsr M4Boss7Turn4
        beq M4Boss7Launch
        tst.b X_SBYTE4(a0)
        beq M4Boss7CInit
        subq.b #1,X_SBYTE4(a0)
; boss7launch_cont 07:D5EA: with hatch and lower launcher gone, climb back
; to -240 (+2/tick).
M4Boss7Launch:
        moveq #1,d0
        bsr M4BsChild
        bne M4Boss7Cont
        moveq #4,d0
        bsr M4BsChild
        bne M4Boss7Cont
        move.w 2(a0),d0
        addi.w #240,d0
        bpl M4Boss7Cont
        addq.w #2,2(a0)
        bra M4Boss7Cont

; alldead 07:D2EC..D49B: the body becomes vulnerable (hitflash), returns to
; the player, turns away 37 ticks, flies off 51 ticks, turns back 37 ticks;
; two Hplasma every 32 ticks while approaching.
M4Boss7AllDeadInit:
        move.l #M4Boss7AllDead,32(a0)
        move.l #M4LcHitFlash,X_COLL(a0)
        move.l #M4_SH_BOSS_7_1,d0 ;descriptor index may exceed 127
        jsr M4LevelSetShape
        bclr #SF_NOHITAFFECT,49(a0)
M4Boss7AllDead:
        move.b 14(a0),d0
        moveq #0,d1
        moveq #3,d2
        jsr M4EnChase8
        move.b d0,14(a0)
        move.w (a0),d0
        move.w M4_SC_PPOSX,d1 ;07:D331 player_posx $150F
        moveq #4,d2
        jsr M4LpAchase
        move.w d0,(a0)
        movea.l a1,a2
        jsr M4EnZD
        subi.w #600,d0
        bmi M4Boss7AllDeadAInit
        jsr M4EnYawTo
        move.b d0,d1
        move.b 13(a0),d0
        moveq #2,d2
        jsr M4EnChase8
        move.b d0,13(a0)
        moveq #30,d0
        moveq #1,d1
        jsr M4EnSpeedTo
        move.w 2(a0),d0
        addi.w #160,d0
        bpl M4Boss7AllDeadFire
        addi.w #10,2(a0)
M4Boss7AllDeadFire:
        move.w M4_LV_GAMEFRAME,d0
        andi.w #$1f,d0
        cmpi.w #25,d0
        beq M4Boss7Plasma
        cmpi.w #30,d0
        bne M4Boss7AllDeadCont
M4Boss7Plasma:
        moveq #2,d0
        moveq #0,d3
        moveq #0,d4
        moveq #$50,d5
        moveq #0,d6
        moveq #0,d7
        suba.l a3,a3
        jsr M4EnFire
        cmpa.w #0,a2
        beq M4Boss7AllDeadCont
        move.w a1,X_ALPTR(a2)
        bra M4Boss7AllDeadCont
M4Boss7AllDeadAInit:
        move.l #M4Boss7AllDeadA,32(a0)
        move.b #36,37(a0)
        bchg #F2_SFLAG1,48(a0)
M4Boss7AllDeadA:
        bsr M4Boss7Bank
        tst.b 37(a0)
        beq M4Boss7AllDeadCInit
        subq.b #1,37(a0)
        bra M4Boss7AllDeadCont
M4Boss7AllDeadCInit:
        move.l #M4Boss7AllDeadC,32(a0)
        move.b #50,37(a0)
M4Boss7AllDeadC:
        moveq #50,d0
        moveq #1,d1
        jsr M4EnSpeedTo
        move.b 14(a0),d0
        moveq #0,d1
        moveq #3,d2
        jsr M4EnChase8
        move.b d0,14(a0)
        tst.b 37(a0)
        beq M4Boss7AllDeadBInit
        subq.b #1,37(a0)
        bra M4Boss7AllDeadCont
M4Boss7AllDeadBInit:
        move.l #M4Boss7AllDeadB,32(a0)
        move.b #36,37(a0)
M4Boss7AllDeadB:
        moveq #30,d0
        moveq #1,d1
        jsr M4EnSpeedTo
        bchg #F2_SFLAG1,48(a0)
        bsr M4Boss7Bank
        bchg #F2_SFLAG1,48(a0)
        tst.b 37(a0)
        beq M4Boss7AllDeadInit
        subq.b #1,37(a0)
; boss7_alldeadcont 07:D1F0: move along (rotx, roty), colours cycle.
M4Boss7AllDeadCont:
        jsr M4EnGen3d
        jsr M4EnMove
        bsr M4BsColCycle
        bra M4Boss7Cont2
; sflag1: rotz - 1, roty - 4; else rotz + 1, roty + 4.
M4Boss7Bank:
        btst #F2_SFLAG1,48(a0)
        beq M4Boss7BankPos
        subq.b #1,14(a0)
        subq.b #4,13(a0)
        rts
M4Boss7BankPos:
        addq.b #1,14(a0)
        addq.b #4,13(a0)
        rts

; Death 07:D226/D283 (expstrat, HP 0): rises then falls with large
; explosions every 2nd tick, spinning faster; the player cannot die nor
; fire; on the ground -> bossbigoutexplode 06:EC68.
M4Boss7Die:
        move.l #M4Boss7Fall,X_EXP(a0)
        clr.w 6(a0)
        move.w #-30,8(a0)
        move.w #20,10(a0)
        move.b #2,37(a0)
        clr.b X_SBYTE3(a0)
        tst.b M4_BOSS_DYING
        bne M4Boss7Fall
        st M4_BOSS_DYING
        bset #5,M4_BOSS_PSTRATF
        bset #6,M4_LP_PSF
M4Boss7Fall:
        btst #0,M4_LV_GAMEFRAME+1
        bne M4Boss7FallSpin
        bsr M4FxLarge
        beq M4Boss7FallSpin
        bset #F2_NOPOLYEXP,48(a2)
        bsr M4FxRandomPos
M4Boss7FallSpin:
        move.b X_SBYTE3(a0),d0
        add.b d0,13(a0)
        move.b X_SBYTE3(a0),d0
        subq.b #8,d0
        bgt M4Boss7FallMove
        move.w M4_LV_GAMEFRAME,d0
        andi.w #7,d0
        bne M4Boss7FallMove
        addq.b #1,X_SBYTE3(a0)
M4Boss7FallMove:
        tst.w 2(a0)
        bpl M4BossBigOut
        addq.w #1,8(a0)
        jsr M4EnMove
        jsr M4EnAddPZ
        moveq #0,d0
        rts
; bossbigoutexplode 06:EC68: the routine of level_macbeth.asm (M4MbBigOut, offset 0;
; bossbigoutexplodeoff 06:EC4A is M4MbBigOutOff), checked against the ROM by
; build/agent-macbeth/macbeth-compare.py (bigout_boss7, boss_kill_long): gameflags
; bossdead, timer 06:EE72 (circle object 06:864B), particle emitter 06:F89C, 10 x
; [large, huge, large, huge] thrown by 06:ED84, then the 11-tick relexplode timer
; 06:8D17. The screen circle flash and the GSU particles are not drawn.
M4BossBigOut:
        jmp M4MbBigOut

; ---------------------------------------------------------------------
; Large/huge explosion objects (makeLexpobj 06:EEDF, 06:EF0C): as the medium
; one with descriptors ACD9 (size 200) / ACBD (size 1000). Return a2, Z.
M4FxLarge:
        move.l #M4_FX_LARGE,d0 ;descriptor index may exceed 127
        bra M4FxSized
M4FxHuge:
        move.l #M4_FX_HUGE,d0 ;descriptor index may exceed 127
M4FxSized:
        move.w d0,-(sp)
        jsr M4FxMedium
        move.w (sp)+,d0
        cmpa.w #0,a2 ;creation result (move.w (sp)+ sets Z from d0)
        beq M4FxSizedDone
        exg a0,a2
        jsr M4LevelSetShape
        exg a0,a2
        cmpa.w #0,a2
M4FxSizedDone:
        rts
; addrnd2posy 06:EF67: a2.x += sext(rnd), a2.y += sext(rnd).
M4FxRandomPos:
        jsr M4IntroRandom
        ext.w d0
        add.w d0,(a2)
        jsr M4IntroRandom
        ext.w d0
        add.w d0,2(a2)
        rts
; bigexplode_Istrat 06:F0D0: five large explosions with delays 1..5 (sprite
; only), then the object explodes itself 5 ticks later (delayexplode).
M4FxBigExplode:
        moveq #1,d6
M4FxBigNext:
        bsr M4FxLarge
        beq M4FxBigSkip
        bset #F2_NOPOLYEXP,48(a2)
        bsr M4FxRandomPos
        move.b d6,19(a2)
        cmpi.w #2,d6
        beq M4FxBigSound
        cmpi.w #4,d6
        bne M4FxBigSkip
M4FxBigSound:
        bclr #F2_NOEXPSND,48(a2)
M4FxBigSkip:
        addq.w #1,d6
        cmpi.w #6,d6
        bne M4FxBigNext
        move.b #4,19(a0)
        bset #F2_RELEXPLODE,48(a0)
        jmp M4FxDelayInit

; ---------------------------------------------------------------------
; Hatch 07:D7A7/D829: opens (9 frames) while the body is in b; open, every
; 32 ticks it drops two zaco_6 (roty -7 / +21); hit only while open.
M4StratHatch:
        move.l #M4HatchTick,32(a0)
        move.l #M4HatchColl,X_COLL(a0)
        move.l #M4HatchDie,X_EXP(a0)
        move.b #16,38(a0)
        move.b #10,39(a0)
        addi.b #16,M4_BOSS_MAXHP
        bsr M4BsPartInit
        moveq #0,d0
        rts
M4BsPartInit:
        ori.b #CF_ENEMY1,44(a0)
        bclr #3,45(a0)
        bset #F2_SHADOW,48(a0)
        move.b #$80,18(a0)
        move.b #$80,16(a0)
        bset #3,X2_FL4(a0)
        bset #1,49(a0) ;invisible on the creation tick
        rts
M4HatchTick:
        bclr #3,X2_FL4(a0)
        bclr #1,49(a0)
        bset #SF_NOHITAFFECT,49(a0)
        bsr M4BsMotherFlags
        btst #F2_SFLAG1,d0
        beq M4HatchClose
        bclr #SF_NOHITAFFECT,49(a0)
        moveq #$7f,d0
        and.b 16(a0),d0
        cmpi.b #8,d0
        beq M4HatchOpen
        addq.b #1,d0
        ori.b #$80,d0
        move.b d0,16(a0)
        bra M4HatchPlace
M4HatchOpen:
        bsr M4BsColCycle
        move.w M4_LV_GAMEFRAME,d0
        andi.w #$1f,d0
        bne M4HatchPlace
        moveq #-7,d5
        bsr M4HatchFire
        moveq #21,d5
        bsr M4HatchFire
        bra M4HatchPlace
M4HatchClose:
        move.b #4|$80,18(a0)
        moveq #$7f,d0
        and.b 16(a0),d0
        beq M4HatchPlace
        subq.b #1,d0
        ori.b #$80,d0
        move.b d0,16(a0)
M4HatchPlace:
        moveq #-20,d3
        moveq #0,d4
        bsr M4BsPlace
        move.b 38(a0),d0
        add.b d0,M4_BOSS_HP
        moveq #0,d0
        rts
; hatchfire 07:D988: zaco_6 at the hatch, offset 8*rot_y8(-10, 7, 0), rotx
; + 3, roty + d5. A failed creation skips the shot (original writes to DP).
M4HatchFire:
        move.l #M4_SH_ZACO_6,d0 ;descriptor index may exceed 127
        jsr M4EnCreate
        beq M4HatchFireDone
        move.l (a0),(a2)
        move.w 4(a0),4(a2)
        move.w 12(a0),12(a2)
        move.b 14(a0),14(a2)
        movem.l d3-d5,-(sp)
        moveq #-10,d3
        moveq #0,d4
        move.b 13(a2),d5
        neg.b d5
        jsr M4WeaponRotatePair
        ext.w d3
        ext.w d4
        asl.w #3,d3
        asl.w #3,d4
        add.w d3,(a2)
        addi.w #7*8,2(a2)
        add.w d4,4(a2)
        movem.l (sp)+,d3-d5
        addq.b #3,12(a2)
        add.b d5,13(a2)
        move.l #M4StratZaco2,32(a2)
M4HatchFireDone:
        rts
; 07:DA34: damage only with the body in b.
M4HatchColl:
        bsr M4BsMotherFlags
        btst #F2_SFLAG1,d0
        beq.s M4HatchNoHit
        jmp M4LcHitFlash
M4HatchNoHit:
        bclr #SF_COLLIDE,49(a0)
        jmp M4LcStrategy
; 07:DA45
M4HatchDie:
        move.w #-160,X_SWORD2(a0)
        move.b #$40,37(a0)
        move.b #1,X_SBYTE4(a0)
        bra M4BsFallInit

; Shield 07:DCEA/DD32: indestructible, follows the body; the body kills it
; (HP 0) when both launchers are gone: 9 more ticks attached, then falls.
M4StratShield:
        move.l #M4ShieldTick,32(a0)
        clr.l X_COLL(a0)
        move.l #M4ShieldDie,X_EXP(a0)
        move.b #$ff,38(a0)
        move.b #10,39(a0)
        bsr M4BsPartInit
        clr.b 16(a0) ;07:DCEA has no init_anim
        clr.b 18(a0)
        moveq #0,d0
        rts
M4ShieldTick:
        bclr #3,X2_FL4(a0)
        bclr #1,49(a0)
        moveq #20,d3
        moveq #0,d4
        bsr M4BsPlace
        moveq #0,d0
        rts
M4ShieldDie:
        move.b #10,37(a0)
        move.l #M4ShieldWait,X_EXP(a0)
M4ShieldWait:
        subq.b #1,37(a0)
        bne M4ShieldTick
        move.w #-160,X_SWORD2(a0)
        move.b #$c0,37(a0)
        move.b #$ff,X_SBYTE4(a0)
        bra M4BsFallInit

; Launchers 07:DA59/DA83, ticks DB05/DB12: open (10 frames) while the body
; is in c; open, a HMISSILE when (gameframe + al1pt) & 31 == 0 (al1pt: the
; original-like record address of M4B1Al1pt); damaged only on HF2 boxes
; (frames 7..15).
M4StratLauncherT:
        move.l #M4LauncherTTick,32(a0)
        move.l #M4LauncherTDie,X_EXP(a0)
        bra M4StratLauncher
M4StratLauncherB:
        move.l #M4LauncherBTick,32(a0)
        move.l #M4LauncherBDie,X_EXP(a0)
M4StratLauncher:
        move.l #M4LauncherColl,X_COLL(a0)
        move.b #8,38(a0)
        move.b #10,39(a0)
        addq.b #8,M4_BOSS_MAXHP
        bsr M4BsPartInit
        moveq #0,d0
        rts
M4LauncherTTick:
        moveq #-15,d4
        bra M4LauncherTick
M4LauncherBTick:
        moveq #25,d4
M4LauncherTick:
        bclr #3,X2_FL4(a0)
        bclr #1,49(a0)
        bset #SF_NOHITAFFECT,49(a0)
        move.w d4,-(sp)
        bsr M4BsMotherFlags
        btst #F2_SFLAG2,d0
        beq M4LauncherClose
        bsr M4BsColCycle
        bclr #SF_NOHITAFFECT,49(a0)
        moveq #$7f,d0
        and.b 16(a0),d0
        cmpi.b #9,d0
        beq M4LauncherOpen
        addq.b #1,d0
        ori.b #$80,d0
        move.b d0,16(a0)
        bra M4LauncherPlace
M4LauncherOpen:
        move.l d1,-(sp) ;al1pt = lo8($0336 + slot * $36) (M4B1Al1pt)
        jsr M4B1Al1pt
        move.w M4_LV_GAMEFRAME,d0
        add.w d1,d0
        move.l (sp)+,d1
        andi.w #$1f,d0
        bne M4LauncherPlace
        moveq #5,d0
        moveq #34,d3
        moveq #-10,d4
        moveq #0,d5
        moveq #0,d6
        moveq #0,d7
        suba.l a3,a3
        jsr M4EnFire
        cmpa.w #0,a2
        beq M4LauncherPlace
        move.w a1,X_ALPTR(a2)
        bra M4LauncherPlace
M4LauncherClose:
        move.b #4|$80,18(a0)
        moveq #$7f,d0
        and.b 16(a0),d0
        beq M4LauncherPlace
        subq.b #1,d0
        ori.b #$80,d0
        move.b d0,16(a0)
M4LauncherPlace:
        move.w (sp)+,d4
        moveq #30,d3
        bsr M4BsPlace
        move.b 38(a0),d0
        add.b d0,M4_BOSS_HP
        moveq #0,d0
        rts
; 07:DC9F: hit only with the body in c and on an HF2 box.
M4LauncherColl:
        bsr M4BsMotherFlags
        btst #F2_SFLAG2,d0
        beq M4LauncherNoHit
        btst #1,20(a0)
        beq M4LauncherNoHit
        clr.b 20(a0)
        jmp M4LcHitFlash
M4LauncherNoHit:
        clr.b 20(a0)
        bclr #SF_COLLIDE,49(a0)
        jmp M4LcStrategy
M4LauncherTDie:
        move.w #-160,X_SWORD2(a0)
        move.b #$ff,X_SBYTE4(a0)
        bra M4LauncherDie
M4LauncherBDie:
        move.w #-160,X_SWORD2(a0)
        clr.b X_SBYTE4(a0)
M4LauncherDie:
        move.b #$c0,37(a0)

; boss7fall 07:DDE3/DE4C: thrown sideways (sbyte2 relative to roty) at
; speed 10, large explosion, unlinked from the body; bounces twice at
; sword2 (160 above the ground) and bursts (bigexplode).
M4BsFallInit:
        move.b #10,15(a0)
        move.b 13(a0),d0
        add.b d0,37(a0)
        move.b #$f8,X_SBYTE3(a0)
        moveq #10,d0
        move.b X_SBYTE3(a0),d1
        move.b 37(a0),d2
        jsr M4EnVector
        movem.w d3-d5,6(a0)
        move.l #M4BsFall,X_EXP(a0)
        bclr #F2_SFLAG1,48(a0)
        bsr M4FxLarge
        move.b #2,37(a0)
        move.w X_ALPTR(a0),d0
        beq M4BsFallUnlinked
        movea.w d0,a3
        move.w a0,d1
M4BsFallFind:
        move.w 40(a3),d0
        beq M4BsFallUnlinked
        cmp.w d0,d1
        beq M4BsFallCut
        movea.w d0,a3
        bra M4BsFallFind
M4BsFallCut:
        move.w 40(a0),40(a3)
M4BsFallUnlinked:
        bclr #4,X2_FL4(a0)
        moveq #0,d0 ;07:DE4B rtl: the fall starts next tick
        rts
M4BsFall:
        move.b X_SBYTE4(a0),d0
        add.b d0,14(a0)
        move.w 2(a0),d0
        sub.w X_SWORD2(a0),d0
        bmi M4BsFallMove
        subq.b #1,37(a0)
        beq M4FxBigExplode
        neg.w 8(a0)
M4BsFallMove:
        addq.w #1,8(a0)
        jsr M4EnMove
        jsr M4EnAddPZ
        subi.w #30,4(a0)
        moveq #0,d0
        rts

; ---------------------------------------------------------------------
; zaco2_Istrat 08:AF57 (zaco_6 from the hatch): 15 straight ticks, chase the
; player (>>3) until ZD < 500, then three passes banking away 32 ticks
; (no missile on route 1), back to the chase when ZD >= 2000; after the
; third pass 30 ticks and it explodes. Bounces on the ground; killed while
; the boss is dying.
M4StratZaco2:
        move.b #4,38(a0)
        move.b #4,39(a0)
        move.b #50,15(a0)
        jsr M4EnGen3d
        move.b #15,36(a0)
        ori.b #$40|CF_ENEMY1|$01,44(a0)
        bclr #3,45(a0)
        move.b #3,37(a0)
        jsr M4LvNormPtrs
        move.l #M4Zaco6Chase,32(a0)
M4Zaco6Chase:
        tst.b 36(a0)
        beq M4Zaco6Aim
        subq.b #1,36(a0)
        bra M4Zaco6Mover
M4Zaco6Aim:
        movea.l a1,a2
        jsr M4EnZD
        subi.w #500,d0
        bmi M4Zaco6Pass
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
M4Zaco6Mover:
        tst.b M4_BOSS_DYING
        beq M4Zaco6Move
        jsr M4EnKill
        moveq #0,d0 ;08:B04F -> 06:8D07 returns without movement
        rts
M4Zaco6Move:
        jsr M4EnGen3d
        jsr M4EnMove
        tst.w 2(a0)
        bmi M4Zaco6Air
        clr.w 2(a0)
        neg.b 12(a0)
M4Zaco6Air:
        jsr M4EnAddPZ
        moveq #0,d0
        rts
M4Zaco6Pass:
        tst.b 37(a0)
        beq M4Zaco6FinalInit
        subq.b #1,37(a0)
        move.l #M4Zaco6Bank,32(a0)
        move.b #32,36(a0)
M4Zaco6Bank:
        tst.b 36(a0)
        beq M4Zaco6BankEnd
        subq.b #1,36(a0)
        btst #AF_LEFTPL,51(a0)
        beq M4Zaco6BankRight
        subi.b #10,14(a0)
        subq.b #4,13(a0)
        bra M4Zaco6Mover
M4Zaco6BankRight:
        addi.b #10,14(a0)
        addq.b #4,13(a0)
        bra M4Zaco6Mover
M4Zaco6BankEnd:
        movea.l a1,a2
        jsr M4EnZD
        subi.w #2000,d0
        bmi M4Zaco6Mover
        move.l #M4Zaco6Chase,32(a0)
        bra M4Zaco6Chase
M4Zaco6FinalInit:
        move.l #M4Zaco6Final,32(a0)
        move.b #30,19(a0)
M4Zaco6Final:
        subq.b #1,19(a0)
        bne M4Zaco6Mover
        bset #SF_COLLDISABLE,49(a0)
        clr.b 38(a0)
        bra M4Zaco6Mover

; ---------------------------------------------------------------------
; HMISSILE (fire id $12, 06:B0DE / init 06:926A / tick 06:92CB): homing on
; al_ptr (>>3) until distXZ < 300, spinning rotz +10; the exhaust smoke and
; tail flame (visual objects) are not created.
M4WpMissileInit:
        move.l #M4WpMissileTick,32(a0)
        ori.b #$01,44(a0)
        bset #F2_SHADOW,48(a0)
        bsr M4WpMissileVec
        moveq #0,d0
        rts
M4WpMissileVec:
        moveq #0,d0
        move.b 15(a0),d0
        jsr M4EnGen3d
        move.b X_SBYTE3(a0),d0
        ext.w d0
        move.b 12(a0),d1
        move.b 13(a0),d2
        jsr M4EnVector
        add.w d3,6(a0)
        add.w d4,8(a0)
        add.w d5,10(a0)
        rts
M4WpMissileTick:
        moveq #0,d7
        addi.b #10,14(a0)
        btst #F2_SFLAG2,48(a0)
        bne M4WpMissileMove
        move.w X_ALPTR(a0),d0
        beq M4WpMissileMove
        movea.w d0,a2
        jsr M4EnDistXZ
        subi.w #300,d0
        bpl M4WpMissileGuide
        bset #F2_SFLAG2,48(a0)
        bra M4WpMissileMove
M4WpMissileGuide:
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
        bsr M4WpMissileVec
M4WpMissileMove:
        jsr M4EnAddPZ
        jsr M4EnMove
        subq.b #1,19(a0)
        bne M4WpMissileAlive
        moveq #1,d7
M4WpMissileAlive:
        bset #3,45(a0)
        btst #AF_INVIEWPL,51(a0)
        bne M4WpMissileFinal
        moveq #1,d7
M4WpMissileFinal:
        jsr M4WpFinal
        move.l d7,d0
        rts
; 06:F42E: back one step, stopped, then explode_Istrat.
M4WpMissileExp:
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
        jmp M4LevelExplode

; Boss bar (mdrawbossHP 01:AFEB): value clamped, drawn by the HUD sprites;
; m_bossHP restarts from 0 for the next tick.
M4BossHudTick:
        moveq #0,d0
        move.b M4_BOSS_MAXHP,d0
        addi.w #10,d0
        move.b M4_BOSS_HP,d1
        cmp.b d0,d1
        blo M4BossHudKeep
        moveq #0,d1
M4BossHudKeep:
        move.b d1,M4_BOSS_HUDHP
        clr.b M4_BOSS_HP
        rts

; mdrawbossHP 01:AFEB (GSU, in the 3D bitmap with the meters, m_meters on):
; w = lo8(max) (0: none; bit7: w >>= 1); w += 4; outline colour 14 at
; (222 - w, 2) w x 6; fill colour 2 at (x + 2, 4), width = lo8(m_bossHP)
; (>> 1 when max bit7), height 2. Value = the clamped bar of M4BossHudTick.
; cmd8 rectangles as the radio meter (M4TxOutline / M4TxBox).
M4BossBarDraw:
        tst.b M4_SC_MMETERS
        beq.s M4BossBarDone
        moveq #0,d4
        move.b M4_BOSS_MAXHP,d4
        beq.s M4BossBarDone
        movem.l d0-d6,-(sp)
        moveq #0,d0
        move.b M4_BOSS_HUDHP,d0
        tst.b d4
        bpl.s M4BossBarW
        lsr.w #1,d4
        lsr.w #1,d0
M4BossBarW:
        addq.w #4,d4
        move.w #222,d2
        sub.w d4,d2
        moveq #2,d3
        moveq #6,d5
        jsr M4TxOutline
        tst.w d0
        beq.s M4BossBarEmpty
        addq.w #2,d2
        moveq #4,d3
        move.w d0,d4
        moveq #2,d5
        moveq #2,d6
        jsr M4TxBox
M4BossBarEmpty:
        movem.l (sp)+,d0-d6
M4BossBarDone:
        rts

; Asteroid Belt 1 boss boss1 08:816E (build/agent-boss1/BOSS1.md).
        include 'stages/level_boss1.asm'

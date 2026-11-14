; Asteroid Belt 1 boss "Rock Crusher" (boss1 08:816E, shape boss_1_2 BE74),
; its core (08:8AC7/8B0D) and eight capsules (08:891A/8945, ticks 899D/89AE).
; Specification: build/agent-boss1/BOSS1.md (ROM USA rev0 disassembly
; build/research/work/bossE/boss1_trace.txt, 06:EAAE/EE09/EE72/EC05/F89C/889E);
; oracle and port comparison build/research/work/bossE/boss1-oracle.py.
; Family links and helpers as boss7 (level_boss.asm): child id in sbyte1,
; mother in X_ALPTR, chain in sword1. Body sflags2 bits: $01 colldisable (49
; bit0), $10 F2_SFLAG1 (core moving: capsules closed, rotz + 2), $20
; F2_SFLAG2 (capsules may open), $40 M4_B1_GROUP (capsules 6..9 active
; instead of 2..5; global byte: one boss1 at a time).
M4_B1_FIRE equ M4_BOSS+4 ;.b bossflags $14D5 bit0: aimed-shot order (core -> capsules)
M4_B1_GROUP equ M4_BOSS+5 ;.b body sflags2 $40 (0/1)
; Small explosion 06:EEFD (smallshape 00:AD11, sh_size 50): no descriptor in
; the effect catalog yet (generate-level-shapes.py EFFECTS); the medium
; placeholder (ACF5, size 90) stands in until M4_FX_SMALL exists.
M4_B1_FXSMALL equ M4_FX_SMALL

; ---------------------------------------------------------------------
; Body Istrat 08:816E: stratptr2 ($1CD9) = 08:8166 (rotz + 2 while dying),
; collstrat hitflash 06:89A3, expstrat bossexplode 06:EAAE; HP 35 / AP 10
; (currentlevel $1FFF != 0: HP 70), bar maximum = HP; roty $80, enemy1,
; atgnd (al_type bit0: sortz + 15000), colframe $84, relexplode; core id 1
; and capsules 2..5 (891A) / 6..9 (8945), each failure 1F:BDEE (fatal);
; colldisable, parts placed (87C3), sbyte3 = 1. Not modelled: trigse $82,
; stratstate $1CDC = DP $00 (never read).
M4StratBoss1:
        move.l #M4B1DyingRoll,X_SM_STRAT2(a0) ;08:8166, only this boss
        move.l #M4B1Up,32(a0)
        move.l #M4LcHitFlash,X_COLL(a0)
        move.l #M4B1Explode,X_EXP(a0)
        moveq #35,d0
        tst.b M4_GS_CURLEVEL
        beq.s M4B1Hp
        moveq #70,d0
M4B1Hp:
        move.b d0,38(a0)
        move.b #10,39(a0)
        move.b d0,M4_BOSS_MAXHP
        clr.b M4_BOSS_HP
        move.b #$80,13(a0)
        ori.b #CF_ENEMY1,44(a0)
        ori.b #1,45(a0)
        move.b #$84,18(a0)
        bset #F2_RELEXPLODE,48(a0)
        move.l #M4_SH_BOSS_1_CORE,d0 ;descriptor index may exceed 127
        moveq #1,d1
        move.l #M4B1CoreInit,d2
        bsr M4BsMakePart
        moveq #2,d1
        move.l #M4B1CapLInit,d2
M4B1MakeCaps:
        move.l #M4_SH_BOSS_1_1,d0 ;descriptor index may exceed 127
        bsr M4BsMakePart
        addq.b #1,d1
        cmpi.b #6,d1
        bne.s M4B1MakeCapsNext
        move.l #M4B1CapRInit,d2
M4B1MakeCapsNext:
        cmpi.b #10,d1
        bne.s M4B1MakeCaps
        bset #SF_COLLDISABLE,49(a0)
        bsr M4B1Place
        move.b #1,X_SBYTE3(a0)
        moveq #0,d0
        rts

; up 08:8413: y - 10 per tick while N(y + 60) is clear.
M4B1Up:
        move.w 2(a0),d0
        addi.w #60,d0
        bmi.s M4B1NormalInit
        subi.w #10,2(a0)
        bra M4B1Tick
; normal 08:8432/8449: capsules may open (sflags2 $20), 30 ticks.
M4B1NormalInit:
        move.l #M4B1Normal,32(a0)
        move.b #30,37(a0)
        bset #F2_SFLAG2,48(a0)
M4B1Normal:
        subq.b #1,37(a0)
        bne M4B1Tick
        move.l #M4B1In,32(a0)
        bset #F2_SFLAG2,48(a0)
; in 08:8464: z - 15 until N(|pz - z| - 1000).
M4B1In:
        subi.w #15,4(a0)
        movea.l a1,a2
        jsr M4EnZD
        subi.w #1000,d0
        bpl M4B1Tick
; out 08:848C/8499: z + 15 until !N(|pz - z| - 1500); then sbyte3 more
; approaches (normal again), or the ram (sbyte3 = 2, capsules shut).
M4B1OutInit:
        move.l #M4B1Out,32(a0)
M4B1Out:
        addi.w #15,4(a0)
        movea.l a1,a2
        jsr M4EnZD
        subi.w #1500,d0
        bmi M4B1Tick
        bset #F2_SFLAG2,48(a0)
        tst.b X_SBYTE3(a0)
        beq.s M4B1InCloseInit
        subq.b #1,X_SBYTE3(a0)
        bra M4B1NormalInit
M4B1InCloseInit:
        move.b #2,X_SBYTE3(a0)
        move.l #M4B1InClose,32(a0)
        bclr #F2_SFLAG2,48(a0)
; inclose 08:84EC: z - 25 until N(|pz - z| - 300) -> out; continues at
; 08:878D (no group test, no homing missiles).
M4B1InClose:
        subi.w #25,4(a0)
        movea.l a1,a2
        jsr M4EnZD
        subi.w #300,d0
        bmi M4B1OutInit
        bra.s M4B1Spin

; Common tick 08:868F..87C2. A capsule group gone (2..5 or 6..9) and
; currentlevel != 0: every 64 ticks ((gameframe + 15) & 63 == 0) two
; HMISSILE1 ($12) aimed at the player from (-96, 0, 0) and (96, 0, 0),
; enemy1, al_ptr = player.
M4B1Tick:
        moveq #2,d6
        bsr M4B1AnyChild
        beq.s M4B1Missiles
        moveq #6,d6
        bsr M4B1AnyChild
        bne.s M4B1Spin
M4B1Missiles:
        tst.b M4_GS_CURLEVEL
        beq.s M4B1Spin
        move.w M4_LV_GAMEFRAME,d0
        addi.w #15,d0
        andi.w #63,d0
        bne.s M4B1Spin
        moveq #-96,d3
        bsr M4B1Homing
        moveq #96,d3
        bsr M4B1Homing
; 08:878D: sflags2 $10 -> rotz + 2; parts placed; no capsule left -> back.
M4B1Spin:
        btst #F2_SFLAG1,48(a0)
        beq.s M4B1SpinDone
        addq.b #2,14(a0)
M4B1SpinDone:
        bsr M4B1Place
        tst.w d0
        bne.s M4B1TickEnd
        move.l #M4B1Back,32(a0)
; 08:87B3: addplayerZ; m_bossHP += HP.
M4B1TickEnd:
        jsr M4EnAddPZ
        move.b 38(a0),d0
        add.b d0,M4_BOSS_HP
        moveq #0,d0
        rts
; d3 = x offset BYTE: HMISSILE1 ($12) aimed at the player (08:8723).
; A failed creation writes to dummyobj in the original: skipped.
M4B1Homing:
        moveq #M4_WT_HMISSILE1,d0
        moveq #0,d4
        moveq #0,d5
        moveq #0,d6
        moveq #0,d7
        movea.l a1,a3
        jsr M4EnFire
        cmpa.w #0,a2
        beq.s M4B1HomingDone
        ori.b #CF_ENEMY1,44(a2)
        move.w a1,X_ALPTR(a2)
M4B1HomingDone:
        rts
; Z clear when a child with id d6..d6+3 exists (find_child 1F:DC40).
M4B1AnyChild:
        moveq #3,d7
M4B1AnyChildNext:
        move.b d6,d0
        bsr M4BsChild
        bne.s M4B1AnyChildDone
        addq.b #1,d6
        dbra d7,M4B1AnyChildNext
        cmp.w d0,d0 ;Z: none
M4B1AnyChildDone:
        rts

; boss1rots 08:87C3 + 08:8004: core at (core.sbyte4, 0, 0) and capsules at
; their offsets, each rotated by rotz (rotate_8 1F:CC78) then roty (rot_y8
; 1F:C97B), x2, added to the body; core z - 300. Returns d0 = capsules found
; ($1532). The original reads the core without testing it (find_child Y = 0
; after its release in the final phase: writes to DP $000C..$0010); the port
; skips the missing core.
M4B1Place:
        movem.l d1-d7/a2-a3,-(sp)
        moveq #1,d0
        bsr M4BsChild
        beq.s M4B1PlaceCaps
        move.b X_SBYTE4(a2),d3
        moveq #0,d4
        moveq #0,d5
        bsr M4B1Offset
        add.w (a0),d3
        move.w d3,(a2)
        add.w 4(a0),d5
        subi.w #300,d5
        move.w d5,4(a2)
        add.w 2(a0),d4
        move.w d4,2(a2)
M4B1PlaceCaps:
        moveq #0,d2
        lea M4B1Offsets,a3
        moveq #2,d7
M4B1PlaceNext:
        move.b d7,d0
        bsr M4BsChild ;clobbers d1
        beq.s M4B1PlaceSkip
        move.b (a3),d3
        move.b 1(a3),d4
        move.b 2(a3),d5
        bsr M4B1Offset
        add.w (a0),d3
        move.w d3,(a2)
        add.w 4(a0),d5
        move.w d5,4(a2)
        add.w 2(a0),d4
        move.w d4,2(a2)
        addq.w #1,d2
M4B1PlaceSkip:
        addq.l #3,a3
        addq.b #1,d7
        cmpi.b #10,d7
        bne.s M4B1PlaceNext
        move.w d2,d0
        movem.l (sp)+,d1-d7/a2-a3
        rts
; 08:8861..8916 ($152E, $152F, $1530 of ids 2..9).
M4B1Offsets:
        include '../build/m4-corneria-boss-offsets.inc'
        even
; d3/d4/d5 = x/y/z BYTEs -> WORD offsets of the body a0: (x, y) by rotz,
; (x, z) by roty (M4WeaponRotatePair angle -roty = rot_y8), sign-extended, x2.
M4B1Offset:
        move.b d5,d6
        move.b 14(a0),d5
        jsr M4WeaponRotatePair
        exg d4,d6 ;d4 = z, d6 = y
        move.b 13(a0),d5
        neg.b d5
        jsr M4WeaponRotatePair
        move.b d4,d5
        move.b d6,d4
        ext.w d3
        ext.w d4
        ext.w d5
        add.w d3,d3
        add.w d4,d4
        add.w d5,d5
        rts

; back 08:8525: offsets 0; |pz - z| < 1500 -> z + 15 and the common tick;
; else 08:8560: release the core (strategy 8B86, unlinked: 1F:DBA4 form),
; body vulnerable (sflags2 &= ~1; trigse $85), then 85AA every tick.
M4B1Back:
        movea.l a1,a2
        jsr M4EnZD
        subi.w #1500,d0
        bpl.s M4B1Final
        addi.w #15,4(a0)
        bra M4B1Tick
M4B1Final:
        moveq #1,d0
        bsr M4BsChild
        beq.s M4B1FinalTick
        move.l #M4B1CoreGone,32(a2)
        jsr M4PvDivorce
        bclr #SF_COLLDISABLE,49(a0)
; 08:85AA: colframe cycle, rotz + 2; gameframe & 63 == 0: Hplasma ($26)
; with rotx/roty + (rnd & 15) - 7; (gameframe + 15) & 63 == 0:
; HMISSILE1 rotx + $18 (and - $18 when currentlevel != 0); al_ptr = player.
M4B1FinalTick:
        bsr M4BsColCycle
        addq.b #2,14(a0)
        move.w M4_LV_GAMEFRAME,d0
        andi.w #63,d0
        bne.s M4B1FinalMissile
        jsr M4IntroRandom
        andi.b #15,d0
        subq.b #7,d0
        move.b d0,d6
        jsr M4IntroRandom
        andi.b #15,d0
        subq.b #7,d0
        move.b d0,d7
        moveq #M4_WT_HPLASMA,d0
        bsr M4B1FireFwd
M4B1FinalMissile:
        move.w M4_LV_GAMEFRAME,d0
        addi.w #15,d0
        andi.w #63,d0
        bne M4B1TickEnd
        moveq #$18,d6
        moveq #0,d7
        moveq #M4_WT_HMISSILE1,d0
        bsr M4B1FireFwd
        tst.b M4_GS_CURLEVEL
        beq M4B1TickEnd
        moveq #-$18,d6
        moveq #0,d7
        moveq #M4_WT_HMISSILE1,d0
        bsr M4B1FireFwd
        bra M4B1TickEnd
; d0 weapon type (M4_WT_*), d6/d7 rotx/roty add; offset 0, no target; al_ptr = player.
M4B1FireFwd:
        moveq #0,d3
        moveq #0,d4
        moveq #0,d5
        suba.l a3,a3
        jsr M4EnFire
        cmpa.w #0,a2
        beq.s M4B1FireFwdDone
        move.w a1,X_ALPTR(a2)
M4B1FireFwdDone:
        rts

; bossexplode 06:EAAE (expstrat, HP 0): first time bossflags dying, notdie
; ($14DF $20), no fire ($14D8 $40) (trigse $1E, $1F49 = $F1: audio, not
; modelled); 14 explosions (06:EEFD small / EEEE medium / EEDF large) moved
; by addrnd2posy 06:EF67 with delays 5..34; a nullshape timer (06:EE72, 15
; ticks: screen flash and BIGParticleexplode); then delayexplode-like
; 06:EA09: HP $FF, AP 8, collstrat 0, expstrat explode 06:F45F, 38 ticks.
M4B1Explode:
        tst.b M4_BOSS_DYING
        bne.s M4B1ExplodeChain
        st M4_BOSS_DYING
        bset #5,M4_BOSS_PSTRATF
        bset #6,M4_LP_PSF
M4B1ExplodeChain:
        lea M4B1ExplList,a3
        moveq #13,d6
M4B1ExplodeNext:
        move.b (a3)+,d0
        ext.w d0
        bsr M4B1Expl
        beq.s M4B1ExplodeFail
        bsr M4FxRandomPos
        move.b (a3),19(a2)
        cmpi.w #13,d6
        bne.s M4B1ExplodeOne
        bclr #F2_NOEXPSND,48(a2) ;first one with sound
        bra.s M4B1ExplodeOne
M4B1ExplodeFail: ;dummyobj in the original: addrnd2posy still draws twice
        jsr M4IntroRandom
        jsr M4IntroRandom
M4B1ExplodeOne:
        addq.l #1,a3
        dbra d6,M4B1ExplodeNext
        moveq #-1,d0
        jsr M4EnCreate
        beq.s M4B1ExplodeNoTimer
        move.b 48(a0),48(a2)
        move.b 49(a0),49(a2)
        move.b X2_FL4(a0),X2_FL4(a2)
        bset #SF_COLLDISABLE,49(a2)
        bset #F2_NOEXPSND,48(a2)
        move.l (a0),(a2)
        move.w 4(a0),4(a2)
        move.b #15,19(a2)
        bset #F2_SFLAG1,48(a2)
        move.l #M4B1FlashInit,32(a2)
M4B1ExplodeNoTimer:
        move.b #38,19(a0)
        move.b #$ff,38(a0)
        move.b #8,39(a0)
        move.l #M4B1Dying,32(a0)
        clr.l X_COLL(a0)
        move.l #M4LevelExplode,X_EXP(a0)
; 06:EA38: hitflash; count - 1; was 0: colldisable, HP 0, huge explosion
; (06:EF0C), gameflags bossdead, explode now (F45F); else addplayerZ and
; stratptr2 08:8166 (rotz + 2).
M4B1Dying:
        bset #SF_HITFLASH,49(a0)
        subq.b #1,19(a0)
        bpl.s M4B1DyingWait
        bset #SF_COLLDISABLE,49(a0)
        clr.b 38(a0)
        move.l #M4_FX_HUGE,d0 ;descriptor index may exceed 127
        bsr M4B1Expl
        bset #2,M4_LP_GAMEFLAGS
        jmp M4LevelExplode
M4B1DyingWait:
        jsr M4EnAddPZ
        move.l X_SM_STRAT2(a0),d0 ;06:EA6F calls stratptr2 only when present
        beq.s M4B1DyingDone
        movea.l d0,a2
        jmp (a2)
M4B1DyingRoll:
        addq.b #2,14(a0)
M4B1DyingDone:
        moveq #0,d0
        rts
; kind (0 small, 1 medium, 2 large), delay: 06:EADF..EB9A.
M4B1ExplList:
        include '../build/m4-corneria-boss-explosions.inc'
; d0 = kind 0/1/2 or a descriptor >= 3: makeexpobj 06:EF1B (medium
; placeholder, delayexplode, relexplode) with that shape -> a2 or 0 (Z).
M4B1Expl:
        cmpi.w #3,d0
        bhs.s M4B1ExplShape
        add.w d0,d0 ;WORD table: descriptor indices pass 127/255
        move.w M4B1ExplShapes(pc,d0.w),d0
M4B1ExplShape:
        move.w d0,-(sp)
        jsr M4FxMedium
        move.w (sp)+,d0
        cmpa.w #0,a2
        beq.s M4B1ExplDone
        exg a0,a2
        jsr M4LevelSetShape
        exg a0,a2
        cmpa.w #0,a2
M4B1ExplDone:
        rts
M4B1ExplShapes:
        dc.w M4_B1_FXSMALL,M4_FX_MEDIUM,M4_FX_LARGE

; 06:EE72/EE91 timer: HP $FF, no pointers (1F:D450), colldisable; count - 1
; each tick (addplayerZ); below 0: 06:EC05 (trigse $1D; circleobj = a
; nullshape 06:864B at this object; circleanim = 1: the screen flash is not
; drawn by the port), with sflags2 $10 a BIGParticleexplode nullshape
; 06:F89C (relexplode), then removed (addplayerZ still applied).
M4B1FlashInit:
        move.b #$ff,38(a0)
        move.b #8,39(a0)
        move.l #M4B1Flash,32(a0)
        clr.l X_COLL(a0)
        clr.l X_EXP(a0)
        bset #SF_COLLDISABLE,49(a0)
M4B1Flash:
        subq.b #1,19(a0)
        bpl.s M4B1FlashMove
        moveq #-1,d0
        jsr M4EnCreate
        beq.s M4B1FlashNoCircle
        move.l (a0),(a2)
        move.w 4(a0),4(a2)
        move.l #M4B1CircleObj,32(a2)
M4B1FlashNoCircle:
        btst #F2_SFLAG1,48(a0)
        beq.s M4B1FlashGone
        moveq #-1,d0
        jsr M4EnCreate
        beq.s M4B1FlashGone
        move.l (a0),(a2)
        move.w 4(a0),4(a2)
        bset #F2_RELEXPLODE,48(a2)
        move.l #M4B1BigParticles,32(a2)
M4B1FlashGone:
        jsr M4EnAddPZ
        moveq #1,d0
        rts
M4B1FlashMove:
        jsr M4EnAddPZ
        moveq #0,d0
        rts
; 06:864B circleobj: addplayerZ, colldisable (stays until the level ends).
M4B1CircleObj:
        jsr M4EnAddPZ
        bset #SF_COLLDISABLE,49(a0)
        moveq #0,d0
        rts
; BIGParticleexplode 06:F89C (Istrat) / F8D2 (expstrat, HP 0): afexp,
; colldisable, particle bytes; count + 1 each tick, removed at 110;
; relexplode z += pviewvelz. Timing only: the particles are not drawn.
M4B1BigParticles:
        move.l #M4B1BigParticlesTick,X_EXP(a0)
        bset #SF_COLLDISABLE,49(a0)
        bset #0,25(a0)
        move.b #4,X_SBYTE3(a0)
        st 36(a0)
        move.b #100,37(a0)
        moveq #0,d0
        rts
M4B1BigParticlesTick:
        clr.b X_SBYTE3(a0)
        clr.b 36(a0)
        clr.b 37(a0)
        addq.b #1,19(a0)
        cmpi.b #110,19(a0)
        beq.s M4B1BigParticlesGone
        btst #F2_RELEXPLODE,48(a0)
        beq.s M4B1BigParticlesStay
        jsr M4EnAddPZ
M4B1BigParticlesStay:
        moveq #0,d0
        rts
M4B1BigParticlesGone:
        moveq #1,d0
        rts

; ---------------------------------------------------------------------
; Core Istrat 08:8AC7: collstrat 06:889E (ricochet), no expstrat; HP $FF /
; AP 16, roty $80, sbyte2 33, sbyte3 10, sbyte4 52, enemy1.
M4B1CoreInit:
        move.l #M4B1Core,32(a0)
        move.l #M4B1Ricochet,X_COLL(a0)
        clr.l X_EXP(a0)
        move.b #$ff,38(a0)
        move.b #16,39(a0)
        move.b #$80,13(a0)
        move.b #33,37(a0)
        move.b #10,X_SBYTE3(a0)
        move.b #52,X_SBYTE4(a0)
        ori.b #CF_ENEMY1,44(a0)
        moveq #0,d0
        rts
; 08:8B0D: fire order; rots from the body; body sflags2 &= ~$10. sbyte2
; counts the move (sbyte4 -/+ 4 toward the active group, sflags2 |= $10);
; then sbyte3 rest ticks (capsules may open; they fire while sbyte3 < 20);
; at its end: trigse $2F, move 32, rest 30 (currentlevel 0: 50), group
; switched (sflags2 ^= $40).
M4B1Core:
        bset #0,M4_B1_FIRE
        move.w X_ALPTR(a0),d0
        beq.s M4B1CoreEnd
        movea.w d0,a2
        move.b 12(a2),12(a0)
        move.b 13(a2),13(a0)
        move.b 14(a2),14(a0)
        bclr #F2_SFLAG1,48(a2)
        subq.b #1,37(a0)
        bne.s M4B1CoreMove
        move.b #1,37(a0)
        subq.b #1,X_SBYTE3(a0)
        bne.s M4B1CoreEnd
        move.b #32,37(a0)
        move.b #30,X_SBYTE3(a0)
        tst.b M4_GS_CURLEVEL
        bne.s M4B1CoreSwap
        move.b #50,X_SBYTE3(a0)
M4B1CoreSwap:
        eori.b #1,M4_B1_GROUP
M4B1CoreMove:
        bset #F2_SFLAG1,48(a2)
        moveq #-4,d0
        tst.b M4_B1_GROUP
        beq.s M4B1CoreSlide
        moveq #4,d0
M4B1CoreSlide:
        add.b d0,X_SBYTE4(a0)
M4B1CoreEnd:
        jsr M4EnAddPZ
        moveq #0,d0
        rts
; Released core 08:8B86: z - 20 per tick (no addplayerZ); removed (06:8D12)
; when behind the player (N(z - pz)) by |pz - z| >= 1000.
M4B1CoreGone:
        move.w 4(a0),d0
        sub.w 4(a1),d0
        bpl.s M4B1CoreGoneMove
        movea.l a1,a2
        jsr M4EnZD
        subi.w #1000,d0
        bmi.s M4B1CoreGoneMove
        moveq #1,d0
        rts
M4B1CoreGoneMove:
        subi.w #20,4(a0)
        moveq #0,d0
        rts

; 06:889E (core; capsules while nohitaffect): no damage; a player laser
; (shape B369) fires RebElaser (fire_weapon id 2, 06:A937) from itself with
; speed 0, roty + $40 and rotx = random, offsets 0, no target; its roty,
; rotx, speed and immuneptr are restored; then the strategy.
M4B1Ricochet:
        bclr #SF_COLLIDE,49(a0)
        jsr M4LcCollider
        move.l a2,d0
        beq.s M4B1RicochetDone
        cmpi.w #M4_SH_P_LASER,46(a2)
        bne.s M4B1RicochetDone
        move.l a0,-(sp)
        movea.l a2,a0
        move.w 28(a0),-(sp)
        move.w 12(a0),-(sp) ;rotx, roty
        move.b 15(a0),-(sp)
        clr.b 15(a0)
        addi.b #$40,13(a0)
        jsr M4IntroRandom
        move.b d0,12(a0)
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
M4B1RicochetDone:
        jmp M4LcStrategy

; ---------------------------------------------------------------------
; Capsule Istrat 08:891A (ids 2..5, tick 899D) / 08:8945 (6..9, 89AE):
; collstrat 08:8AB9, expstrat explode 06:F45F; HP 8 / AP 16, roty $80,
; enemy1 | $40, colframe $84, nohitaffect; m_bossmaxHP += 8.
M4B1CapLInit:
        move.l #M4B1CapL,32(a0)
        bra.s M4B1CapInit
M4B1CapRInit:
        move.l #M4B1CapR,32(a0)
M4B1CapInit:
        move.l #M4B1CapColl,X_COLL(a0)
        move.l #M4B1CapExplode,X_EXP(a0)
        move.b #8,38(a0)
        move.b #16,39(a0)
        move.b #$80,13(a0)
        ori.b #CF_ENEMY1|$40,44(a0)
        move.b #$84,18(a0)
        bset #SF_NOHITAFFECT,49(a0)
        addq.b #8,M4_BOSS_MAXHP
        moveq #0,d0
        rts
; Open when the body's group selects it, sflags2 $20 and not $10: colframe
; cycles, vulnerable; while core.sbyte3 < 20 (or no core) it fires $0C
; (RelSlowElaser) from (0, 0, 10): with the fire order every 16 ticks aimed at the
; player (order consumed), else every 32 ticks forward; phase (gameframe +
; al1pt) with the ROM-like al1pt of M4B1Al1pt. Closed: colframe $84,
; nohitaffect. Always: rotz = body rotz, addplayerZ, m_bossHP += HP.
M4B1CapL:
        tst.b M4_B1_GROUP
        bne M4B1CapClosed
        bra.s M4B1CapCheck
M4B1CapR:
        tst.b M4_B1_GROUP
        beq M4B1CapClosed
M4B1CapCheck:
        move.w X_ALPTR(a0),d0
        beq.s M4B1CapClosed
        movea.w d0,a2
        btst #F2_SFLAG2,48(a2)
        beq.s M4B1CapClosed
        btst #F2_SFLAG1,48(a2)
        bne.s M4B1CapClosed
        bsr M4BsColCycle
        bclr #SF_NOHITAFFECT,49(a0)
        moveq #1,d0
        jsr M4PvFindChild
        move.l a2,d0
        beq.s M4B1CapFire
        move.b X_SBYTE3(a2),d0
        subi.b #20,d0
        bpl.s M4B1CapPlace
M4B1CapFire:
        bsr M4B1Al1pt
        move.b M4_LV_GAMEFRAME+1,d0
        add.b d1,d0
        btst #0,M4_B1_FIRE
        beq.s M4B1CapFire32
        moveq #15,d2
        and.b d0,d2
        bne.s M4B1CapFire32
        bclr #0,M4_B1_FIRE
        movea.l a1,a3
        bra.s M4B1CapShot
M4B1CapFire32:
        andi.b #31,d0
        bne.s M4B1CapPlace
        suba.l a3,a3
M4B1CapShot:
        moveq #M4_WT_RSE,d0
        moveq #0,d3
        moveq #0,d4
        moveq #10,d5
        moveq #0,d6
        moveq #0,d7
        jsr M4EnFire
        bra.s M4B1CapPlace
M4B1CapClosed:
        move.b #$84,18(a0)
        bset #SF_NOHITAFFECT,49(a0)
M4B1CapPlace:
        move.w X_ALPTR(a0),d0
        beq.s M4B1CapEnd
        movea.w d0,a2
        move.b 14(a2),14(a0)
M4B1CapEnd:
        jsr M4EnAddPZ
        move.b 38(a0),d0
        add.b d0,M4_BOSS_HP
        moveq #0,d0
        rts
; 08:8AB9: nohitaffect -> ricochet 06:889E, else hitflash 06:89A3.
M4B1CapColl:
        btst #SF_NOHITAFFECT,49(a0)
        bne M4B1Ricochet
        jmp M4LcHitFlash
; explode_Istrat 06:F45F starts with divorcefamily 1F:DBA4 for a child: the
; capsule leaves the body's chain this tick (M4LevelExplode does not).
M4B1CapExplode:
        btst #4,X2_FL4(a0)
        beq.s M4B1CapExplodeNow
        movea.l a0,a2
        jsr M4PvDivorce
M4B1CapExplodeNow:
        jmp M4LevelExplode
; d1.b = low byte of the original-like object address $0336 + slot * $36
; (02:F4BB pool, 54-byte records) for the (gameframe + al1pt) phases: the
; port's 64-byte slots would give every capsule the same phase.
M4B1Al1pt:
        move.w a0,d1
        subi.w #M4_LV_OBJ&$ffff,d1
        lsr.w #6,d1
        mulu.w #$36,d1
        addi.w #$36,d1
        rts

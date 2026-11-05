; Stage unit: Asteroid Belt 3 (0D:E5F6), Black Hole (0D:C8A9) and Out of This Dimension (0D:C8E5).
; Strategies (table searched by M4LevelFindStrategy, level_objects.asm),
; helpers and effects of these stages. Stage data: tools/stages/spacemisc.py.
; RAM: $FF9900..$FF993F (reserved for this unit).
; Authority: ref/Star Fox (USA).sfc (rev0, SHA-256 3857b529...a84d); every
; routine re-read in the ROM bytes (build/agent-spacemisc/dis/, flow
; disassembly dis-spacemisc.py, linear dis16.py), names from UltraStarFox
; only. Documentation and oracle: build/agent-spacemisc/ (SPACEMISC.md,
; spacemisc-oracle.py). Conventions (level_objects.asm): a0 object, a1
; player; d0 = 0 keep / nonzero deferred removal (1F:D501). "d < K" of the
; original is the N bit of the 16-bit subtraction. Sounds and music
; (trigse 03:B7E5, startbgm $1F49/$1F48) are not ported.
M4_SPACEMISC equ $ff9900
M4_SM_AMOEBAS equ M4_SPACEMISC+0 ;.b $15A3 amoebas stuck to the player (0B:D262 clears it)
M4_SM_NOSETPORT3 equ M4_SPACEMISC+1 ;.b $1FD1 nosetport3 (written by the OOTD bird path)
; Extended fields (object-$8000) of this unit's objects only.
X_SM_STRAT2 equ -$8000+42 ;.l alx $1CD9 stratptr2 (letter bounce)
X_SM_DX equ -$8000+46 ;.b letter x step of the entry phase
X_SM_DY equ -$8000+47 ;.b letter y step
X_SM_FL equ -$8000+46 ;.b webmonster family: bit 6 = sflags2 $40 (legs pulled back, net released)

M4StrategiesSpaceMisc:
        dc.l $0a9211,M4SmBhExit1 ;bholeexit1 (Black Hole -> Venom 1 orbital)
        dc.l $0a9216,M4SmBhExit2 ;bholeexit2 (-> Sector Y)
        dc.l $0a921b,M4SmBhExit3 ;bholeexit3 (-> Sector Z)
        dc.l $09f901,M4SmRandomEnemy ;mother scripts 05:5822.. (Black Hole, Asteroid 3)
        dc.l $0a9f67,M4SmAmoeba ;amoeba (mother script 05:56FA, Black Hole)
        dc.l $0add08,M4SmMeteo0 ;meteo0 (Asteroid 3 map and mother 05:57A3)
        dc.l $06cc0b,M4SmChaseA ;clshipCHASEa (Asteroid 3 ending, Slippy)
        dc.l $06cc5e,M4SmChaseB ;clshipCHASEb (Peppy)
        dc.l $06ccb1,M4SmChaseC ;clshipCHASEc (Falco)
        dc.l $0a938e,M4SmLetterT ;THE END letters of Out of This Dimension
        dc.l $0a9493,M4SmLetterH
        dc.l $0a951b,M4SmLetterE
        dc.l $0a95a3,M4SmLetterE2
        dc.l $0a962b,M4SmLetterN
        dc.l $0a96b3,M4SmLetterD
        dc.l $09d77f,M4SmWebMonster ;webmonster, Asteroid 3 boss (05:F6E4)
        dc.l $099289,M4SmHomeRock ;homing asteroid (mother script 05:5672, Asteroid 3)
        dc.l 0

; ---------------------------------------------------------------------
; levelfinished written by an object: gamestart 02:E3FF reads it after the
; tick, as for the map's setvar (level.asm M4LvSetVar, M4LvLevelFinished).
; d0.b = value.
M4SmLevelFinished:
        move.b d0,M4_GS_LEVELFIN
        tst.b M4_GM_RESULTS
        bne.s M4SmLfDone
        movem.l d0-d1,-(sp)
        jsr M4LvLevelFinished
        movem.l (sp)+,d0-d1
M4SmLfDone:
        rts

; ---------------------------------------------------------------------
; Black Hole exits (gate_0 B8BF). Istrats 0A:9211/9216/921B: sbyte2 =
; levelfinished value 11/12/13 (le_bhole1..3), then 0A:921D: colldisable,
; colframe 4|$80. Tick 0A:9239: rotz += 12; |pz - z| < 200 and distXY
; (1F:D115) in 0..99 -> sflags2 $10, no zremove, strategy 0A:9293.
M4SmBhExit1:
        move.b #11,37(a0)
        bra.s M4SmBhExitInit
M4SmBhExit2:
        move.b #12,37(a0)
        bra.s M4SmBhExitInit
M4SmBhExit3:
        move.b #13,37(a0)
M4SmBhExitInit:
        move.l #M4SmBhExitTick,32(a0)
        bset #SF_COLLDISABLE,49(a0)
        move.b #4|$80,18(a0)
M4SmBhExitTick:
        addi.b #12,14(a0)
        movea.l a1,a2
        jsr M4EnZD
        subi.w #200,d0
        bpl.s M4SmBhKeep
        jsr M4EnDistXY ;$1591
        tst.w d0
        bmi.s M4SmBhKeep
        subi.w #100,d0
        bpl.s M4SmBhKeep
        bset #F2_SFLAG1,48(a0)
        move.l #M4SmBhInto,32(a0)
        bclr #3,45(a0) ;type &= ~atzremove
M4SmBhKeep:
        moveq #0,d0
        rts
; 0A:9293 (next pass): sbyte1 = 8, sbyte3 = 10, music $F5 (not ported),
; pshipflags3 &= ~$02 (engine sound); then 0A:92B8 every tick.
M4SmBhInto:
        move.b #8,36(a0)
        move.b #10,X_SBYTE3(a0)
        move.l #M4SmBhPull,32(a0)
        bclr #1,M4_LP_PSF3
; 0A:92B8: every 8 ticks: sbyte3 == 4 -> fadedir $FF (music $F1 not
; ported); --sbyte3 == 0 -> levelfinished = sbyte2, pshipflags3 &= ~$08;
; else pshipflags |= $60, pshipflags3 |= $08 and a ring B005 at player_pos
; + (0, 0, 600): ssprite, depthoffset 0, texture 0, colldisable, strategy
; 0A:936F (sound $2C not ported).
M4SmBhPull:
        subq.b #1,36(a0)
        bne.s M4SmBhKeep
        move.b #8,36(a0)
        cmpi.b #4,X_SBYTE3(a0)
        bne.s M4SmBhNoFade
        move.b #$ff,M4_FADE
M4SmBhNoFade:
        subq.b #1,X_SBYTE3(a0)
        bne.s M4SmBhRing
        bclr #3,M4_LP_PSF3
        move.b 37(a0),d0
        bsr M4SmLevelFinished
        bra.s M4SmBhKeep
M4SmBhRing:
        ori.b #$60,M4_LP_PSF
        bset #3,M4_LP_PSF3
        move.w #M4_FX_BLACKHOLE,d0
        jsr M4EnCreate
        beq.s M4SmBhKeep
        bset #F2_SPRITE,48(a2)
        clr.b X_DEPTHOFF(a2)
        clr.b X_TX(a2)
        bset #SF_COLLDISABLE,49(a2)
        move.w #$b005,X_SHAPEHDR(a2)
        move.w M4_SC_PPOSX,(a2)
        move.w M4_SC_PPOSY,2(a2)
        move.w M4_LP_POSZ,d0
        addi.w #600,d0
        move.w d0,4(a2)
        move.l #M4SmBhRingTick,32(a2)
        moveq #0,d0
        rts
; 0A:936F (rings): z -= 60, addplayerZ, outvz $18CB += $0A00.
M4SmBhRingTick:
        subi.w #60,4(a0)
        jsr M4EnAddPZ
        addi.w #$0a00,M4_LP_OUTVZ
        moveq #0,d0
        rts

; ---------------------------------------------------------------------
; Random path enemy 09:F901 (created by the mother scripts, e.g. 05:5822):
; path $20F6, shape = table 09:F923[random_l & $3E] (32 headers), then the
; path Istrat 04:8022.
M4SmRandomEnemy:
        move.w #$20f6,42(a0)
        jsr M4IntroRandom
        andi.w #$3e,d0
        move.w M4SmRandomShapes(pc,d0.w),d0
        move.w d0,X_SHAPEHDR(a0)
        jsr M4LevelShapeIndex
        jsr M4LevelSetShape
        jmp M4PathIstrat
M4SmRandomShapes: ;09:F923
        incbin '../build/M4SmRandomShapes.bin'

; ---------------------------------------------------------------------
; amoeba 0A:9F67 (amoeba2 B1A9 sprite): ssprite, depthoffset 0, texture 0,
; collstrat 0A:9FBB, no expstrat, HP $FF, AP 0, roty $80; tick 0A:9FAA:
; z -= 60, addplayerZ.
M4SmAmoeba:
        bset #F2_SPRITE,48(a0)
        clr.b X_DEPTHOFF(a0)
        clr.b X_TX(a0)
        move.l #M4SmAmoebaTick,32(a0)
        move.l #M4SmAmoebaColl,X_COLL(a0)
        clr.l X_EXP(a0)
        move.b #$ff,38(a0)
        clr.b 39(a0)
        move.b #$80,13(a0)
M4SmAmoebaTick:
        subi.w #60,4(a0)
        jsr M4EnAddPZ
        moveq #0,d0
        rts
; collstrat 0A:9FBB (collide is never cleared: it runs every tick after the
; first contact): $15A3 < 3 and collobj = player -> 0A:A023 (stuck),
; $15A3++, then the strategy (1F:DC25); otherwise strategy 0A:9FFB: x, y =
; Achase16_4(.., player), then 0A:9FAA.
M4SmAmoebaColl:
        cmpi.b #3,M4_SM_AMOEBAS
        beq.s M4SmAmFollowSet
        move.w 62(a0),d0
        cmp.w a1,d0
        bne.s M4SmAmFollowSet
        move.l #M4SmAmoebaStick,32(a0)
        addq.b #1,M4_SM_AMOEBAS
        jmp M4LcStrategy
M4SmAmFollowSet:
        move.l #M4SmAmFollow,32(a0)
M4SmAmFollow:
        moveq #4,d2
        move.w (a0),d0
        move.w (a1),d1
        jsr M4LpAchase
        move.w d0,(a0)
        move.w 2(a0),d0
        move.w 2(a1),d1
        jsr M4LpAchase
        move.w d0,2(a0)
        bra.s M4SmAmoebaTick
; 0A:A023: pshipflags |= $40, colldisable, shape B18D, strategy 0A:A06B;
; sword1 = asr2(x - player_posx), sword2 = asr2(y - player_posy).
M4SmAmoebaStick:
        ori.b #$40,M4_LP_PSF
        bset #SF_COLLDISABLE,49(a0)
        move.w #$b18d,d0
        move.w d0,X_SHAPEHDR(a0)
        jsr M4LevelShapeIndex
        jsr M4LevelSetShape
        move.l #M4SmAmStuck,32(a0)
        move.w (a0),d0
        sub.w M4_SC_PPOSX,d0
        asr.w #2,d0
        move.w d0,40(a0)
        move.w 2(a0),d0
        sub.w M4_SC_PPOSY,d0
        asr.w #2,d0
        move.w d0,X_SWORD2(a0)
; 0A:A06B: pos = player + (lo8(sword1), lo8(sword2), 0) rotated by the
; player's rotz, rotx, roty (1F:CC78, CAFB, C97B; BYTE products, results
; sign-extended), addplayerZ. (gameframe + al1pt) & 3 == 0 and rollZvel
; $1503 != 0 -> 0A:A17B (released). Else: gameframe even -> player white
; flash (sflags $02; sound $56 not ported); gameframe & 15 == 0 ->
; screenflash 4 / type 0 and shield - 1 when nonzero.
M4SmAmStuck:
        move.b 41(a0),d3
        move.b X_SWORD2+1(a0),d4
        moveq #0,d5
        movea.l a1,a2
        jsr M4WeaponOffset ;x4 of the three rotations
        asr.w #2,d3
        asr.w #2,d4
        asr.w #2,d5
        add.w (a1),d3
        move.w d3,(a0)
        add.w 2(a1),d4
        move.w d4,2(a0)
        add.w 4(a1),d5
        move.w d5,4(a0)
        jsr M4EnAddPZ
        jsr M4ArPhase
        andi.b #3,d0
        bne.s M4SmAmDrain
        tst.b M4_LP_ROLLZVEL
        bne.s M4SmAmRelease
M4SmAmDrain:
        btst #0,M4_LV_GAMEFRAME+1
        bne.s M4SmAmNoFlash
        bset #2,31(a1) ;white flash (sflags $02)
M4SmAmNoFlash:
        moveq #15,d0
        and.w M4_LV_GAMEFRAME,d0
        bne.s M4SmAmKeep
        move.b #4,M4_LP_FLASHCNT
        clr.b M4_LP_FLASHTYPE
        tst.b M4_LP_BODYHP
        beq.s M4SmAmKeep
        subq.b #1,M4_LP_BODYHP
M4SmAmKeep:
        moveq #0,d0
        rts
; 0A:A17B: strategy 0A:9FAA, $15A3 = 0, pshipflags &= ~$40, then the
; strategy (1F:DC25).
M4SmAmRelease:
        move.l #M4SmAmoebaTick,32(a0)
        clr.b M4_SM_AMOEBAS
        andi.b #$bf,M4_LP_PSF
        bra M4SmAmoebaTick

; ---------------------------------------------------------------------
; coll_Istrat 06:897B: collide = 0; unless nohitaffect, do_coll(self, AP of
; the collider) (no white flash; distance sounds not ported); then the
; strategy.
M4SmCollNoFlash:
        bclr #SF_COLLIDE,49(a0)
        btst #SF_NOHITAFFECT,49(a0)
        bne.s M4SmCollNfDone
        jsr M4LcCollider
        move.l a2,d0
        beq.s M4SmCollNfDone
        moveq #0,d0
        move.b 39(a2),d0
        jsr M4LevelDoColl
M4SmCollNfDone:
        jmp M4LcStrategy

; animframe d0.b + 1 modulo d1 (bit 7 kept): adc #1 / bmi / adc mod / and
; $7F / cmp / sbc / ora $80 (0A:DD7D, 09:8048).
M4SmAfInc:
        addq.b #1,d0
        bmi.s M4SmAfMod
        add.b d1,d0
M4SmAfMod:
        andi.b #$7f,d0
        cmp.b d1,d0
        blo.s M4SmAfDone
        sub.b d1,d0
M4SmAfDone:
        ori.b #$80,d0
        rts

; ---------------------------------------------------------------------
; meteo0 0A:DD08 (meteo_0 BBB8): collstrat 06:897B, expstrat 0A:DDDB, HP 2,
; AP 16, roty $80, animframe 0|$80, sbyte1 20, nohitaffect. Tick 0A:DD4C:
; sbyte1 0 -> nothing; |pz - z| >= 1000 -> nothing; animframe (9 frames)
; advances until 8; at 8: nohitaffect off, every 8th (gameframe + al1pt)
; fire_weapon $0A (RelSlowElaserHome) at the player, sbyte1 - 1; then
; addplayerZ (also while opening).
M4SmMeteo0:
        move.l #M4SmMeteo0Tick,32(a0)
        move.l #M4SmCollNoFlash,X_COLL(a0)
        move.l #M4SmMeteo0Exp,X_EXP(a0)
        move.b #2,38(a0)
        move.b #16,39(a0)
        move.b #$80,13(a0)
        move.b #$80,16(a0)
        move.b #20,36(a0)
        bset #SF_NOHITAFFECT,49(a0)
M4SmMeteo0Tick:
        tst.b 36(a0)
        beq.s M4SmMeteo0Keep
        movea.l a1,a2
        jsr M4EnZD
        subi.w #1000,d0
        bpl.s M4SmMeteo0Keep
        move.b 16(a0),d0
        andi.b #$7f,d0
        cmpi.b #8,d0
        beq.s M4SmMeteo0Open
        move.b 16(a0),d0
        moveq #9,d1
        bsr M4SmAfInc
        move.b d0,16(a0)
        bra.s M4SmMeteo0Move
M4SmMeteo0Open:
        bclr #SF_NOHITAFFECT,49(a0)
        jsr M4ArPhase
        andi.b #7,d0
        bne.s M4SmMeteo0Count
        moveq #M4_WT_RSEH,d0
        moveq #0,d3
        moveq #0,d4
        moveq #0,d5
        moveq #0,d6
        moveq #0,d7
        movea.l a1,a3
        jsr M4EnFire
M4SmMeteo0Count:
        subq.b #1,36(a0)
M4SmMeteo0Move:
        jsr M4EnAddPZ
M4SmMeteo0Keep:
        moveq #0,d0
        rts
; expstrat 0A:DDDB: an asteroid AF5D with strategy meteor 09:9387 at the
; same position (1F:D54B, 1F:DAD9), then explode_Istrat 06:F45F.
M4SmMeteo0Exp:
        move.w #$af5d,d0
        jsr M4LevelShapeIndex
        jsr M4EnCreate
        beq.s M4SmMeteo0Boom
        move.w #$af5d,X_SHAPEHDR(a2)
        move.l #M4StratMeteor,32(a2)
        move.l (a0),(a2)
        move.w 4(a0),4(a2)
M4SmMeteo0Boom:
        jmp M4LevelExplode

; ---------------------------------------------------------------------
; Team-mates of the Asteroid 3 ending (ClearChase). Istrats 06:CC0B (a),
; 06:CC5E (b), 06:CCB1 (c): shadow (sflags $08), no zremove, rotz/roty
; $C0/$20, $40/$E0, -/-; sword1 221/196/171. Every tick x = Achase16_4(x,
; TX) with TX -70/70/0, dZ ($151F) -100/-200/-300, dY ($1521) 20/20/30,
; then the common body 06:CCFC.
M4SmChaseA:
        move.b #$c0,14(a0)
        move.b #$20,13(a0)
        move.w #221,40(a0)
        move.l #M4SmChaseATick,32(a0)
        bsr.s M4SmChaseInit
M4SmChaseATick:
        move.w #-70,d1
        move.w #-100,d5
        moveq #20,d6
        bra.s M4SmChaseBody
M4SmChaseB:
        move.b #$40,14(a0)
        move.b #$e0,13(a0)
        move.w #196,40(a0)
        move.l #M4SmChaseBTick,32(a0)
        bsr.s M4SmChaseInit
M4SmChaseBTick:
        moveq #70,d1
        move.w #-200,d5
        moveq #20,d6
        bra.s M4SmChaseBody
M4SmChaseC:
        move.w #171,40(a0)
        move.l #M4SmChaseCTick,32(a0)
        bsr.s M4SmChaseInit
M4SmChaseCTick:
        moveq #0,d1
        move.w #-300,d5
        moveq #30,d6
        bra.s M4SmChaseBody
M4SmChaseInit:
        bset #F2_SHADOW,48(a0)
        bclr #3,45(a0)
        rts
; 06:CCFC: sword1 0 -> clshipboost_I 06:C115; sword1 - 1; z =
; Achase16_4(z, player.z + dZ) (1F:D6F0); y = Achase16_5(y, player.y + dY)
; (1F:D73E); rotx = Achase8_5(rotx, player.rotx) (1F:D938); even
; gameframe: rotz = Achase8_5(rotz, player.rotz), roty =
; Achase8_4(roty, player.roty) (1F:D8F7); addplayerZ; z += $1558.
M4SmChaseBody:
        move.w (a0),d0
        moveq #4,d2
        jsr M4LpAchase ;x (1F:D6F0, before the body)
        move.w d0,(a0)
        tst.w 40(a0)
        bne.s M4SmChaseFly
        jmp M4StratClshipBoost
M4SmChaseFly:
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
        move.b 12(a0),d0
        move.b 12(a1),d1
        moveq #5,d2
        jsr M4EnChase8
        move.b d0,12(a0)
        btst #0,M4_LV_GAMEFRAME+1
        bne.s M4SmChaseOdd
        move.b 14(a0),d0
        move.b 14(a1),d1
        moveq #5,d2
        jsr M4EnChase8
        move.b d0,14(a0)
        move.b 13(a0),d0
        move.b 13(a1),d1
        moveq #4,d2
        jsr M4EnChase8
        move.b d0,13(a0)
M4SmChaseOdd:
        jsr M4EnAddPZ
        move.w M4_WP_W1558,d0
        add.w d0,4(a0)
        moveq #0,d0
        rts

; ---------------------------------------------------------------------
; keeprelto_player 1F:DB21: z += playervelZ ($14EC = player vz) - pviewvelz.
M4SmKeepRel:
        move.w 10(a1),d0
        sub.w M4_LP_PVIEWVZ,d0
        add.w d0,4(a0)
        rts
; d0.w = ROM shape header -> shape of a0 (descriptor, X_SHAPEHDR).
M4SmSetHdr:
        move.w d0,X_SHAPEHDR(a0)
        jsr M4LevelShapeIndex
        jmp M4LevelSetShape

; ---------------------------------------------------------------------
; THE END letters (Out of This Dimension, map 0D:CBAF..CBF5; UltraStarFox
; theend_*_istrat, font shapes). Istrats 0A:938E T, 9493 H, 951B E, 95A3 E2,
; 962B N, 96B3 D: strategy = collstrat = the entry phase, expstrat 06:F45F,
; sbyte1 $33, roty $80, HP $FF, AP 4. The extracted parameters hold
; spare bounces, z rotation, movement and the upright/tilted shapes.
; Entry phase (0A:93DF..): x += dx, y += dy, rotx += 5, roty += 5, addplayerZ,
; keeprelto_player; sbyte1 0 -> 0A:973B (T: first 0A:9416), H/N: 0A:9792.
M4SmLetterT:
        lea M4SmLtParT(pc),a2
        move.l #M4SmLtEntryT,d1
        bra.s M4SmLtInit
M4SmLetterH:
        lea M4SmLtParH(pc),a2
        move.l #M4SmLtEntryB,d1
        bra.s M4SmLtInit
M4SmLetterE:
        lea M4SmLtParE(pc),a2
        move.l #M4SmLtEntryA,d1
        bra.s M4SmLtInit
M4SmLetterE2:
        lea M4SmLtParE2(pc),a2
        move.l #M4SmLtEntryA,d1
        bra.s M4SmLtInit
M4SmLetterN:
        lea M4SmLtParN(pc),a2
        move.l #M4SmLtEntryB,d1
        bra.s M4SmLtInit
M4SmLetterD:
        lea M4SmLtParD(pc),a2
        move.l #M4SmLtEntryA,d1
M4SmLtInit:
        move.l d1,32(a0)
        move.l d1,X_COLL(a0)
        move.l #M4LevelExplode,X_EXP(a0)
        move.b #$33,36(a0)
        move.b (a2)+,X_SBYTE3(a0)
        move.b #$80,13(a0)
        move.b (a2)+,14(a0)
        move.b (a2)+,X_SM_DX(a0)
        move.b (a2)+,X_SM_DY(a0)
        move.w (a2)+,40(a0)
        move.w (a2)+,X_SWORD2(a0)
        move.b #$ff,38(a0)
        move.b #4,39(a0)
        movea.l d1,a2
        jmp (a2)
; sbyte3, rotz, dx, dy, sword1, sword2
        include '../build/m4-end-letters.inc'
M4SmLtEntryStep: ;Z set when sbyte1 reaches 0
        move.b X_SM_DX(a0),d0
        ext.w d0
        add.w d0,(a0)
        move.b X_SM_DY(a0),d0
        ext.w d0
        add.w d0,2(a0)
        addq.b #5,12(a0)
        addq.b #5,13(a0)
        jsr M4EnAddPZ
        bsr M4SmKeepRel
        subq.b #1,36(a0)
        rts
M4SmLtEntryA:
        bsr.s M4SmLtEntryStep
        beq.s M4SmLtSpinA
        moveq #0,d0
        rts
M4SmLtEntryB:
        bsr.s M4SmLtEntryStep
        beq.s M4SmLtSpinB
        moveq #0,d0
        rts
; T, 0A:9416: the counter object (nullshape, strategy = collstrat =
; expstrat 0A:97E9, HP $FF, AP 4, no zremove) at player + (1000, 0, 7000),
; numendok $1FE2 = 0; then 0A:973B.
M4SmLtEntryT:
        bsr.s M4SmLtEntryStep
        beq.s M4SmLtCounter
        moveq #0,d0
        rts
M4SmLtCounter:
        moveq #-1,d0
        jsr M4EnCreate
        beq.s M4SmLtSpinA
        move.l #M4SmEndCount,32(a2)
        move.l #M4SmEndCount,X_COLL(a2)
        move.l #M4SmEndCount,X_EXP(a2)
        move.b #$ff,38(a2)
        move.b #4,39(a2)
        bclr #3,45(a2)
        clr.b M4_MV_1FE2
        move.w (a1),d0
        addi.w #1000,d0
        move.w d0,(a2)
        move.w 2(a1),2(a2)
        move.w 4(a1),d0
        addi.w #7000,d0
        move.w d0,4(a2)
; 0A:973B / 0A:9792: strategy = collstrat = 0A:976E / 97C5, rotx = roty = 0,
; sbyte1 $21; then roty += 4, z -= 19, addplayerZ, keeprelto_player; sbyte1
; 0 -> 0A:9831 / 9870: strategy 0A:9855 / 9894, collstrat 0A:9922, no
; zremove.
M4SmLtSpinA:
        move.l #M4SmLtTurnA,d1
        bra.s M4SmLtSpin
M4SmLtSpinB:
        move.l #M4SmLtTurnB,d1
M4SmLtSpin:
        move.l d1,32(a0)
        move.l d1,X_COLL(a0)
        move.l #M4LevelExplode,X_EXP(a0)
        clr.b 12(a0)
        clr.b 13(a0)
        move.b #$21,36(a0)
        movea.l d1,a2
        jmp (a2)
M4SmLtTurnStep:
        addq.b #4,13(a0)
        subi.w #19,4(a0)
        jsr M4EnAddPZ
        bsr M4SmKeepRel
        subq.b #1,36(a0)
        rts
M4SmLtTurnA:
        bsr.s M4SmLtTurnStep
        bne.s M4SmLtKeep
        move.l #M4SmLtWaitA,32(a0)
        bra.s M4SmLtWaitSet
M4SmLtTurnB:
        bsr.s M4SmLtTurnStep
        bne.s M4SmLtKeep
        move.l #M4SmLtWaitB,32(a0)
M4SmLtWaitSet:
        move.l #M4SmLtColl,X_COLL(a0)
        bclr #3,45(a0)
        movea.l 32(a0),a2
        jmp (a2)
M4SmLtKeep:
        moveq #0,d0
        rts
; 0A:9855 (A: rotz 0) / 0A:9894 (B: rotz 0 or $80): upright -> 0A:98B9;
; else shape = sword2 (tilted), addplayerZ, keeprelto_player.
M4SmLtWaitB:
        cmpi.b #$80,14(a0)
        beq.s M4SmLtUpright
M4SmLtWaitA:
        tst.b 14(a0)
        beq.s M4SmLtUpright
        move.w X_SWORD2(a0),d0
M4SmLtShow:
        bsr M4SmSetHdr
        jsr M4EnAddPZ
        bsr M4SmKeepRel
        moveq #0,d0
        rts
; 0A:98B9: numendok $1FE2 negative (all six upright) -> 0A:98D2; else shape
; = sword1 (upright), $1FE2 + 1, addplayerZ, keeprelto_player.
M4SmLtUpright:
        tst.b M4_MV_1FE2
        bmi.s M4SmLtLeave
        addq.b #1,M4_MV_1FE2
        move.w 40(a0),d0
        bra.s M4SmLtShow
; 0A:98D2: strategy = collstrat = 0A:98FC, colldisable, zremove; then rotx
; += 3, roty += 2, rotz += 6, addplayerZ, z -= 20.
M4SmLtLeave:
        move.l #M4SmLtGone,32(a0)
        move.l #M4SmLtGone,X_COLL(a0)
        bset #SF_COLLDISABLE,49(a0)
        bset #3,45(a0)
M4SmLtGone:
        addq.b #3,12(a0)
        addq.b #2,13(a0)
        addq.b #6,14(a0)
        jsr M4EnAddPZ
        subi.w #20,4(a0)
        moveq #0,d0
        rts
; Counter 0A:97E9: $1FE2 == 6 (six letters upright in one pass) ->
; strategy 0A:9813 (music $06 not ported); $1FE2 = 0; addplayerZ,
; keeprelto_player. 0A:9813: $1FE2 = $FF (theenddead 0A:9821).
M4SmEndCount:
        cmpi.b #6,M4_MV_1FE2
        bne.s M4SmEndCountClr
        move.l #M4SmEndDone,32(a0)
M4SmEndCountClr:
        clr.b M4_MV_1FE2
        bra.s M4SmEndMove
M4SmEndDone:
        st M4_MV_1FE2
M4SmEndMove:
        jsr M4EnAddPZ
        bsr M4SmKeepRel
        moveq #0,d0
        rts
; collstrat 0A:9922 (hit while waiting): sbyte3 != 0 -> sbyte3 - 1 and a
; bounce only; else sbyte3 = 2 and random_l selects an extracted spawn. Bounce
; 0A:9AA2: stratptr2 = strategy, sbyte1 $20, colldisable, strategy
; 0A:9AE1, vy -45, vz 180, sbyte2 = random_l.
M4SmLtColl:
        tst.b X_SBYTE3(a0)
        beq.s M4SmLtSpawn
        subq.b #1,X_SBYTE3(a0)
        bra.s M4SmLtBounce
M4SmLtSpawn:
        move.b #2,X_SBYTE3(a0)
        jsr M4IntroRandom
        lea M4SmLtSpawns(pc),a3
        moveq #2,d1
M4SmLtSpawnFind:
        cmp.b (a3),d0
        blo.s M4SmLtSpawnThis
        lea 16(a3),a3
        dbra d1,M4SmLtSpawnFind
M4SmLtSpawnThis:
        move.w 2(a3),d0
        jsr M4LevelShapeIndex
        jsr M4EnCreate
        beq.s M4SmLtBounce
        move.w 2(a3),X_SHAPEHDR(a2)
        move.l 4(a3),d0
        move.l a2,-(sp)
        jsr M4LevelFindStrategy
        move.l a2,d0
        movea.l (sp)+,a2
        move.l d0,32(a2)
        tst.b 1(a3)
        beq.s M4SmLtSpawnPos
        move.b #M4SmLtSpawnHP,38(a2)
        move.b #M4SmLtSpawnAP,39(a2)
M4SmLtSpawnPos:
        move.w (a0),d0
        add.w 8(a3),d0
        move.w d0,(a2)
        move.w 2(a0),d0
        add.w 10(a3),d0
        move.w d0,2(a2)
        move.w 4(a0),d0
        add.w 12(a3),d0
        move.w d0,4(a2)
M4SmLtBounce:
        move.l 32(a0),X_SM_STRAT2(a0)
        move.b #$20,36(a0)
        bset #SF_COLLDISABLE,49(a0)
        move.l #M4SmLtFly,32(a0)
        move.w #-45,8(a0)
        move.w #180,10(a0)
        jsr M4IntroRandom
        move.b d0,37(a0)
; 0A:9AE1: addplayerZ, rotx += 8, roty += 8, rotz += 4 / 6 / 2 (sbyte2 <
; $56, < $AC, else); --sbyte1 0 -> strategy = stratptr2, colldisable off;
; else y += vy, z += vz, vy += 3, vz -= 12; keeprelto_player.
M4SmLtFly:
        jsr M4EnAddPZ
        addq.b #8,12(a0)
        addq.b #8,13(a0)
        moveq #4,d0
        cmpi.b #$56,37(a0)
        blo.s M4SmLtFlyRot
        moveq #6,d0
        cmpi.b #$ac,37(a0)
        blo.s M4SmLtFlyRot
        moveq #2,d0
M4SmLtFlyRot:
        add.b d0,14(a0)
        subq.b #1,36(a0)
        bne.s M4SmLtFlyMove
        move.l X_SM_STRAT2(a0),32(a0)
        bclr #SF_COLLDISABLE,49(a0)
        bra.s M4SmLtFlyEnd
M4SmLtFlyMove:
        move.w 8(a0),d0
        add.w d0,2(a0)
        move.w 10(a0),d0
        add.w d0,4(a0)
        addq.w #3,8(a0)
        subi.w #12,10(a0)
M4SmLtFlyEnd:
        bsr M4SmKeepRel
        moveq #0,d0
        rts
; limit (r below), HP/AP flag, header, strategy, offset x, y, z, pad
M4SmLtSpawns:
        include '../build/m4-end-letter-spawns.inc'

; ---------------------------------------------------------------------
; Asteroid 3 boss webmonster 09:D77F (boss_0_1 CA7C) with six legs (CA98,
; 09:DF4D, children 1..6), the web (CA44 / CA60, 09:DA75, child 7) and the
; net it throws (CAB4, 09:DD83). Field use (this unit's objects only):
; X_SM_FL bit 6 = original sflags2 $40 of the legs (pulled back by the web);
; X2_FL4 bit 5 = sflags4 $20 of the net (roll seen). Mother/child links as
; the path interpreter: id in sbyte1, mother in X_ALPTR, chain in sword1,
; X2_FL4 bit 6 mother / bit 4 child. Original sflags2 $10/$20 = F2_SFLAG1/2.

; |player.z - z| < d1 (80AB: N of the 16-bit difference) -> Z clear (near).
M4SmNearZ:
        move.w 4(a1),d0
        sub.w 4(a0),d0
        bpl.s M4SmNearAbs
        neg.w d0
M4SmNearAbs:
        sub.w d1,d0
        smi d0
        tst.b d0
        rts
; findchild ids d4..d5 of a0 (1F:DC40 loop): F2_SFLAG1 cleared / set / X_SM_FL
; bit 6 set according to d6 = 0 / 1 / 2.
M4SmLegsFlag:
        movem.l d0/d4/a2,-(sp)
M4SmLegsNext:
        move.b d4,d0
        jsr M4BsChild
        beq.s M4SmLegsSkip
        tst.b d6
        bne.s M4SmLegsSet
        bclr #F2_SFLAG1,48(a2)
        bra.s M4SmLegsSkip
M4SmLegsSet:
        cmpi.b #2,d6
        beq.s M4SmLegsPull
        bset #F2_SFLAG1,48(a2)
        bra.s M4SmLegsSkip
M4SmLegsPull:
        bset #6,X_SM_FL(a2)
M4SmLegsSkip:
        addq.b #1,d4
        cmp.b d5,d4
        bls.s M4SmLegsNext
        movem.l (sp)+,d0/d4/a2
        rts
; Child of a0 (1F:D54B + makechild 1F:D56F): d0.w header, d1.b id, d2.l
; strategy -> a2 (Z set when the pool is full: skipped, as the ROM does),
; at the end of the mother's chain, collflags enemy1 (set by the callers).
M4SmMakeChild:
        movem.l d0/a3,-(sp)
        move.w d0,-(sp)
        jsr M4LevelShapeIndex
        jsr M4EnCreate
        move.w (sp)+,d0
        cmpa.w #0,a2
        beq.s M4SmMakeDone
        move.w d0,X_SHAPEHDR(a2)
        move.l d2,32(a2)
        ori.b #CF_ENEMY1,44(a2)
        move.b d1,36(a2)
        move.w a0,X_ALPTR(a2)
        clr.w 40(a2)
        movea.l a0,a3
M4SmMakeTail:
        move.w 40(a3),d0
        beq.s M4SmMakeLink
        movea.w d0,a3
        bra.s M4SmMakeTail
M4SmMakeLink:
        move.w a2,40(a3)
        bset #6,X2_FL4(a0)
        bset #4,X2_FL4(a2)
        cmpa.w #0,a2
M4SmMakeDone:
        movem.l (sp)+,d0/a3
        rts

; webmonster_Istrat 09:D77F: depthoffset 1, collflags enemy1, m_bossmaxHP =
; m_bossHP = 0, rotx $60, y 1000, the children (09:D8A6), collstrat
; hitflash 06:89A3, no expstrat, HP $FF, AP 8.
M4SmWebMonster:
        move.b #1,X_DEPTHOFF(a0)
        ori.b #CF_ENEMY1,44(a0)
        clr.b M4_BOSS_MAXHP
        clr.b M4_BOSS_HP
        move.b #$60,12(a0)
        move.w #1000,2(a0)
        clr.b 36(a0)
        clr.w X_ALPTR(a0)
        clr.w 40(a0)
        lea M4SmWebKids(pc),a3
        moveq #6,d3
M4SmWebKid:
        move.w (a3)+,d0
        move.b (a3)+,d1
        move.l #M4SmWebLeg,d2
        cmpi.b #7,d1
        bne.s M4SmWebKidLeg
        move.l #M4SmWeb,d2
M4SmWebKidLeg:
        bsr M4SmMakeChild
        beq.s M4SmWebKidFail
        move.b (a3),X2_CHILDX(a2)
        move.b 1(a3),X2_CHILDX+1(a2)
        move.b 2(a3),X2_CHILDX+2(a2)
        move.b 3(a3),X2_CHILDRX+2(a2)
M4SmWebKidFail:
        addq.l #5,a3
        dbra d3,M4SmWebKid
        jsr M4PvRotChildren
        move.l #M4SmWebTick,32(a0)
        move.l #M4LcHitFlash,X_COLL(a0)
        clr.l X_EXP(a0)
        move.b #$ff,38(a0)
        move.b #8,39(a0)
; 09:D7D5: rotx != 0 -> rotx - 1, y - 10; else y != 0 -> y - 10; else no
; leg (children 1..6) left -> 09:D847. Then 09:D834: rotz - 1, addplayerZ,
; keeprelto_player, rotpos of the children (09:E118).
M4SmWebTick:
        tst.b 12(a0)
        beq.s M4SmWebDown
        subq.b #1,12(a0)
        bra.s M4SmWebDrop
M4SmWebDown:
        tst.w 2(a0)
        beq.s M4SmWebLegs
M4SmWebDrop:
        subi.w #10,2(a0)
        bra.s M4SmWebMove
M4SmWebLegs:
        moveq #1,d4
M4SmWebLegFind:
        move.b d4,d0
        jsr M4BsChild
        bne.s M4SmWebMove
        addq.b #1,d4
        cmpi.b #6,d4
        bls.s M4SmWebLegFind
        bra.s M4SmWebEnd
M4SmWebMove:
        subq.b #1,14(a0)
        jsr M4EnAddPZ
        bsr M4SmKeepRel
        jsr M4PvRotChildren
        moveq #0,d0
        rts
; 09:D847 (all legs destroyed): first time the web (child 7) gets strategy
; 09:DD38; rotz += sbyte2, sbyte2 + 1; 30 -> bossexplode 06:EAAE; below 20:
; a medium explosion (06:EEEE) moved by addrnd2posy (06:EF67) (sound $1E,
; music $F1 at 1: not ported).
M4SmWebEnd:
        tst.b 37(a0)
        bne.s M4SmWebSpin
        moveq #7,d0
        jsr M4BsChild
        beq.s M4SmWebSpin
        move.l #M4SmWebLoose,32(a2)
M4SmWebSpin:
        move.b 37(a0),d0
        add.b d0,14(a0)
        addq.b #1,37(a0)
        cmpi.b #$1e,37(a0)
        bne.s M4SmWebNotYet
        jmp M4B1Explode
M4SmWebNotYet:
        cmpi.b #$14,37(a0)
        bhs.s M4SmWebMove
        jsr M4FxMedium
        cmpa.w #0,a2
        beq.s M4SmWebNoExp
        jsr M4FxRandomPos
        bra.s M4SmWebMove
M4SmWebNoExp: ;dummyobj in the original: addrnd2posy still draws twice
        jsr M4IntroRandom
        jsr M4IntroRandom
        bra.s M4SmWebMove
; header, id, childx, childy, childz, child rotz offset (09:D8A6 order)
M4SmWebKids:
        include '../build/m4-web-children.inc'
        even

; Legs 09:DF4D: set_normcollptrs (hitflash / explode), HP 20, AP 4,
; m_bossmaxHP += 20, depthoffset 1. 09:DF76: sflags2 $40 (pulled back):
; every 8th gameframe depthoffset - 1 down to 1, where $40 clears. Held by
; the web (sflag1): nohitaffect, sflag2 (fire request), every 16th
; gameframe depthoffset + 1 up to 4 unless $40. Free: nohitaffect off; with
; the request: HMISSILE1 ($12) rotx +0, roty +$80, no target, al_ptr =
; player, collflags enemy1; request cleared. Then m_bossHP += HP.
M4SmWebLeg:
        move.l #M4SmWebLegTick,32(a0)
        jsr M4LvNormPtrs
        move.l #M4SmChildExplode,X_EXP(a0)
        move.b #20,38(a0)
        move.b #4,39(a0)
        addi.b #20,M4_BOSS_MAXHP
        move.b #1,X_DEPTHOFF(a0)
M4SmWebLegTick:
        btst #6,X_SM_FL(a0)
        beq.s M4SmLegHeld
        moveq #7,d0
        and.w M4_LV_GAMEFRAME,d0
        bne.s M4SmLegHeld
        cmpi.b #1,X_DEPTHOFF(a0)
        beq.s M4SmLegBack
        subq.b #1,X_DEPTHOFF(a0)
        bra.s M4SmLegHeld
M4SmLegBack:
        bclr #6,X_SM_FL(a0)
M4SmLegHeld:
        btst #F2_SFLAG1,48(a0)
        bne.s M4SmLegCaught
        bclr #SF_NOHITAFFECT,49(a0)
        btst #F2_SFLAG2,48(a0)
        beq.s M4SmLegHp
        moveq #M4_WT_HMISSILE1,d0
        moveq #0,d3
        moveq #0,d4
        moveq #0,d5
        moveq #0,d6
        move.w #$80,d7
        suba.l a3,a3
        jsr M4EnFire
        bclr #F2_SFLAG2,48(a0)
        cmpa.w #0,a2
        beq.s M4SmLegHp
        move.w a1,X_ALPTR(a2)
        ori.b #CF_ENEMY1,44(a2)
        bra.s M4SmLegHp
M4SmLegCaught:
        bset #SF_NOHITAFFECT,49(a0)
        bset #F2_SFLAG2,48(a0)
        btst #6,X_SM_FL(a0)
        bne.s M4SmLegHp
        moveq #15,d0
        and.w M4_LV_GAMEFRAME,d0
        bne.s M4SmLegHp
        cmpi.b #4,X_DEPTHOFF(a0)
        beq.s M4SmLegHp
        addq.b #1,X_DEPTHOFF(a0)
M4SmLegHp:
        move.b 38(a0),d0
        add.b d0,M4_BOSS_HP
        moveq #0,d0
        rts
; explode_Istrat 06:F45F of a child: divorcefamily 1F:DBA4 first (it leaves
; the mother's chain this tick; M4LevelExplode does not).
M4SmChildExplode:
        btst #4,X2_FL4(a0)
        beq.s M4SmChildExplodeNow
        movea.l a0,a2
        jsr M4PvDivorce
M4SmChildExplodeNow:
        jmp M4LevelExplode

; Web 09:DA75: animframe 0|$80, HP $FF, AP 2, collstrat 09:DC00, expstrat
; 06:F45F, nohitaffect. State A 09:DAB1: rotz offset += sbyte2.
;  sbyte3 != 0: snap the offset to a multiple of $55 (+$2A while sflag2):
;   remainder 0 -> 09:DB07; remainder >= $51 -> offset += $55 - remainder,
;   09:DB07; else offset = (offset - 4) & $FC and leave. 09:DB07: sbyte3 - 1;
;   legs 4..6 (sflag2) or 1..3 released (sflag1 cleared).
;  sbyte3 == 0 (09:DB75): sbyte2 + 1 (skipping $2A, wrapping at $55); $3F ->
;   the net (09:DD12, only with rotx 0) and state B 09:DC17; else nonzero ->
;   shape CA60, legs 1..6 held (sflag1); 0 -> sflag2 toggled, sbyte3 = 50,
;   shape CA44. Sounds $4F/$8F not ported.
M4SmWeb:
        move.b #$80,16(a0)
        move.b #$ff,38(a0)
        move.b #2,39(a0)
        move.l #M4SmWebA,32(a0)
        move.l #M4SmWebColl,X_COLL(a0)
        move.l #M4LevelExplode,X_EXP(a0)
        bset #SF_NOHITAFFECT,49(a0)
M4SmWebA:
        move.b 37(a0),d0
        add.b d0,X2_CHILDRX+2(a0)
        tst.b X_SBYTE3(a0)
        beq.s M4SmWebCycle
        move.b X2_CHILDRX+2(a0),d0
        btst #F2_SFLAG2,48(a0)
        beq.s M4SmWebSnap
        addi.b #$2a,d0
M4SmWebSnap:
        tst.b d0
        beq.s M4SmWebStep
        subi.b #$55,d0
        bcc.s M4SmWebSnap
        cmpi.b #$fc,d0
        bhs.s M4SmWebAlign
        move.b X2_CHILDRX+2(a0),d0
        subq.b #4,d0
        andi.b #$fc,d0
        move.b d0,X2_CHILDRX+2(a0)
        bra M4SmWebKeep
M4SmWebAlign:
        sub.b d0,X2_CHILDRX+2(a0)
M4SmWebStep:
        subq.b #1,X_SBYTE3(a0)
        moveq #0,d6
        move.w X_ALPTR(a0),d0
        beq M4SmWebKeep
        move.l a0,-(sp)
        movea.w d0,a0
        moveq #1,d4
        moveq #3,d5
        movea.l (sp),a2
        btst #F2_SFLAG2,48(a2)
        beq.s M4SmWebRelease
        moveq #4,d4
        moveq #6,d5
M4SmWebRelease:
        bsr M4SmLegsFlag
        movea.l (sp)+,a0
        bra M4SmWebKeep
M4SmWebCycle:
        move.b 37(a0),d0
        addq.b #1,d0
        cmpi.b #$2a,d0
        blo.s M4SmWebNo2a
        addq.b #1,d0
M4SmWebNo2a:
        cmpi.b #$55,d0
        blo.s M4SmWebNoWrap
        moveq #0,d0
M4SmWebNoWrap:
        move.b d0,37(a0)
        cmpi.b #$3f,d0
        bne.s M4SmWebNotNet
        tst.b 12(a0)
        bne.s M4SmWebNoNet
        bsr M4SmWebNet
M4SmWebNoNet:
        move.l #M4SmWebB,32(a0)
        bra M4SmWebKeep
M4SmWebNotNet:
        tst.b d0
        beq.s M4SmWebOpen
        move.w #$ca60,d0
        bsr M4SmSetHdr
        moveq #1,d6
        moveq #1,d4
        moveq #6,d5
M4SmWebHold:
        move.w X_ALPTR(a0),d0
        beq M4SmWebKeep
        move.l a0,-(sp)
        movea.w d0,a0
        bsr M4SmLegsFlag
        movea.l (sp)+,a0
        bra M4SmWebKeep
M4SmWebOpen:
        bchg #F2_SFLAG2,48(a0)
        move.b #$32,X_SBYTE3(a0)
        move.w #$ca44,d0
        bsr M4SmSetHdr
        bra M4SmWebKeep
; State B 09:DC17: no net (B1FF finds no CAB4 in allst) -> state C now.
; The net holding the ship (its sflag2): every 4th gameframe animframe + 1
; up to 10; at 10 the body closes in: |pz - body.z| >= 350 -> body.z - 20.
; 09:DC77: rotz offset += sbyte2 (sounds $4F/$50 not ported).
M4SmWebB:
        bsr M4SmFindNet
        beq.s M4SmWebToC
        btst #F2_SFLAG2,48(a2)
        beq.s M4SmWebBAnim
        moveq #3,d0
        and.w M4_LV_GAMEFRAME,d0
        bne.s M4SmWebBAnim
        move.b 16(a0),d0
        addq.b #1,d0
        bmi.s M4SmWebBMod
        addi.b #11,d0
M4SmWebBMod:
        andi.b #$7f,d0
        cmpi.b #11,d0
        blo.s M4SmWebBSet
        moveq #10,d0
M4SmWebBSet:
        ori.b #$80,d0
        move.b d0,16(a0)
M4SmWebBAnim:
        moveq #$7f,d0
        and.b 16(a0),d0
        cmpi.b #10,d0
        bne.s M4SmWebSpinOff
        move.w X_ALPTR(a0),d0
        beq.s M4SmWebSpinOff
        move.l a0,-(sp)
        movea.w d0,a0
        move.w #350,d1
        bsr M4SmNearZ
        bne.s M4SmWebBNear
        subi.w #20,4(a0)
M4SmWebBNear:
        movea.l (sp)+,a0
M4SmWebSpinOff: ;09:DC77
        move.b 37(a0),d0
        add.b d0,X2_CHILDRX+2(a0)
        bra M4SmWebKeep
M4SmWebToC:
        move.l #M4SmWebC,32(a0)
; State C 09:DC9D: animframe != 0 -> animframe - 1 (mod 11), 09:DC77; else
; body.z += 80 and, once |pz - body.z| >= 1200, legs 1..6 pulled back
; (sflags2 $40) and state A now; else 09:DC77.
M4SmWebC:
        moveq #$7f,d0
        and.b 16(a0),d0
        beq.s M4SmWebCBody
        move.b 16(a0),d0
        subq.b #1,d0
        bmi.s M4SmWebCMod
        addi.b #11,d0
M4SmWebCMod:
        andi.b #$7f,d0
        cmpi.b #11,d0
        blo.s M4SmWebCSet
        subi.b #11,d0
M4SmWebCSet:
        ori.b #$80,d0
        move.b d0,16(a0)
        bra.s M4SmWebSpinOff
M4SmWebCBody:
        move.w X_ALPTR(a0),d0
        beq.s M4SmWebSpinOff
        move.l a0,-(sp)
        movea.w d0,a0
        addi.w #$50,4(a0)
        move.w #1200,d1
        bsr M4SmNearZ
        bne.s M4SmWebCNear
        moveq #2,d6
        moveq #1,d4
        moveq #6,d5
        bsr M4SmLegsFlag
        movea.l (sp)+,a0
        move.l #M4SmWebA,32(a0)
        bra M4SmWebA
M4SmWebCNear:
        movea.l (sp)+,a0
        bra.s M4SmWebSpinOff
M4SmWebKeep:
        moveq #0,d0
        rts
; 09:B1FF: the first object of allst with the net header CAB4 -> a2 (Z set
; when none).
M4SmFindNet:
        move.w M4_LV_HEAD,d0
M4SmFindNetNext:
        beq.s M4SmFindNetNone
        movea.w d0,a2
        cmpi.w #$cab4,X_SHAPEHDR(a2)
        beq.s M4SmFindNetFound
        move.w X_NEXT(a2),d0
        bra.s M4SmFindNetNext
M4SmFindNetFound:
        cmpa.w #0,a2
        rts
M4SmFindNetNone:
        suba.l a2,a2
        cmpa.w #0,a2
        rts
; collstrat 09:DC00: shape CA44 (open) -> hitflash 06:89A3; else
; rebelasercol 06:8820 (player lasers bounce off the closed web).
M4SmWebColl:
        cmpi.w #$ca44,X_SHAPEHDR(a0)
        bne.s M4SmWebRebound
        jmp M4LcHitFlash
M4SmWebRebound:
        jmp M4VaRebLaser
; 09:DD38 (body without legs): sbyte2 = 80; 09:DD49: counts down, then the
; web leaves the family (child flag off, out of the body's chain) and stays
; (strategy 09:DD82: nothing).
M4SmWebLoose:
        move.b #$50,37(a0)
        move.l #M4SmWebLooseTick,32(a0)
M4SmWebLooseTick:
        tst.b 37(a0)
        beq.s M4SmWebFree
        subq.b #1,37(a0)
        bra.s M4SmWebKeep
M4SmWebFree:
        movea.l a0,a2
        jsr M4PvDivorce
        move.l #M4SmWebKeep,32(a0)
        bra.s M4SmWebKeep

; The net 09:DD12: object B8F7 behind the web (09:AE35, 1F:D54B) with shape
; CAB4, strategy 09:DD83, the web's rotations and position (1F:DB01, DAD9).
M4SmWebNet:
        move.w #$cab4,d0
        jsr M4LevelShapeIndex
        jsr M4EnCreate
        beq.s M4SmWebNetDone
        move.w #$cab4,X_SHAPEHDR(a2)
        move.l #M4SmNet,32(a2)
        move.b 12(a0),12(a2)
        move.b 13(a0),13(a2)
        move.b 14(a0),14(a2)
        move.l (a0),(a2)
        move.w 4(a0),4(a2)
M4SmWebNetDone:
        rts
; Net 09:DD83: set_normcollptrs, HP $FF, AP 0, nohitaffect, colldisable,
; collflags enemy1, animframe 0|$80, sbyte3 100. 09:DDB9 every tick:
; 09:DF01 contact (|pz - z| < 50 and distXY 0..99: sflag1, sound $51 not
; ported; else sflag1 cleared); |pz - z| < 600: animframe + 1 up to 7;
; addplayerZ; sflag2 set; released (sflags2 $40) or no contact: z - 40,
; sflag2 cleared. Then held (sflag2): 09:DE46; else 09:DE08: x, y step to
; the ship (12 / 6 per tick, no clamp), pshipflags &= ~$40.
M4SmNet:
        move.l #M4SmNetTick,32(a0)
        jsr M4LvNormPtrs
        move.b #$ff,38(a0)
        clr.b 39(a0)
        bset #SF_NOHITAFFECT,49(a0)
        bset #SF_COLLDISABLE,49(a0)
        ori.b #CF_ENEMY1,44(a0)
        move.b #$80,16(a0)
        move.b #100,X_SBYTE3(a0)
M4SmNetTick:
        bclr #F2_SFLAG1,48(a0)
        moveq #50,d1
        bsr M4SmNearZ
        beq.s M4SmNetFar
        movea.l a1,a2
        jsr M4EnDistXY
        tst.w d0
        bmi.s M4SmNetFar
        cmpi.w #100,d0
        bge.s M4SmNetFar
        bset #F2_SFLAG1,48(a0)
M4SmNetFar:
        move.w #600,d1
        bsr M4SmNearZ
        beq.s M4SmNetNoAnim
        move.b 16(a0),d0
        addq.b #1,d0
        bmi.s M4SmNetAMod
        addq.b #8,d0
M4SmNetAMod:
        andi.b #$7f,d0
        cmpi.b #8,d0
        blo.s M4SmNetASet
        moveq #7,d0
M4SmNetASet:
        ori.b #$80,d0
        move.b d0,16(a0)
M4SmNetNoAnim:
        jsr M4EnAddPZ
        bset #F2_SFLAG2,48(a0)
        btst #6,X_SM_FL(a0)
        bne.s M4SmNetBack
        btst #F2_SFLAG1,48(a0)
        bne.s M4SmNetHeld
M4SmNetBack:
        subi.w #40,4(a0)
        bclr #F2_SFLAG2,48(a0)
M4SmNetHeld:
        btst #F2_SFLAG2,48(a0)
        bne.s M4SmNetHold
        moveq #12,d1
        lea 0(a0),a2
        lea 0(a1),a3
        bsr.s M4SmNetStep
        moveq #6,d1
        lea 2(a0),a2
        lea 2(a1),a3
        bsr.s M4SmNetStep
        andi.b #$bf,M4_LP_PSF
        bra M4SmNetEnd
; (a2) steps by d1 toward (a3): equal -> nothing; N((a2) - (a3)) -> +d1.
M4SmNetStep:
        move.w (a2),d0
        cmp.w (a3),d0
        beq.s M4SmNetStepDone
        bmi.s M4SmNetStepUp
        sub.w d1,(a2)
        rts
M4SmNetStepUp:
        add.w d1,(a2)
M4SmNetStepDone:
        rts
; 09:DE46 (held): pshipflags |= $40 (no fire), the ship moves with the net,
; the net drifts to x = y = 0 by 1 per tick, z = ship z + 40. sbyte3 0 ->
; released (sflags2 $40). Else sbyte3 - 1; a new roll (rollZvel != 0 with
; sflags4 $20 clear) sets sflags4 $20 and sbyte4 += 13; no roll clears it;
; a change of the d-pad bits ($15A6 eor $1202) & $0F: sbyte4 + 1. sbyte4
; >= $32 (N clear) -> released.
M4SmNetHold:
        ori.b #$40,M4_LP_PSF
        move.w (a0),(a1)
        move.w 2(a0),2(a1)
        moveq #1,d1
        lea 0(a0),a2
        lea M4SmZero(pc),a3
        bsr.s M4SmNetStep
        lea 2(a0),a2
        bsr.s M4SmNetStep
        move.w 4(a1),d0
        addi.w #40,d0
        move.w d0,4(a0)
        tst.b X_SBYTE3(a0)
        beq.s M4SmNetFree
        subq.b #1,X_SBYTE3(a0)
        tst.b M4_LP_ROLLZVEL
        beq.s M4SmNetNoRoll
        bset #5,X2_FL4(a0)
        bne.s M4SmNetPad
        addi.b #13,X_SBYTE4(a0)
        bra.s M4SmNetCount
M4SmNetNoRoll:
        bclr #5,X2_FL4(a0)
M4SmNetPad:
        move.b M4_LP_LASTJOY,d0
        move.b M4_LP_JOY,d1
        eor.b d1,d0
        andi.b #$0f,d0
        beq.s M4SmNetEnd
        addq.b #1,X_SBYTE4(a0)
M4SmNetCount:
        cmpi.b #$32,X_SBYTE4(a0)
        bmi.s M4SmNetEnd
M4SmNetFree:
        bset #6,X_SM_FL(a0)
M4SmNetEnd:
        bclr #F2_SFLAG1,48(a0)
        moveq #0,d0
        rts
M4SmZero:
        dc.w 0

; ---------------------------------------------------------------------
; Homing asteroid 09:9289 (asteroid2 AF79 sprite, mother script 05:5672):
; ssprite, depthoffset 0, texture 0, set_normcollptrs, HP 2, AP 12; vel =
; rnd & 7, spin sbyte1 = rnd & 3 (negated when roty = rnd >= $80, 0 when a
; fourth rnd >= $7F); v = gen3d(vel, rotx, roty) (09:8276); 09:8009 aims at
; the ship but 09:802A turns it to the camera at once (its stz $1534 of the
; sector mist is not ported); collflags enemy1, nohitaffect. Tick 09:9301:
; x, y = Achase16_4(.., ship), rotz += sbyte1, pos += v.
M4SmHomeRock:
        bset #F2_SPRITE,48(a0)
        clr.b X_DEPTHOFF(a0)
        clr.b X_TX(a0)
        move.l #M4SmHomeRockTick,32(a0)
        jsr M4LvNormPtrs
        move.b #2,38(a0)
        move.b #12,39(a0)
        jsr M4IntroRandom
        andi.b #7,d0
        move.b d0,15(a0)
        jsr M4IntroRandom
        andi.b #3,d0
        move.b d0,36(a0)
        jsr M4IntroRandom
        move.b d0,13(a0)
        bpl.s M4SmHomeSign
        neg.b 36(a0)
M4SmHomeSign:
        jsr M4IntroRandom
        cmpi.b #$7f,d0
        blo.s M4SmHomeSpin
        clr.b 36(a0)
M4SmHomeSpin:
        jsr M4EnGen3d
        jsr M4EnFaceCamera
        ori.b #CF_ENEMY1,44(a0)
        bset #SF_NOHITAFFECT,49(a0)
M4SmHomeRockTick:
        moveq #4,d2
        move.w (a0),d0
        move.w (a1),d1
        jsr M4LpAchase
        move.w d0,(a0)
        move.w 2(a0),d0
        move.w 2(a1),d1
        jsr M4LpAchase
        move.w d0,2(a0)
        move.b 36(a0),d0
        add.b d0,14(a0)
        jsr M4EnMove
        moveq #0,d0
        rts

; ---------------------------------------------------------------------
; Path support of the Out of This Dimension entry (proposed hooks in
; level_paths.asm, build/agent-spacemisc/INTEGRATION.md section 1). Asteroid
; 3 big_meteor path 0176 -> B059 (01D0) -> bird BC60 (01F4); touching it
; (withinrange 40) runs .bird_touch 04:A67D: exportb $F0D6 = 1, exportb
; levelfinished $1FD4 = 16 (le_enterspec), exportb nosetport3 $1FD1 = 1,
; then the inline 65816 at path offset $0297 (04:A695).
; In: a0 object, a4 path command, 42(a0) path pc. Out: Z set when handled.
M4SmPv65:
        cmpi.w #$0297,42(a0)
        bne.s M4SmPv65No
        bclr #1,M4_LP_PSF3 ;psf3_enginesnd off
        bset #3,M4_LP_PSF3 ;psf3_nocollisions
        move.w #M4RouteChange1,M4_GS_ROUTES ;routechange1 03:D0C2: routes[0] and 7E:F0CC
        move.b #(M4RouteChange1&$ff),M4_PV_GLOB+$1c
        move.b #(M4RouteChange1>>8),M4_PV_GLOB+$1d
        move.w #$02c0,42(a0) ;m_clrbitmaps 70:01B2 = 0 and startbgm 2: no port equivalent
        moveq #0,d0
M4SmPv65No:
        rts
; exportb [alvar][var.w] to levelfinished $1FD4 (the gamestart dispatch, as
; the map's setvar) or nosetport3 $1FD1 (written only: its reader 02:E3xx
; is not ported). Z set when handled (path pc += 4).
M4SmPvExport:
        move.b 3(a4),d0
        lsl.w #8,d0
        move.b 2(a4),d0
        cmpi.w #$1fd4,d0
        beq.s M4SmPvExpFin
        cmpi.w #$1fd1,d0
        bne.s M4SmPvExpNo
        move.b 1(a4),d0
        jsr M4PvAlvar
        move.b (a2),M4_SM_NOSETPORT3
        bra.s M4SmPvExpDone
M4SmPvExpFin:
        move.b 1(a4),d0
        jsr M4PvAlvar
        move.b (a2),d0
        bsr M4SmLevelFinished
M4SmPvExpDone:
        addq.w #4,42(a0)
        moveq #0,d0
M4SmPvExpNo:
        rts

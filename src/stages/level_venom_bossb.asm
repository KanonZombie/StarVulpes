; Venom 1 unit (bossb): code. Included from level_venom.asm. Documentation:
; build/agent-venom/bossb/BOSSB.md (Spanish). Field conventions: level_objects.asm.
; Orbital boss bossB (07:AAD1, shape boss_b_1 00:C7A4, created by the map at
; 05:E6D3), its images (ents 07:B586), its decoys (spinend clones 07:B234),
; hitflashBOSSd 06:891B and the escape (expstrat 07:B4C6). ROM USA rev0
; (SHA-256 3857b529...a84d), bytes traced with build/research/strat_trace.py;
; UltraStarFox GB3STRAT.ASM 1252..1845 only for names. Oracle and comparison:
; build/agent-venom/bossb/bossb-oracle.py.
; Field mapping (ROM -> port): sbyte1..4 $22..$25 -> 36, 37, X_SBYTE3,
; X_SBYTE4; sword1+1 $27 (formation group 0..3) -> 40 (high byte of the
; sword1 WORD); sword2 $28 (BYTE use) -> X_SWORD2+1; lifecnt $0A -> 19;
; depthoffset $1CDF -> X_DEPTHOFF; al_ptr $06 -> X_ALPTR. sflags2 $10 sflag1
; (make images) -> F2_SFLAG1; $20 sflag2 (images are decoys) -> F2_SFLAG2;
; $40 sflag3 (decoys vanish) -> X_WFLAGS bit0 (as weapons/meteor boss);
; $80 sflag4 (image every other tick) -> X_WFLAGS bit7; sflags3 $01 sflag5
; (set by the scream, never read here) -> X_WFLAGS bit1. Route: no bossB
; routine reads $1FFF/$16DA; only doelaserspeed inside M4EnFire does.
; Not modelled: sounds ($2D, $2C, $2B, $81, $80, $24 and the hitflash
; distance sounds).
M4_VB equ $ff9f20
M4_VB_GSV1 equ M4_VB+0 ;.b gsvar_byte1 $1551: decoys shot in this cycle
M4_VB_YOBJ equ M4_VB+2 ;.l 65816 Y left by 06:891B (explosion) for spin1
M4VbShBody equ M4_SH_BOSS_B_1 ;boss_b_1 00:C7A4 (body, images, decoys)
VB_SF3 equ 0 ;X_WFLAGS bits
VB_SF5 equ 1
VB_SF4 equ 7

; ---------------------------------------------------------------------
; Istrat 07:AAD1: HP 40 / AP 16, m_bossmaxHP 40, m_bossHP 0; strategy
; AB3B, collstrat hitflashBOSSd 06:891B, expstrat escape 07:B4C6; colltype
; enemy2 | enemyweap ($2E |= $60); rotx $C0, roty $40, vel 40, depthoffset
; 1 (nodepthcue); sflag1 on, sflag2 off, nohitaffect. Falls into AB3B.
M4StratBossB:
        move.b #40,38(a0)
        move.b #16,39(a0)
        move.b #40,M4_BOSS_MAXHP
        clr.b M4_BOSS_HP
        move.l #M4VbApproach,32(a0)
        move.l #M4VbHitBoss,X_COLL(a0)
        move.l #M4VbEscapeI,X_EXP(a0)
        ori.b #$60,44(a0)
        move.b #$c0,12(a0)
        move.b #$40,13(a0)
        move.b #40,15(a0)
        move.b #1,X_DEPTHOFF(a0)
        bset #F2_SFLAG1,48(a0)
        bclr #F2_SFLAG2,48(a0)
        bset #SF_NOHITAFFECT,49(a0)
; bossB_strat 07:AB3B: rotx/roty toward the player (obj2obj_3dangle, step
; 2^4); |pz - z| < 2500: speedto(0, 1), already 0 -> dodge (AC89); else
; (AB F0) v = gen3d(vel), pos += v; bossB_cont.
M4VbApproach:
        movea.l a1,a2
        moveq #4,d2
        bsr M4VbFaceObj
        movea.l a1,a2
        jsr M4EnZD
        subi.w #2500,d0
        bpl.s M4VbApproachMove
        moveq #0,d0
        jsr M4MtSpeedToC
        tst.w d3
        bne M4VbDodgeInit
M4VbApproachMove:
        jsr M4EnGen3d
        jsr M4EnMove
; bossB_cont 07:AC06: with sflag1, sflag4 toggles; when it turns off, an
; image boss_b_1 behind the boss (1F:D54B), al_ptr = boss: with sflag2 a
; decoy (B234, its group $27 = the boss's, boss $27 + 1 & 3), else an ent
; (B586); position and rotations copied. A full pool skips it.
M4VbCont:
        btst #F2_SFLAG1,48(a0)
        beq.s M4VbCont2
        bchg #VB_SF4,X_WFLAGS(a0)
        beq.s M4VbCont2 ;was clear (Z): now set, no image
        move.w #M4VbShBody,d0
        jsr M4EnCreate
        beq.s M4VbCont2
M4VbImgMade: ;a2 = new image (hook point of bossb-oracle.py)
        move.w #$c7a4,X_SHAPEHDR(a2)
        move.w a0,X_ALPTR(a2)
        move.l #M4VbEntI,32(a2)
        btst #F2_SFLAG2,48(a0)
        beq.s M4VbImgPlace
        move.l #M4VbCloneI,32(a2)
        move.b 40(a0),40(a2)
        move.b 40(a0),d0
        addq.b #1,d0
        andi.b #3,d0
        move.b d0,40(a0)
M4VbImgPlace:
        move.l (a0),(a2) ;1F:DAD9
        move.w 4(a0),4(a2)
        move.w 12(a0),12(a2) ;1F:DB01
        move.b 14(a0),14(a2)
; bossB_cont2 07:AC75: m_bossHP += HP (8 bits: decoys add $FF).
M4VbCont2:
        move.b 38(a0),d0
        add.b d0,M4_BOSS_HP
; bossB_cont4 07:AC80: keeprelto_player 1F:DB21 (z += $14EC - $14F6),
; addplayerZ 1F:DC69.
M4VbCont4:
        move.w 10(a1),d0
        sub.w M4_LP_PVIEWVZ,d0
        add.w d0,4(a0)
        jsr M4EnAddPZ
        clr.l M4_VB_YOBJ
        moveq #0,d0
        rts

; ---------------------------------------------------------------------
; dodge init 07:AC89: sbyte3 1, collstrat AEC7, nohitaffect off.
M4VbDodgeInit:
        move.l #M4VbDodge,32(a0)
        move.b #1,X_SBYTE3(a0)
        move.l #M4VbDodgeColl,X_COLL(a0)
        bclr #SF_NOHITAFFECT,49(a0)
; bossBdodge_strat 07:ACB1. HP < 16 -> spin1. --sbyte3 == 0: sbyte3 1,
; quadrant q = 4*((x < 0) + 2*N(y - (-60))) of player_pos $150F/$1511;
; a new q: sbyte1 = q, sbyte2 = 0 or 16 (random_l >= $CC). Target = table
; 07:AECF[sbyte1 + sbyte2]; x, y Achase16_3 toward it. |dx|+|dy| < 300 ->
; face the player (AD8C); else sflag1, sbyte3 25, turn toward it (B5D5)
; and every 8 ticks a HMISSILE1 aimed at the player (AE86).
M4VbDodge:
        cmpi.b #16,38(a0)
        bmi M4VbSpin1Init
        subq.b #1,X_SBYTE3(a0)
        bne.s M4VbDodgeSame
        move.b #1,X_SBYTE3(a0)
        moveq #0,d1
        tst.b M4_SC_PPOSX
        bpl.s M4VbDodgeRight
        moveq #1,d1
M4VbDodgeRight:
        move.w M4_SC_PPOSY,d0
        addi.w #60,d0 ;sbc #$FFC4 (space_viewCY)
        bpl.s M4VbDodgeDown
        addq.b #2,d1
M4VbDodgeDown:
        lsl.b #2,d1
        cmp.b 36(a0),d1
        beq.s M4VbDodgeSame
        move.b d1,36(a0)
        clr.b 37(a0)
        jsr M4IntroRandom
        cmpi.b #$cc,d0
        blo.s M4VbDodgeSame
        move.b #16,37(a0)
M4VbDodgeSame:
        move.b 36(a0),d1
        add.b 37(a0),d1
        bsr M4VbGoto
        bmi.s M4VbDodgeFace
        bset #F2_SFLAG1,48(a0)
        move.b #25,X_SBYTE3(a0)
        bsr M4VbPointDir
        move.w M4_LV_GAMEFRAME,d0
        andi.w #7,d0
        bne M4VbCont
        moveq #M4_WT_HMISSILE1,d0
        moveq #0,d6
        moveq #0,d7
        movea.l a1,a3
        bsr M4VbFire
        beq M4VbCont
        move.w a1,X_ALPTR(a2)
        bra M4VbCont
; .faceplayer 07:AD8C: sflag1 off; turn toward the player (step 2^2); both
; angles there and gameframe even: RelSlowElaser with (rnd&3)-1 added to
; rotx and roty.
M4VbDodgeFace:
        bclr #F2_SFLAG1,48(a0)
        movea.l a1,a2
        moveq #2,d2
        bsr M4VbFaceObj
        cmpi.w #2,d4
        bne M4VbCont
        btst #0,M4_LV_GAMEFRAME+1
        bne M4VbCont
        moveq #3,d2
        moveq #1,d3
        bsr M4VbRndRot
        moveq #M4_WT_RSE,d0
        suba.l a3,a3
        bsr M4VbFire
        bra M4VbCont
; bossBdodgecol 07:AEC7: sbyte3 1 (new decision next tick), hitflashBOSSd.
M4VbDodgeColl:
        move.b #1,X_SBYTE3(a0)
; hitflashBOSSd_Istrat 06:891B: unless nohitaffect, a medium explosion at
; the collider (06:EEEE -> EF1B, created with X = the collider: linked
; behind it), nopolyexp ($1F |= $40); then hitflash 06:89A3. The 65816 Y
; register stays on that explosion for the strategy (read by spin1 AF86).
; A wall/ground collider (0) would make it at object 0: skipped [D].
M4VbHitBoss:
        btst #SF_NOHITAFFECT,49(a0)
        bne.s M4VbHitFlash
        movem.l a0/a2,-(sp)
        jsr M4LcCollider
        move.l a2,d0
        beq.s M4VbHitNone
        move.l M4_LV_CREATOR,-(sp)
        move.l a2,M4_LV_CREATOR
        movea.l a2,a0
        jsr M4FxMedium
        move.l (sp)+,M4_LV_CREATOR
        cmpa.w #0,a2
        beq.s M4VbHitNone
        bset #F2_NOPOLYEXP,48(a2)
        move.l a2,M4_VB_YOBJ
M4VbHitNone:
        movem.l (sp)+,a0/a2
M4VbHitFlash:
        jmp M4LcHitFlash

; ---------------------------------------------------------------------
; spin1 init 07:AF4F: sflag1 on, collstrat hitflashBOSSd.
M4VbSpin1Init:
        move.l #M4VbSpin1,32(a0)
        bset #F2_SFLAG1,48(a0)
        move.l #M4VbHitBoss,X_COLL(a0)
; bossBspin1_strat 07:AF73: x Achase16_3 -> 0; the y of the object in the
; 65816 Y register (the boss, or the explosion of a hit this tick) Achase16_3
; -> 40; roty Achase8_2 -> $40, rotx Achase8_2 -> 0; |0-x|+|40-y| < 300 ->
; spin2 (AFD9), else bossB_cont.
M4VbSpin1:
        move.w (a0),d0
        moveq #0,d1
        moveq #3,d2
        jsr M4LpAchase
        move.w d0,(a0)
        move.l M4_VB_YOBJ,d0
        bne.s M4VbSpin1Y
        move.l a0,d0
M4VbSpin1Y:
        movea.l d0,a2
        move.w 2(a2),d0
        moveq #40,d1
        jsr M4LpAchase
        move.w d0,2(a2)
        move.b 13(a0),d0
        moveq #$40,d1
        moveq #2,d2
        jsr M4EnChase8
        move.b d0,13(a0)
        move.b 12(a0),d0
        moveq #0,d1
        jsr M4EnChase8
        move.b d0,12(a0)
        moveq #0,d0
        moveq #40,d1
        bsr M4VbRange
        bpl M4VbCont
; spin2 init 07:AFD9: sbyte3 0, roty $40, rotx 0, nohitaffect, sflag4 off.
        move.l #M4VbSpin2,32(a0)
        clr.b X_SBYTE3(a0)
        move.w #$0040,12(a0)
        bset #SF_NOHITAFFECT,49(a0)
        bclr #VB_SF4,X_WFLAGS(a0)
; bossBspin2_strat 07:AFFE: speedto(120, 2): already 120 -> sflag2 (images
; become decoys), else sbyte1 5; rotx - 16; v = 2*gen3d(vel) (1F:D5BC),
; pos += v; sbyte1 == 0 -> spinend2 (B055), else sbyte1 - 1, bossB_cont.
M4VbSpin2:
        moveq #120,d0
        cmp.b 15(a0),d0
        bne.s M4VbSpin2Accel
        bset #F2_SFLAG2,48(a0)
        bra.s M4VbSpin2Turn
M4VbSpin2Accel:
        moveq #2,d1
        jsr M4EnSpeedTo
        move.b #5,36(a0)
M4VbSpin2Turn:
        subi.b #16,12(a0)
        jsr M4EnGen3d
        asl.w 6(a0)
        asl.w 8(a0)
        asl.w 10(a0)
        jsr M4EnMove
        tst.b 36(a0)
        beq.s M4VbSpinEnd2Init
        subq.b #1,36(a0)
        bra M4VbCont

; ---------------------------------------------------------------------
; spinend2 init 07:B055: HP 30, m_bossmaxHP 30, m_bossHP 0; collstrat
; hitflashBOSSd (B4AB); nohitaffect off; sbyte4 0; sword2 = HP; v = vel =
; 0 (1F:DB45); al_ptr = itself; gsvar_byte1 0; then the decoy code B266
; (sbyte3 1, depthoffset 1) and B26F on itself.
M4VbSpinEnd2Init:
        move.b #30,38(a0)
        move.b #30,M4_BOSS_MAXHP
        clr.b M4_BOSS_HP
        move.l #M4VbSpinEnd2,32(a0)
        move.l #M4VbHitBoss,X_COLL(a0)
        bclr #SF_NOHITAFFECT,49(a0)
        clr.b X_SBYTE4(a0)
        move.b 38(a0),X_SWORD2+1(a0)
        clr.l 6(a0)
        clr.w 10(a0)
        clr.b 15(a0)
        move.w a0,X_ALPTR(a0)
        clr.b M4_VB_GSV1
        bra M4VbCloneIcont
; bossBspinend2_strat 07:B09E: |sword2 - HP| >= 6 (8 bits) -> scream (B133,
; next tick); sword2 = HP. gsvar_byte1 == 2: 0 and new cycle (B4AF).
; --sbyte3 == 0: sbyte3 30, sbyte1 = (rnd & 7) * 4 (new slot). sbyte4 == 0
; -> B2BB; else --sbyte4 > 3: sflag3 (decoys vanish), B2BB; <= 3: sflag3
; off, (== 3: sbyte3 1) and bossB_cont (decoys are made).
M4VbSpinEnd2:
        move.b X_SWORD2+1(a0),d0
        sub.b 38(a0),d0
        bpl.s M4VbSe2Abs
        neg.b d0
M4VbSe2Abs:
        cmpi.b #6,d0
        bmi.s M4VbSe2Calm
        move.l #M4VbScreamI,32(a0)
M4VbSe2Calm:
        move.b 38(a0),X_SWORD2+1(a0)
        cmpi.b #2,M4_VB_GSV1
        bne.s M4VbSe2Timer
        clr.b M4_VB_GSV1
        bsr M4VbNewCycle
M4VbSe2Timer:
        subq.b #1,X_SBYTE3(a0)
        bne.s M4VbSe2Count
        move.b #30,X_SBYTE3(a0)
        cmpi.b #2,M4_VB_GSV1
        bne.s M4VbSe2Slot
        move.b #15,X_SBYTE3(a0)
M4VbSe2Slot:
        jsr M4IntroRandom
        andi.b #7,d0
        lsl.b #2,d0
        move.b d0,36(a0)
M4VbSe2Count:
        tst.b X_SBYTE4(a0)
        beq M4VbSpinEndCont
        subq.b #1,X_SBYTE4(a0)
        cmpi.b #3,X_SBYTE4(a0)
        beq.s M4VbSe2Make
        bmi.s M4VbSe2Make
        bset #VB_SF3,X_WFLAGS(a0)
        bra M4VbSpinEndCont
M4VbSe2Make:
        bclr #VB_SF3,X_WFLAGS(a0)
        cmpi.b #3,X_SBYTE4(a0)
        bne M4VbCont
        move.b #1,X_SBYTE3(a0)
        bra M4VbCont
; bossBspinendnewent_srou 07:B4AF: sbyte4 14, sflag4 off, sbyte3 1, $27 =
; rnd & 3.
M4VbNewCycle:
        move.b #14,X_SBYTE4(a0)
        bclr #VB_SF4,X_WFLAGS(a0)
        move.b #1,X_SBYTE3(a0)
        jsr M4IntroRandom
        andi.b #3,d0
        move.b d0,40(a0)
        rts

; scream Istrat 07:B133: sbyte1 30, nohitaffect, sflag5.
M4VbScreamI:
        move.l #M4VbScream,32(a0)
        move.b #30,36(a0)
        bset #SF_NOHITAFFECT,49(a0)
        bset #VB_SF5,X_WFLAGS(a0)
; bossBscream_strat 07:B150: sbyte1 == 0 -> scream2 (B19D); sbyte1 - 1;
; roty Achase8_2 -> $80, rotx -> 0; x Achase16_2 -> 0, y -> 40; sflag3;
; bossB_cont2.
M4VbScream:
        tst.b 36(a0)
        beq.s M4VbScream2Init
        subq.b #1,36(a0)
        move.b 13(a0),d0
        move.b #$80,d1
        moveq #2,d2
        jsr M4EnChase8
        move.b d0,13(a0)
        move.b 12(a0),d0
        moveq #0,d1
        jsr M4EnChase8
        move.b d0,12(a0)
        move.w (a0),d0
        moveq #0,d1
        jsr M4LpAchase
        move.w d0,(a0)
        move.w 2(a0),d0
        moveq #40,d1
        jsr M4LpAchase
        move.w d0,2(a0)
        bset #VB_SF3,X_WFLAGS(a0)
        bra M4VbCont2
; scream2 07:B19D/B1AE: sbyte1 93; each tick: 0 -> end (B20F); sbyte1 - 1;
; at 66 a chickhmissile1 ($18) aimed at the player, al_ptr = player; roty =
; $80 + (rnd & 15) - 7; bossB_cont2.
M4VbScream2Init:
        move.l #M4VbScream2,32(a0)
        move.b #93,36(a0)
M4VbScream2:
        tst.b 36(a0)
        beq.s M4VbScreamEnd
        subq.b #1,36(a0)
        cmpi.b #66,36(a0)
        bne.s M4VbScream2Shake
        moveq #M4_WT_CHICK,d0
        moveq #0,d6
        moveq #0,d7
        movea.l a1,a3
        bsr M4VbFire
        beq.s M4VbScream2Shake
        move.w a1,X_ALPTR(a2)
M4VbScream2Shake:
        jsr M4IntroRandom
        andi.b #15,d0
        addi.b #$80-7,d0
        move.b d0,13(a0)
        bra M4VbCont2
; 07:B20F: back to spinend2 (sbyte4 14, sbyte3 1, sflag4 and nohitaffect
; off), run at once (1F:DC25).
M4VbScreamEnd:
        move.l #M4VbSpinEnd2,32(a0)
        move.b #14,X_SBYTE4(a0)
        move.b #1,X_SBYTE3(a0)
        bclr #VB_SF4,X_WFLAGS(a0)
        bclr #SF_NOHITAFFECT,49(a0)
        bra M4VbSpinEnd2

; ---------------------------------------------------------------------
; Decoys (and the boss in spinend2, al_ptr = itself). Istrat 07:B234:
; collstrat B4A4, HP $FF / AP 0, colltype enemy2 | enemyweap; B266: sbyte3
; 1, depthoffset 1.
M4VbCloneI:
        move.l #M4VbClone,32(a0)
        move.l #M4VbCloneColl,X_COLL(a0)
        move.b #$ff,38(a0)
        clr.b 39(a0)
        ori.b #$60,44(a0)
M4VbCloneIcont: ;B266 (also the boss from B055: its strategy stays B09E)
        move.b #1,X_SBYTE3(a0)
        move.b #1,X_DEPTHOFF(a0)
M4VbClone:
; bossBspinend_strat 07:B26F: y = al_ptr; y.sflag3 -> become an ent (next
; tick); gsvar_byte1 == 2 and gameframe & 15 == 0: $27 + 1 & 3 until it
; differs from y.$27. al_ptr 0 reads object 0 in the ROM: not modelled.
        move.w X_ALPTR(a0),d0
        beq M4VbCont2
        movea.w d0,a2
        btst #VB_SF3,X_WFLAGS(a2)
        beq.s M4VbCloneShift
        move.l #M4VbEntI,32(a0)
M4VbCloneShift:
        cmpi.b #2,M4_VB_GSV1
        bne.s M4VbSpinEndCont
        move.w M4_LV_GAMEFRAME,d0
        andi.w #15,d0
        bne.s M4VbSpinEndCont
M4VbCloneShiftLoop:
        move.b 40(a0),d0
        addq.b #1,d0
        andi.b #3,d0
        move.b d0,40(a0)
        cmp.b 40(a2),d0
        beq.s M4VbCloneShiftLoop
; bossBspinend_cont 07:B2BB: slot = al_ptr.sbyte1 + ($27 << 5); x, y
; Achase16_3 toward table 07:AECF[slot]; |dx|+|dy| < 300 -> face the player
; (B3AD); else turn toward the slot (B5D5) and, while (gameframe & 63) <
; 31, every 8 ticks of (gameframe + al1pt) a HMISSILE1 with (rnd&7)-3 on
; rotx/roty, no target, al_ptr = player. bossB_cont2.
M4VbSpinEndCont:
        move.w X_ALPTR(a0),d0
        beq M4VbCont2
        movea.w d0,a2
        move.b 40(a0),d1
        lsl.b #5,d1
        add.b 36(a2),d1
        bsr M4VbGoto
        bmi.s M4VbSpinEndFace
        bsr M4VbPointDir
        move.w M4_LV_GAMEFRAME,d0
        andi.w #63,d0
        cmpi.w #31,d0
        bpl M4VbCont2
        bsr M4VbAl1pt
        add.w M4_LV_GAMEFRAME,d1
        andi.w #7,d1
        bne M4VbCont2
        moveq #7,d2
        moveq #3,d3
        bsr M4VbRndRot
        moveq #M4_WT_HMISSILE1,d0
        suba.l a3,a3
        bsr M4VbFire
        beq M4VbCont2
        move.w a1,X_ALPTR(a2)
        bra M4VbCont2
; .faceplayer 07:B3AD: turn toward the player (step 2^1); both angles there
; and (gameframe & 63) >= 31 and (gameframe + al1pt) & 3 == 0:
; RelSlowElaserHome ($0A) with (rnd&7)-3 on rotx/roty, no target.
M4VbSpinEndFace:
        movea.l a1,a2
        moveq #1,d2
        bsr M4VbFaceObj
        cmpi.w #2,d4
        bne M4VbCont2
        move.w M4_LV_GAMEFRAME,d0
        andi.w #63,d0
        cmpi.w #31,d0
        bmi M4VbCont2
        bsr M4VbAl1pt
        add.w M4_LV_GAMEFRAME,d1
        andi.w #3,d1
        bne M4VbCont2
        moveq #7,d2
        moveq #3,d3
        bsr M4VbRndRot
        moveq #M4_WT_RSEH,d0
        suba.l a3,a3
        bsr M4VbFire
        bra M4VbCont2
; bossBspinendentcol 07:B4A4: gsvar_byte1 + 1, become an ent at once. It
; leaves collide set (the next collision pass turns it into Lcollide).
M4VbCloneColl:
        addq.b #1,M4_VB_GSV1
; Ent (fading image) Istrat 07:B586: lifecnt 8, colldisable, depthoffset 1.
M4VbEntI:
        move.b #8,19(a0)
        bset #SF_COLLDISABLE,49(a0)
        move.l #M4VbEnt,32(a0)
        move.b #1,X_DEPTHOFF(a0)
; bossBent_strat 07:B5A2: (gameframe + al1pt) & 7 == 0: depthoffset + 1;
; --lifecnt == 0: removed (deferred, 1F:D501); addplayerZ, keeprelto_player,
; z + 1.
M4VbEnt:
        moveq #0,d7
        bsr M4VbAl1pt
        add.w M4_LV_GAMEFRAME,d1
        andi.w #7,d1
        bne.s M4VbEntLife
        addq.b #1,X_DEPTHOFF(a0)
M4VbEntLife:
        subq.b #1,19(a0)
        bne.s M4VbEntMove
        moveq #1,d7
M4VbEntMove:
        jsr M4EnAddPZ
        move.w 10(a1),d0
        sub.w M4_LP_PVIEWVZ,d0
        add.w d0,4(a0)
        addq.w #1,4(a0)
        move.l d7,d0
        rts

; ---------------------------------------------------------------------
; Escape: expstrat 07:B4C6 at HP 0: expstrat B4F3 from now on; vel 0;
; sflag3 (decoys vanish); lifecnt 60; gameflags |= bossdead ($04).
M4VbEscapeI:
        move.l #M4VbEscape,X_EXP(a0)
        clr.b 15(a0)
        bset #VB_SF3,X_WFLAGS(a0)
        move.b #60,19(a0)
        ori.b #4,M4_LP_GAMEFLAGS
; 07:B4F3: speedto(100, 1); |pz - z| >= 3000 and rotx != $40: rotx + 1,
; --lifecnt == 0 -> removed (deferred); else roty Achase8_4 -> 0, rotx
; Achase8_3 -> 0. v = gen3d(vel), pos += v; bossB_cont4 (no m_bossHP).
M4VbEscape:
        moveq #0,d7
        moveq #100,d0
        moveq #1,d1
        jsr M4EnSpeedTo
        movea.l a1,a2
        jsr M4EnZD
        subi.w #3000,d0
        bmi.s M4VbEscapeDown
        cmpi.b #$40,12(a0)
        beq.s M4VbEscapeDown
        addq.b #1,12(a0)
        subq.b #1,19(a0)
        bne.s M4VbEscapeMove
        moveq #1,d7
        bra.s M4VbEscapeMove
M4VbEscapeDown:
        move.b 13(a0),d0
        moveq #0,d1
        moveq #4,d2
        jsr M4EnChase8
        move.b d0,13(a0)
        move.b 12(a0),d0
        moveq #3,d2
        jsr M4EnChase8
        move.b d0,12(a0)
M4VbEscapeMove:
        jsr M4EnGen3d
        jsr M4EnMove
        bsr M4VbCont4
        move.l d7,d0
        rts

; ---------------------------------------------------------------------
; Helpers (a0 = object, a1 = player).

; obj2obj_3dangle toward a2 (1F:D03E pitch, 1F:D021 yaw), Achase8 step
; 2^d2 on rotx then roty. d4 = number of angles already there (0..2).
M4VbFaceObj:
        movem.l d0-d3,-(sp)
        moveq #0,d4
        jsr M4EnPitchTo
        move.b d0,d1
        move.b 12(a0),d0
        jsr M4EnChase8
        move.b d0,12(a0)
        add.w d3,d4
        jsr M4EnYawTo
        move.b d0,d1
        move.b 13(a0),d0
        jsr M4EnChase8
        move.b d0,13(a0)
        add.w d3,d4
        movem.l (sp)+,d0-d3
        rts

; d1.b = byte index into the formation table 07:AECF -> d0/d1 = target x/y
; (svar_word1/2); x, y Achase16_3 toward it; d0 = |tx - x| + |ty - y|
; (bossBrange 1F:CFC2, 16 bits); N set when < 300. X_WPX/Y = target.
M4VbGoto:
        movem.l d2-d3/a2,-(sp)
        andi.w #$ff,d1
        lea M4VbPosTab,a2
        adda.w d1,a2
        move.b 1(a2),d3
        lsl.w #8,d3
        move.b (a2),d3
        move.b 3(a2),d1
        lsl.w #8,d1
        move.b 2(a2),d1
        move.w d3,X_WPX(a0)
        move.w d1,X_WPY(a0)
        move.w (a0),d0
        exg d1,d3
        moveq #3,d2
        jsr M4LpAchase
        move.w d0,(a0)
        move.w 2(a0),d0
        move.w d3,d1
        jsr M4LpAchase
        move.w d0,2(a0)
        move.w X_WPX(a0),d0
        move.w X_WPY(a0),d1
        bsr M4VbRange
        movem.l (sp)+,d2-d3/a2
        rts
; d0/d1 = target x/y -> d0 = |d0 - x| + |d1 - y| - 300 (16 bits, N = less).
M4VbRange:
        sub.w (a0),d0
        bpl.s M4VbRangeX
        neg.w d0
M4VbRangeX:
        sub.w 2(a0),d1
        bpl.s M4VbRangeY
        neg.w d1
M4VbRangeY:
        add.w d1,d0
        subi.w #300,d0
        rts
; bossBpointdir 07:B5D5: sWP = (X_WPX, X_WPY, z); roty Achase8_2 toward
; the yaw of 1F:CF43, rotx Achase8_2 toward the pitch of 1F:D05C.
M4VbPointDir:
        movem.l d0-d3,-(sp)
        move.w 4(a0),X_WPZ(a0)
        jsr M4EnWayAngles
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
        movem.l (sp)+,d0-d3
        rts
; s_weapon_rndrot: d6 = (rnd & d2) - d3 (rotx add), d7 = (rnd & d2) - d3.
M4VbRndRot:
        jsr M4IntroRandom
        and.b d2,d0
        sub.b d3,d0
        move.b d0,d6
        jsr M4IntroRandom
        and.b d2,d0
        sub.b d3,d0
        move.b d0,d7
        rts
; fire_weapon from the object (offset 0): d0 type, d6/d7 rot adds, a3
; target or 0 -> a2 (Z set on failure).
M4VbFire:
        moveq #0,d3
        moveq #0,d4
        moveq #0,d5
        jsr M4EnFire
        cmpa.w #0,a2
        rts
; d1.w = low byte of the original-like record address (al1pt $123C).
M4VbAl1pt:
        jsr M4B1Al1pt
        andi.w #$ff,d1
        rts

; 07:AECF bossbpos_tab, as ROM BYTES (little-endian WORD pairs x, y): 4 groups
; ($27) x 8 slots; slots 0..3 at 140 %, 4..7 at 70 % of the space limits,
; around (0,-400), (-400,0), (400,0), (0,400). The index is an 8-bit sum
; sbyte1 + $27*32 and the scream counters (odd, up to 93) also feed it: the
; ROM then reads misaligned words and the code bytes after the table
; (07:AF4F..). The 260 bytes 07:AECF..AFD2 are kept (checked by the oracle).
M4VbPosTab:
        incbin '../build/M4VbPosTab.bin'
        even

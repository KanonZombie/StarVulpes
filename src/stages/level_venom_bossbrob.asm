; Venom 1 unit (bossbrob): code. Included from level_venom.asm. Documentation:
; build/agent-venom/bossbrob/ (Spanish). Field conventions: level_objects.asm.
;
; bossBrob 07:B848 (Venom 1 planet boss "Phantron"), USA rev0 bytes read with
; tools/dis65816.py / build/research/strat_trace.py (trace in
; build/agent-venom/bossbrob/work/bossbrob_trace.txt). Every label that is an
; original entry point ends with its bank-07 address (_AAAA); 06:891B is
; M4VrHitFlashD. Sounds (03:B7E5) and music ($1F49) are not ported.
; Original -> port fields: x/y/z 0/2/4, v ($2F/$31/$33) 6/8/10, rot 12..14,
; vel 15, animframe ($1CE7) 16, count ($0A) 19, hitflags ($35) 20, sbyte1/2
; ($22/$23) 36/37, HP/AP 38/39, sword1 ($26) 40.w (its BYTE $26 = 41),
; sword2 X_SWORD2, sbyte3 X_SBYTE3, sbyte4 X_SBYTE4, al_ptr X_ALPTR,
; collobj ($1B) 62, al_type ($09) 45, colltype ($2E) 44, al_flags ($08) 51,
; stratstate ($1CDC) X_STATE, depthoffset ($1CDF) X_DEPTHOFF.
; Flags: $1E $01 colldisable 49.0, $10 sflag1 F2_SFLAG1, $20 sflag2 F2_SFLAG2,
; $40 sflag3 X_VRFL.6, $80 sflag4 X_VRFL.7; $1F $01 sflag5 X_VRFL.0, $20
; nohitaffect 49.5, $40 nopolyexp F2_NOPOLYEXP; $1D $80 collide 49.3, $08
; shadow F2_SHADOW, $02 hitflash 49.7 (+31.2).
; al1pt (lo8 of the object record, read by (gameframe + al1pt) tests): kept
; per object in X_VRPH, set at creation by M4VrSetPhase = lo8($0336 +
; slot*$36), the 54-byte record pool of 02:F4BB (decision shared with
; M4B1Al1pt; the real value depends on the ROM free list).
X_VRFL equ -$8000+48 ;.b bit6 sflag3, bit7 sflag4 ($1E), bit0 sflag5 ($1F)
X_VRPH equ -$8000+49 ;.b al1pt phase
M4_VR equ $ff9f40 ;unit RAM $FF9F40..$FF9F5F (reserved, unused)
M4VrShB1 equ M4_SH_BOSS_B_1 ;00:C7A4 boss_b_1 (map, images)
M4VrShB0 equ M4_SH_BOSS_B_0 ;00:C788 boss_b_0 (legs)
M4VrShB6 equ M4_SH_BOSS_B_6 ;00:D7D4 boss_b_6 (kick)
M4VrShB7 equ M4_SH_BOSS_B_7 ;00:D7F0 boss_b_7 (foot)
M4VrShBL equ M4_SH_BOSS_B_L ;00:C814 boss_b_l
M4VrShBR equ M4_SH_BOSS_B_R ;00:C830 boss_b_r
M4VrShBH equ M4_SH_BOSS_B_H ;00:C7F8 boss_b_H

; ---------------------------------------------------------------------
; Helpers (a0 object, a1 player).
; a2 = new object: X_VRPH(a2) = lo8($0336 + slot*$36). The compare harness
; hooks this routine to give the ROM record of the same creation.
M4VrSetPhase:
        move.l d0,-(sp)
        move.w a2,d0
        subi.w #M4_LV_OBJ&$ffff,d0
        lsr.w #6,d0
        addq.w #1,d0
        mulu.w #$36,d0
        move.b d0,X_VRPH(a2)
        move.l (sp)+,d0
        rts
; d0.w = (gameframe + al1pt) & d1 (Z set when 0).
M4VrPhase:
        moveq #0,d0
        move.b X_VRPH(a0),d0
        add.w M4_LV_GAMEFRAME,d0
        and.w d1,d0
        rts
; addplayerZ 1F:DC69.
M4VrPZ:
        move.w M4_LP_PVIEWVZ,d0
        add.w d0,4(a0)
        rts
; keeprelto_player 1F:DB21: z += playervelZ ($14EC = player al_vz, copied by
; 06:8375; port 10(a1) as M4Boss7Cont) - pviewvelz.
M4VrKeepRel:
        move.w 10(a1),d0
        sub.w M4_LP_PVIEWVZ,d0
        add.w d0,4(a0)
        rts
; s_add_bossHP: m_bossHP += HP.
M4VrBossHP:
        move.b 38(a0),d0
        add.b d0,M4_BOSS_HP
        rts
; |player.z - z| (abs16, $8000 stays) -> d0; callers test N of d0 - K.
M4VrZD:
        move.w 4(a1),d0
        sub.w 4(a0),d0
        bpl.s M4VrZDDone
        neg.w d0
M4VrZDDone:
        rts
; Achase16_n (1F:D66F n2, D6AB n3, D6F0 n4): d0 value, d1 target, d2 n ->
; d0; d3 = 1 when already equal (carry of the original).
M4VrCh16:
        moveq #0,d3
        cmp.w d0,d1
        bne.s M4VrCh16Go
        moveq #1,d3
        rts
M4VrCh16Go:
        jmp M4LpAchase
; Achase8_n on a rotation byte: d4 = field offset, d1 target, d2 n; d3 = 1
; when already equal (1F:D88A n2, D8BD n3; inline 3dangle chases).
M4VrRot:
        move.b (a0,d4.w),d0
        jsr M4EnChase8
        move.b d0,(a0,d4.w)
        rts
; roty toward the player (yaw -hi(Yanglexy 1F:D021)), Achase8_n d2.
M4VrYawChase:
        movea.l a1,a2
        jsr M4EnYawTo
        move.b d0,d1
        moveq #13,d4
        bra.s M4VrRot
; rotx toward the player (hi(Xanglexy 1F:D03E)), Achase8_n d2.
M4VrPitchChase:
        movea.l a1,a2
        jsr M4EnPitchTo
        move.b d0,d1
        moveq #12,d4
        bra.s M4VrRot
; speedto 1F:D60D: d0.b target, d1.b step; d3 = 1 when vel == target.
M4VrSpeedTo:
        moveq #0,d3
        move.b 15(a0),d2
        sub.b d0,d2
        beq.s M4VrSpeedEq
        bpl.s M4VrSpeedAbs
        neg.b d2
M4VrSpeedAbs:
        sub.b d1,d2
        bpl.s M4VrSpeedStep
        move.b d0,15(a0)
        rts
M4VrSpeedStep:
        move.b 15(a0),d2
        sub.b d0,d2
        bmi.s M4VrSpeedUp
        sub.b d1,15(a0)
        rts
M4VrSpeedUp:
        add.b d1,15(a0)
        rts
M4VrSpeedEq:
        moveq #1,d3
        rts
; s_add_anim (wrap): d1.b delta (1/$FF), d2.b n. frame += delta; a result
; with bit7 clear gets + n; & $7F; >= n -> - n; | $80.
M4VrAnimWrap:
        move.b 16(a0),d0
        add.b d1,d0
        bmi.s M4VrAnimWrapAnd
        add.b d2,d0
M4VrAnimWrapAnd:
        andi.b #$7f,d0
        cmp.b d2,d0
        blo.s M4VrAnimWrapSet
        sub.b d2,d0
M4VrAnimWrapSet:
        ori.b #$80,d0
        move.b d0,16(a0)
        rts
; s_add_anim +1 with a limit label: d2.b n; d3 = 1 when >= n (frame = n-1).
M4VrAnimLimit:
        moveq #0,d3
        move.b 16(a0),d0
        addq.b #1,d0
        bmi.s M4VrAnimLimitAnd
        add.b d2,d0
M4VrAnimLimitAnd:
        andi.b #$7f,d0
        cmp.b d2,d0
        blo.s M4VrAnimLimitSet
        move.b d2,d0
        subq.b #1,d0
        moveq #1,d3
M4VrAnimLimitSet:
        ori.b #$80,d0
        move.b d0,16(a0)
        rts
; (frame & $7F) - d0.b -> Z.
M4VrFrameIs:
        move.b 16(a0),d1
        andi.b #$7f,d1
        cmp.b d0,d1
        rts
; zero_vecs 1F:DB45: v = 0, vel = 0.
M4VrZeroVecs:
        clr.w 6(a0)
        clr.l 8(a0)
        clr.b 15(a0)
        rts
; y >= -320 (s_jmp_lower #-80<<2): N clear of y + 320 -> d0 (callers bpl).
M4VrLower:
        move.w 2(a0),d0
        addi.w #320,d0
        rts
; fire_weapon 1F:D146: d0 id, d6/d7 rotx/roty add, a3 target (0 none),
; zero offsets -> a2 (0 on failure).
M4VrFire:
        movem.l d3-d5,-(sp)
        moveq #0,d3
        moveq #0,d4
        moveq #0,d5
        jsr M4EnFireId
        movem.l (sp)+,d3-d5
        rts
; make_obj 1F:D54B behind a0: d0 descriptor, d1 header -> a2 (Z on failure).
M4VrMake:
        move.w d1,-(sp)
        jsr M4EnCreate
        beq.s M4VrMakeFail
        move.w (sp)+,X_SHAPEHDR(a2)
        cmpa.w #0,a2
        rts
M4VrMakeFail:
        addq.l #2,sp
        rts
; copy_pos 1F:DAD9 and copy_rots 1F:DB01: a2 = a0.
M4VrCopyPosRot:
        move.l (a0),(a2)
        move.w 4(a0),4(a2)
        move.b 12(a0),12(a2)
        move.b 13(a0),13(a2)
        move.b 14(a0),14(a2)
        rts
; Body shape change (s_set_alvar W,x,al_shape): d0 descriptor, d1 header.
M4VrShape:
        move.w d1,X_SHAPEHDR(a0)
        jmp M4LevelSetShape
; makeLexpobj 06:EEDF at a0 (M4B1Expl wrapper) -> a2, Z on failure.
M4VrLexp:
        move.w #M4_FX_LARGE,d0
        jmp M4B1Expl
; makeLexpobj + nopolyexp + addrnd2posy 06:EF67 (the dummy object of a
; failed creation still takes two random_l).
M4VrLexpRnd:
        bsr.s M4VrLexp
        beq.s M4VrLexpRndFail
        bset #F2_NOPOLYEXP,48(a2)
        jmp M4FxRandomPos
M4VrLexpRndFail:
        jsr M4IntroRandom
        jmp M4IntroRandom
; makeMEDexpobj 06:EEEE with X = the collider (collobjptr $1B): at the
; collider, linked behind it -> a2 (0: none / ground collider skipped).
M4VrMedAtCollider:
        jsr M4LcCollider
        move.l a2,d0
        beq.s M4VrMedNone
        move.l M4_LV_CREATOR,-(sp)
        move.l a2,M4_LV_CREATOR
        move.l a0,-(sp)
        movea.l a2,a0
        jsr M4FxMedium
        movea.l (sp)+,a0
        move.l (sp)+,M4_LV_CREATOR
        rts
M4VrMedNone:
        suba.l a2,a2
        rts

; ---------------------------------------------------------------------
; hitflashbossD 06:891B (collstrat of the first phases): unless nohitaffect,
; makeMEDexpobj at the collider with nopolyexp (trigse $80); then
; hitflash_Istrat 06:89A3 (trigse $24 when nohitaffect).
M4VrHitFlashD:
        btst #SF_NOHITAFFECT,49(a0)
        bne.s M4VrHitFlashGo
        bsr M4VrMedAtCollider
        move.l a2,d0
        beq.s M4VrHitFlashGo
        bset #F2_NOPOLYEXP,48(a2)
M4VrHitFlashGo:
        jmp M4LcHitFlash

; ---------------------------------------------------------------------
; bossBrob_Istrat 07:B848: HP 32 AP 16, m_bossmaxHP 32 / m_bossHP 0,
; collstrat 06:891B, expstrat BCE0, colltype enemy2|enemyweap, speed 40,
; nodepthcue, sflag1 (images), sflag2 off, nohitaffect, roty $60, rotx 8,
; sbyte1 $60, shadow, setnoremove_behind.
M4VrIstrat_B848:
        move.b #$20,38(a0)
        move.b #$10,39(a0)
        move.b #$20,M4_BOSS_MAXHP
        clr.b M4_BOSS_HP
        move.l #M4VrStrat_B8C2,32(a0)
        move.l #M4VrHitFlashD,X_COLL(a0)
        move.l #M4VrChgI_BCE0,X_EXP(a0)
        ori.b #$60,44(a0)
        move.b #40,15(a0)
        move.b #1,X_DEPTHOFF(a0)
        bset #F2_SFLAG1,48(a0)
        bclr #F2_SFLAG2,48(a0)
        bset #SF_NOHITAFFECT,49(a0)
        move.b #$60,13(a0)
        move.b #8,12(a0)
        move.b #$60,36(a0)
        bset #F2_SHADOW,48(a0)
        bclr #3,45(a0)
        movea.l a0,a2
        bsr M4VrSetPhase
; B8C2: every 32 ticks sbyte1 swaps $A0/$60; roty Achase8_2 -> sbyte1;
; ZD >= 3000 -> cont3; -200 <= x < 200 -> bossBrob2.
M4VrStrat_B8C2:
        move.w M4_LV_GAMEFRAME,d0
        andi.w #$1f,d0
        bne.s M4VrRobTurn
        move.b #$a0,d1
        cmp.b 36(a0),d1
        bne.s M4VrRobSet
        move.b #$60,d1
M4VrRobSet:
        move.b d1,36(a0)
M4VrRobTurn:
        move.b 36(a0),d1
        moveq #2,d2
        moveq #13,d4
        bsr M4VrRot
        bsr M4VrZD
        subi.w #3000,d0
        bpl.s M4VrCont3_ABF0
        move.w (a0),d0
        bpl.s M4VrRobXPos
        cmpi.w #$ff38,d0
        bhs.s M4VrRob2Init_B92F
        bra.s M4VrCont3_ABF0
M4VrRobXPos:
        cmpi.w #200,d0
        blo.s M4VrRob2Init_B92F
; bossB_cont3 07:ABF0: gen_3dvecs, addvecs; bossB_cont AC06: with sflag1,
; every other tick (sflag4 toggles) an image boss_B_1 (al_ptr = body, strat
; bossBent B586; the sflag2 branch B234 is unreachable: this unit never sets
; sflag2), cont2 AC75 m_bossHP, cont4 AC80 keeprelto + addplayerZ.
M4VrCont3_ABF0:
        jsr M4EnGen3d
        jsr M4EnMove
        btst #F2_SFLAG1,48(a0)
        beq.s M4VrCont2_AC75
        bchg #7,X_VRFL(a0)
        beq.s M4VrCont2_AC75
        move.w #M4VrShB1,d0
        move.w #$c7a4,d1
        bsr M4VrMake
        beq.s M4VrCont2_AC75
        bsr M4VrSetPhase
        move.w a0,X_ALPTR(a2)
        move.l #M4VrEntI_B586,32(a2)
        bsr M4VrCopyPosRot
M4VrCont2_AC75:
        bsr M4VrBossHP
        bsr M4VrKeepRel
        bsr M4VrPZ
        moveq #0,d0
        rts

; bossBrob2 B92F/B93C: speedto 0 by 1 (reached -> split); roty -> $80, rotx
; -> 0 (Achase8_3).
M4VrRob2Init_B92F:
        move.l #M4VrRob2_B93C,32(a0)
M4VrRob2_B93C:
        moveq #0,d0
        moveq #1,d1
        bsr M4VrSpeedTo
        tst.b d3
        bne.s M4VrSplitInit_B968
        move.b #$80,d1
        moveq #3,d2
        moveq #13,d4
        bsr M4VrRot
        moveq #0,d1
        moveq #3,d2
        moveq #12,d4
        bsr M4VrRot
        bra.s M4VrCont3_ABF0

; bossBrobsplit B968/B97B: sflag3 off; centre (BC81); rangexz (1F:CFC2,
; |0 - x| + |-350 - y|) < 50 -> split2, else cont2.
M4VrSplitInit_B968:
        move.l #M4VrSplit_B97B,32(a0)
        bclr #6,X_VRFL(a0)
M4VrSplit_B97B:
        bsr M4VrCent_BC81
        moveq #0,d0
        sub.w (a0),d0
        bpl.s M4VrSplitDx
        neg.w d0
M4VrSplitDx:
        move.w #-350,d1
        sub.w 2(a0),d1
        bmi.s M4VrSplitDyNeg
        add.w d1,d0
        bra.s M4VrSplitRange
M4VrSplitDyNeg:
        sub.w d1,d0
M4VrSplitRange:
        subi.w #50,d0
        bpl.s M4VrCont2_AC75
; bossBrobsplit2_init B994: r = rnd & 3 (retried while 3) is the body's
; position; the other two are new images (Ment BC1D). M4VrSplitTab holds
; the targets (sword1, sword2) for the three slots. Strategy BA27, cont2.
M4VrSplit2Init_B994:
        jsr M4IntroRandom
        andi.b #3,d0
        cmpi.b #3,d0
        beq.s M4VrSplit2Init_B994
        move.b d0,d5
        moveq #0,d6
M4VrSplit2Slot:
        movea.l a0,a2
        cmp.b d6,d5
        beq.s M4VrSplit2Self
        bsr M4VrMent_BC1D
        move.l a2,d0
        beq.s M4VrSplit2Next
M4VrSplit2Self:
        move.w d6,d0
        add.w d0,d0
        add.w d0,d0
        move.w M4VrSplitTab(pc,d0.w),40(a2)
        move.w M4VrSplitTab+2(pc,d0.w),X_SWORD2(a2)
M4VrSplit2Next:
        addq.b #1,d6
        cmpi.b #3,d6
        bne.s M4VrSplit2Slot
        move.l #M4VrEntSplit2I_BA27,32(a0)
        bra M4VrCont2_AC75
M4VrSplitTab:
        include '../build/m4-venom-rob-split.inc'

; bossBentsplit2_Istrat BA27 (body): nohitaffect off, sbyte1 1 (BB38).
M4VrEntSplit2I_BA27:
        move.l #M4VrEntSplit2_BA3D,32(a0)
        bclr #SF_NOHITAFFECT,49(a0)
        bra M4VrEntSplitIcont_BB38
; BA3D: rotx/roty toward the player (Achase8_2); every 8th (gameframe +
; al1pt) RelSlowElaserHome ($0A) aimed at the player; m_bossHP; sbyte1 1 ->
; split2 again, else bossBentsplit_cont.
M4VrEntSplit2_BA3D:
        moveq #2,d2
        bsr M4VrPitchChase
        moveq #2,d2
        bsr M4VrYawChase
        moveq #7,d1
        bsr M4VrPhase
        bne.s M4VrEntSplit2NoFire
        moveq #$0a,d0
        moveq #0,d6
        moveq #0,d7
        movea.l a1,a3
        bsr M4VrFire
M4VrEntSplit2NoFire:
        bsr M4VrBossHP
        cmpi.b #1,36(a0)
        beq M4VrSplit2Init_B994
        moveq #0,d7
        bra M4VrEntSplitCont_BBB4

; bossBentsplitcol_Istrat BAF9 (images): trigse $27, collide off, strategy.
M4VrEntSplitColl_BAF9:
        bclr #SF_COLLIDE,49(a0)
        jmp M4LcStrategy

; bossBentsplit_Istrat BB09 (images): HP $FF AP 0, collstrat BAF9,
; depthoffset 1, count 8; BB38: sbyte1 1, cont.
M4VrEntSplitI_BB09:
        move.b #$ff,38(a0)
        clr.b 39(a0)
        move.l #M4VrEntSplit_BB3F,32(a0)
        move.l #M4VrEntSplitColl_BAF9,X_COLL(a0)
        move.b #1,X_DEPTHOFF(a0)
        move.b #8,19(a0)
M4VrEntSplitIcont_BB38:
        move.b #1,36(a0)
        moveq #0,d7
        bra.s M4VrEntSplitCont_BBB4
; BB3F: every 16th (gameframe + al1pt) RelSlowElaser ($0C) ahead; the body
; (al_ptr) with sflag3 or sbyte1 <= 20 -> fade: every 8th gameframe
; depthoffset + 1, count - 1 (0: removed, deferred).
M4VrEntSplit_BB3F:
        moveq #0,d7
        moveq #15,d1
        bsr M4VrPhase
        bne.s M4VrEntSplitNoFire
        moveq #$0c,d0
        moveq #0,d6
        suba.l a3,a3
        bsr M4VrFire
        moveq #0,d7
M4VrEntSplitNoFire:
        move.w X_ALPTR(a0),d0
        beq.s M4VrEntSplitSb
        movea.w d0,a2
        btst #6,X_VRFL(a2)
        bne.s M4VrEntSplitDie
M4VrEntSplitSb:
        move.b 36(a0),d0
        subi.b #20,d0
        beq.s M4VrEntSplitDie
        bpl.s M4VrEntSplitCont_BBB4
M4VrEntSplitDie:
        move.w M4_LV_GAMEFRAME,d0
        andi.w #7,d0
        bne.s M4VrEntSplitCount
        addq.b #1,X_DEPTHOFF(a0)
M4VrEntSplitCount:
        subq.b #1,19(a0)
        bne.s M4VrEntSplitCont_BBB4
        moveq #1,d7
; bossBentsplit_cont BBB4 (d7 = removal): sbyte1 - 1 (0 -> 100); sbyte1 >=
; 20: x/y Achase16_3 -> sword1/sword2, ZD >= 1500 -> z - 60; else centre;
; addplayerZ.
M4VrEntSplitCont_BBB4:
        subq.b #1,36(a0)
        bne.s M4VrEntSplitNoRes
        move.b #100,36(a0)
M4VrEntSplitNoRes:
        move.b 36(a0),d0
        subi.b #20,d0
        bmi.s M4VrEntSplitCent
        move.w (a0),d0
        move.w 40(a0),d1
        moveq #3,d2
        bsr M4VrCh16
        move.w d0,(a0)
        move.w 2(a0),d0
        move.w X_SWORD2(a0),d1
        moveq #3,d2
        bsr M4VrCh16
        move.w d0,2(a0)
        bsr M4VrZD
        subi.w #1500,d0
        bmi.s M4VrEntSplitEnd
        subi.w #60,4(a0)
        bra.s M4VrEntSplitEnd
M4VrEntSplitCent:
        bsr M4VrCent_BC81
M4VrEntSplitEnd:
        bsr M4VrPZ
        move.l d7,d0
        rts

; bossBrobMent_srou BC1D: make_obj with the shape of a0 behind a0, copy
; position/rotations, strategy BB09, al_ptr = a0 -> a2 (0 on failure: the
; original writes the dummy object instead).
M4VrMent_BC1D:
        move.w 46(a0),d0
        move.w X_SHAPEHDR(a0),d1
        bsr M4VrMake
        beq.s M4VrMentFail
        bsr M4VrSetPhase
        bsr M4VrCopyPosRot
        move.l #M4VrEntSplitI_BB09,32(a2)
        move.w a0,X_ALPTR(a2)
        rts
M4VrMentFail:
        suba.l a2,a2
        rts
; bossBrobMent2_srou BC58: Ment, strategy bossBent B586, animframe = a0's
; | $80, al_type gnd.
M4VrMent2_BC58:
        bsr.s M4VrMent_BC1D
        move.l a2,d0
        beq.s M4VrMent2Done
        move.l #M4VrEntI_B586,32(a2)
        move.b 16(a0),d0
        ori.b #$80,d0
        move.b d0,16(a2)
        bset #0,45(a2)
M4VrMent2Done:
        rts
; bossBrobcent_srou BC81: x -> 0, y -> -350 (Achase16_3); ZD < 3000 -> z + 60.
M4VrCent_BC81:
        move.w (a0),d0
        moveq #0,d1
        moveq #3,d2
        bsr M4VrCh16
        move.w d0,(a0)
        move.w 2(a0),d0
        move.w #-350,d1
        moveq #3,d2
        bsr M4VrCh16
        move.w d0,2(a0)
        bsr M4VrZD
        subi.w #3000,d0
        bpl.s M4VrCentDone
        addi.w #60,4(a0)
M4VrCentDone:
        rts

; ---------------------------------------------------------------------
; bossBrobchg_Istrat BCE0 (expstrat, HP 0): HP 2 AP 16, collstrat CC8B,
; expstrat 00:0000 (none), sbyte1 40, sflag3 (images fade), nohitaffect
; (music $F1, trigse $81).
M4VrChgI_BCE0:
        move.b #2,38(a0)
        move.b #$10,39(a0)
        move.l #M4VrChg_BD2D,32(a0)
        move.l #M4VrColl_CC8B,X_COLL(a0)
        clr.l X_EXP(a0)
        move.b #40,36(a0)
        bset #6,X_VRFL(a0)
        bset #SF_NOHITAFFECT,49(a0)
; BD2D: roty -> $80 (Achase8_3), centre; sbyte1 0 -> chg2, else - 1,
; addplayerZ, vecs_cont4.
M4VrChg_BD2D:
        move.b #$80,d1
        moveq #3,d2
        moveq #13,d4
        bsr M4VrRot
        bsr M4VrCent_BC81
        tst.b 36(a0)
        beq.s M4VrChg2Init_BD5D
        subq.b #1,36(a0)
        bsr M4VrPZ
        bra M4VrVecsCont4_BDBD
; bossBaddpz_cont BD4D / bossBaddbhp_cont BD51.
M4VrAddPZCont_BD4D:
        bsr M4VrPZ
M4VrBhpCont_BD51:
        bsr M4VrBossHP
        moveq #0,d0
        rts
; bossBrobchg2 BD5D/BD7C: vel 0, rotx 0, roty $78 (trigse $84); speedto 60
; by 1; ZD < 1000 -> chg3; vecs_cont.
M4VrChg2Init_BD5D:
        clr.b 15(a0)
        move.l #M4VrChg2_BD7C,32(a0)
        clr.b 12(a0)
        move.b #$78,13(a0)
M4VrChg2_BD7C:
        moveq #60,d0
        moveq #1,d1
        bsr M4VrSpeedTo
        bsr M4VrZD
        subi.w #1000,d0
        bmi.s M4VrChg3Init_BE7D
; bossBrobvecs_cont BDA3 (addplayerZ), cont2 BDA7 (gen_3dvecs), cont3 BDB9
; (addvecs), cont4 BDBD (m_bossHP, damagesmoke #60: HP <= 60 signed ->
; afonfire, every 4th gameframe a smoke at the object).
M4VrVecsCont_BDA3:
        bsr M4VrPZ
M4VrVecsCont2_BDA7:
        jsr M4EnGen3d
M4VrVecsCont3_BDB9:
        jsr M4EnMove
M4VrVecsCont4_BDBD:
        bsr M4VrBossHP
        move.b 38(a0),d0
        subi.b #60,d0
        beq.s M4VrSmoke
        bpl.s M4VrNoSmoke
M4VrSmoke:
        bset #AF_ONFIRE,51(a0)
        move.w M4_LV_GAMEFRAME,d0
        andi.w #3,d0
        bne.s M4VrNoSmoke
        jsr M4FxSmoke
M4VrNoSmoke:
        moveq #0,d0
        rts
; bossBrobchg3 BE7D/BE8A: rotz + 4, roty + 4 until $20; ZD >= 1400 -> chg4.
M4VrChg3Init_BE7D:
        move.l #M4VrChg3_BE8A,32(a0)
M4VrChg3_BE8A:
        addq.b #4,14(a0)
        cmpi.b #$20,13(a0)
        beq.s M4VrChg3Dist
        addq.b #4,13(a0)
M4VrChg3Dist:
        bsr M4VrZD
        subi.w #1400,d0
        bmi.s M4VrVecsCont_BDA3
; bossBrobchg4 BEC1/BEEA (legs): shape boss_b_0, animframe 0, sbyte1 30
; (music 6). rotx, rotz -> 0 (Achase8_3), x -> 0 (Achase16_4), speedto 0 by
; 2; stopped: roty -> $80 (Achase8_2); there: sbyte1 0 -> start, else - 1,
; HP + 2, m_bossmaxHP = HP (m_bossHP 0); even gameframe: anim + 1 up to 12
; with an image (Ment2), then vecs_cont2.
M4VrChg4Init_BEC1:
        move.l #M4VrChg4_BEEA,32(a0)
        move.w #M4VrShB0,d0
        move.w #$c788,d1
        bsr M4VrShape
        move.b #$80,16(a0)
        move.b #30,36(a0)
M4VrChg4_BEEA:
        moveq #0,d1
        moveq #3,d2
        moveq #12,d4
        bsr M4VrRot
        moveq #0,d1
        moveq #3,d2
        moveq #14,d4
        bsr M4VrRot
        move.w (a0),d0
        moveq #0,d1
        moveq #4,d2
        bsr M4VrCh16
        move.w d0,(a0)
        moveq #0,d0
        moveq #2,d1
        bsr M4VrSpeedTo
        tst.b d3
        beq M4VrVecsCont_BDA3
        move.b #$80,d1
        moveq #2,d2
        moveq #13,d4
        bsr M4VrRot
        tst.b d3
        beq M4VrVecsCont_BDA3
        tst.b 36(a0)
        beq.s M4VrStartInit_BF8E
        subq.b #1,36(a0)
        addq.b #2,38(a0)
        move.b 38(a0),M4_BOSS_MAXHP
        clr.b M4_BOSS_HP
        btst #0,M4_LV_GAMEFRAME+1
        bne M4VrVecsCont_BDA3
        moveq #13,d2
        bsr M4VrAnimLimit
        tst.b d3
        bne M4VrVecsCont_BDA3
        bsr M4VrMent2_BC58
        bra M4VrVecsCont2_BDA7
; bossBrobstart BF8E/BFAB: zero_vecs, sflag5 and nohitaffect off; falldown_Yvec
; (vy + 2; at y >= -320: y = -320, vy = trunc0(trunc0(-vy/2)/2), -5..-1 -> 0;
; low byte of vy 0 -> nextstate); vecs_cont3.
M4VrStartInit_BF8E:
        move.l #M4VrStart_BFAB,32(a0)
        bsr M4VrZeroVecs
        bclr #0,X_VRFL(a0)
        bclr #SF_NOHITAFFECT,49(a0)
M4VrStart_BFAB:
        addq.w #2,8(a0)
        bsr M4VrLower
        bmi M4VrVecsCont3_BDB9
        move.w #-320,2(a0)
        move.w 8(a0),d0
        neg.w d0
        ext.l d0
        bpl.s M4VrStartQuarter
        addq.l #3,d0
M4VrStartQuarter:
        asr.l #2,d0
        cmpi.w #$fffb,d0
        blo.s M4VrStartVy
        moveq #0,d0
M4VrStartVy:
        move.w d0,8(a0)
        tst.b d0
        bne M4VrVecsCont3_BDB9
        bra M4VrNextState_CF11
; bossBrobstart2_init C002: strategy fire1 C12A, sbyte2 $E0, sbyte1 60,
; BYTE $26 (sword1 low) 0.
M4VrStart2Init_C002:
        move.l #M4VrFire1_C12A,32(a0)
        move.b #$e0,37(a0)
        move.b #60,36(a0)
        clr.b 41(a0)
        bra M4VrFire1_C12A

; ---------------------------------------------------------------------
; bossBrobjump1 C01F/C033: animframe 12; anim + 1 up to 20 -> jump2.
M4VrJump1Init_C01F:
        move.l #M4VrJump1_C033,32(a0)
        move.b #$8c,16(a0)
M4VrJump1_C033:
        moveq #20,d2
        bsr M4VrAnimLimit
        tst.b d3
        bne.s M4VrJump2Init_C05A
; bossBrob_cont C054: Ouch, addplayerZ, m_bossHP.
M4VrRobCont_C054:
        bsr M4VrOuchSrou_CD8A
        bra M4VrAddPZCont_BD4D
; bossBrobjump2 C05A/C090: vel 100, gen_vecs (gen2d), vy -100 (trigse $4D);
; addvecs; y >= -320 -> land; vy + 20, roty + 7.
M4VrJump2Init_C05A:
        move.l #M4VrJump2_C090,32(a0)
        move.b #100,15(a0)
        jsr M4EnGen2d
        move.w #-100,8(a0)
M4VrJump2_C090:
        jsr M4EnMove
        bsr M4VrLower
        bpl.s M4VrLandInit_C0B9
        addi.w #20,8(a0)
        addq.b #7,13(a0)
        bra.s M4VrRobCont_C054
; bossBrobland C0B9/C0D6: sbyte1 10, BYTE $26 + 1, zero_vecs (trigse $4C);
; sbyte1 0 -> fire1, else - 1; frame 12: $26 == 2 -> nextstate; else anim - 1.
M4VrLandInit_C0B9:
        move.l #M4VrLand_C0D6,32(a0)
        move.b #10,36(a0)
        addq.b #1,41(a0)
        bsr M4VrZeroVecs
M4VrLand_C0D6:
        tst.b 36(a0)
        beq.s M4VrFire1Init_C115
        subq.b #1,36(a0)
        moveq #12,d0
        bsr M4VrFrameIs
        beq.s M4VrLandStill
        moveq #-1,d1
        moveq #20,d2
        bsr M4VrAnimWrap
        bra.s M4VrRobCont_C054
M4VrLandStill:
        cmpi.b #2,41(a0)
        beq M4VrNextState_CF11
        bra.s M4VrRobCont_C054
; bossbrobfire1 C115/C12A: sbyte2 = roty, sbyte1 60; sbyte1 0 -> fire2, else
; - 1; gameframe & 7 == 0: RelSlowElaser ($0C), rot + ((rnd&3)-1,
; (rnd&15)-7); roty toward the player: already equal -> every 16th
; gameframe RelSlowElaserHome aimed, else Achase8_3.
M4VrFire1Init_C115:
        move.l #M4VrFire1_C12A,32(a0)
        move.b 13(a0),37(a0)
        move.b #60,36(a0)
M4VrFire1_C12A:
        tst.b 36(a0)
        beq.s M4VrFire2Init_C20D
        subq.b #1,36(a0)
        move.w M4_LV_GAMEFRAME,d0
        andi.w #7,d0
        bne.s M4VrFire1Aim
        jsr M4IntroRandom
        andi.b #3,d0
        subq.b #1,d0
        move.b d0,d6
        jsr M4IntroRandom
        andi.b #15,d0
        subq.b #7,d0
        move.b d0,d7
        moveq #$0c,d0
        suba.l a3,a3
        bsr M4VrFire
M4VrFire1Aim:
        moveq #3,d2
        bsr M4VrYawChase
        tst.b d3
        beq M4VrRobCont_C054
        move.w M4_LV_GAMEFRAME,d0
        andi.w #15,d0
        bne M4VrRobCont_C054
        moveq #$0a,d0
        moveq #0,d6
        moveq #0,d7
        movea.l a1,a3
        bsr M4VrFire
        bra M4VrRobCont_C054
; bossBrobfire2 C20D/C21A: roty -> sbyte2 (Achase8_2); there -> jump1.
M4VrFire2Init_C20D:
        move.l #M4VrFire2_C21A,32(a0)
M4VrFire2_C21A:
        move.b 37(a0),d1
        moveq #2,d2
        moveq #13,d4
        bsr M4VrRot
        tst.b d3
        bne M4VrJump1Init_C01F
        bra M4VrRobCont_C054

; bossbrobfireP1 C22F/C251: collstrat CC8B, sbyte1 60; in front of the
; player at 1400 (C2B0); sbyte1 0 -> start2, else - 1; every 16th gameframe
; Hplasma ($26) ahead with al_ptr = player; Ouch; addpz_cont.
M4VrFireP1Init_C22F:
        move.l #M4VrColl_CC8B,X_COLL(a0)
        move.l #M4VrFireP1_C251,32(a0)
        move.b #60,36(a0)
M4VrFireP1_C251:
        move.w #1400,d5
        bsr M4VrFront_C2B0
        tst.b 36(a0)
        beq M4VrStart2Init_C002
        subq.b #1,36(a0)
        move.w M4_LV_GAMEFRAME,d0
        andi.w #15,d0
        bne.s M4VrFireP1Ouch
        moveq #$26,d0
        moveq #0,d6
        moveq #0,d7
        suba.l a3,a3
        bsr M4VrFire
        move.l a2,d0
        beq.s M4VrFireP1Ouch
        move.w a1,X_ALPTR(a2)
M4VrFireP1Ouch:
        bsr M4VrOuchSrou_CD8A
        bra M4VrAddPZCont_BD4D
; bossBrobfrontplayer_srou C2B0 (d5 = svar_word1): x -> 0, y -> -320
; (Achase16_3), roty toward the player (Achase8_3), z -> player_posz + d5
; (Achase16_3).
M4VrFront_C2B0:
        move.w (a0),d0
        moveq #0,d1
        moveq #3,d2
        bsr M4VrCh16
        move.w d0,(a0)
        move.w 2(a0),d0
        move.w #-320,d1
        moveq #3,d2
        bsr M4VrCh16
        move.w d0,2(a0)
        moveq #3,d2
        bsr M4VrYawChase
        move.w M4_LP_POSZ,d1
        add.w d5,d1
        move.w 4(a0),d0
        moveq #3,d2
        bsr M4VrCh16
        move.w d0,4(a0)
        rts

; bossBrobPouncepos C332/C34A: sbyte1 30, animframe 12; after 29 ticks
; (then sbyte1 kept at 1) anim + 1 up to 20 -> pounce2, with an image on
; even gameframes; in front of the player at 3000; addpz_cont.
M4VrPounceInit_C332:
        move.l #M4VrPounce_C34A,32(a0)
        move.b #30,36(a0)
        move.b #$8c,16(a0)
M4VrPounce_C34A:
        subq.b #1,36(a0)
        bne.s M4VrPounceFront
        move.b #1,36(a0)
        moveq #20,d2
        bsr M4VrAnimLimit
        tst.b d3
        bne.s M4VrPounce2Init_C395
        btst #0,M4_LV_GAMEFRAME+1
        bne.s M4VrPounceFront
        bsr M4VrMent2_BC58
M4VrPounceFront:
        move.w #3000,d5
        bsr M4VrFront_C2B0
        bra M4VrAddPZCont_BD4D
; bossBrobPounce2 C395/C3BF: v (0, -75, 0), rotx 8 (trigse $4D). Behind the
; player (z < pz) with ZD >= 500 -> reappear. addvecs, rotx + 8 until 0;
; above y -320: vy + 4, image on even gameframes; else zero_vecs, (frame 19:
; trigse $4C), anim - 1 down to 12. baddbhp_cont (no addplayerZ).
M4VrPounce2Init_C395:
        move.l #M4VrPounce2_C3BF,32(a0)
        clr.w 6(a0)
        move.w #-75,8(a0)
        clr.w 10(a0)
        move.b #8,12(a0)
M4VrPounce2_C3BF:
        move.w 4(a0),d0
        sub.w 4(a1),d0
        bpl.s M4VrPounce2Move
        bsr M4VrZD
        subi.w #500,d0
        bpl.s M4VrReapInit_C469
M4VrPounce2Move:
        jsr M4EnMove
        tst.b 12(a0)
        beq.s M4VrPounce2Y
        addq.b #8,12(a0)
M4VrPounce2Y:
        bsr M4VrLower
        bpl.s M4VrPounce2Lower
        addq.w #4,8(a0)
        btst #0,M4_LV_GAMEFRAME+1
        bne M4VrBhpCont_BD51
        bsr M4VrMent2_BC58
        bra M4VrBhpCont_BD51
M4VrPounce2Lower:
        bsr M4VrZeroVecs
        moveq #12,d0
        bsr M4VrFrameIs
        beq M4VrBhpCont_BD51
        moveq #-1,d1
        moveq #20,d2
        bsr M4VrAnimWrap
        bra M4VrBhpCont_BD51
; bossBrobreappear C469/C494: v (0, -75, 45), rotx 8, animframe 19; as
; pounce2 with vy + 3 and addpz_cont; landed at frame 12 -> nextstate.
M4VrReapInit_C469:
        move.l #M4VrReap_C494,32(a0)
        clr.w 6(a0)
        move.w #-75,8(a0)
        move.w #45,10(a0)
        move.b #8,12(a0)
        move.b #$93,16(a0)
M4VrReap_C494:
        jsr M4EnMove
        tst.b 12(a0)
        beq.s M4VrReapY
        addq.b #8,12(a0)
M4VrReapY:
        bsr M4VrLower
        bpl.s M4VrReapLower
        addq.w #3,8(a0)
        btst #0,M4_LV_GAMEFRAME+1
        bne M4VrAddPZCont_BD4D
        bsr M4VrMent2_BC58
        bra M4VrAddPZCont_BD4D
M4VrReapLower:
        bsr M4VrZeroVecs
        moveq #12,d0
        bsr M4VrFrameIs
        beq M4VrNextState_CF11
        moveq #-1,d1
        moveq #20,d2
        bsr M4VrAnimWrap
        bra M4VrAddPZCont_BD4D

; ---------------------------------------------------------------------
; bossBrobsep C519/C55A: sbyte1 2 (images), sbyte2 2 (hits before the
; pounce), sflag1 off, collstrat C9EE, expstrat CA3F (trigse $2D),
; nohitaffect. Even gameframe and frame != 12: anim + 1 (wrap 20); roty + 4
; until $80; ZD < 2000: sbyte1 0 -> strategy rndpos2 C5FF, else - 1 and an
; image (Ment2, colldisable, rndpos C5EF). vecs_cont.
M4VrSepInit_C519:
        move.b #2,36(a0)
        move.b #2,37(a0)
        bclr #F2_SFLAG1,48(a0)
        move.l #M4VrSep_C55A,32(a0)
        move.l #M4VrSepColl_C9EE,X_COLL(a0)
        move.l #M4VrSepExpI_CA3F,X_EXP(a0)
        bset #SF_NOHITAFFECT,49(a0)
M4VrSep_C55A:
        btst #0,M4_LV_GAMEFRAME+1
        bne.s M4VrSepRot
        moveq #12,d0
        bsr M4VrFrameIs
        beq.s M4VrSepRot
        moveq #1,d1
        moveq #20,d2
        bsr M4VrAnimWrap
M4VrSepRot:
        cmpi.b #$80,13(a0)
        beq.s M4VrSepDist
        addq.b #4,13(a0)
M4VrSepDist:
        bsr M4VrZD
        subi.w #2000,d0
        bpl M4VrVecsCont_BDA3
        tst.b 36(a0)
        beq.s M4VrSepFin
        subq.b #1,36(a0)
        bsr M4VrMent2_BC58
        move.l a2,d0
        beq M4VrVecsCont_BDA3
        bset #SF_COLLDISABLE,49(a2)
        move.l #M4VrRndPosI_C5EF,32(a2)
        bra M4VrVecsCont_BDA3
M4VrSepFin:
        move.l #M4VrRndPos2I_C5FF,32(a0)
        bra M4VrVecsCont_BDA3
; bossBrobrndpos_Istrat C5EF (images) / rndpos2_Istrat C5FF (body); C60C:
; sbyte1 1, nohitaffect and sflag1 off, then the strategy.
M4VrRndPosI_C5EF:
        move.l #M4VrRndPos_C631,32(a0)
        bra.s M4VrRndPosIcont_C60C
M4VrRndPos2I_C5FF:
        move.l #M4VrRndPos2_C620,32(a0)
M4VrRndPosIcont_C60C:
        move.b #1,36(a0)
        bclr #SF_NOHITAFFECT,49(a0)
        bclr #F2_SFLAG1,48(a0)
        jmp M4LcStrategy
; C620 (body): Ouch, m_bossHP, rndpos_cont.
M4VrRndPos2_C620:
        bsr M4VrOuchSrou_CD8A
        bsr M4VrBossHP
        bra.s M4VrRndPosCont_C656
; C631 (images): rotx, rotz -> 0 (Achase8_2); the body (al_ptr) with sflag1
; -> bossBent B586.
M4VrRndPos_C631:
        moveq #0,d1
        moveq #2,d2
        moveq #12,d4
        bsr M4VrRot
        moveq #0,d1
        moveq #2,d2
        moveq #14,d4
        bsr M4VrRot
        move.w X_ALPTR(a0),d0
        beq.s M4VrRndPosCont_C656
        movea.w d0,a2
        btst #F2_SFLAG1,48(a2)
        bne M4VrEntI_B586
; rndpos_cont C656: sbyte1 - 1 = 0: sbyte1 30 (trigse $2D), (sword1, sword2)
; = 07:C767[rnd & 7], sword1 + player_posx. x -> sword1, z -> sword2 +
; player_posz (Achase16_2), y -> -320 (Achase16_3); every 16th (gameframe +
; al1pt) RelSlowElaserHome ($0A) ahead; roty toward the player (Achase8_1);
; addplayerZ.
M4VrRndPosCont_C656:
        subq.b #1,36(a0)
        bne.s M4VrRndPosMove
        move.b #30,36(a0)
        jsr M4IntroRandom
        andi.w #7,d0
        lsl.w #2,d0
        move.w M4VrRndPosTab(pc,d0.w),d1
        add.w M4_SC_PPOSX,d1
        move.w d1,40(a0)
        move.w M4VrRndPosTab+2(pc,d0.w),X_SWORD2(a0)
M4VrRndPosMove:
        move.w (a0),d0
        move.w 40(a0),d1
        moveq #2,d2
        bsr M4VrCh16
        move.w d0,(a0)
        move.w X_SWORD2(a0),d1
        add.w M4_LP_POSZ,d1
        move.w 4(a0),d0
        moveq #2,d2
        bsr M4VrCh16
        move.w d0,4(a0)
        move.w 2(a0),d0
        move.w #-320,d1
        moveq #3,d2
        bsr M4VrCh16
        move.w d0,2(a0)
        moveq #15,d1
        bsr M4VrPhase
        bne.s M4VrRndPosYaw
        moveq #$0a,d0
        moveq #0,d6
        moveq #0,d7
        suba.l a3,a3
        bsr M4VrFire
M4VrRndPosYaw:
        moveq #1,d2
        bsr M4VrYawChase
        bsr M4VrPZ
        moveq #0,d0
        rts
M4VrRndPosTab: ;07:C767
        incbin '../build/M4VrRndPosTab.bin'

; ---------------------------------------------------------------------
; bossBrobkick C787/C7A8: shape boss_b_6, animframe 0, sbyte1 20. Until
; frame 19: anim + 1 (wrap 20); at frame 15 a foot boss_b_7 (copy, x + 284,
; z - 360, strategy C971; trigse $2D); rotz -> 0 (Achase8_2). sbyte1 0 ->
; nextstate, else - 1; Ouch; addpz_cont.
M4VrKickInit_C787:
        move.l #M4VrKick_C7A8,32(a0)
        move.w #M4VrShB6,d0
        move.w #$d7d4,d1
        bsr M4VrShape
        move.b #$80,16(a0)
        move.b #20,36(a0)
M4VrKick_C7A8:
        moveq #19,d0
        bsr M4VrFrameIs
        beq.s M4VrKickWait
        moveq #1,d1
        moveq #20,d2
        bsr M4VrAnimWrap
        moveq #15,d0
        bsr M4VrFrameIs
        bne.s M4VrKickRotz
        move.w #M4VrShB7,d0
        move.w #$d7f0,d1
        bsr M4VrMake
        beq.s M4VrKickRotz
        bsr M4VrCopyPosRot
        addi.w #284,(a2)
        subi.w #360,4(a2)
        move.l #M4VrFootI_C971,32(a2)
M4VrKickRotz:
        moveq #0,d1
        moveq #2,d2
        moveq #14,d4
        bsr M4VrRot
M4VrKickWait:
        tst.b 36(a0)
        beq M4VrNextState_CF11
        subq.b #1,36(a0)
        bsr M4VrOuchSrou_CD8A
        bra M4VrAddPZCont_BD4D

; bossBrobfarjump1 C844/C867: shape boss_b_0, animframe 12, nohitaffect;
; anim + 1 up to 20 -> farjump2; roty -> 0 (Achase8_2); Ouch; addpz_cont.
M4VrFarJ1Init_C844:
        move.l #M4VrFarJ1_C867,32(a0)
        move.w #M4VrShB0,d0
        move.w #$c788,d1
        bsr M4VrShape
        move.b #$8c,16(a0)
        bset #SF_NOHITAFFECT,49(a0)
M4VrFarJ1_C867:
        moveq #20,d2
        bsr M4VrAnimLimit
        tst.b d3
        bne.s M4VrFarJ2Init_C89A
        moveq #0,d1
        moveq #2,d2
        moveq #13,d4
        bsr M4VrRot
        bsr M4VrOuchSrou_CD8A
        bra M4VrAddPZCont_BD4D
; bossBrobfarjump2 C89A/C8CA: vel 100, gen_vecs, vy -100; addvecs; y >= -320
; -> farland; vy + 8, roty -> $80 (Achase8_3), x -> player_posx
; (Achase16_2); bossBrob_cont.
M4VrFarJ2Init_C89A:
        move.l #M4VrFarJ2_C8CA,32(a0)
        move.b #100,15(a0)
        jsr M4EnGen2d
        move.w #-100,8(a0)
M4VrFarJ2_C8CA:
        jsr M4EnMove
        bsr M4VrLower
        bpl.s M4VrFarLandInit_C909
        addq.w #8,8(a0)
        move.b #$80,d1
        moveq #3,d2
        moveq #13,d4
        bsr M4VrRot
        move.w (a0),d0
        move.w M4_SC_PPOSX,d1
        moveq #2,d2
        bsr M4VrCh16
        move.w d0,(a0)
        bra M4VrRobCont_C054
; bossBrobfarland C909/C920: zero_vecs, nohitaffect; frame != 12: anim - 1;
; ZD < 2000: nohitaffect off, nextstate; else Ouch, baddbhp_cont.
M4VrFarLandInit_C909:
        move.l #M4VrFarLand_C920,32(a0)
        bsr M4VrZeroVecs
        bset #SF_NOHITAFFECT,49(a0)
M4VrFarLand_C920:
        moveq #12,d0
        bsr M4VrFrameIs
        beq.s M4VrFarLandDist
        moveq #-1,d1
        moveq #20,d2
        bsr M4VrAnimWrap
M4VrFarLandDist:
        bsr M4VrZD
        subi.w #2000,d0
        bpl.s M4VrFarLandWait
        bclr #SF_NOHITAFFECT,49(a0)
        bra M4VrNextState_CF11
M4VrFarLandWait:
        bsr M4VrOuchSrou_CD8A
        bra M4VrBhpCont_BD51

; bossBrobfoot_Istrat C971: no pointers (1F:D450), HP $FF AP 8, vel 120,
; nodepthcue, rotx/roty = angles to the player, gen_3dvecs. C9C8: even
; gameframe: an image (Ment2) with bossBentlong B566; addplayerZ; addvecs.
M4VrFootI_C971:
        move.l #M4VrFoot_C9C8,32(a0)
        clr.l X_COLL(a0)
        clr.l X_EXP(a0)
        move.b #$ff,38(a0)
        move.b #8,39(a0)
        move.b #120,15(a0)
        move.b #1,X_DEPTHOFF(a0)
        movea.l a1,a2
        jsr M4EnPitchTo
        move.b d0,12(a0)
        jsr M4EnYawTo
        move.b d0,13(a0)
        jsr M4EnGen3d
M4VrFoot_C9C8:
        btst #0,M4_LV_GAMEFRAME+1
        bne.s M4VrFootMove
        bsr M4VrMent2_BC58
        move.l a2,d0
        beq.s M4VrFootMove
        move.l #M4VrEntLongI_B566,32(a2)
M4VrFootMove:
        bsr M4VrPZ
        jsr M4EnMove
        moveq #0,d0
        rts

; bossBentlong_Istrat 07:B566 (count 20) / bossBent_Istrat B586 (count 8):
; colldisable, depthoffset 1. B5A2: every 8th (gameframe + al1pt)
; depthoffset + 1; count - 1 (0: removed, deferred); addplayerZ, keeprelto,
; z + 1.
M4VrEntLongI_B566:
        move.b #20,19(a0)
        bra.s M4VrEntICommon
M4VrEntI_B586:
        move.b #8,19(a0)
M4VrEntICommon:
        bset #SF_COLLDISABLE,49(a0)
        move.l #M4VrEnt_B5A2,32(a0)
        move.b #1,X_DEPTHOFF(a0)
M4VrEnt_B5A2:
        moveq #0,d7
        moveq #7,d1
        bsr M4VrPhase
        bne.s M4VrEntCount
        addq.b #1,X_DEPTHOFF(a0)
M4VrEntCount:
        subq.b #1,19(a0)
        bne.s M4VrEntMove
        moveq #1,d7
M4VrEntMove:
        bsr M4VrPZ
        bsr M4VrKeepRel
        addq.w #1,4(a0)
        move.l d7,d0
        rts

; ---------------------------------------------------------------------
; bossBrobsepcol_Istrat C9EE: sflag5 or nohitaffect -> (trigse $27)
; hitflags 0, strategy. sbyte2 - 1 = 0: sflag1 (rndpos images fade),
; nextstate. Else HF1/HF2/HF3 -> Top/Left/Right Ouch. collide is not cleared.
M4VrSepColl_C9EE:
        btst #0,X_VRFL(a0)
        bne.s M4VrSepCollEnd
        btst #SF_NOHITAFFECT,49(a0)
        bne.s M4VrSepCollEnd
        subq.b #1,37(a0)
        bne.s M4VrSepCollHit
        bset #F2_SFLAG1,48(a0)
        bra M4VrNextState_CF11
M4VrSepCollHit:
        btst #0,20(a0)
        bne.s M4VrTopOuch_CD54
        btst #1,20(a0)
        bne.s M4VrLeftOuch_CD3A
        btst #2,20(a0)
        bne.s M4VrRightOuch_CD47
M4VrSepCollEnd:
        clr.b 20(a0)
        jmp M4LcStrategy

; bossBrobcol_Istrat CC8B: collide off; sflag5 or nohitaffect -> (trigse
; $27) hitflags 0, strategy; else makeMEDexpobj at the collider, then
; HF1/HF2/HF3 -> Top/Left/Right Ouch.
M4VrColl_CC8B:
        bclr #SF_COLLIDE,49(a0)
        btst #0,X_VRFL(a0)
        bne.s M4VrSepCollEnd
        btst #SF_NOHITAFFECT,49(a0)
        bne.s M4VrSepCollEnd
        bsr M4VrMedAtCollider
        bra.s M4VrSepCollHit
; bossBrobLeftOuch CD3A (sbyte4 0), RightOuch CD47 (sbyte4 $20): trigse $27;
; TopOuch CD54: trigse $80, sbyte4 $40, do_coll(collider AP, 10), hitflash.
; Ouch CD78: hitflags 0, sbyte3 16, sflag5, strategy.
M4VrLeftOuch_CD3A:
        clr.b X_SBYTE4(a0)
        bra.s M4VrOuch_CD78
M4VrRightOuch_CD47:
        move.b #$20,X_SBYTE4(a0)
        bra.s M4VrOuch_CD78
M4VrTopOuch_CD54:
        move.b #$40,X_SBYTE4(a0)
        jsr M4LcCollider
        move.l a2,d0
        beq.s M4VrTopFlash
        moveq #0,d0
        move.b 39(a2),d0
        jsr M4LevelDoColl
M4VrTopFlash:
        bset #SF_HITFLASH,49(a0)
        bset #2,31(a0)
M4VrOuch_CD78:
        clr.b 20(a0)
        move.b #16,X_SBYTE3(a0)
        bset #0,X_VRFL(a0)
        jmp M4LcStrategy
; bossBrobOuch_srou CD8A: (svar1, svar2) = 07:CCDA[sbyte4]; sbyte4 + 2;
; sbyte3 0 -> rotx -> 0 (Achase8_3), sflag5 off; else - 1, rotx + svar1,
; roty + svar2, every 16th gameframe a bosshmissile1 ($3A) rot + ((rnd&7)-3,
; (rnd&7)-3), al_ptr = player, sbyte3 0.
M4VrOuchSrou_CD8A:
        moveq #0,d1
        move.b X_SBYTE4(a0),d1
        lea M4VrOuchTab,a2
        move.b (a2,d1.w),d4
        move.b 1(a2,d1.w),d5
        addq.b #2,X_SBYTE4(a0)
        tst.b X_SBYTE3(a0)
        beq.s M4VrOuchEnd_CE3F
        subq.b #1,X_SBYTE3(a0)
        add.b d4,12(a0)
        add.b d5,13(a0)
        move.w M4_LV_GAMEFRAME,d0
        andi.w #15,d0
        bne.s M4VrOuchDone
        jsr M4IntroRandom
        andi.b #7,d0
        subq.b #3,d0
        move.b d0,d6
        jsr M4IntroRandom
        andi.b #7,d0
        subq.b #3,d0
        move.b d0,d7
        moveq #$3a,d0
        suba.l a3,a3
        bsr M4VrFire
        move.l a2,d0
        beq.s M4VrOuchDone
        move.w a1,X_ALPTR(a2)
        clr.b X_SBYTE3(a2)
M4VrOuchDone:
        rts
M4VrOuchEnd_CE3F:
        moveq #0,d1
        moveq #3,d2
        moveq #12,d4
        bsr M4VrRot
        bclr #0,X_VRFL(a0)
        rts

; ---------------------------------------------------------------------
; bossBrobsepexp_Istrat CA3F (expstrat from sep on): sbyte1 40, collstrat
; CC8B, sflag1, HP 2, colldisable (trigse $81, music $F0). CA7F: a large
; explosion (nopolyexp, addrnd2posy); above y -320: vy + 8, addvecs; ZD <
; 1300: addplayerZ; sbyte1 0 -> exp, else - 1, rotx -> 0, roty -> $80
; (Achase8_2).
M4VrSepExpI_CA3F:
        move.l #M4VrSepExp_CA7F,32(a0)
        move.b #40,36(a0)
        move.l #M4VrColl_CC8B,X_COLL(a0)
        bset #F2_SFLAG1,48(a0)
        move.b #2,38(a0)
        bset #SF_COLLDISABLE,49(a0)
M4VrSepExp_CA7F:
        bsr M4VrLexpRnd
        bsr M4VrLower
        bpl.s M4VrSepExpDist
        addq.w #8,8(a0)
        jsr M4EnMove
M4VrSepExpDist:
        bsr M4VrZD
        subi.w #1300,d0
        bpl.s M4VrSepExpCount
        bsr M4VrPZ
M4VrSepExpCount:
        tst.b 36(a0)
        beq.s M4VrExpInit_CAF1
        subq.b #1,36(a0)
        moveq #0,d1
        moveq #2,d2
        moveq #12,d4
        bsr M4VrRot
        move.b #$80,d1
        moveq #2,d2
        moveq #13,d4
        bsr M4VrRot
        moveq #0,d0
        rts
; bossBrobexp_init CAF1: halves boss_b_l (x + 152, count 5) and boss_b_r (x -
; 152, count 15) at y + 180, roty $80, strategy pwaitexp CBF2, expstrat
; CC61, HP $FF; the body becomes boss_b_H, count 25, expstrat CC3D; then
; pwaitexp at once.
M4VrExpInit_CAF1:
        move.w #M4VrShBL,d0
        move.w #$c814,d1
        move.w #152,d2
        moveq #5,d3
        bsr.s M4VrHalf
        move.w #M4VrShBR,d0
        move.w #$c830,d1
        move.w #-152,d2
        moveq #15,d3
        bsr.s M4VrHalf
        move.w #M4VrShBH,d0
        move.w #$c7f8,d1
        bsr M4VrShape
        move.b #25,19(a0)
        move.l #M4VrPWaitI_CBF2,32(a0)
        move.l #M4VrPExp2I_CC3D,X_EXP(a0)
        bra.s M4VrPWaitI_CBF2
M4VrHalf:
        bsr M4VrMake
        beq.s M4VrHalfDone
        bsr M4VrSetPhase
        move.l (a0),(a2)
        move.w 4(a0),4(a2)
        move.b #$80,13(a2)
        add.w d2,(a2)
        addi.w #180,2(a2)
        move.b d3,19(a2)
        move.l #M4VrPWaitI_CBF2,32(a2)
        move.l #M4VrPExpI_CC61,X_EXP(a2)
        move.b #$ff,38(a2)
M4VrHalfDone:
        rts
; bossBpwaitexp CBF2/CC07: HP $FF AP 10; even (gameframe + al1pt): a large
; explosion (nopolyexp, addrnd2posy); count - 1 = 0: colldisable, HP 0;
; addplayerZ.
M4VrPWaitI_CBF2:
        move.l #M4VrPWait_CC07,32(a0)
        move.b #$ff,38(a0)
        move.b #10,39(a0)
M4VrPWait_CC07:
        moveq #1,d1
        bsr M4VrPhase
        bne.s M4VrPWaitCount
        bsr M4VrLexpRnd
M4VrPWaitCount:
        subq.b #1,19(a0)
        bne.s M4VrPWaitMove
        bset #SF_COLLDISABLE,49(a0)
        clr.b 38(a0)
M4VrPWaitMove:
        bsr M4VrPZ
        moveq #0,d0
        rts
; bossBpexp2_Istrat CC3D (body, HP 0): gameflags bossdead; makebosscircexp
; 06:EC05 (trigse $1D; circleobj = nullshape 06:864B at the body,
; circleanim 1); huge explosion 06:EF0C; expstrat CC76.
M4VrPExp2I_CC3D:
        bset #2,M4_LP_GAMEFLAGS
        clr.w M4_SC_CIRCLEOBJ
        moveq #-1,d0
        jsr M4EnCreate
        beq.s M4VrPExp2NoCircle
        move.w a2,M4_SC_CIRCLEOBJ
        move.l #M4B1CircleObj,32(a2)
        move.l (a0),(a2)
        move.w 4(a0),4(a2)
M4VrPExp2NoCircle:
        move.w #1,M4_SC_CIRCLE
        move.w #M4_FX_HUGE,d0
        jsr M4B1Expl
        move.l #M4VrPExp_CC76,X_EXP(a0)
        bra.s M4VrPExp_CC76
; bossBpexp_Istrat CC61 (halves, HP 0): expstrat CC76, a large explosion.
M4VrPExpI_CC61:
        move.l #M4VrPExp_CC76,X_EXP(a0)
        bsr M4VrLexp
; bossBpexp_strat CC76: setremove_behind, rotz + 8, rotx + 4.
M4VrPExp_CC76:
        bset #3,45(a0)
        addq.b #8,14(a0)
        addq.b #4,12(a0)
        moveq #0,d0
        rts

; ---------------------------------------------------------------------
; bossBrobnextstate CF11: stratstate + 1 (> 8 signed -> 1); 1, 5 fireP1;
; 2 Pouncepos; 3, 6, 8 farjump1; 4 sep; 7 (and else) kick.
M4VrNextState_CF11:
        move.b X_STATE(a0),d0
        addq.b #1,d0
        move.b d0,d1
        subi.b #8,d1
        beq.s M4VrNextKeep
        bmi.s M4VrNextKeep
        moveq #1,d0
M4VrNextKeep:
        move.b d0,X_STATE(a0)
        cmpi.b #1,d0
        beq M4VrFireP1Init_C22F
        cmpi.b #2,d0
        beq M4VrPounceInit_C332
        cmpi.b #3,d0
        beq M4VrFarJ1Init_C844
        cmpi.b #4,d0
        beq M4VrSepInit_C519
        cmpi.b #5,d0
        beq M4VrFireP1Init_C22F
        cmpi.b #6,d0
        beq M4VrFarJ1Init_C844
        cmpi.b #7,d0
        beq M4VrKickInit_C787
        cmpi.b #8,d0
        beq M4VrFarJ1Init_C844
        bra M4VrKickInit_C787

; bossBOuch_tab 07:CCDA: (rotx, roty) steps; left 0, right $20, top $40.
M4VrOuchTab:
        incbin '../build/M4VrOuchTab.bin'
        even

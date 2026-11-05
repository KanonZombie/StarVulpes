; Space Armada unit (boss): mothership core boss boss8 07:919C (map 0D:B4FB,
; also 0D:E730 of Sector Z) and its parts. ROM USA rev0 (SHA-256
; 3857b529...a84d). Specification build/agent-armada/research/boss/SPEC.md
; (disassembly boss8_trace.txt / nucleus_trace.txt); port notes, oracle and
; tests in build/agent-armada-boss/ (INTEGRATION.md, armada-boss-oracle.py:
; ROM 65816 vs this 68000 code, tick by tick).
; Owner files: this file, level_armada_boss_strats.asm, level_armada_final*.asm,
; tools/stages/armada_boss.py. RAM: $FF9D80..$FF9DBF (M4_AB).
; Units: body 07:919C/9359/93BB/9422/9451/9539/95A6, death 07:95CA/9628;
; cover 07:972B/9776; emitters 07:9815/9864/992A; beam 07:9967/9998;
; launchers 08:9B15/9B3A/9B52/9BFA/9C94/9C6C; pillars 08:9CC1/9CF5; ring
; placement 08:9D07/9D36 (1F:CDF0 + 02:FC62); Shyper 0B:8CE1/8D00; shrapnel
; timer 07:99C3/99EC; shrap1 0B:FF2F/FF90.
; Not ported: sounds/music (03:B7E5, $1F48/$1F49). Deliberate: a cover
; without mother (al_ptr 0 after divorcefamily) reads DP $1E in the ROM; the
; port takes it as closed and does not write DP $1F (SPEC 3.3); the stray
; write of divorcefamily's mother branch to sflags4 of the caller's Y
; (1F:DBDB) is not reproduced.
M4_AB equ M4_AR+$80
M4_AB_BG2X equ M4_AB+0 ;.b bg2Xscroll $16A0 low byte (shake 07:9AF9; no port consumer)
M4_AB_END equ M4_AB+64
; Extended object fields (stage-free X offsets 38..55): original sflags2 /
; sflags3 bits that the port flags2 byte (48) does not hold.
X_AB_SF2 equ -$8000+44 ;.b sflags2 bit7 ($80): body open (07:9451); player leaving (ClearShip2 0B:9CB7)
X_AB_SF3 equ -$8000+45 ;.b sflags3 bit0 ($01): cover fully open, written into the body (07:97EF)

; ---------------------------------------------------------------------
; Helpers. a0 object, a1 player.

; d0 = shape header -> a2 created behind a0 (1F:D54B), X_SHAPEHDR = d0.
; Z set on failure.
M4AbCreate:
        movem.l d0-d1,-(sp)
        move.w d0,d1
        jsr M4LevelShapeIndex
        jsr M4EnCreate
        beq.s M4AbCreateFail
        move.w d1,X_SHAPEHDR(a2)
M4AbCreateFail:
        movem.l (sp)+,d0-d1
        cmpa.w #0,a2
        rts
; d0 = shape header on a0 (descriptor looked up only when it changes).
M4AbSetShape:
        cmp.w X_SHAPEHDR(a0),d0
        beq.s M4AbSetShapeDone
        move.w d0,X_SHAPEHDR(a0)
        jsr M4LevelShapeIndex
        jsr M4LevelSetShape
M4AbSetShapeDone:
        rts
; link_child 1F:D56F after a 1F:D54B creation: d0 header, d1.b id, d2.l
; Istrat -> a2 (sbyte1 = id, al_ptr = a0, sword1 0, appended to the sword1
; chain of a0, mother/child sflags4). A failure is the 1F:BDEE debug restart
; of the original: fatal level status here. Z set on failure. Clobbers d0/a3.
M4AbMakeChild:
        bsr M4AbCreate
        beq.s M4AbMakeChildFail
        move.l d2,32(a2)
        move.b d1,36(a2)
        move.w a0,X_ALPTR(a2)
        clr.w 40(a2)
        movea.l a0,a3
M4AbMakeChildTail:
        move.w 40(a3),d0
        beq.s M4AbMakeChildLink
        movea.w d0,a3
        bra.s M4AbMakeChildTail
M4AbMakeChildLink:
        move.w a2,40(a3)
        bset #6,X2_FL4(a0)
        bset #4,X2_FL4(a2)
        cmpa.w #0,a2
        rts
M4AbMakeChildFail:
        move.w #-1,M4_LV_STATUS
        move.w #$7d00,M4_LV_BADOP
        cmp.w d0,d0
        rts
; find_child 1F:DC40: d0.b id -> a2 child of a0 or 0 (Z set). d1 kept.
M4AbFind:
        move.l d1,-(sp)
        movea.l a0,a2
        jsr M4PvFindChild
        move.l (sp)+,d1
        cmpa.w #0,a2
        rts
; Z clear when an emitter (ids 2..4) lives with sflags2 $10 clear (07:9359,
; 07:94E8). Clobbers d0/d6/a2.
M4AbAnyOff:
        moveq #2,d6
M4AbAnyOffNext:
        move.b d6,d0
        bsr M4AbFind
        beq.s M4AbAnyOffSkip
        btst #F2_SFLAG1,48(a2)
        beq.s M4AbAnyOffFound
M4AbAnyOffSkip:
        addq.b #1,d6
        cmpi.b #5,d6
        bne.s M4AbAnyOffNext
        cmp.w d0,d0
        rts
M4AbAnyOffFound:
        moveq #1,d0
        rts
; Frame step of 07:9461-style code: a = v + delta (8 bits); a >= 0 -> a + n;
; a & $7F; a >= n -> a - n; | $80. d0.b value, d1.b delta, d2.b n.
M4AbStep:
        add.b d1,d0
        bmi.s M4AbStepNeg
        add.b d2,d0
M4AbStepNeg:
        andi.b #$7f,d0
        cmp.b d2,d0
        blo.s M4AbStepOk
        sub.b d2,d0
M4AbStepOk:
        ori.b #$80,d0
        rts
; sflags |= $02 (hit flash of the original), as M4LcHitFlash marks it.
M4AbFlash:
        bset #SF_HITFLASH,49(a0)
        bset #2,31(a0)
        rts
; nucleuswallrot 08:9D07 / 9D36: rot_cdf0(x 0, z sword2, sbyte2) ->
; x = -fc62(sword2, sin8[sbyte2]), z = 2 * fc62(sword2, cos8[sbyte2]) + d1
; (16-bit wrap; d1 = ring centre: player_posz + $500 or pviewposz + $690);
; then sbyte2 += V ($1551). Clobbers d0/d2/d4/a3.
M4AbWallRot:
        lea M4IntroShipSine,a3
        moveq #0,d2
        move.b 37(a0),d2
        move.b (a3,d2.w),d4
        ext.w d4
        move.w X_SWORD2(a0),d0
        jsr M4PvFc62
        neg.w d0
        move.w d0,(a0)
        move.b 64(a3,d2.w),d4
        ext.w d4
        move.w X_SWORD2(a0),d0
        jsr M4PvFc62
        add.w d0,d0
        add.w d1,d0
        move.w d0,4(a0)
        move.b M4_MV_1551,d0
        add.b d0,37(a0)
        rts
; DP $C3 viewposy as the strategies read it: the fixed camera position
; (viewtype bit1) or the last getview position.
M4AbViewY:
        move.w M4_LVW_POS+2,d0
        btst #1,M4_SC_VIEWTYPE
        beq.s M4AbViewYDone
        move.w M4_SC_VIEWPOS+2,d0
M4AbViewYDone:
        rts
; 1F:C951 / 1F:C963: d0 = shape header -> d1.w = objects of allst with it.
M4AbCountShape:
        movem.l d0/d2/a2,-(sp)
        jsr M4LevelShapeIndex
        moveq #0,d1
        move.w M4_LV_HEAD,d2
M4AbCountNext:
        tst.w d2
        beq.s M4AbCountDone
        movea.w d2,a2
        cmp.w 46(a2),d0
        bne.s M4AbCountSkip
        addq.w #1,d1
M4AbCountSkip:
        move.w X_NEXT(a2),d2
        bra.s M4AbCountNext
M4AbCountDone:
        movem.l (sp)+,d0/d2/a2
        rts
; addrnd2posy 06:EF67 on a2 (a failed creation is dummyobj in the original:
; the two random_l calls still happen), then sflags3 |= $40 (nopolyexp) and,
; when gameframe & 3 == 0, sflags2 &= ~$08 (with sound) (07:9666..96A5).
M4AbExpRandom:
        cmpa.w #0,a2
        beq.s M4AbExpRandomNone
        jsr M4FxRandomPos
        bset #F2_NOPOLYEXP,48(a2)
        move.w M4_LV_GAMEFRAME,d0
        andi.w #3,d0
        bne.s M4AbExpRandomDone
        bclr #F2_NOEXPSND,48(a2)
M4AbExpRandomDone:
        rts
M4AbExpRandomNone:
        jsr M4IntroRandom
        jmp M4IntroRandom
; 06:EFA0 on a2 (or dummyobj): x, y, z += 2 * s8(random_l), three calls.
M4AbRnd2xyz:
        moveq #0,d1
M4AbRnd2xyzNext:
        jsr M4IntroRandom
        ext.w d0
        add.w d0,d0
        cmpa.w #0,a2
        beq.s M4AbRnd2xyzSkip
        add.w d0,(a2,d1.w)
M4AbRnd2xyzSkip:
        addq.w #2,d1
        cmpi.w #6,d1
        bne.s M4AbRnd2xyzNext
        rts

; ---------------------------------------------------------------------
; Body boss8 07:919C: HP/AP 32/8 ($1FFF = 0) or 64/8, bar maximum = HP;
; collstrat 0, expstrat 07:95CA; cover (id 1, 07:972B) and emitters 2..4
; (07:9815) with positions and phases from 07:9266..9320, all collflags
; | $20; own collflags | $20 | $40, sbyte4 150, sflags2 &= ~$30, V = 0,
; animframe $80; then the common tick 93BB.
M4AbBody:
        moveq #$20,d0
        tst.b M4_GS_CURLEVEL
        beq.s M4AbBodyHp
        moveq #$40,d0
M4AbBodyHp:
        move.b d0,38(a0)
        move.b #8,39(a0)
        move.b d0,M4_BOSS_MAXHP
        clr.b M4_BOSS_HP
        move.l #M4AbBodyWait,32(a0)
        clr.l X_COLL(a0)
        move.l #M4AbBodyDie,X_EXP(a0)
        move.w #$c590,d0
        moveq #1,d1
        move.l #M4AbCover,d2
        bsr M4AbMakeChild
        beq.s M4AbBodyFail
        ori.b #$20,44(a2)
        lea M4AbEmitters,a4
        moveq #2,d1
        move.l #M4AbEmit,d2
M4AbBodyEmit:
        move.w #$c5e4,d0
        bsr M4AbMakeChild
        beq.s M4AbBodyFail
        ori.b #$20,44(a2)
        move.w (a4)+,2(a2)
        move.w #M4AbEmitterZ,4(a2)
        move.w (a4)+,d0
        move.b d0,37(a2)
        addq.b #1,d1
        cmpi.b #5,d1
        bne.s M4AbBodyEmit
        ori.b #$60,44(a0)
        move.b #150,X_SBYTE4(a0)
        bclr #F2_SFLAG1,48(a0)
        bclr #F2_SFLAG2,48(a0)
        clr.b M4_MV_1551
        move.b #$80,16(a0)
        bra M4AbBodyCommon
M4AbBodyFail:
        moveq #0,d0
        rts
M4AbEmitters: ;y, sbyte2 of ids 2, 3, 4 (07:9266..931E)
        include '../build/m4-armada-emitters.inc'

; wait 07:934C/9359: an emitter alive with sflags2 $10 clear -> common;
; else open 07:9422: collstrat hitflash, sbyte2 100, animframe $80.
M4AbBodyWaitInit:
        move.l #M4AbBodyWait,32(a0)
M4AbBodyWait:
        bsr M4AbAnyOff
        bne M4AbBodyCommon
        move.l #M4AbBodyOpen,32(a0)
        move.l #M4LcHitFlash,X_COLL(a0)
        move.b #100,37(a0)
        move.b #$80,16(a0)
; open 07:9451: sflags2 |= $80; cover fully open (sflags3 bit0) -> animframe
; min(+1, 14); gameframe & 31 = 25 or 30 -> Hplasma ($26) roty + $80,
; al_ptr = player. $1FFF = 0: stays open. Else sbyte2 counts 100 and any
; emitter switched off closes it.
M4AbBodyOpen:
        bset #7,X_AB_SF2(a0)
        btst #0,X_AB_SF3(a0)
        beq.s M4AbOpenFire
        move.b 16(a0),d0
        addq.b #1,d0
        bmi.s M4AbOpenAnim
        addi.b #15,d0
M4AbOpenAnim:
        andi.b #$7f,d0
        cmpi.b #15,d0
        blo.s M4AbOpenAnimSet
        moveq #14,d0
M4AbOpenAnimSet:
        ori.b #$80,d0
        move.b d0,16(a0)
M4AbOpenFire:
        move.w M4_LV_GAMEFRAME,d0
        andi.w #31,d0
        cmpi.w #25,d0
        beq.s M4AbOpenShot
        cmpi.w #30,d0
        bne.s M4AbOpenLevel
M4AbOpenShot:
        moveq #M4_WT_HPLASMA,d0
        moveq #0,d3
        moveq #0,d4
        moveq #0,d5
        moveq #0,d6
        moveq #0,d7
        move.b #$80,d7
        suba.l a3,a3
        jsr M4EnFire
        cmpa.w #0,a2
        beq.s M4AbOpenLevel ;dummyobj in the original
        move.w a1,X_ALPTR(a2)
M4AbOpenLevel:
        tst.b M4_GS_CURLEVEL
        beq M4AbBodyCommon
        tst.b 37(a0)
        beq.s M4AbBodyCloseInit
        subq.b #1,37(a0)
        bsr M4AbAnyOff
        beq M4AbBodyCommon
; close 07:9539: collstrat 0, sbyte2 15, emitters' sflags2 $10 cleared;
; closing 07:95A6: sflags2 &= $7F; cover closed -> animframe $80; sbyte2
; counts down, then wait (same tick).
M4AbBodyCloseInit:
        clr.l X_COLL(a0)
        move.l #M4AbBodyClose,32(a0)
        move.b #15,37(a0)
        moveq #2,d6
M4AbCloseOff:
        move.b d6,d0
        bsr M4AbFind
        beq.s M4AbCloseOffNext
        bclr #F2_SFLAG1,48(a2)
M4AbCloseOffNext:
        addq.b #1,d6
        cmpi.b #5,d6
        bne.s M4AbCloseOff
M4AbBodyClose:
        bclr #7,X_AB_SF2(a0)
        btst #0,X_AB_SF3(a0)
        bne.s M4AbCloseCount
        move.b #$80,16(a0)
M4AbCloseCount:
        tst.b 37(a0)
        beq M4AbBodyWaitInit
        subq.b #1,37(a0)
; common 07:93BB: z = $690 + player_posz; sbyte4 150-tick turn (sflags2 ^=
; $10); gameframe & 7 == 0: V -> -5 / +5 by 1; m_bossHP += HP.
M4AbBodyCommon:
        move.w M4_LP_POSZ,d0
        addi.w #$690,d0
        move.w d0,4(a0)
        subq.b #1,X_SBYTE4(a0)
        bne.s M4AbSpin
        move.b #150,X_SBYTE4(a0)
        bchg #F2_SFLAG1,48(a0)
M4AbSpin:
        move.w M4_LV_GAMEFRAME,d0
        andi.w #7,d0
        bne.s M4AbBar
        move.b M4_MV_1551,d0
        btst #F2_SFLAG1,48(a0)
        beq.s M4AbSpinUp
        cmpi.b #$fb,d0
        beq.s M4AbBar
        subq.b #1,M4_MV_1551
        bra.s M4AbBar
M4AbSpinUp:
        cmpi.b #5,d0
        beq.s M4AbBar
        addq.b #1,M4_MV_1551
M4AbBar:
        move.b 38(a0),d0
        add.b d0,M4_BOSS_HP
        moveq #0,d0
        rts

; Death 07:95CA (expstrat, first tick with HP 0): expstrat 07:9628,
; gameflags |= $04 (bossdead) | $80 (stagedone), sbyte2 30, pshipflags |=
; $60; first time: bossflags dying, pstratflags notdie, pshipflags $40.
M4AbBodyDie:
        move.l #M4AbBodyDying,X_EXP(a0)
        bset #2,M4_LP_GAMEFLAGS
        move.b #30,37(a0)
        ori.b #$60,M4_LP_PSF
        bset #7,M4_LP_GAMEFLAGS
        tst.b M4_BOSS_DYING
        bne.s M4AbBodyDying
        st M4_BOSS_DYING
        bset #5,M4_BOSS_PSTRATF
        bset #6,M4_LP_PSF
; Agony 07:9628: player y/x Achase16_3 toward -40 / 0 (1F:D6AB); even
; gameframe: hit flash, medium and large explosions (06:EEEE/EEDF +
; addrnd2posy, nopolyexp, sound every 4th), a Shyper line (BF8C, 0B:8CE1:
; colldisable, speed 40, body position, y = viewposy, roty $80, rotz =
; random). sbyte2 counts 30, then a shrapnel timer (ACA1, 07:99C3) and
; bigexplode 06:F0D0; else the common tick.
M4AbBodyDying:
        move.w 2(a1),d0
        moveq #-40,d1
        moveq #3,d2
        jsr M4LpAchase
        move.w d0,2(a1)
        move.w (a1),d0
        moveq #0,d1
        moveq #3,d2
        jsr M4LpAchase
        move.w d0,(a1)
        btst #0,M4_LV_GAMEFRAME+1
        bne.s M4AbDyingCount
        bsr M4AbFlash
        jsr M4FxMedium
        bsr M4AbExpRandom
        jsr M4FxLarge
        cmpa.w #0,a2
        bsr M4AbExpRandom
        move.w #$bf8c,d0
        bsr M4AbCreate
        beq.s M4AbDyingCount
        bset #SF_COLLDISABLE,49(a2)
        move.l #M4AbShyper,32(a2)
        move.b #40,15(a2)
        move.l (a0),(a2)
        move.w 4(a0),4(a2)
        bsr M4AbViewY
        move.w d0,2(a2)
        move.b #$80,13(a2)
        jsr M4IntroRandom
        move.b d0,14(a2)
M4AbDyingCount:
        subq.b #1,37(a0)
        bne M4AbBodyCommon
        move.w #$aca1,d0
        bsr M4AbCreate
        beq.s M4AbDyingBig
        move.l #M4AbTimer,32(a2)
M4AbDyingBig:
        jsr M4FxBigExplode
        move.l #M4AbBodyDelay,32(a0)
        move.l #M4AbBodyExplode,X_EXP(a0)
        rts
; delayexplode 06:EE38 after bigexplode (as M4FxDelayTick), ending in
; explode_Istrat 06:F45F, whose divorcefamily 1F:DBA4 (mother branch) frees
; the remaining children first.
M4AbBodyDelay:
        bset #SF_HITFLASH,49(a0)
        subq.b #1,19(a0)
        bpl.s M4AbBodyDelayWait
        bset #SF_COLLDISABLE,49(a0)
        clr.b 38(a0)
M4AbBodyExplode:
        bsr M4AbDivorceMother
        jmp M4LevelExplode
M4AbBodyDelayWait:
        btst #F2_RELEXPLODE,48(a0)
        beq.s M4AbBodyDelayStay
        jsr M4EnAddPZ
M4AbBodyDelayStay:
        moveq #0,d0
        rts
; 1F:DBD1..DC24: n = length of the sword1 chain; for id = n..1: find_child
; -> child flag cleared, al_ptr = 0 (the chain itself is kept).
M4AbDivorceMother:
        btst #6,X2_FL4(a0)
        beq.s M4AbDivorceDone
        moveq #0,d6
        movea.l a0,a2
M4AbDivorceCount:
        move.w 40(a2),d0
        beq.s M4AbDivorceIds
        addq.b #1,d6
        movea.w d0,a2
        bra.s M4AbDivorceCount
M4AbDivorceIds:
        tst.b d6
        beq.s M4AbDivorceDone
M4AbDivorceNext:
        move.b d6,d0
        bsr M4AbFind
        beq.s M4AbDivorceSkip
        bclr #4,X2_FL4(a2)
        clr.w X_ALPTR(a2)
M4AbDivorceSkip:
        subq.b #1,d6
        bne.s M4AbDivorceNext
M4AbDivorceDone:
        rts

; ---------------------------------------------------------------------
; Cover 07:972B: collstrat 0, expstrat explode, HP $FF / AP 10, mother's
; position, y 400, collflags | $40, animframe $80. Tick 07:9776: mother open
; (sflags2 $80): shape C5AC, frame 17 -> mother sflags3 |= 1, else +1 mod 18;
; closed: frame 0 -> shape C590 and mother sflags3 &= ~1, else -1 mod 18.
; roty += V; z = $690 + player_posz.
M4AbCover:
        move.l #M4AbCoverTick,32(a0)
        clr.l X_COLL(a0)
        move.l #M4LevelExplode,X_EXP(a0)
        move.b #$ff,38(a0)
        move.b #10,39(a0)
        move.w X_ALPTR(a0),d0
        beq.s M4AbCoverY
        movea.w d0,a2
        move.l (a2),(a0)
        move.w 4(a2),4(a0)
M4AbCoverY:
        move.w #400,2(a0)
        ori.b #$40,44(a0)
        move.b #$80,16(a0)
M4AbCoverTick:
        move.w X_ALPTR(a0),d0
        beq.s M4AbCoverClosed
        movea.w d0,a2
        btst #7,X_AB_SF2(a2)
        beq.s M4AbCoverClosed
        move.w #$c5ac,d0
        bsr M4AbSetShape
        move.b 16(a0),d0
        andi.b #$7f,d0
        cmpi.b #$11,d0
        bne.s M4AbCoverOpening
        move.w X_ALPTR(a0),d0
        movea.w d0,a2
        bset #0,X_AB_SF3(a2)
        bra.s M4AbCoverSpin
M4AbCoverOpening:
        move.b 16(a0),d0
        moveq #1,d1
        moveq #18,d2
        bsr M4AbStep
        move.b d0,16(a0)
        bra.s M4AbCoverSpin
M4AbCoverClosed:
        move.b 16(a0),d0
        andi.b #$7f,d0
        bne.s M4AbCoverClosing
        move.w #$c590,d0
        bsr M4AbSetShape
        move.w X_ALPTR(a0),d0
        beq.s M4AbCoverSpin
        movea.w d0,a2
        bclr #0,X_AB_SF3(a2)
        bra.s M4AbCoverSpin
M4AbCoverClosing:
        move.b 16(a0),d0
        moveq #-1,d1
        moveq #18,d2
        bsr M4AbStep
        move.b d0,16(a0)
M4AbCoverSpin:
        move.b M4_MV_1551,d0
        add.b d0,13(a0)
        move.w M4_LP_POSZ,d0
        addi.w #$690,d0
        move.w d0,4(a0)
        moveq #0,d0
        rts

; ---------------------------------------------------------------------
; Emitter 07:9815: collstrat 07:992A, expstrat explode, HP $FF / AP 8,
; sword2 1200, no zremove, collflags | $40, sbyte3 50, nohitaffect; not
; placed on its creation tick.
M4AbEmit:
        move.l #M4AbEmitTick,32(a0)
        move.l #M4AbEmitColl,X_COLL(a0)
        move.l #M4AbEmitExplode,X_EXP(a0)
        move.b #$ff,38(a0)
        move.b #8,39(a0)
        move.w #1200,X_SWORD2(a0)
        bclr #3,45(a0)
        ori.b #$40,44(a0)
        move.b #50,X_SBYTE3(a0)
        bset #SF_NOHITAFFECT,49(a0)
        moveq #0,d0
        rts
; 07:9864: sbyte4 ticks of colldisable after a hit; 49 waiting ticks
; (sbyte3); then nohitaffect off; bossdead -> explode; switched on
; (sflags2 $10): colframe 4|$80; else colframe +1 mod 4 and every 4th tick
; a beam (C600, 07:9967) with sbyte2/sword2/position/roty of the emitter.
; Placement 9D07 (centre player_posz + $500), roty = sbyte2 + $80.
M4AbEmitTick:
        tst.b X_SBYTE4(a0)
        beq.s M4AbEmitCollOn
        subq.b #1,X_SBYTE4(a0)
        bset #SF_COLLDISABLE,49(a0)
        bra.s M4AbEmitWait
M4AbEmitCollOn:
        bclr #SF_COLLDISABLE,49(a0)
M4AbEmitWait:
        subq.b #1,X_SBYTE3(a0)
        bne.s M4AbEmitIdle
        move.b #1,X_SBYTE3(a0)
        bclr #SF_NOHITAFFECT,49(a0)
        btst #2,M4_LP_GAMEFLAGS
        bne M4AbEmitExplode
        btst #F2_SFLAG1,48(a0)
        bne.s M4AbEmitIdle
        move.b 18(a0),d0
        moveq #1,d1
        moveq #4,d2
        bsr M4AbStep
        move.b d0,18(a0)
        move.w M4_LV_GAMEFRAME,d0
        andi.w #3,d0
        bne.s M4AbEmitPlace
        move.w #$c600,d0
        bsr M4AbCreate
        beq.s M4AbEmitIdle
        move.b 37(a0),37(a2)
        move.w X_SWORD2(a0),X_SWORD2(a2)
        move.l #M4AbBeam,32(a2)
        move.l (a0),(a2)
        move.w 4(a0),4(a2)
        move.b 13(a0),13(a2)
        bra.s M4AbEmitPlace
M4AbEmitIdle:
        move.b #$84,18(a0)
M4AbEmitPlace:
        move.w M4_LP_POSZ,d1
        addi.w #$500,d1
        bsr M4AbWallRot
        move.b 37(a0),d0
        addi.b #$80,d0
        move.b d0,13(a0)
        moveq #0,d0
        rts
; 07:992A: collide cleared, hit flash, sflags2 ^= $10 (switch), sbyte4 10;
; $1FFF = 0 -> explode; else the strategy (1F:DC25). The nohitaffect bit is
; not consulted (SPEC 3.4).
M4AbEmitColl:
        bclr #SF_COLLIDE,49(a0)
        bsr M4AbFlash
        bchg #F2_SFLAG1,48(a0)
        move.b #10,X_SBYTE4(a0)
        tst.b M4_GS_CURLEVEL
        beq M4AbEmitExplode
        jmp M4LcStrategy
; explode_Istrat 06:F45F of a child: divorcefamily 1F:DBA4 (child branch)
; first, so the body sees it gone this tick.
M4AbEmitExplode:
        btst #4,X2_FL4(a0)
        beq.s M4AbEmitExplodeNow
        movea.l a0,a2
        jsr M4PvDivorce
M4AbEmitExplodeNow:
        jmp M4LevelExplode

; Beam 07:9967: no pointers (1F:D450), HP $FF / AP 8, collflags | $08 |
; $40 | $20, no zremove. 07:9998: placement 9D36 (centre pviewposz +
; $690), roty = sbyte2 + $80, sword2 - 50; N(sword2 - 800) -> removed.
M4AbBeam:
        move.l #M4AbBeamTick,32(a0)
        clr.l X_COLL(a0)
        clr.l X_EXP(a0)
        move.b #$ff,38(a0)
        move.b #8,39(a0)
        ori.b #$68,44(a0)
        bclr #3,45(a0)
M4AbBeamTick:
        move.w M4_LP_PVIEWZ,d1
        addi.w #$690,d1
        bsr M4AbWallRot
        move.b 37(a0),d0
        addi.b #$80,d0
        move.b d0,13(a0)
        subi.w #50,X_SWORD2(a0)
        move.w X_SWORD2(a0),d0
        subi.w #800,d0
        bmi.s M4AbRemove
        moveq #0,d0
        rts
M4AbRemove:
        moveq #1,d0
        rts

; ---------------------------------------------------------------------
; Launcher 08:9B15: HP $FF / AP 8, sword2 1200, no zremove, sbyte3 =
; random_l & 5, collflags | $40. 9B3A: animframe $80, normal pointers
; (1F:D41A). 9B52: player behind (N(pz - z)), 700 <= |x| <= 900 (abs16),
; |px - x| < 200, no kamiHmissile1 alive ($1FFF = 0; else fewer than two):
; sbyte3 counts down, then 9BFA opens (+1 mod 4); at frame 3 kamiHmissile1
; ($16) with roty $80 (restored), al_ptr = player, sflags2 |= $10; 9C94
; closes (sbyte3 5, -1 mod 4), back to 9B3A (same tick) at frame 0.
; 9C6C: placement 9D07, roty = sbyte2 + $80; bossdead -> explode.
M4AbLauncher:
        move.b #$ff,38(a0)
        move.b #8,39(a0)
        move.w #1200,X_SWORD2(a0)
        bclr #3,45(a0)
        jsr M4IntroRandom
        andi.b #5,d0
        move.b d0,X_SBYTE3(a0)
        ori.b #$40,44(a0)
M4AbLaunchRest:
        move.b #$80,16(a0)
        move.l #M4AbLaunchWatch,32(a0)
        move.l #M4LcHitFlash,X_COLL(a0)
        move.l #M4LevelExplode,X_EXP(a0)
M4AbLaunchWatch:
        move.w 4(a1),d0
        sub.w 4(a0),d0
        bpl M4AbLaunchPlace
        move.w (a0),d0
        bpl.s M4AbLaunchAbs
        neg.w d0
M4AbLaunchAbs:
        move.w d0,d1
        subi.w #700,d1
        bmi M4AbLaunchPlace
        subi.w #900,d0
        beq.s M4AbLaunchNear
        bpl M4AbLaunchPlace
M4AbLaunchNear:
        move.w (a1),d0
        sub.w (a0),d0
        bpl.s M4AbLaunchDx
        neg.w d0
M4AbLaunchDx:
        subi.w #200,d0
        bpl M4AbLaunchPlace
        move.w #$c7dc,d0
        bsr M4AbCountShape
        tst.b M4_GS_CURLEVEL
        bne.s M4AbLaunchTwo
        tst.w d1
        bne M4AbLaunchPlace
        bra.s M4AbLaunchCount
M4AbLaunchTwo:
        cmpi.w #2,d1
        beq M4AbLaunchPlace
M4AbLaunchCount:
        subq.b #1,X_SBYTE3(a0)
        bne M4AbLaunchPlace
        move.l #M4AbLaunchOpen,32(a0)
M4AbLaunchOpen:
        move.b 16(a0),d0
        moveq #1,d1
        moveq #4,d2
        bsr M4AbStep
        move.b d0,16(a0)
        andi.b #$7f,d0
        cmpi.b #3,d0
        bne M4AbLaunchPlace
        move.b 13(a0),-(sp)
        move.b #$80,13(a0)
        moveq #M4_WT_KAMI,d0
        moveq #0,d3
        moveq #0,d4
        moveq #0,d5
        moveq #0,d6
        moveq #0,d7
        suba.l a3,a3
        jsr M4EnFire
        move.b (sp)+,13(a0)
        cmpa.w #0,a2
        beq.s M4AbLaunchCloseInit ;dummyobj in the original
        move.w a1,X_ALPTR(a2)
        bset #F2_SFLAG1,48(a2)
M4AbLaunchCloseInit:
        move.l #M4AbLaunchClose,32(a0)
M4AbLaunchClose:
        move.b #5,X_SBYTE3(a0)
        move.b 16(a0),d0
        moveq #-1,d1
        moveq #4,d2
        bsr M4AbStep
        move.b d0,16(a0)
        andi.b #$7f,d0
        beq M4AbLaunchRest
M4AbLaunchPlace:
        move.w M4_LP_POSZ,d1
        addi.w #$500,d1
        bsr M4AbWallRot
        move.b 37(a0),d0
        addi.b #$80,d0
        move.b d0,13(a0)
        btst #2,M4_LP_GAMEFLAGS
        bne.s M4AbLaunchDie
        moveq #0,d0
        rts
M4AbLaunchDie:
        jmp M4LevelExplode

; Pillar 08:9CC1: no pointers, HP $FF / AP 8, sword2 1200, no zremove,
; colldisable, collflags | $40. 08:9CF5: y 400, placement 9D07, roty =
; sbyte2 (no $80, no bossdead test).
M4AbPillar:
        move.l #M4AbPillarTick,32(a0)
        clr.l X_COLL(a0)
        clr.l X_EXP(a0)
        move.b #$ff,38(a0)
        move.b #8,39(a0)
        move.w #1200,X_SWORD2(a0)
        bclr #3,45(a0)
        bset #SF_COLLDISABLE,49(a0)
        ori.b #$40,44(a0)
M4AbPillarTick:
        move.w #400,2(a0)
        move.w M4_LP_POSZ,d1
        addi.w #$500,d1
        bsr M4AbWallRot
        move.b 37(a0),13(a0)
        moveq #0,d0
        rts

; ---------------------------------------------------------------------
; Shyper 0B:8CE1: v = 4 * gen3d(vel, rotx, roty) (1F:D5D4), then every tick
; (0B:8D00) pos += v, z += pviewvelz. Removed by zremove only.
M4AbShyper:
        move.l #M4AbShyperTick,32(a0)
        jsr M4EnGen3d
        lea 6(a0),a2
        moveq #2,d1
M4AbShyperVec:
        move.w (a2),d0
        add.w d0,d0
        add.w d0,d0
        move.w d0,(a2)+
        dbra d1,M4AbShyperVec
M4AbShyperTick:
        jsr M4EnMove
        jsr M4EnAddPZ
        moveq #0,d0
        rts

; Shrapnel timer 07:99C3: no pointers, HP $FF / AP 8, colldisable, no
; zremove, sbyte1 50. 07:99EC: position = pviewpos + (0, 0, 1000); after 50
; ticks a huge explosion (06:EF0C) every tick at z - 1000, nopolyexp, x/y +=
; (rnd & $7F) - $3F, third random_l unused; gameframe & 7 == 0: shrap1
; (C638, 0B:FF2F); even gameframe: large explosion + 06:EFA0; shake:
; bg2Xscroll lo = rnd & 7, bg2Yscroll lo = (rnd & 3) + $F8.
M4AbTimer:
        move.l #M4AbTimerTick,32(a0)
        clr.l X_COLL(a0)
        clr.l X_EXP(a0)
        move.b #$ff,38(a0)
        move.b #8,39(a0)
        bset #SF_COLLDISABLE,49(a0)
        bclr #3,45(a0)
        move.b #50,36(a0)
M4AbTimerTick:
        move.w M4_LP_PVIEWX,(a0)
        move.w M4_LP_PVIEWY,2(a0)
        move.w M4_LP_PVIEWZ,d0
        addi.w #1000,d0
        move.w d0,4(a0)
        tst.b 36(a0)
        beq.s M4AbTimerHuge
        subq.b #1,36(a0)
        bra.s M4AbTimerShrap
M4AbTimerHuge:
        jsr M4FxHuge
        cmpa.w #0,a2
        beq.s M4AbTimerHugeOff
        subi.w #1000,4(a2)
        bset #F2_NOPOLYEXP,48(a2)
M4AbTimerHugeOff:
        moveq #0,d1
M4AbTimerHugeXY:
        jsr M4IntroRandom
        andi.w #$7f,d0
        subi.w #$3f,d0
        cmpa.w #0,a2
        beq.s M4AbTimerHugeSkip
        add.w d0,(a2,d1.w)
M4AbTimerHugeSkip:
        addq.w #2,d1
        cmpi.w #4,d1
        bne.s M4AbTimerHugeXY
        jsr M4IntroRandom ;z += (rnd & 0) - 0
M4AbTimerShrap:
        move.w M4_LV_GAMEFRAME,d0
        andi.w #7,d0
        bne.s M4AbTimerLarge
        move.w #$c638,d0
        bsr M4AbCreate
        beq.s M4AbTimerLarge
        move.l #M4AbShrap,32(a2)
M4AbTimerLarge:
        btst #0,M4_LV_GAMEFRAME+1
        bne.s M4AbTimerShake
        jsr M4FxLarge
        cmpa.w #0,a2
        bsr M4AbRnd2xyz
M4AbTimerShake:
        jsr M4IntroRandom
        andi.b #7,d0
        move.b d0,M4_AB_BG2X
        jsr M4IntroRandom
        andi.b #3,d0
        addi.b #$f8,d0
        move.b d0,M4_SC_BG2Y+1
        moveq #0,d0
        rts

; shrap1 0B:FF2F: y = pviewposy - 500, colldisable, count 26, x = rnd - 128
; + pviewposx, sword1 = 2 * rnd, roty = rnd. 0B:FF90: z = pviewposz + 300 +
; sword1, y + 35, count - 1 -> removed at 0.
M4AbShrap:
        move.l #M4AbShrapTick,32(a0)
        move.w M4_LP_PVIEWY,d0
        subi.w #500,d0
        move.w d0,2(a0)
        bset #SF_COLLDISABLE,49(a0)
        move.b #26,19(a0)
        jsr M4IntroRandom
        subi.w #$80,d0
        add.w M4_LP_PVIEWX,d0
        move.w d0,(a0)
        jsr M4IntroRandom
        add.w d0,d0
        move.w d0,40(a0)
        jsr M4IntroRandom
        move.b d0,13(a0)
M4AbShrapTick:
        move.w M4_LP_PVIEWZ,d0
        addi.w #300,d0
        add.w 40(a0),d0
        move.w d0,4(a0)
        addi.w #35,2(a0)
        subq.b #1,19(a0)
        beq M4AbRemove
        moveq #0,d0
        rts

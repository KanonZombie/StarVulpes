; Fortuna boss: chicken_istrat 09:B31D (map 05:9F55 mapqobj2, body boss_d_1
; B99F), its pieces built by the arm engine arm_istrat 09:A3FB (necks B967,
; heads B983, tail segments B8F7 / bulge B913 and tail end B9BB, ported in
; level_sectors.asm), the wings 09:C046 (BA47 / BA63), the egg 09:BCD9
; (B059 -> BA2B), shell 09:BE5A (BA0F), chick 09:BE0C (B9D7), nothing
; 09:BE46 and the head fire firebreathe 09:BE97 (AD2D, level_titania.asm).
; Authority: ref/Star Fox (USA).sfc (rev0, SHA-256 3857b529...a84d), flow
; disassembly build/agent-sectors/dis/09_B31D.txt .. 09_C046.txt; names from
; UltraStarFox STRAT/DSTRATS.ASM, whose constants differ in places (the egg
; opens when FAR from the player, random_l >= $FC lays it): the ROM wins.
; Flags as level_sectors.asm (X_WFLAGS): sflag3 $1E $40 bit0, sflag5 $1F $01
; bit1, sflag6 $1F $02 bit2 (SXF_TAIL), sflag4 $1E $80 bit7; sflag1/2 = F2.
; Mode table 09:B3AF (dispatch 09:C027, stratstate $1CDC = X_STATE): 30
; entries; flyaway_mode (31..37) has no writer in the ROM code or maps and is
; not ported. Body pointers: al_ptr / sword1 (40.w) necks, sword2 (42.w)
; tail, sWPx1 / sWPy1 (X_WPX / X_WPY) wings. A null piece pointer is skipped
; where the ROM would write through it (object 0) [H, not reached].
CK_HEAD equ $b983 ;boss_d_0
CK_TAIL equ $b9bb ;boss_d_2
CK_BODY equ $b99f ;boss_d_1
CK_NECK equ $b967
CK_ARM equ $b8f7
SXF_S4 equ 7
SXF_S6 equ SXF_TAIL

; 09:B31D: m_bossmaxHP $40, armmode $80, collstrat hitflash 06:89A3,
; expstrat 09:BC95, HP $40 AP 8, count $10, count1 0, sflag6, no zremove,
; animframe $80, shadow, enemy1; the pieces (09:B9E2); a failed creation
; keeps this Istrat for the next tick. Then stratstate 0 and the dispatch.
M4CkChicken:
        move.b #$40,M4_BOSS_MAXHP
        move.b #$80,M4_SX_ARMMODE
        move.l #M4LcHitFlash,X_COLL(a0)
        move.l #M4CkExplode,X_EXP(a0)
        move.b #$40,38(a0)
        move.b #8,39(a0)
        move.b #$10,19(a0)
        clr.b X_COUNT1(a0)
        bset #SXF_S6,X_WFLAGS(a0)
        bclr #3,45(a0)
        move.b #$80,16(a0)
        bset #F2_SHADOW,48(a0)
        ori.b #CF_ENEMY1,44(a0)
        bsr M4CkGenerate
        beq.s M4CkChickenOk
        moveq #0,d0
        rts
M4CkChickenOk:
        move.l #M4CkStrat,32(a0)
        clr.b X_STATE(a0)
; 09:B39E: the entry of mode stratstate (table 09:B3AF).
M4CkStrat:
        moveq #0,d0
        move.b X_STATE(a0),d0
        add.w d0,d0
        add.w d0,d0
        lea M4CkModes(pc),a2
        movea.l (a2,d0.w),a2
        jmp (a2)
M4CkModes:
        dc.l M4CkFold,M4CkSit,M4CkWait600,M4CkGetUp,M4CkUnfold
        dc.l M4CkComeTurn,M4CkGoTurn,M4CkFold,M4CkComeTurn,M4CkStartTurn
        dc.l M4CkEndTurn,M4CkMoveABit,M4CkUnfold,M4CkWaitABit,M4CkJump
        dc.l M4CkWait600,M4CkFold,M4CkGetUp,M4CkWaitABit,M4CkGoTurn
        dc.l M4CkStartTurn,M4CkEndTurn,M4CkSit,M4CkBlaze,M4CkGetUp
        dc.l M4CkAttack,M4CkWaitABit,M4CkComeTurn,M4CkGoTurn,M4CkRepeat

; 09:B46C nxtmode_srou: strategy B39E, stratstate + 1. 09:B457 / B45E: then
; .move / .nomove.
M4CkNextMove:
        bsr.s M4CkNext
        bra M4CkMove
M4CkNextStay:
        bsr.s M4CkNext
        bra M4CkNoMove
M4CkNext:
        move.l #M4CkStrat,32(a0)
        addq.b #1,X_STATE(a0)
        rts
; .repeat 09:B399: stratstate 0 and the dispatch again.
M4CkRepeat:
        clr.b X_STATE(a0)
        bra M4CkStrat

; .cometurn 09:B443: sflag3 set and sflag1 clear -> next mode; .move.
M4CkComeTurn:
        btst #SXF_S3,X_WFLAGS(a0)
        beq M4CkMove
        btst #F2_SFLAG1,48(a0)
        bne M4CkMove
        bra.s M4CkNextMove
; .goturn 09:B480: sflag3 clear and sflag1 clear -> next mode; .move.
M4CkGoTurn:
        btst #SXF_S3,X_WFLAGS(a0)
        bne M4CkMove
        btst #F2_SFLAG1,48(a0)
        beq.s M4CkNextMove
        bra M4CkMove
; .startturn 09:B61D: sflag3 toggles, next mode, .move.
M4CkStartTurn:
        bchg #SXF_S3,X_WFLAGS(a0)
        bra.s M4CkNextMove
; .endturn 09:B627: sflag1 clear -> next mode; .move.
M4CkEndTurn:
        btst #F2_SFLAG1,48(a0)
        beq.s M4CkNextMove
        bra M4CkMove
; .moveabit 09:B53A: sbyte1 + 1; >= 20 -> next mode; .move.
M4CkMoveABit:
        addq.b #1,36(a0)
        cmpi.b #20,36(a0)
        bhs.s M4CkNextMove
        bra M4CkMove
; .waitabit 09:B54B: animframe $80, sbyte2 / sbyte4 0, armmode bit0 off,
; sbyte1 10, strategy B573: sbyte1 0 -> next mode, else - 1; .nomove.
M4CkWaitABit:
        move.b #$80,16(a0)
        clr.b 37(a0)
        clr.b X_SBYTE4(a0)
        bclr #0,M4_SX_ARMMODE
        move.b #10,36(a0)
        move.l #M4CkWaitTick,32(a0)
M4CkWaitTick:
        tst.b 36(a0)
        beq M4CkNextStay
        subq.b #1,36(a0)
        bra M4CkNoMove
; .fireblaze 09:B581: sflag4 toggles, strategy B59C, armmode bit0 (the
; heads breathe fire); B59C: |pz - z| < 1500 -> next mode; .nomove.
M4CkBlaze:
        bchg #SXF_S4,X_WFLAGS(a0)
        move.l #M4CkBlazeTick,32(a0)
        bset #0,M4_SX_ARMMODE
M4CkBlazeTick:
        move.w #1500,d0
        bra.s M4CkWaitZ
; .waitfor600z 09:B5AE: |pz - z| < 600 -> next mode; .nomove.
M4CkWait600:
        move.w #600,d0
M4CkWaitZ:
        bsr M4SxDzLess
        bne M4CkNextStay
        bra M4CkNoMove
; .sitdown 09:B635 (s_add_anim 1, 13, start 10): f = animframe + 1, below
; 10 (8-bit N of f - 10) -> 10; f & $7F >= 13 -> 12 and next mode; .nomove.
M4CkSit:
        move.b 16(a0),d0
        addq.b #1,d0
        move.b d0,d1
        subi.b #10,d1
        bmi.s M4CkSitKeep
        moveq #10,d0
M4CkSitKeep:
        andi.b #$7f,d0
        cmpi.b #13,d0
        blo.s M4CkSitSet
        move.b #$80+12,16(a0)
        bra M4CkNextStay
M4CkSitSet:
        ori.b #$80,d0
        move.b d0,16(a0)
        bra M4CkNoMove
; .getup 09:B65B: animframe & $7F < 7 (N) -> next mode; else -1 mod 12,
; reaching 7 -> next mode; .nomove.
M4CkGetUp:
        move.b 16(a0),d0
        andi.b #$7f,d0
        subq.b #7,d0
        bmi M4CkNextStay
        move.b 16(a0),d0
        moveq #-1,d1
        moveq #12,d2
        jsr M4WpAddAnim
        move.b d0,16(a0)
        andi.b #$7f,d0
        cmpi.b #7,d0
        beq M4CkNextStay
        bra M4CkNoMove
; .foldwings / .unfoldwings 09:B67E / B697: sflag1 of both wings; next mode.
M4CkFold:
        move.w X_WPX(a0),d0
        beq.s M4CkFold2
        movea.w d0,a3
        bset #F2_SFLAG1,48(a3)
M4CkFold2:
        move.w X_WPY(a0),d0
        beq M4CkNextStay
        movea.w d0,a3
        bset #F2_SFLAG1,48(a3)
        bra M4CkNextStay
M4CkUnfold:
        move.w X_WPX(a0),d0
        beq.s M4CkUnfold2
        movea.w d0,a3
        bclr #F2_SFLAG1,48(a3)
M4CkUnfold2:
        move.w X_WPY(a0),d0
        beq M4CkNextStay
        movea.w d0,a3
        bclr #F2_SFLAG1,48(a3)
        bra M4CkNextStay
; .jump 09:B4B2: animframe $87, strategy B4C6: +8 clamped at 9 (s_add_anim
; 8, 10); |pz - z| < 600 -> .leap B4F5 (strategy B511, trigse $3B, vy -60);
; B511: addplayerZ, z + 40, y + vy, dfallyvec (landed: next mode); .nomove.
M4CkJump:
        move.b #$87,16(a0)
        move.l #M4CkJumpTick,32(a0)
M4CkJumpTick:
        move.b 16(a0),d0
        addq.b #8,d0
        bmi.s M4CkJumpMask
        addi.b #10,d0
M4CkJumpMask:
        andi.b #$7f,d0
        cmpi.b #10,d0
        blo.s M4CkJumpSet
        moveq #9,d0
M4CkJumpSet:
        ori.b #$80,d0
        move.b d0,16(a0)
        move.w #600,d0
        bsr M4SxDzLess
        beq M4CkNoMove
        move.l #M4CkLeap,32(a0)
        M4PlaySfx $3b
        move.w #-60,8(a0)
M4CkLeap:
        jsr M4EnAddPZ
        addi.w #40,4(a0)
        move.w 8(a0),d0
        add.w d0,2(a0)
        jsr M4V3FallYVec
        bcs M4CkNextStay
        bra M4CkNoMove
; .attack 09:B5C0: sbyte1 200, strategy B5D1: every 32 gameframes sflag5
; toggles; animframe -1 mod 8; addplayerZ; sbyte1 0 -> next mode (.move);
; else - 1; below 160 the heads strike: sbyte2 / sbyte4 = +-16 by sflag5.
M4CkAttack:
        move.b #200,36(a0)
        move.l #M4CkAttackTick,32(a0)
M4CkAttackTick:
        moveq #31,d0
        and.w M4_LV_GAMEFRAME,d0
        bne.s M4CkAttackAnim
        bchg #SXF_S5,X_WFLAGS(a0)
M4CkAttackAnim:
        move.b 16(a0),d0
        moveq #-1,d1
        moveq #8,d2
        jsr M4WpAddAnim
        move.b d0,16(a0)
        jsr M4EnAddPZ
        tst.b 36(a0)
        beq M4CkNextMove
        subq.b #1,36(a0)
        cmpi.b #160,36(a0)
        bhs.s M4CkNoMove
        btst #SXF_S5,X_WFLAGS(a0)
        bne.s M4CkStrike1
        move.b #$f0,X_SBYTE4(a0)
        move.b #$10,37(a0)
        bra.s M4CkNoMove
M4CkStrike1:
        move.b #$f0,37(a0)
        move.b #$10,X_SBYTE4(a0)
        bra.s M4CkNoMove

; .move 09:B752: addplayerZ, movebackandforth; .nomove 09:B759: triggeregg;
; .nomove2 09:B75C: waveheads, the five pieces placed, check_fin,
; regrownecks, m_bossHP += HP.
M4CkMove:
        jsr M4EnAddPZ
        bsr M4CkMoveBF
M4CkNoMove:
        bsr M4CkTrigEgg
        bsr M4CkWaveHeads
        move.w X_ALPTR(a0),d0
        beq.s M4CkPlaced1
        movea.w d0,a3
        bsr M4CkPos1
M4CkPlaced1:
        move.w 40(a0),d0
        beq.s M4CkPlaced2
        movea.w d0,a3
        bsr M4CkPos2
M4CkPlaced2:
        move.w 42(a0),d0
        beq.s M4CkPlaced3
        movea.w d0,a3
        bsr M4CkPos3
M4CkPlaced3:
        move.w X_WPX(a0),d0
        beq.s M4CkPlaced4
        movea.w d0,a3
        bsr M4CkPos4
M4CkPlaced4:
        move.w X_WPY(a0),d0
        beq.s M4CkPlaced5
        movea.w d0,a3
        bsr M4CkPos5
M4CkPlaced5:
        bsr M4CkCheckFin
        bsr M4CkRegrow
        move.b 38(a0),d0
        add.b d0,M4_BOSS_HP
        moveq #0,d0
        rts

; .movebackandforth 09:B8FA: animframe +1 mod 8; sflag3: vel -20, rotation
; toward $80 (B988), |pz - z| >= 2500 -> sflag3 toggles; else vel -40,
; rotation toward 0 (B9A7), |pz - z| < 600 -> toggles; vx / vz = gen2d(vel,
; roty) (1F:C177), z += vz, x += vx.
M4CkMoveBF:
        move.b 16(a0),d0
        moveq #1,d1
        moveq #8,d2
        jsr M4WpAddAnim
        move.b d0,16(a0)
        btst #SXF_S3,X_WFLAGS(a0)
        beq.s M4CkMoveFwd
        move.b #$ec,15(a0)
        bsr M4CkRot1
        move.w #2500,d0
        bsr M4SxDzLess
        bne.s M4CkMoveGo
        bra.s M4CkMoveFlip
M4CkMoveFwd:
        move.b #$d8,15(a0)
        bsr M4CkRot2
        move.w #600,d0
        bsr M4SxDzLess
        beq.s M4CkMoveGo
M4CkMoveFlip:
        bchg #SXF_S3,X_WFLAGS(a0)
M4CkMoveGo:
        jsr M4EnGen2d
        move.w 10(a0),d0
        add.w d0,4(a0)
        move.w 6(a0),d0
        add.w d0,(a0)
        rts
; .needtorotate1 09:B988: sflag1 -> rotate; roty $80 -> done; else
; leftviewchk, sflag2 toggles, rotate. .needtorotate2 09:B9A7: sflag1 ->
; rotate; roty 0 -> done; else leftviewchk, rotate. .leftviewchk 09:B96A:
; sflag1, sflag2 = afLeftPl. Rotate 09:B9BC: roty -/+ 8 by sflag2; roty &
; $7F 0 -> sflag1 off.
M4CkRot1:
        btst #F2_SFLAG1,48(a0)
        bne.s M4CkRotate
        cmpi.b #$80,13(a0)
        beq.s M4CkRotDone
        bsr.s M4CkLeftView
        bchg #F2_SFLAG2,48(a0)
        bra.s M4CkRotate
M4CkRot2:
        btst #F2_SFLAG1,48(a0)
        bne.s M4CkRotate
        tst.b 13(a0)
        beq.s M4CkRotDone
        bsr.s M4CkLeftView
M4CkRotate:
        btst #F2_SFLAG2,48(a0)
        bne.s M4CkRotSub
        addq.b #8,13(a0)
        bra.s M4CkRotChk
M4CkRotSub:
        subq.b #8,13(a0)
M4CkRotChk:
        moveq #$7f,d0
        and.b 13(a0),d0
        bne.s M4CkRotDone
        bclr #F2_SFLAG1,48(a0)
M4CkRotDone:
        rts
M4CkLeftView:
        bset #F2_SFLAG1,48(a0)
        bclr #F2_SFLAG2,48(a0)
        btst #AF_LEFTPL,51(a0)
        beq.s M4CkLeftDone
        bset #F2_SFLAG2,48(a0)
M4CkLeftDone:
        rts

; .triggeregg 09:BC69: sflag3 and random_l >= $FC -> the first tail piece
; (sword2) gets sflag2 (passed down to the tail end, which lays the egg).
M4CkTrigEgg:
        btst #SXF_S3,X_WFLAGS(a0)
        beq.s M4CkTrigDone
        jsr M4IntroRandom
        cmpi.b #$fc,d0
        blo.s M4CkTrigDone
        move.w 42(a0),d0
        beq.s M4CkTrigDone
        movea.w d0,a3
        bset #F2_SFLAG2,48(a3)
M4CkTrigDone:
        rts
; .waveheads 09:BAF0: sbyte3 = sin8[4 gameframe] / 8 toward zero.
M4CkWaveHeads:
        move.w M4_LV_GAMEFRAME,d0
        add.b d0,d0
        add.b d0,d0
        bsr.s M4CkSin
        bpl.s M4CkWaveP
        addq.b #7,d0
M4CkWaveP:
        asr.b #3,d0
        move.b d0,X_SBYTE3(a0)
        rts
M4CkSin: ;d0.b index -> d0.b sin8 (00:98A5), flags of the value
        move.l a2,-(sp)
        andi.w #$ff,d0
        lea M4IntroShipSine,a2
        move.b (a2,d0.w),d0
        movea.l (sp)+,a2
        tst.b d0
        rts

; Piece placement (a3 = piece): rotations of the body, adjusted; offsets
; (x1, y1, z1) + .updowntab[animframe & 15] (09:BC2E: y1, z1), placed at
; the body + 4 * rot(offset) (09:AED4, M4SxPlace).
; .position1 09:BB1F: roty - sbyte3 - 8, rotx + sbyte2 + sbyte3 + rotz -
; $70, rotz + $80; (-10, -50, -15).
M4CkPos1:
        bsr M4SxCopyRots
        move.b 13(a3),d0
        sub.b X_SBYTE3(a0),d0
        subq.b #8,d0
        move.b d0,13(a3)
        move.b 12(a3),d0
        add.b 37(a0),d0
        add.b X_SBYTE3(a0),d0
        add.b 14(a0),d0
        subi.b #$70,d0
        move.b d0,12(a3)
        addi.b #$80,14(a3)
        moveq #-10,d3
        moveq #-50,d4
        moveq #-15,d5
        bra M4CkPlace
; .position2 09:BB5C: roty + sbyte3 + $88, rotx - sbyte4 - sbyte3 + rotz -
; $10; (10, -50, -15).
M4CkPos2:
        bsr M4SxCopyRots
        move.b 13(a3),d0
        add.b X_SBYTE3(a0),d0
        addi.b #$88,d0
        move.b d0,13(a3)
        move.b 12(a3),d0
        sub.b X_SBYTE4(a0),d0
        sub.b X_SBYTE3(a0),d0
        add.b 14(a0),d0
        subi.b #$10,d0
        move.b d0,12(a3)
        moveq #10,d3
        moveq #-50,d4
        moveq #-15,d5
        bra.s M4CkPlace
; .position3 09:BB90 (tail): i = 8 gameframe, x1 = sin8[i] / 4 toward zero;
; i 0 or $80: |pz - z| < 2000 -> trigse $39, and x1 = $D0 (the distance
; test overwrites it); roty + x1, rotx + rotz + 8; (0, -25, 15).
M4CkPos3:
        bsr M4SxCopyRots
        move.w M4_LV_GAMEFRAME,d0
        lsl.b #3,d0
        move.b d0,d7
        bsr M4CkSin
        bpl.s M4CkPos3P
        addq.b #3,d0
M4CkPos3P:
        asr.b #2,d0
        move.b d0,d6
        moveq #$7f,d0
        and.b d7,d0
        bne.s M4CkPos3Rot
        move.b #$d0,d6 ;dzdistless 09:80AB stores K ($07D0) in $02 = x1
        move.w #2000,d0
        bsr M4SxDzLess
        beq.s M4CkPos3Rot
        M4PlaySfx $39
M4CkPos3Rot:
        add.b d6,13(a3)
        move.b 12(a3),d0
        add.b 14(a0),d0
        addq.b #8,d0
        move.b d0,12(a3)
        moveq #0,d3
        moveq #-25,d4
        moveq #15,d5
        bra.s M4CkPlace
; .position4 / 5 09:BC02 / BC18 (wings): (-18, 0, 0) / (18, 0, 0).
M4CkPos4:
        bsr M4SxCopyRots
        moveq #-18,d3
        bra.s M4CkPosWing
M4CkPos5:
        bsr M4SxCopyRots
        moveq #18,d3
M4CkPosWing:
        moveq #0,d4
        moveq #0,d5
M4CkPlace:
        moveq #15,d0
        and.b 16(a0),d0
        add.w d0,d0
        lea M4CkUpDown(pc),a2
        add.b (a2,d0.w),d4
        add.b 1(a2,d0.w),d5
        bra M4SxPlace
; .updowntab 09:BC4F, 16 (y, z) pairs read with & 15: the last three come
; from the code that follows it in the ROM (09:BC69..BC6E).
M4CkUpDown:
        incbin '../build/M4CkUpDown.bin'

; .check_fin 09:B78C: the tail end on sword2, or a head on both al_ptr and
; sword1 -> vulnerable: nohitaffect off, coltab $82ED (red), the first time
; count $38, count1 + 1, sflag6; odd gameframes coltab 0; else nohitaffect,
; coltab 0. The wings get the same coltab.
M4CkCheckFin:
        move.w 42(a0),d0
        beq.s M4CkFinHeads
        movea.w d0,a3
        bsr M4SxHeader
        cmpi.w #CK_TAIL,d0
        beq.s M4CkFinRed
M4CkFinHeads:
        move.w X_ALPTR(a0),d0
        beq.s M4CkFinNormal
        movea.w d0,a3
        bsr M4SxHeader
        cmpi.w #CK_HEAD,d0
        bne.s M4CkFinNormal
        move.w 40(a0),d0
        beq.s M4CkFinNormal
        movea.w d0,a3
        bsr M4SxHeader
        cmpi.w #CK_HEAD,d0
        bne.s M4CkFinNormal
M4CkFinRed:
        bclr #SF_NOHITAFFECT,49(a0)
        move.w #M4_BH_RED,d1
        bset #SXF_S6,X_WFLAGS(a0)
        bne.s M4CkFinOdd
        move.b #$38,19(a0)
        addq.b #1,X_COUNT1(a0)
M4CkFinOdd:
        btst #0,M4_LV_GAMEFRAME+1
        beq.s M4CkFinSet
        moveq #0,d1
        bra.s M4CkFinSet
M4CkFinNormal:
        bset #SF_NOHITAFFECT,49(a0)
        moveq #0,d1
M4CkFinSet:
        move.w d1,X_COLTAB(a0)
        move.w X_WPX(a0),d0
        beq.s M4CkFinWing2
        movea.w d0,a3
        move.w d1,X_COLTAB(a3)
M4CkFinWing2:
        move.w X_WPY(a0),d0
        beq.s M4CkFinDone
        movea.w d0,a3
        move.w d1,X_COLTAB(a3)
M4CkFinDone:
        rts

; .regrownecks 09:B80A: count - 1; at 0: count 4 (sflag6) or $50, each
; chain grows by one piece (09:B862: necks up to 3, tail up to 5, minus
; count1, at least 2); all three complete -> sflag6 off (slow regrow).
M4CkRegrow:
        subq.b #1,19(a0)
        bne.s M4CkRegrowDone
        move.b #$50,19(a0)
        btst #SXF_S6,X_WFLAGS(a0)
        beq.s M4CkRegrowGo
        move.b #4,19(a0)
M4CkRegrowGo:
        moveq #0,d6 ;chains complete
        lea X_ALPTR(a0),a4
        moveq #3,d0
        bsr.s M4CkRegrowNeck
        lea 40(a0),a4
        moveq #3,d0
        bsr.s M4CkRegrowNeck
        lea 42(a0),a4
        moveq #5,d0
        bsr.s M4CkRegrowNeck
        cmpi.b #3,d6
        bne.s M4CkRegrowDone
        bclr #SXF_S6,X_WFLAGS(a0)
M4CkRegrowDone:
        rts
; 09:B862 (a4 = the body's pointer word, d0 = full length): n = max(d0 -
; count1, 2) (8-bit N); the chain walked to its end (head B983 / tail
; B9BB): k pieces before it. k >= n -> complete (d6 + 1). Else a new piece
; (make_obj B8F7 behind the end, 1F:D3A9 links after x = the end), Istrat
; arm, neck B967 before a head; k > 0: inserted after the last piece (its
; rotations and position); k = 0: between the body and the end.
M4CkRegrowNeck:
        sub.b X_COUNT1(a0),d0
        bmi.s M4CkRgMin
        cmpi.b #2,d0
        bhs.s M4CkRgLen
M4CkRgMin:
        moveq #2,d0
M4CkRgLen:
        andi.w #$ff,d0
        move.w d0,d5 ;n
        moveq #0,d4 ;k
        move.w (a4),d0
M4CkRgWalk:
        beq.s M4CkRgDone ;null link [H]: the ROM would walk object 0
        movea.w d0,a2
        movea.l a2,a3
        bsr M4SxHeader
        cmpi.w #CK_HEAD,d0
        beq.s M4CkRgEnd
        cmpi.w #CK_TAIL,d0
        beq.s M4CkRgEnd
        addq.w #1,d4
        move.l a2,d3 ;last piece
        move.w X_ALPTR(a2),d0
        bra.s M4CkRgWalk
M4CkRgEnd:
        cmp.w d5,d4
        blo.s M4CkRgGrow
        addq.b #1,d6
M4CkRgDone:
        rts
M4CkRgGrow:
        move.w d0,d7 ;header of the end
        move.l a2,d2 ;the end
        move.l M4_LV_CREATOR,-(sp)
        move.l a2,M4_LV_CREATOR
        move.w #CK_ARM,d0
        jsr M4ArCreateHdr
        move.l (sp)+,M4_LV_CREATOR
        cmpa.w #0,a2
        beq.s M4CkRgDone
        movea.l a2,a3 ;new piece
        move.l #M4SxArm,32(a3)
        cmpi.w #CK_HEAD,d7
        bne.s M4CkRgShape
        move.w #CK_NECK,d0
        bsr M4SxSetHdr
M4CkRgShape:
        move.w d2,X_ALPTR(a3) ;-> the end
        tst.w d4
        beq.s M4CkRgFirst
        movea.l d3,a2 ;last piece
        move.w a3,X_ALPTR(a2)
        exg a0,a2
        bsr M4SxCopyRots
        move.l (a0),(a3)
        move.w 4(a0),4(a3)
        exg a0,a2
        rts
M4CkRgFirst:
        move.w a3,(a4)
        rts

; .generate 09:B9E2: neck 1 (al_ptr), neck 2 (sword1): make_obj, Istrat arm,
; B967, sword1 1, placed; the tail (sword2): B8F7, sword1 1, placed; wing 1
; (unless sflag1): BA47, Istrat C046, sflag1, sWPx1, placed; wing 2: BA63,
; sflag2, sWPy1, placed; sflag1 off. Z set when all exist (carry clear).
M4CkGenerate:
        tst.w X_ALPTR(a0)
        bne.s M4CkGenNeck2
        bsr M4CkGenPiece
        beq M4CkGenFail
        bsr M4CkGenNeck
        move.w a2,X_ALPTR(a0)
        movea.l a2,a3
        bsr M4CkPos1
M4CkGenNeck2:
        tst.w 40(a0)
        bne.s M4CkGenTail
        bsr M4CkGenPiece
        beq M4CkGenFail
        bsr M4CkGenNeck
        move.w a2,40(a0)
        movea.l a2,a3
        bsr M4CkPos2
M4CkGenTail:
        tst.w 42(a0)
        bne.s M4CkGenWings
        bsr M4CkGenPiece
        beq.s M4CkGenFail
        move.l #M4SxArm,32(a2)
        move.b #1,41(a2)
        move.w a2,42(a0)
        movea.l a2,a3
        bsr M4CkPos3
M4CkGenWings:
        btst #F2_SFLAG1,48(a0)
        bne.s M4CkGenWing2
        bsr M4CkGenPiece
        beq.s M4CkGenFail
        movea.l a2,a3
        move.w #$ba47,d0
        bsr M4SxSetHdr
        move.l #M4CkWings,32(a3)
        bset #F2_SFLAG1,48(a0)
        move.w a3,X_WPX(a0)
        bsr M4CkPos4
M4CkGenWing2:
        bsr M4CkGenPiece
        beq.s M4CkGenFail
        movea.l a2,a3
        move.w #$ba63,d0
        bsr M4SxSetHdr
        move.l #M4CkWings,32(a3)
        bset #F2_SFLAG2,48(a0)
        move.w a3,X_WPY(a0)
        bsr M4CkPos5
        bclr #F2_SFLAG1,48(a0)
        moveq #0,d0
        rts
M4CkGenFail:
        moveq #1,d0
        rts
M4CkGenPiece: ;make_obj B8F7 09:AE35 -> a2 (Z set on failure)
        move.w #CK_ARM,d0
        jsr M4ArCreateHdr
        rts
M4CkGenNeck: ;Istrat arm, B967, sword1 1
        move.l #M4SxArm,32(a2)
        movea.l a2,a3
        move.w #CK_NECK,d0
        bsr M4SxSetHdr
        move.b #1,41(a2)
        rts

; wings_istrat 09:C046: strategy C07E, normcollptrs, HP $FF AP 8,
; nohitaffect, colldisable, shadow, no zremove, animframe $80. C07E: sflag1
; (folded): animframe -1 mod 15 down to 0; else +1 mod 15, 14 -> 4.
M4CkWings:
        move.l #M4CkWingsTick,32(a0)
        jsr M4LvNormPtrs
        move.b #$ff,38(a0)
        move.b #8,39(a0)
        bset #SF_NOHITAFFECT,49(a0)
        bset #SF_COLLDISABLE,49(a0)
        bset #F2_SHADOW,48(a0)
        bclr #3,45(a0)
        move.b #$80,16(a0)
M4CkWingsTick:
        move.b 16(a0),d0
        moveq #15,d2
        btst #F2_SFLAG1,48(a0)
        beq.s M4CkWingsOpen
        moveq #$7f,d1
        and.b d0,d1
        beq.s M4CkWingsDone
        moveq #-1,d1
        jsr M4WpAddAnim
        move.b d0,16(a0)
        bra.s M4CkWingsDone
M4CkWingsOpen:
        moveq #1,d1
        jsr M4WpAddAnim
        move.b d0,16(a0)
        andi.b #$7f,d0
        cmpi.b #14,d0
        bne.s M4CkWingsDone
        move.b #$84,16(a0)
M4CkWingsDone:
        moveq #0,d0
        rts

; Expstrat 09:BC95 (body HP 0): the neck and tail chains (09:C0E0:
; colldisable, HP 0 each) and both wings killed; expstrat bossexplode
; 06:EAAE, run on the next tick (no stratptr2: M4V3BossExplode).
M4CkExplode:
        move.w X_ALPTR(a0),d0
        bsr.s M4CkKillChain
        move.w 40(a0),d0
        bsr.s M4CkKillChain
        move.w 42(a0),d0
        bsr.s M4CkKillChain
        move.w X_WPX(a0),d0
        bsr.s M4CkKillOne
        move.w X_WPY(a0),d0
        bsr.s M4CkKillOne
        move.l #M4V3BossExplode,X_EXP(a0)
        moveq #0,d0
        rts
M4CkKillChain:
        beq.s M4CkKillDone ;[H] the ROM would kill object 0
        movea.w d0,a3
        bset #SF_COLLDISABLE,49(a3)
        clr.b 38(a3)
        move.w X_ALPTR(a3),d0
        bra.s M4CkKillChain
M4CkKillOne:
        beq.s M4CkKillDone
        movea.w d0,a3
        bset #SF_COLLDISABLE,49(a3)
        clr.b 38(a3)
M4CkKillDone:
        rts

; firebreathe_istrat 09:BE97: vel $50, then firebreathe2 09:BE9B.
M4CkFire:
        move.b #$50,15(a0)
        jmp M4TiFireBreathI

; egg_istrat 09:BCD9 (B059, laid by the tail end): ssprite, depthoffset 0,
; tx 0, strategy BD11, normcollptrs, HP $15 AP 8, enemy1, shadow, faces the
; camera (09:802A). BD11: dfallyvec; in the air y + vy; landed: random_l <
; $4C or within 600 of the player -> BDF4 (strategy BE01: waits for a hit,
; HP != $15 -> opens); else it opens (BD3D).
M4CkEgg:
        bset #F2_SPRITE,48(a0)
        clr.b X_DEPTHOFF(a0)
        clr.b X_TX(a0)
        move.l #M4CkEggTick,32(a0)
        jsr M4LvNormPtrs
        move.b #$15,38(a0)
        move.b #8,39(a0)
        ori.b #CF_ENEMY1,44(a0)
        bset #F2_SHADOW,48(a0)
        jsr M4EnFaceCamera
M4CkEggTick:
        jsr M4V3FallYVec
        bcs.s M4CkEggLanded
        move.w 8(a0),d0
        add.w d0,2(a0)
        moveq #0,d0
        rts
M4CkEggLanded:
        jsr M4IntroRandom
        cmpi.b #$4c,d0
        blo.s M4CkEggShut
        move.w #600,d0
        bsr M4SxDzLess
        beq.s M4CkEggOpen
M4CkEggShut:
        move.l #M4CkEggWait,32(a0)
M4CkEggWait:
        cmpi.b #$15,38(a0)
        bne.s M4CkEggOpen
        moveq #0,d0
        rts
; 09:BD3D: own shape BA2B; the shell BA0F (its position and rotations,
; strategy BE5A, vy -15, hitflash); own hitflash, vy -15, strategy BDC6,
; trigse $3A; the chick B9D7 (position, rotations, strategy BE0C). A failed
; shell keeps the egg as it is (BD22). BDC6: y + vy, rotz - 6, dfallyvec
; (landed: nothing BE46), x - 15.
M4CkEggOpen:
        movea.l a0,a3
        move.w #$ba2b,d0
        bsr M4SxSetHdr
        move.w #CK_ARM,d0
        jsr M4ArCreateHdr
        bne.s M4CkEggShell
        moveq #0,d0
        rts
M4CkEggShell:
        movea.l a2,a3
        move.w #$ba0f,d0
        bsr M4SxSetHdr
        jsr M4TiCopyPosRots
        move.l #M4CkShell,32(a2)
        move.w #-15,8(a2)
        bset #SF_HITFLASH,49(a2)
        bset #2,31(a2)
        bset #SF_HITFLASH,49(a0)
        bset #2,31(a0)
        move.w #-15,8(a0)
        move.l #M4CkEggOut,32(a0)
        M4PlaySfx $3a
        move.w #CK_ARM,d0
        jsr M4ArCreateHdr
        beq.s M4CkEggOut
        movea.l a2,a3
        move.w #$b9d7,d0
        bsr M4SxSetHdr
        jsr M4TiCopyPosRots
        move.l #M4CkChick,32(a2)
M4CkEggOut:
        move.w 8(a0),d0
        add.w d0,2(a0)
        subq.b #6,14(a0)
        jsr M4V3FallYVec
        bcs.s M4CkNothing
        subi.w #15,(a0)
        moveq #0,d0
        rts
; nothing_istrat 09:BE46: strategy BE46, colldisable.
M4CkNothing:
        move.l #M4CkNothing,32(a0)
        bset #SF_COLLDISABLE,49(a0)
        moveq #0,d0
        rts
; shell_istrat 09:BE5A (also its strategy): enemy1, HP $FF AP 8, shadow;
; y + vy, x + 15, rotz + 6, dfallyvec (landed: nothing).
M4CkShell:
        ori.b #CF_ENEMY1,44(a0)
        move.b #$ff,38(a0)
        move.b #8,39(a0)
        bset #F2_SHADOW,48(a0)
        move.w 8(a0),d0
        add.w d0,2(a0)
        addi.w #15,(a0)
        addq.b #6,14(a0)
        jsr M4V3FallYVec
        bcs.s M4CkNothing
        moveq #0,d0
        rts
; chick_istrat 09:BE0C: enemy1, shadow, strategy BE3E, normcollptrs, HP 2
; AP 8, aimed at the player (09:8009), vel $50, v = gen3d (09:8276). BE3E:
; addplayerZ, pos += v.
M4CkChick:
        ori.b #CF_ENEMY1,44(a0)
        bset #F2_SHADOW,48(a0)
        move.l #M4CkChickTick,32(a0)
        jsr M4LvNormPtrs
        move.b #2,38(a0)
        move.b #8,39(a0)
        movea.l a1,a2
        jsr M4EnPitchTo
        move.b d0,12(a0)
        movea.l a1,a2
        jsr M4EnYawTo
        move.b d0,13(a0)
        move.b #$50,15(a0)
        jsr M4EnGen3d
M4CkChickTick:
        jsr M4EnAddPZ
        jsr M4EnMove
        moveq #0,d0
        rts

; ---------------------------------------------------------------------
; Arm engine branches of the heads B983 and the tail end B9BB (called from
; M4SxArmTick, level_sectors.asm). 09:A4B5 (d0 = header): HP below $41 ->
; .chickenheadhit; a head: rotz $80 / 0 by the sign of rotx - $40; armmode
; bit6 toggles (the two heads alternate); with armmode bit0 (fireblaze),
; bit5 equal to bit6 and no fire AD2D in allst: firebreathe 09:BE97 (its
; position and rotations, rotx +$28 / -$28), trigse $3B, armmode bit5
; toggles.
M4CkArmHead:
        cmpi.b #$41,38(a0)
        bhs.s M4CkHeadHpOk
        move.w d0,-(sp)
        bsr M4CkHeadHit
        move.w (sp)+,d0
M4CkHeadHpOk:
        cmpi.w #CK_TAIL,d0
        beq M4CkArmHeadDone
        move.b 12(a0),d0
        subi.b #$40,d0
        smi d0
        not.b d0
        andi.b #$80,d0
        move.b d0,14(a0)
        eori.b #$40,M4_SX_ARMMODE
        move.b M4_SX_ARMMODE,d0
        btst #0,d0
        beq.s M4CkArmHeadDone
        move.b d0,d1
        add.b d1,d1
        eor.b d0,d1
        btst #6,d1
        bne.s M4CkArmHeadDone
        move.w #$ad2d,d1
        bsr M4SxFindHdr
        bne.s M4CkArmHeadDone
        move.w #CK_ARM,d0
        jsr M4ArCreateHdr
        beq.s M4CkArmHeadDone
        jsr M4TiCopyPosRots
        move.l #M4CkFire,32(a2)
        movea.l a2,a3
        move.w #$ad2d,d0
        bsr M4SxSetHdr
        M4PlaySfx $3b
        eori.b #$20,M4_SX_ARMMODE
        moveq #$28,d0
        move.b 12(a0),d1
        subi.b #$40,d1
        bmi.s M4CkFireAim
        move.b #$d8,d0
M4CkFireAim:
        add.b d0,12(a2)
M4CkArmHeadDone:
        rts

; .chickenheadhit 09:A72F: trigse $3B; a head HP + 4, the tail end HP $42;
; its parent (09:B1C7), unless none or the body: the parent piece removed
; (pointers to it cleared 09:A3E5, al_ptr 0; acf_firstframe -> removed now
; 1F:D501, else killed); the end linked to the grandparent, or to the body
; when there is none: the tail on sword2, a head on al_ptr when it is 0,
; else on sword1.
M4CkHeadHit:
        M4PlaySfx $3b
        movea.l a0,a3
        bsr M4SxHeader
        cmpi.w #CK_HEAD,d0
        bne.s M4CkHitTail
        addq.b #4,38(a0)
        bra.s M4CkHitFind
M4CkHitTail:
        move.b #$42,38(a0)
M4CkHitFind:
        bsr M4SxFindParent
        beq.s M4CkHitDone
        bsr M4SxHeader
        cmpi.w #CK_BODY,d0
        beq.s M4CkHitDone
        move.l a0,-(sp) ;the end
        movea.l a3,a0 ;the piece to remove
        bsr M4SxFindParent
        move.l a3,d4 ;grandparent or 0
        bsr M4SxUnlinkMe
        clr.w X_ALPTR(a0)
        btst #2,44(a0) ;acf_firstframe
        beq.s M4CkHitKill
        jsr M4LevelRemove
        bra.s M4CkHitLink
M4CkHitKill:
        bset #SF_COLLDISABLE,49(a0)
        clr.b 38(a0)
M4CkHitLink:
        movea.l (sp)+,a0
        tst.l d4
        beq.s M4CkHitBody
        movea.l d4,a3
        bsr M4SxHeader
        cmpi.w #CK_BODY,d0
        beq.s M4CkHitBody
        move.w a0,X_ALPTR(a3)
M4CkHitDone:
        rts
M4CkHitBody:
        move.w #CK_BODY,d1
        bsr M4SxFindHdr
        beq.s M4CkHitDone
        movea.l a3,a4
        movea.l a0,a3
        bsr M4SxHeader
        cmpi.w #CK_TAIL,d0
        bne.s M4CkHitNeck
        move.w a0,42(a4)
        rts
M4CkHitNeck:
        tst.w X_ALPTR(a4)
        beq.s M4CkHitNeck1
        move.w a0,40(a4)
        rts
M4CkHitNeck1:
        move.w a0,X_ALPTR(a4)
        rts

; Head collstrat 09:A704: facing angle (roty, or roty - $80 when rotx - $40
; >= 0) + $AD below $5A -> hittable (nohitaffect off), else nohitaffect;
; then hitflash_Istrat 06:89A3.
M4CkHeadColl:
        move.b 12(a0),d0
        subi.b #$40,d0
        bmi.s M4CkCollRoty
        move.b 13(a0),d0
        subi.b #$80,d0
        bra.s M4CkCollAdd
M4CkCollRoty:
        move.b 13(a0),d0
M4CkCollAdd:
        addi.b #$ad,d0
        cmpi.b #$5a,d0
        bhs.s M4CkCollShield
        bclr #SF_NOHITAFFECT,49(a0)
        jmp M4LcHitFlash
M4CkCollShield:
        bset #SF_NOHITAFFECT,49(a0)
        jmp M4LcHitFlash

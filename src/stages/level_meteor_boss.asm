; Meteor boss bossh 00:E8D4 (map 0D:BBF5): body, legs, top, teleporter and
; their weapons. Table entries: level_meteor_boss_strats.asm. Shapes and
; effects: tools/stages/meteor_boss.py. RAM: $FF9E80..$FF9EFF.
; Specification and tests: build/agent-meteor/BOSS.md (ROM USA rev0 bank 00
; E8D4..F891, traces build/agent-meteor/boss/bossh_all.txt; oracle
; build/agent-meteor/boss/bossh-oracle.py).
; Family links as boss7/boss1 (level_boss.asm): child id in sbyte1 (36),
; mother in X_ALPTR, chain in sword1 (40); child offsets X2_CHILDX..+2,
; rotation offsets X2_CHILDRX..+2 (rotpos 09:E03F = M4PvRotChildren).
; Fields: stratstate $1CDC = X_STATE (mode of the 09:C027 mode tables),
; animframe $1CE7 = 16, coltab $1CEA = X_COLTAB, tx $1CF4 = X_TX, ty $1CF5
; = X_TY, pbyte1 $1CFC = X2_PBYTE1, sword2 $28 = X_SWORD2, sbyte3/4 =
; X_SBYTE3/4, depthoffset $1CDF = X_DEPTHOFF; sflags2 $10 = F2_SFLAG1, $20 =
; F2_SFLAG2, $40 (body sflag3) = X_WFLAGS bit0 (sflags2 $40, as weapons).
M4_BH equ $ff9e80
M4_BH_HITCOUNT equ M4_BH+0 ;.b 7E:F0BB bosshhitcount (bar: m_bossHP += it)
M4_BH_PHANTOM equ M4_BH+1 ;.b 7E:1CDC: stratstate read/written through
                           ;find_child Y = 0 (a leg already gone)
M4_BH_RED equ $82ed ;id_1_c coltab 03:82ED (red legs / vulnerable body)
M4_BH_FIRECOL equ $8574 ;bonfire_c coltab 03:8574

; ---------------------------------------------------------------------
; Body Istrat 00:E8D4: collstrat hitflash 06:89A3, expstrat 00:EE08; HP 64 /
; AP 4, shadow, enemy1, depthoffset 1, sbyte3 1 (spin speed), nohitaffect;
; hitcount 35 (5*2 drops + 5*5 legs); m_bossmaxHP = 35 + 64, m_bossHP = 0;
; .generate (EEB5), stratstate 0, then the mode dispatch (E943) this tick.
M4BhIstrat:
        move.l #M4BhBody,32(a0)
        move.l #M4LcHitFlash,X_COLL(a0)
        move.l #M4BhExplode,X_EXP(a0)
        move.b #64,38(a0)
        move.b #4,39(a0)
        bset #F2_SHADOW,48(a0)
        ori.b #CF_ENEMY1,44(a0)
        move.b #1,X_DEPTHOFF(a0)
        move.b #1,X_SBYTE3(a0)
        bset #SF_NOHITAFFECT,49(a0)
        move.b #35,M4_BH_HITCOUNT
        move.b #35,M4_BOSS_MAXHP
        clr.b M4_BOSS_HP
        addi.b #64,M4_BOSS_MAXHP
        bsr M4BhGenerate
        clr.b X_STATE(a0)
; E943: mode table 00:E954 (09:C027 dispatcher; nxtmode E9B0 re-enters here).
M4BhBody:
        moveq #0,d0
        move.b X_STATE(a0),d0
        cmpi.b #22,d0
        bhs M4BhMove ;entries 22.. are not code (never reached)
        add.w d0,d0
        move.w M4BhModes(pc,d0.w),d0
        jmp M4BhModes(pc,d0.w)
M4BhModes:
        dc.w M4BhWalkOn-M4BhModes,M4BhMove2-M4BhModes,M4BhDrop-M4BhModes
        dc.w M4BhSpinFaster-M4BhModes,M4BhBackForth-M4BhModes,M4BhMiddle-M4BhModes
        dc.w M4BhWaitMiddle-M4BhModes,M4BhScuttleFwd-M4BhModes,M4BhScuttleBack-M4BhModes
        dc.w M4BhMove2-M4BhModes,M4BhDrop-M4BhModes,M4BhRedLegs-M4BhModes
        dc.w M4BhSpinFaster-M4BhModes,M4BhBackForth-M4BhModes,M4BhTo2500-M4BhModes
        dc.w M4BhFloat-M4BhModes,M4BhTeleport-M4BhModes,M4BhTo1500-M4BhModes
        dc.w M4BhWaitTele-M4BhModes,M4BhWaitLoop-M4BhModes,M4BhStand-M4BhModes
        dc.w M4BhCrouch-M4BhModes
; E9AC znxtmode / E9B0 nxtmode.
M4BhZNext:
        clr.b 37(a0)
M4BhNext:
        addq.b #1,X_STATE(a0)
        bra.s M4BhBody

; d1.w = n -> N set when ZD(player) < n (d3zdistless 00:E8B0: abs16(pz - z) - n).
M4BhZDLess:
        movea.l a1,a2
        jsr M4EnZD
        sub.w d1,d0
        rts

; 0 walkon E9B9: ZD < 2500 -> z + 20; x >= 0 -> x - 25; neither -> next.
M4BhWalkOn:
        moveq #0,d7
        move.w #2500,d1
        bsr M4BhZDLess
        bpl.s M4BhWalkX
        addi.w #20,4(a0)
        addq.b #1,d7
M4BhWalkX:
        tst.w (a0)
        bmi.s M4BhWalkEnd
        subi.w #25,(a0)
        addq.b #1,d7
M4BhWalkEnd:
        tst.b d7
        beq.s M4BhNext
        bra M4BhMove

; 2/10 droptoground ECB8: legs to movetoflat; pos += v; vy + 8; ground at
; y >= -80: bounce (falldown_Yvec); bounce speed 0: hitcount - 5 (trigse
; $8E), three smokes, next.
M4BhDrop:
        moveq #7,d1
        bsr M4BhSetChildMode
        jsr M4EnMove
        addq.w #8,8(a0)
        move.w 2(a0),d0
        addi.w #80,d0
        bmi M4BhMove
        move.w #-80,2(a0)
        bsr M4BhBounce
        bne M4BhMove
        subq.b #5,M4_BH_HITCOUNT
        bsr M4BhSmoke
        bsr M4BhSmoke
        bsr M4BhSmoke
        bra M4BhNext
; falldown_Yvec bounce (ECE7 / F5D1): vy = trunc0(-vy / 16) (four signed /2
; toward zero), -5..-1 -> 0; Z set when lo8(vy) = 0 (8-bit cmp #0).
M4BhBounce:
        move.w 8(a0),d0
        neg.w d0
        bpl.s M4BhBouncePos
        addi.w #15,d0
M4BhBouncePos:
        asr.w #4,d0
        cmpi.w #$fffb,d0
        blo.s M4BhBounceKeep
        moveq #0,d0
M4BhBounceKeep:
        move.w d0,8(a0)
        tst.b d0
        rts

; 3/12 spinfaster EC7D: every 4 ticks sbyte3 one step toward 20; y - 4;
; y < -400 -> next.
M4BhSpinFaster:
        move.w M4_LV_GAMEFRAME,d0
        andi.w #3,d0
        bne.s M4BhSpinUp
        move.b X_SBYTE3(a0),d0
        move.b d0,d1
        subi.b #20,d1
        beq.s M4BhSpinUp
        bmi.s M4BhSpinInc
        subq.b #1,X_SBYTE3(a0)
        bra.s M4BhSpinUp
M4BhSpinInc:
        addq.b #1,X_SBYTE3(a0)
M4BhSpinUp:
        subq.w #4,2(a0)
        move.w 2(a0),d0
        addi.w #400,d0
        bmi M4BhNext
        bra M4BhMove

; 4/13 movebackandforth EB99. sflag2 clear: z - 40; sflag3 or ZD < 2000
; (sets sflag3 and sword2 = -300 if rnd >= $7F, else -70): y Achase16_3
; toward sword2; ZD < 500: turn (sbyte2 1: sflag2 off, znxtmode; else
; sbyte2 + 1, sflag2 toggled, sflag3 off). sflag2 set: y one step of 5
; toward -400, z + 40, ZD >= 2500 -> turn. Then x = 4*sin8(sbyte4),
; sbyte4 + 4.
M4BhBackForth:
        btst #F2_SFLAG2,48(a0)
        bne.s M4BhForward
        subi.w #40,4(a0)
        btst #0,X_WFLAGS(a0)
        bne.s M4BhGoLow
        move.w #2000,d1
        bsr M4BhZDLess
        bpl.s M4BhNoLow
        bset #0,X_WFLAGS(a0)
        jsr M4IntroRandom
        cmpi.b #$7f,d0
        bhs.s M4BhHigh
        move.w #-70,X_SWORD2(a0)
        bra.s M4BhGoLow
M4BhHigh:
        move.w #-300,X_SWORD2(a0)
M4BhGoLow:
        move.w 2(a0),d0
        move.w X_SWORD2(a0),d1
        moveq #3,d2
        jsr M4LpAchase
        move.w d0,2(a0)
M4BhNoLow:
        move.w #500,d1
        bsr M4BhZDLess
        bpl.s M4BhSway4
M4BhTurn:
        cmpi.b #1,37(a0)
        bne.s M4BhTurnNorm
        bclr #F2_SFLAG2,48(a0)
        bra M4BhZNext
M4BhTurnNorm:
        addq.b #1,37(a0)
        bchg #F2_SFLAG2,48(a0)
        bclr #0,X_WFLAGS(a0)
        bra.s M4BhSway4
M4BhForward:
        move.w 2(a0),d0
        move.w d0,d1
        addi.w #400,d1
        beq.s M4BhFwdY
        bmi.s M4BhFwdUp
        subq.w #5,d0
        bra.s M4BhFwdY
M4BhFwdUp:
        addq.w #5,d0
M4BhFwdY:
        move.w d0,2(a0)
        addi.w #40,4(a0)
        move.w #2500,d1
        bsr M4BhZDLess
        bpl.s M4BhTurn
M4BhSway4:
        moveq #4,d1
        bsr M4BhSway
        bra M4BhMove
; x = 4 * sext(sin8[sbyte4]) (00:98A5); sbyte4 + d1.
M4BhSway:
        lea M4IntroShipSine,a2
        moveq #0,d0
        move.b X_SBYTE4(a0),d0
        move.b (a2,d0.w),d0
        ext.w d0
        asl.w #2,d0
        move.w d0,(a0)
        add.b d1,X_SBYTE4(a0)
        rts

; 5 middlestage EB8F / 6 waitformiddle EB78.
M4BhMiddle:
        moveq #12,d1
        bsr M4BhSetChildMode
        bra M4BhNext
M4BhWaitMiddle:
        moveq #13,d1
        bsr M4BhChkChildMode
        cmpi.b #5,d0
        bne M4BhMove2
        moveq #14,d1
        bsr M4BhSetChildMode
        bra M4BhNext

; 7 scuttleforwards EB38: ZD < 1500 -> next; sbyte3 Achase8_3 toward 2
; (1F:D8BD); z - 50.
M4BhScuttleFwd:
        move.w #1500,d1
        bsr M4BhZDLess
        bmi M4BhNext
        move.b X_SBYTE3(a0),d0
        moveq #2,d1
        moveq #3,d2
        jsr M4EnChase8
        move.b d0,X_SBYTE3(a0)
        subi.w #50,4(a0)
        bra M4BhMove2
; 8 scuttlebackwards EB1B: ZD >= 2000 -> next; z + 80.
M4BhScuttleBack:
        move.w #2000,d1
        bsr M4BhZDLess
        bpl M4BhNext
        addi.w #80,4(a0)
        bra M4BhMove2

; 11 redlegs EABE: legs in M4BhLegIds get coltab id_1_c (a missing leg: the ROM
; writes 7E:1CEA, never read back; skipped).
M4BhRedLegs:
        lea M4BhLegIds,a3
        moveq #4,d6
M4BhRedNext:
        move.b (a3)+,d0
        jsr M4BsChild
        beq.s M4BhRedSkip
        move.w #M4_BH_RED,X_COLTAB(a2)
M4BhRedSkip:
        dbra d6,M4BhRedNext
        bra M4BhNext

; 14 moveto2500 EAA1 / 17 moveto1500 EA97: ZD < n -> next; z - 50.
M4BhTo2500:
        move.w #2500,d1
        bra.s M4BhMoveTo
M4BhTo1500:
        move.w #1500,d1
M4BhMoveTo:
        bsr M4BhZDLess
        bmi M4BhNext
        subi.w #50,4(a0)
        bra M4BhMove3

; 15 floatto400 EA19: y Achase16_4 toward -400; already there -> next.
M4BhFloat:
        move.w 2(a0),d0
        cmpi.w #-400,d0
        beq M4BhNext
        move.w #-400,d1
        moveq #4,d2
        jsr M4LpAchase
        move.w d0,2(a0)
        bra M4BhMove

; 16 teleport EA4E: child id 7 boss_h_3 (teleporter_istrat F69E, offsets 0,
; enemy1), trigse $98, moved to the end of allst (09:C0F7); next.
M4BhTeleport:
        move.w #M4_SH_BOSS_H_3,d0
        moveq #7,d1
        move.l #M4BhTeleIstrat,d2
        bsr M4BhMakeChild
        moveq #7,d0
        jsr M4BsChild
        beq.s M4BhTeleportDone ;ROM: moveobjtoend_l on X = 0 (not modelled)
        bsr M4BhMoveToEnd
M4BhTeleportDone:
        bra M4BhNext
; 18 waitforteleportfinish EA33: teleporter alive -> move; else (sflags2
; &= $7F: sflag4 never set) next.
M4BhWaitTele:
        moveq #7,d0
        jsr M4BsChild
        bne M4BhMove
        bra M4BhNext
; 19 waitabitthenloop E9FF: pbyte1 30 -> 0, mode 13 (bh_looptohere),
; dispatched again; else pbyte1 + 1 and move3.
M4BhWaitLoop:
        cmpi.b #30,X2_PBYTE1(a0)
        bne.s M4BhWaitLoopInc
        clr.b X2_PBYTE1(a0)
        move.b #13,X_STATE(a0)
        bra M4BhBody
M4BhWaitLoopInc:
        addq.b #1,X2_PBYTE1(a0)
        bra M4BhMove3
; 20 stand ED51 / 21 crouch ED47 (not reachable: mode 19 loops to 13).
M4BhStand:
        addq.b #1,37(a0)
        cmpi.b #15,37(a0)
        beq M4BhNext
        moveq #3,d1
        bsr M4BhSetChildMode
        bra M4BhMove
M4BhCrouch:
        moveq #4,d1
        bsr M4BhSetChildMode
        bra M4BhMove

; .move2 F065: legs in waggle >= 3 -> next; 2 -> sbyte3 6; 1 -> sbyte3 4;
; y + ytab[gameframe & 3] (00:EEAD); then .move3.
M4BhMove2:
        moveq #6,d1
        bsr M4BhChkChildMode
        move.b d0,d1
        subq.b #3,d1
        bpl M4BhNext
        cmpi.b #2,d0
        bne.s M4BhMove2One
        move.b #6,X_SBYTE3(a0)
        bra.s M4BhMove2Y
M4BhMove2One:
        cmpi.b #1,d0
        bne.s M4BhMove2Y
        move.b #4,X_SBYTE3(a0)
M4BhMove2Y:
        move.w M4_LV_GAMEFRAME,d0
        andi.w #3,d0
        add.w d0,d0
        move.w M4BhYTab(pc,d0.w),d0
        add.w d0,2(a0)
; .move3 F0A3: x = 4 * sin8(sbyte4), sbyte4 + 2.
M4BhMove3:
        moveq #2,d1
        bsr M4BhSway
; .move F0CB: roty + sbyte3 (trigse $4F when bit 7 changes and sbyte3 >= 8:
; audio); addplayerZ; while a leg 1..5 lives HP = 64, else coltab id_1_c,
; nohitaffect off, tx + 10; tx + 5; rotpos of the children; m_bossHP +=
; HP + hitcount.
M4BhMove:
        move.b X_SBYTE3(a0),d0
        add.b d0,13(a0)
        jsr M4EnAddPZ
        moveq #1,d6
M4BhAliveNext:
        move.b d6,d0
        jsr M4BsChild
        bne.s M4BhLegsAlive
        addq.b #1,d6
        cmpi.b #6,d6
        bne.s M4BhAliveNext
        move.w #M4_BH_RED,X_COLTAB(a0)
        bclr #SF_NOHITAFFECT,49(a0)
        addi.b #10,X_TX(a0)
        bra.s M4BhTx
M4BhLegsAlive:
        move.b #64,38(a0)
M4BhTx:
        addq.b #5,X_TX(a0)
        jsr M4PvRotChildren
        move.b 38(a0),d0
        add.b M4_BH_HITCOUNT,d0
        add.b d0,M4_BOSS_HP
        moveq #0,d0
        rts
M4BhYTab:
        include '../build/m4-meteor-leg-y.inc'
M4BhLegIds:
        include '../build/m4-meteor-leg-ids.inc'
        even

; setchildmode EE57: legs in M4BhLegIds get stratstate d1 (a missing leg:
; 7E:1CDC, kept in M4_BH_PHANTOM).
M4BhSetChildMode:
        move.b d1,d5
        lea M4BhLegIds,a3
        moveq #4,d6
M4BhSetNext:
        move.b (a3)+,d0
        jsr M4BsChild ;clobbers d1
        beq.s M4BhSetPhantom
        move.b d5,X_STATE(a2)
        bra.s M4BhSetSkip
M4BhSetPhantom:
        move.b d5,M4_BH_PHANTOM
M4BhSetSkip:
        dbra d6,M4BhSetNext
        rts
; chkchildmode EE34: d0 = number of legs 1..5 in stratstate d1 (a missing
; leg reads 7E:1CDC).
M4BhChkChildMode:
        move.b d1,d5
        moveq #0,d7
        moveq #1,d6
M4BhChkNext:
        move.b d6,d0
        jsr M4BsChild ;clobbers d1
        beq.s M4BhChkPhantom
        cmp.b X_STATE(a2),d5
        bra.s M4BhChkTest
M4BhChkPhantom:
        cmp.b M4_BH_PHANTOM,d5
M4BhChkTest:
        bne.s M4BhChkSkip
        addq.b #1,d7
M4BhChkSkip:
        addq.b #1,d6
        cmpi.b #6,d6
        bne.s M4BhChkNext
        move.b d7,d0
        rts

; .generate EEB5: sbyte1, al_ptr and sword1 cleared; five legs boss_h_1
; (bosshleg_istrat F15A) and the top boss_h_2 (F614), offsets 00:EEDF..F05B
; (x, y, z BYTEs, childroty); a failed creation skips that child; rotpos.
M4BhGenerate:
        clr.b 36(a0)
        clr.w X_ALPTR(a0)
        clr.w 40(a0)
        lea M4BhChildren,a3
        moveq #5,d6
M4BhGenNext:
        move.w #M4_SH_BOSS_H_1,d0
        move.l #M4BhLegIstrat,d2
        cmpi.b #6,(a3)
        bne.s M4BhGenMake
        move.w #M4_SH_BOSS_H_2,d0
        move.l #M4BhTopIstrat,d2
M4BhGenMake:
        move.b (a3),d1
        bsr M4BhMakeChild
        beq.s M4BhGenSkip
        move.b 1(a3),X2_CHILDX(a2)
        move.b 2(a3),X2_CHILDX+1(a2)
        move.b 3(a3),X2_CHILDX+2(a2)
        move.b 4(a3),X2_CHILDRX+1(a2)
M4BhGenSkip:
        addq.l #5,a3
        dbra d6,M4BhGenNext
        jmp M4PvRotChildren
M4BhChildren: ;id, x, y, z, childroty
        include '../build/m4-meteor-boss-children.inc'
        even

; make_childobjrotpos: d0 descriptor, d1 id, d2.l Istrat -> a2 (Z when the
; pool is full: skipped as 1F:D54B carry clear). Linked behind a0 in allst
; (1F:D3A9) and at the end of its chain (1F:D56F); collflags enemy1.
M4BhMakeChild:
        movem.l d0-d2/a3,-(sp)
        jsr M4EnCreate
        beq.s M4BhMakeDone
        move.b d1,36(a2)
        move.w a0,X_ALPTR(a2)
        clr.w 40(a2)
        movea.l a0,a3
M4BhMakeTail:
        move.w 40(a3),d0
        beq.s M4BhMakeLink
        movea.w d0,a3
        bra.s M4BhMakeTail
M4BhMakeLink:
        move.w a2,40(a3)
        bset #6,X2_FL4(a0)
        bset #4,X2_FL4(a2)
        move.l d2,32(a2)
        ori.b #CF_ENEMY1,44(a2)
        cmpa.w #0,a2
M4BhMakeDone:
        movem.l (sp)+,d0-d2/a3
        rts

; moveobjtoend_l 09:C0F7: a2 unlinked from allst and appended at its end.
M4BhMoveToEnd:
        movem.l d0/a3,-(sp)
        lea M4_LV_HEAD-X_NEXT,a3
M4BhEndFind:
        move.w X_NEXT(a3),d0
        beq.s M4BhEndDone
        cmp.w a2,d0
        beq.s M4BhEndFound
        movea.w d0,a3
        bra.s M4BhEndFind
M4BhEndFound:
        move.w X_NEXT(a2),d0
        beq.s M4BhEndDone ;already the last one
        move.w d0,X_NEXT(a3)
        movea.w d0,a3
M4BhEndTail:
        move.w X_NEXT(a3),d0
        beq.s M4BhEndLink
        movea.w d0,a3
        bra.s M4BhEndTail
M4BhEndLink:
        move.w a2,X_NEXT(a3)
        clr.w X_NEXT(a2)
M4BhEndDone:
        movem.l (sp)+,d0/a3
        rts

; .createsmoke ED6A: Lsmoke 00:ADF1 behind the body, strategy EDE0,
; colframe $80, colldisable, at the body, ssprite, depthoffset 0; tx =
; (rnd & 31) - 15; x += 2 * sext(rnd). Pool full: nothing (no rnd).
M4BhSmoke:
        move.w #M4_FX_LSMOKE,d0
        jsr M4EnCreate
        beq.s M4BhSmokeDone
        move.l #M4BhSmokeTick,32(a2)
        move.b #$80,18(a2)
        bset #SF_COLLDISABLE,49(a2)
        move.l (a0),(a2)
        move.w 4(a0),4(a2)
        bset #F2_SPRITE,48(a2)
        clr.b X_DEPTHOFF(a2)
        clr.b X_TX(a2)
        jsr M4IntroRandom
        andi.b #31,d0
        subi.b #15,d0
        add.b d0,X_TX(a2)
        jsr M4IntroRandom
        ext.w d0
        add.w d0,d0
        add.w d0,(a2)
M4BhSmokeDone:
        rts
; .smoke EDE0: colframe 7 -> removed (deferred); else colframe + 1 (mod 8).
M4BhSmokeTick:
        move.b 18(a0),d0
        andi.b #$7f,d0
        cmpi.b #7,d0
        beq.s M4BhSmokeGone
        addq.b #1,d0
        andi.b #7,d0
        ori.b #$80,d0
        move.b d0,18(a0)
        moveq #0,d0
        rts
M4BhSmokeGone:
        moveq #1,d0
        rts

; .explode EE08 (expstrat, HP 0): top killed (colldisable, HP 0), the
; teleporter removed (1F:D540), then bossexplode 06:EAAE.
M4BhExplode:
        moveq #6,d0
        jsr M4BsChild
        beq.s M4BhExplodeTele
        bset #SF_COLLDISABLE,49(a2)
        clr.b 38(a2)
M4BhExplodeTele:
        moveq #7,d0
        jsr M4BsChild
        beq.s M4BhBossExplode
        exg a0,a2
        jsr M4LevelRemove
        exg a0,a2
; bossexplode 06:EAAE as M4B1Explode (level_boss1.asm, same ROM routine):
; dying flags, 14 delayed explosions, the flash timer, then 06:EA09 with
; stratptr2 ($1CD9) = 0 for bossh: no extra strategy while dying.
M4BhBossExplode:
        tst.b M4_BOSS_DYING
        bne.s M4BhExplodeChain
        st M4_BOSS_DYING
        bset #5,M4_BOSS_PSTRATF
        bset #6,M4_LP_PSF
M4BhExplodeChain:
        lea M4B1ExplList,a3
        moveq #13,d6
M4BhExplodeNext:
        move.b (a3)+,d0
        ext.w d0
        jsr M4B1Expl
        beq.s M4BhExplodeFail
        jsr M4FxRandomPos
        move.b (a3),19(a2)
        cmpi.w #13,d6
        bne.s M4BhExplodeOne
        bclr #F2_NOEXPSND,48(a2)
        bra.s M4BhExplodeOne
M4BhExplodeFail:
        jsr M4IntroRandom
        jsr M4IntroRandom
M4BhExplodeOne:
        addq.l #1,a3
        dbra d6,M4BhExplodeNext
        moveq #-1,d0
        jsr M4EnCreate
        beq.s M4BhExplodeNoTimer
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
M4BhExplodeNoTimer:
        move.b #38,19(a0)
        move.b #$ff,38(a0)
        move.b #8,39(a0)
        move.l #M4BhDying,32(a0)
        clr.l X_COLL(a0)
        move.l #M4LevelExplode,X_EXP(a0)
; 06:EA38: hitflash; count - 1; was 0: colldisable, HP 0, huge explosion,
; gameflags bossdead, explode now; else addplayerZ (stratptr2 0: nothing).
M4BhDying:
        bset #SF_HITFLASH,49(a0)
        subq.b #1,19(a0)
        bpl.s M4BhDyingWait
        bset #SF_COLLDISABLE,49(a0)
        clr.b 38(a0)
        move.w #M4_FX_HUGE,d0
        jsr M4B1Expl
        bset #2,M4_LP_GAMEFLAGS
        jmp M4LevelExplode
M4BhDyingWait:
        jsr M4EnAddPZ
        moveq #0,d0
        rts

; ---------------------------------------------------------------------
; Leg Istrat F15A: collstrat .hit F53D, expstrat .explode F547; HP 74 / AP
; 4, depthoffset 1, animframe (sbyte1 - 2) | $80, stratstate 0; mode table
; 00:F1B2 (F1A1).
M4BhLegIstrat:
        move.l #M4BhLeg,32(a0)
        move.l #M4BhLegHit,X_COLL(a0)
        move.l #M4BhLegExplode,X_EXP(a0)
        move.b #74,38(a0)
        move.b #4,39(a0)
        move.b #1,X_DEPTHOFF(a0)
        move.b 36(a0),d0
        subq.b #2,d0
        ori.b #$80,d0
        move.b d0,16(a0)
        clr.b X_STATE(a0)
M4BhLeg:
        moveq #0,d0
        move.b X_STATE(a0),d0
        cmpi.b #15,d0
        bhs M4BhLegMove
        add.w d0,d0
        move.w M4BhLegModes(pc,d0.w),d0
        jmp M4BhLegModes(pc,d0.w)
M4BhLegModes:
        dc.w M4BhLegScamper-M4BhLegModes,M4BhLegShake-M4BhLegModes
        dc.w M4BhLegShake2-M4BhLegModes,M4BhLegStand-M4BhLegModes
        dc.w M4BhLegCrouch-M4BhLegModes,M4BhLegUp-M4BhLegModes
        dc.w M4BhLegWaggle-M4BhLegModes,M4BhLegFlat-M4BhLegModes
        dc.w M4BhLegTo30-M4BhLegModes,M4BhLegLower-M4BhLegModes
        dc.w M4BhLegMove-M4BhLegModes,M4BhLegScamper3-M4BhLegModes
        dc.w M4BhLegMidPose-M4BhLegModes,M4BhLegMove-M4BhLegModes
        dc.w M4BhLegScamper2-M4BhLegModes
M4BhLegNext:
        addq.b #1,X_STATE(a0)
        bra.s M4BhLeg

; animframe + d1 modulo 16 (F4BA: add, +16 when bit 7 is lost, & $7F,
; - 16 when >= 16, | $80).
M4BhAnimAdd:
        move.b 16(a0),d0
        add.b d1,d0
        bmi.s M4BhAnimAddW
        addi.b #16,d0
M4BhAnimAddW:
        andi.b #$7f,d0
        cmpi.b #16,d0
        blo.s M4BhAnimAddS
        subi.b #16,d0
M4BhAnimAddS:
        ori.b #$80,d0
        move.b d0,16(a0)
        rts
M4BhAnimDec:
        moveq #-1,d1
        bra.s M4BhAnimAdd
M4BhAnimInc:
        moveq #1,d1
        bra.s M4BhAnimAdd
; animframe + 1 clamped to d2 - 1 (s_add_anim with an end label): Z clear
; (d0 nonzero) when the end was reached.
M4BhAnimClamp:
        move.b 16(a0),d0
        addq.b #1,d0
        bmi.s M4BhAnimClampW
        add.b d2,d0
M4BhAnimClampW:
        andi.b #$7f,d0
        cmp.b d2,d0
        blo.s M4BhAnimClampS
        move.b d2,d0
        subq.b #1,d0
        ori.b #$80,d0
        move.b d0,16(a0)
        moveq #1,d0
        rts
M4BhAnimClampS:
        ori.b #$80,d0
        move.b d0,16(a0)
        moveq #0,d0
        rts
; d0 = animframe & $7F.
M4BhAnim:
        move.b 16(a0),d0
        andi.b #$7f,d0
        rts

; Scamper modes: sflag1 set: frame lo -> trigse $97 and toggle, else - 1;
; clear: frame hi -> toggle, else + 1; then .animed. 0 scampering F4DD
; (0..3), 11 scamper3 F226 (9..11), 14 scamper2 F1EE (4..6).
M4BhLegScamper:
        moveq #0,d2
        moveq #3,d3
        bra.s M4BhLegScamp
M4BhLegScamper3:
        moveq #9,d2
        moveq #11,d3
        bra.s M4BhLegScamp
M4BhLegScamper2:
        moveq #4,d2
        moveq #6,d3
M4BhLegScamp:
        bsr M4BhAnim
        btst #F2_SFLAG1,48(a0)
        beq.s M4BhLegScampUp
        cmp.b d2,d0
        beq.s M4BhLegScampFlip
        bsr M4BhAnimDec
        bra.s M4BhLegAnimed
M4BhLegScampUp:
        cmp.b d3,d0
        beq.s M4BhLegScampFlip
        bsr M4BhAnimInc
        bra.s M4BhLegAnimed
M4BhLegScampFlip:
        bchg #F2_SFLAG1,48(a0)
; .animed F510: N(HP - 64) -> mode legup (5).
M4BhLegAnimed:
        move.b 38(a0),d0
        subi.b #64,d0
        bpl.s M4BhLegMove
        move.b #5,X_STATE(a0)
; .move F51B: shape boss_h_1a (BC28) from animframe 13, else boss_h_1.
M4BhLegMove:
        bsr M4BhAnim
        move.w #M4_SH_BOSS_H_1,d1
        cmpi.b #13,d0
        blo.s M4BhLegShape
        move.w #M4_SH_BOSS_H_1A,d1
M4BhLegShape:
        cmp.w 46(a0),d1
        beq.s M4BhLegEnd
        move.w d1,d0
        jsr M4LevelSetShape
M4BhLegEnd:
        moveq #0,d0
        rts

; 1 shakealeg F407: sflag1 off, next. 2 shakealeg2 F410: up to 5 and back
; to 0, then mode 0 (dispatched again).
M4BhLegShake:
        bclr #F2_SFLAG1,48(a0)
        bra M4BhLegNext
M4BhLegShake2:
        bsr M4BhAnim
        btst #F2_SFLAG1,48(a0)
        beq.s M4BhLegShakeUp
        tst.b d0
        bne.s M4BhLegShakeDec
        clr.b X_STATE(a0)
        bra M4BhLeg
M4BhLegShakeDec:
        bsr M4BhAnimDec
        bra M4BhLegMove
M4BhLegShakeUp:
        cmpi.b #5,d0
        bne.s M4BhLegShakeInc
        bchg #F2_SFLAG1,48(a0)
        bra M4BhLegMove
M4BhLegShakeInc:
        bsr M4BhAnimInc
        bra M4BhLegMove
; 3 stand F37B: toward frame 0 (the bpl at F388 is always taken: -1).
M4BhLegStand:
        bsr M4BhAnim
        tst.b d0
        beq.s M4BhLegMove
        bsr M4BhAnimDec
        bra M4BhLegMove
; 4 crouch F357: + 1 up to 10.
M4BhLegCrouch:
        moveq #11,d2
        bsr M4BhAnimClamp
        bra M4BhLegMove
; 5 legup F471: + 1; at 10 next (waggle), else HP 74.
M4BhLegUp:
        moveq #11,d2
        bsr M4BhAnimClamp
        bne M4BhLegNext
        move.b #74,38(a0)
        bra M4BhLegMove
; 6 waggle F499: HP 74; frame 10 <-> 9.
M4BhLegWaggle:
        move.b #74,38(a0)
        bsr M4BhAnim
        moveq #$8a-256,d1
        cmpi.b #10,d0
        bne.s M4BhLegWaggleSet
        moveq #$89-256,d1
M4BhLegWaggleSet:
        move.b d1,16(a0)
        bra M4BhLegMove
; 7 movetoflat F2FB: red: collstrat .hit; else HP 74 and collstrat
; defelasercol 06:889E (ricochet, M4B1Ricochet); + 1 up to 14.
M4BhLegFlat:
        cmpi.w #M4_BH_RED,X_COLTAB(a0)
        bne.s M4BhLegFlatBlue
        move.l #M4BhLegHit,X_COLL(a0)
        bra.s M4BhLegFlatAnim
M4BhLegFlatBlue:
        move.b #74,38(a0)
        move.l #M4B1Ricochet,X_COLL(a0)
M4BhLegFlatAnim:
        moveq #15,d2
        bsr M4BhAnimClamp
        bra M4BhLegMove
; 8 moveto30 F3C2: every 16 ticks - 1 down to 11.
M4BhLegTo30:
        move.w M4_LV_GAMEFRAME,d0
        andi.w #15,d0
        bne M4BhLegMove
        bsr M4BhAnim
        cmpi.b #11,d0
        beq M4BhLegMove
        bsr M4BhAnimDec
        bra M4BhLegMove
; 9 lowerpose F25E / 12 middlepose F2AB: collstrat .hit, HP 74, sflag1;
; frame (sbyte1 & 3) + 9 / + 4 reached -> next, else - 1.
M4BhLegLower:
        moveq #9,d2
        bra.s M4BhLegPose
M4BhLegMidPose:
        moveq #4,d2
M4BhLegPose:
        move.l #M4BhLegHit,X_COLL(a0)
        move.b #74,38(a0)
        bset #F2_SFLAG1,48(a0)
        move.b 36(a0),d1
        andi.b #3,d1
        add.b d1,d2
        bsr M4BhAnim
        cmp.b d2,d0
        beq M4BhLegNext
        bsr M4BhAnimDec
        bra M4BhLegMove

; .hit F53D: trigse $24 (audio), hitflash 06:89A3.
M4BhLegHit:
        jmp M4LcHitFlash
; .explode F547 (expstrat, HP 0): hitcount - 5; expstrat .explode2 F5A2;
; leaves the mother's chain (sflags4 child off); vel 120, gen2d by roty
; (vx, vz); colldisable; then .explode2 this tick.
M4BhLegExplode:
        subq.b #5,M4_BH_HITCOUNT
        move.l #M4BhLegFall,X_EXP(a0)
        movea.l a0,a2
        jsr M4PvDivorce
        move.b #120,15(a0)
        jsr M4EnGen2d
        bset #SF_COLLDISABLE,49(a0)
; .explode2 F5A2: pos += v, roty + $10 (deg22), vy + 4; ground y >= -20:
; bounce; bounce speed 0 -> explode_Istrat 06:F45F.
M4BhLegFall:
        jsr M4EnMove
        addi.b #$10,13(a0)
        addq.w #4,8(a0)
        move.w 2(a0),d0
        addi.w #20,d0
        bmi.s M4BhLegFallKeep
        move.w #-20,2(a0)
        bsr M4BhBounce
        bne.s M4BhLegFallKeep
        jmp M4LevelExplode
M4BhLegFallKeep:
        moveq #0,d0
        rts

; ---------------------------------------------------------------------
; Top Istrat F614: shadow, hitflash / explode_Istrat (1F:D41A), HP $FF / AP
; 8, nohitaffect. F639: childroty + 5; facing roty >= $F0 or < $10 and
; (gameframe & 15) = 0: Hplasma ($26) from (0, -50, 0), roty + $80, al_ptr
; = player, life 255, enemy1 (a failed fire writes the dummy object).
M4BhTopIstrat:
        bset #F2_SHADOW,48(a0)
        move.l #M4BhTop,32(a0)
        move.l #M4LcHitFlash,X_COLL(a0)
        move.l #M4BhPartExplode,X_EXP(a0)
        move.b #$ff,38(a0)
        move.b #8,39(a0)
        bset #SF_NOHITAFFECT,49(a0)
M4BhTop:
        addq.b #5,X2_CHILDRX+1(a0)
        move.b 13(a0),d0
        cmpi.b #$f0,d0
        bhs.s M4BhTopFire
        cmpi.b #$10,d0
        bhs.s M4BhTopEnd
M4BhTopFire:
        move.w M4_LV_GAMEFRAME,d0
        andi.w #15,d0
        bne.s M4BhTopEnd
        moveq #M4_WT_HPLASMA,d0
        moveq #0,d3
        moveq #-50,d4
        moveq #0,d5
        moveq #0,d6
        move.l #$80,d7
        suba.l a3,a3
        jsr M4EnFire
        cmpa.w #0,a2
        beq.s M4BhTopEnd
        move.w a1,X_ALPTR(a2)
        move.b #$ff,19(a2)
        ori.b #CF_ENEMY1,44(a2)
M4BhTopEnd:
        moveq #0,d0
        rts

; explode_Istrat 06:F45F of a child: divorcefamily 1F:DBA4 first (the top
; leaves the body's chain this tick; M4LevelExplode does not divorce).
M4BhPartExplode:
        btst #4,X2_FL4(a0)
        beq.s M4BhPartExplodeNow
        movea.l a0,a2
        jsr M4PvDivorce
M4BhPartExplodeNow:
        jmp M4LevelExplode

; ---------------------------------------------------------------------
; Teleporter Istrat F69E: animframe $80, HP $FF / AP 8, colldisable,
; sbyte2 50. F6C4: (sflag1, never set: frames back to 0, removed) sbyte2
; 20 or 1 -> fire_bonfire; sbyte2 > 0: - 1, frame + 1 up to 9; sbyte2 0:
; frame + 1, at 19 removed; ty - 5 (texture scroll); addplayerZ; rots 0.
M4BhTeleIstrat:
        move.b #$80,16(a0)
        move.b #$ff,38(a0)
        move.b #8,39(a0)
        bset #SF_COLLDISABLE,49(a0)
        move.l #M4BhTele,32(a0)
        move.b #50,37(a0)
M4BhTele:
        btst #F2_SFLAG1,48(a0)
        beq.s M4BhTeleLive
        bsr M4BhAnim
        tst.b d0
        beq.s M4BhTeleGone
        bsr M4BhAnimDec
        bra.s M4BhTeleMove
M4BhTeleLive:
        cmpi.b #20,37(a0)
        beq.s M4BhTeleFire
        cmpi.b #1,37(a0)
        bne.s M4BhTeleNoFire
M4BhTeleFire:
        bsr M4BhFireBonfire
M4BhTeleNoFire:
        tst.b 37(a0)
        beq.s M4BhTeleKnock
        subq.b #1,37(a0)
        moveq #10,d2
        bsr M4BhAnimClamp
M4BhTeleScroll:
        subq.b #5,X_TY(a0)
M4BhTeleMove:
        jsr M4EnAddPZ
        clr.w 12(a0)
        clr.b 14(a0)
        moveq #0,d0
        rts
M4BhTeleKnock:
        moveq #20,d2
        bsr M4BhAnimClamp
        beq.s M4BhTeleScroll
M4BhTeleGone:
        moveq #1,d0
        rts

; fire_bonfire F773: fireball 00:AD9D behind the teleporter, at it with y =
; 0, bonfire_istrat F7D9, enemy1 (trigse $99); rotx/roty toward the player
; (obj2obj_3dangle: 1F:D03E pitch, 1F:D021 yaw).
M4BhFireBonfire:
        move.w #M4_FX_FIREBALL,d0
        jsr M4EnCreate
        beq.s M4BhFireBonfireDone
        move.l (a0),(a2)
        move.w 4(a0),4(a2)
        clr.w 2(a2)
        move.l #M4BhBonfireIstrat,32(a2)
        ori.b #CF_ENEMY1,44(a2)
        move.l a0,-(sp)
        movea.l a2,a0
        movea.l a1,a2
        jsr M4EnPitchTo
        move.b d0,12(a0)
        jsr M4EnYawTo
        move.b d0,13(a0)
        movea.l (sp)+,a0
M4BhFireBonfireDone:
        rts
; bonfire_istrat F7D9: hitflash / explode_Istrat, nohitaffect, HP $FF / AP
; 8, coltab bonfire_c, ssprite, depthoffset 0, tx 0, vel 120, gen3d. F828:
; each tick a trail fireball (F860, colldisable) at it, then pos += v,
; addplayerZ.
M4BhBonfireIstrat:
        move.l #M4BhBonfire,32(a0)
        move.l #M4LcHitFlash,X_COLL(a0)
        move.l #M4LevelExplode,X_EXP(a0)
        bset #SF_NOHITAFFECT,49(a0)
        move.b #$ff,38(a0)
        move.b #8,39(a0)
        move.w #M4_BH_FIRECOL,X_COLTAB(a0)
        bset #F2_SPRITE,48(a0)
        clr.b X_DEPTHOFF(a0)
        clr.b X_TX(a0)
        move.b #120,15(a0)
        jsr M4EnGen3d
M4BhBonfire:
        move.w #M4_FX_FIREBALL,d0
        jsr M4EnCreate
        beq.s M4BhBonfireMove
        move.l (a0),(a2)
        move.w 4(a0),4(a2)
        move.l #M4BhTrail,32(a2)
        bset #SF_COLLDISABLE,49(a2)
M4BhBonfireMove:
        jsr M4EnMove
        jsr M4EnAddPZ
        moveq #0,d0
        rts
; .dummdumm_strat F860 (every tick): enemy1, coltab bonfire_c, ssprite,
; depthoffset 1, tx 0; sbyte1 10 -> removed (deferred), else + 1 and
; addplayerZ.
M4BhTrail:
        ori.b #CF_ENEMY1,44(a0)
        move.w #M4_BH_FIRECOL,X_COLTAB(a0)
        bset #F2_SPRITE,48(a0)
        move.b #1,X_DEPTHOFF(a0)
        clr.b X_TX(a0)
        cmpi.b #10,36(a0)
        beq.s M4BhTrailGone
        addq.b #1,36(a0)
        jsr M4EnAddPZ
        moveq #0,d0
        rts
M4BhTrailGone:
        moveq #1,d0
        rts

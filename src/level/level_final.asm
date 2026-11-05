; End of a level (build/research/corneria-missing.md section 4; oracle
; tools/clship-oracle.py): ClearDemo 0B:9558..96xx, dupplayer 0B:EA5E,
; clshipboost 06:C115, the friends' ships clshipGND 06:BF90/BFDF/C02E,
; calcteamdamage 06:BB22 and end_level_seq 02:EC20 (logic: calcstageperc
; 02:EBBB, the count of printspeclp 02:EC42 and checkbonus 02:EF57).
; Game state that outlives a level lives in M4_GM.

M4_GM equ $fff800
M4_GM_CLB2 equ M4_GM+0 ;.b $001C clb2: end_level_seq exit
M4_GM_DONEACIRCLE equ M4_GM+1 ;.b $1FD0 doneacircle
M4_GM_SPECTOT equ M4_GM+2 ;.b $1F0A spectot
M4_GM_SPECDEAD equ M4_GM+3 ;.b $1F09 spectotdead
M4_GM_PLANETDEAD equ M4_GM+4 ;.b $18AF planetdead
M4_GM_SPECPTR equ M4_GM+5 ;.b $1FBD specptr
M4_GM_CREDITS equ M4_GM+6 ;.b $189A credits
M4_GM_STAGE equ M4_GM+7 ;.b $16D8 stage
M4_GM_SPECBUF equ M4_GM+8 ;8 BYTEs specbuf (stage percentages)
M4_GM_RESULTS equ M4_GM+16 ;.b end_level_seq running
M4_GM_ONECRED equ M4_GM+17 ;.b $1FCF onecredspr
M4_GM_CLA1 equ M4_GM+18 ;.w $16 cla1 (shown percentage)
M4_GM_CLA2 equ M4_GM+20 ;.w $18 cla2 (stage percentage)
M4_GM_CLB1 equ M4_GM+22 ;.w $1A clb1 (bonus credit timer)
M4_GM_CLBM equ M4_GM+24 ;.w $22 clbm (previous total)
M4_GM_CLAM equ M4_GM+26 ;.w $20 clam
M4_GM_PLOTX1 equ M4_GM+28 ;.w $24 plotx1
M4_GM_TOTAL equ M4_GM+30 ;.w calctotalscore
M4_GM_SIZE equ 32

; initialise_l 02:E265 (game start): credits, stage and route totals.
M4GameInit:
        clr.l M4_TX_HOOK
        clr.b M4_END_ON ;level_ending.asm: no ending running
        lea M4_GM,a0
        moveq #M4_GM_SIZE/4-1,d0
M4GmClear:
        clr.l (a0)+
        dbra d0,M4GmClear
        rts

; calcteamdamage 06:BB22 (0D:CF2A): spectot += specialobjtotal, spectotdead
; += specials_dead; total != dead -> planetdead = min(100, planetdead +
; 2*(total - dead)) (route state of the planet map).
M4LvCalcTeamDamage:
        move.b M4_LV_SPECIALS+1,d0
        add.b d0,M4_GM_SPECTOT
        move.b M4_LV_SPECIALDEAD+1,d1
        add.b d1,M4_GM_SPECDEAD
        sub.b d1,d0
        beq.s M4LvTeamDone
        add.b d0,d0
        add.b M4_GM_PLANETDEAD,d0
        cmpi.b #100,d0
        bls.s M4LvTeamStore
        moveq #100,d0
M4LvTeamStore:
        move.b d0,M4_GM_PLANETDEAD
M4LvTeamDone:
        rts

; ---------------------------------------------------------------------
; ClearDemo. set_playerClearDemo 0B:9558 only replaces the player's
; strategy (it keeps its allst place); the Istrat runs this same tick.
; Counters $1553/$1554/$1555 are the scramble psvar bytes (M4_SC_P155x).
M4CdIstrat: ;0B:956D
        move.l #M4CdPhase1,32(a0)
        move.b #110,M4_SC_P1554
        ori.b #$60,M4_LP_PSF ;noctrl, nofire
        andi.b #$df,M4_LP_GAMEFLAGS ;no viewrot
        move.w #-10000,M4_LP_MINY ;minPmoveY = minPWmoveY = $D8F0
        ori.b #$09,M4_BOSS_PSTRATF ;novdistC | inseq
        move.b #180,M4_SC_P1555
M4CdPhase1: ;0B:95CC
        tst.b M4_SC_P1554
        beq.s M4CdPhase2Init
        subq.b #1,M4_SC_P1554
        move.w M4_LP_OUTVX,d0 ;centoutrots 0B:AB4F
        moveq #0,d1
        moveq #3,d2
        jsr M4LpAchase
        move.w d0,M4_LP_OUTVX
        move.w M4_LP_OUTVY,d0
        jsr M4LpAchase
        move.w d0,M4_LP_OUTVY
        moveq #4,d2
        move.w 2(a0),d0
        moveq #-50,d1
        jsr M4LpAchase
        move.w d0,2(a0)
        move.w (a0),d0
        moveq #0,d1
        jsr M4LpAchase
        move.w d0,(a0)
        move.b #85,M4_LP_TOSPEED ;viewmove_srou puts medspeed back (sbyte2 <= 10)
        cmpi.w #300,M4_LP_OUTDIST
        bgt.s M4CdArm1
        addq.w #4,M4_LP_OUTDIST
M4CdArm1:
        subq.b #1,M4_SC_P1555
        jmp M4LevelPlayerStrat ;jml playeronplanet_strat 0B:BBE3 (no control)
M4CdPhase2Init: ;0B:9629
        move.l #M4CdPhase2,32(a0)
        clr.b M4_SC_P1553
        move.b #250,M4_SC_P1554
M4CdPhase2: ;0B:9640
        move.b M4_LP_OUTVY,d0 ;hi(outvy) - $C0 >= 0 (8 bits) -> outvy -= 32
        subi.b #$c0,d0
        bmi.s M4CdNoYaw
        subi.w #32,M4_LP_OUTVY
M4CdNoYaw:
        tst.b M4_SC_P1554
        beq.s M4CdNoCount
        subq.b #1,M4_SC_P1554
        move.b M4_SC_P1554,d0
        add.b d0,M4_SC_P1553
M4CdNoCount:
        cmpi.w #600,M4_LP_OUTDIST
        bgt.s M4CdArm2
        addq.w #4,M4_LP_OUTDIST
M4CdArm2:
        subi.w #$200,M4_LP_PLROTX
        subq.w #1,M4_SC_BG2Y
        movem.l d0-d7/a1,-(sp)
        jsr M4LpMove ;playermove_srou 0B:D33A (no control)
        movem.l (sp)+,d0-d7/a1
        tst.b M4_SC_P1555
        beq.s M4CdNoDup
        subq.b #1,M4_SC_P1555
        cmpi.b #1,M4_SC_P1555
        bne.s M4CdNoDup
        bsr M4CdDupPlayer
        andi.b #$fd,M4_LP_PSF3
M4CdNoDup:
        movem.l d0-d7/a1,-(sp)
        jsr M4LpViewMove ;viewmove_srou (novdistC: no arm chase)
        movem.l (sp)+,d0-d7/a1
        move.w (a0),d0 ;pviewposx = asr1+asr2+asr3 (floor)
        move.w d0,d1
        asr.w #1,d1
        move.w d0,d2
        asr.w #2,d2
        add.w d2,d1
        asr.w #3,d0
        add.w d0,d1
        move.w d1,M4_LP_PVIEWX
        move.w 2(a0),M4_LP_PVIEWY ;y before the move
        moveq #0,d0
        move.b 15(a0),d0
        jsr M4LevelGen3dVecs ;1F:D5A7
        jsr M4EnMove
        moveq #0,d0
        rts

; dupplayer 0B:EA5E: a copy of the player (current shape, position and
; rotation), colldisable and shadow, running clshipboost; the player
; becomes invisible. No free slot: skipped (the ROM writes through an
; invalid Y).
M4CdDupPlayer:
        movem.l d0/a0-a2,-(sp)
        movea.l a0,a2
        jsr M4LevelAlloc
        move.l a0,d0
        beq.s M4CdDupDone
        move.w 46(a2),d0
        jsr M4LevelSetShape
        move.l (a2),(a0)
        move.w 4(a2),4(a0)
        move.b 12(a2),12(a0)
        move.b 13(a2),13(a0)
        move.b 14(a2),14(a0)
        bset #SF_COLLDISABLE,49(a0)
        bset #F2_SHADOW,48(a0)
        move.l #M4StratClshipBoost,32(a0)
        bset #SF_INVISIBLE,49(a2)
M4CdDupDone:
        movem.l (sp)+,d0/a0-a2
        rts

; clshipboost_I 06:C115: boostobj = this ship, the boost flame (B219),
; vel 120; then 06:C15A every tick: sbyte2 count (0: never removed), pos
; += gen3d(vel, rotx, roty), z += psvar_word2 $1558 (0 outside the Warp).
M4StratClshipBoost:
        jsr M4LevelBoostFlame
        move.b #120,15(a0)
        move.l #M4ClshipBoostTick,32(a0)
M4ClshipBoostTick:
        tst.b 37(a0)
        beq.s M4ClBoostMove
        subq.b #1,37(a0)
        cmpi.b #1,37(a0)
        bne.s M4ClBoostMove
        moveq #1,d0 ;1F:D501
        rts
M4ClBoostMove:
        moveq #0,d0
        move.b 15(a0),d0
        jsr M4LevelGen3dVecs
        jsr M4EnMove
        move.w M4_WP_W1558,d0 ;z += psvar_word2 $1558 (Warp hyperspace)
        add.w d0,4(a0)
        moveq #0,d0
        rts

; ---------------------------------------------------------------------
; Friends' ships of cl_ground. Istrats 06:BF90 (a, Peppy), 06:BFDF (b,
; Slippy), 06:C02E (c, Falco): shadow, no zremove, rotz $C0/$40/-, sword1
; 130/170/120; then every tick x = Achase16_4(x, TX), the offsets dZ/dY
; and the common body 06:C079.
M4StratClshipA:
        move.b #$c0,14(a0)
        move.w #130,40(a0)
        bsr.s M4ClshipInit
        move.l #M4ClshipATick,32(a0)
M4ClshipATick:
        move.w #-50,d1
        move.w #-200,d5
        moveq #20,d6
        bra.s M4ClshipBody
M4StratClshipB:
        move.b #$40,14(a0)
        move.w #170,40(a0)
        bsr.s M4ClshipInit
        move.l #M4ClshipBTick,32(a0)
M4ClshipBTick:
        moveq #50,d1
        moveq #-100,d5
        moveq #40,d6
        bra.s M4ClshipBody
M4StratClshipC:
        move.w #120,40(a0)
        bsr.s M4ClshipInit
        move.l #M4ClshipCTick,32(a0)
M4ClshipCTick:
        moveq #0,d1
        move.w #-300,d5
        moveq #50,d6
        bra.s M4ClshipBody
M4ClshipInit:
        bset #F2_SHADOW,48(a0)
        bclr #3,45(a0) ;no atzremove
        rts
; 06:C079: sword1 0 -> clshipboost_I; sword1 - 1; z = Achase16_3(z,
; player.z + dZ); y = Achase16_2(y, player.y + dY); even gameframe: rotz
; = Achase8_5(rotz, player.rotz); gameframe & 3 == 0: rotx likewise;
; addplayerZ. d1 TX, d5 dZ, d6 dY.
M4ClshipBody:
        move.w (a0),d0
        moveq #4,d2
        jsr M4LpAchase
        move.w d0,(a0)
        tst.w 40(a0)
        beq M4StratClshipBoost
        subq.w #1,40(a0)
        lea LV_PLAYER,a2
        move.w 4(a0),d0
        move.w 4(a2),d1
        add.w d5,d1
        moveq #3,d2
        jsr M4LpAchase
        move.w d0,4(a0)
        move.w 2(a0),d0
        move.w 2(a2),d1
        add.w d6,d1
        moveq #2,d2
        jsr M4LpAchase
        move.w d0,2(a0)
        moveq #5,d2
        btst #0,M4_LV_GAMEFRAME+1
        bne.s M4ClshipNoRoll
        move.b 14(a0),d0
        move.b 14(a2),d1
        jsr M4LpAchase8
        move.b d0,14(a0)
M4ClshipNoRoll:
        moveq #3,d0
        and.w M4_LV_GAMEFRAME,d0
        bne.s M4ClshipNoPitch
        move.b 12(a0),d0
        move.b 12(a2),d1
        moveq #5,d2
        jsr M4LpAchase8
        move.b d0,12(a0)
M4ClshipNoPitch:
        jsr M4EnAddPZ
        moveq #0,d0
        rts

; ---------------------------------------------------------------------
; levelfinished = 3 -> end_level_seq 02:EC20. The world keeps running
; (transfer_l each iteration, without friends_messages_l) until clb2 != 0.
; calcstageperc 02:EBBB: 5 per living friend; stageclear = 0; p =
; specials_dead*100/specialobjtotal (0 without specials); cla2 = min(p +
; bonus, 100). calctotalscore 02:E8A6: the sum of specbuf (no $65 entries).
M4LvResultsStart:
        addq.b #1,M4_GM_STAGE ;gamestart 02:E3FF: levelfinished != 0 -> stage++
        st M4_GM_RESULTS
        move.l #M4TxResults,M4_TX_HOOK
        moveq #0,d2
        lea M4_PV_FRIENDHP+1,a0
        moveq #2,d1
M4LvResFriends:
        tst.b (a0)+
        beq.s M4LvResDead
        addq.w #5,d2
M4LvResDead:
        dbra d1,M4LvResFriends
        clr.b M4_BOSS_STAGECLEAR
        moveq #0,d0
        move.w M4_LV_SPECIALS,d1
        andi.w #$ff,d1
        beq.s M4LvResPerc
        moveq #0,d0
        move.b M4_LV_SPECIALDEAD+1,d0
        mulu.w #100,d0
        divu.w d1,d0 ;GSU mcalcperc 01:B6A2: floor [H]
M4LvResPerc:
        add.w d2,d0
        cmpi.w #100,d0
        bls.s M4LvResCla2
        moveq #100,d0
M4LvResCla2:
        move.w d0,M4_GM_CLA2
        bsr M4LvTotalScore
        move.w d0,M4_GM_CLBM
        clr.w M4_GM_CLA1
        clr.w M4_GM_CLB1
        clr.w M4_GM_CLAM
        clr.w M4_GM_PLOTX1
        rts
M4LvTotalScore:
        moveq #0,d0
        moveq #0,d1
        move.b M4_GM_SPECPTR,d1
        lea M4_GM_SPECBUF,a0
        bra.s M4LvTotalNext
M4LvTotalAdd:
        moveq #0,d2
        move.b (a0)+,d2
        cmpi.b #$65,d2
        beq.s M4LvTotalNext
        add.w d2,d0
M4LvTotalNext:
        dbra d1,M4LvTotalAdd
        move.w d0,M4_GM_TOTAL
        rts

; printspeclp 02:EC42, one iteration per tick (counting only; the texts,
; bars and faces are drawn by M4LvResultsDraw).
M4LvResultsTick:
        bsr M4LvTotalScore
        move.w M4_GM_CLB1,d0
        cmpi.w #1,d0
        bne.s M4LvResCount
        tst.w M4_GM_PLOTX1 ;BONUS 1 CREDIT
        beq.s M4LvResCredit
        subq.w #1,M4_GM_PLOTX1
        cmpi.w #1,M4_GM_PLOTX1
        bne.s M4LvResCredit
        addq.b #1,M4_GM_CREDITS
        st M4_GM_ONECRED
M4LvResCredit:
        bra.s M4LvResClam
M4LvResCount:
        subq.w #1,d0
        bpl.s M4LvResClb1
        moveq #0,d0
M4LvResClb1:
        move.w d0,M4_GM_CLB1
        cmpi.w #2,d0
        bne.s M4LvResClam
        move.w #10,M4_GM_PLOTX1 ;sound $1A
M4LvResClam:
        move.w M4_GM_CLAM,d0
        bne.s M4LvResWait
        addq.w #3,M4_GM_CLA1 ;sound $12
        move.w M4_GM_CLA1,d0
        cmp.w M4_GM_CLA2,d0
        blo.s M4LvResDone
        move.w M4_GM_CLA2,M4_GM_CLA1
        move.w #20,M4_GM_CLAM
        rts
M4LvResWait:
        cmpi.w #1,d0
        beq.s M4LvResDone
        subq.w #1,d0
        move.w d0,M4_GM_CLAM
        cmpi.w #2,d0
        bne.s M4LvResDone
        moveq #0,d0 ;sound $11; specbuf[specptr++] = cla2; checkbonus
        move.b M4_GM_SPECPTR,d0
        cmpi.b #8,d0
        bhs.s M4LvResBonus
        lea M4_GM_SPECBUF,a0
        move.b M4_GM_CLA2+1,(a0,d0.w)
        addq.b #1,M4_GM_SPECPTR
M4LvResBonus:
        bsr M4LvTotalScore ;checkbonus 02:EF57: T = highest bonertab <= total
        lea M4LvBonerTab,a0
M4LvResBonerFind:
        move.w (a0)+,d1
        cmp.w d1,d0
        blt.s M4LvResBonerFind
        cmp.w M4_GM_CLBM,d1
        ble.s M4LvResDone
        move.w #20,M4_GM_CLB1
M4LvResDone:
        rts
M4LvBonerTab: ;02:EF7F
        incbin '../build/M4LvBonerTab.bin'

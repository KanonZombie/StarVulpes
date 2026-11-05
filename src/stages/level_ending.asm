; Stage unit: game ending and credits (end_game_seq 02:E56F, creditsmap 0D:F1EE).
; Strategies (table searched by M4LevelFindStrategy, level_objects.asm),
; helpers and effects of these stages. Stage data: tools/stages/ending.py.
; RAM: $FF9980..$FF99BF (reserved for this unit).
; Evidence and oracle: build/agent-ending/ENDING.md (tools/ending-resources.py,
; build/agent-ending/ending-oracle.py). Hooks into level.asm: INTEGRATION.md.
;
; Flow (selected ROM, re-read from the bytes):
; levelfinished = 6 (map dm_end 0D:DD4C / viewoutofLB3 06:DFB7) -> gamestart
; 02:E3FF stage++ -> end_level_seq 02:EC20: calcstageperc 02:EBBB, finis1
; 02:EF49 (specbuf[specptr++] = cla2, no results screen) -> end_game_seq
; 02:E56F: m_meters 0; every 30 ticks a line "STAGE n  xx%" of three text
; objects (makeendobj 02:EA76); after the last line c_type ($1F11, reused as
; a counter) runs 30 -> 0 -> 255 -> 201; maketotalscore 02:E762 (TOTAL SCORE,
; its digits, AVERAGE SCORE, the average, 25 ticks apart); 80 ticks;
; levelfinished = 9 (the escape camera swings away); 370 ticks, fadedir $FF
; on the last 14; endseq_l 1F:DD0D (boss parade: NOT PORTED, skipped); credits
; music 03:AEBD (not ported); creditsmap 0D:F1EE through initgame_l 02:E2C6;
; transfer_l until levelfinished = 8; maketotalscore2 02:E8DB (10 ticks
; apart); then 02:E697 jsl transfer_l / bra forever: the original never
; returns to the title (no ranking screen either).
; Every wait counts transfer_l calls: here, calls of M4EndTick after the
; tick's strategies (the original loop body follows its transfer_l).

M4_ENDING equ $ff9980
M4_END_ON equ M4_ENDING+0 ;.b phase: 0 off, 1 start pending, 2..13 below
M4_END_COUNT equ M4_ENDING+2 ;.w ticks left in a wait
M4_END_V1ADDR equ M4_ENDING+4 ;.w $188C vram1addr: y of the next line
M4_END_V1LEN equ M4_ENDING+6 ;.w $188E vram1len: string of the stage number
M4_END_V2ADDR equ M4_ENDING+8 ;.w $1890 vram2addr: specbuf index
M4_END_V2LEN equ M4_ENDING+10 ;.w $1892 vram2len: ticks to the next line
M4_END_V3ADDR equ M4_ENDING+12 ;.w $1894 vram3addr: setthepath index (x2)
M4_END_AVGMSG equ M4_ENDING+14 ;.w string of the average (pushed by the ROM)
M4_END_KTPX equ M4_ENDING+16 ;.w $1F3F ktpx
M4_END_KTPY equ M4_ENDING+18 ;.w $1F41 ktpy
M4_END_TPA equ M4_ENDING+20 ;.w $14C7 tpa (calctotalscore)
M4_END_N101 equ M4_ENDING+22 ;.w 7E:A058 maintempalc (entries = 101)
M4_END_MODE equ M4_ENDING+24 ;.b 0 makeendobj, 1 makeendobj2

END_PH_START equ 1
END_PH_STAGES equ 2
END_PH_TOTAL equ 3 ;waits 25, then the TOTAL SCORE digits
END_PH_AVE equ 4 ;waits 25, then AVERAGE SCORE
END_PH_AVEN equ 5 ;waits 25, then the average
END_PH_WAIT80 equ 6
END_PH_FADE equ 7
END_PH_CREDREQ equ 8 ;post-draw: start the credits map
END_PH_CREDITS equ 9 ;until levelfinished = 8
END_PH_T2N equ 10 ;maketotalscore2: waits 10, digits
END_PH_T2A equ 11 ;waits 10, AVERAGE SCORE
END_PH_T2AN equ 12 ;waits 10, the average
END_PH_FOREVER equ 13 ;02:E697

; GSU message bank $14 (tools/ending-resources.py; codes 1..26 A..Z, 28..37
; digits, 40 space, 65 %).
END_MSG_STAGE equ $cde5
END_MSG_TOTAL equ $cdcb
END_MSG_AVE equ $cdd7
END_MSG_1 equ $cbb9 ;msg_1 (vram1len start), msg_n = msg_0 + 2n
END_MSG_0 equ $cbb7
END_MSG_00 equ $cbcd ;msg_00 + 5p = "  p%"
END_ZACO4 equ $d924 ;zaco_4: shape of the score text objects

M4StrategiesEnding:
        dc.l $04800e,M4PathIstratText ;patht_istrat (textpath, credits/intro/OOTD)
        dc.l 0

; patht_istrat 04:800E: $1E |= 1 (colldisable), $1D |= $40 (textobj),
; HP $2A = 10, AP $2B = 8 (hardAP), then falls into path_istrat 04:8022.
; Same flags as the path op text 04:989B (M4PvOp_text).
M4PathIstratText:
        bset #SF_COLLDISABLE,49(a0)
        bset #0,X_TEXTFL(a0)
        move.b #10,38(a0)
        move.b #8,39(a0)
        jmp M4PathIstrat

; ---------------------------------------------------------------------
; Called by M4LvLevelFinished for levelfinished = 6 (INTEGRATION.md):
; the dispatch happens after the image of this tick (status 9).
M4EndLevelFinished:
        move.w #9,M4_LV_STATUS
        move.b #END_PH_START,M4_END_ON
        rts

; Post-draw hook of the level loop (after M4LevelPause, INTEGRATION.md).
M4EndPostDraw:
        cmpi.b #END_PH_CREDREQ,M4_END_ON
        beq M4EndCredits
        cmpi.b #END_PH_START,M4_END_ON
        bne.s M4EndPostRet
        movem.l d0-d7/a0-a4,-(sp)
        bsr.s M4EndStart
        movem.l (sp)+,d0-d7/a0-a4
M4EndPostRet:
        rts

; gamestart 02:E40C stage++; end_level_seq 02:EC20 with levelfinished 6:
; calcstageperc 02:EBBB (5 per living friend, stageclear = 0, specials %
; as M4LvResultsStart, cla2 = min(p + bonus, 100)) and finis1 02:EF49
; (specbuf[specptr++] = cla2; the ROM stores a WORD, the next byte gets 0;
; the port keeps its 8-entry bound). Then end_game_seq 02:E56F.
M4EndStart:
        move.w #1,M4_LV_STATUS
        addq.b #1,M4_GM_STAGE
        moveq #0,d2
        lea M4_PV_FRIENDHP+1,a0
        moveq #2,d1
M4EndFriends:
        tst.b (a0)+
        beq.s M4EndFriendDead
        addq.w #5,d2
M4EndFriendDead:
        dbra d1,M4EndFriends
        clr.b M4_BOSS_STAGECLEAR
        moveq #0,d0
        move.w M4_LV_SPECIALS,d1
        andi.w #$ff,d1
        beq.s M4EndPerc
        moveq #0,d0
        move.b M4_LV_SPECIALDEAD+1,d0
        mulu.w #100,d0
        divu.w d1,d0 ;GSU mcalcperc 01:B6A2 (as M4LvResultsStart)
M4EndPerc:
        add.w d2,d0
        cmpi.w #100,d0
        bls.s M4EndCla2
        moveq #100,d0
M4EndCla2:
        move.w d0,M4_GM_CLA2
        moveq #0,d1
        move.b M4_GM_SPECPTR,d1
        cmpi.b #8,d1
        bhs.s M4EndSeqInit
        lea M4_GM_SPECBUF,a0
        move.b d0,(a0,d1.w)
        addq.b #1,M4_GM_SPECPTR
; end_game_seq 02:E56F..E597, then the first stagescore body (before the
; first transfer_l).
M4EndSeqInit:
        clr.b M4_SC_MMETERS ;m_meters 70:021C = 0
        move.w #-550,M4_END_V1ADDR
        move.w #END_MSG_1,M4_END_V1LEN
        clr.w M4_END_V2ADDR
        move.w #1,M4_END_V2LEN
        clr.w M4_END_V3ADDR
        move.b #200,M4_CTL_TYPE ;c_type $1F11
        clr.b M4_END_MODE
        move.b #END_PH_STAGES,M4_END_ON
        bra M4EndStageBody

; After the strategies of every tick while the ending runs (in place of
; friends_messages_l / the results tick, INTEGRATION.md).
M4EndTick:
        movem.l d0-d7/a0-a4,-(sp)
        move.l M4_LV_CREATOR,-(sp)
        clr.l M4_LV_CREATOR ;makeendobj: behind allst's head (ldx $121F)
        moveq #0,d0
        move.b M4_END_ON,d0
        cmpi.w #END_PH_FOREVER,d0
        bhi.s M4EndTickDone
        add.w d0,d0
        move.w M4EndTickTable(pc,d0.w),d0
        jsr M4EndTickTable(pc,d0.w)
M4EndTickDone:
        move.l (sp)+,M4_LV_CREATOR
        movem.l (sp)+,d0-d7/a0-a4
        rts
M4EndTickTable:
        dc.w M4EndNone-M4EndTickTable ;0
        dc.w M4EndNone-M4EndTickTable ;1 start pending (dispatch after the image)
        dc.w M4EndStages-M4EndTickTable
        dc.w M4EndPhTotal-M4EndTickTable
        dc.w M4EndPhAve-M4EndTickTable
        dc.w M4EndPhAven-M4EndTickTable
        dc.w M4EndPh80-M4EndTickTable
        dc.w M4EndPhFade-M4EndTickTable
        dc.w M4EndNone-M4EndTickTable ;8 credits requested (post-draw)
        dc.w M4EndPhCredits-M4EndTickTable
        dc.w M4EndPhT2N-M4EndTickTable
        dc.w M4EndPhT2A-M4EndTickTable
        dc.w M4EndPhT2AN-M4EndTickTable
        dc.w M4EndNone-M4EndTickTable ;13 02:E697 forever
M4EndNone:
        rts

; stagescore loop 02:E59A..E628: after transfer_l, c_type = 201 ends it
; (02:E621), else the body runs before the next transfer_l.
M4EndStages:
        cmpi.b #201,M4_CTL_TYPE
        beq M4EndTotalScore
M4EndStageBody:
        subq.w #1,M4_END_V2LEN ;dec vram2len (16 bits)
        bne M4EndStageSkip
        move.w M4_END_V2ADDR,d0
        moveq #0,d1
        move.b M4_GM_SPECPTR,d1 ;cpx $1FBD (word: specptr high byte 0)
        cmp.w d1,d0
        beq M4EndStageSkip
        move.w #30,M4_END_V2LEN
        move.w #END_MSG_STAGE,d0
        move.w #-500,d1
        move.w M4_END_V1ADDR,d2
        bsr M4EndMakeObj
        bsr M4EndSetThePath
        move.w M4_END_V1LEN,d0
        moveq #0,d1
        move.w M4_END_V1ADDR,d2
        bsr M4EndMakeObj
        bsr M4EndSetThePath
        addq.w #2,M4_END_V1LEN
        move.w M4_END_V2ADDR,d1
        addq.w #1,M4_END_V2ADDR
        moveq #0,d0
        cmpi.w #8,d1
        bhs.s M4EndStagePerc
        lea M4_GM_SPECBUF,a0
        move.b (a0,d1.w),d0
M4EndStagePerc:
        mulu.w #5,d0
        addi.w #END_MSG_00,d0
        move.w #600,d1
        move.w M4_END_V1ADDR,d2
        bsr M4EndMakeObj
        bsr M4EndSetThePath
        addi.w #200,M4_END_V1ADDR
        addq.w #2,M4_END_V3ADDR
M4EndStageSkip:
        cmpi.b #200,M4_CTL_TYPE ;.skip: c_type - 1 unless 200 (8 bits)
        beq.s M4EndStageRet
        subq.b #1,M4_CTL_TYPE
M4EndStageRet:
        rts

; calctotalscore 02:E8A6: tpa = sum of specbuf[0..specptr) with the 101
; entries counted in maintempalc and added as 0. Average: GSU
; mkrisdivu3115 01:B6B7 -> mdivu3115 (restoring 32/16, dividend 0:tpa,
; divisor specptr - maintempalc; divisor 0 gives $FFFF), msg_00 + 5 q.
M4EndCalcTotal:
        moveq #0,d0
        moveq #0,d2
        moveq #0,d1
        lea M4_GM_SPECBUF,a0
M4EndCalcNext:
        cmp.b M4_GM_SPECPTR,d1
        beq.s M4EndCalcDone
        moveq #0,d3
        cmpi.w #8,d1
        bhs.s M4EndCalcAdd
        move.b (a0,d1.w),d3
        cmpi.b #101,d3
        bne.s M4EndCalcAdd
        addq.w #1,d2
        moveq #0,d3
M4EndCalcAdd:
        add.w d3,d0
        addq.w #1,d1
        bra.s M4EndCalcNext
M4EndCalcDone:
        move.w d0,M4_END_TPA
        move.w d2,M4_END_N101
        rts
M4EndAverage:
        bsr M4EndCalcTotal
        moveq #0,d1
        move.b M4_GM_SPECPTR,d1
        sub.w M4_END_N101,d1
        moveq #0,d0
        move.w M4_END_TPA,d0
        move.w #$ffff,d2
        tst.w d1
        beq.s M4EndAvgMsg
        divu.w d1,d0 ;quotient < 65536 (dividend < 65536)
        move.w d0,d2
M4EndAvgMsg:
        mulu.w #5,d2
        addi.w #END_MSG_00,d2
        move.w d2,M4_END_AVGMSG
        rts

; maketotalscore 02:E762 (c_type = 1, vram3addr = 14, TOTAL SCORE at y -1600).
M4EndTotalScore:
        move.b #1,M4_CTL_TYPE
        move.w #14,M4_END_V3ADDR
        bsr M4EndAverage
        move.w #END_MSG_TOTAL,d0
        moveq #0,d1
        move.w #-1600,d2
        bsr M4EndMakeObj
        bsr M4EndSetThePath
        addq.w #2,M4_END_V3ADDR
        move.w #25,M4_END_COUNT
        move.b #END_PH_TOTAL,M4_END_ON
        rts
M4EndPhTotal:
        subq.w #1,M4_END_COUNT
        bne M4EndPhRet
        move.w #-1400,d2
        bsr M4EndDigits
        addq.w #2,M4_END_V3ADDR
        move.w #25,M4_END_COUNT
        move.b #END_PH_AVE,M4_END_ON
M4EndPhRet:
        rts
M4EndPhAve:
        subq.w #1,M4_END_COUNT
        bne M4EndPhRet
        move.w #END_MSG_AVE,d0
        moveq #0,d1
        move.w #-850,d2
        bsr M4EndMakeObj
        bsr M4EndSetThePath
        addq.w #2,M4_END_V3ADDR
        move.w #25,M4_END_COUNT
        move.b #END_PH_AVEN,M4_END_ON
        rts
M4EndPhAven:
        subq.w #1,M4_END_COUNT
        bne M4EndPhRet
        move.w M4_END_AVGMSG,d0
        moveq #0,d1
        move.w #-650,d2
        bsr M4EndMakeObj
        bsr M4EndSetThePath
        addq.w #2,M4_END_V3ADDR
        clr.b M4_CTL_TYPE ;02:E89C stz c_type
        move.w #80,M4_END_COUNT ;02:E62E
        move.b #END_PH_WAIT80,M4_END_ON
        rts
M4EndPh80:
        subq.w #1,M4_END_COUNT
        bne M4EndPhRet
        move.b #9,M4_GS_LEVELFIN ;02:E640 le_endtotalscore (not dispatched)
        move.w #370,M4_END_COUNT
        move.b #END_PH_FADE,M4_END_ON
        rts
; 02:E647..E663: 370 transfer_l; after each one, A < 15 -> fadedir $FF.
M4EndPhFade:
        cmpi.w #15,M4_END_COUNT
        bhs.s M4EndFadeCount
        move.b #$ff,M4_FADE
M4EndFadeCount:
        subq.w #1,M4_END_COUNT
        bne M4EndPhRet
        move.b #END_PH_CREDREQ,M4_END_ON
        rts

; Digits of the total (02:E7CD..E84B / 02:E8xx in maketotalscore2): cla2 =
; tpa, cla1 = -200; hundreds (only when nonzero) at x -300, tens at -150,
; ones at 0, then "0" at 150 and 300; the loops subtract while the 16-bit
; result stays >= 0 (bpl). d2 = y; M4_END_MODE selects the variant. x is
; relative (+totalxpos 500 in maketotalscore2).
M4EndDigits:
        move.w d2,-(sp)
        bsr M4EndCalcTotal
        move.w M4_END_TPA,d0
        move.w #$ff38,M4_GM_CLA1
        moveq #-1,d3
M4EndHundreds:
        addq.w #1,d3
        subi.w #100,d0
        bpl.s M4EndHundreds
        addi.w #100,d0
        move.w d0,M4_GM_CLA2
        tst.w d3
        beq.s M4EndTens
        move.w d3,d0
        move.w #-300,d1
        move.w (sp),d2
        bsr M4EndMakeDigit
M4EndTens:
        move.w M4_GM_CLA2,d0
        moveq #-1,d3
M4EndTensLp:
        addq.w #1,d3
        subi.w #10,d0
        bpl.s M4EndTensLp
        addi.w #10,d0
        move.w d0,M4_GM_CLA2
        move.w d3,d0
        move.w #-150,d1
        move.w (sp),d2
        bsr M4EndMakeDigit
        move.w M4_GM_CLA2,d0
        moveq #0,d1
        move.w (sp),d2
        bsr M4EndMakeDigit
        moveq #0,d0
        move.w #150,d1
        move.w (sp),d2
        bsr M4EndMakeDigit
        moveq #0,d0
        move.w #300,d1
        move.w (sp)+,d2
        bra M4EndMakeDigit
; makeendobjn 02:EA71 / makeendobjn2 02:EB0A: string msg_0 + 2 d0. In
; maketotalscore each digit gets setthepath (index vram3addr, unchanged).
M4EndMakeDigit:
        add.w d0,d0
        addi.w #END_MSG_0,d0
        tst.b M4_END_MODE
        bne.s M4EndMakeDigit2
        bsr M4EndMakeObj
        bra M4EndSetThePath
M4EndMakeDigit2:
        addi.w #500,d1 ;totalxpos
        bra M4EndMakeObj

; makeendobj 02:EA76 (mode 0) / makeendobj2 02:EB0F (mode 1). d0 string,
; d1 x, d2 y. zaco_4 object (1F:D54B behind allst's head) with strategy
; patht_istrat 04:800E (Istrat on its first tick), textobj + colldisable,
; depthoffset (colour) 3 / 5, string, tscrollx (size) 0, al_ty (trail
; colour) 3, path $4829 total / $4815 fadeintotal; position of viewtoobj
; $15A0 / playpt $123A, + (x, y), z + 4000 / 3600. Returns a2 (0 if the
; pool is full: the ROM then skips the object, jml 02:EB07).
M4EndMakeObj:
        movem.l d0-d2,-(sp)
        move.w #END_ZACO4,d0
        jsr M4LevelShapeIndex
        jsr M4EnCreate
        movem.l (sp)+,d0-d2
        cmpa.w #0,a2
        beq M4EndMakeRet
        move.w #END_ZACO4,X_SHAPEHDR(a2)
        move.l #M4PathIstratText,32(a2)
        bset #0,X_TEXTFL(a2)
        bset #SF_COLLDISABLE,49(a2)
        move.w d0,X_COLTAB(a2)
        clr.b X_TX(a2)
        move.b #3,X_TY(a2)
        lea LV_PLAYER,a3
        move.w #3600,d0
        tst.b M4_END_MODE
        bne.s M4EndMakeMode2
        move.b #3,X_DEPTHOFF(a2)
        move.w #$4829,42(a2)
        move.w M4_SC_VIEWTOOBJ,d0 ;viewtoobj $15A0 (the escape camera carrier)
        beq.s M4EndMakeVtoNone ;0: the ROM reads 00:000C..0011 (not modelled): player
        movea.w d0,a3
        adda.l #$ff0000,a3
M4EndMakeVtoNone:
        move.w #4000,d0
        bra.s M4EndMakePos
M4EndMakeMode2:
        move.b #5,X_DEPTHOFF(a2)
        move.w #$4815,42(a2)
M4EndMakePos:
        move.w (a3),(a2) ;copy_pos 1F:DAED
        move.w 2(a3),2(a2)
        move.w 4(a3),4(a2)
        add.w d1,(a2)
        add.w d2,2(a2)
        add.w d0,4(a2)
M4EndMakeRet:
        cmpa.w #0,a2
        rts

; setthepath 02:E69D: jmp ($E6A7,x) with x = vram3addr: stage1..stage7
; ($4895 + 50 n, each followed by checkifiamend 02:E756: n = specptr ->
; c_type = 30), total $4829, totaln $4844, ave $485F, aven $487A. Beyond 10
; the ROM table runs into code: no change here (unreachable with <= 8
; stages). a2 = the object (none after a failed creation).
M4EndSetThePath:
        cmpa.w #0,a2
        beq.s M4EndSetRet
        move.w M4_END_V3ADDR,d0
        lsr.w #1,d0
        cmpi.w #10,d0
        bhi.s M4EndSetRet
        move.w d0,d1
        add.w d1,d1
        move.w M4EndPathTab(pc,d1.w),42(a2)
        cmpi.w #7,d0
        bhs.s M4EndSetRet
        addq.b #1,d0
        cmp.b M4_GM_SPECPTR,d0
        bne.s M4EndSetRet
        move.b #30,M4_CTL_TYPE
M4EndSetRet:
        rts
M4EndPathTab: ;02:E6BD.. sta $28,x immediates (tools/ending-resources.py)
        incbin '../build/M4EndPathTab.bin'

; 02:E665..E680: endseq_l 1F:DD0D (boss parade) and the credits music
; 03:AEBD are not ported; creditsmap 0D:F1EE through initgame_l (port:
; M4LevelStart with that map), levelfinished = 0.
M4EndCredits:
        move.w #$71ee,M4_GS_NEWMAP
        move.b #$0d,M4_GS_NEWBANK
        clr.b M4_GS_LEVELFIN
        move.b #END_PH_CREDITS,M4_END_ON
        jsr M4PipeFlush
        beq.s M4EndCreditsGo
        jmp M4IntroFailed
M4EndCreditsGo:
        lea $ffff00,sp
        jmp M4LevelStart

; 02:E683..E692: after each transfer_l, levelfinished = 8 -> maketotalscore2
; 02:E8DB: TOTAL SCORE at (500, 750), z + 3600 from the player, colour 5,
; path fadeintotal, no setthepath; 10 ticks; digits at y 900; 10; AVERAGE
; SCORE at y 1050; 10; the average at y 1200; then forever.
M4EndPhCredits:
        cmpi.b #8,M4_GS_LEVELFIN
        bne.s M4EndPh2Ret
        move.b #1,M4_END_MODE
        bsr M4EndAverage
        move.w #END_MSG_TOTAL,d0
        move.w #500,d1
        move.w #750,d2
        bsr M4EndMakeObj
        move.w #10,M4_END_COUNT
        move.b #END_PH_T2N,M4_END_ON
M4EndPh2Ret:
        rts
M4EndPhT2N:
        subq.w #1,M4_END_COUNT
        bne.s M4EndPh2Ret
        move.w #900,d2
        bsr M4EndDigits
        move.w #10,M4_END_COUNT
        move.b #END_PH_T2A,M4_END_ON
        rts
M4EndPhT2A:
        subq.w #1,M4_END_COUNT
        bne.s M4EndPh2Ret
        move.w #END_MSG_AVE,d0
        move.w #500,d1
        move.w #1050,d2
        bsr M4EndMakeObj
        move.w #10,M4_END_COUNT
        move.b #END_PH_T2AN,M4_END_ON
        rts
M4EndPhT2AN:
        subq.w #1,M4_END_COUNT
        bne.s M4EndPh2Ret
        move.w M4_END_AVGMSG,d0
        move.w #500,d1
        move.w #1200,d2
        bsr M4EndMakeObj
        move.b #END_PH_FOREVER,M4_END_ON
        rts

; ---------------------------------------------------------------------
; Path support of the score lines (proposed hook in level_paths.asm
; M4PvOp_start65816, INTEGRATION.md): the inline 65816 of the paths
; stage1..stage7 at $48AA + 50 (n - 1) (04:ECA9.., read by
; tools/ending-resources.py: lda #n / cmp $16D8 / bne / lda #$C9 / sta
; $1F11 / rep / lda #next / rtl): stage = n -> c_type = 201; continue at
; +$13. In: a0 object, 42(a0) path pc. Out: Z set when handled.
M4EndPv65:
        move.w 42(a0),d0
        subi.w #$48aa,d0
        bcs.s M4EndPv65No
        andi.l #$ffff,d0
        divu.w #50,d0
        cmpi.w #6,d0
        bhi.s M4EndPv65No
        swap d0
        tst.w d0
        bne.s M4EndPv65No
        swap d0
        addq.b #1,d0
        cmp.b M4_GM_STAGE,d0
        bne.s M4EndPv65Cont
        move.b #201,M4_CTL_TYPE
M4EndPv65Cont:
        addi.w #$13,42(a0)
        moveq #0,d0
        rts
M4EndPv65No:
        moveq #1,d0
        rts

; ---------------------------------------------------------------------
; Scaled text of the level: msprint 01:CEF0 (MDRAWLIS.MC .notpart: textobj
; objects are drawn only as text). The 68000 runs the projection part
; (01:CEF0..CF9F: z <= 128 rejected, mprojectpnt 01:9263 of the centre and of
; (127 + size, (127 + size) * len), lob, centring by ceil(w/2), the small /
; mlargescale choice and the divisions 01:8183) and passes the Y-loop state
; to the SVP as one raw cmd8 record (type 13, SVP_SText of
; tools/generate-svp-ending-text.py: every pixel there). Checked against the
; ROM GSU by tools/check-ending-text.py. Cost: 4 to 6 restoring divisions of
; 16 steps per text object (as M4TextProject of the intro).
; The 68000 projection is a transitional split, as M4TextProject of the
; intro; only the release (M4_STEXT) assembles SVP_SText and sends records.
M4_END_TP equ M4_ENDING+26 ;in: x, y, z, size (s8 extended), string ptr (14:xxxx); out +10: x, y, scale, sprsize, large, string index

; M4_END_TP inputs -> outputs; d0 = 0 drawn, 1 z <= 128, 2 string outside 14:C8DA..CDEC.
M4EndTextProject:
        movem.l d1-d7/a0,-(sp)
        lea M4_END_TP,a0
        move.w #128,d0 ;CEFA: 128 - z < 0 (N of the 16-bit subtraction) continues
        sub.w 4(a0),d0
        bmi.s M4EtpZOk
        moveq #1,d0
        bra M4EtpRet
M4EtpZOk:
        if def(M4_STEXT)
        moveq #0,d1
        move.w 8(a0),d1
        subi.w #$c8da,d1
        bcs M4EtpBadStr
        cmpi.w #$cdec-$c8da,d1
        bhs M4EtpBadStr
        move.w d1,20(a0) ;out: byte index of the string in SVP_STextStr
        lea SVP_STextStr,a1 ;14:C8DA..CDEC, two codes per WORD: the same bytes
        adda.l d1,a1
        moveq #0,d7 ;CF24..CF2B: length (bytes up to the 0)
M4EtpLen:
        tst.b (a1)+
        beq.s M4EtpLenDone
        addq.w #1,d7
        bra.s M4EtpLen
M4EtpLenDone:
        else
        bra M4EtpBadStr
        endif
        move.w (a0),d1 ;CEFE: centre
        move.w 2(a0),d2
        move.w 4(a0),d3
        bsr M4EtpProject
        move.w d1,10(a0)
        move.w d2,12(a0)
        move.w d7,d5 ;CF2C: unscaled width = mult (signed 8 x 8) len * 16
        ext.w d5
        lsl.w #4,d5
        move.w 6(a0),d1 ;CF33: r1 = size + 127, r2 = umult (8 x 8) r1 * len
        addi.w #127,d1
        move.w d1,d2
        andi.w #$ff,d2
        move.w d7,d4
        andi.w #$ff,d4
        mulu.w d4,d2
        move.w 4(a0),d3
        bsr M4EtpProject
        subi.w #112,d1 ;CF46: minus the vanishing point
        subi.w #96,d2
        andi.w #$ff,d1 ;lob
        move.w d1,16(a0)
        move.w d2,d0 ;CF55: x -= ceil(r2 / 2) (unsigned)
        lsr.w #1,d0
        moveq #0,d4
        addx.w d4,d0
        sub.w d0,10(a0)
        move.w d1,d0 ;y -= ceil(r1 / 2)
        lsr.w #1,d0
        addx.w d4,d0
        sub.w d0,12(a0)
        cmp.w d5,d2 ;CF84: r2 - unscaled: borrow -> small path
        bcs.s M4EtpSmall
        move.w #1,18(a0) ;D03E mlargescale
        move.w #$ffff,d4
        cmp.w d5,d2
        beq.s M4EtpScale
        move.w d5,d0 ;(unscaled : 0) / scaled
        moveq #0,d4
        move.w d2,d6
        bsr M4EtpDiv
        bra.s M4EtpScale
M4EtpSmall:
        clr.w 18(a0)
        move.w d2,d0 ;CF8D: (scaled : 0) / unscaled
        moveq #0,d4
        move.w d5,d6
        bsr M4EtpDiv
M4EtpScale:
        move.w d4,14(a0)
        moveq #0,d0
M4EtpRet:
        movem.l (sp)+,d1-d7/a0
        rts
M4EtpBadStr:
        moveq #2,d0
        bra.s M4EtpRet

; mdivu3216 01:8183 = mpdivu3216 01:9493: d0:d4 / d6 (16 bits each) -> d4.
; If d0 or d6 has bit 15 both are halved first (d0:d4 >> 1, d6 >> 1); 16
; restoring steps on the shifted pair; the remainder is discarded.
M4EtpDiv:
        move.l d1,-(sp)
        tst.w d0
        bmi.s M4EtpDivHalf
        tst.w d6
        bpl.s M4EtpDivGo
M4EtpDivHalf:
        lsr.w #1,d6
        lsr.w #1,d0 ;X = bit 0 of d0
        roxr.w #1,d4
M4EtpDivGo:
        add.w d4,d4 ;X = old bit 15
        addx.w d0,d0
        moveq #15,d1
M4EtpDivStep:
        cmp.w d6,d0
        bcs.s M4EtpDivBorrow
        sub.w d6,d0
        add.w d4,d4
        addx.w d0,d0
        addq.w #1,d4
        dbra d1,M4EtpDivStep
        move.l (sp)+,d1
        rts
M4EtpDivBorrow:
        add.w d4,d4
        addx.w d0,d0
        dbra d1,M4EtpDivStep
        move.l (sp)+,d1
        rts

; mprojectpnt 01:9263 for z > 0: d1 x, d2 y, d3 z -> d1, d2 (+ vanishing
; point 112 / 96). Absolute values, the larger one first (unsigned compare),
; mdo_project 01:942F, signs restored. d0/d4/d6 clobbered.
M4EtpProject:
        moveq #0,d0 ;bit 0: x negative, bit 1: y negative
        tst.w d1
        bpl.s M4EtpPx
        neg.w d1
        bset #0,d0
M4EtpPx:
        tst.w d2
        bpl.s M4EtpPy
        neg.w d2
        bset #1,d0
M4EtpPy:
        move.w d0,-(sp)
        cmp.w d2,d1 ;x - y: borrow -> exchange
        bcc.s M4EtpNoSwap
        exg d1,d2
        bsr.s M4EtpDoProject
        exg d1,d2
        bra.s M4EtpSigns
M4EtpNoSwap:
        bsr.s M4EtpDoProject
M4EtpSigns:
        move.w (sp)+,d0
        btst #0,d0
        beq.s M4EtpSx
        neg.w d1
M4EtpSx:
        btst #1,d0
        beq.s M4EtpSy
        neg.w d2
M4EtpSy:
        addi.w #112,d1 ;mdo_outcode 01:93F0
        addi.w #96,d2
        rts
; mdo_project 01:942F: d1 >= d2 >= 0 unsigned, d3 = z.
M4EtpDoProject:
        move.w d1,d0
        lsr.w #8,d0 ;hib
        cmp.w d3,d0
        bcc.s M4EtpOverflow ;(x * 256).hi >= z
        move.w d1,d4
        lsl.w #8,d4 ;lob, swap
        move.w d3,d6
        bsr M4EtpDiv
        move.w d4,d1
        bsr.s M4EtpDivY
        cmpi.w #$3fff,d1 ;9445: x' > 16383 -> .check (then the overflow scaling)
        bhi.s M4EtpOverflow
        rts
M4EtpDivY:
        move.w d2,d0
        lsr.w #8,d0
        move.w d2,d4
        lsl.w #8,d4
        move.w d3,d6
        bsr M4EtpDiv
        move.w d4,d2
        rts
; 9473: d2 = d2 * 16383 / d1 (32/16 as above), d1 = 16383.
M4EtpOverflow:
        moveq #0,d0
        move.w d2,d0
        swap d0
        lsr.l #2,d0 ;d2 << 14 as d0.hi : d0.lo
        moveq #0,d4
        move.w d2,d4
        sub.l d4,d0 ;- d2
        move.w d0,d4
        swap d0
        move.w d1,d6
        bsr M4EtpDiv
        move.w d4,d2
        move.w #$3fff,d1
        rts

        if def(M4_STEXT)
; ---------------------------------------------------------------------
; Text objects in the painter order (MDRAWLIS.MC .notpart, 01:...): the draw
; list keeps them as ordinary entries and draws them only with msprint. The
; port keeps a separate list with the same culling (rel.W, z + r and lateral
; cone of M4LevelDrawList, nullshape 00:ACA1 size 188 / sortz 0) and the same
; descending key, and M4IntroSceneDrawObjects interleaves one cmd8 type-13
; record per text where its key falls among the mesh/sprite entries. This
; keeps them out of M4_SHIP_DRAW_LIST and therefore out of the cmd9 poses.
; RAM $FF99C0..$FF9A4F (free after the ending block; no other reference).
M4_END_TEXTN equ $ff99c0 ;.w entries of the draw list being built
M4_END_TEXTI equ $ff99c2 ;.w next entry to draw
M4_END_TEXTL equ $ff99c4 ;END_TEXT_MAX x (object.l, key.w), descending key
M4_END_REC equ $ff9a40 ;8 WORDs: the cmd8 record
END_TEXT_MAX equ 20 ;credits: at most 17 live text objects (ENDING.md)
END_NULL_SIZE equ 188 ;nullshape 00:ACA1 sh_size (header +16)

; a0 = text object of M4LevelDrawList (view position and matrix ready).
M4EndTextEntry:
        movem.l d0-d5/a0-a3,-(sp)
        btst #1,49(a0) ;invisible
        bne M4EteDone
        lea M4_LVW_SCR,a2 ;rel
        move.w (a0),d0
        sub.w M4_LVW_POS,d0
        move.w d0,(a2)
        move.w 2(a0),d0
        sub.w M4_LVW_POS+2,d0
        move.w d0,2(a2)
        move.w 4(a0),d0
        sub.w M4_LVW_POS+4,d0
        move.w d0,4(a2)
        move.l a0,-(sp)
        movea.l a2,a0
        lea M4_LVW_W,a1
        lea M4_LVW_ARM,a2
        jsr M4LvwRowTimes
        movea.l (sp)+,a0
        move.l M4_LVW_ARM,56(a0)
        move.w M4_LVW_ARM+4,60(a0)
        move.w #END_NULL_SIZE,d4 ;r
        moveq #0,d3 ;sortz
        move.w 46(a0),d0
        cmpi.w #$ffff,d0
        beq.s M4EteShape
        lsl.w #5,d0
        lea M4LevelShapeDescriptors,a3
        adda.w d0,a3
        move.w 26(a3),d4
        move.w 18(a3),d3
M4EteShape:
        move.w 60(a0),d0 ;z + r < 0: behind
        add.w d4,d0
        bmi M4EteDone
        add.w d4,d4 ;2r + asr1(z)
        move.w 60(a0),d5
        asr.w #1,d5
        add.w d5,d4
        move.w 56(a0),d0
        bpl.s M4EteX
        neg.w d0
M4EteX:
        sub.w d4,d0
        bpl M4EteDone
        move.w 58(a0),d0
        bpl.s M4EteY
        neg.w d0
M4EteY:
        sub.w d4,d0
        bpl M4EteDone
        add.w 60(a0),d3 ;key = sortz + z (atgnd + 15000)
        btst #0,45(a0)
        beq.s M4EteKey
        addi.w #15000,d3
M4EteKey:
        move.w M4_END_TEXTN,d2
        cmpi.w #END_TEXT_MAX,d2
        bhs M4EteDone
        lea M4_END_TEXTL,a2 ;same insertion rule as M4IntroSceneSortAt
        move.w d2,d1
        mulu.w #6,d1
        lea (a2,d1.w),a3
M4EteFind:
        tst.w d2
        beq.s M4EteInsert
        move.w 4(a2),d0
        subq.w #1,d0
        sub.w d3,d0
        bmi.s M4EteInsert
        lea 6(a2),a2
        subq.w #1,d2
        bra.s M4EteFind
M4EteInsert:
        tst.w d2
        beq.s M4EteStore
M4EteShift:
        move.l -6(a3),(a3)
        move.w -2(a3),4(a3)
        subq.l #6,a3
        subq.w #1,d2
        bne.s M4EteShift
M4EteStore:
        move.l a0,(a2)
        move.w d3,4(a2)
        addq.w #1,M4_END_TEXTN
M4EteDone:
        movem.l (sp)+,d0-d5/a0-a3
        rts

; Before the draw-list entry of key d0: the texts farther than it.
M4EndTextUpTo:
        movem.l d0-d3/a0-a1,-(sp)
        moveq #0,d3
        bra.s M4EtuStart
; After the last entry: every text left, and the list is consumed.
M4EndTextRest:
        movem.l d0-d3/a0-a1,-(sp)
        moveq #1,d3
M4EtuStart:
        tst.w M4_GEO_VIEW ;level views only
        beq.s M4EtuDone
        move.w d0,d2
M4EtuNext:
        move.w M4_END_TEXTI,d1
        cmp.w M4_END_TEXTN,d1
        bhs.s M4EtuEnd
        mulu.w #6,d1
        lea M4_END_TEXTL,a1
        adda.w d1,a1
        tst.w d3
        bne.s M4EtuDraw
        cmp.w 4(a1),d2 ;key <= d2: not farther, wait
        bge.s M4EtuDone
M4EtuDraw:
        movea.l (a1),a0
        bsr.s M4EndTextRecord
        addq.w #1,M4_END_TEXTI
        bra.s M4EtuNext
M4EtuEnd:
        tst.w d3
        beq.s M4EtuDone
        clr.w M4_END_TEXTN
M4EtuDone:
        movem.l (sp)+,d0-d3/a0-a1
        rts

; a0 text object -> msprint 01:CEF0 projection and one cmd8 type-13 record:
; string coltab (alx+$20), colour depthoffset (alx+$15; 15 = depth cue
; 14 - min(5, z >> 10), MDRAWLIS.MC .daijobu), size tscrollx (alx+$2A).
M4EndTextRecord:
        movem.l d0-d1/a1-a2,-(sp)
        lea M4_END_TP,a1
        move.l 56(a0),(a1)
        move.w 60(a0),4(a1)
        move.b X_TX(a0),d0
        ext.w d0
        move.w d0,6(a1)
        move.w X_COLTAB(a0),8(a1)
        bsr M4EndTextProject ;keeps d1-d7/a0 only: a1 walked the string
        tst.w d0
        bne.s M4EtrDone
        lea M4_END_TP,a1
        lea M4_END_REC,a2
        move.w #13,(a2)
        move.w 10(a1),2(a2) ;x
        move.w 12(a1),4(a2) ;y
        move.w 14(a1),6(a2) ;scale
        moveq #0,d0
        move.b X_DEPTHOFF(a0),d0
        cmpi.w #15,d0
        bne.s M4EtrColour
        move.w 60(a0),d1 ;hib, lsr, lsr
        lsr.w #8,d1
        lsr.w #2,d1
        cmpi.w #5,d1
        bls.s M4EtrCue
        moveq #5,d1
M4EtrCue:
        moveq #14,d0
        sub.w d1,d0
M4EtrColour:
        move.w d0,8(a2)
        move.w 20(a1),10(a2) ;string byte index
        move.w 16(a1),12(a2) ;sprsize
        move.w 18(a1),14(a2) ;small / large
        jsr M4RmRawRecord2 ;face kind 34: copied as one cmd8 record
M4EtrDone:
        movem.l (sp)+,d0-d1/a1-a2
        rts
        endif

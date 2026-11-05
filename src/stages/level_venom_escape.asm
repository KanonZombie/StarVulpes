; Venom 1 unit (escape): code. Included from level_venom.asm. Documentation:
; build/agent-venom/escape/ESCAPE.md (Spanish). Field conventions: level_objects.asm.
; Escape after Andross, map 0D:DB46 .. 0D:DD4C (levelfinished = 6), selected ROM
; USA rev0. Every routine below was re-read from the ROM bytes (traces in
; build/agent-venom/escape/work/); UltraStarFox PCSTRATS.ASM / GCSTRATS.ASM only
; give the names. Correspondence: build/agent-venom/escape/escape-oracle.py.
; Object fields (SNES -> port): $22/$23 sbyte1/2 -> 36/37, $24 sbyte3 ->
; X_SBYTE3, $26 sword1 -> 40, $28 sword2 -> 42 (the map's setalvar.w $28 lands
; there: M4LvAlvarMap), $06 al_ptr -> X_ALPTR, $2F/$31/$33 v -> 6/8/10,
; $1CE7 anim -> 16, $1CDC stratstate -> X_STATE, $1E bit4 sflag1 -> 48 bit0
; (F2_SFLAG1), $1E bit6 sflag3 -> 50 bit6 (VE_SF3, this unit's objects only),
; $1E bit0 colldisable -> 49 bit0, $20 bit3 invisible -> 49 bit1, $09 type -> 45.
; Globals: $14D3 gameflags2 M4_AR_GF2, $1736 mapvar1 M4_LV_MAPVAR1, $158D
; boostobj M4_LP_BOOSTOBJ, $16AB/$16AD circleobj/circleanim M4_SC_CIRCLEOBJ/
; M4_SC_CIRCLE, $15CC viewtype M4_SC_VIEWTYPE, $C1/$C3/$C5 viewpos M4_SC_VIEWPOS
; (Fpos) or M4_LVW_POS (last getview), $1238 viewpt z M4_LVW_POS+4, $169E
; bg2Yscroll M4_SC_BG2Y, $18A2..$18A4 friends M4_PV_FRIENDHP+1..3, $1FD4
; levelfinished M4_GS_LEVELFIN. Sounds and music (trigse/startbgm) are not
; modelled by the port (no audio in this stage).
M4_VE equ $ff9fc0
M4_VE_TEMPSTRAT equ M4_VE+0 ;.l player tempstrat $1CD9 (toCslow push_stratptr)
M4_VE_FINDPTR equ M4_VE+4 ;.w $14CC find_obj pointer (object low WORD, 0 = end)
M4_VE_REUSE equ M4_VE+6 ;.w slot freed by pship1 that mapvar1 still names (node reuse)
; viewtoobj $15A0 (object low WORD, 0 = the player): the free M4_SC slot that
; INTEGRATION.md patch (a) makes M4LvwFixed aim at. M4ScInit clears it.
M4_VE_VTO equ M4_SC_VIEWTOOBJ
VE_SF3 equ 6 ;byte 50 bit: $1E bit6 (sflag3)
VE_BOOSTZOFF equ -80 ;$1570 boostZoff = $B0 (06:DAC9), read by this unit's flames
; Shapes (descriptors; the coordinator may switch them to drawn M4_SH_*).
M4VeShDemoBS equ M4_FX_VE_MY_DEMOBS ;00:BC98 my_demoBS
M4VeShShrap equ M4_FX_VE_SHRAP1 ;00:C638 shrap1

; ---------------------------------------------------------------------
; Helpers.

; a2 = viewtoobj object ($15A0; 0 -> the player). d0 clobbered.
M4VeVto:
        move.w M4_VE_VTO,d0
        beq.s M4VeVtoPlayer
        movea.w d0,a2
        rts
M4VeVtoPlayer:
        lea LV_PLAYER,a2
        rts

; Byte Achase 1F:D85E/D88A/D8BD/D8F7/D938 (n = d2): d = t - v on 8 bits
; (wraps), |d| raised to 2^n, n signed halvings toward zero, v += d. d0.b =
; current, d1.b = target -> d0.b. d3 = 1 when v == t on entry (carry of
; 1F:DA29, the "done" exit), else 0. d1 clobbered.
M4VeAchase8:
        moveq #0,d3
        sub.b d0,d1
        bne.s M4VeA8Go
        moveq #1,d3
        rts
M4VeA8Go:
        move.l d0,-(sp)
        ext.w d1
        moveq #0,d0
        jsr M4LpAchase ;0 + trunc(clamp(d)/2^n), WORD rule of 1F:D63C..
        move.w d0,d1
        move.l (sp)+,d0
        add.b d1,d0
        rts

; |a2.z - a0.z| - d1 (16 bits; the N flag is the original cmp's): d0.
M4VeZDist:
        move.w 4(a2),d0
        sub.w 4(a0),d0
        bpl.s M4VeZDistPos
        neg.w d0
M4VeZDistPos:
        sub.w d1,d0
        rts
; |a2.y - a0.y| - d1.
M4VeYDist:
        move.w 2(a2),d0
        sub.w 2(a0),d0
        bpl.s M4VeYDistPos
        neg.w d0
M4VeYDistPos:
        sub.w d1,d0
        rts

; Shape change of this unit's objects: d0 = descriptor, d1 = ROM header.
M4VeSetShape:
        move.w d1,X_SHAPEHDR(a0)
        jmp M4LevelSetShape

; Original shape header ($04) of a3 -> d0.w: X_SHAPEHDR (map and unit
; objects) or the descriptor's header ($FFFF -> nullshape ACA1).
M4VeHeader:
        move.w X_SHAPEHDR(a3),d0
        bne.s M4VeHeaderDone
        move.w 46(a3),d0
        cmpi.w #$ffff,d0
        beq.s M4VeHeaderNull
        lsl.w #5,d0
        move.l a4,-(sp)
        lea M4LevelShapeDescriptors,a4
        move.w 16(a4,d0.w),d0
        movea.l (sp)+,a4
        rts
M4VeHeaderNull:
        move.w #$aca1,d0
M4VeHeaderDone:
        rts

; find_obj 1F:C7D5: from the find pointer ($14CC) along allst, the first
; object whose shape is d1.w other than a0 -> a3 (Z set when none); the
; pointer moves to the found object's next. Not found: the original leaves
; $14CC = [$0000] (direct page); the port leaves 0 (no later find reads it).
M4VeFindObj:
        move.w M4_VE_FINDPTR,d2
M4VeFindNext:
        tst.w d2
        beq.s M4VeFindNone
        movea.w d2,a3
        move.w X_NEXT(a3),d2
        cmpa.l a0,a3
        beq.s M4VeFindNext
        jsr M4VeHeader
        cmp.w d1,d0
        bne.s M4VeFindNext
        move.w d2,M4_VE_FINDPTR
        move.l a3,d0 ;Z clear
        rts
M4VeFindNone:
        clr.w M4_VE_FINDPTR
        suba.l a3,a3
        move.l a3,d0 ;Z set
        rts

; Allocation while M4_LV_CREATOR is a4 (1F:D54B with X = a4: linked right
; after a4). Returns a2 (Z set on failure). d0 = descriptor.
M4VeCreateAfter:
        move.l M4_LV_CREATOR,-(sp)
        move.l a4,M4_LV_CREATOR
        move.l a0,-(sp)
        movea.l a4,a0
        jsr M4EnCreate
        movea.l (sp)+,a0
        move.l (sp)+,M4_LV_CREATOR
        cmpa.w #0,a2
        rts

; Node reuse (1F:D3A9 pops the free list, LIFO): when pship1 removed the
; object mapvar1 names, the original's next allocation gets that same node,
; so mapvar1 then names the new object. a2 = the new object.
M4VeReuse:
        tst.w M4_VE_REUSE
        beq.s M4VeReuseDone
        clr.w M4_VE_REUSE
        move.w a2,M4_LV_MAPVAR1
M4VeReuseDone:
        rts

; Boost flame of this unit (boost_sprite #10: 06:DA90 / 06:DC71): boostobj =
; a0, make_obj(B219) linked after a0, sbyte1 = 10, invisible, Istrat 06:8671
; (M4VeFlameInit). As M4LevelBoostFlame plus the sbyte1 (sprite tx start).
M4VeFlame:
        movem.l d0/a0/a2,-(sp)
        move.w a0,M4_LP_BOOSTOBJ
        jsr M4LevelAlloc
        move.l a0,d0
        beq.s M4VeFlameDone
        movea.l a0,a2
        jsr M4VeReuse
        move.w #M4_FX_BOOST,d0
        move.w #$b219,d1
        jsr M4VeSetShape
        move.b #10,36(a0)
        bset #SF_INVISIBLE,49(a0)
        move.l #M4VeFlameInit,32(a0)
M4VeFlameDone:
        movem.l (sp)+,d0/a0/a2
        rts
; boost_Istrat 06:8671 / boost_strat 06:86AA (M4StratBoostInit with tx =
; sbyte1 and boostZoff $1570 = -80, the value this unit's ships set).
M4VeFlameInit:
        move.b #10,19(a0)
        bset #SF_COLLDISABLE,49(a0)
        bset #F2_SPRITE,48(a0)
        clr.b X_DEPTHOFF(a0)
        move.b 36(a0),X_TX(a0)
        bclr #SF_INVISIBLE,49(a0)
        bclr #3,45(a0)
        move.l #M4VeFlameTick,32(a0)
M4VeFlameTick:
        subq.b #1,X_TX(a0)
        move.w M4_LP_BOOSTOBJ,d0
        beq.s M4VeFlameGone
        movea.w d0,a2
        moveq #0,d3
        moveq #VE_BOOSTZOFF,d4
        move.b 12(a2),d5
        jsr M4WeaponRotatePair ;(y,z) by rotx 1F:CAFB
        move.b d3,d6
        moveq #0,d3
        move.b 13(a2),d5
        neg.b d5
        jsr M4WeaponRotatePair ;(x,z) by -roty 1F:C97B
        ext.w d3
        ext.w d4
        ext.w d6
        add.w (a2),d3
        add.w 2(a2),d6
        add.w 4(a2),d4
        move.w d3,(a0)
        move.w d6,2(a0)
        move.w d4,4(a0)
        subq.b #1,19(a0)
        beq.s M4VeFlameGone
        moveq #0,d0
        rts
M4VeFlameGone:
        moveq #1,d0 ;delete 1F:D501 (deferred removal of the current object)
        rts

; gen_3dvecs 1F:D5A7 (vel, rotx, roty) then add_vecs2pos 1F:C7BB; d0 = 0.
M4VeMove:
        jsr M4EnGen3d
        jsr M4EnMove
        moveq #0,d0
        rts

; Sine byte 00:98A5[d0.b] halved twice toward zero (set_var2alvartab ..,-2,
; 06:DE22/E0C7) -> d1.w = b << 8 (svar_word1: high byte b, low byte 0).
M4VeSinWord:
        andi.w #$ff,d0
        lea M4IntroShipSine,a2
        move.b (a2,d0.w),d1
        ext.w d1
        bpl.s M4VeSinPos
        addq.w #3,d1
M4VeSinPos:
        asr.w #2,d1
        lsl.w #8,d1
        rts

; ---------------------------------------------------------------------
; Map player modes (player_mode blocks 0D:DB5B and 0D:DBBE). Entry for the
; player_mode dispatch (M4LvPlayerMode, level.asm: not wired yet, see
; build/agent-venom/escape/INTEGRATION.md section 4; the oracle calls it):
; a2 = block record, 8(a2).l = original routine. d0.w = 0 handled, -1 not
; this unit's. Registers d1-d7/a0-a6 preserved. The player is LV_PLAYER.
M4VePlayerMode:
        movem.l d1-d7/a0-a6,-(sp)
        lea LV_PLAYER,a0
        move.l 8(a2),d1
        cmpi.l #$000baaad,d1
        bne.s M4VePmNot1
        ; set_playertoCslow_l 0B:AAAD: push_stratptr (tempstrat $1CD9 =
        ; strategy), strategy 0B:AADA, noctrl|nofire.
        move.l 32(a0),M4_VE_TEMPSTRAT
        move.l #M4VeToCslow,32(a0)
        ori.b #$60,M4_LP_PSF
        bra.s M4VePmDone
M4VePmNot1:
        cmpi.l #$000ba642,d1
        bne.s M4VePmBad
        ; set_playerOutOfLB2a_l 0B:A642: strategy 0B:A657 (control unchanged).
        move.l #M4VeOutLB2aI,32(a0)
M4VePmDone:
        movem.l (sp)+,d1-d7/a0-a6
        moveq #0,d0
        rts
M4VePmBad:
        movem.l (sp)+,d1-d7/a0-a6
        moveq #-1,d0
        rts

; ---------------------------------------------------------------------
; Player strategies. a0 = player; d0 = 0.

; playertoCslow 0B:AADA: viewdist 120, playertomiddle4 0B:AB25 (y -> viewCY,
; then x -> 0, Achase n = 4 1F:D6F0), then jmpto_tempstrat (0B:AAE8: the
; pushed strategy continues this pass; none when its bank byte is 0).
M4VeToCslow:
        move.w #120,M4_LP_VIEWDIST
        move.w 2(a0),d0
        move.w M4_LP_VIEWCY,d1
        moveq #4,d2
        jsr M4LpAchase
        move.w d0,2(a0)
        move.w (a0),d0
        moveq #0,d1
        jsr M4LpAchase
        move.w d0,(a0)
        move.l M4_VE_TEMPSTRAT,d0
        beq.s M4VeToCslowNone
        movea.l d0,a2
        jmp (a2)
M4VeToCslowNone:
        moveq #0,d0
        rts

; playerOutofLB1_Istrat 0B:A535 (newplayerstrat of bg $6F, 1_7a): Ltunnel
; limits; $1575/$1577 (+-120), $1581 (0), $157D/$157F (-120/5) have no
; port consumer. Then playerOutofLB1_strat 0B:A619.
M4VeOutLB1I:
        ori.b #$60,M4_LP_PSF
        move.l #M4VeOutLB1,32(a0)
        andi.b #$ef,M4_LP_FLYMODE
        ori.b #$08,M4_BOSS_PSTRATF ;inseq (cleared again below, 0B:A5FD)
        andi.b #$f7,M4_LP_GAMEFLAGS
        move.w #-60,M4_LP_VIEWCY
        move.w #-120,M4_LP_MINX
        move.w #120,M4_LP_MAXX
        move.w #-120,M4_LP_MINY
        move.w #-20,M4_LP_MAXY
        move.b #$09,M4_LP_FLYMODE
        move.b #$ff,M4_LP_PMOVEAND
        move.b #$0b,M4_SPP_LIMITS
        andi.b #$df,M4_LP_GAMEFLAGS
        andi.b #$fb,M4_BOSS_PSTRATF
        ori.b #$02,M4_LP_PSF3
        andi.b #$fb,M4_LP_PSF2
        andi.b #$d7,M4_BOSS_PSTRATF
        bset #F2_SHADOW,48(a0)
        ori.b #$01,M4_LP_PSF3 ;trigse $1E (no audio)
; 0B:A619: x -> 0, y -> viewCY (Achase n = 4), shrapnel_srou, tunnel.
M4VeOutLB1:
        move.w (a0),d0
        moveq #0,d1
        moveq #4,d2
        jsr M4LpAchase
        move.w d0,(a0)
        move.w 2(a0),d0
        move.w M4_LP_VIEWCY,d1
        jsr M4LpAchase
        move.w d0,2(a0)
        bsr M4VeShrapnel
        bra M4VeTunnel

; set_playerOutOfLB2a 0B:A657: boostobj, speed and tospeed maxpspeed 85,
; boost flame (06:8671, boostZoff still -30: M4LevelBoostFlame), trigse $32.
M4VeOutLB2aI:
        move.l #M4VeOutLB2a,32(a0)
        move.b #85,15(a0)
        move.b #85,M4_LP_TOSPEED
        jsr M4LevelBoostFlame ;boostobj = player, flame linked after it
; 0B:A6A1: player_Zstratadd -= 4, then the tunnel strategy.
M4VeOutLB2a:
        subq.b #4,M4_LP_ZSTRATADD
; playerintunnel_strat 0B:BF79: outvx/outvy -> 0 (Achase n = 2), tunnel move
; 0B:E913, pviewposx = perc87(x), pviewposy = viewCY, viewmove 0B:D083; the
; port's laser/bomb factories as M4LevelPlayerStrat (nofire: no requests).
M4VeTunnel:
        move.w M4_LP_OUTVX,d0
        moveq #0,d1
        moveq #2,d2
        jsr M4LpAchase
        move.w d0,M4_LP_OUTVX
        move.w M4_LP_OUTVY,d0
        jsr M4LpAchase
        move.w d0,M4_LP_OUTVY
        movem.l d0-d7/a1,-(sp)
        jsr M4LpMove ;0B:D33A
        moveq #0,d0
        move.b 15(a0),d0
        jsr M4LevelGen3dVecs ;1F:D5A7
        move.w 6(a0),d0 ;vx = perc62 1F:D4A8: asr1(v) + asr3(v)
        move.w d0,d1
        asr.w #1,d1
        asr.w #3,d0
        add.w d1,d0
        move.w d0,6(a0)
        move.w 8(a0),d0 ;vy = adiv2 (toward zero)
        jsr M4LpDiv2
        move.w d0,8(a0)
        jsr M4LpFrameScale ;0B:EA9A
        jsr M4EnMove ;1F:C7BB
        jsr M4SpLimitX ;0B:DF21
        jsr M4LpFire ;0B:DF6C
        bsr M4VeArrows ;0B:E9D0
        move.w (a0),d0 ;pviewposx = perc87(x): asr1 + asr2 + asr3
        move.w d0,d1
        asr.w #1,d1
        move.w d0,d2
        asr.w #2,d2
        add.w d2,d1
        asr.w #3,d0
        add.w d0,d1
        move.w d1,M4_LP_PVIEWX
        move.w M4_LP_VIEWCY,M4_LP_PVIEWY
        jsr M4LpViewMove ;0B:D083
        movem.l (sp)+,d0-d7/a1
        jsr M4LevelFireBomb
        jsr M4LevelFireLasers
        moveq #0,d0
        rts

; Arrows 0B:E9D0: inseq -> 0; else each arrow bit kept only while its pad
; direction is held and its pmoveand bit is clear.
; cont0 $1202 = high byte of M4_LP_JOY.
M4VeArrows:
        btst #3,M4_BOSS_PSTRATF
        beq.s M4VeArrowsGo
        clr.b M4_LP_ARROWS
        rts
M4VeArrowsGo:
        move.b M4_LP_JOY,d1
        move.b M4_LP_PMOVEAND,d2
        lea M4VeArrowTab,a2
        moveq #3,d3
M4VeArrowNext:
        move.b (a2)+,d0 ;pad bit
        and.b d1,d0
        beq.s M4VeArrowClr
        move.b (a2),d0 ;pmoveand bit
        and.b d2,d0
        beq.s M4VeArrowKeep
M4VeArrowClr:
        move.b 1(a2),d0 ;arrow bit mask (cleared)
        and.b d0,M4_LP_ARROWS
M4VeArrowKeep:
        addq.l #2,a2
        dbra d3,M4VeArrowNext
        rts
M4VeArrowTab: ;pad bit, pmoveand bit, ~arrow bit
        include '../build/m4-arrow-masks.inc'
        even

; shrapnel_srou 0B:A7DE. Every 8 ticks a shrap1 ahead of the player (strategy
; shrapfall2 0B:A8E5); every 2 ticks a large and a medium explosion (06:EEDF,
; 06:EEEE): no zremove, nopolyexp, sound, vz 150, z - 200, addrnd2posy
; 06:EF67. A failed explosion works on dummyobj: its random draws still run.
M4VeShrapnel:
        move.w M4_LV_GAMEFRAME,d0
        andi.w #7,d0
        bne.s M4VeShrapNoPiece
        move.w #M4VeShShrap,d0
        bsr M4VeCreateHere
        beq.s M4VeShrapNoPiece
        move.w #$c638,X_SHAPEHDR(a2)
        move.l #M4VeShrapFall,32(a2)
        jsr M4IntroRandom ;x = rnd - 128 (low byte only, 0B:A80C)
        andi.w #$ff,d0
        subi.w #128,d0
        move.w d0,(a2)
        jsr M4IntroRandom
        andi.w #$ff,d0
        subi.w #128,d0
        add.w M4_LP_VIEWCY,d0
        move.w d0,2(a2)
        jsr M4IntroRandom
        move.b d0,13(a2)
        jsr M4IntroRandom
        move.b d0,12(a2)
        move.w 4(a0),d0
        addi.w #2000,d0
        move.w d0,4(a2)
M4VeShrapNoPiece:
        move.w M4_LV_GAMEFRAME,d0
        andi.w #1,d0
        bne.s M4VeShrapDone
        jsr M4FxLarge
        bsr.s M4VeShrapExp
        jsr M4FxMedium
M4VeShrapExp:
        beq.s M4VeShrapDummy
        bsr M4VeReuseA2
        bclr #3,45(a2) ;setnoremove_behind
        bset #F2_NOPOLYEXP,48(a2)
        bclr #F2_NOEXPSND,48(a2)
        move.w #150,10(a2)
        subi.w #200,4(a2)
        jmp M4FxRandomPos
M4VeShrapDummy:
        jsr M4IntroRandom
        jmp M4IntroRandom
M4VeShrapDone:
        rts
; 1F:D54B behind a0 (the running object): a2, Z on failure. d0 = descriptor.
M4VeCreateHere:
        jsr M4EnCreate
        beq.s M4VeCreateHereDone
        bsr.s M4VeReuseA2
        cmpa.w #0,a2
M4VeCreateHereDone:
        rts
M4VeReuseA2:
        move.l d0,-(sp)
        jsr M4VeReuse
        move.l (sp)+,d0
        cmpa.w #0,a2
        rts
; shrapfall2 0B:A8E5: z -= 30.
M4VeShrapFall:
        subi.w #30,4(a0)
        moveq #0,d0
        rts

; playerOutofLB2_Istrat 0B:A6CD (bg $75, 1_7b): planet limits, invisible,
; nozremove, outvx $C000, bg2Yscroll 200; strategy 0B:A7CD z += 65.
M4VeOutLB2I:
        ori.b #$60,M4_LP_PSF
        move.l #M4VeOutLB2,32(a0)
        andi.b #$ef,M4_LP_FLYMODE
        ori.b #$08,M4_BOSS_PSTRATF
        move.w #-50,M4_LP_VIEWCY
        move.w #-500,M4_LP_MINX
        move.w #500,M4_LP_MAXX
        move.w #-255,M4_LP_MINY
        move.w #-20,M4_LP_MAXY
        move.b #$1b,M4_LP_FLYMODE
        move.b #$a8,M4_LP_PMOVEAND
        move.b #$08,M4_SPP_LIMITS
        ori.b #$20,M4_LP_GAMEFLAGS
        andi.b #$fb,M4_BOSS_PSTRATF
        ori.b #$02,M4_LP_PSF3
        andi.b #$fb,M4_LP_PSF2
        andi.b #$d7,M4_BOSS_PSTRATF
        bset #F2_SHADOW,48(a0)
        andi.b #$fe,M4_LP_PSF3
        ori.b #$01,M4_LP_GAMEFLAGS ;nozremove
        bset #SF_INVISIBLE,49(a0)
        move.w #$c000,M4_LP_OUTVX
        move.w #200,M4_SC_BG2Y
        andi.b #$f7,M4_LP_GAMEFLAGS
M4VeOutLB2:
        addi.w #65,4(a0)
        moveq #0,d0
        rts

; playerOutofLB3_Istrat 0B:A907 (bg $7B, 1_7c): space limits, inseq,
; nozremove, invisible, bg2Yscroll 292; strategy 0B:A9F7: bg2Yscroll - 1
; down to 172, z += 65.
M4VeOutLB3I:
        ori.b #$60,M4_LP_PSF
        move.l #M4VeOutLB3,32(a0)
        move.w #-60,M4_LP_VIEWCY
        move.w #-240,M4_LP_MINX
        move.w #240,M4_LP_MAXX
        move.w #-190,M4_LP_MINY
        move.w #60,M4_LP_MAXY
        move.b #$12,M4_LP_FLYMODE
        clr.b M4_LP_PMOVEAND
        clr.b M4_SPP_LIMITS
        ori.b #$20,M4_LP_GAMEFLAGS
        andi.b #$fb,M4_BOSS_PSTRATF
        ori.b #$02,M4_LP_PSF3
        andi.b #$fb,M4_LP_PSF2
        andi.b #$d7,M4_BOSS_PSTRATF
        andi.b #$fe,M4_LP_PSF3
        ori.b #$08,M4_BOSS_PSTRATF ;inseq
        andi.b #$ef,M4_LP_FLYMODE
        ori.b #$01,M4_LP_GAMEFLAGS
        bset #SF_INVISIBLE,49(a0)
        andi.b #$f7,M4_LP_GAMEFLAGS
        move.w #292,M4_SC_BG2Y
M4VeOutLB3:
        cmpi.w #172,M4_SC_BG2Y
        beq.s M4VeOutLB3Z
        subq.w #1,M4_SC_BG2Y
M4VeOutLB3Z:
        addi.w #65,4(a0)
        moveq #0,d0
        rts

; ---------------------------------------------------------------------
; Objects. a0 = object, a1 = player; d0 = 0 keep.

; lseqdoor1 06:D2A5 (door_l): colldisable; |pz - z| >= 585 -> closed (anim
; 0); else opens: anim + 1 up to 9 (add_anim modulo 10), sound $55 at 0.
M4VeDoor1:
        bset #SF_COLLDISABLE,49(a0)
        movea.l a1,a2
        move.w #585,d1
        bsr M4VeZDist
        bpl.s M4VeDoorClose
        move.b 16(a0),d0
        andi.b #$7f,d0
        cmpi.b #9,d0
        beq.s M4VeDoorDone
        moveq #10,d2
M4VeDoorStep:
        move.b 16(a0),d0
        moveq #1,d1
        jsr M4WpAddAnim
        move.b d0,16(a0)
M4VeDoorDone:
        moveq #0,d0
        rts
M4VeDoorClose:
        move.b #$80,16(a0)
        moveq #0,d0
        rts

; lseqdoor2 06:D30B (last_b_3): colldisable; viewtoobj within 400 in y ->
; gameflags2 bit0; within 200 -> sflag1 (opens for good): anim + 1 up to 10
; (modulo 11); else closed.
M4VeDoor2:
        bset #SF_COLLDISABLE,49(a0)
        btst #F2_SFLAG1,48(a0)
        bne.s M4VeDoor2Open
        bsr M4VeVto
        move.w #400,d1
        bsr M4VeYDist
        bpl.s M4VeDoor2Far
        bset #0,M4_AR_GF2
M4VeDoor2Far:
        move.w #200,d1
        bsr M4VeYDist
        bpl.s M4VeDoorClose
        bset #F2_SFLAG1,48(a0)
M4VeDoor2Open:
        move.b 16(a0),d0
        andi.b #$7f,d0
        cmpi.b #10,d0
        beq.s M4VeDoorDone
        moveq #11,d2
        bra.s M4VeDoorStep

; pshipoutofLB1_Istrat 06:D470 (my_demoS): colldisable, speed 65, rotx -64,
; viewtoobj = this ship, stratdone1 cleared.
M4VePship1I:
        move.l #M4VePship1,32(a0)
        bset #SF_COLLDISABLE,49(a0)
        move.b #65,15(a0)
        move.b #$c0,12(a0)
        move.w a0,M4_VE_VTO
        andi.b #$f7,M4_LP_GAMEFLAGS
; 06:D496 state machine (X_STATE); nextstate 1F:DB66 runs the strategy again
; from the top in the same pass.
M4VePship1:
        tst.b X_STATE(a0)
        bne.s M4VeP1S1
        subq.b #4,14(a0) ;state 0: up out of the base
        move.w 2(a0),d0
        cmpi.w #-1000,d0
        bpl.s M4VeP1S1 ;N clear: not above y = -1000
        moveq #85,d0
        moveq #1,d1
        jsr M4EnSpeedTo
        move.b #23,36(a0)
        cmpi.b #$e0,12(a0)
        bne.s M4VeP1RotX
        addq.b #1,X_STATE(a0) ;startbgm 7 (no audio), nextstate
        bra.s M4VePship1
M4VeP1RotX:
        addq.b #2,12(a0)
M4VeP1S1:
        cmpi.b #1,X_STATE(a0)
        bne.s M4VeP1S2
        subq.b #1,36(a0) ;state 1: line up
        bne.s M4VeP1S1Chase
        move.b #1,36(a0)
        move.w #M4VeShDemoBS,d0
        move.w #$bc98,d1
        jsr M4VeSetShape
M4VeP1S1Chase:
        move.b 14(a0),d0
        moveq #0,d1
        moveq #3,d2
        bsr M4VeAchase8
        move.b d0,14(a0)
        move.b 12(a0),d0
        moveq #0,d1
        moveq #5,d2
        bsr M4VeAchase8
        move.b d0,12(a0)
        tst.w d3
        beq.s M4VeP1S2
        move.w #M4_SH_MY_DEMOS,d0
        move.w #$bcb4,d1
        jsr M4VeSetShape
        move.b #70,36(a0)
        addq.b #1,X_STATE(a0)
M4VeP1S2:
        cmpi.b #2,X_STATE(a0)
        bne.s M4VeP1S3
        subq.b #1,36(a0) ;state 2: wait for the turn
        bne.s M4VeP1S3
        addq.b #1,X_STATE(a0)
        move.b #47,36(a0)
        bra M4VeP1Move
M4VeP1S3:
        cmpi.b #3,X_STATE(a0)
        bne M4VeP1S4
        bsr M4VeP1Base ;state 3: remove the base, the companions
        addq.b #1,X_STATE(a0)
M4VeP1S4:
        cmpi.b #4,X_STATE(a0)
        bne.s M4VeP1S5
        move.b #10,15(a0) ;state 4: turn
        subq.b #1,36(a0)
        bne.s M4VeP1Turn
        move.b #110,36(a0)
        addq.b #1,X_STATE(a0) ;nextstate
        bra M4VePship1
M4VeP1Turn:
        addq.b #3,13(a0)
        cmpi.b #$20,14(a0)
        beq.s M4VeP1S5
        btst #0,M4_LV_GAMEFRAME+1
        bne.s M4VeP1S5
        addq.b #1,14(a0)
M4VeP1S5:
        cmpi.b #5,X_STATE(a0)
        bne.s M4VeP1Move
        move.b #15,15(a0) ;state 5: away, then stratdone1
        move.b 36(a0),d0
        cmpi.b #60,d0
        beq.s M4VeP1Down
        bpl.s M4VeP1Fpos
M4VeP1Down:
        btst #0,M4_LV_GAMEFRAME+1
        bne.s M4VeP1Fpos
        subq.b #1,12(a0)
M4VeP1Fpos:
        move.b #2,M4_SC_VIEWTYPE
        subq.b #1,36(a0)
        bne.s M4VeP1Move
        ori.b #$08,M4_LP_GAMEFLAGS
M4VeP1Move:
        bra M4VeMove

; 06:D564: set_find 0 (allst head), find last_b_0 and last_b_3 (each
; removed, the second search resuming after the first find), then a
; companion my_demoS (shiplb1 06:D3A2) per live friend: frog $18A4,
; falcon $18A3, rabbit $18A2 (copy_pos/rots/vecs, offsets, sword1, sbyte1).
M4VeP1Base:
        move.w M4_LV_HEAD,M4_VE_FINDPTR
        move.w #$d010,d1
        bsr M4VeFindObj
        beq.s M4VeP1NoB0
        bsr M4VeRemoveFound
M4VeP1NoB0:
        move.w #$d048,d1
        bsr M4VeFindObj
        beq.s M4VeP1NoB3
        bsr M4VeRemoveFound
M4VeP1NoB3:
        lea M4VeMateTab,a4
        moveq #2,d7
M4VeP1Mate:
        move.w (a4),d0 ;friends_hp index
        lea M4_PV_FRIENDHP,a3
        tst.b (a3,d0.w)
        beq.s M4VeP1MateNext
        move.w #M4_SH_MY_DEMOS,d0
        bsr M4VeCreateHere
        beq.s M4VeP1MateNext
        move.w #$bcb4,X_SHAPEHDR(a2)
        move.l (a0),(a2) ;copy_pos 1F:DAD9
        move.w 4(a0),4(a2)
        move.b 12(a0),12(a2) ;copy_rots 1F:DB01
        move.b 13(a0),13(a2)
        move.b 14(a0),14(a2)
        move.l 6(a0),6(a2) ;copy_vecs
        move.w 10(a0),10(a2)
        move.w 2(a4),d0
        add.w d0,(a2)
        move.w 4(a4),d0
        add.w d0,2(a2)
        move.w 6(a4),40(a2)
        move.w 8(a4),d0
        add.w d0,4(a2)
        move.b 11(a4),36(a2)
        move.l #M4VeShipLb1,32(a2)
M4VeP1MateNext:
        lea 12(a4),a4
        dbra d7,M4VeP1Mate
        rts
; index, dx, dy, sword1, dz, sbyte1 (06:D59E frog, D61E falcon, D69E rabbit)
M4VeMateTab:
        include '../build/m4-venom-escape-formation.inc'
; remove_obj 1F:D540 of a3 (removedeadal: immediate). The node goes to the
; head of the original's free list: if mapvar1 names it, the next
; allocation reuses it (M4VeReuse).
M4VeRemoveFound:
        move.w a3,d0
        cmp.w M4_LV_MAPVAR1,d0
        bne.s M4VeRemoveNoVar
        move.w d0,M4_VE_REUSE
M4VeRemoveNoVar:
        move.l a0,-(sp)
        movea.l a3,a0
        jsr M4LevelRemove
        movea.l (sp)+,a0
        rts

; shiplb1 06:D3A2 (companions leaving the base): colldisable; state 0 speed
; 20, y chase, rotz 32, roty 64 for sbyte1 ticks; state 1 roty + 3 for 25;
; state 2 y chase for 40, then rotx - 1 every other tick.
M4VeShipLb1:
        bset #SF_COLLDISABLE,49(a0)
        tst.b X_STATE(a0)
        bne.s M4VeLb1S1
        move.b #20,15(a0)
        bsr.s M4VeLb1Chase
        move.b #$20,14(a0)
        move.b #$40,13(a0)
        subq.b #1,36(a0)
        bne.s M4VeLb1S1
        move.b #25,36(a0)
        addq.b #1,X_STATE(a0)
M4VeLb1S1:
        cmpi.b #1,X_STATE(a0)
        bne.s M4VeLb1S2
        bsr.s M4VeLb1Chase
        addq.b #3,13(a0)
        subq.b #1,36(a0)
        bne.s M4VeLb1S2
        move.b #40,36(a0)
        addq.b #1,X_STATE(a0)
M4VeLb1S2:
        cmpi.b #2,X_STATE(a0)
        bne.s M4VeLb1Move
        subq.b #1,36(a0)
        bne.s M4VeLb1Wait
        move.b #1,36(a0)
        btst #0,M4_LV_GAMEFRAME+1
        bne.s M4VeLb1Move
        subq.b #1,12(a0)
        bra.s M4VeLb1Move
M4VeLb1Wait:
        bsr.s M4VeLb1Chase
M4VeLb1Move:
        bra M4VeMove
; 06:D443: y -> viewtoobj.y + sword1 (Achase n = 5 1F:D73E).
M4VeLb1Chase:
        bsr M4VeVto
        move.w 2(a2),d1
        add.w 40(a0),d1
        move.w 2(a0),d0
        moveq #5,d2
        jsr M4LpAchase
        move.w d0,2(a0)
        rts

; viewoutofLB1_Istrat 06:D7C0 (camera carrier): sword1 = outdist, sword2 =
; al_ptr = 0, viewtype Fpos|toobj, rotx -32, gameflags2 bit0 cleared.
M4VeView1I:
        move.l #M4VeView1,32(a0)
        bset #SF_COLLDISABLE,49(a0)
        move.w M4_LP_OUTDIST,40(a0)
        clr.w 42(a0)
        clr.w X_ALPTR(a0)
        move.b #3,M4_SC_VIEWTYPE
        move.b #$e0,12(a0)
        bclr #0,M4_AR_GF2
; 06:D7FF: explosions at mapvar1 while gameflags2 bit0 and not sflag3;
; speed/rotx from the viewtoobj ship's state; the circle wipe object when
; the ship climbs above y = -1000 (it then follows this carrier's vy);
; viewpos = position, then move.
M4VeView1:
        btst #VE_SF3,50(a0)
        bne M4VeV1NoExp
        btst #0,M4_AR_GF2
        beq M4VeV1NoExp
        movea.w M4_LV_MAPVAR1,a4
        move.w #M4_FX_LARGE,d0 ;makeLexpobj 06:EEDF with X = mapvar1
        bsr M4VeExpAt
        moveq #2,d5 ;3 x ((rnd & $7F) - 63)
        moveq #0,d6
M4VeV1Rnd:
        jsr M4IntroRandom
        andi.w #$7f,d0
        subi.w #63,d0
        cmpa.w #0,a2
        beq.s M4VeV1RndNext
        add.w d0,(a2,d6.w)
M4VeV1RndNext:
        addq.w #2,d6
        dbra d5,M4VeV1Rnd
        move.w #-400,d4
        bsr.s M4VeV1Exp
        move.w #M4_FX_LARGE,d0
        bsr M4VeExpAt
        moveq #2,d5 ;06:EFA0: 3 x sext(rnd) * 2
        moveq #0,d6
M4VeV1Rnd2:
        jsr M4IntroRandom
        ext.w d0
        add.w d0,d0
        cmpa.w #0,a2
        beq.s M4VeV1Rnd2Next
        add.w d0,(a2,d6.w)
M4VeV1Rnd2Next:
        addq.w #2,d6
        dbra d5,M4VeV1Rnd2
        move.w #-800,d4
        bsr.s M4VeV1Exp
        bra.s M4VeV1NoExp
M4VeV1Exp: ;not relexplode, nopolyexp, y += d4
        cmpa.w #0,a2
        beq.s M4VeV1ExpDone
        bclr #F2_RELEXPLODE,48(a2)
        bset #F2_NOPOLYEXP,48(a2)
        add.w d4,2(a2)
M4VeV1ExpDone:
        rts
M4VeV1NoExp:
        bsr M4VeVto
        move.b X_STATE(a2),d0
        bne.s M4VeV1St1
        movem.l d0/a2,-(sp)
        moveq #80,d0
        moveq #2,d1
        jsr M4EnSpeedTo
        movem.l (sp)+,d0/a2
M4VeV1St1:
        cmpi.b #1,d0
        bne.s M4VeV1St4
        movem.l d0/a2,-(sp)
        move.b 12(a0),d0
        moveq #0,d1
        moveq #5,d2
        bsr M4VeAchase8
        move.b d0,12(a0)
        movem.l (sp)+,d0/a2
M4VeV1St4:
        cmpi.b #4,d0
        bne.s M4VeV1Circle
        bset #VE_SF3,50(a0)
        clr.b 15(a0)
M4VeV1Circle:
        btst #F2_SFLAG1,48(a0)
        bne.s M4VeV1CircleMove
        move.w 2(a2),d0
        cmpi.w #-1000,d0
        bpl.s M4VeV1View ;N clear: the ship is not above -1000
        bset #F2_SFLAG1,48(a0)
        movea.w M4_LV_MAPVAR1,a4
        move.w #$ffff,d0 ;make_obj(nullshape) behind mapvar1
        bsr M4VeCreateAfter
        beq.s M4VeV1CircleMove
        bsr M4VeReuseA2
        move.w #$aca1,X_SHAPEHDR(a2)
        move.w a2,M4_SC_CIRCLEOBJ
        move.l (a4),(a2) ;copy_pos from mapvar1
        move.w 4(a4),4(a2)
        move.w #$cf,M4_SC_CIRCLE ;circleanim laststage_circle (trigse $1D)
        clr.w M4_SC_WIPETICK
M4VeV1CircleMove:
        move.w M4_SC_CIRCLEOBJ,d0
        beq.s M4VeV1View ;no circle object (make_obj failed)
        movea.w d0,a2
        move.w 8(a0),d0
        add.w d0,2(a2)
M4VeV1View:
        move.l (a0),M4_SC_VIEWPOS
        move.w 4(a0),M4_SC_VIEWPOS+4
        bra M4VeMove
; makeLexpobj (06:EF1B) with X = a4: a2 or 0. d0 = descriptor.
M4VeExpAt:
        bsr M4VeCreateAfter
        beq.s M4VeExpAtFail
        bsr M4VeReuseA2
        bset #SF_COLLDISABLE,49(a2) ;as M4FxMedium (06:EF2F..EF5E)
        bset #F2_NOEXPSND,48(a2)
        bset #F2_RELEXPLODE,48(a2)
        move.l #M4FxDelayInit,32(a2)
        move.l (a4),(a2) ;copy_pos 1F:DAD9 from X (mapvar1)
        move.w 4(a4),4(a2)
M4VeExpAtFail:
        rts

; shipoutofLB3_Istrat 06:D9C9 (companions, my_demo; map sets al_ptr, sword1,
; sword2, sbyte2, rotz): sbyte1 150, type gnd.
M4VeShip3I:
        move.l #M4VeShip3,32(a0)
        move.b #150,36(a0)
        ori.b #$01,45(a0)
; 06:D9E0.
M4VeShip3:
        tst.b X_STATE(a0)
        bne.s M4VeS3S1
        tst.b 36(a0) ;state 0: 150 ticks at z + 100 per tick
        bne.s M4VeS3Fly
        addq.b #1,X_STATE(a0) ;nextstate
        bra.s M4VeShip3
M4VeS3Fly:
        subq.b #1,36(a0)
        addi.w #100,4(a0)
        bra M4VeS3End
M4VeS3S1:
        cmpi.b #1,X_STATE(a0)
        bne.s M4VeS3S2
        clr.b 14(a0) ;state 1: z = al_ptr + viewposz
        move.w X_ALPTR(a0),d0
        add.w M4_LVW_POS+4,d0
        move.w d0,4(a0)
        addq.b #1,X_STATE(a0)
M4VeS3S2:
        cmpi.b #2,X_STATE(a0)
        bne.s M4VeS3S3
        btst #0,M4_AR_GF2 ;state 2: hold formation
        beq.s M4VeS3Wait
        addq.b #1,X_STATE(a0) ;nextstate
        bra.s M4VeShip3
M4VeS3Wait:
        bsr M4VeVto
        move.w 40(a0),d0
        add.w (a2),d0
        move.w d0,(a0)
        move.w 42(a0),d0
        add.w 2(a2),d0
        move.w d0,2(a0)
        addi.w #80,4(a0)
        bra.s M4VeS3End
M4VeS3S3:
        cmpi.b #3,X_STATE(a0)
        bne.s M4VeS3S4
        subq.b #1,37(a0) ;state 3: sbyte2 ticks, then boost
        bne.s M4VeS3Wait
        bsr M4VeFlame ;trigse $32
        addq.b #1,X_STATE(a0)
        move.b #15,36(a0)
M4VeS3S4:
        cmpi.b #4,X_STATE(a0)
        bne.s M4VeS3End
        addi.w #80,4(a0)
        jsr M4EnMove
        move.w 10(a0),d0
        cmpi.w #150,d0
        beq.s M4VeS3Acc
        bpl.s M4VeS3NoAcc
M4VeS3Acc:
        addi.w #15,10(a0)
M4VeS3NoAcc:
        bsr.s M4VeClimb
M4VeS3End:
        moveq #0,d0
        rts
; 06:DB11 / 06:DCEE: every sbyte1 ticks (then every tick) vy - 5 down to
; -40 and rotx -> -16 (Achase8 n = 3 1F:D8BD).
M4VeClimb:
        subq.b #1,36(a0)
        bne.s M4VeClimbDone
        move.b #1,36(a0)
        cmpi.w #-40,8(a0)
        beq.s M4VeClimbRot
        subq.w #5,8(a0)
M4VeClimbRot:
        move.b 12(a0),d0
        move.b #$f0,d1
        moveq #3,d2
        bsr M4VeAchase8
        move.b d0,12(a0)
M4VeClimbDone:
        rts

; pshipoutofLB3_Istrat 06:DB45 (my_demo): viewtoobj = Y at the first
; do_strat (the object itself: 02:DB10 ldy/tyx), viewtype Fpos|toobj,
; stratdone1 cleared, type gnd.
M4VePship3I:
        move.l #M4VePship3,32(a0)
        move.w a0,M4_VE_VTO
        move.b #3,M4_SC_VIEWTYPE
        andi.b #$f7,M4_LP_GAMEFLAGS
        ori.b #$01,45(a0)
; 06:DB68.
M4VePship3:
        tst.b X_STATE(a0)
        bne.s M4VeP3S1
        tst.b M4_SC_VIEWTYPE ;state 0: to the camera
        bne.s M4VeP3Near
        addq.b #1,X_STATE(a0) ;nextstate (viewtype normal)
        bra.s M4VePship3
M4VeP3Near:
        addi.w #84,4(a0)
        lea M4_LVW_POS,a2 ;viewpt $1238 (viewblk of the last getview)
        btst #F2_SFLAG1,48(a0)
        bne.s M4VeP3Far
        move.w #500,d1
        bsr M4VeZDist
        bmi.s M4VeP3Slow
        addi.w #11,4(a0)
        bra.s M4VeP3Far
M4VeP3Slow:
        bset #F2_SFLAG1,48(a0)
M4VeP3Far:
        move.w #3000,d1
        bsr M4VeZDist
        bpl.s M4VeP3S1
        addq.w #1,(a0)
M4VeP3S1:
        cmpi.b #1,X_STATE(a0)
        bne.s M4VeP3S2
        btst #0,M4_AR_GF2 ;state 1: wait for gameflags2 bit0
        beq.s M4VeP3Hold
        addq.b #1,X_STATE(a0) ;nextstate
        bra.s M4VePship3
M4VeP3Hold:
        move.w 40(a0),d0
        addi.w #84,d0
        add.w d0,4(a0)
        move.w #81,M4_LP_PVIEWVZ
        cmpi.w #-3,40(a0)
        beq.s M4VeP3S2
        move.w M4_LV_GAMEFRAME,d0
        andi.w #3,d0
        bne.s M4VeP3S2
        subq.w #1,40(a0)
M4VeP3S2:
        cmpi.b #2,X_STATE(a0)
        bne.s M4VeP3S3
        addi.w #81,4(a0) ;state 2: sbyte2 ticks, then boost
        subq.b #1,37(a0)
        bne.s M4VeP3S3
        andi.b #$fd,M4_LP_PSF3 ;engine sound off; startbgm $F1
        bsr M4VeFlame ;trigse $32
        addq.b #1,X_STATE(a0)
        move.b #15,36(a0)
        bra.s M4VeP3End
M4VeP3S3:
        cmpi.b #3,X_STATE(a0)
        bne.s M4VeP3End
        addi.w #81,4(a0) ;state 3: away
        jsr M4EnMove
        cmpi.w #150,10(a0)
        beq.s M4VeP3NoAcc
        addi.w #15,10(a0)
M4VeP3NoAcc:
        bsr M4VeClimb
        lea M4_LVW_POS,a2
        move.w #2000,d1
        bsr M4VeZDist
        bmi.s M4VeP3End
        andi.b #$fe,M4_LP_GAMEFLAGS
        ori.b #$08,M4_LP_GAMEFLAGS
M4VeP3End:
        moveq #0,d0
        rts

; viewoutofLB3_Istrat 06:DD51 (camera carrier): speed 65, sbyte1 50,
; gameflags2 bit0 cleared, never z-removed.
M4VeView3I:
        move.l #M4VeView3,32(a0)
        move.b #65,15(a0)
        move.b #50,36(a0)
        bclr #0,M4_AR_GF2
        bclr #3,45(a0)
; 06:DD74: y = viewtoobj (the escaping ship).
M4VeView3:
        bsr M4VeVto
        tst.b X_STATE(a0)
        bne M4VeV3S1
        move.l a2,-(sp) ;state 0: fly in front, Fpos camera
        jsr M4EnGen3d
        jsr M4EnMove
        movea.l (sp)+,a2
        move.l (a0),M4_SC_VIEWPOS
        move.w 4(a0),M4_SC_VIEWPOS+4
        move.w #250,d1
        bsr M4VeZDist
        bpl.s M4VeV3S1
        move.l a2,-(sp)
        moveq #80,d0
        moveq #1,d1
        jsr M4EnSpeedTo
        movea.l (sp)+,a2
        subq.b #1,36(a0)
        bne.s M4VeV3S1
        addq.b #1,X_STATE(a0)
        move.w #280,M4_LP_OUTDIST
        move.w #$1700,M4_LP_OUTVY
        clr.b M4_SC_VIEWTYPE ;normal view
        move.w #230,40(a0)
M4VeV3S1:
        cmpi.b #1,X_STATE(a0)
        bne.s M4VeV3S2
        bsr M4VeSwing ;state 1: swing round the ship
        cmpi.w #100,40(a0)
        bmi.s M4VeV3Near
        cmpi.w #600,M4_LP_OUTDIST
        beq.s M4VeV3Out
        bpl.s M4VeV3Dec
M4VeV3Out:
        addq.w #2,M4_LP_OUTDIST
        bra.s M4VeV3Dec
M4VeV3Near:
        subq.w #1,M4_LP_OUTDIST
M4VeV3Dec:
        subq.w #1,40(a0)
        bne.s M4VeV3S2
        addq.b #1,X_STATE(a0)
        move.b #70,36(a0)
M4VeV3S2:
        cmpi.b #2,X_STATE(a0)
        bne.s M4VeV3S3
        moveq #5,d2 ;state 2: centre, then levelfinished = 6
        bsr M4VeOutV0
        subq.b #1,36(a0)
        bne.s M4VeV3S2Move
        move.b #6,M4_GS_LEVELFIN ;06:DFB7 sta $1FD4
        addq.b #1,X_STATE(a0)
        bsr M4VeLevelFinished
M4VeV3S2Move:
        bsr M4VeLb3Move
M4VeV3S3:
        cmpi.b #3,X_STATE(a0)
        bne.s M4VeV3S4
        moveq #3,d2 ;state 3: wait for levelfinished 9 (end_game_seq)
        bsr M4VeOutV0
        bsr M4VeLb3Move
        cmpi.b #9,M4_GS_LEVELFIN
        bne.s M4VeV3S4
        addq.b #1,X_STATE(a0)
        move.b #$e0,36(a0)
        clr.b X_SBYTE3(a0)
M4VeV3S4:
        cmpi.b #4,X_STATE(a0)
        bne.s M4VeV3S5
        subq.b #1,36(a0) ;state 4: second swing, outdist + 1
        cmpi.b #$10,36(a0)
        bne.s M4VeV3Swing2
        addq.b #1,X_STATE(a0) ;nextstate
        bra M4VeView3
M4VeV3Swing2:
        addq.w #1,M4_LP_OUTDIST ;sbyte1 $A0: trigse $0D (speech, no audio)
        bsr M4VeSwing
M4VeV3S5:
        cmpi.b #5,X_STATE(a0)
        bne.s M4VeV3S6
        move.b #60,36(a0)
        addq.b #1,X_STATE(a0)
M4VeV3S6:
        cmpi.b #6,X_STATE(a0)
        bne.s M4VeV3End
        moveq #5,d2 ;state 6: zoom in, then Fpos
        bsr M4VeOutV0
        move.w M4_LP_OUTDIST,d0
        moveq #100,d1
        jsr M4LpAchase
        move.w d0,M4_LP_OUTDIST
        bsr M4VeLb3Move
        move.l M4_LVW_POS,M4_SC_VIEWPOS ;$C1..$C5 of the last getview
        move.w M4_LVW_POS+4,d0
        addi.w #80,d0
        move.w d0,M4_SC_VIEWPOS+4 ;viewposz += 80
        subq.b #1,36(a0)
        bne.s M4VeV3End
        move.b #1,36(a0)
        bset #0,M4_AR_GF2
        move.b #2,M4_SC_VIEWTYPE
M4VeV3End:
        moveq #0,d0
        rts
; 06:DE10 / 06:E0B5: sbyte3 + 1, outvx -> sin(sbyte3)/4 << 8 (Achase n = 3),
; outvy - 256, viewlb3move. a2 = viewtoobj.
M4VeSwing:
        addq.b #1,X_SBYTE3(a0)
        move.b X_SBYTE3(a0),d0
        move.l a2,-(sp)
        bsr M4VeSinWord
        movea.l (sp)+,a2
        move.w M4_LP_OUTVX,d0
        moveq #3,d2
        jsr M4LpAchase
        move.w d0,M4_LP_OUTVX
        subi.w #$100,M4_LP_OUTVY
; viewlb3move_srou 06:E297: pviewpos = viewtoobj position, z + 80.
M4VeLb3Move:
        move.w (a2),M4_LP_PVIEWX
        move.w 2(a2),M4_LP_PVIEWY
        move.w 4(a2),d0
        addi.w #80,d0
        move.w d0,M4_LP_PVIEWZ
        rts
; outvx, outvy -> 0 (Achase n = d2).
M4VeOutV0:
        move.w M4_LP_OUTVX,d0
        moveq #0,d1
        jsr M4LpAchase
        move.w d0,M4_LP_OUTVX
        move.w M4_LP_OUTVY,d0
        jsr M4LpAchase
        move.w d0,M4_LP_OUTVY
        rts
; levelfinished written by an object (06:DFB7): gamestart 02:E3FF reads it
; after the tick, as for the map's setvar (level.asm M4LvSetVar).
M4VeLevelFinished:
        tst.b M4_GM_RESULTS
        bne.s M4VeLfDone
        movem.l d0-d1,-(sp)
        jsr M4LvLevelFinished
        movem.l (sp)+,d0-d1
M4VeLfDone:
        rts

; ---------------------------------------------------------------------
; Entry into the base (Venom 1 planet, map 0D:D6C8..D6E0): the last_b
; pieces lastb2/lastb3/lastb4 07:8507/8530/85BD (re-read from the ROM;
; UltraStarFox names). inseq = $14DF bit3 (M4_BOSS_PSTRATF), gameflags2
; $14D3 (M4_AR_GF2), viewtoobj $15A0 (M4_VE_VTO, 0 = none: these test it).
; Invisible = $20 bit3: both port copies (49 bit1 and X2_FL4 bit3).
M4VeHide:
        bset #SF_INVISIBLE,49(a0)
        bset #3,X2_FL4(a0)
        rts
M4VeShow:
        bclr #SF_INVISIBLE,49(a0)
        bclr #3,X2_FL4(a0)
        rts

; lastb2 07:8507 (last_b_2): colldisable; visible only while inseq and
; gameflags2 bit0.
M4VeLastB2:
        bset #SF_COLLDISABLE,49(a0)
        btst #3,M4_BOSS_PSTRATF
        beq.s M4VeLb2Hide
        bsr M4VeShow
        btst #0,M4_AR_GF2
        bne.s M4VeLbKeep
M4VeLb2Hide:
        bsr M4VeHide
M4VeLbKeep:
        moveq #0,d0
        rts

; lastb3 07:8530 (last_b_3): colldisable; inseq, gameflags2 bit0, a
; viewtoobj and |y - viewtoobj.y| < 500 -> gameflags2 bit1 and the door
; opens (anim + 1 up to 10, modulo 11; sound $55 at 0, not modelled);
; otherwise closed (anim $80).
M4VeLastB3:
        bset #SF_COLLDISABLE,49(a0)
        btst #3,M4_BOSS_PSTRATF
        beq.s M4VeLbClose
        btst #0,M4_AR_GF2
        beq.s M4VeLbClose
        move.w M4_VE_VTO,d0
        beq.s M4VeLbClose
        movea.w d0,a2
        move.w #500,d1
        bsr M4VeYDist
        bpl.s M4VeLbClose
        bset #1,M4_AR_GF2
        moveq #10,d1
        moveq #11,d2
M4VeLbOpen: ;d1 = last frame, d2 = frames
        move.b 16(a0),d0
        andi.b #$7f,d0
        cmp.b d1,d0
        beq.s M4VeLbKeep
        move.b 16(a0),d0
        moveq #1,d1
        jsr M4WpAddAnim
        move.b d0,16(a0)
        bra.s M4VeLbKeep
M4VeLbClose:
        move.b #$80,16(a0)
        bra.s M4VeLbKeep

; lastb4 07:85BD (door_l): rotx $40, colldisable, invisible; inseq and
; gameflags2 bit1 -> visible; no viewtoobj -> unchanged; |dy| >= 700 ->
; closed; else stratdone1 (gameflags bit3) and, within 300, the door
; opens (anim + 1 up to 9, modulo 10; sound $55 at 0).
M4VeLastB4:
        move.b #$40,12(a0)
        bset #SF_COLLDISABLE,49(a0)
        bsr M4VeHide
        btst #3,M4_BOSS_PSTRATF
        beq M4VeLbClose
        btst #1,M4_AR_GF2
        beq M4VeLbClose
        bsr M4VeShow
        move.w M4_VE_VTO,d0
        beq M4VeLbKeep
        movea.w d0,a2
        move.w #700,d1
        bsr M4VeYDist
        bpl M4VeLbClose
        ori.b #$08,M4_LP_GAMEFLAGS
        move.w #300,d1
        bsr M4VeYDist
        bpl M4VeLbClose
        moveq #9,d1
        moveq #10,d2
        bra M4VeLbOpen

; ---------------------------------------------------------------------
; clshipDIVEa/b/c 06:C920/C9F3/CAC6 (end of the Venom 1/2 orbital stages,
; script 05:E16C/E121/E1B7): the friends' ships fly in formation while
; sword1 > 60 (06:CB6F: z = Achase16_4(z, player.z + dZ), y likewise with
; dY, rotz/rotx = Achase8_5 to 0/player.rotx), dive away while 30 <= sword1
; <= 60, jump above the player at sword1 == 1 (copy_pos 1F:DAED, y - 200)
; and at sword1 == 0 leave with rotz 0, rotx 4 (clshipboost_I 06:C115).
; Every tick before that (06:CBDD): sword1 - 1, addplayerZ, z += $1558.
; dZ/dY ($151F/$1521, scratch globals of these ships) stay in d5/d6.
M4VeDiveA: ;06:C920
        bclr #3,45(a0) ;no zremove
        move.w #120,40(a0)
        move.b #$c0,14(a0)
        move.l #M4VeDiveATick,32(a0)
M4VeDiveATick: ;06:C940
        moveq #-50,d1
        bsr M4VeDiveX
        moveq #100,d5
        moveq #-20,d6
        bsr M4VeDivePhase
        bgt M4VeDiveForm
        blt.s M4VeDaMove
        addq.b #2,14(a0)
        moveq #3,d0
        and.w M4_LV_GAMEFRAME,d0
        bne.s M4VeDaVy
        subq.w #1,6(a0)
M4VeDaVy:
        bsr M4VeDiveVy
M4VeDaMove:
        jsr M4EnMove
        cmpi.w #1,40(a0)
        bne M4VeDiveEnd
        bsr M4VeDiveCopy
        subi.w #50,(a0)
        bra M4VeDiveEnd

M4VeDiveB: ;06:C9F3
        bclr #3,45(a0)
        move.w #160,40(a0)
        move.b #$40,14(a0)
        move.l #M4VeDiveBTick,32(a0)
M4VeDiveBTick: ;06:CA13
        moveq #50,d1
        bsr M4VeDiveX
        move.w #200,d5
        moveq #-20,d6
        bsr M4VeDivePhase
        bgt M4VeDiveForm
        blt.s M4VeDbMove
        subq.b #2,14(a0)
        moveq #3,d0
        and.w M4_LV_GAMEFRAME,d0
        bne.s M4VeDbVy
        addq.w #1,6(a0)
M4VeDbVy:
        bsr.s M4VeDiveVy
M4VeDbMove:
        jsr M4EnMove
        cmpi.w #1,40(a0)
        bne M4VeDiveEnd
        bsr.s M4VeDiveCopy
        addi.w #50,(a0)
        bra M4VeDiveEnd

M4VeDiveC: ;06:CAC6
        bclr #3,45(a0)
        move.w #80,40(a0)
        move.b #20,37(a0) ;sbyte2: clshipboost removes it after 19 ticks
        move.l #M4VeDiveCTick,32(a0)
M4VeDiveCTick: ;06:CAE6
        moveq #0,d1
        bsr.s M4VeDiveX
        move.w #300,d5
        moveq #-30,d6
        bsr.s M4VeDivePhase
        bgt.s M4VeDiveForm
        blt.s M4VeDcMove
        bsr.s M4VeDiveVy
M4VeDcMove:
        jsr M4EnMove
        cmpi.w #1,40(a0)
        bne M4VeDiveEnd
        bsr.s M4VeDiveCopy
        bra M4VeDiveEnd

; x = Achase16_4(x, d1) (1F:D6F0).
M4VeDiveX:
        move.w (a0),d0
        moveq #4,d2
        jsr M4LpAchase
        move.w d0,(a0)
        rts
; Flags of the phase: GT formation (sword1 > 60), LT only move (sword1 <
; 30), EQ dive (30..60). Signed WORD compares as the ROM's bmi/bpl.
M4VeDivePhase:
        cmpi.w #60,40(a0)
        bgt.s M4VeDivePhaseDone
        cmpi.w #30,40(a0)
        blt.s M4VeDivePhaseDone
        cmp.w d0,d0 ;EQ
M4VeDivePhaseDone:
        rts
; Even gameframe: vy - 1.
M4VeDiveVy:
        btst #0,M4_LV_GAMEFRAME+1
        bne.s M4VeDiveVyDone
        subq.w #1,8(a0)
M4VeDiveVyDone:
        rts
; copy_pos from the player ($123A), y - 200.
M4VeDiveCopy:
        lea LV_PLAYER,a2
        move.l (a2),(a0)
        move.w 4(a2),4(a0)
        subi.w #200,2(a0)
        rts
; 06:CB6F: formation.
M4VeDiveForm:
        lea LV_PLAYER,a2
        move.w 4(a0),d0
        move.w 4(a2),d1
        add.w d5,d1
        moveq #4,d2
        jsr M4LpAchase
        move.w d0,4(a0)
        move.w 2(a0),d0
        move.w 2(a2),d1
        add.w d6,d1
        jsr M4LpAchase
        move.w d0,2(a0)
        move.b 14(a0),d0
        moveq #0,d1
        moveq #5,d2
        bsr M4VeAchase8
        move.b d0,14(a0)
        lea LV_PLAYER,a2
        move.b 12(a0),d0
        move.b 12(a2),d1
        moveq #5,d2
        bsr M4VeAchase8
        move.b d0,12(a0)
; 06:CBDD.
M4VeDiveEnd:
        tst.w 40(a0)
        bne.s M4VeDiveLive
; clshipDIVEboost_Istrat 06:CC00: rotz 0, rotx 4, clshipboost_I 06:C115.
M4VeDiveBoost:
        clr.b 14(a0)
        move.b #4,12(a0)
        jmp M4StratClshipBoost
M4VeDiveLive:
        subq.w #1,40(a0)
        jsr M4EnAddPZ
        move.w M4_WP_W1558,d0
        add.w d0,4(a0)
        moveq #0,d0
        rts

; ---------------------------------------------------------------------
; set_playerDIVE_l 0B:9E4A (cl_player_mode block 05:E0B6 of the Venom 1/2/3
; orbital scripts, kind $1D: M4LvClPlayerMode runs calcteamdamage and finds
; this Istrat in M4PlayerModesVenom). playerDIVE_Istrat 0B:9E5F: psvar_word2
; $1558 = 0, noctrl|nofire, novdistC ($14DF bit0), psvar_word1 $1556 = 286,
; playerflymode |= wobble ($10).
M4VePlayerDiveI:
        clr.w M4_WP_W1558
        move.l #M4VePlayerDive,32(a0)
        ori.b #$60,M4_LP_PSF
        ori.b #$01,M4_BOSS_PSTRATF
        move.w #286,M4_WP_W1556
        ori.b #$10,M4_LP_FLYMODE
; playerDIVE_strat 0B:9E98: centoutrots 0B:AB4F; $1556 0 -> DIVE2; $1556 - 1;
; 30 <= $1556 <= 60 -> bg2Yscroll + 1; y = Achase16_4(y, -40), x likewise
; to 0 (1F:D6F0); then playerinspace_strat 0B:B95C.
M4VePlayerDive:
        jsr M4WpViewAngles
        tst.w M4_WP_W1556
        beq.s M4VePdEnd
        subq.w #1,M4_WP_W1556
        cmpi.w #60,M4_WP_W1556
        bgt.s M4VePdChase
        cmpi.w #30,M4_WP_W1556
        blt.s M4VePdChase
        addq.w #1,M4_SC_BG2Y
M4VePdChase:
        move.w 2(a0),d0
        moveq #-40,d1
        moveq #4,d2
        jsr M4LpAchase
        move.w d0,2(a0)
        move.w (a0),d0
        moveq #0,d1
        jsr M4LpAchase
        move.w d0,(a0)
        jmp M4SpInSpaceStrat
; playerDIVE2_init 0B:9F05: dupplayer 0B:EA5E (the copy runs clshipDIVEboost
; 06:CC00), engine sound off ($14DA bit1); playerDIVE2_strat 0B:9F2C =
; playerinspace_strat.
M4VePdEnd:
        move.l #M4SpInSpaceStrat,32(a0)
        move.l M4_LV_LAST,-(sp) ;lastobj $16F9 is only the map's: kept
        clr.l M4_LV_LAST
        jsr M4CdDupPlayer
        move.l M4_LV_LAST,d0
        move.l (sp)+,M4_LV_LAST
        tst.l d0
        beq.s M4VePdNoDup ;no free slot
        movea.l d0,a2
        move.l #M4VeDiveBoost,32(a2)
M4VePdNoDup:
        andi.b #$fd,M4_LP_PSF3
        jmp M4SpInSpaceStrat

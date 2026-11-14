; Player flight in level play, selected ROM (USA rev0) translated to 68000.
; playeronplanet_strat 0B:BBE3, do_player_Yvel125 0B:E8AA, playermove_srou
; 0B:D33A..DF20, framescalevecs 0B:EA9A, playerlimitx 0B:DF21, playerfire
; 0B:DF6C, viewmove_srou 0B:D083. Source map: SF/STRAT/PSTRATS.ASM.
; Research: build/research/game-start-and-player.md (Parte 2).
; Achase(v,t,n): d=t-v; 0<|d|<2^n -> +-2^n; v += trunc(d/2^n) (adiv2).
; Object context: level object layout (level.asm), player = M4_LV_PLAYER.

; Player variables (original SNES address in comment).
M4_LP equ $fff000
M4_LP_PLROTX equ M4_LP+0 ;.w $1232
M4_LP_PLROTY equ M4_LP+2 ;.w $1234
M4_LP_PLROTZ equ M4_LP+4 ;.w $1236
M4_LP_OUTVX equ M4_LP+6 ;.w $18C7 view pitch offset
M4_LP_OUTVY equ M4_LP+8 ;.w $18C9 view yaw offset
M4_LP_ZSHAKE equ M4_LP+10 ;.w $1505
M4_LP_ZSHAKEV equ M4_LP+12 ;.w $1507
M4_LP_TURNROT equ M4_LP+14 ;.w $152C
M4_LP_PVIEWX equ M4_LP+16 ;.w $14F8
M4_LP_PVIEWY equ M4_LP+18 ;.w $14FA
M4_LP_PVIEWZ equ M4_LP+20 ;.w $14FC
M4_LP_PVIEWVZ equ M4_LP+22 ;.w $14F6
M4_LP_POSZ equ M4_LP+24 ;.w player_posz (init_strats_l, start of tick)
M4_LP_OUTDIST equ M4_LP+26 ;.w $18CD
M4_LP_VIEWDIST equ M4_LP+28 ;.w $159A
M4_LP_VIEWCY equ M4_LP+30 ;.w $158B
M4_LP_MINX equ M4_LP+32 ;.w $1571
M4_LP_MAXX equ M4_LP+34 ;.w $1573
M4_LP_MINY equ M4_LP+36 ;.w $1579
M4_LP_MAXY equ M4_LP+38 ;.w $157B
M4_LP_ZTILT equ M4_LP+40 ;.b $1509
M4_LP_ZSTRATADD equ M4_LP+41 ;.b $150A
M4_LP_ROLLZVEL equ M4_LP+42 ;.b $1503
M4_LP_ROLLDELAY equ M4_LP+43 ;.b $1502
M4_LP_ROLLZOFF equ M4_LP+44 ;.b $1504
M4_LP_KEYFLAGS equ M4_LP+45 ;.b $14E2 bit0 LRkeydown, bit1 Lkeydown
M4_LP_PMOVELIMIT equ M4_LP+46 ;.b $14E0
M4_LP_PMOVEAND equ M4_LP+47 ;.b $14E1
M4_LP_NOCTRLCNT equ M4_LP+48 ;.b $152B
M4_LP_TOSPEED equ M4_LP+49 ;.b $150D
M4_LP_MEDSPEED equ M4_LP+50 ;.b $150E
M4_LP_FLYMODE equ M4_LP+51 ;.b $14DC playerflymode
M4_LP_PSF equ M4_LP+52 ;.b $14D8 pshipflags
M4_LP_PSF2 equ M4_LP+53 ;.b $14D9 pshipflags2
M4_LP_PSF3 equ M4_LP+54 ;.b $14DA pshipflags3
M4_LP_GAMEFLAGS equ M4_LP+55 ;.b $14D2
M4_LP_BOOSTMETER equ M4_LP+56 ;.b $70:01BC m_boostanim
M4_LP_BOOSTCNT equ M4_LP+57 ;.b $70:01BA
M4_LP_FIREDELAY equ M4_LP+58 ;.b $1527
M4_LP_FIRECNT equ M4_LP+59 ;.b $1526
M4_LP_NUMLASERS equ M4_LP+60 ;.b $1525
M4_LP_SPECDELAY equ M4_LP+61 ;.b $1528
M4_LP_WOBBLEPTR equ M4_LP+62 ;.b player_Zrotfloatptr
M4_LP_ARROWS equ M4_LP+63 ;.b $1FC9
M4_LP_FRAMERATE equ M4_LP+64 ;.w $14E5 VBlanks of the previous tick
M4_LP_JOY equ M4_LP+66 ;.w SNES layout B Y Sel St U D L R A X L R 0000
M4_LP_LASTJOY equ M4_LP+68 ;.w previous tick ($15A6/$15A7)
M4_LP_SPECWEP equ M4_LP+70 ;.w $15AF Nova bombs
M4_LP_HUDROT equ M4_LP+72 ;.b $14C5
M4_LP_FIREREQ equ M4_LP+73 ;.b lasers requested this tick (factory consumer)
M4_LP_VIEWSHAKE equ M4_LP+74 ;.b x3 $1597..$1599
M4_LP_SIXBUTTON equ M4_LP+77 ;.b $FF when a six-button pad answered
; pBody/pLWing/pRWing objects (0B:ADE6/B022/B2C8) kept as player state.
M4_LP_BODYHP equ M4_LP+78 ;.b shield, 40
M4_LP_BODYCC equ M4_LP+79 ;.b collcount
M4_LP_LWHP equ M4_LP+80
M4_LP_LWCC equ M4_LP+81
M4_LP_RWHP equ M4_LP+82
M4_LP_RWCC equ M4_LP+83
M4_LP_PARTCOLL equ M4_LP+84 ;.b bit0 body, bit1 left wing, bit2 right wing collide
M4_LP_LIVES equ M4_LP+85 ;.b $16EE, 3
M4_LP_DEADCNT equ M4_LP+86 ;.b playerdead sbyte1
M4_LP_FLASHCNT equ M4_LP+87 ;.b $1529 screenflashcnt
M4_LP_FLASHTYPE equ M4_LP+88 ;.b $152A
M4_LP_BOMBREQ equ M4_LP+89 ;.b nova bomb requested this tick (factory consumer)
M4_LP_SPECFLASH equ M4_LP+90 ;.b $1FCA specflash (HUD blink of the last bomb)
M4_LP_BOOSTOBJ equ M4_LP+92 ;.w $158D boostobj: object the boost flames follow (low WORD)
M4_LP_FADETIMER equ M4_LP+91 ;.b $155E timeuntilfade
M4_LP_SIZE equ 96

; SNES joypad bits as stored in M4_LP_JOY (cont0 high byte, contl0 low).
J_B equ 15
J_Y equ 14
J_SELECT equ 13
J_START equ 12
J_UP equ 11
J_DOWN equ 10
J_LEFT equ 9
J_RIGHT equ 8
J_A equ 7
J_X equ 6
J_L equ 5
J_R equ 4

; Original constants.
LP_MINPSPEED equ 20
LP_MAXPSPEED equ 85
LP_MEDPSPEED equ 65
LP_XROTSPEED equ $200
LP_ZROTSPEED equ $200
PML_BBOTTOM equ $80
PML_LRWTOP equ $14
PML_LRWBOTTOM equ $28
PSF_NOCTRL equ $20
PSF_NOYCTRL equ $80
PSF_NOFIRE equ $40
PSF2_BOOSTING equ $20
PSF2_BRAKING equ $40
PSF2_DOUBLASER equ $01
PFM_WOBBLE equ $10

; d0 = value, d1 = target, d2 = n (1..4). WORD Achase, returns d0.
M4LpAchase:
        movem.l d3-d4,-(sp)
        move.w d1,d3
        sub.w d0,d3
        beq.s M4LpAchaseDone
        moveq #1,d4
        lsl.w d2,d4
        tst.w d3
        bmi.s M4LpAchaseNeg
        cmp.w d4,d3
        bge.s M4LpAchaseDiv
        move.w d4,d3
        bra.s M4LpAchaseDiv
M4LpAchaseNeg:
        neg.w d4
        cmp.w d4,d3
        blt.s M4LpAchaseDiv
        move.w d4,d3
M4LpAchaseDiv:
        ext.l d3
        tst.l d3
        bpl.s M4LpAchasePos
        moveq #1,d4
        lsl.w d2,d4
        subq.w #1,d4
        add.l d4,d3 ;round toward zero
M4LpAchasePos:
        asr.l d2,d3
        add.w d3,d0
M4LpAchaseDone:
        movem.l (sp)+,d3-d4
        rts

; BYTE Achase (1F:D8BD n=3, 1F:D8F7 n=4, 1F:D938 n=5 and the inline 8-bit
; copies): d = (t - v) mod 256 as a signed byte (8-bit wrap); 0 -> unchanged;
; 0 < d < 2^n -> 2^n; -2^n <= d < 0 -> -2^n; n halvings toward zero; v += d
; (8 bits). d0.b = v, d1.b = t, d2 = n -> d0 = result sign-extended to a
; WORD; d1/d2 preserved.
M4LpAchase8:
        movem.l d3-d4,-(sp)
        move.b d1,d3
        sub.b d0,d3
        beq.s M4LpAch8Done
        moveq #1,d4
        lsl.b d2,d4
        tst.b d3
        bmi.s M4LpAch8Neg
        cmp.b d4,d3
        bge.s M4LpAch8Div
        move.b d4,d3
        bra.s M4LpAch8Div
M4LpAch8Neg:
        neg.b d4
        cmp.b d4,d3
        blt.s M4LpAch8Div
        move.b d4,d3
M4LpAch8Div:
        ext.w d3
        bpl.s M4LpAch8Pos
        moveq #1,d4
        lsl.w d2,d4
        subq.w #1,d4
        add.w d4,d3 ;toward zero
M4LpAch8Pos:
        asr.w d2,d3
        add.b d3,d0
M4LpAch8Done:
        ext.w d0
        movem.l (sp)+,d3-d4
        rts

; Signed WORD /2 toward zero (adiv2).
M4LpDiv2:
        tst.w d0
        bpl.s M4LpDiv2Pos
        addq.w #1,d0
M4LpDiv2Pos:
        asr.w #1,d0
        rts

; playermove_init 0B:D1FD with planet defaults for the restart entry.
; Carry inventory flags forward, applying playermove_init's mode masks.
M4LevelPlayerInit:
        move.w M4_LP_SPECWEP,-(sp)
        move.w M4_LP_PSF,-(sp)
        move.b M4_LP_PSF3,-(sp)
        lea M4_LP,a1
        moveq #M4_LP_SIZE/4-1,d0
M4LpClear:
        clr.l (a1)+
        dbra d0,M4LpClear
        move.b (sp)+,M4_LP_PSF3
        move.w (sp)+,M4_LP_PSF
        move.w (sp)+,M4_LP_SPECWEP
        move.w #120,M4_LP_VIEWDIST
        move.w #120,M4_LP_OUTDIST
        move.w #LP_MEDPSPEED,M4_LP_PVIEWVZ
        move.b #LP_MEDPSPEED,M4_LP_TOSPEED
        move.b #LP_MEDPSPEED,M4_LP_MEDSPEED
        move.b #1,M4_LP_SPECDELAY
        clr.b M4_TN_PNUMHITS ;playermove_init 0B:D294
        move.b #40,M4_LP_BOOSTMETER
        move.b #3,M4_LP_FIRECNT
        move.b #1,M4_LP_FIREDELAY
        ; playeronplanet_Istrat: planet limits and fly mode.
        move.w #-50,M4_LP_VIEWCY
        move.w #-500,M4_LP_MINX
        move.w #500,M4_LP_MAXX
        move.w #-500,M4_PM_1575 ;0B:BB03: $1575/$1577/$1581, wing roof/floor
        move.w #500,M4_PM_1577
        clr.w M4_PM_1581
        move.w #-255,M4_PM_157D
        move.w #5,M4_PM_157F
        move.w #-255,M4_LP_MINY
        move.w #-20,M4_LP_MAXY
        move.b #$1b,M4_LP_FLYMODE
        move.b #$a8,M4_LP_PMOVEAND
        ori.b #$20,M4_LP_GAMEFLAGS ;viewrot
        andi.b #$f2,M4_LP_PSF3 ;0B:D2DE..D2E6: clear tunnel/forced brake/no collisions
        ori.b #2,M4_LP_PSF3 ;playermove_init enables the engine
        move.w #3,M4_LP_FRAMERATE
        move.b #40,M4_LP_BODYHP
        move.b #5,M4_LP_LWHP
        move.b #5,M4_LP_RWHP
        move.b #1,M4_LP_BODYCC
        move.b #1,M4_LP_LWCC
        move.b #1,M4_LP_RWCC
        jmp M4SpInit ;$14DD 0, $14DE 2, outvz 0 (level_cockpit.asm)

; playerstart_init_l 0B:D2EF. Called by initialise_l, continue YES,
; restart_l and gameoverinit_l, independently of per-stage playermove_init.
M4PlayerStartInit:
        move.w #3,M4_LP_SPECWEP
        clr.w M4_LP_PSF
        clr.b M4_LP_PSF3
        clr.b M4_TN_SHIELDUP
        clr.b M4_TN_CURRSHIP
        rts

; player_Istrat 0B:B53A..B54D, after playermove_init created the player.
M4PlayerEntryInit:
        jsr M4PmCredI
        bclr #SF_INVISIBLE,49(a0)
        bclr #SF_COLLDISABLE,49(a0)
        clr.b M4_PM_14C4 ;slowstars
        moveq #0,d0
        rts

; a0 = player object. One original tick of playeronplanet_strat.
M4LevelPlayerTick:
        movem.l d0-d7/a1,-(sp)
        jsr M4LpMove
        moveq #0,d0
        move.b 15(a0),d0
        jsr M4LevelGen3dVecs
        move.w 8(a0),d0 ;vy += asr2(vy)+asr3(vy) (asra: floor)
        move.w d0,d1
        asr.w #2,d1
        move.w d1,d2
        asr.w #1,d2
        add.w d1,d2
        add.w d2,d0
        move.w d0,8(a0)
        jsr M4LpFrameScale
        move.w 6(a0),d0
        add.w d0,(a0)
        move.w 8(a0),d0
        add.w d0,2(a0)
        move.w 10(a0),d0
        add.w d0,4(a0)
        ; playerlimitx
        andi.b #$f3,M4_LP_ARROWS
        move.w (a0),d0
        cmp.w M4_LP_MINX,d0
        bgt.s M4LpLimitXMax
        move.w M4_LP_MINX,(a0)
        ori.b #$04,M4_LP_ARROWS
M4LpLimitXMax:
        move.w (a0),d0
        cmp.w M4_LP_MAXX,d0
        blt.s M4LpLimitXDone
        move.w M4_LP_MAXX,(a0)
        ori.b #$08,M4_LP_ARROWS
M4LpLimitXDone:
        jsr M4LpFire
        jsr M4PmArrows ;0B:E9D0 (level_armada_player.asm)
        ; pviewposx = perc87(worldx): v>>1 + v>>2 + v>>3 (asr, floor)
        move.w (a0),d0
        move.w d0,d1
        asr.w #1,d1
        move.w d0,d2
        asr.w #2,d2
        add.w d2,d1
        asr.w #3,d0
        add.w d0,d1
        move.w d1,M4_LP_PVIEWX
        ; pviewposy = perc75(worldy - viewCY) + viewCY
        move.w 2(a0),d0
        sub.w M4_LP_VIEWCY,d0
        move.w d0,d1
        asr.w #1,d1
        asr.w #2,d0
        add.w d1,d0
        add.w M4_LP_VIEWCY,d0
        move.w d0,M4_LP_PVIEWY
        jsr M4LpViewMove
        movem.l (sp)+,d0-d7/a1
        rts

; 1F:C41E gen_3dvecs: d0 speed BYTE, rotx 12(a0), roty 13(a0) -> 6/8/10.
M4LevelGen3dVecs:
        cmpi.b #$80,d0 ;1F:C41E: a speed byte of -128 gives (0, 0, 0) (02:FC62 product)
        bne.s M4LvGen3dGo
        clr.w 6(a0)
        clr.l 8(a0)
        rts
M4LvGen3dGo:
        movem.l d1-d6/a1,-(sp)
        move.w d0,d6
        lea M4IntroShipSine,a1
        moveq #0,d0
        move.b 12(a0),d0
        move.b 64(a1,d0.w),d4
        ext.w d4
        move.b (a1,d0.w),d5
        ext.w d5
        moveq #0,d2
        move.b 13(a0),d2
        neg.b d2
        move.b (a1,d2.w),d1
        ext.w d1
        move.w d6,d0
        jsr M4IntroShipMul
        move.w d4,d1
        jsr M4IntroShipMul
        move.w d0,6(a0)
        move.b 64(a1,d2.w),d1
        ext.w d1
        move.w d6,d0
        jsr M4IntroShipMul
        move.w d4,d1
        jsr M4IntroShipMul
        move.w d0,10(a0)
        move.w d6,d0
        move.w d5,d1
        jsr M4IntroShipMul
        move.w d0,8(a0)
        movem.l (sp)+,d1-d6/a1
        rts

; framescalevecs 0B:EA9A: only the LOW BYTE of vx/vy, v = trunc(s8*f/4).
M4LpFrameScale:
        move.w M4_LP_FRAMERATE,d2
        moveq #6,d3
M4LpFrameScaleAxis:
        move.b 1(a0,d3.w),d0
        ext.w d0
        muls.w d2,d0
        tst.l d0
        bpl.s M4LpFrameScalePos
        addq.l #3,d0
M4LpFrameScalePos:
        asr.l #2,d0
        move.w d0,(a0,d3.w)
        addq.w #2,d3
        cmpi.w #10,d3
        bne.s M4LpFrameScaleAxis
        rts

; playermove_srou (wire ship, hit timer and wing collision branches need
; collision state: inactive until the collision unit sets their flags).
M4LpMove:
        ; wireship 0B:D33A ($14D9 bit1, item6 08:D5F0): pnumhits <= 2 -> timer
        ; $14F4 = 50; else timer 0 -> normal ship, shieldup 0, wire off, 50;
        ; else timer--, (timer & 3) == 0 -> normal ship / shieldup 0, otherwise
        ; wire ship / shieldup 1 (blink). select_ship_l = M4_TN_CURRSHIP.
        btst #1,M4_LP_PSF2
        beq.s M4LpWireDone
        move.b M4_TN_PNUMHITS,d0
        subq.b #2,d0
        beq.s M4LpWireTimer
        bmi.s M4LpWireTimer
        tst.b M4_TN_WIRECNT
        bne.s M4LpWireBlink
        clr.b M4_TN_SHIELDUP
        clr.b M4_TN_CURRSHIP
        bclr #1,M4_LP_PSF2
M4LpWireTimer:
        move.b #50,M4_TN_WIRECNT
        bra.s M4LpWireDone
M4LpWireBlink:
        subq.b #1,M4_TN_WIRECNT
        moveq #3,d0
        and.b M4_TN_WIRECNT,d0
        sne d0
        andi.b #1,d0
        move.b d0,M4_TN_SHIELDUP
        move.b d0,M4_TN_CURRSHIP
M4LpWireDone:
        ; hit timer al_sbyte1 ($22) -> view shake (collision unit sets it)
        tst.b 36(a0)
        beq.s M4LpNoHit
        subq.b #1,36(a0)
        lea M4_LP_VIEWSHAKE,a2
        moveq #2,d3
M4LpHitShake:
        jsr M4IntroRandom ;0B:D3A6, three independent random_l calls
        andi.b #15,d0
        subq.b #7,d0
        move.b d0,(a2)+
        dbra d3,M4LpHitShake
        btst #0,M4_LV_GAMEFRAME+1
        bne.s M4LpHitDone
        bset #SF_HITFLASH,49(a0)
        bset #2,31(a0) ;white material consumed by the graphical frontend
        bset #5,49(a0) ;nohitaffect
        bra.s M4LpHitDone
M4LpNoHit:
        bclr #5,49(a0)
        clr.w M4_LP_VIEWSHAKE
        clr.b M4_LP_VIEWSHAKE+2
M4LpHitDone:
        ; ground: s1 = maxY - vy; worldy >= s1 and != s1 -> Bbottom
        move.w M4_LP_MAXY,d0
        sub.w 8(a0),d0
        move.w 2(a0),d1
        cmp.w d0,d1
        blt.s M4LpNoGround
        beq.s M4LpNoGround
        ori.b #PML_BBOTTOM,M4_LP_PMOVELIMIT
M4LpNoGround:
        move.b M4_LP_PMOVEAND,d0
        and.b d0,M4_LP_PMOVELIMIT
        ; setcurrpshape: broken wings select playershapeL/R/LR (06:80D5 entry0)
        moveq #0,d0
        btst #3,M4_LP_PSF ;psf_brkLwing
        beq.s M4LpShapeNoL
        moveq #1,d0
M4LpShapeNoL:
        btst #4,M4_LP_PSF ;psf_brkRwing
        beq.s M4LpShapeSet
        addq.w #2,d0
M4LpShapeSet:
        move.b d0,M4_SPP_HUDFLAGS ;m_hudflags 0B:EB28 (cockpit HUD colours)
        tst.b M4_TN_CURRSHIP ;select_ship_l(1) 06:818D: wire ship shapes C360 C398 C37C C3B4
        beq.s M4LpShapeNormal
        move.w #$c360,d0 ;my_w (the broken-wing wire variants are not convertible: C360 for all)
        jsr M4LevelShapeIndex
M4LpShapeNormal:
        jsr M4LevelSetShape ;cockpit: nullplayer D2CC in the original (invisible here)
        btst #7,M4_LP_PMOVELIMIT
        beq.s M4LpFloorDone
        tst.w 8(a0)
        bmi.s M4LpFloorDone
        move.b 15(a0),d0
        cmp.b M4_LP_MEDSPEED,d0
        bhi.s M4LpFloorFast
        btst #J_DOWN,M4_LP_JOY
        bne.s M4LpFloorKeep
        clr.w M4_LP_PLROTX
M4LpFloorKeep:
        move.w M4_LP_MAXY,2(a0)
        bra.s M4LpFloorDone
M4LpFloorFast:
        move.w M4_LP_MAXY,2(a0)
        move.w M4_LP_PLROTX,d0
        neg.w d0
        asr.w #1,d0
        move.w d0,M4_LP_PLROTX
        ori.b #PML_LRWBOTTOM,M4_LP_PMOVELIMIT
        move.b #4,M4_LP_NOCTRLCNT
M4LpFloorDone:
        andi.b #$fc,M4_LP_ARROWS ;~(up|down) arrow bits 0/1
        btst #7,M4_LP_PMOVEAND
        bne.s M4LpBottomDone
        move.w 2(a0),d0
        cmp.w M4_LP_MAXY,d0
        blt.s M4LpBottomDone
        move.w M4_LP_MAXY,2(a0)
        ori.b #2,M4_LP_ARROWS
M4LpBottomDone:
        move.w 2(a0),d0
        cmp.w M4_LP_MINY,d0
        bgt.s M4LpTopDone
        move.w M4_LP_MINY,2(a0)
        ori.b #1,M4_LP_ARROWS
M4LpTopDone:
        ; view rotation offsets (gameflags viewrot)
        btst #5,M4_LP_GAMEFLAGS
        beq M4LpNoViewRot
        move.b M4_LP_PSF,d0
        andi.b #PSF_NOCTRL|PSF_NOYCTRL,d0
        bne.s M4LpZeroVRot
        btst #J_UP,M4_LP_JOY
        beq.s M4LpVxMax
        subi.w #256,M4_LP_OUTVX
M4LpVxMax:
        btst #J_DOWN,M4_LP_JOY
        beq.s M4LpVxMin
        addi.w #256,M4_LP_OUTVX
M4LpVxMin:
        move.w M4_LP_MINX,d1
        addi.w #300,d1
        move.w (a0),d0
        cmp.w d1,d0
        bgt.s M4LpVyMin
        btst #J_LEFT,M4_LP_JOY
        beq.s M4LpVyMin
        subi.w #200,M4_LP_OUTVY
M4LpVyMin:
        move.w M4_LP_MAXX,d1
        subi.w #300,d1
        cmp.w d1,d0
        blt.s M4LpZeroVRot
        btst #J_RIGHT,M4_LP_JOY
        beq.s M4LpZeroVRot
        addi.w #200,M4_LP_OUTVY
M4LpZeroVRot:
        move.w M4_LP_OUTVX,d0
        moveq #0,d1
        moveq #3,d2
        jsr M4LpAchase
        move.w d0,M4_LP_OUTVX
        move.w M4_LP_OUTVY,d0
        jsr M4LpAchase
        move.w d0,M4_LP_OUTVY
M4LpNoViewRot:
        ; wings against roof/floor
        move.b M4_LP_PMOVELIMIT,d0
        andi.b #PML_LRWTOP,d0
        beq.s M4LpNoWingTop
        addi.w #$300,M4_LP_PLROTX
M4LpNoWingTop:
        move.b M4_LP_PMOVELIMIT,d0
        andi.b #PML_LRWBOTTOM,d0
        beq.s M4LpNoWingBottom
        move.w M4_LP_PLROTX,d0
        neg.w d0
        subi.w #$a00,d0
        move.w d0,M4_LP_PLROTX
        move.b #4,M4_LP_NOCTRLCNT
M4LpNoWingBottom:
        ; boost/brake timer al_sbyte2 ($23)
        tst.b 37(a0)
        beq.s M4LpBoostTimerDone
        subq.b #1,37(a0)
        bne.s M4LpBoostTimerDone
        andi.b #~(PSF2_BOOSTING|PSF2_BRAKING),M4_LP_PSF2
M4LpBoostTimerDone:
        ; control gate: stayblack $FF and no wipe (doingwipe)
        cmpi.b #$ff,M4_SC_STAYBLACK
        bne M4LpNoCtrl
        tst.b M4_SC_WIPE
        bne M4LpNoCtrl
        btst #5,M4_LP_PSF
        bne M4LpNoCtrl
        tst.b M4_LP_NOCTRLCNT
        beq.s M4LpCtrl
        subq.b #1,M4_LP_NOCTRLCNT
        bra M4LpNoCtrl
M4LpCtrl:
        ; boost (X without B) / brake (B without X), meter full and sbyte2=0
        tst.b 37(a0)
        bne M4LpSpeedDone
        cmpi.b #40,M4_LP_BOOSTMETER
        blo M4LpSpeedDone
        move.w M4_LP_JOY,d0
        andi.w #(1<<J_X)|(1<<J_B),d0
        cmpi.w #1<<J_X,d0
        bne.s M4LpNotBoost
        ori.b #PSF2_BOOSTING,M4_LP_PSF2
        M4PlaySfx $32 ;0B:D922 speedup
        move.b #1,M4_LP_BOOSTCNT
        move.b #LP_MAXPSPEED,15(a0)
        move.b #LP_MAXPSPEED,M4_LP_TOSPEED
        move.b #20,37(a0)
        cmpi.b #3,M4_SPP_FM ;0B:D922: no flame in the cockpit
        beq.s M4LpSpeedDone
        jsr M4LevelBoostFlame ;0B:D937 (not with the brake)
        bra.s M4LpSpeedDone
M4LpNotBoost:
        cmpi.w #1<<J_B,d0
        bne.s M4LpSpeedDone
        ori.b #PSF2_BRAKING,M4_LP_PSF2
        M4PlaySfx $33 ;speeddown
        move.b #1,M4_LP_BOOSTCNT
        move.b #LP_MINPSPEED,M4_LP_TOSPEED
        move.b #30,37(a0)
M4LpSpeedDone:
        ; lateral drift: x += -( trunc(asr7(plrotz)/2) + tpa )
        moveq #0,d1
        move.w M4_LP_JOY,d0
        andi.w #(1<<J_LEFT)|(1<<J_RIGHT),d0
        beq.s M4LpDriftTpa
        move.b M4_LP_ZTILT,d1
        asr.b #3,d1
        ext.w d1
M4LpDriftTpa:
        move.w M4_LP_PLROTZ,d0
        asr.w #7,d0
        jsr M4LpDiv2
        add.w d1,d0
        neg.w d0
        add.w d0,(a0)
        ; left/right steering; svar = maxY - 30
        move.w M4_LP_MAXY,d3
        subi.w #30,d3
        btst #0,M4_LP_PMOVELIMIT ;0B:DA44: left wall touched by the wing
        bne.s M4LpNotLeft
        btst #J_LEFT,M4_LP_JOY
        beq.s M4LpNotLeft
        btst #7,M4_LP_PMOVEAND
        beq.s M4LpLeftTilt
        cmp.w 2(a0),d3
        blt.s M4LpLeftNoTilt ;worldy lower (greater) than maxY-30
M4LpLeftTilt:
        addq.b #2,M4_LP_ZTILT
M4LpLeftNoTilt:
        addi.w #LP_ZROTSPEED,M4_LP_PLROTZ
        addi.w #LP_ZROTSPEED,M4_LP_PLROTY
M4LpNotLeft:
        btst #1,M4_LP_PMOVELIMIT ;0B:DA95: right wall
        bne.s M4LpNotRight
        btst #J_RIGHT,M4_LP_JOY
        beq.s M4LpNotRight
        btst #7,M4_LP_PMOVEAND
        beq.s M4LpRightTilt
        cmp.w 2(a0),d3
        blt.s M4LpRightNoTilt
M4LpRightTilt:
        subq.b #2,M4_LP_ZTILT
M4LpRightNoTilt:
        subi.w #LP_ZROTSPEED,M4_LP_PLROTZ
        subi.w #LP_ZROTSPEED,M4_LP_PLROTY
M4LpNotRight:
        btst #7,M4_LP_PSF
        bne.s M4LpNoYCtrl
        btst #J_UP,M4_LP_JOY
        beq.s M4LpNotUp
        addi.w #LP_XROTSPEED,M4_LP_PLROTX
M4LpNotUp:
        btst #J_DOWN,M4_LP_JOY
        beq.s M4LpNoYCtrl
        subi.w #LP_XROTSPEED,M4_LP_PLROTX
M4LpNoYCtrl:
        ; barrel roll (L/R new press within the roll delay)
        tst.b M4_LP_ROLLZVEL
        bne.s M4LpRollDone
        tst.b M4_LP_ROLLDELAY
        beq.s M4LpRollAgain
        subq.b #1,M4_LP_ROLLDELAY
        move.w M4_LP_JOY,d0
        andi.w #(1<<J_L)|(1<<J_R),d0
        beq.s M4LpRollDone
        move.w M4_LP_LASTJOY,d0
        andi.w #(1<<J_L)|(1<<J_R),d0
        bne.s M4LpRollDone
        move.b #-32,M4_LP_ROLLZVEL
        clr.b M4_LP_ROLLZOFF
        btst #J_L,M4_LP_JOY+1
        beq.s M4LpRollAgain
        move.b #32,M4_LP_ROLLZVEL
M4LpRollAgain:
        move.w M4_LP_JOY,d0
        andi.w #(1<<J_L)|(1<<J_R),d0
        beq.s M4LpRollDone
        move.b #3,M4_LP_ROLLDELAY ;barrelrolldelay
M4LpRollDone:
        ; keyflags: last pressed of L/R wins
        bclr #0,M4_LP_KEYFLAGS
        btst #J_L,M4_LP_JOY+1
        beq.s M4LpKeyNoL
        bset #0,M4_LP_KEYFLAGS
        btst #J_L,M4_LP_LASTJOY+1
        bne.s M4LpKeyR
        bset #1,M4_LP_KEYFLAGS
        bra.s M4LpKeyR
M4LpKeyNoL:
        btst #J_R,M4_LP_JOY+1
        beq.s M4LpKeyR
        bclr #1,M4_LP_KEYFLAGS
M4LpKeyR:
        btst #J_R,M4_LP_JOY+1
        beq.s M4LpKeyNoR
        bset #0,M4_LP_KEYFLAGS
        btst #J_R,M4_LP_LASTJOY+1
        bne.s M4LpKeyDone
        bclr #1,M4_LP_KEYFLAGS
        bra.s M4LpKeyDone
M4LpKeyNoR:
        btst #J_L,M4_LP_JOY+1
        beq.s M4LpKeyDone
        bset #1,M4_LP_KEYFLAGS
M4LpKeyDone:
        btst #0,M4_LP_KEYFLAGS
        beq.s M4LpNoCtrl
        btst #1,M4_LP_KEYFLAGS
        beq.s M4LpTiltRight
        move.b M4_LP_ZTILT,d0
        addi.b #10,d0
        bvs.s M4LpTiltLeftMax
        cmpi.b #64,d0
        blt.s M4LpTiltStore
M4LpTiltLeftMax:
        moveq #64,d0
        bra.s M4LpTiltStore
M4LpTiltRight:
        btst #J_R,M4_LP_JOY+1
        beq.s M4LpNoCtrl
        move.b M4_LP_ZTILT,d0
        subi.b #10,d0
        bvs.s M4LpTiltRightMax
        cmpi.b #-64,d0
        bge.s M4LpTiltStore
M4LpTiltRightMax:
        moveq #-64,d0
M4LpTiltStore:
        move.b d0,M4_LP_ZTILT
        bra.s M4LpTiltChased
M4LpNoCtrl:
        move.b M4_LP_ZTILT,d0
        moveq #0,d1
        moveq #3,d2
        jsr M4LpAchase8
        move.b d0,M4_LP_ZTILT
M4LpTiltChased:
        move.w M4_LP_PLROTY,d0
        moveq #0,d1
        moveq #3,d2
        jsr M4LpAchase
        move.w d0,M4_LP_PLROTY
        bclr #SF_COLLDISABLE,49(a0) ;0B:DCDA..DCDE
        move.w M4_LP_PLROTZ,d0
        moveq #4,d2
        jsr M4LpAchase
        move.w d0,M4_LP_PLROTZ
        move.w M4_LP_PLROTX,d0
        moveq #3,d2
        jsr M4LpAchase
        move.w d0,M4_LP_PLROTX
        clr.b M4_LP_PMOVELIMIT
        ; limits and composition
        move.b 15(a0),d0
        cmpi.b #LP_MINPSPEED,d0
        bhs.s M4LpVelMin
        moveq #LP_MINPSPEED,d0
M4LpVelMin:
        cmpi.b #LP_MAXPSPEED,d0
        bls.s M4LpVelMax
        moveq #LP_MAXPSPEED,d0
M4LpVelMax:
        move.b d0,15(a0)
        move.w M4_LP_PLROTZ,d0
        cmpi.w #-$600,d0
        bge.s M4LpRotzMin
        move.w #-$600,d0
M4LpRotzMin:
        cmpi.w #$600,d0
        ble.s M4LpRotzMax
        move.w #$600,d0
M4LpRotzMax:
        move.w d0,M4_LP_PLROTZ
        move.b M4_LP_PLROTX,12(a0)
        move.b M4_LP_PLROTY,d0
        add.b M4_LP_TURNROT,d0
        move.b d0,13(a0)
        move.b M4_LP_PLROTZ,d0
        add.b M4_LP_ZTILT,d0
        add.b M4_LP_ZSHAKE,d0
        add.b M4_LP_ZSTRATADD,d0
        move.b d0,14(a0)
        ; roll
        tst.b M4_LP_ROLLZVEL
        bne.s M4LpRolling
        move.b M4_LP_ROLLZOFF,d0
        moveq #0,d1
        moveq #3,d2
        jsr M4LpAchase8
        move.b d0,M4_LP_ROLLZOFF
        bra.s M4LpRollAdd
M4LpRolling:
        move.b M4_LP_ROLLZVEL,d0
        add.b d0,M4_LP_ROLLZOFF
        tst.b d0
        bpl.s M4LpRollSlowPos
        addq.b #2,M4_LP_ROLLZVEL
        bra.s M4LpRollAdd
M4LpRollSlowPos:
        subq.b #2,M4_LP_ROLLZVEL
M4LpRollAdd:
        move.b M4_LP_ROLLZOFF,d0
        add.b d0,14(a0)
        ; wobble 0B:EB8F (halved while both wings are intact)
        btst #4,M4_LP_FLYMODE
        beq.s M4LpNoWobble
        moveq #0,d1
        move.b M4_LP_WOBBLEPTR,d1
        lea M4LpWobbleTable,a1
        move.b (a1,d1.w),d0
        move.b M4_LP_PSF,d2
        andi.b #$18,d2 ;broken wing bits (psf_brkLwing|psf_brkRwing)
        bne.s M4LpWobbleFull
        tst.b d0 ;0B:DE90 halves towards 0
        bpl.s M4LpWobbleHalf
        addq.b #1,d0
M4LpWobbleHalf:
        asr.b #1,d0
M4LpWobbleFull:
        add.b d0,14(a0)
        addq.b #1,d1
        cmpi.b #28,d1
        bne.s M4LpWobblePtr
        moveq #0,d1
M4LpWobblePtr:
        move.b d1,M4_LP_WOBBLEPTR
M4LpNoWobble:
        ; zshake spring
        move.w M4_LP_ZSHAKE,d0
        move.w M4_LP_ZSHAKEV,d1
        sub.w d0,d1
        move.w d1,M4_LP_ZSHAKEV
        add.w d1,d0
        move.w d0,d1
        asr.w #2,d1
        sub.w d1,d0
        move.w d0,M4_LP_ZSHAKE
        move.b 14(a0),M4_LP_HUDROT
        cmpi.b #3,M4_SPP_FM ;0B:DEBB: outvz = sext(Ztilt) + zshake in the cockpit
        bne.s M4LpOutvzDone
        move.b M4_LP_ZTILT,d0
        ext.w d0
        add.w M4_LP_ZSHAKE,d0
        move.w d0,M4_LP_OUTVZ
M4LpOutvzDone:
        rts

; viewmove_srou 0B:D083 (exterior view). pstratflags bit0 novdistC (ClearDemo
; 0B:95A3) skips the arm chase toward viewdist.
M4LpViewMove:
        btst #0,M4_BOSS_PSTRATF
        bne.s M4LpViewNoArm
        move.w M4_LP_OUTDIST,d0
        move.w M4_LP_VIEWDIST,d1
        moveq #3,d2
        jsr M4LpAchase
        move.w d0,M4_LP_OUTDIST
M4LpViewNoArm:
        move.w M4_LP_PVIEWVZ,d0
        add.w d0,M4_LP_PVIEWZ
        ; Fchase pviewvelz -> al_vz by 1
        move.w 10(a0),d1
        cmp.w d0,d1
        beq.s M4LpVzDone
        bgt.s M4LpVzUp
        subq.w #1,M4_LP_PVIEWVZ
        bra.s M4LpVzDone
M4LpVzUp:
        addq.w #1,M4_LP_PVIEWVZ
M4LpVzDone:
        move.w M4_LP_PVIEWZ,d0
        sub.w M4_LP_POSZ,d0
        cmpi.w #-200,d0
        bge.s M4LpViewMin
        move.w #-200,d0
M4LpViewMin:
        cmpi.w #50,d0
        ble.s M4LpViewMax
        move.w #50,d0
M4LpViewMax:
        add.w M4_LP_POSZ,d0
        move.w d0,M4_LP_PVIEWZ
        cmpi.b #10,37(a0)
        bgt.s M4LpNormSpeed
        move.b M4_LP_MEDSPEED,M4_LP_TOSPEED
        move.w M4_LP_PVIEWZ,d0
        move.w M4_LP_POSZ,d1
        moveq #3,d2
        jsr M4LpAchase
        move.w d0,M4_LP_PVIEWZ
M4LpNormSpeed:
        ; speedto 1F:D60D: vel -> tospeed in steps of 2
        move.b 15(a0),d0
        move.b M4_LP_TOSPEED,d1
        cmp.b d1,d0
        beq.s M4LpSpeedToDone
        bhi.s M4LpSpeedDown
        addq.b #2,d0
        cmp.b d1,d0
        bls.s M4LpSpeedStore
        move.b d1,d0
        bra.s M4LpSpeedStore
M4LpSpeedDown:
        subq.b #2,d0
        cmp.b d1,d0
        bhs.s M4LpSpeedStore
        move.b d1,d0
M4LpSpeedStore:
        move.b d0,15(a0)
M4LpSpeedToDone:
        rts

; playerfire 0B:DF6C: Y = laser. firedelay/firecnt cadence; numplasers
; limit 4-1 (8-1 with double lasers). The factory consumer (level.asm)
; creates M4_LP_FIREREQ ELASER objects (id4, 06:A7E3) this tick.
M4LpFire:
        clr.b M4_LP_FIREREQ
        clr.b M4_LP_BOMBREQ
        move.b M4_LP_PSF,d0
        andi.b #$18,d0 ;broken wings
        beq.s M4LpFireWings
        andi.b #~PSF2_DOUBLASER,M4_LP_PSF2
        andi.b #$ef,M4_LP_PSF3 ;0B:DF7F: a broken wing also removes beamball
M4LpFireWings:
        btst #6,M4_LP_PSF
        bne.w M4LpFireReturn
        cmpi.b #$ff,M4_SC_STAYBLACK
        bne.w M4LpFireReturn
        tst.b M4_SC_WIPE ;doingwipe $1FD3 blocks lasers and bombs
        bne.w M4LpFireReturn
        ; nova bomb 0B:E010..E086 (before the laser block): A edge, at most
        ; every 50 ticks (also with no bombs left)
        subq.b #1,M4_LP_SPECDELAY
        bne.s M4LpBombDone
        move.b #1,M4_LP_SPECDELAY
        btst #J_A,M4_LP_JOY+1
        beq.s M4LpBombDone
        btst #J_A,M4_LP_LASTJOY+1
        bne.s M4LpBombDone
        move.b #50,M4_LP_SPECDELAY
        tst.w M4_LP_SPECWEP
        beq.s M4LpBombDone
        subq.w #1,M4_LP_SPECWEP
        st M4_LP_BOMBREQ ;fire_weapon($2A) in M4LevelFireBomb
M4LpBombDone:
        btst #J_Y,M4_LP_JOY
        beq.s M4LpFireReset
        subq.b #1,M4_LP_FIREDELAY
        bne.s M4LpFireReturn
        move.b #2,M4_LP_FIREDELAY ;player_firespeed
        tst.b M4_LP_FIRECNT
        beq.s M4LpFireReturn
        subq.b #1,M4_LP_FIRECNT
        moveq #4-1,d1
        btst #0,M4_LP_PSF2
        beq.s M4LpFireLimit
        moveq #8-1,d1
M4LpFireLimit:
        cmp.b M4_LP_NUMLASERS,d1
        blo.s M4LpFireReturn
        move.b #1,M4_LP_FIREREQ
        btst #0,M4_LP_PSF2
        beq.s M4LpFireReturn
        move.b #2,M4_LP_FIREREQ
        rts
M4LpFireReset:
        move.b #3,M4_LP_FIRECNT
        move.b #1,M4_LP_FIREDELAY
M4LpFireReturn:
        rts

; pZrotfloattab 0B:EB8F, 28 entries.
M4LpWobbleTable:
        incbin '../build/M4LpWobbleTable.bin'
        even

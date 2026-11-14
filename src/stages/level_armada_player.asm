; Player modes (bank-0B player strategies) of Space Armada and of the other
; stages that reuse them. ROM USA rev0 (SHA-256 3857b529...a84d); specification
; build/agent-armada/research/player/SPEC.md, build/agent-player-modes/
; PLAYER-MODES.md; oracle build/agent-player-modes/pm-compare.py (ROM 65816 vs
; this 68000 code, tick by tick).
; Owner files: this file, level_armada_player_strats.asm, tools/stages/
; player_modes.py. RAM: $FF9DC0..$FF9DFF (top of the Space Armada block).
; Units: WarpOut 0B:8960/8975/8AAC/8AF6 + generator 0B:8B38/8B52/8BAE;
; tunnels 0B:C03A/C10C/C1C9/C1DE + C297 + body 0B:BF79/E913/E9D0; tunnel
; exits 0B:C398/C46E/C52E/C544; wing boxes 0B:B039/B2DA (pmovelimit bits
; 0..5 and $158F) and the push 0B:D6C2..D74B; washent 0B:AA79/AAA0 + copy
; 06:E593..E815; innucleus 0B:C699/C782; EscapeNucleus 0B:9437/944C..9557;
; ClearShip2 0B:9ACC/9AE1/9BFA; InSpace 0B:B86D.
; Not ported: sounds/music (03:B7E5, $1F48/$1F49), the wing boxes' hit flash
; (+1D |= $80 of $1565/$1567: no wing objects in the port), 06:8C31 (wing on
; the ground, needs $14DC bit2: none of these modes), the white fade step
; 02:FEE4 of 8AAC (the port steps M4MvWhiteTick every tick, level.asm).
M4_PM equ $ff9dc0
M4_PM_1575 equ M4_PM+0 ;.w enemy shot X min (06:903D; no port consumer)
M4_PM_1577 equ M4_PM+2 ;.w enemy shot X max (06:9025; no port consumer)
M4_PM_1581 equ M4_PM+4 ;.w enemy shot limit (06:90A3; no port consumer)
M4_PM_157D equ M4_PM+6 ;.w wing roof (0B:B0D4/B373)
M4_PM_157F equ M4_PM+8 ;.w wing floor (0B:B0ED/B38C)
M4_PM_158F equ M4_PM+10 ;.w wing push distance (0B:B0C3/B362 -> D714/D739)
M4_PM_1593 equ M4_PM+12 ;.w innucleus camera x offset (no ROM writer found: 0)
M4_PM_1595 equ M4_PM+14 ;.w innucleus camera y offset (no ROM writer found: 0)
M4_PM_DOZROT equ M4_PM+16 ;.b $16F3 dozrot (06:E7EE; no port consumer)
M4_PM_1583 equ M4_PM+18 ;.w (onbridge/water Istrats; no port consumer)
M4_PM_1585 equ M4_PM+20 ;.w (onbridge; no port consumer)
M4_PM_1587 equ M4_PM+22 ;.w (water Istrats; no port consumer)
M4_PM_14FE equ M4_PM+24 ;.w (IntoLB1 camera 07:8501; no port consumer)
M4_PM_156B equ M4_PM+26 ;.b x2 $156B/$156C (IntoLB1 hand-over 07:8383; no port consumer)
M4_PM_14C4 equ M4_PM+28 ;.b (playercred_Istrat; no port consumer)
M4_PM_14CF equ M4_PM+30 ;.w (playercred +16 per tick; no port consumer)
M4_PM_END equ M4_PM+64

; Player modes of this unit (original pstrat 24-bit address.l, port Istrat.l;
; 0 ends), searched by M4LevelFindPlayerMode (level_warp.asm): pure
; "ldx $123A; stratptr = Istrat; rtl" routines (cl_player_mode $1D and,
; through M4PmPlayerMode, player_mode).
M4PlayerModesArmada:
        dc.l $0b8960,M4PmWarpOutI ;WarpOut -> 0B:8975
        dc.l $0b9437,M4PmEscapeI ;EscapeNucleus -> 0B:944C
        dc.l $0b9acc,M4PmClearShip2I ;ClearShip2 -> 0B:9AE1
        dc.l $0bb86d,M4SpInSpaceI ;InSpace -> 0B:B882 (level_cockpit.asm)
        dc.l $0bc1c9,M4PmLTunnelI ;InLtunnel -> 0B:C1DE
        dc.l $0bbd27,M4PmOnWaterI ;OnWater -> 0B:BD3C
        dc.l $0b924f,M4PmIntoLB1I ;IntoLB1 -> 0B:9264
        dc.l $0ba11e,M4PmClearUnderI ;ClearUnder -> 0B:A133 (Macbeth, cl_under 05:DF34)
        dc.l 0
; Routines that do their work in the map phase (player_mode, jsl from the
; block): address.l, routine.l (a0 = player).
M4PmMapCalls:
        dc.l $0bc398,M4PmMTexit ;InS/MTexit
        dc.l $0bc46e,M4PmLTexit ;InLTexit
        dc.l 0

; player_mode (map kind $78 blocks: phb; DB = $7E; jsl routine; $1788 =
; routine; plb). a2 = block record, 8(a2).l = routine. d0.w = 0 handled, -1
; not ported. d1-d7/a0-a6 preserved. Order: this unit's map routines, the
; install tables (M4LevelFindPlayerMode), the Venom unit (M4VePlayerMode:
; toCslow 0B:AAAD, OutOfLB2a 0B:A642). $1788 = routine is not reproduced
; (always overwritten by the next background routine in the stages seen).
M4PmPlayerMode:
        movem.l d1-d7/a0-a6,-(sp)
        lea LV_PLAYER,a0
        move.l 8(a2),d0
        lea M4PmMapCalls,a3
M4PmPmFind:
        move.l (a3)+,d1
        beq.s M4PmPmInstall
        movea.l (a3)+,a4
        cmp.l d1,d0
        bne.s M4PmPmFind
        jsr (a4)
        bra.s M4PmPmDone
M4PmPmInstall:
        jsr M4LevelFindPlayerMode
        move.l a3,d1
        beq.s M4PmPmVenom
        move.l a3,32(a0)
M4PmPmDone:
        movem.l (sp)+,d1-d7/a0-a6
        moveq #0,d0
        rts
M4PmPmVenom:
        movem.l (sp)+,d1-d7/a0-a6
        jmp M4VePlayerMode ;level_venom_escape.asm (d0 = 0 / -1)

; ---------------------------------------------------------------------
; Helpers. a0 = player.

; Limits block: a2 = viewCY, $1571, $1573, $1575, $1577, $1581, $157D,
; $157F, $1579, $157B (WORDs), then flymode $14DC, pmovelimitAND $14E1,
; pmovelimits $14D7 (BYTEs).
M4PmLimits:
        move.w (a2)+,M4_LP_VIEWCY
        move.w (a2)+,M4_LP_MINX
        move.w (a2)+,M4_LP_MAXX
        move.w (a2)+,M4_PM_1575
        move.w (a2)+,M4_PM_1577
        move.w (a2)+,M4_PM_1581
        move.w (a2)+,M4_PM_157D
        move.w (a2)+,M4_PM_157F
        move.w (a2)+,M4_LP_MINY
        move.w (a2)+,M4_LP_MAXY
        move.b (a2)+,M4_LP_FLYMODE
        move.b (a2)+,M4_LP_PMOVEAND
        move.b (a2)+,M4_SPP_LIMITS
        rts

; Achase8_n with the ROM's 8-bit wrap (1F:D8BD/D8F7 and the inline copies):
; d = (t - v) mod 256 signed; 0 -> unchanged; 0 < d < 2^n -> 2^n; -2^n <=
; d < 0 -> -2^n; n halvings toward zero; v += d (8 bits). d0.b = v, d1.b =
; t, d2 = n -> d0.b.
M4PmAch8:
        jmp M4LpAchase8 ;level_player.asm (same 8-bit rule)

; gen_3dvecs 1F:D5A7 with vel/rotx/roty of a0, then 1F:C7BB pos += v.
M4PmGenMove:
        moveq #0,d0
        move.b 15(a0),d0
        jsr M4LevelGen3dVecs
M4PmMove:
        move.w 6(a0),d0
        add.w d0,(a0)
        move.w 8(a0),d0
        add.w d0,2(a0)
        move.w 10(a0),d0
        add.w d0,4(a0)
        rts

; The laser/bomb factories of this tick (as M4SpFactNormal: no cockpit here).
M4PmFactories:
        clr.b M4_SPP_FIREON
        jmp M4SpFactories ;level_cockpit.asm: returns d0 = 0

; Wing boxes pLWing 0B:B039 / pRWing 0B:B2DA, called by level.asm after the
; whole allst pass (the boxes are the allst tail; read by the next tick's
; playermove). Their expstrats 0B:B263/B502 (wing destroyed: HP back to $FF,
; brkL/RWing, debris) end in jml 1F:DC25 to the same box strategy, so a
; broken wing keeps measuring the walls: no special case. box = player + rotate_8((-+33,
; 13, 0), rotz) (1F:CC78); left: x - $1571 zero or N -> $158F = $1571 - x,
; bit0; y - $157D zero or N -> bit2; y - $157F not N -> bit3. Right: x -
; $1573 not N -> $158F = $1573 - x, bit1; bits 4/5 likewise.
M4PmWings:
        movem.l d0-d5,-(sp)
        moveq #-33,d3
        moveq #1,d5 ;left: bits 0/2/3
        bsr.s M4PmWing
        moveq #33,d3
        moveq #2,d5 ;right: bits 1/4/5
        bsr.s M4PmWing
        movem.l (sp)+,d0-d5
        rts
M4PmWing:
        move.w d5,-(sp)
        moveq #13,d4
        move.b 14(a0),d5
        jsr M4WeaponRotatePair
        move.w (sp)+,d5
        ext.w d3
        ext.w d4
        add.w (a0),d3 ;box x
        add.w 2(a0),d4 ;box y
        cmpi.b #1,d5
        bne.s M4PmWingRight
        move.w d3,d0
        sub.w M4_LP_MINX,d0
        beq.s M4PmWingLHit
        bpl.s M4PmWingY
M4PmWingLHit:
        move.w M4_LP_MINX,d0
        sub.w d3,d0
        move.w d0,M4_PM_158F
        ori.b #1,M4_LP_PMOVELIMIT
        bra.s M4PmWingY
M4PmWingRight:
        move.w d3,d0
        sub.w M4_LP_MAXX,d0
        bmi.s M4PmWingY
        move.w M4_LP_MAXX,d0
        sub.w d3,d0
        move.w d0,M4_PM_158F
        ori.b #2,M4_LP_PMOVELIMIT
M4PmWingY:
        lsl.b #2,d5 ;roof bit: 4 (left) / 8 -> $10 (right)
        cmpi.b #8,d5
        bne.s M4PmWingRoof
        moveq #$10,d5
M4PmWingRoof:
        move.w d4,d0
        sub.w M4_PM_157D,d0
        beq.s M4PmWingRoofHit
        bpl.s M4PmWingFloor
M4PmWingRoofHit:
        or.b d5,M4_LP_PMOVELIMIT
M4PmWingFloor:
        add.b d5,d5 ;floor bit: 8 / $20
        move.w d4,d0
        sub.w M4_PM_157F,d0
        bmi.s M4PmWingDone
        or.b d5,M4_LP_PMOVELIMIT
M4PmWingDone:
        rts

; 0B:E9D0 arrows $1FC9: inseq -> 0; otherwise the bit survives
; only with its pad bit set and its $14E1 mask clear.
M4PmArrows:
        btst #3,M4_BOSS_PSTRATF
        beq.s M4PmArGo
        clr.b M4_LP_ARROWS
        rts
M4PmArGo:
        movem.l d0-d3/a2,-(sp)
        lea M4PmArTab,a2
        moveq #3,d3
M4PmArNext:
        move.b (a2)+,d0 ;pad bit (M4_LP_JOY high byte = $1202)
        move.b (a2)+,d1 ;$14E1 mask
        move.b (a2)+,d2 ;arrow bit to clear
        addq.l #1,a2
        btst d0,M4_LP_JOY
        beq.s M4PmArClear
        and.b M4_LP_PMOVEAND,d1
        beq.s M4PmArKeep
M4PmArClear:
        not.b d2
        and.b d2,M4_LP_ARROWS
M4PmArKeep:
        dbra d3,M4PmArNext
        movem.l (sp)+,d0-d3/a2
        rts
M4PmArTab:
        include '../build/m4-arrow-bits.inc'

; Tunnel body 0B:E913: playermove (with the wall push 0B:D704..D74B), gen3d,
; vx = asr1+asr3 (1F:D4A8), vy = adiv2, framescalevecs, pos += v, limitx,
; playerfire, arrows 0B:E9D0.
M4PmBodyE913:
        move.b M4_LP_PMOVELIMIT,d0 ;bits 0/1 survive $14E0 &= $14E1
        and.b M4_LP_PMOVEAND,d0
        move.w d0,-(sp)
        jsr M4LpMove
        move.w (sp)+,d0
        ; 0B:D704: bit0 -> x += $158F, else bit1 -> x += $158F (no x read in
        ; playermove after it: applied here, same result)
        andi.b #3,d0
        beq.s M4PmBodyNoPush
        move.w M4_PM_158F,d0
        add.w d0,(a0)
M4PmBodyNoPush:
        moveq #0,d0
        move.b 15(a0),d0
        jsr M4LevelGen3dVecs
        move.w 6(a0),d0 ;1F:D4A8 perc62 (floor shifts)
        move.w d0,d1
        asr.w #1,d1
        asr.w #3,d0
        add.w d1,d0
        move.w d0,6(a0)
        move.w 8(a0),d0
        jsr M4LpDiv2
        move.w d0,8(a0)
        jsr M4LpFrameScale
        bsr M4PmMove
        jsr M4SpLimitX
        jsr M4LpFire
        bra M4PmArrows

; ---------------------------------------------------------------------
; WarpOut. playerwarpout_Istrat 0B:8975 (also newplayerstrat of bg $27).
M4PmWarpOutI:
        ori.b #$09,M4_BOSS_PSTRATF ;inseq | novdistC
        ori.b #$60,M4_LP_PSF
        move.l a0,-(sp)
        jsr M4LevelAlloc ;1F:D54B nullshape behind the player: runs this pass
        move.l a0,d0
        beq.s M4PmWoNoGen
        move.l #M4PmWarpGenI,32(a0)
M4PmWoNoGen:
        movea.l (sp)+,a0
        move.b #120,15(a0)
        move.b #120,M4_LP_TOSPEED
        move.b #64,M4_SC_P1553
        move.w #128,M4_WP_W1558
        move.w #400,M4_LP_OUTDIST
        lea M4PmLimSpace,a2
        bsr M4PmLimits
        ori.b #$20,M4_LP_GAMEFLAGS
        andi.b #$fb,M4_BOSS_PSTRATF
        ori.b #2,M4_LP_PSF3
        andi.b #$fb,M4_LP_PSF2
        andi.b #$d7,M4_BOSS_PSTRATF
        andi.b #$fe,M4_LP_PSF3
        move.l #M4PmWarpOut,32(a0)
        move.l #M4LcPlayerColl,X_COLL(a0)
        move.l #M4LcPlayerDead,X_EXP(a0)
        ori.b #2,M4_BOSS_PSTRATF
; 0B:8AAC (02:FEE4 white step: M4MvWhiteTick of level.asm)
M4PmWarpOut:
        subq.w #5,M4_LP_OUTDIST
        subq.b #1,M4_SC_P1553
        beq.s M4PmWoEnd
        move.w M4_WP_W1558,d0
        add.w d0,4(a0)
        add.w d0,M4_LP_PVIEWZ
        subq.w #2,M4_WP_W1558
        jmp M4SpInSpaceStrat ;0B:B95C
M4PmWoEnd: ;0B:8AF6
        andi.b #$fe,M4_BOSS_PSTRATF
        move.w #120,M4_LP_VIEWDIST
        move.b #65,M4_LP_TOSPEED
        move.l #M4SpInSpaceStrat,32(a0)
        move.b #5,M4_SPP_FMOPT
        move.b #2,M4_SPP_FM
        jsr M4SpChangeView ;-> playerintocock_Istrat 0B:C893 (music 4 not ported)
        jmp M4SpInSpaceStrat
M4PmLimSpace: ;0B:89D2.. (= playerinspace 0B:B88C..)
        include '../build/m4-flight-space.inc'

; Generator 0B:8B38 / 8B52: 64 ticks, trail shape by sbyte1 (table 0B:8B90).
M4PmWarpGenI:
        move.l #M4PmWarpGen,32(a0)
        move.w #$bf70,40(a0)
        move.b #64,36(a0)
M4PmWarpGen:
        tst.b 36(a0)
        bne.s M4PmWgLive
        moveq #1,d0 ;jml 06:8D12: removed
        rts
M4PmWgLive:
        subq.b #1,36(a0)
        moveq #0,d0
        move.b 36(a0),d0
        lsr.b #4,d0 ;sbyte1 0..63: asr4 of a positive byte
        add.w d0,d0
        lea M4PmWgShapes,a2
        move.w (a2,d0.w),40(a0)
; 0B:8BAE with the trail shape from sword1 (the Warp's M4WpGenerator fixes
; BF70): roty $80, z = player.z + 4000; a trail on even gameframes, every
; tick with $14DF bit1.
        move.b #$80,13(a0)
        move.w 4(a1),d0
        addi.w #4000,d0
        move.w d0,4(a0)
        btst #1,M4_BOSS_PSTRATF
        bne.s M4PmWgMake
        btst #0,M4_LV_GAMEFRAME+1
        bne M4PmWgDone
M4PmWgMake:
        movea.l a0,a3
        jsr M4LevelAlloc ;behind the generator (creator)
        move.l a0,d0
        beq M4PmWgFail
        move.w 40(a3),d0
        move.w d0,X_SHAPEHDR(a0)
        jsr M4LevelShapeIndex
        jsr M4LevelSetShape
        bset #SF_COLLDISABLE,49(a0)
        move.l #M4WpTrail,32(a0) ;0B:8CD4 (level_warp.asm)
        jsr M4IntroRandom ;x = rnd + 256 (rnd & 1) - 256
        move.w d0,d3
        jsr M4IntroRandom
        andi.w #1,d0
        lsl.w #8,d0
        or.w d3,d0
        subi.w #256,d0
        move.w d0,(a0)
        jsr M4IntroRandom ;y likewise
        move.w d0,d3
        jsr M4IntroRandom
        andi.w #1,d0
        lsl.w #8,d0
        or.w d3,d0
        subi.w #256,d0
        move.w d0,2(a0)
        jsr M4IntroRandom
        move.b d0,14(a0) ;rotz
        move.b d0,d5 ;1F:CC78: (0, 50) by rotz
        moveq #0,d3
        moveq #50,d4
        jsr M4WeaponRotatePair
        ext.w d3
        add.w d3,(a0)
        ext.w d4
        add.w d4,2(a0)
        subi.w #60,2(a0)
        move.w 4(a3),4(a0) ;z = the generator's
M4PmWgFail:
        movea.l a3,a0
M4PmWgDone:
        moveq #0,d0
        rts
M4PmWgShapes: ;0B:8B90
        include '../build/m4-pm-warp-shapes.inc'

; ---------------------------------------------------------------------
; Tunnels. playerinstunnel 0B:C03A, playerinmtunnel 0B:C10C, playerinLtunnel
; 0B:C1DE (InLtunnel 0B:C1C9 installs it); common tail 0B:C297 and the
; tunnel body 0B:BF79 run in the same tick (jml 1F:DC25).
M4PmSTunnelI:
        lea M4PmLimSTunnel,a2
        bra.s M4PmTunnelI
M4PmMTunnelI:
        lea M4PmLimMTunnel,a2
        bra.s M4PmTunnelI
M4PmLTunnelI:
        lea M4PmLimLTunnel,a2
M4PmTunnelI:
        andi.b #$1f,M4_LP_PSF
        bsr M4PmLimits
        andi.b #$df,M4_LP_GAMEFLAGS ;no viewrot
        andi.b #$fb,M4_BOSS_PSTRATF
        ori.b #2,M4_LP_PSF3
        andi.b #$fb,M4_LP_PSF2
        andi.b #$d7,M4_BOSS_PSTRATF
        bset #F2_SHADOW,48(a0) ;+1D |= 8
        ori.b #1,M4_LP_PSF3 ;in a tunnel
        move.l #M4PmTunnel,32(a0) ;0B:C297
        move.l #M4LcPlayerColl,X_COLL(a0)
        move.l #M4LcPlayerDead,X_EXP(a0)
; 0B:BF79: outvx/outvy Achase16_2 -> 0, body E913, pviewposx = perc87(x)
; (asr1+asr2+asr3), pviewposy = viewCY, viewmove; then the wing boxes and
; the weapon factories of the tick.
M4PmTunnel:
        movem.l d0-d7/a1-a3,-(sp)
        move.w M4_LP_OUTVX,d0
        moveq #0,d1
        moveq #2,d2
        jsr M4LpAchase
        move.w d0,M4_LP_OUTVX
        move.w M4_LP_OUTVY,d0
        jsr M4LpAchase
        move.w d0,M4_LP_OUTVY
        bsr M4PmBodyE913
        move.w (a0),d0
        move.w d0,d1
        asr.w #1,d1
        move.w d0,d2
        asr.w #2,d2
        add.w d2,d1
        asr.w #3,d0
        add.w d0,d1
        move.w d1,M4_LP_PVIEWX
        move.w M4_LP_VIEWCY,M4_LP_PVIEWY
        jsr M4LpViewMove
        movem.l (sp)+,d0-d7/a1-a3
        bra M4PmFactories
        include '../build/m4-armada-tunnel-enter.inc'

; Tunnel exits. InS/MTexit 0B:C398 and InLTexit 0B:C46E, run once by the
; map (player_mode), with X = lastobj (not the player): their "+1D,X &= $F7"
; lands on that object (port: M4_LV_LAST), the player's bit stays.
M4PmMTexit:
        lea M4PmLimMTexit,a2
        bra.s M4PmTexit
M4PmLTexit:
        lea M4PmLimLTexit,a2
M4PmTexit:
        bsr M4PmLimits
        ori.b #$20,M4_LP_GAMEFLAGS ;viewrot
        andi.b #$fb,M4_BOSS_PSTRATF
        ori.b #2,M4_LP_PSF3
        ori.b #4,M4_LP_PSF2
        andi.b #$f7,M4_BOSS_PSTRATF
        ori.b #$20,M4_BOSS_PSTRATF ;notdie
        move.l M4_LV_LAST,d0
        beq.s M4PmTxNoLast
        movea.l d0,a3
        bclr #F2_SHADOW,48(a3)
M4PmTxNoLast:
        andi.b #$fe,M4_LP_PSF3
; playerinLTexit 0B:C52E (newplayerstrat; also the tail of both routines):
; stratptr = 0B:C544, noYctrl; nothing else this tick.
M4PmLTexitI:
        move.l #M4PmExit,32(a0)
        ori.b #$80,M4_LP_PSF
        moveq #0,d0
        rts
; 0B:C544: y = Achase16_2(y, viewCY) (1F:D66F), then the tunnel body BF79.
M4PmExit:
        move.w 2(a0),d0
        move.w M4_LP_VIEWCY,d1
        moveq #2,d2
        jsr M4LpAchase
        move.w d0,2(a0)
        bra M4PmTunnel
        include '../build/m4-armada-tunnel-exit.inc'

; ---------------------------------------------------------------------
; playerwashent_Istrat 0B:AA79 (bg $45): noctrl|nofire, dupplayer 0B:EA5E
; (the copy runs 06:E593; the player becomes invisible), then 0B:AAA0.
; Without a free slot the ROM writes the copy's stratptr through an
; undefined Y: not reproduced (no copy).
M4PmWashentI:
        ori.b #$60,M4_LP_PSF
        move.l #M4PmWashent,32(a0)
        jsr M4SpDupPlayer ;a2 = copy (level_cockpit.asm)
        move.l a2,d0
        beq.s M4PmWashent
        move.l #M4PmWashDupI,32(a2)
; 0B:AAA0: z += 65.
M4PmWashent:
        addi.w #65,4(a0)
        moveq #0,d0
        rts

; Copy 06:E593 (pipe): sbyte1 1, vel $41, +1D |= 8; 06:E5AE every tick:
; rotz -> rotx<<1 (Achase8_4), outvz.hi -> rotx<<1 (Achase8_4), outvx.hi ->
; -rotx (Achase8_2); sbyte1 counts the table 06:E818 (count, rotx target);
; rotx -> sbyte3 (Achase8_3); pviewpos = pos; gen3d; pos += v.
M4PmWashDupI:
        move.b #1,36(a0)
        move.l #M4PmWashDup,32(a0)
        move.b #$41,15(a0)
        bset #F2_SHADOW,48(a0)
M4PmWashDup:
        lea M4PmWashTab,a3
        bsr.s M4PmPipe
        bne M4PmWdEndI
M4PmWdView: ;06:E690
        move.l (a0),M4_LP_PVIEWX
        move.w 4(a0),M4_LP_PVIEWZ
        bsr M4PmGenMove
        moveq #0,d0
        rts
; Pipe step common to 06:E5AE (washent) and 06:E2DF (clearcolony), a3 =
; table (count, rotx target): rotz/outvz.hi -> rotx<<1 (Achase8_4), outvx.hi
; -> -rotx (Achase8_2), table step, rotx -> sbyte3 (Achase8_3). d0 = 1 (NE)
; when the table ended (count 0: no rotx chase), else 0 (EQ).
M4PmPipe:
        move.b 12(a0),d1
        add.b d1,d1
        move.b d1,d6 ;$152E
        move.b 14(a0),d0
        moveq #4,d2
        bsr M4PmAch8
        move.b d0,14(a0)
        move.b M4_LP_OUTVZ,d0 ;$18CC
        move.b d6,d1
        bsr M4PmAch8
        move.b d0,M4_LP_OUTVZ
        move.b 12(a0),d1
        neg.b d1
        move.b M4_LP_OUTVX,d0 ;$18C8
        moveq #2,d2
        bsr M4PmAch8
        move.b d0,M4_LP_OUTVX
        subq.b #1,36(a0)
        bne.s M4PmWdPitch
        moveq #0,d0
        move.b 37(a0),d0
        move.b (a3,d0.w),36(a0)
        move.b 1(a3,d0.w),X_SBYTE3(a0)
        addq.b #2,37(a0)
        tst.b 36(a0)
        bne.s M4PmWdPitch
        moveq #1,d0
        rts
M4PmWdPitch: ;06:E684 / 06:E3B5
        move.b 12(a0),d0
        move.b X_SBYTE3(a0),d1
        moveq #3,d2
        bsr M4PmAch8
        move.b d0,12(a0)
        moveq #0,d0
        rts

; playerclearcolony_Istrat 0B:AA30 (Venom 2 colony): noctrl|nofire,
; dupplayer (copy 06:E2C4; the player becomes invisible), 0B:AA57 z += 65.
M4PmClearColonyI:
        ori.b #$60,M4_LP_PSF
        move.l #M4PmWashent,32(a0) ;0B:AA57 = z += 65 (as 0B:AAA0)
        jsr M4SpDupPlayer
        move.l a2,d0
        beq M4PmWashent
        move.l #M4PmColonyDupI,32(a2)
        bra M4PmWashent
; Copy 06:E2C4 / 06:E2DF: the pipe with table 06:E55F; 06:E3C1: pviewpos =
; pos, $14FE += 65, gen3d, pos += v. Table end -> 06:E403: boostobj = copy,
; flame, vel 120, sbyte1 30 (sound $32 not ported); 06:E44A: outvz.hi /
; outvx.hi / rotz / rotx -> 0 (Achase8_4), z += 150, y -> -60 (Achase16_4);
; at 0: the player gets playerinLtunnel 0B:C1DE, dozrot 0, visible, (0, -60,
; z + 120); the copy runs 06:8D12 (removed) next pass.
M4PmColonyDupI:
        move.b #1,36(a0)
        move.l #M4PmColonyDup,32(a0)
        move.b #$41,15(a0)
        bset #F2_SHADOW,48(a0)
M4PmColonyDup:
        lea M4PmColonyTab,a3
        bsr M4PmPipe
        bne.s M4PmCdEndI
M4PmCdView: ;06:E3C1
        move.l (a0),M4_LP_PVIEWX
        move.w 4(a0),M4_LP_PVIEWZ
        addi.w #65,M4_PM_14FE
        bsr M4PmGenMove
        moveq #0,d0
        rts
M4PmCdEndI: ;06:E403
        move.l #M4PmColonyEnd,32(a0)
        jsr M4LevelBoostFlame ;boostobj = copy
        move.b #120,15(a0)
        move.b #30,36(a0)
M4PmColonyEnd: ;06:E44A
        moveq #4,d2
        moveq #0,d1
        move.b M4_LP_OUTVZ,d0
        bsr M4PmAch8
        move.b d0,M4_LP_OUTVZ
        move.b M4_LP_OUTVX,d0
        bsr M4PmAch8
        move.b d0,M4_LP_OUTVX
        move.b 14(a0),d0
        bsr M4PmAch8
        move.b d0,14(a0)
        move.b 12(a0),d0
        bsr M4PmAch8
        move.b d0,12(a0)
        addi.w #150,4(a0)
        move.w 2(a0),d0
        moveq #-60,d1
        jsr M4LpAchase
        move.w d0,2(a0)
        subq.b #1,36(a0)
        bne M4PmCdView
        move.l #M4PmLTunnelI,32(a1)
        clr.b M4_PM_DOZROT
        bclr #SF_INVISIBLE,49(a1)
        clr.w (a1)
        move.w #-60,2(a1)
        move.w 4(a0),d0
        addi.w #120,d0
        move.w d0,4(a1)
        move.l #M4EnRemoveSelf,32(a0) ;06:8D12 next pass
        bra M4PmCdView
M4PmColonyTab: ;06:E55F (count, rotx target)
        incbin '../build/M4PmColonyTab.bin'
        even
        move.l (a0),M4_LP_PVIEWX
        move.w 4(a0),M4_LP_PVIEWZ
        bsr M4PmGenMove
        moveq #0,d0
        rts
; 06:E6C2: 30 ticks of camera approach (sound $33 not ported), same tick.
M4PmWdEndI:
        move.l #M4PmWashEnd,32(a0)
        move.b #30,36(a0)
; 06:E6D9: outdist -> 0 (Achase16_3), y -> -60 (1F:D6AB), outvz.hi/outvx.hi
; -> 0, rotz/rotx -> 0 (Achase8_4); player.z = z; at 0: the player gets
; playerinnucleus 0B:C699, dozrot 0, visible, x 0, z + 65, and the copy is
; removed after its last 06:E690.
M4PmWashEnd:
        move.w M4_LP_OUTDIST,d0
        moveq #0,d1
        moveq #3,d2
        jsr M4LpAchase
        move.w d0,M4_LP_OUTDIST
        move.w 2(a0),d0
        moveq #-60,d1
        jsr M4LpAchase
        move.w d0,2(a0)
        moveq #4,d2
        move.b M4_LP_OUTVZ,d0
        moveq #0,d1
        bsr M4PmAch8
        move.b d0,M4_LP_OUTVZ
        move.b M4_LP_OUTVX,d0
        bsr M4PmAch8
        move.b d0,M4_LP_OUTVX
        move.b 14(a0),d0
        bsr M4PmAch8
        move.b d0,14(a0)
        move.b 12(a0),d0
        bsr M4PmAch8
        move.b d0,12(a0)
        move.w 4(a0),4(a1)
        subq.b #1,36(a0)
        bne M4PmWdView
        move.l #M4PmNucleusI,32(a1)
        clr.b M4_PM_DOZROT
        bclr #SF_INVISIBLE,49(a1)
        clr.w (a1)
        addi.w #65,4(a1)
        bsr M4PmWdView ;1F:D501 then brl 06:E690
        moveq #1,d0
        rts
M4PmWashTab: ;06:E818 (count, rotx target)
        incbin '../build/M4PmWashTab.bin'

; ---------------------------------------------------------------------
; playerinnucleus_Istrat 0B:C699 / 0B:C782.
M4PmNucleusI:
        andi.b #$1f,M4_LP_PSF
        lea M4PmLimNucleus,a2
        bsr M4PmLimits
        andi.b #$df,M4_LP_GAMEFLAGS
        andi.b #$fb,M4_BOSS_PSTRATF
        ori.b #2,M4_LP_PSF3
        andi.b #$fb,M4_LP_PSF2
        andi.b #$d7,M4_BOSS_PSTRATF
        bset #F2_SHADOW,48(a0)
        andi.b #$fe,M4_LP_PSF3
        move.w #-60,2(a0)
        move.l #M4PmNucleus,32(a0)
        move.l #M4LcPlayerColl,X_COLL(a0)
        move.l #M4LcPlayerDead,X_EXP(a0)
; 0B:C782: Ztilt += lo8(asr7(player_posx $150F)); body E913; pviewposx =
; x*15/16 (1F:D4DF asr1+asr2+asr3+asr4) + $1593; pviewposy = -60 + $1595.
M4PmNucleus:
        movem.l d0-d7/a1-a3,-(sp)
        move.w M4_SC_PPOSX,d0
        asr.w #7,d0
        add.b d0,M4_LP_ZTILT
        bsr M4PmBodyE913
        move.w (a0),d0
        move.w d0,d1
        asr.w #1,d1
        move.w d0,d2
        asr.w #2,d2
        add.w d2,d1
        move.w d0,d2
        asr.w #3,d2
        add.w d2,d1
        asr.w #4,d0
        add.w d0,d1
        add.w M4_PM_1593,d1
        move.w d1,M4_LP_PVIEWX
        moveq #-60,d0
        add.w M4_PM_1595,d0
        move.w d0,M4_LP_PVIEWY
        jsr M4LpViewMove
        movem.l (sp)+,d0-d7/a1-a3
        bra M4PmFactories
M4PmLimNucleus: ;0B:C6A3..C711
        include '../build/m4-flight-nucleus.inc'

; ---------------------------------------------------------------------
; EscapeNucleus 0B:9437 -> 0B:944C (Istrat) / 946F (turn) / 9496 (boost) /
; 94D5 (exit) / 9512 (common). No playermove/viewmove.
M4PmEscapeI:
        ori.b #8,M4_BOSS_PSTRATF ;inseq
        move.l #M4PmEscTurn,32(a0)
        clr.b 15(a0)
        clr.b 13(a0)
        bset #SF_COLLDISABLE,49(a0)
M4PmEscTurn:
        cmpi.b #$f0,13(a0)
        beq.s M4PmEscBoost
        subq.b #1,13(a0)
        subq.b #1,14(a0)
        cmpi.b #8,12(a0)
        beq.s M4PmEscCommon
        addq.b #1,12(a0)
        bra.s M4PmEscCommon
M4PmEscBoost: ;0B:9496
        move.l #M4PmEscGo,32(a0)
        move.b #15,X_SBYTE3(a0)
        jsr M4LevelBoostFlame ;boostobj = player, flame 06:8671 (invisible until it runs)
M4PmEscGo: ;0B:94D5
        subq.b #1,X_SBYTE3(a0)
        bne.s M4PmEscCommon
        move.b #1,X_SBYTE3(a0)
        cmpi.b #$f8,12(a0)
        beq.s M4PmEscRz
        subq.b #1,12(a0)
M4PmEscRz:
        cmpi.b #$20,14(a0)
        beq.s M4PmEscRy
        addq.b #2,14(a0)
M4PmEscRy:
        cmpi.b #$98,13(a0)
        beq.s M4PmEscCommon
        addq.b #8,13(a0)
M4PmEscCommon: ;0B:9512
        moveq #30,d0
        moveq #1,d1
        jsr M4EnSpeedTo
        move.w #65,M4_LP_PVIEWVZ
        addi.w #65,M4_LP_PVIEWZ
        moveq #0,d0
        move.b 15(a0),d0
        jsr M4LevelGen3dVecs
        addi.w #65,10(a0)
        bsr M4PmMove
        moveq #0,d0
        rts

; ---------------------------------------------------------------------
; Other stages. Planet/water bodies: 0B:E913, 0B:E952 and 0B:E991 are the
; same instructions (M4PmBodyE913).

; playerspaceflyin_Istrat 0B:822A: space limits, no coll/exp (1F:D450),
; (0, -400, 0), novdistC, speeds 65; 0B:8326: outdist + 3, y -> viewCY
; (1F:D6AB, C when equal on entry): then playerinspace_Istrat 0B:B882.
M4PmSpaceFlyinI:
        ori.b #$60,M4_LP_PSF
        lea M4PmLimSpace,a2
        bsr M4PmLimits
        ori.b #$20,M4_LP_GAMEFLAGS
        andi.b #$fb,M4_BOSS_PSTRATF
        ori.b #2,M4_LP_PSF3
        andi.b #$fb,M4_LP_PSF2
        andi.b #$d7,M4_BOSS_PSTRATF
        andi.b #$fe,M4_LP_PSF3
        move.l #M4PmSpaceFlyin,32(a0)
        clr.l X_COLL(a0)
        clr.l X_EXP(a0)
        clr.w (a0)
        move.w #-400,2(a0)
        clr.w 4(a0)
        ori.b #1,M4_BOSS_PSTRATF
        move.w #65,M4_LP_PVIEWVZ
        move.b #65,M4_LP_TOSPEED
        move.b #65,M4_LP_MEDSPEED
        move.b #65,15(a0)
M4PmSpaceFlyin:
        addq.w #3,M4_LP_OUTDIST
        move.w 2(a0),d0
        move.w M4_LP_VIEWCY,d1
        cmp.w d1,d0
        beq.s M4PmSfArrived
        moveq #3,d2
        jsr M4LpAchase
        move.w d0,2(a0)
        jmp M4SpInSpaceStrat
M4PmSfArrived:
        andi.b #$fe,M4_BOSS_PSTRATF
        jmp M4SpInSpaceI

; playerundergnd_Istrat 0B:BC25 / 0B:BD05: body E913, pviewposx = perc87(x)
; (1F:D4C8), pviewposy = viewCY.
M4PmUnderGndI:
        andi.b #$1f,M4_LP_PSF
        lea M4PmLimUnderGnd,a2
        bsr M4PmLimits
        andi.b #$fb,M4_BOSS_PSTRATF
        ori.b #2,M4_LP_PSF3
        andi.b #$fb,M4_LP_PSF2
        andi.b #$d7,M4_BOSS_PSTRATF
        bset #F2_SHADOW,48(a0)
        andi.b #$fe,M4_LP_PSF3
        move.l #M4PmUnderGnd,32(a0)
        move.l #M4LcPlayerColl,X_COLL(a0)
        move.l #M4LcPlayerDead,X_EXP(a0)
M4PmUnderGnd:
        movem.l d0-d7/a1-a3,-(sp)
        bsr M4PmBodyE913
        bsr M4PmPerc87
        move.w M4_LP_VIEWCY,M4_LP_PVIEWY
        bra.s M4PmBodyEnd
; d1 = perc87(x) = asr1+asr2+asr3 (1F:D4C8) -> pviewposx.
M4PmPerc87:
        move.w (a0),d0
        move.w d0,d1
        asr.w #1,d1
        move.w d0,d2
        asr.w #2,d2
        add.w d2,d1
        asr.w #3,d0
        add.w d0,d1
        move.w d1,M4_LP_PVIEWX
        rts
M4PmBodyEnd:
        jsr M4LpViewMove
        movem.l (sp)+,d0-d7/a1-a3
        bra M4PmFactories
M4PmLimUnderGnd: ;0B:BC2F..BC9D
        include '../build/m4-flight-underground.inc'

; OnWater 0B:BD27 -> playeronwater_Istrat 0B:BD3C / 0B:BE1C (= the planet
; body 0B:BBE3: M4LevelPlayerStrat with its weapon factories).
M4PmOnWaterI:
        andi.b #$1f,M4_LP_PSF
        lea M4PmLimOnWater,a2
        bsr M4PmLimits
        ori.b #$20,M4_LP_GAMEFLAGS
        andi.b #$fb,M4_BOSS_PSTRATF
        ori.b #2,M4_LP_PSF3
        andi.b #$fb,M4_LP_PSF2
        andi.b #$d7,M4_BOSS_PSTRATF
        bset #F2_SHADOW,48(a0)
        andi.b #$fe,M4_LP_PSF3
        move.l #M4LevelPlayerStrat,32(a0)
        move.l #M4LcPlayerColl,X_COLL(a0)
        move.l #M4LcPlayerDead,X_EXP(a0)
; 0B:BE1C = 0B:BBE3 (M4LevelPlayerStrat).
        jmp M4LevelPlayerStrat
M4PmLimOnWater: ;0B:BD46..BDB4
        include '../build/m4-flight-on-water.inc'

; playeronbridge_Istrat 0B:BE5E / 0B:BF52: body E991 (= E913), then vy =
; adiv2(vy) again, pviewposx = perc62(x) (1F:D4A8), pviewposy = viewCY.
M4PmOnBridgeI:
        andi.b #$1f,M4_LP_PSF
        lea M4PmLimOnBridge,a2
        bsr M4PmLimits
        andi.b #$df,M4_LP_GAMEFLAGS
        andi.b #$fb,M4_BOSS_PSTRATF
        ori.b #2,M4_LP_PSF3
        andi.b #$fb,M4_LP_PSF2
        move.w #-90,M4_PM_1583
        move.w #90,M4_PM_1585
        andi.b #$d7,M4_BOSS_PSTRATF
        bset #F2_SHADOW,48(a0)
        andi.b #$fe,M4_LP_PSF3
        move.l #M4PmOnBridge,32(a0)
        move.l #M4LcPlayerColl,X_COLL(a0)
        move.l #M4LcPlayerDead,X_EXP(a0)
M4PmOnBridge:
        movem.l d0-d7/a1-a3,-(sp)
        bsr M4PmBodyE913
        move.w 8(a0),d0
        jsr M4LpDiv2
        move.w d0,8(a0)
        bsr M4PmPerc62
        move.w M4_LP_VIEWCY,M4_LP_PVIEWY
        bra M4PmBodyEnd
; pviewposx = perc62(x) = asr1+asr3 (1F:D4A8).
M4PmPerc62:
        move.w (a0),d0
        move.w d0,d1
        asr.w #1,d1
        asr.w #3,d0
        add.w d1,d0
        move.w d0,M4_LP_PVIEWX
        rts
M4PmLimOnBridge: ;0B:BE68..BED6
        include '../build/m4-flight-on-bridge.inc'

; Water (Venom 2 colony): playercolonyflyin_Istrat 0B:86F1 / 0B:87E4 (y ->
; viewCY by Achase16_4, C when equal on entry -> 0B:C56E), water Istrat
; 0B:C56E / body 0B:C66A (E952 = E913, pviewposx = perc62(x), pviewposy = -60).
M4PmColonyFlyinI:
        ori.b #$60,M4_LP_PSF
        bsr.s M4PmWaterLimits
        move.l #M4PmColonyFlyin,32(a0)
        clr.l X_COLL(a0)
        clr.l X_EXP(a0)
        move.w #-120,2(a0)
        move.b #85,15(a0)
M4PmColonyFlyin:
        move.w 2(a0),d0
        move.w M4_LP_VIEWCY,d1
        cmp.w d1,d0
        beq.s M4PmWaterI
        moveq #4,d2
        jsr M4LpAchase
        move.w d0,2(a0)
        bra.s M4PmWater
M4PmWaterI:
        andi.b #$1f,M4_LP_PSF
        bsr.s M4PmWaterLimits
        move.l #M4PmWater,32(a0)
        move.l #M4LcPlayerColl,X_COLL(a0)
        move.l #M4LcPlayerDead,X_EXP(a0)
M4PmWater:
        movem.l d0-d7/a1-a3,-(sp)
        bsr M4PmBodyE913
        bsr M4PmPerc62
        move.w #-60,M4_LP_PVIEWY
        bra M4PmBodyEnd
M4PmWaterLimits: ;0B:86FB..87C3 = 0B:C578..C640
        lea M4PmLimWater,a2
        bsr M4PmLimits
        andi.b #$df,M4_LP_GAMEFLAGS
        andi.b #$fb,M4_BOSS_PSTRATF
        ori.b #2,M4_LP_PSF3
        andi.b #$fb,M4_LP_PSF2
        move.w #-140,M4_PM_1583
        move.w #-140,M4_PM_1587
        andi.b #$d7,M4_BOSS_PSTRATF
        ori.b #$10,M4_BOSS_PSTRATF
        bset #F2_SHADOW,48(a0)
        ori.b #1,M4_LP_PSF3
        rts
M4PmLimWater:
        include '../build/m4-flight-colony-water.inc'

; IntoLB1 0B:924F -> 0B:9264 (Istrat, noctrl|nofire) / 0B:9279: x -> 0,
; y -> viewCY (Achase16_4); |mapvar1.z - z| >= $6F9 (N of the difference)
; -> the planet body 0B:BBE3; else 0B:92BB: no coll/exp (1F:D450), gameflags
; bit3 off, wobble off, inseq, dupplayer (copy 07:819E = viewtoobj),
; viewtype Fpos|toobj, camera nullshape 07:83A9 at the player, no zremove,
; then 0B:9335 (z += 65). Without a free slot the ROM writes the copy's
; stratptr through an undefined Y: not reproduced.
M4PmIntoLB1I:
        ori.b #$60,M4_LP_PSF
        move.l #M4PmIntoLB1,32(a0)
M4PmIntoLB1:
        move.w (a0),d0
        moveq #0,d1
        moveq #4,d2
        jsr M4LpAchase
        move.w d0,(a0)
        move.w 2(a0),d0
        move.w M4_LP_VIEWCY,d1
        jsr M4LpAchase
        move.w d0,2(a0)
        move.w M4_LV_MAPVAR1,d0
        beq.s M4PmLb1Far ;no object: the ROM reads $0010 (not reproduced)
        movea.w d0,a2
        move.w 4(a2),d0
        sub.w 4(a0),d0
        bpl.s M4PmLb1Abs
        neg.w d0
M4PmLb1Abs:
        cmpi.w #$6f9,d0
        bmi.s M4PmLb1Near
M4PmLb1Far:
        jmp M4LevelPlayerStrat ;0B:BBE3
M4PmLb1Near: ;0B:92BB
        ori.b #$60,M4_LP_PSF
        move.l #M4PmLb1Run,32(a0)
        clr.l X_COLL(a0)
        clr.l X_EXP(a0)
        andi.b #$f7,M4_LP_GAMEFLAGS
        andi.b #$ef,M4_LP_FLYMODE
        ori.b #8,M4_BOSS_PSTRATF
        jsr M4SpDupPlayer ;a2 = copy or 0
        move.l a2,d0
        beq.s M4PmLb1NoCopy
        move.l #M4PmLB1CopyI,32(a2)
        bset #F2_SHADOW,48(a2) ;0B:EA8B +1D |= 8
        move.w a2,M4_VE_VTO ;viewtoobj
M4PmLb1NoCopy:
        move.b #3,M4_SC_VIEWTYPE
        move.l a0,-(sp)
        jsr M4LevelAlloc ;nullshape behind the player (before the copy)
        movea.l (sp)+,a3
        move.l a0,d0
        beq.s M4PmLb1NoCam
        move.l #M4PmLB1CamI,32(a0)
        move.l (a3),(a0) ;1F:DAD9
        move.w 4(a3),4(a0)
M4PmLb1NoCam:
        movea.l a3,a0
        ori.b #1,M4_LP_GAMEFLAGS ;no zremove
; 0B:9335: z += 65.
M4PmLb1Run:
        addi.w #65,4(a0)
        moveq #0,d0
        rts

; Copy 07:819E (viewtoobj): colldisable, vel $41, sbyte1 $20; 07:81B9 by its
; stratstate: 0 speedto(20,1), rotx -2 (32 ticks); 1 sbyte1 10 -> gf2 bit0,
; rotz +8, speedto, rotx +2 (64 ticks) -> vel 85 and the boost flame; 2
; z/x -> mapvar1 (Achase16_4), rotz -> 0 (Achase8_3) (40 ticks) -> 4:
; hand-over to playerinLtunnel 0B:C1DE and removal; else gen3d, pos += v.
M4PmLB1CopyI:
        move.l #M4PmLB1Copy,32(a0)
        bset #SF_COLLDISABLE,49(a0)
        move.b #$41,15(a0)
        move.b #$20,36(a0)
M4PmLB1Copy:
        tst.b X_STATE(a0)
        bne.s M4PmLc1
        moveq #20,d0
        moveq #1,d1
        jsr M4EnSpeedTo
        subq.b #2,12(a0)
        subq.b #1,36(a0)
        bne.s M4PmLc1
        move.b #1,X_STATE(a0)
        move.b #$40,36(a0)
M4PmLc1:
        cmpi.b #1,X_STATE(a0)
        bne.s M4PmLc2
        cmpi.b #10,36(a0)
        bne.s M4PmLc1b
        ori.b #1,M4_AR_GF2 ;$14D3
M4PmLc1b:
        addq.b #8,14(a0)
        moveq #20,d0
        moveq #1,d1
        jsr M4EnSpeedTo
        addq.b #2,12(a0)
        subq.b #1,36(a0)
        bne.s M4PmLc2
        move.b #2,X_STATE(a0)
        move.b #$55,15(a0)
        jsr M4LevelBoostFlame ;boostobj = copy (sound $32 not ported)
        move.b #$28,36(a0)
M4PmLc2:
        cmpi.b #2,X_STATE(a0)
        bne.s M4PmLc4
        move.w M4_LV_MAPVAR1,d0
        beq.s M4PmLc2Rz
        movea.w d0,a2
        move.w 4(a0),d0
        move.w 4(a2),d1
        moveq #4,d2
        jsr M4LpAchase
        move.w d0,4(a0)
        move.w (a0),d0
        move.w (a2),d1
        jsr M4LpAchase
        move.w d0,(a0)
M4PmLc2Rz:
        move.b 14(a0),d0
        moveq #0,d1
        moveq #3,d2
        bsr M4PmAch8
        move.b d0,14(a0)
        subq.b #1,36(a0)
        bne.s M4PmLc4
        move.b #4,X_STATE(a0)
M4PmLc4:
        cmpi.b #4,X_STATE(a0)
        beq.s M4PmLcHand
        bsr M4PmGenMove ;07:8392
        moveq #0,d0
        rts
M4PmLcHand: ;07:82BA
        move.l #M4PmLTunnelI,32(a1)
        bclr #SF_INVISIBLE,49(a1)
        clr.w M4_VE_VTO ;viewtoobj = the player
        clr.b M4_SC_VIEWTYPE
        move.w #85,M4_LP_PVIEWVZ
        move.b #85,M4_LP_TOSPEED
        move.w #60,M4_LP_OUTDIST
        move.w #60,M4_LP_VIEWDIST
        move.b #65,M4_LP_MEDSPEED
        move.b #85,15(a1)
        move.b #1,37(a1)
        move.w #-65,2(a1)
        clr.w (a1)
        move.w 4(a1),M4_LP_POSZ ;$1513 player_posz
        move.w 4(a1),d0
        subi.w #85,d0
        move.w d0,M4_LP_PVIEWZ
        move.w #-60,M4_LP_PVIEWY
        clr.w M4_LP_PVIEWX
        clr.w M4_LP_OUTVX
        clr.w M4_LP_OUTVY
        clr.w M4_LP_OUTVZ
        andi.b #$fe,M4_LP_GAMEFLAGS
        clr.w M4_PM_156B
        moveq #1,d0 ;1F:D501
        rts

; Camera 07:83A9: colldisable, vel $41, sbyte1 $15, sword1 = outdist, sword2
; 0, al_ptr 0, rnd >= $7F -> sflag1; 07:83F1 by the stratstate of viewtoobj
; (the copy; the player's once handed over): 0 sword1 += 4, al_ptr -+ 2; 1
; sword1 -> 5 (Achase16_4), sword2 -= 8; 2 sword2 -> -60 (Achase16_4), al_ptr
; -> 0 (Achase16_3); 4 removed; pos = viewtoobj + (al_ptr, sword2, -sword1)
; -> $C1/$C3/$C5, $14FE = y.
M4PmLB1CamI:
        move.l #M4PmLB1Cam,32(a0)
        bset #SF_COLLDISABLE,49(a0)
        move.b #$41,15(a0)
        move.b #$15,36(a0)
        move.w M4_LP_OUTDIST,40(a0)
        clr.w 42(a0)
        clr.w X_ALPTR(a0)
        jsr M4IntroRandom
        cmpi.b #$7f,d0
        bcs.s M4PmLB1Cam
        bset #F2_SFLAG1,48(a0)
M4PmLB1Cam:
        lea LV_PLAYER,a2
        move.b M4_WP_STATE,d3 ;the player's stratstate $1CDC
        move.w M4_VE_VTO,d0
        beq.s M4PmLcmState
        movea.w d0,a2
        move.b X_STATE(a2),d3
M4PmLcmState:
        tst.b d3
        bne.s M4PmLcm1
        addq.w #4,40(a0)
        moveq #2,d0
        btst #F2_SFLAG1,48(a0)
        beq.s M4PmLcm0
        moveq #-2,d0
M4PmLcm0:
        add.w d0,X_ALPTR(a0)
M4PmLcm1:
        cmpi.b #1,d3
        bne.s M4PmLcm2
        move.w 40(a0),d0
        moveq #5,d1
        moveq #4,d2
        jsr M4LpAchase
        move.w d0,40(a0)
        subq.w #8,42(a0)
M4PmLcm2:
        cmpi.b #2,d3
        bne.s M4PmLcm4
        move.w 42(a0),d0
        moveq #-60,d1
        moveq #4,d2
        jsr M4LpAchase
        move.w d0,42(a0)
        move.w X_ALPTR(a0),d0
        moveq #0,d1
        moveq #3,d2
        jsr M4LpAchase
        move.w d0,X_ALPTR(a0)
M4PmLcm4:
        moveq #0,d7
        cmpi.b #4,d3
        bne.s M4PmLcmPos
        moveq #1,d7 ;1F:D501 (this object; it still runs to the end)
M4PmLcmPos: ;1F:DAED pos = viewtoobj
        move.w 4(a2),d0
        sub.w 40(a0),d0
        move.w d0,4(a0)
        move.w 2(a2),d0
        add.w 42(a0),d0
        move.w d0,2(a0)
        move.w (a2),d0
        add.w X_ALPTR(a0),d0
        move.w d0,(a0)
        move.l (a0),M4_SC_VIEWPOS
        move.w 4(a0),M4_SC_VIEWPOS+4
        move.w 2(a0),M4_PM_14FE
        move.l d7,d0
        rts

; playerdivegnd_Istrat 0B:8D1E: stayblack - 11 neither zero nor N (8 bits)
; -> playeronplanet_Istrat 0B:BB03; else planet limits, no zremove, 0B:8EC4
; (rtl: nothing per tick), dupplayer (copy 06:D055 = viewtoobj, at 0), camera
; nullshape 06:D18B (sword1 = copy, copy.sword1 = camera, at 0), viewtype 0,
; player at 0, lastplayz $1701 = 0, outvx 0.
M4PmDiveGndI:
        move.b M4_SC_STAYBLACK,d0
        subi.b #11,d0
        beq.s M4PmDvGo
        bmi.s M4PmDvGo
        jmp M4ScOnPlanetNew ;0B:BB03 Istrat + planet body
M4PmDvGo:
        ori.b #1,M4_LP_GAMEFLAGS
        lea M4PmLimDive,a2
        bsr M4PmLimits
        ori.b #$20,M4_LP_GAMEFLAGS
        andi.b #$fb,M4_BOSS_PSTRATF
        ori.b #2,M4_LP_PSF3
        andi.b #$fb,M4_LP_PSF2
        andi.b #$d7,M4_BOSS_PSTRATF
        bset #F2_SHADOW,48(a0)
        andi.b #$fe,M4_LP_PSF3
        move.l #M4PmDiveGnd,32(a0)
        move.l #M4LcPlayerColl,X_COLL(a0)
        move.l #M4LcPlayerDead,X_EXP(a0)
        andi.b #$df,M4_LP_GAMEFLAGS
        ori.b #$60,M4_LP_PSF
        jsr M4SpDupPlayer ;a2 = copy or 0
        move.l a2,d0
        beq.s M4PmDvNoCopy
        move.l #M4PmDiveCopyI,32(a2)
        bset #F2_SHADOW,48(a2)
        clr.l (a2)
        clr.w 4(a2)
        move.w a2,M4_VE_VTO
M4PmDvNoCopy:
        move.l a2,d6 ;$151D
        move.l a0,-(sp)
        jsr M4LevelAlloc ;nullshape behind the player (before the copy)
        movea.l (sp)+,a3
        move.l a0,d0
        beq.s M4PmDvNoCam
        move.l #M4PmDiveCamI,32(a0)
        move.w d6,40(a0)
        clr.l (a0)
        clr.w 4(a0)
        tst.l d6
        beq.s M4PmDvNoCam
        movea.l d6,a2
        move.w a0,40(a2)
M4PmDvNoCam:
        movea.l a3,a0
        clr.b M4_SC_VIEWTYPE
        clr.l (a0)
        clr.w 4(a0)
        clr.w TEXT_MAP_CONTEXT+4 ;lastplayz $1701
        clr.w M4_LP_OUTVX
; 0B:8EC4: rtl.
M4PmDiveGnd:
        moveq #0,d0
        rts
M4PmLimDive: ;0B:8D35..8DA3
        include '../build/m4-flight-dive.inc'

; Copy 06:D055: rotx $40, vel 50, y -2798, +1D |= 8, no zremove, sbyte1 54;
; 06:D083: |camera.z - z| >= 120 -> hand-over (06:D0A0); else gen3d, pos +=
; v; sbyte1 > 20: rotz -= 8, speedto(20, 1); else (06:D15A at 0: viewtype
; toobj) gameflags bit0 off, rotx -> 0 (Achase8_5), speedto(65, 1), rotz ->
; 0 (Achase8_4).
M4PmDiveCopyI:
        move.b #$40,12(a0)
        move.l #M4PmDiveCopy,32(a0)
        move.b #50,15(a0)
        move.w #-2798,2(a0)
        bset #F2_SHADOW,48(a0)
        bclr #3,45(a0) ;no zremove
        move.b #$36,36(a0)
M4PmDiveCopy:
        movea.w 40(a0),a2 ;the camera
        move.w 4(a2),d0
        sub.w 4(a0),d0
        bpl.s M4PmDcAbs
        neg.w d0
M4PmDcAbs:
        cmpi.w #120,d0
        bmi.s M4PmDcDive
        move.l #M4EnRemoveSelf,32(a2) ;06:8D12 next pass
        move.l #M4EnRemoveSelf,32(a0)
        move.l #M4ScOnPlanetNew,32(a1) ;0B:BB03
        move.l #M4ScOnPlanetNew,M4_SC_NEWPSTRAT ;$1788
        clr.b M4_SC_VIEWTYPE
        move.w #65,M4_LP_PVIEWVZ
        move.b #65,M4_LP_TOSPEED
        move.w #120,M4_LP_OUTDIST
        move.w #120,M4_LP_VIEWDIST
        move.b #65,M4_LP_MEDSPEED
        move.b #65,15(a1)
        move.l (a0),(a1) ;1F:DAD9
        move.w 4(a0),4(a1)
        bclr #SF_INVISIBLE,49(a1)
        moveq #0,d0
        rts
M4PmDcDive: ;06:D11D
        bsr M4PmGenMove
        tst.b 36(a0)
        beq.s M4PmDcLevel
        subq.b #1,36(a0)
        cmpi.b #20,36(a0)
        bmi.s M4PmDcFlat
        subq.b #8,14(a0)
        moveq #20,d0
        moveq #1,d1
        jsr M4EnSpeedTo
        moveq #0,d0
        rts
M4PmDcLevel:
        move.b #1,M4_SC_VIEWTYPE
M4PmDcFlat: ;06:D15F
        andi.b #$fe,M4_LP_GAMEFLAGS
        move.b 12(a0),d0
        moveq #0,d1
        moveq #5,d2
        bsr M4PmAch8
        move.b d0,12(a0)
        moveq #65,d0
        moveq #1,d1
        jsr M4EnSpeedTo
        move.b 14(a0),d0
        moveq #0,d1
        moveq #4,d2
        bsr M4PmAch8
        move.b d0,14(a0)
        moveq #0,d0
        rts

; Camera 06:D18B: no zremove, y -2637, vel 20, rotx $40, sbyte1 90, outvx
; $C000, outvz 0; 06:D1C7: z += copy.vz, gen3d (own), y += vy, pviewpos =
; pos, player pos = pos; sbyte1 > 40: outvz -= $400; else (at 0: z -= 3)
; rotx -> 0 (Achase8_5), speedto(65, 1), outvz -> 0 (Achase16_3).
M4PmDiveCamI:
        move.l #M4PmDiveCam,32(a0)
        bclr #3,45(a0)
        move.w #-2637,2(a0)
        move.b #20,15(a0)
        move.b #$40,12(a0)
        move.b #$5a,36(a0)
        move.w #$c000,M4_LP_OUTVX
        clr.w M4_LP_OUTVZ
M4PmDiveCam:
        movea.w 40(a0),a2 ;the copy
        move.w 10(a2),d0
        add.w d0,4(a0)
        moveq #0,d0
        move.b 15(a0),d0
        jsr M4LevelGen3dVecs
        move.w 8(a0),d0
        add.w d0,2(a0)
        move.l (a0),M4_LP_PVIEWX
        move.w 4(a0),M4_LP_PVIEWZ
        move.l (a0),(a1) ;1F:DAD9 player pos
        move.w 4(a0),4(a1)
        tst.b 36(a0)
        beq.s M4PmDvcEnd
        subq.b #1,36(a0)
        cmpi.b #40,36(a0)
        bmi.s M4PmDvcFlat
        subi.w #$400,M4_LP_OUTVZ
        moveq #0,d0
        rts
M4PmDvcEnd:
        subq.w #3,4(a0)
M4PmDvcFlat: ;06:D244
        move.b 12(a0),d0
        moveq #0,d1
        moveq #5,d2
        bsr M4PmAch8
        move.b d0,12(a0)
        moveq #65,d0
        moveq #1,d1
        jsr M4EnSpeedTo
        move.w M4_LP_OUTVZ,d0
        moveq #0,d1
        moveq #3,d2
        jsr M4LpAchase
        move.w d0,M4_LP_OUTVZ
        moveq #0,d0
        rts

; playercred_Istrat 0B:B566 (credits/intro background): $14C4 = 1, lastplayz
; $1701 = 0, $C5 = 0, turnrot 0, gameflags bit0 off, player and pviewpos at
; 0, outvx/outvy 0, outdist = viewdist = 120, viewtype 0, noctrl|nofire,
; space limits, wobble off, no coll/exp, invisible, engine off, speeds 65,
; plrotz 0; 0B:B6EA: space body 0B:E884, viewmove, colldisable, outvz 0,
; plrotz 0, $14CF += 16. Shared by the normal player entry and credit modes.
M4PmCredI:
        move.b #1,M4_PM_14C4
        clr.w TEXT_MAP_CONTEXT+4 ;lastplayz $1701
        clr.w M4_SC_VIEWPOS+4 ;$C5
        clr.w M4_LP_TURNROT
        andi.b #$fe,M4_LP_GAMEFLAGS
        clr.l (a0)
        clr.w 4(a0)
        clr.w M4_LP_OUTVX
        clr.w M4_LP_OUTVY
        move.w #120,M4_LP_OUTDIST
        move.w #120,M4_LP_VIEWDIST
        clr.l M4_LP_PVIEWX
        clr.w M4_LP_PVIEWZ
        clr.b M4_SC_VIEWTYPE
        ori.b #$60,M4_LP_PSF
        lea M4PmLimSpace,a2
        bsr M4PmLimits
        ori.b #$20,M4_LP_GAMEFLAGS
        andi.b #$fb,M4_BOSS_PSTRATF
        ori.b #2,M4_LP_PSF3
        andi.b #$fb,M4_LP_PSF2
        andi.b #$d7,M4_BOSS_PSTRATF
        andi.b #$fe,M4_LP_PSF3
        andi.b #$ef,M4_LP_FLYMODE
        move.l #M4PmCred,32(a0)
        clr.l X_COLL(a0)
        clr.l X_EXP(a0)
        bset #SF_INVISIBLE,49(a0)
        andi.b #$fd,M4_LP_PSF3
        move.b #65,15(a0)
        move.w #65,M4_LP_PVIEWVZ
        move.b #65,M4_LP_MEDSPEED
        move.b #65,M4_LP_TOSPEED
        clr.w M4_LP_PLROTZ
M4PmCred:
        movem.l d0-d7/a1-a3,-(sp)
        move.b M4_LP_PMOVELIMIT,d0 ;0B:E884 (push as in M4PmBodyE913)
        and.b M4_LP_PMOVEAND,d0
        move.w d0,-(sp)
        jsr M4LpMove
        move.w (sp)+,d0
        andi.b #3,d0
        beq.s M4PmCrNoPush
        move.w M4_PM_158F,d0
        add.w d0,(a0)
M4PmCrNoPush:
        moveq #0,d0
        move.b 15(a0),d0
        jsr M4LevelGen3dVecs
        jsr M4LpFrameScale
        bsr M4PmMove
        jsr M4SpLimitX
        jsr M4LpFire
        bsr M4PmArrows
        jsr M4LpViewMove
        bset #SF_COLLDISABLE,49(a0)
        clr.w M4_LP_OUTVZ
        clr.w M4_LP_PLROTZ
        addi.w #16,M4_PM_14CF
        movem.l (sp)+,d0-d7/a1-a3
        bra M4PmFactories

; ClearUnder 0B:A11E -> 0B:A133 (Istrat): noctrl|nofire, no viewrot, minY =
; wing roof = -10000, novdistC|inseq, psvar_word1 $1556 = 194, psvar_word2
; $1558 = 0, tospeed 85; 0B:A18D: y -> -80, x -> 0 (Achase16_3, 1F:D6AB);
; outdist - 500 zero or N -> outdist + 4; outvy += $A9; $1556 counts down,
; then (0B:A1F5) engine off, dupplayer (copy = clshipUNDERboost 06:CFCD,
; M4MbClshipBoostI of level_macbeth.asm, +1E |= $20), 0B:A224; every tick
; the undergnd body 0B:BD05.
M4PmClearUnderI:
        move.l #M4PmClearUnder,32(a0)
        ori.b #$60,M4_LP_PSF
        andi.b #$df,M4_LP_GAMEFLAGS
        move.w #-10000,M4_LP_MINY
        move.w #-10000,M4_PM_157D
        ori.b #$09,M4_BOSS_PSTRATF
        move.w #194,M4_WP_W1556
        clr.w M4_WP_W1558
        move.b #85,M4_LP_TOSPEED
M4PmClearUnder:
        move.w 2(a0),d0
        moveq #-80,d1
        moveq #3,d2
        jsr M4LpAchase
        move.w d0,2(a0)
        move.w (a0),d0
        moveq #0,d1
        jsr M4LpAchase
        move.w d0,(a0)
        move.w M4_LP_OUTDIST,d0
        subi.w #500,d0
        beq.s M4PmCuArm
        bpl.s M4PmCuNoArm
M4PmCuArm:
        addq.w #4,M4_LP_OUTDIST
M4PmCuNoArm:
        addi.w #$a9,M4_LP_OUTVY
        tst.w M4_WP_W1556
        beq.s M4PmCuEnd
        subq.w #1,M4_WP_W1556
        bra M4PmUnderGnd
M4PmCuEnd: ;0B:A1F5
        andi.b #$fd,M4_LP_PSF3
        jsr M4SpDupPlayer ;a2 = copy or 0 (player invisible)
        move.l #M4PmUnderGnd,32(a0) ;0B:A224 = jml 0B:BD05
        move.l a2,d0
        beq M4PmUnderGnd
        move.l #M4MbClshipBoostI,32(a2) ;06:CFCD
        bset #F2_SHADOW,48(a2) ;0B:EA8B +1D |= 8
        bset #F2_SFLAG2,48(a2) ;+1E |= $20
        bra M4PmUnderGnd

; playernull 0B:D05E: pviewvelz = 65, z += 65, pviewposz += 65.
M4PmNull:
        move.w #65,M4_LP_PVIEWVZ
        addi.w #65,4(a0)
        addi.w #65,M4_LP_PVIEWZ
        moveq #0,d0
        rts

; ---------------------------------------------------------------------
; ClearShip2 0B:9ACC -> 0B:9AE1 (Istrat, also newplayerstrat of bg $4B) /
; 0B:9BFA (states on the player's stratstate $1CDC = M4_WP_STATE). Camera
; Fpos|toobj at $C1/$C3/$C5 (M4_SC_VIEWPOS, seeded from the last viewpos).
M4PmClearShip2I:
        ori.b #$60,M4_LP_PSF
        ori.b #8,M4_BOSS_PSTRATF
        move.l #M4PmClearShip2,32(a0)
        move.b #3,M4_SC_VIEWTYPE
        ori.b #1,M4_LP_GAMEFLAGS ;no zremove
        move.b #$5f,M4_SC_P1553
        move.w 46(a0),M4_WP_W1556 ;$1556 = shape
        clr.b 12(a0)
        clr.b 13(a0)
        clr.b 14(a0)
        clr.w (a0)
        move.w #-60,2(a0)
        move.l M4_LVW_POS,M4_SC_VIEWPOS ;$C1/$C3 of the last getview
        move.w 4(a0),d0
        addi.w #$728,d0
        move.w d0,M4_SC_VIEWPOS+4
        subi.w #20,M4_SC_VIEWPOS
        lea M4PmLimClear,a2
        bsr M4PmLimits
        andi.b #$df,M4_LP_GAMEFLAGS
        andi.b #$fb,M4_BOSS_PSTRATF
        ori.b #2,M4_LP_PSF3
        andi.b #$fe,M4_LP_PSF3
        ori.b #$20,M4_BOSS_PSTRATF
M4PmClearShip2:
        tst.b M4_WP_STATE
        bne.s M4PmCs1
        subq.b #1,M4_SC_P1553
        bne.s M4PmCs1
        moveq #0,d0 ;black ship by the broken wings (06:80FD table)
        move.b M4_LP_PSF,d1
        andi.b #$18,d1
        beq.s M4PmCsShape
        moveq #2,d0
        cmpi.b #$08,d1
        beq.s M4PmCsShape
        moveq #4,d0
        cmpi.b #$10,d1
        beq.s M4PmCsShape
        moveq #6,d0
M4PmCsShape:
        lea M4PmCsShapes,a2
        move.w (a2,d0.w),d0
        jsr M4LevelShapeIndex
        jsr M4LevelSetShape
        move.b #15,M4_SC_P1553
        addq.b #1,M4_WP_STATE
M4PmCs1:
        cmpi.b #1,M4_WP_STATE
        bne.s M4PmCs2
        subq.b #1,M4_SC_P1553
        bne.s M4PmCs2
        move.w M4_WP_W1556,d0
        jsr M4LevelSetShape
        ;$16A0 = $FE (no port consumer)
        addq.b #1,M4_WP_STATE
        move.b #200,M4_SC_P1553
M4PmCs2:
        cmpi.b #2,M4_WP_STATE
        bne.s M4PmCs3
        addi.w #10,M4_SC_VIEWPOS+4
        subq.b #1,M4_SC_P1553
        bne.s M4PmCs3
        ;+1E |= $80 (sflags2 bit7: no port consumer)
        move.b #2,M4_SC_VIEWTYPE
        andi.b #$fd,M4_LP_PSF3 ;engine off
        jsr M4LevelBoostFlame ;boostobj = player, flame 06:8671
        addq.b #1,M4_WP_STATE ;sound $32 not ported
        move.b #$55,M4_SC_P1553
M4PmCs3:
        cmpi.b #3,M4_WP_STATE
        bne.s M4PmCsAll
        addi.w #10,M4_SC_VIEWPOS+4
        addi.w #100,4(a0)
        subq.b #1,M4_SC_P1553
        bne.s M4PmCsAll
        ori.b #$80,M4_LP_GAMEFLAGS
M4PmCsAll: ;0B:9D2D
        addi.w #65,4(a0)
        addi.w #50,M4_SC_VIEWPOS+4
        move.w M4_SC_VIEWPOS+2,d0
        cmpi.w #-200,d0
        bmi.s M4PmCsDone
        subq.w #1,M4_SC_VIEWPOS+2
M4PmCsDone:
        moveq #0,d0
        rts
M4PmCsShapes: ;06:80FD bmyship_4/_l/_r/_lr
        include '../build/m4-pm-clear-shapes.inc'
M4PmLimClear: ;0B:9B59..9BC7
        include '../build/m4-flight-clear.inc'
        even

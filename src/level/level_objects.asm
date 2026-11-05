; Level objects: own pool with the original alien semantics needed so far.
; Context (64 bytes; the first 32 match the intro draw/geometry layout):
;  0 x.w  2 y.w  4 z.w  6 vx.w  8 vy.w  10 vz.w  12 rotx  13 roty  14 rotz
; 15 vel  16 animframe ($1CE7, geometry frame for kinds>=14)  17 collcount
; 18 colframe ($1CE6; elaser2a frame)  19 count ($0A)  20 hitflags
; 21 draw kind (descriptor svp model + 2, 0 = not drawn)  22 alive.w
; 25 bit0 afexp  26 birth.w  28 immune.w  30 flags.w (bit2 hit flash)
; 32 strategy.l (68000 routine, 0 = none)  36 sbyte1 ($22)  37 sbyte2 ($23)
; 38 HP ($2A)  39 AP ($2B)  40 sword1.w ($26)  42 path.w ($28)
; 44 collflags ($2E)  45 al_type ($09)  46 descriptor index.w ($FFFF =
; nullshape)  48 port flags2 (F2_*)  49 sflags (bit0 colldisable,
; bit1 invisible, bit2 special, bit3 collide, bit4 Lcollide, bit5
; nohitaffect, bit6 sameshape, bit7 hitflash)  50 free  51 al_flags ($08:
; bit2 afLeftPl, bit3 afFrontPl, bit4 afInviewPl)  52 order.w (sequence)
; 54 speed2 ($24)  56 x.w 58 y.w 60 z.w view coordinates (rel.W)
; 62 collobj.w
; Extended block at object-$8000 ($FF6000.., free during the level: intro
; background decode area), same 64-byte stride:
X_NEXT equ -$8000+0 ;.w allst link (low address word, 0 = end)
X_COLL equ -$8000+2 ;.l collstrat routine ($1CD3) or 0
X_EXP equ -$8000+6 ;.l expstrat routine ($1CD0) or 0
X_ALPTR equ -$8000+10 ;.w al_ptr ($06): object (low word) or integer
X_SWORD2 equ -$8000+12 ;.w ($28)
X_WPX equ -$8000+14 ;.w sWPx1 ($1CCA)
X_WPY equ -$8000+16 ;.w sWPy1
X_WPZ equ -$8000+18 ;.w sWPz1
X_COUNT1 equ -$8000+20 ;.b ($0B)
X_SBYTE3 equ -$8000+21 ;.b ($24 sbyte3)
X_SBYTE4 equ -$8000+22 ;.b
X_TX equ -$8000+23 ;.b sprite texture offset ($1CF4, visual only)
; X_ offsets in use: 24-26 level_scramble, 27-29 level_paths (TEXTFL, COLTAB),
; 30-31 X_SHAPEHDR, 56-57 X_DEBRIS, 58-59 level_asteroid, 60 X_TY, 62-63 X_W2F. Second extended block at object-$7000
; ($FF7000.., same stride): path interpreter state (level_paths.asm), X2_*.
; Port flags2 byte 48: original bits spread over sflags2/3/4.
F2_SFLAG1 equ 0 ;sflags2 $10
F2_SFLAG2 equ 1 ;sflags2 $20
F2_RELEXPLODE equ 2 ;sflags4 $04 (follows the player: z += pviewvelz)
F2_NOEXPSND equ 3 ;sflags2 $08
F2_NOPOLYEXP equ 4 ;sflags3 $40
F2_CSPECIAL equ 5 ;sflags4 $80
F2_SHADOW equ 6 ;sflags $08 (shadow not drawn yet)
F2_SPRITE equ 7 ;sflags $20 (ssprite)
AF_LEFTPL equ 2
AF_FRONTPL equ 3
AF_INVIEWPL equ 4
; Strategy calling convention: a0 = object, a1 = player; d0 = 0 keep,
; nonzero = remove (deferred removal of the current object, 1F:D501 with
; x == al1pt). Routines may clobber d0-d7/a2-a4.
M4_LV_OBJ equ $ffe000
M4_LV_EXT equ M4_LV_OBJ-$8000
M4_LV_EXT2 equ M4_LV_OBJ-$7000
M4_LV_SLOTS equ 64
M4_LV_COUNT equ $fff100 ;.w live objects
M4_LV_SEQ equ $fff102 ;.w creation sequence
M4_LV_SKILLFLY equ $fff104 ;.b 7E:F0B7 arch counter
M4_LV_SKIPPED equ $fff106 ;.w script objects with no ported strategy
M4_LV_LAST equ $fff108 ;.l last created object (setalvar/mapsetpath target)
M4_LV_HEAD equ $fff190 ;.w allst head ($121F)
M4_LV_CREATOR equ $fff192 ;.l object running its strategy (al1pt) or 0
AT_ZREMOVE equ 8
LV_PLAYER equ M4_LV_OBJ

M4LevelObjectsInit:
        jsr M4SoundStopLoops ;scene/restart: release continuous voices before clearing their objects
        lea M4_LV_OBJ,a0
        move.w #M4_LV_SLOTS*16-1,d0
M4LvClear:
        clr.l (a0)+
        dbra d0,M4LvClear
        lea M4_LV_EXT,a0
        move.w #M4_LV_SLOTS*16*2-1,d0 ;both extended blocks (contiguous)
M4LvClearExt:
        clr.l (a0)+
        dbra d0,M4LvClearExt
        clr.l M4_LV_COUNT
        clr.l M4_LV_SKILLFLY
        clr.l M4_LV_LAST
        move.w #LV_PLAYER&$ffff,M4_LV_HEAD ;player: first object, head of allst
        clr.l M4_LV_CREATOR
        jsr M4SoundObjectsClear
        rts

; Allocate a slot (never slot 0: player). Returns a0 (0 when full).
; 1F:D36E/D3A9: cleared, atzremove, firstframe, collcount 1; linked at the
; head of allst, or right after the object running its strategy (so it runs
; in this same traversal, behind its creator).
M4LevelAlloc:
        movem.l d0-d1/a1-a2,-(sp)
        lea M4_LV_OBJ+64,a0
        moveq #M4_LV_SLOTS-2,d0
M4LvAllocFind:
        tst.w 22(a0)
        beq.s M4LvAllocFound
        lea 64(a0),a0
        dbra d0,M4LvAllocFind
        suba.l a0,a0
        bra.w M4LvAllocReturn
M4LvAllocFound:
        jsr M4SoundObjectClear
        moveq #15,d1
        movea.l a0,a1
        lea X_NEXT(a0),a2
M4LvAllocClear:
        clr.l (a1)+
        clr.l $1000(a2) ;X2 block (same slot, object-$7000)
        clr.l (a2)+
        dbra d1,M4LvAllocClear
        move.w #1,22(a0)
        move.w #$ffff,46(a0)
        move.b #AT_ZREMOVE,45(a0)
        addq.w #1,M4_LV_SEQ
        move.w M4_LV_SEQ,52(a0)
        move.w M4_SCENE_TICK,26(a0)
        move.b #CF_FIRSTFRAME,44(a0) ;acf_firstframe until its first Do_strat
        move.b #1,17(a0) ;collcount
        bset #3,X2_FL3(a0) ;1F:D36E: sflags3 |= $08 realobj (clearrealobjmap_l 1F:D3FD)
        ori.b #1<<AF_INVIEWPL,51(a0) ;1F:D36E sets inview
        addq.w #1,M4_LV_COUNT
        move.l a0,M4_LV_LAST
        move.l M4_LV_CREATOR,d0
        beq.s M4LvAllocHead
        movea.l d0,a1
        move.w X_NEXT(a1),X_NEXT(a0)
        move.w a0,X_NEXT(a1)
        bra.s M4LvAllocReturn
; No creator (map objects 03:F767: ldx $121F; txy): linked right after the
; head object, i.e. the player, which was created first and stays the head
; (WRAM probe: allst = player, newest map object, ..., the player's own
; objects). An empty list takes it as the head.
M4LvAllocHead:
        move.w M4_LV_HEAD,d0
        beq.s M4LvAllocEmpty
        movea.w d0,a1
        move.w X_NEXT(a1),X_NEXT(a0)
        move.w a0,X_NEXT(a1)
        bra.s M4LvAllocReturn
M4LvAllocEmpty:
        move.w a0,M4_LV_HEAD
M4LvAllocReturn:
        move.l a0,d0
        movem.l (sp)+,d0-d1/a1-a2
        rts

; Remove a0 (1F:D501/removedeadal 1F:BFDC): unlink from allst and clear
; immuneptr, al_ptr and collobjptr of every object that points to it.
M4LevelRemove:
        movem.l d0-d1/d7/a1,-(sp)
        tst.w 22(a0)
        beq.s M4LvRemoveDone
        clr.w 22(a0)
        btst #4,X2_FL4(a0) ;divorcefamily 1F:DBA4, child branch (mother branch PEND)
        beq.s M4LvRemoveNotChild
        movem.l d0-d1/a2-a3,-(sp)
        movea.l a0,a2
        jsr M4PvDivorce
        movem.l (sp)+,d0-d1/a2-a3
M4LvRemoveNotChild:
        subq.w #1,M4_LV_COUNT
        move.w a0,d1
        lea M4_LV_HEAD-X_NEXT,a1 ;pseudo object whose X_NEXT is the head
M4LvRemoveFind:
        move.w X_NEXT(a1),d0
        beq.s M4LvRemoveRefs
        cmp.w d0,d1
        beq.s M4LvRemoveLink
        movea.w d0,a1
        bra.s M4LvRemoveFind
M4LvRemoveLink:
        move.w X_NEXT(a0),X_NEXT(a1)
M4LvRemoveRefs:
        lea M4_LV_OBJ,a1
        moveq #M4_LV_SLOTS-1,d7
M4LvRemoveRef:
        cmp.w 28(a1),d1
        bne.s M4LvRemoveRef1
        clr.w 28(a1)
M4LvRemoveRef1:
        cmp.w 62(a1),d1
        bne.s M4LvRemoveRef2
        clr.w 62(a1)
M4LvRemoveRef2:
        cmp.w X_ALPTR(a1),d1
        bne.s M4LvRemoveRef3
        clr.w X_ALPTR(a1)
M4LvRemoveRef3:
        lea 64(a1),a1
        dbra d7,M4LvRemoveRef
        cmpa.l M4_LV_LAST,a0
        bne.s M4LvRemoveDone
        clr.l M4_LV_LAST
M4LvRemoveDone:
        movem.l (sp)+,d0-d1/d7/a1
        rts

; d0 = descriptor index (level shape or M4_FX_*) or $FFFF (nullshape).
; Draw kind = min(svp model + 2,255) ($FFFF svp: not drawn).
; Models above 253 use the descriptor's WORD in M4IntroEffectMesh; the
; byte remains a nonzero polygon marker for sorting/shadows/sprites.
M4LevelSetShape:
        movem.l d0/a3,-(sp)
        move.w d0,46(a0)
        clr.b 21(a0)
        cmpi.w #$ffff,d0
        beq.s M4LvShapeDone
        lsl.w #5,d0
        lea M4LevelShapeDescriptors,a3
        move.w 14(a3,d0.w),d0
        cmpi.w #$ffff,d0
        beq.s M4LvShapeDone
        addq.w #2,d0
        cmpi.w #255,d0
        bls.s M4LvShapeKind
        move.w #255,d0
M4LvShapeKind:
        move.b d0,21(a0)
M4LvShapeDone:
        movem.l (sp)+,d0/a3
        rts

; Collision/explosion strategy pairs (set_normcollptrs 1F:D41A, 1F:D450).
M4LvNormPtrs:
        move.l #M4LcHitFlash,X_COLL(a0)
        move.l #M4LevelExplode,X_EXP(a0)
        rts
M4LvZeroPtrs:
        clr.l X_COLL(a0)
        clr.l X_EXP(a0)
        rts

; ---------------------------------------------------------------------
; Strategies (Istrat runs on the creation tick, then the tick routine).
; GSTRATS.ASM nocoll_Istrat 06:873F: colldisable, no strategy.
M4StratNoColl:
        bset #0,49(a0)
        clr.l 32(a0)
        moveq #0,d0
        rts
; hard_Istrat 06:8599: s_hardvars (HP $FF, AP hardAP 8), no strategy.
M4StratHard:
        move.b #$ff,38(a0)
        move.b #8,39(a0)
        clr.l 32(a0)
        moveq #0,d0
        rts
; hard180YR_Istrat 06:85B9: colltype enemy1, roty deg180, hardvars.
M4StratHard180YR:
        ori.b #CF_ENEMY1,44(a0) ;colltype enemy1
        move.b #$80,13(a0)
        bra.s M4StratHard
; rader1_Istrat 08:B194: colltype enemy1 then hard_Istrat.
M4StratRader1:
        ori.b #CF_ENEMY1,44(a0)
        bra.s M4StratHard
; tower0_Istrat 08:B176: HP hardHP, AP hardAP/2; tower0_strat roty += 8.
M4StratTower0:
        move.b #$ff,38(a0)
        move.b #4,39(a0)
        move.l #M4StratTower0Tick,32(a0)
M4StratTower0Tick:
        addq.b #8,13(a0)
        moveq #0,d0
        rts
; skillfly_istrat 09:F856 (DSTRATS.ASM): invisible counter on the arches.
M4StratSkillFly:
        bset #0,49(a0)
        cmpi.w #$ffff,46(a0)
        bne.s M4SkillVisible
        bset #1,49(a0)
M4SkillVisible:
        move.l #M4StratSkillFlyTick,32(a0)
        addq.b #1,M4_LV_SKILLFLY
        tst.w 40(a0)
        bne.s M4StratSkillFlyTick
        move.w #20<<2,40(a0)
M4StratSkillFlyTick:
        ; 09:F899: |pz - z| < 200 (09:80AB, N flag), then d = |dx| + |dy|
        ; (1F:D115, 16 bits): !N(d) and N(d - sword1) -> passed (dec F0B7).
        move.w 4(a1),d0
        sub.w 4(a0),d0
        bpl.s M4SkillDz
        neg.w d0
M4SkillDz:
        subi.w #200,d0
        bpl.s M4SkillNorm
        move.w (a1),d0
        sub.w (a0),d0
        bpl.s M4SkillDx
        neg.w d0
M4SkillDx:
        move.w 2(a1),d1
        sub.w 2(a0),d1
        bmi.s M4SkillDyNeg
        add.w d1,d0
        bra.s M4SkillDxy
M4SkillDyNeg:
        sub.w d1,d0
M4SkillDxy:
        tst.w d0
        bmi.s M4SkillNorm
        sub.w 40(a0),d0
        bpl.s M4SkillNorm
        subq.b #1,M4_LV_SKILLFLY
        moveq #1,d0
        rts
M4SkillNorm:
        ; 09:F8D5: removed (no dec) when !N(pz - (z + 1000)), equality too
        move.w 4(a1),d0
        sub.w 4(a0),d0
        subi.w #1000,d0
        bpl.s M4SkillRemove
        moveq #0,d0
        rts
M4SkillRemove:
        moveq #1,d0
        rts

; Strategy table: original 24-bit address -> Istrat routine. Unlisted
; strategies are not created (counted in M4_LV_SKIPPED): no invented behaviour.
M4LevelStrategies:
        dc.l $06873f,M4StratNoColl
        dc.l $068599,M4StratHard
        dc.l $0685b9,M4StratHard180YR
        dc.l $08b194,M4StratRader1
        dc.l $08b176,M4StratTower0
        dc.l $09f856,M4StratSkillFly
        dc.l $08b19e,M4StratRader0
        dc.l $0a8790,M4StratHard90YR
        dc.l $08b1cb,M4StratZaco1L
        dc.l $08b1db,M4StratZaco1R
        dc.l $08ac8b,M4StratZacos
        dc.l $0a8004,M4StratZaco4
        dc.l $098aa4,M4StratPillar3
        dc.l $0ae817,M4StratGate3
        dc.l $0997da,M4StratGate
        dc.l $08ddec,M4StratItem7
        dc.l $08d556,M4StratItem5
        dc.l $08d414,M4StratBomwing
        dc.l $048022,M4PathIstrat
        dc.l $048004,M4PathIstratDha
        dc.l $07cf7c,M4StratBoss7
        dc.l $08f15d,M4StratGnd ;SCRAMBLE tunnel pieces
        dc.l $078673,M4StratShipIntro
        dc.l $078137,M4StratFriendExitBase
        dc.l $06bf90,M4StratClshipA ;cl_ground friends' ships
        dc.l $06bfdf,M4StratClshipB
        dc.l $06c02e,M4StratClshipC
        dc.l $0af7a6,M4StratPilon ;training groundpilon
        dc.l $04f5b3,M4StratMother ;generators (mapmother, Asteroid 1)
        dc.l $099337,M4StratSlowMeteor
        dc.l $099387,M4StratMeteor
        ; Asteroid Belt 1 (level_asteroid.asm, build/agent-asteroid/ASTEROID_STRATS.md)
        dc.l $00fa62,M4StratBigMeteor
        dc.l $00faa5,M4StratBreakMeteor
        dc.l $00faba,M4StratBreakMeteorT
        dc.l $0ad5f1,M4StratShou0a
        dc.l $0ad5f7,M4StratShou0
        dc.l $0aa4ef,M4StratSzaco0
        dc.l $0aa197,M4StratSzaco2
        dc.l $08cad1,M4StratWormHead
        dc.l $08cb12,M4StratWorm
        dc.l $0995a1,M4StratCameleon
        dc.l $08b93f,M4StratCameleon2
        dc.l $0aeede,M4StratTadpole ;also path setstrat (45AB)
        dc.l $09f967,M4StratSpacePilon
        dc.l $0ade06,M4StratBlackhole
        dc.l $06f7e6,M4StratParticles ;debris aux / path particle 04:9DE4
        dc.l $0ae8b7,M4StratGate2 ;path setstrat gate2 (4341)
        dc.l 0

; d0.l = original strategy address. Returns a2 = Istrat or 0. Searches the
; tables of M4LevelStrategyTables in order (one per unit/stage file).
M4LevelFindStrategy:
        move.l a3,-(sp)
        lea M4LevelStrategyTables,a3
M4LvStratTable:
        move.l (a3)+,d1
        beq.s M4LvStratNone
        movea.l d1,a2
M4LvStratFind:
        move.l (a2)+,d1
        beq.s M4LvStratTable
        cmp.l d1,d0
        beq.s M4LvStratFound
        addq.l #4,a2
        bra.s M4LvStratFind
M4LvStratFound:
        movea.l (a2),a2
        movea.l (sp)+,a3
        rts
M4LvStratNone:
        suba.l a2,a2
        movea.l (sp)+,a3
        rts
; Strategy tables (address.l, Istrat.l; 0 ends each table). A stage file adds
; its own table here.
M4LevelStrategyTables:
        dc.l M4LevelStrategies
        dc.l M4LevelStrategies2 ;level_warp.asm
        dc.l M4StrategiesSpaceArmada ;level_armada.asm
        dc.l M4StrategiesMeteor ;level_meteor.asm
        dc.l M4StrategiesVenom ;level_venom.asm
        dc.l M4StrategiesCorneria2 ;level_corneria23.asm
        dc.l M4StrategiesTitania ;level_titania.asm
        dc.l M4StrategiesMacbeth ;level_macbeth.asm
        dc.l M4StrategiesSectors ;level_sectors.asm
        dc.l M4StrategiesSpaceMisc ;level_spacemisc.asm
        dc.l M4StrategiesVenom23 ;level_venom23.asm
        dc.l M4StrategiesEnding ;level_ending.asm
        dc.l 0

; Do_strat_l 1F:D26B over allst from $121F (06:8040): the player is the head
; and runs first; then the map objects, newest first.
; Objects created by a strategy are linked
; right after their creator and run in this same traversal; the next object
; is read after the strategy returns.
M4LevelObjectsTick:
        movem.l d0-d7/a0-a6,-(sp)
        move.l M4_LV_LAST,-(sp) ;lastobj $16F9: only map handlers write it
        move.w M4_LV_HEAD,d0
M4LvTickNext:
        tst.w d0
        beq.s M4LvTickDone
        movea.w d0,a0
        move.l a0,M4_LV_CREATOR
        lea LV_PLAYER,a1
        jsr M4LevelDoStrat
        clr.l M4_LV_CREATOR
        move.w X_NEXT(a0),d1
        tst.w d0
        beq.s M4LvTickKeep
        jsr M4LevelRemove
M4LvTickKeep:
        move.w d1,d0
        bra.s M4LvTickNext
M4LvTickDone:
        move.l (sp)+,M4_LV_LAST
        movem.l (sp)+,d0-d7/a0-a6
        rts

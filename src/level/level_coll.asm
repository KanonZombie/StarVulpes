; Level collisions (research: build/research/collision-damage-hud.md).
; generate_collist_l 1F:C03D + init_strats_ram_l 02:9DBC / chkcoll 02:9E14..
; A5EE: run at the end of the tick (after the draw), consumed by the
; strategies of the NEXT tick (Do_strat_l 1F:D26B). World-space AABB per
; axis Z, X, Y on 16 bits: |dB-A| < eA+eB, decided by the N bit of the
; 16-bit subtraction (abs($8000) stays $8000). Box offsets of a colbox list
; rotate as bytes (rotate_8xz/yx/yz, 8-bit tables 7E:5C6C/5CAC = 00:98A5),
; sign-extend and scale << (rotflags & 15); extents never rotate or scale.
; Object fields (level_objects.asm): 17 collcount ($2D), 20 hitflags ($35),
; 28 immune (low WORD address, $19), 44 collflags ($2E), 48 sflags (port
; bits: 0 colldisable, 1 invisible, 2 special, 3 collide, 4 Lcollide,
; 5 nohitaffect, 6 sameshape, 7 hitflash), 25 bit0 afexp,
; 62 collobj (low WORD address, 0 = wall/ground).
CF_FIRSTFRAME equ $04
CF_LASER equ $08
CF_ENEMY1 equ $10
CF_FRIEND equ $80
SF_COLLDISABLE equ 0
SF_INVISIBLE equ 1
SF_SPECIAL equ 2
SF_COLLIDE equ 3
SF_LCOLLIDE equ 4
SF_NOHITAFFECT equ 5
SF_SAMESHAPE equ 6
SF_HITFLASH equ 7
M4_LC equ $fff400
M4_LC_COUNT equ M4_LC+0 ;.w candidates
M4_LC_LIST equ M4_LC+2 ;64 LONG object pointers (allst order: newest first)
M4_LC_POS equ M4_LC+258 ;3 WORDs box position of A
M4_LC_EXT equ M4_LC+264 ;3 WORDs box extents of A
M4_LC_FLAGSET equ M4_LC+270 ;.b flagset of the current box of A
M4_LC_BPOS equ M4_LC+272 ;3 WORDs box position of B
M4_LC_BEXT equ M4_LC+278 ;3 WORDs
M4_LC_HITB equ M4_LC+284 ;.b accumulated flagset of B
M4_LC_PAIRS equ M4_LC+286 ;.w pair tests this pass (diagnostic)

; a0 object -> a3 descriptor of its shape (or 0 for nullshape).
M4LcDescriptor:
        move.w 46(a0),d0
        cmpi.w #$ffff,d0
        beq.s M4LcNoShape
        mulu.w #32,d0
        lea M4LevelShapeDescriptors,a3
        adda.l d0,a3
        rts
M4LcNoShape:
        suba.l a3,a3
        rts

; End-of-tick pass. Objects visited newest first (allst order).
M4LevelCollisions:
        if def(M4_GRAPHICS117)
        jmp G117H106Collision
        nop
        nop
        else
        movem.l d0-d7/a0-a6,-(sp)
        clr.w M4_LC_PAIRS
        endif
M4LevelCollisionsBody:
        ; reset per object: collide -> Lcollide, else collcount = 1
        lea M4_LV_OBJ,a0
        moveq #M4_LV_SLOTS-1,d7
M4LcReset:
        tst.w 22(a0)
        beq.s M4LcResetNext
        bclr #SF_COLLIDE,49(a0)
        beq.s M4LcResetNoHit
        bset #SF_LCOLLIDE,49(a0)
        bra.s M4LcResetPtr
M4LcResetNoHit:
        move.b #1,17(a0)
M4LcResetPtr:
        clr.w 62(a0)
M4LcResetNext:
        lea 64(a0),a0
        dbra d7,M4LcReset
        ; body/wing states: no contact last pass -> collcount 1
        btst #0,M4_LP_PARTCOLL
        bne.s M4LcResetLW
        move.b #1,M4_LP_BODYCC
M4LcResetLW:
        btst #1,M4_LP_PARTCOLL
        bne.s M4LcResetRW
        move.b #1,M4_LP_LWCC
M4LcResetRW:
        btst #2,M4_LP_PARTCOLL
        bne.s M4LcResetParts
        move.b #1,M4_LP_RWCC
M4LcResetParts:
        clr.b M4_LP_PARTCOLL
        ; candidates: !firstframe, !colldisable, HP != 0, !afexp
        jsr M4LcOrder
        lea M4_LC_LIST,a1
        moveq #0,d6
M4LcBuild:
        move.l (a2)+,d0
        beq.s M4LcBuildDone
        movea.l d0,a0
        btst #2,44(a0)
        bne.s M4LcBuild
        btst #SF_COLLDISABLE,49(a0)
        bne.s M4LcBuild
        tst.b 38(a0)
        beq.s M4LcBuild
        btst #0,25(a0)
        bne.s M4LcBuild
        cmpi.w #$ffff,46(a0)
        beq.s M4LcBuild ;no shape: no box
        move.l a0,(a1)+
        addq.w #1,d6
        bra.s M4LcBuild
M4LcBuildDone:
        if def(M4_GRAPHICS117)
        jmp G117H117Cache
        else
        move.w d6,M4_LC_COUNT
        endif
M4LcBuildDoneBody:
        ; pairs
        lea M4_LC_LIST,a5
        move.w M4_LC_COUNT,d7
        subq.w #2,d7
        bmi M4LcDone
M4LcOuter:
        movea.l (a5)+,a0 ;A
        btst #SF_COLLIDE,49(a0)
        bne.s M4LcOuterNext
        jsr M4LcDescriptor
        movea.l 28(a3),a4 ;box list or 0
        move.l a4,d0
        bne.s M4LcOuterList
        move.l (a0),M4_LC_POS
        move.w 4(a0),M4_LC_POS+4
        move.l 20(a3),M4_LC_EXT
        move.w 24(a3),M4_LC_EXT+4
        clr.b M4_LC_FLAGSET
        jsr M4LcSweep
        bra.s M4LcOuterNext
M4LcOuterList:
        move.w (a4)+,d5
        bmi.s M4LcOuterAnim
        btst #14,d5
        beq.s M4LcOuterCount
        move.b 16(a0),d0
        bsr M4LcFrameList ;mixed animated list (base_0)
        bra.s M4LcOuterCount
M4LcOuterAnim:
        moveq #15,d0 ;animated list: box of frame animframe & 15
        and.b 16(a0),d0
        lsl.w #4,d0
        adda.w d0,a4
        moveq #1,d5
M4LcOuterCount:
        subq.w #1,d5
M4LcOuterBox:
        jsr M4LcBoxPos ;a4 box of a0 -> M4_LC_POS/EXT/FLAGSET
        jsr M4LcSweep
        lea 16(a4),a4
        dbra d5,M4LcOuterBox
M4LcOuterNext:
        dbra d7,M4LcOuter
M4LcDone:
        movem.l (sp)+,d0-d7/a0-a6
        rts

; a5 -> remaining list after A (count d7+1 entries), A in a0.
M4LcSweep:
        if def(M4_GRAPHICS117)
        jmp G117H117Dispatch
M4LcSweepNext equ *-2 ;unreachable original loop keeps its Sweep+4 target
        else
        movem.l d5-d7/a4-a5,-(sp)
M4LcSweepNext:
        movea.l (a5)+,a1 ;B
        endif
        btst #SF_COLLIDE,49(a1)
        bne M4LcSweepSkip
        move.b 44(a0),d0
        and.b 44(a1),d0
        andi.b #$f8,d0
        bne M4LcSweepSkip
        move.w a1,d0
        cmp.w 28(a0),d0
        beq M4LcSweepSkip
        move.w a0,d0
        cmp.w 28(a1),d0
        beq M4LcSweepSkip
        move.w 46(a0),d0
        cmp.w 46(a1),d0
        bne.s M4LcShapeOk
        btst #SF_SAMESHAPE,49(a0)
        beq M4LcSweepSkip
        btst #SF_SAMESHAPE,49(a1)
        beq M4LcSweepSkip
M4LcShapeOk:
        addq.w #1,M4_LC_PAIRS
        exg a0,a1
        jsr M4LcDescriptor
        exg a0,a1
        move.l (a1),M4_LC_BPOS
        move.w 4(a1),M4_LC_BPOS+4
        move.l 20(a3),M4_LC_BEXT
        move.w 24(a3),M4_LC_BEXT+4
        jsr M4LcAabb ;broad phase / single box
        bne M4LcSweepSkip
        clr.b M4_LC_HITB
        move.l 28(a3),d0
        beq M4LcImpact
        movea.l d0,a4
        move.w (a4)+,d6
        bmi.s M4LcBAnim
        btst #14,d6
        beq.s M4LcBCount
        exg d5,d6
        move.b 16(a1),d0
        bsr M4LcFrameList ;mixed animated list (base_0)
        exg d5,d6
        bra.s M4LcBCount
M4LcBAnim:
        moveq #15,d0
        and.b 16(a1),d0
        lsl.w #4,d0
        adda.w d0,a4
        moveq #1,d6
M4LcBCount:
        subq.w #1,d6
        movem.l M4_LC_POS,d0-d2 ;save A box (POS, EXT; 12 bytes)
        movem.l d0-d2,-(sp)
        move.b M4_LC_FLAGSET,-(sp)
M4LcBBox:
        exg a0,a1
        jsr M4LcBoxPos
        exg a0,a1
        move.l M4_LC_POS,M4_LC_BPOS
        move.w M4_LC_POS+4,M4_LC_BPOS+4
        move.l M4_LC_EXT,M4_LC_BEXT
        move.w M4_LC_EXT+4,M4_LC_BEXT+4
        move.b M4_LC_FLAGSET,d1
        movem.l 2(sp),d0/d2/d3
        movem.l d0/d2/d3,M4_LC_POS
        jsr M4LcAabb
        bne.s M4LcBBoxNext
        or.b d1,M4_LC_HITB
M4LcBBoxNext:
        lea 16(a4),a4
        dbra d6,M4LcBBox
        move.b (sp)+,M4_LC_FLAGSET
        movem.l (sp)+,d0-d2
        movem.l d0-d2,M4_LC_POS
        tst.b M4_LC_HITB
        beq.s M4LcSweepSkip
M4LcImpact:
        bset #SF_COLLIDE,49(a0)
        move.w a1,62(a0)
        bset #SF_COLLIDE,49(a1)
        move.w a0,62(a1)
        move.b M4_LC_HITB,d0
        or.b d0,20(a1)
        move.b M4_LC_FLAGSET,d0
        or.b d0,20(a0)
        bra.s M4LcSweepDone ;one collision per object and pass
M4LcSweepSkip:
        dbra d7,M4LcSweepNext
M4LcSweepDone:
        movem.l (sp)+,d5-d7/a4-a5
        rts

; Z, X, Y: r = eA + eB (16-bit), d = |B - A| (abs($8000)=$8000),
; (d - r) N clear -> no collision. Returns Z set on collision.
M4LcAabb:
        if def(M4_GRAPHICS117)
        jmp G117H106AabbDispatch
        else
        movem.l d0-d3,-(sp)
        moveq #4,d3
        endif
M4LcAabbBody:
        bsr.s M4LcAxis
        bne.s M4LcAabbOut
        moveq #0,d3
        bsr.s M4LcAxis
        bne.s M4LcAabbOut
        moveq #2,d3
        bsr.s M4LcAxis
M4LcAabbOut:
        movem.l (sp)+,d0-d3
        rts
M4LcAxis:
        lea M4_LC_POS,a6
        move.w M4_LC_EXT-M4_LC_POS(a6,d3.w),d0
        add.w M4_LC_BEXT-M4_LC_POS(a6,d3.w),d0
        move.w M4_LC_BPOS-M4_LC_POS(a6,d3.w),d1
        sub.w (a6,d3.w),d1
        bpl.s M4LcAxisAbs
        neg.w d1
M4LcAxisAbs:
        sub.w d0,d1
        bmi.s M4LcAxisHit
        moveq #1,d0 ;Z clear: separated
        rts
M4LcAxisHit:
        moveq #0,d0 ;Z set: overlapping on this axis
        rts

; a0 object, a4 box record -> M4_LC_POS (world + offset), EXT, FLAGSET.
; COLDET.ASM: rotflags bit4 rotz (x,y by rotz), bit5 roty (x,z by -roty),
; bit6 rotx (y,z by rotx), bit7 all (z, x, y); rotated components are bytes,
; sign-extended and scaled << (rotflags & 15); others are full WORDs.
; Mixed animated list (tools/generate-level-shapes.py MIXED_ANIMATED_COLBOX: dc.w $4000+n, n offsets,
; n flat lists). 02:9E41..9E6E: k = (animframe if its bit 7 is set, else gameframe $15BD) & (n - 1).
; In: a4 after the count WORD, d5 = $4000+n, d0.b = animframe. Out: a4 first box, d5 count. d0 lost.
M4LcFrameList:
        tst.b d0
        bmi.s M4LcFrameAf
        move.b M4_LV_GAMEFRAME+1,d0
M4LcFrameAf:
        andi.w #$ff,d0
        subq.b #1,d5
        and.b d5,d0
        add.w d0,d0
        move.w (a4,d0.w),d0
        lea -2(a4,d0.w),a4
        move.w (a4)+,d5
        rts

M4LcBoxPos:
        movem.l d0-d7/a1,-(sp)
        move.w (a4),d1 ;xoff
        move.w 2(a4),d2 ;yoff
        move.w 4(a4),d3 ;zoff
        move.w 6(a4),d7 ;rotflags
        move.w d7,d6
        andi.w #15,d6 ;scale
        btst #4,d7
        bne.s M4LcRotZ
        btst #5,d7
        bne.s M4LcRotY
        btst #6,d7
        bne M4LcRotX
        btst #7,d7
        bne M4LcRotAll
        bra M4LcBoxStore
M4LcRotZ: ;rotate_8yx (rotz, not negated): x' = m(x,c)+m(y,s), y' = -m(x,s)+m(y,c)
        moveq #0,d0
        move.b 14(a0),d0
        bsr M4LcRotPair ;d1=x, d2=y
        bsr M4LcScale12
        bra.s M4LcBoxStore
M4LcRotY: ;rotate_8xz (angle -roty): x' = m(x,c)+m(z,s), z' = -m(x,s)+m(z,c)
        moveq #0,d0
        move.b 13(a0),d0
        neg.b d0
        move.w d2,d4 ;y unrotated, unscaled
        move.w d3,d2
        bsr M4LcRotPair ;d1=x, d2=z
        bsr M4LcScale12
        move.w d2,d3
        move.w d4,d2
        bra.s M4LcBoxStore
M4LcRotX: ;rotate_8yz (rotx): y' = m(y,c)+m(z,s), z' = -m(y,s)+m(z,c)
        moveq #0,d0
        move.b 12(a0),d0
        move.w d1,d4 ;x unrotated, unscaled
        move.w d2,d1
        move.w d3,d2
        bsr M4LcRotPair ;d1=y, d2=z
        bsr M4LcScale12
        move.w d2,d3
        move.w d1,d2
        move.w d4,d1
        bra.s M4LcBoxStore
M4LcRotAll: ;bit7 (z, x, then y with the ORIGINAL z): not used by the catalog
        move.w #-1,M4_LV_STATUS
M4LcBoxStore:
        add.w (a0),d1
        add.w 2(a0),d2
        add.w 4(a0),d3
        move.w d1,M4_LC_POS
        move.w d2,M4_LC_POS+2
        move.w d3,M4_LC_POS+4
        move.l 8(a4),M4_LC_EXT
        move.w 12(a4),M4_LC_EXT+4
        move.b 15(a4),M4_LC_FLAGSET
        movem.l (sp)+,d0-d7/a1
        rts
; d1,d2 bytes (low bytes used) rotated by angle d0 with 8-bit tables:
; p' = m(p,c) + m(q,s) ; q' = -m(p,s) + m(q,c); byte sums wrap, sign-extended.
M4LcRotPair:
        tst.b d0 ;COLDET skips the byte rotation when the angle is zero
        bne.s M4LcRotPairNonzero
        ext.w d1
        ext.w d2
        rts
M4LcRotPairNonzero:
        movem.l d0/d3-d5/a1,-(sp)
        lea M4IntroShipSine,a1
        move.b (a1,d0.w),d4 ;s
        move.b 64(a1,d0.w),d5 ;c
        move.b d1,d0
        move.b d5,d3
        bsr M4LcMul8
        move.b d0,-(sp)
        move.b d2,d0
        move.b d4,d3
        bsr M4LcMul8
        add.b (sp)+,d0
        move.b d0,-(sp) ;p'
        move.b d1,d0
        move.b d4,d3
        bsr M4LcMul8
        neg.b d0
        move.b d0,-(sp)
        move.b d2,d0
        move.b d5,d3
        bsr M4LcMul8
        add.b (sp)+,d0
        ext.w d0
        move.w d0,d2 ;q'
        move.b (sp)+,d1
        ext.w d1 ;p'
        movem.l (sp)+,d0/d3-d5/a1
        rts
; mulslogmacram: sgn * floor(2|a||b|/256) on bytes d0, d3 -> d0.b
M4LcMul8:
        movem.l d1/d3,-(sp)
        ext.w d0
        ext.w d3
        move.w d0,d1
        eor.w d3,d1 ;sign
        tst.w d0
        bpl.s M4LcMulA
        neg.w d0
M4LcMulA:
        tst.w d3
        bpl.s M4LcMulB
        neg.w d3
M4LcMulB:
        add.w d0,d0
        andi.w #255,d0 ;8-bit asl
        mulu.w d3,d0
        lsr.w #8,d0
        tst.w d1
        bpl.s M4LcMulDone
        neg.w d0
M4LcMulDone:
        movem.l (sp)+,d1/d3
        rts
M4LcScale12:
        lsl.w d6,d1
        lsl.w d6,d2
        rts

; a2 <- allst order (head = newest, player last), terminated by 0
; (M4_LC_ORDER, LONG entries).
M4LcOrder:
        movem.l d0/a3,-(sp)
        lea M4_LC_ORDER,a3
        move.w M4_LV_HEAD,d0
M4LcOrderNext:
        tst.w d0
        beq.s M4LcOrderEnd
        movea.w d0,a2
        move.l a2,(a3)+
        move.w X_NEXT(a2),d0
        bra.s M4LcOrderNext
M4LcOrderEnd:
        clr.l (a3)
        lea M4_LC_ORDER,a2
        movem.l (sp)+,d0/a3
        rts
M4_LC_ORDER equ M4_LC+300 ;65 LONGs
M4_LC_HITLOG equ $fff2e0 ;.w collider descriptor, .w gameframe, .w map index, .w hits (diagnostic)

; ---------------------------------------------------------------------
; do_coll_l 1F:D23A: a0 object, d0 = AP of the other. collcount-1; at 0:
; HP (bit7 = indestructible) -= AP clamped at 0, collcount = 10 (frames/AP);
; in a tunnel AP 8 counts 4 (1F:D242).
M4LevelDoColl:
        subq.b #1,17(a0)
        bne.s M4LcDoCollDone
        bsr.s M4LcTunnelAp
        move.b #10,17(a0)
        move.b 38(a0),d1
        bmi.s M4LcDoCollDone
        sub.b d0,d1
        bpl.s M4LcDoCollHp
        moveq #0,d1
M4LcDoCollHp:
        move.b d1,38(a0)
M4LcDoCollDone:
        rts
; 1F:D242: inside a tunnel ($14DA bit0) an AP of 8 counts 4 (asr).
M4LcTunnelAp:
        btst #0,M4_LP_PSF3
        beq.s M4LcTunnelApDone
        cmpi.b #8,d0
        bne.s M4LcTunnelApDone
        moveq #4,d0
M4LcTunnelApDone:
        rts

; a0 object -> a2 collider (or 0 = wall/ground) from the low WORD address.
M4LcCollider:
        moveq #0,d0
        move.w 62(a0),d0
        beq.s M4LcColliderNone
        ori.l #$ff0000,d0
M4LcColliderNone:
        movea.l d0,a2
        rts

; Do_strat_l 1F:D26B for one object (a0), a1 = player. d0 nonzero: remove.
; HP 0 (not nuked) runs the expstrat if the object has one; a fresh object
; (HP 0, no pointers) continues to its Istrat. collide without collstrat
; only clears collide; Lcollide without endcollstrat falls to the strategy.
M4LevelDoStrat:
        bclr #2,44(a0) ;acf_firstframe
        tst.b 38(a0)
        bne.s M4LcDoAlive
        btst #4,45(a0)
        bne.s M4LcDoAlive
        move.l X_EXP(a0),d0
        beq.s M4LcDoAlive ;no expstrat pointer
        movea.l d0,a2
        jmp (a2)
M4LcDoAlive:
        bclr #4,45(a0) ;atnuked
        btst #SF_COLLIDE,49(a0)
        beq.s M4LcDoNoColl
        move.l X_COLL(a0),d0
        beq.s M4LcNoColl
        movea.l d0,a2
        jmp (a2) ;handlers end in M4LcStrategy (1F:DC25) or remove
M4LcDoNoColl:
        bclr #SF_LCOLLIDE,49(a0) ;no endcollstrat in the ported strategies
M4LcStrategy:
        move.l 32(a0),d0
        beq.s M4LcStrategyNone
        movea.l d0,a2
        jmp (a2)
M4LcStrategyNone:
        moveq #0,d0
        rts
M4LcNoColl:
        bclr #SF_COLLIDE,49(a0)
        bra M4LcStrategy

; hitflash_Istrat 06:89A3: collide=0; unless nohitaffect: do_coll(self, AP of
; collider, 10), hitflash; distance sound (no audio); then the strategy.
M4LcHitFlash:
        bclr #SF_COLLIDE,49(a0)
        btst #SF_NOHITAFFECT,49(a0)
        bne.s M4LcStrategy
        bsr M4LcCollider
        move.l a2,d0
        beq.s M4LcHitFlashMark
        moveq #0,d0
        move.b 39(a2),d0
        bsr M4LevelDoColl
M4LcHitFlashMark:
        M4PlaySfxAt $24 ;06:89A3 damenemysound, selected-ROM distXZ
        bset #SF_HITFLASH,49(a0)
        bset #2,31(a0) ;drawn white once (draw list consumes it)
        bra.s M4LcStrategy

; pelasercollide 06:8783: the laser dies (colldisable, HP 0, its expstrat).
M4LcPLaserColl:
        bset #SF_COLLDISABLE,49(a0)
        clr.b 38(a0)
M4LcPLaserDeath: ;06:A21D: type &= ~zremove, numplasers--, laser explosion
        bclr #3,45(a0) ;06:A066 (the object lives on as the explosion: the
        subq.b #1,M4_LP_NUMLASERS ;collider of this pass keeps its collobjptr)
        jmp M4WpLaserExp

; playercoll_Istrat 0B:E729. Body/wing objects are player state (M4_LP_*).
; $14DA bit3 -> no effect; $14D9 bit1 -> only indestructible colliders hurt;
; rolling (rollZvel != 0) deflects a destructible laser (0B:E768..E7FF):
; random pitch (rnd&$3F)-$1F, yaw (rnd&$1F) -/+ $18 (third rnd >= $7F ->
; minus), speed 60, four steps at once, no collision, beamball tick
; 06:9C4B for 30 ticks; no damage.
M4LcPlayerColl:
        bclr #SF_COLLIDE,49(a0)
        btst #3,M4_LP_PSF3
        bne M4LcPlayerCollEnd
        addq.b #1,M4_TN_PNUMHITS ;0B:E734 pnumhits++ (wireship hits, level_player.asm)
        bsr M4LcCollider
        ; diagnostic (M4_LC_HITLOG): last collider of the player
        move.l a2,d0
        beq.s M4LcHitLogged
        move.w 46(a2),M4_LC_HITLOG ;descriptor index of the collider
        move.w M4_LV_GAMEFRAME,M4_LC_HITLOG+2
        move.w TEXT_MAP_CONTEXT,M4_LC_HITLOG+4 ;map index
        addq.w #1,M4_LC_HITLOG+6
M4LcHitLogged:
        btst #1,M4_LP_PSF2
        beq.s M4LcPlayerVuln
        move.l a2,d0
        beq M4LcPlayerCollEnd
        cmpi.b #$ff,38(a2)
        bne M4LcPlayerCollEnd
M4LcPlayerVuln:
        btst #SF_NOHITAFFECT,49(a0)
        bne M4LcPlayerCollEnd
        tst.b M4_LP_ROLLZVEL
        beq M4LcPlayerParts
        move.l a2,d0
        beq M4LcPlayerParts
        btst #3,44(a2)
        beq M4LcPlayerParts
        cmpi.b #$ff,38(a2)
        beq M4LcPlayerParts
        exg a0,a2
        jsr M4IntroRandom
        andi.b #$3f,d0
        subi.b #$1f,d0
        move.b d0,12(a0)
        move.b #60,15(a0)
        jsr M4IntroRandom
        andi.b #$1f,d0
        move.b d0,13(a0)
        jsr M4IntroRandom
        cmpi.b #$7f,d0
        bhs.s M4LcDeflectLeft
        addi.b #$18,13(a0)
        bra.s M4LcDeflectVec
M4LcDeflectLeft:
        subi.b #$18,13(a0)
M4LcDeflectVec:
        jsr M4EnGen3d
        moveq #3,d1
M4LcDeflectMove:
        jsr M4EnMove
        dbra d1,M4LcDeflectMove
        bclr #SF_COLLIDE,49(a0)
        bset #SF_COLLDISABLE,49(a0)
        move.l #M4WpBeamTick,32(a0)
        move.b #30,19(a0)
        exg a0,a2
        bra M4LcPlayerCollEnd
M4LcPlayerParts:
        move.b 20(a0),d4
        btst #0,d4 ;HF1 body: pcolB_Istrat 0B:AE72 + pcolB_strat 0B:AEF8
        beq.s M4LcPlayerNoBody
        bset #0,M4_LP_PARTCOLL
        bsr M4LcPlayerBody
M4LcPlayerNoBody:
        btst #1,d4 ;HF2 left wing
        beq.s M4LcPlayerNoLeft
        bset #1,M4_LP_PARTCOLL
        moveq #0,d5
        bsr M4LcPlayerWing
M4LcPlayerNoLeft:
        btst #2,d4 ;HF3 right wing
        beq.s M4LcPlayerCollEnd
        bset #2,M4_LP_PARTCOLL
        moveq #1,d5
        bsr M4LcPlayerWing
M4LcPlayerCollEnd:
        clr.b 20(a0)
        bra M4LcStrategy

; Body hit: collider AP 0 -> nothing; else sbyte1 7, screen flash 4/type0,
; do_coll(body, AP) every 10 ticks of contact. Shield 0 -> player dies.
M4LcPlayerBody:
        move.l a2,d0
        beq.s M4LcBodyDone
        moveq #0,d0
        move.b 39(a2),d0
        beq.s M4LcBodyDone
M4LcBodyDamage:
        move.b #7,36(a0)
        move.b #4,M4_LP_FLASHCNT
        clr.b M4_LP_FLASHTYPE
        bsr M4LcBodyDoColl
M4LcBodyDone:
        rts
; do_coll on the body state with AP d0.
M4LcBodyDoColl:
        movem.l d1,-(sp)
        subq.b #1,M4_LP_BODYCC
        bne.s M4LcBodyCollDone
        bsr M4LcTunnelAp ;1F:D242
        M4PlaySfx $04 ;body impact, pcolBexp
        move.b #10,M4_LP_BODYCC
        move.b M4_LP_BODYHP,d1
        bmi.s M4LcBodyCollDone
        sub.b d0,d1
        bpl.s M4LcBodyHp
        moveq #0,d1
M4LcBodyHp:
        move.b d1,M4_LP_BODYHP
        bne.s M4LcBodyCollDone
        ; pcolBexp_Istrat 0B:AFC9: noctrl ($14D8 $20) or notdie ($14DF $20)
        ; keep HP 1; else player colldisable, HP 0 -> playerdead
        btst #5,M4_LP_PSF
        bne.s M4LcBodyKeep
        btst #5,M4_BOSS_PSTRATF
        bne.s M4LcBodyKeep
        bset #SF_COLLDISABLE,49(a0)
        clr.b 38(a0)
        bra.s M4LcBodyCollDone
M4LcBodyKeep:
        move.b #1,M4_LP_BODYHP
M4LcBodyCollDone:
        movem.l (sp)+,d1
        rts

; Wing hit, d5 = 0 left / 1 right (pcolLW 0B:B110 / pcolRW 0B:B3FA, pwingcol
; 0B:AD18, broken wing brkpwingcol 0B:ACDF).
M4LcPlayerWing:
        lea M4_LP_LWHP,a3
        tst.w d5
        beq.s M4LcWingSide
        lea M4_LP_RWHP,a3
M4LcWingSide:
        cmpi.b #$ff,(a3)
        bne.s M4LcWingIntact
        ; broken wing: the impact passes to the body with the full AP
        move.l a2,d0
        bne.s M4LcWingBrokenAp
        moveq #4,d0 ;wall/ground: do_coll(body, 4)
        bra M4LcBodyDoColl
M4LcWingBrokenAp:
        moveq #0,d0
        move.b 39(a2),d0
        bra M4LcBodyDoColl
M4LcWingIntact:
        move.b #2,M4_LP_FLASHCNT
        move.b #1,M4_LP_FLASHTYPE
        move.l a2,d0
        beq.s M4LcWingCount
        tst.b 39(a2)
        beq.s M4LcWingCount
        tst.b 14(a0)
        bmi.s M4LcWingRotNeg
        addi.w #8<<8,M4_LP_PLROTX
        bra.s M4LcWingPush
M4LcWingRotNeg:
        subi.w #8<<8,M4_LP_PLROTX
M4LcWingPush:
        tst.w d5
        bne.s M4LcWingPushRight
        addi.w #10,(a0)
        move.w #$f800,M4_LP_ZSHAKE
        bra.s M4LcWingCount
M4LcWingPushRight:
        subi.w #10,(a0)
        move.w #$0800,M4_LP_ZSHAKE
M4LcWingCount:
        ; pwingcol: first contact tick -> body takes AP>>1; wing -1 per 10
        cmpi.b #1,1(a3)
        bne.s M4LcWingSelf
        move.l a2,d0
        beq.s M4LcWingSelf
        moveq #0,d0
        move.b 39(a2),d0
        asr.b #1,d0
        bsr M4LcBodyDoColl
M4LcWingSelf:
        subq.b #1,1(a3)
        bne.s M4LcWingDone
        move.b #10,1(a3)
        subq.b #1,(a3)
        bne.s M4LcWingDone
        ; PLWbrk 0B:B263 / PRWbrk 0B:B502: wing HP $FF, broken flag, body cc 10
        move.b #$ff,(a3)
        moveq #$08,d0
        tst.w d5
        beq.s M4LcWingFlag
        moveq #$10,d0
M4LcWingFlag:
        or.b d0,M4_LP_PSF
        move.b #10,M4_LP_BODYCC
M4LcWingDone:
        rts

; playerdead_Istrat 0B:E215 (expstrat of the player at HP 0; corneria-
; missing.md C.2): HP 10 AP 0, collisions back on with hitflash, PLAYERDYING,
; pshipflags2 $80, noctrl + nofire, sbyte1 0, then playerdead_strat. Not
; modelled (PEND): fadered 02:F794, sounds/music, the wing sparks removal
; (no wing boxes in the port).
M4LcPlayerDead:
        clr.b M4_LP_ARROWS
        move.b #10,38(a0)
        clr.b 39(a0)
        bclr #SF_COLLDISABLE,49(a0)
        ori.b #2,M4_LP_GAMEFLAGS ;PLAYERDYING
        move.l #M4PdStrat,32(a0)
        move.l #M4LcHitFlash,X_COLL(a0) ;0B:E627 = hitflash
        move.l #M4PdExplode,X_EXP(a0)
        clr.b 36(a0)
        bset #7,M4_LP_PSF2
        bclr #F2_SFLAG1,48(a0)
        ori.b #$60,M4_LP_PSF
        cmpi.b #3,M4_SPP_FM ;0B:E2F4: dying in the cockpit leaves it first
        bne.s M4LcPdNotCockpit
        bset #SF_COLLDISABLE,49(a0)
        move.b #4,M4_SPP_FM
        move.l #M4SpOutCockI,32(a0) ;0B:CC91, then 0B:E215 again at its end
        moveq #0,d0
        rts
M4LcPdNotCockpit:
; playerdead_strat 0B:E41B: sbyte1 60 -> pexplode; white below 15 on even
; gameframes, else smoke every 4th (dieYrot); diefall: in the air the nose
; goes to 5000 (even gameframes) and the roll grows 4 per tick, on the
; ground plrotx -2000 and y 0 (the 4 sparks sgenspark 0B:AC5E: PEND); the
; speed falls 1 per 4 ticks; gen_3dvecs, vx 0, pos += v, the view follows.
M4PdStrat:
        addq.b #1,36(a0)
        move.b 36(a0),M4_LP_DEADCNT
        cmpi.b #60,36(a0)
        beq M4PdExplode
        cmpi.b #15,36(a0)
        bhs.s M4PdSmoke
        btst #0,M4_LV_GAMEFRAME+1
        bne.s M4PdFall
        bset #SF_HITFLASH,49(a0)
        bset #2,31(a0)
        bra.s M4PdFall
M4PdSmoke:
        btst #1,M4_LP_FLYMODE ;dieYrot
        beq.s M4PdFall
        moveq #3,d0
        and.w M4_LV_GAMEFRAME,d0
        bne.s M4PdFall
        jsr M4FxSmoke ;06:8EA8
M4PdFall:
        btst #0,M4_LP_FLYMODE ;diefall
        beq.s M4PdSpeed
        tst.w 2(a0)
        bpl.s M4PdGround
        bclr #F2_SFLAG1,48(a0)
        btst #0,M4_LV_GAMEFRAME+1
        bne.s M4PdNoDive
        move.w M4_LP_PLROTX,d0
        move.w #5000,d1
        moveq #4,d2
        jsr M4LpAchase
        move.w d0,M4_LP_PLROTX
M4PdNoDive:
        addq.b #4,M4_LP_ZSTRATADD
        bra.s M4PdSpeed
M4PdGround:
        move.w #-2000,M4_LP_PLROTX
        clr.w 2(a0)
        bset #F2_SFLAG1,48(a0)
M4PdSpeed:
        moveq #3,d0
        and.w M4_LV_GAMEFRAME,d0
        bne.s M4PdRot
        tst.b 15(a0)
        beq.s M4PdRot
        subq.b #1,15(a0)
M4PdRot:
        move.b M4_LP_PLROTX,12(a0)
        move.b M4_LP_PLROTY,13(a0)
        move.b M4_LP_PLROTZ,d0
        add.b M4_LP_ZSTRATADD,d0
        move.b d0,14(a0)
        moveq #0,d0
        move.b 15(a0),d0
        jsr M4LevelGen3dVecs
        btst #1,M4_LP_FLYMODE
        beq.s M4PdNoView
        move.w M4_LP_PVIEWY,d0
        move.w 2(a0),d1
        moveq #3,d2
        jsr M4LpAchase
        move.w d0,M4_LP_PVIEWY
M4PdNoView:
        clr.w 6(a0)
        jsr M4EnMove
        move.w 4(a0),M4_LP_PVIEWZ
        moveq #0,d0
        rts
; pexplode_Istrat 0B:E62B (tick 59): the player becomes the still null
; object of the view (pos += v once, no strategy, invisible, no collision);
; a copy with its shape explodes on the next tick (explode_Istrat: explosion
; class of myship_4 and debris). PLAYERDEAD, lives - 1, timeuntilfade 20.
; Not modelled (PEND): circleanim $BC, BIGParticleexplode 06:F89C, $15B8.
M4PdExplode:
        M4PlaySfx $03 ;playerdown 0B:AFC9
        movem.l a1-a2,-(sp)
        movea.l a0,a2
        jsr M4LevelAlloc
        move.l a0,d0
        beq.s M4PdNoCopy
        move.w 46(a2),d0
        jsr M4LevelSetShape
        move.l (a2),(a0)
        move.w 4(a2),4(a0)
        move.b 12(a2),12(a0)
        move.b 13(a2),13(a0)
        move.b 14(a2),14(a0)
        move.b 51(a2),51(a0)
        bset #SF_COLLDISABLE,49(a0)
        move.b #1,38(a0)
        move.l #M4PdBoom,32(a0)
M4PdNoCopy:
        movea.l a2,a0
        movem.l (sp)+,a1-a2
        move.w 6(a0),d0
        add.w d0,(a0)
        move.w 8(a0),d0
        add.w d0,2(a0)
        move.w 10(a0),d0
        add.w d0,4(a0)
        clr.l 32(a0)
        clr.l X_COLL(a0)
        clr.l X_EXP(a0)
        bset #SF_INVISIBLE,49(a0)
        bset #SF_COLLDISABLE,49(a0)
        bclr #F2_SHADOW,48(a0)
        ori.b #$40,M4_LP_GAMEFLAGS ;PLAYERDEAD
        subq.b #1,M4_LP_LIVES
        move.b #20,M4_LP_FADETIMER
        moveq #0,d0
        rts
M4PdBoom: ;the copy explodes on the tick after pexplode
        clr.b 38(a0)
        jmp M4LevelExplode

; init_strats_l 06:8380..84D9, after the strategy pass: while PLAYERDYING
; the view orbits (outvx -> 0 >>3, plrotz -> 0 >>2, outvy -= $80, outdist
; -> 500 >>4 until PLAYERDEAD); after pexplode timeuntilfade 20, then
; fadedir $FF each tick until fade 0: restart (lives left, restart_l) or
; game over (levelfinished $0A).
M4LevelPlayerDying:
        btst #1,M4_LP_GAMEFLAGS
        beq.s M4PdDyingDone
        move.w M4_LP_OUTVX,d0
        moveq #0,d1
        moveq #3,d2
        jsr M4LpAchase
        move.w d0,M4_LP_OUTVX
        move.w M4_LP_PLROTZ,d0
        moveq #2,d2
        jsr M4LpAchase
        move.w d0,M4_LP_PLROTZ
        subi.w #$80,M4_LP_OUTVY
        btst #6,M4_LP_GAMEFLAGS
        bne.s M4PdDead
        move.w M4_LP_OUTDIST,d0
        move.w #500,d1
        moveq #4,d2
        jsr M4LpAchase
        move.w d0,M4_LP_OUTDIST
M4PdDyingDone:
        rts
M4PdDead:
        tst.b M4_LP_FADETIMER
        beq.s M4PdFade
        subq.b #1,M4_LP_FADETIMER
        rts
M4PdFade:
        tst.b M4_FADE+1
        beq.s M4PdFaded
        move.b #$ff,M4_FADE ;fadedir $FF
        rts
M4PdFaded:
        move.w #4,M4_LV_STATUS ;restart_l (5 = game over, levelfinished $0A)
        tst.b M4_LP_LIVES
        bne.s M4PdFadedDone
        move.w #5,M4_LV_STATUS
M4PdFadedDone:
        rts

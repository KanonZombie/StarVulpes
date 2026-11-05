; graphics117 collision sweep (117, tools/hw-boot/make-round56.py): RAM copy
; with the exact Z rejection and the reference copy of M4LcSweep.
; 117 (make-round56.py): M4LcSweep with the exact WORD Z rejection taken
; from G117_LC_CACHE before reading the descriptor/XY. Runs from RAM.
G117SweepImage:
        obj G117_SWEEP_RAM
G117Sweep:
        movem.l d5-d7/a4-a5,-(sp)
G117SweepNext:
        movea.l (a5)+,a1 ;B
        btst #SF_COLLIDE,49(a1)
        bne G117SweepSkip
        move.b 44(a0),d0
        and.b 44(a1),d0
        andi.b #$f8,d0
        bne G117SweepSkip
        move.w a1,d0
        cmp.w 28(a0),d0
        beq G117SweepSkip
        move.w a0,d0
        cmp.w 28(a1),d0
        beq G117SweepSkip
        move.w 46(a0),d0
        cmp.w 46(a1),d0
        bne.s G117SweepShapeOk
        btst #SF_SAMESHAPE,49(a0)
        beq G117SweepSkip
        btst #SF_SAMESHAPE,49(a1)
        beq G117SweepSkip
G117SweepShapeOk:
        addq.w #1,M4_LC_PAIRS
        move.w a1,d0
        andi.w #$0fff,d0
        lsr.w #3,d0
        lea G117_LC_CACHE,a3
        adda.w d0,a3
        move.w (a3),d0
        sub.w M4_LC_POS+4,d0
        bpl.s G117SweepAbsZ
        neg.w d0
G117SweepAbsZ:
        sub.w M4_LC_EXT+4,d0
        sub.w 2(a3),d0
        bpl G117SweepSkip
        movea.l 4(a3),a3
        move.l (a1),M4_LC_BPOS
        move.w 4(a1),M4_LC_BPOS+4
        move.l 20(a3),M4_LC_BEXT
        move.w 24(a3),M4_LC_BEXT+4
        jsr G117_AABB_RAM ;broad phase / single box
        bne G117SweepSkip
        clr.b M4_LC_HITB
        move.l 28(a3),d0
        beq G117SweepImpact
        movea.l d0,a4
        move.w (a4)+,d6
        bmi.s G117SweepBAnim
        btst #14,d6
        beq.s G117SweepBCount
        exg d5,d6
        move.b 16(a1),d0
        jsr M4LcFrameList ;mixed animated list (base_0)
        exg d5,d6
        bra.s G117SweepBCount
G117SweepBAnim:
        moveq #15,d0
        and.b 16(a1),d0
        lsl.w #4,d0
        adda.w d0,a4
        moveq #1,d6
G117SweepBCount:
        subq.w #1,d6
        movem.l M4_LC_POS,d0-d2 ;save A box (POS, EXT; 12 bytes)
        movem.l d0-d2,-(sp)
        move.b M4_LC_FLAGSET,-(sp)
G117SweepBBox:
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
        jsr G117_AABB_RAM
        bne.s G117SweepBBoxNext
        or.b d1,M4_LC_HITB
G117SweepBBoxNext:
        lea 16(a4),a4
        dbra d6,G117SweepBBox
        move.b (sp)+,M4_LC_FLAGSET
        movem.l (sp)+,d0-d2
        movem.l d0-d2,M4_LC_POS
        tst.b M4_LC_HITB
        beq.s G117SweepSkip
G117SweepImpact:
        bset #SF_COLLIDE,49(a0)
        move.w a1,62(a0)
        bset #SF_COLLIDE,49(a1)
        move.w a0,62(a1)
        move.b M4_LC_HITB,d0
        or.b d0,20(a1)
        move.b M4_LC_FLAGSET,d0
        or.b d0,20(a0)
        bra.s G117SweepDone ;one collision per object and pass
G117SweepSkip:
        dbra d7,G117SweepNext
G117SweepDone:
        movem.l (sp)+,d5-d7/a4-a5
        rts
        objend
G117SweepImageEnd:

        g117at $15ca00
; Reference path (M4_SCREEN set): verbatim copy of M4LcSweep, level_coll.asm.
G117SweepRef:
        movem.l d5-d7/a4-a5,-(sp)
G117SweepRefNext:
        movea.l (a5)+,a1 ;B
        btst #SF_COLLIDE,49(a1)
        bne G117SweepRefSkip
        move.b 44(a0),d0
        and.b 44(a1),d0
        andi.b #$f8,d0
        bne G117SweepRefSkip
        move.w a1,d0
        cmp.w 28(a0),d0
        beq G117SweepRefSkip
        move.w a0,d0
        cmp.w 28(a1),d0
        beq G117SweepRefSkip
        move.w 46(a0),d0
        cmp.w 46(a1),d0
        bne.s G117SweepRefShapeOk
        btst #SF_SAMESHAPE,49(a0)
        beq G117SweepRefSkip
        btst #SF_SAMESHAPE,49(a1)
        beq G117SweepRefSkip
G117SweepRefShapeOk:
        addq.w #1,M4_LC_PAIRS
        exg a0,a1
        jsr M4LcDescriptor
        exg a0,a1
        move.l (a1),M4_LC_BPOS
        move.w 4(a1),M4_LC_BPOS+4
        move.l 20(a3),M4_LC_BEXT
        move.w 24(a3),M4_LC_BEXT+4
        jsr M4LcAabb ;broad phase / single box
        bne G117SweepRefSkip
        clr.b M4_LC_HITB
        move.l 28(a3),d0
        beq G117SweepRefImpact
        movea.l d0,a4
        move.w (a4)+,d6
        bmi.s G117SweepRefBAnim
        btst #14,d6
        beq.s G117SweepRefBCount
        exg d5,d6
        move.b 16(a1),d0
        jsr M4LcFrameList ;mixed animated list (base_0)
        exg d5,d6
        bra.s G117SweepRefBCount
G117SweepRefBAnim:
        moveq #15,d0
        and.b 16(a1),d0
        lsl.w #4,d0
        adda.w d0,a4
        moveq #1,d6
G117SweepRefBCount:
        subq.w #1,d6
        movem.l M4_LC_POS,d0-d2 ;save A box (POS, EXT; 12 bytes)
        movem.l d0-d2,-(sp)
        move.b M4_LC_FLAGSET,-(sp)
G117SweepRefBBox:
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
        bne.s G117SweepRefBBoxNext
        or.b d1,M4_LC_HITB
G117SweepRefBBoxNext:
        lea 16(a4),a4
        dbra d6,G117SweepRefBBox
        move.b (sp)+,M4_LC_FLAGSET
        movem.l (sp)+,d0-d2
        movem.l d0-d2,M4_LC_POS
        tst.b M4_LC_HITB
        beq.s G117SweepRefSkip
G117SweepRefImpact:
        bset #SF_COLLIDE,49(a0)
        move.w a1,62(a0)
        bset #SF_COLLIDE,49(a1)
        move.w a0,62(a1)
        move.b M4_LC_HITB,d0
        or.b d0,20(a1)
        move.b M4_LC_FLAGSET,d0
        or.b d0,20(a0)
        bra.s G117SweepRefDone ;one collision per object and pass
G117SweepRefSkip:
        dbra d7,G117SweepRefNext
G117SweepRefDone:
        movem.l (sp)+,d5-d7/a4-a5
        rts


; Space stages (build/research/stage-asteroid1.md): map commands of the
; generators and object links, the generator ("mother") strategy and its
; script interpreter 03:FB40, and the asteroid strategies.

M4_LV_MAPVAR1 equ $fff8c4 ;.w $1736 mapvar1 (object low WORD, 4A/48)
X_SHAPEHDR equ -$8000+30 ;.w original shape header of map / mother objects

; 0A mapmother 03:FA6E [wait.w x.w y.w zrel.w shape.w strat.24 script.w]:
; mapcnt = wait; a free object inserted right after the head (the player);
; lastobj = it; x, y absolute, z = player z + zrel; +$06 = script (bank 05
; index); type atzremove. No free object: lastobj = 0, nothing created.
M4LvMother:
        clr.l M4_LV_LAST
        move.l a0,-(sp)
        move.l M4_LV_CREATOR,-(sp)
        clr.l M4_LV_CREATOR
        moveq #0,d0
        move.b 13(a1),d0 ;strategy bank
        swap d0
        move.b 12(a1),d0
        lsl.w #8,d0
        move.b 11(a1),d0
        movem.l a1,-(sp)
        jsr M4LevelFindStrategy
        movem.l (sp)+,a1
        move.l a2,d1
        beq.s M4LvMotherSkip
        movea.l a2,a3
        jsr M4LevelAlloc
        move.l a0,d0
        beq.s M4LvMotherDone
        bsr M4LvWordAt1 ;x
        move.w d0,(a0)
        moveq #5,d1
        bsr M4LvWordAtD1
        move.w d0,2(a0)
        moveq #7,d1
        bsr M4LvWordAtD1
        add.w LV_PLAYER+4,d0
        move.w d0,4(a0)
        moveq #9,d1
        bsr M4LvWordAtD1
        move.w d0,X_SHAPEHDR(a0)
        jsr M4LevelShapeIndex
        jsr M4LevelSetShape
        moveq #14,d1
        bsr M4LvWordAtD1
        move.w d0,X_ALPTR(a0) ;+$06 script pointer (bank 05)
        move.l a3,32(a0)
        bra.s M4LvMotherDone
M4LvMotherSkip:
        addq.w #1,M4_LV_SKIPPED
M4LvMotherDone:
        move.l (sp)+,M4_LV_CREATOR
        move.l (sp)+,a0
        moveq #1,d1
        bsr M4LvWordAtD1
        move.w d0,2(a0) ;mapcnt = wait
        bra M4LsCommit
M4LsCommit:
        jmp M4LvCommit
M4LsUnsupported:
        jmp M4LvUnsupported
; d1 = byte offset in the command (a1) -> d0.w little-endian WORD.
M4LvWordAt1:
        moveq #3,d1
M4LvWordAtD1:
        move.b 1(a1,d1.w),d0
        lsl.w #8,d0
        move.b (a1,d1.w),d0
        rts

; 0C mapremove 03:FB0D [0 0 shape.w]: from the second object on (the head is
; skipped), the first one whose shape is `shape` is removed (removedeadal).
M4LvMapRemove:
        moveq #3,d1
        bsr M4LvWordAtD1
        move.w d0,d2
        move.w M4_LV_HEAD,d0
        beq.s M4LvMapRemoveDone
        movea.w d0,a3
M4LvMapRemoveNext:
        move.w X_NEXT(a3),d0
        beq.s M4LvMapRemoveDone
        movea.w d0,a3
        cmp.w X_SHAPEHDR(a3),d2
        bne.s M4LvMapRemoveNext
        move.l a0,-(sp)
        movea.l a3,a0
        jsr M4LevelRemove
        move.l (sp)+,a0
M4LvMapRemoveDone:
        bra M4LsCommit

; 3E setalxvar.w 03:F2D9 [off.w val.w]: WORD at lastobj + off (alx area);
; $FCCA / $FCCC = sWPx1 / sWPy1.
M4LvSetAlxW:
        move.l M4_LV_LAST,d0
        beq M4LsCommit
        movea.l d0,a3
        moveq #1,d1
        bsr M4LvWordAtD1
        move.w d0,d2
        moveq #3,d1
        bsr M4LvWordAtD1
        cmpi.w #$fcca,d2
        bne.s M4LvSetAlxWY
        move.w d0,X_WPX(a3)
        bra M4LsCommit
M4LvSetAlxWY:
        cmpi.w #$fccc,d2
        bne.s M4LvSetAlxWDepth
        move.w d0,X_WPY(a3)
        bra M4LsCommit
M4LvSetAlxWDepth: ;$FCDF: alx+$15 depthoffset of the far ships (0D:A8C4..; high byte $1CE0 is 0 in every use)
        cmpi.w #$fcdf,d2
        bne.s M4LvSetAlxWStr
        move.b d0,X_DEPTHOFF(a3)
        bra M4LsCommit
M4LvSetAlxWStr: ;$FCEA: alx+$20 coltab = textpath string (credits map 0D:F2EE..)
        cmpi.w #$fcea,d2
        bne.s M4LvSetAlxWPword
        move.w d0,X_COLTAB(a3)
        bra M4LsCommit
M4LvSetAlxWPword: ;$FCFE: alx+$34 pword1 of the path objects of Corneria 3 (05:EBBA..: path 4345 exportw)
        cmpi.w #$fcfe,d2
        bne M4LsUnsupported
        move.w d0,X2_PWORD1(a3)
        bra M4LsCommit
; 48 setalvarptr.w 03:F1E5 [off.w ptr.24]: WORD [lastobj + off] = WORD
; [ptr]; used as sword1 ($26) / sword2 ($28) / al_ptr ($06) = mapvar1 ($1736).
M4LvSetAlvarPtr:
        move.l M4_LV_LAST,d0
        beq M4LsCommit
        movea.l d0,a3
        moveq #1,d1
        bsr M4LvWordAtD1
        moveq #40,d2 ;sword1 ($26)
        cmpi.w #$0026,d0
        beq.s M4LvAlvarPtrOff
        move.w #X_ALPTR,d2 ;al_ptr ($06): Macbeth woods -> its launcher (05:B88B..)
        cmpi.w #$0006,d0
        beq.s M4LvAlvarPtrOff
        moveq #42,d2 ;sword2 ($28): exit faces of ship3 (0D:B27D/B29D)
        cmpi.w #$0028,d0
        bne M4LsUnsupported
M4LvAlvarPtrOff:
        moveq #3,d1
        bsr M4LvWordAtD1
        cmpi.w #$1736,d0
        bne M4LsUnsupported
        tst.b 5(a1)
        bne M4LsUnsupported
        move.w M4_LV_MAPVAR1,(a3,d2.w)
        bra M4LsCommit
; 4A setvarobj 03:F195 [ptr.24]: WORD [ptr] = lastobj ($1736 only).
M4LvSetVarObj:
        moveq #1,d1
        bsr M4LvWordAtD1
        cmpi.w #$1736,d0
        bne M4LsUnsupported
        tst.b 3(a1)
        bne M4LsUnsupported
        move.w M4_LV_LAST+2,M4_LV_MAPVAR1
        bra M4LsCommit

; ---------------------------------------------------------------------
; Generator 04:F5B3 (Istrat) / 04:F5D7: sword2 = z - player z; every tick z =
; player z + sword2, then the script interpreter 03:FB40 with the generator
; as the list head: its children are linked right after it and run their
; Istrat in this same traversal.
M4StratMother:
        move.w 4(a0),d0
        sub.w LV_PLAYER+4,d0
        move.w d0,X_SWORD2(a0)
        move.l #M4StratMotherTick,32(a0)
M4StratMotherTick:
        move.w LV_PLAYER+4,d0
        add.w X_SWORD2(a0),d0
        move.w d0,4(a0)
        move.l M4_LV_CREATOR,-(sp)
        move.l a0,M4_LV_CREATOR
        bsr.s M4MotherRun
        move.l (sp)+,M4_LV_CREATOR
        rts ;d0 from the interpreter: 1 = removed by `end`

; 03:FB40: +$26 (sword1) = wait in player Z units, +$06 script pointer
; (bank 05), +$24 (sbyte3) loop counter. A wait > 0 is decreased by $1703
; and ends the call; otherwise the next command runs and loads its wait.
M4MotherRun:
        move.w 40(a0),d0
        ble.s M4MotherOp
        sub.w TEXT_MAP_CONTEXT+6,d0 ;$1703 (map advance of this tick)
        move.w d0,40(a0)
        moveq #0,d0
        rts
M4MotherOp:
        lea M4Map05Bytes,a3
        moveq #0,d0
        move.w X_ALPTR(a0),d0
        andi.w #$7fff,d0
        adda.l d0,a3 ;command
        move.b 2(a3),d0
        lsl.w #8,d0
        move.b 1(a3),d0
        move.w d0,40(a0) ;+$26 = wait of the command
        moveq #0,d0
        move.b (a3),d0
        cmpi.b #$0e,d0
        bhi M4MotherBad
        add.w d0,d0
        move.w M4MotherOps(pc,d0.w),d0
        jmp M4MotherOps(pc,d0.w)
M4MotherOps:
        dc.w M4MotherObj-M4MotherOps,M4MotherBad-M4MotherOps,M4MotherLoop-M4MotherOps
        dc.w M4MotherBad-M4MotherOps,M4MotherEnd-M4MotherOps,M4MotherBad-M4MotherOps
        dc.w M4MotherRnd-M4MotherOps,M4MotherBad-M4MotherOps,M4MotherGoto-M4MotherOps
        dc.w M4MotherBad-M4MotherOps,M4MotherWait-M4MotherOps,M4MotherBad-M4MotherOps
        dc.w M4MotherCnt-M4MotherOps,M4MotherBad-M4MotherOps,M4MotherIf-M4MotherOps
M4MotherBad:
        move.w #$7d00,M4_LV_BADOP
        move.w #-1,M4_LV_STATUS
        moveq #0,d0
        rts
; 00 obj [wait dx.w dy.w dz.w shape.w strat.24]: child at the generator's
; position + (dx, dy, dz).
M4MotherObj:
        moveq #3,d1
        bsr M4MotherWord
        move.w d0,d3
        moveq #5,d1
        bsr M4MotherWord
        move.w d0,d4
        moveq #7,d1
        bsr M4MotherWord
        move.w d0,d5
        bra.s M4MotherCreate
; 06 rnd (motherrnd 03:FD19) [wait rx.w ry.w rz.w shape.w strat.24]: six
; random_l bytes give X, Y, Z; per axis off = R ? (rnd & (R - 1)) - R/2 : 0.
M4MotherRnd:
        moveq #2,d6
        lea -6(sp),sp
        movea.l sp,a2
M4MotherRndByte:
        jsr M4IntroRandom
        move.b d0,(a2)+ ;low then high byte
        jsr M4IntroRandom
        move.b d0,(a2)+
        dbra d6,M4MotherRndByte
        movea.l sp,a2
        moveq #3,d1
        bsr M4MotherAxis
        move.w d0,d3
        moveq #5,d1
        bsr M4MotherAxis
        move.w d0,d4
        moveq #7,d1
        bsr M4MotherAxis
        move.w d0,d5
        lea 6(sp),sp
        bra.s M4MotherCreate
M4MotherAxis: ;a2 -> random WORD (little-endian bytes), d1 range offset
        bsr M4MotherWord
        move.w d0,d2 ;R
        move.b 1(a2),d0
        lsl.w #8,d0
        move.b (a2),d0
        addq.l #2,a2
        tst.w d2
        beq.s M4MotherAxisZero
        move.w d2,d1
        subq.w #1,d1
        and.w d1,d0
        lsr.w #1,d2
        sub.w d2,d0
        rts
M4MotherAxisZero:
        moveq #0,d0
        rts
; Common create (03:FB93..): after the generator ($121F = it), shape and
; strategy, position generator + (d3, d4, d5), coll/exp 0, type 8.
M4MotherCreate:
        movem.l a0/a3,-(sp)
        moveq #0,d0
        move.b 13(a3),d0
        swap d0
        move.b 12(a3),d0
        lsl.w #8,d0
        move.b 11(a3),d0
        jsr M4LevelFindStrategy
        movea.l (sp),a0
        movea.l 4(sp),a3
        move.l a2,d0
        beq.s M4MotherNoStrat
        move.l a2,d6
        jsr M4LevelAlloc
        move.l a0,d0
        beq.s M4MotherCreated
        movea.l (sp),a2 ;generator
        add.w (a2),d3
        add.w 2(a2),d4
        add.w 4(a2),d5
        move.w d3,(a0)
        move.w d4,2(a0)
        move.w d5,4(a0)
        moveq #9,d1
        bsr M4MotherWord
        move.w d0,X_SHAPEHDR(a0)
        jsr M4LevelShapeIndex
        jsr M4LevelSetShape
        move.l d6,32(a0)
        bra.s M4MotherCreated
M4MotherNoStrat:
        addq.w #1,M4_LV_SKIPPED
M4MotherCreated:
        movem.l (sp)+,a0/a3
        addi.w #14,X_ALPTR(a0)
        bra M4MotherRun
; d1 = byte offset in the command (a3) -> d0.w little-endian WORD.
M4MotherWord:
        move.b 1(a3,d1.w),d0
        lsl.w #8,d0
        move.b (a3,d1.w),d0
        rts
; 02 loop [wait dest.w n]: c = +$24 + 1; c < n: +$24 = c, ptr = dest; else
; +$24 = 0, ptr += 6.
M4MotherLoop:
        move.b X_SBYTE3(a0),d0
        addq.b #1,d0
        cmp.b 5(a3),d0
        bge.s M4MotherLoopDone
        move.b d0,X_SBYTE3(a0)
        moveq #3,d1
        bsr M4MotherWord
        move.w d0,X_ALPTR(a0)
        bra M4MotherRun
M4MotherLoopDone:
        clr.b X_SBYTE3(a0)
        addq.w #6,X_ALPTR(a0)
        bra M4MotherRun
; 04 end: the generator removes itself (1F:D501) and leaves.
M4MotherEnd:
        moveq #1,d0
        rts
M4MotherGoto: ;08 [wait dest.w]
        moveq #3,d1
        bsr M4MotherWord
        move.w d0,X_ALPTR(a0)
        bra M4MotherRun
M4MotherWait: ;0A [wait]
        addq.w #3,X_ALPTR(a0)
        bra M4MotherRun
; 0C cnt [wait shape.w]: $1757 = objects with that shape from the generator
; to the end of the list.
M4MotherCnt:
        moveq #3,d1
        bsr M4MotherWord
        move.w d0,d2
        moveq #0,d3
        movea.l a0,a2
M4MotherCntNext:
        cmp.w X_SHAPEHDR(a2),d2
        bne.s M4MotherCntSkip
        addq.w #1,d3
M4MotherCntSkip:
        move.w X_NEXT(a2),d0
        beq.s M4MotherCntDone
        movea.w d0,a2
        bra.s M4MotherCntNext
M4MotherCntDone:
        move.w d3,M4_LV_COUNT1757
        addq.w #5,X_ALPTR(a0)
        bra M4MotherRun
; 0E if [wait v.w dest.w cond]: cond 0 ==, 1 !=, 2 < (unsigned), 3 >= on
; $1757; true: ptr = dest, else ptr += 8.
M4MotherIf:
        moveq #3,d1
        bsr M4MotherWord
        move.w M4_LV_COUNT1757,d2
        move.b 7(a3),d1
        beq.s M4MotherIfEq
        cmpi.b #1,d1
        beq.s M4MotherIfNe
        cmpi.b #2,d1
        beq.s M4MotherIfLt
        cmp.w d0,d2
        bhs.s M4MotherIfTrue
        bra.s M4MotherIfFalse
M4MotherIfLt:
        cmp.w d0,d2
        blo.s M4MotherIfTrue
        bra.s M4MotherIfFalse
M4MotherIfEq:
        cmp.w d0,d2
        beq.s M4MotherIfTrue
        bra.s M4MotherIfFalse
M4MotherIfNe:
        cmp.w d0,d2
        bne.s M4MotherIfTrue
M4MotherIfFalse:
        addq.w #8,X_ALPTR(a0)
        bra M4MotherRun
M4MotherIfTrue:
        moveq #5,d1
        bsr M4MotherWord
        move.w d0,X_ALPTR(a0)
        bra M4MotherRun
M4_LV_COUNT1757 equ $fff8c6 ;.w $1757 (mother cnt)

; ---------------------------------------------------------------------
; slowmeteor 09:9337 (sword1 20) / meteor 09:9387 (sword1 60), shape
; asteroid1: sprite facing the camera; HP 2 AP 12, nohitaffect
; (indestructible); vel = r1 & 7, spin sbyte1 = r2 & 3 (negated when roty
; = r3 >= $80; 0 when r4 >= $7F), v = gen3d(vel, rotx 0, roty); every tick
; z -= sword1 (not for asteroid3 $AF95), rotz += sbyte1, pos += v.
M4StratSlowMeteor:
        moveq #20,d0
        bra.s M4StratMeteorInit
M4StratMeteor:
        moveq #60,d0
M4StratMeteorInit:
        bset #F2_SPRITE,48(a0)
        clr.b X_DEPTHOFF(a0)
        clr.b X_TX(a0)
        move.w d0,40(a0)
        move.l #M4StratMeteorTick,32(a0)
        move.l #M4LcHitFlash,X_COLL(a0)
        move.l #M4LevelExplode,X_EXP(a0)
        move.b #2,38(a0)
        move.b #12,39(a0)
        clr.b 14(a0)
        jsr M4IntroRandom
        andi.b #7,d0
        move.b d0,15(a0)
        jsr M4IntroRandom
        andi.b #3,d0
        move.b d0,36(a0)
        jsr M4IntroRandom
        move.b d0,13(a0)
        bpl.s M4MeteorSpinSign
        neg.b 36(a0)
M4MeteorSpinSign:
        jsr M4IntroRandom
        cmpi.b #$7f,d0
        blo.s M4MeteorSpinKeep
        clr.b 36(a0)
M4MeteorSpinKeep:
        clr.b 12(a0)
        jsr M4EnGen3d ;v = gen3d(vel, rotx, roty)
        jsr M4EnFaceCamera
        ori.b #$10,44(a0)
        bset #5,49(a0) ;nohitaffect
M4StratMeteorTick:
        cmpi.w #$af95,X_SHAPEHDR(a0)
        beq.s M4MeteorNoZ
        move.w 40(a0),d0
        sub.w d0,4(a0)
M4MeteorNoZ:
        move.b 36(a0),d0
        add.b d0,14(a0)
        jsr M4EnMove
        moveq #0,d0
        rts

; Asteroid Belt 1 strategies (provisional include point; may move to main.asm).
        include 'stages/level_asteroid.asm'

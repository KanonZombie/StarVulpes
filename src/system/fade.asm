; Selected ROM 010C12..010C9B, copied SNES code CODE_7E3DAB / setinidisp.
; a0: mode.b, timer.b, gameframe.w, three INIDISP bytes, spare.b.
; Byte wrap, equality limits and odd-frame FD skip are intentional.
; Scheduling is external: original consumers are NMI tasks.
M4FadeStep:
        move.b (a0),d0
        beq.s M4FadeReturn
        bpl.s M4FadeUp
        cmpi.b #$fe,d0
        beq.s M4FadeQuickDown
        cmpi.b #$fd,d0
        bne.s M4FadeDown
        btst #0,3(a0)
        bne.s M4FadeReturn
M4FadeDown:
        move.b 1(a0),d0
M4FadeDownA:
        tst.b d0
        beq.s M4FadeOff
        subq.b #1,d0
        beq.s M4FadeOff
M4FadeWrite:
        move.b d0,4(a0)
        move.b d0,5(a0)
        move.b d0,6(a0)
        move.b d0,1(a0)
M4FadeReturn:
        rts
M4FadeOff:
        move.b #$80,4(a0)
        move.b #$80,5(a0)
        move.b #$80,6(a0)
        clr.b (a0)
        clr.b 1(a0)
        rts
M4FadeQuickDown:
        move.b 1(a0),d0
        beq.s M4FadeOff
        subq.b #1,d0
        beq.s M4FadeOff
        bra.s M4FadeDownA
M4FadeUp:
        cmpi.b #2,d0
        beq.s M4FadeQuickUp
        move.b 1(a0),d0
M4FadeUpA:
        cmpi.b #15,d0
        beq.s M4FadeOn
        addq.b #1,d0
        bra.s M4FadeWrite
M4FadeOn:
        clr.b (a0)
        move.b #15,1(a0)
        rts
M4FadeQuickUp:
        move.b 1(a0),d0
        cmpi.b #15,d0
        beq.s M4FadeOn
        addq.b #1,d0
        cmpi.b #15,d0
        beq.s M4FadeOn
        addq.b #1,d0
        bra.s M4FadeUpA

M4FadeTest:
        move.l #'M4FD',$ff2400
        clr.l $ff2404
        lea M4FadeVectors,a4
        lea $ff2420,a5
        move.w #M4_FADE_CASES-1,d7
M4FadeTestNext:
        move.l (a4)+,(a5)
        move.l (a4)+,4(a5)
        move.l (a5),8(a5)
        move.l 4(a5),12(a5)
        lea 8(a5),a0
        bsr M4FadeStep
        move.l (a4)+,16(a5)
        move.l (a4)+,20(a5)
        addq.w #1,$ff2406
        move.l 16(a5),d0
        cmp.l 8(a5),d0
        bne.s M4FadeTestBad
        move.l 20(a5),d0
        cmp.l 12(a5),d0
        bne.s M4FadeTestBad
        lea 24(a5),a5
        dbra d7,M4FadeTestNext
        move.w #1,$ff2404
        rts
M4FadeTestBad:
        move.w #$ffff,$ff2404
        rts
M4FadeVectors:
        include '../build/m4-fade-cases.inc'

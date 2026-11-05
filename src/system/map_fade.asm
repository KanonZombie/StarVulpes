; Script index 7870 in bank 0D, bus 0D:F870, begins 50/4C.
; Handlers ROM 03:F237 / 03:F175.
; a0: pointer.w, counter.w, mode.b, timer.b, INIDISP0.b, spare.b.
; d0 input opcode / output 1 continue parsing, 0 blocked, FFFF unsupported.
; A blocked 4C sets counter=1 and retains its pointer; it tests timer AND
; exact INIDISP byte 80. A set high bit alone is insufficient.
M4MapFadeCommand:
        cmpi.w #$50,d0
        beq.s M4MapQuickDown
        cmpi.w #$4c,d0
        beq.s M4MapWaitFade
        moveq #-1,d0
        rts
M4MapQuickDown:
        move.b #$fe,4(a0)
        bra.s M4MapFadeContinue
M4MapWaitFade:
        tst.b 5(a0)
        bne.s M4MapFadeBlocked
        cmpi.b #$80,6(a0)
        bne.s M4MapFadeBlocked
M4MapFadeContinue:
        addq.w #1,(a0)
        moveq #1,d0
        rts
M4MapFadeBlocked:
        move.w #1,2(a0)
        moveq #0,d0
        rts

M4MapFadeTest:
        move.l #'M4MF',$ff3400
        clr.l $ff3404
        lea M4MapFadeVectors,a4
        lea $ff3420,a5
        move.w #M4_MAP_FADE_CASES-1,d7
M4MapFadeTestNext:
        move.w (a4)+,(a5)
        move.l (a4)+,2(a5)
        move.l (a4)+,6(a5)
        move.l 2(a5),10(a5)
        move.l 6(a5),14(a5)
        lea 10(a5),a0
        move.w (a5),d0
        bsr M4MapFadeCommand
        move.w d0,26(a5)
        move.l (a4)+,18(a5)
        move.l (a4)+,22(a5)
        cmp.w (a4)+,d0
        bne.s M4MapFadeTestBad
        move.l 18(a5),d0
        cmp.l 10(a5),d0
        bne.s M4MapFadeTestBad
        move.l 22(a5),d0
        cmp.l 14(a5),d0
        bne.s M4MapFadeTestBad
        addq.w #1,$ff3406
        lea 28(a5),a5
        dbra d7,M4MapFadeTestNext
        ; The next real command is outside this unit; it must not execute
        ; an invented background operation or consume bytes silently.
        lea $ff39a0,a0
        move.l #$78721234,(a0)
        move.l #$070080a5,4(a0)
        moveq #$10,d0
        bsr M4MapFadeCommand
        cmpi.w #$ffff,d0
        bne.s M4MapFadeTestBad
        cmpi.l #$78721234,(a0)
        bne.s M4MapFadeTestBad
        cmpi.l #$070080a5,4(a0)
        bne.s M4MapFadeTestBad
        move.w #1,$ff3404
        rts
M4MapFadeTestBad:
        move.w #$ffff,$ff3404
        rts
M4MapFadeVectors:
        include '../build/m4-map-fade-cases.inc'

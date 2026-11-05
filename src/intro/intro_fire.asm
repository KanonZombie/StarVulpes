; Selected-ROM07:8BE6/8BFD prefix. Caller consumes weapon14 at07:8C18.
; Own32-byte context: xyz0..4,life19.b,alive22.w,event24.w,pending26.w.
M4_FIRE_OBJECT equ $ff8d00
M4_FIRE_CREATED equ $ff8d20
M4_FIRE_TARGET equ $ff8d22 ; source mapvar1 identity, not an MD pointer
M4_LAST_NATIVE equ $ff82a0
M4_LAST_CONTEXT equ $ff82a2
M4_MAPVAR1_CONTEXT equ $ff82a6
M4_MAPVAR1_NATIVE equ $ff82aa

; a0=context. Caller supplies original command coordinates/worldZ.
M4IntroFireInit:
        move.b #35,19(a0)
        move.w #1,22(a0)
        move.w #2,30(a0) ; original keepbehind, not collision disable
        rts

; d0=gameframe BYTE,d1=native al1pt WORD,d2=original pviewVelocityZ.
; Return0 completed/1 BEFORE weapon consumer. Never suppress the shot.
M4IntroFireTick:
        tst.w 22(a0)
        beq.s M4IntroFireDone
        clr.w 24(a0)
        subq.b #1,19(a0)
        beq.s M4IntroFireRemove
        add.b d1,d0
        andi.b #3,d0
        beq.s M4IntroFireRequest
        add.w d2,4(a0)
M4IntroFireDone:
        moveq #0,d0
        rts
M4IntroFireRemove:
        clr.w 22(a0)
        bra.s M4IntroFireDone
M4IntroFireRequest:
        move.w #14,24(a0)
        move.w #1,26(a0)
        moveq #1,d0
        rts

; Real 68000 prefix cases, source ROM executor is the fixture oracle.
M4IntroFireTest:
        movem.l d0-d7/a0-a6,-(sp)
        move.l #'M4FI',$ff4520
        clr.l $ff4524
        lea M4IntroFireCases,a4
        move.w #M4_FIRE_CASES-1,d7
M4IntroFireTestNext:
        lea $ff8e00,a0
        moveq #7,d0
M4IntroFireTestClear:
        clr.l (a0)+
        dbra d0,M4IntroFireTestClear
        lea $ff8e00,a0
        move.b 5(a4),19(a0)
        move.w 6(a4),4(a0)
        move.w #1,22(a0)
        tst.w 10(a4)
        beq.s M4IntroFireTestTick
        bsr M4IntroFireInit
M4IntroFireTestTick:
        move.w (a4),d0
        move.w 2(a4),d1
        move.w 8(a4),d2
        bsr M4IntroFireTick
        cmp.w 18(a4),d0
        bne.s M4IntroFireTestBad
        moveq #0,d0
        move.b 19(a0),d0
        cmp.w 12(a4),d0
        bne.s M4IntroFireTestBad
        move.w 4(a0),d0
        cmp.w 14(a4),d0
        bne.s M4IntroFireTestBad
        move.w 22(a0),d0
        cmp.w 16(a4),d0
        bne.s M4IntroFireTestBad
        addq.w #1,$ff4526
        lea 20(a4),a4
        dbra d7,M4IntroFireTestNext
        move.w #1,$ff4524
        bra.s M4IntroFireTestDone
M4IntroFireTestBad:
        move.w #-1,$ff4524
M4IntroFireTestDone:
        movem.l (sp)+,d0-d7/a0-a6
        rts

; Shape rotation: selected ROM GSU829F, native Q15 FMULT+ROL semantics.
; MOBJ negates object BYTE angles<<8 and transposes the returned matrix.
; Original vertex consumer uses COLUMNS (ROM873F..8782), not rows.
; a0=ship32B, a1=9 WORDs row-major result. Clobbers d0-d3/a2/a3.
; No floating-point trig or alternate Euler algorithm. Products floor, WORD
; additions wrap exactly. The caller owns world/view composition separately.
M4IntroMatrix:
        lea -20(sp),sp
        movea.l sp,a2
        lea M4IntroMatrixSine,a3
        moveq #0,d3
M4IntroMatrixTrig:
        moveq #0,d0
        move.b 12(a0,d3.w),d0
        neg.b d0
        andi.w #255,d0
        move.w d0,d1
        add.w d0,d0
        move.w (a3,d0.w),(a2)+
        addi.w #64,d1
        andi.w #255,d1
        add.w d1,d1
        move.w (a3,d1.w),(a2)+
        addq.w #1,d3
        cmpi.w #3,d3
        bne.s M4IntroMatrixTrig
        movea.l sp,a2 ; sx,cx,sy,cy,sz,cz,t1,t2,t3,t4
        move.w 10(a2),d0
        move.w 4(a2),d1
        bsr M4IntroMatrixMul
        move.w d0,12(a2)
        move.w 10(a2),d0
        move.w 6(a2),d1
        bsr M4IntroMatrixMul
        move.w d0,14(a2)
        move.w 8(a2),d0
        move.w 4(a2),d1
        bsr M4IntroMatrixMul
        move.w d0,16(a2)
        move.w 8(a2),d0
        move.w 6(a2),d1
        bsr M4IntroMatrixMul
        move.w d0,18(a2)
        move.w 16(a2),d0
        move.w (a2),d1
        bsr M4IntroMatrixMul
        add.w 14(a2),d0
        move.w d0,(a1)
        move.w 12(a2),d0
        move.w (a2),d1
        bsr M4IntroMatrixMul
        sub.w 18(a2),d0
        move.w d0,6(a1)
        move.w 2(a2),d0
        move.w 4(a2),d1
        bsr M4IntroMatrixMul
        move.w d0,12(a1)
        move.w 2(a2),d0
        move.w 8(a2),d1
        bsr M4IntroMatrixMul
        move.w d0,2(a1)
        move.w 2(a2),d0
        move.w 10(a2),d1
        bsr M4IntroMatrixMul
        move.w d0,8(a1)
        move.w (a2),d0
        neg.w d0
        move.w d0,14(a1)
        move.w 18(a2),d0
        move.w (a2),d1
        bsr M4IntroMatrixMul
        sub.w 12(a2),d0
        move.w d0,4(a1)
        move.w 14(a2),d0
        move.w (a2),d1
        bsr M4IntroMatrixMul
        add.w 16(a2),d0
        move.w d0,10(a1)
        move.w 2(a2),d0
        move.w 6(a2),d1
        bsr M4IntroMatrixMul
        move.w d0,16(a1)
        lea 20(sp),sp
        rts
M4IntroMatrixMul:
        muls.w d1,d0
        asr.l #8,d0
        asr.l #7,d0
        rts
M4IntroMatrixSine:
        incbin '../build/intro-matrix-sine.bin'
        even

M4IntroMatrixTest:
        move.l #'M4MX',$ff44c0
        clr.l $ff44c4
        lea M4IntroMatrixCases,a4
        move.w #M4_MATRIX_CASES-1,d7
M4IntroMatrixTestNext:
        lea $ffa100,a0
        move.w (a4)+,d0
        move.b d0,12(a0)
        move.w (a4)+,d0
        move.b d0,13(a0)
        move.w (a4)+,d0
        move.b d0,14(a0)
        lea $ffa120,a1
        bsr M4IntroMatrix
        moveq #8,d2
M4IntroMatrixTestCompare:
        move.w (a4)+,d0
        cmp.w (a1)+,d0
        bne.s M4IntroMatrixTestBad
        dbra d2,M4IntroMatrixTestCompare
        addq.w #1,$ff44c6
        dbra d7,M4IntroMatrixTestNext
        move.w #1,$ff44c4
        rts
M4IntroMatrixTestBad:
        move.w #$ffff,$ff44c4
        rts
